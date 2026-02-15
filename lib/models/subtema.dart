class Subtema {
  final String id;
  final String temaId;
  final String nombre;
  final int orden;

  Subtema({
    required this.id,
    required this.temaId,
    required this.nombre,
    required this.orden,
  });

  factory Subtema.fromFirestore(Map<String, dynamic> data, String id) {
    return Subtema(
      id: id,
      temaId: data['temaId'] ?? '',
      nombre: data['nombre'] ?? '',
      orden: data['orden'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temaId': temaId,
      'nombre': nombre,
      'orden': orden,
    };
  }
}