import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pregunta.dart';

class PreguntasService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener preguntas por lista de subtemas
  Future<List<Pregunta>> getPreguntasBySubtemas(List<String> subtemaIds) async {
    if (subtemaIds.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('preguntas')
          .where('subtemaId', whereIn: subtemaIds)
          .get();

      return snapshot.docs
          .map((doc) => Pregunta.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo preguntas: $e');
      return [];
    }
  }

  // Obtener N preguntas aleatorias de una lista
  List<Pregunta> getRandomPreguntas(List<Pregunta> todasPreguntas, int cantidad) {
    if (todasPreguntas.length <= cantidad) {
      return todasPreguntas;
    }

    final shuffled = List<Pregunta>.from(todasPreguntas)..shuffle();
    return shuffled.take(cantidad).toList();
  }

  // Obtener preguntas falladas del usuario (desde resultados previos)
  Future<List<String>> getPreguntasFalladasIds(String usuarioId) async {
    try {
      // Obtener el último test del usuario
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final resultado = snapshot.docs.first.data();
      final preguntas = resultado['preguntas'] as List<dynamic>? ?? [];

      // Filtrar solo las falladas
      final falladas = preguntas
          .where((p) => p['esAcierto'] == false && p['respuestaUsuario'] != null)
          .map((p) => p['preguntaId'] as String)
          .toList();

      return falladas;
    } catch (e) {
      debugPrint('Error obteniendo preguntas falladas: $e');
      return [];
    }
  }

  // Obtener preguntas específicas por IDs
  Future<List<Pregunta>> getPreguntasByIds(List<String> preguntaIds) async {
    if (preguntaIds.isEmpty) return [];

    try {
      // Firestore permite máximo 10 elementos en 'whereIn'
      // Si hay más, hacemos múltiples consultas
      List<Pregunta> todasPreguntas = [];

      for (int i = 0; i < preguntaIds.length; i += 10) {
        final batch = preguntaIds.skip(i).take(10).toList();
        
        final snapshot = await _firestore
            .collection('preguntas')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final preguntas = snapshot.docs
            .map((doc) => Pregunta.fromFirestore(doc.data(), doc.id))
            .toList();

        todasPreguntas.addAll(preguntas);
      }

      return todasPreguntas;
    } catch (e) {
      debugPrint('Error obteniendo preguntas por IDs: $e');
      return [];
    }
  }
}