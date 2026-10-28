import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _turnoActivo;
  Map<String, dynamic>? _resumenTurno;
  List<dynamic> _historialTurnos = [];

  // Formulario Apertura
  final _fondoAperturaController = TextEditingController(text: '1000.00');
  final _notasAperturaController = TextEditingController();

  // Formulario Cierre
  final _dineroFisicoController = TextEditingController();
  final _notasCierreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosCaja();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fondoAperturaController.dispose();
    _notasAperturaController.dispose();
    _dineroFisicoController.dispose();
    _notasCierreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosCaja() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final turno = await ApiService.getTurnoActivo();
      Map<String, dynamic>? resumen;
      if (turno != null) {
        resumen = await ApiService.getResumenTurno();
      }
      final historial = await ApiService.getHistorialTurnos();

      if (mounted) {
        setState(() {
          _turnoActivo = turno;
          _resumenTurno = resumen;
          _historialTurnos = historial;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _abrirNuevoTurno() async {
    final monto = double.tryParse(_fondoAperturaController.text.trim()) ?? 0.0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un fondo inicial válido mayor a 0.')),
      );
      return;
    }

    final auth = AuthService();
    final cajeroNombre = auth.usuarioActual.nombreCompleto;

    setState(() => _isLoading = true);
    try {
      await ApiService.abrirTurno(
        cajeroNombre: cajeroNombre,
        montoApertura: monto,
        usuarioId: auth.usuarioActual.id,
        notas: _notasAperturaController.text.trim().isEmpty ? null : _notasAperturaController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Turno de caja abierto con éxito! Fondo: \$$monto MXN'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
        _notasAperturaController.clear();
        await _cargarDatosCaja();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error abriendo turno: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  void _mostrarDialogoCierre() {
    final esperado = (_resumenTurno?['efectivo_esperado_en_caja'] as num? ?? 0.0).toDouble();
    _dineroFisicoController.text = esperado.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final contado = double.tryParse(_dineroFisicoController.text.trim()) ?? 0.0;
            final diferencia = contado - esperado;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.point_of_sale, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  const Text('Arqueo de Caja y Corte Z'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fondo Inicial: \$${_turnoActivo?["monto_apertura"]} MXN'),
                          Text('Ventas en Efectivo: \$${_turnoActivo?["ventas_efectivo"]} MXN'),
                          const Divider(),
                          Text(
                            'Efectivo Esperado en Gaveta: \$${esperado.toStringAsFixed(2)} MXN',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dineroFisicoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Efectivo Físico Contado (\$ MXN)',
                        prefixIcon: Icon(Icons.payments_outlined),
                        helperText: 'Cuenta el dinero físico que hay en la gaveta',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notasCierreController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones de cierre (opcional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Indicador de Cuadre / Sobrante / Faltante
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: diferencia == 0
                            ? Colors.green.shade50
                            : diferencia > 0
                                ? Colors.blue.shade50
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: diferencia == 0
                              ? Colors.green
                              : diferencia > 0
                                  ? Colors.blue
                                  : Colors.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diferencia == 0
                                ? Icons.check_circle
                                : diferencia > 0
                                    ? Icons.add_circle
                                    : Icons.warning,
                            color: diferencia == 0
                                ? Colors.green
                                : diferencia > 0
                                    ? Colors.blue
                                    : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              diferencia == 0
                                  ? '¡Cuadre Exacto! Sin diferencias.'
                                  : diferencia > 0
                                      ? 'Sobrante en Caja: +\$${diferencia.toStringAsFixed(2)} MXN'
                                      : 'Faltante en Caja: -\$${(-diferencia).toStringAsFixed(2)} MXN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: diferencia == 0
                                    ? Colors.green.shade900
                                    : diferencia > 0
                                        ? Colors.blue.shade900
                                        : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Confirmar Corte Z y Cerrar'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _cerrarTurnoDefinitivo(contado);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cerrarTurnoDefinitivo(double montoContado) async {
    setState(() => _isLoading = true);
    try {
      final turnoCerrado = await ApiService.cerrarTurno(
        montoCierreEfectivo: montoContado,
        notas: _notasCierreController.text.trim().isEmpty ? null : _notasCierreController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Turno de caja cerrado exitosamente! Corte Z ID #${turnoCerrado["id"]}'),
            backgroundColor: Colors.teal.shade900,
          ),
        );
        _notasCierreController.clear();
        await _cargarDatosCaja();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cerrando turno: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con pestañas
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.teal.shade900,
                    indicatorColor: Colors.teal,
                    tabs: const [
                      Tab(icon: Icon(Icons.point_of_sale), text: 'Turno Activo y Arqueo'),
                      Tab(icon: Icon(Icons.history), text: 'Historial de Cortes Z'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargarDatosCaja,
                  tooltip: 'Actualizar balance',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPestanaTurnoActivo(),
                            _buildPestanaHistorial(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPestanaTurnoActivo() {
    if (_turnoActivo == null) {
      return Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(Icons.lock_open, size: 40, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay ningún turno de caja abierto',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para registrar ventas y cobrar en el mostrador, abre un turno ingresando el fondo de caja inicial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _fondoAperturaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Fondo Inicial en Efectivo (\$ MXN)',
                    prefixIcon: Icon(Icons.attach_money),
                    helperText: 'Fondo de cambio entregado al cajero',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notasAperturaController,
                  decoration: const InputDecoration(
                    labelText: 'Notas de apertura (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Abrir Turno de Caja', style: TextStyle(fontSize: 16)),
                  onPressed: _abrirNuevoTurno,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final turno = _turnoActivo!;
    final resumen = _resumenTurno ?? {};
    final totalTickets = resumen['total_tickets'] ?? 0;
    final efectivoEsperado = (resumen['efectivo_esperado_en_caja'] as num? ?? 0.0).toDouble();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade600]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.storefront, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Turno Abierto #${turno["id"]}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('ACTIVO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      Text(
                        'Cajero: ${turno["cajero_nombre"]} | Apertura: ${turno["fecha_apertura"].toString().replaceFirst("T", " ").substring(0, 16)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade900,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.calculate, size: 18),
                  label: const Text('Corte Z / Arqueo'),
                  onPressed: _mostrarDialogoCierre,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjetas KPI del Turno
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiCard('Fondo Inicial', '\$${turno["monto_apertura"]} MXN', Icons.account_balance_wallet, Colors.blue),
              _buildKpiCard('Ventas Efectivo', '\$${turno["ventas_efectivo"]} MXN', Icons.payments, Colors.green),
              _buildKpiCard('Ventas Tarjetas', '\$${turno["ventas_tarjeta"]} MXN', Icons.credit_card, Colors.purple),
              _buildKpiCard('Transferencias', '\$${turno["ventas_transferencia"]} MXN', Icons.swap_horiz, Colors.orange),
              _buildKpiCard('Total Vendido', '\$${turno["total_ventas"]} MXN ($totalTickets tickets)', Icons.receipt, Colors.teal),
              _buildKpiCard('Efectivo Esperado', '\$${efectivoEsperado.toStringAsFixed(2)} MXN', Icons.savings, Colors.indigo, esDestacado: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icono, MaterialColor color, {bool esDestacado = false}) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esDestacado ? color.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: esDestacado ? color.shade400 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              Icon(icono, color: color.shade800, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: esDestacado ? color.shade900 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPestanaHistorial() {
    if (_historialTurnos.isEmpty) {
      return const Center(child: Text('No hay registros de cortes de caja previos'));
    }

    return ListView.builder(
      itemCount: _historialTurnos.length,
      itemBuilder: (context, index) {
        final t = _historialTurnos[index];
        final bool estaCerrado = t['estado'] == 'CERRADO';
        final double diferencia = (t['diferencia_efectivo'] as num? ?? 0.0).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: estaCerrado ? Colors.teal.shade50 : Colors.amber.shade50,
              child: Icon(
                estaCerrado ? Icons.check_circle : Icons.timelapse,
                color: estaCerrado ? Colors.teal : Colors.amber.shade800,
              ),
            ),
            title: Text(
              'Corte #${t["id"]} - ${t["cajero_nombre"]}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Apertura: ${t["fecha_apertura"].toString().replaceFirst("T", " ").substring(0, 16)}\n'
              '${estaCerrado ? "Cierre: ${t['fecha_cierre'].toString().replaceFirst('T', ' ').substring(0, 16)}" : "EN CURSO"}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Vendido: \$${t["total_ventas"]} MXN',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (estaCerrado)
                  Text(
                    diferencia == 0
                        ? 'Cuadre: \$0.00'
                        : diferencia > 0
                            ? 'Sobrante: +\$${diferencia.toStringAsFixed(2)}'
                            : 'Faltante: -\$${(-diferencia).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: diferencia == 0
                          ? Colors.green.shade800
                          : diferencia > 0
                              ? Colors.blue.shade800
                              : Colors.red.shade800,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
