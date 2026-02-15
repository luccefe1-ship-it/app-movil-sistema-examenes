import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  AuthService() {
    // Escuchar cambios en el estado de autenticación
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Obtener usuario actual
  User? get currentUser => _user;

  // Verificar si está autenticado
  bool get isAuthenticated => _user != null;

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login con email y contraseña
  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error en login: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error inesperado en login: $e');
      return false;
    }
  }

  // Registrar nuevo usuario
  Future<bool> register(String email, String password, String nombre) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Actualizar nombre de usuario
      await userCredential.user?.updateDisplayName(nombre);
      
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error en registro: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error inesperado en registro: $e');
      return false;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error en logout: $e');
    }
  }

  // Obtener UID del usuario actual
  String? get userId => _user?.uid;

  // Obtener email del usuario actual
  String? get userEmail => _user?.email;

  // Obtener nombre del usuario actual
  String? get userName => _user?.displayName;
}