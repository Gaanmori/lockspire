# Ficha y envío en Microsoft Store

Lockspire en Partner Center:
- **Store ID:** `9NXFLQH9LMQN`
- **Enlace:** `https://apps.microsoft.com/detail/9NXFLQH9LMQN`
- **Identidad:** `gaanmori.Lockspire`, publicador `gaanmori`

## Paquete

1. Compilar con las donaciones de la Store y las credenciales OAuth:

   ```powershell
   cd app
   flutter build windows --release --dart-define-from-file=google_oauth_secrets.json --dart-define-from-file=microsoft_oauth_secrets.json --dart-define=LOCKSPIRE_STORE=msstore
   ```

2. Compilar el native host junto a la app (`native-host/README.md`):

   ```powershell
   cd native-host
   dart compile exe bin\lockspire_native_host.dart -o ..\app\build\windows\x64\runner\Release\lockspire-native-host.exe
   ```

3. Armar el paquete sin firmar, que la Store lo firma:

   ```powershell
   powershell -File tools\build_msix.ps1 -Store -Version 1.0.0.0
   ```

   Resultado: `app\build\msix\Lockspire_1.0.0.0_x64.msix`.

- **Cada envío necesita una versión mayor.** La Store exige que el último número sea 0: `1.0.1.0`, `1.1.0.0`…

## Complementos (donaciones, ADR 0035)

**Add-ons → Create a new add-on**, tres veces:

| Tipo | Product ID | Nombre visible (ES / EN) | Precio (nivel USD) |
|---|---|---|---|
| Developer-managed consumable | `donation_coffee` | Un café / A coffee | 2,99 |
| Developer-managed consumable | `donation_coffee_and_cake` | Café y pastel / Coffee and cake | 4,99 |
| Developer-managed consumable | `donation_lunch` | Un almuerzo / A lunch | 9,99 |

- El **Product ID** tiene que ser exactamente ese: la app busca los complementos por él.
- Los precios son una propuesta; los niveles se eligen de la lista de Partner Center.
- Cada complemento necesita su propio envío: precio y una ficha con título y descripción, en español (España) e inglés (Estados Unidos). El ícono es opcional; sirve `assets/play-icon-512.png`.
- **Descripción de los tres** (la misma para todos):
  - ES: `Una donación voluntaria para apoyar el desarrollo de Lockspire, un gestor de contraseñas libre. No desbloquea nada: todas las funciones son gratis.`
  - EN: `A voluntary donation to support the development of Lockspire, a free password manager. It unlocks nothing: every feature is free.`
- **Requisito previo:** sin el perfil de pago y el fiscal completos (Configuración de la cuenta → Pagos e impuestos, formulario W-8BEN), Partner Center no deja publicar complementos de pago.

## Envío de la app (Start submission)

- **Pricing and availability:** Gratis. Todos los mercados. Visibilidad pública.
- **Properties:**
  - categoría **Security** (subcategoría si la pide: *Password managers*);
  - política de privacidad: `https://gaanmori.github.io/lockspire/privacy-policy`;
  - sitio web: `https://github.com/Gaanmori/lockspire`;
  - no requiere hardware especial;
  - "¿Accede, recoge o transmite información personal?": **Sí**. Maneja contraseñas en el dispositivo y, si el usuario lo activa, sube la bóveda cifrada a su propia nube. Por eso pide la URL de la política de privacidad, que ya está publicada.
- **Age ratings:** cuestionario IARC. Todas las respuestas son "No". Resultado esperado: para todas las edades.
- **Packages:** subir el `.msix`.
- **Store listings:** español (España) e inglés (Estados Unidos).
  - La descripción, la descripción breve, las funciones, las palabras clave y el copyright están abajo, listos para pegar.
  - **Capturas de escritorio:** `assets/screenshots/windows/es-01` a `es-06` (1920 × 1080), en este orden:
    1. la bóveda;
    2. una entrada con el generador;
    3. Seguridad, con Windows Hello y el bloqueo automático;
    4. los temas;
    5. el desbloqueo con dos perfiles;
    6. una entrada en modo oscuro.
  - Se generan con la interfaz real y una bóveda de demostración (`app/tool/store_screenshots/`), sin tocar ninguna bóveda. Para rehacerlas después de cambiar la interfaz, desde `app/`: `flutter test --update-goldens tool/store_screenshots/windows_screenshots_test.dart`.

