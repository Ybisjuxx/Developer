import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/medico.dart';
import 'auth_service.dart';

class ApiService {
  static bool _esIpLan(String host) {
    return host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(host);
  }

  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8000';
      }
      if (_esIpLan(host)) {
        return 'http://$host:8000';
      }
      if (host.endsWith('.lhr.life') ||
          host.endsWith('.localhost.run') ||
          host.endsWith('.loca.lt') ||
          host.endsWith('.trycloudflare.com') ||
          host.endsWith('.serveo.net')) {
        return Uri.base.origin;
      }
      return 'https://developer-80fs.onrender.com';
    }
    try {
      if (Platform.isAndroid) {
        return 'https://developer-80fs.onrender.com';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // =========================================================================
  // GESTIÓN CENTRALIZADA DE CABECERAS, AUTORIZACIÓN BEARER Y PETICIONES HTTP
  // =========================================================================
  static String? authToken;

  static Map<String, String> _headers({bool isJson = false, Map<String, String>? extra}) {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = authToken ?? AuthService().token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  static http.Response _checkAuth(http.Response response, {bool isAuthEndpoint = false}) {
    if (response.statusCode == 401 && !isAuthEndpoint) {
      AuthService().logout();
    }
    return response;
  }

  static Future<http.Response> _get(Uri uri, {Duration timeout = const Duration(seconds: 10)}) async {
    final res = await http.get(uri, headers: _headers()).timeout(timeout);
    return _checkAuth(res);
  }

  static Future<http.Response> _post(
    Uri uri, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
    bool isAuthEndpoint = false,
  }) async {
    final res = await http.post(
      uri,
      headers: _headers(isJson: body != null),
      body: body,
    ).timeout(timeout);
    return _checkAuth(res, isAuthEndpoint: isAuthEndpoint);
  }

  static Future<http.Response> _put(
    Uri uri, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = await http.put(
      uri,
      headers: _headers(isJson: body != null),
      body: body,
    ).timeout(timeout);
    return _checkAuth(res);
  }

  static Future<http.Response> _delete(Uri uri, {Duration timeout = const Duration(seconds: 10)}) async {
    final res = await http.delete(uri, headers: _headers()).timeout(timeout);
    return _checkAuth(res);
  }



  // =========================================================================
  // AUTENTICACIÓN Y USUARIOS
  // =========================================================================
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final response = await _post(
      uri,
      body: jsonEncode({'username': username, 'password': password}),
      isAuthEndpoint: true,
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error de autenticación');
    }
  }

  static Future<void> logout() async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/logout');
      await _post(uri, isAuthEndpoint: true);
    } catch (_) {
      // Si el backend no responde, el cierre local continúa sin bloquear al usuario
    }
  }

  static Future<List<dynamic>> getUsuarios({bool soloActivos = false}) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios').replace(
      queryParameters: {'solo_activos': soloActivos.toString()},
    );
    final response = await _get(uri);
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
    final response = await _get(uri);
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
    final response = await _post(
      uri,
      body: jsonEncode({
        'cajero_nombre': cajeroNombre,
        'monto_apertura': montoApertura,
        'usuario_id': usuarioId,
        'notas': notas,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al abrir turno');
    }
  }

  static Future<Map<String, dynamic>> getResumenTurno() async {
    final uri = Uri.parse('$baseUrl/api/caja/resumen');
    final response = await _get(uri);
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
    final response = await _post(
      uri,
      body: jsonEncode({
        'monto_cierre_efectivo': montoCierreEfectivo,
        'notas': notas,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al cerrar turno');
    }
  }

  static Future<List<dynamic>> getHistorialTurnos() async {
    final uri = Uri.parse('$baseUrl/api/caja/historial');
    final response = await _get(uri);
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
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al procesar devolución');
    }
  }

  static Future<List<dynamic>> getDevoluciones() async {
    final uri = Uri.parse('$baseUrl/api/devoluciones/');
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener devoluciones: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getMermas() async {
    final uri = Uri.parse('$baseUrl/api/devoluciones/mermas');
    final response = await _get(uri);
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

    final response = await _get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Medico.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener médicos: ${response.statusCode}');
    }
  }

  static Future<Medico> createMedico(Medico medico) async {
    final uri = Uri.parse('$baseUrl/api/medicos/');
    final response = await _post(
      uri,
      body: jsonEncode(medico.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Medico.fromJson(data);
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = errorData['detail'] ?? 'Error desconocido del servidor';
      throw Exception(detail);
    }
  }

  static Future<Medico> updateMedico(int id, Medico medico) async {
    final uri = Uri.parse('$baseUrl/api/medicos/$id');
    final response = await _put(
      uri,
      body: jsonEncode(medico.toJson()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Medico.fromJson(data);
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = errorData['detail'] ?? 'Error al actualizar médico';
      throw Exception(detail);
    }
  }

  static Future<Map<String, dynamic>> deleteMedico(int id, {bool permanente = false}) async {
    final uri = Uri.parse('$baseUrl/api/medicos/$id?permanente=$permanente');
    final response = await _delete(uri);

    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isNotEmpty) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'mensaje': 'Médico eliminado/desactivado correctamente'};
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al eliminar médico');
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
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener productos: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/inventario/productos');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al crear producto');
    }
  }

  static Future<Map<String, dynamic>> createLote(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/inventario/lotes');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al registrar lote');
    }
  }

  static Future<List<dynamic>> getKardex({int limit = 300}) async {
    final uri = Uri.parse('$baseUrl/api/inventario/kardex?limit=$limit');
    final response = await _get(uri);
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
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener ventas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> registrarVenta(Map<String, dynamic> ventaData) async {
    final uri = Uri.parse('$baseUrl/api/ventas/');
    final response = await _post(
      uri,
      body: jsonEncode(ventaData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al procesar la venta');
    }
  }

  static Future<Map<String, dynamic>> buscarVentaPorTicket(String folioTicket) async {
    final uri = Uri.parse('$baseUrl/api/ventas/ticket/${Uri.encodeComponent(folioTicket.trim())}');
    final response = await _get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Ticket no encontrado');
    }
  }

  static Future<Map<String, dynamic>> generarFacturaVenta(int ventaId, Map<String, dynamic> datosFiscales) async {
    final uri = Uri.parse('$baseUrl/api/ventas/$ventaId/facturar');
    final response = await _post(
      uri,
      body: jsonEncode(datosFiscales),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al emitir factura electrónica');
    }
  }

  static Future<Map<String, dynamic>> obtenerFacturaVenta(int ventaId) async {
    final uri = Uri.parse('$baseUrl/api/ventas/$ventaId/factura');
    final response = await _get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al consultar factura');
    }
  }

  static Future<String> descargarXmlFactura(int ventaId) async {
    final uri = Uri.parse('$baseUrl/api/ventas/$ventaId/factura/xml');
    final response = await _get(uri);

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al descargar XML');
    }
  }

  static Future<Map<String, dynamic>?> buscarProductoPorCodigo(String codigoBarras) async {
    final uri = Uri.parse('$baseUrl/api/inventario/productos/buscar-codigo/${Uri.encodeComponent(codigoBarras.trim())}');
    final response = await _get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al verificar código de barras');
    }
  }

  // =========================================================================
  // ENFERMEDADES (CIE-11)
  // =========================================================================
  static Future<List<dynamic>> getEnfermedades({String? buscar}) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/').replace(
      queryParameters: {
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      },
    );
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener enfermedades: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createEnfermedad(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

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
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al buscar en catálogo CIE');
    }
  }

  static Future<Map<String, dynamic>> importarDesdeCatalogoCIE(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/catalogo-cie/importar');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al importar diagnóstico');
    }
  }

  static Future<Map<String, dynamic>> autoRegistrarEnfermedad(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/enfermedades/auto-registrar');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

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
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener clientes: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getCliente(int id) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener cliente: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createCliente(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/clientes/');
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al registrar cliente');
    }
  }

  static Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await _put(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al actualizar cliente');
    }
  }

  static Future<void> desactivarCliente(int id) async {
    final uri = Uri.parse('$baseUrl/api/clientes/$id');
    final response = await _delete(uri);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al desactivar cliente: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getClientesConAlertaResurtimiento() async {
    final uri = Uri.parse('$baseUrl/api/clientes/alertas-resurtimiento');
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener alertas de resurtimiento: ${response.statusCode}');
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
    final response = await _post(
      uri,
      body: jsonEncode({
        'nuevo_stock': nuevoStock,
        'motivo': motivo,
        'usuario': usuario,
        'rol_usuario': rolUsuario,
      }),
    );

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
    final response = await _post(
      uri,
      body: jsonEncode({
        'motivo': motivo,
        'usuario': usuario,
        'rol_usuario': rolUsuario,
      }),
    );

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
    final response = await _post(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al crear usuario');
    }
  }

  static Future<Map<String, dynamic>> updateUsuario(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios/$id');
    final response = await _put(
      uri,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al actualizar usuario');
    }
  }

  static Future<void> desactivarUsuario(int id) async {
    final uri = Uri.parse('$baseUrl/api/auth/usuarios/$id');
    final response = await _delete(uri);
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
    final response = await _post(
      uri,
      body: jsonEncode({
        'observaciones': observaciones,
        'es_irregular': esIrregular,
        'usuario_auditor': usuarioAuditor,
      }),
    );

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
    final response = await _get(uri);
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
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener reporte mensual de ventas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getIndicadoresMensuales({int? anio, int? mes}) async {
    final Map<String, String> queryParams = {};
    if (anio != null) {
      queryParams['anio'] = anio.toString();
    }
    if (mes != null) {
      queryParams['mes'] = mes.toString();
    }
    final uri = Uri.parse('$baseUrl/api/reportes/indicadores-mensuales').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Error al obtener indicadores mensuales: ${response.statusCode}');
    }
  }

  static Future<String> descargarReporteMensualCsv({
    int? anio,
    int? mes,
    String? area,
  }) async {
    final Map<String, String> queryParams = {'formato': 'csv'};
    if (anio != null) {
      queryParams['anio'] = anio.toString();
    }
    if (mes != null) {
      queryParams['mes'] = mes.toString();
    }
    if (area != null && area.trim().isNotEmpty) {
      queryParams['area'] = area.trim();
    }
    final uri = Uri.parse('$baseUrl/api/reportes/indicadores-mensuales/descargar').replace(
      queryParameters: queryParams,
    );
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('Error al descargar reporte mensual CSV: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> consultarIaMedicamentos(
    String consulta, {
    List<Map<String, dynamic>>? historial,
  }) async {
    final uri = Uri.parse('$baseUrl/api/ia/consulta-medicamento');
    final response = await _post(
      uri,
      body: jsonEncode({
        'consulta': consulta,
        'historial': historial,
      }),
      timeout: const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorData['detail'] ?? 'Error al consultar asistente IA');
    }
  }

  static Future<List<dynamic>> getBitacoraCofepris({int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/reportes/bitacora-cofepris?limit=$limit');
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Error al cargar bitácora COFEPRIS: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> registrarBitacoraCofepris(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/reportes/bitacora-cofepris');
    final response = await _post(uri, body: jsonEncode(data));
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    final err = jsonDecode(utf8.decode(response.bodyBytes));
    throw Exception(err['detail'] ?? 'Error al registrar lectura ambiental');
  }

  static Future<List<dynamic>> getDocumentosSanitarios() async {
    final uri = Uri.parse('$baseUrl/api/reportes/documentos-sanitarios');
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Error al cargar documentos sanitarios: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> registrarDocumentoSanitario(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/reportes/documentos-sanitarios');
    final response = await _post(uri, body: jsonEncode(data));
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    final err = jsonDecode(utf8.decode(response.bodyBytes));
    throw Exception(err['detail'] ?? 'Error al guardar documento sanitario');
  }

  static Future<Map<String, dynamic>> getParametrosFinancieros({int? anio, int? mes}) async {
    final now = DateTime.now();
    final uri = Uri.parse('$baseUrl/api/reportes/parametros-financieros').replace(
      queryParameters: {
        'anio': (anio ?? now.year).toString(),
        'mes': (mes ?? now.month).toString(),
      },
    );
    final response = await _get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Error al cargar parámetros financieros: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> actualizarParametrosFinancieros(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/reportes/parametros-financieros');
    final response = await _put(uri, body: jsonEncode(data));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    final err = jsonDecode(utf8.decode(response.bodyBytes));
    throw Exception(err['detail'] ?? 'Error al actualizar parámetros financieros');
  }
}
