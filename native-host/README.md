# native-host/ — Native Messaging host

Puente entre `extension/` y `app/`: el navegador lanza este programa y le pasa mensajes por stdin/stdout (Native Messaging); el host los valida y los reenvía a la app por un canal IPC local. Diseño en [ADR 0005](../docs/adr/0005-protocolo-native-messaging.md) y [ADR 0013](../docs/adr/0013-native-host-dart-e-ipc.md).

- **Relay delgado, en Dart** (compilado AOT, sin runtime): no contiene lógica de bóveda ni criptografía, nunca ve la contraseña maestra.
- Valida cada petición contra el esquema estricto de `packages/lockspire_bridge`. Lo inválido se responde con `BAD_REQUEST` y no llega a la app.
- Antes de enviarle el token comprueba que la app al otro lado corre como el mismo usuario del SO (anti *pipe squatting*).
- Si la app no está abierta responde `APP_NOT_RUNNING`. No la lanza por su cuenta.

## Estructura

```
bin/lockspire_native_host.dart   # entrada: lee args de Chrome, arranca el relay
lib/native_host.dart             # bucle stdin → validación → app → stdout (testeable)
test/                            # tests del relay con una app falsa
```

El protocolo y el transporte (named pipe en Windows, socket Unix en Linux) viven en `../packages/lockspire_bridge/`, compartido con la app.

## Compilar e instalar (desarrollo)

```
dart pub get
dart test
dart compile exe bin/lockspire_native_host.dart -o build/lockspire-native-host.exe   # Windows
dart compile exe bin/lockspire_native_host.dart -o build/lockspire-native-host       # Linux
```

El binario tiene que quedar **junto al ejecutable de la app**, con ese nombre exacto:

- Windows: `app/build/windows/x64/runner/Debug/` (o `Release/`)
- Linux: `app/build/linux/x64/debug/bundle/` (o `release/bundle/`)

Después, en la app: **Navegador → "Conectar con Chrome/Edge"**. Eso escribe el manifest `com.lockspire.native_host.json` y lo registra en Chrome, Edge y Chromium (registro de Windows `HKCU\Software\...\NativeMessagingHosts`, o `~/.config/<navegador>/NativeMessagingHosts/` en Linux). Reinicia el navegador si estaba abierto.

Probar sin navegador: el host exige el origen de la extensión como argumento, igual que lo pasa Chrome:

```
lockspire-native-host chrome-extension://gmlibgaohpjlblfapahkkjcoohpdeofk/
```

(espera frames de Native Messaging por stdin; no es interactivo).
