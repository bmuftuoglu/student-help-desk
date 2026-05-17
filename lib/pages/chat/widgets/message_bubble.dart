import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.message.isTyping) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.isTyping && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.message.isTyping && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isUser
        ? const Color(0xFF2563EB)
        : (isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB));

    final textColor =
        isUser ? Colors.white : (isDarkMode ? Colors.white : Colors.black87);

    final bool showTextBubble =
        widget.message.isTyping || widget.message.text.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.message.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                child: Image.file(
                  File(widget.message.imagePath!),
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 250,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, size: 40),
                            SizedBox(height: 4),
                            Text('Görsel yüklenemedi',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (showTextBubble)
              Container(
                margin: widget.message.hasImage
                    ? const EdgeInsets.only(top: 4)
                    : EdgeInsets.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isUser
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                ),
                child: widget.message.isTyping
                    ? _buildTypingDots(textColor)
                    : Text(
                        widget.message.text,
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDots(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _animatedDot(color, 0.0),
        const SizedBox(width: 4),
        _animatedDot(color, 0.33),
        const SizedBox(width: 4),
        _animatedDot(color, 0.66),
      ],
    );
  }

  Widget _animatedDot(Color color, double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value - delay) % 1.0;
        final bounce = math.sin(t * math.pi);
        return Transform.translate(
          offset: Offset(0, -4 * bounce),
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
