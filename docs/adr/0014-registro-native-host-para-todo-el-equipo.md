# 0014 — Registro opcional del native host para todo el equipo (Windows)

- Estado: Aceptado
- Fecha: 2026-09-24
- Complementa: [ADR 0013](0013-native-host-dart-e-ipc.md) (el registro por usuario sigue siendo el camino por defecto).

## Contexto

En la primera prueba real, en un equipo corporativo del usuario (Windows, Azure AD), Chrome devolvía `Specified native messaging host not found` aunque:

- la clave `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.lockspire.native_host` apuntaba al manifest correcto;
- el manifest era JSON válido, sin BOM, con el `path` y el `allowed_origins` correctos;
- el host respondía bien lanzado igual que lo lanza Chrome;
- Chrome corría como el mismo usuario y no había políticas de native messaging en el registro.

La hipótesis inicial fue una política de Chrome aplicada desde la nube (`NativeMessagingUserLevelHosts = false`, que hace que Chrome ignore los hosts registrados en `HKCU`), y el usuario pidió añadir el registro a nivel de equipo.

**Corrección en la misma sesión: la hipótesis era errónea.** La causa real fue que la app se había lanzado desde la sesión del agente, que corre dentro del paquete MSIX de la app de Claude. Windows virtualiza las escrituras de un proceso empaquetado en `%LOCALAPPDATA%` y en `HKCU`, y las redirige a `...\Packages\<paquete>\LocalCache\`. Tanto el registro por usuario como el token IPC quedaron ahí, invisibles para Chrome y para el host. El registro elevado funcionó porque la ventana de UAC corre fuera del paquete. Con la app lanzada normalmente (desde el Explorador) no hace falta este ADR.

Aun así se mantiene la opción: la política `NativeMessagingUserLevelHosts` existe de verdad en entornos corporativos, y para ese caso este es el camino legítimo (la política admite los hosts registrados por un administrador).

## Decisión

La pantalla "Navegador" ofrece, **solo en Windows** y además del registro por usuario, "Registrar para todo el equipo". Se ejecuta **solo a petición del usuario** y pide elevación con UAC.

- El manifest va en `%ProgramData%\Lockspire\native-messaging\com.lockspire.native_host.json`. El directorio queda con una ACL explícita **sin herencia**: Administradores y SYSTEM con control total, Usuarios solo lectura y ejecución. (La ACL por defecto de `ProgramData` deja a los usuarios crear archivos en subcarpetas.)
- Se registra `HKLM\SOFTWARE\{Google\Chrome, Microsoft\Edge, Chromium}\NativeMessagingHosts\com.lockspire.native_host` en **las dos vistas del registro** (64 y 32 bits), que Chrome consulta según su arquitectura.
- **El script elevado se pasa en línea con `-EncodedCommand`, nunca como archivo temporal.** Un `.ps1` en `%TEMP%` podría modificarlo cualquier proceso del usuario entre que se escribe y Windows lo ejecuta como administrador: una escalada de privilegios.
- "Quitar registro" deshace ambas cosas, también con elevación.

## Consecuencias

- **El binario del host sigue donde esté la app.** En desarrollo eso es `app\build\...`, una carpeta que el usuario puede escribir, así que una clave de `HKLM` apunta a un ejecutable modificable por el usuario. Para el propio usuario no cambia nada respecto al registro por usuario: su malware ya podía reemplazar el host (adversario 4). Pero para un producto instalable, el host debe vivir en `Program Files`, y eso le toca a un instalador futuro. Se acepta en desarrollo.
- Linux no lo necesita por ahora: la política equivalente también existe (`/etc/opt/chrome/native-messaging-hosts`), pero no hay caso de uso todavía.
- Si la organización también define `NativeMessagingBlocklist` o `NativeMessagingAllowlist`, este registro no basta. Ahí el problema es de política de TI, no algo que la app deba sortear.

## Alternativas consideradas

- **Script `.ps1` temporal ejecutado elevado:** descartado por la carrera descrita arriba.
- **Registrar siempre en `HKLM`:** descartado. Exigiría permisos de administrador a todo el mundo sin necesidad.
