import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'premium_ui.dart';

/// Pestaña operativa para capturar Bitácora Ambiental COFEPRIS,
/// Vigencias Sanitarias y Parámetros Financieros Mensuales.
class CofeprisFinanzasTab extends StatefulWidget {
  const CofeprisFinanzasTab({super.key});

  @override
  State<CofeprisFinanzasTab> createState() => _CofeprisFinanzasTabState();
}

class _CofeprisFinanzasTabState extends State<CofeprisFinanzasTab> {
  bool _cargando = true;
  List<dynamic> _bitacora = [];
  List<dynamic> _documentos = [];

  // Bitácora ambiental
  String _zona = 'ANAQUEL_GENERAL';
  String _turno = 'MATUTINO';
  final _tempCtrl = TextEditingController(text: '22.5');
  final _humCtrl = TextEditingController(text: '48.0');
  final _obsCtrl = TextEditingController();
  bool _guardandoTemp = false;

  // Documentos sanitarios
  String _tipoDoc = 'LICENCIA_SANITARIA';
  final _folioDocCtrl = TextEditingController();
  DateTime _vencimientoDoc = DateTime.now().add(const Duration(days: 180));
  bool _guardandoDoc = false;

  // Parámetros financieros (solo ADMINISTRADOR)
  final _gastosFijosCtrl = TextEditingController(text: '28500');
  final _nominaCtrl = TextEditingController(text: '16500');
  bool _guardandoFin = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _humCtrl.dispose();
    _obsCtrl.dispose();
    _folioDocCtrl.dispose();
    _gastosFijosCtrl.dispose();
    _nominaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      final auth = AuthService();
      final futures = <Future<dynamic>>[
        ApiService.getBitacoraCofepris(limit: 15),
        ApiService.getDocumentosSanitarios(),
        if (auth.isAdmin) ApiService.getParametrosFinancieros(),
      ];
      final res = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _bitacora = res[0] as List<dynamic>;
        _documentos = res[1] as List<dynamic>;
        if (auth.isAdmin && res.length > 2) {
          final fin = res[2] as Map<String, dynamic>;
          _gastosFijosCtrl.text = (fin['gastos_fijos_mensuales'] ?? 28500).toString();
          _nominaCtrl.text = (fin['nomina_mensual'] ?? 16500).toString();
        }
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aviso al cargar registros: $e')),
      );
    }
  }

  Future<void> _guardarLectura() async {
    final temp = double.tryParse(_tempCtrl.text.trim());
    final hum = double.tryParse(_humCtrl.text.trim());
    if (temp == null || hum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa temperatura y humedad numéricas válidas.')),
      );
      return;
    }
    setState(() => _guardandoTemp = true);
    try {
      await ApiService.registrarBitacoraCofepris({
        'turno': _turno,
        'zona': _zona,
        'temperatura_c': temp,
        'humedad_relativa_pct': hum,
        if (_obsCtrl.text.trim().isNotEmpty) 'observaciones': _obsCtrl.text.trim(),
      });
      _obsCtrl.clear();
      await _cargarTodo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeService.instance.neonGreen,
          content: const Text('Lectura ambiental guardada en Bitácora COFEPRIS.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardandoTemp = false);
    }
  }

  Future<void> _guardarDocumento() async {
    if (_folioDocCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el folio del documento sanitario.')),
      );
      return;
    }
    setState(() => _guardandoDoc = true);
    try {
      final hoy = DateTime.now();
      await ApiService.registrarDocumentoSanitario({
        'tipo_documento': _tipoDoc,
        'folio_documento': _folioDocCtrl.text.trim(),
        'fecha_emision': hoy.toIso8601String().split('T').first,
        'fecha_vencimiento': _vencimientoDoc.toIso8601String().split('T').first,
        'activo': true,
      });
      _folioDocCtrl.clear();
      await _cargarTodo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeService.instance.neonGreen,
          content: const Text('Documento sanitario actualizado.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardandoDoc = false);
    }
  }

  Future<void> _guardarFinanzas() async {
    final gastos = double.tryParse(_gastosFijosCtrl.text.trim());
    final nomina = double.tryParse(_nominaCtrl.text.trim());
    if (gastos == null || nomina == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa montos válidos para gastos fijos y nómina.')),
      );
      return;
    }
    setState(() => _guardandoFin = true);
    try {
      final now = DateTime.now();
      await ApiService.actualizarParametrosFinancieros({
        'anio': now.year,
        'mes': now.month,
        'gastos_fijos_mensuales': gastos,
        'nomina_mensual': nomina,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeService.instance.neonGreen,
          content: const Text('Parámetros financieros del mes guardados.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardandoFin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final auth = AuthService();

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!auth.isSanitario) {
      return Center(
        child: Text(
          'Solo Administrador o Responsable Sanitario pueden registrar bitácoras COFEPRIS.',
          style: TextStyle(color: ts.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Bitácora Diaria de Temperatura y Humedad (COF-04)
          PremiumSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.thermostat_rounded, color: ts.neonBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bitácora Diaria de Temperatura y Humedad (COFEPRIS)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ts.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Norma: Anaquel 15–30 °C (HR ≤ 65%) • Red de Frío 2–8 °C. Alimenta el KPI COF-04.',
                  style: TextStyle(fontSize: 12, color: ts.textSecondary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        initialValue: _zona,
                        decoration: const InputDecoration(labelText: 'Zona', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'ANAQUEL_GENERAL', child: Text('Anaquel General (15–30°C)')),
                          DropdownMenuItem(value: 'RED_FRIO', child: Text('Red de Frío (2–8°C)')),
                        ],
                        onChanged: (v) => setState(() => _zona = v ?? 'ANAQUEL_GENERAL'),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _turno,
                        decoration: const InputDecoration(labelText: 'Turno', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'MATUTINO', child: Text('Matutino')),
                          DropdownMenuItem(value: 'VESPERTINO', child: Text('Vespertino')),
                          DropdownMenuItem(value: 'NOCTURNO', child: Text('Nocturno')),
                        ],
                        onChanged: (v) => setState(() => _turno = v ?? 'MATUTINO'),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Temp (°C)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _humCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Humedad (%)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _obsCtrl,
                        decoration: const InputDecoration(labelText: 'Observaciones (opcional)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _guardandoTemp ? null : _guardarLectura,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_guardandoTemp ? 'Guardando...' : 'Registrar Lectura'),
                    ),
                  ],
                ),
                if (_bitacora.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Divider(color: ts.borderColor),
                  ..._bitacora.take(6).map((b) {
                    final bool ok = b['dentro_norma'] == true;
                    final color = ok ? ts.neonGreen : ts.neonRed;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: color, size: 20),
                      title: Text(
                        '${b['zona']} • ${b['temperatura_c']} °C / ${b['humedad_relativa_pct']}% HR (${b['turno']})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts.textPrimary),
                      ),
                      subtitle: Text(
                        '${b['responsable_nombre'] ?? ''} • ${(b['fecha_registro'] ?? '').toString().replaceFirst('T', ' ').substring(0, 16)}',
                        style: TextStyle(fontSize: 11, color: ts.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ok ? 'EN NORMA' : 'FUERA DE NORMA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Vigencias Legales y Licencias Sanitarias (COF-07)
          PremiumSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: ts.neonAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vigencias Legales y Documentos Sanitarios (COF-07)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ts.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoDoc,
                        decoration: const InputDecoration(labelText: 'Documento', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'LICENCIA_SANITARIA', child: Text('Licencia Sanitaria')),
                          DropdownMenuItem(value: 'AVISO_FUNCIONAMIENTO', child: Text('Aviso de Funcionamiento')),
                          DropdownMenuItem(value: 'CERTIFICADO_FUMIGACION', child: Text('Certificado Fumigación')),
                          DropdownMenuItem(value: 'CAPACITACION_PNO', child: Text('Capacitación PNO')),
                          DropdownMenuItem(value: 'CONTRATO_SINGREM', child: Text('Contrato SINGREM')),
                        ],
                        onChanged: (v) => setState(() => _tipoDoc = v ?? 'LICENCIA_SANITARIA'),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _folioDocCtrl,
                        decoration: const InputDecoration(labelText: 'Folio / Registro', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _vencimientoDoc,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _vencimientoDoc = picked);
                      },
                      icon: const Icon(Icons.event, size: 18),
                      label: Text('Vence: ${_vencimientoDoc.toIso8601String().split('T').first}'),
                    ),
                    FilledButton.icon(
                      onPressed: _guardandoDoc ? null : _guardarDocumento,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: Text(_guardandoDoc ? 'Guardando...' : 'Guardar Vigencia'),
                    ),
                  ],
                ),
                if (_documentos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: ts.borderColor),
                  ..._documentos.map((d) {
                    final int dias = (d['dias_restantes'] as num?)?.toInt() ?? 0;
                    final color = dias >= 30 ? ts.neonGreen : ts.neonRed;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${d['tipo_documento']} • Folio ${d['folio_documento']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts.textPrimary)),
                      subtitle: Text('Vence: ${d['fecha_vencimiento']}', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                      trailing: Text('$dias días', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    );
                  }),
                ],
              ],
            ),
          ),

          // 3. Parámetros Financieros Mensuales (FIN-02, FIN-03, FIN-04)
          if (auth.isAdmin) ...[
            const SizedBox(height: 16),
            PremiumSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_outlined, color: ts.accentPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Parámetros Financieros del Mes (FIN-02, FIN-03, FIN-04)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ts.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _gastosFijosCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Gastos Fijos Mensuales (\$)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _nominaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Nómina Mensual (\$)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _guardandoFin ? null : _guardarFinanzas,
                        icon: const Icon(Icons.save, size: 18),
                        label: Text(_guardandoFin ? 'Guardando...' : 'Actualizar Finanzas'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
