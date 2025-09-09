$ErrorActionPreference = 'SilentlyContinue'

# --- Elevar privilégios se necessário ---
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`""
        Exit
    }
}

# --- Função para pegar versão mais recente do GitHub ---
function Get-LatestRustDesk {
    Write-Output "Buscando versão mais recente do RustDesk..."
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try { $HTML.IHTMLDocument2_write($Page.Content) } catch { $src = [System.Text.Encoding]::Unicode.GetBytes($Page.Content); $HTML.write($src) }

    $DownloadLink = ($HTML.Links |
        Where-Object { $_.href -match '(.)+\/rustdesk\/rustdesk\/releases\/download\/\d{1,}\.\d{1,}\.\d{1,}(.{0,3})\/rustdesk(.)+x86_64.exe' } |
        Select-Object -First 1).href

    $DownloadLink = $DownloadLink.Replace('about:', 'https://github.com')
    $Version = "unknown"

    if ($DownloadLink -match '/rustdesk/rustdesk/releases/download/(?<content>.*)/rustdesk-(.)+x86_64.exe') { 
        $Version = $matches['content'] 
    }

    if ($Version -eq "unknown" -or [string]::IsNullOrEmpty($DownloadLink)) { 
        Write-Output "ERRO: Versão ou link de download não encontrado."
        Exit 1
    }

    return @{ Version = $Version; DownloadLink = $DownloadLink }
}

# --- Função para instalar ou atualizar RustDesk ---
function Ensure-RustDeskInstalled {
    param($Latest)

    $rdver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue).Version
    if ($rdver -and $rdver -eq $Latest.Version) {
        Write-Output "RustDesk $rdver já é a versão mais recente."
        return
    }

    Write-Output "Instalando/atualizando RustDesk para a versão $($Latest.Version)..."

    if (!(Test-Path C:\Temp)) { New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null }
    Push-Location C:\Temp

    try {
        Write-Output "Baixando RustDesk..."
        Invoke-WebRequest $Latest.DownloadLink -OutFile "rustdesk.exe"
        Write-Output "Executando instalação silenciosa..."
        Start-Process -FilePath .\rustdesk.exe -ArgumentList '--silent-install' -Wait
    } finally { Pop-Location }

    # Instalar serviço se não existir
    $ServiceName = 'Rustdesk'
    $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($arrService -eq $null) {
        Write-Output "Registrando serviço RustDesk..."
        if (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe") {
            Push-Location "$env:ProgramFiles\RustDesk"
            Start-Process -FilePath .\rustdesk.exe -ArgumentList '--install-service' -Wait
            Pop-Location
        } else {
            Write-Output "Erro: binário do RustDesk não encontrado após instalação."
        }
    }
}

# --- Função para garantir que o serviço está rodando ---
function Ensure-ServiceRunning {
    param($ServiceName='Rustdesk')
    $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($arrService -eq $null) { return }
    while ($arrService.Status -ne 'Running') {
        Start-Service $ServiceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $arrService.Refresh()
    }
}

# --- Função para configurar RustDesk e pegar ID ---
function Configure-And-GetId {
    if (-not (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe")) {
        Write-Output "Erro: rustdesk.exe não encontrado em $env:ProgramFiles\RustDesk"
        Exit 1
    }

    Push-Location "$env:ProgramFiles\RustDesk"
    try {
        Write-Output "Instalando serviço (caso ainda não tenha)..."
        & .\rustdesk.exe --install-service

        # Espera visual
        $seconds = 5
        for ($i = $seconds; $i -ge 1; $i--) {
            $percent = [int](($seconds - $i) / $seconds * 100)
            Write-Progress -Activity "Aguardando..." -Status "$i segundos restantes" -PercentComplete $percent
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity "Aguardando..." -Completed
        Write-Host "Continuando..."

        # Obter ID
        $id = & .\rustdesk.exe --get-id 2>&1 | Out-String
        $id = $id.Trim()

        # Configuração e senha
        & .\rustdesk.exe --config "host=acesso.sistemasnano.com.br,relay=acesso.sistemasnano.com.br,key=714N6tBWc1EwLZxJfAMbjDf2J39BBYI2XxvH8SistKk="
        & .\rustdesk.exe --password "@acessN@n0!"

        Ensure-ServiceRunning -ServiceName 'Rustdesk'

        # Exibir ID e senha
        Write-Output "..............................................."
        Write-Output "RustDesk ID: $id"
        Write-Output "Password: @acessN@n0!"
        Write-Output "..............................................."

        # Segurar a janela aberta
        Write-Host "`nPressione ENTER para sair..."
        Read-Host

    } finally { Pop-Location }
}

# --- Execução principal ---
$RustDeskOnGitHub = Get-LatestRustDesk
Ensure-RustDeskInstalled -Latest $RustDeskOnGitHub
Configure-And-GetId
