import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Sub-Agente 1: Automatización de búsqueda por ticket para facturación
  final _ticketSearchController = TextEditingController();
  bool _buscandoTicket = false;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  @override
  void dispose() {
    _ticketSearchController.dispose();
    super.dispose();
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

  // Sub-Agente 1: Automatización de búsqueda y carga de ticket para facturar
  Future<void> _buscarTicketParaFacturar(String folioTicket) async {
    final folio = folioTicket.trim();
    if (folio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese el folio de ticket o ID de compra para facturar.')),
      );
      return;
    }

    setState(() => _buscandoTicket = true);

    try {
      final venta = await ApiService.buscarVentaPorTicket(folio);
      if (mounted) {
        setState(() => _buscandoTicket = false);
        _ticketSearchController.clear();
        _abrirModalFacturacion(venta);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscandoTicket = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.search_off, color: Colors.orange, size: 40),
            title: const Text('Ticket no encontrado'),
            content: Text(
              'No se encontró ninguna venta registrada con el folio o ID "$folio". Verifique el número impreso en el ticket de compra.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar')),
            ],
          ),
        );
      }
    }
  }

  // Sub-Agente 1: Modal para Generar o Consultar Factura CFDI 4.0
  void _abrirModalFacturacion(Map<String, dynamic> venta) {
    final bool yaFacturada = venta['facturada'] == true;

    final rfcController = TextEditingController(text: venta['rfc_receptor'] ?? 'XAXX010101000');
    final razonSocialController = TextEditingController(
      text: venta['razon_social_receptor'] ?? venta['comprador_nombre'] ?? 'Público General',
    );
    final cpController = TextEditingController(text: venta['codigo_postal_receptor'] ?? '44100');
    final correoController = TextEditingController(text: venta['correo_factura'] ?? '');

    String regimenFiscal = venta['regimen_fiscal_receptor'] ?? '616 - Sin obligaciones fiscales';
    String usoCfdi = venta['uso_cfdi'] ?? 'G03 - Gastos en general';

    final List<String> opcionesRegimen = [
      '601 - General de Ley Personas Morales',
      '603 - Personas Morales con Fines no Lucrativos',
      '605 - Sueldos y Salarios e Ingresos Asimilados',
      '612 - Personas Físicas con Actividades Empresariales y Profesionales',
      '616 - Sin obligaciones fiscales',
      '621 - Incorporación Fiscal',
      '625 - Actividades Empresariales con Plataformas Tecnológicas',
      '626 - Régimen Simplificado de Confianza (RESICO)',
    ];

    final List<String> opcionesUsoCfdi = [
      'G01 - Adquisición de mercancías',
      'G03 - Gastos en general',
      'D01 - Honorarios médicos, dentales y gastos hospitalarios',
      'D02 - Gastos médicos por incapacidad o discapacidad',
      'S01 - Sin efectos fiscales',
      'CP01 - Pagos',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double subtotal = (venta['subtotal'] as num? ?? 0.0).toDouble();
          final double descuento = (venta['descuento'] as num? ?? 0.0).toDouble();
          final double total = (venta['total'] as num? ?? 0.0).toDouble();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.indigo.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    yaFacturada ? 'Factura Fiscal CFDI 4.0' : 'Generar Factura para Ticket',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta Resumen del Ticket
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${venta["fecha_venta"].toString().replaceFirst("T", " ").substring(0, 16)}  •  Método: ${venta["metodo_pago"] ?? "EFECTIVO"}',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          if (yaFacturada) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.verified, size: 16, color: Colors.indigo.shade900),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Factura: ${venta["folio_factura"]} | UUID: ${venta["uuid_fiscal"]}',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
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
                            style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                            icon: const Icon(Icons.code, size: 16),
                            label: const Text('Descargar XML CFDI 4.0'),
                            onPressed: () async {
                              try {
                                final xmlStr = await ApiService.descargarXmlFactura(venta['id']);
                                Clipboard.setData(ClipboardData(text: xmlStr));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('XML CFDI 4.0 oficial descargado y copiado al portapapeles.'),
                                      backgroundColor: Colors.indigo,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al descargar XML: $e'), backgroundColor: Colors.red),
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
                                  backgroundColor: Colors.indigo.shade900,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      // Formulario de Emisión de Factura
                      const Text(
                        'Ingrese los datos fiscales del cliente para timbrar la factura:',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: rfcController,
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
                              controller: cpController,
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
                        controller: razonSocialController,
                        decoration: const InputDecoration(
                          labelText: 'Razón Social / Nombre Completo *',
                          hintText: 'Nombre de la empresa o persona física',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: opcionesRegimen.contains(regimenFiscal) ? regimenFiscal : opcionesRegimen[0],
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Régimen Fiscal (SAT) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: opcionesRegimen
                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => regimenFiscal = val);
                        },
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: opcionesUsoCfdi.contains(usoCfdi) ? usoCfdi : opcionesUsoCfdi[0],
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Uso de CFDI (SAT) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: opcionesUsoCfdi
                            .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => usoCfdi = val);
                        },
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: correoController,
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
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
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
                                  const Text('Descuento Otorgado:', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  Text('-\$${descuento.toStringAsFixed(2)} MXN', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                ],
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('IVA (Medicamentos Tasa 0% / Misceláneos 16%):', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                const Text('\$0.00 MXN (Tasa 0%)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Facturado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '\$${total.toStringAsFixed(2)} MXN',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
              if (!yaFacturada)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                  icon: const Icon(Icons.send_and_archive, size: 18),
                  label: const Text('Emitir Factura CFDI 4.0'),
                  onPressed: () async {
                    final rfc = rfcController.text.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
                    final razon = razonSocialController.text.trim();
                    final cp = cpController.text.trim();

                    if (rfc.length < 12 || rfc.length > 13) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El RFC debe contar con 12 (persona moral) o 13 (persona física) caracteres alfanuméricos.')),
                      );
                      return;
                    }

                    if (razon.isEmpty || cp.length < 5) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Razón social y Código Postal válidos son obligatorios.')),
                      );
                      return;
                    }

                    Navigator.of(ctx).pop();
                    await _procesarFacturaApi(
                      ventaId: venta['id'],
                      rfc: rfc,
                      razonSocial: razon,
                      regimenFiscal: regimenFiscal,
                      codigoPostal: cp,
                      usoCfdi: usoCfdi,
                      correo: correoController.text.trim().isEmpty ? null : correoController.text.trim(),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDatoFactura(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarFacturaApi({
    required int ventaId,
    required String rfc,
    required String razonSocial,
    required String regimenFiscal,
    required String codigoPostal,
    required String usoCfdi,
    String? correo,
  }) async {
    setState(() => _isLoading = true);

    try {
      final resFactura = await ApiService.generarFacturaVenta(ventaId, {
        'rfc_receptor': rfc,
        'razon_social_receptor': razonSocial,
        'regimen_fiscal_receptor': regimenFiscal,
        'codigo_postal_receptor': codigoPostal,
        'uso_cfdi': usoCfdi,
        'correo_factura': correo,
      });

      if (mounted) {
        await _cargarVentas();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Factura ${resFactura["folio_factura"]} emitida exitosamente! UUID: ${resFactura["uuid_fiscal"]}'),
            backgroundColor: Colors.indigo.shade900,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al emitir factura: $e'), backgroundColor: Colors.red.shade800),
        );
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
    String estadoProducto = 'BUEN_ESTADO';

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
                          final nombre = d['producto_nombre'] ?? 'Prod #${d["producto_id"]}';
                          return DropdownMenuItem(
                            value: d,
                            child: Text('$nombre (${d["cantidad"]} pzas vendidas)'),
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
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historial de Ventas, Tickets y Facturación',
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

            // Sub-Agente 1: Apartado de Automatización de Facturación por Folio de Ticket
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Icon(Icons.receipt_long, color: Colors.indigo.shade900),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Módulo de Facturación Electrónica (CFDI 4.0)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Automatización: Si el cliente solicita su factura, ingrese su folio de ticket (ej: TK-20261028-A1B2C3) para emitirla al instante.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _ticketSearchController,
                      decoration: InputDecoration(
                        hintText: 'Folio de ticket (ej: TK-...)...',
                        prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        suffixIcon: _buscandoTicket
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      onSubmitted: (val) => _buscarTicketParaFacturar(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                    onPressed: _buscandoTicket ? null : () => _buscarTicketParaFacturar(_ticketSearchController.text),
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Facturar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Lista de Ventas
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
                                final bool estaFacturada = v['facturada'] == true;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: estaFacturada ? Colors.indigo.shade50 : Colors.teal.shade50,
                                      child: Icon(
                                        estaFacturada ? Icons.verified : Icons.receipt,
                                        color: estaFacturada ? Colors.indigo.shade800 : Colors.teal,
                                      ),
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
                                        if (estaFacturada) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.indigo.shade400),
                                            ),
                                            child: Text(
                                              'FACTURADA: ${v["folio_factura"] ?? "CFDI"}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
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
                                                // Sub-Agente 1: Botón Facturar o Ver Factura
                                                FilledButton.tonalIcon(
                                                  icon: Icon(estaFacturada ? Icons.description : Icons.request_quote_outlined, size: 16),
                                                  label: Text(
                                                    estaFacturada ? 'Ver Factura CFDI' : 'Facturar Ticket',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: estaFacturada ? Colors.indigo.shade100 : null,
                                                    foregroundColor: estaFacturada ? Colors.indigo.shade900 : null,
                                                  ),
                                                  onPressed: () => _abrirModalFacturacion(v),
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
                                              'Detalle de artículos despachados:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 8),
                                            ...detalles.map((d) {
                                              final List<dynamic> lotesDespachados = d['despachos_lotes'] ?? [];
                                              final String nombreProd = d['producto_nombre'] ?? 'Prod ID #${d["producto_id"]}';
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
                                                      '$nombreProd [ID: #${d["producto_id"]}]  •  Cantidad: ${d["cantidad"]} pzas  •  Subtotal: \$${d["subtotal"]}',
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 8,
                                                      children: lotesDespachados.map((ld) {
                                                        return Chip(
                                                          label: Text(
                                                            'Lote #${ld["lote_id"]}: ${ld["cantidad_despachada"]} pzas',
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
