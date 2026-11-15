import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';

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
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 480),
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
                        initialValue: rolSeleccionado,
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
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) {
        final ts = _themeService;
        return Scaffold(
          backgroundColor: ts.scaffoldBg,
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumModuleHeader(
                  title: 'Configuración del Sistema',
                  subtitle: 'Personalización visual HeroUI, modo oscuro, tipografía y administración de cuentas.',
                  icon: Icons.tune_rounded,
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ts.esTemaNeon
                          ? ts.accentPrimary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ts.esTemaNeon
                            ? ts.accentPrimary.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      ts.colorActual.nombre.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: ts.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ts.borderColor),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: ts.accentPrimary,
                    unselectedLabelColor: ts.textSecondary,
                    indicatorColor: ts.accentPrimary,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(icon: Icon(Icons.palette_outlined), text: 'Personalización Visual e Interfaz'),
                      Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Usuarios y Permisos de Acceso'),
                    ],
                  ),
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
      },
    );
  }

  Widget _buildTabPersonalizacion() {
    final ts = _themeService;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // TARJETA DE VISTA PREVIA HERO UI CON heroBannerGradient Y cardGlowShadow
          // ===================================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: ts.heroBannerGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ts.esTemaNeon ? ts.accentPrimary.withValues(alpha: 0.5) : ts.borderColor,
                width: 1.2,
              ),
              boxShadow: ts.cardGlowShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ts.esTemaNeon
                                ? ts.accentPrimary.withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ts.esTemaNeon
                                  ? ts.accentPrimary.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Vista Previa en Vivo',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ts.esTemaNeon
                                        ? ts.accentPrimary.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: ts.esTemaNeon
                                          ? ts.accentPrimary.withValues(alpha: 0.5)
                                          : Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    ts.colorActual.nombre,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Diseño reactivo HeroUI + Fragments UI adaptado al sistema farmacéutico',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Interruptor de Modo Oscuro con actualización instantánea
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: ts.esTemaNeon
                            ? Colors.black.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ts.esOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            size: 18,
                            color: ts.esOscuro ? (ts.esTemaNeon ? ts.accentPrimary : Colors.amberAccent) : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ts.esOscuro ? 'Modo Oscuro' : 'Modo Claro',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: ts.modoOscuro,
                            activeThumbColor: ts.accentPrimary,
                            onChanged: (val) {
                              _themeService.alternarModoOscuro(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mock visual interactivo de demostración
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ts.cardBg.withValues(alpha: ts.esOscuro ? 0.94 : 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ts.borderColor, width: 1.2),
                    boxShadow: ts.cardGlowShadow,
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.15, darkAlpha: 0.25),
                            child: Icon(Icons.medical_services_rounded, color: ts.accentPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Paracetamol 500mg • Lote #CAD2027',
                                style: TextStyle(
                                  fontSize: 14 * ts.factorEscala,
                                  fontWeight: FontWeight.bold,
                                  color: ts.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dispensación controlada FEFO • Existencias: 140 pzas',
                                style: TextStyle(
                                  fontSize: 12 * ts.factorEscala,
                                  color: ts.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonGreen, lightAlpha: 0.12, darkAlpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ts.neonGreen.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 14, color: ts.neonGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'Vigente',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ts.neonGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonBlue, lightAlpha: 0.12, darkAlpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ts.neonBlue.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              '\$45.00 MXN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ts.neonBlue,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ts.accentPrimary,
                              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: () {},
                            icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                            label: const Text('Simular Venta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ===================================================================
          // SELECTOR DE PALETAS CON SWATCH VÍVIDO + ts.cardGlowShadow AL SELECCIONAR
          // ===================================================================
          PremiumSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ts.tintBg(ts.accentPrimary, lightAlpha: 0.12, darkAlpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.palette_rounded, color: ts.accentPrimary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paleta de Colores de la Farmacia',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ts.textPrimary,
                          ),
                        ),
                        Text(
                          'Selecciona la identidad cromática institucional de tu botica o sucursal:',
                          style: TextStyle(color: ts.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: ThemeService.coloresDisponibles.map((opc) {
                        final bool seleccionado = ts.colorActual.nombre == opc.nombre;
                        final Color cardGlowColor = opc.esNeonOscuro
                            ? const Color(0xFF00F5D4)
                            : opc.primaryColor;

                        return SizedBox(
                          width: 250,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: seleccionado
                                  ? (opc.esNeonOscuro
                                      ? const Color(0xFF0E131F)
                                      : ts.tintBg(opc.primaryColor, lightAlpha: 0.10, darkAlpha: 0.16))
                                  : ts.surfaceBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: seleccionado
                                    ? cardGlowColor
                                    : (opc.esNeonOscuro
                                        ? const Color(0xFF00F5D4).withValues(alpha: 0.35)
                                        : ts.borderColor),
                                width: seleccionado ? 2.0 : 1.2,
                              ),
                              boxShadow: seleccionado
                                  ? [
                                      BoxShadow(
                                        color: cardGlowColor.withValues(alpha: opc.esNeonOscuro ? 0.30 : 0.22),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _themeService.cambiarColor(opc),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Swatch Vívido con gradiente e indicadores de tonos
                                      Container(
                                        height: 38,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: opc.esNeonOscuro
                                                ? [
                                                    const Color(0xFF090B10),
                                                    const Color(0xFF00F5D4),
                                                    const Color(0xFFBB86FC),
                                                  ]
                                                : [
                                                    opc.accentColor,
                                                    opc.primaryColor,
                                                    opc.primaryColor.shade200,
                                                  ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: cardGlowColor.withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: opc.accentColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 1.5),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: opc.esNeonOscuro
                                                          ? const Color(0xFF00F5D4)
                                                          : opc.primaryColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 1.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (seleccionado)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check, size: 12, color: Colors.white),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'ACTIVA',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  opc.nombre,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                                                    color: seleccionado ? cardGlowColor : ts.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  opc.esNeonOscuro ? 'Alto Contraste Neón' : 'Tono Clínico',
                                                  style: TextStyle(fontSize: 10, color: ts.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            seleccionado ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                            size: 20,
                                            color: seleccionado ? cardGlowColor : ts.textSecondary.withValues(alpha: 0.4),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ===================================================================
          // TAMAÑO DE FUENTE Y ACCESIBILIDAD
          // ===================================================================
          PremiumSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ts.tintBg(ts.neonBlue, lightAlpha: 0.12, darkAlpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.format_size_rounded, color: ts.neonBlue, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tamaño de Fuente y Accesibilidad Visual',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ts.textPrimary,
                          ),
                        ),
                        Text(
                          'Ajusta la escala tipográfica global para pantallas táctiles o mostradores:',
                          style: TextStyle(color: ts.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: EscalaFuente.values.map((escala) {
                    final bool seleccionada = ts.escalaActual == escala;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: OutlinedButton(
                          onPressed: () => _themeService.cambiarEscala(escala),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: seleccionada
                                ? ts.tintBg(ts.accentPrimary, lightAlpha: 0.18, darkAlpha: 0.24)
                                : ts.surfaceBg,
                            side: BorderSide(
                              color: seleccionada ? ts.accentPrimary : ts.borderColor,
                              width: seleccionada ? 2.0 : 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            escala.etiqueta,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                              color: seleccionada ? ts.accentPrimary : ts.textPrimary,
                              fontSize: 12 * escala.factor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ts.surfaceAltBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ts.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.preview_rounded, color: ts.accentPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vista previa de escala: FarmaControl POS — Paracetamol 500mg Lote #CAD2027 a \$45.00 MXN',
                          style: TextStyle(
                            fontSize: 13 * ts.factorEscala,
                            fontWeight: FontWeight.w600,
                            color: ts.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabUsuarios() {
    final ts = _themeService;
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
              onPressed: () => _abrirFormularioUsuario(),
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
          child: _isLoadingUsuarios
              ? const Center(child: CircularProgressIndicator())
              : _errorUsuarios != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: ts.neonRed, size: 36),
                          const SizedBox(height: 8),
                          Text(_errorUsuarios!, style: TextStyle(color: ts.neonRed)),
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
