import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/lector_codigo_barras_dialog.dart';

void showClienteFormDialog({
  required BuildContext context,
  Map<String, dynamic>? clienteExistente,
  required List<dynamic> enfermedadesDisponibles,
  required List<dynamic> productosInventario,
  required VoidCallback onSaved,
}) {
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ClienteFormDialog(
      clienteExistente: clienteExistente,
      enfermedadesDisponibles: enfermedadesDisponibles,
      productosInventario: productosInventario,
      onSaved: onSaved,
      messenger: messenger,
    ),
  );
}

class _ClienteFormDialog extends StatefulWidget {
  final Map<String, dynamic>? clienteExistente;
  final List<dynamic> enfermedadesDisponibles;
  final List<dynamic> productosInventario;
  final VoidCallback onSaved;
  final ScaffoldMessengerState messenger;

  const _ClienteFormDialog({
    required this.clienteExistente,
    required this.enfermedadesDisponibles,
    required this.productosInventario,
    required this.onSaved,
    required this.messenger,
  });

  @override
  State<_ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<_ClienteFormDialog> {
  late final bool _esEdicion;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoPaternoCtrl;
  late final TextEditingController _apellidoMaternoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _correoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _descuentoCtrl;
  late final TextEditingController _notasCtrl;

  late bool _tienePadecimientosCronicos;
  final List<String> _medicamentosList = [];
  final TextEditingController _buscarMedCtrl = TextEditingController();
  List<dynamic> _sugerenciasInventario = [];

  late int _diasTratamiento;
  late final TextEditingController _diasTratamientoCtrl;
  int _semanasAnticipacion = 3; // 1, 2, 3 o 4 semanas
  DateTime? _fechaProximoResurtimiento;
  String? _ultimaVisitaStr;

  String? _sexoSeleccionado;
  DateTime? _fechaNacParsed;
  late final TextEditingController _diaCtrl;
  late final TextEditingController _mesCtrl;
  late final TextEditingController _anioCtrl;

  final Set<int> _enfSeleccionadas = {};

  @override
  void initState() {
    super.initState();
    final c = widget.clienteExistente;
    _esEdicion = c != null;
    _nombreCtrl = TextEditingController(text: c?['nombre'] ?? '');

    // Sub-Agente 5: Separación de Apellido Paterno y Materno (opcional si es uno solo o compuesto)
    String initPaterno = c?['apellido_paterno'] ?? '';
    String initMaterno = c?['apellido_materno'] ?? '';
    if (initPaterno.isEmpty && initMaterno.isEmpty && c?['apellido'] != null) {
      final partes = c!['apellido'].toString().trim().split(' ');
      if (partes.length >= 2) {
        initPaterno = partes[0];
        initMaterno = partes.sublist(1).join(' ');
      } else {
        initPaterno = partes.isNotEmpty ? partes[0] : '';
      }
    }
    _apellidoPaternoCtrl = TextEditingController(text: initPaterno);
    _apellidoMaternoCtrl = TextEditingController(text: initMaterno);

    _telefonoCtrl = TextEditingController(text: c?['telefono'] ?? '');
    _correoCtrl = TextEditingController(text: c?['correo_electronico'] ?? '');
    _direccionCtrl = TextEditingController(text: c?['direccion'] ?? '');
    _descuentoCtrl = TextEditingController(text: (c?['descuento_porcentaje'] ?? 5.0).toString());
    _notasCtrl = TextEditingController(text: c?['notas_clinicas'] ?? '');

    // Sub-Agente 1: Padecimientos Crónicos, Medicamento y Resurtimiento Preventivo
    _tienePadecimientosCronicos = c?['tiene_padecimientos_cronicos'] ?? false;
    if (c?['medicamento_cronico_principal'] != null) {
      final raw = c!['medicamento_cronico_principal'].toString();
      for (var item in raw.split(',')) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && !_medicamentosList.contains(trimmed)) {
          _medicamentosList.add(trimmed);
        }
      }
    }

    _diasTratamiento = c?['dias_tratamiento'] ?? 30;
    _diasTratamientoCtrl = TextEditingController(text: _diasTratamiento.toString());

    if (c?['fecha_proximo_resurtimiento'] != null) {
      _fechaProximoResurtimiento = DateTime.tryParse(c!['fecha_proximo_resurtimiento'].toString());
    } else if (c?['ultima_visita'] != null) {
      final uVisita = DateTime.tryParse(c!['ultima_visita'].toString());
      _fechaProximoResurtimiento = uVisita?.add(Duration(days: _diasTratamiento));
    } else {
      _fechaProximoResurtimiento = DateTime.now().add(Duration(days: _diasTratamiento));
    }

