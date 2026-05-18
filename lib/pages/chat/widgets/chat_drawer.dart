import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final bgColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final initials = _getInitials(displayName);

    return Drawer(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kullanıcı profil alanı
            InkWell(
              onTap: widget.onProfileTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: widget.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty ? displayName : 'Kullanıcı',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Arama kutusu + Yeni sohbet butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Sohbetlerde ara',
                        hintStyle:
                            TextStyle(color: textColor.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: widget.isDarkMode
                            ? const Color.fromARGB(57, 35, 35, 35)
                            : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onNewChat,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isDarkMode
                            ? const Color.fromARGB(57, 35, 35, 35)
                            : Colors.grey[300],
                      ),
                      child:
                          Icon(Icons.add, color: textColor, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Sohbetler',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatService.sessionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Henüz sohbet yok',
                        style: TextStyle(color: textColor.withValues(alpha: 0.6)),
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
                      child: Text(
                        'Eşleşen sohbet yok',
                        style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final title =
                          doc['title'] as String? ?? 'Başlıksız sohbet';

                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(title, overflow: TextOverflow.ellipsis),
                        textColor: textColor,
                        iconColor: textColor,
                        onTap: () =>
                            widget.onSessionSelected(doc.id, title),
                        onLongPress: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Sohbeti Sil'),
                              content: Text(
                                '"$title" sohbetini silmek istediğine emin misin?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Vazgeç'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Sil',
                                      style:
                                          TextStyle(color: Colors.red)),
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
                                  SnackBar(
                                    content: Text('Sohbet silinemedi: $e'),
                                  ),
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

            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış yap'),
              textColor: textColor,
              iconColor: textColor,
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
