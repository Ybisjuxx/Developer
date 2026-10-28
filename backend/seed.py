import datetime
import hashlib
from app.database import Base, SessionLocal, engine
from app.models import Cliente, Enfermedad, KardexMovimiento, Lote, Medico, Producto, TurnoCaja, Usuario


def hash_pw(pw: str) -> str:
    return hashlib.sha256(pw.encode("utf-8")).hexdigest()


def seed_database():
    print("Iniciando creación de tablas en SQLite...")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # 1. Sembrar Usuarios y Roles
        if db.query(Usuario).count() == 0:
            print("Sembrando usuarios por roles (Cajero, Administrador, Responsable Sanitario)...")
            u1 = Usuario(
                username="admin",
                password_hash=hash_pw("admin123"),
                nombre_completo="Lic. Alejandro Mendoza",
                rol="ADMINISTRADOR",
                activo=True,
            )
            u2 = Usuario(
                username="cajero",
                password_hash=hash_pw("caja123"),
                nombre_completo="Juan Daniel Morales",
                rol="CAJERO",
                activo=True,
            )
            u3 = Usuario(
                username="sanitario",
                password_hash=hash_pw("resp123"),
                nombre_completo="QFB Dra. Carmen Sofía Morales",
                rol="RESPONSABLE_SANITARIO",
                activo=True,
            )
            db.add_all([u1, u2, u3])
            db.commit()

        # 2. Sembrar Turno de Caja Abierto Inicial
        if db.query(TurnoCaja).count() == 0:
            print("Sembrando turno de caja matutino con fondo inicial...")
            cajero_user = db.query(Usuario).filter(Usuario.username == "cajero").first()
            turno_inicial = TurnoCaja(
                usuario_id=cajero_user.id if cajero_user else None,
                cajero_nombre="Juan Daniel Morales",
                monto_apertura=1000.0,
                fecha_apertura=datetime.datetime.utcnow(),
                ventas_efectivo=0.0,
                ventas_tarjeta=0.0,
                ventas_transferencia=0.0,
                total_ventas=0.0,
                estado="ABIERTO",
                notas="Turno matutino de apertura con fondo de cambio $1,000 MXN",
            )
            db.add(turno_inicial)
            db.commit()

        # 3. Sembrar Médicos
        if db.query(Medico).count() == 0:
            print("Sembrando médicos...")
            m1 = Medico(
                nombres="Roberto Carlos",
                apellidos="Hernández Gómez",
                cedula_profesional="11223344",
                especialidad="Medicina General",
                institucion_emisora="UNAM",
                telefono="5551234567",
                correo="dr.roberto@farmacia.com",
                vigente=True,
            )
            m2 = Medico(
                nombres="Carmen Sofía",
                apellidos="Morales Peña",
                cedula_profesional="99887766",
                especialidad="Pediatría",
                institucion_emisora="IPN",
                telefono="5559876543",
                correo="dra.morales@hospital.org",
                vigente=True,
            )
            db.add_all([m1, m2])
            db.commit()

        # 4. Sembrar Enfermedades (CIE-10)
        if db.query(Enfermedad).count() == 0:
            print("Sembrando enfermedades CIE-10...")
            enfermedades = [
                Enfermedad(codigo_cie="J00", descripcion="Rinofaringitis aguda (resfriado común)", categoria="Infecciones respiratorias", comentarios_especiales="Evaluar si requiere sintomático"),
                Enfermedad(codigo_cie="A09", descripcion="Gastroenteritis y colitis de origen infeccioso", categoria="Infecciones gastrointestinales", comentarios_especiales="Priorizar hidratación oral"),
                Enfermedad(codigo_cie="I10", descripcion="Hipertensión esencial (primaria)", categoria="Cardiovascular", comentarios_especiales="Monitoreo de presión arterial"),
                Enfermedad(codigo_cie="E11", descripcion="Diabetes mellitus tipo 2", categoria="Endocrino y metabólico", comentarios_especiales="Verificar apego a hipoglucemiantes orales"),
            ]
            db.add_all(enfermedades)
            db.commit()

        # 4.1 Sembrar Clientes Registrados con Historial Clínico (Diagnósticos CIE)
        if db.query(Cliente).count() == 0:
            print("Sembrando clientes de lealtad con historial clínico (CIE-10)...")
            cie_i10 = db.query(Enfermedad).filter(Enfermedad.codigo_cie == "I10").first()
            cie_e11 = db.query(Enfermedad).filter(Enfermedad.codigo_cie == "E11").first()
            cie_j45 = db.query(Enfermedad).filter(Enfermedad.codigo_cie == "J45").first()

            c1 = Cliente(
                nombre="Roberto",
                apellido="Morales Peña",
                correo_electronico="roberto.morales@gmail.com",
                telefono="555-321-7890",
                direccion="Av. Universidad 120, Col. del Valle",
                descuento_porcentaje=5.0,
                notas_clinicas="Paciente con hipertensión y diabetes en control. Monitorear cifras tensionales.",
                activo=True,
            )
            if cie_i10:
                c1.enfermedades.append(cie_i10)
            if cie_e11:
                c1.enfermedades.append(cie_e11)

            c2 = Cliente(
                nombre="María Elena",
                apellido="Gómez Fuentes",
                correo_electronico="elena.gomez@hotmail.com",
                telefono="555-654-1122",
                direccion="Calle Juárez 45, Centro",
                descuento_porcentaje=10.0,
                notas_clinicas="Alergia a betalactámicos. Diagnóstico de Asma bronquial.",
                activo=True,
            )
            if cie_j45:
                c2.enfermedades.append(cie_j45)

            c3 = Cliente(
                nombre="Carlos",
                apellido="Santana Vega",
                correo_electronico=None,
                telefono="555-888-9900",
                direccion="Privada Las Flores 8",
                descuento_porcentaje=5.0,
                notas_clinicas=None,
                activo=True,
            )

            db.add_all([c1, c2, c3])
            db.commit()

        # 5. Sembrar Catálogo Completo de 100 Medicamentos y Lotes con Caducidades
        from app.catalogo_medicamentos import MEDICAMENTOS_100
        hoy = datetime.date.today()
        productos_creados = 0
        lotes_creados = 0

        print(f"Sembrando catálogo maestro de {len(MEDICAMENTOS_100)} medicamentos...")
        for item in MEDICAMENTOS_100:
            prod = db.query(Producto).filter(Producto.codigo_barras == item["codigo_barras"]).first()
            if not prod:
                prod = Producto(
                    codigo_barras=item["codigo_barras"],
                    nombre_comercial=item["nombre_comercial"],
                    sustancia_activa=item["sustancia_activa"],
                    presentacion=item["presentacion"],
                    laboratorio=item["laboratorio"],
                    grupo_farmacopea=item["grupo_farmacopea"],
                    requiere_receta=item["requiere_receta"],
                    precio_venta=item["precio_venta"],
                    activo=True,
                )
                db.add(prod)
                db.flush()
                productos_creados += 1

            # Crear lotes del producto
            for lote_info in item.get("lotes", []):
                num_lote = lote_info["numero_lote"]
                lote_existente = db.query(Lote).filter(
                    Lote.producto_id == prod.id,
                    Lote.numero_lote == num_lote
                ).first()

                if not lote_existente:
                    dias_cad = lote_info.get("dias_cad", 365)
                    stock_ini = lote_info.get("stock", 30)
                    costo_u = item.get("costo_unitario", round(item["precio_venta"] * 0.5, 2))

                    nuevo_lote = Lote(
                        producto_id=prod.id,
                        numero_lote=num_lote,
                        fecha_fabricacion=hoy - datetime.timedelta(days=90),
                        fecha_caducidad=hoy + datetime.timedelta(days=dias_cad),
                        costo_unitario=costo_u,
                        stock_actual=stock_ini,
                        activo=True,
                    )
                    db.add(nuevo_lote)
                    db.flush()
                    lotes_creados += 1

                    # Registrar entrada inicial inmutable en Kardex
                    kardex = KardexMovimiento(
                        lote_id=nuevo_lote.id,
                        tipo_movimiento="ENTRADA_COMPRA",
                        cantidad=stock_ini,
                        stock_anterior=0,
                        stock_posterior=stock_ini,
                        costo_unitario=costo_u,
                        referencia_tipo="INICIAL_DEMO_100",
                        referencia_id=f"SEED-{prod.codigo_barras}",
                        motivo=f"Carga inicial de inventario maestro ({prod.nombre_comercial})",
                    )
                    db.add(kardex)

        db.commit()
        print(f"Sembrado finalizado: {productos_creados} productos nuevos, {lotes_creados} lotes creados.")
        total_p = db.query(Producto).count()
        total_l = db.query(Lote).count()
        print(f"Total en Base de Datos: {total_p} Productos, {total_l} Lotes registrados.")

    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

