import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/lector_codigo_barras_dialog.dart';
import '../widgets/premium_ui.dart';
import '../widgets/ticket_impresion_dialog.dart';
import 'pos/pos_checkout_dialog.dart';
import 'pos/pos_ticket_panel.dart';

class PosScreen extends StatefulWidget {
  final VoidCallback onVentaCompletada;

  const PosScreen({super.key, required this.onVentaCompletada});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<dynamic> _productos = [];
  List<Medico> _medicos = [];
  List<dynamic> _clientes = [];
  Map<String, dynamic>? _clienteSeleccionado;
  bool _isLoading = true;

  // Búsqueda y Filtros de Mostrador
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _busquedaFocus = FocusNode();
  String _filtroGrupo = 'TODOS';
  bool _soloConStock = false;

  // Carrito de compras
  final List<Map<String, dynamic>> _carrito = [];
  final _compradorController = TextEditingController(text: 'Público General');
  final _folioRecetaController = TextEditingController();
  DateTime? _inicioAtencionVenta;
  bool _recetaRetenida = true;
  bool _recetaSinErrores = true;
  bool _recetaSurtidaCompleta = true;
  final _montoRecibidoController = TextEditingController();
  String _metodoPago = 'EFECTIVO';
  Medico? _medicoSeleccionado;
  bool _procesandoVenta = false;
  bool _ticketSheetAbierto = false;

