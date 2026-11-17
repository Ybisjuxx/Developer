import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';
import 'devoluciones_screen.dart';

class RegistrosBitacorasScreen extends StatefulWidget {
  const RegistrosBitacorasScreen({super.key});

  @override
  State<RegistrosBitacorasScreen> createState() => _RegistrosBitacorasScreenState();
}

class _RegistrosBitacorasScreenState extends State<RegistrosBitacorasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Estado Tab 1: Bitácora Temp & Humedad ---
  bool _loadingBitacora = true;
  bool _savingBitacora = false;
  String _rangoBitacora = 'hoy'; // hoy | 7dias | mes
  String _filtroZona = 'TODAS';
  List<dynamic> _bitacora = [];
  String _turno = 'MATUTINO';
  String _zona = 'ANAQUEL_GENERAL';
  final _tempCtrl = TextEditingController(text: '21.5');
  final _humCtrl = TextEditingController(text: '48.0');
  final _obsCtrl = TextEditingController();

  // --- Estado Tab 2: Documentos Sanitarios ---
  bool _loadingDocs = true;
  bool _savingDoc = false;
  List<dynamic> _docs = [];
  String _tipoDoc = 'AVISO_FUNCIONAMIENTO';
  final _folioDocCtrl = TextEditingController();
  DateTime _emisionDoc = DateTime.now().subtract(const Duration(days: 30));
  DateTime _vencimientoDoc = DateTime.now().add(const Duration(days: 180));

  // --- Estado Tab 3: Gastos Operativos Fechados ---
  bool _loadingGastos = true;
  bool _savingGasto = false;
  String? _errorGastos;
  String _rangoGastos = 'mes'; // hoy | 7dias | mes
  String _filtroCategoriaGasto = 'TODAS';
  Map<String, dynamic> _gastosData = {};
  DateTime _fechaGasto = DateTime.now();
  String _categoriaGasto = 'SERVICIOS';
  String _metodoPagoGasto = 'EFECTIVO';
  final _conceptoGastoCtrl = TextEditingController();
  final _montoGastoCtrl = TextEditingController();
  final _folioGastoCtrl = TextEditingController();

  static const List<Map<String, String>> _categoriasGasto = [
    {'code': 'NOMINA', 'label': 'Nómina y Sueldos'},
    {'code': 'RENTA', 'label': 'Renta del Local'},
    {'code': 'SERVICIOS', 'label': 'Luz, Agua e Internet'},
    {'code': 'MANTENIMIENTO', 'label': 'Mantenimiento y Calibración'},
    {'code': 'INSUMOS', 'label': 'Insumos y Papelería'},
    {'code': 'IMPUESTOS_PERMISOS', 'label': 'Impuestos y Permisos'},
    {'code': 'OTROS', 'label': 'Otros Gastos'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarBitacora();
    _cargarDocumentos();
    _cargarGastos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tempCtrl.dispose();
    _humCtrl.dispose();
    _obsCtrl.dispose();
    _folioDocCtrl.dispose();
    _conceptoGastoCtrl.dispose();
    _montoGastoCtrl.dispose();
    _folioGastoCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtFechaHora(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cargarBitacora() async {
    setState(() => _loadingBitacora = true);
    try {
      final rows = await ApiService.getBitacoraCofepris(
        rango: _rangoBitacora,
        zona: _filtroZona == 'TODAS' ? null : _filtroZona,
        limit: 200,
      );
      if (mounted) {
        setState(() {
          _bitacora = rows;
          _loadingBitacora = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBitacora = false);
        _snack('Error al cargar bitácora: $e', isError: true);
      }
    }
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _loadingDocs = true);
    try {
      final rows = await ApiService.getDocumentosSanitarios();
      if (mounted) {
        setState(() {
          _docs = rows;
          _loadingDocs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDocs = false);
      }
    }
  }

  Future<void> _cargarGastos() async {
    final rol = AuthService().usuarioActual.rol.toUpperCase();
    if (rol != 'ADMINISTRADOR') {
      setState(() {
        _loadingGastos = false;
        _errorGastos = 'Solo el rol ADMINISTRADOR puede consultar y registrar gastos operativos.';
      });
      return;
    }
    setState(() {
      _loadingGastos = true;
      _errorGastos = null;
    });
    try {
      final data = await ApiService.getGastosOperativos(
        rango: _rangoGastos,
        categoria: _filtroCategoriaGasto == 'TODAS' ? null : _filtroCategoriaGasto,
      );
      if (mounted) {
        setState(() {
          _gastosData = data;
          _loadingGastos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingGastos = false;
          _errorGastos = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final ts = ThemeService.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? ts.neonRed : ts.neonGreen,
      ),
    );
  }

  Future<void> _guardarLecturaBitacora() async {
    final temp = double.tryParse(_tempCtrl.text.trim());
    final hum = double.tryParse(_humCtrl.text.trim());
    if (temp == null || hum == null) {
      _snack('Ingresa valores numéricos válidos para temperatura y humedad.', isError: true);
      return;
    }
    setState(() => _savingBitacora = true);
    try {
      await ApiService.registrarBitacoraCofepris({
        'turno': _turno,
        'zona': _zona,
        'temperatura_c': temp,
        'humedad_relativa_pct': hum,
        if (_obsCtrl.text.trim().isNotEmpty) 'observaciones': _obsCtrl.text.trim(),
      });
      _obsCtrl.clear();
      _snack('Lectura ambiental registrada en bitácora COFEPRIS.');
      await _cargarBitacora();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _savingBitacora = false);
    }
  }

  Future<void> _guardarDocumento() async {
    if (_folioDocCtrl.text.trim().isEmpty) {
      _snack('Ingresa el folio del documento sanitario.', isError: true);
      return;
    }
    setState(() => _savingDoc = true);
    try {
      await ApiService.registrarDocumentoSanitario({
        'tipo_documento': _tipoDoc,
        'folio_documento': _folioDocCtrl.text.trim(),
        'fecha_emision': _fmtDate(_emisionDoc),
        'fecha_vencimiento': _fmtDate(_vencimientoDoc),
        'activo': true,
      });
      _folioDocCtrl.clear();
      _snack('Documento sanitario guardado.');
      await _cargarDocumentos();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _savingDoc = false);
    }
  }

  Future<void> _guardarGasto() async {
    final concepto = _conceptoGastoCtrl.text.trim();
    final monto = double.tryParse(_montoGastoCtrl.text.trim());
    if (concepto.length < 2 || monto == null || monto <= 0) {
      _snack('Ingresa un concepto válido y un monto mayor a 0.', isError: true);
      return;
    }
    setState(() => _savingGasto = true);
    try {
      await ApiService.registrarGastoOperativo({
        'fecha_gasto': _fmtDate(_fechaGasto),
        'categoria': _categoriaGasto,
        'concepto': concepto,
        'monto': monto,
        'metodo_pago': _metodoPagoGasto,
        if (_folioGastoCtrl.text.trim().isNotEmpty) 'comprobante_folio': _folioGastoCtrl.text.trim(),
      });
      _conceptoGastoCtrl.clear();
      _montoGastoCtrl.clear();
      _folioGastoCtrl.clear();
      _snack('Gasto operativo registrado.');
      await _cargarGastos();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _savingGasto = false);
    }
  }

  Future<void> _eliminarGasto(int id) async {
    try {
      await ApiService.eliminarGastoOperativo(id);
      _snack('Gasto eliminado.');
      await _cargarGastos();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PremiumModuleHeader(
              title: 'Registros, Bitácoras y Devoluciones',
              subtitle: 'Control diario COFEPRIS por fecha, gastos operativos desglosados y devoluciones.',
              icon: Icons.fact_check_rounded,
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
                isScrollable: true,
                labelColor: ts.accentPrimary,
                unselectedLabelColor: ts.textSecondary,
                indicatorColor: ts.accentPrimary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.thermostat_rounded), text: 'Temp. y Humedad'),
                  Tab(icon: Icon(Icons.verified_user_outlined), text: 'Docs. Sanitarios'),
                  Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Gastos y Nómina'),
                  Tab(icon: Icon(Icons.assignment_return_outlined), text: 'Devoluciones y Mermas'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabBitacoraTemp(),
                  _buildTabDocumentos(),
                  _buildTabGastos(),
                  const DevolucionesScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangoChips({
    required String actual,
    required ValueChanged<String> onChanged,
  }) {
    final ts = ThemeService.instance;
    final opciones = const [
      {'k': 'hoy', 'label': 'Hoy'},
      {'k': '7dias', 'label': 'Últimos 7 días'},
      {'k': 'mes', 'label': 'Este mes'},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: opciones.map((op) {
        final selected = actual == op['k'];
        return ChoiceChip(
          label: Text(op['label']!),
          selected: selected,
          selectedColor: ts.accentPrimary.withValues(alpha: 0.2),
          onSelected: (_) => onChanged(op['k']!),
        );
      }).toList(),
    );
  }

  Widget _buildTabBitacoraTemp() {
    final ts = ThemeService.instance;
    final total = _bitacora.length;
    final dentro = _bitacora.where((b) => b['dentro_norma'] == true).length;
    final pct = total > 0 ? ((dentro / total) * 100.0).toStringAsFixed(1) : '100.0';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar lectura COFEPRIS (Anaquel 15–30 °C • Red frío 2–8 °C • Humedad 30–65%)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _turno,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Turno', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'MATUTINO', child: Text('Matutino', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'VESPERTINO', child: Text('Vespertino', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'NOCTURNO', child: Text('Nocturno', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _turno = v ?? 'MATUTINO'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _zona,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Zona', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'ANAQUEL_GENERAL', child: Text('Anaquel General', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'RED_FRIO', child: Text('Red de Frío', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _zona = v ?? 'ANAQUEL_GENERAL'),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Temp (°C)', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _humCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Humedad (%)', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _obsCtrl,
                        decoration: const InputDecoration(labelText: 'Observaciones (opcional)', isDense: true),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _savingBitacora ? null : _guardarLecturaBitacora,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_savingBitacora ? 'Guardando...' : 'Guardar lectura'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _buildRangoChips(
                      actual: _rangoBitacora,
                      onChanged: (val) {
                        setState(() => _rangoBitacora = val);
                        _cargarBitacora();
                      },
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filtroZona,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Filtrar zona', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'TODAS', child: Text('Todas las zonas', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'ANAQUEL_GENERAL', child: Text('Anaquel General', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'RED_FRIO', child: Text('Red de Frío', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroZona = v ?? 'TODAS');
                          _cargarBitacora();
                        },
                      ),
                    ),
                    Text(
                      '$total lecturas • $pct% en norma',
                      style: TextStyle(fontWeight: FontWeight.bold, color: ts.accentPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loadingBitacora)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_bitacora.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No hay lecturas registradas en el rango seleccionado.', style: TextStyle(color: ts.textSecondary)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _bitacora.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = _bitacora[i];
                      final ok = b['dentro_norma'] == true;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          ok ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: ok ? ts.neonGreen : ts.neonRed,
                        ),
                        title: Text(
                          '${b['zona']} (${b['turno']}) — ${b['temperatura_c']} °C | ${b['humedad_relativa_pct']}% HR',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${_fmtFechaHora(b['fecha_registro']?.toString())} • ${b['responsable_nombre'] ?? ''}'
                          '${(b['observaciones'] ?? '').toString().isNotEmpty ? ' • ${b['observaciones']}' : ''}',
                          style: TextStyle(fontSize: 11, color: ts.textSecondary),
                        ),
                        trailing: Chip(
                          label: Text(ok ? 'EN NORMA' : 'FUERA', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: (ok ? ts.neonGreen : ts.neonRed).withValues(alpha: 0.15),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabDocumentos() {
    final ts = ThemeService.instance;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documentos Sanitarios y Vigencias (COF-07)', style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoDoc,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tipo de documento', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'AVISO_FUNCIONAMIENTO', child: Text('Aviso de Funcionamiento', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'LICENCIA_SANITARIA', child: Text('Licencia Sanitaria', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'RESPONSABLE_SANITARIO', child: Text('Responsable Sanitario', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'CAPACITACION_COFEPRIS', child: Text('Capacitación Personal', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'FUMIGACION_CONTROL_PLAGAS', child: Text('Control de Plagas', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _tipoDoc = v ?? 'AVISO_FUNCIONAMIENTO'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _folioDocCtrl,
                        decoration: const InputDecoration(labelText: 'Folio / Certificado', isDense: true),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text('Emisión: ${_fmtDate(_emisionDoc)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _emisionDoc,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) setState(() => _emisionDoc = picked);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_available, size: 16),
                      label: Text('Vence: ${_fmtDate(_vencimientoDoc)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _vencimientoDoc,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                        );
                        if (picked != null) setState(() => _vencimientoDoc = picked);
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _savingDoc ? null : _guardarDocumento,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: Text(_savingDoc ? 'Guardando...' : 'Guardar documento'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumSurfaceCard(
            child: _loadingDocs
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _docs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = _docs[i];
                      final dias = (d['dias_restantes'] as num?)?.toInt() ?? 0;
                      final ok = dias >= 30;
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.description_outlined, color: ok ? ts.neonGreen : ts.neonRed),
                        title: Text('${d['tipo_documento']} • Folio: ${d['folio_documento']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('Emisión: ${d['fecha_emision']} • Vence: ${d['fecha_vencimiento']}', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        trailing: Chip(
                          label: Text('$dias días', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: (ok ? ts.neonGreen : ts.neonRed).withValues(alpha: 0.15),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabGastos() {
    final ts = ThemeService.instance;
    if (_errorGastos != null) {
      return Center(child: Text(_errorGastos!, style: TextStyle(color: ts.neonAmber)));
    }
    final items = (_gastosData['items'] as List<dynamic>?) ?? [];
    final totalMonto = (_gastosData['total_monto'] as num?)?.toDouble() ?? 0.0;
    final totalNomina = (_gastosData['total_nomina'] as num?)?.toDouble() ?? 0.0;
    final totalOtros = (_gastosData['total_otros_gastos'] as num?)?.toDouble() ?? 0.0;
    final porCategoria = (_gastosData['por_categoria'] as Map<String, dynamic>?) ?? {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar Gasto Operativo Fechado (alimenta FIN-02, FIN-03 y FIN-04)', style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Fecha: ${_fmtDate(_fechaGasto)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaGasto,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _fechaGasto = picked);
                      },
                    ),
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoriaGasto,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
                        items: _categoriasGasto
                            .map((c) => DropdownMenuItem(value: c['code'], child: Text(c['label']!, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoriaGasto = v ?? 'SERVICIOS'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _conceptoGastoCtrl,
                        decoration: const InputDecoration(labelText: 'Concepto / Detalle *', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _montoGastoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monto MXN *', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        initialValue: _metodoPagoGasto,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Método pago', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _metodoPagoGasto = v ?? 'EFECTIVO'),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _folioGastoCtrl,
                        decoration: const InputDecoration(labelText: 'Folio / Factura', isDense: true),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _savingGasto ? null : _guardarGasto,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(_savingGasto ? 'Guardando...' : 'Registrar gasto'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _buildRangoChips(
                      actual: _rangoGastos,
                      onChanged: (val) {
                        setState(() => _rangoGastos = val);
                        _cargarGastos();
                      },
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filtroCategoriaGasto,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
                        items: [
                          const DropdownMenuItem(value: 'TODAS', child: Text('Todas las categorías', overflow: TextOverflow.ellipsis)),
                          ..._categoriasGasto.map((c) => DropdownMenuItem(value: c['code'], child: Text(c['label']!, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroCategoriaGasto = v ?? 'TODAS');
                          _cargarGastos();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Total periodo: \$${totalMonto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Chip(label: Text('Nómina: \$${totalNomina.toStringAsFixed(2)}')),
                    Chip(label: Text('Operativos: \$${totalOtros.toStringAsFixed(2)}')),
                    ...porCategoria.entries.map(
                      (e) => Chip(
                        label: Text('${e.key}: \$${(e.value as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loadingGastos)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No hay gastos registrados en este rango.', style: TextStyle(color: ts.textSecondary)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final g = items[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: ts.accentPrimary.withValues(alpha: 0.15),
                          child: Icon(Icons.receipt_long, size: 16, color: ts.accentPrimary),
                        ),
                        title: Text(
                          '${g['concepto']} — \$${(g['monto'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${g['fecha_gasto']} • ${g['categoria']} • ${g['metodo_pago']}'
                          '${(g['comprobante_folio'] ?? '').toString().isNotEmpty ? ' • Folio: ${g['comprobante_folio']}' : ''}',
                          style: TextStyle(fontSize: 11, color: ts.textSecondary),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: ts.neonRed, size: 20),
                          tooltip: 'Eliminar gasto',
                          onPressed: () => _eliminarGasto(g['id'] as int),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
