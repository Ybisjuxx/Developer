import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';

/// Muestra el diálogo modal para consultar o emitir una Factura Fiscal CFDI 4.0.
Future<void> mostrarModalFacturacion(
  BuildContext context, {
  required Map<String, dynamic> venta,
  required void Function(bool loading) setParentLoading,
  required Future<void> Function() onRefresh,
}) async {
  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _FacturacionDialog(venta: venta),
  );

  if (payload == null || !context.mounted) return;

  final ts = ThemeService.instance;
  setParentLoading(true);

  try {
    final resFactura = await ApiService.generarFacturaVenta(venta['id'], payload);

    if (context.mounted) {
      await onRefresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Factura ${resFactura["folio_factura"]} emitida exitosamente! UUID: ${resFactura["uuid_fiscal"]}',
          ),
          backgroundColor: ts.neonBlue,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      setParentLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al emitir factura: $e'), backgroundColor: ts.neonRed),
      );
    }
  }
}

class _FacturacionDialog extends StatefulWidget {
  final Map<String, dynamic> venta;

  const _FacturacionDialog({required this.venta});

  @override
  State<_FacturacionDialog> createState() => _FacturacionDialogState();
}

class _FacturacionDialogState extends State<_FacturacionDialog> {
  static const List<String> _opcionesRegimen = [
    '601 - General de Ley Personas Morales',
    '603 - Personas Morales con Fines no Lucrativos',
    '605 - Sueldos y Salarios e Ingresos Asimilados',
    '612 - Personas Físicas con Actividades Empresariales y Profesionales',
    '616 - Sin obligaciones fiscales',
    '621 - Incorporación Fiscal',
    '625 - Actividades Empresariales con Plataformas Tecnológicas',
    '626 - Régimen Simplificado de Confianza (RESICO)',
  ];

  static const List<String> _opcionesUsoCfdi = [
    'G01 - Adquisición de mercancías',
    'G03 - Gastos en general',
    'D01 - Honorarios médicos, dentales y gastos hospitalarios',
    'D02 - Gastos médicos por incapacidad o discapacidad',
    'S01 - Sin efectos fiscales',
    'CP01 - Pagos',
  ];

  late final TextEditingController _rfcController;
  late final TextEditingController _razonSocialController;
  late final TextEditingController _cpController;
  late final TextEditingController _correoController;
  late String _regimenFiscal;
  late String _usoCfdi;

