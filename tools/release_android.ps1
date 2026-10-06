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

  Requiere gh con sesión iniciada. Si la release todavía no existe (el flujo
  tarda unos minutos después de empujar la etiqueta), espera hasta 15 min.

.EXAMPLE
  powershell -File tools/release_android.ps1 -Tag v1.0.0
#>
param(
  [Parameter(Mandatory)] [string]$Tag,
  [string]$Repo = 'Gaanmori/lockspire'
)

$ErrorActionPreference = 'Stop'

# En Windows PowerShell 5.1, con 'Stop', una línea en stderr de un programa
# externo (gh, flutter, Gradle) corta el script aunque el programa termine
# bien. Corren con 'Continue' y se juzgan por $LASTEXITCODE.
function Invoke-Native([scriptblock]$Command) {
  $ErrorActionPreference = 'Continue'
  & $Command
}

function Test-Release {
  Invoke-Native { gh release view $Tag --repo $Repo 2>&1 } | Out-Null
  $LASTEXITCODE -eq 0
}

$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$apkName = 'Lockspire-android.apk'

# La etiqueta tiene que ser la versión de pubspec.yaml, como en release.yml.
$pubspec = (Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
if ($Tag -ne "v$pubspec") { throw "La etiqueta $Tag no coincide con la versión $pubspec de app/pubspec.yaml" }
if (-not (Test-Path (Join-Path $app 'android\key.properties'))) {
  throw 'Falta app/android/key.properties: sin la clave de subida el APK sale firmado con la de depuración (docs/release-android.md)'
}
$deadline = (Get-Date).AddMinutes(15)
while (-not (Test-Release)) {
  if ((Get-Date) -gt $deadline) {
    throw "La release $Tag no apareció en 15 min: revise el flujo Release en GitHub Actions"
  }
  Write-Host "La release $Tag todavía no existe: GitHub la está creando (flujo Release). Reintento en 30 s..."
  Start-Sleep -Seconds 30
}

Push-Location $app
try {
  $defines = @()
  foreach ($secrets in 'google_oauth_secrets.json', 'microsoft_oauth_secrets.json') {
    if (Test-Path $secrets) { $defines += "--dart-define-from-file=$secrets" }
    else { Write-Warning "Sin $secrets`: esa nube no va a funcionar en este APK" }
  }
  Invoke-Native { flutter build apk --release @defines } | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk falló ($LASTEXITCODE)" }
} finally {
  Pop-Location
}

$apk = Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk'

# Quién lo firmó: nunca la clave de depuración.
$buildTools = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools') -Directory |
  Sort-Object { [version]$_.Name } | Select-Object -Last 1
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$signer = Invoke-Native { & $apksigner verify --print-certs $apk 2>&1 }
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
Invoke-Native { gh release download $Tag --repo $Repo --pattern 'SHA256SUMS.txt' --dir $out } | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar SHA256SUMS.txt de la release' }
$lines = @(Get-Content $sums | Where-Object { $_ -notmatch [regex]::Escape($apkName) })
$lines += "$hash  $apkName"
# LF y sin BOM, como lo escribe sha256sum en release.yml.
[IO.File]::WriteAllText($sums, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

Invoke-Native { gh release upload $Tag (Join-Path $out $apkName) $sums --repo $Repo --clobber } | Out-Host
if ($LASTEXITCODE -ne 0) { throw "gh release upload falló ($LASTEXITCODE)" }
Write-Host "Listo: $apkName en la release $Tag (SHA-256 $hash)"
