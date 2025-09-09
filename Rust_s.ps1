$ErrorActionPreference = 'SilentlyContinue'

# --- Elevar privilégios automaticamente ---
If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- Buscar versão mais recente ---
function Get-LatestRustDesk {
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try { $HTML.IHTMLDocument2_write($Page.Content) } catch { $HTML.write([System.Text.Encoding]::Unicode.GetBytes($Page.Content)) }
    $DownloadLink = ($HTML.Links | Where-Object { $_.href -match 'rustdesk/.+x86_64\.exe' } | Select-Object -First 1).href
    $DownloadLink = $DownloadLink.Replace('about:', 'https://github.com')
    if ($DownloadLink -match '/rustdesk/rustdesk/releases/download/(?<v>.*)/rustdesk-(.+)x86_64.exe') { $Version = $matches['v'] } else { $Version = "unknown" }
    if ($Version -eq "unknown" -or [string]::IsNullOrEmpty($DownloadLink)) { Write-Error "Link ou versão não encontrados"; Exit 1 }
    return @{ Version = $Version; DownloadLink = $DownloadLink }
}

# --- Instalar/Atualizar RustDesk ---
function Ensure-RustDeskInstalled {
    param($Latest)
    $rdver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue).Version
    if ($rdver -and $rdver -eq $Latest.Version) { Write-Host "RustDesk $rdver já é a versão mais recente."; return }

    Write-Host "Instalando/atualizando RustDesk versão $($Latest.Version)..."
    if (!(Test-Path C:\Temp)) { New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null }
    Push-Location C:\Temp
    try {
        Invoke-WebRequest $Latest.DownloadLink -OutFile "rustdesk.exe"
        Start-Process -FilePath .\rustdesk.exe -ArgumentList '--silent-install' -Wait
    } finally { Pop-Location }

    if (-not (Get-Service -Name 'Rustdesk' -ErrorAction SilentlyContinue)) {
        Push-Location "$env:ProgramFiles\RustDesk"
        Start-Process .\rustdesk.exe -ArgumentList '--install-service' -Wait
        Pop-Location
    }
}

# --- Configurar e obter ID ---
function Configure-And-GetId {
    Push-Location "$env:ProgramFiles\RustDesk"
    & .\rustdesk.exe --install-service
    Start-Sleep -Seconds 5
    $id = (& .\rustdesk.exe --get-id).Trim()
    & .\rustdesk.exe --config "host=acesso.sistemasnano.com.br,relay=acesso.sistemasnano.com.br,key=714N6tBWc1EwLZxJfAMbjDf2J39BBYI2XxvH8SistKk="
    & .\rustdesk.exe --password "@acessN@n0!"
    Write-Host "RustDesk ID: $id"
    Write-Host "Password: @acessN@n0!"
    $folder = "C:\Nano"
    if (-not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory | Out-Null }
    [System.IO.File]::WriteAllText("$folder\RustDeskID.txt", $id)
}

# --- Executar ---
$RustDeskOnGitHub = Get-LatestRustDesk
Ensure-RustDeskInstalled -Latest $RustDeskOnGitHub
Configure-And-GetId
