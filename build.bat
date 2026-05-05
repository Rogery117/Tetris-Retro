@echo off
echo [INFO] Compilando con msdos-player...

:: 1. Compilar (Esto ya funciona por finnnnnn)
.\msdos.exe TASM.EXE src\tetris.asm bin\tetris.obj

:: 2. Enlazar (Corregido x14)
:: Usamos /t para programas pequeños o quitamos rutas complejas si da error
.\msdos.exe TLINK.EXE bin\tetris.obj, bin\tetris.exe

if exist bin\tetris.exe (
    echo [OK] Tetris generado con exito.
    "C:\Program Files (x86)\DOSBox-0.74-3\dosbox.exe" -c "mount c ." -c "c:" -c "bin\tetris.exe" -c "exit"
) else (
    echo [ERROR] No se pudo crear el EXE. 
    echo Intenta borrar manualmente cualquier 'tetris.exe' viejo si existe.
    pause
)