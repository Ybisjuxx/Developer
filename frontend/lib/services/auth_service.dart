import 'package:flutter/foundation.dart';

class UsuarioSesion {
  final int id;
  final String username;
  final String nombreCompleto;
  final String rol; // CAJERO, ADMINISTRADOR, RESPONSABLE_SANITARIO

  const UsuarioSesion({
    required this.id,
    required this.username,
    required this.nombreCompleto,
    required this.rol,
  });

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    return UsuarioSesion(
      id: json['id'] ?? 1,
      username: json['username'] ?? 'usuario',
      nombreCompleto: json['nombre_completo'] ?? 'Usuario General',
      rol: json['rol'] ?? 'CAJERO',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nombre_completo': nombreCompleto,
    'rol': rol,
  };
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UsuarioSesion _usuarioActual = const UsuarioSesion(
    id: 1,
    username: 'admin',
    nombreCompleto: 'Lic. Alejandro Mendoza',
    rol: 'ADMINISTRADOR',
  );

  UsuarioSesion get usuarioActual => _usuarioActual;
  static UsuarioSesion get currentUser => _instance.usuarioActual;


  bool get isAdmin => _usuarioActual.rol == 'ADMINISTRADOR';
  bool get isSanitario => _usuarioActual.rol == 'RESPONSABLE_SANITARIO' || isAdmin;
  bool get isCajero => _usuarioActual.rol == 'CAJERO' || isAdmin;

  // Lista de perfiles rápidos para demostración y cambio ágil
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

  void cambiarUsuario(UsuarioSesion nuevoUsuario) {
    _usuarioActual = nuevoUsuario;
    notifyListeners();
  }
}
