import 'package:flutter/material.dart';
import 'caja_screen.dart';
import 'clientes_screen.dart';
import 'configuracion_screen.dart';
import 'dashboard_screen.dart';
import 'registros_bitacoras_screen.dart';
import 'enfermedades_screen.dart';
import 'inventario_screen.dart';
import 'medicos_screen.dart';
import 'pos_screen.dart';
import 'ventas_screen.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/ia_consulta_sheet.dart';
import '../widgets/premium_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0; // Iniciar en el Tablero de Mando por defecto
  int _inventarioSubTab = 0; // 0: Catálogo, 1: Lotes por Caducar, 2: Kardex
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    ThemeService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    ThemeService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _cambiarPestana(int index, {int subTab = 0}) {
    setState(() {
      _selectedIndex = index;
      if (index == 3) {
        _inventarioSubTab = subTab;
      }
    });
  }

  void _mostrarSelectorUsuario() {
    final ts = ThemeService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.switch_account, color: ts.accentPrimary),
            const SizedBox(width: 8),
            const Text('Cambiar Usuario / Rol'),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selecciona un perfil para operar con sus permisos normativos:',
                style: TextStyle(fontSize: 12, color: ts.textSecondary),
              ),
              const SizedBox(height: 12),
              ...AuthService.usuariosDemostracion.map((u) {
                final bool seleccionado = _auth.usuarioActual.id == u.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: seleccionado ? ts.tintBg(ts.accentPrimary) : ts.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: seleccionado ? ts.accentPrimary : ts.borderColor),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: AppFormatters.colorPorRol(u.rol).withValues(alpha: 0.2),
                      child: Icon(Icons.person, color: AppFormatters.colorPorRol(u.rol), size: 20),
                    ),
                    title: Text(u.nombreCompleto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary)),
                    subtitle: Text(u.rol, style: TextStyle(color: AppFormatters.colorPorRol(u.rol), fontSize: 11, fontWeight: FontWeight.bold)),
                    trailing: seleccionado ? Icon(Icons.check_circle, color: ts.accentPrimary) : null,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _auth.loginRapidoDemo(u.username);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sesión activa: ${u.nombreCompleto} (${u.rol})')),
                        );
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmarCerrarSesion();
            },
            icon: const Icon(Icons.logout, color: Colors.red, size: 16),
            label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: Text('¿Deseas cerrar la sesión activa de ${_auth.usuarioActual.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _auth.logout();
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-AGENTE 5: MODAL DE CHAT CON IA PARA BÚSQUEDA Y SUSTITUTOS
  // =========================================================================
  Widget _construirPantallaActual(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onNavigate: _cambiarPestana);
      case 1:
        return PosScreen(onVentaCompletada: () => setState(() {}));
      case 2:
        return const ClientesScreen();
      case 3:
        return InventarioScreen(key: ValueKey('inv-$_inventarioSubTab'), tabInicial: _inventarioSubTab);
      case 4:
        return const VentasScreen();
      case 5:
        return const CajaScreen();
      case 6:
        return const RegistrosBitacorasScreen();
      case 7:
        return const MedicosScreen();
      case 8:
        return const EnfermedadesScreen();
      case 9:
        return const ConfiguracionScreen();
      default:
        return DashboardScreen(onNavigate: _cambiarPestana);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = const [
      'Tablero de Mando Farmacéutico',
      'Punto de Venta y Cobranza',
      'Padrón de Clientes e Historial Clínico',
      'Inventario, Caducidades y Kardex',
      'Historial de Ventas y Tickets',
      'Corte de Caja y Turnos (Arqueo)',
      'Registros, Bitácoras y Devoluciones',
      'Directorio de Médicos',
      'Catálogo de Diagnósticos CIE-11',
      'Configuración del Sistema y Usuarios',
    ];

    final user = _auth.usuarioActual;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 820;

        return Scaffold(
          key: _scaffoldKey,
          // Sub-Agente 4: Drawer siempre accesible en móviles y pantallas reducidas
          drawer: isDesktop ? null : Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.teal.shade900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_pharmacy, color: Colors.black87, size: 24),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'FarmaControl',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        '${user.nombreCompleto} (${user.rol})',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _drawerItem(0, Icons.dashboard, 'Tablero de Mando'),
                _drawerItem(1, Icons.point_of_sale, 'Punto de Venta (Cobrar)'),
                _drawerItem(2, Icons.people_alt, 'Padrón de Clientes CIE-11'),
                _drawerItem(3, Icons.inventory_2, 'Inventario y Caducidades FEFO'),
                _drawerItem(4, Icons.receipt_long, 'Historial de Ventas'),
                _drawerItem(5, Icons.calculate, 'Corte de Caja (Arqueo)'),
                _drawerItem(6, Icons.fact_check, 'Registros y Bitácoras'),
                _drawerItem(7, Icons.medical_information, 'Directorio Médico'),
                _drawerItem(8, Icons.healing, 'Catálogo CIE-11'),
                _drawerItem(9, Icons.settings, 'Configuración y Usuarios'),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: ThemeService.instance.headerBg,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: ThemeService.instance.headerGradient,
              ),
            ),
            title: isDesktop
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ThemeService.instance.accentPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_pharmacy,
                          color: ThemeService.instance.esTemaNeon ? Colors.black : Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'FarmaControl',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ThemeService.instance.accentPrimary.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            titles[_selectedIndex],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemeService.instance.esTemaNeon
                                  ? ThemeService.instance.accentPrimary
                                  : Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Sub-Agente 5: Botón Destacado de Consulta con IA
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ThemeService.instance.accentPrimary,
                          foregroundColor: ThemeService.instance.esTemaNeon ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => showConsultaIaModal(context, onNavigate: _cambiarPestana),
                        icon: const Icon(Icons.smart_toy, size: 18),
                        label: const Text(
                          'Consulta IA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Chip de Usuario / Rol con botón para cambiar
                      InkWell(
                        onTap: _mostrarSelectorUsuario,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ThemeService.instance.accentPrimary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: AppFormatters.colorPorRol(user.rol),
                                child: const Icon(Icons.person, size: 12, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Text(
                                  user.nombreCompleto,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Chip indicador del servidor backend
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade900.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.greenAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                            SizedBox(width: 5),
                            Text('Online', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                        tooltip: 'Cerrar Sesión',
                        onPressed: _confirmarCerrarSesion,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.local_pharmacy, color: Colors.black87, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'FarmaControl',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titles[_selectedIndex],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
            actions: isDesktop
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.smart_toy, color: Colors.tealAccent, size: 20),
                      tooltip: 'Consulta IA Farmacéutica',
                      onPressed: () => showConsultaIaModal(context, onNavigate: _cambiarPestana),
                    ),
                    InkWell(
                      onTap: _mostrarSelectorUsuario,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppFormatters.colorPorRol(user.rol),
                          child: const Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                      tooltip: 'Cerrar Sesión',
                      onPressed: _confirmarCerrarSesion,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12, left: 4),
                      child: Center(
                        child: CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                      ),
                    ),
                  ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: ThemeService.instance.shellGradient,
            ),
            child: Row(
              children: [
                // Arc UI Workspace Shell: Menú lateral integrado sobre el marco degradado
                if (isDesktop)
                  SizedBox(
                    width: 112,
                    child: LayoutBuilder(
                      builder: (context, railConstraints) {
                        return SingleChildScrollView(
                          clipBehavior: Clip.none,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: railConstraints.maxHeight),
                            child: IntrinsicHeight(
                              child: RibbonNavRail(
                                selectedIndex: _selectedIndex,
                                onDestinationSelected: _cambiarPestana,
                                destinations: const [
                                  RibbonNavItem(
                                    icon: Icons.dashboard_outlined,
                                    selectedIcon: Icons.dashboard,
                                    label: 'Tablero',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.point_of_sale_outlined,
                                    selectedIcon: Icons.point_of_sale,
                                    label: 'Cobrar',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.people_alt_outlined,
                                    selectedIcon: Icons.people_alt,
                                    label: 'Clientes',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.inventory_2_outlined,
                                    selectedIcon: Icons.inventory_2,
                                    label: 'Inventario',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.receipt_long_outlined,
                                    selectedIcon: Icons.receipt_long,
                                    label: 'Ventas',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.calculate_outlined,
                                    selectedIcon: Icons.calculate,
                                    label: 'Corte Caja',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.fact_check_outlined,
                                    selectedIcon: Icons.fact_check,
                                    label: 'Bitácoras',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.medical_information_outlined,
                                    selectedIcon: Icons.medical_information,
                                    label: 'Médicos',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.healing_outlined,
                                    selectedIcon: Icons.healing,
                                    label: 'CIE-11',
                                  ),
                                  RibbonNavItem(
                                    icon: Icons.settings_outlined,
                                    selectedIcon: Icons.settings,
                                    label: 'Ajustes',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: isDesktop ? const EdgeInsets.fromLTRB(4, 10, 12, 12) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: ThemeService.instance.scaffoldBg,
                      borderRadius: isDesktop ? BorderRadius.circular(20) : BorderRadius.zero,
                      border: isDesktop
                          ? Border.all(color: ThemeService.instance.borderColor, width: 1.2)
                          : null,
                      boxShadow: isDesktop ? ThemeService.instance.cardGlowShadow : null,
                    ),
                    child: ClipRRect(
                      borderRadius: isDesktop ? BorderRadius.circular(19) : BorderRadius.zero,
                      child: _construirPantallaActual(_selectedIndex),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex >= 4 ? 4 : _selectedIndex,
                  onDestinationSelected: (idx) {
                    if (idx == 4) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      _cambiarPestana(idx);
                    }
                  },
                  indicatorColor: ThemeService.instance.accentPrimary.withValues(alpha: 0.20),
                  backgroundColor: ThemeService.instance.cardBg,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard, color: ThemeService.instance.accentPrimary),
                      label: 'Tablero',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale, color: ThemeService.instance.accentPrimary),
                      label: 'Cobrar',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt, color: ThemeService.instance.accentPrimary),
                      label: 'Clientes',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2, color: ThemeService.instance.accentPrimary),
                      label: 'Inventario',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.menu),
                      label: 'Más Módulos',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    final bool seleccionado = _selectedIndex == index;
    final ts = ThemeService.instance;
    return ListTile(
      leading: Icon(icon, color: seleccionado ? ts.accentPrimary : ts.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
          color: seleccionado ? ts.accentPrimary : ts.textPrimary,
        ),
      ),
      selected: seleccionado,
      onTap: () {
        Navigator.of(context).pop();
        _cambiarPestana(index);
      },
    );
  }
}

