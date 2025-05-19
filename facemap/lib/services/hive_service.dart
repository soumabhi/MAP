import 'package:hive/hive.dart';
import '../models/face_model.dart';

class HiveService {
  late Box<Face> _faceBox;

  Future<void> init() async {
    _faceBox = await Hive.openBox<Face>('faces');
  }

  Future<void> registerFace(Face face) async {
    await _faceBox.add(face);
  }

  Future<List<Face>> getFaces() async {
  final box = await Hive.openBox<Face>('faces'); // always fresh
  return box.values.toList();
}


  Future<void> clearFaces() async {
    await _faceBox.clear();
  }
}