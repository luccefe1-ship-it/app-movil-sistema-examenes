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
  int _numeroPreguntas = 25;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _soloNuevas = false;
  bool _soloFalladas = false;
  bool _soloOficiales = false;
  int? _disponiblesConFiltro; // preguntas que quedan tras aplicar el filtro
  bool _calculandoDisponibles = false;
  int _peticionDisponibles = 0; // descarta cálculos obsoletos

  // Conteo por tema/subtema con el filtro activo (clave = temaId → nº de
  // preguntas de ESE tema que coinciden con el filtro). Las claves del
  // historial se cachean para no releer Firestore por cada tarjeta.
  Map<String, int> _conteoFiltradoPorTema = {};
  Set<String>? _clavesVistos;
  Set<String>? _clavesFallados;
  bool _cargandoConteos = false;

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

    if (authService.userId != null) {
      await temasService.cargarTemas(authService.userId!);
    }

    setState(() => _isLoading = false);
  }

  void _toggleTema(String temaId, TemasService temasService) {
    setState(() {
      if (_temasSeleccionados
              .containsAll(temasService.getSubtemas(temaId).map((s) => s.id)) ||
          _temasSeleccionados.contains(temaId)) {
        _temasSeleccionados.remove(temaId);
        final subtemas = temasService.getSubtemas(temaId);
        for (var s in subtemas) {
          _temasSeleccionados.remove(s.id);
        }
      } else {
        final subtemas = temasService.getSubtemas(temaId);
        if (subtemas.isNotEmpty) {
          // Solo añadir subtemas, NO el padre (las preguntas están en los subtemas)
          for (var s in subtemas) {
            _temasSeleccionados.add(s.id);
          }
        } else {
          // Tema sin subtemas: añadir directamente
          _temasSeleccionados.add(temaId);
        }
      }
    });
    _recalcularDisponibles();
  }

  void _toggleSubtema(String subtemaId) {
    setState(() {
      if (_temasSeleccionados.contains(subtemaId)) {
        _temasSeleccionados.remove(subtemaId);
      } else {
        _temasSeleccionados.add(subtemaId);
      }
    });
    _recalcularDisponibles();
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
    _recalcularDisponibles();
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
        const SnackBar(
            content: Text('No hay preguntas verificadas en la selección')),
      );
      return;
    }

    // Filtros: oficiales (independiente) + nuevas/falladas (excluyentes)
    List<PreguntaEmbebida> pool = _aplicarOficiales(todasPreguntas);
    final authService = context.read<AuthService>();

    if (authService.userId != null && (_soloNuevas || _soloFalladas)) {
      pool = _soloNuevas
          ? await testService.filtrarSoloNuevas(pool, authService.userId!)
          : await testService.filtrarSoloFalladas(pool, authService.userId!);

      if (!mounted) return;
    }

    if (_filtroActivo && pool.isEmpty) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensajeSinPreguntas())),
      );
      return;
    }

    final preguntas = testService.getRandomPreguntas(pool, _numeroPreguntas);

    // Nº de fallos pendientes de cada pregunta, para el badge en el test
    // (en cualquier test, no solo en el de falladas).
    Map<String, int>? conteoFallos;
    if (authService.userId != null) {
      conteoFallos =
          await testService.conteoFallosPara(preguntas, authService.userId!);
    }

    if (!mounted) return;
    setState(() => _isStarting = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealizarTestScreen(
          nombreTest: nombre,
          preguntas: preguntas,
          temasIds: _temasSeleccionados.toList(),
          conteoFallos: conteoFallos,
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
        title: Text('Configurar Test',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                  // Botón rápido
                  OutlinedButton.icon(
                    onPressed: _repetirUltimosParametros,
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text('Repetir últimos',
                        style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nombre
                  Text('Nombre del test',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
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
                      hintStyle:
                          GoogleFonts.inter(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Número de preguntas
                  Text('Número de preguntas',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [10, 25, 50, 100].map((n) {
                      final isSelected = _numeroPreguntas == n;
                      return ChoiceChip(
                        label: Text(
                          '$n',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
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
                  Text('Seleccionar temas',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),

                  ...temasService.temasPrincipales
                      .map((tema) => _buildTemaCard(tema, temasService)),

                  const SizedBox(height: 24),

                  // Filtros de preguntas (solo nuevas / solo falladas)
                  Text('Filtrar preguntas (opcional)',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  _buildFiltrosCard(),
                  const SizedBox(height: 32),

                  if (_temasSeleccionados.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDisponiblesText(temasService),
                    ),

                  ElevatedButton(
                    onPressed: _isStarting ? null : _iniciarTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isStarting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)))
                        : Text('Iniciar Test',
                            style: GoogleFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  int _contarPreguntasDisponibles(TemasService temasService) {
    return _aplicarOficiales(
      temasService.getPreguntasVerificadas(_temasSeleccionados.toList()),
    ).length;
  }

  /// Recalcula cuántas preguntas quedan tras aplicar el filtro activo.
  /// Sin filtro (o sin temas) no hay número filtrado que mostrar.
  Future<void> _recalcularDisponibles() async {
    if (!_filtroActivo || _temasSeleccionados.isEmpty) {
      if (mounted) {
        setState(() {
          _disponiblesConFiltro = null;
          _calculandoDisponibles = false;
        });
      }
      return;
    }

    final authService = context.read<AuthService>();
    final temasService = context.read<TemasService>();
    final testService = context.read<TestService>();

    if (authService.userId == null) return;

    // Marca de petición: si el usuario cambia la selección mientras se calcula,
    // descartamos las respuestas viejas y nos quedamos solo con la última.
    final miPeticion = ++_peticionDisponibles;
    setState(() => _calculandoDisponibles = true);

    var pool = _aplicarOficiales(
        temasService.getPreguntasVerificadas(_temasSeleccionados.toList()));

    if (_soloNuevas || _soloFalladas) {
      pool = _soloNuevas
          ? await testService.filtrarSoloNuevas(pool, authService.userId!)
          : await testService.filtrarSoloFalladas(pool, authService.userId!);
    }

    if (!mounted || miPeticion != _peticionDisponibles) return;

    setState(() {
      _disponiblesConFiltro = pool.length;
      _calculandoDisponibles = false;
    });
  }

  /// Recalcula, para cada tema y subtema, cuántas de sus preguntas coinciden
  /// con el filtro activo (solo nuevas / solo falladas), tomando como
  /// referencia el historial de tests de la app. El resultado se guarda en
  /// `_conteoFiltradoPorTema` (clave = id del tema/subtema → nº propio) y lo
  /// usan las tarjetas para mostrar el número correcto.
  Future<void> _recalcularConteosPorTema() async {
    // Sin filtro: no hay conteo especial, las tarjetas vuelven al total.
    if (!_filtroActivo) {
      if (mounted) setState(() => _conteoFiltradoPorTema = {});
      return;
    }

    final authService = context.read<AuthService>();
    final temasService = context.read<TemasService>();
    final testService = context.read<TestService>();

    if (authService.userId == null) return;

    setState(() => _cargandoConteos = true);

    // "Nuevas" usa el historial (vistas). "Falladas" usa el contador vivo de
    // preguntasFalladas (solo pendientes > 0), no el historial.
    if (_soloNuevas && _clavesVistos == null) {
      final historial =
          await testService.cargarClavesHistorial(authService.userId!);
      _clavesVistos = historial['vistos'] ?? <String>{};
      _clavesFallados = historial['fallados'] ?? <String>{};
    }
    Set<String> falladasPend = <String>{};
    if (_soloFalladas) {
      falladasPend =
          await testService.clavesFalladasPendientes(authService.userId!);
    }

    if (!mounted) return;

    final Map<String, int> conteos = {};
    for (final tema in temasService.todosTemas) {
      int n = 0;
      for (final p in tema.preguntas) {
        if (!p.verificada) continue;
        if (_soloOficiales && !p.esOficial) continue;
        if (_soloFalladas) {
          if (!falladasPend.contains('${p.temaId}_${p.indexEnTema}')) continue;
        } else if (_soloNuevas) {
          final coincide =
              testService.coincideEnHistorial(p, _clavesVistos ?? <String>{});
          if (coincide) continue; // nuevas: excluir las ya vistas
        }
        n++;
      }
      conteos[tema.id] = n;
    }

    if (!mounted) return;
    setState(() {
      _conteoFiltradoPorTema = conteos;
      _cargandoConteos = false;
    });
  }

  /// Número que muestra la tarjeta de un tema con el filtro activo: la suma de
  /// sus preguntas propias que coinciden más las de todos sus subtemas.
  int _conteoTemaConSubtemas(Tema tema, TemasService temasService) {
    int total = _conteoFiltradoPorTema[tema.id] ?? 0;
    for (final s in temasService.getSubtemas(tema.id)) {
      total += _conteoFiltradoPorTema[s.id] ?? 0;
    }
    return total;
  }

  /// Texto de preguntas disponibles. Reacciona al filtro seleccionado.
  Widget _buildDisponiblesText(TemasService temasService) {
    // Sin filtro: total de verificadas de los temas elegidos.
    if (!_filtroActivo) {
      return Text(
        '${_contarPreguntasDisponibles(temasService)} preguntas verificadas disponibles',
        style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      );
    }

    // Con filtro pero aún calculando.
    if (_calculandoDisponibles || _disponiblesConFiltro == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Calculando preguntas disponibles…',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final disp = _disponiblesConFiltro!;
    final color = _colorFiltro;
    final etiqueta = _etiquetaFiltro;

    if (disp == 0) {
      return Text(
        _mensajeSinPreguntas(),
        style: GoogleFonts.inter(
            fontSize: 14, color: color, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      );
    }

    final usara = disp < _numeroPreguntas ? disp : _numeroPreguntas;
    return Column(
      children: [
        Text(
          '$disp preguntas $etiqueta disponibles',
          style: GoogleFonts.inter(
              fontSize: 14, color: color, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (disp < _numeroPreguntas)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'El test tendrá $usara (todas las disponibles)',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  bool get _filtroActivo => _soloNuevas || _soloFalladas || _soloOficiales;

  /// Etiqueta descriptiva del filtro combinado activo ("oficiales falladas").
  String get _etiquetaFiltro {
    final partes = <String>[];
    if (_soloOficiales) partes.add('oficiales');
    if (_soloNuevas) partes.add('nuevas');
    if (_soloFalladas) partes.add('falladas');
    return partes.join(' ');
  }

  /// Color dominante del filtro activo.
  Color get _colorFiltro {
    if (_soloNuevas) return AppColors.success;
    if (_soloFalladas) return AppColors.error;
    return AppColors.oficial;
  }

  /// Aplica el filtro de oficiales en memoria (no necesita Firestore).
  List<PreguntaEmbebida> _aplicarOficiales(List<PreguntaEmbebida> pool) {
    if (!_soloOficiales) return pool;
    return pool.where((p) => p.esOficial).toList();
  }

  /// Mensaje cuando la combinación de filtros no deja ninguna pregunta.
  String _mensajeSinPreguntas() {
    if (_soloOficiales && !_soloNuevas && !_soloFalladas) {
      return 'No hay preguntas marcadas como oficiales en estos temas.';
    }
    if (_soloNuevas) {
      return _soloOficiales
          ? 'No quedan preguntas oficiales nuevas en estos temas.'
          : '¡Ya has hecho todas las preguntas de estos temas! No quedan preguntas nuevas.';
    }
    return _soloOficiales
        ? 'No tienes preguntas oficiales falladas en estos temas.'
        : 'No tienes preguntas falladas registradas en estos temas.';
  }

  Widget _buildFiltrosCard() {
    return Card(
      color: AppColors.cardBackground,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          CheckboxListTile(
            value: _soloOficiales,
            activeColor: AppColors.oficial,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              '📋 Solo preguntas oficiales',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Las marcadas como oficiales de examen en la plataforma',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            onChanged: (v) {
              setState(() => _soloOficiales = v ?? false);
              _recalcularDisponibles();
              _recalcularConteosPorTema();
            },
          ),
          const Divider(height: 1),
          CheckboxListTile(
            value: _soloNuevas,
            activeColor: AppColors.success,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              '🆕 Solo preguntas nuevas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Que no te hayan salido nunca en ningún test',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            onChanged: (v) {
              setState(() {
                _soloNuevas = v ?? false;
                if (_soloNuevas) _soloFalladas = false;
              });
              _recalcularDisponibles();
              _recalcularConteosPorTema();
            },
          ),
          const Divider(height: 1),
          CheckboxListTile(
            value: _soloFalladas,
            activeColor: AppColors.error,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              '🔴 Solo preguntas falladas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Solo las que has fallado alguna vez en tests anteriores',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            onChanged: (v) {
              setState(() {
                _soloFalladas = v ?? false;
                if (_soloFalladas) _soloNuevas = false;
              });
              _recalcularDisponibles();
              _recalcularConteosPorTema();
            },
          ),
        ],
      ),
    );
  }

  /// Subtítulo de la tarjeta de tema: número total, o número filtrado
  /// (nuevas/falladas) cuando hay un filtro activo.
  Widget _buildContadorTema(Tema tema, TemasService temasService, int total) {
    if (!_filtroActivo) {
      return Text('$total preguntas',
          style:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary));
    }
    if (_cargandoConteos && _conteoFiltradoPorTema.isEmpty) {
      return Text('Calculando…',
          style:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary));
    }
    final n = _conteoTemaConSubtemas(tema, temasService);
    return Text('$n $_etiquetaFiltro',
        style: GoogleFonts.inter(
            fontSize: 12, color: _colorFiltro, fontWeight: FontWeight.w600));
  }

  /// Subtítulo de la fila de subtema: número total, o número filtrado.
  Widget _buildContadorSubtema(Tema subtema) {
    if (!_filtroActivo) {
      return Text('${subtema.numPreguntasVerificadas} preguntas',
          style:
              GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary));
    }
    if (_cargandoConteos && _conteoFiltradoPorTema.isEmpty) {
      return Text('Calculando…',
          style:
              GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary));
    }
    final n = _conteoFiltradoPorTema[subtema.id] ?? 0;
    return Text('$n $_etiquetaFiltro',
        style: GoogleFonts.inter(
            fontSize: 11, color: _colorFiltro, fontWeight: FontWeight.w600));
  }

  Widget _buildTemaCard(Tema tema, TemasService temasService) {
    final subtemas = temasService.getSubtemas(tema.id);
    final isSelected = subtemas.isNotEmpty
        ? subtemas.every((s) => _temasSeleccionados.contains(s.id))
        : _temasSeleccionados.contains(tema.id);
    final isExpanded = _temasExpandidos.contains(tema.id);
    final totalPreguntas = temasService.contarPreguntasVerificadas(tema.id);

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2),
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
                      Text(tema.nombre,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      _buildContadorTema(tema, temasService, totalPreguntas),
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
              padding:
                  const EdgeInsets.only(left: 16, right: 8, bottom: 8, top: 4),
              child: Column(
                children: subtemas.map((subtema) {
                  final subSelected = _temasSeleccionados.contains(subtema.id);
                  return CheckboxListTile(
                    title: Text(subtema.nombre,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: _buildContadorSubtema(subtema),
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
