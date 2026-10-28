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
      setState(() {
        _medicos = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
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
                      hintText: 'Buscar por nombre, especialidad o cédula...',
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
                                        ],
                                      ),
                                      trailing: Chip(
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
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: m.vigente ? Colors.green.shade50 : Colors.red.shade50,
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
