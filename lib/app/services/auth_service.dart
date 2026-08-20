import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/models/user_model.dart';
import 'auth_exceptions.dart';
import 'notification_service.dart';

class AuthService extends GetxService {
  final _firebase = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Rx<UserModel?> currentUser = Rx(null);

  bool get isLoggedIn => currentUser.value != null;

  @override
  void onInit() {
    super.onInit();
    // Mantém o estado de login entre sessões
    _firebase.authStateChanges().listen((user) {
      if (user != null) {
        currentUser.value = UserModel(
          id: user.uid,
          name: user.displayName ?? user.email?.split('@').first ?? 'Usuário',
          email: user.email ?? '',
          photoUrl: user.photoURL,
        );
        Future.delayed(const Duration(seconds: 2), () => NotificationService.init());
      } else {
        currentUser.value = null;
        NotificationService.dispose();
      }
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebase.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Verifica se é um tutor — bloqueia profissionais tentando logar aqui
      final doc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();
      if (doc.exists && doc.data()?['role'] != 'tutor') {
        await _firebase.signOut();
        throw const AuthException(
            'Esta conta é de um profissional. Use o app VetVem Pro.');
      }
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthExceptions.networkError;
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String name,
    String email,
    String password, {
    String? cpf,
    String? phone,
    Map<String, dynamic>? address,
    Map<String, dynamic>? pet,
  }) async {
    try {
      final credential = await _firebase.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      // Salva perfil do tutor no Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'tutor',
        'createdAt': FieldValue.serverTimestamp(),
        if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null) 'addresses': [address],
        if (pet != null) 'pets': [pet],
      });
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthExceptions.networkError;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw AuthExceptions.googleCancelled;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebase.signInWithCredential(credential);
      final user = userCredential.user!;

      // Verifica se é um profissional tentando logar no app cliente
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['role'] == 'professional') {
        await _firebase.signOut();
        await GoogleSignIn().signOut();
        throw const AuthException(
            'Esta conta é de um profissional. Use o app VetVem Pro.');
      }

      // Cria documento no Firestore se for primeiro login
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'role': 'tutor',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthExceptions.googleCancelled;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebase.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw const AuthException('Nenhuma conta encontrada com este e-mail.');
      }
      throw const AuthException('Erro ao enviar e-mail. Tente novamente.');
    }
  }

  Future<void> signOut() async {
    await _firebase.signOut();
  }

  AuthException _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthExceptions.invalidCredentials;
      case 'email-already-in-use':
        return AuthExceptions.emailAlreadyInUse;
      case 'weak-password':
        return const AuthException('A senha deve ter pelo menos 6 caracteres.');
      case 'invalid-email':
        return const AuthException('E-mail inválido.');
      case 'network-request-failed':
        return AuthExceptions.networkError;
      case 'too-many-requests':
        return const AuthException('Muitas tentativas. Aguarde alguns minutos.');
      default:
        return AuthException('Erro: ${e.message ?? e.code}');
    }
  }
}
