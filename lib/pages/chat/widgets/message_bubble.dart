import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _FullscreenImageViewer(url: widget.message.fileUrl!),
        ),
      ),
    );
  }

  void _showImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Cihaza İndir'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadImage(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response =
          await http.get(Uri.parse(widget.message.fileUrl!)).timeout(
                const Duration(seconds: 30),
              );
      await Gal.putImageBytes(response.bodyBytes);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf galeriye kaydedildi.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('İndirme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isUser
        ? const Color(0xFF4361EE)
        : (isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    final textColor =
        isUser ? Colors.white : (isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B));

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
              GestureDetector(
                onTap: () => _openFullscreen(context),
                onLongPress: () => _showImageOptions(context),
                child: ClipRRect(
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
                  child: CachedNetworkImage(
                    imageUrl: widget.message.fileUrl!,
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 250,
                      height: 250,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
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
                    ),
                  ),
                ),
              )
            else if (widget.message.hasFile)
              _buildFileCard(isDarkMode),
            if (showTextBubble)
              Container(
                margin: widget.message.hasFile
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

  Widget _buildFileCard(bool isDarkMode) {
    final mimeType = widget.message.mimeType ?? '';
    final fileName = widget.message.fileName ?? 'Dosya';
    final fileUrl = widget.message.fileUrl!;

    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _fileIcon(mimeType),
            color: _fileIconColor(mimeType),
            size: 32,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _openFile(fileUrl),
                  child: Text(
                    'Aç',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _fileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('msword')) {
      return Icons.description;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }
    return Icons.insert_drive_file;
  }

  Color _fileIconColor(String mimeType) {
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('msword')) {
      return Colors.blue;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Colors.green;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Colors.orange;
    }
    return Colors.grey;
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

class _FullscreenImageViewer extends StatefulWidget {
  final String url;

  const _FullscreenImageViewer({required this.url});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  VoidCallback? _animTick;
  CurvedAnimation? _curved;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    if (_animTick != null) _animController.removeListener(_animTick!);
    _curved?.dispose();
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails _) {
    _animController.stop();
    if (_animTick != null) {
      _animController.removeListener(_animTick!);
      _animTick = null;
    }
    _curved?.dispose();
    _curved = null;
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final begin = _transformController.value.clone();
    _curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    final tween = Matrix4Tween(begin: begin, end: Matrix4.identity());
    _animTick = () => _transformController.value = tween.evaluate(_curved!);

    _animController.reset();
    _animController.addListener(_animTick!);
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.88),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          onInteractionStart: _onInteractionStart,
          onInteractionEnd: _onInteractionEnd,
          minScale: 0.5,
          maxScale: 6.0,
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 8),
                  Text('Görsel yüklenemedi',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
