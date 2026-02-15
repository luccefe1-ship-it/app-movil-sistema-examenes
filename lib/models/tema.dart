class Tema {
  final String id;
  final String nombre;
  final int orden;
  final String? descripcion;

  Tema({
    required this.id,
    required this.nombre,
    required this.orden,
    this.descripcion,
  });

  factory Tema.fromFirestore(Map<String, dynamic> data, String id) {
    return Tema(
      id: id,
      nombre: data['nombre'] ?? '',
      orden: data['orden'] ?? 0,
      descripcion: data['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'orden': orden,
      'descripcion': descripcion,
    };
  }
}