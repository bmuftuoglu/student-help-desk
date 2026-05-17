import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';

class ChatFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturum açmamış.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _sessionsCol =>
      _userDoc.collection('sessions');

  CollectionReference<Map<String, dynamic>> _messagesCol(String sessionId) =>
      _sessionsCol.doc(sessionId).collection('messages');

  CollectionReference<Map<String, dynamic>> get _questionHistoryCol =>
      _userDoc.collection('questionHistory');

  Future<String> createSession({required String title}) async {
    final docRef = _sessionsCol.doc();
    await docRef.set({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUserPrompt': null,
      'lastAiResponse': null,
    });
    return docRef.id;
  }

  // Sadece gerçek session'ları döner — placeholder yok çünkü artık oluşturulmuyor.
  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream() {
    return _sessionsCol.orderBy('updatedAt', descending: true).snapshots();
  }

  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    final snap = await _messagesCol(sessionId).orderBy('createdAt').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      final isUser = (data['role'] == 'user');
      final content = data['content'] as String? ?? '';
      final ts = data['createdAt'] as Timestamp?;
      final imagePath = data['imagePath'] as String?;
      return ChatMessage(
        text: content,
        isUser: isUser,
        timestamp: ts?.toDate() ?? DateTime.now(),
        imagePath: imagePath,
      );
    }).toList();
  }

  Future<void> saveUserMessage({
    required String sessionId,
    required ChatMessage message,
  }) async {
    await _messagesCol(sessionId).add({
      'role': 'user',
      'content': message.text,
      'imagePath': message.imagePath,
      'createdAt': Timestamp.fromDate(message.timestamp),
    });

    // Sadece metin varsa questionHistory'ye kaydet — boş prompt oluşmasın.
    if (message.text.isNotEmpty) {
      await _questionHistoryCol.add({
        'prompt': message.text,
        'sessionId': sessionId,
        'createdAt': Timestamp.fromDate(message.timestamp),
      });
    }
  }

  Future<void> saveAssistantMessage({
    required String sessionId,
    required ChatMessage message,
  }) async {
    await _messagesCol(sessionId).add({
      'role': 'assistant',
      'content': message.text,
      'imagePath': message.imagePath,
      'createdAt': Timestamp.fromDate(message.timestamp),
    });
  }

  Future<void> updateSessionSummary({
    required String sessionId,
    required String lastUserPrompt,
    required String lastAiResponse,
    String? titleOverride,
  }) async {
    final updateData = <String, dynamic>{
      'lastUserPrompt': lastUserPrompt,
      'lastAiResponse': lastAiResponse,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (titleOverride != null && titleOverride.isNotEmpty) {
      updateData['title'] = titleOverride;
    }
    await _sessionsCol.doc(sessionId).update(updateData);
  }

  // WriteBatch ile N+1 Firestore isteği yerine tek commit'te siler.
  Future<void> deleteSession(String sessionId) async {
    final sessionRef = _sessionsCol.doc(sessionId);
    final messagesSnap = await sessionRef.collection('messages').get();

    final batch = _firestore.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(sessionRef);
    await batch.commit();
  }
}
