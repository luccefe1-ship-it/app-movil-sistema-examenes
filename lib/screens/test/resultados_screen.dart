import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import 'realizar_test_screen.dart';
import 'detalle_test_screen.dart';

class ResultadosScreen extends StatefulWidget {
  final String nombreTest;
  final List<PreguntaEmbebida> preguntas;
  final Map<String, String?> respuestasUsuario;
  final Map<String, dynamic> resultados;
  final List<String> temasIds;
  final bool esModoFalladas;

  const ResultadosScreen({
    super.key,
    required this.nombreTest,
    required this.preguntas,
    required this.respuestasUsuario,
    required this.resultados,
    required this.temasIds,
    this.esModoFalladas = false,
  });

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _guardarResultado();
  }

  Future<void> _guardarResultado() async {
    final authService = context.read<AuthService>();
    final testService = context.read<TestService>();

    if (authService.userId == null) return;

    final success = await testService.guardarResultado(
      usuarioId: authService.userId!,
      nombreTest: widget.nombreTest,
      preguntas: widget.preguntas,
      respuestasUsuario: widget.respuestasUsuario,
      resultados: widget.resultados,
      temasIds: widget.temasIds,
    );

    if (mounted) setState(() => _guardado = success);
  }

  void _repetirFallos() {
    final falladas = widget.preguntas.where((p) {
      final resp = widget.respuestasUsuario[p.id];
      return resp != null && resp != p.respuestaCorrecta;
    }).toList();

    if (falladas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes preguntas falladas')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RealizarTestScreen(
          nombreTest: '${widget.nombreTest} (Fallos)',
          preguntas: falladas,
          temasIds: widget.temasIds,
          esModoFalladas: true,
        ),
      ),
    );
  }

  void _repetirTodo() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RealizarTestScreen(
          nombreTest: '${widget.nombreTest} (Repetir)',
          preguntas: widget.preguntas,
          temasIds: widget.temasIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultados;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Resultados', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              widget.nombreTest,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Puntuación grande
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      '${r['puntuacion']}',
                      style: GoogleFonts.inter(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: r['puntuacion'] >= 50 ? AppColors.success : AppColors.error,
                      ),
                    ),
                    Text('sobre 100', style: GoogleFonts.inter(fontSize: 18, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Nota examen: ${r['notaExamen']} / 60',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Estadísticas
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatRow('Total preguntas', '${r['total']}', AppColors.textPrimary),
                    const Divider(),
                    _buildStatRow('Correctas', '${r['correctas']}', AppColors.success),
                    const Divider(),
                    _buildStatRow('Incorrectas', '${r['incorrectas']}', AppColors.error),
                    const Divider(),
                    _buildStatRow('En blanco', '${r['sinResponder']}', AppColors.neutral),
                    const Divider(),
                    _buildStatRow('Penalización', '-${(r['penalizacion'] as double).toStringAsFixed(2)}', AppColors.error),
                    const Divider(),
                    _buildStatRow('Aciertos netos', (r['aciertosNetos'] as double).toStringAsFixed(2), AppColors.primary),
                  ],
                ),
              ),
            ),

            if (_guardado)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_done, size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text('Resultado guardado', style: GoogleFonts.inter(fontSize: 12, color: AppColors.success)),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _repetirFallos,
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text('Repetir Fallos', style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _repetirTodo,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('Repetir Todo', style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetalleTestScreen(
                        nombreTest: widget.nombreTest,
                        preguntas: widget.preguntas,
                        respuestasUsuario: widget.respuestasUsuario,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: Text('Ver Detalle del Test', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text('Volver al Menú', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}