import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  List<dynamic> _devoluciones = [];
  List<dynamic> _mermas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devs = await ApiService.getDevoluciones();
      final mermas = await ApiService.getMermas();

      if (mounted) {
        setState(() {
          _devoluciones = devs;
          _mermas = mermas;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.teal.shade900,
                    indicatorColor: Colors.teal,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.assignment_return_outlined),
                        text: 'Devoluciones y Reembolsos (${_devoluciones.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        text: 'Mermas Sanitarias (${_mermas.length})',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargarDatos,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPestanaDevoluciones(),
                            _buildPestanaMermas(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPestanaDevoluciones() {
    if (_devoluciones.isEmpty) {
      return const Center(child: Text('No hay devoluciones registradas aún'));
    }

    return ListView.builder(
      itemCount: _devoluciones.length,
      itemBuilder: (context, index) {
        final d = _devoluciones[index];
        final List<dynamic> detalles = d['detalles'] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              child: Icon(Icons.replay, color: Colors.orange.shade800),
            ),
            title: Text(
              'Folio: ${d["folio_devolucion"]}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Venta ID: #${d["venta_id"]} | Motivo: ${d["motivo"]}\n'
              'Fecha: ${d["fecha_devolucion"].toString().replaceFirst("T", " ").substring(0, 16)}',
            ),
            trailing: Text(
              'Reembolso:\n\$${d["total_reembolsado"]} MXN',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red.shade900,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Artículos Devueltos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...detalles.map((det) {
                      final bool buenEstado = det['estado_producto'] == 'BUEN_ESTADO';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: buenEstado ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: buenEstado ? Colors.green.shade200 : Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${det["cantidad"]} pzas (Prod #${det["producto_id"]}, Lote #${det["lote_id"]})',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: buenEstado ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                buenEstado ? 'Reingresó a Stock' : 'MERMA (Dañado)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: buenEstado ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPestanaMermas() {
    if (_mermas.isEmpty) {
      return const Center(child: Text('No hay productos registrados en merma sanitaria'));
    }

    return ListView.builder(
      itemCount: _mermas.length,
      itemBuilder: (context, index) {
        final m = _mermas[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade50,
              child: Icon(Icons.delete_forever, color: Colors.red.shade800),
            ),
            title: Text(
              '${m["producto_nombre"]} (Lote: ${m["numero_lote"]})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Cantidad Merma: ${m["cantidad"]} piezas | Motivo: ${m["motivo"]}\n'
              'Fecha de baja: ${m["fecha"].toString().replaceFirst("T", " ").substring(0, 16)}',
            ),
            trailing: Text(
              'Costo Baja:\n\$${m["costo_total"]} MXN',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.red.shade900,
              ),
            ),
          ),
        );
      },
    );
  }
}
