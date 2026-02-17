class Tema {
  final String id;
  final String nombre;
  final String usuarioId;
  final String? temaPadreId;
  final int orden;
  final List<PreguntaEmbebida> preguntas;
  final DateTime? fechaCreacion;

  Tema({
    required this.id,
    required this.nombre,
    required this.usuarioId,
    this.temaPadreId,
    this.orden = 0,
    this.preguntas = const [],
    this.fechaCreacion,
  });

  bool get esSubtema => temaPadreId != null;
  int get numPreguntas => preguntas.length;
  int get numPreguntasVerificadas =>
      preguntas.where((p) => p.verificada).length;

  factory Tema.fromFirestore(Map<String, dynamic> data, String id) {
    List<PreguntaEmbebida> preguntas = [];
    if (data['preguntas'] != null && data['preguntas'] is List) {
      preguntas = (data['preguntas'] as List).asMap().entries.map((entry) {
        final map = entry.value as Map<String, dynamic>;
        return PreguntaEmbebida.fromMap(map, id, entry.key);
      }).toList();
    }

    return Tema(
      id: id,
      nombre: data['nombre'] ?? '',
      usuarioId: data['usuarioId'] ?? '',
      temaPadreId: data['temaPadreId'],
      orden: data['orden'] ?? 0,
      preguntas: preguntas,
      fechaCreacion: data['fechaCreacion']?.toDate(),
    );
  }

  // Extraer número del nombre para ordenar (Tema 1, Tema 2, etc.)
  int? get numeroExtraido {
    final match = RegExp(r'\d+').firstMatch(nombre);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }
}

class PreguntaEmbebida {
  final String temaId;
  final int indexEnTema;
  final String texto;
  final List<OpcionPregunta> opciones;
  final String respuestaCorrecta;
  final bool verificada;
  final String? explicacion;
  final String? temaNombre; // Nombre del tema padre general

  PreguntaEmbebida({
    required this.temaId,
    required this.indexEnTema,
    required this.texto,
    required this.opciones,
    required this.respuestaCorrecta,
    this.verificada = false,
    this.explicacion,
    this.temaNombre,
  });

  // ID único generado
  String get id => '${temaId}_$indexEnTema';

  int get numOpciones => opciones.length;

  String? get textoRespuestaCorrecta {
    final opcion =
        opciones.where((o) => o.letra == respuestaCorrecta).firstOrNull;
    return opcion?.texto;
  }

  /// Crea una copia con el nombre del tema padre asignado
  PreguntaEmbebida conTemaNombre(String nombre) {
    return PreguntaEmbebida(
      temaId: temaId,
      indexEnTema: indexEnTema,
      texto: texto,
      opciones: opciones,
      respuestaCorrecta: respuestaCorrecta,
      verificada: verificada,
      explicacion: explicacion,
      temaNombre: nombre,
    );
  }

  factory PreguntaEmbebida.fromMap(
      Map<String, dynamic> map, String temaId, int index) {
    List<OpcionPregunta> opciones = [];
    if (map['opciones'] != null && map['opciones'] is List) {
      opciones = (map['opciones'] as List).map((o) {
        final opMap = o as Map<String, dynamic>;
        return OpcionPregunta(
          letra: opMap['letra'] ?? '',
          texto: opMap['texto'] ?? '',
          esCorrecta: opMap['esCorrecta'] == true,
        );
      }).toList();
    }

    return PreguntaEmbebida(
      temaId: temaId,
      indexEnTema: index,
      texto: map['texto'] ?? '',
      opciones: opciones,
      respuestaCorrecta: map['respuestaCorrecta'] ?? '',
      verificada: map['verificada'] == true,
      explicacion: map['explicacion'],
      temaNombre: map['temaNombre'],
    );
  }
}

class OpcionPregunta {
  final String letra;
  final String texto;
  final bool esCorrecta;

  OpcionPregunta({
    required this.letra,
    required this.texto,
    required this.esCorrecta,
  });
}
