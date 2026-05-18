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
    required String fileName,
  }) async {
    final objectName = '$uid/${DateTime.now().microsecondsSinceEpoch}_$fileName';
    await _minio.fPutObject(s3Bucket, objectName, localPath);
    return 'https://$s3Endpoint/$s3Bucket/$objectName';
  }

  Future<void> deleteFile(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    // /proje/{uid}/... → bucket'ı (ilk segment) atla
    final objectName = uri.pathSegments.skip(1).join('/');
    await _minio.removeObject(s3Bucket, objectName);
  }
}