### Descripción

```
Lockspire guarda sus contraseñas, tarjetas, documentos y notas en una bóveda cifrada que vive en su equipo. No hay servidores de Lockspire, no hay cuentas que crear y nadie más que usted puede abrirla.

CIFRADO SERIO
• Su contraseña maestra nunca se guarda ni se envía a ningún lado.
• La bóveda se cifra con XChaCha20-Poly1305 y la clave se deriva con Argon2id, con parámetros exigentes, usando libsodium.
• Desbloqueo con Windows Hello.
• Bloqueo automático por inactividad, al bloquear la sesión o al suspender el equipo, y borrado del portapapeles tras copiar una contraseña.

EN SU NAVEGADOR
• Extensión para Chrome y Edge: rellena usuario y contraseña en los sitios web y le ofrece guardar las cuentas nuevas.
• La extensión habla solo con la app de su equipo; la bóveda nunca sale de ella.

SINCRONIZACIÓN EN SU PROPIA NUBE (OPCIONAL)
• Google Drive, Microsoft OneDrive o su propio servidor WebDAV.
• Solo se sube el archivo cifrado, directamente desde su equipo.
• Si edita en dos dispositivos a la vez, Lockspire combina los cambios campo por campo, sin preguntarle nada.

VARIAS PERSONAS, UN EQUIPO
• Perfiles: cada persona tiene su propia bóveda, con su propia contraseña maestra y sus propios ajustes.

ORGANIZADO Y CÓMODO
• Generador de contraseñas y de frases de contraseña.
• Historial de cada contraseña: recupere la anterior si la cambió por error.
• Importa desde SafeInCloud, Bitwarden, KeePassXC y archivos CSV (por ejemplo, de Chrome o Firefox). Exporta a Bitwarden y Chrome, o como copia cifrada.
• Temas claro y oscuro, colores de varios sistemas operativos o el color que usted elija.
• En español y en inglés.

TAMBIÉN EN SU TELÉFONO
Lockspire tiene versión para Android, con autocompletado en apps y sitios web, y para Linux.

LIBRE Y SIN ANUNCIOS
• Código abierto bajo licencia AGPLv3: cualquiera puede revisar cómo protege sus datos.
• Sin publicidad, sin analíticas y sin telemetría.
• Si Lockspire le resulta útil, puede invitarme un café desde "Acerca de". Es totalmente opcional y no desbloquea nada.

Código fuente: github.com/Gaanmori/lockspire
```

```
Lockspire keeps your passwords, cards, documents and notes in an encrypted vault that lives on your computer. There are no Lockspire servers, no accounts to create, and nobody but you can open it.

SERIOUS ENCRYPTION
• Your master password is never stored or sent anywhere.
• The vault is encrypted with XChaCha20-Poly1305 and the key is derived with Argon2id, with demanding parameters, using libsodium.
• Windows Hello unlock.
• Auto-lock after inactivity, when you lock your session or suspend the computer, and the clipboard is cleared after you copy a password.

IN YOUR BROWSER
• Chrome and Edge extension: fills usernames and passwords on websites and offers to save new accounts.
• The extension talks only to the app on your computer; the vault never leaves it.

SYNC WITH YOUR OWN CLOUD (OPTIONAL)
• Google Drive, Microsoft OneDrive or your own WebDAV server.
• Only the encrypted file is uploaded, straight from your computer.
• If you edit on two devices at once, Lockspire merges the changes field by field, without asking you anything.

SEVERAL PEOPLE, ONE COMPUTER
• Profiles: each person gets their own vault, with their own master password and their own settings.

ORGANIZED AND CONVENIENT
• Password and passphrase generator.
• History for every password: get the old one back if you changed it by mistake.
• Imports from SafeInCloud, Bitwarden, KeePassXC and CSV files (for example, from Chrome or Firefox). Exports to Bitwarden and Chrome, or as an encrypted backup.
• Light and dark themes, colors from several operating systems, or any color you choose.
• In English and Spanish.

ALSO ON YOUR PHONE
Lockspire has an Android version, with autofill in apps and websites, and a Linux version.

FREE AND AD-FREE
• Open source under the AGPLv3 license: anyone can check how it protects your data.
• No ads, no analytics, no telemetry.
• If you find Lockspire useful, you can buy me a coffee from "About". It is completely optional and unlocks nothing.

Source code: github.com/Gaanmori/lockspire
```

