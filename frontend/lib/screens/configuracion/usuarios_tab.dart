import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class UsuariosTab extends StatelessWidget {
  final ThemeService themeService;
  final List<dynamic> usuarios;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final void Function({Map<String, dynamic>? usuarioExistente}) onOpenFormulario;

  const UsuariosTab({
    super.key,
    required this.themeService,
    required this.usuarios,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onOpenFormulario,
  });

  Color _colorRol(String rol) {
    switch (rol) {
      case 'ADMINISTRADOR':
        return Colors.purple.shade700;
      case 'RESPONSABLE_SANITARIO':
        return Colors.blue.shade700;
      case 'CAJERO':
      default:
        return Colors.teal.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = themeService;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cuentas de Usuarios y Perfiles del Sistema:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary),
            ),
            ElevatedButton.icon(
              onPressed: () => onOpenFormulario(),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Usuario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: ts.neonRed, size: 36),
                          const SizedBox(height: 8),
                          Text(error!, style: TextStyle(color: ts.neonRed)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: onRetry,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final u = usuarios[index];
                        final bool activo = u['activo'] ?? true;
                        final rol = u['rol'] as String;
                        final colorRol = _colorRol(rol);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: ts.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ts.borderColor, width: 1.2),
                            boxShadow: ts.cardGlowShadow,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ts.tintBg(colorRol, lightAlpha: 0.15, darkAlpha: 0.25),
                              child: Icon(Icons.person, color: colorRol),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  u['nombre_completo'],
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ts.tintBg(colorRol, lightAlpha: 0.15, darkAlpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    rol,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorRol,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!activo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ts.tintBg(ts.neonRed, lightAlpha: 0.15, darkAlpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'INACTIVO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: ts.neonRed,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Usuario de acceso: @${u['username']}', style: TextStyle(color: ts.textSecondary)),
                            trailing: IconButton(
                              icon: Icon(Icons.edit_outlined, color: ts.accentPrimary),
                              tooltip: 'Editar Usuario y Rol',
                              onPressed: () => onOpenFormulario(usuarioExistente: u),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
