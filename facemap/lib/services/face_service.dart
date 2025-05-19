import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img;
import 'ml_service.dart';

class LivenessResult {
  final bool isLive;
  final double leftStd;
  final double rightStd;
  final double headMovement;  // Added headMovement field to track this value

  LivenessResult({
    required this.isLive,
    required this.leftStd,
    required this.rightStd,
    required this.headMovement,  // Added to constructor
  });
}

class FaceService {
  final MLService _mlService;
  final FaceDetector _faceDetector;
  final FaceMeshDetector _faceMeshDetector;

  static const int _bufferSize = 20;
  // Made thresholds more lenient
  static const double _eyeStdThreshold = 0.03;  // Reduced from 0.05
  static const double _headMovementThreshold = 1.0;  // Reduced from 1.5

  final List<double> _leftEyeBuffer = [];
  final List<double> _rightEyeBuffer = [];
  final List<Offset> _noseBuffer = [];

  FaceService({required MLService mlService})
      : _mlService = mlService,
        // standard face detector for embeddings
        _faceDetector = GoogleMlKit.vision.faceDetector(
          FaceDetectorOptions(
            enableContours: false,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.accurate,
          ),
        ),
        // mesh detector for liveness
        _faceMeshDetector = GoogleMlKit.vision.faceMeshDetector();

  /// Detect face meshes for liveness checks.
  Future<List<FaceMesh>> detectFaceMeshes(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    try {
      return await _faceMeshDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Error detecting face meshes: $e');
      return [];
    }
  }

  /// Detect faces for embedding (bounding boxes only).
  Future<List<Face>> detectFaces(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Error detecting faces: $e');
      return [];
    }
  }

  /// Process a camera frame for liveness detection.
  Future<LivenessResult> processFrame(Uint8List imageBytes, String filePath) async {
    final meshes = await detectFaceMeshes(filePath);
    if (meshes.isEmpty) {
      return LivenessResult(isLive: false, leftStd: 0.0, rightStd: 0.0, headMovement: 0.0);
    }
    final mesh = meshes.first;
    final landmarks = mesh.points;

    // Eye‑Aspect Ratio computation
    final leftEAR = _calculateEAR(landmarks, _leftEyeIndices);
    final rightEAR = _calculateEAR(landmarks, _rightEyeIndices);
    _updateBuffer(_leftEyeBuffer, leftEAR);
    _updateBuffer(_rightEyeBuffer, rightEAR);
    final leftStd = _computeStdDev(_leftEyeBuffer);
    final rightStd = _computeStdDev(_rightEyeBuffer);

    // Nose‑tip head movement
    final nose = landmarks[1];
    final nosePos = Offset(nose.x.toDouble(), nose.y.toDouble());
    _updateNoseBuffer(nosePos);
    final headMovement = _computeNoseMovement(_noseBuffer);

    // Changed from AND (&&) to OR (||) condition to make it more lenient
    final eyeBlink = (leftStd > _eyeStdThreshold || rightStd > _eyeStdThreshold);
    final hasHeadMovement = headMovement > _headMovementThreshold;
    
    // Now we consider the person live if EITHER condition passes
    final isLive = eyeBlink || hasHeadMovement;

    return LivenessResult(
      isLive: isLive, 
      leftStd: leftStd, 
      rightStd: rightStd,
      headMovement: headMovement,
    );
  }

  /// Extract a face embedding using the standard detector for cropping.
  Future<List<double>> getEmbedding(Uint8List imageBytes, String filePath) async {
    // Detect face bounding box
    final faces = await detectFaces(filePath);
    if (faces.isEmpty) {
      return [];
    }
    final bbox = faces.first.boundingBox;

    // Decode and crop the raw image
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return [];

    final left = bbox.left.toInt().clamp(0, decoded.width - 1);
    final top = bbox.top.toInt().clamp(0, decoded.height - 1);
    final width = bbox.width.toInt().clamp(0, decoded.width - left);
    final height = bbox.height.toInt().clamp(0, decoded.height - top);

    final cropped = img.copyCrop(decoded, x: left, y: top, width: width, height: height);
    final resized = img.copyResize(cropped, width: 112, height: 112);

    // Compute embedding and normalize
    final emb = await _mlService.getEmbedding(resized);
    final norm2 = emb.fold(0.0, (s, e) => s + e * e);
    if (norm2 <= 0) return emb;
    final norm = sqrt(norm2);
    return emb.map((e) => e / norm).toList();
  }

  void dispose() {
    _faceMeshDetector.close();
    _faceDetector.close();
  }

  // ─── Helpers ────────────────────────────

  void _updateBuffer(List<double> buf, double val) {
    buf.add(val);
    if (buf.length > _bufferSize) buf.removeAt(0);
  }

  double _computeStdDev(List<double> vals) {
    if (vals.isEmpty) return 0.0;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final variance = vals.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / vals.length;
    return sqrt(variance);
  }

  void _updateNoseBuffer(Offset pos) {
    _noseBuffer.add(pos);
    if (_noseBuffer.length > _bufferSize) _noseBuffer.removeAt(0);
  }

  double _computeNoseMovement(List<Offset> pts) {
    if (pts.length < 2) return 0.0;
    final dx = <double>[];
    final dy = <double>[];
    for (var i = 1; i < pts.length; i++) {
      dx.add((pts[i].dx - pts[i - 1].dx).abs());
      dy.add((pts[i].dy - pts[i - 1].dy).abs());
    }
    final avgDx = dx.reduce((a, b) => a + b) / dx.length;
    final avgDy = dy.reduce((a, b) => a + b) / dy.length;
    return sqrt(pow(avgDx, 2) + pow(avgDy, 2));
  }

  double _calculateEAR(List<FaceMeshPoint> p, List<int> i) {
    final p1 = p[i[0]], p2 = p[i[1]], p3 = p[i[2]];
    final p4 = p[i[3]], p5 = p[i[4]], p6 = p[i[5]];
    final v1 = sqrt(pow(p2.x - p6.x, 2) + pow(p2.y - p6.y, 2));
    final v2 = sqrt(pow(p3.x - p5.x, 2) + pow(p3.y - p5.y, 2));
    final h = sqrt(pow(p1.x - p4.x, 2) + pow(p1.y - p4.y, 2));
    return (v1 + v2) / (2 * h);
  }

  static const List<int> _leftEyeIndices = [33, 159, 160, 133, 144, 153];
  static const List<int> _rightEyeIndices = [362, 386, 385, 263, 373, 380];
}


