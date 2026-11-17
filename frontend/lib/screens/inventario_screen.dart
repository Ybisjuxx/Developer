import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';
import 'inventario/caducidades_tab.dart';
import 'inventario/kardex_tab.dart';
import 'inventario/nuevo_lote_dialog.dart';
import 'inventario/productos_tab.dart';

class InventarioScreen extends StatefulWidget {
  final int tabInicial;

  const InventarioScreen({super.key, this.tabInicial = 0});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _productos = [];
  List<dynamic> _kardex = [];
  List<dynamic> _lotesCaducidades = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.tabInicial >= 0 && widget.tabInicial <= 2) ? widget.tabInicial : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        ApiService.getProductos(),
        ApiService.getKardex(),
        ApiService.getLotesCaducidades(dias: 90),
      ]);
      if (mounted) {
        setState(() {
          _productos = futures[0];
          _kardex = futures[1];
          _lotesCaducidades = futures[2];
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

  void _abrirNuevoLote() {
    mostrarDialogoNuevoLote(
      context,
      productos: _productos,
      onSuccess: _cargarTodo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return ListenableBuilder(
      listenable: ts,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 800;

            return Scaffold(
              backgroundColor: ts.scaffoldBg,
              floatingActionButton: isMobile
                  ? FloatingActionButton.extended(
                      onPressed: _abrirNuevoLote,
                      backgroundColor: ts.accentPrimary,
                      foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Lote'),
                    )
                  : null,
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 16,
                    isMobile ? 12 : 16,
                    isMobile ? 12 : 16,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PremiumModuleHeader(
                        title: 'Inventario, Caducidades FEFO y Kardex',
                        subtitle: 'Control de existencias por lote, alertas sanitarias FEFO y auditoría inmutable de Kardex.',
                        icon: Icons.inventory_2_rounded,
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
                            _lotesCaducidades.isNotEmpty
                                ? '${_lotesCaducidades.length} FEFO'
                                : '${_productos.length} PRODUCTOS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        actions: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                              foregroundColor: ts.esTemaNeon ? Colors.black : ts.accentPrimary,
                            ),
                            onPressed: _abrirNuevoLote,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nuevo Lote', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PremiumSurfaceCard(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        elevatedGlow: false,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: ts.accentPrimary,
                          unselectedLabelColor: ts.textSecondary,
                          indicatorColor: ts.accentPrimary,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.inventory_2_outlined),
                              text: isMobile ? 'Catálogo y Lotes' : 'Catálogo y Todos los Lotes',
                            ),
                            Tab(
                              icon: Badge(
                                isLabelVisible: _lotesCaducidades.isNotEmpty,
                                label: Text('${_lotesCaducidades.length}'),
                                backgroundColor: ts.neonRed,
                                child: const Icon(Icons.warning_amber_rounded),
                              ),
                              text: isMobile ? 'Alertas FEFO' : 'Lotes por Caducar (Alertas FEFO)',
                            ),
                            Tab(
                              icon: const Icon(Icons.history_edu_outlined),
                              text: isMobile ? 'Kardex' : 'Kardex y Auditoría de Movimientos',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _error != null
                                ? Center(child: Text('Error: $_error', style: TextStyle(color: ts.neonRed)))
                                : TabBarView(
                                    controller: _tabController,
                                    children: [
                                      // Pestaña 1: Catálogo y Lotes
                                      ProductosTab(
                                        productos: _productos,
                                        onReload: _cargarTodo,
                                      ),
                                      // Pestaña 2: Sub-Agente 1 - Lotes Próximos a Caducar Separados
                                      CaducidadesTab(
                                        lotesCaducidades: _lotesCaducidades,
                                        productos: _productos,
                                        onReload: _cargarTodo,
                                      ),
                                      // Pestaña 3: Kardex Inmutable con Comentarios
                                      KardexTab(
                                        kardex: _kardex,
                                        productos: _productos,
                                        onReload: _cargarTodo,
                                      ),
                                    ],
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
