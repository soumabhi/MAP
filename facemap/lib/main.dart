// 

import 'package:flutter/material.dart';
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

  // 2️⃣ Initialize services
  final hiveService = HiveService();
  await hiveService.init(); // custom logic for face storage if any

  final mlService = MLService();
  await mlService.loadModel(); // load tflite model

  final faceService = FaceService(mlService: mlService);

  // 3️⃣ Run app with services passed into MyApp
  runApp(
    MyApp(
      hiveService: hiveService,
      mlService: mlService,
      faceService: faceService,
    ),
  );
}
