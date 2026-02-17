import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../models/tema.dart';
import '../../services/auth_service.dart';
import '../../services/temas_service.dart';
import '../../services/test_service.dart';
import 'realizar_test_screen.dart';

class ConfigurarTestScreen extends StatefulWidget {
  const ConfigurarTestScreen({super.key});

  @override
  State<ConfigurarTestScreen> createState() => _ConfigurarTestScreenState();
}

class _ConfigurarTestScreenState extends State<ConfigurarTestScreen> {
  final _nombreController = TextEditingController();
  final Set<String> _temasSeleccionados = {};
  final Set<String> _temasExpandidos = {};
  int _numeroPreguntas = 10;
  bool _isLoading = true;
  bool _isStarting = false;
  int _preguntasFalladas = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final authService = context.read<AuthService>();
    final temasService = context.read<TemasService>();
    final testService = context.read<TestService>();

    if (authService.userId != null) {
      await temasService.cargarTemas(authService.userId!);
      _preguntasFalladas = await testService.contarPreguntasFalladas(authService.userId!);
    }

    setState(() => _isLoading = false);
  }

  void _toggleTema(String temaId, TemasService temasService) {
    setState(() {
      if (_temasSeleccionados.contains(temaId)) {
        _temasSeleccionados.remove(temaId);
        final subtemas = temasService.getSubtemas(temaId);
        for (var s in subtemas) {
          _temasSeleccionados.remove(s.id);
        }
      } else {
        _temasSeleccionados.add(temaId);
        final subtemas = temasService.getSubtemas(temaId);
        for (var s in subtemas) {
          _temasSeleccionados.add(s.id);
        }
      }
    });
  }

  void _toggleSubtema(String subtemaId) {
    setState(() {
      if (_temasSeleccionados.contains(subtemaId)) {
        _temasSeleccionados.remove(subtemaId);
      } else {
        _temasSeleccionados.add(subtemaId);
      }
    });
  }

  void _toggleExpandir(String temaId) {
    setState(() {
      if (_temasExpandidos.contains(temaId)) {
        _temasExpandidos.remove(temaId);
      } else {
        _temasExpandidos.add(temaId);
      }
    });
  }

  Future<void> _repetirUltimosParametros() async {
    final testService = context.read<TestService>();
    final config = await testService.cargarUltimaConfiguracion();

    if (config == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay configuración anterior guardada')),
      );
      return;
    }

    setState(() {
      _nombreController.text = config['nombre'];
      _temasSeleccionados.clear();
      _temasSeleccionados.addAll(List<String>.from(config['temasIds']));
      _numeroPreguntas = config['numPreguntas'];
    });
  }

  Future<void> _practicarFalladas() async {
    setState(() => _isStarting = true);

    final authService = context.read<AuthService>();
    final testService = context.read<TestService>();
    final temasService = context.read<TemasService>();

    if (authService.userId == null) {
      setState(() => _isStarting = false);
      return;
    }

    final falladas = await testService.getPreguntasFalladas(
      authService.userId!,
      temasService.todosTemas,
    );

    setState(() => _isStarting = false);

    if (!mounted) return;

    if (falladas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes preguntas falladas pendientes')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealizarTestScreen(
          nombreTest: 'Repaso de Fallos',
          preguntas: falladas,
          temasIds: const [],
          esModoFalladas: true,
        ),
      ),
    );
  }

  Future<void> _iniciarTest() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para el test')),
      );
      return;
    }

    if (_temasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un tema o subtema')),
      );
      return;
    }

    setState(() => _isStarting = true);

    final temasService = context.read<TemasService>();
    final testService = context.read<TestService>();

    await testService.guardarConfiguracion(
      nombre,
      _temasSeleccionados.toList(),
      _numeroPreguntas,
    );

    final todasPreguntas = temasService.getPreguntasVerificadas(
      _temasSeleccionados.toList(),
    );

    if (!mounted) return;

    if (todasPreguntas.isEmpty) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay preguntas verificadas en la selección')),
      );
      return;
    }

    final preguntas = testService.getRandomPreguntas(todasPreguntas, _numeroPreguntas);

    setState(() => _isStarting = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealizarTestScreen(
          nombreTest: nombre,
          preguntas: preguntas,
          temasIds: _temasSeleccionados.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final temasService = context.watch<TemasService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Configurar Test', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botones rápidos
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _repetirUltimosParametros,
                          icon: const Icon(Icons.replay, size: 18),
                          label: Text('Repetir últimos', style: GoogleFonts.inter(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preguntasFalladas > 0 ? _practicarFalladas : null,
                          icon: const Icon(Icons.error_outline, size: 18),
                          label: Text(
                            _preguntasFalladas > 0
                                ? 'Falladas ($_preguntasFalladas)'
                                : 'Sin falladas',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: _preguntasFalladas > 0 ? AppColors.error : Colors.grey[700]!,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Nombre
                  Text('Nombre del test', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nombreController,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: Test Tema 1 y 2',
                      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Número de preguntas
                  Text('Número de preguntas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [10, 20, 50, 100].map((n) {
                      final isSelected = _numeroPreguntas == n;
                      return ChoiceChip(
                        label: Text(
                          '$n',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardBackground,
                        onSelected: (_) => setState(() => _numeroPreguntas = n),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Temas
                  Text('Seleccionar temas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),

                  ...temasService.temasPrincipales.map((tema) => _buildTemaCard(tema, temasService)),

                  const SizedBox(height: 32),

                  if (_temasSeleccionados.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_contarPreguntasDisponibles(temasService)} preguntas verificadas disponibles',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _isStarting ? null : _iniciarTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isStarting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text('Iniciar Test', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  int _contarPreguntasDisponibles(TemasService temasService) {
    return temasService.getPreguntasVerificadas(_temasSeleccionados.toList()).length;
  }

  Widget _buildTemaCard(Tema tema, TemasService temasService) {
    final isSelected = _temasSeleccionados.contains(tema.id);
    final isExpanded = _temasExpandidos.contains(tema.id);
    final subtemas = temasService.getSubtemas(tema.id);
    final totalPreguntas = temasService.contarPreguntasVerificadas(tema.id);

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (_) => _toggleTema(tema.id, temasService),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleTema(tema.id, temasService),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tema.nombre, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('$totalPreguntas preguntas', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              if (subtemas.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => _toggleExpandir(tema.id),
                ),
            ],
          ),

          if (isExpanded && subtemas.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8, top: 4),
              child: Column(
                children: subtemas.map((subtema) {
                  final subSelected = _temasSeleccionados.contains(subtema.id);
                  return CheckboxListTile(
                    title: Text(subtema.nombre, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text('${subtema.numPreguntasVerificadas} preguntas', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    value: subSelected,
                    activeColor: AppColors.primaryLight,
                    dense: true,
                    onChanged: (_) => _toggleSubtema(subtema.id),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}