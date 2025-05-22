import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../models/face_model.dart';
import '../services/face_service.dart';
import '../services/hive_service.dart';
import '../services/ml_service.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class ScanFaceScreen extends StatefulWidget {
  const ScanFaceScreen({super.key});

  @override
  State<ScanFaceScreen> createState() => _ScanFaceScreenState();
}

class _ScanFaceScreenState extends State<ScanFaceScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _statusMessage;
  Timer? _processingTimer;
  bool _showingSuccessDialog = false;

  // Attendance mode tracking
  String _attendanceMode = ''; // 'IN' or 'OUT'

  double _matchSimilarityThreshold = 0.7;
  double _highMatchThreshold = 0.85;
  double _minConfidenceScore = 0.5;

  double _scanLinePosition = 0.0;
  Timer? _scanAnimationTimer;
  bool _scanAnimationUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _startScanAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _processingTimer?.cancel();
    _scanAnimationTimer?.cancel();
    super.dispose();
  }

  void _startScanAnimation() {
    const animationSpeed = 0.01;
    _scanAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!mounted) return;

      setState(() {
        if (_scanAnimationUp) {
          _scanLinePosition -= animationSpeed;
          if (_scanLinePosition <= 0.0) {
            _scanLinePosition = 0.0;
            _scanAnimationUp = false;
          }
        } else {
          _scanLinePosition += animationSpeed;
          if (_scanLinePosition >= 1.0) {
            _scanLinePosition = 1.0;
            _scanAnimationUp = true;
          }
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _scanAnimationTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      _startScanAnimation();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _statusMessage =
            'Select IN or OUT, then position your face in the oval';
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera initialization failed';
        });
      }
    }
  }

  // Set attendance mode and start face detection
  void _setAttendanceMode(String mode) {
    setState(() {
      _attendanceMode = mode;
      _statusMessage = '$mode mode selected. Position your face in the oval';
    });
    _processingTimer = Timer(const Duration(seconds: 1), _startFaceDetection);
  }

  Future<void> _startFaceDetection() async {
    if (_isProcessing ||
        !_isCameraInitialized ||
        !mounted ||
        _showingSuccessDialog ||
        _attendanceMode.isEmpty)
      return;

    final faceService = context.read<FaceService>();
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Detecting face...';
    });
    try {
      final xFile = await _cameraController!.takePicture();
      final faces = await faceService.detectFaces(xFile.path);
      if (!mounted) return;
      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'No face detected. Please center your face';
          _isProcessing = false;
        });
        _processingTimer = Timer(
          const Duration(seconds: 2),
          _startFaceDetection,
        );
        return;
      }
      setState(() {
        _statusMessage = 'Face detected. Verifying...';
      });
      final isLive = await _performLivenessCheck(faceService);
      if (!mounted) return;
      if (!isLive) {
        setState(() {
          _statusMessage = 'Security alert: Liveness check failed';
          _isProcessing = false;
        });
        _processingTimer = Timer(
          const Duration(seconds: 3),
          _startFaceDetection,
        );
        return;
      }

      // CAPTURE NEW IMAGE AFTER LIVENESS CHECK
      final xFileNew = await _cameraController!.takePicture();
      final imageBytesNew = await xFileNew.readAsBytes();

      // VERIFY FACE IN NEW IMAGE
      final facesNew = await faceService.detectFaces(xFileNew.path);
      if (facesNew.isEmpty) {
        setState(() {
          _statusMessage = 'Face lost during verification';
          _isProcessing = false;
        });
        _processingTimer = Timer(
          const Duration(seconds: 2),
          _startFaceDetection,
        );
        return;
      }

      await _processFaceRecognition(imageBytesNew, xFileNew.path);
    } catch (e) {
      debugPrint('Error during face detection: $e');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error occurred during detection';
        _isProcessing = false;
      });
      _processingTimer = Timer(const Duration(seconds: 3), _startFaceDetection);
    }
  }

  Future<void> _processFaceRecognition(
  Uint8List imageBytes,
  String filePath,
) async {
  if (!mounted) return;
  setState(() {
    _statusMessage = 'Processing face...';
  });

  final faceService = context.read<FaceService>();
  final hiveService = context.read<HiveService>();
  final mlService = context.read<MLService>();
  final authService = AuthService();

  try {
    final faceEmbedding = await faceService.getEmbedding(imageBytes, filePath);
    if (faceEmbedding.isEmpty) {
      setState(() {
        _statusMessage = 'Failed to analyze face features';
        _isProcessing = false;
      });
      _processingTimer = Timer(const Duration(seconds: 3), _startFaceDetection);
      return;
    }

    final storedFaces = await hiveService.getFaces();
    if (!mounted || storedFaces.isEmpty) {
      setState(() {
        _statusMessage = 'No registered faces. Please register first';
        _isProcessing = false;
      });
      return;
    }

    Face? bestMatch;
    double bestSimilarity = 0.0;

    for (final storedFace in storedFaces) {
      if (storedFace.embedding.isEmpty) continue;
      final similarity = mlService.calculateSimilarity(faceEmbedding, storedFace.embedding);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = storedFace;
      }
    }

    if (bestSimilarity < _matchSimilarityThreshold || bestMatch == null) {
      setState(() {
        _statusMessage = '✗ No match found';
        _isProcessing = false;
      });
      _processingTimer = Timer(const Duration(seconds: 3), _startFaceDetection);
      return;
    }

    final match = bestMatch;
    final employeeId = match.employeeId;
    final branchId = await authService.getBranchId() ?? '';

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    // final formattedTime = DateFormat('HH:mm:ss').format(now);
    final fullTime = now.toIso8601String(); // e.g. 2025-05-21T11:53:41.000Z


    final body = {
      "user": employeeId,
      "date": formattedDate,
      // "branch": branchId,
      if (_attendanceMode == 'IN') "checkInTime": fullTime,
      if (_attendanceMode == 'OUT') "checkOutTime": fullTime,
      if (_attendanceMode == 'IN') "checkinBranch": branchId,
      if (_attendanceMode == 'OUT') "checkoutBranch": branchId,
    };

    final url = _attendanceMode == 'IN'
        ? 'http://10.0.2.2:5000/api/attendance/create'
        : 'http://10.0.2.2:5000/api/attendance/checkout';

    final headers = await authService.getAuthHeaders();
    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));

    debugPrint('✅ Attendance response (${response.statusCode}): ${response.body}');

    Map<String, dynamic>? employeeDetails;
    if (response.statusCode == 201 || response.statusCode == 200) {
      final empResponse = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/employee/byUserId/$employeeId'),
        headers: headers,
      );
      if (empResponse.statusCode == 200) {
        employeeDetails = jsonDecode(empResponse.body);
      }
    }

    // Determine confidence visuals
    Color confidenceColor = Colors.red;
    String confidenceLevel = "Low";

    if (bestSimilarity >= _highMatchThreshold) {
      confidenceColor = const Color.fromARGB(255, 59, 189, 61);
      confidenceLevel = "Very High";
    } else if (bestSimilarity >= 0.75) {
      confidenceColor = Colors.green;
      confidenceLevel = "High";
    } else if (bestSimilarity >= 0.7) {
      confidenceColor = Colors.lime;
      confidenceLevel = "Medium";
    } else {
      confidenceColor = Colors.amber;
      confidenceLevel = "Acceptable";
    }

    setState(() {
      _statusMessage = '✓ Match found: $employeeId';
      _showingSuccessDialog = true;
      _isProcessing = false;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
  if (!mounted) return;

  if (employeeDetails != null && employeeDetails['userName'] != null) {
    debugPrint('✅ Showing success modal');
    _showSuccessMatchDialog(
      match,
      employeeDetails,
      bestSimilarity,
      confidenceColor,
      confidenceLevel,
    );
  } else {
    // ❌ Modal not shown — fix stuck state
    debugPrint('❌ No modal shown. Resetting UI manually...');
    setState(() {
      _showingSuccessDialog = false;
      _isProcessing = false;
      _attendanceMode = ''; // ✅ critical
      _statusMessage = 'Attendance marked. Ready for next.';
    });
  }
});

  } catch (e) {
    debugPrint('❌ Face recognition error: $e');
    setState(() {
      _statusMessage = 'Error during recognition';
      _isProcessing = false;
    });
    _processingTimer = Timer(const Duration(seconds: 3), _startFaceDetection);
  }
}


  // Function to save attendance record to local storage
  // void _saveAttendanceRecord(String employeeId) {
  //   final hiveService = context.read<HiveService>();
  //   final now = DateTime.now();
  //   final formattedDate = DateFormat('yyyy-MM-dd').format(now);
  //   final formattedTime = DateFormat('HH:mm:ss').format(now);

  //   // Create attendance record
  //   final attendanceRecord = {
  //     'employeeId': employeeId,
  //     'date': formattedDate,
  //     'time': formattedTime,
  //     'type': _attendanceMode,
  //     'timestamp': now.millisecondsSinceEpoch,
  //   };

  //   // Save to local storage
  //   try {
  //     // Using a simple key format: attendance_{employeeId}_{date}_{mode}
  //     final key = 'attendance_${employeeId}_${formattedDate}_$_attendanceMode';
  //     hiveService.saveAttendanceRecord(key, attendanceRecord);
  //     debugPrint('Saved $key attendance record: $attendanceRecord');
  //   } catch (e) {
  //     debugPrint('Error saving attendance record: $e');
  //   }
  // }

  // Full dynamic _showSuccessMatchDialog with real employee data
