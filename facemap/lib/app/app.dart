// // app/app.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../screens/home_screen.dart';
// import '../services/face_service.dart';
// import '../services/hive_service.dart';
// import '../services/ml_service.dart';

// class MyApp extends StatelessWidget {
//   final HiveService hiveService;
//   final MLService mlService;
//   final FaceService faceService;

//   const MyApp({
//     required this.hiveService,
//     required this.mlService,
//     required this.faceService,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         Provider.value(value: hiveService),
//         Provider.value(value: mlService),
//         Provider.value(value: faceService),
//       ],
//       child: MaterialApp(
//         title: 'FaceNet Flutter',
//         theme: ThemeData(primarySwatch: Colors.blue),
//         home: HomeScreen(),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import '../screens/home_screen.dart';

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'FaceNet Flutter',
//       theme: ThemeData(
//         primarySwatch: Colors.cyan,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: const HomeScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

import 'package:flutter/material.dart';
// import '../screens/home_screen.dart';
import '../screens/login_screen.dart'; // <-- add this

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceNet Flutter',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(), // <-- start with login
      debugShowCheckedModeBanner: false,
    );
  }
}

