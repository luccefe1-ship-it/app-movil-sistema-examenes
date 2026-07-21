import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/notas_corte.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../../widgets/comparativa_corte.dart';
import '../../widgets/explicacion_modal.dart';

class DetalleTestScreen extends StatelessWidget {
  final String nombreTest;
  final List<PreguntaEmbebida> preguntas;
  final Map<String, String?> respuestasUsuario;

  // Estadísticas guardadas del test (opcionales). Si no se pasan, se calculan
  // a partir de las respuestas del usuario.
  final int? correctas;
  final int? incorrectas;
  final int? total;
  final int? sinResponder;

  const DetalleTestScreen({
    super.key,
    required this.nombreTest,
    required this.preguntas,
    required this.respuestasUsuario,
    this.correctas,
    this.incorrectas,
    this.total,
    this.sinResponder,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular estadísticas desde las respuestas (fallback / verificación)
    int correctasCalc = 0, incorrectasCalc = 0, blancoCalc = 0;
    for (final p in preguntas) {
      final r = respuestasUsuario[p.id];
      if (r == null) {
        blancoCalc++;
      } else if (r == p.respuestaCorrecta) {
        correctasCalc++;
      } else {
        incorrectasCalc++;
      }
    }

    final int totalEfectivo =
        (total != null && total! > 0) ? total! : preguntas.length;
    final int correctasEfectivo = correctas ?? correctasCalc;
    final int incorrectasEfectivo = incorrectas ?? incorrectasCalc;
    final int blancoEfectivo = sinResponder ?? blancoCalc;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Detalle del Test',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: preguntas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResumen(
              context,
              correctasEfectivo,
              incorrectasEfectivo,
              blancoEfectivo,
              totalEfectivo,
            );
          }
          return _buildPreguntaCard(
              context, preguntas[index - 1], index - 1);
        },
      ),
    );
  }

  // Cabecera del detalle: nota oficial, tarjetas de estadísticas y el bloque
  // "¿Habrías aprobado la oposición?" (idéntico a la plataforma web).
  Widget _buildResumen(
    BuildContext context,
    int correctas,
    int incorrectas,
    int sinResponder,
    int total,
  ) {
    // Fórmula oficial BOE: acierto +0,60 / error -0,15 → divisor 4. Nota /60.
    final double penalizacion = incorrectas / kDivisorPenalizacion;
    final double aciertosNetos = correctas - penalizacion;
    final int nota = total > 0
        ? ((aciertosNetos / total) * 60).clamp(0.0, 60.0).round()
        : 0;
    final bool aprobado = nota >= 30;
    final Color colorNota = aprobado ? AppColors.success : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tarjeta de resultado (nota + estadísticas) ──
        Card(
          color: AppColors.cardBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  '$correctas / $total',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: colorNota,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorNota.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorNota, width: 2),
                  ),
                  child: Text(
                    'Nota: $nota / 60',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorNota,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                        '✅', 'Correctas', correctas, AppColors.success),
                    _buildStatChip(
                        '❌', 'Incorrectas', incorrectas, AppColors.error),
                    _buildStatChip('⭕', 'Sin responder', sinResponder,
                        AppColors.neutral),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Bloque "¿Habrías aprobado la oposición?" ──
        ComparativaCorte(
          correctas: correctas,
          incorrectas: incorrectas,
          total: total,
        ),
        const SizedBox(height: 20),

        // ── Encabezado de la revisión de respuestas ──
        Text(
          'Revisión de respuestas',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStatChip(
      String icono, String label, int valor, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(icono, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
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

  Widget _buildPreguntaCard(
      BuildContext context, PreguntaEmbebida pregunta, int index) {
    final respuesta = respuestasUsuario[pregunta.id];
    final enBlanco = respuesta == null;
    final esCorrecta = !enBlanco && respuesta == pregunta.respuestaCorrecta;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (enBlanco) {
      statusColor = AppColors.neutral;
      statusText = 'En blanco';
      statusIcon = Icons.remove_circle_outline;
    } else if (esCorrecta) {
      statusColor = AppColors.success;
      statusText = 'Correcta';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppColors.error;
      statusText = 'Incorrecta';
      statusIcon = Icons.cancel;
    }

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número + estado
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 4),
                Text(statusText,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ],
            ),

            // Etiqueta tema padre
            if (pregunta.temaNombre != null &&
                pregunta.temaNombre!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      pregunta.temaNombre!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(pregunta.texto,
                style: GoogleFonts.inter(
                    fontSize: 15, height: 1.5, color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            ...pregunta.opciones.map((opcion) {
              final isUserAnswer = respuesta == opcion.letra;
              final isCorrectOption = opcion.esCorrecta;

              Color bgColor = Colors.transparent;
              Color borderColor = Colors.grey[700]!;

              if (isCorrectOption) {
                bgColor = AppColors.success.withValues(alpha: 0.2);
                borderColor = AppColors.success;
              } else if (isUserAnswer && !isCorrectOption) {
                bgColor = AppColors.error.withValues(alpha: 0.2);
                borderColor = AppColors.error;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isCorrectOption
                            ? AppColors.success
                            : isUserAnswer
                                ? AppColors.error
                                : Colors.grey[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          opcion.letra,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (isCorrectOption || isUserAnswer)
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(opcion.texto,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textPrimary))),
                    if (isCorrectOption)
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                    if (isUserAnswer && !isCorrectOption)
                      const Icon(Icons.cancel,
                          color: AppColors.error, size: 18),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final authService = context.read<AuthService>();
                  final testService = context.read<TestService>();
                  showExplicacionModal(
                    context,
                    pregunta,
                    authService.userId ?? '',
                    testService,
                  );
                },
                icon: const Icon(Icons.menu_book, size: 16),
                label: Text('Ver Explicación',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
