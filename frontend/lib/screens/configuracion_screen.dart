import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ThemeService _themeService = ThemeService.instance;

  List<dynamic> _usuarios = [];
  bool _isLoadingUsuarios = true;
  String? _errorUsuarios;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoadingUsuarios = true;
      _errorUsuarios = null;
    });

    try {
      final data = await ApiService.getUsuarios(soloActivos: false);
      if (mounted) {
        setState(() {
          _usuarios = data;
          _isLoadingUsuarios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorUsuarios = e.toString().replaceAll('Exception: ', '');
          _isLoadingUsuarios = false;
        });
      }
    }
  }

  void _abrirFormularioUsuario({Map<String, dynamic>? usuarioExistente}) {
    final bool esEdicion = usuarioExistente != null;
    final usernameCtrl = TextEditingController(text: usuarioExistente?['username'] ?? '');
    final nombreCtrl = TextEditingController(text: usuarioExistente?['nombre_completo'] ?? '');
    final passwordCtrl = TextEditingController();
    String rolSeleccionado = usuarioExistente?['rol'] ?? 'CAJERO';
    bool activo = usuarioExistente?['activo'] ?? true;

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
                    esEdicion ? Icons.manage_accounts : Icons.person_add,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(esEdicion ? 'Editar Usuario' : 'Registrar Nuevo Usuario'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!esEdicion)
                        TextField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de Usuario (Login) *',
                            prefixIcon: Icon(Icons.account_circle),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Usuario: ${usuarioExistente['username']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo del Operador *',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: rolSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Rol Operativo y Nivel de Acceso *',
                          prefixIcon: Icon(Icons.security),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CAJERO',
                            child: Text('Cajero (POS, cortes personales)'),
                          ),
                          DropdownMenuItem(
                            value: 'ADMINISTRADOR',
                            child: Text('Administrador (Acceso total, ajustes y bajas)'),
                          ),
                          DropdownMenuItem(
                            value: 'RESPONSABLE_SANITARIO',
                            child: Text('Responsable Sanitario (QFB, controlados y auditoría)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => rolSeleccionado = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: esEdicion
                              ? 'Nueva Contraseña (dejar en blanco para no cambiar)'
                              : 'Contraseña de Acceso *',
                          prefixIcon: const Icon(Icons.lock),
                        ),
                      ),
                      if (esEdicion) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Usuario Activo en el Sistema'),
                          subtitle: Text(
                            activo ? 'Puede iniciar sesión' : 'Acceso revocado temporalmente',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: activo,
                          onChanged: (val) {
                            setDialogState(() => activo = val);
                          },
                        ),
                      ],
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
                  label: Text(esEdicion ? 'Actualizar' : 'Crear Usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final nom = nombreCtrl.text.trim();
                    if (nom.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre completo es requerido.')),
                      );
                      return;
                    }

                    if (!esEdicion) {
                      final uName = usernameCtrl.text.trim();
                      final pass = passwordCtrl.text.trim();
                      if (uName.isEmpty || pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Usuario y contraseña son obligatorios.')),
                        );
                        return;
                      }

                      try {
                        await ApiService.createUsuario({
                          'username': uName,
                          'nombre_completo': nom,
                          'password': pass,
                          'rol': rolSeleccionado,
                          'activo': true,
                        });
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        _cargarUsuarios();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Usuario "$uName" registrado exitosamente.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } else {
                      final updatePayload = <String, dynamic>{
                        'nombre_completo': nom,
                        'rol': rolSeleccionado,
                        'activo': activo,
                      };
                      if (passwordCtrl.text.trim().isNotEmpty) {
                        updatePayload['password'] = passwordCtrl.text.trim();
                      }

                      try {
                        await ApiService.updateUsuario(usuarioExistente['id'], updatePayload);
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        _cargarUsuarios();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Usuario "${usuarioExistente['username']}" actualizado.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Configuración del Sistema',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Personalización visual de la interfaz, escala de tipografía accesible y administración de cuentas de usuario.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.palette_outlined), text: 'Personalización Visual e Interfaz'),
                Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Usuarios y Permisos de Acceso'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabPersonalizacion(),
                  _buildTabUsuarios(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPersonalizacion() {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.color_lens, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Paleta de Colores de la Farmacia',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Selecciona el tema cromático que mejor se adapte a la identidad institucional de tu botica o sucursal:',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ThemeService.coloresDisponibles.map((opc) {
                          final bool seleccionado = _themeService.colorActual.nombre == opc.nombre;
                          return InkWell(
                            onTap: () => _themeService.cambiarColor(opc),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 170,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: seleccionado
                                    ? opc.primaryColor.withValues(alpha: 0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: seleccionado ? opc.primaryColor : Colors.grey.shade300,
                                  width: seleccionado ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: opc.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opc.nombre,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                                        color: seleccionado ? opc.accentColor : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (seleccionado)
                                    Icon(Icons.check_circle, size: 18, color: opc.primaryColor),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_size, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Tamaño de Fuente y Accesibilidad Visual',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajusta la escala tipográfica global para mejorar la legibilidad en pantallas táctiles o mostradores de farmacia:',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: EscalaFuente.values.map((escala) {
                          final bool seleccionada = _themeService.escalaActual == escala;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: OutlinedButton(
                                onPressed: () => _themeService.cambiarEscala(escala),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: seleccionada
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                                      : Colors.white,
                                  side: BorderSide(
                                    color: seleccionada
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade300,
                                    width: seleccionada ? 2 : 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  escala.etiqueta,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                                    color: seleccionada
                                        ? Theme.of(context).primaryColor
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.preview, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vista previa: FarmaControl POS — Paracetamol 500mg Lote #CAD2027 a \$45.00 MXN',
                                style: TextStyle(
                                  fontSize: 13 * _themeService.factorEscala,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabUsuarios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cuentas de Usuarios y Perfiles del Sistema:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            ElevatedButton.icon(
              onPressed: () => _abrirFormularioUsuario(),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Usuario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingUsuarios
              ? const Center(child: CircularProgressIndicator())
              : _errorUsuarios != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 36),
                          const SizedBox(height: 8),
                          Text(_errorUsuarios!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _cargarUsuarios,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _usuarios.length,
                      itemBuilder: (context, index) {
                        final u = _usuarios[index];
                        final bool activo = u['activo'] ?? true;
                        final rol = u['rol'] as String;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _colorRol(rol).withValues(alpha: 0.15),
                              child: Icon(Icons.person, color: _colorRol(rol)),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  u['nombre_completo'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _colorRol(rol).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    rol,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _colorRol(rol),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!activo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'INACTIVO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Usuario de acceso: @${u['username']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                              tooltip: 'Editar Usuario y Rol',
                              onPressed: () => _abrirFormularioUsuario(usuarioExistente: u),
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
