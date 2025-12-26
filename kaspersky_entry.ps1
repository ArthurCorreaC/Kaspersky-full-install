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

$ExecutionMode = if ($Config['EXECUTION_MODE']) { $Config['EXECUTION_MODE'] } else { 'AUTO' }

# =================================================================================
# CONTROLE DE EXECUÇÃO
# =================================================================================

$InstallerScript = Join-Path $PSScriptRoot "kaspersky_installer.ps1"
$UninstallerScript = Join-Path $PSScriptRoot "kaspersky_uninstaller.ps1"
$StatusScript = Join-Path $PSScriptRoot "kaspersky_status.ps1"

function Invoke-EntryScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )

    if (-not (Test-Path -Path $ScriptPath)) {
        throw "Script não encontrado: $ScriptPath"
    }

    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $process = Start-Process powershell.exe -ArgumentList $arguments -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        throw "Script retornou erro (ExitCode: $($process.ExitCode))."
    }
}

try {
    $normalizedMode = $ExecutionMode.ToString().Trim().ToUpperInvariant()
    if (-not $normalizedMode) {
        $normalizedMode = "AUTO"
    }

    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "         ASSISTENTE KASPERSKY - SELETOR DE MODO" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host
    Write-Host ("[ INFO  ] Modo de execução selecionado: {0}" -f $normalizedMode) -ForegroundColor Cyan
    Write-Host

    switch ($normalizedMode) {
        "AUTO" {
            Invoke-EntryScript -ScriptPath $InstallerScript
        }
        "INSTALL" {
            Invoke-EntryScript -ScriptPath $InstallerScript
        }
        "REMOVE" {
            Invoke-EntryScript -ScriptPath $UninstallerScript
        }
        "STATUS" {
            Invoke-EntryScript -ScriptPath $StatusScript
        }
        default {
            throw "Modo de execução inválido: '$ExecutionMode'. Use AUTO, INSTALL, REMOVE ou STATUS."
        }
    }
} catch {
    Write-Host
    Write-Host "[ ERRO  ] O seletor de modo foi interrompido:" -ForegroundColor Red
    Write-Host ($_.Exception.Message) -ForegroundColor Red
    exit 1
}