  double get _descuento {
    if (_clienteSeleccionado != null) {
      final pct = (_clienteSeleccionado!['descuento_porcentaje'] as num?)?.toDouble() ?? 0.0;
      return _subtotal * (pct / 100.0);
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _busquedaFocus.dispose();
    _compradorController.dispose();
    _folioRecetaController.dispose();
    _montoRecibidoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final productosFuture = ApiService.getProductos();
      final medicosFuture = ApiService.getMedicos(soloVigentes: true);
      final clientesFuture = ApiService.getClientes(soloActivos: true);

      final results = await Future.wait([productosFuture, medicosFuture, clientesFuture]);
      if (mounted) {
        setState(() {
          _productos = results[0];
          _medicos = results[1] as List<Medico>;
          _clientes = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando catálogo: $e')),
        );
      }
    }
  }

  Future<void> _modalNuevoClienteRapido() {
    return mostrarModalNuevoClienteRapido(
      context,
      onClienteCreado: (nuevoCliente) {
        if (!mounted) return;
        final nom = nuevoCliente['nombre'] ?? '';
        final ape = nuevoCliente['apellido'] ?? '';
        setState(() {
          _clientes.insert(0, nuevoCliente);
          _clienteSeleccionado = nuevoCliente;
          _compradorController.text = '$nom $ape'.trim();
        });
      },
    );
  }

  Future<void> _abrirBuscadorYConfirmacionCliente() {
    return mostrarBuscadorYConfirmacionCliente(
      context,
      clientes: _clientes,
      clienteSeleccionado: _clienteSeleccionado,
      onClienteSeleccionado: (cliente) {
        if (!mounted) return;
        setState(() {
          _clienteSeleccionado = cliente;
          _compradorController.text = cliente != null
              ? '${cliente["nombre"]} ${cliente["apellido"]}'
              : 'Público General';
        });
      },
      onNuevoCliente: _modalNuevoClienteRapido,
    );
  }

  // Filtrado reactivo en memoria para máxima velocidad de respuesta en mostrador
  List<dynamic> get _productosFiltrados {
    final query = _busquedaController.text.trim().toLowerCase();

    return _productos.where((p) {
      // 1. Filtro por disponibilidad de stock
      final int stock = p['stock_total'] ?? 0;
      if (_soloConStock && stock <= 0) return false;

      // 2. Filtro por Grupo Farmacopea / COFEPRIS
      final String grupo = p['grupo_farmacopea'] ?? '';
      if (_filtroGrupo != 'TODOS') {
        if (_filtroGrupo == 'CONTROLADOS') {
          if (grupo != 'GRUPO_I' && grupo != 'GRUPO_II' && grupo != 'GRUPO_III') {
            return false;
          }
        } else if (grupo != _filtroGrupo) {
          return false;
        }
      }

      // 3. Filtro por texto (Nombre comercial, sustancia activa, código de barras o laboratorio)
      if (query.isNotEmpty) {
        final nom = (p['nombre_comercial'] ?? '').toString().toLowerCase();
        final sus = (p['sustancia_activa'] ?? '').toString().toLowerCase();
        final cod = (p['codigo_barras'] ?? '').toString().toLowerCase();
        final lab = (p['laboratorio'] ?? '').toString().toLowerCase();

        if (!nom.contains(query) &&
            !sus.contains(query) &&
            !cod.contains(query) &&
            !lab.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Apertura de escáner de código de barras con la cámara del celular
  Future<void> _abrirEscanerCamara() async {
    final codigo = await LectorCodigoBarrasDialog.escanear(
      context,
      titulo: 'Escanear Medicamento para Cobro',
    );
    if (codigo != null && codigo.trim().isNotEmpty) {
      _procesarEscaneoCodigoBarras(codigo.trim());
    }
  }

  // Soporte para pistola / escáner de código de barras
  void _procesarEscaneoCodigoBarras(String valor) {
    final ts = ThemeService.instance;
    final codigo = valor.trim();
    if (codigo.isEmpty) return;

    // Buscar coincidencia exacta por código de barras
    final index = _productos.indexWhere((p) => p['codigo_barras'] == codigo);
    if (index >= 0) {
      final producto = _productos[index];
      final int stock = producto['stock_total'] ?? 0;
      if (stock > 0) {
        _agregarAlCarrito(producto);
        _busquedaController.clear();
        _busquedaFocus.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: ts.esTemaNeon ? Colors.black : Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('¡Añadido: ${producto["nombre_comercial"]}!'),
              ],
            ),
            backgroundColor: ts.accentPrimary,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡${producto["nombre_comercial"]} no tiene stock disponible!'),
            backgroundColor: ts.neonAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int _cantidadEnCarrito(int productoId) {
    final item = _carrito.firstWhere(
      (it) => it['producto']['id'] == productoId,
      orElse: () => {'cantidad': 0},
    );
    return item['cantidad'] as int;
  }

  void _agregarAlCarrito(dynamic producto) {
    final ts = ThemeService.instance;
    final int stockTotal = producto['stock_total'] ?? 0;
    if (stockTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${producto["nombre_comercial"]} no tiene stock disponible!'),
          backgroundColor: ts.neonAmber,
        ),
      );
      return;
    }

    final index = _carrito.indexWhere((item) => item['producto']['id'] == producto['id']);
    if (index >= 0) {
      if (_carrito[index]['cantidad'] < stockTotal) {
        setState(() {
          _carrito[index]['cantidad'] += 1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay más stock disponible para ${producto["nombre_comercial"]}')),
        );
      }
    } else {
      setState(() {
        _inicioAtencionVenta ??= DateTime.now();
        _carrito.add({
          'producto': producto,
          'cantidad': 1,
        });
      });
    }
  }

  void _cambiarCantidad(int index, int delta) {
    setState(() {
      final item = _carrito[index];
      final int stockTotal = item['producto']['stock_total'] ?? 0;
      final int nuevaCantidad = item['cantidad'] + delta;

      if (nuevaCantidad > stockTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cantidad supera el stock disponible en los lotes.')),
        );
        return;
      }

      if (nuevaCantidad <= 0) {
        _carrito.removeAt(index);
      } else {
        item['cantidad'] = nuevaCantidad;
      }
    });
  }

  bool get _requiereMedico {
    return _carrito.any((item) => item['producto']['requiere_receta'] == true);
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _carrito) {
      final precio = (item['producto']['precio_venta'] as num).toDouble();
      total += precio * item['cantidad'];
    }
    return total;
  }

  double get _total {
    return (_subtotal - _descuento).clamp(0.0, double.infinity);
  }

  double get _montoRecibido {
    return double.tryParse(_montoRecibidoController.text.trim()) ?? 0.0;
  }

  double get _cambio {
    if (_metodoPago != 'EFECTIVO') return 0.0;
    if (_montoRecibido >= _total) {
      return _montoRecibido - _total;
    }
    return 0.0;
  }

  Future<void> _cobrarVenta() async {
    final ts = ThemeService.instance;
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío')),
      );
      return;
    }

    if (_requiereMedico && _medicoSeleccionado == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: ts.neonAmber, size: 48),
          title: const Text('Bloqueo Regulatorio COFEPRIS'),
          content: const Text(
            'El carrito contiene medicamentos del Grupo IV (Antibióticos) o Controlados que por Ley General de Salud '
            'requieren la prescripción de un médico con cédula profesional vigente.\n\n'
            'Por favor, selecciona al médico prescriptor antes de continuar.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    if (_metodoPago == 'EFECTIVO' && _montoRecibido < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El monto recibido (\$${_montoRecibido.toStringAsFixed(2)}) es menor al total (\$${_total.toStringAsFixed(2)})'),
          backgroundColor: ts.neonRed,
        ),
      );
      return;
    }

