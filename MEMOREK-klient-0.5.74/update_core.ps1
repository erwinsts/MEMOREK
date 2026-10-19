function Get-MemorekPackage([string]$Root,[string]$CurrentVersion) {
    $manifest=Join-Path $Root 'build\update.json'
    if((Get-Item -LiteralPath $manifest).Length -gt 65536){throw 'Opis aktualizacji jest zbyt duży.'}
    $m=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    if($m.version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$' -or $CurrentVersion -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$'){throw 'Nieprawidłowy numer wersji.'}
    if([version]$m.version -le [version]$CurrentVersion){throw 'Brak nowszej wersji.'}
    if($m.file -cne "MEMOREK-$($m.version).exe" -or $m.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Nieprawidłowy pakiet aktualizacji.'}
    $candidate=Join-Path $Root ('build\'+$m.file)
    if((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $m.sha256){throw 'Plik aktualizacji jest uszkodzony lub został zmieniony.'}
    return @{ Manifest=$m; Candidate=$candidate; Root=$Root }
}
function Install-MemorekPackage($Package) {
    $target=Join-Path $Package.Root 'MEMOREK.exe'
    $running=@(Get-Process MEMOREK -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $target})
    if($running.Count){throw 'MEMOREK jest nadal otwarty. Aktualizacja czeka na zapis rozmowy.'}
    $expected=$Package.Manifest.sha256
    if((Get-FileHash -LiteralPath $Package.Candidate -Algorithm SHA256).Hash -ne $expected){throw 'Pakiet zmienił się po sprawdzeniu.'}
    $stamp=Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $backup=Join-Path $Package.Root "build\MEMOREK-przed-$($Package.Manifest.version)_$stamp.exe"
    Copy-Item -LiteralPath $target -Destination $backup
    $archive=Join-Path $Package.Root 'native-data\conversations.json'
    if(Test-Path -LiteralPath $archive) {
        $backups=Join-Path $Package.Root 'native-data\backups'
        New-Item -ItemType Directory -Path $backups -Force | Out-Null
        Copy-Item -LiteralPath $archive -Destination (Join-Path $backups "upgrade_conversations_$stamp.json")
    }
    $temporary=Join-Path $Package.Root 'MEMOREK.update.tmp'
    Copy-Item -LiteralPath $Package.Candidate -Destination $temporary
    if((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $expected){throw 'Niepoprawna kopia aktualizacji. Poprzedni program zachowany.'}
    if(-not ('MemorekAtomicUpdate' -as [type])) {
        Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class MemorekAtomicUpdate { [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool MoveFileEx(string source,string destination,uint flags); }'
    }
    if(![MemorekAtomicUpdate]::MoveFileEx($temporary,$target,9)){throw "Nie można podmienić programu: $([Runtime.InteropServices.Marshal]::GetLastWin32Error()). Poprzedni program zachowany."}
    return $backup
}
