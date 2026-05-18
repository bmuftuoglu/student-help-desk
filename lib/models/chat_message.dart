class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileName;
  final String? mimeType;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.fileUrl,
    this.fileName,
    this.mimeType,
  });

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get hasImage => hasFile && (mimeType?.startsWith('image/') ?? false);
}
