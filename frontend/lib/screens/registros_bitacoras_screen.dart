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
    final rol = AuthService().usuarioActual.rol.toUpperCase();
    final puedeCofepris = rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO';
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: puedeCofepris ? 0 : 3,
    );
    if (puedeCofepris) {
      _cargarBitacora();
      _cargarDocumentos();
    } else {
      _loadingBitacora = false;
      _loadingDocs = false;
    }
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

  Widget _buildBentoMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final ts = ThemeService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ts.tintBg(color, lightAlpha: 0.08, darkAlpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ts.tintBg(color, lightAlpha: 0.16, darkAlpha: 0.26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ts.textPrimary),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color, {IconData? icon}) {
    final ts = ThemeService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow({
    required IconData icon,
    required Color accentColor,
    required Widget title,
    required String subtitle,
    required Widget trailing,
    Color? borderColor,
  }) {
    final ts = ThemeService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ts.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? ts.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ts.tintBg(accentColor, lightAlpha: 0.12, darkAlpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 11, color: ts.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDateBtn({
    required String label,
    required IconData icon,
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onPicked,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () async {
        final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _buildFieldBox(double width, TextEditingController ctrl, String label, {TextInputType? keyboard}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Widget _buildDropdownBox(
    double width,
    String value,
    String label,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTabBitacoraTemp() {
    final ts = ThemeService.instance;
    final total = _bitacora.length;
    final dentro = _bitacora.where((b) => b['dentro_norma'] == true).length;
    final pct = total > 0 ? ((dentro / total) * 100.0).toStringAsFixed(1) : '100.0';
    final normaColor = dentro == total
        ? ts.neonGreen
        : (total > 0 && (dentro / total) < 0.8 ? ts.neonRed : ts.neonAmber);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildBentoMetricTile(
                label: 'Total lecturas',
                value: '$total',
                icon: Icons.thermostat_rounded,
                color: ts.accentPrimary,
                subtitle: _filtroZona == 'TODAS' ? 'Todas las zonas' : _filtroZona,
              ),
              _buildBentoMetricTile(
                label: '% en norma',
                value: '$pct%',
                icon: Icons.verified_outlined,
                color: normaColor,
                subtitle: '$dentro de $total dentro de rango',
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    _buildDropdownBox(150, _turno, 'Turno', const [
                      DropdownMenuItem(value: 'MATUTINO', child: Text('Matutino', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'VESPERTINO', child: Text('Vespertino', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'NOCTURNO', child: Text('Nocturno', overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _turno = v ?? 'MATUTINO')),
                    _buildDropdownBox(200, _zona, 'Zona', const [
                      DropdownMenuItem(value: 'ANAQUEL_GENERAL', child: Text('Anaquel General', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'RED_FRIO', child: Text('Red de Frío', overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _zona = v ?? 'ANAQUEL_GENERAL')),
                    _buildFieldBox(120, _tempCtrl, 'Temp (°C)', keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true)),
                    _buildFieldBox(120, _humCtrl, 'Humedad (%)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
                    _buildFieldBox(240, _obsCtrl, 'Observaciones (opcional)'),
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
                    _buildDropdownBox(190, _filtroZona, 'Filtrar zona', const [
                      DropdownMenuItem(value: 'TODAS', child: Text('Todas las zonas', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'ANAQUEL_GENERAL', child: Text('Anaquel General', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'RED_FRIO', child: Text('Red de Frío', overflow: TextOverflow.ellipsis)),
                    ], (v) {
                      setState(() => _filtroZona = v ?? 'TODAS');
                      _cargarBitacora();
                    }),
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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = _bitacora[i];
                      final ok = b['dentro_norma'] == true;
                      final statusColor = ok ? ts.neonGreen : ts.neonRed;
                      final obs = (b['observaciones'] ?? '').toString();
                      return _buildLogRow(
                        icon: ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        accentColor: statusColor,
                        borderColor: ok ? ts.borderColor : ts.neonRed.withValues(alpha: 0.40),
                        title: Text(
                          '${b['zona']} (${b['turno']}) — ${b['temperatura_c']} °C | ${b['humedad_relativa_pct']}% HR',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ts.textPrimary),
                        ),
                        subtitle: '${_fmtFechaHora(b['fecha_registro']?.toString())} • ${b['responsable_nombre'] ?? ''}'
                            '${obs.isNotEmpty ? ' • $obs' : ''}',
                        trailing: _buildStatusPill(
                          ok ? 'EN NORMA' : 'FUERA',
                          statusColor,
                          icon: ok ? Icons.verified_outlined : Icons.error_outline,
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
    final activos = _docs.where((d) => d['activo'] != false).length;
    int? minDias;
    for (final d in _docs) {
      final dias = (d['dias_restantes'] as num?)?.toInt();
      if (dias != null && (minDias == null || dias < minDias)) {
        minDias = dias;
      }
    }
    final vigenciaColor = minDias == null
        ? ts.textSecondary
        : (minDias >= 30 ? ts.neonGreen : (minDias >= 0 ? ts.neonAmber : ts.neonRed));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildBentoMetricTile(
                label: 'Documentos activos',
                value: '$activos',
                icon: Icons.folder_copy_outlined,
                color: ts.accentPrimary,
                subtitle: '${_docs.length} registrados',
              ),
              _buildBentoMetricTile(
                label: 'Menor vigencia',
                value: minDias == null ? 'Sin docs' : '$minDias días',
                icon: Icons.event_available_rounded,
                color: vigenciaColor,
                subtitle: minDias == null
                    ? 'Registra un documento'
                    : (minDias >= 30 ? 'Vigencia saludable' : 'Requiere renovación'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    _buildDropdownBox(260, _tipoDoc, 'Tipo de documento', const [
                      DropdownMenuItem(value: 'AVISO_FUNCIONAMIENTO', child: Text('Aviso de Funcionamiento', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'LICENCIA_SANITARIA', child: Text('Licencia Sanitaria', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'RESPONSABLE_SANITARIO', child: Text('Responsable Sanitario', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'CAPACITACION_COFEPRIS', child: Text('Capacitación Personal', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'FUMIGACION_CONTROL_PLAGAS', child: Text('Control de Plagas', overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _tipoDoc = v ?? 'AVISO_FUNCIONAMIENTO')),
                    _buildFieldBox(180, _folioDocCtrl, 'Folio / Certificado'),
                    _buildDateBtn(
                      label: 'Emisión: ${_fmtDate(_emisionDoc)}',
                      icon: Icons.date_range,
                      initial: _emisionDoc,
                      first: DateTime(2015),
                      last: DateTime(2040),
                      onPicked: (d) => setState(() => _emisionDoc = d),
                    ),
                    _buildDateBtn(
                      label: 'Vence: ${_fmtDate(_vencimientoDoc)}',
                      icon: Icons.event_available,
                      initial: _vencimientoDoc,
                      first: DateTime(2020),
                      last: DateTime(2050),
                      onPicked: (d) => setState(() => _vencimientoDoc = d),
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
                : _docs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No hay documentos sanitarios registrados.', style: TextStyle(color: ts.textSecondary)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final d = _docs[i];
                          final dias = (d['dias_restantes'] as num?)?.toInt() ?? 0;
                          final ok = dias >= 30;
                          final docColor = ok ? ts.neonGreen : (dias >= 0 ? ts.neonAmber : ts.neonRed);
                          return _buildLogRow(
                            icon: Icons.description_outlined,
                            accentColor: docColor,
                            borderColor: ok ? ts.borderColor : docColor.withValues(alpha: 0.40),
                            title: Text(
                              '${d['tipo_documento']} • Folio: ${d['folio_documento']}',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ts.textPrimary),
                            ),
                            subtitle: 'Emisión: ${d['fecha_emision']} • Vence: ${d['fecha_vencimiento']}',
                            trailing: _buildStatusPill(
                              '$dias días',
                              docColor,
                              icon: ok ? Icons.verified_user_outlined : Icons.schedule_rounded,
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildBentoMetricTile(
                label: 'Total periodo',
                value: '\$${totalMonto.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
                color: ts.accentPrimary,
                subtitle: '${items.length} movimientos',
              ),
              _buildBentoMetricTile(
                label: 'Nómina',
                value: '\$${totalNomina.toStringAsFixed(2)}',
                icon: Icons.badge_outlined,
                color: ts.neonPurple,
                subtitle: 'Sueldos y prestaciones',
              ),
              _buildBentoMetricTile(
                label: 'Operativos',
                value: '\$${totalOtros.toStringAsFixed(2)}',
                icon: Icons.receipt_long_rounded,
                color: ts.neonAmber,
                subtitle: 'Servicios, renta e insumos',
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    _buildDateBtn(
                      label: 'Fecha: ${_fmtDate(_fechaGasto)}',
                      icon: Icons.calendar_today,
                      initial: _fechaGasto,
                      first: DateTime(2020),
                      last: DateTime(2035),
                      onPicked: (d) => setState(() => _fechaGasto = d),
                    ),
                    _buildDropdownBox(
                      250,
                      _categoriaGasto,
                      'Categoría',
                      _categoriasGasto
                          .map((c) => DropdownMenuItem(value: c['code'], child: Text(c['label']!, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      (v) => setState(() => _categoriaGasto = v ?? 'SERVICIOS'),
                    ),
                    _buildFieldBox(220, _conceptoGastoCtrl, 'Concepto / Detalle *'),
                    _buildFieldBox(130, _montoGastoCtrl, 'Monto MXN *', keyboard: const TextInputType.numberWithOptions(decimal: true)),
                    _buildDropdownBox(160, _metodoPagoGasto, 'Método pago', const [
                      DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta', overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _metodoPagoGasto = v ?? 'EFECTIVO')),
                    _buildFieldBox(150, _folioGastoCtrl, 'Folio / Factura'),
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
                if (porCategoria.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: porCategoria.entries
                        .map((e) => _buildStatusPill(
                              '${e.key}: \$${(e.value as num).toStringAsFixed(2)}',
                              e.key == 'NOMINA' ? ts.neonPurple : ts.accentPrimary,
                            ))
                        .toList(),
                  ),
                ],
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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final g = items[i];
                      final cat = (g['categoria'] ?? '').toString();
                      final catColor = cat == 'NOMINA' ? ts.neonPurple : ts.accentPrimary;
                      final folio = (g['comprobante_folio'] ?? '').toString();
                      return _buildLogRow(
                        icon: Icons.receipt_long_rounded,
                        accentColor: catColor,
                        title: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${g['concepto']} — \$${(g['monto'] as num).toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ts.textPrimary),
                            ),
                            _buildStatusPill(cat, catColor),
                          ],
                        ),
                        subtitle: '${g['fecha_gasto']} • ${g['metodo_pago']}${folio.isNotEmpty ? ' • Folio: $folio' : ''}',
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
