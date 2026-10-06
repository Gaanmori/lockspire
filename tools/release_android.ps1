# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
<#
.SYNOPSIS
  Compila el APK de Android firmado y lo sube a una release de GitHub
  (ADR 0040).

.DESCRIPTION
  La release la crea GitHub Actions al publicar la etiqueta (release.yml),
  con Linux, Windows y la extensión. El APK se compila aquí porque se firma
  con la clave de subida de app/android/key.properties, que nunca sale de
  este equipo.

  - Se niega a subir un APK firmado con la clave de depuración.
  - Sin LOCKSPIRE_STORE: fuera de Google Play no hay donaciones.
  - Sube Lockspire-android.apk (nombre fijo: el README enlaza
    releases/latest/download/Lockspire-android.apk) y agrega su huella a
    SHA256SUMS.txt.

  Requiere gh con sesión iniciada y la release ya creada.

.EXAMPLE
  powershell -File tools/release_android.ps1 -Tag v1.0.0
#>
param(
  [Parameter(Mandatory)] [string]$Tag,
  [string]$Repo = 'Gaanmori/lockspire'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$apkName = 'Lockspire-android.apk'

# La etiqueta tiene que ser la versión de pubspec.yaml, como en release.yml.
$pubspec = (Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
if ($Tag -ne "v$pubspec") { throw "La etiqueta $Tag no coincide con la versión $pubspec de app/pubspec.yaml" }
if (-not (Test-Path (Join-Path $app 'android\key.properties'))) {
  throw 'Falta app/android/key.properties: sin la clave de subida el APK sale firmado con la de depuración (docs/release-android.md)'
}
& gh release view $Tag --repo $Repo *> $null
if ($LASTEXITCODE -ne 0) { throw "No existe la release ${Tag}: primero se publica la etiqueta y termina release.yml" }

Push-Location $app
try {
  $defines = @()
  foreach ($secrets in 'google_oauth_secrets.json', 'microsoft_oauth_secrets.json') {
    if (Test-Path $secrets) { $defines += "--dart-define-from-file=$secrets" }
    else { Write-Warning "Sin $secrets`: esa nube no va a funcionar en este APK" }
  }
  & flutter build apk --release @defines
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk falló ($LASTEXITCODE)" }
} finally {
  Pop-Location
}

$apk = Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk'

# Quién lo firmó: nunca la clave de depuración.
$buildTools = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools') -Directory |
  Sort-Object { [version]$_.Name } | Select-Object -Last 1
$signer = & (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs $apk
if ($LASTEXITCODE -ne 0) { throw 'apksigner: el APK no tiene una firma válida' }
if ($signer -match 'CN=Android Debug') { throw 'El APK está firmado con la clave de depuración: no se sube' }
Write-Host ($signer | Select-String 'certificate DN|SHA-256 digest' | Select-Object -First 2)

$out = Join-Path $root 'build\android-release'
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item $apk (Join-Path $out $apkName) -Force
$hash = (Get-FileHash (Join-Path $out $apkName) -Algorithm SHA256).Hash.ToLower()

# SHA256SUMS.txt de la release, con la línea del APK actualizada.
$sums = Join-Path $out 'SHA256SUMS.txt'
Remove-Item $sums -ErrorAction SilentlyContinue
& gh release download $Tag --repo $Repo --pattern 'SHA256SUMS.txt' --dir $out
if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar SHA256SUMS.txt de la release' }
$lines = @(Get-Content $sums | Where-Object { $_ -notmatch [regex]::Escape($apkName) })
$lines += "$hash  $apkName"
# LF y sin BOM, como lo escribe sha256sum en release.yml.
[IO.File]::WriteAllText($sums, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

& gh release upload $Tag (Join-Path $out $apkName) $sums --repo $Repo --clobber
if ($LASTEXITCODE -ne 0) { throw "gh release upload falló ($LASTEXITCODE)" }
Write-Host "Listo: $apkName en la release $Tag (SHA-256 $hash)"
