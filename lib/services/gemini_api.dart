import 'dart:convert';

import 'package:http/http.dart' as http;

import '../secrets.dart';
import '../models/chat_message.dart';

class GeminiApi {
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String> generateReply({
    required List<ChatMessage> history,
  }) async {
    final List<Map<String, dynamic>> contents = [];

    for (final msg in history) {
      final parts = await _buildPartsFromMessage(msg);
      if (parts.isEmpty) continue;
      contents.add({'role': msg.isUser ? 'user' : 'model', 'parts': parts});
    }

    if (contents.isEmpty) {
      throw Exception('Gemini\'ye gönderilecek içerik yok.');
    }

    final uri = Uri.parse('$_endpoint/$_model:generateContent');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': geminiApiKey,
          },
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {
                  'text': 'Sen bir öğrenci yardım masası yapay zeka asistanısın. '
                      'Öğrencilerin ders çalışmasına, ödevlerine ve akademik '
                      'sorularına yardımcı olursun. Türkçe sorulara Türkçe, '
                      'İngilizce sorulara İngilizce yanıt ver. Yanıtların açık, '
                      'anlaşılır ve eğitici olsun.',
                }
              ],
            },
            'contents': contents,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception(
            'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.',
          ),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini hatası: ${response.statusCode} - ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    try {
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } catch (e) {
      throw Exception('Beklenmeyen yanıt formatı: $e\nBody: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> _buildPartsFromMessage(
    ChatMessage msg,
  ) async {
    final List<Map<String, dynamic>> parts = [];

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
          // İndirilemezse metin bağlamı gönderilir.
          parts.add({
            'text': '[Dosya yüklenemedi: ${msg.fileName ?? 'dosya'}]',
          });
        }
      } else {
        // Word, Excel, PowerPoint vb. Gemini tarafından desteklenmiyor.
        parts.add({
          'text':
              '[Kullanıcı bir dosya paylaştı: ${msg.fileName ?? 'dosya'} — '
              'bu format Gemini tarafından analiz edilemiyor]',
        });
      }
    }

    return parts;
  }
}
