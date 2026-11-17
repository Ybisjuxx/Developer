import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';

/// Muestra el modal de registro exprés de cliente y notifica con [onClienteCreado].
Future<void> mostrarModalNuevoClienteRapido(
  BuildContext context, {
  required void Function(Map<String, dynamic> nuevoCliente) onClienteCreado,
}) async {
  final ts = ThemeService.instance;
  final nomCtrl = TextEditingController();
  final apePaternoCtrl = TextEditingController();
  final apeMaternoCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  final descCtrl = TextEditingController(text: '0');

  String? sexoSeleccionado;
  final diaCtrl = TextEditingController();
  final mesCtrl = TextEditingController();
  final anioCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (modalContext, setModalState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add_alt_1, color: ts.accentPrimary),
            const SizedBox(width: 8),
            const Text('Registro Exprés de Cliente'),
          ],
        ),
        content: Container(
          width: MediaQuery.of(modalContext).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre(s) *', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: apePaternoCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido Paterno *', prefixIcon: Icon(Icons.badge)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: apeMaternoCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido Materno', prefixIcon: Icon(Icons.badge_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: telCtrl,
                        decoration: const InputDecoration(labelText: 'Teléfono (Opcional)', prefixIcon: Icon(Icons.phone)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: descCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '% Descuento', suffixText: '%'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sexoSeleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sexo / Género (Opcional)',
                    prefixIcon: Icon(Icons.wc),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('No especificar / Prefiero no decir', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'MASCULINO', child: Text('Masculino', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'FEMENINO', child: Text('Femenino', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'OTRO', child: Text('Otro / No especificado', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setModalState(() => sexoSeleccionado = val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Fecha de Nacimiento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.calendar_month, color: ts.accentPrimary),
                      tooltip: 'Buscar en calendario',
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: modalContext,
                          initialDate: DateTime(1995, 1, 1),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            diaCtrl.text = picked.day.toString().padLeft(2, '0');
                            mesCtrl.text = picked.month.toString().padLeft(2, '0');
                            anioCtrl.text = picked.year.toString();
                          });
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: diaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Día', hintText: 'DD', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: mesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Mes', hintText: 'MM', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: anioCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Año', hintText: 'AAAA', isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar y Aplicar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            onPressed: () async {
              final nom = nomCtrl.text.trim();
              final pat = apePaternoCtrl.text.trim();
              final mat = apeMaternoCtrl.text.trim();
              if (nom.isEmpty || (pat.isEmpty && mat.isEmpty)) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(content: Text('Nombre y al menos un Apellido son obligatorios')),
                );
                return;
              }

              final apCompleto = "$pat $mat".trim();
              String? fechaNacStr;
              final d = int.tryParse(diaCtrl.text.trim());
              final m = int.tryParse(mesCtrl.text.trim());
              final a = int.tryParse(anioCtrl.text.trim());
              if (d != null &&
                  m != null &&
                  a != null &&
                  d >= 1 &&
                  d <= 31 &&
                  m >= 1 &&
                  m <= 12 &&
                  a >= 1900 &&
                  a <= DateTime.now().year) {
                fechaNacStr = "${a.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
              }

              final desc = double.tryParse(descCtrl.text.trim()) ?? 0.0;
              try {
                final nuevoCliente = await ApiService.createCliente({
                  'nombre': nom,
                  'apellido': apCompleto,
                  'apellido_paterno': pat.isNotEmpty ? pat : null,
                  'apellido_materno': mat.isNotEmpty ? mat : null,
                  'telefono': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                  'descuento_porcentaje': desc,
                  'fecha_nacimiento': fechaNacStr,
                  'sexo': sexoSeleccionado,
                });

                if (ctx.mounted) Navigator.of(ctx).pop();
                onClienteCreado(nuevoCliente);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cliente "$nom $apCompleto" registrado con $desc% de descuento aplicado.'),
                      backgroundColor: ts.neonGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al registrar cliente: $e'), backgroundColor: ts.neonRed),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Muestra el modal de búsqueda y confirmación de cliente por teléfono/nombre/fecha de nacimiento.
Future<void> mostrarBuscadorYConfirmacionCliente(
  BuildContext context, {
  required List<dynamic> clientes,
  required Map<String, dynamic>? clienteSeleccionado,
  required void Function(Map<String, dynamic>? cliente) onClienteSeleccionado,
  required VoidCallback onNuevoCliente,
}) async {
  final ts = ThemeService.instance;
  final TextEditingController busquedaCtrl = TextEditingController();
  String query = '';
  Map<String, dynamic>? candidatoSeleccionado;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (modalContext, setModalState) {
        final q = query.trim().toLowerCase();
        final qLimpio = q.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

        final resultados = clientes.where((c) {
          if (q.isEmpty) return true;
          final nom = (c['nombre'] ?? '').toString().toLowerCase();
          final ape = (c['apellido'] ?? '').toString().toLowerCase();
          final tel = (c['telefono'] ?? '').toString().toLowerCase();
          final telLimpio = tel.replaceAll(RegExp(r'[^0-9]'), '');
          final fechaNac = (c['fecha_nacimiento'] ?? '').toString().toLowerCase();

          return nom.contains(q) ||
              ape.contains(q) ||
              tel.contains(q) ||
              (qLimpio.isNotEmpty && telLimpio.contains(qLimpio)) ||
              fechaNac.contains(q);
        }).toList();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ts.tintBg(ts.accentPrimary), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.person_search, color: ts.accentPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Búsqueda y Confirmación de Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Busca por teléfono, nombre o confirma con fecha de nacimiento', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(modalContext).size.width * 0.9,
            height: MediaQuery.of(modalContext).size.height * 0.70,
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 540),
            child: Column(
              children: [
                TextField(
                  controller: busquedaCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar por teléfono (ej: 555-321-7890), nombre o apellido...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setModalState(() {
                                busquedaCtrl.clear();
                                query = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) => setModalState(() => query = val),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Asignar a Público General', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onClienteSeleccionado(null);
                      },
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.person_add, size: 16, color: ts.accentPrimary),
                      label: Text('Nuevo Cliente', style: TextStyle(fontSize: 12, color: ts.accentPrimary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onNuevoCliente();
                      },
                    ),
                  ],
                ),
                const Divider(height: 14),
                Expanded(
                  child: resultados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 36, color: ts.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                query.isEmpty ? 'No hay clientes registrados.' : 'Sin resultados para "$query"',
                                style: TextStyle(color: ts.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: resultados.length,
                          separatorBuilder: (context, index) => const Divider(height: 8),
                          itemBuilder: (context, i) {
                            final c = resultados[i];
                            final bool esActual = (clienteSeleccionado?['id'] == c['id']);
                            final bool esCandidato = (candidatoSeleccionado?['id'] == c['id']);
                            final double desc = (c['descuento_porcentaje'] ?? 5.0).toDouble();
                            final String? tel = c['telefono'];
                            final String? fechaNac = c['fecha_nacimiento'];

                            return Container(
                              decoration: BoxDecoration(
                                color: esCandidato
                                    ? ts.tintBg(ts.accentPrimary)
                                    : (esActual ? ts.tintBg(ts.neonGreen) : ts.cardBg),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: esCandidato
                                      ? ts.accentPrimary
                                      : (esActual ? ts.neonGreen : ts.borderColor),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.2, darkAlpha: 0.3),
                                  child: Text(
                                    '${c['nombre']?[0] ?? 'C'}${c['apellido']?[0] ?? ''}'.toUpperCase(),
                                    style: TextStyle(color: ts.accentPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c['nombre']} ${c['apellido']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ts.tintBg(ts.neonGreen),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$desc% Desc',
                                        style: TextStyle(fontSize: 10, color: ts.neonGreen, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (c['alerta_resurtimiento_activa'] == true) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ts.tintBg(ts.neonAmber, lightAlpha: 0.25, darkAlpha: 0.3),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: ts.neonAmber),
                                        ),
                                        child: Text(
                                          '🔔 Resurtir (${c['dias_para_resurtimiento'] ?? 0}d)',
                                          style: TextStyle(fontSize: 10, color: ts.neonAmber, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ] else if (c['tiene_padecimientos_cronicos'] == true) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ts.tintBg(ts.neonBlue),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '💊 Crónico',
                                          style: TextStyle(fontSize: 9, color: ts.neonBlue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  children: [
                                    if (tel != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.phone, size: 11, color: ts.accentPrimary),
                                          const SizedBox(width: 3),
                                          Text(tel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    if (fechaNac != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.cake, size: 11, color: ts.neonPurple),
                                          const SizedBox(width: 3),
                                          Text('Nac: $fechaNac', style: const TextStyle(fontSize: 11)),
                                        ],
                                      )
                                    else
                                      Text('Sin fecha nac.', style: TextStyle(fontSize: 10, color: ts.textSecondary)),
                                  ],
                                ),
                                trailing: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      candidatoSeleccionado = c;
                                    });
                                  },
                                  child: const Text('Verificar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                if (candidatoSeleccionado != null) ...[
                  const Divider(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ts.tintBg(ts.neonAmber, lightAlpha: 0.12, darkAlpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ts.neonAmber.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user, color: ts.neonAmber, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Confirmar: ${candidatoSeleccionado!["nombre"]} ${candidatoSeleccionado!["apellido"]}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.neonAmber),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setModalState(() => candidatoSeleccionado = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          candidatoSeleccionado!['fecha_nacimiento'] != null
                              ? '🎂 Fecha de nacimiento para confirmar: ${candidatoSeleccionado!["fecha_nacimiento"]}  •  📞 ${candidatoSeleccionado!["telefono"] ?? "Sin tel"}'
                              : '📞 Teléfono para confirmar: ${candidatoSeleccionado!["telefono"] ?? "No registrado"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (candidatoSeleccionado!['alerta_resurtimiento_activa'] == true) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonAmber, lightAlpha: 0.22, darkAlpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ts.neonAmber),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notification_important, color: ts.neonAmber, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    candidatoSeleccionado!['mensaje_alerta_resurtimiento'] ??
                                        '🔔 Sugerir resurtimiento de tratamiento crónico al paciente.',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.neonAmber),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed: () => setModalState(() => candidatoSeleccionado = null),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ts.accentPrimary,
                                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                              ),
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Confirmar y Asignar Cliente', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                final elegido = candidatoSeleccionado!;
                                Navigator.of(ctx).pop();
                                onClienteSeleccionado(elegido);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cliente "${elegido["nombre"]} ${elegido["apellido"]}" confirmado y asignado.',
                                      ),
                                      backgroundColor: ts.neonGreen,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          ],
        );
      },
    ),
  );
}
