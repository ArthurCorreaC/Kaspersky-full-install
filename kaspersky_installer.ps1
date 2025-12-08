<#
#############################################################################
#                                                                           #
#   Copyright (c) 4º Batalhão de Infantaria Mecanizado (4ºBIMEC)            #
#   Seção de Informática                                                    #
#                                                                           #
#   Autoria:                                                                #
#   Ten Valdevino                                                           #
#   3º Sgt Souto                                                            #
#   Cb Bruno Silva                                                          #
#                                                                           #
#############################################################################
#>

# --- ETAPA 0: LÓGICA DE EXECUÇÃO E ELEVAÇÃO ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

Clear-Host

# Força a página de código do console para UTF-8 para exibir acentos corretamente.
chcp 65001 | Out-Null

# Força o terminal a interpretar a saída do script como UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# =================================================================================
# VARIÁVEIS DE CONFIGURAÇÃO
# =================================================================================
$InstallerPath    = Join-Path $PSScriptRoot "kaspersky\installer.exe"
$CleanerPath      = Join-Path $PSScriptRoot "cleaner\cleaner.exe"
$CleanerDir       = Join-Path $PSScriptRoot "cleaner\"

$KlmoverPath      = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab\Components\27\1103\1.0.0.0\Installer" -Name "KLMOVE_EXE" -ErrorAction SilentlyContinue
if (-not $KlmoverPath) {
    $KlmoverPath = "C:\Program Files (x86)\Kaspersky Lab\NetworkAgent\klmover.exe"
}

$ManagementServer = "ksc3cta.3cta.eb.mil.br"
$NtpServer        = "ntp.3cta.eb.mil.br"

# =================================================================================
# FUNÇÕES AUXILIARES
# =================================================================================

function Write-Status {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Success", "Warning", "Error", "Info", "Action", "Step")]
        [string]$Type,
        [switch]$NoNewLine
    )
    $statusText = ""
    $color = "White"
    switch ($Type) {
        "Success" { $statusText = "[  OK   ]"; $color = "Green" }
        "Warning" { $statusText = "[ AVISO ]"; $color = "Yellow" }
        "Error"   { $statusText = "[ ERRO  ]"; $color = "Red" }
        "Info"    { $statusText = "[ INFO  ]"; $color = "Cyan" }
        "Action"  { $statusText = "[ AÇÃO  ]"; $color = "Magenta" }
        "Step"    { $statusText = "---"; $color = "Green"; Write-Host "" }
    }
    $formattedMessage = "$($statusText) $Message"
    if ($Type -eq "Warning") {
        Write-Warning $Message
    } elseif ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
}

## [ALTERADO] Removidas as linhas "return $true" e "return $false" para limpar a saída.
function Invoke-CommandWithStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ActionMessage,
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$Command
    )
    
    Write-Status -Type Info -Message $ActionMessage -NoNewLine
    try {
        & $Command
        Write-Host " [  OK   ]" -ForegroundColor Green
    } catch {
        Write-Host " [ FALHA ]" -ForegroundColor Red
        Write-Status -Type Warning -Message "Ocorreu um erro: $($_.Exception.Message)"
    }
}

# =================================================================================
# FUNÇÕES PRINCIPAIS DO SCRIPT
# =================================================================================

function Show-Banner {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "         ASSISTENTE DE INSTALAÇÃO KASPERSKY - 3º CTA" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host
    Write-Status -Type Info -Message "Desenvolvido pela Seção de Informática do 4ºBIMEC."
    Write-Host "  Autoria:" -ForegroundColor Yellow
    Write-Host "  - Ten Valdevino, 3º Sgt Souto, Cb Bruno Silva" -ForegroundColor Cyan
    Write-Host
    Write-Status -Type Info -Message "Executando como Administrador."
    Write-Host
}

function Test-Prerequisites {
    Write-Status -Type Step -Message "ETAPA 1: Verificando arquivos e pré-requisitos"
    
    if (-NOT (Test-Path -Path $InstallerPath)) {
        throw "O arquivo instalador '$InstallerPath' não foi encontrado. A instalação não pode continuar."
    }
    Write-Status -Type Success -Message "Arquivo instalador encontrado."

    Invoke-CommandWithStatus -ActionMessage "Testando conexão com o servidor '$ManagementServer'..." -Command {
        Resolve-DnsName $ManagementServer -ErrorAction Stop | Out-Null
    }

    Invoke-CommandWithStatus -ActionMessage "Configurando servidor de horário para '$NtpServer'..." -Command {
        w32tm /config /manualpeerlist:"$NtpServer" /syncfromflags:manual /reliable:yes /update | Out-Null
        w32tm /resync /force | Out-Null
    }
}

