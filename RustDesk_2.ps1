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

# --- Pasta temporária ---
$tempPath = "C:\Temp"
if (!(Test-Path $tempPath)) { New-Item -Path $tempPath -ItemType Directory | Out-Null }
Set-Location $tempPath

# --- Obter última versão no GitHub ---
try {
    $tag = (Invoke-RestMethod -Uri "https://api.github.com/repos/rustdesk/rustdesk/releases/latest").tag_name
} catch {
    [System.Windows.Forms.MessageBox]::Show("Falha ao obter versão do RustDesk pela API!", "Erro")
    exit
}

Write-Host "Baixando RustDesk versão $tag ..."
$exeFile = "$tempPath\rustdesk.exe"

Invoke-WebRequest -Uri "https://github.com/rustdesk/rustdesk/releases/download/$tag/rustdesk-$tag-x86_64.exe" -OutFile $exeFile -UseBasicParsing

# --- Instalar em modo silencioso ---
Start-Process $exeFile -ArgumentList "--silent-install" -Wait

Start-Sleep -Seconds 20

# --- Caminho padrão ---
$installPath = "C:\Program Files\RustDesk"
Set-Location $installPath

# --- Instalar serviço ---
Start-Process ".\rustdesk.exe" -ArgumentList "--install-service" -Wait
Start-Sleep -Seconds 20

# --- Capturar ID ---
$rustdesk_id = & ".\rustdesk.exe" --get-id

# --- Aplicar config ---
& ".\rustdesk.exe" --config $rustdesk_cfg

# --- Definir senha ---
& ".\rustdesk.exe" --password $rustdesk_pw

# --- Mostrar resultado final ---
$msg = "ID RustDesk: $rustdesk_id`nSenha: $rustdesk_pw"
[System.Windows.Forms.MessageBox]::Show($msg, "RustDesk Configurado")
