# ADR 0038 — Paquetes de Linux: AppImage y .deb

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario preguntó si desde Windows se podían generar el AppImage, Flatpak y el instalador de Ubuntu. Eligió generarlos en GitHub Actions, empezando por AppImage y .deb.
- **Amplía:** ADR 0028 (canales del MVP) y ADR 0013 (native host).

## Contexto

- Flutter no compila la versión de Linux desde Windows, y el equipo del autor no tiene WSL.
- La extensión del navegador necesita que Chrome o Edge puedan lanzar el native host desde una ruta fija.
- **Snap y Flatpak** confinan la app. Además, los navegadores instalados como Snap o Flatpak no pueden lanzar un native host de fuera. Quedan para después del MVP, como ya decía el ADR 0028.

## Decisión

- **Dónde se compila:** en GitHub Actions (`.github/workflows/linux-packages.yml`), sobre Ubuntu 22.04. Así los binarios corren en glibc 2.35 y posteriores: Ubuntu 22.04 y 24.04, Mint 21 y 22.
  - Al publicar una etiqueta `v*`, el flujo adjunta los paquetes a la release de GitHub.
  - A mano, los deja como artefactos del run.
  - Las credenciales OAuth salen de los secretos del repositorio `GOOGLE_OAUTH_SECRETS_JSON` y `MICROSOFT_OAUTH_SECRETS_JSON`.
- **Armado:** `packaging/linux/build_packages.sh` parte del bundle release, con `lockspire-native-host` junto al ejecutable.
- **.deb:**
  - la app va en `/opt/lockspire` y el enlace en `/usr/bin/lockspire`;
  - lanzador `com.lockspire.lockspire.desktop` e íconos en `hicolor`, en grafito (ADR 0036);
  - depende de GTK 3 (`libgtk-3-0t64 | libgtk-3-0`), `libsecret-1-0` y `libayatana-appindicator3-1`;
  - el host queda en una ruta fija, así que no hace falta nada más.
- **AppImage:** el mismo bundle con `AppRun`, el `.desktop` y el ícono, armado con `appimagetool`. Usa GTK, libsecret y appindicator del sistema.
- **El native host en AppImage:** la app corre desde un montaje temporal (`/tmp/.mount_…`) que cambia en cada arranque. Por eso, si existe la variable `APPIMAGE`:
  - "Conectar con Chrome/Edge" copia el host a `~/.local/share/lockspire/bin/lockspire-native-host` (o `$XDG_DATA_HOME`) y registra esa ruta;
  - la copia es atómica (temporal + rename) y conserva el permiso de ejecución;
  - volver a conectar con una versión nueva la reemplaza, y desconectar la borra.

## Consecuencias

- **La copia del host en AppImage está en una carpeta del usuario,** así que otro proceso del mismo usuario podría reemplazarla. No empeora la situación: el propio AppImage también es un archivo del usuario. El host no maneja secretos y la app valida cada petición.
- **Al actualizar el AppImage,** conviene pulsar "Volver a conectar" para renovar la copia. La versión vieja del host sigue hablando el mismo protocolo v1.
- **`appimagetool`** se descarga en cada build desde su release `continuous` en GitHub.
