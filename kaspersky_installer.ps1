# ETAPA 0: LÓGICA DE EXECUÇÃO E ELEVAÇÃO
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

Clear-Host

chcp 65001 | Out-Null
$OutputEncoding = [System.Text.Encoding]::UTF8

# =================================================================================
# CONFIGURAÇÃO
# =================================================================================
$InstallerPath = Join-Path $PSScriptRoot "kaspersky\installer.exe"
$CleanerPath   = Join-Path $PSScriptRoot "cleaner\cleaner.exe"
$DefaultInstallerUrl = "https://dados.3cta.eb.mil.br/s/cyJnnqEMn8pa3NP/download?path=%2FWindows&files=installer_win_12_11.exe"

$Config = @{}
$EnvFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
            $parts = $line -split '=', 2
            $Config[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
}

$InstallerUrl    = if ($Config['INSTALLER_URL']) { $Config['INSTALLER_URL'] } else { $DefaultInstallerUrl }
$ManagementServer = if ($Config['MANAGEMENT_SERVER']) { $Config['MANAGEMENT_SERVER'] } else { 'ksc3cta02.3cta.eb.mil.br' }
$NtpServer        = if ($Config['NTP_SERVER']) { $Config['NTP_SERVER'] } else { 'ntp.3cta.eb.mil.br' }
$LogDirectory     = if ($Config['LOG_DIRECTORY']) { Join-Path $PSScriptRoot $Config['LOG_DIRECTORY'] } else { Join-Path $PSScriptRoot 'log' }
$AutoPatchStep4   = if ($Config['AUTO_PATCH_STEP4']) { $Config['AUTO_PATCH_STEP4'] } else { 'S' }
$SilentInstall    = if ($Config['SILENT_INSTALL']) { $Config['SILENT_INSTALL'] } else { '1' }
$InstallerParameters = if ($Config['INSTALLER_PARAMETERS']) { $Config['INSTALLER_PARAMETERS'] } else { '/pEULA=1 /pPRIVACYPOLICY=1 /pKSN=0 /pALLOWREBOOT=1 /s /qn' }

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogDirectory ("install_{0}.log" -f $timestamp)
$TranscriptFile = Join-Path $LogDirectory ("install_transcript_{0}.log" -f $timestamp)
Start-Transcript -Path $TranscriptFile -Append | Out-Null

$KlmoverPath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab\Components\27\1103\1.0.0.0\Installer" -Name "KLMOVE_EXE" -ErrorAction SilentlyContinue
if (-not $KlmoverPath) {
    $KlmoverPath = "C:\Program Files (x86)\Kaspersky Lab\NetworkAgent\klmover.exe"
}

# =================================================================================
# CONFIGURAÇÕES DE REDE
# =================================================================================

function Initialize-TlsConfiguration {
    # Garante suporte a TLS mais modernos e ignora certificados não confiáveis da rede interna
    $currentProtocols = [System.Net.ServicePointManager]::SecurityProtocol
    $desiredProtocols = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
    if (($currentProtocols -band $desiredProtocols) -ne $desiredProtocols) {
        [System.Net.ServicePointManager]::SecurityProtocol = $currentProtocols -bor $desiredProtocols
    }

    if (-not $script:CertificateCallbackSet) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $script:CertificateCallbackSet = $true
        Write-Status -Type Warning -Message "Certificados SSL inseguros serão ignorados para downloads internos."
    }
}

