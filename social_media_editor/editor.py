import os
import math
from moviepy.editor import VideoFileClip, CompositeVideoClip
import moviepy.video.fx.all as vfx

def process_video(input_path, output_path, target_size=(1080, 1920), max_duration=59):
    """
    Procesa un video: asegura relación 9:16 (con borde desenfocado si no encaja perfecto)
    y lo divide automáticamente en partes si excede 'max_duration'.
    Devuelve una lista con las rutas de los videos generados.
    """
    print(f"[{input_path}] Iniciando procesamiento...")
    
    generated_files = []
    try:
        # 1. Cargar video principal
        full_clip = VideoFileClip(input_path)
        
        num_chunks = int(math.ceil(full_clip.duration / max_duration))
        print(f"[{input_path}] Duración: {full_clip.duration:.2f}s. Se dividirá en {num_chunks} parte(s).")
        
        for i in range(num_chunks):
            start_time = i * max_duration
            end_time = min((i + 1) * max_duration, full_clip.duration)
            clip = full_clip.subclip(start_time, end_time)
            
            # Nombre de archivo dinámico si hay múltiples partes
            if num_chunks > 1:
                name, ext = os.path.splitext(output_path)
                current_output = f"{name}_part{i+1}{ext}"
            else:
                current_output = output_path
                
            print(f"[{input_path}] Procesando parte {i+1}/{num_chunks} ({start_time:.1f}s - {end_time:.1f}s)...")
            
            # 3. Preparar el efecto de fondo desenfocado (Blur Padding)
            w, h = clip.size
            target_w, target_h = target_size
            
            aspect_original = w / h
            aspect_target = target_w / target_h
            
            if round(aspect_original, 2) != round(aspect_target, 2):
                
                bg_clip = clip.resize(height=target_h)
                if bg_clip.w < target_w:
                    bg_clip = clip.resize(width=target_w)
                    
                bg_clip = bg_clip.crop(x_center=bg_clip.w/2, y_center=bg_clip.h/2, width=target_w, height=target_h)
                
                def blur_frame(image):
                    return (image * 0.4).astype('uint8')
                
                bg_clip = bg_clip.fl_image(blur_frame)
                
                main_clip = clip.resize(width=target_w) if aspect_original > aspect_target else clip.resize(height=target_h)
                main_clip = main_clip.set_position("center")
                
                final_clip = CompositeVideoClip([bg_clip, main_clip], size=target_size)
            else:
                if (w, h) != target_size:
                    final_clip = clip.resize(newsize=target_size)
                else:
                    final_clip = clip
                    
            # 4. Exportar
            target_fps = min(clip.fps, 30) if clip.fps else 30
            
            final_clip.write_videofile(
                current_output, 
                fps=target_fps, 
                codec="libx264", 
                audio_codec="aac",
                preset="ultrafast",
                threads=os.cpu_count() or 4
            )
            
            # Liberar clips pequeños para no saturar la RAM
            clip.close()
            final_clip.close()
            generated_files.append(current_output)
            print(f"[{current_output}] ✨ Parte {i+1} procesada con éxito.")
            
        full_clip.close()
        return generated_files
        
    except Exception as e:
        print(f"[{input_path}] ❌ Error durante el procesamiento: {e}")
        return []

if __name__ == "__main__":
    pass
