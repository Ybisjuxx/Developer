import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../services/api_service.dart';

class RegistrarMedicoScreen extends StatefulWidget {
  final Medico? medicoAEditar;

  const RegistrarMedicoScreen({super.key, this.medicoAEditar});

  @override
  State<RegistrarMedicoScreen> createState() => _RegistrarMedicoScreenState();
}

class _RegistrarMedicoScreenState extends State<RegistrarMedicoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombresController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _especialidadController = TextEditingController();
  final _institucionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _correoController = TextEditingController();

  bool _vigente = true;
  bool _isLoading = false;

  bool get _esEdicion => widget.medicoAEditar != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final m = widget.medicoAEditar!;
      _nombresController.text = m.nombres;
      _apellidoPaternoController.text = m.apellidoPaterno ?? m.apellidos;
      _apellidoMaternoController.text = m.apellidoMaterno ?? '';
      _cedulaController.text = m.cedulaProfesional;
      _especialidadController.text = m.especialidad ?? '';
      _institucionController.text = m.institucionEmisora ?? '';
      _telefonoController.text = m.telefono ?? '';
      _correoController.text = m.correo ?? '';
      _vigente = m.vigente;
    }
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _cedulaController.dispose();
    _especialidadController.dispose();
    _institucionController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _guardarMedico() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final pat = _apellidoPaternoController.text.trim();
    final mat = _apellidoMaternoController.text.trim();
    final consolidado = ('$pat $mat').trim();

    final medico = Medico(
      id: widget.medicoAEditar?.id,
      nombres: _nombresController.text.trim(),
      apellidoPaterno: pat.isNotEmpty ? pat : null,
      apellidoMaterno: mat.isNotEmpty ? mat : null,
      apellidos: consolidado,
      cedulaProfesional: _cedulaController.text.trim(),
      especialidad: _especialidadController.text.trim().isEmpty ? null : _especialidadController.text.trim(),
      institucionEmisora: _institucionController.text.trim().isEmpty ? null : _institucionController.text.trim(),
      telefono: _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
      correo: _correoController.text.trim().isEmpty ? null : _correoController.text.trim(),
      vigente: _vigente,
    );

    try {
      if (_esEdicion) {
        final actualizado = await ApiService.updateMedico(widget.medicoAEditar!.id!, medico);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Médico "${actualizado.nombreCompleto}" actualizado con éxito'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      } else {
        final nuevo = await ApiService.createMedico(medico);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Médico "${nuevo.nombreCompleto}" registrado con éxito'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
          title: Text(_esEdicion ? 'Error al Actualizar' : 'Error de Registro'),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Aceptar'),
            )
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Médico' : 'Registrar Médico'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _esEdicion ? Icons.edit_note : Icons.badge_outlined,
                            color: theme.colorScheme.primary,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _esEdicion
                                ? 'Edición de Datos de Profesional Médico'
                                : 'Alta Sanitaria de Profesional Médico',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingrese los datos correspondientes a la cédula profesional para habilitar la prescripción de medicamentos controlados y antibióticos.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                      const Divider(height: 32),

                      // Nombre(s)
                      TextFormField(
                        controller: _nombresController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre(s) *',
                          hintText: 'ej: Manuel, María Elena',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Ingrese el nombre o nombres'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Sub-Agente 3: Separación en Apellido Paterno y Materno
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _apellidoPaternoController,
                              decoration: const InputDecoration(
                                labelText: 'Apellido Paterno *',
                                hintText: 'ej: de la Cruz, del Toro',
                                helperText: 'Primer apellido o principal',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => (val == null || val.trim().isEmpty)
                                  ? 'Ingrese el apellido paterno'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _apellidoMaternoController,
                              decoration: const InputDecoration(
                                labelText: 'Apellido Materno',
                                hintText: 'ej: Montes, Sánchez',
                                helperText: 'Opcional (extranjeros o 1 apellido)',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cédula Profesional
                      TextFormField(
                        controller: _cedulaController,
                        decoration: const InputDecoration(
                          labelText: 'Cédula Profesional *',
                          prefixIcon: Icon(Icons.card_membership_outlined),
                          helperText: 'Debe ser única y registrada ante la DGP / SEP',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'La cédula profesional es obligatoria';
                          }
                          if (val.trim().length < 4) {
                            return 'Cédula inválida (mínimo 4 caracteres)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Especialidad e Institución
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _especialidadController,
                              decoration: const InputDecoration(
                                labelText: 'Especialidad Médica',
                                prefixIcon: Icon(Icons.medical_services_outlined),
                                hintText: 'Ej. Medicina General, Cardiología',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _institucionController,
                              decoration: const InputDecoration(
                                labelText: 'Institución de Egreso / DGP',
                                prefixIcon: Icon(Icons.school_outlined),
                                hintText: 'Ej. UNAM, IPN, UdeG',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Teléfono y Correo
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _telefonoController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono de Contacto',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _correoController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo Electrónico',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Switch Cédula Vigente
                      SwitchListTile(
                        value: _vigente,
                        onChanged: (val) => setState(() => _vigente = val),
                        title: const Text('Cédula Vigente y Activa'),
                        subtitle: const Text('Habilita al médico para autorizar surtido de recetas en POS'),
                        secondary: Icon(
                          _vigente ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: _vigente ? Colors.teal : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            onPressed: _isLoading ? null : _guardarMedico,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(_esEdicion ? Icons.save : Icons.save_outlined),
                            label: Text(_isLoading
                                ? 'Guardando...'
                                : (_esEdicion ? 'Actualizar Médico' : 'Registrar Médico')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