# =================================================================================
# FUNÇÕES AUXILIARES
# =================================================================================

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
}

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
    Write-Log -Message $formattedMessage
    if ($Type -eq "Warning") {
        Write-Warning $Message
    } elseif ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
}

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
        Write-Log -Message "$ActionMessage concluído com sucesso."
    } catch {
        Write-Host " [ FALHA ]" -ForegroundColor Red
        $errorMessage = "Ocorreu um erro: $($_.Exception.Message)"
        Write-Status -Type Warning -Message $errorMessage
        Write-Log -Message $errorMessage
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

    Initialize-TlsConfiguration

    if (-NOT (Test-Path -Path $InstallerPath)) {
        if (-not $InstallerUrl) {
            throw "O arquivo instalador '$InstallerPath' não foi encontrado e nenhuma INSTALLER_URL foi definida no .env."
        }

        $installerDir = Split-Path -Parent $InstallerPath
        if (-not (Test-Path $installerDir)) {
            New-Item -ItemType Directory -Path $installerDir | Out-Null
        }

        $tempDownloadPath = Join-Path $installerDir ("installer_tmp_{0}.exe" -f (Get-Random))

        Write-Status -Type Info -Message "Instalador não encontrado. Iniciando download..."
        try {
            $originalProgressPreference = $global:ProgressPreference
            $global:ProgressPreference = 'SilentlyContinue'

            try {
                Start-BitsTransfer -Source $InstallerUrl -Destination $tempDownloadPath -ErrorAction Stop
            } catch {
                Write-Status -Type Warning -Message "BITS indisponível, tentando download via Invoke-WebRequest..."
                Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempDownloadPath -UseBasicParsing -ErrorAction Stop
            }

            if (Test-Path -Path $InstallerPath) {
                Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
            }

            Move-Item -Path $tempDownloadPath -Destination $InstallerPath -Force
            Write-Status -Type Success -Message "Download concluído e arquivo salvo como 'installer.exe'."
        } catch {
            if (Test-Path -Path $tempDownloadPath) {
                Remove-Item -Path $tempDownloadPath -Force -ErrorAction SilentlyContinue
            }

            $downloadError = "Falha ao baixar o instalador: $($_.Exception.Message)"
            Write-Status -Type Error -Message $downloadError
            Write-Log -Message $downloadError
            throw
        } finally {
            $global:ProgressPreference = $originalProgressPreference
        }
    } else {
        Write-Status -Type Success -Message "Arquivo instalador encontrado."
    }

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
    $shouldRunSilently = $SilentInstall -and ($SilentInstall.ToString().ToLower() -in @('1','true','yes','y','sim','s'))

    if ($shouldRunSilently) {
        Write-Status -Type Action -Message "Instalação silenciosa solicitada (SILENT_INSTALL ativado). Executando instalador automaticamente..."
        try {
            Start-Process -FilePath $InstallerPath -ArgumentList $InstallerParameters -Wait -ErrorAction Stop
            Write-Status -Type Success -Message "Instalação silenciosa concluída ou instalador encerrado."
        } catch {
            throw "Falha ao executar a instalação silenciosa: $($_.Exception.Message)"
        }
    } else {
        Write-Status -Type Action -Message "Aguardando instalação manual. A janela do instalador será aberta."
        Write-Status -Type Action -Message "Por favor, conclua a instalação e feche o instalador para continuar."
        
        try {
            Start-Process -FilePath $InstallerPath -Wait -ErrorAction Stop
            Write-Status -Type Success -Message "Instalador do antivírus foi fechado."
        } catch {
            throw "O processo de instalação falhou, foi cancelado ou não pôde ser iniciado."
        }
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

    $shouldAutoApply = $AutoPatchStep4 -and ($AutoPatchStep4.ToString().ToLower() -in @('1','true','yes','y','sim','s'))
    $userConsent = $false

    if ($shouldAutoApply) {
        Write-Status -Type Info -Message "Variável AUTO_PATCH_STEP4 ativa. Aplicando patch automaticamente."
        $userConsent = $true
    } else {
        $title = "Patch de Correção"
        $message = "Deseja executar o patch de correção para problemas de sincronização?"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Sim", "Aplica os patches de correção."
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&Não", "Ignora a aplicação dos patches."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.UI.PromptForChoice($title, $message, $options, 1)
        $userConsent = ($result -eq 0)
    }

    if ($userConsent) {
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
    Write-Log -Message "Erro fatal: $($_.Exception.Message)"
} finally {
    Write-Progress -Activity "Instalação Personalizada Kaspersky" -Completed -ErrorAction SilentlyContinue
    Write-Host
    Stop-Transcript | Out-Null
    Read-Host -Prompt "Pressione ENTER para fechar esta janela..."
}
