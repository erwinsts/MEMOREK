param([string]$Root=$PSScriptRoot,[string]$CurrentVersion='0.5.1',[int]$WaitPid=0,[switch]$Preview)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'update_core.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
Add-Type -TypeDefinition 'using System;using System.Text;using System.Runtime.InteropServices;public class MemorekUpdateWindow { [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h,int id); [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder text,int count); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l); }'
$created=$false
$key=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Root))).Replace('/','_')
$mutex=[Threading.Mutex]::new($true,('Local\MemorekUpdate_'+$key),[ref]$created)
if(!$created){$mutex.Dispose();exit}
$form=[Windows.Forms.Form]::new()
$form.Text='Aktualizacja MEMORKA';$form.ClientSize=[Drawing.Size]::new(560,480)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$form.ControlBox=$true;$form.ShowIcon=$true
try{$form.Icon=[Drawing.Icon]::ExtractAssociatedIcon((Join-Path $Root 'MEMOREK.exe'))}catch{}
$form.BackColor=[Drawing.Color]::FromArgb(245,247,251)
$form.Font=[Drawing.Font]::new('Segoe UI',10)
function Label([string]$text,[int]$x,[int]$y,[int]$width,[int]$height) {
    $item=[Windows.Forms.Label]::new();$item.Text=$text;$item.Location=[Drawing.Point]::new($x,$y);$item.Size=[Drawing.Size]::new($width,$height)
    $item.ForeColor=[Drawing.Color]::FromArgb(43,64,98);$form.Controls.Add($item);return $item
}
$title=Label 'Nowa wersja MEMORKA' 26 22 510 38
$title.Font=[Drawing.Font]::new('Segoe UI',19,[Drawing.FontStyle]::Bold)
$versions=Label "Obecna wersja: $CurrentVersion" 28 70 500 26
$heading=Label 'CO SIĘ ZMIENIA' 28 113 500 24
$heading.Font=[Drawing.Font]::new('Segoe UI',10,[Drawing.FontStyle]::Bold)
$changes=[Windows.Forms.TextBox]::new();$changes.Location=[Drawing.Point]::new(28,144);$changes.Size=[Drawing.Size]::new(504,142)
$changes.Multiline=$true;$changes.ReadOnly=$true;$changes.ScrollBars='Vertical';$changes.BorderStyle='None'
$changes.TabStop=$false
$changes.BackColor=$form.BackColor;$changes.ForeColor=[Drawing.Color]::FromArgb(65,80,105);$form.Controls.Add($changes)
$step=Label 'Sprawdzanie przygotowanej aktualizacji…' 28 305 454 25
$percent=Label '0%' 482 305 50 25;$percent.TextAlign='TopRight'
$bar=[Windows.Forms.ProgressBar]::new();$bar.Location=[Drawing.Point]::new(28,338);$bar.Size=[Drawing.Size]::new(504,13);$form.Controls.Add($bar)
$autoClose=[Windows.Forms.CheckBox]::new()
$autoClose.Name='AutoCloseUpdate';$autoClose.Text='Zamknij okno automatycznie po aktualizacji'
$autoClose.Location=[Drawing.Point]::new(28,367);$autoClose.Size=[Drawing.Size]::new(504,30)
$autoClose.Checked=$false;$form.Controls.Add($autoClose)
$settingsFile=Join-Path $Root 'native-data\update-settings.json'
try {
    if(Test-Path -LiteralPath $settingsFile) {
        $settings=Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if($settings.autoClose -is [bool]){$autoClose.Checked=$settings.autoClose}
    }
}catch{}
$note=Label 'Rozmowy zostaną zapisane przed ponownym uruchomieniem.' 28 411 360 48
$note.Font=[Drawing.Font]::new('Segoe UI',9)
$close=[Windows.Forms.Button]::new();$close.Text='Anuluj';$close.Location=[Drawing.Point]::new(422,419);$close.Size=[Drawing.Size]::new(110,36)
$close.Add_Click({$form.Close()});$form.Controls.Add($close)
$script:stage=0;$script:critical=$false;$script:finished=$false;$script:backup=$null;$script:app=$null
$script:completed=$false;$script:ownsMutex=$true;$script:shuttingDown=$false
$script:deadline=(Get-Date).AddMinutes(10);$script:requested=$false;$script:closedOld=$false
$log=Join-Path $Root 'build\update_progress.log'
function Progress([int]$value,[string]$text) {
    $bar.Value=$value;$percent.Text="$value%";$step.Text=$text
    "$(Get-Date -Format o) $value% $text" | Add-Content -LiteralPath $log -Encoding UTF8
}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=350
$autoClose.Add_CheckedChanged({
    if($script:shuttingDown){return}
    try {
        New-Item -ItemType Directory -Path (Split-Path $settingsFile -Parent) -Force | Out-Null
        @{autoClose=[bool]$autoClose.Checked} | ConvertTo-Json | Set-Content -LiteralPath ($settingsFile+'.tmp') -Encoding UTF8
        Move-Item -LiteralPath ($settingsFile+'.tmp') -Destination $settingsFile -Force
    }catch{}
    if($script:completed) {
        $script:finished=!$autoClose.Checked
        if($autoClose.Checked){
            $script:finishAt=(Get-Date).AddSeconds(5)
            $note.Text='Rozmowy zachowane. Okno zamknie się za 5 sekund.'
            $timer.Start()
        }else{
            $timer.Stop();$note.Text='Przeczytaj zmiany i zamknij okno, gdy zechcesz.'
        }
    }
})
$timer.Add_Tick({
    $timer.Stop()
    try {
        switch($script:stage) {
            0 {
                $script:package=Get-MemorekPackage $Root $CurrentVersion
                $versions.Text="$CurrentVersion  →  $($package.Manifest.version)"
                $changes.Text=(@($package.Manifest.changes) | ForEach-Object { '• '+$_ }) -join "`r`n`r`n"
                if($Preview){Progress 35 'Podgląd okna — instalacja nie jest wykonywana';$script:finished=$true;$close.Text='Zamknij';return}
                Progress 20 'Plik aktualizacji sprawdzony'
                $script:stage=1
            }
            1 {
                $old=if($WaitPid){Get-Process -Id $WaitPid -ErrorAction SilentlyContinue}else{$null}
                if($old -and !$old.HasExited) {
                    if($old.Path -ne (Join-Path $Root 'MEMOREK.exe')){throw 'Identyfikator starego programu już nie wskazuje na MEMORKA.'}
                    if((Get-Date) -gt $deadline){throw 'Nie udało się zamknąć programu. Rozmowa nie została przerwana.'}
                    if(!$requested){Progress 30 'Oczekiwanie na zapis rozmowy…';$script:requested=$true}
                    if([version]$CurrentVersion -ge [version]'0.5.2') {
                        [MemorekUpdateWindow]::PostMessage($old.MainWindowHandle,0x803D,[IntPtr]0,[IntPtr]0) | Out-Null
                        $script:critical=$true;$close.Enabled=$false
                    } else {
                        $text=[Text.StringBuilder]::new(256)
                        [MemorekUpdateWindow]::GetWindowText([MemorekUpdateWindow]::GetDlgItem($old.MainWindowHandle,41),$text,256) | Out-Null
                        if($text.ToString() -notmatch 'Zaj') {
                            $script:critical=$true;$close.Enabled=$false
                            [MemorekUpdateWindow]::PostMessage($old.MainWindowHandle,0x10,[IntPtr]0,[IntPtr]0) | Out-Null
                        }
                    }
                } else {$script:closedOld=$true;Progress 45 'Rozmowa zapisana, stary program zamknięty';$script:stage=2;$script:critical=$true;$close.Enabled=$false}
            }
            2 {
                Progress 55 'Tworzenie kopii i instalowanie nowej wersji…'
                $script:backup=Install-MemorekPackage $package
                Progress 80 'Nowa wersja zainstalowana'
                $script:stage=3
            }
            3 {
                $script:app=Start-Process -FilePath (Join-Path $Root 'MEMOREK.exe') -WorkingDirectory $Root -WindowStyle Normal -PassThru
                $script:deadline=(Get-Date).AddSeconds(25)
                Progress 90 'Uruchamianie MEMORKA…';$script:stage=4
            }
            4 {
                $app.Refresh()
                if($app.HasExited){throw 'Nowa wersja zakończyła się podczas uruchamiania.'}
                if($app.MainWindowTitle -like "MEMOREK $($package.Manifest.version) |*") {
                    Progress 100 "Gotowe — działa MEMOREK $($package.Manifest.version)"
                    $note.Text='Przeczytaj zmiany i zamknij okno, gdy zechcesz.'
                    $script:critical=$false;$close.Enabled=$true;$close.Text='Zamknij'
                    $script:completed=$true;$script:stage=5;$script:finished=!$autoClose.Checked
                    if($autoClose.Checked){$script:finishAt=(Get-Date).AddSeconds(5);$note.Text='Rozmowy zachowane. Okno zamknie się za 5 sekund.'}
                    $mutex.ReleaseMutex();$script:ownsMutex=$false
                    $form.Activate();$form.BringToFront();$close.Focus() | Out-Null
                } elseif((Get-Date) -gt $deadline){throw 'Nie potwierdzono uruchomienia nowej wersji. Sprawdź okno MEMORKA.'}
            }
            5 {
                if($autoClose.Checked -and (Get-Date) -ge $script:finishAt){$script:finished=$true;$form.Close()}
            }
        }
        if(!$finished){$timer.Start()}
    } catch {
        $message=$_.Exception.Message
        if($backup -and (!$app -or $app.HasExited)) {
            try {
                $rollback=Join-Path $Root 'MEMOREK.rollback.tmp'
                Copy-Item -LiteralPath $backup -Destination $rollback
                if(![MemorekAtomicUpdate]::MoveFileEx($rollback,(Join-Path $Root 'MEMOREK.exe'),9)){throw 'Nie można przywrócić EXE.'}
                Start-Process -FilePath (Join-Path $Root 'MEMOREK.exe') -WorkingDirectory $Root -WindowStyle Normal | Out-Null
                $message+=' Przywrócono i uruchomiono poprzednią wersję.'
            }catch{$message+=' Kopia poprzedniej wersji: '+$backup}
        }
        if(!$backup -and $closedOld) {
            try{Start-Process -FilePath (Join-Path $Root 'MEMOREK.exe') -WorkingDirectory $Root -WindowStyle Normal | Out-Null;$message+=' Uruchomiono poprzednią wersję.'}catch{}
        }
        $step.Text='Aktualizacja zatrzymana';$note.Text=$message;$note.ForeColor=[Drawing.Color]::Firebrick
        $changes.Text+="`r`n`r`n"+$message
        "BŁĄD: $message" | Add-Content -LiteralPath $log -Encoding UTF8
        $script:critical=$false;$script:finished=$true;$close.Enabled=$true;$close.Text='Zamknij'
    }
})
$form.Add_FormClosing({param($sender,$eventArgs) if($script:critical){$eventArgs.Cancel=$true}else{$script:shuttingDown=$true;$timer.Stop()}})
$form.Add_Shown({$timer.Start()})
try{[Windows.Forms.Application]::Run($form)}finally{$script:shuttingDown=$true;$timer.Dispose();$form.Dispose();if($script:ownsMutex){$mutex.ReleaseMutex()};$mutex.Dispose()}
