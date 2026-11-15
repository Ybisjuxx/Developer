import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
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
    final ts = ThemeService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ts.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ts.neonAmber),
            const SizedBox(width: 8),
            Text('Baja o Eliminación de Médico', style: TextStyle(color: ts.textPrimary)),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué acción desea realizar con el Dr(a). ${m.nombreCompleto} (Cédula: ${m.cedulaProfesional})?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ts.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ts.tintBg(ts.neonAmber),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ts.neonAmber.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• "Dar de Baja": Desactiva su vigencia sanitaria. Permite conservar la trazabilidad de recetas y ventas históricas conforme a la regulación de COFEPRIS.',
                      style: TextStyle(fontSize: 12, color: ts.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• "Eliminar Permanente": Borra definitivamente el registro de la base de datos (únicamente si no tiene recetas ni tickets vinculados).',
                      style: TextStyle(fontSize: 12, color: ts.textPrimary),
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
            child: Text('Cancelar', style: TextStyle(color: ts.textSecondary)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Dar de Baja'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ts.neonAmber,
              side: BorderSide(color: ts.neonAmber.withValues(alpha: 0.5)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _eliminarMedicoApi(m, permanente: false);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Eliminar Permanente'),
            style: FilledButton.styleFrom(backgroundColor: ts.neonRed, foregroundColor: Colors.white),
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
    final ts = ThemeService.instance;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.deleteMedico(m.id!, permanente: permanente);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje'] ?? 'Operación realizada con éxito'),
            backgroundColor: ts.accentPrimary,
          ),
        );
        _cargarMedicos();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    return Scaffold(
      backgroundColor: ts.scaffoldBg,
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
                      prefixIcon: Icon(Icons.search, color: ts.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: ts.textSecondary),
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
                    backgroundColor: ts.accentPrimary,
                    foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
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
                              Icon(Icons.cloud_off, size: 48, color: ts.neonAmber),
                              const SizedBox(height: 12),
                              Text(
                                'No se pudo conectar con el backend:\n$_error',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ts.textPrimary),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ts.accentPrimary,
                                  foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                ),
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
                                  Icon(Icons.person_search_outlined, size: 64, color: ts.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No se encontraron médicos registrados',
                                    style: TextStyle(color: ts.textSecondary),
                                  ),
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
                                    elevation: ts.esTemaNeon ? 0 : 1.5,
                                    color: ts.cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: ts.borderColor),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: m.vigente
                                              ? ts.tintBg(ts.accentPrimary, lightAlpha: 0.15, darkAlpha: 0.25)
                                              : ts.surfaceAltBg,
                                          foregroundColor: m.vigente ? ts.accentPrimary : ts.textSecondary,
                                          child: Text(
                                            m.nombres.isNotEmpty ? m.nombres[0] : 'M',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          'Dr(a). ${m.nombreCompleto}',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              'Cédula: ${m.cedulaProfesional}  •  ${m.especialidad ?? "Medicina General"}',
                                              style: TextStyle(color: ts.textSecondary),
                                            ),
                                            if (m.institucionEmisora != null)
                                              Text(
                                                'Institución: ${m.institucionEmisora}',
                                                style: TextStyle(color: ts.textSecondary, fontSize: 12),
                                              ),
                                            if (m.telefono != null || m.correo != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  'Contacto: ${m.telefono ?? ""} ${m.correo != null ? "• ${m.correo}" : ""}'.trim(),
                                                  style: TextStyle(color: ts.accentPrimary, fontSize: 11),
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
                                                color: m.vigente ? ts.neonGreen : ts.neonRed,
                                              ),
                                              label: Text(
                                                m.vigente ? 'Vigente' : 'Inactivo',
                                                style: TextStyle(
                                                  color: m.vigente ? ts.neonGreen : ts.neonRed,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: m.vigente
                                                  ? ts.tintBg(ts.neonGreen)
                                                  : ts.tintBg(ts.neonRed),
                                              side: BorderSide(
                                                color: m.vigente
                                                    ? ts.neonGreen.withValues(alpha: 0.4)
                                                    : ts.neonRed.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            // Sub-Agente 4: Botón Editar
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20),
                                              color: ts.accentPrimary,
                                              tooltip: 'Editar Datos de Médico',
                                              onPressed: () => _editarMedico(m),
                                            ),
                                            // Sub-Agente 4: Botón Borrar / Dar de baja
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              color: ts.neonRed,
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
