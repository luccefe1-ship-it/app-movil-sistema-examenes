import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tema.dart';
import '../models/subtema.dart';

class TemasService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Tema> _temas = [];
  Map<String, List<Subtema>> _subtemasCache = {};
  bool _isLoading = false;

  List<Tema> get temas => _temas;
  bool get isLoading => _isLoading;

  // Obtener todos los temas
  Future<void> getTemas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('temas')
          .orderBy('orden')
          .get();

      _temas = snapshot.docs
          .map((doc) => Tema.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo temas: $e');
      _temas = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Obtener subtemas de un tema
  Future<List<Subtema>> getSubtemas(String temaId) async {
    // Verificar si ya están en caché
    if (_subtemasCache.containsKey(temaId)) {
      return _subtemasCache[temaId]!;
    }

    try {
      final snapshot = await _firestore
          .collection('subtemas')
          .where('temaId', isEqualTo: temaId)
          .orderBy('orden')
          .get();

      final subtemas = snapshot.docs
          .map((doc) => Subtema.fromFirestore(doc.data(), doc.id))
          .toList();

      // Guardar en caché
      _subtemasCache[temaId] = subtemas;
      
      return subtemas;
    } catch (e) {
      debugPrint('Error obteniendo subtemas: $e');
      return [];
    }
  }

  // Limpiar caché de subtemas
  void clearSubtemasCache() {
    _subtemasCache.clear();
    notifyListeners();
  }

  // Stream de temas en tiempo real (opcional)
  Stream<List<Tema>> temasStream() {
    return _firestore
        .collection('temas')
        .orderBy('orden')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tema.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}