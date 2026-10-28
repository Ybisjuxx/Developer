import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/medico.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // =========================================================================
  // AUTENTICACIÓN Y USUARIOS
  // =========================================================================
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error de autenticación');
    }
  }

  static Future<List<dynamic>> getUsuarios({bool soloActivos = false}) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios').replace(
      queryParameters: {'solo_activos': soloActivos.toString()},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener usuarios: ${response.statusCode}');
    }
  }

  // =========================================================================
  // CORTES DE CAJA Y TURNOS
  // =========================================================================
  static Future<Map<String, dynamic>?> getTurnoActivo() async {
    final uri = Uri.parse('$baseUrl/api/caja/turno-activo');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al verificar turno activo: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> abrirTurno({
    required String cajeroNombre,
    required double montoApertura,
    int? usuarioId,
    String? notas,
  }) async {
    final uri = Uri.parse('$baseUrl/api/caja/abrir');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cajero_nombre': cajeroNombre,
        'monto_apertura': montoApertura,
        'usuario_id': usuarioId,
        'notas': notas,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al abrir turno');
    }
  }

  static Future<Map<String, dynamic>> getResumenTurno() async {
    final uri = Uri.parse('$baseUrl/api/caja/resumen');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al obtener resumen de caja');
    }
  }

  static Future<Map<String, dynamic>> cerrarTurno({
    required double montoCierreEfectivo,
    String? notas,
  }) async {
    final uri = Uri.parse('$baseUrl/api/caja/cerrar');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'monto_cierre_efectivo': montoCierreEfectivo,
        'notas': notas,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al cerrar turno');
    }
  }

  static Future<List<dynamic>> getHistorialTurnos() async {
    final uri = Uri.parse('$baseUrl/api/caja/historial');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener historial de turnos: ${response.statusCode}');
    }
  }

  // =========================================================================
  // DEVOLUCIONES Y MERMAS
  // =========================================================================
  static Future<Map<String, dynamic>> registrarDevolucion(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/devoluciones/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al procesar devolución');
    }
  }

  static Future<List<dynamic>> getDevoluciones() async {
    final uri = Uri.parse('$baseUrl/api/devoluciones/');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener devoluciones: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getMermas() async {
    final uri = Uri.parse('$baseUrl/api/devoluciones/mermas');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener mermas: ${response.statusCode}');
    }
  }

  // =========================================================================
  // MÉDICOS
  // =========================================================================
  static Future<List<Medico>> getMedicos({String? query, bool soloVigentes = false}) async {
    final uri = Uri.parse('$baseUrl/api/medicos/').replace(
      queryParameters: {
        'solo_vigentes': soloVigentes.toString(),
        if (query != null && query.isNotEmpty) 'buscar': query,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Medico.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener médicos: ${response.statusCode}');
    }
  }

  static Future<Medico> createMedico(Medico medico) async {
    final uri = Uri.parse('$baseUrl/api/medicos/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(medico.toJson()),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Medico.fromJson(data);
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = errorData['detail'] ?? 'Error desconocido del servidor';
      throw Exception(detail);
    }
  }

  // =========================================================================
  // INVENTARIO / PRODUCTOS / LOTES / KARDEX
  // =========================================================================
  static Future<List<dynamic>> getProductos({String? buscar}) async {
    final uri = Uri.parse('$baseUrl/api/inventario/productos').replace(
      queryParameters: {
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener productos: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/inventario/productos');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al crear producto');
    }
  }

  static Future<Map<String, dynamic>> createLote(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/inventario/lotes');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al registrar lote');
    }
  }

  static Future<List<dynamic>> getKardex() async {
    final uri = Uri.parse('$baseUrl/api/inventario/kardex');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener kardex: ${response.statusCode}');
    }
  }

  // =========================================================================
  // VENTAS Y COBRANZA
  // =========================================================================
  static Future<List<dynamic>> getVentas() async {
    final uri = Uri.parse('$baseUrl/api/ventas/');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener ventas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> registrarVenta(Map<String, dynamic> ventaData) async {
    final uri = Uri.parse('$baseUrl/api/ventas/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(ventaData),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al procesar la venta');
    }
  }

  // =========================================================================
  // ENFERMEDADES (CIE-10)
  // =========================================================================
  static Future<List<dynamic>> getEnfermedades({String? buscar}) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/').replace(
      queryParameters: {
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener enfermedades: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createEnfermedad(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al crear enfermedad');
    }
  }

  static Future<List<dynamic>> buscarCatalogoCIE(String query, {int limit = 30}) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/catalogo-cie/buscar').replace(
      queryParameters: {
        'q': query,
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al buscar en catálogo CIE');
    }
  }

  static Future<Map<String, dynamic>> importarDesdeCatalogoCIE(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/catalogo-cie/importar');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al importar diagnóstico');
    }
  }

  static Future<Map<String, dynamic>> autoRegistrarEnfermedad(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/auto-registrar');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al auto-registrar diagnóstico');
    }
  }

  // =========================================================================
  // SUB-AGENTE 1 & 2: CLIENTES E HISTORIAL CLÍNICO
  // =========================================================================
  static Future<List<dynamic>> getClientes({String? buscar, bool soloActivos = true}) async {
    final uri = Uri.parse('$baseUrl/api/clientes/').replace(
      queryParameters: {
        'solo_activos': soloActivos.toString(),
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener clientes: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getCliente(int id) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener cliente: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createCliente(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/clientes/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al registrar cliente');
    }
  }

  static Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al actualizar cliente');
    }
  }

  static Future<void> desactivarCliente(int id) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await http.delete(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al desactivar cliente: ${response.statusCode}');
    }
  }

  // =========================================================================
  // SUB-AGENTE 3: AJUSTE Y BAJA DE LOTES
  // =========================================================================
  static Future<Map<String, dynamic>> ajustarStockLote(
    int loteId, {
    required int nuevoStock,
    required String motivo,
    required String usuario,
    required String rolUsuario,
  }) async {
    final uri = Uri.parse('$baseUrl/api/inventario/lotes/$loteId/ajuste');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nuevo_stock': nuevoStock,
        'motivo': motivo,
        'usuario': usuario,
        'rol_usuario': rolUsuario,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al ajustar stock');
    }
  }

  static Future<Map<String, dynamic>> darDeBajaLote(
    int loteId, {
    required String motivo,
    required String usuario,
    required String rolUsuario,
  }) async {
    final uri = Uri.parse('$baseUrl/api/inventario/lotes/$loteId/baja');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'motivo': motivo,
        'usuario': usuario,
        'rol_usuario': rolUsuario,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al dar de baja lote');
    }
  }

  // =========================================================================
  // SUB-AGENTE 4: USUARIOS EN CONFIGURACIÓN
  // =========================================================================

  static Future<Map<String, dynamic>> createUsuario(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al crear usuario');
    }
  }

  static Future<Map<String, dynamic>> updateUsuario(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios/$id');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al actualizar usuario');
    }
  }

  static Future<void> desactivarUsuario(int id) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios/$id');
    final response = await http.delete(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al desactivar usuario: ${response.statusCode}');
    }
  }

  // =========================================================================
  // SUB-AGENTE 5: AUDITORÍA DE KARDEX Y COMENTARIOS
  // =========================================================================
  static Future<Map<String, dynamic>> agregarObservacionKardex(
    int movimientoId, {
    required String observaciones,
    required bool esIrregular,
    String? usuarioAuditor,
  }) async {
    final uri = Uri.parse('$baseUrl/api/inventario/kardex/$movimientoId/observaciones');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'observaciones': observaciones,
        'es_irregular': esIrregular,
        'usuario_auditor': usuarioAuditor,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al agregar observación al kardex');
    }
  }

  // =========================================================================
  // NUEVAS FUNCIONALIDADES v1.2.0: CADUCIDADES, REPORTE MENSUAL E IA
  // =========================================================================
  static Future<List<dynamic>> getLotesCaducidades({int dias = 90, bool incluirCaducados = true}) async {
    final uri = Uri.parse('$baseUrl/api/inventario/lotes/caducidades').replace(
      queryParameters: {
        'dias': dias.toString(),
        'incluir_caducados': incluirCaducados.toString(),
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener lotes con riesgo de caducidad: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getReporteVentasMensual({int? anio}) async {
    final Map<String, String> queryParams = {};
    if (anio != null) {
      queryParams['anio'] = anio.toString();
    }
    final uri = Uri.parse('$baseUrl/api/ventas/reporte-mensual').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener reporte mensual de ventas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> consultarIaMedicamentos(
    String consulta, {
    List<Map<String, dynamic>>? historial,
  }) async {
    final uri = Uri.parse('$baseUrl/api/ia/consulta-medicamento');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'consulta': consulta,
        'historial': historial,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al consultar asistente IA');
    }
  }
}


