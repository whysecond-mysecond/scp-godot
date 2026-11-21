@echo off
title SCP: Secret Laboratory 3D — Запуск
chdir /d "%~dp0"

REM Путь к Godot (автоматически определяет winget-установку)
set GODOT=C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot.exe

if not exist "%GODOT%" (
    echo ERROR: Godot не найден!
    echo Установите Godot Engine 4.x: https://godotengine.org/download/
    pause
    exit /b 1
)

echo Запуск SCP: Secret Laboratory 3D...
start "" "%GODOT%" --path "."
