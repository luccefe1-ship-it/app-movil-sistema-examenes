import 'package:cloud_firestore/cloud_firestore.dart';

class PreguntaResultado {
  final String preguntaId;
  final String enunciado;
  final List<String> opciones;
  final String? respuestaUsuario;
  final String respuestaCorrecta;
  final bool esAcierto;
  final String? explicacion;
  final String? temaNombre; // Nombre del tema padre

  PreguntaResultado({
    required this.preguntaId,
    required this.enunciado,
    required this.opciones,
    this.respuestaUsuario,
    required this.respuestaCorrecta,
    required this.esAcierto,
    this.explicacion,
    this.temaNombre,
  });

  Map<String, dynamic> toMap() {
    return {
      'preguntaId': preguntaId,
      'enunciado': enunciado,
      'opciones': opciones,
      'respuestaUsuario': respuestaUsuario,
      'respuestaCorrecta': respuestaCorrecta,
      'esAcierto': esAcierto,
      'explicacion': explicacion,
      'temaNombre': temaNombre,
    };
  }

  factory PreguntaResultado.fromMap(Map<String, dynamic> map) {
    return PreguntaResultado(
      preguntaId: map['preguntaId'] ?? '',
      enunciado: map['enunciado'] ?? '',
      opciones: List<String>.from(map['opciones'] ?? []),
      respuestaUsuario: map['respuestaUsuario'],
      respuestaCorrecta: map['respuestaCorrecta'] ?? '',
      esAcierto: map['esAcierto'] ?? false,
      explicacion: map['explicacion'],
      temaNombre: map['temaNombre'],
    );
  }
}

class ResultadoTest {
  final String? id;
  final String usuarioId;
  final String nombreTest;
  final DateTime fecha;
  
  // Configuración
  final List<String> temas;
  final List<String> subtemas;
  final int numeroPreguntas;
  final int numOpciones;
  
  // Resultados
  final int totalPreguntas;
  final int correctas;
  final int incorrectas;
  final int blancoNulas;
  
  // Cálculos
  final double penalizacion;
  final double aciertosNetos;
  final int puntuacion;
  final int? notaExamen;
  
  // Porcentajes
  final double porcentajeCorrectas;
  final double porcentajeIncorrectas;
  final double porcentajeBlancoNulas;
  
  // Preguntas detalladas
  final List<PreguntaResultado> preguntas;

  ResultadoTest({
    this.id,
    required this.usuarioId,
    required this.nombreTest,
    required this.fecha,
    required this.temas,
    required this.subtemas,
    required this.numeroPreguntas,
    this.numOpciones = 4,
    required this.totalPreguntas,
    required this.correctas,
    required this.incorrectas,
    required this.blancoNulas,
    required this.penalizacion,
    required this.aciertosNetos,
    required this.puntuacion,
    this.notaExamen,
    required this.porcentajeCorrectas,
    required this.porcentajeIncorrectas,
    required this.porcentajeBlancoNulas,
    required this.preguntas,
  });

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'nombreTest': nombreTest,
      'fecha': Timestamp.fromDate(fecha),
      'parametros': {
        'temas': temas,
        'subtemas': subtemas,
        'numeroPreguntas': numeroPreguntas,
        'numOpciones': numOpciones,
      },
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
      'preguntas': preguntas.map((p) => p.toMap()).toList(),
    };
  }

  factory ResultadoTest.fromFirestore(Map<String, dynamic> data, String id) {
    final parametros = data['parametros'] as Map<String, dynamic>? ?? {};
    
    return ResultadoTest(
      id: id,
      usuarioId: data['usuarioId'] ?? '',
      nombreTest: data['nombreTest'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      temas: List<String>.from(parametros['temas'] ?? []),
      subtemas: List<String>.from(parametros['subtemas'] ?? []),
      numeroPreguntas: parametros['numeroPreguntas'] ?? 0,
      numOpciones: parametros['numOpciones'] ?? 4,
      totalPreguntas: data['totalPreguntas'] ?? 0,
      correctas: data['correctas'] ?? 0,
      incorrectas: data['incorrectas'] ?? 0,
      blancoNulas: data['blancoNulas'] ?? 0,
      penalizacion: (data['penalizacion'] ?? 0.0).toDouble(),
      aciertosNetos: (data['aciertosNetos'] ?? 0.0).toDouble(),
      puntuacion: data['puntuacion'] ?? 0,
      notaExamen: data['notaExamen'],
      porcentajeCorrectas: (data['porcentajeCorrectas'] ?? 0.0).toDouble(),
      porcentajeIncorrectas: (data['porcentajeIncorrectas'] ?? 0.0).toDouble(),
      porcentajeBlancoNulas: (data['porcentajeBlancoNulas'] ?? 0.0).toDouble(),
      preguntas: (data['preguntas'] as List<dynamic>?)
              ?.map((p) => PreguntaResultado.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
