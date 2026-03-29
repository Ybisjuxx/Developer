import os
import shutil
from editor import process_video

INPUT_DIR = "input"
OUTPUT_DIR = "output"
PROCESSED_DIR = "procesados"

def get_video_files(directory):
    extensions = ('.mp4', '.mov', '.avi', '.mkv')
    video_files = []
    if not os.path.exists(directory):
        os.makedirs(directory)
        return []
    for file in os.listdir(directory):
        if file.lower().endswith(extensions):
            video_files.append(os.path.join(directory, file))
    return video_files

def main():
    print("🚀 Iniciando Motor de Edición y División Automática")
    
    os.makedirs(INPUT_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    
    videos = get_video_files(INPUT_DIR)
    
    if not videos:
        print(f"⚠️ No hay videos en la carpeta '{INPUT_DIR}'.")
        print("Arrastra videos allí y vuelve a ejecutarme.")
        return
        
    print(f"Encontrados {len(videos)} video(s) para editar.")
    
    for vi in videos:
        filename = os.path.basename(vi)
        name, ext = os.path.splitext(filename)
        output_path = os.path.join(OUTPUT_DIR, f"{name}_vertical{ext}")
        
        print(f"🎬 Trabajando en: {filename}...")
        archivos_generados = process_video(vi, output_path)
        
        if archivos_generados:
            print(f"✅ Se dividió en {len(archivos_generados)} clips listos para Reels/TikTok.")
            # Mover original para evitar procesarlo 2 veces
            shutil.move(vi, os.path.join(PROCESSED_DIR, filename))
        else:
            print(f"❌ Error con {filename}")

if __name__ == "__main__":
    main()
