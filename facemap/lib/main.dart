import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'models/face_model.dart';
import 'services/hive_service.dart';
import 'services/ml_service.dart';
import 'services/face_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(FaceAdapter());
  await Hive.openBox<Face>('faces');

  // 2️⃣ Initialize your services
  final hiveService = HiveService();
  await hiveService.init();      // your HiveService setup

  final mlService = MLService();
  await mlService.loadModel();   // load the ML model

  // 3️⃣ Run the app, injecting services via Provider
  runApp(
    MultiProvider(
      providers: [
        Provider<HiveService>.value(value: hiveService),
        Provider<MLService>.value(value: mlService),
        Provider<FaceService>(
          create: (_) => FaceService(mlService: mlService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
