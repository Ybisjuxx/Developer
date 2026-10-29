class Medico {
  final int? id;
  final String nombres;
  final String apellidos;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String cedulaProfesional;
  final String? especialidad;
  final String? institucionEmisora;
  final String? telefono;
  final String? correo;
  final bool vigente;
  final String? createdAt;

  Medico({
    this.id,
    required this.nombres,
    required this.apellidos,
    this.apellidoPaterno,
    this.apellidoMaterno,
    required this.cedulaProfesional,
    this.especialidad,
    this.institucionEmisora,
    this.telefono,
    this.correo,
    this.vigente = true,
    this.createdAt,
  });

  factory Medico.fromJson(Map<String, dynamic> json) {
    return Medico(
      id: json['id'] as int?,
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      apellidoPaterno: json['apellido_paterno'],
      apellidoMaterno: json['apellido_materno'],
      cedulaProfesional: json['cedula_profesional'] ?? '',
      especialidad: json['especialidad'],
      institucionEmisora: json['institucion_emisora'],
      telefono: json['telefono'],
      correo: json['correo'],
      vigente: json['vigente'] ?? true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    final pat = apellidoPaterno?.trim() ?? '';
    final mat = apellidoMaterno?.trim() ?? '';
    final consolidado = ('$pat $mat').trim();

    return {
      'nombres': nombres,
      'apellidos': consolidado.isNotEmpty ? consolidado : apellidos,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'cedula_profesional': cedulaProfesional,
      'especialidad': especialidad,
      'institucion_emisora': institucionEmisora,
      'telefono': telefono,
      'correo': correo,
      'vigente': vigente,
    };
  }

  String get nombreCompleto {
    final aps = '${apellidoPaterno ?? ""} ${apellidoMaterno ?? ""}'.trim();
    if (aps.isNotEmpty) return '$nombres $aps'.trim();
    return '$nombres $apellidos'.trim();
  }
}
