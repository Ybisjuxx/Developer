import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

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
        final ts = ThemeService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Turno de caja abierto con éxito! Fondo: \$$monto MXN'),
            backgroundColor: ts.accentPrimary,
          ),
        );
        _notasAperturaController.clear();
        await _cargarDatosCaja();
      }
    } catch (e) {
      if (mounted) {
        final ts = ThemeService.instance;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error abriendo turno: $e'), backgroundColor: ts.neonRed),
        );
      }
    }
  }

  void _mostrarDialogoCierre() {
    final ts = ThemeService.instance;
    final esperado = (_resumenTurno?['efectivo_esperado_en_caja'] as num? ?? 0.0).toDouble();
    _dineroFisicoController.text = esperado.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final contado = double.tryParse(_dineroFisicoController.text.trim()) ?? 0.0;
            final diferencia = contado - esperado;
            final Color diffColor = diferencia == 0
                ? ts.neonGreen
                : (diferencia > 0 ? ts.neonBlue : ts.neonRed);

            return AlertDialog(
              backgroundColor: ts.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
              ),
              title: Row(
                children: [
                  Icon(Icons.point_of_sale, color: ts.neonAmber),
                  const SizedBox(width: 8),
                  Text('Arqueo de Caja y Corte Z', style: TextStyle(color: ts.textPrimary)),
                ],
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ts.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ts.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fondo Inicial: \$${_turnoActivo?["monto_apertura"]} MXN', style: TextStyle(color: ts.textPrimary)),
                          Text('Ventas en Efectivo: \$${_turnoActivo?["ventas_efectivo"]} MXN', style: TextStyle(color: ts.textPrimary)),
                          Divider(color: ts.borderColor),
                          Text(
                            'Efectivo Esperado en Gaveta: \$${esperado.toStringAsFixed(2)} MXN',
                            style: TextStyle(fontWeight: FontWeight.bold, color: ts.accentPrimary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dineroFisicoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: ts.textPrimary),
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
                      style: TextStyle(color: ts.textPrimary),
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
                        color: ts.tintBg(diffColor, lightAlpha: 0.10, darkAlpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: diffColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diferencia == 0
                                ? Icons.check_circle
                                : diferencia > 0
                                    ? Icons.add_circle
                                    : Icons.warning,
                            color: diffColor,
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
                                color: diffColor,
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
                  child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ts.neonRed,
                    foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                  ),
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
        final ts = ThemeService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Turno de caja cerrado exitosamente! Corte Z ID #${turnoCerrado["id"]}'),
            backgroundColor: ts.accentPrimary,
          ),
        );
        _notasCierreController.clear();
        await _cargarDatosCaja();
      }
    } catch (e) {
      if (mounted) {
        final ts = ThemeService.instance;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cerrando turno: $e'), backgroundColor: ts.neonRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de módulo HeroUI / Fragments UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: ts.heroBannerGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ts.esTemaNeon
                              ? ts.accentPrimary.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ts.esTemaNeon
                                ? ts.accentPrimary.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          Icons.point_of_sale,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control de Caja y Cortes Z',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Arqueo de turnos, corte Z ciego, balance de gaveta y registro de ventas.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                    ),
                    onPressed: _cargarDatosCaja,
                    tooltip: 'Actualizar balance de caja',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Pestañas de navegación
            Container(
              decoration: BoxDecoration(
                color: ts.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ts.borderColor, width: 1.0),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: ts.accentPrimary,
                unselectedLabelColor: ts.textSecondary,
                indicatorColor: ts.accentPrimary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.point_of_sale, size: 18), text: 'Turno Activo y Arqueo'),
                  Tab(icon: Icon(Icons.history, size: 18), text: 'Historial de Cortes Z'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error', style: TextStyle(color: ts.neonRed)))
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
    final ts = ThemeService.instance;
    if (_turnoActivo == null) {
      return Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ts.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ts.borderColor, width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: ts.tintBg(ts.neonAmber, lightAlpha: 0.15, darkAlpha: 0.25),
                  child: Icon(Icons.lock_open, size: 40, color: ts.neonAmber),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay ningún turno de caja abierto',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ts.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para registrar ventas y cobrar en el mostrador, abre un turno ingresando el fondo de caja inicial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ts.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _fondoAperturaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ts.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Fondo Inicial en Efectivo (\$ MXN)',
                    prefixIcon: Icon(Icons.attach_money),
                    helperText: 'Fondo de cambio entregado al cajero',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notasAperturaController,
                  style: TextStyle(color: ts.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Notas de apertura (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ts.accentPrimary,
                    foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
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
          // Banner de Estado Activo con HeroUI
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ts.heroBannerGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ts.borderColor, width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: LayoutBuilder(
              builder: (context, bConstraints) {
                final isNarrow = bConstraints.maxWidth < 650;

                final infoColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Turno Abierto #${turno["id"]}',
                          style: TextStyle(
                            color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: ts.neonGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('ACTIVO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Cajero: ${turno["cajero_nombre"]} | Apertura: ${turno["fecha_apertura"].toString().replaceFirst("T", " ").substring(0, 16)}',
                      style: TextStyle(
                        color: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                );

                final corteBtn = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ts.esTemaNeon ? ts.neonAmber : Colors.white,
                    foregroundColor: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.calculate, size: 18, color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor),
                  label: Text(
                    'Corte Z / Arqueo',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor),
                  ),
                  onPressed: _mostrarDialogoCierre,
                );

                final avatarBox = Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ts.esTemaNeon
                        ? ts.accentPrimary.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ts.esTemaNeon
                          ? ts.accentPrimary.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(Icons.storefront, color: ts.esTemaNeon ? ts.accentPrimary : Colors.white, size: 24),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          avatarBox,
                          const SizedBox(width: 12),
                          Expanded(child: infoColumn),
                        ],
                      ),
                      const SizedBox(height: 12),
                      corteBtn,
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      avatarBox,
                      const SizedBox(width: 14),
                      Expanded(child: infoColumn),
                      corteBtn,
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Tarjetas KPI del Turno
          LayoutBuilder(
            builder: (context, kConstraints) {
              final double w = kConstraints.maxWidth;
              final double cardWidth = w < 480 ? (w - 12) / 2 : (w < 800 ? (w - 24) / 3 : 210);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildKpiCard('Fondo Inicial', '\$${turno["monto_apertura"]} MXN', Icons.account_balance_wallet, ts.neonBlue, cardWidth: cardWidth),
                  _buildKpiCard('Ventas Efectivo', '\$${turno["ventas_efectivo"]} MXN', Icons.payments, ts.neonGreen, cardWidth: cardWidth),
                  _buildKpiCard('Ventas Tarjetas', '\$${turno["ventas_tarjeta"]} MXN', Icons.credit_card, ts.neonPurple, cardWidth: cardWidth),
                  _buildKpiCard('Transferencias', '\$${turno["ventas_transferencia"]} MXN', Icons.swap_horiz, ts.neonAmber, cardWidth: cardWidth),
                  _buildKpiCard('Total Vendido', '\$${turno["total_ventas"]} MXN ($totalTickets tickets)', Icons.receipt, ts.accentPrimary, cardWidth: cardWidth),
                  _buildKpiCard('Efectivo Esperado', '\$${efectivoEsperado.toStringAsFixed(2)} MXN', Icons.savings, ts.accentPrimary, esDestacado: true, cardWidth: cardWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icono, Color color, {bool esDestacado = false, double? cardWidth}) {
    final ts = ThemeService.instance;
    return Container(
      width: cardWidth ?? 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esDestacado ? ts.tintBg(color, lightAlpha: 0.12, darkAlpha: 0.22) : ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esDestacado ? color : ts.borderColor, width: 1.2),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, color: ts.textSecondary, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: esDestacado ? color : ts.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPestanaHistorial() {
    final ts = ThemeService.instance;
    if (_historialTurnos.isEmpty) {
      return Center(child: Text('No hay registros de cortes de caja previos', style: TextStyle(color: ts.textSecondary)));
    }

    return ListView.builder(
      itemCount: _historialTurnos.length,
      itemBuilder: (context, index) {
        final t = _historialTurnos[index];
        final bool estaCerrado = t['estado'] == 'CERRADO';
        final double diferencia = (t['diferencia_efectivo'] as num? ?? 0.0).toDouble();

        final Color statusColor = estaCerrado ? ts.accentPrimary : ts.neonAmber;
        final Color diffColor = diferencia == 0
            ? ts.neonGreen
            : (diferencia > 0 ? ts.neonBlue : ts.neonRed);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ts.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ts.borderColor, width: 1.2),
            boxShadow: ts.cardGlowShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: ts.tintBg(statusColor, lightAlpha: 0.12, darkAlpha: 0.22),
              child: Icon(
                estaCerrado ? Icons.check_circle : Icons.timelapse,
                color: statusColor,
              ),
            ),
            title: Text(
              'Corte #${t["id"]} - ${t["cajero_nombre"]}',
              style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
            ),
            subtitle: Text(
              'Apertura: ${t["fecha_apertura"].toString().replaceFirst("T", " ").substring(0, 16)}\n'
              '${estaCerrado ? "Cierre: ${t['fecha_cierre'].toString().replaceFirst('T', ' ').substring(0, 16)}" : "EN CURSO"}',
              style: TextStyle(color: ts.textSecondary),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Vendido: \$${t["total_ventas"]} MXN',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
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
                      color: diffColor,
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
