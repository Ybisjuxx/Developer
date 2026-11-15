import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarLogin([String? usuarioCustom, String? passwordCustom]) async {
    final usuario = (usuarioCustom ?? _usernameController.text).trim();
    final password = passwordCustom ?? _passwordController.text;

    if (usuarioCustom == null && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().login(usuario, password);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _ingresoRapidoDemo(String username) async {
    final password = AuthService.credencialesDemostracion[username] ?? 'admin123';
    _usernameController.text = username;
    _passwordController.text = password;
    await _ejecutarLogin(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final ts = ThemeService.instance;

    return Scaffold(
      backgroundColor: ts.esOscuro ? ts.scaffoldBg : const Color(0xFFF0FDF4),
      body: BackgroundLines(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: ts.esTemaNeon ? 0 : 8,
                shadowColor: ts.accentPrimary.withValues(alpha: 0.20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: ts.esOscuro
                        ? ts.accentPrimary.withValues(alpha: 0.35)
                        : ts.accentPrimary.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                color: ts.cardBg.withValues(alpha: ts.esOscuro ? 0.88 : 0.93),
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado y Logotipo FarmaControl
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ts.tintBg(ts.accentPrimary, lightAlpha: 0.10, darkAlpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: ts.accentPrimary.withValues(alpha: 0.45), width: 2),
                          ),
                          child: Icon(
                            Icons.local_pharmacy,
                            size: 40,
                            color: ts.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FarmaControl',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: ts.esOscuro ? ts.textPrimary : const Color(0xFF134E4A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                'v1.4.8',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ts.accentPrimary,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.14, darkAlpha: 0.22),
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Sistema Integral de Gestión Farmacéutica',
                          style: TextStyle(
                            fontSize: 12,
                            color: ts.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Banner de error si las credenciales fallan
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Campo Usuario
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de Usuario',
                          hintText: 'Ej. admin, cajero, sanitario',
                          prefixIcon: Icon(Icons.person_outline, color: ts.accentPrimary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: ts.surfaceBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu nombre de usuario';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Campo Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline, color: ts.accentPrimary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: ts.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: ts.surfaceBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _ejecutarLogin(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Botón Principal de Inicio de Sesión
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ts.accentPrimary,
                          foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                        ),
                        onPressed: _isLoading ? null : () => _ejecutarLogin(),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ts.esTemaNeon ? Colors.black : Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Divisor con etiqueta de auditoría / demo
                      Row(
                        children: [
                          Expanded(child: Divider(color: ts.borderColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'ACCESO RÁPIDO / AUDITORÍA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ts.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: ts.borderColor)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Botones de Acceso Rápido por Perfil para Auditoría
                      _botonAccesoRapido(
                        titulo: 'Administrador (Control Total)',
                        subtitulo: 'admin · admin123',
                        icono: Icons.admin_panel_settings,
                        color: ts.neonPurple,
                        backgroundColor: ts.tintBg(ts.neonPurple),
                        onTap: () => _ingresoRapidoDemo('admin'),
                      ),
                      const SizedBox(height: 8),
                      _botonAccesoRapido(
                        titulo: 'Cajero (Punto de Venta y Turnos)',
                        subtitulo: 'cajero · caja123',
                        icono: Icons.point_of_sale,
                        color: ts.accentPrimary,
                        backgroundColor: ts.tintBg(ts.accentPrimary),
                        onTap: () => _ingresoRapidoDemo('cajero'),
                      ),
                      const SizedBox(height: 8),
                      _botonAccesoRapido(
                        titulo: 'Responsable Sanitario (Kardex y Lotes)',
                        subtitulo: 'sanitario · resp123',
                        icono: Icons.medical_services,
                        color: ts.neonBlue,
                        backgroundColor: ts.tintBg(ts.neonBlue),
                        onTap: () => _ingresoRapidoDemo('sanitario'),
                      ),

                      const SizedBox(height: 20),

                      // Indicador de Servidor Backend
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: ts.surfaceAltBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ts.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: ts.neonGreen),
                              const SizedBox(width: 6),
                              Text(
                                'Servidor: ${ApiService.baseUrl}',
                                style: TextStyle(fontSize: 10, color: ts.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _botonAccesoRapido({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icono, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 10,
                      color: ThemeService.instance.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}
