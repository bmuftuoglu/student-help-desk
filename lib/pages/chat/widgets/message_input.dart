import 'dart:io';
import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onFileTap;
  final String? attachedFilePath;
  final String? attachedFileName;
  final String? attachedMimeType;
  final VoidCallback? onRemoveAttachment;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onCameraTap,
    this.onGalleryTap,
    this.onFileTap,
    this.attachedFilePath,
    this.attachedFileName,
    this.attachedMimeType,
    this.onRemoveAttachment,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _menuAnimation;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _menuAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _showMenu = false);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_showMenu) {
      _animController.reverse();
    } else {
      setState(() => _showMenu = true);
      _animController.forward(from: 0);
    }
  }

  void _closeMenu() {
    if (_showMenu) _animController.reverse();
  }

  bool get _hasAttachment =>
      widget.attachedFilePath != null && widget.attachedFilePath!.isNotEmpty;

  bool get _isImage => widget.attachedMimeType?.startsWith('image/') ?? false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppConstants.kDarkBackground : AppConstants.kSurface;
    final border = isDark ? AppConstants.kDarkBorder : AppConstants.kBorder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Input bar ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasAttachment) _buildAttachmentPreview(isDark),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // + butonu — döner animasyonlu
                  GestureDetector(
                    onTap: _toggleMenu,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _showMenu
                            ? AppConstants.kPrimary
                            : (isDark ? AppConstants.kDarkSurface : AppConstants.kInputFill),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showMenu ? AppConstants.kPrimary : border,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _showMenu ? 0.125 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: _showMenu
                              ? Colors.white
                              : (isDark
                                  ? AppConstants.kDarkTextSecondary
                                  : AppConstants.kTextSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      onTap: _closeMenu,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppConstants.kDarkTextPrimary
                            : AppConstants.kTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppConstants.kDarkTextSecondary
                              : AppConstants.kTextSecondary,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppConstants.kDarkSurface
                            : AppConstants.kInputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.defaultBorderRadius),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.defaultBorderRadius),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.defaultBorderRadius),
                          borderSide: const BorderSide(
                              color: AppConstants.kPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                            onPressed: widget.onSend,
                            icon: const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppConstants.kPrimary,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Kayan menü (alttan açılır) ---
        SizeTransition(
          sizeFactor: _menuAnimation,
          axisAlignment: -1,
          child: _showMenu ? _buildMenu(isDark, border) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMenu(bool isDark, Color border) {
    final bg = isDark ? AppConstants.kDarkBackground : AppConstants.kSurface;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: border),
          _menuItem(
            icon: Icons.camera_alt_outlined,
            label: 'Kamera',
            description: 'Fotoğraf veya video çek',
            isDark: isDark,
            onTap: () {
              _toggleMenu();
              widget.onCameraTap?.call();
            },
          ),
          Divider(height: 1, indent: 80, color: border),
          _menuItem(
            icon: Icons.photo_library_outlined,
            label: 'Galeri',
            description: 'Telefondan resim seç',
            isDark: isDark,
            onTap: () {
              _toggleMenu();
              widget.onGalleryTap?.call();
            },
          ),
          Divider(height: 1, indent: 80, color: border),
          _menuItem(
            icon: Icons.attach_file_rounded,
            label: 'Dosya',
            description: 'PDF, Word, Excel ve daha fazlası',
            isDark: isDark,
            onTap: () {
              _toggleMenu();
              widget.onFileTap?.call();
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required String description,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppConstants.kPrimaryLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppConstants.kPrimary, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppConstants.kDarkTextPrimary
                        : AppConstants.kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppConstants.kDarkTextSecondary
                        : AppConstants.kTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.kDarkSurface : AppConstants.kInputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppConstants.kDarkBorder : AppConstants.kBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.attachedFilePath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppConstants.kDarkBorder : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _fileIcon(widget.attachedMimeType),
                size: 28,
                color: _fileIconColor(widget.attachedMimeType),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.attachedFileName ?? '1 dosya eklendi',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppConstants.kDarkTextPrimary
                    : AppConstants.kTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onRemoveAttachment,
            icon: Icon(Icons.close_rounded,
                size: 18,
                color: isDark
                    ? AppConstants.kDarkTextSecondary
                    : AppConstants.kTextSecondary),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
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

  Color _fileIconColor(String? mimeType) {
    if (mimeType == null) return Colors.grey;
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
}
