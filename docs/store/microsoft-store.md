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
- Cada complemento necesita su propio envío, con descripción y un ícono. Sirve `assets/play-icon-512.png`.

## Envío de la app (Start submission)

- **Pricing and availability:** Gratis. Todos los mercados. Visibilidad pública.
- **Properties:**
  - categoría **Security** (subcategoría si la pide: *Password managers*);
  - política de privacidad: `https://gaanmori.github.io/lockspire/privacy-policy`;
  - sitio web: `https://github.com/Gaanmori/lockspire`;
  - no requiere hardware especial. En "Product declarations", marcar que la app **no** recoge datos personales.
- **Age ratings:** cuestionario IARC. Todas las respuestas son "No". Resultado esperado: para todas las edades.
- **Packages:** subir el `.msix`.
- **Store listings:** español (España) e inglés (Estados Unidos).
  - La descripción es la de `google-play.md` con dos cambios: la sección "AUTOCOMPLETADO" pasa a hablar de la extensión de Chrome y Edge, y "TAMBIÉN EN SU ORDENADOR" pasa a "TAMBIÉN EN SU TELÉFONO" (Android).
  - **Capturas de escritorio:** `assets/screenshots/windows/es-01` a `es-06` (1920 × 1080), en este orden:
    1. la bóveda;
    2. una entrada con el generador;
    3. Seguridad, con Windows Hello y el bloqueo automático;
    4. los temas;
    5. el desbloqueo con dos perfiles;
    6. una entrada en modo oscuro.
  - Se generan con la interfaz real y una bóveda de demostración (`app/tool/store_screenshots/`), sin tocar ninguna bóveda. Para rehacerlas después de cambiar la interfaz, desde `app/`: `flutter test --update-goldens tool/store_screenshots/windows_screenshots_test.dart`.

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
