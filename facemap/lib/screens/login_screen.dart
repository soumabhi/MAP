import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      // Simulated login delay
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });

        // Mock login condition - you can change these credentials as needed
        if (_branchIdController.text == 'B001' &&
            _passwordController.text == '1234') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          _showErrorDialog(context);
        }
      });
    }
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Login Failed', textAlign: TextAlign.center),
        content: const Text(
          'Invalid Branch ID or password. Please try again.',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.cyan.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600; // Typical breakpoint for tablet
    
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Gradient Background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00838F), // Cyan 800
                      Color(0xFF006064), // Cyan 900
                      Color(0xFF004D40), // Teal 900
                    ],
                  ),
                ),
              ),

              // Animated background patterns - adjusted for different screen sizes
              ..._buildAnimatedPatterns(constraints),

              // Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? constraints.maxWidth * 0.1 : 24,
                      ),
                      child: Column(
                        children: [
                          // App logo/icon - responsive size
                          Container(
                            height: isTablet ? 160 : 120,
                            width: isTablet ? 160 : 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.face_retouching_natural,
                                size: isTablet ? 90 : 70,
                                color: const Color(0xFF00838F),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isTablet ? 40 : 30),
                          
                          // Title - responsive font size
                          Text(
                            "Face Attendance System",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 34 : 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Subtitle - responsive font size
                          Text(
                            "Made By Bhoomika",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isTablet ? 20 : 16,
                              letterSpacing: 1,
                            ),
                          ),
                          
                          SizedBox(height: isTablet ? 50 : 40),
                          
                          // Login Card
                          _buildLoginCard(constraints),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
  
  Widget _buildLoginCard(BoxConstraints constraints) {
    final isTablet = constraints.maxWidth > 600;
    final cardWidth = isTablet 
        ? constraints.maxWidth * 0.7 // 70% width for tablet
        : constraints.maxWidth;
        
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 40.0 : 30.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Text - responsive font size
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: isTablet ? 32 : 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan.shade800,
                ),
              ),
              
              SizedBox(height: isTablet ? 15 : 10),
              
              Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 16,
                  color: Colors.grey.shade600,
                ),
              ),
              
              SizedBox(height: isTablet ? 40 : 30),
              
              // Branch ID Field
              _buildBranchIdField(isTablet: isTablet),
              
              SizedBox(height: isTablet ? 25 : 20),
              
              // Password Field
              _buildPasswordField(isTablet: isTablet),
              
              SizedBox(height: isTablet ? 40 : 30),
              
              // Login Button - responsive height
              _buildLoginButton(isTablet: isTablet),
              
              SizedBox(height: isTablet ? 25 : 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedPatterns(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isTablet = width > 600;
    
    final topCircleSize = isTablet ? 300.0 : 200.0;
    final bottomCircleSize = isTablet ? 320.0 : 220.0;
    final middleCircleSize = isTablet ? 150.0 : 100.0;
    
    return [
      // Top left pattern
      Positioned(
        left: -topCircleSize / 4,
        top: -topCircleSize / 4,
        child: Opacity(
          opacity: 0.2,
          child: Container(
            width: topCircleSize,
            height: topCircleSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      
      // Bottom right pattern
      Positioned(
        right: -bottomCircleSize / 3,
        bottom: -bottomCircleSize / 3,
        child: Opacity(
          opacity: 0.15,
          child: Container(
            width: bottomCircleSize,
            height: bottomCircleSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      
      // Middle left pattern
      Positioned(
        left: -middleCircleSize / 3,
        top: height / 2,
        child: Opacity(
          opacity: 0.1,
          child: Container(
            width: middleCircleSize,
            height: middleCircleSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),

      // Additional pattern for tablet
      if (isTablet)
        Positioned(
          right: width * 0.3,
          top: height * 0.2,
          child: Opacity(
            opacity: 0.07,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildBranchIdField({required bool isTablet}) {
    return TextFormField(
      controller: _branchIdController,
      style: TextStyle(fontSize: isTablet ? 18 : 16),
      decoration: InputDecoration(
        labelText: 'Branch ID',
        hintText: 'Enter your branch ID',
        prefixIcon: Icon(
          Icons.business, 
          color: Colors.cyan.shade800,
          size: isTablet ? 28 : 24,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 20 : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade800, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        floatingLabelStyle: TextStyle(
          color: Colors.cyan.shade800,
          fontSize: isTablet ? 18 : 16,
        ),
        labelStyle: TextStyle(fontSize: isTablet ? 18 : 16),
        hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your branch ID';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({required bool isTablet}) {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: TextStyle(fontSize: isTablet ? 18 : 16),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: Icon(
          Icons.lock_outline, 
          color: Colors.cyan.shade800,
          size: isTablet ? 28 : 24,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 20 : 16,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.cyan.shade800,
            size: isTablet ? 28 : 24,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.cyan.shade800, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        floatingLabelStyle: TextStyle(
          color: Colors.cyan.shade800,
          fontSize: isTablet ? 18 : 16,
        ),
        labelStyle: TextStyle(fontSize: isTablet ? 18 : 16),
        hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton({required bool isTablet}) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan.shade800,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.cyan.shade300,
        padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
      child: _isLoading
          ? SizedBox(
              height: isTablet ? 30 : 25,
              width: isTablet ? 30 : 25,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : Text(
              'LOGIN',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
    );
  }

  @override
  void dispose() {
    _branchIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}