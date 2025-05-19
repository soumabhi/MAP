import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ImageEnhancer {
  static const int inputSize = 112;

  static Float32List preprocessImage(img.Image image) {
    final enhancedImage = img.adjustColor(
      image,
      brightness: 1.2,
      contrast: 1.1,
      gamma: 0.8,
    );

    final resized = img.copyResize(
      enhancedImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );

    final normalized = Float32List(inputSize * inputSize * 3);
    int index = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        normalized[index++] = (pixel.r.toDouble() - 127.5) / 127.5;
        normalized[index++] = (pixel.g.toDouble() - 127.5) / 127.5;
        normalized[index++] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }
    return normalized;
  }

  static img.Image adaptivelyEnhance(img.Image image) {
    int totalLum = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        totalLum += image.getPixel(x, y).luminance.toInt();
      }
    }
    double avgLum = totalLum.toDouble() / (image.width * image.height);

    if (avgLum < 50) {
      return img.adjustColor(image, brightness: 1.4, contrast: 1.2, gamma: 0.6);
    } else if (avgLum < 100) {
      return img.adjustColor(image, brightness: 1.2, contrast: 1.1, gamma: 0.8);
    } else {
      return image;
    }
  }

  static img.Image histogramEqualize(img.Image image) {
    final gray = img.grayscale(image);
    final hist = List<int>.filled(256, 0);
    final width = gray.width;
    final height = gray.height;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final lum = gray.getPixel(x, y).luminance;
        hist[lum.toInt()]++;
      }
    }
    final cdf = List<int>.filled(256, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + hist[i];
    }
    final totalPixels = width * height;
    final equalized = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final origPixel = image.getPixel(x, y);
        final r = origPixel.r;
        final g = origPixel.g;
        final b = origPixel.b;
        final a = origPixel.a;
        final lum = origPixel.luminance;
        final newLum = (cdf[lum.toInt()] * 255 ~/ totalPixels).clamp(0, 255);
        final scale = lum > 0 ? newLum.toDouble() / lum : 1.0;
        final nr = (r * scale).clamp(0, 255).toInt();
        final ng = (g * scale).clamp(0, 255).toInt();
        final nb = (b * scale).clamp(0, 255).toInt();
        equalized.setPixelRgba(x, y, nr, ng, nb, a);
      }
    }
    return equalized;
  }
}

class MLService {
  late Interpreter _interpreter;
  static const int embeddingSize = 192;
  static const double similarityThreshold = 0.7;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      debugPrint('Loading model from assets/mobile_facenet.tflite');
      _interpreter = await Interpreter.fromAsset('assets/mobile_facenet.tflite', options: options);
      debugPrint('Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading model: $e');
      rethrow;
    }
  }

  Future<List<double>> getEmbedding(img.Image image) async {
    final enhanced = ImageEnhancer.adaptivelyEnhance(image);
    final input = ImageEnhancer.preprocessImage(enhanced).reshape([1, 112, 112, 3]);
    final output = List<double>.filled(embeddingSize, 0.0).reshape([1, embeddingSize]);

    try {
      _interpreter.run(input, output);
      debugPrint('Model inference completed');
    } catch (e) {
      debugPrint('Error in inference: $e');
      rethrow;
    }

    return _l2Normalize(List<double>.from(output[0]));
  }

  List<double> _l2Normalize(List<double> embedding) {
    double sum = 0.0;
    for (final val in embedding) {
      sum += val * val;
    }
    if (sum > 1e-6) {
      double invNorm = 1.0 / sqrt(sum);
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] *= invNorm;
      }
    } else {
      debugPrint('Warning: Near-zero embedding vector');
    }
    return embedding;
  }

  double calculateSimilarity(List<dynamic> emb1, List<dynamic> emb2) {
    if (emb1.isEmpty || emb2.isEmpty || emb1.length != emb2.length) return -1.0;
    double dot = 0.0, norm1 = 0.0, norm2 = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      final v1 = emb1[i].toDouble();
      final v2 = emb2[i].toDouble();
      dot += v1 * v2;
      norm1 += v1 * v1;
      norm2 += v2 * v2;
    }
    if (norm1 < 1e-6 || norm2 < 1e-6) return 0.0;
    return (dot / (sqrt(norm1) * sqrt(norm2))).clamp(-1.0, 1.0);
  }

  bool doFacesMatch(List<dynamic> emb1, List<dynamic> emb2, {double threshold = similarityThreshold}) {
    final similarity = calculateSimilarity(emb1, emb2);
    debugPrint('Similarity: $similarity');
    return similarity >= threshold;
  }

  void dispose() {
    _interpreter.close();
    debugPrint('Interpreter disposed');
  }
}



// import 'dart:math';

// import 'package:flutter/foundation.dart';
// import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';

// class MLService {
//   late Interpreter _interpreter;
//   // Changed to lowerCamelCase as per Dart style guide
//   static const int inputSize = 112;
//   static const int embeddingSize = 192;
//   static const double similarityThreshold = 0.7; // Configurable threshold
  
//   Future<void> loadModel() async {
//     try {
//       final options = InterpreterOptions()..threads = 4; // Optimize with multi-threading
//       debugPrint('Loading model from assets/mobile_facenet.tflite');
//       _interpreter = await Interpreter.fromAsset(
//         'assets/mobile_facenet.tflite',
//         options: options,
//       );
//       debugPrint('Model loaded successfully with input shape: ${_interpreter.getInputTensor(0).shape}');
//       debugPrint('Output shape: ${_interpreter.getOutputTensor(0).shape}');
//     } catch (e) {
//       debugPrint('Error loading model: $e');
//       rethrow;
//     }
//   }
  
//   Future<List<double>> getEmbedding(img.Image image) async {
//     // Preprocess the image
//     final processedData = preprocessImage(image);
    