// import 'dart:typed_data';
// import 'dart:math'; // For sqrt, pow
// import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter/material.dart';
// import 'ml_service.dart';

// /// Result of liveness detection for a single frame sequence.
// class LivenessResult {
//   /// Whether the face is considered live based on eye-blink variation.
//   final bool isLive;

//   /// Standard deviation of left eye open probability over buffer.
//   final double leftStd;

//   /// Standard deviation of right eye open probability over buffer.
//   final double rightStd;

//   LivenessResult({
//     required this.isLive,
//     required this.leftStd,
//     required this.rightStd,
//   });
// }

// /// Service that detects faces and performs liveness check based on eye-blink variability.
// class FaceService {
//   final MLService _mlService;
//   final FaceDetector _faceDetector;

//   /// Buffer size of recent frames to analyze.
//   static const int _bufferSize = 20;

//   /// Thresholds for eye stddev to consider as live.
//   static const double _eyeStdThreshold = 0.05;

//   final List<double> _leftEyeBuffer = [];
//   final List<double> _rightEyeBuffer = [];

//   FaceService({required MLService mlService})
//       : _mlService = mlService,
//         _faceDetector = GoogleMlKit.vision.faceDetector(
//           FaceDetectorOptions(
//             enableContours: true,
//             enableLandmarks: true,
//             enableClassification: true,
//           ),
//         );

//   /// Detects faces in the image at [filePath].
//   Future<List<Face>> detectFaces(Uint8List imageBytes, String filePath) async {
//     final inputImage = InputImage.fromFilePath(filePath);
//     try {
//       final faces = await _faceDetector.processImage(inputImage);
//       debugPrint('Detected ${faces.length} faces');
//       return faces;
//     } catch (e) {
//       debugPrint('Error detecting faces: \$e');
//       return [];
//     }
//   }

//   /// Processes a frame, updating internal buffers and returning liveness result.
//   Future<LivenessResult> processFrame(Uint8List imageBytes, String filePath) async {
//     final faces = await detectFaces(imageBytes, filePath);
//     if (faces.isEmpty) {
//       // No face detected; treat as not live
//       return LivenessResult(isLive: false, leftStd: 0.0, rightStd: 0.0);
//     }

//     // Use first detected face
//     final face = faces.first;

