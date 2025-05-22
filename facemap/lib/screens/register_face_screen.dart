import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/face_model.dart';
import '../services/face_service.dart';
import '../services/hive_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraOpen = false;
  bool _isProcessing = false;
  String _statusMessage = '';
  final TextEditingController _employeeIdController = TextEditingController();
  bool _isEmployeeIdEntered = false;

  // Auto-capture related variables
  Timer? _captureTimer;
  bool _isFaceDetected = false;
  bool _isCountingDown = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Guide steps
  int _currentGuideStep = 0;
  final List<String> _guideSteps = [
    'Position your face in the oval',
    'Make sure there is good lighting',
    'Keep a neutral expression',
    'Hold still for auto-capture',
  ];
  Timer? _guideTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _countdownController;
  late Animation<double> _countdownAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for the capture indicator
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup fade animation for guidelines
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _fadeController.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _currentGuideStep = (_currentGuideStep + 1) % _guideSteps.length;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _fadeController.forward();
            }
          });
        }
      }
    });

    // Setup countdown animation
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _countdownAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    if (_cameraController != null) {
      _cameraController!.dispose();
    }
    _pulseController.dispose();
    _fadeController.dispose();
    _countdownController.dispose();
    _employeeIdController.dispose();

    if (_guideTimer != null) {
      _guideTimer!.cancel();
    }
    if (_captureTimer != null) {
      _captureTimer!.cancel();
    }
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
    }
    super.dispose();
  }

  Future<void> _uploadFaceToBackend(String employeeId, List<double> embedding) async {
  final url = Uri.parse('http://10.0.2.2:5000/api/employee/registerEmployeFace');
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': employeeId, 'embedding': embedding}),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ [Backend] Face data uploaded successfully for $employeeId');
    } else {
      debugPrint('❌ [Backend] Failed to upload face: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    debugPrint('❗ [Backend] Exception while uploading face: $e');
  }
}

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Initializing camera...';
      _isProcessing = true;
    });

    if (_isCameraOpen) return;

    try {
      // Set preferred orientations to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = '';
          });
          _showResult(context, 'No cameras available');
        }
        return;
      }

      // Get the front camera for selfies
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.initialize();

      // Check if widget is still mounted before updating state
      if (!mounted) {
        cameraController.dispose();
        return;
      }

      _cameraController = cameraController;

      // Start face detection and auto-capture logic
      _startFaceDetection();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraOpen = true;
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
        _showResult(context, 'Failed to initialize camera: $e');
      }
    }
  }

  void _startFaceDetection() {
    // Cancel any existing timer
    if (_captureTimer != null) {
      _captureTimer!.cancel();
    }

    // This simulates the face detection process
    // In a real app, you would use an ML model or camera face detection capabilities
    _captureTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!mounted ||
          _isProcessing ||
          !_isCameraOpen ||
          _cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        // This would normally be face detection logic
        // For demo purposes, we'll simulate face detection
        final image = await _cameraController?.takePicture();
        if (image == null) return;

        if (!mounted) return;

        final faceService = Provider.of<FaceService>(context, listen: false);
        final faces = await faceService.detectFaces(image.path);

        if (!mounted) return;

        final hasFace = faces.isNotEmpty;

        if (hasFace && !_isCountingDown) {
          // Face detected, start countdown for capture
          setState(() {
            _isFaceDetected = true;
            _isCountingDown = true;
            _countdownValue = 3;
          });

          _startCountdown();
          timer.cancel(); // Stop checking while countdown is active
        } else if (!hasFace) {
          setState(() {
            _isFaceDetected = false;
          });
        }
      } catch (e) {
        // Silently handle errors during face detection
        debugPrint('Face detection error: $e');
      }
    });
  }

  void _startCountdown() {
    // Cancel any existing timer
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
        // Play animation
        _countdownController.reset();
        _countdownController.forward();
      } else {
        timer.cancel();
        _takePicture();
      }
    });

    // Start the first animation
    _countdownController.reset();
    _countdownController.forward();
  }

  void _verifyAndProceedWithEmployeeId() async {
  final employeeId = _employeeIdController.text.trim();

  debugPrint('🟡 Verifying Employee ID: "$employeeId"');

  if (employeeId.isEmpty) {
    debugPrint('❌ Employee ID is empty');
    _showResult(context, 'Please enter your Employee ID', isError: true);
    return;
  }

  setState(() {
    _isProcessing = true;
    _statusMessage = 'Verifying employee ID...';
  });

  try {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    debugPrint('🔐 Retrieved Auth Token: ${token != null ? "Yes" : "No"}');
    final url = 'http://10.0.2.2:5000/api/employee/byUserId/$employeeId';
    debugPrint('🌐 Sending GET request to: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('📩 Response Status Code: ${response.statusCode}');
    debugPrint('📦 Response Body: ${response.body}');

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('✅ Employee Found: ${data['userName']} (${data['userId']})');

      final faceExists = data['faceIdExist'] == 1;

      if (faceExists) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Face Already Registered"),
            content: const Text("This employee already has a registered face. Do you want to replace it?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Replace"),
              ),
            ],
          ),
        );

        if (confirm != true) {
          setState(() {
            _isProcessing = false;
            _statusMessage = '';
          });
          return;
        }
      }

      setState(() {
        _isEmployeeIdEntered = true;
        _isProcessing = false;
        _statusMessage = '';
      });

      debugPrint('🎯 Employee ID matched, proceeding to initialize camera...');
      _initializeCamera();
    } else if (response.statusCode == 404) {
      debugPrint('❗ Employee not found with ID: $employeeId');
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
      _showResult(context, 'Employee not found with ID: $employeeId', isError: true);
    } else {
      debugPrint('⚠️ Unexpected Server Response: ${response.statusCode}');
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
      _showResult(context, 'Server error: ${response.statusCode}', isError: true);
    }
  } catch (e) {
    debugPrint('🔥 Exception occurred during verification: $e');
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _statusMessage = '';
    });
    _showResult(context, 'Error verifying employee ID: $e', isError: true);
  }
}

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Capturing image...';
        _isCountingDown = false;
      });

      if (_captureTimer != null) {
        _captureTimer!.cancel();
      }
      if (_countdownTimer != null) {
        _countdownTimer!.cancel();
      }

      final XFile? image = await _cameraController?.takePicture();
      if (image == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = '';
          });
          _showResult(context, 'Failed to capture image', isError: true);
        }
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Processing face...';
      });

      final faceService = Provider.of<FaceService>(context, listen: false);

      // Detect faces
      final faces = await faceService.detectFaces(image.path);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
        _showResult(context, 'No face detected', isError: true);

        // Restart face detection after error
        _startFaceDetection();
        return;
      }

      setState(() {
        _statusMessage = 'Generating face profile...';
      });

      // Generate embedding
      final embedding = await faceService.getEmbedding(bytes, image.path);

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Saving your profile...';
      });

      // Save to Hive
      final newFace = Face(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        employeeId: _employeeIdController.text.trim(),
        embedding: embedding,
      );

      final hiveService = Provider.of<HiveService>(context, listen: false);
      await hiveService.registerFace(newFace);

      await _uploadFaceToBackend(newFace.employeeId, newFace.embedding);

      // await _uploadFaceDataToServer(newFace.employeeId, newFace.embedding);

      // Reset orientations and close camera
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      if (!mounted) return;

      setState(() {
        _isCameraOpen = false;
        _isProcessing = false;
        _statusMessage = '';
        _isEmployeeIdEntered =
            false; // Reset to show employee ID input screen again
      });

      _showSuccessDialog(_employeeIdController.text.trim());

      // Clear the employee ID field for next registration
      _employeeIdController.clear();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
        _showResult(context, 'Failed to register face: $e', isError: true);

        // Restart face detection after error
        _startFaceDetection();
      }
    }
  }

  void _showSuccessDialog(String employeeId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Success Dialog',
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: curvedAnimation,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 35,
                  child: Icon(Icons.check, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 20),
                Text(
                  'Success!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Employee ID: $employeeId has been registered successfully',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.cyan.shade700,
                  const Color.fromARGB(255, 10, 107, 110),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child:
                _isEmployeeIdEntered
                    ? _buildCameraView()
                    : _buildEmployeeIdInputScreen(),
          ),

          // App bar
          Positioned(
  top: 10,
  left: 0,
  right: 0,
  child: SafeArea(
    child: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(
        color: Colors.white, 
        size: 32,            
      ),
      title: Text(
        'Face Registration',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 25,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      automaticallyImplyLeading: true, // Ensures back button appears
      // Apply padding to the entire AppBar instead of just the title
      toolbarHeight: 70, // Increase height to accommodate the text size
    ),
  ),
),



          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: const Color.fromRGBO(0, 0, 0, 0.54),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.cyan,
                            ),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeIdInputScreen() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Calculate responsive sizes based on screen width
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final isTablet = screenWidth > 600;
      
      // Responsive sizing calculations
      final iconSize = isTablet ? 150.0 : 100.0;
      final titleFontSize = isTablet ? 35.0 : 26.0;
      final descriptionFontSize = isTablet ? 20.0 : 16.0;
      final inputFontSize = isTablet ? 20.0 : 16.0;
      final hintFontSize = isTablet ? 18.0 : 14.0;
      final buttonFontSize = isTablet ? 18.0 : 16.0;
      final securityFontSize = isTablet ? 16.0 : 12.0;
      final inputFieldWidth = isTablet 
          ? 400.0 
          : min(screenWidth * 0.85, 350.0); // Responsive width with upper limit
      
      // Calculate responsive padding
      final screenPadding = isTablet ? 30.0 : 20.0;
      final verticalSpacing = isTablet ? 1.0 : 0.8; // Spacing multiplier
      
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600, // Maximum width for content
            maxHeight: screenHeight * 0.95, // Maximum height while avoiding overflow
          ),
          child: Padding(
            padding: EdgeInsets.all(screenPadding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top space for app bar
              SizedBox(height: 10 * verticalSpacing),
      
              // ID Card Icon
              Icon(
                Icons.badge_outlined,
                size: iconSize,
                color: const Color(0xE6FFFFFF), // More efficient than withOpacity(0.9)
              ),
      
              SizedBox(height: 30 * verticalSpacing),
      
              // Title
              Text(
                'Enter Employee ID',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      
              SizedBox(height: 20 * verticalSpacing),
      
              // Description
              Text(
                'Please enter your numeric employee ID to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: descriptionFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xCCFFFFFF), // More efficient than withOpacity(0.8)
                ),
              ),
      
              SizedBox(height: 40 * verticalSpacing),
      
              // Employee ID Input Field
              Container(
                width: inputFieldWidth,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF), // More efficient than withOpacity(0.2)
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0x4DFFFFFF)), // More efficient than withOpacity(0.3)
                ),
                child: TextField(
                  controller: _employeeIdController,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: inputFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: Colors.white,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Employee ID (only numbers)',
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xB3FFFFFF), // More efficient than withOpacity(0.7)
                      fontSize: hintFontSize,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
                ),
              ),
      
              SizedBox(height: 50 * verticalSpacing),
      
              // Continue Button
              SizedBox(
                width: isTablet ? null : min(screenWidth * 0.7, 280.0),
                child: ElevatedButton(
                  onPressed: _verifyAndProceedWithEmployeeId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.cyan.shade700,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 50 : 30, 
                      vertical: isTablet ? 16 : 12
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      
              SizedBox(height: 40 * verticalSpacing),
      
              // Security note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    color: const Color(0xB3FFFFFF), // More efficient than withOpacity(0.7)
                    size: isTablet ? 20 : 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Your data is securely encrypted',
                    style: GoogleFonts.poppins(
                      fontSize: securityFontSize,
                      color: const Color(0xB3FFFFFF), // More efficient than withOpacity(0.7)
                    ),
                  ),
                ],
              ),
            ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'Initializing camera...',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // This ensures the camera preview takes up the entire screen
    return Stack(
      children: [
        // Full screen camera preview
        Positioned.fill(
          child: Transform(
            // Apply horizontal flip to mirror the camera feed
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // PI radians = 180 degrees
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

        // Face overlay guide
        Positioned.fill(
          child: CustomPaint(
            painter: FaceGuidePainter(isActive: _isFaceDetected),
          ),
        ),

        // Fading guidelines with sequential display
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _getIconForGuideStep(_currentGuideStep),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _guideSteps[_currentGuideStep],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Face detected indicator
        if (_isFaceDetected)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.06,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Face Detected',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Countdown overlay
        if (_isCountingDown)
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _countdownAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + _countdownAnimation.value,
                    child: Opacity(
                      opacity: 1.0 - _countdownAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Text(
                            '$_countdownValue',
                            style: GoogleFonts.poppins(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Auto-capture indicator (instead of capture button)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Auto-Capture Enabled',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Position your face in the oval',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Icon _getIconForGuideStep(int step) {
    switch (step) {
      case 0:
        return const Icon(Icons.face, color: Colors.white, size: 24);
      case 1:
        return const Icon(Icons.wb_sunny, color: Colors.white, size: 24);
      case 2:
        return const Icon(
          Icons.sentiment_neutral,
          color: Colors.white,
          size: 24,
        );
      case 3:
        return const Icon(Icons.auto_awesome, color: Colors.white, size: 24);
      default:
        return const Icon(Icons.info, color: Colors.white, size: 24);
    }
  }

  void _showResult(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  isError ? Icons.error : Icons.info,
                  color: isError ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 10),
                Text(
                  isError ? 'Error' : 'Information',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(message, style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.cyan),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }
}

// Enhanced custom painter to draw a face guide overlay
class FaceGuidePainter extends CustomPainter {
  final bool isActive;

  FaceGuidePainter({this.isActive = false});

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