  @override
  void initState() {
    super.initState();
    final v = widget.venta;
    _rfcController = TextEditingController(text: v['rfc_receptor'] ?? 'XAXX010101000');
    _razonSocialController = TextEditingController(
      text: v['razon_social_receptor'] ?? v['comprador_nombre'] ?? 'Público General',
    );
    _cpController = TextEditingController(text: v['codigo_postal_receptor'] ?? '44100');
    _correoController = TextEditingController(text: v['correo_factura'] ?? '');
    _regimenFiscal = v['regimen_fiscal_receptor'] ?? '616 - Sin obligaciones fiscales';
    _usoCfdi = v['uso_cfdi'] ?? 'G03 - Gastos en general';
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _cpController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Widget _buildDatoFactura(String etiqueta, String valor) {
    final ts = ThemeService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ts.textSecondary)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final venta = widget.venta;
    final bool yaFacturada = venta['facturada'] == true;
    final double subtotal = (venta['subtotal'] as num? ?? 0.0).toDouble();
    final double descuento = (venta['descuento'] as num? ?? 0.0).toDouble();
    final double total = (venta['total'] as num? ?? 0.0).toDouble();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: ts.neonBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              yaFacturada ? 'Factura Fiscal CFDI 4.0' : 'Generar Factura para Ticket',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta Resumen del Ticket
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ts.tintBg(ts.accentPrimary),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ts.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Folio Ticket: ${venta["folio_ticket"]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)} MXN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${venta["fecha_venta"].toString().replaceFirst("T", " ").substring(0, 16)}  •  Método: ${venta["metodo_pago"] ?? "EFECTIVO"}',
                      style: TextStyle(fontSize: 11, color: ts.textSecondary),
                    ),
                    if (yaFacturada) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ts.tintBg(ts.neonBlue),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ts.neonBlue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: ts.neonBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Factura: ${venta["folio_factura"]} | UUID: ${venta["uuid_fiscal"]}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.neonBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (yaFacturada) ...[
                // Consulta de Factura Emitida
                const Text('Datos Fiscales Registrados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _buildDatoFactura('RFC Receptor:', venta['rfc_receptor'] ?? 'N/A'),
                _buildDatoFactura('Razón Social:', venta['razon_social_receptor'] ?? 'N/A'),
                _buildDatoFactura('Régimen Fiscal:', venta['regimen_fiscal_receptor'] ?? 'N/A'),
                _buildDatoFactura('Código Postal:', venta['codigo_postal_receptor'] ?? 'N/A'),
                _buildDatoFactura('Uso de CFDI:', venta['uso_cfdi'] ?? 'N/A'),
                if (venta['correo_factura'] != null)
                  _buildDatoFactura('Correo:', venta['correo_factura']),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar UUID SAT'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: venta['uuid_fiscal'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UUID Fiscal copiado al portapapeles.')),
                        );
                      },
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.accentPrimary,
                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                      ),
                      icon: const Icon(Icons.code, size: 16),
                      label: const Text('Descargar XML CFDI 4.0'),
                      onPressed: () async {
                        try {
                          final xmlStr = await ApiService.descargarXmlFactura(venta['id']);
                          Clipboard.setData(ClipboardData(text: xmlStr));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('XML CFDI 4.0 oficial descargado y copiado al portapapeles.'),
                                backgroundColor: ts.neonBlue,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al descargar XML: $e'), backgroundColor: ts.neonRed),
                            );
                          }
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimir Factura'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Enviando factura ${venta["folio_factura"]} a imprimir en formato fiscal...'),
                            backgroundColor: ts.neonBlue,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ] else ...[
                // Formulario de Emisión de Factura
                Text(
                  'Ingrese los datos fiscales del cliente para timbrar la factura:',
                  style: TextStyle(fontSize: 12, color: ts.textSecondary),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _rfcController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'RFC del Receptor *',
                          hintText: 'XAXX010101000',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _cpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'C.P. Fiscal *',
                          hintText: '44100',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _razonSocialController,
                  decoration: const InputDecoration(
                    labelText: 'Razón Social / Nombre Completo *',
                    hintText: 'Nombre de la empresa o persona física',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: _opcionesRegimen.contains(_regimenFiscal) ? _regimenFiscal : _opcionesRegimen[0],
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Régimen Fiscal (SAT) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _opcionesRegimen
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _regimenFiscal = val);
                  },
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: _opcionesUsoCfdi.contains(_usoCfdi) ? _usoCfdi : _opcionesUsoCfdi[0],
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Uso de CFDI (SAT) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _opcionesUsoCfdi
                      .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _usoCfdi = val);
                  },
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico (Envío de XML y PDF)',
                    hintText: 'cliente@ejemplo.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Desglose de Facturación
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ts.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ts.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 12)),
                          Text('\$${subtotal.toStringAsFixed(2)} MXN', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (descuento > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Descuento Otorgado:', style: TextStyle(fontSize: 12, color: ts.neonRed)),
                            Text('-\$${descuento.toStringAsFixed(2)} MXN', style: TextStyle(fontSize: 12, color: ts.neonRed)),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'IVA (Medicamentos Tasa 0% / Misceláneos 16%):',
                              style: TextStyle(fontSize: 11, color: ts.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('\$0.00 MXN (Tasa 0%)', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Facturado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '\$${total.toStringAsFixed(2)} MXN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (!yaFacturada)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            icon: const Icon(Icons.send_and_archive, size: 18),
            label: const Text('Emitir Factura CFDI 4.0'),
            onPressed: () {
              final rfc = _rfcController.text.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
              final razon = _razonSocialController.text.trim();
              final cp = _cpController.text.trim();

              if (rfc.length < 12 || rfc.length > 13) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El RFC debe contar con 12 (persona moral) o 13 (persona física) caracteres alfanuméricos.'),
                  ),
                );
                return;
              }

              if (razon.isEmpty || cp.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Razón social y Código Postal válidos son obligatorios.')),
                );
                return;
              }

              Navigator.of(context).pop({
                'rfc_receptor': rfc,
                'razon_social_receptor': razon,
                'regimen_fiscal_receptor': _regimenFiscal,
                'codigo_postal_receptor': cp,
                'uso_cfdi': _usoCfdi,
                'correo_factura': _correoController.text.trim().isEmpty ? null : _correoController.text.trim(),
              });
            },
          ),
      ],
    );
  }
}
