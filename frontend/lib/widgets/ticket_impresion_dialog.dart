import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class TicketImpresionDialog extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const TicketImpresionDialog({super.key, required this.ticket});

  static void mostrar(BuildContext context, Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TicketImpresionDialog(ticket: ticket),
    );
  }

  String _generarTextoPlano() {
    final sb = StringBuffer();
    sb.writeln('========================================');
    sb.writeln('           FARMACONTROL MÉXICO          ');
    sb.writeln('       FARMACIA Y DISPENSARIO S.A.      ');
    sb.writeln('             RFC: FCM-241026-9Z1        ');
    sb.writeln(' Reg. Sanitario COFEPRIS: 24-FAR-09923  ');
    sb.writeln(' Av. Hidalgo #1042, Guadalajara, Jal.   ');
    sb.writeln('========================================');
    sb.writeln('Folio: ${ticket["folio_ticket"]}');
    sb.writeln('Fecha: ${ticket["fecha_venta"].toString().replaceFirst("T", " ").substring(0, 16)}');
    sb.writeln('Cajero: ${ticket["cajero_nombre"] ?? "Cajero General"}');
    sb.writeln('Cliente: ${ticket["comprador_nombre"] ?? "Público General"}');
    if (ticket["medico_id"] != null) {
      sb.writeln('Médico Emisor: ID #${ticket["medico_id"]} (Cédula Validada)');
    }
    sb.writeln('----------------------------------------');
    sb.writeln('CANT  DESCRIPCIÓN              IMPORTE  ');
    sb.writeln('----------------------------------------');

    final detalles = ticket['detalles'] as List<dynamic>? ?? [];
    for (var d in detalles) {
      final pId = d['producto_id'];
      final pNombre = d['producto_nombre'] ?? d['nombre_comercial'] ?? 'Producto #$pId';
      final cant = d['cantidad'];
      final sub = d['subtotal'];
      final lineaArticulo = '${cant.toString().padRight(4)} [ID: #$pId] $pNombre';
      sb.writeln(lineaArticulo);
      sb.writeln('     Importe: \$$sub MXN');
    }

    sb.writeln('----------------------------------------');
    sb.writeln('SUBTOTAL:                      \$${ticket["subtotal"]} MXN');
    if ((ticket["descuento"] as num? ?? 0) > 0) {
      sb.writeln('DESCUENTO:                    -\$${ticket["descuento"]} MXN');
    }
    sb.writeln('TOTAL:                         \$${ticket["total"]} MXN');
    sb.writeln('MÉTODO DE PAGO:                ${ticket["metodo_pago"] ?? "EFECTIVO"}');
    if ((ticket["monto_recibido"] as num? ?? 0) > 0) {
      sb.writeln('PAGA CON:                      \$${ticket["monto_recibido"]} MXN');
      sb.writeln('CAMBIO:                        \$${ticket["cambio"]} MXN');
    }
    sb.writeln('========================================');
    sb.writeln('  Medicamentos controlados y antibióticos');
    sb.writeln('  requieren receta médica conforme al    ');
    sb.writeln('   Art. 226 Ley General de Salud.       ');
    sb.writeln('     ¡Gracias por su preferencia!       ');
    sb.writeln('========================================');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final folio = ticket['folio_ticket'] ?? 'TK-0000';
    final fecha = ticket['fecha_venta']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? '';
    final cajero = ticket['cajero_nombre'] ?? 'Cajero Mostrador';
    final comprador = ticket['comprador_nombre'] ?? 'Público General';
    final total = ticket['total'] ?? 0.0;
    final subtotal = ticket['subtotal'] ?? 0.0;
    final metodoPago = ticket['metodo_pago'] ?? 'EFECTIVO';
    final recibido = (ticket['monto_recibido'] as num? ?? 0.0).toDouble();
    final cambio = (ticket['cambio'] as num? ?? 0.0).toDouble();
    final List<dynamic> detalles = ticket['detalles'] ?? [];

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.teal.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.tealAccent, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Ticket Térmico de Venta',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF8), // Color papel térmico
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado Farmacia
              Center(
                child: Column(
                  children: [
                    Icon(Icons.local_pharmacy, color: Colors.teal.shade800, size: 36),
                    const SizedBox(height: 4),
                    const Text(
                      'FARMACONTROL MÉXICO',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                    ),
                    const Text('FARMACIA Y DISPENSARIO S.A.', style: TextStyle(fontSize: 11, color: Colors.black87)),
                    const Text('RFC: FCM-241026-9Z1', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const Text('Reg. Sanitario COFEPRIS: 24-FAR-09923', style: TextStyle(fontSize: 10, color: Colors.black54)),
                    const Text('Av. Hidalgo #1042, Guadalajara, Jal.', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildLineaPunteada(),
              const SizedBox(height: 8),

              // Metadatos
              _buildDatoFila('Folio Ticket:', folio, esBold: true),
              _buildDatoFila('Fecha y Hora:', fecha),
              _buildDatoFila('Atendió:', cajero),
              _buildDatoFila('Cliente:', comprador),
              if (ticket['medico_id'] != null)
                _buildDatoFila('Médico Emisor:', 'Registrado (ID #${ticket["medico_id"]})', colorValor: Colors.teal.shade900),

              const SizedBox(height: 8),
              _buildLineaPunteada(),
              const SizedBox(height: 6),

              // Tabla Renglones
              const Row(
                children: [
                  Expanded(flex: 2, child: Text('CANT / PROD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('P.UNIT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 4),
              _buildLineaPunteada(),
              const SizedBox(height: 6),

              ...detalles.map((d) {
                final int cant = d['cantidad'] ?? 1;
                final int pId = d['producto_id'] ?? 0;
                final String pNombre = d['producto_nombre'] ?? d['nombre_comercial'] ?? 'Producto #$pId';
                final double pUnit = (d['precio_unitario'] as num? ?? 0.0).toDouble();
                final double sub = (d['subtotal'] as num? ?? 0.0).toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              '$cant x $pNombre [ID: #$pId]',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('\$${pUnit.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('\$${sub.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              _buildLineaPunteada(),
              const SizedBox(height: 8),

              // Totales y Cobro
              _buildDatoFila('SUBTOTAL:', '\$${subtotal.toStringAsFixed(2)} MXN'),
              if ((ticket['descuento'] as num? ?? 0) > 0)
                _buildDatoFila('DESCUENTO:', '-\$${ticket["descuento"]} MXN', colorValor: Colors.red),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL PAGADO:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    '\$${total.toStringAsFixed(2)} MXN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildDatoFila('FORMA DE PAGO:', metodoPago),
              if (recibido > 0) ...[
                _buildDatoFila('IMPORTE RECIBIDO:', '\$${recibido.toStringAsFixed(2)} MXN'),
                _buildDatoFila('CAMBIO ENTREGADO:', '\$${cambio.toStringAsFixed(2)} MXN', colorValor: Colors.teal.shade800, esBold: true),
              ],

              const SizedBox(height: 12),
              _buildLineaPunteada(),
              const SizedBox(height: 10),

              // Leyendas Sanitarias
              Center(
                child: Column(
                  children: [
                    const Text(
                      'CONSERVE SU TICKET PARA CUALQUIER ACLARACIÓN',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Medicamentos controlados y antibióticos surtidos con receta médica retenida conforme al Art. 226 de la Ley General de Salud.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    // Código de barras simulado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black26),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '||| | |||| || | ||||| |||| || | || |||',
                            style: TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 13, color: Colors.grey.shade800),
                          ),
                          Text(folio, style: const TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long, size: 18),
          label: const Text('Facturar Ticket'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo.shade900),
          onPressed: () => _abrirModalFacturaRapida(context),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar Ticket'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _generarTextoPlano()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ticket copiado al portapapeles en formato térmico')),
            );
          },
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Imprimir Ticket'),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enviando ticket $folio a impresora térmica conectada...'),
                backgroundColor: Colors.teal.shade900,
              ),
            );
          },
        ),
      ],
    );
  }

  void _abrirModalFacturaRapida(BuildContext context) {
    final rfcCtrl = TextEditingController(text: 'XAXX010101000');
    final razonCtrl = TextEditingController(text: ticket['comprador_nombre'] ?? 'Público General');
    final cpCtrl = TextEditingController(text: '44100');
    final correoCtrl = TextEditingController();
    const String regimen = '616 - Sin obligaciones fiscales';
    const String usoCfdi = 'G03 - Gastos en general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.indigo.shade800),
              const SizedBox(width: 8),
              const Text('Facturar Ticket (CFDI 4.0)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Folio: ${ticket["folio_ticket"]}  •  Total: \$${ticket["total"]} MXN', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rfcCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'RFC Receptor *', hintText: 'XAXX010101000', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: razonCtrl,
                    decoration: const InputDecoration(labelText: 'Razón Social / Nombre *', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'C.P. Fiscal *', hintText: '44100', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: correoCtrl,
                    decoration: const InputDecoration(labelText: 'Correo Electrónico (Opcional)', hintText: 'cliente@ejemplo.com', border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Timbrar CFDI 4.0'),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade800),
              onPressed: () async {
                final rfcLimpio = rfcCtrl.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
                if (rfcLimpio.length < 12 || rfcLimpio.length > 13) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El RFC debe contar con 12 o 13 caracteres.')),
                  );
                  return;
                }
                try {
                  final res = await ApiService.generarFacturaVenta(ticket['id'], {
                    'rfc_receptor': rfcLimpio,
                    'razon_social_receptor': razonCtrl.text.trim(),
                    'regimen_fiscal_receptor': regimen,
                    'codigo_postal_receptor': cpCtrl.text.trim(),
                    'uso_cfdi': usoCfdi,
                    'correo_factura': correoCtrl.text.trim().isEmpty ? null : correoCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Factura ${res["folio_factura"]} generada con éxito! UUID: ${res["uuid_fiscal"]}'),
                        backgroundColor: Colors.indigo.shade900,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al generar factura: $e'), backgroundColor: Colors.red.shade800),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatoFila(String label, String valor, {bool esBold = false, Color? colorValor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 11,
              fontWeight: esBold ? FontWeight.bold : FontWeight.normal,
              color: colorValor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineaPunteada() {
    return Row(
      children: List.generate(
        35,
        (i) => Expanded(
          child: Container(
            color: i.isEven ? Colors.black38 : Colors.transparent,
            height: 1,
          ),
        ),
      ),
    );
  }
}
