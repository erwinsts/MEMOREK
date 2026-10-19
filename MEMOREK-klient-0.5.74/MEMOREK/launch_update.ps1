param([string]$Root=$PSScriptRoot,[string]$CurrentVersion='',[int]$WaitPid=0)
$ErrorActionPreference='Stop'
try {
    if(!$CurrentVersion) {
        $old=Get-Process MEMOREK -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $Root 'MEMOREK.exe')} | Select-Object -First 1
        if($old -and $old.MainWindowTitle -match 'MEMOREK (\d+\.\d+\.\d+)'){$CurrentVersion=$Matches[1];$WaitPid=$old.Id}
        else {
            $versionFile=Join-Path $Root 'native-data\app-version.txt'
            $CurrentVersion=if(Test-Path -LiteralPath $versionFile){(Get-Content -LiteralPath $versionFile -Raw).Trim()}else{'0.5.1'}
        }
    }
    if($CurrentVersion -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$'){throw 'Nieprawidłowa wersja programu.'}
    $scriptPath=Join-Path $Root 'update_window.ps1'
    $shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $modernShell=Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if(Test-Path -LiteralPath $modernShell){$shell=$modernShell}
    $command='"'+$shell+'" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$scriptPath+'" -Root "'+$Root+'" -CurrentVersion '+$CurrentVersion+' -WaitPid '+$WaitPid
    # WMI starts the updater independently, so closing MEMOREK cannot terminate it.
    $result=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$command;CurrentDirectory=$Root}
    if($result.ReturnValue -ne 0){throw "Nie można uruchomić aktualizacji: $($result.ReturnValue)"}
    $result.ProcessId | Set-Content -LiteralPath (Join-Path $Root 'build\update_process.txt') -Encoding ASCII
    "Uruchomiono okno aktualizacji, PID $($result.ProcessId)" | Set-Content -LiteralPath (Join-Path $Root 'build\update_launch.log') -Encoding UTF8
} catch {
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $Root 'build\update_launch.log') -Encoding UTF8
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Aktualizacja MEMORKA') | Out-Null
    exit 1
}
