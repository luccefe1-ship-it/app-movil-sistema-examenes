// notas_corte.dart — Datos oficiales de convocatoria y comparativa de resultados
// PORT LITERAL de js/notas-corte.js (plataforma web). Mismos valores y misma fórmula.
// Fuente: OEP 2024 · BOE núm. 305 de 19-12-2024 · Órdenes PJC/1437/2024, PJC/1435/2024, PJC/1436/2024
// Notas de corte finales: relaciones oficiales del Tribunal Calificador Único (mayo–junio 2026),
// ámbito MADRID, sistema general.
// ⚠️ Al actualizar la convocatoria, SOLO hay que tocar este fichero (y su gemelo en la web).

import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class TurnoConvocatoria {
  final String nombre;
  final int preguntasExamen;
  final int opcionesPorPregunta;
  final double valorAcierto;
  final double penalizacionError;
  final bool blancasPenalizan;
  final double notaMaxima;
  final double notaCortePrimerEjercicio;
  final String tipoCorte;
  final double notaMaximaProceso;
  final double notaCorteFinal;
  final int plazas;
  final int plazasAmbito;

  const TurnoConvocatoria({
    required this.nombre,
    required this.preguntasExamen,
    required this.opcionesPorPregunta,
    required this.valorAcierto,
    required this.penalizacionError,
    required this.blancasPenalizan,
    required this.notaMaxima,
    required this.notaCortePrimerEjercicio,
    required this.tipoCorte,
    required this.notaMaximaProceso,
    required this.notaCorteFinal,
    required this.plazas,
    required this.plazasAmbito,
  });
}

class CuerpoConvocatoria {
  final String nombre;
  final String nombreCorto;
  final Map<String, TurnoConvocatoria> turnos;

  const CuerpoConvocatoria({
    required this.nombre,
    required this.nombreCorto,
    required this.turnos,
  });
}

class DatosConvocatoria {
  static const String etiqueta = 'OEP 2024';
  static const String boe = 'BOE núm. 305, de 19-12-2024';
  static const String ambito = 'Madrid · sistema general';
  static const String fechaExamen =
      '27-09-2025 (libre) / 28-06-2025 (promoción interna)';

  /// 'Madrid' — equivalente a ambito.split('·')[0].trim() de la web
  static String get ambitoCorto => ambito.split('·').first.trim();

  static const Map<String, CuerpoConvocatoria> cuerpos = {
    'gestion': CuerpoConvocatoria(
      nombre: 'Gestión Procesal y Administrativa',
      nombreCorto: 'Gestión',
      turnos: {
        'libre': TurnoConvocatoria(
          nombre: 'Turno libre',
          preguntasExamen: 100,
          opcionesPorPregunta: 4,
          valorAcierto: 0.60,
          penalizacionError: 0.15,
          blancasPenalizan: false,
          notaMaxima: 60,
          notaCortePrimerEjercicio: 30,
          tipoCorte: 'mínima fija en bases (50%)',
          notaMaximaProceso: 100,
          notaCorteFinal: 52.85,
          plazas: 731,
          plazasAmbito: 180,
        ),
        'interna': TurnoConvocatoria(
          nombre: 'Promoción interna',
          preguntasExamen: 100,
          opcionesPorPregunta: 4,
          valorAcierto: 1.00,
          penalizacionError: 0.25,
          blancasPenalizan: false,
          notaMaxima: 100,
          notaCortePrimerEjercicio: 50,
          tipoCorte: 'mínima fija en bases',
          notaMaximaProceso: 165,
          notaCorteFinal: 120.00,
          plazas: 219,
          plazasAmbito: 48,
        ),
      },
    ),
    'tramitacion': CuerpoConvocatoria(
      nombre: 'Tramitación Procesal y Administrativa',
      nombreCorto: 'Tramitación',
      turnos: {
        'libre': TurnoConvocatoria(
          nombre: 'Turno libre',
          preguntasExamen: 100,
          opcionesPorPregunta: 4,
          valorAcierto: 0.60,
          penalizacionError: 0.15,
          blancasPenalizan: false,
          notaMaxima: 60,
          notaCortePrimerEjercicio: 30,
          tipoCorte: 'mínima fija en bases (50%)',
          notaMaximaProceso: 100,
          notaCorteFinal: 71.10,
          plazas: 855,
          plazasAmbito: 310,
        ),
        'interna': TurnoConvocatoria(
          nombre: 'Promoción interna',
          preguntasExamen: 100,
          opcionesPorPregunta: 4,
          valorAcierto: 1.00,
          penalizacionError: 0.25,
          blancasPenalizan: false,
          notaMaxima: 100,
          notaCortePrimerEjercicio: 50,
          tipoCorte: 'mínima fija en bases',
          notaMaximaProceso: 165,
          notaCorteFinal: 82.20,
          plazas: 257,
          plazasAmbito: 79,
        ),
      },
    ),
  };

