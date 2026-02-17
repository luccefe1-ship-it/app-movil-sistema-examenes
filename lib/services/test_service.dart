import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/test_config.dart';
import '../models/resultado_test.dart';
import '../models/pregunta.dart';
import '../models/respuesta_usuario.dart';

class TestService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  TestConfig? _ultimaConfiguracion;
  
  TestConfig? get ultimaConfiguracion => _ultimaConfiguracion;

  // Guardar configuración del test
  Future<void> guardarConfiguracion(TestConfig config) async {
    _ultimaConfiguracion = config;
    
    // Guardar en SharedPreferences para persistencia
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultima_config', jsonEncode(config.toMap()));
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
    }
    
    notifyListeners();
  }

  // Cargar última configuración guardada
  Future<void> cargarUltimaConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('ultima_config');
      
      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        _ultimaConfiguracion = TestConfig.fromMap(configMap);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
  }

  // Calcular resultados del test con sistema de puntuación
  Map<String, dynamic> calcularResultados({
    required int totalPreguntas,
    required int correctas,
    required int incorrectas,
    required int blancoNulas,
    int numOpciones = 4,
    int puntosMaximos = 100,
    int? notaMaximaExamen = 60,
  }) {
    // Validar datos
    assert(
      correctas + incorrectas + blancoNulas == totalPreguntas,
      'La suma de correctas, incorrectas y blanco debe ser igual al total',
    );

    // Paso 1: Calcular penalización
    final double penalizacion = incorrectas / (numOpciones - 1);

    // Paso 2: Calcular aciertos netos
    final double aciertosNetos = correctas - penalizacion;

    // Paso 3: Calcular puntuación sobre 100
    final double puntuacionDecimal =
        (aciertosNetos / totalPreguntas) * puntosMaximos;
    final int puntuacion =
        puntuacionDecimal.clamp(0, puntosMaximos).round();

    // Paso 4: Calcular nota sobre examen oficial (si aplica)
    int? notaExamen;
    if (notaMaximaExamen != null) {
      final double notaDecimal =
          (aciertosNetos / totalPreguntas) * notaMaximaExamen;
      notaExamen = notaDecimal.clamp(0, notaMaximaExamen).round();
    }

    // Paso 5: Calcular porcentajes
    final double porcentajeCorrectas = (correctas / totalPreguntas) * 100;
    final double porcentajeIncorrectas = (incorrectas / totalPreguntas) * 100;
    final double porcentajeBlancoNulas = (blancoNulas / totalPreguntas) * 100;

    return {
      'totalPreguntas': totalPreguntas,
      'correctas': correctas,
      'incorrectas': incorrectas,
      'blancoNulas': blancoNulas,
      'penalizacion': penalizacion,
      'aciertosNetos': aciertosNetos,
      'puntuacion': puntuacion,
      'notaExamen': notaExamen,
      'porcentajeCorrectas': porcentajeCorrectas,
      'porcentajeIncorrectas': porcentajeIncorrectas,
      'porcentajeBlancoNulas': porcentajeBlancoNulas,
    };
  }

  // Procesar respuestas y crear resultado del test
  ResultadoTest procesarTest({
    required String usuarioId,
    required String nombreTest,
    required List<String> temasIds,
    required List<String> subtemasIds,
    required List<Pregunta> preguntas,
    required Map<String, RespuestaUsuario> respuestas,
  }) {
    int correctas = 0;
    int incorrectas = 0;
    int blancoNulas = 0;

    List<PreguntaResultado> preguntasResultado = [];

    for (var pregunta in preguntas) {
      final respuesta = respuestas[pregunta.id];
      final respuestaUsuario = respuesta?.respuestaSeleccionada;
      
      bool esAcierto = false;
      
      if (respuestaUsuario == null) {
        blancoNulas++;
      } else if (respuestaUsuario == pregunta.respuestaCorrecta) {
        correctas++;
        esAcierto = true;
      } else {
        incorrectas++;
      }

      preguntasResultado.add(
        PreguntaResultado(
          preguntaId: pregunta.id,
          enunciado: pregunta.enunciado,
          opciones: pregunta.opciones,
          respuestaUsuario: respuestaUsuario,
          respuestaCorrecta: pregunta.respuestaCorrecta,
          esAcierto: esAcierto,
          explicacion: pregunta.explicacion,
          temaNombre: pregunta.temaNombre, // ← NUEVO: pasar tema padre
        ),
      );
    }

    // Calcular puntuación
    final numOpciones = preguntas.isNotEmpty ? preguntas.first.numOpciones : 4;
    final calculos = calcularResultados(
      totalPreguntas: preguntas.length,
      correctas: correctas,
      incorrectas: incorrectas,
      blancoNulas: blancoNulas,
      numOpciones: numOpciones,
    );

    return ResultadoTest(
      usuarioId: usuarioId,
      nombreTest: nombreTest,
      fecha: DateTime.now(),
      temas: temasIds,
      subtemas: subtemasIds,
      numeroPreguntas: preguntas.length,
      numOpciones: numOpciones,
      totalPreguntas: calculos['totalPreguntas'],
      correctas: calculos['correctas'],
      incorrectas: calculos['incorrectas'],
      blancoNulas: calculos['blancoNulas'],
      penalizacion: calculos['penalizacion'],
      aciertosNetos: calculos['aciertosNetos'],
      puntuacion: calculos['puntuacion'],
      notaExamen: calculos['notaExamen'],
      porcentajeCorrectas: calculos['porcentajeCorrectas'],
      porcentajeIncorrectas: calculos['porcentajeIncorrectas'],
      porcentajeBlancoNulas: calculos['porcentajeBlancoNulas'],
      preguntas: preguntasResultado,
    );
  }

  // Guardar resultado en Firebase
  Future<bool> guardarResultado(ResultadoTest resultado) async {
    try {
      await _firestore.collection('resultados_tests').add(resultado.toMap());
      return true;
    } catch (e) {
      debugPrint('Error guardando resultado: $e');
      return false;
    }
  }

  // Obtener historial del usuario
  Future<List<ResultadoTest>> getHistorial(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('resultados_tests')
          .where('usuarioId', isEqualTo: usuarioId)
          .orderBy('fecha', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ResultadoTest.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial: $e');
      return [];
    }
  }

  // Obtener un resultado específico por ID
  Future<ResultadoTest?> getResultadoById(String resultadoId) async {
    try {
      final doc = await _firestore
          .collection('resultados_tests')
          .doc(resultadoId)
          .get();

      if (!doc.exists) return null;

      return ResultadoTest.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error obteniendo resultado: $e');
      return null;
    }
  }
}
