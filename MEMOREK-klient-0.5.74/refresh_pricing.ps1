param([string]$Root=$PSScriptRoot,[switch]$FunctionsOnly)
$ErrorActionPreference='Stop'
function Read-ModelRates([string]$Document) {
    if($Document.Length -gt 2000000){throw 'Dokument za duży'}
    $result=@{}
    foreach($label in @('Input','Cached input','Output')) {
        $pattern='(?m)^\|\s*'+[regex]::Escape($label)+'\s*\|\s*\$([0-9]+(?:\.[0-9]+)?)\s*\|\s*1M tokens\s*\|\s*$'
        $matchesFound=[regex]::Matches($Document,$pattern)
        if($matchesFound.Count -ne 1){throw "Brak jednoznacznej stawki: $label"}
        $value=[double]::Parse($matchesFound[0].Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
        if($value -le 0 -or $value -gt 1000){throw 'Niepoprawna stawka'}
        $result[$label]=$value
    }
    if($result['Cached input'] -gt $result.Input){throw 'Cache droższy od wejścia'}
    return @{input=$result.Input;cached=$result['Cached input'];output=$result.Output}
}
if($FunctionsOnly){return}
$cache=Join-Path $Root 'native-data\pricing-cache.json'
$models=@{}
if(Test-Path -LiteralPath $cache){try {$old=Get-Content -LiteralPath $cache -Raw -Encoding UTF8 | ConvertFrom-Json;foreach($entry in $old.models.PSObject.Properties){$models[$entry.Name]=$entry.Value}}catch {}}
$changed=$false
foreach($model in @('gpt-6.1-sol','gpt-6-sol','gpt-6-astra','gpt-6-luna','gpt-5.6-sol','gpt-5.6-luna','gpt-5.3-codex')) {
    try {
        $url="https://developers.openai.com/api/docs/models/$model.md"
        $response=Invoke-WebRequest -Uri $url -TimeoutSec 12 -MaximumRedirection 0 -UseBasicParsing
        $rates=Read-ModelRates $response.Content
        $rates.checkedAt=[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')+' UTC'
        $rates.source=$url
        $models[$model]=$rates;$changed=$true
    } catch { # Keep the last valid price for this model on network or parsing errors.
    }
}
if($changed){
    $data=@{schema=1;models=$models} | ConvertTo-Json -Depth 5
    $temporary=$cache+'.tmp'
    [IO.File]::WriteAllText($temporary,$data,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $cache -Force
}