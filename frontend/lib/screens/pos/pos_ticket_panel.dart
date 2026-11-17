import 'package:flutter/material.dart';
import '../../models/medico.dart';
import '../../services/theme_service.dart';

/// Abre el ticket de venta en un BottomSheet responsivo para pantallas móviles.
void mostrarTicketBottomSheet(
  BuildContext context, {
  required Widget Function(VoidCallback onActualizar) builder,
  required VoidCallback onClosed,
}) {
  final ts = ThemeService.instance;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(sheetContext).size.height * 0.90,
              decoration: BoxDecoration(
                color: ts.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: ts.esOscuro ? Border(top: BorderSide(color: ts.borderColor)) : null,
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ts.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: builder(() => setSheetState(() {})),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(onClosed);
}

/// Barra inferior fija en móvil con resumen del carrito y botón para abrir el ticket.
class PosMobileCartBar extends StatelessWidget {
  final List<Map<String, dynamic>> carrito;
  final double total;
  final VoidCallback onAbrirTicket;

  const PosMobileCartBar({
    super.key,
    required this.carrito,
    required this.total,
    required this.onAbrirTicket,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final int cantidadTotal = carrito.fold<int>(0, (sum, item) => sum + (item['cantidad'] as int));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ts.cardBg,
        border: Border(top: BorderSide(color: ts.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ts.esOscuro ? 0.3 : 0.08),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Badge(
              isLabelVisible: carrito.isNotEmpty,
              label: Text('$cantidadTotal'),
              backgroundColor: ts.accentPrimary,
              textColor: ts.esTemaNeon ? Colors.black : Colors.white,
              child: Icon(Icons.shopping_cart, color: ts.accentPrimary, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${carrito.length} ${carrito.length == 1 ? "artículo" : "artículos"}',
                    style: TextStyle(fontSize: 11, color: ts.textSecondary),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)} MXN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: carrito.isEmpty
                    ? (ts.esOscuro ? Colors.white12 : ts.borderColor)
                    : ts.accentPrimary,
                foregroundColor: carrito.isEmpty
                    ? null
                    : (ts.esTemaNeon ? Colors.black : Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: carrito.isEmpty ? null : onAbrirTicket,
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Ver Ticket / Cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel del Ticket de Venta (usado tanto en columna derecha desktop como en BottomSheet móvil).
class PosTicketPanel extends StatelessWidget {
  final List<Map<String, dynamic>> carrito;
  final Map<String, dynamic>? clienteSeleccionado;
  final List<Medico> medicos;
  final Medico? medicoSeleccionado;
  final bool requiereMedico;
  final TextEditingController folioRecetaController;
  final bool recetaRetenida;
  final bool recetaSinErrores;
  final bool recetaSurtidaCompleta;
  final String metodoPago;
  final TextEditingController montoRecibidoController;
  final double subtotal;
  final double descuento;
  final double total;
  final double cambio;
  final bool procesandoVenta;
  final bool enBottomSheet;

  final VoidCallback onVaciarCarrito;
  final Future<void> Function() onBuscarCliente;
  final Future<void> Function() onNuevoCliente;
  final VoidCallback onQuitarCliente;
  final ValueChanged<Medico?> onMedicoChanged;
  final ValueChanged<bool> onRecetaRetenidaChanged;
  final ValueChanged<bool> onRecetaSinErroresChanged;
  final ValueChanged<bool> onRecetaSurtidaCompletaChanged;
  final void Function(int index, int delta) onCambiarCantidad;
  final ValueChanged<String> onMetodoPagoChanged;
  final VoidCallback onMontoRecibidoChanged;
  final VoidCallback onMontoExacto;
  final Future<void> Function() onCobrar;

  const PosTicketPanel({
    super.key,
    required this.carrito,
    required this.clienteSeleccionado,
    required this.medicos,
    required this.medicoSeleccionado,
    required this.requiereMedico,
    required this.folioRecetaController,
    required this.recetaRetenida,
    required this.recetaSinErrores,
    required this.recetaSurtidaCompleta,
    required this.metodoPago,
    required this.montoRecibidoController,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.cambio,
    required this.procesandoVenta,
    this.enBottomSheet = false,
    required this.onVaciarCarrito,
    required this.onBuscarCliente,
    required this.onNuevoCliente,
    required this.onQuitarCliente,
    required this.onMedicoChanged,
    required this.onRecetaRetenidaChanged,
    required this.onRecetaSinErroresChanged,
    required this.onRecetaSurtidaCompletaChanged,
    required this.onCambiarCantidad,
    required this.onMetodoPagoChanged,
    required this.onMontoRecibidoChanged,
    required this.onMontoExacto,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final bool enCarrito = carrito.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: ts.surfaceBg,
        borderRadius: enBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
        border: Border.all(
          color: enCarrito ? ts.accentPrimary : ts.borderColor,
          width: enCarrito ? 1.6 : 1.2,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: ts.accentPrimary),
              const SizedBox(width: 8),
              Text(
                'Ticket de Venta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (carrito.isNotEmpty)
                TextButton(
                  onPressed: onVaciarCarrito,
                  child: Text('Vaciar', style: TextStyle(color: ts.neonRed, fontSize: 12)),
                ),
              if (enBottomSheet)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar ticket',
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra Buscadora y Confirmación de Clientes por Teléfono / Fecha de Nacimiento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: ts.accentPrimary, size: 16),
                  const SizedBox(width: 4),
                  const Text('Cliente / Lealtad:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.search, size: 14),
                    label: const Text('Buscar (Tel)', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: const Size(40, 24),
                    ),
                    onPressed: onBuscarCliente,
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 14),
                    label: const Text('Nuevo', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: const Size(40, 24),
                    ),
                    onPressed: onNuevoCliente,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (clienteSeleccionado == null)
            InkWell(
              onTap: onBuscarCliente,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ts.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ts.borderColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.2, darkAlpha: 0.3),
                      child: Icon(Icons.person_outline, size: 14, color: ts.accentPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👤 Público General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Toca para buscar por teléfono o nombre...', style: TextStyle(fontSize: 10, color: ts.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search, size: 18, color: ts.accentPrimary),
                      tooltip: 'Buscar cliente por teléfono o nombre',
                      onPressed: onBuscarCliente,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ts.tintBg(ts.accentPrimary),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ts.accentPrimary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: ts.accentPrimary,
                    child: Icon(Icons.person, size: 15, color: ts.esTemaNeon ? Colors.black : Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⭐️ ${clienteSeleccionado!["nombre"]} ${clienteSeleccionado!["apellido"]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (clienteSeleccionado!['telefono'] != null)
                              Text('📞 ${clienteSeleccionado!["telefono"]}', style: TextStyle(fontSize: 10, color: ts.textSecondary)),
                            if (clienteSeleccionado!['fecha_nacimiento'] != null)
                              Text('🎂 ${clienteSeleccionado!["fecha_nacimiento"]}', style: TextStyle(fontSize: 10, color: ts.neonPurple)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.swap_horiz, size: 18, color: ts.accentPrimary),
                    tooltip: 'Cambiar cliente',
                    onPressed: onBuscarCliente,
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: ts.textSecondary),
                    tooltip: 'Quitar cliente (Público General)',
                    onPressed: onQuitarCliente,
                  ),
                ],
              ),
            ),
          if (clienteSeleccionado != null) ...[
            if (clienteSeleccionado!['alerta_resurtimiento_activa'] == true) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ts.tintBg(ts.neonAmber, lightAlpha: 0.22, darkAlpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ts.neonAmber, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notification_important, color: ts.neonAmber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔔 AVISO AL CAJERO: RESURTIMIENTO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ts.neonAmber,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clienteSeleccionado!['mensaje_alerta_resurtimiento'] ??
                                'Sugerir al paciente el resurtimiento de su tratamiento.',
                            style: TextStyle(fontSize: 11, color: ts.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ts.tintBg(ts.neonGreen),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ts.neonGreen.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.loyalty, color: ts.neonGreen, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Beneficio: ${clienteSeleccionado!["descuento_porcentaje"]}% de Descuento aplicado',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.neonGreen),
                        ),
                      ),
                    ],
                  ),
                  if (clienteSeleccionado!['enfermedades'] != null &&
                      (clienteSeleccionado!['enfermedades'] as List).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (clienteSeleccionado!['enfermedades'] as List).map((enf) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ts.tintBg(ts.accentPrimary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🩺 ${enf["codigo_cie"]}',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ts.accentPrimary),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Si requiere receta, selector de médico
          if (requiereMedico) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ts.tintBg(ts.neonAmber),
                border: Border.all(color: ts.neonAmber.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: ts.neonAmber),
                      const SizedBox(width: 6),
                      Text(
                        'Medicamento Controlado / Antibiótico',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.neonAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Medico>(
                    initialValue: medicoSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Médico que Prescribe (Cédula Vigente) *',
                      isDense: true,
                    ),
                    items: medicos.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text('Dr. ${m.nombreCompleto} (Céd: ${m.cedulaProfesional})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: onMedicoChanged,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: folioRecetaController,
                    decoration: const InputDecoration(
                      labelText: 'Folio de receta (COFEPRIS)',
                      hintText: 'Ej. REC-2026-001',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Receta retenida', style: TextStyle(fontSize: 11)),
                        selected: recetaRetenida,
                        onSelected: onRecetaRetenidaChanged,
                        visualDensity: VisualDensity.compact,
                      ),
                      FilterChip(
                        label: const Text('Sin errores', style: TextStyle(fontSize: 11)),
                        selected: recetaSinErrores,
                        onSelected: onRecetaSinErroresChanged,
                        visualDensity: VisualDensity.compact,
                      ),
                      FilterChip(
                        label: const Text('Surtida 100%', style: TextStyle(fontSize: 11)),
                        selected: recetaSurtidaCompleta,
                        onSelected: onRecetaSurtidaCompletaChanged,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Lista del Carrito
          Expanded(
            child: carrito.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 48, color: ts.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text('Selecciona productos del catálogo'),
                        const SizedBox(height: 4),
                        Text(
                          'O escanea el código de barras en la búsqueda',
                          style: TextStyle(color: ts.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: carrito.length,
                    separatorBuilder: (_, index) => const Divider(height: 10),
                    itemBuilder: (context, index) {
                      final item = carrito[index];
                      final p = item['producto'];
                      final cant = item['cantidad'] as int;
                      final sub = (p['precio_venta'] as num) * cant;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['nombre_comercial'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('\$${p["precio_venta"]} c/u', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () => onCambiarCantidad(index, -1),
                          ),
                          Text('$cant', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => onCambiarCantidad(index, 1),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              '\$$sub',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Método de Pago y Totales
          const Divider(height: 16),

          Row(
            children: [
              const Text('Método de Pago: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              DropdownButton<String>(
                value: metodoPago,
                isDense: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo')),
                  DropdownMenuItem(value: 'TARJETA', child: Text('💳 Tarjeta')),
                  DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('🏦 Transferencia')),
                ],
                onChanged: (val) {
                  if (val != null) onMetodoPagoChanged(val);
                },
              ),
            ],
          ),

          if (metodoPago == 'EFECTIVO' && carrito.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: montoRecibidoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Paga con (\$ MXN)',
                      isDense: true,
                      prefixIcon: Icon(Icons.attach_money, size: 18),
                    ),
                    onChanged: (_) => onMontoRecibidoChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: onMontoExacto,
                  child: const Text('Exacto', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (cambio > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cambio a entregar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonGreen)),
                  Text('\$${cambio.toStringAsFixed(2)} MXN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ts.neonGreen)),
                ],
              ),
            ],
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:', style: TextStyle(fontSize: 13, color: ts.textSecondary)),
              Text(
                '\$${subtotal.toStringAsFixed(2)} MXN',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (descuento > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desc. Lealtad (${clienteSeleccionado!["descuento_porcentaje"]}%):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonGreen),
                ),
                Text(
                  '-\$${descuento.toStringAsFixed(2)} MXN',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ts.neonGreen),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a Cobrar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '\$${total.toStringAsFixed(2)} MXN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: procesandoVenta ? null : onCobrar,
            icon: procesandoVenta
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ts.esTemaNeon ? Colors.black : Colors.white,
                    ),
                  )
                : const Icon(Icons.payments),
            label: Text(procesandoVenta ? 'Despachando FEFO...' : 'Cobrar e Imprimir Ticket'),
          ),
        ],
      ),
    );
  }
}
