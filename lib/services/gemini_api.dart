import 'dart:convert';

import 'package:http/http.dart' as http;

import '../secrets.dart';
import '../models/chat_message.dart';

class GeminiApi {
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const String _systemInstruction =
      '''Sen bir ortaokul öğrencisi yardım masası yapay zeka asistanısın.

KONU SINIRLAMASI:
Yalnızca ortaokul müfredatıyla ilgili konularda yardım et: Matematik, Fen Bilimleri, Türkçe, İngilizce, Sosyal Bilgiler, Tarih, Coğrafya, Din Kültürü ve Ahlak Bilgisi, İnkılap Tarihi, Görsel Sanatlar, Müzik gibi dersler.
Ders dışı konularda (günlük sohbet, oyun, eğlence, politika, vb.) kibarca yanıt vermeyi reddet ve öğrenciyi ders konularına yönlendir. Reddettiğinde kısa ve nazik bir cümle söyle, uzun açıklamaya gerek yok.

PEDAGOJİK YAKLAŞIM:
Soruları doğrudan çözme veya cevabı verme. Öğrencinin kendi başına düşünmesine ve çözmesine rehberlik et:
- Problemi daha küçük adımlara böl ve hangi adımdan başlayacağını sor.
- İpuçları ve yönlendirici sorular sor ("Bu formülü hatırlıyor musun?", "Burada ne fark ediyorsun?").
- Öğrenci yanlış giderse nerede hata yaptığını söyle ama doğrusunu verme, tekrar denemesini iste.
- Öğrenci doğru cevabı bulduktan sonra tebrik et ve neden doğru olduğunu birlikte açıkla.
- Görsel veya dosya gönderildiyse içeriği analiz et ve yukarıdaki yaklaşımla yönlendir.

DİL: Türkçe mesajlara Türkçe, İngilizce mesajlara İngilizce yanıt ver.''';

  Future<List<Map<String, dynamic>>> _buildContents(
    List<ChatMessage> history,
  ) async {
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final parts = await _buildPartsFromMessage(msg);
      if (parts.isEmpty) continue;
      contents.add({'role': msg.isUser ? 'user' : 'model', 'parts': parts});
    }
    return contents;
  }

  Stream<String> generateReplyStream({
    required List<ChatMessage> history,
  }) async* {
    final contents = await _buildContents(history);
    if (contents.isEmpty) {
      throw Exception('Gemini\'ye gönderilecek içerik yok.');
    }

    final uri = Uri.parse(
      '$_endpoint/$_model:streamGenerateContent?alt=sse',
    );

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['x-goog-api-key'] = geminiApiKey
        ..body = jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _systemInstruction},
            ],
          },
          'contents': contents,
        });

      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.',
        ),
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception(
          'Gemini hatası: ${streamedResponse.statusCode} - $body',
        );
      }

      final lineBuffer = StringBuffer();
      await for (final bytes in streamedResponse.stream) {
        lineBuffer.write(utf8.decode(bytes));
        final raw = lineBuffer.toString();
        final lines = raw.split('\n');
        lineBuffer
          ..clear()
          ..write(lines.last);

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('data: ')) continue;
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final candidates = data['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) continue;
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts == null || parts.isEmpty) continue;
            final chunk = parts[0]['text'] as String?;
            if (chunk != null && chunk.isNotEmpty) yield chunk;
          } catch (_) {
            // Hatalı chunk'ları atla
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> _buildPartsFromMessage(
    ChatMessage msg,
  ) async {
    final parts = <Map<String, dynamic>>[];

    final text = msg.text.trim();
    if (text.isNotEmpty) {
      parts.add({'text': text});
    }

    if (msg.hasFile && msg.fileUrl != null) {
      final mime = msg.mimeType ?? '';
      final isGeminiSupported =
          mime.startsWith('image/') || mime == 'application/pdf';

      if (isGeminiSupported) {
        try {
          final response = await http
              .get(Uri.parse(msg.fileUrl!))
              .timeout(const Duration(seconds: 30));
          if (response.statusCode == 200) {
            parts.add({
              'inline_data': {
                'mime_type': mime.isNotEmpty ? mime : 'application/octet-stream',
                'data': base64Encode(response.bodyBytes),
              },
            });
          }
        } catch (_) {
          parts.add({
            'text': '[Dosya yüklenemedi: ${msg.fileName ?? 'dosya'}]',
          });
        }
      } else {
        parts.add({
          'text': '[Kullanıcı bir dosya paylaştı: ${msg.fileName ?? 'dosya'} — '
              'bu format Gemini tarafından analiz edilemiyor]',
        });
      }
    }

    return parts;
  }
}
