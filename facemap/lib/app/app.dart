import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/hive_service.dart';
import '../services/ml_service.dart';
import '../services/face_service.dart';
import '../providers/auth_provider.dart';

import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

class MyApp extends StatelessWidget {
  final HiveService hiveService;
  final MLService mlService;
  final FaceService faceService;

  const MyApp({
    super.key,
    required this.hiveService,
    required this.mlService,
    required this.faceService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: hiveService),
        Provider.value(value: mlService),
        Provider.value(value: faceService),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            // 👇 Dark Cyan Spinner Page
            return MaterialApp(
              home: Scaffold(
                backgroundColor: const Color(0xFF004D40), // Dark Cyan
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Checking session...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          }

          return MaterialApp(
            title: 'FaceNet Flutter',
            theme: ThemeData(
              primarySwatch: Colors.cyan,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            debugShowCheckedModeBanner: false,
            home: auth.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
