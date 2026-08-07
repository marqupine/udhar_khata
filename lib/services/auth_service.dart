import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirestoreService? _firestoreService;

  AuthService({FirebaseAuth? auth, FirestoreService? firestoreService})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService;

  // Stream of auth state changes (persisted session)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  String get currentUserId => _auth.currentUser?.uid ?? 'system';

  String get currentUserName {
    final user = _auth.currentUser;
    if (user == null) return 'System User';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.email != null && user.email!.contains('@')) {
      final prefix = user.email!.split('@')[0];
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return user.email ?? 'User';
  }

  String get currentUserEmail => _auth.currentUser?.email ?? '';

  // Sign In with Email & Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Sync user profile to Firestore
      if (cred.user != null && _firestoreService != null) {
        final appUser = AppUser(
          uid: cred.user!.uid,
          name: currentUserName,
          email: cred.user!.email ?? email.trim(),
          phoneNumber: cred.user!.phoneNumber ?? '',
          createdAt: DateTime.now(),
        );
        await _firestoreService.syncUserProfile(appUser);
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected authentication error occurred: ${e.toString()}');
    }
  }

  // Ensure current user is synced
  Future<void> ensureUserSynced() async {
    final user = _auth.currentUser;
    if (user != null && _firestoreService != null) {
      final appUser = AppUser(
        uid: user.uid,
        name: currentUserName,
        email: user.email ?? '',
        phoneNumber: user.phoneNumber ?? '',
        createdAt: DateTime.now(),
      );
      await _firestoreService.syncUserProfile(appUser);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      default:
        return e.message ?? 'Authentication failed. Code: ${e.code}';
    }
  }
}
