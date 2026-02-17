import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../../widgets/explicacion_modal.dart';
import 'resultados_screen.dart';

class RealizarTestScreen extends StatefulWidget {
  final String nombreTest;
  final List<PreguntaEmbebida> preguntas;
  final List<String> temasIds;
  final bool esModoFalladas;

  const RealizarTestScreen({
    super.key,
    required this.nombreTest,
    required this.preguntas,
    required this.temasIds,
    this.esModoFalladas = false,
  });

  @override
  State<RealizarTestScreen> createState() => _RealizarTestScreenState();
}

class _RealizarTestScreenState extends State<RealizarTestScreen> {
  int _preguntaActual = 0;
  final Map<String, String?> _respuestas = {};
  final Set<String> _yaRespondidas = {};
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _seleccionarRespuesta(String preguntaId, String letra) {
    if (_yaRespondidas.contains(preguntaId)) return;
    setState(() {
      _respuestas[preguntaId] = letra;
      _yaRespondidas.add(preguntaId);
    });
  }

  void _irAPregunta(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _finalizarTest() {
    final sinResponder = widget.preguntas.length - _yaRespondidas.length;

    if (sinResponder > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text('Finalizar Test',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          content: Text(
            'Tienes $sinResponder pregunta${sinResponder > 1 ? 's' : ''} sin responder. Las preguntas en blanco no penalizan.\n\n¿Quieres finalizar?',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Seguir', style: TextStyle(color: AppColors.neutral)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _procesarResultados();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
    } else {
      _procesarResultados();
    }
  }

  void _procesarResultados() {
    final testService = context.read<TestService>();
    final resultados = testService.calcularResultados(
      preguntas: widget.preguntas,
      respuestasUsuario: _respuestas,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultadosScreen(
          nombreTest: widget.nombreTest,
          preguntas: widget.preguntas,
          respuestasUsuario: _respuestas,
          resultados: resultados,
          temasIds: widget.temasIds,
          esModoFalladas: widget.esModoFalladas,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPreguntas = widget.preguntas.length;
    final respondidas = _yaRespondidas.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.nombreTest,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$respondidas/$totalPreguntas',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: respondidas / totalPreguntas,
            backgroundColor: Colors.grey[800],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.success),
            minHeight: 4,
          ),

          // Navegación preguntas
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: totalPreguntas,
              itemBuilder: (context, index) {
                final pregunta = widget.preguntas[index];
                final respondida = _yaRespondidas.contains(pregunta.id);
                final isCurrent = index == _preguntaActual;

                Color bgColor = AppColors.cardBackground;
                Color textColor = AppColors.textPrimary;

                if (respondida) {
                  final esCorrecta =
                      _respuestas[pregunta.id] == pregunta.respuestaCorrecta;
                  bgColor =
                      esCorrecta ? AppColors.success : AppColors.error;
                  textColor = Colors.white;
                }

                return GestureDetector(
                  onTap: () => _irAPregunta(index),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : Colors.grey[700]!,
                        width: isCurrent ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text('${index + 1}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                    ),
                  ),
                );
              },
            ),
          ),

          // Preguntas
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPreguntas,
              onPageChanged: (index) =>
                  setState(() => _preguntaActual = index),
              itemBuilder: (context, index) =>
                  _buildPregunta(widget.preguntas[index]),
            ),
          ),

          // Botones navegación
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            color: AppColors.cardBackground,
            child: Row(
              children: [
                if (_preguntaActual > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _irAPregunta(_preguntaActual - 1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.neutral),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Anterior', style: GoogleFonts.inter()),
                    ),
                  ),
                if (_preguntaActual > 0) const SizedBox(width: 12),
                Expanded(
                  child: _preguntaActual < totalPreguntas - 1
                      ? ElevatedButton(
                          onPressed: () =>
                              _irAPregunta(_preguntaActual + 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child:
                              Text('Siguiente', style: GoogleFonts.inter()),
                        )
                      : ElevatedButton(
                          onPressed: _finalizarTest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Finalizar Test',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPregunta(PreguntaEmbebida pregunta) {
    final respondida = _yaRespondidas.contains(pregunta.id);
    final respuestaUsuario = _respuestas[pregunta.id];
    final esCorrecta =
        respondida && respuestaUsuario == pregunta.respuestaCorrecta;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ETIQUETA TEMA PADRE ──────────────────────────
          if (pregunta.temaNombre != null && pregunta.temaNombre!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    pregunta.temaNombre!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Enunciado
          Card(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(pregunta.texto,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 16),

          // Opciones
          ...pregunta.opciones.map((opcion) {
            final isSelected = respuestaUsuario == opcion.letra;
            final opcionCorrecta = opcion.esCorrecta;

            Color bgColor = AppColors.cardBackground;
            Color borderColor = Colors.grey[700]!;
            IconData? trailingIcon;
            Color? iconColor;

            if (respondida) {
              if (opcionCorrecta) {
                bgColor = AppColors.success.withOpacity(0.2);
                borderColor = AppColors.success;
                trailingIcon = Icons.check_circle;
                iconColor = AppColors.success;
              } else if (isSelected && !opcionCorrecta) {
                bgColor = AppColors.error.withOpacity(0.2);
                borderColor = AppColors.error;
                trailingIcon = Icons.cancel;
                iconColor = AppColors.error;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: respondida
                    ? null
                    : () =>
                        _seleccionarRespuesta(pregunta.id, opcion.letra),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: respondida && opcionCorrecta
                              ? AppColors.success
                              : respondida && isSelected
                                  ? AppColors.error
                                  : Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            opcion.letra,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: respondida &&
                                      (opcionCorrecta || isSelected)
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(opcion.texto,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.textPrimary))),
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: iconColor, size: 24),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Resultado inmediato
          if (respondida) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: esCorrecta
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    esCorrecta ? Icons.check_circle : Icons.cancel,
                    color:
                        esCorrecta ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      esCorrecta
                          ? '¡Correcto!'
                          : 'Incorrecto. La respuesta correcta es: ${pregunta.respuestaCorrecta}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: esCorrecta
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                icon: const Icon(Icons.menu_book, size: 18),
                label: Text('Ver Explicación',
                    style: GoogleFonts.inter(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
