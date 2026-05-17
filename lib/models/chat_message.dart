class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime timestamp;
  final String? imagePath;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.imagePath,
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
