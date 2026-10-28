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

        # 6. Sembrar Historial Mensual de Ventas para Gráfica Anual (si hay menos de 10 ventas)
        from app.models import Venta, VentaDetalle, VentaDetalleLote
        if db.query(Venta).count() < 10:
            print("Sembrando histórico de ventas mes a mes para gráfica anual 2026...")
            prods = db.query(Producto).all()
            if prods:
                cajero = db.query(Usuario).filter(Usuario.rol == "CAJERO").first()
                cajero_nom = cajero.nombre_completo if cajero else "Juan Daniel Morales"
                
                ventas_mensuales_config = [
                    (1, 15, 3450.0),   # Ene: 15 tickets, aprox $3,450
                    (2, 12, 2890.0),   # Feb: 12 tickets, aprox $2,890
                    (3, 18, 4120.0),   # Mar: 18 tickets, aprox $4,120
                    (4, 16, 3850.0),   # Abr: 16 tickets, aprox $3,850
                    (5, 20, 5210.0),   # May: 20 tickets, aprox $5,210
                    (6, 19, 4780.0),   # Jun: 19 tickets, aprox $4,780
                    (7, 22, 5890.0),   # Jul: 22 tickets, aprox $5,890
                    (8, 25, 6420.0),   # Ago: 25 tickets, aprox $6,420
                    (9, 21, 5630.0),   # Sep: 21 tickets, aprox $5,630
                    (10, 28, 7350.0),  # Oct: 28 tickets, aprox $7,350 (Mes pico)
                ]
                
                for mes, num_tickets, meta_monto in ventas_mensuales_config:
                    monto_por_ticket = round(meta_monto / num_tickets, 2)
                    for t in range(1, num_tickets + 1):
                        dia = min(28, (t * 2) % 27 + 1)
                        fecha_v = datetime.datetime(2026, mes, dia, 10 + (t % 8), (t * 7) % 59)
                        p_sel = prods[(mes * 7 + t) % len(prods)]
                        lote_sel = p_sel.lotes[0] if p_sel.lotes else None
                        
                        v = Venta(
                            folio_ticket=f"TK-2026{mes:02d}{dia:02d}-{t:04d}",
                            fecha_venta=fecha_v,
                            comprador_nombre="Público General" if t % 3 != 0 else "Cliente Frecuente",
                            subtotal=monto_por_ticket,
                            descuento=round(monto_por_ticket * 0.05, 2) if t % 4 == 0 else 0.0,
                            total=monto_por_ticket,
                            metodo_pago="EFECTIVO" if t % 2 == 0 else "TARJETA",
                            monto_recibido=monto_por_ticket,
                            cambio=0.0,
                            cajero_nombre=cajero_nom,
                            estado="COMPLETADA",
                        )
                        db.add(v)
                        db.flush()
                        
                        det = VentaDetalle(
                            venta_id=v.id,
                            producto_id=p_sel.id,
                            cantidad=1,
                            precio_unitario=monto_por_ticket,
                            subtotal=monto_por_ticket,
                        )
                        db.add(det)
                        db.flush()
                        
                        if lote_sel:
                            desp = VentaDetalleLote(
                                venta_detalle_id=det.id,
                                lote_id=lote_sel.id,
                                cantidad_despachada=1,
                                costo_unitario=lote_sel.costo_unitario,
                            )
                            db.add(desp)
                db.commit()
                print("Ventas históricas para gráfica 2026 sembradas con éxito.")

    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

