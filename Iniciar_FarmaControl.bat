@echo off
chcp 65001 > nul
title FarmaControl - Sistema de Farmacia

echo ===================================================
echo           INICIANDO FARMACONTROL MÉXICO
echo ===================================================
echo.

:: 1. Verificar si el backend ya está activo en el puerto 8000
netstat -ano | findstr :8000 | findstr LISTENING > nul
if %errorlevel% equ 0 (
    echo [✓] El servidor Backend ya se encuentra activo en el puerto 8000.
) else (
    echo [*] Iniciando servidor Backend en segundo plano...
    cd /d "%~dp0backend"
    start /b python -m uvicorn app.main:app --port 8000 > nul 2>&1
    timeout /t 2 /nobreak > nul
    echo [✓] Servidor Backend listo en http://127.0.0.1:8000
)

echo.
echo [*] Abriendo aplicación de escritorio FarmaControl (.exe)...
cd /d "%~dp0frontend\build\windows\x64\runner\Release"
start "" "frontend.exe"

exit
