import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tema.dart';

class TestService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN
  // ─────────────────────────────────────────────

  Future<void> guardarConfiguracion(
    String nombre,
    List<String> temasIds,
    int numPreguntas,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultima_config', jsonEncode({
        'nombre': nombre,
        'temasIds': temasIds,
        'numPreguntas': numPreguntas,
      }));
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
    }
  }

  Future<Map<String, dynamic>?> cargarUltimaConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('ultima_config');
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // CALCULAR RESULTADOS
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
    final puntuacion =
        total > 0 ? (aciertosNetos / total * 100).round().clamp(0, 100) : 0;
    final notaExamen =
        total > 0 ? (aciertosNetos / total * 60).clamp(0.0, 60.0) : 0.0;

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
  // Compatible con la estructura existente de la plataforma web
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
        final esAcierto = respuesta == p.respuestaCorrecta;
        return {
          'temaId': p.temaId,
          'indice': p.indexEnTema,
          'temaNombre': p.temaNombre ?? '',
          'temaEpigrafe': '',
          'estado': respuesta == null
              ? 'sinResponder'
              : esAcierto
                  ? 'correcta'
                  : 'incorrecta',
          'pregunta': {
            'texto': p.texto,
            'opciones': p.opciones
                .map((o) => {
                      'letra': o.letra,
                      'texto': o.texto,
                      'esCorrecta': o.esCorrecta,
                    })
                .toList(),
            'respuestaCorrecta': p.respuestaCorrecta,
            'explicacion': p.explicacion,
            'temaId': p.temaId,
            'temaNombre': p.temaNombre ?? '',
            'temaEpigrafe': '',
            'texto': p.texto,
          },
          'respuestaCorrecta': p.respuestaCorrecta,
          'respuestaUsuario': respuesta,
        };
      }).toList();

      final total = resultados['total'] as int;
      final correctas = resultados['correctas'] as int;
      final porcentaje = total > 0 ? ((correctas / total) * 100).round() : 0;

      await _firestore.collection('resultados').add({
        'usuarioId': usuarioId,
        'test': {
          'nombre': nombreTest,
          'tema': temasIds,
          'total': total,
          'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
          'fechaInicio': FieldValue.serverTimestamp(),
          'tiempoEmpleado': 0,
        },
        'correctas': correctas,
        'incorrectas': resultados['incorrectas'],
        'sinResponder': resultados['sinResponder'],
        'porcentaje': porcentaje,
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
  // HISTORIAL
  // ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorial(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      final lista = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Normalizar: la pantalla espera 'total' y 'puntuacion' en raíz
        final testMap = data['test'] as Map<String, dynamic>? ?? {};
        if (!data.containsKey('total')) {
          data['total'] = testMap['total'] ?? 0;
        }
        // La web guarda 'porcentaje', la pantalla espera 'puntuacion'
        if (!data.containsKey('puntuacion')) {
          data['puntuacion'] = data['porcentaje'] ?? 0;
        }

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

  Future<bool> eliminarResultado(String testId) async {
    try {
      await _firestore.collection('resultados').doc(testId).delete();
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

      final tema = todosTemas.where((t) => t.id == temaId).firstOrNull;
      if (tema == null) continue;

      if (indice >= 0 && indice < tema.preguntas.length) {
        final p = tema.preguntas[indice];
        String temaNombre = tema.nombre;
        if (tema.esSubtema) {
          final padre =
              todosTemas.where((t) => t.id == tema.temaPadreId).firstOrNull;
          if (padre != null) temaNombre = padre.nombre;
        }
        resultado.add(p.conTemaNombre(temaNombre));
      }
    }

    return resultado;
  }

  Future<List<Map<String, dynamic>>> _getPreguntasFalladasRaw(
      String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      final falladas = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final detalles = data['detalleRespuestas'] as List<dynamic>? ?? [];
        for (final detalle in detalles) {
          final d = detalle as Map<String, dynamic>;
          final estado = d['estado'] as String? ?? '';
          // Compatible con formato web ('estado') y app ('esAcierto')
          final esFallo = estado == 'incorrecta' ||
              (d.containsKey('esAcierto') && d['esAcierto'] == false);
          final respuesta = d['respuestaUsuario'];
          if (esFallo && respuesta != null) {
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

  // ─────────────────────────────────────────────
  // MÉTODOS PARA EXPLICACION_MODAL
  // ─────────────────────────────────────────────

  Future<String?> obtenerTemaDigital(String temaId) async {
    try {
      final doc =
          await _firestore.collection('temas_digital').doc(temaId).get();
      if (doc.exists) {
        return doc.data()?['contenido'] as String?;
      }
    } catch (e) {
      debugPrint('Error obteniendo tema digital: $e');
    }
    return null;
  }

  Future<String?> obtenerSubrayados(
      String userId, String preguntaTexto) async {
    try {
      final snapshot = await _firestore
          .collection('subrayados')
          .where('usuarioId', isEqualTo: userId)
          .where('preguntaTexto', isEqualTo: preguntaTexto)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['html'] as String?;
      }
    } catch (e) {
      debugPrint('Error obteniendo subrayados: $e');
    }
    return null;
  }

  Future<String?> obtenerExplicacionGemini(
      String userId, String preguntaTexto) async {
    try {
      final snapshot = await _firestore
          .collection('explicacionesGemini')
          .where('preguntaTexto', isEqualTo: preguntaTexto)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['explicacion'] as String?;
      }
    } catch (e) {
      debugPrint('Error obteniendo explicación Gemini: $e');
    }
    return null;
  }
}