  static TurnoConvocatoria? config(String cuerpo, String turno) {
    return cuerpos[cuerpo]?.turnos[turno];
  }
}

// ─────────────────────────────────────────────
// PREFERENCIA DEL USUARIO (cuerpo + turno)
// Equivalente a obtenerPreferencia/guardarPreferencia de la web
// ─────────────────────────────────────────────

class PreferenciaComparativa {
  final String cuerpo;
  final String turno;
  const PreferenciaComparativa(this.cuerpo, this.turno);

  static const PreferenciaComparativa porDefecto =
      PreferenciaComparativa('tramitacion', 'libre');
}

const String _kClaveCuerpo = 'preferenciaComparativaCuerpo';
const String _kClaveTurno = 'preferenciaComparativaTurno';

Future<PreferenciaComparativa> obtenerPreferencia() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cuerpo = prefs.getString(_kClaveCuerpo);
    final turno = prefs.getString(_kClaveTurno);
    if (cuerpo != null &&
        turno != null &&
        DatosConvocatoria.config(cuerpo, turno) != null) {
      return PreferenciaComparativa(cuerpo, turno);
    }
  } catch (_) {
    // preferencia corrupta o sin acceso: se ignora
  }
  return PreferenciaComparativa.porDefecto;
}

Future<void> guardarPreferencia(String cuerpo, String turno) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaveCuerpo, cuerpo);
    await prefs.setString(_kClaveTurno, turno);
  } catch (_) {
    // sin almacenamiento: no es crítico
  }
}

// ─────────────────────────────────────────────
// FÓRMULA OFICIAL
// Libre:   acierto 0,60 / error 0,15 → 1 error = 0,25 aciertos
// Interna: acierto 1,00 / error 0,25 → 1 error = 0,25 aciertos
// En ambos casos el divisor real es 4, NO 3.
// ─────────────────────────────────────────────

const double kDivisorPenalizacion = 4.0;

double divisorPenalizacion(
    [String cuerpo = 'tramitacion', String turno = 'libre']) {
  final cfg = DatosConvocatoria.config(cuerpo, turno);
  if (cfg == null) return 4.0;
  return cfg.valorAcierto / cfg.penalizacionError; // 4 en todos los vigentes
}

enum FiabilidadMuestra { baja, media, alta }

class ResultadoComparativa {
  final TurnoConvocatoria cfg;
  final String cuerpo;
  final String turno;
  final int correctas;
  final int incorrectas;
  final int total;
  final double penalizacionAciertos;
  final double puntosBrutos;
  final double notaExtrapolada;
  final bool superaPrimerEjercicio;
  final double difPrimerEjercicio;
  final double? notaProceso;
  final double? difProceso;
  final bool? obtendriaPlaza;
  final double? puntosConcursoNecesarios;
  final FiabilidadMuestra fiabilidad;

  const ResultadoComparativa({
    required this.cfg,
    required this.cuerpo,
    required this.turno,
    required this.correctas,
    required this.incorrectas,
    required this.total,
    required this.penalizacionAciertos,
    required this.puntosBrutos,
    required this.notaExtrapolada,
    required this.superaPrimerEjercicio,
    required this.difPrimerEjercicio,
    required this.notaProceso,
    required this.difProceso,
    required this.obtendriaPlaza,
    required this.puntosConcursoNecesarios,
    required this.fiabilidad,
  });
}

