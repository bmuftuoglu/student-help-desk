import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants/app_constants.dart';
import '../../../services/chat_firestore_service.dart';

class ChatDrawer extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onNewChat;
  final VoidCallback onLogout;
  final VoidCallback onProfileTap;
  final void Function(String sessionId, String title) onSessionSelected;
  final void Function(String sessionId) onSessionDeleted;
  final ChatFirestoreService chatService;

  const ChatDrawer({
    super.key,
    required this.isDarkMode,
    required this.onNewChat,
    required this.onLogout,
    required this.onProfileTap,
    required this.onSessionSelected,
    required this.onSessionDeleted,
    required this.chatService,
  });

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  ChatFirestoreService get _chatService => widget.chatService;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isDark => widget.isDarkMode;
  Color get _bg => _isDark ? AppConstants.kDarkSurface : AppConstants.kSurface;
  Color get _text => _isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary;
  Color get _subText => _isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary;
  Color get _border => _isDark ? AppConstants.kDarkBorder : AppConstants.kBorder;
  Color get _inputFill => _isDark ? AppConstants.kDarkBackground : AppConstants.kInputFill;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final initials = _getInitials(displayName);

    return Drawer(
      backgroundColor: _bg,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profil bölümü
            InkWell(
              onTap: widget.onProfileTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4361EE), Color(0xFF738BFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty ? displayName : 'Kullanıcı',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: _subText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 16, color: _subText),
                  ],
                ),
              ),
            ),

            Divider(color: _border, height: 1),
            const SizedBox(height: 12),

            // Arama + Yeni Sohbet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: _text),
                        decoration: InputDecoration(
                          hintText: 'Sohbetlerde ara',
                          hintStyle: TextStyle(fontSize: 13, color: _subText),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: _subText),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onNewChat,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppConstants.kPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'SOHBETLER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: _subText,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Sohbet listesi
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatService.sessionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.kPrimary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 36, color: _subText),
                          const SizedBox(height: 8),
                          Text('Henüz sohbet yok',
                              style: TextStyle(fontSize: 13, color: _subText)),
                        ],
                      ),
                    );
                  }

                  final allDocs = snapshot.data!.docs;
                  final docs = _searchQuery.isEmpty
                      ? allDocs
                      : allDocs.where((doc) {
                          final title =
                              (doc['title'] as String? ?? '').toLowerCase();
                          return title.contains(_searchQuery);
                        }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text('Eşleşen sohbet yok',
                          style: TextStyle(fontSize: 13, color: _subText)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final title = doc['title'] as String? ?? 'Başlıksız sohbet';

                      return _SessionTile(
                        title: title,
                        isDark: _isDark,
                        onTap: () => widget.onSessionSelected(doc.id, title),
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor:
                                  _isDark ? AppConstants.kDarkSurface : AppConstants.kSurface,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Sohbeti Sil',
                                  style: TextStyle(color: _text, fontWeight: FontWeight.w600)),
                              content: Text(
                                '"$title" sohbetini silmek istediğine emin misin?',
                                style: TextStyle(fontSize: 14, color: _subText),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('Vazgeç', style: TextStyle(color: _subText)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sil',
                                      style: TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await _chatService.deleteSession(doc.id);
                              widget.onSessionDeleted(doc.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sohbet silinemedi: $e')),
                                );
                              }
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),

            Divider(color: _border, height: 1),

            // Çıkış
            InkWell(
              onTap: widget.onLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: const Color(0xFFEF4444)),
                    const SizedBox(width: 10),
                    const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String title;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.title,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
