import 'dart:async';
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
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final S3StorageService _s3Service = S3StorageService();
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
    _messageController.clear();

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

      final reply = await _geminiApi.generateReply(
        history: _messages.where((m) => !m.isTyping).toList(),
      );

      if (!mounted) return;

      final aiMessage = ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        final index = _messages.indexOf(typingMessage);
        if (index != -1) {
          _messages[index] = aiMessage;
        } else {
          _messages.add(aiMessage);
        }
      });

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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        toolbarHeight: AppConstants.appBarHeight,
        title: const Text(
          'AI Study Assistant',
          style: TextStyle(fontSize: AppConstants.appBarFontSize),
        ),
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Sohbet geçmişi',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
            tooltip: 'Tema değiştir',
          ),
        ],
      ),
      drawer: ChatDrawer(
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
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.red[700],
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'İnternet bağlantısı yok',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const SizedBox.shrink()
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
