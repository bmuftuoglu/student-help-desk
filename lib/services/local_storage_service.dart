import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  Future<Directory> _getSessionDirectory(String sessionId) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory(
      '${documentsDir.path}/student_help_desk_chat/$sessionId',
    );
    if (!sessionDir.existsSync()) {
      sessionDir.createSync(recursive: true);
    }
    return sessionDir;
  }

  Future<String> saveImageToSession({
    required String imagePath,
    required String sessionId,
  }) async {
    final sourceFile = File(imagePath);
    if (!sourceFile.existsSync()) {
      throw Exception('Kaynak dosya bulunamadı: $imagePath');
    }
    final sessionDir = await _getSessionDirectory(sessionId);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final destinationPath = '${sessionDir.path}/$fileName';
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  Future<void> deleteSessionFolder(String sessionId) async {
    try {
      final sessionDir = await _getSessionDirectory(sessionId);
      if (sessionDir.existsSync()) {
        sessionDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Silme başarısız olsa da devam et.
    }
  }

  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  Future<bool> imageExists(String imagePath) async {
    return File(imagePath).existsSync();
  }
}
