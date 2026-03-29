import os
import sys
import json
from editor import process_video

def main():
    if len(sys.argv) < 2:
        print("Uso: python n8n_bridge.py <ruta_del_video_original>")
        sys.exit(1)
        
    input_video_path = sys.argv[1]
    
    if not os.path.isfile(input_video_path):
        print(f"Error: El archivo {input_video_path} no existe.")
        sys.exit(1)
        
    filename = os.path.basename(input_video_path)
    name, ext = os.path.splitext(filename)
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(base_dir, "output")
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, f"{name}_vertical{ext}")
    
    print(f"n8n solicita edición de: {input_video_path}")
    
    archivos_generados = process_video(input_video_path, output_path)
    
    if archivos_generados:
        # Convertimos las listas absolutas a una cadena JSON fuerte
        rutas_absolutas = [os.path.abspath(f) for f in archivos_generados]
        print(f"RESULT_PATHS:{json.dumps(rutas_absolutas)}")
    else:
        print("Error en el recorte y renderizado en Python.")
        sys.exit(1)

if __name__ == "__main__":
    main()
