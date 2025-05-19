// models/face_model.dart
import 'package:hive/hive.dart';

part 'face_model.g.dart';

@HiveType(typeId: 0)
class Face {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String employeeId;

  @HiveField(2)
  final List<double> embedding;

  Face({
    required this.id,
    required this.employeeId,
    required this.embedding,
  });
}
