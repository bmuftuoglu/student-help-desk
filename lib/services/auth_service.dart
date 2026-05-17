import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  // Yeni kullanıcı için Firestore yapısını oluşturur.
  // Placeholder session OLUŞTURMAZ — çünkü drawer'da "Placeholder session" görünmesine yol açıyor.
  Future<void> _createUserStructure(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final existing = await userRef.get();
    if (existing.exists) return;

    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserCredential> registerWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName('$firstName $lastName');
      await userCredential.user?.reload();
      final user = _firebaseAuth.currentUser;
      if (user != null) await _createUserStructure(user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) await _createUserStructure(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _firebaseAuth.signInWithCredential(credential);
      if (cred.user != null) await _createUserStructure(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> reauthenticate({required String password}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('Kullanıcı bulunamadı.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updateProfileName({
    required String firstName,
    required String lastName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Kullanıcı bulunamadı.');
    final displayName = '$firstName $lastName'.trim();
    await user.updateDisplayName(displayName);
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': displayName,
    });
  }

  Future<void> updateUserEmail({required String newEmail}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Kullanıcı bulunamadı.');
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updateUserPassword({required String newPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Kullanıcı bulunamadı.');
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  AuthException _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthException('Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.');
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException('Mevcut şifre yanlış.');
      case 'email-already-in-use':
        return const AuthException('Bu e-posta adresi zaten kullanılıyor.');
      case 'invalid-email':
        return const AuthException('Geçersiz e-posta adresi.');
      case 'weak-password':
        return const AuthException('Şifre çok zayıf. En az 6 karakter kullanın.');
      case 'user-disabled':
        return const AuthException('Bu kullanıcı devre dışı bırakılmıştır.');
      case 'too-many-requests':
        return const AuthException('Çok fazla başarısız girişim. Lütfen daha sonra tekrar deneyin.');
      case 'operation-not-allowed':
        return const AuthException('Bu işlem şu anda kullanılamıyor.');
      case 'requires-recent-login':
        return const AuthException('Bu işlem için mevcut şifrenizi girmeniz gerekiyor.');
      default:
        return AuthException('Bir hata oluştu: ${e.message}');
    }
  }
}
