@echo off
color 0A
echo =========================================
echo      EDITOR DE MULTIMEDIA SOCIAL
echo =========================================
echo.
cd /d "%~dp0"
call venv\Scripts\activate.bat
python main.py
echo.
echo =========================================
echo   PROCESO FINALIZADO - Revisa la carpeta 'output'
echo =========================================
pause