    setState(() => _procesandoVenta = true);

    final int tiempoAtencionSeg = _inicioAtencionVenta != null
        ? DateTime.now().difference(_inicioAtencionVenta!).inSeconds.clamp(1, 7200)
        : 140;
    final bool tieneReceta = _medicoSeleccionado != null ||
        _carrito.any((it) => it['producto']?['requiere_receta'] == true);

    final payload = {
      'cliente_id': _clienteSeleccionado?['id'],
      'comprador_nombre': _clienteSeleccionado != null
          ? '${_clienteSeleccionado!["nombre"]} ${_clienteSeleccionado!["apellido"]}'
          : (_compradorController.text.trim().isEmpty ? 'Público General' : _compradorController.text.trim()),
      'comprador_identificacion': null,
      'medico_id': _medicoSeleccionado?.id,
      'descuento': _descuento,
      'metodo_pago': _metodoPago,
      'monto_recibido': _metodoPago == 'EFECTIVO' ? _montoRecibido : _total,
      'cajero_nombre': AuthService.currentUser.nombreCompleto,
      'tiempo_atencion_seg': tiempoAtencionSeg,
      if (_folioRecetaController.text.trim().isNotEmpty) 'folio_receta': _folioRecetaController.text.trim(),
      'receta_retenida': tieneReceta ? _recetaRetenida : false,
      'receta_sin_errores': _recetaSinErrores,
      'receta_surtida_completa': _recetaSurtidaCompleta,
      'items': _carrito.map((item) {
        return {
          'producto_id': item['producto']['id'],
          'cantidad': item['cantidad'],
        };
      }).toList(),
    };

