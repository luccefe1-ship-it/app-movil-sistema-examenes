import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/tema.dart';
import '../services/test_service.dart';

class ExplicacionModal extends StatefulWidget {
  final PreguntaEmbebida pregunta;
  final String userId;
  final TestService testService;

  const ExplicacionModal({
    super.key,
    required this.pregunta,
    required this.userId,
    required this.testService,
  });

  @override
  State<ExplicacionModal> createState() => _ExplicacionModalState();
}

class _ExplicacionModalState extends State<ExplicacionModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _temaDigitalTexto;
  String? _subrayadosHtml;
  String? _geminiTexto;
  bool _loadingDigital = true;
  bool _loadingGemini = true;
  bool _tieneDigital = false;
  bool _tieneGemini = false;
  bool _tieneSubrayados = false;

  final GlobalKey _firstHighlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarExplicaciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarExplicaciones() async {
    try {
      final textoDigital = await widget.testService.obtenerTemaDigital(widget.pregunta.temaId);
      final subrayados = await widget.testService.obtenerSubrayados(widget.userId, widget.pregunta.texto);

      if (mounted) {
        setState(() {
          _temaDigitalTexto = textoDigital;
          _subrayadosHtml = subrayados;
          _tieneDigital = (textoDigital != null && textoDigital.isNotEmpty) ||
              (subrayados != null && subrayados.isNotEmpty);
          _tieneSubrayados = subrayados != null && subrayados.isNotEmpty;
          _loadingDigital = false;
        });

        if (_tieneSubrayados) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 200), () {
              _scrollToFirstHighlight();
            });
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDigital = false);
    }

    try {
      final texto = await widget.testService.obtenerExplicacionGemini(widget.userId, widget.pregunta.texto);
      if (mounted) {
        setState(() {
          _geminiTexto = texto;
          _tieneGemini = texto != null && texto.isNotEmpty;
          _loadingGemini = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingGemini = false);
    }
  }

  void _scrollToFirstHighlight() {
    if (!mounted) return;
    final ctx = _firstHighlightKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tema Digital'),
                      if (_tieneDigital) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Explicación Gemini'),
                      if (_tieneGemini) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
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

  Widget _buildTemaDigitalTab() {
    if (_loadingDigital) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Cargando tema digital...', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (!_tieneDigital) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 48, color: AppColors.neutral),
              const SizedBox(height: 12),
              Text('No hay documento digital disponible para este tema.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_tieneSubrayados) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✏️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('Mostrando tus subrayados',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                ],
              ),
            ),
            ..._buildHighlightedWidgets(_subrayadosHtml!),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _temaDigitalTexto!,
        style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: AppColors.textPrimary),
      ),
    );
  }

  List<Widget> _buildHighlightedWidgets(String html) {
    final widgets = <Widget>[];
    final regex = RegExp(r'<span[^>]*class="subrayado"[^>]*>(.*?)</span>', dotAll: true);

    bool firstHighlightFound = false;
    int lastEnd = 0;

    for (final match in regex.allMatches(html)) {
      if (match.start > lastEnd) {
        final before = _stripHtml(html.substring(lastEnd, match.start));
        if (before.trim().isNotEmpty) {
          widgets.add(Text(
            before,
            style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: AppColors.textPrimary),
          ));
        }
      }

      final highlightedText = _stripHtml(match.group(1) ?? '');
      if (highlightedText.trim().isNotEmpty) {
        final isFirst = !firstHighlightFound;
        if (isFirst) firstHighlightFound = true;

        widgets.add(Container(
          key: isFirst ? _firstHighlightKey : null,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          color: const Color(0xFFFBBF24),
          child: Text(
            highlightedText,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.7,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < html.length) {
      final remaining = _stripHtml(html.substring(lastEnd));
      if (remaining.trim().isNotEmpty) {
        widgets.add(Text(
          remaining,
          style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: AppColors.textPrimary),
        ));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(Text(
        _stripHtml(html),
        style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: AppColors.textPrimary),
      ));
    }

    return widgets;
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

  Widget _buildGeminiTab() {
    if (_loadingGemini) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Cargando explicación Gemini...', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (!_tieneGemini) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 48, color: AppColors.neutral),
              const SizedBox(height: 12),
              Text('No hay explicación Gemini para esta pregunta.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    String textoLimpio = _geminiTexto!
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        textoLimpio,
        style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: AppColors.textPrimary),
      ),
    );
  }
}

// Función helper para mostrar el modal
void showExplicacionModal(
  BuildContext context,
  PreguntaEmbebida pregunta,
  String userId,
  TestService testService,
) {
  showDialog(
    context: context,
    builder: (_) => ExplicacionModal(
      pregunta: pregunta,
      userId: userId,
      testService: testService,
    ),
  );
}