import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/tema.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/test_service.dart';

class ExplicacionModal extends StatefulWidget {
  final PreguntaEmbebida pregunta;
  final String userId;
  final TestService testService;
  final String? respuestaUsuario;

  const ExplicacionModal({
    super.key,
    required this.pregunta,
    required this.userId,
    required this.testService,
    this.respuestaUsuario,
  });

  @override
  State<ExplicacionModal> createState() => _ExplicacionModalState();
}

class _ExplicacionModalState extends State<ExplicacionModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tema Digital
  String? _temaDigitalTexto;
  String? _subrayadosHtml;
  bool _loadingDigital = true;
  bool _tieneDigital = false;
  bool _tieneSubrayados = false;
  TextSelection? _seleccionActual;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _guardandoSubrayado = false;

  // IA
  String? _geminiTexto;
  bool _loadingGemini = true;
  bool _tieneGemini = false;
  bool _generandoIA = false;
  bool _guardadoIA = false;
  bool _yaGuardadoEnFirestore = false;
  bool _editandoIA = false;
  late TextEditingController _iaEditController;

  final GlobalKey _firstHighlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _iaEditController = TextEditingController();
    _cargarExplicaciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _iaEditController.dispose();
    super.dispose();
  }

  Future<void> _cargarExplicaciones() async {
    try {
      final textoDigital =
          await widget.testService.obtenerTemaDigital(widget.pregunta.temaId);
      final subrayados = await widget.testService
          .obtenerSubrayados(widget.userId, widget.pregunta.texto);
      if (mounted) {
        setState(() {
          _temaDigitalTexto = textoDigital;
          _subrayadosHtml = subrayados;
          _tieneDigital = textoDigital != null && textoDigital.isNotEmpty;
          _tieneSubrayados = subrayados != null && subrayados.isNotEmpty;
          _loadingDigital = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDigital = false);
    }

    try {
      final texto = await widget.testService
          .obtenerExplicacionGemini(widget.userId, widget.pregunta.texto);
      if (mounted) {
        setState(() {
          _geminiTexto = texto;
          _tieneGemini = texto != null && texto.isNotEmpty;
          _guardadoIA = texto != null && texto.isNotEmpty;
          _yaGuardadoEnFirestore = texto != null && texto.isNotEmpty;
          if (_geminiTexto != null) _iaEditController.text = _geminiTexto!;
          _loadingGemini = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingGemini = false);
    }
  }

  void _scrollToFirstHighlight() {
    final ctx = _firstHighlightKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.3);
    }
  }

  // ─── BUILD ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildTabs(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.58,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemaDigitalTab(),
                _buildGeminiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('Explicación',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Tema Digital'),
              if (_tieneSubrayados) ...[
                const SizedBox(width: 6),
                _dot(AppColors.success),
              ],
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Explicación IA'),
              if (_tieneGemini) ...[
                const SizedBox(width: 6),
                _dot(AppColors.success),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ─── TAB TEMA DIGITAL ────────────────────────────────

  Widget _buildTemaDigitalTab() {
    if (_loadingDigital) {
      return _loading('Cargando tema digital...');
    }
    if (!_tieneDigital) {
      return _empty(Icons.description_outlined,
          'No hay documento digital disponible para este tema.');
    }

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar en el documento...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),

        // Info subrayados
        if (_tieneSubrayados)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('✏️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('Tienes subrayados guardados',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E))),
                ]),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _borrarSubrayados,
                icon: const Icon(Icons.delete_outline,
                    size: 14, color: Colors.red),
                label: Text('Borrar',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.red)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
            ]),
          ),

        // Texto
        Expanded(
          child: _tieneSubrayados
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildHighlightedWidgets(_subrayadosHtml!),
                  ),
                )
              : _buildTextoConSeleccion(),
        ),

        // Barra inferior: subrayar
        if (!_tieneSubrayados)
          _buildBarraSubrayar(),
      ],
    );
  }

  Widget _buildTextoConSeleccion() {
    final texto = _temaDigitalTexto!;
    if (_searchQuery.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          texto,
          style: GoogleFonts.inter(
              fontSize: 14, height: 1.7, color: AppColors.textPrimary),
          onSelectionChanged: (sel, _) =>
              setState(() => _seleccionActual = sel),
        ),
      );
    }

    // Con búsqueda: resaltar coincidencias
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _buildRichTextBusqueda(texto, _searchQuery),
    );
  }

  Widget _buildRichTextBusqueda(String texto, String query) {
    final spans = <TextSpan>[];
    final lower = texto.toLowerCase();
    final queryLower = query.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lower.indexOf(queryLower, start);
      if (idx == -1) {
        spans.add(TextSpan(
            text: texto.substring(start),
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.7, color: AppColors.textPrimary)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(
            text: texto.substring(start, idx),
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.7, color: AppColors.textPrimary)));
      }
      spans.add(TextSpan(
          text: texto.substring(idx, idx + query.length),
          style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.7,
              color: Colors.black,
              fontWeight: FontWeight.bold,
              backgroundColor: const Color(0xFFFBBF24))));
      start = idx + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildBarraSubrayar() {
    final tieneSeleccion = _seleccionActual != null &&
        !_seleccionActual!.isCollapsed &&
        _seleccionActual!.start >= 0 &&
        _seleccionActual!.end <= (_temaDigitalTexto?.length ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(children: [
        Icon(Icons.touch_app_outlined,
            size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            tieneSeleccion
                ? 'Texto seleccionado — pulsa para subrayar'
                : 'Mantén pulsado y selecciona texto para subrayar',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        if (tieneSeleccion)
          _guardandoSubrayado
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : ElevatedButton.icon(
                  onPressed: _guardarSubrayado,
                  icon: const Text('✏️', style: TextStyle(fontSize: 12)),
                  label: Text('Subrayar',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
      ]),
    );
  }

  Future<void> _guardarSubrayado() async {
    if (_seleccionActual == null || _seleccionActual!.isCollapsed) return;
    final texto = _temaDigitalTexto!;
    final start = _seleccionActual!.start.clamp(0, texto.length);
    final end = _seleccionActual!.end.clamp(0, texto.length);
    if (start >= end) return;

    setState(() => _guardandoSubrayado = true);
    try {
      final antes = texto.substring(0, start);
      final seleccionado = texto.substring(start, end);
      final despues = texto.substring(end);
      final html =
          '$antes<span class="subrayado" style="background-color: rgb(254, 240, 138);">$seleccionado</span>$despues';

      await widget.testService.guardarSubrayado(
        userId: widget.userId,
        preguntaTexto: widget.pregunta.texto,
        html: html,
      );

      if (mounted) {
        setState(() {
          _subrayadosHtml = html;
          _tieneSubrayados = true;
          _seleccionActual = null;
          _guardandoSubrayado = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Subrayado guardado'),
              backgroundColor: Colors.green),
        );
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => Future.delayed(const Duration(milliseconds: 300),
                _scrollToFirstHighlight));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardandoSubrayado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _borrarSubrayados() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Borrar subrayados',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text('¿Eliminar todos los subrayados de esta pregunta?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    await widget.testService.eliminarSubrayado(
      userId: widget.userId,
      preguntaTexto: widget.pregunta.texto,
    );
    if (mounted) {
      setState(() {
        _subrayadosHtml = null;
        _tieneSubrayados = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Subrayados eliminados'),
            backgroundColor: Colors.green),
      );
    }
  }

  List<Widget> _buildHighlightedWidgets(String html) {
    final widgets = <Widget>[];
    final regex =
        RegExp(r'<span[^>]*class="subrayado"[^>]*>(.*?)</span>', dotAll: true);
    bool firstFound = false;
    int lastEnd = 0;

    // Filtrar por búsqueda si hay query
    String textoFiltrado = html;

    for (final match in regex.allMatches(textoFiltrado)) {
      if (match.start > lastEnd) {
        final before = _stripHtml(textoFiltrado.substring(lastEnd, match.start));
        if (before.trim().isNotEmpty) {
          widgets.add(_richTextWithSearch(before));
        }
      }
      final highlighted = _stripHtml(match.group(1) ?? '');
      if (highlighted.trim().isNotEmpty) {
        final isFirst = !firstFound;
        if (isFirst) firstFound = true;
        widgets.add(Container(
          key: isFirst ? _firstHighlightKey : null,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          color: const Color(0xFFFBBF24),
          child: Text(highlighted,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.7,
                  color: Colors.black,
                  fontWeight: FontWeight.w500)),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < textoFiltrado.length) {
      final remaining = _stripHtml(textoFiltrado.substring(lastEnd));
      if (remaining.trim().isNotEmpty) {
        widgets.add(_richTextWithSearch(remaining));
      }
    }
    if (widgets.isEmpty) {
      widgets.add(_richTextWithSearch(_stripHtml(textoFiltrado)));
    }
    return widgets;
  }

  Widget _richTextWithSearch(String text) {
    if (_searchQuery.isEmpty) {
      return Text(text,
          style: GoogleFonts.inter(
              fontSize: 14, height: 1.7, color: AppColors.textPrimary));
    }
    return _buildRichTextBusqueda(text, _searchQuery);
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
  }

  // ─── TAB IA ──────────────────────────────────────────

  Widget _buildGeminiTab() {
    if (_loadingGemini) return _loading('Cargando explicación IA...');

    if (!_tieneGemini) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.smart_toy_outlined,
                size: 48, color: AppColors.neutral),
            const SizedBox(height: 12),
            Text('No hay explicación IA para esta pregunta.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _generandoIA
                ? const CircularProgressIndicator(color: AppColors.primary)
                : ElevatedButton.icon(
                    onPressed: _generarExplicacionIA,
                    icon: const Text('✨', style: TextStyle(fontSize: 16)),
                    label: Text('Generar con IA',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ]),
        ),
      );
    }

    // Modo edición
    if (_editandoIA) {
      return Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _iaEditController,
              maxLines: null,
              expands: true,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        _buildBarraAccionesIA(editando: true),
      ]);
    }

    // Modo lectura
    final textoLimpio = (_geminiTexto ?? '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(textoLimpio,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textPrimary)),
        ),
      ),
      _buildBarraAccionesIA(editando: false),
    ]);
  }

  Widget _buildBarraAccionesIA({required bool editando}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: editando
          ? Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _editandoIA = false;
                    _iaEditController.text = _geminiTexto ?? '';
                  }),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                  child: Text('Cancelar',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _guardarEdicionIA,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text('Guardar',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ])
          : Row(children: [
              // Editar
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _iaEditController.text = _geminiTexto ?? '';
                    _editandoIA = true;
                  }),
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text('Editar',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side:
                          const BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 8),
              // Guardar (si no guardado)
              if (!_yaGuardadoEnFirestore)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _guardadoIA ? null : _guardarIA,
                    icon: Icon(
                        _guardadoIA ? Icons.check : Icons.save,
                        size: 14),
                    label: Text(
                        _guardadoIA ? 'Guardada' : 'Guardar',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _guardadoIA
                          ? Colors.grey
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Borrar
              OutlinedButton.icon(
                onPressed: _borrarIA,
                icon: const Icon(Icons.delete_outline,
                    size: 14, color: Colors.red),
                label: Text('Borrar',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red)),
              ),
            ]),
    );
  }

  Future<void> _guardarIA() async {
    await widget.testService.guardarExplicacionGemini(
      widget.pregunta.texto,
      _geminiTexto!,
      userId: widget.userId,
    );
    if (mounted) {
      setState(() {
        _guardadoIA = true;
        _yaGuardadoEnFirestore = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Explicación guardada'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _guardarEdicionIA() async {
    final texto = _iaEditController.text.trim();
    if (texto.isEmpty) return;
    await widget.testService.guardarExplicacionGemini(
      widget.pregunta.texto,
      texto,
      userId: widget.userId,
    );
    if (mounted) {
      setState(() {
        _geminiTexto = texto;
        _tieneGemini = true;
        _guardadoIA = true;
        _yaGuardadoEnFirestore = true;
        _editandoIA = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Explicación actualizada'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _borrarIA() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Borrar explicación',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text('¿Eliminar la explicación IA de esta pregunta?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    await widget.testService.eliminarExplicacionGemini(
      userId: widget.userId,
      preguntaTexto: widget.pregunta.texto,
    );
    if (mounted) {
      setState(() {
        _geminiTexto = null;
        _tieneGemini = false;
        _guardadoIA = false;
        _yaGuardadoEnFirestore = false;
        _editandoIA = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Explicación eliminada'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _generarExplicacionIA() async {
    setState(() => _generandoIA = true);
    try {
      final apiKey = await widget.testService.obtenerClaudeApiKey();
      if (apiKey == null)
        throw Exception('No se encontró la configuración de IA');

      final opciones =
          widget.pregunta.opciones.map((o) => '${o.letra}) ${o.texto}').join('\n');
      final correcta = widget.pregunta.opciones.firstWhere(
          (o) => o.esCorrecta,
          orElse: () => widget.pregunta.opciones.first);
      final respUsuario = widget.respuestaUsuario != null
          ? widget.pregunta.opciones.firstWhere(
              (o) => o.letra == widget.respuestaUsuario,
              orElse: () => widget.pregunta.opciones.first)
          : null;

      final prompt =
          'Eres un experto en Derecho español y oposiciones a la justicia. '
          'Analiza esta pregunta citando la legislación española vigente aplicable.\n\n'
          'Pregunta: ${widget.pregunta.texto}\n'
          'Opciones:\n$opciones\n'
          'Respuesta del alumno: ${respUsuario != null ? "${respUsuario.letra}) ${respUsuario.texto}" : "No disponible"}\n'
          'Respuesta correcta: ${correcta.letra}) ${correcta.texto}\n\n'
          'Responde en dos partes:\n'
          '1. POR QUÉ ES INCORRECTA: explica el error del alumno citando el artículo o norma que lo contradice.\n'
          '2. POR QUÉ ES CORRECTA: justifica la respuesta correcta con el fundamento legal exacto (artículo, ley, código).\n'
          'Sé preciso y conciso. Máximo 8 líneas.';

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 500,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200)
        throw Exception('Error API: ${response.statusCode}');
      final data = jsonDecode(response.body);
      final texto = data['content'][0]['text'] as String;

      if (mounted) {
        setState(() {
          _geminiTexto = texto;
          _tieneGemini = true;
          _guardadoIA = false;
          _yaGuardadoEnFirestore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoIA = false);
    }
  }

  // ─── HELPERS ─────────────────────────────────────────

  Widget _loading(String msg) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text(msg,
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ]),
      );

  Widget _empty(IconData icon, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.neutral),
            const SizedBox(height: 12),
            Text(msg,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

void showExplicacionModal(
  BuildContext context,
  PreguntaEmbebida pregunta,
  String userId,
  TestService testService, {
  String? respuestaUsuario,
}) {
  showDialog(
    context: context,
    builder: (_) => ExplicacionModal(
      pregunta: pregunta,
      userId: userId,
      testService: testService,
      respuestaUsuario: respuestaUsuario,
    ),
  );
}
