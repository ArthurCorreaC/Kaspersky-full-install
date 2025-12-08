@echo off
:: #############################################################################
:: #                                                                           #
:: #             Script Assistente de Instalação do Kaspersky Endpoint         #
:: #                                                                           #
:: #   Copyright (c) 2024 4º Batalhão de Infantaria Mecanizado (4ºBIMEC)       #
:: #   Seção de Informática                                                    #
:: #                                                                           #
:: #   Desenvolvido por:                                                       #
:: #   1º Ten Valdevino                                                        #
:: #   3º Sgt Souto                                                            #
:: #   Cb Bruno Silva                                                          #
:: #                                                                           #
:: #   Versão: 1.0                                                             #
:: #   Última Modificação: 04/07/2024                                          #
:: #                                                                           #
:: #############################################################################

TITLE Assistente de Instalação Kaspersky - 4ºBIMEC

:: Define o caminho completo para o script PowerShell que será executado.
:: %~dp0 é uma variável especial que expande para o diretório onde o arquivo .bat está localizado.
SET "SCRIPT_PATH=%~dp0kaspersky_installer.ps1"

:: --- VERIFICAÇÃO DE ROBUSTEZ ---
:: Verifica se o script PowerShell realmente existe no local esperado.
:: Se não existir, exibe uma mensagem de erro clara e aguarda o usuário.
IF NOT EXIST "%SCRIPT_PATH%" (
    ECHO.
    ECHO ERRO FATAL: O script PowerShell 'kaspersky_installer_final.ps1' não foi encontrado.
    ECHO.
    ECHO Por favor, certifique-se de que este arquivo .bat e o arquivo .ps1 estejam na mesma pasta.
    ECHO.
    PAUSE
    EXIT /B 1
)

:: --- EXECUÇÃO ---
:: Executa o script PowerShell.
::
:: -ExecutionPolicy Bypass: Permite que o script rode sem problemas de política de execução.
:: -File: Especifica qual script executar.
::
:: O parâmetro "-NoExit" foi REMOVIDO INTENCIONALMENTE.
:: O próprio script PowerShell já se encarrega de manter a janela final aberta.
:: Removê-lo daqui evita que uma primeira janela (não-elevada) fique aberta desnecessariamente
:: caso a elevação de privilégios seja necessária.
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

:: O script .bat termina aqui. A janela do PowerShell que foi aberta continuará visível,
:: conforme programado no script .ps1.