//     // Get eye-open probabilities (0.0 to 1.0)
//     final leftProb = face.leftEyeOpenProbability ?? 0.0;
//     final rightProb = face.rightEyeOpenProbability ?? 0.0;

//     // Update buffers
//     _updateBuffer(_leftEyeBuffer, leftProb);
//     _updateBuffer(_rightEyeBuffer, rightProb);

//     // Compute standard deviations
//     final leftStd = _computeStdDev(_leftEyeBuffer);
//     final rightStd = _computeStdDev(_rightEyeBuffer);

//     // Determine liveness based on thresholds
//     final isLive = leftStd > _eyeStdThreshold || rightStd > _eyeStdThreshold;

//     return LivenessResult(isLive: isLive, leftStd: leftStd, rightStd: rightStd);
//   }

//   /// Crops and resizes a face region for embedding generation.
//   img.Image preprocessImage(img.Image image, Face face) {
//     final rect = face.boundingBox;

//     final int left = rect.left.toInt().clamp(0, image.width - 1);
//     final int top = rect.top.toInt().clamp(0, image.height - 1);
//     final int width = rect.width.toInt().clamp(0, image.width - left);
//     final int height = rect.height.toInt().clamp(0, image.height - top);

//     final cropped = img.copyCrop(image, x: left, y: top, width: width, height: height);
//     return img.copyResize(cropped, width: 112, height: 112);
//   }

//   /// Generates a normalized embedding vector for a face image.
//   Future<List<double>> getEmbedding(img.Image image) async {
//     final embeddings = await _mlService.getEmbedding(image);
//     final double normSquared = embeddings.fold(0.0, (sum, e) => sum + e * e);
//     if (normSquared <= 0) return embeddings;
//     final norm = sqrt(normSquared);
//     return embeddings.map((e) => e / norm).toList();
//   }

//   /// Closes the face detector.
//   void dispose() {
//     _faceDetector.close();
//   }

//   // -- Private utility methods --

//   void _updateBuffer(List<double> buffer, double value) {
//     buffer.add(value);
//     if (buffer.length > _bufferSize) buffer.removeAt(0);
//   }

//   double _computeStdDev(List<double> values) {
//     if (values.isEmpty) return 0.0;
//     final mean = values.reduce((a, b) => a + b) / values.length;
//     final variance = values
//         .map((v) => pow(v - mean, 2))
//         .reduce((a, b) => a + b) / values.length;
//     return sqrt(variance);
//   }
// }


// import 'dart:typed_data';
// import 'dart:math'; // For sqrt
// import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter/material.dart';
// import 'ml_service.dart';

// class FaceService {
//   final MLService _mlService;
//   final faceDetector = GoogleMlKit.vision.faceDetector(
//     FaceDetectorOptions(
//       enableContours: true,
//       enableLandmarks: true,
//     ),
//   );

//   FaceService({required MLService mlService}) : _mlService = mlService;

//   Future<List<Face>> detectFaces(Uint8List imageBytes, String filePath) async {
//     final inputImage = InputImage.fromFilePath(filePath);

//     try {
//       final faces = await faceDetector.processImage(inputImage);
//       debugPrint('Detected ${faces.length} faces');
//       return faces;
//     } catch (e) {
//       debugPrint('Error detecting faces: $e');
//       return [];
//     }
//   }

//   img.Image preprocessImage(img.Image image, Face face) {
//     final rect = face.boundingBox;

//     final int left = rect.left.toInt().clamp(0, image.width - 1);
//     final int top = rect.top.toInt().clamp(0, image.height - 1);
//     final int width = rect.width.toInt().clamp(0, image.width - left);
//     final int height = rect.height.toInt().clamp(0, image.height - top);

//     final cropped = img.copyCrop(image, x: left, y: top, width: width, height: height);
//     final resized = img.copyResize(cropped, width: 112, height: 112);

//     return resized;
//   }

//   Future<List<double>> getEmbedding(img.Image image) async {
//     final embeddings = await _mlService.getEmbedding(image);

//     // Normalize embeddings to unit length
//     final double norm = embeddings.fold(0.0, (sum, e) => sum + e * e);
//     final normalizedEmbeddings = norm > 0
//         ? embeddings.map((e) => e / sqrt(norm)).toList() // Use sqrt from dart:math
//         : embeddings;

//     return normalizedEmbeddings;
//   }

//   void dispose() {
//     faceDetector.close();
//   }
// }