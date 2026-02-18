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
  // GUARDAR RESULTADO + ACTUALIZAR FALLADAS
  // Mismo formato que la plataforma web
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
            'temaId': p.temaId,
            'temaNombre': p.temaNombre ?? '',
            'temaEpigrafe': '',
            'opciones': p.opciones.map((o) => {
              'letra': o.letra,
              'texto': o.texto,
              'esCorrecta': o.esCorrecta,
            }).toList(),
            'respuestaCorrecta': p.respuestaCorrecta,
            'explicacion': p.explicacion,
          },
          'respuestaCorrecta': p.respuestaCorrecta,
          'respuestaUsuario': respuesta,
        };
      }).toList();

      final total = resultados['total'] as int;
      final correctas = resultados['correctas'] as int;
      final porcentaje = total > 0 ? ((correctas / total) * 100).round() : 0;

      // Guardar resultado (misma estructura que la web)
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
        // ← Campo 'total' también a nivel raíz (la web lo lee como resultado.total)
        'total': total,
        'correctas': correctas,
        'incorrectas': resultados['incorrectas'],
        'sinResponder': resultados['sinResponder'],
        'porcentaje': porcentaje,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'detalleRespuestas': detalleRespuestas,
        'origen': 'app_movil', // Identificador de origen
      });

      // Actualizar preguntasFalladas (igual que la web)
      await _actualizarPreguntasFalladas(
        usuarioId: usuarioId,
        preguntas: preguntas,
        respuestasUsuario: respuestasUsuario,
      );

      // Registrar en progresoSimple para que cuente en el registro diario
      await _registrarEnProgresoSimple(
        usuarioId: usuarioId,
        temasIds: temasIds,
      );

      return true;
    } catch (e) {
      debugPrint('Error guardando resultado: $e');
      return false;
    }
  }

  /// Añade falladas nuevas y elimina las que se han acertado en este test
  Future<void> _actualizarPreguntasFalladas({
    required String usuarioId,
    required List<PreguntaEmbebida> preguntas,
    required Map<String, String?> respuestasUsuario,
  }) async {
    final batch = _firestore.batch();
    final colRef = _firestore.collection('preguntasFalladas');

    // Obtener falladas actuales del usuario
    final snapshot = await colRef
        .where('usuarioId', isEqualTo: usuarioId)
        .get();

    final falladasActuales = <String, String>{}; // key: temaId_indice, value: docId
    for (final doc in snapshot.docs) {
      final d = doc.data();
      final key = '${d['temaId']}_${d['indice']}';
      falladasActuales[key] = doc.id;
    }

    for (final p in preguntas) {
      final respuesta = respuestasUsuario[p.id];
      final key = '${p.temaId}_${p.indexEnTema}';

      if (respuesta == null) continue; // sin responder → no tocar

      if (respuesta == p.respuestaCorrecta) {
        // Acertada → eliminar de falladas si existía
        if (falladasActuales.containsKey(key)) {
          batch.delete(colRef.doc(falladasActuales[key]!));
        }
      } else {
        // Fallada → añadir si no existía
        if (!falladasActuales.containsKey(key)) {
          final newDoc = colRef.doc();
          batch.set(newDoc, {
            'usuarioId': usuarioId,
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
              'respuestaCorrecta': p.respuestaCorrecta,
            },
            'fechaFallo': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
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

        // Normalizar campos para la pantalla
        final testMap = data['test'] as Map<String, dynamic>? ?? {};
        if (!data.containsKey('total')) {
          data['total'] = testMap['total'] ?? 0;
        }
        if (!data.containsKey('puntuacion')) {
          data['puntuacion'] = data['porcentaje'] ?? 0;
        }

        return data;
      }).toList();

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
  // PREGUNTAS FALLADAS (desde colección preguntasFalladas)
  // ─────────────────────────────────────────────

  Future<int> contarPreguntasFalladas(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('preguntasFalladas')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error contando falladas: $e');
      return 0;
    }
  }

  Future<List<PreguntaEmbebida>> getPreguntasFalladas(
    String usuarioId,
    List<Tema> todosTemas,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('preguntasFalladas')
          .where('usuarioId', isEqualTo: usuarioId)
          .get();

      final resultado = <PreguntaEmbebida>[];

      for (final doc in snapshot.docs) {
        final d = doc.data();
        final temaId = d['temaId'] as String?;
        final indice = d['indice'] as int?;
        if (temaId == null || indice == null) continue;

        final tema = todosTemas.where((t) => t.id == temaId).firstOrNull;
        if (tema == null) continue;

        if (indice >= 0 && indice < tema.preguntas.length) {
          final p = tema.preguntas[indice];
          String temaNombre = tema.nombre;
          if (tema.esSubtema) {
            final padre = todosTemas
                .where((t) => t.id == tema.temaPadreId)
                .firstOrNull;
            if (padre != null) temaNombre = padre.nombre;
          }
          resultado.add(p.conTemaNombre(temaNombre));
        }
      }

      return resultado;
    } catch (e) {
      debugPrint('Error obteniendo falladas: $e');
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

  Future<String?> obtenerSubrayados(String userId, String preguntaTexto) async {
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

  // ─────────────────────────────────────────────
  // REGISTRO DIARIO (progresoSimple)
  // Replica la lógica de registrarTestEnProgresoSimple() de tests.js
  // ─────────────────────────────────────────────

  Future<void> _registrarEnProgresoSimple({
    required String usuarioId,
    required List<String> temasIds,
  }) async {
    try {
      final progresoRef =
          _firestore.collection('progresoSimple').doc(usuarioId);
      final progresoDoc = await progresoRef.get();

      // Si el usuario no tiene progresoSimple (no usa planning), no registrar
      if (!progresoDoc.exists) return;

      final progresoData =
          Map<String, dynamic>.from(progresoDoc.data()!);
      final temas =
          Map<String, dynamic>.from(progresoData['temas'] ?? {});
      final registros =
          List<dynamic>.from(progresoData['registros'] ?? []);

      final temasUnicos = temasIds.toSet().toList();

      // Obtener info de cada tema del banco
      final List<Map<String, dynamic>> infoTemas = [];
      for (final temaId in temasUnicos) {
        final temaDoc =
            await _firestore.collection('temas').doc(temaId).get();
        if (!temaDoc.exists) continue;
        final d = temaDoc.data()!;
        infoTemas.add({
          'idBanco': temaId,
          'nombreBanco': d['nombre'] ?? '',
          'padre': d['temaPadreId'],
        });
      }

      if (infoTemas.isEmpty) return;

      // ¿Todos los temas son subtemas del mismo padre?
      final padres = infoTemas
          .map((t) => t['padre'])
          .where((p) => p != null)
          .toList();
      final todosDelMismoPadre = padres.length == infoTemas.length &&
          padres.isNotEmpty &&
          padres.every((p) => p == padres[0]);

      final esMix = infoTemas.length > 1 && !todosDelMismoPadre;
      final fechaHoy = Timestamp.now();

      if (esMix) {
        // Test mixto (múltiples temas raíz)
        registros.add({
          'fecha': fechaHoy,
          'temaId': 'mix',
          'hojasLeidas': 0,
          'testsRealizados': 1,
          'temasMix': temasUnicos,
        });
      } else {
        // Test de un solo tema (o subtemas del mismo padre)
        Map<String, dynamic> temaInfo = infoTemas[0];

        if (todosDelMismoPadre && padres.isNotEmpty) {
          final padreId = padres[0] as String;
          final padreDoc =
              await _firestore.collection('temas').doc(padreId).get();
          if (padreDoc.exists) {
            final pd = padreDoc.data()!;
            temaInfo = {
              'idBanco': padreId,
              'nombreBanco': pd['nombre'] ?? '',
              'padre': null,
            };
          }
        }

        final idBanco = temaInfo['idBanco'] as String;
        final nombreBanco = temaInfo['nombreBanco'] as String;

        // Buscar coincidencia en planningSimple por nombre
        String temaIdFinal = idBanco;
        String nombreFinal = nombreBanco;
        int hojasTotales = 0;

        final planningDoc = await _firestore
            .collection('planningSimple')
            .doc(usuarioId)
            .get();
        if (planningDoc.exists) {
          final pd = planningDoc.data()!;
          final planningTemas = List<dynamic>.from(pd['temas'] ?? []);
          final nombreNorm = _normalizarNombre(nombreBanco);
          for (final pt in planningTemas) {
            if (_normalizarNombre(pt['nombre'] ?? '') == nombreNorm) {
              temaIdFinal = pt['id'] ?? idBanco;
              nombreFinal = pt['nombre'] ?? nombreBanco;
              hojasTotales = (pt['hojas'] ?? 0) as int;
              break;
            }
          }
        }

        // Crear entrada de tema si no existe
        if (!temas.containsKey(temaIdFinal)) {
          temas[temaIdFinal] = {
            'nombre': nombreFinal,
            'hojasTotales': hojasTotales,
            'hojasLeidas': 0,
            'testsRealizados': 0,
          };
        }

        // Incrementar contador
        final entry =
            Map<String, dynamic>.from(temas[temaIdFinal] as Map);
        entry['testsRealizados'] = ((entry['testsRealizados'] ?? 0) as int) + 1;
        temas[temaIdFinal] = entry;

        // Añadir registro
        registros.add({
          'fecha': fechaHoy,
          'temaId': temaIdFinal,
          'hojasLeidas': 0,
          'testsRealizados': 1,
        });
      }

      progresoData['temas'] = temas;
      progresoData['registros'] = registros;
      await progresoRef.set(progresoData);
      debugPrint('✅ Test registrado en progresoSimple');
    } catch (e) {
      debugPrint('Error registrando en progresoSimple: $e');
    }
  }

  String _normalizarNombre(String nombre) {
    return nombre
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'tema\s*'), 'tema ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
