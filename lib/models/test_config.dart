class TestConfig {
  final String nombreTest;
  final List<String> temasIds;
  final List<String> subtemasIds;
  final int numeroPreguntas;

  TestConfig({
    required this.nombreTest,
    required this.temasIds,
    required this.subtemasIds,
    required this.numeroPreguntas,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombreTest': nombreTest,
      'temasIds': temasIds,
      'subtemasIds': subtemasIds,
      'numeroPreguntas': numeroPreguntas,
    };
  }

  factory TestConfig.fromMap(Map<String, dynamic> map) {
    return TestConfig(
      nombreTest: map['nombreTest'] ?? '',
      temasIds: List<String>.from(map['temasIds'] ?? []),
      subtemasIds: List<String>.from(map['subtemasIds'] ?? []),
      numeroPreguntas: map['numeroPreguntas'] ?? 10,
    );
  }
}