    try {
      final ticket = await ApiService.registrarVenta(payload);
      if (!mounted) return;

      setState(() {
        _carrito.clear();
        _inicioAtencionVenta = null;
        _folioRecetaController.clear();
        _clienteSeleccionado = null;
        _compradorController.text = 'Público General';
        _medicoSeleccionado = null;
        _montoRecibidoController.clear();
        _procesandoVenta = false;
      });

      _cargarDatos();
      widget.onVentaCompletada();

      if (_ticketSheetAbierto && mounted) {
        Navigator.of(context).pop();
        _ticketSheetAbierto = false;
      }

      // Abrir modal térmico realista con opción de imprimir
      TicketImpresionDialog.mostrar(context, ticket);
    } catch (e) {
      if (mounted) {
        setState(() => _procesandoVenta = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.error_outline, color: ts.neonRed, size: 40),
            title: const Text('Error en el Despacho'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar')),
            ],
          ),
        );
      }
    }
  }

  void _abrirTicketBottomSheet() {
    _ticketSheetAbierto = true;
    mostrarTicketBottomSheet(
      context,
      builder: (onActualizar) => _construirTicketWidget(
        enBottomSheet: true,
        onActualizar: () {
          onActualizar();
          setState(() {});
        },
      ),
      onClosed: () => _ticketSheetAbierto = false,
    );
  }

  Widget _construirBarraResumenCarritoMobile() {
    return PosMobileCartBar(
      carrito: _carrito,
      total: _total,
      onAbrirTicket: _abrirTicketBottomSheet,
    );
  }

  Widget _construirTicketWidget({bool enBottomSheet = false, VoidCallback? onActualizar}) {
    void refrescar() {
      if (onActualizar != null) {
        onActualizar();
      } else {
        setState(() {});
      }
    }

    return PosTicketPanel(
      carrito: _carrito,
      clienteSeleccionado: _clienteSeleccionado,
      medicos: _medicos,
      medicoSeleccionado: _medicoSeleccionado,
      requiereMedico: _requiereMedico,
      folioRecetaController: _folioRecetaController,
      recetaRetenida: _recetaRetenida,
      recetaSinErrores: _recetaSinErrores,
      recetaSurtidaCompleta: _recetaSurtidaCompleta,
      metodoPago: _metodoPago,
      montoRecibidoController: _montoRecibidoController,
      subtotal: _subtotal,
      descuento: _descuento,
      total: _total,
      cambio: _cambio,
      procesandoVenta: _procesandoVenta,
      enBottomSheet: enBottomSheet,
      onVaciarCarrito: () {
        _carrito.clear();
        refrescar();
      },
      onBuscarCliente: () async {
        await _abrirBuscadorYConfirmacionCliente();
        refrescar();
      },
      onNuevoCliente: () async {
        await _modalNuevoClienteRapido();
        refrescar();
      },
      onQuitarCliente: () {
        _clienteSeleccionado = null;
        _compradorController.text = 'Público General';
        refrescar();
      },
      onMedicoChanged: (val) {
        _medicoSeleccionado = val;
        refrescar();
      },
      onRecetaRetenidaChanged: (v) {
        _recetaRetenida = v;
        refrescar();
      },
      onRecetaSinErroresChanged: (v) {
        _recetaSinErrores = v;
        refrescar();
      },
      onRecetaSurtidaCompletaChanged: (v) {
        _recetaSurtidaCompleta = v;
        refrescar();
      },
      onCambiarCantidad: (index, delta) {
        _cambiarCantidad(index, delta);
        refrescar();
      },
      onMetodoPagoChanged: (val) {
        _metodoPago = val;
        refrescar();
      },
      onMontoRecibidoChanged: refrescar,
      onMontoExacto: () {
        _montoRecibidoController.text = _total.toStringAsFixed(2);
        refrescar();
      },
      onCobrar: () async {
        await _cobrarVenta();
        refrescar();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final productosVisibles = _productosFiltrados;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 850;

        final Widget catalogoWidget = Padding(
          padding: EdgeInsets.all(isMobile ? 10.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado y Contador de Inventario HeroUI
              PremiumModuleHeader(
                title: isMobile ? 'Despacho POS' : 'Despacho y Cobro en Mostrador',
                subtitle: 'Venta asistida y control sanitario FEFO',
                icon: Icons.point_of_sale,
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ts.esTemaNeon
                        ? ts.tintBg(ts.accentPrimary)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ts.esTemaNeon ? ts.borderColor : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${productosVisibles.length} de ${_productos.length} medicamentos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: ts.esTemaNeon ? ts.textPrimary : Colors.white),
                    onPressed: _cargarDatos,
                    tooltip: 'Recargar stock',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Contenedor de Búsqueda y Filtros HeroUI / Fragments UI
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ts.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ts.borderColor, width: 1.2),
                  boxShadow: ts.cardGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra de Búsqueda Inteligente + Lector de Código de Barras
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _busquedaController,
                            focusNode: _busquedaFocus,
                            decoration: InputDecoration(
                              hintText: isMobile
                                  ? 'Buscar por nombre o fórmula...'
                                  : 'Buscar por nombre, sustancia activa o escanea código de barras...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: ts.cardBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: ts.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: ts.borderColor),
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_busquedaController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _busquedaController.clear();
                                        setState(() {});
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.camera_alt, color: ts.accentPrimary),
                                    tooltip: 'Escanear código de barras con la cámara',
                                    onPressed: _abrirEscanerCamara,
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: _procesarEscaneoCodigoBarras,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Chips de Filtro Rápido por Clasificación Sanitaria
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: _filtroGrupo == 'TODOS',
                            onSelected: (val) => setState(() => _filtroGrupo = 'TODOS'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Venta Libre (Grupo VI)'),
                            selected: _filtroGrupo == 'GRUPO_VI',
                            selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.25, darkAlpha: 0.3),
                            onSelected: (val) => setState(() => _filtroGrupo = 'GRUPO_VI'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Antibióticos (Grupo IV)'),
                            selected: _filtroGrupo == 'GRUPO_IV',
                            selectedColor: ts.tintBg(ts.neonAmber, lightAlpha: 0.25, darkAlpha: 0.3),
                            onSelected: (val) => setState(() => _filtroGrupo = 'GRUPO_IV'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Controlados (Grupo I-III)'),
                            selected: _filtroGrupo == 'CONTROLADOS',
                            selectedColor: ts.tintBg(ts.neonRed, lightAlpha: 0.25, darkAlpha: 0.3),
                            onSelected: (val) => setState(() => _filtroGrupo = 'CONTROLADOS'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Crónicos (Grupo V)'),
                            selected: _filtroGrupo == 'GRUPO_V',
                            selectedColor: ts.tintBg(ts.neonPurple, lightAlpha: 0.25, darkAlpha: 0.3),
                            onSelected: (val) => setState(() => _filtroGrupo = 'GRUPO_V'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Solo con Stock'),
                            selected: _soloConStock,
                            onSelected: (val) => setState(() => _soloConStock = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grilla de Medicamentos
              Expanded(
                child: productosVisibles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 56, color: ts.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron medicamentos para "${_busquedaController.text.trim()}"',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Verifica la ortografía o limpia los filtros de búsqueda.',
                              style: TextStyle(color: ts.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.tonal(
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() {
                                  _filtroGrupo = 'TODOS';
                                  _soloConStock = false;
                                });
                              },
                              child: const Text('Limpiar Filtros y Ver Todos'),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, gConstraints) {
                          final double gWidth = gConstraints.maxWidth;
                          final bool isSmallPhone = gWidth < 420;
                          final double maxExtent = isSmallPhone ? 175 : (isMobile ? 190 : 260);
                          final double aspectRatio = isSmallPhone ? 0.67 : (isMobile ? 0.72 : 0.86);

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: maxExtent,
                              childAspectRatio: aspectRatio,
                              crossAxisSpacing: isMobile ? 8 : 12,
                              mainAxisSpacing: isMobile ? 8 : 12,
                            ),
                            itemCount: productosVisibles.length,
                            itemBuilder: (context, index) {
                              final p = productosVisibles[index];
                              final int stock = p['stock_total'] ?? 0;
                              final bool reqReceta = p['requiere_receta'] == true;
                              final int enCarrito = _cantidadEnCarrito(p['id']);
                              final bool estaEnCarrito = enCarrito > 0;

                              return Container(
                                decoration: BoxDecoration(
                                  color: ts.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: estaEnCarrito ? ts.accentPrimary : ts.borderColor,
                                    width: estaEnCarrito ? 1.6 : 1.2,
                                  ),
                                  boxShadow: ts.cardGlowShadow,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: stock > 0 ? () => _agregarAlCarrito(p) : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(9.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Barra Superior: Clasificación y Stock
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: reqReceta ? ts.tintBg(ts.neonAmber) : ts.tintBg(ts.accentPrimary),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  p['grupo_farmacopea'] ?? 'GRUPO_VI',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: reqReceta ? ts.neonAmber : ts.accentPrimary,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'Stock: $stock',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: stock > 0 ? ts.neonGreen : ts.neonRed,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Nombre comercial y sustancia
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['nombre_comercial'],
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
                                              ),
                                              Text(
                                                p['sustancia_activa'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10, color: ts.textSecondary),
                                              ),
                                            ],
                                          ),

                                          // Presentación y Laboratorio
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['presentacion'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 9, color: ts.textSecondary),
                                              ),
                                              Text(
                                                p['laboratorio'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 9, color: ts.accentPrimary, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),

                                          // Precio y Botón de Añadir con Badge
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '\$${p["precio_venta"]} MXN',
                                                  style: TextStyle(
                                                    fontSize: isMobile ? 11 : 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (enCarrito > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: ts.accentPrimary,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '🛒 $enCarrito',
                                                    style: TextStyle(color: ts.esTemaNeon ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                )
                                              else
                                                FilledButton.tonal(
                                                  style: FilledButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    minimumSize: const Size(32, 28),
                                                  ),
                                                  onPressed: stock > 0 ? () => _agregarAlCarrito(p) : null,
                                                  child: const Icon(Icons.add_shopping_cart, size: 14),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: ts.scaffoldBg,
            body: catalogoWidget,
            bottomNavigationBar: _construirBarraResumenCarritoMobile(),
          );
        } else {
          return Scaffold(
            backgroundColor: ts.scaffoldBg,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: catalogoWidget),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                  child: SizedBox(
                    width: 380,
                    child: _construirTicketWidget(),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
