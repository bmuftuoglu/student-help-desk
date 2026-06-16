import 'package:minio/minio.dart';
import 'package:minio/io.dart';

import '../secrets.dart';

class S3StorageService {
  late final Minio _minio;

  S3StorageService() {
    _minio = Minio(
      endPoint: s3Endpoint,
      accessKey: s3AccessKey,
      secretKey: s3SecretKey,
      region: s3Region,
      useSSL: true,
    );
  }

  Future<String> uploadFile({
    required String localPath,
    required String uid,
    required String sessionId,
    required String fileName,
  }) async {
    final objectName =
        '$uid/$sessionId/${DateTime.now().microsecondsSinceEpoch}_$fileName';
    try {
      await _minio.fPutObject(s3Bucket, objectName, localPath);
    } on MinioS3Error catch (e) {
      final code = e.error?.code ?? 'bilinmiyor';
      final msg = e.error?.message ?? '';
      throw Exception('Depolama S3 hatası [$code]: $msg');
    } on MinioError catch (e) {
      throw Exception('Depolama bağlantı hatası: ${e.message}');
    } catch (e) {
      throw Exception('Dosya yükleme hatası: $e');
    }
    return 'https://$s3Endpoint/$s3Bucket/$objectName';
  }

  Future<void> deleteSessionFiles(String uid, String sessionId) async {
    final prefix = '$uid/$sessionId/';
    await for (final chunk in _minio.listObjects(s3Bucket, prefix: prefix, recursive: true)) {
      for (final obj in chunk.objects) {
        if (obj.key != null) {
          await _minio.removeObject(s3Bucket, obj.key!);
        }
      }
    }
  }

  Future<void> deleteFile(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    // bucket'ı (ilk segment) atla
    final objectName = uri.pathSegments.skip(1).join('/');
    await _minio.removeObject(s3Bucket, objectName);
  }
}
