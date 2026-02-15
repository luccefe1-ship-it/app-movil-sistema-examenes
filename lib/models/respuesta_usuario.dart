class RespuestaUsuario {
  final String preguntaId;
  final String? respuestaSeleccionada;
  final bool yaRespondida;

  RespuestaUsuario({
    required this.preguntaId,
    this.respuestaSeleccionada,
    this.yaRespondida = false,
  });

  RespuestaUsuario copyWith({
    String? respuestaSeleccionada,
    bool? yaRespondida,
  }) {
    return RespuestaUsuario(
      preguntaId: preguntaId,
      respuestaSeleccionada: respuestaSeleccionada ?? this.respuestaSeleccionada,
      yaRespondida: yaRespondida ?? this.yaRespondida,
    );
  }
}