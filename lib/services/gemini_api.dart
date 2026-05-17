import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../secrets.dart';
import '../models/chat_message.dart';

class GeminiApi {
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // [history] zaten son kullanıcı mesajını içeriyor — ayrı parametre gerekmiyor.
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

    if (msg.imagePath != null && msg.imagePath!.isNotEmpty) {
      try {
        final file = File(msg.imagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          parts.add({
            'inline_data': {
              'mime_type': _detectMimeType(msg.imagePath!),
              'data': base64Encode(bytes),
            },
          });
        }
      } catch (_) {
        // Görsel okunamazsa yalnızca metin gönderilir.
      }
    }

    return parts;
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
