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

    // Agrupar por semana y calcular media
    final Map<int, List<double>> porSemana = {};
    final Map<int, DateTime> fechaPorSemana = {};

    for (final t in conFecha) {
      try {
        final fecha = t['fechaCreacion'].toDate() as DateTime;
        final semana =
            fecha.year * 100 + ((fecha.month - 1) * 30 + fecha.day) ~/ 7;
        final pts =
            ((t['puntuacion'] ?? t['porcentaje'] ?? 0) as num).toDouble();
        porSemana.putIfAbsent(semana, () => []).add(pts);
        fechaPorSemana.putIfAbsent(semana, () => fecha);
      } catch (_) {}
    }

    final semanasOrdenadas = porSemana.keys.toList()..sort();
    _spots = [];
    _fechasEje = [];

    for (int i = 0; i < semanasOrdenadas.length; i++) {
      final semana = semanasOrdenadas[i];
      final valores = porSemana[semana]!;
      final media = valores.reduce((a, b) => a + b) / valores.length;
      _spots.add(FlSpot(i.toDouble(), media));
      final fecha = fechaPorSemana[semana]!;
      _fechasEje.add(DateFormat('dd/MM').format(fecha));
    }
    // ── ANÁLISIS POR TEMAS ───────────────────────
    final Map<String, _TemaStat> temaMap = {};

    for (final test in _historial) {
      final detalles = test['detalleRespuestas'] as List<dynamic>? ?? [];
      for (final d in detalles) {
        final det = d as Map<String, dynamic>;
        final temaNombre = (det['temaNombre'] as String?)?.trim() ?? '';
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

    _temasOrdenados = temaMap.values.toList()
      ..sort((a, b) => a.porcentajeFallo.compareTo(b.porcentajeFallo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Estadísticas',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('${_notaMedia.toStringAsFixed(1)} pts',
                      style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(
                      'sobre ${_historial.length} test${_historial.length != 1 ? 's' : ''} realizados',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                _notaMedia >= 50 ? Icons.emoji_events : Icons.trending_up,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: Colors.grey.withValues(alpha: 0.15),
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
                              fontSize: 10, color: AppColors.textSecondary),
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
                                  fontSize: 9, color: AppColors.textSecondary),
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
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeColor: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    // Línea de referencia en 50
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 50),
                        FlSpot((_spots.length - 1).toDouble(), 50),
                      ],
                      isCurved: false,
                      color: AppColors.neutral.withValues(alpha: 0.4),
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
    // Tomar los 3 peores (más fallos) y los 3 mejores (menos fallos)
    final peores = _temasOrdenados.reversed.take(3).toList();
    final mejores = _temasOrdenados.take(3).toList();

    final analisis = _generarAnalisis(mejores, peores);

    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  fontSize: 13.5, height: 1.7, color: AppColors.textSecondary),
            ),
            if (peores.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTemasList('🔴 Temas a reforzar', peores, AppColors.error),
            ],
            if (mejores.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTemasList('🟢 Temas dominados', mejores, AppColors.success),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemasList(String titulo, List<_TemaStat> temas, Color color) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
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

  String _generarAnalisis(List<_TemaStat> mejores, List<_TemaStat> peores) {
    final totalTests = _historial.length;
    final nota = _notaMedia;
    final tendencia = _calcularTendencia();
    int seed = DateTime.now().millisecondsSinceEpoch;

    String pick(List<String> opciones) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      return opciones[seed.abs() % opciones.length];
    }

    String texto = '';

    // Valoración general
    if (nota >= 80) {
      texto += pick([
        'Excelente trabajo. Con ${nota.toStringAsFixed(1)} puntos de media estás en un nivel muy alto para este tipo de oposición. ',
        'Los números hablan por sí solos: ${nota.toStringAsFixed(1)} puntos de media es un resultado sobresaliente que pocos alcanzan en esta fase. ',
        'Un ${nota.toStringAsFixed(1)} de media es una marca que refleja constancia y solidez en el estudio. Vas por el buen camino. ',
        'Con ${nota.toStringAsFixed(1)} de media estás claramente entre los candidatos mejor preparados. Eso no se consigue sin esfuerzo real. ',
        'Pocas personas llegan al ${nota.toStringAsFixed(1)} de media en tests de este nivel. Lo que estás haciendo está funcionando, no lo cambies. ',
        'Un ${nota.toStringAsFixed(1)} de media en este punto de la preparación es una señal muy positiva. El trabajo constante se nota en los resultados. ',
        '${nota.toStringAsFixed(1)} puntos de media. Eso no es suerte, es preparación. Sigue así y el día del examen estarás en condiciones óptimas. ',
        'Estás rindiendo a un nivel alto: ${nota.toStringAsFixed(1)} de media es una cifra que muchos opositores no alcanzan ni al final de su preparación. ',
      ]);
    } else if (nota >= 65) {
      texto += pick([
        'Con ${nota.toStringAsFixed(1)} puntos de media tienes una base sólida. Estás claramente por encima del aprobado, aunque siempre hay margen para subir más. ',
        'Tu media de ${nota.toStringAsFixed(1)} es buena, aunque en oposiciones de este nivel la diferencia entre aprobar y no hacerlo suele estar en los detalles. ',
        'Un ${nota.toStringAsFixed(1)} de media es un buen punto de partida. Con trabajo específico en los puntos débiles puedes mejorar ese número considerablemente. ',
        'Con ${nota.toStringAsFixed(1)} de media estás por encima de la línea, pero en una oposición competitiva eso no siempre es suficiente. Queda margen. ',
        'Un ${nota.toStringAsFixed(1)} habla de alguien que conoce el temario. El siguiente escalón es dominarlo, y eso se consigue atacando los temas que más fallan. ',
        'Estás bien, con ${nota.toStringAsFixed(1)} de media. Pero "bien" en una oposición es el punto de partida, no el destino. Hay que seguir apretando. ',
        'Tu ${nota.toStringAsFixed(1)} de media refleja una preparación real. Con ajustes en los puntos débiles identificados, ese número puede subir varios puntos. ',
        '${nota.toStringAsFixed(1)} de media es un nivel competitivo. Los pequeños detalles y los temas que más se te resisten son los que marcarán la diferencia final. ',
      ]);
    } else if (nota >= 50) {
      texto += pick([
        'Estás en la línea del aprobado con ${nota.toStringAsFixed(1)} puntos, pero en una oposición real necesitas un colchón mayor. Toca apretar. ',
        'Con ${nota.toStringAsFixed(1)} de media apruebas, pero no con comodidad. Los temas que más fallas te están costando puntos que puedes recuperar. ',
        'Un ${nota.toStringAsFixed(1)} de media indica que el temario lo conoces, pero no lo dominas todavía. La diferencia está en los flecos. ',
        'Con ${nota.toStringAsFixed(1)} estás aprobando, pero en una oposición cualquier imprevisto el día del examen puede cambiar el resultado. Necesitas más margen. ',
        'El ${nota.toStringAsFixed(1)} de media dice que estás en el camino correcto, pero que el ritmo actual no es suficiente para estar tranquilo. Hay que subir. ',
        'Un ${nota.toStringAsFixed(1)} es un punto de partida honesto. No es ni para alarmarse ni para conformarse. Es para trabajar los puntos concretos que te están bajando la nota. ',
        'Con ${nota.toStringAsFixed(1)} de media el temario no es el problema, el problema son esos temas específicos donde los fallos se acumulan. Atacarlos tiene un impacto inmediato. ',
        'Estás aprobando con ${nota.toStringAsFixed(1)}, pero en oposiciones la nota importa tanto como el aprobado. Subir esa media vale el esfuerzo. ',
      ]);
    } else {
      texto += pick([
        'Tu media de ${nota.toStringAsFixed(1)} puntos dice que todavía queda camino por recorrer. Eso no es malo: significa que hay mucho margen de mejora. ',
        'Con ${nota.toStringAsFixed(1)} de media el nivel no es el necesario todavía, pero con los tests que llevas hechos ya tienes información muy valiosa para saber dónde actuar. ',
        'Un ${nota.toStringAsFixed(1)} de media en este punto del estudio es perfectamente recuperable. Lo importante ahora es identificar los bloques más flojos y atacarlos. ',
        'El ${nota.toStringAsFixed(1)} de media actual no refleja tu techo, sino tu punto de partida. Con un trabajo más focalizado en los temas débiles, esa cifra puede cambiar rápido. ',
        'Con ${nota.toStringAsFixed(1)} de media el diagnóstico es claro: hay temas que necesitan mucho más trabajo. La buena noticia es que tienes los datos para saber cuáles son. ',
        'Un ${nota.toStringAsFixed(1)} es una señal de que el estudio todavía no ha calado lo suficiente en algunos bloques clave. Identificarlos y trabajarlos de forma específica es el paso siguiente. ',
        'No te quedes con el número: ${nota.toStringAsFixed(1)} de media es información, no una sentencia. Úsala para decidir dónde poner el foco a partir de ahora. ',
        'Con ${nota.toStringAsFixed(1)} de media hay trabajo por hacer, pero lo más valioso es que ya tienes un diagnóstico claro de dónde están los agujeros. Eso vale mucho. ',
      ]);
    }

    // Tendencia
    if (tendencia > 8) {
      texto += pick([
        'Además, tu evolución reciente es muy positiva: las últimas semanas estás claramente por encima de tu propio nivel anterior. ',
        'Lo que más destaca es la tendencia ascendente de tus últimos resultados. Eso indica que el método de estudio actual te está funcionando. ',
        'Tu progresión reciente es uno de los puntos más positivos del análisis. Llevas varias semanas mejorando de forma consistente. ',
        'La gráfica lo dice todo: estás en plena progresión. Lo que estás haciendo en las últimas semanas está dando resultados muy tangibles. ',
        'Tu evolución reciente es notable. No todo el mundo es capaz de mantener una curva ascendente sostenida, y tú lo estás logrando. ',
        'Los últimos resultados están claramente por encima de tu media histórica. Eso es una señal de que algo en tu método de estudio ha mejorado. ',
      ]);
    } else if (tendencia > 3) {
      texto += pick([
        'Tu tendencia reciente apunta ligeramente hacia arriba, lo que es una señal positiva aunque discreta. ',
        'Se aprecia una ligera mejora en los últimos resultados. Si mantienes el ritmo, esa tendencia debería consolidarse. ',
        'La dirección es buena: los últimos tests están por encima de tu media anterior. Pequeñas mejoras sostenidas acaban siendo grandes diferencias. ',
        'Hay una mejora sutil pero real en los resultados recientes. No es espectacular, pero la dirección es la correcta. ',
        'Los últimos resultados apuntan hacia arriba. No es un cambio brusco, pero es estable, y eso vale más que un pico puntual. ',
      ]);
    } else if (tendencia < -8) {
      texto += pick([
        'Sin embargo, tus últimas semanas muestran una caída notable respecto a tu nivel previo. Puede ser cansancio acumulado o que los temas recientes son más difíciles para ti. ',
        'La tendencia reciente es preocupante: estás bajando. Antes de seguir avanzando en temario nuevo, puede que valga la pena consolidar lo que ya has estudiado. ',
        'Tus resultados recientes están por debajo de tu media histórica. Merece la pena revisar el ritmo de estudio y si estás dedicando suficiente tiempo al repaso. ',
        'La gráfica muestra una bajada clara en las últimas semanas. Puede ser un bache puntual, pero si se mantiene hay que revisar qué está fallando en el proceso. ',
        'Algo ha cambiado en las últimas semanas y los resultados lo reflejan. Antes de seguir hacia adelante, puede que lo más inteligente sea hacer un repaso general de lo estudiado. ',
        'La caída reciente en los resultados no debería ignorarse. A veces es señal de que el ritmo es demasiado alto y el cerebro necesita consolidar antes de avanzar más. ',
      ]);
    } else if (tendencia < -3) {
      texto += pick([
        'Se aprecia una ligera bajada en los últimos resultados. No es alarmante, pero conviene vigilarlo. ',
        'Los últimos tests están un poco por debajo de tu media habitual. Podría ser algo puntual o una señal de que necesitas reforzar los temas recientes. ',
        'Hay una pequeña tendencia descendente en las últimas semanas. Puede ser algo pasajero, pero vale la pena prestarle atención antes de que vaya a más. ',
        'Los resultados recientes han bajado ligeramente. No es una alarma, pero sí una señal para revisar si hay temas nuevos que no están acabando de asentarse. ',
        'Una bajada leve en los últimos resultados. Antes de preocuparse, conviene ver si coincide con temas más difíciles o con menos tiempo de estudio esas semanas. ',
      ]);
    } else {
      texto += pick([
        'Tu evolución es estable, sin grandes altibajos. Eso refleja una preparación sólida y constante. ',
        'Los resultados se mantienen estables. En una preparación larga, la consistencia es tan valiosa como los picos altos. ',
        'Tu nivel se mantiene regular a lo largo del tiempo. Eso habla de una base sólida sobre la que seguir construyendo. ',
      ]);
    }

    // Temas débiles
    if (peores.isNotEmpty) {
      final n = peores.map((t) => '"${t.nombre}"').join(', ');
      texto += pick([
        'En cuanto a los puntos débiles, los temas $n son los que más fallos acumulan. No es casualidad: son los que necesitan más tiempo de tu agenda de repaso. ',
        'Los temas $n aparecen como los más problemáticos en tu historial. Dedicarles una sesión específica puede tener un impacto directo en tu nota. ',
        'Si tuvieras que elegir por dónde empezar a mejorar, los temas $n serían la respuesta. Son donde más puntos se te están escapando. ',
        'Hay un patrón claro de fallos en $n. Esto no significa que no los sepas, sino que quizás no los tienes tan afianzados como crees. Un repaso focalizado marcaría la diferencia. ',
        'Los datos apuntan a $n como tus talones de Aquiles. Cada vez que aparece una pregunta de esos temas, las probabilidades de fallo aumentan considerablemente. ',
        'Si quieres subir nota de forma eficiente, $n son el punto de partida. Ahí es donde tu esfuerzo tiene mayor retorno. ',
        'Los temas $n son los que más te están costando según el historial. No es un juicio, es un dato. Y los datos sirven para actuar. ',
        'En $n los fallos son recurrentes. Puede que la forma en que los has estudiado no sea la más efectiva para ti. Vale la pena probar otro enfoque con esos temas. ',
        'El análisis es claro: $n necesitan más trabajo. No porque sean imposibles, sino porque todavía no han calado del todo. Una sesión específica y focalizada puede cambiarlo. ',
      ]);
    }

    // Temas fuertes
    if (mejores.isNotEmpty) {
      final n = mejores.map((t) => '"${t.nombre}"').join(', ');
      texto += pick([
        'Por el lado positivo, $n son tus temas más sólidos. Puedes confiar en ellos cuando llegue el momento. ',
        'Donde realmente destacas es en $n. Ahí tu tasa de acierto es alta y consistente. ',
        'Los temas $n los llevas bien. Eso te da una base sobre la que construir el resto del temario. ',
        'En $n tu rendimiento es claramente superior. Son tu zona de confort dentro del temario y una fuente segura de puntos el día del examen. ',
        'Los temas $n son tu punto fuerte. No los descuides del todo, pero puedes dedicarles menos tiempo y centrarte en lo que más falla. ',
        'Cuando aparecen preguntas de $n, tu tasa de acierto es alta. Eso se traduce en puntos seguros el día que de verdad importa. ',
        'Dominas $n con claridad. Eso no se da por sentado: hay candidatos que nunca llegan a ese nivel de solidez en esos temas. ',
        'Los datos confirman que $n son tus temas más sólidos. Mantén ese nivel con repasos periódicos y tendrás esa parte del examen prácticamente resuelta. ',
        'En $n el trabajo está hecho. Ahora toca usar ese tiempo liberado para atacar las zonas más débiles del temario. ',
      ]);
    }

    // Consejo final
    if (totalTests < 5) {
      texto += pick([
        'Llevas $totalTests test${totalTests != 1 ? 's' : ''} realizados. Este análisis irá siendo más preciso según acumules más datos.',
        'Con $totalTests test${totalTests != 1 ? 's' : ''} el análisis es orientativo. Cuantos más hagas, más fiable será el diagnóstico.',
        'Todavía es pronto para extraer conclusiones definitivas con $totalTests test${totalTests != 1 ? 's' : ''}. Sigue practicando y el análisis irá afinándose.',
        'Con $totalTests test${totalTests != 1 ? 's' : ''} tenemos un primer vistazo, pero nada más. La foto completa aparece con más datos acumulados.',
      ]);
    } else if (peores.isNotEmpty) {
      texto += pick([
        'La estrategia más eficiente ahora mismo: tests cortos y frecuentes centrados en los temas débiles identificados, combinados con el repaso de fallos.',
        'Mi recomendación: no avances más temario nuevo hasta consolidar los puntos débiles detectados. Los cimientos importan.',
        'Usa el modo de "Repaso de Fallos" con regularidad. Es la forma más directa de convertir tus errores en puntos ganados.',
        'El camino más corto para subir nota pasa por esos temas débiles. Atacarlos de forma específica tiene un impacto mucho mayor que hacer más tests generales.',
        'Tests específicos sobre los temas problemáticos, combinados con repaso de fallos. Esa combinación es la más eficaz en este punto de la preparación.',
        'No hace falta estudiar más horas, hace falta estudiar mejor. Y estudiar mejor ahora mismo significa enfocarse en los temas que más se resisten.',
        'Convierte los fallos en rutina de repaso. Cada pregunta que fallas es una oportunidad de aprender algo que antes no tenías claro.',
        'La clave no es hacer más tests, sino hacer los tests adecuados. Y los adecuados ahora son los que atacan directamente los temas donde más fallas.',
      ]);
    } else {
      texto += pick([
        'Estás en un buen momento. Mantén el ritmo y no descuides los temas que llevas bien: la memoria necesita refuerzo periódico.',
        'El nivel es bueno. La clave ahora es no relajarse y seguir haciendo tests mixtos para no perder lo que ya tienes.',
        'Cuando el nivel es alto el riesgo es la confianza excesiva. Sigue practicando con regularidad para llegar al examen con todo fresco.',
        'Todo apunta bien. En esta fase lo más importante es mantener la consistencia y no dejar que ningún tema se oxide por falta de repaso.',
        'Estás preparado. Ahora toca mantenerse: tests regulares, repasos periódicos y cabeza fría. El trabajo ya está hecho en gran parte.',
        'El nivel que tienes se mantiene con práctica constante. No hace falta cambiar nada, solo seguir con lo que está funcionando.',
        'En este punto de la preparación el objetivo es consolidar, no acelerar. Sigue a este ritmo y llegarás al examen en tu mejor versión.',
        'Cuando se está bien preparado, el enemigo es la confianza. Sigue haciendo tests con regularidad y trata cada uno como si fuera el real.',
      ]);
    }

    return texto;
  }

  double _calcularTendencia() {
    if (_spots.length < 4) return 0;
    final ultimos = _spots.sublist(_spots.length - 4).map((s) => s.y).toList();
    final primeros = _spots.sublist(0, 4).map((s) => s.y).toList();
    final mediaUltimos = ultimos.reduce((a, b) => a + b) / ultimos.length;
    final mediaPrimeros = primeros.reduce((a, b) => a + b) / primeros.length;
    return mediaUltimos - mediaPrimeros;
  }
}

class _TemaStat {
  final String nombre;
  int total = 0;
  int correctas = 0;
  int incorrectas = 0;

  _TemaStat(this.nombre);

  double get porcentajeFallo => total == 0 ? 0 : (incorrectas / total) * 100;
  double get porcentajeAcierto => total == 0 ? 0 : (correctas / total) * 100;
}
