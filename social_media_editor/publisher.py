import sys
import os
import json
from instagrapi import Client

CREDENTIALS_FILE = "instagram_credentials.json"

def login_instagram():
    """Inicia sesión en Instagram usando instagrapi de forma segura guardando sesión."""
    if not os.path.exists(CREDENTIALS_FILE):
        print(f"ERROR: No existe el archivo {CREDENTIALS_FILE}.")
        print("Crea un archivo instagram_credentials.json con tus datos:")
        print('{"username": "tu_usuario", "password": "tu_password"}')
        sys.exit(1)
        
    with open(CREDENTIALS_FILE, 'r') as f:
        creds = json.load(f)
        
    username = creds.get('username')
    password = creds.get('password')
    
    cl = Client()
    # Recomendado para evitar bloqueos por login frecuente
    # delay_range=[1, 3] en ciertas versiones, configuraremos lo básico.
    try:
        print(f"Iniciando sesión como {username}...")
        cl.login(username, password)
        print("¡Sesión iniciada con éxito!")
        return cl
    except Exception as e:
        print(f"Error al iniciar sesión: {e}")
        sys.exit(1)

def publish_reel(cl, video_path, caption):
    """Sube un video como Reel."""
    if not os.path.exists(video_path):
        print(f"ERROR: Video no encontrado en {video_path}")
        sys.exit(1)
        
    print(f"Publicando Reel: {video_path}...")
    try:
        media = cl.clip_upload(video_path, caption)
        print(f"¡Reel publicado con éxito! ID: {media.id}")
        return True
    except Exception as e:
        print(f"Error al publicar el Reel: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Uso: python publisher.py <ruta_del_video> [caption_opcional]")
        sys.exit(1)
        
    video_path = sys.argv[1]
    
    caption = "¡Nuevo video automático directo de mi código! 🚀🔥"
    if len(sys.argv) > 2:
        caption = sys.argv[2]
        
    cl = login_instagram()
    publish_reel(cl, video_path, caption)

if __name__ == "__main__":
    main()
