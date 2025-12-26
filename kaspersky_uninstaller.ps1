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
$CleanerPath = Join-Path $PSScriptRoot "cleaner\cleaner.exe"
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

$LogDirectory = if ($Config['LOG_DIRECTORY']) { Join-Path $PSScriptRoot $Config['LOG_DIRECTORY'] } else { Join-Path $PSScriptRoot 'log' }

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogDirectory ("uninstall_{0}.log" -f $timestamp)
$TranscriptFile = Join-Path $LogDirectory ("uninstall_transcript_{0}.log" -f $timestamp)
Start-Transcript -Path $TranscriptFile -Append | Out-Null

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

function Get-KasperskyUninstallInfo {
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($root in $uninstallRoots) {
        $items = Get-ChildItem -Path $root -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $displayName = Get-ItemPropertyValue -Path $item.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue
            if ($displayName -and $displayName -match "Kaspersky") {
                $uninstallString = Get-ItemPropertyValue -Path $item.PSPath -Name "UninstallString" -ErrorAction SilentlyContinue
                return [PSCustomObject]@{
                    DisplayName = $displayName
                    UninstallString = $uninstallString
                    RegistryPath = $item.PSPath
                }
            }
        }
    }

    return $null
}

function Invoke-KasperskyUninstall {
    Write-Status -Type Step -Message "ETAPA 1: Desinstalação do Kaspersky"

    $info = Get-KasperskyUninstallInfo
    if (-not $info) {
        Write-Status -Type Warning -Message "Produto Kaspersky não encontrado no registro. Nada para desinstalar."
        return
    }

    Write-Status -Type Info -Message "Produto encontrado: $($info.DisplayName)"

    if (-not $info.UninstallString) {
        throw "UninstallString não encontrado para o produto Kaspersky."
    }

    $commandLine = $info.UninstallString.Trim()
    if ($commandLine.StartsWith('"')) {
        $commandLine = $commandLine.Trim('"')
    }

    $exePath = $commandLine
    $arguments = ""
    if ($commandLine -match "^\s*([^\s]+)\s+(.*)$") {
        $exePath = $matches[1]
        $arguments = $matches[2]
    }

    if ($exePath -match "msiexec\.exe") {
        $arguments = $arguments -replace "/I", "/X"
        if ($arguments -notmatch "/X") {
            $arguments = "/X $arguments"
        }
        if ($arguments -notmatch "/qn") {
            $arguments = "$arguments /qn /norestart"
        }
    } else {
        if ($arguments -notmatch "/quiet|/s|/silent") {
            $arguments = "$arguments /quiet"
        }
    }

    Write-Status -Type Action -Message "Executando desinstalação: $exePath $arguments"
    $process = Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
    if ($process.ExitCode -ne 0) {
        throw "O desinstalador retornou erro (ExitCode: $($process.ExitCode))."
    }
    Write-Status -Type Success -Message "Desinstalação concluída."
}

function Invoke-CleanerCommands {
    Write-Status -Type Step -Message "ETAPA 2: Limpeza pós-desinstalação"

    if (-not (Test-Path -Path $CleanerPath)) {
        throw "Arquivo '$CleanerPath' não encontrado."
    }

    Write-Status -Type Info -Message "Executando comandos do cleaner.exe..."
    & $CleanerPath /uc {B9518725-0B76-4793-A409-C6794442FB50} | Out-Null
    & $CleanerPath /uc {B9518725-0B76-4793-A409-C6794442FB50} | Out-Null
    & $CleanerPath /pc {0F05E4E5-5A89-482C-9A62-47CC58643788} | Out-Null
    Write-Status -Type Success -Message "Limpeza concluída."
}

# =================================================================================
# EXECUÇÃO PRINCIPAL
# =================================================================================

try {
    Invoke-KasperskyUninstall
    Invoke-CleanerCommands

    Write-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Status -Type Success -Message "DESINSTALAÇÃO FINALIZADA COM SUCESSO!"
    Write-Host "============================================================" -ForegroundColor Cyan
} catch {
    Write-Host
    Write-Status -Type Error -Message "O SCRIPT DE DESINSTALAÇÃO FOI INTERROMPIDO:"
    Write-Host ($_.Exception.Message) -ForegroundColor Red
    Write-Log -Message "Erro fatal: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Host
    Stop-Transcript | Out-Null
    Read-Host -Prompt "Pressione ENTER para fechar esta janela..."
}
