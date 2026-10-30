import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ticket_impresion_dialog.dart';

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
  final _montoRecibidoController = TextEditingController();
  String _metodoPago = 'EFECTIVO';
  Medico? _medicoSeleccionado;
  bool _procesandoVenta = false;

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

  void _modalNuevoClienteRapido() {
    final nomCtrl = TextEditingController();
    final apePaternoCtrl = TextEditingController();
    final apeMaternoCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: '5.0');

    // Sub-Agente 3 & 4: Sexo y Fecha de Nacimiento en Alta Rápida
    String? sexoSeleccionado;
    final diaCtrl = TextEditingController();
    final mesCtrl = TextEditingController();
    final anioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.teal),
              SizedBox(width: 8),
              Text('Registro Exprés de Cliente'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre(s) *', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 10),
                  // Sub-Agente 5: Apellido Paterno y Materno
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: apePaternoCtrl,
                          decoration: const InputDecoration(labelText: 'Apellido Paterno *', prefixIcon: Icon(Icons.badge)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: apeMaternoCtrl,
                          decoration: const InputDecoration(labelText: 'Apellido Materno', prefixIcon: Icon(Icons.badge_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: telCtrl,
                          decoration: const InputDecoration(labelText: 'Teléfono (Opcional)', prefixIcon: Icon(Icons.phone)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: descCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: '% Descuento', suffixText: '%'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Sub-Agente 4: Sexo con isExpanded y TextOverflow.ellipsis
                  DropdownButtonFormField<String>(
                    value: sexoSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sexo / Género (Opcional)',
                      prefixIcon: Icon(Icons.wc),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('No especificar / Prefiero no decir', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'MASCULINO', child: Text('Masculino', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'FEMENINO', child: Text('Femenino', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'OTRO', child: Text('Otro / No especificado', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setModalState(() => sexoSeleccionado = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Fecha de Nacimiento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, color: Colors.teal),
                        tooltip: 'Buscar en calendario',
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(1995, 1, 1),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              diaCtrl.text = picked.day.toString().padLeft(2, '0');
                              mesCtrl.text = picked.month.toString().padLeft(2, '0');
                              anioCtrl.text = picked.year.toString();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: diaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Día', hintText: 'DD', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: mesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Mes', hintText: 'MM', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: anioCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Año', hintText: 'AAAA', isDense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar y Aplicar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                final nom = nomCtrl.text.trim();
                final pat = apePaternoCtrl.text.trim();
                final mat = apeMaternoCtrl.text.trim();
                if (nom.isEmpty || (pat.isEmpty && mat.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre y al menos un Apellido son obligatorios')),
                  );
                  return;
                }

                final apCompleto = "$pat $mat".trim();
                String? fechaNacStr;
                final d = int.tryParse(diaCtrl.text.trim());
                final m = int.tryParse(mesCtrl.text.trim());
                final a = int.tryParse(anioCtrl.text.trim());
                if (d != null && m != null && a != null && d >= 1 && d <= 31 && m >= 1 && m <= 12 && a >= 1900 && a <= DateTime.now().year) {
                  fechaNacStr = "${a.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
                }

                final desc = double.tryParse(descCtrl.text.trim()) ?? 5.0;
                try {
                  final nuevoCliente = await ApiService.createCliente({
                    'nombre': nom,
                    'apellido': apCompleto,
                    'apellido_paterno': pat.isNotEmpty ? pat : null,
                    'apellido_materno': mat.isNotEmpty ? mat : null,
                    'telefono': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                    'descuento_porcentaje': desc,
                    'fecha_nacimiento': fechaNacStr,
                    'sexo': sexoSeleccionado,
                  });

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  setState(() {
                    _clientes.insert(0, nuevoCliente);
                    _clienteSeleccionado = nuevoCliente;
                    _compradorController.text = '$nom $apCompleto';
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cliente "$nom $apCompleto" registrado con $desc% de descuento aplicado.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al registrar cliente: $e'), backgroundColor: Colors.red),
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

  // =========================================================================
  // SUB-AGENTE 3: MODAL DE BÚSQUEDA Y CONFIRMACIÓN DE CLIENTE (TEL / FECHA NAC)
  // =========================================================================
  void _abrirBuscadorYConfirmacionCliente() {
    final TextEditingController busquedaCtrl = TextEditingController();
    String query = '';
    Map<String, dynamic>? candidatoSeleccionado;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final q = query.trim().toLowerCase();
          final qLimpio = q.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

          final resultados = _clientes.where((c) {
            if (q.isEmpty) return true;
            final nom = (c['nombre'] ?? '').toString().toLowerCase();
            final ape = (c['apellido'] ?? '').toString().toLowerCase();
            final tel = (c['telefono'] ?? '').toString().toLowerCase();
            final telLimpio = tel.replaceAll(RegExp(r'[^0-9]'), '');
            final fechaNac = (c['fecha_nacimiento'] ?? '').toString().toLowerCase();

            return nom.contains(q) ||
                ape.contains(q) ||
                tel.contains(q) ||
                (qLimpio.isNotEmpty && telLimpio.contains(qLimpio)) ||
                fechaNac.contains(q);
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person_search, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Búsqueda y Confirmación de Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Busca por teléfono, nombre o confirma con fecha de nacimiento', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    controller: busquedaCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por teléfono (ej: 555-321-7890), nombre o apellido...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  busquedaCtrl.clear();
                                  query = '';
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: const Text('Asignar a Público General', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _clienteSeleccionado = null;
                            _compradorController.text = 'Público General';
                          });
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add, size: 16, color: Colors.teal),
                        label: const Text('Nuevo Cliente', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _modalNuevoClienteRapido();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Expanded(
                    child: resultados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 36, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  query.isEmpty ? 'No hay clientes registrados.' : 'Sin resultados para "$query"',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: resultados.length,
                            separatorBuilder: (context, index) => const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final c = resultados[i];
                              final bool esActual = (_clienteSeleccionado?['id'] == c['id']);
                              final bool esCandidato = (candidatoSeleccionado?['id'] == c['id']);
                              final double desc = (c['descuento_porcentaje'] ?? 5.0).toDouble();
                              final String? tel = c['telefono'];
                              final String? fechaNac = c['fecha_nacimiento'];

                              return Container(
                                decoration: BoxDecoration(
                                  color: esCandidato
                                      ? Colors.teal.shade50
                                      : (esActual ? Colors.green.shade50 : Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: esCandidato
                                        ? Colors.teal
                                        : (esActual ? Colors.green : Colors.grey.shade300),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      '${c['nombre']?[0] ?? 'C'}${c['apellido']?[0] ?? ''}'.toUpperCase(),
                                      style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c['nombre']} ${c['apellido']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$desc% Desc',
                                          style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (c['alerta_resurtimiento_activa'] == true) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.shade800),
                                          ),
                                          child: Text(
                                            '🔔 Resurtir (${c['dias_para_resurtimiento'] ?? 0}d)',
                                            style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ] else if (c['tiene_padecimientos_cronicos'] == true) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '💊 Crónico',
                                            style: TextStyle(fontSize: 9, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      if (tel != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone, size: 11, color: Colors.teal),
                                            const SizedBox(width: 3),
                                            Text(tel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      if (fechaNac != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.cake, size: 11, color: Colors.purple),
                                            const SizedBox(width: 3),
                                            Text('Nac: $fechaNac', style: const TextStyle(fontSize: 11)),
                                          ],
                                        )
                                      else
                                        const Text('Sin fecha nac.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  trailing: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        candidatoSeleccionado = c;
                                      });
                                    },
                                    child: const Text('Verificar', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Panel de Confirmación con Fecha de Nacimiento
                  if (candidatoSeleccionado != null) ...[
                    const Divider(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user, color: Colors.amber.shade900, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Confirmar: ${candidatoSeleccionado!["nombre"]} ${candidatoSeleccionado!["apellido"]}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setModalState(() => candidatoSeleccionado = null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            candidatoSeleccionado!['fecha_nacimiento'] != null
                                ? '🎂 Fecha de nacimiento para confirmar: ${candidatoSeleccionado!["fecha_nacimiento"]}  •  📞 ${candidatoSeleccionado!["telefono"] ?? "Sin tel"}'
                                : '📞 Teléfono para confirmar: ${candidatoSeleccionado!["telefono"] ?? "No registrado"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (candidatoSeleccionado!['alerta_resurtimiento_activa'] == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade800),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.notification_important, color: Colors.amber.shade900, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      candidatoSeleccionado!['mensaje_alerta_resurtimiento'] ??
                                          '🔔 Sugerir resurtimiento de tratamiento crónico al paciente.',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Spacer(),
                              TextButton(
                                onPressed: () => setModalState(() => candidatoSeleccionado = null),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Confirmar y Asignar Cliente', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  setState(() {
                                    _clienteSeleccionado = candidatoSeleccionado;
                                    _compradorController.text =
                                        '${candidatoSeleccionado!["nombre"]} ${candidatoSeleccionado!["apellido"]}';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cliente "${candidatoSeleccionado!["nombre"]} ${candidatoSeleccionado!["apellido"]}" confirmado y asignado.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
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
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
            ],
          );
        },
      ),
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

  // Soporte para pistola / escáner de código de barras
  void _procesarEscaneoCodigoBarras(String valor) {
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
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('¡Añadido: ${producto["nombre_comercial"]}!'),
              ],
            ),
            backgroundColor: Colors.teal.shade800,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡${producto["nombre_comercial"]} no tiene stock disponible!'),
            backgroundColor: Colors.orange.shade900,
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
    final int stockTotal = producto['stock_total'] ?? 0;
    if (stockTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${producto["nombre_comercial"]} no tiene stock disponible!'),
          backgroundColor: Colors.orange.shade800,
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
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
          title: const Text('Bloqueo Regulatorio COFEPRIS'),
          content: const Text(
            'El carrito contiene medicamentos del Grupo IV (Antibióticos) o Controlados que por Ley General de Salud '
            'requieren la prescripción de un médico con cédula profesional vigente.\n\n'
            'Por favor, selecciona al médico prescriptor antes de continuar.',
          ),
          actions: [
            FilledButton(
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
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() => _procesandoVenta = true);

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
        _clienteSeleccionado = null;
        _compradorController.text = 'Público General';
        _medicoSeleccionado = null;
        _montoRecibidoController.clear();
        _procesandoVenta = false;
      });

      _cargarDatos();
      widget.onVentaCompletada();

      // Abrir modal térmico realista con opción de imprimir
      TicketImpresionDialog.mostrar(context, ticket);
    } catch (e) {
      if (mounted) {
        setState(() => _procesandoVenta = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final productosVisibles = _productosFiltrados;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =================================================================
          // SECCIÓN IZQUIERDA: CATÁLOGO Y BÚSQUEDA RÁPIDA DE MOSTRADOR
          // =================================================================
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado y Contador de Inventario
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.point_of_sale, color: Colors.teal.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Despacho y Cobro en Mostrador',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Text(
                              '${productosVisibles.length} de ${_productos.length} medicamentos',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _cargarDatos,
                            tooltip: 'Recargar stock',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barra de Búsqueda Inteligente + Lector de Código de Barras
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busquedaController,
                          focusNode: _busquedaFocus,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, sustancia activa o escanea código de barras...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _busquedaController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _busquedaController.clear();
                                      setState(() {});
                                    },
                                  )
                                : const Icon(Icons.qr_code_scanner, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          selectedColor: Colors.teal.shade100,
                          onSelected: (val) => setState(() => _filtroGrupo = 'GRUPO_VI'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Antibióticos (Grupo IV)'),
                          selected: _filtroGrupo == 'GRUPO_IV',
                          selectedColor: Colors.amber.shade100,
                          onSelected: (val) => setState(() => _filtroGrupo = 'GRUPO_IV'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Controlados (Grupo I-III)'),
                          selected: _filtroGrupo == 'CONTROLADOS',
                          selectedColor: Colors.red.shade100,
                          onSelected: (val) => setState(() => _filtroGrupo = 'CONTROLADOS'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Crónicos (Grupo V)'),
                          selected: _filtroGrupo == 'GRUPO_V',
                          selectedColor: Colors.purple.shade100,
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
                  const SizedBox(height: 12),

                  // Grilla de Medicamentos
                  Expanded(
                    child: productosVisibles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron medicamentos para "${_busquedaController.text.trim()}"',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Verifica la ortografía o limpia los filtros de búsqueda.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              childAspectRatio: 0.86,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: productosVisibles.length,
                            itemBuilder: (context, index) {
                              final p = productosVisibles[index];
                              final int stock = p['stock_total'] ?? 0;
                              final bool reqReceta = p['requiere_receta'] == true;
                              final int enCarrito = _cantidadEnCarrito(p['id']);

                              return Card(
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: enCarrito > 0
                                        ? Colors.teal.shade400
                                        : Colors.grey.shade200,
                                    width: enCarrito > 0 ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: stock > 0 ? () => _agregarAlCarrito(p) : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Barra Superior: Clasificación y Stock
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: reqReceta ? Colors.amber.shade100 : Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p['grupo_farmacopea'] ?? 'GRUPO_VI',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: reqReceta ? Colors.amber.shade900 : Colors.teal.shade900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Stock: $stock',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: stock > 0 ? Colors.green.shade800 : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Nombre comercial
                                        Text(
                                          p['nombre_comercial'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        // Sustancia activa
                                        Text(
                                          p['sustancia_activa'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                        const Spacer(),

                                        // Presentación y Laboratorio
                                        Text(
                                          p['presentacion'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                        ),
                                        Text(
                                          p['laboratorio'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, color: Colors.teal.shade700, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 6),

                                        // Precio y Botón de Añadir con Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '\$${p["precio_venta"]} MXN',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade900,
                                              ),
                                            ),
                                            if (enCarrito > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade800,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '🛒 $enCarrito',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              )
                                            else
                                              FilledButton.tonal(
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  minimumSize: const Size(36, 32),
                                                ),
                                                onPressed: stock > 0 ? () => _agregarAlCarrito(p) : null,
                                                child: const Icon(Icons.add_shopping_cart, size: 16),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // =================================================================
          // SECCIÓN DERECHA: TICKET DE VENTA, DESPACHO Y COBRO
          // =================================================================
          SizedBox(
            width: 370,
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        'Ticket de Venta',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_carrito.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _carrito.clear()),
                          child: const Text('Vaciar', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sub-Agente 3: Barra Buscadora y Confirmación de Clientes por Teléfono / Fecha de Nacimiento
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person, color: Colors.teal, size: 16),
                          SizedBox(width: 4),
                          Text('Cliente / Lealtad:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                            onPressed: _abrirBuscadorYConfirmacionCliente,
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            icon: const Icon(Icons.person_add, size: 14),
                            label: const Text('Nuevo', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: const Size(40, 24),
                            ),
                            onPressed: _modalNuevoClienteRapido,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_clienteSeleccionado == null)
                    InkWell(
                      onTap: _abrirBuscadorYConfirmacionCliente,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blueGrey,
                              child: Icon(Icons.person_outline, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('👤 Público General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('Toca para buscar por teléfono o nombre...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search, size: 18, color: Colors.teal),
                              tooltip: 'Buscar cliente por teléfono o nombre',
                              onPressed: _abrirBuscadorYConfirmacionCliente,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.teal.shade700,
                            child: const Icon(Icons.person, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '⭐️ ${_clienteSeleccionado!["nombre"]} ${_clienteSeleccionado!["apellido"]}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    if (_clienteSeleccionado!['telefono'] != null)
                                      Text('📞 ${_clienteSeleccionado!["telefono"]}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                    if (_clienteSeleccionado!['fecha_nacimiento'] != null)
                                      Text('🎂 ${_clienteSeleccionado!["fecha_nacimiento"]}', style: const TextStyle(fontSize: 10, color: Colors.purple)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.teal),
                            tooltip: 'Cambiar cliente',
                            onPressed: _abrirBuscadorYConfirmacionCliente,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                            tooltip: 'Quitar cliente (Público General)',
                            onPressed: () {
                              setState(() {
                                _clienteSeleccionado = null;
                                _compradorController.text = 'Público General';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  if (_clienteSeleccionado != null) ...[
                    if (_clienteSeleccionado!['alerta_resurtimiento_activa'] == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade800, width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notification_important, color: Colors.amber.shade900, size: 20),
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
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _clienteSeleccionado!['mensaje_alerta_resurtimiento'] ??
                                        'Sugerir al paciente el resurtimiento de su tratamiento.',
                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
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
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.loyalty, color: Colors.green, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Beneficio: ${_clienteSeleccionado!["descuento_porcentaje"]}% de Descuento aplicado',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                              ),
                            ],
                          ),
                          if (_clienteSeleccionado!['enfermedades'] != null && (_clienteSeleccionado!['enfermedades'] as List).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: (_clienteSeleccionado!['enfermedades'] as List).map((enf) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '🩺 ${enf["codigo_cie"]}',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
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
                  if (_requiereMedico) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Medicamento Controlado / Antibiótico',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Medico>(
                            initialValue: _medicoSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Médico que Prescribe (Cédula Vigente) *',
                              isDense: true,
                            ),
                            items: _medicos.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text('Dr. ${m.nombreCompleto} (Céd: ${m.cedulaProfesional})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _medicoSeleccionado = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Lista del Carrito
                  Expanded(
                    child: _carrito.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_shopping_cart, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text('Selecciona productos del catálogo'),
                                const SizedBox(height: 4),
                                Text(
                                  'O escanea el código de barras en la búsqueda',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _carrito.length,
                            separatorBuilder: (_, __) => const Divider(height: 10),
                            itemBuilder: (context, index) {
                              final item = _carrito[index];
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
                                        Text('\$${p["precio_venta"]} c/u', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () => _cambiarCantidad(index, -1),
                                  ),
                                  Text('$cant', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () => _cambiarCantidad(index, 1),
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

                  // Selector de Método de Pago
                  Row(
                    children: [
                      const Text('Método de Pago: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _metodoPago,
                        isDense: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo')),
                          DropdownMenuItem(value: 'TARJETA', child: Text('💳 Tarjeta')),
                          DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('🏦 Transferencia')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _metodoPago = val);
                        },
                      ),
                    ],
                  ),

                  // Si es efectivo, input de Paga con y cálculo de cambio
                  if (_metodoPago == 'EFECTIVO' && _carrito.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _montoRecibidoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Paga con (\$ MXN)',
                              isDense: true,
                              prefixIcon: Icon(Icons.attach_money, size: 18),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: () {
                            _montoRecibidoController.text = _total.toStringAsFixed(2);
                            setState(() {});
                          },
                          child: const Text('Exacto', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    if (_cambio > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cambio a entregar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('\$${_cambio.toStringAsFixed(2)} MXN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ],

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      Text(
                        '\$${_subtotal.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (_descuento > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Desc. Lealtad (${_clienteSeleccionado!["descuento_porcentaje"]}%):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                        Text(
                          '-\$${_descuento.toStringAsFixed(2)} MXN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade800),
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
                        '\$${_total.toStringAsFixed(2)} MXN',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _procesandoVenta ? null : _cobrarVenta,
                    icon: _procesandoVenta
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.payments),
                    label: Text(_procesandoVenta ? 'Despachando FEFO...' : 'Cobrar e Imprimir Ticket'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