    _ultimaVisitaStr = c?['ultima_visita'] != null
        ? c!['ultima_visita'].toString().replaceFirst('T', ' ').substring(0, 16)
        : null;

    // Sub-Agente 3 & 4: Sexo y Fecha de Nacimiento desglosada
    _sexoSeleccionado = c?['sexo'];
    if (c?['fecha_nacimiento'] != null) {
      _fechaNacParsed = DateTime.tryParse(c!['fecha_nacimiento'].toString());
    }
    _diaCtrl = TextEditingController(text: _fechaNacParsed != null ? _fechaNacParsed!.day.toString().padLeft(2, '0') : '');
    _mesCtrl = TextEditingController(text: _fechaNacParsed != null ? _fechaNacParsed!.month.toString().padLeft(2, '0') : '');
    _anioCtrl = TextEditingController(text: _fechaNacParsed != null ? _fechaNacParsed!.year.toString() : '');

    // Diagnósticos CIE-11 seleccionados
    if (c != null && c['enfermedades'] != null) {
      for (var enf in c['enfermedades']) {
        _enfSeleccionadas.add(enf['id'] as int);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _apellidoPaternoCtrl, _apellidoMaternoCtrl,
      _telefonoCtrl, _correoCtrl, _direccionCtrl, _descuentoCtrl,
      _notasCtrl, _buscarMedCtrl, _diasTratamientoCtrl,
      _diaCtrl, _mesCtrl, _anioCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregarMedicamento(String medItem) {
    if (!_medicamentosList.contains(medItem)) {
      _medicamentosList.add(medItem);
    }
    _buscarMedCtrl.clear();
    _sugerenciasInventario = [];
  }

  void _recalcularFechaResurtimiento(int dias) {
    final rawVisita = widget.clienteExistente?['ultima_visita']?.toString();
    final base = rawVisita != null ? (DateTime.tryParse(rawVisita) ?? DateTime.now()) : DateTime.now();
    _fechaProximoResurtimiento = base.add(Duration(days: dias));
  }

  Widget _datePartField(TextEditingController ctrl, String label, String hint, int flex) {
    return Expanded(
      flex: flex,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
      ),
    );
  }

  Widget _labeledField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    String? suffixText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _guardar(ThemeService ts) async {
    final nom = _nombreCtrl.text.trim();
    final pat = _apellidoPaternoCtrl.text.trim();
    final mat = _apellidoMaternoCtrl.text.trim();
    if (nom.isEmpty || (pat.isEmpty && mat.isEmpty)) {
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('El Nombre y al menos un Apellido son obligatorios.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final apCompleto = "$pat $mat".trim();
    final double desc = double.tryParse(_descuentoCtrl.text.trim()) ?? 5.0;

    String? fechaNacStr;
    final d = int.tryParse(_diaCtrl.text.trim());
    final m = int.tryParse(_mesCtrl.text.trim());
    final a = int.tryParse(_anioCtrl.text.trim());
    if (d != null && m != null && a != null && d >= 1 && d <= 31 && m >= 1 && m <= 12 && a >= 1900 && a <= DateTime.now().year) {
      fechaNacStr = "${a.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
    }

    final String? medFinal = _tienePadecimientosCronicos && _medicamentosList.isNotEmpty
        ? _medicamentosList.join(', ')
        : (_tienePadecimientosCronicos && _buscarMedCtrl.text.trim().isNotEmpty
            ? _buscarMedCtrl.text.trim()
            : null);

    final int diasSuministro = _tienePadecimientosCronicos
        ? (int.tryParse(_diasTratamientoCtrl.text.trim()) ?? 30)
        : 30;

    final String? fechaMetaStr = _tienePadecimientosCronicos && _fechaProximoResurtimiento != null
        ? "${_fechaProximoResurtimiento!.year.toString().padLeft(4, '0')}-${_fechaProximoResurtimiento!.month.toString().padLeft(2, '0')}-${_fechaProximoResurtimiento!.day.toString().padLeft(2, '0')}"
        : null;

    final Map<String, dynamic> payload = {
      'nombre': nom,
      'apellido': apCompleto,
      'apellido_paterno': pat.isNotEmpty ? pat : null,
      'apellido_materno': mat.isNotEmpty ? mat : null,
      'telefono': _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
      'correo_electronico': _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      'descuento_porcentaje': desc,
      'fecha_nacimiento': fechaNacStr,
      'sexo': _sexoSeleccionado,
      'notas_clinicas': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      'tiene_padecimientos_cronicos': _tienePadecimientosCronicos,
      'medicamento_cronico_principal': medFinal,
      'dias_tratamiento': diasSuministro,
      'fecha_proximo_resurtimiento': fechaMetaStr,
      'enfermedades_ids': _enfSeleccionadas.toList(),
    };

    try {
      if (_esEdicion) {
        await ApiService.updateCliente(widget.clienteExistente!['id'], payload);
      } else {
        await ApiService.createCliente(payload);
      }
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Cliente "$nom $apCompleto" actualizado.'
                : 'Cliente "$nom $apCompleto" dado de alta con éxito.',
          ),
          backgroundColor: ts.accentPrimary,
        ),
      );
    } catch (e) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text('Error al guardar cliente: $e'),
          backgroundColor: ts.neonRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _esEdicion ? Icons.edit : Icons.person_add_alt_1,
            color: ts.accentPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            _esEdicion ? 'Editar Cliente' : 'Registrar Nuevo Cliente',
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
              _labeledField(_nombreCtrl, 'Nombre(s) *', Icons.person),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _labeledField(_apellidoPaternoCtrl, 'Apellido Paterno *', Icons.badge, hint: 'Primer apellido'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeledField(_apellidoMaternoCtrl, 'Apellido Materno', Icons.badge_outlined, hint: 'Opcional (segundo apellido)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _labeledField(_telefonoCtrl, 'Teléfono de contacto', Icons.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _labeledField(_correoCtrl, 'Correo electrónico', Icons.email)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: _labeledField(_direccionCtrl, 'Dirección de domicilio', Icons.location_on)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _labeledField(
                      _descuentoCtrl,
                      '% Descuento Lealtad',
                      Icons.percent,
                      suffixText: '%',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sexoSeleccionado,
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
                onChanged: (val) => setState(() => _sexoSeleccionado = val),
              ),
              const SizedBox(height: 12),
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
                            initialDate: _fechaNacParsed ?? DateTime(1990, 1, 1),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _fechaNacParsed = picked;
                              _diaCtrl.text = picked.day.toString().padLeft(2, '0');
                              _mesCtrl.text = picked.month.toString().padLeft(2, '0');
                              _anioCtrl.text = picked.year.toString();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _datePartField(_diaCtrl, 'Día', 'DD', 1),
                      const SizedBox(width: 8),
                      _datePartField(_mesCtrl, 'Mes', 'MM', 1),
                      const SizedBox(width: 8),
                      _datePartField(_anioCtrl, 'Año', 'AAAA', 2),
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
              if (widget.enfermedadesDisponibles.isEmpty)
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
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.enfermedadesDisponibles.map((enf) {
                        final id = enf['id'] as int;
                        final seleccionada = _enfSeleccionadas.contains(id);
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
                            setState(() {
                              if (selected) {
                                _enfSeleccionadas.add(id);
                              } else {
                                _enfSeleccionadas.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _labeledField(
                _notasCtrl,
                'Notas Clínicas / Alergias / Observaciones Médicas',
                Icons.note_alt_outlined,
                hint: 'Ej. Alergia a Penicilinas, requiere monitoreo de glucosa...',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Sub-Agente 1: Padecimientos Crónicos, Inventario y Resurtimiento Preventivo
              _buildSeccionPadecimientosCronicos(ts),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: Text(_esEdicion ? 'Actualizar' : 'Guardar Cliente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ts.accentPrimary,
            foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
          ),
          onPressed: () => _guardar(ts),
        ),
      ],
    );
  }

  Widget _buildSeccionPadecimientosCronicos(ThemeService ts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tienePadecimientosCronicos
            ? ts.tintBg(ts.neonAmber, lightAlpha: 0.12, darkAlpha: 0.2)
            : ts.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _tienePadecimientosCronicos
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
            value: _tienePadecimientosCronicos,
            activeThumbColor: ts.neonAmber,
            onChanged: (val) => setState(() => _tienePadecimientosCronicos = val),
          ),
          if (_tienePadecimientosCronicos) ...[
            Divider(color: ts.borderColor),
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
                    controller: _buscarMedCtrl,
                    onChanged: (val) {
                      setState(() {
                        final q = val.trim().toLowerCase();
                        if (q.length >= 2) {
                          _sugerenciasInventario = widget.productosInventario.where((p) {
                            final nom = (p['nombre_comercial'] ?? '').toString().toLowerCase();
                            final sust = (p['sustancia_activa'] ?? '').toString().toLowerCase();
                            final cod = (p['codigo_barras'] ?? '').toString().toLowerCase();
                            return nom.contains(q) || sust.contains(q) || cod.contains(q);
                          }).take(5).toList();
                        } else {
                          _sugerenciasInventario = [];
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
                                final match = widget.productosInventario.firstWhere(
                                  (p) => (p['codigo_barras'] ?? '').toString().toLowerCase() == q,
                                  orElse: () => null,
                                );
                                setState(() {
                                  if (match != null) {
                                    final nom = (match['nombre_comercial'] ?? '').toString().trim();
                                    final pres = (match['presentacion'] ?? '').toString().trim();
                                    _agregarMedicamento(pres.isNotEmpty ? '$nom ($pres)' : nom);
                                  } else {
                                    _buscarMedCtrl.text = cod.trim();
                                    _sugerenciasInventario = widget.productosInventario.where((p) {
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
                              final txt = _buscarMedCtrl.text.trim();
                              if (txt.isNotEmpty) {
                                setState(() => _agregarMedicamento(txt));
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
            if (_sugerenciasInventario.isNotEmpty) ...[
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
                  itemCount: _sugerenciasInventario.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: ts.borderColor),
                  itemBuilder: (ctx, i) {
                    final p = _sugerenciasInventario[i];
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
                        setState(() {
                          _agregarMedicamento(pres.isNotEmpty ? '$nom ($pres)' : nom);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Lista de Medicamentos que Requieren Resurtimiento:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
            ),
            const SizedBox(height: 4),
            if (_medicamentosList.isEmpty)
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
                children: _medicamentosList.map((m) {
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
                      setState(() {
                        _medicamentosList.remove(m);
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Text(
              'Duración del Suministro / Tratamiento (Días):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [15, 30, 60, 90].map((diasPreset) {
                final int currDias = int.tryParse(_diasTratamientoCtrl.text.trim()) ?? 30;
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
                      setState(() {
                        _diasTratamientoCtrl.text = diasPreset.toString();
                        _recalcularFechaResurtimiento(diasPreset);
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
                    controller: _diasTratamientoCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final d = int.tryParse(val.trim());
                      if (d != null && d > 0) {
                        setState(() => _recalcularFechaResurtimiento(d));
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
                        _ultimaVisitaStr ?? 'Sin compras previas',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Anticipación para Alerta al Cajero y Recordatorio al Paciente:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ts.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [1, 2, 3, 4].map((sem) {
                final bool sel = _semanasAnticipacion == sem;
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
                      setState(() {
                        _semanasAnticipacion = sem;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
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
                          _fechaProximoResurtimiento != null
                              ? '${_fechaProximoResurtimiento!.day.toString().padLeft(2, '0')}/${_fechaProximoResurtimiento!.month.toString().padLeft(2, '0')}/${_fechaProximoResurtimiento!.year}'
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
                        initialDate: _fechaProximoResurtimiento ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setState(() => _fechaProximoResurtimiento = picked);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_fechaProximoResurtimiento != null) _buildResurtimientoPreview(ts),
          ],
        ],
      ),
    );
  }

  Widget _buildResurtimientoPreview(ThemeService ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_fechaProximoResurtimiento!.year, _fechaProximoResurtimiento!.month, _fechaProximoResurtimiento!.day);
    final diasRestantes = target.difference(today).inDays;
    final fechaAlerta = target.subtract(Duration(days: _semanasAnticipacion * 7));
    final bool alertaActiva = today.isAfter(fechaAlerta) || today.isAtSameMomentAs(fechaAlerta);
    final bool isVencido = diasRestantes < 0;
    final statusColor = isVencido ? ts.neonRed : (alertaActiva ? ts.neonAmber : ts.neonGreen);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ts.tintBg(statusColor, lightAlpha: 0.12, darkAlpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            isVencido ? Icons.error : (alertaActiva ? Icons.notifications_active : Icons.check_circle),
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
                      : '🟢 Tratamiento al día: Restan $diasRestantes días. La alerta iniciará el ${fechaAlerta.day.toString().padLeft(2, '0')}/${fechaAlerta.month.toString().padLeft(2, '0')}/${fechaAlerta.year} ($_semanasAnticipacion sem antes).'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
