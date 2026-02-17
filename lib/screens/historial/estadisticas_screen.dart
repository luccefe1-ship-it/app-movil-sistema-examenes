import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historial = [];

  // Datos procesados
  double _notaMedia = 0;
  List<FlSpot> _spots = [];
  List<String> _fechasEje = [];
  List<_TemaStat> _temasOrdenados = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final authService = context.read<AuthService>();
    final testService = context.read<TestService>();
    if (authService.userId == null) return;

    final historial = await testService.getHistorial(authService.userId!);
    if (!mounted) return;

    setState(() {
      _historial = historial;
      _procesarDatos();
      _isLoading = false;
    });
  }

  void _procesarDatos() {
    if (_historial.isEmpty) return;

    // ── NOTA MEDIA ──────────────────────────────
    final puntuaciones = _historial
        .map((t) => (t['puntuacion'] ?? t['porcentaje'] ?? 0) as num)
        .toList();
    _notaMedia = puntuaciones.isEmpty
        ? 0
        : puntuaciones.reduce((a, b) => a + b) / puntuaciones.length;

    // ── GRÁFICO EVOLUCIÓN (hasta hoy, cronológico) ──
    final conFecha = _historial
        .where((t) => t['fechaCreacion'] != null)
        .toList()
        .reversed
        .toList(); // más antiguo primero

    _spots = [];
    _fechasEje = [];
    for (int i = 0; i < conFecha.length; i++) {
      final t = conFecha[i];
      final pts =
          ((t['puntuacion'] ?? t['porcentaje'] ?? 0) as num).toDouble();
      _spots.add(FlSpot(i.toDouble(), pts));
      try {
        final fecha = t['fechaCreacion'].toDate() as DateTime;
        _fechasEje.add(DateFormat('dd/MM').format(fecha));
      } catch (_) {
        _fechasEje.add('');
      }
    }

    // ── ANÁLISIS POR TEMAS ───────────────────────
    final Map<String, _TemaStat> temaMap = {};

    for (final test in _historial) {
      final detalles =
          test['detalleRespuestas'] as List<dynamic>? ?? [];
      for (final d in detalles) {
        final det = d as Map<String, dynamic>;
        final temaNombre =
            (det['temaNombre'] as String?)?.trim() ?? '';
        if (temaNombre.isEmpty) continue;

        final estado = det['estado'] as String? ?? '';
        temaMap.putIfAbsent(temaNombre, () => _TemaStat(temaNombre));
        temaMap[temaNombre]!.total++;
        if (estado == 'correcta') {
          temaMap[temaNombre]!.correctas++;
        } else if (estado == 'incorrecta') {
          temaMap[temaNombre]!.incorrectas++;
        }
      }
    }

    _temasOrdenados = temaMap.values
        .where((t) => t.total >= 3)
        .toList()
      ..sort((a, b) => a.porcentajeFallo.compareTo(b.porcentajeFallo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Estadísticas',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _historial.isEmpty
              ? Center(
                  child: Text('Aún no hay tests realizados.',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 16)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotaMedia(),
                      const SizedBox(height: 20),
                      _buildGraficoEvolucion(),
                      const SizedBox(height: 20),
                      _buildAnalisisTemas(),
                    ],
                  ),
                ),
    );
  }

  // ── NOTA MEDIA ────────────────────────────────
  Widget _buildNotaMedia() {
    final color = _notaMedia >= 50 ? AppColors.success : AppColors.error;
    return Card(
      color: AppColors.cardBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nota media global',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('${_notaMedia.toStringAsFixed(1)} pts',
                      style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text('sobre ${_historial.length} test${_historial.length != 1 ? 's' : ''} realizados',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(
                _notaMedia >= 50
                    ? Icons.emoji_events
                    : Icons.trending_up,
                color: color,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GRÁFICO EVOLUCIÓN ─────────────────────────
  Widget _buildGraficoEvolucion() {
    if (_spots.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppColors.cardBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16),
              child: Text('Evolución de la puntuación',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: _spots.length <= 10,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _fechasEje.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _fechasEje[i],
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: AppColors.textSecondary),
                            ),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: _spots.length <= 20,
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeColor: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                    // Línea de referencia en 50
                    LineChartBarData(
                      spots: [
                        FlSpot(0, 50),
                        FlSpot((_spots.length - 1).toDouble(), 50),
                      ],
                      isCurved: false,
                      color: AppColors.neutral.withOpacity(0.4),
                      barWidth: 1,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ANÁLISIS DE TEMAS ─────────────────────────
  Widget _buildAnalisisTemas() {
    if (_temasOrdenados.isEmpty) {
      return Card(
        color: AppColors.cardBackground,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Necesitas más tests para generar un análisis por temas.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final mejores = _temasOrdenados
        .where((t) => t.porcentajeFallo < 25)
        .take(3)
        .toList();
    final peores = _temasOrdenados.reversed
        .where((t) => t.porcentajeFallo >= 30)
        .take(3)
        .toList();

    final analisis = _generarAnalisis(mejores, peores);

    return Card(
      color: AppColors.cardBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Análisis del profesor',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              analisis,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.7,
                  color: AppColors.textSecondary),
            ),
            if (peores.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTemasList(
                  '🔴 Temas a reforzar', peores, AppColors.error),
            ],
            if (mejores.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTemasList(
                  '🟢 Temas dominados', mejores, AppColors.success),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemasList(
      String titulo, List<_TemaStat> temas, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        ...temas.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.nombre,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${t.porcentajeAcierto.toStringAsFixed(0)}% acierto',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _generarAnalisis(
      List<_TemaStat> mejores, List<_TemaStat> peores) {
    final totalTests = _historial.length;
    final nota = _notaMedia;
    final tendencia = _calcularTendencia();

    String texto = '';

    // Valoración general
    if (nota >= 70) {
      texto +=
          'Tu rendimiento global es muy sólido, con una media de ${nota.toStringAsFixed(1)} puntos sobre 100. ';
    } else if (nota >= 50) {
      texto +=
          'Tu rendimiento es aceptable, con una media de ${nota.toStringAsFixed(1)} puntos. Estás en la línea de aprobado, pero hay margen de mejora. ';
    } else {
      texto +=
          'Tu media actual de ${nota.toStringAsFixed(1)} puntos indica que aún queda trabajo por hacer. No te desanimes, el análisis siguiente te orientará. ';
    }

    // Tendencia
    if (tendencia > 5) {
      texto +=
          'Además, tu tendencia en los últimos tests es claramente ascendente, lo que demuestra que el estudio está dando resultados. ';
    } else if (tendencia < -5) {
      texto +=
          'Sin embargo, tus últimas puntuaciones muestran una tendencia descendente. Puede ser señal de fatiga o de que necesitas consolidar mejor los temas recientes. ';
    }

    // Temas débiles
    if (peores.isNotEmpty) {
      final nombresDebiles =
          peores.map((t) => '"${t.nombre}"').join(', ');
      texto +=
          'Los temas que más atención requieren son $nombresDebiles. En ellos tu tasa de error es significativa y conviene dedicarles sesiones específicas de repaso. ';
    }

    // Temas fuertes
    if (mejores.isNotEmpty) {
      final nombresFuertes =
          mejores.map((t) => '"${t.nombre}"').join(', ');
      texto +=
          'Por otro lado, demuestras un buen dominio en $nombresFuertes, donde tus aciertos son consistentes. ';
    }

    // Consejo final
    if (totalTests < 5) {
      texto +=
          'Lleva $totalTests test${totalTests != 1 ? 's' : ''} realizados. Cuantos más hagas, más preciso será este análisis.';
    } else if (peores.isNotEmpty) {
      texto +=
          'La recomendación es usar la opción de "Repaso de Fallos" con regularidad y hacer tests específicos de los temas débiles identificados.';
    } else {
      texto +=
          'Sigue manteniendo el ritmo de estudio y practica con tests mixtos para afianzar el conjunto del temario.';
    }

    return texto;
  }

  double _calcularTendencia() {
    if (_spots.length < 4) return 0;
    final ultimos =
        _spots.sublist(_spots.length - 4).map((s) => s.y).toList();
    final primeros = _spots.sublist(0, 4).map((s) => s.y).toList();
    final mediaUltimos =
        ultimos.reduce((a, b) => a + b) / ultimos.length;
    final mediaPrimeros =
        primeros.reduce((a, b) => a + b) / primeros.length;
    return mediaUltimos - mediaPrimeros;
  }
}

class _TemaStat {
  final String nombre;
  int total = 0;
  int correctas = 0;
  int incorrectas = 0;

  _TemaStat(this.nombre);

  double get porcentajeFallo =>
      total == 0 ? 0 : (incorrectas / total) * 100;
  double get porcentajeAcierto =>
      total == 0 ? 0 : (correctas / total) * 100;
}
