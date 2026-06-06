import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/chat_message.dart';
import '../../constants/app_constants.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/chat_drawer.dart';
import '../../services/gemini_api.dart';
import '../../services/chat_firestore_service.dart';
import '../../services/s3_storage_service.dart';
import '../profile/profile_page.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback onLogout;

  const ChatPage({
    super.key,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  final GeminiApi _geminiApi = GeminiApi();
  final S3StorageService _s3Service = S3StorageService();
  late final ChatFirestoreService _chatService;
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;
  bool _isOffline = false;
  String? _currentSessionId;
  String _currentSessionTitle = 'Yeni sohbet';

  String? _pendingFilePath;
  String? _pendingFileName;
  String? _pendingMimeType;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _chatService = ChatFirestoreService(s3Service: _s3Service);
    _initConnectivity();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestInitialPermissions(),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (!mounted || offline == _isOffline) return;
    setState(() => _isOffline = offline);
    if (!offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İnternet bağlantısı yeniden kuruldu.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _requestInitialPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('permissions_requested') ?? false) return;
    await prefs.setBool('permissions_requested', true);

    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('İzin Gerekli'),
        content: const Text(
          'Fotoğraf çekmek, galeriden görsel seçmek ve dosya eklemek için '
          'kamera ve depolama iznine ihtiyaç duyulmaktadır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Daha Sonra'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await [Permission.camera, Permission.photos, Permission.storage].request();
    }
  }

  Future<void> _createNewSession({bool clearMessages = true}) async {
    final sessionId = await _chatService.createSession(title: 'Yeni sohbet');
    if (!mounted) return;
    setState(() {
      _currentSessionId = sessionId;
      _currentSessionTitle = 'Yeni sohbet';
      if (clearMessages) _messages.clear();
    });
  }

  Future<void> _loadSession(String sessionId, String title) async {
    final msgs = await _chatService.loadMessages(sessionId);
    if (!mounted) return;
    setState(() {
      _currentSessionId = sessionId;
      _currentSessionTitle = title;
      _messages
        ..clear()
        ..addAll(msgs);
      _pendingFilePath = null;
      _pendingFileName = null;
      _pendingMimeType = null;
      _messageController.clear();
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final hasFile = _pendingFilePath != null && _pendingFilePath!.isNotEmpty;

    if ((!hasFile && text.isEmpty) || _isSending) return;

    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İnternet bağlantısı yok. Mesaj gönderilemedi.'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_currentSessionId == null) {
        await _createNewSession(clearMessages: false);
        if (!mounted) return;
      }
      final sessionId = _currentSessionId!;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      String? uploadedFileUrl;
      String? uploadedFileName;
      String? uploadedMimeType;

      if (hasFile) {
        uploadedFileName = _pendingFileName;
        uploadedMimeType = _pendingMimeType;
        uploadedFileUrl = await _s3Service.uploadFile(
          localPath: _pendingFilePath!,
          uid: uid,
          sessionId: sessionId,
          fileName: _pendingFileName!,
        );
      }

      final userMessage = ChatMessage(
        text: text,
        fileUrl: uploadedFileUrl,
        fileName: uploadedFileName,
        mimeType: uploadedMimeType,
        isUser: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(userMessage);
        _messageController.clear();
        _pendingFilePath = null;
        _pendingFileName = null;
        _pendingMimeType = null;
      });

      await _chatService.saveUserMessage(
        sessionId: sessionId,
        message: userMessage,
      );

      String? titleOverride;
      if (_currentSessionTitle == 'Yeni sohbet') {
        titleOverride = text.isNotEmpty
            ? (text.length > 30 ? '${text.substring(0, 30)}...' : text)
            : (uploadedFileName ?? 'Dosya');
      }

      final typingMessage = ChatMessage(
        text: '',
        isUser: false,
        isTyping: true,
        timestamp: DateTime.now(),
      );
      setState(() => _messages.add(typingMessage));
      final streamingIndex = _messages.length - 1;

      final pendingBuffer = StringBuffer();
      var streamDone = false;
      var displayedText = '';
      final aiTimestamp = DateTime.now();
      final typewriterDone = Completer<void>();
      Timer? typewriterTimer;

      typewriterTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
        if (!mounted) {
          t.cancel();
          if (!typewriterDone.isCompleted) typewriterDone.complete();
          return;
        }
        final pending = pendingBuffer.toString();
        if (pending.isEmpty) {
          if (streamDone) {
            t.cancel();
            if (!typewriterDone.isCompleted) typewriterDone.complete();
          }
          return;
        }
        // Buffer büyükse hızlı tüket, küçükse yavaş typewriter hissi ver
        final take = (pending.length > 80 ? 8 : 3).clamp(1, pending.length);
        displayedText += pending.substring(0, take);
        pendingBuffer.clear();
        if (take < pending.length) pendingBuffer.write(pending.substring(take));
        setState(() {
          _messages[streamingIndex] = ChatMessage(
            text: displayedText,
            isUser: false,
            timestamp: aiTimestamp,
          );
        });
      });

      try {
        await for (final chunk in _geminiApi.generateReplyStream(
          history: _messages.where((m) => !m.isTyping).toList(),
        )) {
          if (!mounted) {
            typewriterTimer.cancel();
            return;
          }
          pendingBuffer.write(chunk);
        }
        streamDone = true;
        if (pendingBuffer.isEmpty && !typewriterDone.isCompleted) {
          typewriterTimer.cancel();
          typewriterDone.complete();
        }
        await typewriterDone.future;
      } catch (e) {
        typewriterTimer.cancel();
        rethrow;
      }

      if (!mounted) return;

      final reply = displayedText;
      if (reply.isEmpty) {
        setState(() {
          if (streamingIndex < _messages.length) {
            _messages.removeAt(streamingIndex);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yanıt güvenlik filtresi tarafından engellendi.'),
          ),
        );
        return;
      }

      try {
        final aiMessage = _messages[streamingIndex];
        await _chatService.saveAssistantMessage(
          sessionId: sessionId,
          message: aiMessage,
        );
        await _chatService.updateSessionSummary(
          sessionId: sessionId,
          lastUserPrompt: text,
          lastAiResponse: reply,
          titleOverride: titleOverride,
        );
        if (_currentSessionTitle == 'Yeni sohbet' && titleOverride != null) {
          if (!mounted) return;
          setState(() => _currentSessionTitle = titleOverride!);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yanıt kaydedilemedi.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.isTyping));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        title: 'Kamera izni gerekli',
        message: 'Kamera kullanmak için ayarlardan izin vermen gerekiyor.',
      );
      return false;
    }
    final result = await Permission.camera.request();
    if (result.isGranted) return true;
    if (result.isPermanentlyDenied) {
      await _showSettingsDialog(
        title: 'Kamera izni gerekli',
        message: 'Kamera kullanmak için ayarlardan izin vermen gerekiyor.',
      );
    }
    return false;
  }

  Future<bool> _ensureGalleryPermission() async {
    var status = await Permission.photos.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        title: 'Galeri izni gerekli',
        message:
            'Galeriden fotoğraf seçmek için ayarlardan izin vermen gerekiyor.',
      );
      return false;
    }
    final result = await Permission.photos.request();
    if (result.isGranted) return true;
    if (result.isPermanentlyDenied) {
      await _showSettingsDialog(
        title: 'Galeri izni gerekli',
        message:
            'Galeriden fotoğraf seçmek için ayarlardan izin vermen gerekiyor.',
      );
    }
    return false;
  }

  Future<void> _showSettingsDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Ayarları Aç'),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureCameraPermission()) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (File(picked.path).lengthSync() > 20 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Görsel 20MB\'dan büyük olamaz.')),
        );
        return;
      }
      final mime = lookupMimeType(picked.path) ?? 'image/jpeg';
      if (mounted) {
        setState(() {
          _pendingFilePath = picked.path;
          _pendingFileName = picked.name;
          _pendingMimeType = mime;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kamera hatası: $e')));
    }
  }

  Future<void> _pickFromGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureGalleryPermission()) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (File(picked.path).lengthSync() > 20 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Görsel 20MB\'dan büyük olamaz.')),
        );
        return;
      }
      final mime = lookupMimeType(picked.path) ?? 'image/jpeg';
      if (mounted) {
        setState(() {
          _pendingFilePath = picked.path;
          _pendingFileName = picked.name;
          _pendingMimeType = mime;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Galeri hatası: $e')));
    }
  }

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      if (File(file.path!).lengthSync() > 20 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Dosya 20MB\'dan büyük olamaz.')),
        );
        return;
      }
      final mime = lookupMimeType(file.path!) ?? 'application/octet-stream';
      if (mounted) {
        setState(() {
          _pendingFilePath = file.path;
          _pendingFileName = file.name;
          _pendingMimeType = mime;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Dosya seçme hatası: $e')));
    }
  }

  void _clearAttachment() {
    setState(() {
      _pendingFilePath = null;
      _pendingFileName = null;
      _pendingMimeType = null;
    });
  }

  Widget _buildEmptyState(bool isDark) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppConstants.kPrimaryLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.school_rounded, color: AppConstants.kPrimary, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              name.isNotEmpty ? 'Merhaba, $name!' : 'Merhaba!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Size nasıl yardımcı olabilirim?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDarkMode ? AppConstants.kDarkBackground : AppConstants.kBackground,
      appBar: AppBar(
        toolbarHeight: AppConstants.appBarHeight,
        title: const Text('AI Study Assistant'),
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode ? AppConstants.kDarkBackground : AppConstants.kSurface,
        foregroundColor: isDarkMode ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDarkMode ? AppConstants.kDarkBorder : AppConstants.kBorder,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Sohbet geçmişi',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: widget.onThemeToggle,
            tooltip: 'Tema değiştir',
          ),
        ],
      ),
      drawer: ChatDrawer(
        chatService: _chatService,
        isDarkMode: isDarkMode,
        onProfileTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        },
        onNewChat: () async {
          await _createNewSession(clearMessages: true);
          if (context.mounted) Navigator.pop(context);
        },
        onLogout: widget.onLogout,
        onSessionSelected: (sessionId, title) async {
          await _loadSession(sessionId, title);
          if (context.mounted) Navigator.pop(context);
        },
        onSessionDeleted: (sessionId) async {
          if (_currentSessionId == sessionId) {
            setState(() {
              _currentSessionId = null;
              _currentSessionTitle = 'Yeni sohbet';
              _messages.clear();
              _pendingFilePath = null;
              _pendingFileName = null;
              _pendingMimeType = null;
              _messageController.clear();
            });
          }
        },
        onSessionRenamed: (sessionId, newTitle) {
          if (_currentSessionId == sessionId) {
            setState(() => _currentSessionTitle = newTitle);
          }
        },
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 8),
                  Text(
                    'İnternet bağlantısı yok',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDarkMode)
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _messages[_messages.length - 1 - index];
                      return MessageBubble(message: message);
                    },
                  ),
          ),
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            onCameraTap: _pickFromCamera,
            onGalleryTap: _pickFromGallery,
            onFileTap: _pickFile,
            attachedFilePath: _pendingFilePath,
            attachedFileName: _pendingFileName,
            attachedMimeType: _pendingMimeType,
            onRemoveAttachment: _clearAttachment,
          ),
        ],
      ),
    );
  }
}
