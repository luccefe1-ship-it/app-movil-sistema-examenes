import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tema.dart';
import '../models/test_config.dart';

class TestService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TestConfig? _ultimaConfiguracion;
  TestConfig? get ultimaConfiguracion => _ultimaConfiguracion;

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN
  // ─────────────────────────────────────────────

  Future<void> guardarConfiguracion(TestConfig config) async {
    _ultimaConfiguracion = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultima_config', jsonEncode(config.toMap()));
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
    }
    notifyListeners();
  }

  Future<void> cargarUltimaConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('ultima_config');
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _ultimaConfiguracion = TestConfig.fromMap(map);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
  }

  // ─────────────────────────────────────────────
  // CALCULAR RESULTADOS (se llama en RealizarTestScreen)
  // ─────────────────────────────────────────────

  Map<String, dynamic> calcularResultados({
    required List<PreguntaEmbebida> preguntas,
    required Map<String, String?> respuestasUsuario,
  }) {
    int correctas = 0;
    int incorrectas = 0;
    int sinResponder = 0;

    for (final p in preguntas) {
      final respuesta = respuestasUsuario[p.id];
      if (respuesta == null) {
        sinResponder++;
      } else if (respuesta == p.respuestaCorrecta) {
        correctas++;
      } else {
        incorrectas++;
      }
    }

    final total = preguntas.length;
    final penalizacion = incorrectas / 3.0;
    final aciertosNetos = correctas - penalizacion;
    final puntuacion = total > 0 ? (aciertosNetos / total * 100).round().clamp(0, 100) : 0;
    final notaExamen = total > 0 ? (aciertosNetos / total * 60).clamp(0, 60) : 0;

    return {
      'total': total,
      'correctas': correctas,
      'incorrectas': incorrectas,
      'sinResponder': sinResponder,
      'penalizacion': penalizacion,
      'aciertosNetos': aciertosNetos,
      'puntuacion': puntuacion,
      'notaExamen': double.parse(notaExamen.toStringAsFixed(2)),
    };
  }

  // ─────────────────────────────────────────────
  // GUARDAR RESULTADO EN FIREBASE
  // ─────────────────────────────────────────────

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
          'indice': p.indexEnTema,
          'temaNombre': p.temaNombre ?? '',
          'pregunta': {
            'texto': p.texto,
            'opciones': p.opciones.map((o) => {
              'letra': o.letra,
              'texto': o.texto,
              'esCorrecta': o.esCorrecta,
            }).toList(),
            'explicacion': p.explicacion,
          },
          'respuestaCorrecta': p.respuestaCorrecta,
          'respuestaUsuario': respuesta,
          'esAcierto': respuesta == p.respuestaCorrecta,
        };
      }).toList();

      await _firestore.collection('resultados_tests').add({
        'usuarioId': usuarioId,
        'test': {
          'nombre': nombreTest,
          'temasIds': temasIds,
          'numPreguntas': preguntas.length,
        },
        'correctas': resultados['correctas'],
        'incorrectas': resultados['incorrectas'],
        'sinResponder': resultados['sinResponder'],
        'total': resultados['total'],
        'puntuacion': resultados['puntuacion'],
        'notaExamen': resultados['notaExamen'],
        'penalizacion': resultados['penalizacion'],
        'aciertosNetos': resultados['aciertosNetos'],
        'fechaCreacion': FieldValue.serverTimestamp(),
        'detalleRespuestas': detalleRespuestas,
      });

      return true;
    } catch (e) {
      debugPrint('Error guardando resultado: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // OBTENER HISTORIAL
  // ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorial(String usuarioId) async {
    try {
      // Sin orderBy para evitar requerir índice compuesto en Firestore
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      final lista = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Ordenar localmente por fechaCreacion (más reciente primero)
      lista.sort((a, b) {
        final fechaA = a['fechaCreacion'];
        final fechaB = b['fechaCreacion'];
        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return 1;
        if (fechaB == null) return -1;
        try {
          return fechaB.toDate().compareTo(fechaA.toDate());
        } catch (e) {
          return 0;
        }
      });

      return lista;
    } catch (e) {
      debugPrint('Error obteniendo historial: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // ELIMINAR RESULTADO
  // ─────────────────────────────────────────────

  Future<bool> eliminarResultado(String testId) async {
    try {
      await _firestore.collection('resultados_tests').doc(testId).delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando resultado: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PREGUNTAS ALEATORIAS
  // ─────────────────────────────────────────────

  List<PreguntaEmbebida> getRandomPreguntas(
    List<PreguntaEmbebida> todasPreguntas,
    int cantidad,
  ) {
    final lista = List<PreguntaEmbebida>.from(todasPreguntas);
    lista.shuffle();
    return lista.take(cantidad.clamp(0, lista.length)).toList();
  }

  // ─────────────────────────────────────────────
  // PREGUNTAS FALLADAS
  // ─────────────────────────────────────────────

  Future<int> contarPreguntasFalladas(String usuarioId) async {
    final falladas = await _getPreguntasFalladasRaw(usuarioId);
    return falladas.length;
  }

  Future<List<PreguntaEmbebida>> getPreguntasFalladas(
    String usuarioId,
    List<Tema> todosTemas,
  ) async {
    final raw = await _getPreguntasFalladasRaw(usuarioId);
    final resultado = <PreguntaEmbebida>[];
    final vistas = <String>{};

    for (final item in raw) {
      final temaId = item['temaId'] as String?;
      final indice = item['indice'] as int?;
      if (temaId == null || indice == null) continue;

      final key = '${temaId}_$indice';
      if (vistas.contains(key)) continue;
      vistas.add(key);

      // Buscar el tema en la lista
      final tema = todosTemas.where((t) => t.id == temaId).firstOrNull;
      if (tema == null) continue;

      // Buscar la pregunta en ese tema por índice
      if (indice >= 0 && indice < tema.preguntas.length) {
        final p = tema.preguntas[indice];

        // Resolver temaNombre
        String temaNombre = tema.nombre;
        if (tema.esSubtema) {
          final padre = todosTemas.where((t) => t.id == tema.temaPadreId).firstOrNull;
          if (padre != null) temaNombre = padre.nombre;
        }

        resultado.add(p.conTemaNombre(temaNombre));
      }
    }

    return resultado;
  }

  /// Devuelve la lista raw de respuestas falladas de todos los tests del usuario
  Future<List<Map<String, dynamic>>> _getPreguntasFalladasRaw(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      final falladas = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final detalles = data['detalleRespuestas'] as List<dynamic>? ?? [];
        for (final detalle in detalles) {
          final d = detalle as Map<String, dynamic>;
          final esAcierto = d['esAcierto'] == true;
          final respuesta = d['respuestaUsuario'];
          if (!esAcierto && respuesta != null) {
            falladas.add(d);
          }
        }
      }
      return falladas;
    } catch (e) {
      debugPrint('Error obteniendo preguntas falladas: $e');
      return [];
    }
  }
}