//     // Reshape the input to [1, 112, 112, 3]
//     final input = processedData.reshape([1, inputSize, inputSize, 3]);
    
//     // Prepare the output buffer with the correct shape
//     final output = List<double>.filled(embeddingSize, 0.0).reshape([1, embeddingSize]);
    
//     try {
//       // Run the model with error handling
//       _interpreter.run(input, output);
//       debugPrint('Model inference completed successfully');
//     } catch (e) {
//       debugPrint('Error running model inference: $e');
//       rethrow;
//     }
    
//     // Convert the output to a list of doubles and normalize
//     final embedding = List<double>.from(output[0]);
    
//     // L2 normalize the embedding (crucial for accurate cosine similarity)
//     return _l2Normalize(embedding);
//   }
  
//   Float32List preprocessImage(img.Image image) {
//     try {
//       // Check if image needs resizing
//       img.Image processedImage = image;
//       if (image.width != inputSize || image.height != inputSize) {
//         processedImage = img.copyResize(
//           image, 
//           width: inputSize, 
//           height: inputSize,
//           interpolation: img.Interpolation.cubic, // Better quality resize
//         );
//       }
      
//       debugPrint('Image processed to: ${processedImage.width}x${processedImage.height}');
      
//       // Normalize the pixel values to [-1, 1] using more efficient approach
//       final normalized = Float32List(inputSize * inputSize * 3);
      
//       int index = 0;
//       for (int y = 0; y < inputSize; y++) {
//         for (int x = 0; x < inputSize; x++) {
//           final pixel = processedImage.getPixel(x, y);
//           // Normalize to [-1, 1] range
//           normalized[index++] = (pixel.r - 127.5) / 127.5;
//           normalized[index++] = (pixel.g - 127.5) / 127.5;
//           normalized[index++] = (pixel.b - 127.5) / 127.5;
//         }
//       }
      
//       return normalized;
//     } catch (e) {
//       debugPrint('Error in image preprocessing: $e');
//       rethrow;
//     }
//   }
  
//   /// Calculates cosine similarity between two face embeddings
//   /// Returns value between -1 and 1 (1 being identical, -1 being opposite)
//   double calculateSimilarity(List<dynamic> emb1, List<dynamic> emb2) {
//     // Fixed null check issue - now checking for empty lists only
//     if (emb1.isEmpty || emb2.isEmpty) {
//       debugPrint('Warning: Empty embedding detected');
//       return -1.0; // Return invalid similarity
//     }
    
//     if (emb1.length != emb2.length) {
//       debugPrint('Warning: Embedding length mismatch: ${emb1.length} vs ${emb2.length}');
//       return -1.0; 
//     }
    
//     // Using efficient vector operations for cosine similarity
//     double dotProduct = 0.0;
//     double norm1 = 0.0;
//     double norm2 = 0.0;
    
//     // SIMD-friendly loop structure (helps compiler optimize)
//     final int length = emb1.length;
//     for (int i = 0; i < length; i++) {
//       final double val1 = emb1[i].toDouble();
//       final double val2 = emb2[i].toDouble();
      
//       dotProduct += val1 * val2;
//       norm1 += val1 * val1;
//       norm2 += val2 * val2;
//     }
    
//     // Compute cosine similarity with overflow protection
//     if (norm1 <= 1e-6 || norm2 <= 1e-6) {
//       debugPrint('Warning: Embedding normalization issue detected');
//       return 0.0;
//     }
    
//     final double similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    
//     // Clamp to valid range (floating point errors can cause values slightly outside [-1,1])
//     return similarity.clamp(-1.0, 1.0);
//   }
  
//   /// L2 normalization for more accurate similarity measurement
//   List<double> _l2Normalize(List<double> embedding) {
//     double squareSum = 0.0;
    
//     // Calculate sum of squares
//     for (var val in embedding) {
//       squareSum += val * val;
//     }
    
//     // Normalize only if we have non-zero values
//     if (squareSum > 1e-6) {
//       double invNorm = 1.0 / sqrt(squareSum);
//       for (int i = 0; i < embedding.length; i++) {
//         embedding[i] *= invNorm;
//       }
//     } else {
//       debugPrint('Warning: Near-zero embedding vector detected');
//     }
    
//     return embedding;
//   }
  
//   /// Checks if two face embeddings match
//   bool doFacesMatch(List<dynamic> emb1, List<dynamic> emb2, {double threshold = similarityThreshold}) {
//     final similarity = calculateSimilarity(emb1, emb2);
//     debugPrint('Face similarity score: $similarity');
//     return similarity >= threshold;
//   }
  
//   /// Calculate Euclidean distance between embeddings (alternative metric)
//   double calculateEuclideanDistance(List<dynamic> emb1, List<dynamic> emb2) {
//     if (emb1.isEmpty || emb2.isEmpty || emb1.length != emb2.length) {
//       return double.infinity;
//     }
    
//     double sumSquaredDifferences = 0.0;
//     for (int i = 0; i < emb1.length; i++) {
//       final diff = emb1[i].toDouble() - emb2[i].toDouble();
//       sumSquaredDifferences += diff * diff;
//     }
    
//     return sqrt(sumSquaredDifferences);
//   }
  
//   /// Gets information about the loaded model
//   Map<String, dynamic> getModelInfo() {
//     return {
//       'inputShape': _interpreter.getInputTensor(0).shape,
//       'outputShape': _interpreter.getOutputTensor(0).shape,
//       'embeddingSize': embeddingSize,
//       'defaultThreshold': similarityThreshold,
//     };
//   }
  
//   /// Dispose resources when no longer needed
//   void dispose() {
//     _interpreter.close();
//     debugPrint('ML resources released');
//   }
// }