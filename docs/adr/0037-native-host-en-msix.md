# ADR 0037 — Native host de la extensión en el paquete MSIX

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** prueba del MSIX local antes de publicar en Microsoft Store (ADR 0028 y 0035). Con la app instalada, la extensión decía "Error when communicating with the native messaging host".
- **Amplía:** ADR 0013 (native host y canal IPC).

## Contexto

Una app MSIX tiene dos obstáculos para el native messaging de Chrome y Edge:

1. **Virtualización:** MSIX desvía las escrituras en `%LOCALAPPDATA%` y `HKCU` a una copia privada del paquete. El token del canal IPC y el registro del host quedarían invisibles para el navegador.
2. **Carpeta del paquete:** la app vive en `C:\Program Files\WindowsApps\<paquete>\`. Un proceso de fuera del paquete, como el navegador, no puede ejecutar nada ahí: da "Acceso denegado", aunque las ACL muestren permiso de lectura y ejecución para Usuarios. Además, la carpeta cambia con cada versión.

## Decisión

- **Sin virtualización** (`AppxManifest.xml`): `desktop6:FileSystemWriteVirtualization` y `desktop6:RegistryWriteVirtualization` en `disabled`, con la capacidad restringida `unvirtualizedResources`. La Store pide justificarla al enviar la app. El motivo es el canal con la extensión.
- **Alias de ejecución para el host:** el paquete declara una segunda aplicación, `NativeHost`, de consola y sin entrada en el menú Inicio, con `uap3:AppExecutionAlias` `lockspire-native-host.exe`. Windows publica el alias en `%LOCALAPPDATA%\Microsoft\WindowsApps\lockspire-native-host.exe`. El navegador sí puede lanzarlo, con stdin y stdout, y la ruta no cambia entre versiones.
- **El registro apunta al alias:** `NativeMessagingRegistrationAdapter` detecta que la app corre desde una carpeta `WindowsApps`. En ese caso escribe en el manifest la ruta del alias; la existencia del host se sigue comprobando junto a la app. Fuera del paquete (Release, AppImage) no cambia nada.

### Alternativas descartadas

- **Copiar el host a `%LOCALAPPDATA%\Lockspire\bin`:** funcionaría, pero es un ejecutable fuera del paquete. Otro proceso del usuario podría reemplazarlo sin que Windows lo note, y habría que recopiarlo con cada versión. El alias sigue apuntando al binario firmado del paquete.
- **Instalador EXE o MSI aparte:** otra vía de distribución que firmar y mantener.

## Consecuencias

- **Verificado el 2026-09-30** con el paquete de prueba `Lockspire.Prueba` 1.0.2.0: la extensión mostró la cuenta y autocompletó.
- **El registro "para todo el equipo" no sirve en MSIX:** el alias existe solo para cada usuario que instaló la app. El registro por usuario basta.
- **Cambiar el nombre del alias** o del ejecutable del host rompe la extensión en las instalaciones de la Store hasta que la app vuelva a registrarse.
