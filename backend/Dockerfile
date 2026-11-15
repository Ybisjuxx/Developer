FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY backend ./backend
RUN mkdir -p /app/reportes_mensuales/01_mostrador_ventas \
    /app/reportes_mensuales/02_almacen_inventario \
    /app/reportes_mensuales/03_compras_proveedores \
    /app/reportes_mensuales/04_finanzas_administracion \
    /app/reportes_mensuales/05_calidad_atencion_farmaceutica \
    /app/reportes_mensuales/06_regulacion_cofepris

EXPOSE 8000

CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