void _showSuccessMatchDialog(
  Face match,
  Map<String, dynamic> employeeDetails,
  double confidence,
  Color confidenceColor,
  String confidenceLevel,
) {
  final dynamic userNameData = employeeDetails['userName'];
String employeeName = 'Unknown';

if (userNameData is Map<String, dynamic>) {
  employeeName =
      '${userNameData['salutation'] ?? ''} ${userNameData['firstName'] ?? ''} ${userNameData['lastName'] ?? ''}'.trim();
} else if (userNameData is String) {
  employeeName = userNameData;
}

  // final String employeeEmail = employeeDetails['userEmail'] ?? 'N/A';
  final String employeeId = employeeDetails['userId'] ?? '---';
  final String designation = employeeDetails['designationId']?['designationName'] ?? '---';
  final String imageUrl = employeeDetails['userFaceImage'] != null && employeeDetails['userFaceImage'].isNotEmpty
      ? 'http://10.0.2.2:5000/${employeeDetails['userFaceImage'][0]}'
      : '';
  final String shift = 'N/A'; // You can replace this with real shift data

  final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final String todayTime = DateFormat('HH:mm:ss').format(DateTime.now());

  // Screen size checks
  final Size screenSize = MediaQuery.of(context).size;
  final bool isSmallScreen = screenSize.width < 360;
  final bool isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
  final bool isTablet = screenSize.width >= 600;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : (isMediumScreen ? 18 : 24),
        vertical: isSmallScreen ? 12 : 24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: isTablet ? min(500, constraints.maxWidth) : constraints.maxWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: isSmallScreen ? 60 : 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyan.shade700,
                            Colors.cyan.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user, color: Colors.white, size: isSmallScreen ? 24 : 30),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "EMPLOYEE VERIFIED",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 14 : (isMediumScreen ? 16 : 18),
                                letterSpacing: isSmallScreen ? 1 : 2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(isSmallScreen ? 12 : (isMediumScreen ? 16 : 20)),
                      child: Column(
                        children: [
                          isSmallScreen
                              ? Column(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(imageUrl, fit: BoxFit.cover)
                                            : Icon(Icons.person, size: 60, color: Colors.grey),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    _buildEmployeeDetails(
                                      employeeName,
                                      designation,
                                      employeeId,
                                      shift,
                                      isSmallScreen,
                                      isMediumScreen,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Container(
                                      width: isMediumScreen ? 90 : 100,
                                      height: isMediumScreen ? 110 : 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(imageUrl, fit: BoxFit.cover)
                                            : Icon(Icons.person, size: 60, color: Colors.grey),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: _buildEmployeeDetails(
                                        employeeName,
                                        designation,
                                        employeeId,
                                        shift,
                                        isSmallScreen,
                                        isMediumScreen,
                                      ),
                                    ),
                                  ],
                                ),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                          Divider(color: Colors.grey.shade300),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          _buildAttendanceInfo(todayDate, todayTime, isSmallScreen, isMediumScreen),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "FACIAL RECOGNITION RESULTS",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    color: Colors.blueGrey.shade500,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                _buildConfidenceIndicators(
                                  confidence,
                                  confidenceColor,
                                  confidenceLevel,
                                  confidence,
                                  isSmallScreen,
                                  isMediumScreen,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showingSuccessDialog = false;
                                  _isProcessing = false;
                                  _attendanceMode = '';
                                });
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'CONTINUE',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  letterSpacing: isSmallScreen ? 1 : 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyan.shade700,
                            Colors.cyan.shade900,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Timer(const Duration(seconds: 5), () {
    if (Navigator.of(context).canPop() && _showingSuccessDialog) {
      setState(() {
        _showingSuccessDialog = false;
        _isProcessing = false;
        _attendanceMode = '';
      });
      Navigator.of(context).pop();
    }
  });
}


  // Helper method to build employee details
  Widget _buildEmployeeDetails(
    String name,
    String designation,
    String employeeId,
    String shift,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : (isMediumScreen ? 18 : 20),
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Text(
          designation,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.blueGrey.shade600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Text(
          "ID: $employeeId",
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Text(
          shift,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            color: Colors.blueGrey.shade600,
          ),
        ),
      ],
    );
  }

  // Helper method to build attendance information
  Widget _buildAttendanceInfo(
    String date,
    String time,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    return isSmallScreen
        ? Column(
          children: [
            _buildAttendanceItem("DATE", date, isSmallScreen, isMediumScreen),
            SizedBox(height: 12),
            _buildAttendanceItem("TIME", time, isSmallScreen, isMediumScreen),
            SizedBox(height: 12),
            _buildAttendanceStatus(isSmallScreen, isMediumScreen),
          ],
        )
        : Row(
          children: [
            Expanded(
              child: _buildAttendanceItem(
                "DATE",
                date,
                isSmallScreen,
                isMediumScreen,
              ),
            ),
            Expanded(
              child: _buildAttendanceItem(
                "TIME",
                time,
                isSmallScreen,
                isMediumScreen,
              ),
            ),
            Expanded(
              child: _buildAttendanceStatus(isSmallScreen, isMediumScreen),
            ),
          ],
        );
  }

  // Helper method to build a single attendance item
  Widget _buildAttendanceItem(
    String label,
    String value,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.blueGrey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : (isMediumScreen ? 15 : 16),
            color: Colors.blueGrey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper method to build attendance status
  Widget _buildAttendanceStatus(bool isSmallScreen, bool isMediumScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "STATUS",
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.blueGrey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color:
                _attendanceMode == 'IN'
                    ? Colors.green.shade100
                    : Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _attendanceMode == 'IN' ? Icons.login : Icons.logout,
                size: isSmallScreen ? 14 : 16,
                color:
                    _attendanceMode == 'IN'
                        ? Colors.green.shade700
                        : Colors.red.shade700,
              ),
              SizedBox(width: 4),
              Text(
                _attendanceMode,
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color:
                      _attendanceMode == 'IN'
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build confidence indicators
  Widget _buildConfidenceIndicators(
    double confidence,
    Color confidenceColor,
    String confidenceLevel,
    double similarity,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    // For small screens, display in a column
    if (isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfidenceItem(
            "CONFIDENCE",
            "${(confidence * 100).toStringAsFixed(1)}%",
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
          SizedBox(height: 10),
          _buildConfidenceItem(
            "LEVEL",
            confidenceLevel,
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
          SizedBox(height: 10),
          _buildConfidenceItem(
            "SIMILARITY",
            similarity.toStringAsFixed(3),
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
        ],
      );
    }

    // For medium and larger screens, display in a row
    return Row(
      children: [
        Expanded(
          child: _buildConfidenceItem(
            "CONFIDENCE",
            "${(confidence * 100).toStringAsFixed(1)}%",
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
        ),
        Expanded(
          child: _buildConfidenceItem(
            "LEVEL",
            confidenceLevel,
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
        ),
        Expanded(
          child: _buildConfidenceItem(
            "SIMILARITY",
            similarity.toStringAsFixed(3),
            confidenceColor,
            isSmallScreen,
            isMediumScreen,
          ),
        ),
      ],
    );
  }

  // Helper method to build a single confidence item
  Widget _buildConfidenceItem(
    String label,
    String value,
    Color color,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    return Column(
      crossAxisAlignment:
          isSmallScreen ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 11,
            color: Colors.blueGrey.shade400,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : (isMediumScreen ? 10 : 12),
            vertical: isSmallScreen ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : (isMediumScreen ? 15 : 16),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _performLivenessCheck(FaceService faceService) async {
    if (_cameraController == null || !_isCameraInitialized || !mounted)
      return false;

    // Keep frames needed at 5 for balance between speed and security
    const framesNeeded = 5;
    int liveFramesDetected = 0;

    try {
      for (var i = 0; i < framesNeeded; i++) {
        if (!mounted) return false;
        setState(() {
          _statusMessage = 'Security check ${i + 1}/$framesNeeded...';
        });
        final xFile = await _cameraController!.takePicture();
        final bytes = await xFile.readAsBytes();
        final livenessResult = await faceService.processFrame(
          bytes,
          xFile.path,
        );

        // Debug liveness values
        debugPrint(
          'Liveness frame $i: ${livenessResult.isLive} ' +
              '(leftStd: ${livenessResult.leftStd.toStringAsFixed(4)}, ' +
              'rightStd: ${livenessResult.rightStd.toStringAsFixed(4)}, ' +
              'headMovement: ${livenessResult.headMovement.toStringAsFixed(4)})',
        );

        if (livenessResult.isLive) liveFramesDetected++;
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // More strict check - require 60% of frames to pass (up from 50%)
      final isLive = liveFramesDetected >= (framesNeeded * 0.6);
      debugPrint(
        'Liveness result: $isLive ($liveFramesDetected/$framesNeeded frames passed)',
      );
      return isLive;
    } catch (e) {
      debugPrint('Error during liveness check: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview - now takes up full screen
          if (_isCameraInitialized)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: Transform.scale(
                    scaleX: -1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              ),
            ),

          // Custom face overlay and scan animation
          CustomPaint(
            size: Size.infinite,
            painter: FaceOverlayPainter(scanPosition: _scanLinePosition),
          ),

          // IN/OUT Buttons
          Positioned(
            bottom: 50, // Position above the status indicator
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
              ), // Padding on left and right sides
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween, // Space buttons evenly
                    children: [
                      // IN Button - Expanded to take up available space
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _setAttendanceMode('IN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center the content
                            children: [
                              Icon(Icons.login, color: Colors.white, size: 28),
                              SizedBox(width: 10),
                              Text(
                                'IN',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 16), // Consistent padding between buttons
                      // OUT Button - Expanded to take up available space
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _setAttendanceMode('OUT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center the content
                            children: [
                              Icon(Icons.logout, color: Colors.white, size: 28),
                              SizedBox(width: 10),
                              Text(
                                'OUT',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Status indicator at bottom
          // Positioned(
          //   bottom: 50,
          //   left: 0,
          //   right: 0,
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          //     margin: const EdgeInsets.symmetric(horizontal: 30),
          //     decoration: BoxDecoration(
          //       color: Colors.black.withOpacity(0.7),
          //       borderRadius: BorderRadius.circular(20),
          //       border: Border.all(
          //         color: _attendanceMode == 'IN'
          //           ? Colors.green.withOpacity(0.3)
          //           : _attendanceMode == 'OUT'
          //             ? Colors.red.withOpacity(0.3)
          //             : Colors.cyan.withOpacity(0.3),
          //         width: 1,
          //       ),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black.withOpacity(0.2),
          //           blurRadius: 10,
          //           offset: Offset(0, 5),
          //         ),
          //       ],
          //     ),
          //     child: Column(
          //       children: [
          //         if (_isProcessing)
          //           Padding(
          //             padding: EdgeInsets.only(bottom: 12),
          //             child: SizedBox(
          //               width: 24,
          //               height: 24,
          //               child: CircularProgressIndicator(
          //                 color: _attendanceMode == 'IN'
          //                   ? Colors.green.shade200
          //                   : _attendanceMode == 'OUT'
          //                     ? Colors.red.shade200
          //                     : Colors.cyan.shade200,
          //                 strokeWidth: 2,
          //               ),
          //             ),
          //           ),
          //         Text(
          //           _statusMessage ?? '',
          //           textAlign: TextAlign.center,
          //           style: TextStyle(
          //             color: Colors.white,
          //             fontSize: 16,
          //             fontWeight: FontWeight.w600,
          //             letterSpacing: 0.5,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),

          // Help button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _showHelpDialog();
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.help_outline, color: Colors.white),
              ),
            ),
          ),

          // Settings button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () {
                _showSettingsDialog();
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.cyan),
                SizedBox(width: 10),
                Text('Help & Instructions'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.looks_one, color: Colors.cyan),
                    title: Text('Select Mode'),
                    subtitle: Text('Choose IN when arriving, OUT when leaving'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.looks_two, color: Colors.cyan),
                    title: Text('Position Your Face'),
                    subtitle: Text('Center your face within the oval guide'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.looks_3, color: Colors.cyan),
                    title: Text('Remain Still'),
                    subtitle: Text('Hold steady for the face verification'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.looks_4, color: Colors.cyan),
                    title: Text('Verification'),
                    subtitle: Text(
                      'The system will automatically verify your identity',
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please ensure good lighting and remove glasses for best results.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('GOT IT'),
                style: TextButton.styleFrom(foregroundColor: Colors.cyan),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.cyan),
                    SizedBox(width: 10),
                    Text('Recognition Settings'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Face Match Threshold',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _matchSimilarityThreshold,
                        min: 0.5,
                        max: 0.9,
                        divisions: 8,
                        label: _matchSimilarityThreshold.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() {
                            _matchSimilarityThreshold = value;
                          });
                        },
                      ),
                      Text(
                        'Current: ${_matchSimilarityThreshold.toStringAsFixed(2)} (Higher = Stricter)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 16),

                      Text(
                        'High Match Threshold',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _highMatchThreshold,
                        min: 0.7,
                        max: 0.95,
                        divisions: 5,
                        label: _highMatchThreshold.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() {
                            _highMatchThreshold = value;
                          });
                        },
                      ),
                      Text(
                        'Current: ${_highMatchThreshold.toStringAsFixed(2)} (For high confidence display)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 16),

                      Text(
                        'Minimum Confidence Score',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _minConfidenceScore,
                        min: 0.3,
                        max: 0.7,
                        divisions: 8,
                        label: _minConfidenceScore.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() {
                            _minConfidenceScore = value;
                          });
                        },
                      ),
                      Text(
                        'Current: ${_minConfidenceScore.toStringAsFixed(2)} (Higher = More strict)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 16),

                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.cyan),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Increasing thresholds improves security but may reduce recognition rates in challenging conditions.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('CANCEL'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      // Apply settings to main widget state
                      this.setState(() {
                        this._matchSimilarityThreshold =
                            _matchSimilarityThreshold;
                        this._highMatchThreshold = _highMatchThreshold;
                        this._minConfidenceScore = _minConfidenceScore;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text('SAVE'),
                    style: TextButton.styleFrom(foregroundColor: Colors.cyan),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            },
          ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final double scanPosition;

  FaceOverlayPainter({required this.scanPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Calculate a more balanced oval shape for mobile
    // Use the smaller dimension as a base to maintain proportions
    final smallerDimension =
        size.width < size.height ? size.width : size.height;

    // Make oval proportional regardless of screen dimensions
    final radiusX = smallerDimension * 0.35;
    // Keep face oval slightly taller than wide for realistic face proportions
    final radiusY = radiusX * 1.15; // Just slightly taller than wide

    // Draw semi-transparent overlay with gradient
    final backgroundPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    // Create a path for the entire screen
    final backgroundPath =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the face cutout (oval)
    final ovalRect = Rect.fromCenter(
      center: center,
      width: radiusX * 2,
      height: radiusY * 2,
    );
    final cutoutPath = Path()..addOval(ovalRect);

    // Subtract the cutout from the background
    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, backgroundPaint);

    // Draw the oval outline with glow effect
    // First draw outer glow
    for (double i = 5; i >= 0; i--) {
      final glowPaint =
          Paint()
            ..color = Colors.white.withOpacity(0.03 * (6 - i))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 + i;

      final glowRect = Rect.fromCenter(
        center: center,
        width: radiusX * 2 + i * 2,
        height: radiusY * 2 + i * 2,
      );

      canvas.drawOval(glowRect, glowPaint);
    }

    // Draw the main oval border
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    canvas.drawOval(ovalRect, borderPaint);

    // Draw face alignment guides with subtle dashed lines
    final guidesPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw dashed horizontal line
    _drawDashedLine(
      canvas,
      Offset(center.dx - radiusX, center.dy),
      Offset(center.dx + radiusX, center.dy),
      guidesPaint,
    );

    // Draw dashed vertical line
    _drawDashedLine(
      canvas,
      Offset(center.dx, center.dy - radiusY),
      Offset(center.dx, center.dy + radiusY),
      guidesPaint,
    );

    // Draw face recognition landmarks as subtle hints
    final landmarkPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Eyes position hints (as small circles)
    final eyeOffsetX = radiusX * 0.5;
    final eyeOffsetY = radiusY * 0.2;
    final eyeRadius = 4.0;

    canvas.drawCircle(
      Offset(center.dx - eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      landmarkPaint,
    );

    canvas.drawCircle(
      Offset(center.dx + eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      landmarkPaint,
    );

    // Mouth position hint (as a small line)
    final mouthOffsetY = radiusY * 0.3;
    final mouthWidth = radiusX * 0.5;

    canvas.drawLine(
      Offset(center.dx - mouthWidth / 2, center.dy + mouthOffsetY),
      Offset(center.dx + mouthWidth / 2, center.dy + mouthOffsetY),
      landmarkPaint,
    );

    // Nose position hint (optional small dot)
    canvas.drawCircle(center, 3.0, landmarkPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final count = sqrt(dx * dx + dy * dy) / (dashWidth + dashSpace);
    final x = dx / count;
    final y = dy / count;

    var startX = start.dx;
    var startY = start.dy;

    for (int i = 0; i < count; i++) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(
          startX + x * dashWidth / (dashWidth + dashSpace),
          startY + y * dashWidth / (dashWidth + dashSpace),
        ),
        paint,
      );
      startX += x;
      startY += y;
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.scanPosition != scanPosition;
  }
}
