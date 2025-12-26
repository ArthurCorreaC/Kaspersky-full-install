# ETAPA 0: LÓGICA DE EXECUÇÃO E ELEVAÇÃO
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

Clear-Host

chcp 65001 | Out-Null
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Status {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Success", "Warning", "Error", "Info", "Step")]
        [string]$Type
    )
    $statusText = ""
    $color = "White"
    switch ($Type) {
        "Success" { $statusText = "[  OK   ]"; $color = "Green" }
        "Warning" { $statusText = "[ AVISO ]"; $color = "Yellow" }
        "Error"   { $statusText = "[ ERRO  ]"; $color = "Red" }
        "Info"    { $statusText = "[ INFO  ]"; $color = "Cyan" }
        "Step"    { $statusText = "---"; $color = "Green"; Write-Host "" }
    }
    Write-Host "$statusText $Message" -ForegroundColor $color
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

try {
    Write-Status -Type Step -Message "STATUS: Verificando instalação do Kaspersky"
    $info = Get-KasperskyUninstallInfo
    if ($info) {
        Write-Status -Type Success -Message "Produto encontrado: $($info.DisplayName)"
        if ($info.UninstallString) {
            Write-Status -Type Info -Message "UninstallString registrado."
        } else {
            Write-Status -Type Warning -Message "UninstallString não encontrado no registro."
        }
    } else {
        Write-Status -Type Warning -Message "Nenhum produto Kaspersky foi encontrado no registro."
    }
} catch {
    Write-Host
    Write-Status -Type Error -Message "Falha ao verificar status: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Host
    Read-Host -Prompt "Pressione ENTER para fechar esta janela..."
}
