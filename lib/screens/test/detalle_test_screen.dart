import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../../widgets/explicacion_modal.dart';

class DetalleTestScreen extends StatelessWidget {
  final String nombreTest;
  final List<PreguntaEmbebida> preguntas;
  final Map<String, String?> respuestasUsuario;

  const DetalleTestScreen({
    super.key,
    required this.nombreTest,
    required this.preguntas,
    required this.respuestasUsuario,
  });

  @override
  Widget build(BuildContext context) {
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
        itemCount: preguntas.length,
        itemBuilder: (context, index) =>
            _buildPreguntaCard(context, preguntas[index], index),
      ),
    );
  }

  Widget _buildPreguntaCard(
      BuildContext context, PreguntaEmbebida pregunta, int index) {
    final respuesta = respuestasUsuario[pregunta.id];
    final enBlanco = respuesta == null;
    final esCorrecta =
        !enBlanco && respuesta == pregunta.respuestaCorrecta;

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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: número + estado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
            const SizedBox(height: 8),

            // Etiqueta del tema padre
            if (pregunta.temaNombre != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        pregunta.temaNombre!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Enunciado
            Text(pregunta.texto,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            // Opciones
            ...pregunta.opciones.map((opcion) {
              final isUserAnswer = respuesta == opcion.letra;
              final isCorrectOption = opcion.esCorrecta;

              Color bgColor = Colors.transparent;
              Color borderColor = Colors.grey[700]!;

              if (isCorrectOption) {
                bgColor = AppColors.success.withOpacity(0.2);
                borderColor = AppColors.success;
              } else if (isUserAnswer && !isCorrectOption) {
                bgColor = AppColors.error.withOpacity(0.2);
                borderColor = AppColors.error;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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
                                fontSize: 13,
                                color: AppColors.textPrimary))),
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
