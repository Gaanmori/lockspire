# ADR 0040 — Descargas en GitHub Releases

- **Estado:** Aceptado
- **Fecha:** 2026-10-06
- **Origen:** el usuario pidió una sección "Descarga" en el README, siempre actualizada con lo último disponible para Android, Windows y Linux, mientras las tiendas no están listas.
- **Amplía:** ADR 0038 (paquetes de Linux), cuyo flujo `linux-packages.yml` pasa a ser un trabajo de `release.yml`.

## Decisión

- **Publicar una etiqueta `vX.Y.Z`** dispara `.github/workflows/release.yml`, que crea la release con:
  - el AppImage y el .deb de Linux;
  - el .zip de Windows: el build release con el native host, en una carpeta `Lockspire`, sin donaciones;
  - `Lockspire-extension.zip`: el build de la extensión con la clave de desarrollo, cuyo ID ya está en `allowedExtensionIds`, para cargarla descomprimida;
  - `SHA256SUMS.txt`.
- **Nombres fijos y sin versión** (`Lockspire-x86_64.AppImage`, `lockspire_amd64.deb`, `Lockspire-windows-x64.zip`, `Lockspire-android.apk`…). El README enlaza `releases/latest/download/<nombre>`, que GitHub resuelve a la última release: no hay que editar el README en cada versión. La versión va en el título de la release y en una insignia.
- **La etiqueta tiene que coincidir con la versión de `app/pubspec.yaml`**, o no se publica nada.
- **El APK de Android no se compila en GitHub.** Lo firma la clave de subida (`app/android/key.properties`), que nunca sale del equipo del autor. `tools/release_android.ps1`:
  - lo compila sin donaciones (Play Billing solo funciona instalado desde Play);
  - se niega a subirlo si va firmado con la clave de depuración;
  - lo sube a la release y agrega su huella a `SHA256SUMS.txt`.

## Alternativas descartadas

- **Firmar el APK en GitHub Actions** con la clave en los secretos del repositorio: más cómodo, pero la clave quedaría en un servicio externo. Seguridad por encima de comodidad.
- **Una clave aparte para GitHub:** una clave más que custodiar, sin ventaja real. El certificado público es el mismo que se ve en cualquier APK.
- **Un MSIX autofirmado para Windows:** obliga a cada usuario a confiar en un certificado. El .zip se abre directamente; el MSIX es para la Microsoft Store.

## Consecuencias

- **El APK de GitHub y el de Google Play no se actualizan entre sí.** Play reemplaza la firma con la clave de Google (Play App Signing). Pasar de uno a otro exige desinstalar; el README avisa que se sincronice o se exporte antes.
- **El .exe de Windows no está firmado.** SmartScreen avisa la primera vez, y el README explica cómo continuar. Firmarlo requiere un certificado de firma de código, pendiente.
- **Publicar una versión** son dos pasos: el autor empuja la etiqueta y, cuando termina `release.yml`, ejecuta `tools/release_android.ps1`.
