import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';

class EnfermedadesScreen extends StatefulWidget {
  const EnfermedadesScreen({super.key});

  @override
  State<EnfermedadesScreen> createState() => _EnfermedadesScreenState();
}

class _EnfermedadesScreenState extends State<EnfermedadesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Pestaña 1: Diagnósticos Locales
  List<dynamic> _enfermedadesLocales = [];
  bool _isLoadingLocales = true;
  String? _errorLocales;
  String _filtroTipoLocal = 'todos'; // 'todos' | 'cronicos' | 'agudos'
  final _searchLocalController = TextEditingController();

  // Pestaña 2: Catálogo CIE-11 (API / Global)
  List<dynamic> _catalogoResultados = [];
  bool _isLoadingCatalogo = false;
  String? _errorCatalogo;
  final _searchCatalogoController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarEnfermedadesLocales();
    _buscarEnCatalogoCIE('respiratoria');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchLocalController.dispose();
    _searchCatalogoController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _esDiagnosticoCronico(dynamic enf) {
    if (enf is Map && enf['es_cronica'] is bool) return enf['es_cronica'] as bool;
    final texto = [
      enf['categoria']?.toString() ?? '',
      enf['descripcion']?.toString() ?? '',
      enf['comentarios_especiales']?.toString() ?? '',
    ].join(' ').toLowerCase();

    const keywords = [
      'crónic', 'cronic', 'diabetes', 'hipertensi', 'asma', 'epoc', 'artritis',
      'insuficiencia', 'tiroid', 'epilep', 'cardiovascular', 'endocrin',
      'metabólic', 'metabolic', 'oncológ', 'oncolog', 'autoinmune', 'parkinson', 'alzheimer',
    ];
    return keywords.any(texto.contains);
  }

  List<dynamic> get _enfermedadesFiltradas {
    if (_filtroTipoLocal == 'cronicos') return _enfermedadesLocales.where(_esDiagnosticoCronico).toList();
    if (_filtroTipoLocal == 'agudos') return _enfermedadesLocales.where((e) => !_esDiagnosticoCronico(e)).toList();
    return _enfermedadesLocales;
  }

  Map<String, String> _authHeaders({bool isJson = false}) {
    final token = ApiService.authToken ?? AuthService().token;
    return {
      if (isJson) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarEnfermedadesLocales({String? query}) async {
    setState(() {
      _isLoadingLocales = true;
      _errorLocales = null;
    });
    try {
      final list = await ApiService.getEnfermedades(buscar: query);
      if (mounted) setState(() { _enfermedadesLocales = list; _isLoadingLocales = false; });
    } catch (e) {
      if (mounted) setState(() { _errorLocales = e.toString().replaceAll('Exception: ', ''); _isLoadingLocales = false; });
    }
  }

  Future<void> _buscarEnCatalogoCIE(String query) async {
    final termino = query.trim();
    if (termino.isEmpty) {
      setState(() => _catalogoResultados = []);
      return;
    }
    setState(() {
      _isLoadingCatalogo = true;
      _errorCatalogo = null;
    });
    try {
      final resultados = await ApiService.buscarCatalogoCIE(termino);
      if (mounted) setState(() { _catalogoResultados = resultados; _isLoadingCatalogo = false; });
    } catch (e) {
      if (mounted) setState(() { _errorCatalogo = e.toString().replaceAll('Exception: ', ''); _isLoadingCatalogo = false; });
    }
  }

  void _onCatalogoSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (value.trim().isNotEmpty) _buscarEnCatalogoCIE(value);
    });
  }

  Future<void> _importarDiagnostico(dynamic item) async {
    final ts = ThemeService.instance;
    try {
      await ApiService.importarDesdeCatalogoCIE({
        'codigo_cie': item['codigo_cie'],
        'descripcion': item['descripcion'],
        'categoria': item['categoria'],
        'comentarios_especiales': item['comentarios_especiales'],
        'activo': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Diagnóstico ${item["codigo_cie"]} incorporado a la farmacia!'),
          backgroundColor: ts.accentPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => item['ya_registrado'] = true);
      _cargarEnfermedadesLocales(query: _searchLocalController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: ts.neonRed,
        ),
      );
    }
  }

  void _mostrarDialogoNuevoDiagnostico() => _mostrarDialogoDiagnostico();

  void _mostrarDialogoEditarDiagnostico(dynamic enf) => _mostrarDialogoDiagnostico(existing: enf);

  void _mostrarDialogoDiagnostico({dynamic existing}) {
    final ts = ThemeService.instance;
    final bool isEdit = existing != null;
    final codigoController = TextEditingController(text: existing?['codigo_cie']?.toString() ?? '');
    final descController = TextEditingController(text: existing?['descripcion']?.toString() ?? '');
    final catController = TextEditingController(text: existing?['categoria']?.toString() ?? '');
    final notasController = TextEditingController(text: existing?['comentarios_especiales']?.toString() ?? '');
    bool buscandoAutocompletar = false;
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          backgroundColor: ts.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
          ),
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit_note_rounded : Icons.medical_services_outlined, color: ts.accentPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isEdit ? 'Editar Diagnóstico CIE-11' : 'Registrar Diagnóstico CIE-11',
                  style: TextStyle(color: ts.textPrimary),
                ),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codigoController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: isEdit ? 'Código CIE-11 *' : 'Código CIE-11 * (ej: 5A11, BA00, CA23)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.tag),
                          ),
                        ),
                      ),
                      if (!isEdit) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ts.tintBg(ts.accentPrimary),
                            foregroundColor: ts.accentPrimary,
                          ),
                          onPressed: buscandoAutocompletar
                              ? null
                              : () async {
                                  final cod = codigoController.text.trim();
                                  if (cod.isEmpty) return;
                                  setModalState(() => buscandoAutocompletar = true);
                                  try {
                                    final res = await ApiService.buscarCatalogoCIE(cod, limit: 1);
                                    if (res.isNotEmpty) {
                                      final match = res.first;
                                      descController.text = match['descripcion'] ?? '';
                                      catController.text = match['categoria'] ?? '';
                                      notasController.text = match['comentarios_especiales'] ?? '';
                                    }
                                  } catch (_) {}
                                  if (modalCtx.mounted) setModalState(() => buscandoAutocompletar = false);
                                },
                          icon: buscandoAutocompletar
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: ts.accentPrimary),
                                )
                              : const Icon(Icons.auto_fix_high),
                          label: const Text('Completar'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Nombre de la Enfermedad *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catController,
                    decoration: const InputDecoration(
                      labelText: 'Categoría (ej: Infecciones respiratorias, Cardiovascular)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notasController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Consideraciones Sanitarias / Farmacológicas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
              onPressed: guardando
                  ? null
                  : () async {
                      if (codigoController.text.trim().isEmpty || descController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código CIE y Descripción son obligatorios')),
                        );
                        return;
                      }
                      final payload = {
                        'codigo_cie': codigoController.text.trim().toUpperCase(),
                        'descripcion': descController.text.trim(),
                        'categoria': catController.text.trim().isEmpty ? null : catController.text.trim(),
                        'comentarios_especiales':
                            notasController.text.trim().isEmpty ? null : notasController.text.trim(),
                        if (!isEdit) 'activo': true,
                      };
                      setModalState(() => guardando = true);
                      try {
                        if (isEdit) {
                          final uri = Uri.parse('${ApiService.baseUrl}/api/enfermedades/${existing['id']}');
                          final response = await http.put(
                            uri,
                            headers: _authHeaders(isJson: true),
                            body: jsonEncode(payload),
                          );
                          if (response.statusCode != 200) {
                            _mostrarErrorHttp(response, 'Error al actualizar (${response.statusCode})');
                            return;
                          }
                        } else {
                          await ApiService.createEnfermedad(payload);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _cargarEnfermedadesLocales(query: _searchLocalController.text);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Diagnóstico actualizado con éxito' : 'Diagnóstico registrado con éxito'),
                              backgroundColor: isEdit ? ts.neonGreen : null,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                          );
                        }
                      } finally {
                        if (modalCtx.mounted) setModalState(() => guardando = false);
                      }
                    },
              child: guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarDiagnostico(dynamic enf) {
    final ts = ThemeService.instance;
    bool eliminando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          backgroundColor: ts.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: ts.neonRed),
              const SizedBox(width: 8),
              Flexible(child: Text('Desactivar Diagnóstico', style: TextStyle(color: ts.textPrimary))),
            ],
          ),
          content: Text(
            '¿Deseas desactivar el diagnóstico "${enf['codigo_cie']} - ${enf['descripcion']}" del catálogo local?',
            style: TextStyle(color: ts.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: eliminando ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ts.neonRed, foregroundColor: Colors.white),
              onPressed: eliminando
                  ? null
                  : () async {
                      setModalState(() => eliminando = true);
                      try {
                        final uri = Uri.parse('${ApiService.baseUrl}/api/enfermedades/${enf['id']}');
                        final response = await http.delete(uri, headers: _authHeaders());
                        if (response.statusCode == 200 || response.statusCode == 204) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _cargarEnfermedadesLocales(query: _searchLocalController.text);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Diagnóstico desactivado'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        } else {
                          _mostrarErrorHttp(response, 'No se pudo desactivar (${response.statusCode})');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error de conexión: $e'), backgroundColor: ts.neonRed),
                          );
                        }
                      } finally {
                        if (modalCtx.mounted) setModalState(() => eliminando = false);
                      }
                    },
              child: eliminando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Desactivar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarErrorHttp(http.Response response, String fallback) {
    String detail = fallback;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['detail'] != null) detail = body['detail'].toString();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail), backgroundColor: ThemeService.instance.neonRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final bool isMobile = MediaQuery.of(context).size.width < 680;
    final int totalLocales = _enfermedadesLocales.length;

    return Scaffold(
      backgroundColor: ts.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumModuleHeader(
                title: 'Catálogo de Diagnósticos CIE-11',
                subtitle: 'Clasificación Internacional de Enfermedades (OMS/NIH) y diagnósticos registrados en farmacia.',
                icon: Icons.healing_rounded,
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ts.esTemaNeon
                        ? ts.accentPrimary.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ts.esTemaNeon
                          ? ts.accentPrimary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '$totalLocales REGISTRADOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                actions: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                      foregroundColor: ts.esTemaNeon ? Colors.black : ts.headerBg,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _mostrarDialogoNuevoDiagnostico,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nuevo Diagnóstico', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: ts.esTemaNeon
                          ? ts.tintBg(ts.accentPrimary)
                          : Colors.white.withValues(alpha: 0.2),
                      foregroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Actualizar lista',
                    onPressed: () => _cargarEnfermedadesLocales(query: _searchLocalController.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: ts.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ts.borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  labelColor: ts.accentPrimary,
                  unselectedLabelColor: ts.textSecondary,
                  indicatorColor: ts.accentPrimary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(icon: const Icon(Icons.local_hospital_outlined, size: 18), text: 'Mis Diagnósticos ($totalLocales)'),
                    const Tab(icon: Icon(Icons.public_rounded, size: 18), text: 'Catálogo Oficial CIE-11 (OMS/NIH)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabLocales(ts, isMobile),
                    _buildTabCatalogoCIE(ts, isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildSearchDecoration(
    ThemeService ts, {
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    required VoidCallback onClear,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: ts.textSecondary, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: ts.accentPrimary),
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(icon: Icon(Icons.clear_rounded, color: ts.textSecondary), onPressed: onClear)
          : null,
      filled: true,
      fillColor: ts.surfaceBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ts.borderColor)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ts.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ts.accentPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildCodeBadge(ThemeService ts, String codigo, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ts.tintBg(color, lightAlpha: 0.12, darkAlpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        codigo,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildTabLocales(ThemeService ts, bool isMobile) {
    final int total = _enfermedadesLocales.length;
    final int cronicos = _enfermedadesLocales.where(_esDiagnosticoCronico).length;
    final int agudos = total - cronicos;
    final List<dynamic> filtradas = _enfermedadesFiltradas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumSurfaceCard(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchLocalController,
                style: TextStyle(color: ts.textPrimary),
                decoration: _buildSearchDecoration(
                  ts,
                  hintText: 'Filtrar por código CIE-11 o descripción (ej: 5A11, BA00, Diabetes, Asma)...',
                  prefixIcon: Icons.search_rounded,
                  controller: _searchLocalController,
                  onClear: () {
                    _searchLocalController.clear();
                    setState(() {});
                    _cargarEnfermedadesLocales();
                  },
                ),
                onChanged: (val) {
                  setState(() {});
                  _cargarEnfermedadesLocales(query: val);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip(ts, label: 'Todos', value: 'todos', icon: Icons.apps_rounded),
                      _buildFilterChip(ts, label: 'Crónicos', value: 'cronicos', icon: Icons.timelapse_rounded),
                      _buildFilterChip(ts, label: 'Agudos', value: 'agudos', icon: Icons.bolt_rounded),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildKpiPill(ts, label: 'Total', value: '$total', color: ts.accentPrimary),
                      _buildKpiPill(ts, label: 'Crónicos', value: '$cronicos', color: ts.neonPurple),
                      _buildKpiPill(ts, label: 'Agudos', value: '$agudos', color: ts.neonBlue),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
                Expanded(
                  child: _isLoadingLocales
                      ? const Center(child: CircularProgressIndicator())
                      : _errorLocales != null
                          ? _buildStatusCard(ts, text: 'Error: $_errorLocales', isError: true)
                          : filtradas.isEmpty
                              ? _buildStatusCard(
                                  ts,
                                  icon: Icons.search_off_rounded,
                                  text: 'No hay diagnósticos que coincidan con el filtro actual',
                                  action: FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: ts.tintBg(ts.accentPrimary),
                                      foregroundColor: ts.accentPrimary,
                                    ),
                                    onPressed: () => _tabController.animateTo(1),
                                    icon: const Icon(Icons.public_rounded, size: 18),
                                    label: const Text('Buscar en Catálogo Global CIE-11'),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtradas.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _buildDiagnosticoLocalCard(ts, filtradas[index], isMobile),
                                ),
                ),
      ],
    );
  }

  Widget _buildFilterChip(ThemeService ts, {required String label, required String value, required IconData icon}) {
    final bool selected = _filtroTipoLocal == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: selected ? ts.accentPrimary : ts.textSecondary),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? ts.accentPrimary : ts.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.14, darkAlpha: 0.24),
      backgroundColor: ts.surfaceBg,
      side: BorderSide(color: selected ? ts.accentPrimary.withValues(alpha: 0.5) : ts.borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
      onSelected: (_) => setState(() => _filtroTipoLocal = value),
    );
  }

  Widget _buildKpiPill(ThemeService ts, {required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ts.tintBg(color, lightAlpha: 0.10, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDiagnosticoLocalCard(ThemeService ts, dynamic enf, bool isMobile) {
    final bool esCronico = _esDiagnosticoCronico(enf);
    final Color tipoColor = esCronico ? ts.neonPurple : ts.neonBlue;
    final codeBadge = _buildCodeBadge(ts, enf['codigo_cie'] ?? '', ts.accentPrimary);

    final tipoPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ts.tintBg(tipoColor, lightAlpha: 0.12, darkAlpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tipoColor.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(esCronico ? Icons.timelapse_rounded : Icons.bolt_rounded, size: 13, color: tipoColor),
          const SizedBox(width: 4),
          Text(
            esCronico ? 'Crónico' : 'Agudo',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tipoColor),
          ),
        ],
      ),
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Editar diagnóstico',
          icon: Icon(Icons.edit_outlined, size: 19, color: ts.accentPrimary),
          style: IconButton.styleFrom(
            backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.08, darkAlpha: 0.16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _mostrarDialogoEditarDiagnostico(enf),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Desactivar diagnóstico',
          icon: Icon(Icons.delete_outline_rounded, size: 19, color: ts.neonRed),
          style: IconButton.styleFrom(
            backgroundColor: ts.tintBg(ts.neonRed, lightAlpha: 0.08, darkAlpha: 0.16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _confirmarEliminarDiagnostico(enf),
        ),
      ],
    );

    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enf['descripcion'] ?? '',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ts.textPrimary),
        ),
        if (enf['categoria'] != null && enf['categoria'].toString().trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: ts.textSecondary),
              const SizedBox(width: 5),
              Expanded(child: Text(enf['categoria'], style: TextStyle(color: ts.textSecondary, fontSize: 12))),
            ],
          ),
        ],
        if (enf['comentarios_especiales'] != null && enf['comentarios_especiales'].toString().trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.medical_information_outlined, size: 14, color: ts.neonAmber),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Nota Sanitaria: ${enf["comentarios_especiales"]}',
                  style: TextStyle(color: ts.neonAmber, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return AnimatedHoverScaleCard(
      hoverScale: 1.008,
      cursor: SystemMouseCursors.basic,
      child: PremiumSurfaceCard(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        elevatedGlow: !ts.esTemaNeon,
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [codeBadge, const SizedBox(width: 8), tipoPill, const Spacer(), actionsRow]),
                  const SizedBox(height: 10),
                  detailsColumn,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  codeBadge,
                  const SizedBox(width: 14),
                  Expanded(child: detailsColumn),
                  const SizedBox(width: 12),
                  tipoPill,
                  const SizedBox(width: 12),
                  actionsRow,
                ],
              ),
      ),
    );
  }

  Widget _buildTabCatalogoCIE(ThemeService ts, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumSurfaceCard(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ts.tintBg(ts.neonBlue),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ts.neonBlue.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, color: ts.neonBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Catálogo oficial de Clasificación Internacional de Enfermedades 11.ª Revisión (CIE-11 / OMS). '
                        'Conectado a la API oficial de terminología médica global (NIH/OMS). Busca cualquier condición y agrégala a tu farmacia.',
                        style: TextStyle(color: ts.textPrimary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCatalogoController,
                      style: TextStyle(color: ts.textPrimary),
                      decoration: _buildSearchDecoration(
                        ts,
                        hintText: 'Escribe un diagnóstico, síntoma o código CIE-11 (ej: Neumonía, Asma, 5A11)...',
                        prefixIcon: Icons.travel_explore_rounded,
                        controller: _searchCatalogoController,
                        onClear: () {
                          _searchCatalogoController.clear();
                          setState(() => _catalogoResultados = []);
                        },
                      ),
                      onChanged: _onCatalogoSearchChanged,
                      onSubmitted: _buscarEnCatalogoCIE,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.accentPrimary,
                      foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _buscarEnCatalogoCIE(_searchCatalogoController.text),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingCatalogo
              ? const Center(child: CircularProgressIndicator())
              : _errorCatalogo != null
                  ? _buildStatusCard(ts, text: 'Error: $_errorCatalogo', isError: true)
                  : _catalogoResultados.isEmpty
                      ? _buildStatusCard(
                          ts,
                          icon: Icons.menu_book_rounded,
                          text: 'Ingresa un término o código para consultar el catálogo oficial CIE-11',
                        )
                      : ListView.separated(
                          itemCount: _catalogoResultados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildCatalogoCard(ts, _catalogoResultados[index], isMobile),
                        ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeService ts, {required String text, IconData? icon, bool isError = false, Widget? action}) {
    return Center(
      child: PremiumSurfaceCard(
        accentBorder: isError ? ts.neonRed.withValues(alpha: 0.45) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: ts.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: icon != null ? FontWeight.bold : FontWeight.normal,
                color: isError ? ts.neonRed : ts.textPrimary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogoCard(ThemeService ts, dynamic item, bool isMobile) {
    final bool yaRegistrado = item['ya_registrado'] == true;
    final codeBox = _buildCodeBadge(ts, item['codigo_cie'] ?? '', yaRegistrado ? ts.neonGreen : ts.accentPrimary);
    final actionWidget = yaRegistrado
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ts.tintBg(ts.neonGreen),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: ts.neonGreen),
                const SizedBox(width: 5),
                Text('En Farmacia', style: TextStyle(color: ts.neonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _importarDiagnostico(item),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Agregar a Farmacia'),
          );
    final infoCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item['descripcion'] ?? '',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ts.textPrimary),
        ),
        const SizedBox(height: 4),
        Text('Categoría: ${item["categoria"] ?? "General"}', style: TextStyle(color: ts.textSecondary, fontSize: 12)),
        if (item['comentarios_especiales'] != null && item['comentarios_especiales'].toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Guía Clínica: ${item["comentarios_especiales"]}',
            style: TextStyle(color: ts.accentPrimary, fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
    return AnimatedHoverScaleCard(
      hoverScale: 1.008,
      cursor: SystemMouseCursors.basic,
      child: PremiumSurfaceCard(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        accentBorder: yaRegistrado ? ts.neonGreen.withValues(alpha: 0.45) : null,
        elevatedGlow: !ts.esTemaNeon,
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [codeBox, actionWidget]),
                  const SizedBox(height: 10),
                  infoCol,
                ],
              )
            : Row(children: [codeBox, const SizedBox(width: 14), Expanded(child: infoCol), const SizedBox(width: 12), actionWidget]),
      ),
    );
  }
}
