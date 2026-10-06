# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
<#
.SYNOPSIS
  Arma el paquete MSIX de Lockspire para Windows (Microsoft Store, ADR 0028).

.DESCRIPTION
  Toma el build release (`flutter build windows --release`), le agrega el
  manifiesto de app/windows/packaging y lo empaqueta con makeappx.

  - Para la Store: -Store usa la identidad que asigna Partner Center
    (Lockspire, Store ID 9NXFLQH9LMQN, "Product identity"). Sin -Sign: la
    Store firma el paquete. El build release tiene que estar compilado con
    --dart-define=LOCKSPIRE_STORE=msstore (donaciones con la Store, ADR 0035)
    y las credenciales OAuth.
  - Para probar en este equipo: -Sign crea (o reutiliza) un certificado de
    prueba en el almacén del usuario y firma con él. Para instalarlo, hay que
    confiar en ese certificado (Personas de confianza del equipo, pide
    permisos de administrador); el .cer queda junto al paquete.

.EXAMPLE
  powershell -File tools/build_msix.ps1 -Sign
.EXAMPLE
  powershell -File tools/build_msix.ps1 -Store -Version 1.0.0.0
#>
param(
  [string]$Version = '1.0.0.0',
  [string]$Identity = 'Lockspire.Prueba',
  [string]$Publisher = 'CN=Lockspire Prueba',
  [string]$PublisherDisplayName = 'Lockspire (prueba)',
  [switch]$Store,
  [switch]$Sign
)

if ($Store) {
  if ($Sign) { throw "-Store no se firma: lo firma la Store" }
  # Partner Center → Lockspire → Product identity. No son secretos: van
  # dentro del paquete publicado.
  $Identity = 'gaanmori.Lockspire'
  $Publisher = 'CN=194EE10D-AF31-4B74-BEA3-A850550FE34B'
  $PublisherDisplayName = 'gaanmori'
}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$release = Join-Path $app 'build\windows\x64\runner\Release'
$packaging = Join-Path $app 'windows\packaging'
$out = Join-Path $app 'build\msix'
$stage = Join-Path $out 'stage'
$sdk = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64'

if (-not (Test-Path (Join-Path $release 'lockspire.exe'))) {
  throw "Falta el build release: flutter build windows --release"
}
if (-not (Test-Path (Join-Path $release 'lockspire-native-host.exe'))) {
  throw "Falta lockspire-native-host.exe junto a la app (native-host/README.md)"
}

# Carpeta del paquete: el build, los íconos y el manifiesto con la identidad.
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $release '*') $stage -Recurse
Copy-Item (Join-Path $packaging 'Assets') $stage -Recurse
$manifest = (Get-Content (Join-Path $packaging 'AppxManifest.xml') -Raw -Encoding UTF8).
  Replace('{IDENTITY}', $Identity).
  Replace('{PUBLISHER_DISPLAY_NAME}', $PublisherDisplayName).
  Replace('{PUBLISHER}', $Publisher).
  Replace('{VERSION}', $Version)
[IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $manifest, [Text.UTF8Encoding]::new($false))

$msix = Join-Path $out "Lockspire_${Version}_x64.msix"
& (Join-Path $sdk 'makeappx.exe') pack /d $stage /p $msix /o | Out-Host
if ($LASTEXITCODE -ne 0) { throw "makeappx falló ($LASTEXITCODE)" }

if ($Sign) {
  # Certificado de prueba: solo sirve en este equipo, nunca para publicar.
  $cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq $Publisher -and $_.NotAfter -gt (Get-Date) } |
    Select-Object -First 1
  if (-not $cert) {
    $cert = New-SelfSignedCertificate -Type Custom -Subject $Publisher `
      -KeyUsage DigitalSignature -FriendlyName 'Lockspire (prueba local)' `
      -CertStoreLocation Cert:\CurrentUser\My `
      -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
  }
  Export-Certificate -Cert $cert -FilePath (Join-Path $out 'Lockspire-prueba.cer') | Out-Null
  & (Join-Path $sdk 'signtool.exe') sign /fd SHA256 /sha1 $cert.Thumbprint $msix | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "signtool falló ($LASTEXITCODE)" }
}

Write-Host "Listo: $msix"
