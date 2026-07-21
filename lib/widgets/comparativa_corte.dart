// comparativa_corte.dart — Bloque "¿Habrías aprobado la oposición?"
// Equivalente móvil de generarBloqueComparativa() de js/notas-corte.js.
// Mismos textos, mismos umbrales de fiabilidad y mismo cálculo.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/notas_corte.dart';

class ComparativaCorte extends StatefulWidget {
  final int correctas;
  final int incorrectas;
  final int total;

  const ComparativaCorte({
    super.key,
    required this.correctas,
    required this.incorrectas,
    required this.total,
  });

  @override
  State<ComparativaCorte> createState() => _ComparativaCorteState();
}

class _ComparativaCorteState extends State<ComparativaCorte> {
  PreferenciaComparativa _pref = PreferenciaComparativa.porDefecto;
  bool _cargando = true;

  // Las 4 combinaciones cuerpo · turno
  static const List<PreferenciaComparativa> _opciones = [
    PreferenciaComparativa('tramitacion', 'libre'),
    PreferenciaComparativa('tramitacion', 'interna'),
    PreferenciaComparativa('gestion', 'libre'),
    PreferenciaComparativa('gestion', 'interna'),
  ];

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  Future<void> _cargarPreferencia() async {
    final pref = await obtenerPreferencia();
    if (mounted) {
      setState(() {
        _pref = pref;
        _cargando = false;
      });
    }
  }

  String _claveDe(PreferenciaComparativa p) => '${p.cuerpo}|${p.turno}';

  String _etiquetaDe(PreferenciaComparativa p) {
    final cuerpo = DatosConvocatoria.cuerpos[p.cuerpo]!.nombreCorto;
    final turno = p.turno == 'libre' ? 'Libre' : 'P. interna';
    return '$cuerpo · $turno';
  }

  Color get _colorAviso {
    final r = _resultado;
    if (r == null) return AppColors.neutral;
    switch (r.fiabilidad) {
      case FiabilidadMuestra.baja:
        return AppColors.error;
      case FiabilidadMuestra.media:
        return const Color(0xFFF0932B);
      case FiabilidadMuestra.alta:
        return AppColors.success;
    }
  }

  ResultadoComparativa? get _resultado => calcularNotaOficial(
        correctas: widget.correctas,
        incorrectas: widget.incorrectas,
        total: widget.total,
        cuerpo: _pref.cuerpo,
        turno: _pref.turno,
      );

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();

    final r = _resultado;
    if (r == null) return const SizedBox.shrink();

    final colorVeredicto =
        r.superaPrimerEjercicio ? AppColors.success : AppColors.error;
    final aviso = avisosFiabilidad[r.fiabilidad]!;

    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '🎯 ¿Habrías aprobado la oposición?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── Selector cuerpo · turno ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _claveDe(_pref),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.expand_more, color: AppColors.primary),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  items: _opciones
                      .map((o) => DropdownMenuItem<String>(
                            value: _claveDe(o),
                            child: Text(_etiquetaDe(o)),
                          ))
                      .toList(),
                  onChanged: (valor) {
                    if (valor == null) return;
                    final partes = valor.split('|');
                    setState(() =>
                        _pref = PreferenciaComparativa(partes[0], partes[1]));
                    guardarPreferencia(partes[0], partes[1]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── NIVEL 1: primer ejercicio ──
            _bloqueNivel(
              colorBorde: colorVeredicto,
              cabecera: '1º ejercicio (test)',
              hijos: [
                Text(
                  r.superaPrimerEjercicio ? '✅ SUPERADO' : '❌ NO SUPERADO',
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: colorVeredicto,
                  ),
                ),
                const SizedBox(height: 8),
                _linea(
                  'Tu nota extrapolada: ',
                  '${fmtNota(r.notaExtrapolada)} / ${r.cfg.notaMaxima.toStringAsFixed(0)}',
                ),
                _linea(
                  'Mínimo exigido: ',
                  '${fmtNota(r.cfg.notaCortePrimerEjercicio, 0)} / ${r.cfg.notaMaxima.toStringAsFixed(0)}',
                  pie: '(${r.cfg.tipoCorte})',
                ),
                const SizedBox(height: 6),
                Text(
                  r.difPrimerEjercicio >= 0
                      ? '+${fmtNota(r.difPrimerEjercicio)} por encima del mínimo'
                      : 'Te faltan ${fmtNota(r.difPrimerEjercicio.abs())} puntos',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorVeredicto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── NIVEL 2: plaza ──
            if (r.turno == 'libre')
              _bloqueNivel(
                colorBorde: r.obtendriaPlaza == true
                    ? AppColors.success
                    : AppColors.error,
                cabecera: '¿Plaza?',
                tag: 'orientativo',
                hijos: [
                  Text(
                    r.obtendriaPlaza == true
                        ? '🏅 HABRÍAS COGIDO PLAZA'
                        : '📉 FUERA DE PLAZA',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: r.obtendriaPlaza == true
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _linea(
                    'Proyección al proceso completo: ',
                    '${fmtNota(r.notaProceso!)} / ${r.cfg.notaMaximaProceso.toStringAsFixed(0)}',
                  ),
                  _linea(
                    'Última plaza en ${DatosConvocatoria.ambitoCorto}: ',
                    '${fmtNota(r.cfg.notaCorteFinal)} / ${r.cfg.notaMaximaProceso.toStringAsFixed(0)}',
                    pie: '(${r.cfg.plazasAmbito} plazas)',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.difProceso! >= 0
                        ? '+${fmtNota(r.difProceso!)} sobre la última plaza'
                        : 'Te faltarían ${fmtNota(r.difProceso!.abs())} puntos',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: r.obtendriaPlaza == true
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _supuesto(
                      'Asume un rendimiento equivalente en el 2º y 3er ejercicio.'),
                ],
              )
            else
              _bloqueNivel(
                colorBorde: AppColors.neutral,
                cabecera: '¿Plaza?',
                tag: 'depende del concurso',
                hijos: [
                  _linea(
                    'Última plaza en ${DatosConvocatoria.ambitoCorto}: ',
                    '${fmtNota(r.cfg.notaCorteFinal)} / ${r.cfg.notaMaximaProceso.toStringAsFixed(0)}',
                  ),
                  _linea(
                    'Con esta nota de oposición necesitarías ',
                    fmtNota(r.puntosConcursoNecesarios!),
                    cola: ' puntos de méritos',
                    pie: '(máx. 65)',
                  ),
                  const SizedBox(height: 8),
                  _supuesto(
                      'En promoción interna la nota total depende fuertemente de la antigüedad y titulación.'),
                ],
              ),
            const SizedBox(height: 12),

            // ── Aviso de fiabilidad ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _colorAviso, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${aviso.icono} ${aviso.texto}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.5,
                  color: _colorAviso,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Pie con procedencia del dato ──
            Text(
              'Datos: ${DatosConvocatoria.etiqueta} · ${DatosConvocatoria.boe} · ${DatosConvocatoria.ambito}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers de maquetación ──

  Widget _bloqueNivel({
    required Color colorBorde,
    required String cabecera,
    required List<Widget> hijos,
    String? tag,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de color (equivalente al border-left del CSS)
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: colorBorde,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cabecera.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  letterSpacing: 0.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...hijos,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linea(String etiqueta, String valor, {String? cola, String? pie}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(text: etiqueta),
            TextSpan(
              text: valor,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (cola != null) TextSpan(text: cola),
            if (pie != null)
              TextSpan(
                text: ' $pie',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _supuesto(String texto) {
    return Text(
      texto,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
      ),
    );
  }
}
