import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';
import 'configuracion/personalizacion_tab.dart';
import 'configuracion/usuario_form_dialog.dart';
import 'configuracion/usuarios_tab.dart';

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
    showUsuarioFormDialog(
      context: context,
      usuarioExistente: usuarioExistente,
      onSaved: _cargarUsuarios,
    );
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
                    isScrollable: true,
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
                      PersonalizacionTab(themeService: _themeService),
                      UsuariosTab(
                        themeService: _themeService,
                        usuarios: _usuarios,
                        isLoading: _isLoadingUsuarios,
                        error: _errorUsuarios,
                        onRetry: _cargarUsuarios,
                        onOpenFormulario: _abrirFormularioUsuario,
                      ),
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
}
