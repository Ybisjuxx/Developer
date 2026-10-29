import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../services/api_service.dart';
import 'registrar_medico_screen.dart';

class MedicosScreen extends StatefulWidget {
  const MedicosScreen({super.key});

  @override
  State<MedicosScreen> createState() => _MedicosScreenState();
}

class _MedicosScreenState extends State<MedicosScreen> {
  List<Medico> _medicos = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarMedicos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarMedicos({String? query}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.getMedicos(query: query);
      if (mounted) {
        setState(() {
          _medicos = list;
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

  Future<void> _editarMedico(Medico m) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RegistrarMedicoScreen(medicoAEditar: m)),
    );
    if (result == true) {
      _cargarMedicos();
    }
  }

  void _confirmarEliminarMedico(Medico m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
            const SizedBox(width: 8),
            const Text('Baja o Eliminación de Médico'),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué acción desea realizar con el Dr(a). ${m.nombreCompleto} (Cédula: ${m.cedulaProfesional})?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• "Dar de Baja": Desactiva su vigencia sanitaria. Permite conservar la trazabilidad de recetas y ventas históricas conforme a la regulación de COFEPRIS.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• "Eliminar Permanente": Borra definitivamente el registro de la base de datos (únicamente si no tiene recetas ni tickets vinculados).',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Dar de Baja'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade900),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _eliminarMedicoApi(m, permanente: false);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Eliminar Permanente'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _eliminarMedicoApi(m, permanente: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarMedicoApi(Medico m, {required bool permanente}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.deleteMedico(m.id!, permanente: permanente);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje'] ?? 'Operación realizada con éxito'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
        _cargarMedicos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior de búsqueda y botón registrar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar médico por nombre, apellidos, especialidad o cédula...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _cargarMedicos();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (val) => _cargarMedicos(query: val),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const RegistrarMedicoScreen()),
                    );
                    if (result == true) {
                      _cargarMedicos();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Médico'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenido
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                              const SizedBox(height: 12),
                              Text('No se pudo conectar con el backend:\n$_error', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _cargarMedicos,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _medicos.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No se encontraron médicos registrados'),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargarMedicos,
                              child: ListView.separated(
                                itemCount: _medicos.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final m = _medicos[index];
                                  return Card(
                                    elevation: 1.5,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: m.vigente ? Colors.teal.shade100 : Colors.grey.shade300,
                                          foregroundColor: m.vigente ? Colors.teal.shade900 : Colors.grey.shade700,
                                          child: Text(m.nombres.isNotEmpty ? m.nombres[0] : 'M'),
                                        ),
                                        title: Text(
                                          'Dr(a). ${m.nombreCompleto}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text('Cédula: ${m.cedulaProfesional}  •  ${m.especialidad ?? "Medicina General"}'),
                                            if (m.institucionEmisora != null)
                                              Text(
                                                'Institución: ${m.institucionEmisora}',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                            if (m.telefono != null || m.correo != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  'Contacto: ${m.telefono ?? ""} ${m.correo != null ? "• ${m.correo}" : ""}'.trim(),
                                                  style: TextStyle(color: Colors.teal.shade800, fontSize: 11),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            Chip(
                                              avatar: Icon(
                                                m.vigente ? Icons.verified_user : Icons.block,
                                                size: 16,
                                                color: m.vigente ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                              label: Text(
                                                m.vigente ? 'Vigente' : 'Inactivo',
                                                style: TextStyle(
                                                  color: m.vigente ? Colors.green.shade900 : Colors.red.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: m.vigente ? Colors.green.shade50 : Colors.red.shade50,
                                            ),
                                            // Sub-Agente 4: Botón Editar
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20),
                                              color: Colors.indigo.shade700,
                                              tooltip: 'Editar Datos de Médico',
                                              onPressed: () => _editarMedico(m),
                                            ),
                                            // Sub-Agente 4: Botón Borrar / Dar de baja
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              color: Colors.red.shade700,
                                              tooltip: 'Baja o Eliminación',
                                              onPressed: () => _confirmarEliminarMedico(m),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
