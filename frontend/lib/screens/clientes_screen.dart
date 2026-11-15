import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/lector_codigo_barras_dialog.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<dynamic> _clientes = [];
  List<dynamic> _enfermedadesDisponibles = [];
  List<dynamic> _productosInventario = [];
  String _filtroResurtimiento = 'TODOS';
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientesFuture = ApiService.getClientes(
        buscar: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      final enfFuture = ApiService.getEnfermedades();
      final productosFuture = ApiService.getProductos();

      final results = await Future.wait([clientesFuture, enfFuture, productosFuture]);
      if (mounted) {
        setState(() {
          _clientes = results[0];
          _enfermedadesDisponibles = results[1];
          _productosInventario = results[2];
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

  List<dynamic> get _clientesFiltrados {
    return _clientes.where((c) {
      final bool esCronico = c['tiene_padecimientos_cronicos'] == true;
      final int? dias = c['dias_para_resurtimiento'] as int?;
      final bool alerta = c['alerta_resurtimiento_activa'] == true;

      switch (_filtroResurtimiento) {
        case 'ALERTAS':
          return alerta;
        case 'VENCIDOS':
          return esCronico && dias != null && dias < 0;
        case 'AL_DIA':
          return esCronico && dias != null && dias > 21;
        case 'CRONICOS':
          return esCronico;
        case 'TODOS':
        default:
          return true;
      }
    }).toList();
  }

  int get _countAlertas => _clientes.where((c) => c['alerta_resurtimiento_activa'] == true).length;
  int get _countVencidos => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true && (c['dias_para_resurtimiento'] ?? 0) < 0).length;
  int get _countAlDia => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true && (c['dias_para_resurtimiento'] ?? 0) > 21).length;
  int get _countCronicos => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true).length;

  void _abrirFormularioCliente({Map<String, dynamic>? clienteExistente}) {
    final bool esEdicion = clienteExistente != null;
    final nombreCtrl = TextEditingController(text: clienteExistente?['nombre'] ?? '');

    // Sub-Agente 5: Separación de Apellido Paterno y Materno (opcional si es uno solo o compuesto)
    String initPaterno = clienteExistente?['apellido_paterno'] ?? '';
    String initMaterno = clienteExistente?['apellido_materno'] ?? '';
    if (initPaterno.isEmpty && initMaterno.isEmpty && clienteExistente?['apellido'] != null) {
      final partes = clienteExistente!['apellido'].toString().trim().split(' ');
      if (partes.length >= 2) {
        initPaterno = partes[0];
        initMaterno = partes.sublist(1).join(' ');
      } else {
        initPaterno = partes.isNotEmpty ? partes[0] : '';
      }
    }
    final apellidoPaternoCtrl = TextEditingController(text: initPaterno);
    final apellidoMaternoCtrl = TextEditingController(text: initMaterno);

    final telefonoCtrl = TextEditingController(text: clienteExistente?['telefono'] ?? '');
    final correoCtrl = TextEditingController(text: clienteExistente?['correo_electronico'] ?? '');
    final direccionCtrl = TextEditingController(text: clienteExistente?['direccion'] ?? '');
    final descuentoCtrl = TextEditingController(
      text: (clienteExistente?['descuento_porcentaje'] ?? 5.0).toString(),
    );
    final notasCtrl = TextEditingController(text: clienteExistente?['notas_clinicas'] ?? '');

    // Sub-Agente 1: Padecimientos Crónicos, Medicamento y Resurtimiento Preventivo
    bool tienePadecimientosCronicos = clienteExistente?['tiene_padecimientos_cronicos'] ?? false;
    final List<String> medicamentosList = [];
    if (clienteExistente?['medicamento_cronico_principal'] != null) {
      final raw = clienteExistente!['medicamento_cronico_principal'].toString();
      for (var item in raw.split(',')) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && !medicamentosList.contains(trimmed)) {
          medicamentosList.add(trimmed);
        }
      }
    }
    final buscarMedCtrl = TextEditingController();
    List<dynamic> sugerenciasInventario = [];

    int diasTratamiento = clienteExistente?['dias_tratamiento'] ?? 30;
    final diasTratamientoCtrl = TextEditingController(text: diasTratamiento.toString());
    int semanasAnticipacion = 3; // 1, 2, 3 o 4 semanas

    DateTime? fechaProximoResurtimiento;
    if (clienteExistente?['fecha_proximo_resurtimiento'] != null) {
      fechaProximoResurtimiento = DateTime.tryParse(clienteExistente!['fecha_proximo_resurtimiento'].toString());
    } else if (clienteExistente?['ultima_visita'] != null) {
      final uVisita = DateTime.tryParse(clienteExistente!['ultima_visita'].toString());
      fechaProximoResurtimiento = uVisita?.add(Duration(days: diasTratamiento));
    } else {
      fechaProximoResurtimiento = DateTime.now().add(Duration(days: diasTratamiento));
    }

    final String? ultimaVisitaStr = clienteExistente?['ultima_visita'] != null
        ? clienteExistente!['ultima_visita'].toString().replaceFirst('T', ' ').substring(0, 16)
        : null;

    // Sub-Agente 3 & 4: Sexo y Fecha de Nacimiento desglosada
    String? sexoSeleccionado = clienteExistente?['sexo'];
    DateTime? fechaNacParsed;
    if (clienteExistente?['fecha_nacimiento'] != null) {
      fechaNacParsed = DateTime.tryParse(clienteExistente!['fecha_nacimiento'].toString());
    }
    final diaCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.day.toString().padLeft(2, '0') : '');
    final mesCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.month.toString().padLeft(2, '0') : '');
    final anioCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.year.toString() : '');

    // Diagnósticos CIE-11 seleccionados
    final Set<int> enfSeleccionadas = {};
    if (clienteExistente != null && clienteExistente['enfermedades'] != null) {
      for (var enf in clienteExistente['enfermedades']) {
        enfSeleccionadas.add(enf['id'] as int);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final ts = ThemeService.instance;
            return AlertDialog(
              backgroundColor: ts.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
              ),
              title: Row(
                children: [
                  Icon(
                    esEdicion ? Icons.edit : Icons.person_add_alt_1,
                    color: ts.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    esEdicion ? 'Editar Cliente' : 'Registrar Nuevo Cliente',
                    style: TextStyle(color: ts.textPrimary),
                  ),
                ],
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ts.tintBg(ts.neonBlue),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ts.neonBlue.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: ts.neonBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nombre y al menos un Apellido son obligatorios. El Apellido Materno es opcional para personas con un solo apellido o extranjeros.',
                                style: TextStyle(fontSize: 11, color: ts.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Nombre(s)
                      TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre(s) *',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sub-Agente 5: Apellido Paterno y Materno
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: apellidoPaternoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Apellido Paterno *',
                                hintText: 'Primer apellido',
                                prefixIcon: Icon(Icons.badge),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: apellidoMaternoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Apellido Materno',
                                hintText: 'Opcional (segundo apellido)',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: telefonoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono de contacto',
                                prefixIcon: Icon(Icons.phone),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: correoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: direccionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de domicilio',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: descuentoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: '% Descuento Lealtad',
                                suffixText: '%',
                                prefixIcon: Icon(Icons.percent),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sub-Agente 4: Sexo / Género en fila completa con isExpanded y TextOverflow.ellipsis
                      DropdownButtonFormField<String>(
                        initialValue: sexoSeleccionado,
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
                        onChanged: (val) => setDialogState(() => sexoSeleccionado = val),
                      ),
                      const SizedBox(height: 12),
                      // Sub-Agente 3 & 4: Fecha de Nacimiento en bloque independiente sin colisión
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cake, size: 16, color: ts.accentPrimary),
                                  const SizedBox(width: 6),
                                  Text('Fecha de Nacimiento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.textPrimary)),
                                ],
                              ),
                              TextButton.icon(
                                icon: Icon(Icons.calendar_month, color: ts.accentPrimary, size: 16),
                                label: Text('Calendario', style: TextStyle(fontSize: 11, color: ts.accentPrimary)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: fechaNacParsed ?? DateTime(1990, 1, 1),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      fechaNacParsed = picked;
                                      diaCtrl.text = picked.day.toString().padLeft(2, '0');
                                      mesCtrl.text = picked.month.toString().padLeft(2, '0');
                                      anioCtrl.text = picked.year.toString();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: diaCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Día', hintText: 'DD', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: mesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Mes', hintText: 'MM', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                      const SizedBox(height: 16),
                      Text(
                        'Historial Clínico - Diagnósticos CIE-11 Vinculados:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      if (_enfermedadesDisponibles.isEmpty)
                        Text(
                          'No hay enfermedades registradas en el catálogo local. Puede darlas de alta desde el módulo CIE-11.',
                          style: TextStyle(fontSize: 12, color: ts.textSecondary),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ts.surfaceBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ts.borderColor),
                          ),
                          constraints: const Duration(milliseconds: 300) == Duration.zero
                              ? null
                              : const BoxConstraints(maxHeight: 140),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _enfermedadesDisponibles.map((enf) {
                                final id = enf['id'] as int;
                                final seleccionada = enfSeleccionadas.contains(id);
                                return FilterChip(
                                  label: Text('${enf['codigo_cie']} - ${enf['descripcion']}'),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                                    color: seleccionada
                                        ? (ts.esTemaNeon ? Colors.black : ts.accentPrimary)
                                        : ts.textPrimary,
                                  ),
                                  selected: seleccionada,
                                  selectedColor: ts.esTemaNeon
                                      ? ts.accentPrimary
                                      : ts.tintBg(ts.accentPrimary, lightAlpha: 0.2, darkAlpha: 0.3),
                                  checkmarkColor: ts.esTemaNeon ? Colors.black : ts.accentPrimary,
                                  backgroundColor: ts.surfaceAltBg,
                                  side: BorderSide(
                                    color: seleccionada ? ts.accentPrimary : ts.borderColor,
                                  ),
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      if (selected) {
                                        enfSeleccionadas.add(id);
                                      } else {
                                        enfSeleccionadas.remove(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notasCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas Clínicas / Alergias / Observaciones Médicas',
                          hintText: 'Ej. Alergia a Penicilinas, requiere monitoreo de glucosa...',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sub-Agente 1: Padecimientos Crónicos, Inventario y Resurtimiento Preventivo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tienePadecimientosCronicos
                              ? ts.tintBg(ts.neonAmber, lightAlpha: 0.12, darkAlpha: 0.2)
                              : ts.surfaceBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tienePadecimientosCronicos
                                ? ts.neonAmber.withValues(alpha: 0.45)
                                : ts.borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Paciente con Padecimiento Crónico',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                              ),
                              subtitle: Text(
                                'Activa recordatorios inteligentes con semanas de anticipación y vincula medicamentos de nuestro inventario.',
                                style: TextStyle(fontSize: 11, color: ts.textSecondary),
                              ),
                              value: tienePadecimientosCronicos,
                              activeThumbColor: ts.neonAmber,
                              onChanged: (val) => setDialogState(() => tienePadecimientosCronicos = val),
                            ),
                            if (tienePadecimientosCronicos) ...[
                              Divider(color: ts.borderColor),
                              // 1. Buscador conectado al Inventario con Escáner de Cámara
                              Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 16, color: ts.accentPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Buscar Medicamentos en Inventario:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ts.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: buscarMedCtrl,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          final q = val.trim().toLowerCase();
                                          if (q.length >= 2) {
                                            sugerenciasInventario = _productosInventario.where((p) {
                                              final nom = (p['nombre_comercial'] ?? '').toString().toLowerCase();
                                              final sust = (p['sustancia_activa'] ?? '').toString().toLowerCase();
                                              final cod = (p['codigo_barras'] ?? '').toString().toLowerCase();
                                              return nom.contains(q) || sust.contains(q) || cod.contains(q);
                                            }).take(5).toList();
                                          } else {
                                            sugerenciasInventario = [];
                                          }
                                        });
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Buscar medicamento o fórmula...',
                                        hintText: 'Ej. Losartán, Metformina, Insulina, 750100...',
                                        prefixIcon: Icon(Icons.search, size: 20, color: ts.textSecondary),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.qr_code_scanner, color: ts.accentPrimary),
                                              tooltip: 'Escanear código de barras con la cámara',
                                              onPressed: () async {
                                                final cod = await LectorCodigoBarrasDialog.escanear(
                                                  context,
                                                  titulo: 'Escanear Medicamento para Resurtimiento',
                                                );
                                                if (cod != null && cod.trim().isNotEmpty) {
                                                  final q = cod.trim().toLowerCase();
                                                  final match = _productosInventario.firstWhere(
                                                    (p) => (p['codigo_barras'] ?? '').toString().toLowerCase() == q,
                                                    orElse: () => null,
                                                  );
                                                  setDialogState(() {
                                                    if (match != null) {
                                                      final nom = (match['nombre_comercial'] ?? '').toString().trim();
                                                      final pres = (match['presentacion'] ?? '').toString().trim();
                                                      final medItem = pres.isNotEmpty ? '$nom ($pres)' : nom;
                                                      if (!medicamentosList.contains(medItem)) {
                                                        medicamentosList.add(medItem);
                                                      }
                                                      buscarMedCtrl.clear();
                                                      sugerenciasInventario = [];
                                                    } else {
                                                      buscarMedCtrl.text = cod.trim();
                                                      sugerenciasInventario = _productosInventario.where((p) {
                                                        final c = (p['codigo_barras'] ?? '').toString().toLowerCase();
                                                        return c.contains(q);
                                                      }).take(5).toList();
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.add_circle, color: ts.accentPrimary),
                                              tooltip: 'Agregar medicamento ingresado',
                                              onPressed: () {
                                                final txt = buscarMedCtrl.text.trim();
                                                if (txt.isNotEmpty) {
                                                  setDialogState(() {
                                                    if (!medicamentosList.contains(txt)) {
                                                      medicamentosList.add(txt);
                                                    }
                                                    buscarMedCtrl.clear();
                                                    sugerenciasInventario = [];
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (sugerenciasInventario.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: ts.cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: ts.borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: ts.esOscuro ? 0.3 : 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: sugerenciasInventario.length,
                                    separatorBuilder: (_, _) => Divider(height: 1, color: ts.borderColor),
                                    itemBuilder: (ctx, i) {
                                      final p = sugerenciasInventario[i];
                                      final stock = (p['stock_total'] ?? 0) as int;
                                      final nom = (p['nombre_comercial'] ?? '').toString().trim();
                                      final pres = (p['presentacion'] ?? '').toString().trim();
                                      final sust = (p['sustancia_activa'] ?? '').toString().trim();
                                      final lab = (p['laboratorio'] ?? '').toString().trim();
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(Icons.medication, color: ts.accentPrimary, size: 20),
                                        title: Text(nom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ts.textPrimary)),
                                        subtitle: Text('$sust • $pres${lab.isNotEmpty ? " ($lab)" : ""}', style: TextStyle(fontSize: 10, color: ts.textSecondary)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: stock > 0 ? ts.tintBg(ts.neonGreen) : ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: stock > 0
                                                      ? ts.neonGreen.withValues(alpha: 0.4)
                                                      : ts.neonRed.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                'Stock: $stock',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: stock > 0 ? ts.neonGreen : ts.neonRed,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.add_circle_outline, color: ts.accentPrimary, size: 18),
                                          ],
                                        ),
                                        onTap: () {
                                          setDialogState(() {
                                            final medItem = pres.isNotEmpty ? '$nom ($pres)' : nom;
                                            if (!medicamentosList.contains(medItem)) {
                                              medicamentosList.add(medItem);
                                            }
                                            buscarMedCtrl.clear();
                                            sugerenciasInventario = [];
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Lista de Medicamentos Crónicos Agregados
                              Text(
                                'Lista de Medicamentos que Requieren Resurtimiento:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              if (medicamentosList.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: ts.tintBg(ts.neonAmber),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ts.neonAmber.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: ts.neonAmber),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'No hay medicamentos asignados todavía. Busque en inventario arriba o use la cámara.',
                                          style: TextStyle(fontSize: 11, color: ts.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: medicamentosList.map((m) {
                                    return Chip(
                                      avatar: Icon(Icons.medication, size: 14, color: ts.esTemaNeon ? Colors.black : Colors.white),
                                      backgroundColor: ts.accentPrimary,
                                      label: Text(
                                        m,
                                        style: TextStyle(
                                          color: ts.esTemaNeon ? Colors.black : Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      deleteIcon: Icon(Icons.close, color: ts.esTemaNeon ? Colors.black : Colors.white, size: 14),
                                      onDeleted: () {
                                        setDialogState(() {
                                          medicamentosList.remove(m);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 12),
                              // 2. Duración del Suministro / Tratamiento
                              Text(
                                'Duración del Suministro / Tratamiento (Días):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [15, 30, 60, 90].map((diasPreset) {
                                  final int currDias = int.tryParse(diasTratamientoCtrl.text.trim()) ?? 30;
                                  final bool sel = currDias == diasPreset;
                                  return ChoiceChip(
                                    label: Text(
                                      diasPreset == 30 ? '30 días (1 mes)' : (diasPreset == 60 ? '60 días (2 m)' : (diasPreset == 90 ? '90 días (3 m)' : '$diasPreset días')),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                        color: sel ? (ts.esTemaNeon ? Colors.black : ts.accentPrimary) : ts.textSecondary,
                                      ),
                                    ),
                                    selected: sel,
                                    selectedColor: ts.esTemaNeon
                                        ? ts.accentPrimary
                                        : ts.tintBg(ts.accentPrimary, lightAlpha: 0.2, darkAlpha: 0.3),
                                    backgroundColor: ts.surfaceAltBg,
                                    side: BorderSide(color: sel ? ts.accentPrimary : ts.borderColor),
                                    onSelected: (val) {
                                      if (val) {
                                        setDialogState(() {
                                          diasTratamientoCtrl.text = diasPreset.toString();
                                          final base = clienteExistente?['ultima_visita'] != null
                                              ? (DateTime.tryParse(clienteExistente!['ultima_visita'].toString()) ?? DateTime.now())
                                              : DateTime.now();
                                          fechaProximoResurtimiento = base.add(Duration(days: diasPreset));
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: diasTratamientoCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        final d = int.tryParse(val.trim());
                                        if (d != null && d > 0) {
                                          setDialogState(() {
                                            final base = clienteExistente?['ultima_visita'] != null
                                                ? (DateTime.tryParse(clienteExistente!['ultima_visita'].toString()) ?? DateTime.now())
                                                : DateTime.now();
                                            fechaProximoResurtimiento = base.add(Duration(days: d));
                                          });
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Días de Tratamiento Personalizados',
                                        hintText: '30',
                                        suffixText: 'días',
                                        prefixIcon: Icon(Icons.timelapse, size: 18),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: ts.surfaceBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ts.borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Última Visita:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textSecondary)),
                                        Text(
                                          ultimaVisitaStr ?? 'Sin compras previas',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 3. Anticipación de Alerta (Semanas de Anticipación)
                              Text(
                                'Anticipación para Alerta al Cajero y Recordatorio al Paciente:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [1, 2, 3, 4].map((sem) {
                                  final bool sel = semanasAnticipacion == sem;
                                  return ChoiceChip(
                                    label: Text(
                                      sem == 1 ? '1 semana (7d antes)' : (sem == 3 ? '3 semanas (21d - Recomendado)' : '$sem semanas (${sem * 7}d antes)'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                        color: sel ? (ts.esTemaNeon ? Colors.black : ts.neonAmber) : ts.textSecondary,
                                      ),
                                    ),
                                    selected: sel,
                                    selectedColor: ts.esTemaNeon
                                        ? ts.neonAmber
                                        : ts.tintBg(ts.neonAmber, lightAlpha: 0.2, darkAlpha: 0.3),
                                    backgroundColor: ts.surfaceAltBg,
                                    side: BorderSide(color: sel ? ts.neonAmber : ts.borderColor),
                                    onSelected: (val) {
                                      if (val) {
                                        setDialogState(() {
                                          semanasAnticipacion = sem;
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              // 4. Fecha Meta de Próximo Resurtimiento y Resumen
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ts.surfaceBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ts.borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event, color: ts.accentPrimary, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Fecha Meta de Resurtimiento:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textSecondary)),
                                                Text(
                                                  fechaProximoResurtimiento != null
                                                      ? '${fechaProximoResurtimiento!.day.toString().padLeft(2, '0')}/${fechaProximoResurtimiento!.month.toString().padLeft(2, '0')}/${fechaProximoResurtimiento!.year}'
                                                      : 'Sin fecha asignada',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            icon: Icon(Icons.edit_calendar, size: 16, color: ts.accentPrimary),
                                            label: Text('Cambiar', style: TextStyle(fontSize: 11, color: ts.accentPrimary)),
                                            onPressed: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: fechaProximoResurtimiento ?? DateTime.now().add(const Duration(days: 30)),
                                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                                lastDate: DateTime.now().add(const Duration(days: 730)),
                                              );
                                              if (picked != null) {
                                                setDialogState(() {
                                                  fechaProximoResurtimiento = picked;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Dynamic summary preview
                              Builder(
                                builder: (ctx) {
                                  if (fechaProximoResurtimiento == null) return const SizedBox.shrink();
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final target = DateTime(fechaProximoResurtimiento!.year, fechaProximoResurtimiento!.month, fechaProximoResurtimiento!.day);
                                  final diasRestantes = target.difference(today).inDays;
                                  final fechaAlerta = target.subtract(Duration(days: semanasAnticipacion * 7));
                                  final bool alertaActiva = today.isAfter(fechaAlerta) || today.isAtSameMomentAs(fechaAlerta);
                                  final bool isVencido = diasRestantes < 0;
                                  final statusColor = isVencido
                                      ? ts.neonRed
                                      : (alertaActiva ? ts.neonAmber : ts.neonGreen);

                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: ts.tintBg(statusColor, lightAlpha: 0.12, darkAlpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: statusColor.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isVencido
                                              ? Icons.error
                                              : (alertaActiva ? Icons.notifications_active : Icons.check_circle),
                                          color: statusColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isVencido
                                                ? '🚨 ¡Tratamiento vencido hace ${diasRestantes.abs()} días! Alerta de resurtimiento prioritaria activa en mostrador.'
                                                : (alertaActiva
                                                    ? '🔔 Alerta activa hoy: Restan $diasRestantes días de tratamiento (~${((diasRestantes + 6) ~/ 7)} sem). Se notificará al cajero en el POS.'
                                                    : '🟢 Tratamiento al día: Restan $diasRestantes días. La alerta iniciará el ${fechaAlerta.day.toString().padLeft(2, '0')}/${fechaAlerta.month.toString().padLeft(2, '0')}/${fechaAlerta.year} ($semanasAnticipacion sem antes).'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
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
                  child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(esEdicion ? 'Actualizar' : 'Guardar Cliente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ts.accentPrimary,
                    foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                  ),
                  onPressed: () async {
                    final nom = nombreCtrl.text.trim();
                    final pat = apellidoPaternoCtrl.text.trim();
                    final mat = apellidoMaternoCtrl.text.trim();
                    if (nom.isEmpty || (pat.isEmpty && mat.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El Nombre y al menos un Apellido son obligatorios.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final apCompleto = "$pat $mat".trim();
                    final double desc = double.tryParse(descuentoCtrl.text.trim()) ?? 5.0;

                    String? fechaNacStr;
                    final d = int.tryParse(diaCtrl.text.trim());
                    final m = int.tryParse(mesCtrl.text.trim());
                    final a = int.tryParse(anioCtrl.text.trim());
                    if (d != null && m != null && a != null && d >= 1 && d <= 31 && m >= 1 && m <= 12 && a >= 1900 && a <= DateTime.now().year) {
                      fechaNacStr = "${a.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
                    }

                    final String? medFinal = tienePadecimientosCronicos && medicamentosList.isNotEmpty
                        ? medicamentosList.join(', ')
                        : (tienePadecimientosCronicos && buscarMedCtrl.text.trim().isNotEmpty
                            ? buscarMedCtrl.text.trim()
                            : null);

                    final int diasSuministro = tienePadecimientosCronicos
                        ? (int.tryParse(diasTratamientoCtrl.text.trim()) ?? 30)
                        : 30;

                    final String? fechaMetaStr = tienePadecimientosCronicos && fechaProximoResurtimiento != null
                        ? "${fechaProximoResurtimiento!.year.toString().padLeft(4, '0')}-${fechaProximoResurtimiento!.month.toString().padLeft(2, '0')}-${fechaProximoResurtimiento!.day.toString().padLeft(2, '0')}"
                        : null;

                    final Map<String, dynamic> payload = {
                      'nombre': nom,
                      'apellido': apCompleto,
                      'apellido_paterno': pat.isNotEmpty ? pat : null,
                      'apellido_materno': mat.isNotEmpty ? mat : null,
                      'telefono': telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
                      'correo_electronico': correoCtrl.text.trim().isEmpty ? null : correoCtrl.text.trim(),
                      'direccion': direccionCtrl.text.trim().isEmpty ? null : direccionCtrl.text.trim(),
                      'descuento_porcentaje': desc,
                      'fecha_nacimiento': fechaNacStr,
                      'sexo': sexoSeleccionado,
                      'notas_clinicas': notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
                      'tiene_padecimientos_cronicos': tienePadecimientosCronicos,
                      'medicamento_cronico_principal': medFinal,
                      'dias_tratamiento': diasSuministro,
                      'fecha_proximo_resurtimiento': fechaMetaStr,
                      'enfermedades_ids': enfSeleccionadas.toList(),
                    };

                    try {
                      if (esEdicion) {
                        await ApiService.updateCliente(clienteExistente['id'], payload);
                      } else {
                        await ApiService.createCliente(payload);
                      }
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      _cargarDatos();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              esEdicion
                                  ? 'Cliente "$nom $apCompleto" actualizado.'
                                  : 'Cliente "$nom $apCompleto" dado de alta con éxito.',
                            ),
                            backgroundColor: ts.accentPrimary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar cliente: $e'),
                            backgroundColor: ts.neonRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _verDetallesCliente(Map<String, dynamic> c) {
    final ts = ThemeService.instance;
    showDialog(
      context: context,
      builder: (ctx) {
        final List enfermedades = c['enfermedades'] ?? [];
        return AlertDialog(
          backgroundColor: ts.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: ts.accentPrimary,
                child: Icon(Icons.person, color: ts.esTemaNeon ? Colors.black : Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['nombre']} ${c['apellido']}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ts.textPrimary),
                    ),
                    Text(
                      'Cliente Lealtad • ${c['descuento_porcentaje']}% Descuento en Compras',
                      style: TextStyle(fontSize: 12, color: ts.accentPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: ts.borderColor),
                  _infoItem(Icons.phone, 'Teléfono', c['telefono'] ?? 'No especificado'),
                  _infoItem(Icons.email, 'Correo', c['correo_electronico'] ?? 'No especificado'),
                  _infoItem(Icons.location_on, 'Dirección', c['direccion'] ?? 'No especificada'),
                  _infoItem(Icons.wc, 'Sexo / Género', c['sexo'] ?? 'No especificado'),
                  _infoItem(Icons.cake, 'Fecha de Nacimiento', c['fecha_nacimiento'] ?? 'No especificada'),
                  const SizedBox(height: 12),
                  // Sub-Agente 1: Seguimiento de Padecimientos Crónicos y Resurtimiento
                  if (c['tiene_padecimientos_cronicos'] == true) ...[
                    Builder(
                      builder: (ctx) {
                        final int? dias = c['dias_para_resurtimiento'] as int?;
                        final bool alerta = c['alerta_resurtimiento_activa'] == true;
                        final bool vencido = dias != null && dias < 0;
                        final String medStr = c['medicamento_cronico_principal'] ?? 'Tratamiento crónico';
                        final medsList = medStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

                        Color headerColor = ts.tintBg(ts.neonGreen);
                        Color statusBorderColor = ts.neonGreen.withValues(alpha: 0.45);
                        Color textColor = ts.neonGreen;
                        IconData icon = Icons.check_circle_outline;
                        String statusTitle = '🟢 Tratamiento al Día';

                        if (vencido) {
                          headerColor = ts.tintBg(ts.neonRed);
                          statusBorderColor = ts.neonRed.withValues(alpha: 0.45);
                          textColor = ts.neonRed;
                          icon = Icons.error_outline;
                          statusTitle = '🚨 Resurtimiento Vencido hace ${dias.abs()} días';
                        } else if (alerta) {
                          headerColor = ts.tintBg(ts.neonAmber);
                          statusBorderColor = ts.neonAmber.withValues(alpha: 0.45);
                          textColor = ts.neonAmber;
                          icon = Icons.alarm_on;
                          statusTitle = '⚠️ Alerta de Resurtimiento Activa (${dias ?? 0} días restantes)';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: headerColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, color: textColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      statusTitle,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Medicamentos Crónicos Prescritos:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.textSecondary)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: medsList.map((m) {
                                  return Chip(
                                    avatar: Icon(Icons.medication, size: 14, color: ts.esTemaNeon ? Colors.black : Colors.white),
                                    backgroundColor: ts.accentPrimary,
                                    label: Text(m, style: TextStyle(color: ts.esTemaNeon ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Suministro: ${c["dias_tratamiento"] ?? 30} días  •  Última Visita: ${c["ultima_visita"] != null ? c["ultima_visita"].toString().replaceFirst("T", " ").substring(0, 16) : "Sin registrar"}',
                                style: TextStyle(fontSize: 11, color: ts.textPrimary),
                              ),
                              if (c['fecha_proximo_resurtimiento'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Fecha Meta de Resurtimiento: ${c["fecha_proximo_resurtimiento"]}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.textPrimary),
                                ),
                              ],
                              if (c['mensaje_alerta_resurtimiento'] != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ts.surfaceBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusBorderColor),
                                  ),
                                  child: Text(
                                    c['mensaje_alerta_resurtimiento'],
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Historial Clínico (Diagnósticos CIE-11):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (enfermedades.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ts.surfaceBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ts.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.health_and_safety_outlined, color: ts.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Text('Sin padecimientos crónicos registrados.', style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: enfermedades.map((enf) {
                        return Chip(
                          avatar: Icon(Icons.medical_services, size: 16, color: ts.accentPrimary),
                          backgroundColor: ts.surfaceAltBg,
                          side: BorderSide(color: ts.borderColor),
                          label: Text(
                            '${enf['codigo_cie']} - ${enf['descripcion']}',
                            style: TextStyle(color: ts.textPrimary, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  if (c['notas_clinicas'] != null && (c['notas_clinicas'] as String).isNotEmpty) ...[
                    Text(
                      'Notas Médicas y Farmacéuticas:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ts.tintBg(ts.neonAmber),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ts.neonAmber.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        c['notas_clinicas'],
                        style: TextStyle(fontSize: 12, color: ts.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ts.accentPrimary),
              onPressed: () {
                Navigator.of(ctx).pop();
                _abrirFormularioCliente(clienteExistente: c);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 4),
                  Text('Editar Cliente'),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    final ts = ThemeService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ts.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: ts.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildClienteKpiCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    required String filtroKey,
    required ThemeService ts,
    double? width,
  }) {
    final bool isSelected = _filtroResurtimiento == filtroKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filtroResurtimiento = isSelected && filtroKey != 'TODOS' ? 'TODOS' : filtroKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width ?? 190,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.24) : ts.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : ts.borderColor,
            width: 1.2,
          ),
          boxShadow: ts.cardGlowShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color : ts.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : ts.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    return Scaffold(
      backgroundColor: ts.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                spacing: 16,
                runSpacing: 12,
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
                          Icons.people_alt,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Padrón de Clientes y Expediente Clínico',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Historial clínico CIE-11, tratamientos crónicos, descuentos de lealtad y alertas de resurtimiento.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _abrirFormularioCliente(),
                    icon: Icon(
                      Icons.person_add,
                      size: 18,
                      color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                    ),
                    label: Text(
                      'Registrar Nuevo Cliente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                      foregroundColor: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tarjetas KPI Bento y Filtros de Pacientes
            LayoutBuilder(
              builder: (context, kConstraints) {
                final double w = kConstraints.maxWidth;
                final double cardWidth = w < 480 ? (w - 12) / 2 : (w < 860 ? (w - 24) / 3 : 190);

                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildClienteKpiCard(
                      titulo: 'Todos los Clientes',
                      valor: '${_clientes.length}',
                      icono: Icons.people_outline,
                      color: ts.accentPrimary,
                      filtroKey: 'TODOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '⚠️ Próx. a Resurtir',
                      valor: '$_countAlertas',
                      icono: Icons.alarm_on,
                      color: ts.neonAmber,
                      filtroKey: 'ALERTAS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '🚨 Resurtido Vencido',
                      valor: '$_countVencidos',
                      icono: Icons.warning_amber_rounded,
                      color: ts.neonRed,
                      filtroKey: 'VENCIDOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '🟢 Tratamiento al Día',
                      valor: '$_countAlDia',
                      icono: Icons.check_circle_outline,
                      color: ts.neonGreen,
                      filtroKey: 'AL_DIA',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '💊 Pacientes Crónicos',
                      valor: '$_countCronicos',
                      icono: Icons.medication_outlined,
                      color: ts.neonBlue,
                      filtroKey: 'CRONICOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Barra de Búsqueda
            Container(
              decoration: BoxDecoration(
                color: ts.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.search, color: ts.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _cargarDatos(),
                        style: TextStyle(color: ts.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, apellido, teléfono o correo electrónico...',
                          hintStyle: TextStyle(color: ts.textSecondary.withValues(alpha: 0.7)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 20, color: ts.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _cargarDatos();
                        },
                      ),
                    FilledButton(
                      onPressed: _cargarDatos,
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.accentPrimary,
                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: ts.neonRed, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyle(color: ts.neonRed)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ts.accentPrimary,
                                  foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                ),
                                onPressed: _cargarDatos,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _clientesFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 48, color: ts.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _clientes.isNotEmpty
                                        ? 'No se encontraron clientes con el filtro "$_filtroResurtimiento".'
                                        : 'No se encontraron clientes registrados con ese criterio.',
                                    style: TextStyle(fontSize: 15, color: ts.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_clientes.isNotEmpty && _filtroResurtimiento != 'TODOS')
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ts.accentPrimary,
                                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                      ),
                                      onPressed: () => setState(() => _filtroResurtimiento = 'TODOS'),
                                      child: const Text('Ver Todos los Clientes'),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ts.accentPrimary,
                                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                      ),
                                      onPressed: () => _abrirFormularioCliente(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Registrar Primer Cliente'),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _clientesFiltrados.length,
                              itemBuilder: (context, index) {
                                final c = _clientesFiltrados[index];
                                final List enfermedades = c['enfermedades'] ?? [];
                                final double descuento = (c['descuento_porcentaje'] ?? 5.0).toDouble();
                                final bool esCronico = c['tiene_padecimientos_cronicos'] == true;
                                final int? dias = c['dias_para_resurtimiento'] as int?;
                                final bool alerta = c['alerta_resurtimiento_activa'] == true;
                                final bool vencido = esCronico && dias != null && dias < 0;

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
                                      radius: 22,
                                      backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.15, darkAlpha: 0.25),
                                      child: Text(
                                        '${c['nombre'][0]}${c['apellido'][0]}'.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ts.accentPrimary,
                                        ),
                                      ),
                                    ),
                                    title: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${c['nombre']} ${c['apellido']}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ts.textPrimary),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ts.tintBg(ts.neonGreen),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            '$descuento% Desc. Lealtad',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: ts.neonGreen,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (esCronico) ...[
                                          if (vencido)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonRed.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning, size: 12, color: ts.neonRed),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '🚨 Vencido hace ${dias.abs()}d',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonRed,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (alerta)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonAmber),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonAmber.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.alarm_on, size: 12, color: ts.neonAmber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '⚠️ Resurtir en ${dias ?? 0}d (~${((dias ?? 0) + 6) ~/ 7} sem)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonAmber,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonGreen),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonGreen.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_outline, size: 12, color: ts.neonGreen),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '🟢 Al día (${dias ?? 0}d)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonGreen,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        // Sub-Agente 4: Wrap responsivo para evitar overflow en tamaños grandes de fuente
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (c['telefono'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.phone, size: 13, color: ts.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(c['telefono'], style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                                                ],
                                              ),
                                            if (c['correo_electronico'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.email, size: 13, color: ts.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(c['correo_electronico'], style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                                                ],
                                              ),
                                            if (c['sexo'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.neonBlue),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.neonBlue.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  c['sexo'] == 'MASCULINO' ? '♂ Masc' : (c['sexo'] == 'FEMENINO' ? '♀ Fem' : '${c['sexo']}'),
                                                  style: TextStyle(fontSize: 10, color: ts.neonBlue, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (c['fecha_nacimiento'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.neonPurple),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.neonPurple.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  '🎂 ${c["fecha_nacimiento"]}',
                                                  style: TextStyle(fontSize: 10, color: ts.neonPurple, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (esCronico && c['medicamento_cronico_principal'] != null) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.accentPrimary),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.accentPrimary.withValues(alpha: 0.35)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.medication, size: 12, color: ts.accentPrimary),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'Rx: ${c["medicamento_cronico_principal"]}',
                                                        style: TextStyle(fontSize: 11, color: ts.accentPrimary, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (c['fecha_proximo_resurtimiento'] != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ts.surfaceBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: ts.borderColor),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.event, size: 12, color: ts.textSecondary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Próx. Resurtido: ${c["fecha_proximo_resurtimiento"]}',
                                                        style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        if (enfermedades.isNotEmpty)
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: enfermedades.map((enf) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.surfaceAltBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: ts.borderColor),
                                                ),
                                                child: Text(
                                                  '${enf['codigo_cie']}: ${enf['descripcion']}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: ts.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        else
                                          Text(
                                            'Sin historial de enfermedades crónicas.',
                                            style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.visibility_outlined, color: ts.accentPrimary),
                                          tooltip: 'Ver Expediente Clínico',
                                          onPressed: () => _verDetallesCliente(c),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: ts.textSecondary),
                                          tooltip: 'Editar Cliente',
                                          onPressed: () => _abrirFormularioCliente(clienteExistente: c),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _verDetallesCliente(c),
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