function Start-AntivirusInstallation {
    Write-Status -Type Step -Message "ETAPA 2: Instalação do Kaspersky Antivirus"
    Write-Status -Type Action -Message "Aguardando instalação manual. A janela do instalador será aberta."
    Write-Status -Type Action -Message "Por favor, conclua a instalação e feche o instalador para continuar."
    
    try {
        Start-Process -FilePath $InstallerPath -Wait -ErrorAction Stop
        Write-Status -Type Success -Message "Instalador do antivírus foi fechado."
    } catch {
        throw "O processo de instalação falhou, foi cancelado ou não pôde ser iniciado."
    }
}

function Configure-NetworkAgent {
    Write-Status -Type Step -Message "ETAPA 3: Configuração Pós-Instalação (Agente de Rede)"
    
    if (Test-Path -Path $KlmoverPath) {
        Write-Status -Type Info -Message "Executando 'klmover.exe' para apontar para o servidor..." -NoNewLine
        & $KlmoverPath -address $ManagementServer -silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [  OK   ]" -ForegroundColor Green
            Write-Status -Type Success -Message "Agente de rede configurado com sucesso."
        } else {
            Write-Host " [ ERRO  ]" -ForegroundColor Yellow
            Write-Status -Type Warning -Message "O comando 'klmover' retornou um código de erro: $LASTEXITCODE."
        }
    } else {
        Write-Status -Type Warning -Message "'klmover.exe' não encontrado. Etapa ignorada."
    }
}

function Apply-OptionalPatches {
    Write-Status -Type Step -Message "ETAPA 4: Patch de Correção (Opcional)"
    
    $title = "Patch de Correção"
    $message = "Deseja executar o patch de correção para problemas de sincronização?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Sim", "Aplica os patches de correção."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&Não", "Ignora a aplicação dos patches."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $result = $host.UI.PromptForChoice($title, $message, $options, 1)

    if ($result -eq 0) {
        if (-NOT (Test-Path -Path $CleanerPath)) {
            Write-Status -Type Error -Message "Arquivo '$CleanerPath' não encontrado. Etapa ignorada."
            return
        }
        try {
            Write-Status -Type Info -Message "Aplicando patches de correção..."
            & $CleanerPath /uc {B9518725-0876-4793-A409-C6794442FB50} | Out-Null
            & $CleanerPath /pc {BCF4CF24-88AB-45E1-A6E6-40C8278A70C5} | Out-Null
            & $CleanerPath /pc {0F05E4E5-5A89-482C-9A62-47CC58643788} | Out-Null
            Write-Status -Type Success -Message "Patches de correção foram aplicados."
        } catch {
            Write-Status -Type Error -Message "Ocorreu um erro ao executar o cleaner."
        }
    } else {
        Write-Status -Type Info -Message "Aplicação de patch de correção ignorada pelo usuário."
    }
}

# =================================================================================
# EXECUÇÃO PRINCIPAL DO SCRIPT
# =================================================================================

try {
    Show-Banner
    
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Status "Iniciando verificação..." -PercentComplete 0
    Test-Prerequisites
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Status "Pré-requisitos verificados." -PercentComplete 25

    Start-AntivirusInstallation
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Status "Instalação base concluída." -PercentComplete 50
    
    Configure-NetworkAgent
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Status "Agente de rede configurado." -PercentComplete 75

    Apply-OptionalPatches
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Status "Processo finalizado." -PercentComplete 100

    Write-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Status -Type Success -Message "PROCESSO AUTOMATIZADO CONCLUÍDO COM SUCESSO!"
    Write-Host "============================================================" -ForegroundColor Cyan
    
} catch {
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Completed
    Write-Host
    Write-Status -Type Error -Message "O SCRIPT FOI INTERROMPIDO DEVIDO A UM ERRO:"
    Write-Host ($_.Exception.Message) -ForegroundColor Red
} finally {
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Completed -ErrorAction SilentlyContinue
    Write-Host
    Read-Host -Prompt "Pressione ENTER para fechar esta janela..."
}
