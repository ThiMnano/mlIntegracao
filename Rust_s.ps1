$ErrorActionPreference = 'SilentlyContinue'

If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

function TimerSleep{
    param($seconds, $message)
    for ($i = $seconds; $i -ge 1; $i--) {
        $percent = [int](($seconds - $i) / $seconds * 100)
        Write-Progress -Activity $message -Status "$i segundos restantes" -PercentComplete $percent
        Start-Sleep -Seconds 1
    }
}
function UltimaVesao {
    Write-Output "Buscando versao mais recente do RustDesk..."
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try { 
        $HTML.IHTMLDocument2_write($Page.Content) 
    } 
    catch { 
        $HTML.write([System.Text.Encoding]::Unicode.GetBytes($Page.Content)) 
    }
    $DownloadLink = ($HTML.Links | Where-Object { $_.href -match 'rustdesk/.+x86_64\.exe' } | Select-Object -First 1).href
    $DownloadLink = $DownloadLink.Replace('about:', 'https://github.com')
    if ($DownloadLink -match '/rustdesk/rustdesk/releases/download/(?<v>.*)/rustdesk-(.+)x86_64.exe') { 
        $Version = $matches['v'] 
    } 
    else { 
        $Version = "unknown" 
    }
    if ($Version -eq "unknown" -or [string]::IsNullOrEmpty($DownloadLink)) {
        Write-Output "Erro: link ou versão não encontrados"; 
        Exit 1 
    }
    return @{ Version = $Version; DownloadLink = $DownloadLink }
}
function Instalar {
    param($Latest)
    $rdver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue).Version
    if ($rdver -and $rdver -eq $Latest.Version) {
        Write-Output "RustDesk $rdver ja e a versao mais recente."
        return
    }
    Write-Output "Instalando/atualizando RustDesk versao $($Latest.Version)..."
    if (!(Test-Path C:\Temp)) {
        New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null 
    }
    Push-Location C:\Temp
    try {
        Write-Output "Baixando RustDesk..."
        Invoke-WebRequest $Latest.DownloadLink -OutFile "rustdesk.exe"
        Write-Output "Executando instalacao..."
        Start-Process -FilePath .\rustdesk.exe -ArgumentList '--silent-install' -Wait
    }
    catch {
         Write-Output "Falha ao baixar ou instalar RustDesk"
    }
}
function Config_PegarId {
    if (-not (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe")) {
        Write-Output "Erro: rustdesk.exe nao encontrado em $env:ProgramFiles\RustDesk"
        Exit 1
    }
    Push-Location "$env:ProgramFiles\RustDesk"
    
    & .\rustdesk.exe --install-service
    TimerSleep(10, "Aguardando servico iniciar...")
    
    $id = & .\rustdesk.exe --get-id 2>&1 | Out-String
    $id = $id.Trim()
    
    & .\rustdesk.exe --config "host=acesso.sistemasnano.com.br,relay=acesso.sistemasnano.com.br,key=714N6tBWc1EwLZxJfAMbjDf2J39BBYI2XxvH8SistKk="
    & .\rustdesk.exe --password "@acessN@n0!"
   
    Write-Output "..............................................."
    Write-Output "RustDesk ID: $id"
    Write-Output "Password: @acessN@n0!"
    Write-Output "..............................................."
    
    $folder = "C:\Nano"
    if (-not (Test-Path $folder)) { 
        New-Item -Path $folder -ItemType Directory | Out-Null
    }
    if (-not [string]::IsNullOrEmpty($id)) {
        [System.IO.File]::WriteAllText("$folder\RustDeskID.txt", $id)
        Write-Host "ID $id salvo em $folder\RustDeskID.txt"
    } else {
        Write-Host "Erro: não foi possível obter o RustDesk ID"
    }
}



Write-Host "Verificando instalação do RustDesk..."
if (Test-Path "C:\Program Files\RustDesk\rustdesk.exe") {
    Write-Host "RustDesk já instalado."
    $RustDeskOnGitHub = UltimaVesao
    Instalar -Latest $RustDeskOnGitHub
    TimerSleep(10, "Aguardando...")
    Config_PegarId
} else {
    Write-Host "RustDesk não encontrado. Instalando..."
}
