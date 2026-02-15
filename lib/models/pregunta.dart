class Pregunta {
  final String id;
  final String subtemaId;
  final String enunciado;
  final List<String> opciones;
  final String respuestaCorrecta;
  final int numOpciones;
  final String? explicacion;

  Pregunta({
    required this.id,
    required this.subtemaId,
    required this.enunciado,
    required this.opciones,
    required this.respuestaCorrecta,
    this.numOpciones = 4,
    this.explicacion,
  });

  factory Pregunta.fromFirestore(Map<String, dynamic> data, String id) {
    return Pregunta(
      id: id,
      subtemaId: data['subtemaId'] ?? '',
      enunciado: data['enunciado'] ?? '',
      opciones: List<String>.from(data['opciones'] ?? []),
      respuestaCorrecta: data['respuestaCorrecta'] ?? '',
      numOpciones: data['numOpciones'] ?? 4,
      explicacion: data['explicacion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subtemaId': subtemaId,
      'enunciado': enunciado,
      'opciones': opciones,
      'respuestaCorrecta': respuestaCorrecta,
      'numOpciones': numOpciones,
      'explicacion': explicacion,
    };
  }

  bool tieneExplicacion() => explicacion != null && explicacion!.isNotEmpty;
}