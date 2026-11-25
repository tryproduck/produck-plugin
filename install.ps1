$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not ('ProduckPathIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ProduckPathIdentity {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    public static extern uint GetLongPathNameW(string path, StringBuilder buffer, uint capacity);
}
'@
}
function Get-ProduckPathIdentity($entry) {
    $normalized = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"')).Replace('/', '\').TrimEnd('\')
    if ($normalized -eq '') { return '' }
    if ($normalized -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+(?:\\|$))') { return $normalized }
    try {
        $absolute = [IO.Path]::GetFullPath($normalized)
        $buffer = [Text.StringBuilder]::new(32768)
        $length = [ProduckPathIdentity]::GetLongPathNameW($absolute, $buffer, $buffer.Capacity)
        if ($length -gt 0 -and $length -lt $buffer.Capacity) { return $buffer.ToString().TrimEnd('\') }
    } catch { }
    return $normalized
}
if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    throw 'Produck supports Windows x64 only. Run 64-bit Windows PowerShell.'
}
$tar = Join-Path $env:SystemRoot 'System32/tar.exe'
if (-not (Test-Path -LiteralPath $tar)) { throw 'Produck requires tar.exe (included with Windows 10 and newer).' }
$base = if ($env:PRODUCK_RELEASE_URL) { $env:PRODUCK_RELEASE_URL } else { 'https://github.com/tryproduck/produck-plugin/releases/download/v0.1.0-84.1' }
if ($base -eq '__PRODUCK_RELEASE_URL__') { throw 'Use install.ps1 from a GitHub Release, or set PRODUCK_RELEASE_URL.' }
if ($base -notmatch '^https://[^\s]+$' -and $base -notmatch '^http://127\.0\.0\.1:[0-9]+(?:/[^\s]*)?$') {
    throw 'PRODUCK_RELEASE_URL must be HTTPS (or a loopback HTTP test server).'
}
$homePath = if ($env:PRODUCK_HOME) { $env:PRODUCK_HOME } else { Join-Path $HOME '.produck' }
$setupArguments = @($args)
for ($i = 0; $i -lt $setupArguments.Count; $i++) {
    if ($setupArguments[$i] -eq '--home') {
        if ($i + 1 -ge $setupArguments.Count) { throw '--home requires a directory' }
        $homePath = $setupArguments[++$i]
    } elseif ($setupArguments[$i] -like '--home=*') { $homePath = $setupArguments[$i].Substring(7) }
}
$homePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($homePath)
$setupArguments += @('--home', $homePath)
$null = New-Item -ItemType Directory -Force -Path $homePath
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
Set-Acl -LiteralPath $homePath -AclObject $acl
if (Get-ChildItem -LiteralPath $homePath -Force | Select-Object -First 1) {
    & (Join-Path $env:SystemRoot 'System32/icacls.exe') (Join-Path $homePath '*') /reset /T /L /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not restrict Produck home permissions' }
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('produck-install-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $metadata = Join-Path $temporary 'release.env'
    Invoke-WebRequest -UseBasicParsing "$base/release.env" -OutFile $metadata
    $release = @{}
    Get-Content -LiteralPath $metadata | ForEach-Object {
        $pair = $_ -split '=', 2
        if ($pair.Count -eq 2) { $release[$pair[0]] = $pair[1] }
    }
    $version = $release['VERSION']
    if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-(?:test\.)?[0-9]+\.[0-9]+)?$') { throw 'Invalid release VERSION.' }
    $hash = $release['SHA256_WIN32_X64']
    if (-not $hash) { throw 'Development build: run ./run.sh in the Produck checkout' }
    if ($hash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid Windows archive SHA-256.' }
    $downloadBase = if ($release['BASE_URL']) { $release['BASE_URL'] } else { $base }
    if ($downloadBase -notmatch '^https://[^\s]+$' -and $downloadBase -notmatch '^http://127\.0\.0\.1:[0-9]+(?:/[^\s]*)?$') { throw 'Invalid release BASE_URL.' }
    $archive = Join-Path $temporary 'produck.tar.gz'
    Invoke-WebRequest -UseBasicParsing "$downloadBase/produck-$version-win32-x64.tar.gz" -OutFile $archive
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash -ne $hash) { throw 'Produck archive SHA-256 mismatch.' }
    $appRoot = Join-Path $homePath 'app'
    New-Item -ItemType Directory -Force -Path $appRoot | Out-Null
    $app = Join-Path $appRoot $version
    $receipt = Join-Path $app 'archive.sha256'
    if (Test-Path -LiteralPath $app) {
        if (-not (Test-Path -LiteralPath $receipt) -or (Get-Content -Raw -LiteralPath $receipt).Trim() -ne $hash) {
            throw 'This Produck version already exists without a matching archive receipt. Remove it before reinstalling.'
        }
    } else {
        $staging = Join-Path $appRoot ('.install-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $staging | Out-Null
        try {
            & $tar -xzf $archive -C $staging
            if ($LASTEXITCODE -ne 0) { throw 'Produck archive extraction failed.' }
            if (-not (Test-Path -LiteralPath (Join-Path $staging 'node.exe')) -or -not (Test-Path -LiteralPath (Join-Path $staging 'produck.cjs'))) { throw 'Invalid Produck archive.' }
            Copy-Item -LiteralPath $metadata -Destination (Join-Path $staging 'release.env')
            Set-Content -LiteralPath (Join-Path $staging 'archive.sha256') -Value $hash -Encoding ASCII
            Move-Item -LiteralPath $staging -Destination $app
        } finally { if (Test-Path -LiteralPath $staging) { Remove-Item -Recurse -Force -LiteralPath $staging } }
    }
    $previousPath = $env:PATH
    try {
        $env:PATH = "$app;$previousPath"
        & (Join-Path $app 'node.exe') (Join-Path $app 'produck.cjs') setup @setupArguments
        if ($LASTEXITCODE -ne 0) { throw "Produck setup failed (exit $LASTEXITCODE)." }
    } finally {
        $env:PATH = $previousPath
        $bin = Join-Path $homePath 'bin'
        if (Test-Path -LiteralPath (Join-Path $bin 'produck.cmd')) {
            $target = Get-ProduckPathIdentity $bin
            $entries = @($previousPath -split ';' | Where-Object {
                $_ -ne '' -and -not [string]::Equals((Get-ProduckPathIdentity $_), $target, [StringComparison]::OrdinalIgnoreCase)
            })
            $env:PATH = (@($bin) + $entries) -join ';'
        }
    }
    [Console]::Out.WriteLine('Produck installed. CLI: ~/.produck/bin/produck.cmd')
} finally { Remove-Item -Recurse -Force -LiteralPath $temporary }
