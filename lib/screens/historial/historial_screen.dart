import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';

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

    if (authService.userId == null) return;

    final historial = await testService.getHistorial(authService.userId!);
    if (mounted) {
      setState(() {
        _historial = historial;
        _isLoading = false;
      });
    }
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      DateTime dt;
      if (fecha is DateTime) {
        dt = fecha;
      } else {
        dt = fecha.toDate();
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _confirmarEliminar(String testId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Eliminar test',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Seguro que quieres eliminar este test del historial?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      final testService = context.read<TestService>();
      await testService.eliminarResultado(testId);
      await _cargarHistorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Historial de Tests',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historial.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes tests realizados aún',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarHistorial,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historial.length,
                    itemBuilder: (context, index) {
                      final test = _historial[index];
                      return _TestHistorialCard(
                        test: test,
                        onTap: () => _abrirDetalle(test),
                        onDelete: () => _confirmarEliminar(test['id']),
                        formatearFecha: _formatearFecha,
                      );
                    },
                  ),
                ),
    );
  }

  void _abrirDetalle(Map<String, dynamic> test) {
    // Reconstruir preguntas con temaNombre desde Firebase
    final detalleRaw =
        List<Map<String, dynamic>>.from(test['detalleRespuestas'] ?? []);

    final preguntas = detalleRaw.map((d) {
      final opciones = (d['opciones'] as List? ?? []).map((o) {
        final om = o as Map<String, dynamic>;
        return OpcionPregunta(
          letra: om['letra'] ?? '',
          texto: om['texto'] ?? '',
          esCorrecta: om['letra'] == d['respuestaCorrecta'],
        );
      }).toList();

      return PreguntaEmbebida(
        temaId: d['temaId'] ?? '',
        indexEnTema: d['indexEnTema'] ?? 0,
        texto: d['texto'] ?? '',
        opciones: opciones,
        respuestaCorrecta: d['respuestaCorrecta'] ?? '',
        verificada: true,
        explicacion: d['explicacion'],
        temaNombre: d['temaNombre'], // ← lee el nombre del tema padre guardado
      );
    }).toList();

    final respuestasUsuario = <String, String?>{};
    for (final d in detalleRaw) {
      final temaId = d['temaId'] ?? '';
      final index = d['indexEnTema'] ?? 0;
      final key = '${temaId}_$index';
      respuestasUsuario[key] = d['respuestaUsuario'];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleTestHistorialScreen(
          nombreTest: test['nombreTest'] ?? 'Test',
          fecha: _formatearFecha(test['fecha']),
          preguntas: preguntas,
          respuestasUsuario: respuestasUsuario,
          resultados: {
            'totalPreguntas': test['totalPreguntas'],
            'correctas': test['correctas'],
            'incorrectas': test['incorrectas'],
            'blancoNulas': test['blancoNulas'],
            'puntuacion': test['puntuacion'],
            'notaExamen': test['notaExamen'],
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD DEL HISTORIAL
// ─────────────────────────────────────────────────────────────

class _TestHistorialCard extends StatelessWidget {
  final Map<String, dynamic> test;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(dynamic) formatearFecha;

  const _TestHistorialCard({
    required this.test,
    required this.onTap,
    required this.onDelete,
    required this.formatearFecha,
  });

  @override
  Widget build(BuildContext context) {
    final puntuacion = test['puntuacion'] ?? 0;
    final correctas = test['correctas'] ?? 0;
    final total = test['totalPreguntas'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
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
                      test['nombreTest'] ?? 'Test',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatearFecha(test['fecha']),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '📊 $puntuacion pts',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$correctas/$total correctas',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.error),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANTALLA DE DETALLE DEL TEST DESDE HISTORIAL
// ─────────────────────────────────────────────────────────────

class DetalleTestHistorialScreen extends StatelessWidget {
  final String nombreTest;
  final String fecha;
  final List<PreguntaEmbebida> preguntas;
  final Map<String, String?> respuestasUsuario;
  final Map<String, dynamic> resultados;

  const DetalleTestHistorialScreen({
    super.key,
    required this.nombreTest,
    required this.fecha,
    required this.preguntas,
    required this.respuestasUsuario,
    required this.resultados,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          nombreTest,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Resumen superior
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ResumenChip(
                  label: 'Correctas',
                  valor: '${resultados['correctas']}',
                  color: AppColors.success,
                ),
                _ResumenChip(
                  label: 'Incorrectas',
                  valor: '${resultados['incorrectas']}',
                  color: AppColors.error,
                ),
                _ResumenChip(
                  label: 'Blanco',
                  valor: '${resultados['blancoNulas']}',
                  color: AppColors.neutral,
                ),
                _ResumenChip(
                  label: 'Puntuación',
                  valor: '${resultados['puntuacion']}',
                  color: Colors.white,
                ),
              ],
            ),
          ),

          // Lista de preguntas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: preguntas.length,
              itemBuilder: (context, index) {
                final pregunta = preguntas[index];
                final respuesta = respuestasUsuario[pregunta.id];
                final esAcierto = respuesta != null &&
                    respuesta == pregunta.respuestaCorrecta;
                final esBlanco = respuesta == null;

                return _PreguntaDetalleCard(
                  numero: index + 1,
                  pregunta: pregunta,
                  respuestaUsuario: respuesta,
                  esAcierto: esAcierto,
                  esBlanco: esBlanco,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenChip extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _ResumenChip({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _PreguntaDetalleCard extends StatelessWidget {
  final int numero;
  final PreguntaEmbebida pregunta;
  final String? respuestaUsuario;
  final bool esAcierto;
  final bool esBlanco;

  const _PreguntaDetalleCard({
    required this.numero,
    required this.pregunta,
    required this.respuestaUsuario,
    required this.esAcierto,
    required this.esBlanco,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: número + tema padre + icono resultado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Etiqueta del tema padre
                      if (pregunta.temaNombre != null &&
                          pregunta.temaNombre!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pregunta.temaNombre!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      Text(
                        pregunta.texto,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  esBlanco ? '⚪' : esAcierto ? '✅' : '❌',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Opciones
            ...pregunta.opciones.map((opcion) {
              final esLaRespuestaUsuario = respuestaUsuario == opcion.letra;
              final esLaCorrecta = opcion.letra == pregunta.respuestaCorrecta;

              Color? bgColor;
              Color borderColor = Colors.grey.shade200;

              if (esLaCorrecta) {
                bgColor = AppColors.success.withOpacity(0.1);
                borderColor = AppColors.success;
              } else if (esLaRespuestaUsuario && !esAcierto) {
                bgColor = AppColors.error.withOpacity(0.1);
                borderColor = AppColors.error;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${opcion.letra}) ',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: esLaCorrecta
                            ? AppColors.success
                            : esLaRespuestaUsuario && !esAcierto
                                ? AppColors.error
                                : AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        opcion.texto,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (esLaCorrecta)
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 16),
                    if (esLaRespuestaUsuario && !esAcierto)
                      const Icon(Icons.cancel, color: AppColors.error, size: 16),
                  ],
                ),
              );
            }),

            // En blanco
            if (esBlanco)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sin respuesta — Correcta: ${pregunta.respuestaCorrecta}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Explicación
            if (pregunta.explicacion != null &&
                pregunta.explicacion!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.explicacionBackground,
                  border:
                      Border.all(color: AppColors.explicacionBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Explicación',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pregunta.explicacion!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
