$ErrorActionPreference= 'silentlycontinue'
# Assign the value random password to the password variable
#$rustdesk_pw=('@acessN@n0!')
# Get your config string from your Web portal and Fill Below
#$rustdesk_cfg="==Qfi0zaLR3cpNFOIZHeYJTSZJkQ5MjSyYGRqJWTBZmS4pFT3VUMjdlQ0ZjT0EzNiojI5V2aiwiIiojIpBXYiwiIyJmLt92Yu8mbh52ch1WZ0NXaz5ybzNXZjFmI6ISehxWZyJCLiInYu02bj5ybuFmbzFWblR3cpNnLvN3clNWYiojI0N3boJye"

if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000)
    {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"" ;
        Exit;
    }
}
function getLatest()
{
    $Page = Invoke-WebRequest -Uri 'https://github.com/rustdesk/rustdesk/releases/latest' -UseBasicParsing
    $HTML = New-Object -Com "HTMLFile"
    try { $HTML.IHTMLDocument2_write($Page.Content) } catch { $src = [System.Text.Encoding]::Unicode.GetBytes($Page.Content); $HTML.write($src) }

    $Downloadlink = ($HTML.Links |
        Where-Object { $_.href -match '(.)+\/rustdesk\/rustdesk\/releases\/download\/\d{1,}\.\d{1,}\.\d{1,}(.{0,3})\/rustdesk(.)+x86_64.exe' } |
        Select-Object -First 1).href
    $Downloadlink = $Downloadlink.Replace('about:', 'https://github.com')
    $Version = "unknown"
    if ($Downloadlink -match '/rustdesk/rustdesk/releases/download/(?<content>.*)/rustdesk-(.)+x86_64.exe') { $Version = $matches['content'] }
    if ($Version -eq "unknown" -or [string]::IsNullOrEmpty($Downloadlink)) { Write-Output "ERROR: Version or download link not found."; Exit 1 }
    return @{ Version = $Version; Downloadlink = $Downloadlink }
}
function Ensure-RustDeskInstalled {
    param($Latest)
    $rdver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" -ErrorAction SilentlyContinue).Version
    if ($rdver -and $rdver -eq $Latest.Version) {
        Write-Output "RustDesk $rdver is the newest version."
        return
    }
    Write-Output "Instalando/atualizando RustDesk para a versÃ£o $($Latest.Version)..."
    if (!(Test-Path C:\Temp)) { New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null }
    Push-Location C:\Temp
    try {
        Invoke-WebRequest $Latest.Downloadlink -OutFile "rustdesk.exe"
        Start-Process -FilePath .\rustdesk.exe -ArgumentList '--silent-install' -Wait
    } finally { Pop-Location }
    $ServiceName = 'Rustdesk'
    $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($arrService -eq $null) {
        Write-Output "Registrando serviÃ§o RustDesk..."
        if (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe") {
            Push-Location "$env:ProgramFiles\RustDesk"
            Start-Process -FilePath .\rustdesk.exe -ArgumentList '--install-service' -Wait
            Pop-Location
        } else {
            Write-Output "Erro: binÃ¡rio do RustDesk nÃ£o encontrado apÃ³s instalaÃ§Ã£o."
        }
    }
}
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
    } finally { Pop-Location }
}

$RustDeskOnGitHub = getLatest
Ensure-RustDeskInstalled -Latest $RustDeskOnGitHub
Configure-And-GetId
pause
