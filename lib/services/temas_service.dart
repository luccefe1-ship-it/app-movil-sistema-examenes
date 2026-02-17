import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tema.dart';

class TemasService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Tema> _temasPrincipales = [];
  Map<String, List<Tema>> _subtemasPorPadre = {};
  List<Tema> _todosTemas = [];
  bool _isLoading = false;

  List<Tema> get temasPrincipales => _temasPrincipales;
  Map<String, List<Tema>> get subtemasPorPadre => _subtemasPorPadre;
  List<Tema> get todosTemas => _todosTemas;
  bool get isLoading => _isLoading;

  Future<void> cargarTemas(String usuarioId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('temas')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      debugPrint('Total docs en temas: ${snapshot.docs.length}');

      _todosTemas = snapshot.docs.map((doc) {
        return Tema.fromFirestore(doc.data(), doc.id);
      }).toList();

      // Separar temas principales y subtemas
      _temasPrincipales = _todosTemas.where((t) => !t.esSubtema).toList();
      
      _subtemasPorPadre = {};
      for (var tema in _todosTemas.where((t) => t.esSubtema)) {
        if (!_subtemasPorPadre.containsKey(tema.temaPadreId)) {
          _subtemasPorPadre[tema.temaPadreId!] = [];
        }
        _subtemasPorPadre[tema.temaPadreId!]!.add(tema);
      }

      // Ordenar temas por número en nombre (Tema 1, Tema 2, etc.)
      _temasPrincipales.sort(_ordenarPorNombre);

      // Ordenar subtemas
      for (var key in _subtemasPorPadre.keys) {
        _subtemasPorPadre[key]!.sort(_ordenarPorNombre);
      }

      debugPrint('Temas principales: ${_temasPrincipales.length}');
      debugPrint('Subtemas grupos: ${_subtemasPorPadre.length}');

    } catch (e) {
      debugPrint('Error cargando temas: $e');
      _temasPrincipales = [];
      _subtemasPorPadre = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ordenamiento inteligente: extraer números del nombre
  int _ordenarPorNombre(Tema a, Tema b) {
    final numA = a.numeroExtraido;
    final numB = b.numeroExtraido;
    
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    return a.nombre.compareTo(b.nombre);
  }

  // Obtener subtemas de un tema padre
  List<Tema> getSubtemas(String temaPadreId) {
    return _subtemasPorPadre[temaPadreId] ?? [];
  }

  // Contar preguntas verificadas de un tema + sus subtemas
  int contarPreguntasVerificadas(String temaId) {
    int total = 0;
    
    // Preguntas del tema principal
    final tema = _todosTemas.where((t) => t.id == temaId).firstOrNull;
    if (tema != null) {
      total += tema.numPreguntasVerificadas;
    }
    
    // Preguntas de subtemas
    final subtemas = _subtemasPorPadre[temaId] ?? [];
    for (var sub in subtemas) {
      total += sub.numPreguntasVerificadas;
    }
    
    return total;
  }

  // Obtener preguntas verificadas de una lista de temas
  List<PreguntaEmbebida> getPreguntasVerificadas(List<String> temasIds) {
    List<PreguntaEmbebida> preguntas = [];
    
    for (var temaId in temasIds) {
      final tema = _todosTemas.where((t) => t.id == temaId).firstOrNull;
      if (tema != null) {
        preguntas.addAll(tema.preguntas.where((p) => p.verificada));
      }
    }
    
    return preguntas;
  }

  // Obtener todas las preguntas verificadas del usuario
  List<PreguntaEmbebida> getTodasPreguntasVerificadas() {
    List<PreguntaEmbebida> preguntas = [];
    for (var tema in _todosTemas) {
      preguntas.addAll(tema.preguntas.where((p) => p.verificada));
    }
    return preguntas;
  }
}