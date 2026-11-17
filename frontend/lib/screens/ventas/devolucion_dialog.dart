import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

/// Muestra el diálogo modal para procesar una devolución de venta y su reembolso.
Future<void> mostrarModalDevolucion(
  BuildContext context, {
  required Map<String, dynamic> venta,
  required void Function(bool loading) setParentLoading,
  required Future<void> Function() onRefresh,
}) async {
  final detalles = venta['detalles'] as List<dynamic>? ?? [];
  if (detalles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta venta no tiene detalles de productos.')),
    );
    return;
  }

  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _DevolucionDialog(venta: venta, detalles: detalles),
  );

  if (payload == null || !context.mounted) return;

  final ts = ThemeService.instance;
  setParentLoading(true);

  try {
    final res = await ApiService.registrarDevolucion(payload);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Devolución ${res["folio_devolucion"]} procesada! Reembolsado: \$${res["total_reembolsado"]} MXN'),
          backgroundColor: ts.neonGreen,
        ),
      );
      await onRefresh();
    }
  } catch (e) {
    if (context.mounted) {
      setParentLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
      );
    }
  }
}

class _DevolucionDialog extends StatefulWidget {
  final Map<String, dynamic> venta;
  final List<dynamic> detalles;

  const _DevolucionDialog({required this.venta, required this.detalles});

  @override
  State<_DevolucionDialog> createState() => _DevolucionDialogState();
}

class _DevolucionDialogState extends State<_DevolucionDialog> {
  late dynamic _itemSeleccionado;
  dynamic _despachoSeleccionado;
  late final TextEditingController _cantController;
  late final TextEditingController _motivoController;
  String _estadoProducto = 'BUEN_ESTADO';

  @override
  void initState() {
    super.initState();
    _itemSeleccionado = widget.detalles.first;
    final lotes = _itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? [];
    _despachoSeleccionado = lotes.isNotEmpty ? lotes.first : null;
    _cantController = TextEditingController(text: '1');
    _motivoController = TextEditingController(text: 'Producto con empaque maltratado');
  }

  @override
  void dispose() {
    _cantController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final int maxCant = _despachoSeleccionado != null ? (_despachoSeleccionado['cantidad_despachada'] as int) : 1;
    final int cantDevolver = int.tryParse(_cantController.text.trim()) ?? 1;
    final double pUnit = (_itemSeleccionado['precio_unitario'] as num? ?? 0.0).toDouble();
    final double reembolsoEstimado = cantDevolver * pUnit;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.assignment_return, color: ts.neonAmber),
          const SizedBox(width: 8),
          Text('Devolución: ${widget.venta["folio_ticket"]}', style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona el artículo y lote despachado que el paciente devuelve:',
                style: TextStyle(fontSize: 12, color: ts.textSecondary),
              ),
              const SizedBox(height: 12),

              // Selector de Producto
              DropdownButtonFormField<dynamic>(
                initialValue: _itemSeleccionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Artículo a Devolver', isDense: true),
                items: widget.detalles.map((d) {
                  final nombre = d['producto_nombre'] ?? 'Prod #${d["producto_id"]}';
                  return DropdownMenuItem(
                    value: d,
                    child: Text('$nombre (${d["cantidad"]} pzas vendidas)'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _itemSeleccionado = val;
                    final lotes = _itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? [];
                    _despachoSeleccionado = lotes.isNotEmpty ? lotes.first : null;
                  });
                },
              ),
              const SizedBox(height: 10),

              // Selector de Lote despachado
              if (_itemSeleccionado != null && (_itemSeleccionado['despachos_lotes'] as List<dynamic>? ?? []).isNotEmpty) ...[
                DropdownButtonFormField<dynamic>(
                  initialValue: _despachoSeleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lote Específico FEFO', isDense: true),
                  items: (_itemSeleccionado['despachos_lotes'] as List<dynamic>).map((ld) {
                    return DropdownMenuItem(
                      value: ld,
                      child: Text('Lote #${ld["lote_id"]} - ${ld["cantidad_despachada"]} pzas'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _despachoSeleccionado = val),
                ),
                const SizedBox(height: 10),
              ],

              // Cantidad a devolver
              TextField(
                controller: _cantController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad a Devolver (Máx $maxCant)',
                  isDense: true,
                  helperText: 'Piezas físicas recibidas en mostrador',
                ),
                onChanged: (_) => setState(() {}),
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
                selected: {_estadoProducto},
                onSelectionChanged: (val) => setState(() => _estadoProducto = val.first),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _motivoController,
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
                  color: ts.tintBg(ts.accentPrimary),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ts.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto a Reembolsar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '\$${reembolsoEstimado.toStringAsFixed(2)} MXN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                      ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: ts.neonAmber,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Procesar Reembolso'),
          onPressed: () {
            if (_despachoSeleccionado == null) return;
            if (cantDevolver <= 0 || cantDevolver > maxCant) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('La cantidad debe ser entre 1 y $maxCant piezas.')),
              );
              return;
            }

            final cajero = AuthService().usuarioActual.nombreCompleto;
            Navigator.of(context).pop({
              'venta_id': widget.venta['id'],
              'motivo': _motivoController.text.trim(),
              'metodo_reembolso': 'EFECTIVO',
              'cajero_nombre': cajero,
              'items': [
                {
                  'producto_id': _itemSeleccionado['producto_id'],
                  'lote_id': _despachoSeleccionado['lote_id'],
                  'cantidad': cantDevolver,
                  'estado_producto': _estadoProducto,
                }
              ],
            });
          },
        ),
      ],
    );
  }
}
