import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  final _searchLocalController = TextEditingController();

  // Pestaña 2: Catálogo CIE-10 (API / Global)
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
    // Búsqueda inicial en catálogo para poblar sugerencias
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

  Future<void> _cargarEnfermedadesLocales({String? query}) async {
    setState(() {
      _isLoadingLocales = true;
      _errorLocales = null;
    });

    try {
      final list = await ApiService.getEnfermedades(buscar: query);
      if (mounted) {
        setState(() {
          _enfermedadesLocales = list;
          _isLoadingLocales = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorLocales = e.toString().replaceAll('Exception: ', '');
          _isLoadingLocales = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _catalogoResultados = resultados;
          _isLoadingCatalogo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorCatalogo = e.toString().replaceAll('Exception: ', '');
          _isLoadingCatalogo = false;
        });
      }
    }
  }

  void _onCatalogoSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (value.trim().isNotEmpty) {
        _buscarEnCatalogoCIE(value);
      }
    });
  }

  Future<void> _importarDiagnostico(dynamic item) async {
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
          backgroundColor: Colors.teal.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Actualizar estado en vista de catálogo
      setState(() {
        item['ya_registrado'] = true;
      });

      // Recargar lista local
      _cargarEnfermedadesLocales();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _mostrarDialogoNuevoDiagnostico() {
    final codigoController = TextEditingController();
    final descController = TextEditingController();
    final catController = TextEditingController();
    final notasController = TextEditingController();
    bool buscandoAutocompletar = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.medical_services_outlined, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              const Text('Registrar Diagnóstico CIE-10'),
            ],
          ),
          content: SizedBox(
            width: 520,
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
                          decoration: const InputDecoration(
                            labelText: 'Código CIE-10 * (ej: J00, A09, E11, I10)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
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
                                setModalState(() => buscandoAutocompletar = false);
                              },
                        icon: buscandoAutocompletar
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_fix_high),
                        label: const Text('Completar'),
                      ),
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
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
              onPressed: () async {
                if (codigoController.text.trim().isEmpty || descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código CIE y Descripción son obligatorios')),
                  );
                  return;
                }

                try {
                  await ApiService.createEnfermedad({
                    'codigo_cie': codigoController.text.trim().toUpperCase(),
                    'descripcion': descController.text.trim(),
                    'categoria': catController.text.trim().isEmpty ? null : catController.text.trim(),
                    'comentarios_especiales': notasController.text.trim().isEmpty ? null : notasController.text.trim(),
                    'activo': true,
                  });
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _cargarEnfermedadesLocales();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagnóstico registrado con éxito')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Diagnósticos y Enfermedades CIE-10'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal.shade900,
          indicatorColor: Colors.teal.shade800,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.local_hospital_outlined),
              text: 'Mis Diagnósticos en Farmacia (${_enfermedadesLocales.length})',
            ),
            const Tab(
              icon: Icon(Icons.public),
              text: 'Catálogo Oficial CIE-10 (Búsqueda Global y API)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // =================================================================
          // PESTAÑA 1: DIAGNÓSTICOS REGISTRADOS EN LA FARMACIA
          // =================================================================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchLocalController,
                        decoration: InputDecoration(
                          hintText: 'Filtrar por código CIE o descripción (ej: J00, Diabetes, Asma)...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchLocalController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchLocalController.clear();
                                    _cargarEnfermedadesLocales();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          setState(() {});
                          _cargarEnfermedadesLocales(query: val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _mostrarDialogoNuevoDiagnostico,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Diagnóstico'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar lista',
                      onPressed: () => _cargarEnfermedadesLocales(query: _searchLocalController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingLocales
                      ? const Center(child: CircularProgressIndicator())
                      : _errorLocales != null
                          ? Center(child: Text('Error: $_errorLocales'))
                          : _enfermedadesLocales.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No hay diagnósticos que coincidan con la búsqueda',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          _tabController.animateTo(1);
                                        },
                                        child: const Text('Buscar en Catálogo Global CIE-10'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _enfermedadesLocales.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final enf = _enfermedadesLocales[index];
                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Text(
                                            enf['codigo_cie'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.teal.shade900,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          enf['descripcion'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            if (enf['categoria'] != null)
                                              Row(
                                                children: [
                                                  Icon(Icons.folder_outlined, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    enf['categoria'],
                                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            if (enf['comentarios_especiales'] != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Nota Sanitaria: ${enf["comentarios_especiales"]}',
                                                style: TextStyle(
                                                  color: Colors.amber.shade900,
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),

          // =================================================================
          // PESTAÑA 2: CATÁLOGO OFICIAL CIE-10 (BÚSQUEDA GLOBAL Y EN LÍNEA)
          // =================================================================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Catálogo oficial de Clasificación Internacional de Enfermedades (CIE-10 / OMS). '
                          'Busca cualquier condición y agrégala a tu farmacia con un solo clic.',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCatalogoController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un diagnóstico, síntoma o código (ej: Neumonía, Asma, Gastritis, I10, J00)...',
                          prefixIcon: const Icon(Icons.travel_explore),
                          suffixIcon: _searchCatalogoController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCatalogoController.clear();
                                    setState(() => _catalogoResultados = []);
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: _onCatalogoSearchChanged,
                        onSubmitted: _buscarEnCatalogoCIE,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _buscarEnCatalogoCIE(_searchCatalogoController.text),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingCatalogo
                      ? const Center(child: CircularProgressIndicator())
                      : _errorCatalogo != null
                          ? Center(child: Text('Error: $_errorCatalogo'))
                          : _catalogoResultados.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.menu_book, size: 50, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Ingresa un término para consultar el catálogo CIE-10',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _catalogoResultados.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = _catalogoResultados[index];
                                    final bool yaRegistrado = item['ya_registrado'] == true;

                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: yaRegistrado ? Colors.green.shade200 : Colors.blue.shade100,
                                        ),
                                      ),
                                      color: yaRegistrado ? Colors.green.shade50.withValues(alpha: 0.3) : Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 70,
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: yaRegistrado ? Colors.green.shade100 : Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item['codigo_cie'] ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: yaRegistrado ? Colors.green.shade900 : Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['descripcion'] ?? '',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Categoría: ${item["categoria"] ?? "General"}',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                  ),
                                                  if (item['comentarios_especiales'] != null &&
                                                      item['comentarios_especiales'].toString().isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Guía Clínica: ${item["comentarios_especiales"]}',
                                                      style: TextStyle(
                                                        color: Colors.teal.shade800,
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            if (yaRegistrado)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade800),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'En Farmacia',
                                                      style: TextStyle(
                                                        color: Colors.green.shade900,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.teal.shade800,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: () => _importarDiagnostico(item),
                                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                                label: const Text('Agregar a Farmacia'),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
