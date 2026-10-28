import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<dynamic> _clientes = [];
  List<dynamic> _enfermedadesDisponibles = [];
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

      final results = await Future.wait([clientesFuture, enfFuture]);
      if (mounted) {
        setState(() {
          _clientes = results[0];
          _enfermedadesDisponibles = results[1];
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

    // Sub-Agente 3 & 4: Sexo y Fecha de Nacimiento desglosada
    String? sexoSeleccionado = clienteExistente?['sexo'];
    DateTime? fechaNacParsed;
    if (clienteExistente?['fecha_nacimiento'] != null) {
      fechaNacParsed = DateTime.tryParse(clienteExistente!['fecha_nacimiento'].toString());
    }
    final diaCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.day.toString().padLeft(2, '0') : '');
    final mesCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.month.toString().padLeft(2, '0') : '');
    final anioCtrl = TextEditingController(text: fechaNacParsed != null ? fechaNacParsed.year.toString() : '');

    // Diagnósticos CIE-10 seleccionados
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
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    esEdicion ? Icons.edit : Icons.person_add_alt_1,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(esEdicion ? 'Editar Cliente' : 'Registrar Nuevo Cliente'),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nombre y al menos un Apellido son obligatorios. El Apellido Materno es opcional para personas con un solo apellido o extranjeros.',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
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
                        onChanged: (val) => setDialogState(() => sexoSeleccionado = val),
                      ),
                      const SizedBox(height: 12),
                      // Sub-Agente 3 & 4: Fecha de Nacimiento en bloque independiente sin colisión
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cake, size: 16, color: Colors.teal),
                              const SizedBox(width: 6),
                              const Text('Fecha de Nacimiento (Opcional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.calendar_month, color: Colors.teal, size: 16),
                                label: const Text('Buscar en calendario', style: TextStyle(fontSize: 11)),
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
                      const Text(
                        'Historial Clínico - Diagnósticos CIE-10 Vinculados:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      if (_enfermedadesDisponibles.isEmpty)
                        const Text(
                          'No hay enfermedades registradas en el catálogo local. Puede darlas de alta desde el módulo CIE-10.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
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
                                    color: seleccionada ? Colors.teal.shade900 : Colors.black87,
                                  ),
                                  selected: seleccionada,
                                  selectedColor: Colors.teal.shade100,
                                  checkmarkColor: Colors.teal.shade900,
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(esEdicion ? 'Actualizar' : 'Guardar Cliente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
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

                    final payload = {
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
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar cliente: $e'),
                            backgroundColor: Colors.red,
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
    showDialog(
      context: context,
      builder: (ctx) {
        final List enfermedades = c['enfermedades'] ?? [];
        return AlertDialog(
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['nombre']} ${c['apellido']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Cliente Lealtad • ${c['descuento_porcentaje']}% Descuento en Compras',
                      style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _infoItem(Icons.phone, 'Teléfono', c['telefono'] ?? 'No especificado'),
                  _infoItem(Icons.email, 'Correo', c['correo_electronico'] ?? 'No especificado'),
                  _infoItem(Icons.location_on, 'Dirección', c['direccion'] ?? 'No especificada'),
                  _infoItem(Icons.wc, 'Sexo / Género', c['sexo'] ?? 'No especificado'),
                  _infoItem(Icons.cake, 'Fecha de Nacimiento', c['fecha_nacimiento'] ?? 'No especificada'),
                  const SizedBox(height: 12),
                  const Text(
                    'Historial Clínico (Diagnósticos CIE-10):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (enfermedades.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.health_and_safety_outlined, color: Colors.grey, size: 18),
                          SizedBox(width: 8),
                          Text('Sin padecimientos crónicos registrados.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: enfermedades.map((enf) {
                        return Chip(
                          avatar: const Icon(Icons.medical_services, size: 16, color: Colors.white),
                          backgroundColor: Colors.teal.shade800,
                          label: Text(
                            '${enf['codigo_cie']} - ${enf['descripcion']}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  if (c['notas_clinicas'] != null && (c['notas_clinicas'] as String).isNotEmpty) ...[
                    const Text(
                      'Notas Médicas y Farmacéuticas:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Text(
                        c['notas_clinicas'],
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_alt, color: Theme.of(context).primaryColor, size: 28),
                          const SizedBox(width: 10),
                          const Text(
                            'Padrón de Clientes e Historial Clínico',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Base de datos de clientes frecuentes, descuentos de lealtad y vinculación con catálogo de enfermedades CIE-10.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _abrirFormularioCliente(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Registrar Nuevo Cliente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _cargarDatos(),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre, apellido, teléfono o correo electrónico...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _cargarDatos();
                        },
                      ),
                    ElevatedButton(
                      onPressed: _cargarDatos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _cargarDatos,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _clientes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No se encontraron clientes registrados con ese criterio.',
                                    style: TextStyle(fontSize: 15, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _abrirFormularioCliente(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Registrar Primer Cliente'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _clientes.length,
                              itemBuilder: (context, index) {
                                final c = _clientes[index];
                                final List enfermedades = c['enfermedades'] ?? [];
                                final double descuento = (c['descuento_porcentaje'] ?? 5.0).toDouble();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                      child: Text(
                                        '${c['nombre'][0]}${c['apellido'][0]}'.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Text(
                                            '$descuento% Desc. Lealtad',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
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
                                                  const Icon(Icons.phone, size: 13, color: Colors.blueGrey),
                                                  const SizedBox(width: 4),
                                                  Text(c['telefono'], style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            if (c['correo_electronico'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.email, size: 13, color: Colors.blueGrey),
                                                  const SizedBox(width: 4),
                                                  Text(c['correo_electronico'], style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            if (c['sexo'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blue.shade200),
                                                ),
                                                child: Text(
                                                  c['sexo'] == 'MASCULINO' ? '♂ Masc' : (c['sexo'] == 'FEMENINO' ? '♀ Fem' : '${c['sexo']}'),
                                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (c['fecha_nacimiento'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.purple.shade200),
                                                ),
                                                child: Text(
                                                  '🎂 ${c["fecha_nacimiento"]}',
                                                  style: TextStyle(fontSize: 10, color: Colors.purple.shade900, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (enfermedades.isNotEmpty)
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: enfermedades.map((enf) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.teal.shade200),
                                                ),
                                                child: Text(
                                                  '${enf['codigo_cie']}: ${enf['descripcion']}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.teal.shade900,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        else
                                          const Text(
                                            'Sin historial de enfermedades crónicas.',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, color: Colors.teal),
                                          tooltip: 'Ver Expediente Clínico',
                                          onPressed: () => _verDetallesCliente(c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
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