/// Calcula la nota extrapolada a la escala oficial del examen.
/// Devuelve null si los datos no son válidos (mismo comportamiento que la web).
ResultadoComparativa? calcularNotaOficial({
  int correctas = 0,
  int incorrectas = 0,
  int total = 0,
  String cuerpo = 'tramitacion',
  String turno = 'libre',
}) {
  final cfg = DatosConvocatoria.config(cuerpo, turno);
  if (cfg == null || total <= 0) return null;

  // Puntuación bruta con la fórmula literal del BOE, sobre las preguntas hechas
  final puntosBrutos =
      (correctas * cfg.valorAcierto) - (incorrectas * cfg.penalizacionError);

  // Extrapolación a un examen completo de 100 preguntas
  final factor = cfg.preguntasExamen / total;
  final notaExtrapolada =
      math.max(0.0, math.min(cfg.notaMaxima, puntosBrutos * factor));

  // ¿Supera el primer ejercicio?
  final superaPrimerEjercicio = notaExtrapolada >= cfg.notaCortePrimerEjercicio;
  final difPrimerEjercicio = notaExtrapolada - cfg.notaCortePrimerEjercicio;

  // Proyección al proceso completo (orientativa)
  double? notaProceso;
  bool? obtendriaPlaza;
  double? difProceso;
  double? puntosConcursoNecesarios;

  if (turno == 'libre') {
    // Se asume rendimiento equivalente en los otros dos ejercicios
    notaProceso = (notaExtrapolada / cfg.notaMaxima) * cfg.notaMaximaProceso;
    difProceso = notaProceso - cfg.notaCorteFinal;
    obtendriaPlaza = notaProceso >= cfg.notaCorteFinal;
  } else {
    // Promoción interna: la nota total depende de los méritos del concurso
    puntosConcursoNecesarios =
        math.max(0.0, cfg.notaCorteFinal - notaExtrapolada);
    obtendriaPlaza = null; // no determinable sin méritos
  }

  // Fiabilidad estadística según tamaño de la muestra
  final FiabilidadMuestra fiabilidad;
  if (total < 15) {
    fiabilidad = FiabilidadMuestra.baja;
  } else if (total < 30) {
    fiabilidad = FiabilidadMuestra.media;
  } else {
    fiabilidad = FiabilidadMuestra.alta;
  }

  return ResultadoComparativa(
    cfg: cfg,
    cuerpo: cuerpo,
    turno: turno,
    correctas: correctas,
    incorrectas: incorrectas,
    total: total,
    penalizacionAciertos: incorrectas / divisorPenalizacion(cuerpo, turno),
    puntosBrutos: puntosBrutos,
    notaExtrapolada: notaExtrapolada,
    superaPrimerEjercicio: superaPrimerEjercicio,
    difPrimerEjercicio: difPrimerEjercicio,
    notaProceso: notaProceso,
    difProceso: difProceso,
    obtendriaPlaza: obtendriaPlaza,
    puntosConcursoNecesarios: puntosConcursoNecesarios,
    fiabilidad: fiabilidad,
  );
}

class AvisoFiabilidad {
  final String icono;
  final String texto;
  const AvisoFiabilidad(this.icono, this.texto);
}

const Map<FiabilidadMuestra, AvisoFiabilidad> avisosFiabilidad = {
  FiabilidadMuestra.baja: AvisoFiabilidad('⚠️',
      'Muestra muy pequeña: con menos de 15 preguntas la extrapolación es solo orientativa. Haz tests de 50-100 preguntas para una estimación fiable.'),
  FiabilidadMuestra.media: AvisoFiabilidad('📊',
      'Muestra reducida: la extrapolación tiene margen de error. Con 30 o más preguntas la estimación gana precisión.'),
  FiabilidadMuestra.alta: AvisoFiabilidad(
      '✅', 'Muestra suficiente para una extrapolación razonablemente fiable.'),
};

/// Formato español: 50.00 → "50,00" (equivalente al helper fmt() de la web)
String fmtNota(num n, [int decimales = 2]) =>
    n.toStringAsFixed(decimales).replaceAll('.', ',');
