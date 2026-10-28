import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ticket_impresion_dialog.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  List<dynamic> _ventas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.getVentas();
      if (mounted) {
        setState(() {
          _ventas = list;
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

  void _abrirModalDevolucion(Map<String, dynamic> venta) {
    final detalles = venta['detalles'] as List<dynamic>? ?? [];
    if (detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta venta no tiene detalles de productos.')),
      );
      return;
    }

    dynamic itemSeleccionado = detalles.first;
    dynamic despachoSeleccionado = (itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? []).isNotEmpty
        ? itemSeleccionado['despachos_lotes'].first
        : null;

    final cantController = TextEditingController(text: '1');
    final motivoController = TextEditingController(text: 'Producto con empaque maltratado');
    String estadoProducto = 'BUEN_ESTADO'; // BUEN_ESTADO o DANADO

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int maxCant = despachoSeleccionado != null ? (despachoSeleccionado['cantidad_despachada'] as int) : 1;
            final int cantDevolver = int.tryParse(cantController.text.trim()) ?? 1;
            final double pUnit = (itemSeleccionado['precio_unitario'] as num? ?? 0.0).toDouble();
            final double reembolsoEstimado = cantDevolver * pUnit;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.assignment_return, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Text('Devolución: ${venta["folio_ticket"]}', style: const TextStyle(fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona el artículo y lote despachado que el paciente devuelve:',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      // Selector de Producto
                      DropdownButtonFormField<dynamic>(
                        initialValue: itemSeleccionado,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Artículo a Devolver', isDense: true),
                        items: detalles.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text('Prod #${d["producto_id"]} (${d["cantidad"]} pzas vendidas)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            itemSeleccionado = val;
                            final lotes = itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? [];
                            despachoSeleccionado = lotes.isNotEmpty ? lotes.first : null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      // Selector de Lote despachado
                      if (itemSeleccionado != null && (itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? []).isNotEmpty) ...[
                        DropdownButtonFormField<dynamic>(
                          initialValue: despachoSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Lote Específico FEFO', isDense: true),
                          items: (itemSeleccionado['despachos_lotes'] as List<dynamic>).map((ld) {
                            return DropdownMenuItem(
                              value: ld,
                              child: Text('Lote #${ld["lote_id"]} - ${ld["cantidad_despachada"]} pzas'),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => despachoSeleccionado = val),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Cantidad a devolver
                      TextField(
                        controller: cantController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cantidad a Devolver (Máx $maxCant)',
                          isDense: true,
                          helperText: 'Piezas físicas recibidas en mostrador',
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // Estado Sanitario del Producto
                      const Text('Condición del Producto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'BUEN_ESTADO',
                            label: Text('Buen Estado (Vuelve a Stock)', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.check_circle_outline, size: 16),
                          ),
                          ButtonSegment(
                            value: 'DANADO',
                            label: Text('Dañado (Merma / Cuarentena)', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.delete_outline, size: 16),
                          ),
                        ],
                        selected: {estadoProducto},
                        onSelectionChanged: (val) => setModalState(() => estadoProducto = val.first),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: motivoController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de la Devolución',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Resumen de Reembolso
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Monto a Reembolsar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              '\$${reembolsoEstimado.toStringAsFixed(2)} MXN',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade900),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Procesar Reembolso'),
                  onPressed: () async {
                    if (despachoSeleccionado == null) return;
                    if (cantDevolver <= 0 || cantDevolver > maxCant) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('La cantidad debe ser entre 1 y $maxCant piezas.')),
                      );
                      return;
                    }

                    Navigator.of(ctx).pop();
                    await _procesarDevolucionApi(
                      ventaId: venta['id'],
                      productoId: itemSeleccionado['producto_id'],
                      loteId: despachoSeleccionado['lote_id'],
                      cantidad: cantDevolver,
                      estado: estadoProducto,
                      motivo: motivoController.text.trim(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _procesarDevolucionApi({
    required int ventaId,
    required int productoId,
    required int loteId,
    required int cantidad,
    required String estado,
    required String motivo,
  }) async {
    setState(() => _isLoading = true);
    final cajero = AuthService().usuarioActual.nombreCompleto;

    final payload = {
      'venta_id': ventaId,
      'motivo': motivo,
      'metodo_reembolso': 'EFECTIVO',
      'cajero_nombre': cajero,
      'items': [
        {
          'producto_id': productoId,
          'lote_id': loteId,
          'cantidad': cantidad,
          'estado_producto': estado,
        }
      ],
    };

    try {
      final res = await ApiService.registrarDevolucion(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Devolución ${res["folio_devolucion"]} procesada! Reembolsado: \$${res["total_reembolsado"]} MXN'),
            backgroundColor: Colors.teal.shade900,
          ),
        );
        await _cargarVentas();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado) {
      case 'COMPLETADA':
        return Colors.green.shade700;
      case 'DEVOLUCION_PARCIAL':
        return Colors.orange.shade800;
      case 'DEVUELTA':
        return Colors.red.shade700;
      default:
        return Colors.teal;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historial de Ventas y Tickets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargarVentas,
                  tooltip: 'Actualizar ventas',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _ventas.isEmpty
                          ? const Center(child: Text('No hay ventas registradas aún'))
                          : ListView.builder(
                              itemCount: _ventas.length,
                              itemBuilder: (context, index) {
                                final v = _ventas[index];
                                final List<dynamic> detalles = v['detalles'] ?? [];
                                final String estado = v['estado'] ?? 'COMPLETADA';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade50,
                                      child: const Icon(Icons.receipt, color: Colors.teal),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          'Folio: ${v["folio_ticket"]}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _obtenerColorEstado(estado).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _obtenerColorEstado(estado)),
                                          ),
                                          child: Text(
                                            estado,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _obtenerColorEstado(estado),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'Comprador: ${v["comprador_nombre"] ?? "Público General"} | Pago: ${v["metodo_pago"] ?? "EFECTIVO"}\n'
                                      'Fecha: ${v["fecha_venta"].toString().replaceFirst("T", " ").substring(0, 16)}',
                                    ),
                                    trailing: Text(
                                      '\$${v["total"]} MXN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade900,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.print, size: 16),
                                                  label: const Text('Ver Ticket Térmico', style: TextStyle(fontSize: 12)),
                                                  onPressed: () => TicketImpresionDialog.mostrar(context, v),
                                                ),
                                                const SizedBox(width: 8),
                                                if (estado != 'DEVUELTA')
                                                  FilledButton.tonalIcon(
                                                    icon: const Icon(Icons.replay, size: 16),
                                                    label: const Text('Devolución / Merma', style: TextStyle(fontSize: 12)),
                                                    onPressed: () => _abrirModalDevolucion(v),
                                                  ),
                                              ],
                                            ),
                                            const Divider(),
                                            const Text(
                                              'Detalle de artículos y lotes asignados (FEFO):',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 8),
                                            ...detalles.map((d) {
                                              final List<dynamic> lotesDespachados = d['despachos_lotes'] ?? [];
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Producto ID: ${d["producto_id"]}  •  Cantidad: ${d["cantidad"]} pzas  •  Subtotal: \$${d["subtotal"]}',
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 8,
                                                      children: lotesDespachados.map((ld) {
                                                        return Chip(
                                                          label: Text(
                                                            'Lote ID ${ld["lote_id"]}: ${ld["cantidad_despachada"]} pzas',
                                                            style: const TextStyle(fontSize: 11),
                                                          ),
                                                          backgroundColor: Colors.teal.shade50,
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
