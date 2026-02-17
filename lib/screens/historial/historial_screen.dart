import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../../services/temas_service.dart';
import '../test/detalle_test_screen.dart';
import 'estadisticas_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<Map<String, dynamic>> _historial = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final authService = context.read<AuthService>();
    final testService = context.read<TestService>();

    if (authService.userId != null) {
      final historial = await testService.getHistorial(authService.userId!);
      if (mounted) {
        setState(() {
          _historial = historial;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarTest(String testId, int index) async {
    final testService = context.read<TestService>();
    final success = await testService.eliminarResultado(testId);

    if (!mounted) return;

    if (success) {
      setState(() {
        _historial.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test eliminado', style: GoogleFonts.inter()),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar el test', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmarEliminacion(String testId, int index, String nombreTest) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Eliminar test',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        content: Text(
          '¿Eliminar "$nombreTest"?\n\nEsta acción no se puede deshacer.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancelar', style: TextStyle(color: AppColors.neutral)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarTest(testId, index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Historial de Tests',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Estadísticas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EstadisticasScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary))
          : _historial.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 80, color: AppColors.neutral),
                      const SizedBox(height: 16),
                      Text(
                        'No hay tests realizados',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarHistorial,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historial.length,
                    itemBuilder: (context, index) {
                      final test = _historial[index];
                      return _buildTestCard(test, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test, int index) {
    final testData = test['test'] as Map<String, dynamic>? ?? {};
    final nombre = testData['nombre'] ?? 'Test sin nombre';
    final correctas = test['correctas'] ?? 0;
    final incorrectas = test['incorrectas'] ?? 0;
    final total = test['total'] ?? 0;
    final puntuacion = test['puntuacion'] ?? 0;
    final fecha = test['fechaCreacion'];

    String fechaTexto = 'Sin fecha';
    if (fecha != null) {
      try {
        final fechaDt = fecha.toDate();
        fechaTexto = DateFormat('dd/MM/yyyy HH:mm').format(fechaDt);
      } catch (e) {
        fechaTexto = 'Fecha inválida';
      }
    }

    return Dismissible(
      key: Key(test['id'] ?? 'test_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        _confirmarEliminacion(test['id'], index, nombre);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: Card(
        color: AppColors.cardBackground,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            final temasService = context.read<TemasService>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalleTestHistorialScreen(
                  testData: test,
                  temasService: temasService,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fechaTexto,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: puntuacion >= 50
                                  ? AppColors.success.withOpacity(0.2)
                                  : AppColors.neutral.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$puntuacion pts',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: puntuacion >= 50
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.check_circle,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('$correctas',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.success)),
                          const SizedBox(width: 8),
                          Icon(Icons.cancel,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text('$incorrectas',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.error)),
                          const SizedBox(width: 4),
                          Text('/ $total',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _confirmarEliminacion(test['id'], index, nombre),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                ),
                Icon(Icons.chevron_right, color: AppColors.neutral),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetalleTestHistorialScreen extends StatelessWidget {
  final Map<String, dynamic> testData;
  final TemasService temasService;

  const DetalleTestHistorialScreen({
    super.key,
    required this.testData,
    required this.temasService,
  });

  @override
  Widget build(BuildContext context) {
    final testInfo = testData['test'] as Map<String, dynamic>? ?? {};
    final nombre = testInfo['nombre'] ?? 'Test sin nombre';
    final detalleRespuestas =
        testData['detalleRespuestas'] as List<dynamic>? ?? [];

    final preguntas = <PreguntaEmbebida>[];
    final respuestasUsuario = <String, String?>{};

    for (var detalle in detalleRespuestas) {
      final d = detalle as Map<String, dynamic>;
      final preguntaData =
          d['pregunta'] as Map<String, dynamic>? ?? {};
      final opcionesData =
          preguntaData['opciones'] as List<dynamic>? ?? [];

      final temaId = d['temaId'] ?? '';
      final indice = d['indice'] ?? 0;
      final preguntaId = '${temaId}_$indice';
      final temaNombre = d['temaNombre'] as String?;

      final opciones = opcionesData.map((o) {
        final opcion = o as Map<String, dynamic>;
        return OpcionPregunta(
          letra: opcion['letra'] ?? '',
          texto: opcion['texto'] ?? '',
          esCorrecta: opcion['esCorrecta'] ?? false,
        );
      }).toList();

      preguntas.add(PreguntaEmbebida(
        temaId: temaId,
        texto: preguntaData['texto'] ?? '',
        opciones: opciones,
        respuestaCorrecta: d['respuestaCorrecta'] ?? '',
        indexEnTema: indice,
        explicacion: preguntaData['explicacion'],
        temaNombre: temaNombre,
      ));

      respuestasUsuario[preguntaId] = d['respuestaUsuario'];
    }

    return DetalleTestScreen(
      nombreTest: nombre,
      preguntas: preguntas,
      respuestasUsuario: respuestasUsuario,
    );
  }
}
