import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tema.dart';

class TestService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _ultimoNombreTest;
  List<String>? _ultimosTemasIds;
  int? _ultimoNumPreguntas;

  // ─────────────────────────────────────────────────────────────
  // CONFIGURACIÓN
  // ─────────────────────────────────────────────────────────────

  Future<void> guardarConfiguracion(
      String nombreTest, List<String> temasIds, int numPreguntas) async {
    _ultimoNombreTest = nombreTest;
    _ultimosTemasIds = temasIds;
    _ultimoNumPreguntas = numPreguntas;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ultima_config',
        jsonEncode({
          'nombreTest': nombreTest,
          'temasIds': temasIds,
          'numPreguntas': numPreguntas,
        }),
      );
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> cargarUltimaConfiguracion() async {
    if (_ultimoNombreTest != null) {
      return {
        'nombreTest': _ultimoNombreTest,
        'temasIds': _ultimosTemasIds,
        'numPreguntas': _ultimoNumPreguntas,
      };
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('ultima_config');
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _ultimoNombreTest = data['nombreTest'];
        _ultimosTemasIds = List<String>.from(data['temasIds'] ?? []);
        _ultimoNumPreguntas = data['numPreguntas'];
        return data;
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // PREGUNTAS
  // ─────────────────────────────────────────────────────────────

  List<PreguntaEmbebida> getRandomPreguntas(
      List<PreguntaEmbebida> todas, int cantidad) {
    if (todas.length <= cantidad) return List.from(todas);
    final shuffled = List<PreguntaEmbebida>.from(todas)..shuffle();
    return shuffled.take(cantidad).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // PREGUNTAS FALLADAS
  // ─────────────────────────────────────────────────────────────

  Future<int> contarPreguntasFalladas(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final detalle = List<Map<String, dynamic>>.from(
          snapshot.docs.first.data()['detalleRespuestas'] ?? []);

      return detalle
          .where((d) => d['esAcierto'] == false && d['respuestaUsuario'] != null)
          .length;
    } catch (e) {
      debugPrint('Error contando falladas: $e');
      return 0;
    }
  }

  Future<List<PreguntaEmbebida>> getPreguntasFalladas(
      String usuarioId, List<Tema> todosTemas) async {
    try {
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final detalle = List<Map<String, dynamic>>.from(
          snapshot.docs.first.data()['detalleRespuestas'] ?? []);

      final falladas = detalle
          .where((d) => d['esAcierto'] == false && d['respuestaUsuario'] != null)
          .toList();

      List<PreguntaEmbebida> resultado = [];
      for (final d in falladas) {
        final temaId = d['temaId'] as String?;
        final index = d['indexEnTema'] as int?;
        if (temaId == null || index == null) continue;

        final tema = todosTemas.where((t) => t.id == temaId).firstOrNull;
        if (tema == null || index >= tema.preguntas.length) continue;

        final pregunta = tema.preguntas[index];
        // Preservar temaNombre si está guardado en Firebase
        final temaNombreGuardado = d['temaNombre'] as String?;
        resultado.add(temaNombreGuardado != null
            ? pregunta.conTemaNombre(temaNombreGuardado)
            : pregunta);
      }

      return resultado;
    } catch (e) {
      debugPrint('Error obteniendo falladas: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CÁLCULO DE RESULTADOS
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> calcularResultados({
    required List<PreguntaEmbebida> preguntas,
    required Map<String, String?> respuestasUsuario,
  }) {
    int correctas = 0;
    int incorrectas = 0;
    int blancoNulas = 0;

    for (final pregunta in preguntas) {
      final respuesta = respuestasUsuario[pregunta.id];
      if (respuesta == null) {
        blancoNulas++;
      } else if (respuesta == pregunta.respuestaCorrecta) {
        correctas++;
      } else {
        incorrectas++;
      }
    }

    final int totalPreguntas = preguntas.length;
    final int numOpciones =
        preguntas.isNotEmpty ? preguntas.first.numOpciones : 4;

    final double penalizacion =
        numOpciones > 1 ? incorrectas / (numOpciones - 1) : 0;
    final double aciertosNetos = correctas - penalizacion;

    final double puntuacionDecimal = totalPreguntas > 0
        ? (aciertosNetos / totalPreguntas) * 100
        : 0;
    final int puntuacion = puntuacionDecimal.clamp(0, 100).round();

    final double notaDecimal = totalPreguntas > 0
        ? (aciertosNetos / totalPreguntas) * 60
        : 0;
    final int notaExamen = notaDecimal.clamp(0, 60).round();

    return {
      'totalPreguntas': totalPreguntas,
      'correctas': correctas,
      'incorrectas': incorrectas,
      'blancoNulas': blancoNulas,
      'penalizacion': penalizacion,
      'aciertosNetos': aciertosNetos,
      'puntuacion': puntuacion,
      'notaExamen': notaExamen,
      'porcentajeCorrectas': totalPreguntas > 0
          ? (correctas / totalPreguntas * 100)
          : 0.0,
      'porcentajeIncorrectas': totalPreguntas > 0
          ? (incorrectas / totalPreguntas * 100)
          : 0.0,
      'porcentajeBlancoNulas': totalPreguntas > 0
          ? (blancoNulas / totalPreguntas * 100)
          : 0.0,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR RESULTADO EN FIREBASE
  // ─────────────────────────────────────────────────────────────

  Future<bool> guardarResultado({
    required String usuarioId,
    required String nombreTest,
    required List<PreguntaEmbebida> preguntas,
    required Map<String, String?> respuestasUsuario,
    required Map<String, dynamic> resultados,
    required List<String> temasIds,
  }) async {
    try {
      final detalleRespuestas = preguntas.map((p) {
        final respuesta = respuestasUsuario[p.id];
        return {
          'temaId': p.temaId,
          'indexEnTema': p.indexEnTema,
          'temaNombre': p.temaNombre, // ← guarda el nombre del tema padre
          'texto': p.texto,
          'opciones': p.opciones
              .map((o) => {'letra': o.letra, 'texto': o.texto})
              .toList(),
          'respuestaUsuario': respuesta,
          'respuestaCorrecta': p.respuestaCorrecta,
          'esAcierto': respuesta != null && respuesta == p.respuestaCorrecta,
          'explicacion': p.explicacion,
        };
      }).toList();

      await _firestore.collection('resultados_tests').add({
        'usuarioId': usuarioId,
        'nombreTest': nombreTest,
        'fecha': FieldValue.serverTimestamp(),
        'temasIds': temasIds,
        'totalPreguntas': resultados['totalPreguntas'],
        'correctas': resultados['correctas'],
        'incorrectas': resultados['incorrectas'],
        'blancoNulas': resultados['blancoNulas'],
        'penalizacion': resultados['penalizacion'],
        'aciertosNetos': resultados['aciertosNetos'],
        'puntuacion': resultados['puntuacion'],
        'notaExamen': resultados['notaExamen'],
        'porcentajeCorrectas': resultados['porcentajeCorrectas'],
        'porcentajeIncorrectas': resultados['porcentajeIncorrectas'],
        'porcentajeBlancoNulas': resultados['porcentajeBlancoNulas'],
        'detalleRespuestas': detalleRespuestas,
      });

      return true;
    } catch (e) {
      debugPrint('Error guardando resultado: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HISTORIAL
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorial(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .orderBy('fecha', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo historial: $e');
      return [];
    }
  }

  Future<bool> eliminarResultado(String resultadoId) async {
    try {
      await _firestore
          .collection('resultados_tests')
          .doc(resultadoId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando resultado: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MÉTODOS PARA EXPLICACION_MODAL (funcionalidad futura)
  // ─────────────────────────────────────────────────────────────

  Future<String?> obtenerTemaDigital(String temaId) async {
    return null;
  }

  Future<String?> obtenerSubrayados(String userId, String preguntaTexto) async {
    return null;
  }

  Future<String?> obtenerExplicacionGemini(String userId, String preguntaTexto) async {
    return null;
  }
}
