Write-Host "==> Iniciando reparo de arquivos do sistema..." -ForegroundColor Cyan

# Passo 1: Verificar disco
chkdsk C: /scan

# Passo 2: Verificar integridade de DLLs do Windows
sfc /scannow

# Passo 3: Restaurar imagem do Windows
DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth

Write-Host "==> Processo concluído. Reinicie o computador." -ForegroundColor Green
Pause
