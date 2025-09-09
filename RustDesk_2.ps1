#requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms

# ========================================
# Instalando e Configurando RustDesk
# ========================================

# --- Força execução como admin ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Reexecutando como Administrador..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Senha fixa ---
$rustdesk_pw = '@acessN@n0!'

# --- Configuração do servidor/key ---
$rustdesk_cfg = "host=acesso.sistemasnano.com.br,key=714N6tBWc1EwLZxJfAMbjDf2J39BBYI2XxvH8SistKk="

# --- Função para pegar versão mais recente no GitHub ---
function Get-LatestRustDesk {
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try {
        $HTML.IHTMLDocument2_write($Page.Content)
    } catch {
        $src = [System.Text.Encoding]::Unicode.GetBytes($Page.Content)
        $HTML.write($src)
    }

    $Downloadlink = ($HTML.Links | Where-Object { $_.href -match 'rustdesk/releases/download/\d+(\.\d+){1,3}/rustdesk-.*x86_64.exe' } | Select-Object -First 1).href
    $Downloadlink = $Downloadlink.Replace('about:', 'https://github.com')

    $Version = "unknown"
    if ($Downloadlink -match 'rustdesk/releases/download/(?<content>.*)/rustdesk-.*x86_64.exe') {
        $Version = $matches['content']
    }

    if ($Version -eq "unknown" -or $Downloadlink -eq "") {
        throw "Erro: versão ou link de download não encontrado."
    }

    return [PSCustomObject]@{
        Version     = $Version
        DownloadURL = $Downloadlink
    }
}

# --- Descobre versão instalada ---
$installedVersion = $null
try {
    $installedVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk\" -ErrorAction Stop).Version
} catch {
    Write-Host "RustDesk não encontrado instalado."
}

# --- Pega versão mais nova ---
$RustDeskOnline = Get-LatestRustDesk

# --- Decide se baixa ou só reconfigura ---
$needInstall = $true
if ($installedVersion) {
    if ($installedVersion -eq $RustDeskOnline.Version) {
        Write-Host "RustDesk $installedVersion já é a versão mais recente. Não será feito download."
        $needInstall = $false
    } else {
        Write-Host "RustDesk instalado ($installedVersion), mas existe versão nova ($($RustDeskOnline.Version))."
    }
}

# --- Instala se necessário ---
if ($needInstall) {
    $tempPath = "C:\Temp"
    if (!(Test-Path $tempPath)) { New-Item -Path $tempPath -ItemType Directory | Out-Null }
    Set-Location $tempPath

    $exeFile = "$tempPath\rustdesk.exe"
    Write-Host "Baixando RustDesk versão $($RustDeskOnline.Version) ..."
    Invoke-WebRequest -Uri $RustDeskOnline.DownloadURL -OutFile $exeFile -UseBasicParsing

    Write-Host "Instalando RustDesk..."
    Start-Process $exeFile -ArgumentList "--silent-install" -Wait
    Start-Sleep -Seconds 20
}

# --- Caminho padrão ---
$installPath = "C:\Program Files\RustDesk"
if (Test-Path $installPath) { Set-Location $installPath }

# --- (Re)instalar serviço ---
Start-Process ".\rustdesk.exe" -ArgumentList "--install-service" -Wait
Start-Sleep -Seconds 10

# --- Capturar ID ---
$rustdesk_id = & ".\rustdesk.exe" --get-id

# --- Aplicar config ---
& ".\rustdesk.exe" --config $rustdesk_cfg

# --- Definir senha ---
& ".\rustdesk.exe" --password $rustdesk_pw

# --- Mostrar resultado final ---
$msg = "ID RustDesk: $rustdesk_id`nSenha: $rustdesk_pw"
[System.Windows.Forms.MessageBox]::Show($msg, "RustDesk Configurado")
