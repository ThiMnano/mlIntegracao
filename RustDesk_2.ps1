Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = 'SilentlyContinue'

# --- Elevar automaticamente se não for admin ---
If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- Função para pegar a versão mais recente ---
function Get-LatestRustDesk {
    Write-Output "Buscando versão mais recente do RustDesk..."
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try { $HTML.IHTMLDocument2_write($Page.Content) } catch { $HTML.write([System.Text.Encoding]::Unicode.GetBytes($Page.Content)) }
    $DownloadLink = ($HTML.Links | Where-Object { $_.href -match 'rustdesk/.+x86_64\.exe' } | Select-Object -First 1).href
    $DownloadLink = $DownloadLink.Replace('about:', 'https://github.com')
    if ($DownloadLink -match '/rustdesk/rustdesk/releases/download/(?<v>.*)/rustdesk-(.+)x86_64.exe') { $Version = $matches['v'] } else { $Version = "unknown" }
    if ($Version -eq "unknown" -or [string]::IsNullOrEmpty($DownloadLink)) { Write-Output "Erro: link ou versão não encontrados"; Exit 1 }
    return @{ Version = $Version; DownloadLink = $DownloadLink }
}
# --- Instalar ou atualizar RustDesk ---
function Ensure-RustDeskInstalled {
    param($Latest)
    $rdver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue).Version
    if ($rdver -and $rdver -eq $Latest.Version) {
        Write-Output "RustDesk $rdver já é a versão mais recente."
        return
    }

    Write-Output "Instalando/atualizando RustDesk versão $($Latest.Version)..."

    if (!(Test-Path C:\Temp)) { New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null }
    Push-Location C:\Temp
    try {
        Write-Output "Baixando RustDesk..."
        Invoke-WebRequest $Latest.DownloadLink -OutFile "rustdesk.exe"
        Write-Output "Executando instalação silenciosa..."
        Start-Process -FilePath .\rustdesk.exe -ArgumentList '--silent-install' -Wait
    } finally { Pop-Location }

    # Instalar serviço se não existir
    if (-not (Get-Service -Name 'Rustdesk' -ErrorAction SilentlyContinue)) {
        Write-Output "Registrando serviço RustDesk..."
        Push-Location "$env:ProgramFiles\RustDesk"
        Start-Process .\rustdesk.exe -ArgumentList '--install-service' -Wait
        Pop-Location
    }
}
# --- Configurar RustDesk e pegar ID ---
function Configure-And-GetId {
    if (-not (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe")) {
        Write-Output "Erro: rustdesk.exe nÃ£o encontrado em $env:ProgramFiles\RustDesk"
        Exit 1
    }
    Push-Location "$env:ProgramFiles\RustDesk"
    try {
        & .\rustdesk.exe --install-service
        $seconds = 5
        for ($i = $seconds; $i -ge 1; $i--) {
            $percent = [int](($seconds - $i) / $seconds * 100)
            Write-Progress -Activity "Aguardando..." -Status "$i segundos restantes" -PercentComplete $percent
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity "Aguardando..." -Completed
        Write-Host "Continuando..."
        $id = & .\rustdesk.exe --get-id 2>&1 | Out-String
        $id = $id.Trim()
        & .\rustdesk.exe --config "host=acesso.sistemasnano.com.br,relay=acesso.sistemasnano.com.br,key=714N6tBWc1EwLZxJfAMbjDf2J39BBYI2XxvH8SistKk="
        & .\rustdesk.exe --password "@acessN@n0!"
        Ensure-ServiceRunning -ServiceName 'Rustdesk'
        Write-Output "..............................................."
        Write-Output "RustDesk ID: $id"
        Write-Output "Password: @acessN@n0!"
        Write-Output "..............................................."
        $folder = "C:\Nano"
        if (-not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory | Out-Null }       
        $id | Set-Content -Path "$folder\RustDeskID.txt" -Encoding UTF8
    } finally { Pop-Location }
}


# --- Bloco principal ---
Write-Host "Verificando instalação do RustDesk..."
if (Test-Path "C:\Program Files\RustDesk\rustdesk.exe") {
    Write-Host "RustDesk já instalado. Verificando atualização e configurando..."
} else {
    Write-Host "RustDesk não encontrado. Instalando..."
}
$RustDeskOnGitHub = Get-LatestRustDesk
Ensure-RustDeskInstalled -Latest $RustDeskOnGitHub
Configure-And-GetId
