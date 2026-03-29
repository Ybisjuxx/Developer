import sqlite3

db_path = r'C:\Users\ybis\.n8n\database.sqlite'
print(f"Abriendo base de datos en {db_path}...")

try:
    # Usamos un timeout corto por si la base de datos está bloqueada por n8n
    conn = sqlite3.connect(db_path, timeout=3)
    cur = conn.cursor()
    
    # Intentamos borrar de las dos tablas posibles donde n8n esconde los paquetes
    try:
        cur.execute("DELETE FROM installed_packages WHERE packageName LIKE '%instagram%'")
        print("Borrado de installed_packages.")
    except:
        pass
        
    try:
        cur.execute("DELETE FROM installed_nodes WHERE name LIKE '%instagram%' OR packageName LIKE '%instagram%'")
        print("Borrado de installed_nodes.")
    except:
        pass

    conn.commit()
    conn.close()
    print("¡Operación exitosa! El paquete fantasma fue extirpado.")
    
except Exception as e:
    print(f"❌ Falló: {e}")
    print("¡ATENCIÓN! La base de datos está bloqueada. NECESITAS apagar n8n (Ctrl+C) en tu terminal antes de correr esto.")
