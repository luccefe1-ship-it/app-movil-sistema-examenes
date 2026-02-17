import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pregunta.dart';
import '../models/tema.dart';
import '../models/subtema.dart';

class PreguntasService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener preguntas por lista de subtemas
  Future<List<Pregunta>> getPreguntasBySubtemas(List<String> subtemaIds) async {
    if (subtemaIds.isEmpty) return [];

    try {
      // Firestore permite máximo 30 elementos en 'whereIn'
      // Si hay más, hacemos múltiples consultas
      List<Pregunta> todasPreguntas = [];

      for (int i = 0; i < subtemaIds.length; i += 30) {
        final batch = subtemaIds.skip(i).take(30).toList();

        final snapshot = await _firestore
            .collection('preguntas')
            .where('subtemaId', whereIn: batch)
            .get();

        todasPreguntas.addAll(
          snapshot.docs
              .map((doc) => Pregunta.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
      }

      return todasPreguntas;
    } catch (e) {
      debugPrint('Error obteniendo preguntas: $e');
      return [];
    }
  }

  /// Asigna el nombre del tema padre a cada pregunta.
  ///
  /// [preguntas] - Lista de preguntas a enriquecer
  /// [subtemas] - Lista de subtemas (contienen temaId)
  /// [temas] - Lista de temas (contienen nombre)
  ///
  /// Devuelve una nueva lista con temaNombre asignado.
  List<Pregunta> asignarTemaNombre({
    required List<Pregunta> preguntas,
    required List<Subtema> subtemas,
    required List<Tema> temas,
  }) {
    // Crear mapa subtemaId -> temaId
    final Map<String, String> subtemaToTema = {};
    for (final subtema in subtemas) {
      subtemaToTema[subtema.id] = subtema.temaId;
    }

    // Crear mapa temaId -> nombre
    final Map<String, String> temaIdToNombre = {};
    for (final tema in temas) {
      temaIdToNombre[tema.id] = tema.nombre;
    }

    // Asignar temaNombre a cada pregunta
    return preguntas.map((pregunta) {
      final temaId = subtemaToTema[pregunta.subtemaId];
      final temaNombre = temaId != null ? temaIdToNombre[temaId] : null;
      return pregunta.conTemaNombre(temaNombre ?? 'Sin tema');
    }).toList();
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
