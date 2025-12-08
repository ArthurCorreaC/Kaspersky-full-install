@echo off
TITLE Assistente de Instalação Kaspersky - 4ºBIMEC

SET "SCRIPT_PATH=%~dp0kaspersky_installer.ps1"

IF NOT EXIST "%SCRIPT_PATH%" (
    ECHO.
    ECHO ERRO FATAL: O script PowerShell 'kaspersky_installer.ps1' não foi encontrado.
    ECHO Certifique-se de manter este .bat e o .ps1 no mesmo diretório.
    ECHO.
    PAUSE
    EXIT /B 1
)

powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
