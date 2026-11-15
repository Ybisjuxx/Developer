import 'package:flutter/foundation.dart';
import 'api_service.dart';

class UsuarioSesion {
  final int id;
  final String username;
  final String nombreCompleto;
  final String rol; // CAJERO, ADMINISTRADOR, RESPONSABLE_SANITARIO
  final bool activo;

  const UsuarioSesion({
    required this.id,
    required this.username,
    required this.nombreCompleto,
    required this.rol,
    this.activo = true,
  });

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    return UsuarioSesion(
      id: json['id'] ?? 1,
      username: json['username'] ?? 'usuario',
      nombreCompleto: json['nombre_completo'] ?? 'Usuario General',
      rol: (json['rol'] ?? 'CAJERO').toString().toUpperCase().trim(),
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nombre_completo': nombreCompleto,
    'rol': rol,
    'activo': activo,
  };
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UsuarioSesion? _usuarioActual;
  String? _token;

  bool get isAuthenticated => _usuarioActual != null && _token != null && _token!.isNotEmpty;
  String? get token => _token;

  UsuarioSesion get usuarioActual =>
      _usuarioActual ??
      const UsuarioSesion(
        id: 0,
        username: 'anonimo',
        nombreCompleto: 'Sin Sesión Activa',
        rol: '',
      );

  static UsuarioSesion get currentUser => _instance.usuarioActual;
  static String? get currentToken => _instance.token;

  bool get isAdmin => usuarioActual.rol == 'ADMINISTRADOR';
  bool get isSanitario => usuarioActual.rol == 'RESPONSABLE_SANITARIO' || isAdmin;
  bool get isCajero => usuarioActual.rol == 'CAJERO' || isAdmin;
  String get currentRol => usuarioActual.rol;

  // Lista de perfiles rápidos para demostración y auditoría
  static const List<UsuarioSesion> usuariosDemostracion = [
    UsuarioSesion(
      id: 1,
      username: 'admin',
      nombreCompleto: 'Lic. Alejandro Mendoza',
      rol: 'ADMINISTRADOR',
    ),
    UsuarioSesion(
      id: 2,
      username: 'cajero',
      nombreCompleto: 'Juan Daniel Morales',
      rol: 'CAJERO',
    ),
    UsuarioSesion(
      id: 3,
      username: 'sanitario',
      nombreCompleto: 'Dra. Carmen Sofía Morales',
      rol: 'RESPONSABLE_SANITARIO',
    ),
  ];

  static const Map<String, String> credencialesDemostracion = {
    'admin': 'admin123',
    'cajero': 'caja123',
    'sanitario': 'resp123',
  };

  /// Autentica con el backend mediante credenciales reales, almacena el token firmado Bearer
  Future<void> login(String username, String password) async {
    final data = await ApiService.login(username.trim(), password);
    final String? tokenRecibido = data['access_token'];
    final dynamic userData = data['usuario'];

    if (tokenRecibido == null || tokenRecibido.isEmpty) {
      throw Exception('El servidor no retornó un token de acceso válido.');
    }

    _token = tokenRecibido;
    ApiService.authToken = tokenRecibido;

    if (userData != null && userData is Map) {
      _usuarioActual = UsuarioSesion.fromJson(Map<String, dynamic>.from(userData));
    } else {
      _usuarioActual = UsuarioSesion(
        id: 1,
        username: username,
        nombreCompleto: username,
        rol: 'ADMINISTRADOR',
      );
    }

    notifyListeners();
  }

  /// Cierra la sesión activa, revoca el token en backend y limpia la memoria
  void logout() {
    if (_token != null && _token!.isNotEmpty) {
      ApiService.logout();
    }
    _token = null;
    _usuarioActual = null;
    ApiService.authToken = null;
    notifyListeners();
  }

  /// Inicio de sesión rápido para pruebas de auditoría y demostración de roles (deshabilitado en Release)
  Future<void> loginRapidoDemo(String username) async {
    if (kReleaseMode) {
      throw Exception('El acceso rápido de demostración está deshabilitado en producción.');
    }
    final password = credencialesDemostracion[username] ?? 'admin123';
    try {
      await login(username, password);
    } catch (_) {
      final demo = usuariosDemostracion.firstWhere(
        (u) => u.username == username,
        orElse: () => UsuarioSesion(
          id: 1,
          username: username,
          nombreCompleto: username,
          rol: 'ADMINISTRADOR',
        ),
      );
      _token = 'demo_token_${demo.username}';
      ApiService.authToken = _token;
      _usuarioActual = demo;
      notifyListeners();
    }
  }

  /// Método retrocompatible para cambio de usuario
  void cambiarUsuario(UsuarioSesion nuevoUsuario) {
    _usuarioActual = nuevoUsuario;
    notifyListeners();
  }
}
