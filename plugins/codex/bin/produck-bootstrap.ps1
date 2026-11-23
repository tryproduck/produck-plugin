
$ErrorActionPreference = 'Stop'
$release = @{}
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release.env') | ForEach-Object { $pair = $_ -split '=', 2; if ($pair.Count -eq 2) { $release[$pair[0]] = $pair[1] } }
if (-not $release['SHA256_WIN32_X64']) { throw 'Development build: run ./run.sh in the Produck checkout' }
$base = $release['BASE_URL']
if ($base -notmatch '^https://[^\s]+$') { throw 'Invalid release BASE_URL.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('produck-' + [guid]::NewGuid() + '.ps1')
try {
  Invoke-WebRequest -UseBasicParsing ($base + '/install.ps1') -OutFile $temporary
  & $temporary @args
} finally { Remove-Item -Force -LiteralPath $temporary }
