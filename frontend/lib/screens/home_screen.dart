import 'package:flutter/material.dart';
import 'caja_screen.dart';
import 'clientes_screen.dart';
import 'configuracion_screen.dart';
import 'dashboard_screen.dart';
import 'devoluciones_screen.dart';
import 'enfermedades_screen.dart';
import 'inventario_screen.dart';
import 'medicos_screen.dart';
import 'pos_screen.dart';
import 'ventas_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Iniciar en el Tablero de Mando por defecto
  int _inventarioSubTab = 0; // 0: Catálogo, 1: Lotes por Caducar, 2: Kardex
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.switch_account, color: Colors.teal),
            SizedBox(width: 8),
            Text('Cambiar Usuario / Rol'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Selecciona un perfil para operar con sus permisos normativos:',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              ...AuthService.usuariosDemostracion.map((u) {
                final bool seleccionado = _auth.usuarioActual.id == u.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: seleccionado ? Colors.teal.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: seleccionado ? Colors.teal : Colors.grey.shade300),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: _obtenerColorRol(u.rol).withValues(alpha: 0.2),
                      child: Icon(Icons.person, color: _obtenerColorRol(u.rol), size: 20),
                    ),
                    title: Text(u.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(u.rol, style: TextStyle(color: _obtenerColorRol(u.rol), fontSize: 11, fontWeight: FontWeight.bold)),
                    trailing: seleccionado ? const Icon(Icons.check_circle, color: Colors.teal) : null,
                    onTap: () {
                      _auth.cambiarUsuario(u);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sesión activa: ${u.nombreCompleto} (${u.rol})')),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Color _obtenerColorRol(String rol) {
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

  // =========================================================================
  // SUB-AGENTE 5: MODAL DE CHAT CON IA PARA BÚSQUEDA Y SUSTITUTOS
  // =========================================================================
  void _abrirChatConsultaIa() {
    final TextEditingController chatController = TextEditingController();
    final List<Map<String, dynamic>> conversacion = [
      {
        'remitente': 'ia',
        'texto':
            '¡Hola! Soy tu **Asistente Farmacéutico IA** de FarmaControl.\n\n'
            'Puedo verificar si tenemos un medicamento en stock o buscar **sustitutos bioequivalentes y alternativas terapéuticas** en nuestro catálogo si no está disponible.',
        'sustitutos': <dynamic>[],
        'aviso': null,
      }
    ];
    bool esperandoIa = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setChatState) {
          final isWide = MediaQuery.of(context).size.width > 700;

          void enviarConsulta([String? textoDirecto]) async {
            final query = (textoDirecto ?? chatController.text).trim();
            if (query.isEmpty || esperandoIa) return;

            chatController.clear();
            setChatState(() {
              conversacion.add({
                'remitente': 'usuario',
                'texto': query,
                'sustitutos': <dynamic>[],
                'aviso': null,
              });
              esperandoIa = true;
            });

            try {
              final res = await ApiService.consultarIaMedicamentos(query);
              setChatState(() {
                conversacion.add({
                  'remitente': 'ia',
                  'texto': res['respuesta_ia'] ?? 'Análisis farmacológico completado.',
                  'sustitutos': res['sustitutos_en_stock'] ?? <dynamic>[],
                  'aviso': res['aviso_sanitario'],
                });
                esperandoIa = false;
              });
            } catch (e) {
              setChatState(() {
                conversacion.add({
                  'remitente': 'ia',
                  'texto': '⚠️ No se pudo procesar la consulta con el motor IA: $e',
                  'sustitutos': <dynamic>[],
                  'aviso': null,
                });
                esperandoIa = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente Farmacéutico IA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        'Búsqueda de medicamentos, bioequivalencia y sustitutos en stock',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: isWide ? 620 : double.maxFinite,
              height: 520,
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Sugerencias rápidas de consulta
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipSugerencia('¿Tempra o Paracetamol?', () => enviarConsulta('Tempra')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Sustitutos de Amoxicilina?', () => enviarConsulta('Sustitutos de Amoxicilina')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Antihistamínico para alergia?', () => enviarConsulta('Antihistamínico para alergia')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Alternativas a Flanax / Naproxeno?', () => enviarConsulta('Alternativas a Flanax')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Área de mensajes del chat
                  Expanded(
                    child: ListView.builder(
                      itemCount: conversacion.length + (esperandoIa ? 1 : 0),
                      itemBuilder: (context, idx) {
                        if (idx == conversacion.length && esperandoIa) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Analizando catálogo de farmacia y bioequivalencia...',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          );
                        }

                        final msg = conversacion[idx];
                        final bool esUsuario = msg['remitente'] == 'usuario';
                        final List sustitutos = msg['sustitutos'] ?? [];
                        final String? aviso = msg['aviso'];

                        return Align(
                          alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: BoxConstraints(maxWidth: isWide ? 520 : 340),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esUsuario ? Colors.teal.shade700 : Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: esUsuario ? const Radius.circular(14) : Radius.zero,
                                bottomRight: esUsuario ? Radius.zero : const Radius.circular(14),
                              ),
                              border: Border.all(
                                color: esUsuario ? Colors.teal.shade800 : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      esUsuario ? Icons.person : Icons.smart_toy,
                                      size: 14,
                                      color: esUsuario ? Colors.white70 : Colors.teal.shade800,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      esUsuario ? 'Tú (Farmacéutico)' : 'Asistente IA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: esUsuario ? Colors.white70 : Colors.teal.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  msg['texto'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: esUsuario ? Colors.white : Colors.black87,
                                    height: 1.35,
                                  ),
                                ),

                                // Tarjetas de sustitutos en stock directo
                                if (sustitutos.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    '📦 Fármacos disponibles en inventario:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  ...sustitutos.map((s) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.teal.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${s["nombre_comercial"]} (${s["sustancia_activa"]})',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                Text(
                                                  '${s["presentacion"]} • Lab: ${s["laboratorio"]}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Stock: ${s["stock_disponible"]} pzas • \$${s["precio_venta"]} MXN',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FilledButton.tonal(
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () {
                                              Navigator.of(ctx).pop();
                                              _cambiarPestana(1); // Ir a Punto de Venta
                                            },
                                            child: const Text('Cobrar', style: TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],

                                // Aviso Sanitario COFEPRIS
                                if (aviso != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Text(
                                      aviso,
                                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Caja de entrada de consulta
                  Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            onSubmitted: (_) => enviarConsulta(),
                            decoration: const InputDecoration(
                              hintText: 'Pregunta por un fármaco o sustituto...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onPressed: esperandoIa ? null : () => enviarConsulta(),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('Consultar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chipSugerencia(String label, VoidCallback onTap) {
    return ActionChip(
      avatar: const Icon(Icons.bubble_chart, size: 14, color: Colors.teal),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: Colors.teal.shade50,
      side: BorderSide(color: Colors.teal.shade200),
    );
  }

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
        return const DevolucionesScreen();
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
      'Devoluciones y Mermas Sanitarias',
      'Directorio de Médicos',
      'Catálogo de Diagnósticos CIE-10',
      'Configuración del Sistema y Usuarios',
    ];

    final user = _auth.usuarioActual;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 820;

        return Scaffold(
          // Sub-Agente 4: Drawer siempre accesible en móviles y pantallas reducidas
          drawer: Drawer(
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
                _drawerItem(2, Icons.people_alt, 'Padrón de Clientes CIE-10'),
                _drawerItem(3, Icons.inventory_2, 'Inventario y Caducidades FEFO'),
                _drawerItem(4, Icons.receipt_long, 'Historial de Ventas'),
                _drawerItem(5, Icons.calculate, 'Corte de Caja (Arqueo)'),
                _drawerItem(6, Icons.assignment_return, 'Devoluciones y Mermas'),
                _drawerItem(7, Icons.medical_information, 'Directorio Médico'),
                _drawerItem(8, Icons.healing, 'Catálogo CIE-10'),
                _drawerItem(9, Icons.settings, 'Configuración y Usuarios'),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: Colors.teal.shade900,
            foregroundColor: Colors.white,
            elevation: 2,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_pharmacy, color: Colors.black87, size: 22),
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
                      color: Colors.teal.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade700),
                    ),
                    child: Text(
                      titles[_selectedIndex],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const Spacer(),

                // Sub-Agente 5: Botón Destacado de Consulta con IA
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _abrirChatConsultaIa,
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
                      color: Colors.teal.shade800,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.tealAccent.shade400.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: _obtenerColorRol(user.rol),
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
              ],
            ),
          ),
          body: Row(
            children: [
              // Sub-Agente 4: Menú vertical con Scroll para nunca cortarse al agrandar texto
              if (isDesktop)
                SizedBox(
                  width: 95,
                  child: LayoutBuilder(
                    builder: (context, railConstraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: railConstraints.maxHeight),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _selectedIndex,
                              onDestinationSelected: _cambiarPestana,
                              labelType: NavigationRailLabelType.all,
                              selectedIconTheme: IconThemeData(color: Colors.teal.shade900, size: 24),
                              unselectedIconTheme: IconThemeData(color: Colors.grey.shade600, size: 22),
                              selectedLabelTextStyle: TextStyle(
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              unselectedLabelTextStyle: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                              ),
                              destinations: const [
                                NavigationRailDestination(
                                  icon: Icon(Icons.dashboard_outlined),
                                  selectedIcon: Icon(Icons.dashboard),
                                  label: Text('Tablero'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.point_of_sale_outlined),
                                  selectedIcon: Icon(Icons.point_of_sale),
                                  label: Text('Cobrar'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.people_alt_outlined),
                                  selectedIcon: Icon(Icons.people_alt),
                                  label: Text('Clientes'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.inventory_2_outlined),
                                  selectedIcon: Icon(Icons.inventory_2),
                                  label: Text('Inventario'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.receipt_long_outlined),
                                  selectedIcon: Icon(Icons.receipt_long),
                                  label: Text('Ventas'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.calculate_outlined),
                                  selectedIcon: Icon(Icons.calculate),
                                  label: Text('Corte Caja'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.assignment_return_outlined),
                                  selectedIcon: Icon(Icons.assignment_return),
                                  label: Text('Devolución'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.medical_information_outlined),
                                  selectedIcon: Icon(Icons.medical_information),
                                  label: Text('Médicos'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.healing_outlined),
                                  selectedIcon: Icon(Icons.healing),
                                  label: Text('CIE-10'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.settings_outlined),
                                  selectedIcon: Icon(Icons.settings),
                                  label: Text('Ajustes'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: _construirPantallaActual(_selectedIndex),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex >= 5 ? 0 : _selectedIndex,
                  onDestinationSelected: (idx) {
                    if (idx == 4) {
                      Scaffold.of(context).openDrawer();
                    } else {
                      _cambiarPestana(idx);
                    }
                  },
                  indicatorColor: Colors.teal.shade100,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard, color: Colors.teal),
                      label: 'Tablero',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale, color: Colors.teal),
                      label: 'Cobrar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt, color: Colors.teal),
                      label: 'Clientes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2, color: Colors.teal),
                      label: 'Inventario',
                    ),
                    NavigationDestination(
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
    return ListTile(
      leading: Icon(icon, color: seleccionado ? Colors.teal : Colors.blueGrey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
          color: seleccionado ? Colors.teal.shade900 : Colors.black87,
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