### Funciones del producto (una por línea, máx. 200 caracteres)

```
Bóveda cifrada en su equipo con XChaCha20-Poly1305 y Argon2id
Desbloqueo con Windows Hello
Extensión para Chrome y Edge que rellena y guarda contraseñas
Sincronización opcional con Google Drive, OneDrive o WebDAV
Perfiles: una bóveda para cada persona del equipo
Generador de contraseñas y de frases de contraseña
Importa desde SafeInCloud, Bitwarden, KeePassXC, Chrome y Firefox
Código abierto (AGPLv3), sin anuncios ni telemetría
```

```
Encrypted vault on your computer with XChaCha20-Poly1305 and Argon2id
Windows Hello unlock
Chrome and Edge extension that fills and saves passwords
Optional sync with Google Drive, OneDrive or WebDAV
Profiles: one vault for each person on the computer
Password and passphrase generator
Imports from SafeInCloud, Bitwarden, KeePassXC, Chrome and Firefox
Open source (AGPLv3), no ads or telemetry
```

### Palabras clave (hasta 7)

- ES: `contraseñas`, `gestor de contraseñas`, `bóveda`, `seguridad`, `autocompletar`, `cifrado`, `código abierto`
- EN: `passwords`, `password manager`, `vault`, `security`, `autofill`, `encryption`, `open source`

### Copyright y requisitos

- **Copyright:** `© 2026 Gabriel Ángel Montoya Rico`
- **Requisitos:** Windows 10 versión 2004 (19041) o posterior, 64 bits.

### Descripción breve para Windows

```
Gestor de contraseñas libre y cifrado, sin servidores. Con extensión para Chrome y Edge.
```

```
Free, encrypted password manager with no servers. With a Chrome and Edge extension.
```

### Justificación de capacidades restringidas

Partner Center la pide en **Submission options → Restricted capabilities**. Copiar tal cual:

```
runFullTrust: Lockspire is a Flutter desktop app (Win32). It also ships a small console helper, lockspire-native-host.exe, that Chrome and Edge launch through native messaging so the Lockspire browser extension can request credentials from the app.

unvirtualizedResources: the browser extension works only if Chrome and Edge can see what the app writes. The app writes its native-messaging host manifest to %LOCALAPPDATA%\Lockspire and registers it under HKCU\Software\Google\Chrome\NativeMessagingHosts (and the Edge/Chromium equivalents), and it writes a per-session IPC token to %LOCALAPPDATA%\Lockspire\ipc. With file and registry virtualization those writes stay in the package's private copy, the browsers cannot find the host, and the extension cannot connect. Nothing else is written outside the package's data; all vault data stays encrypted with the user's master password.
```

## Edge Add-ons (la extensión)

Se hace en la misma cuenta: Partner Center → **Microsoft Edge**, con inscripción gratuita.

- **Paquete:** `extension/lockspire-extension-1.0.0.zip` (`npm run package`).
- **Justificación de permisos:**
  - `nativeMessaging`: habla con la app de escritorio de Lockspire del mismo equipo.
  - `storage`: guarda por 3 minutos, en memoria de sesión, una contraseña que el usuario acaba de enviar, para ofrecerle guardarla.
  - `activeTab` y `scripting`: rellenar la página abierta cuando el usuario elige una cuenta.
  - Content script en `http/https`: detectar el envío de un formulario de inicio de sesión para ofrecer guardarlo.
- **Después de publicar:** añadir el ID que asigne Edge a `allowedExtensionIds` (`app/lib/features/browser_bridge/infrastructure/extension_ids.dart`) y publicar una versión de la app con ese cambio.
