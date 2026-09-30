---
title: Lockspire — Política de privacidad / Privacy Policy
---

# Política de privacidad de Lockspire

_Última actualización: 30 de septiembre de 2026_

Lockspire es un gestor de contraseñas de código abierto (AGPLv3) que funciona en su dispositivo. **No tenemos servidores y no recogemos ningún dato suyo.**

## Qué guarda Lockspire y dónde

- **Su bóveda.** Guarda sus contraseñas, tarjetas, documentos y notas en un archivo en su dispositivo. El archivo está **cifrado con su contraseña maestra** (Argon2id y XChaCha20-Poly1305). Nadie puede leerlo sin esa contraseña, tampoco los desarrolladores de Lockspire.
- **Su contraseña maestra.** Nunca se guarda ni se envía a ningún lado. Si activa el desbloqueo con huella o Windows Hello, se guarda en su dispositivo una clave derivada de ella. En Android la protege el hardware seguro (Android Keystore) y solo se libera con su huella. En Windows queda cifrada y atada a su sesión de Windows (DPAPI), y Lockspire exige Windows Hello antes de usarla.
- **Preferencias.** El tema, el tiempo de bloqueo y otros ajustes se guardan en su dispositivo.

## Sincronización

Si usted la activa, Lockspire copia **el archivo cifrado** de la bóveda a la nube que usted elija:

- **Google Drive:** en la carpeta privada de la aplicación (`appDataFolder`), que solo Lockspire puede ver.
- **Microsoft OneDrive:** en la carpeta de aplicaciones de Lockspire.
- **WebDAV:** en el servidor que usted indique.

La conexión va **directamente de su dispositivo a ese servicio**, sin pasar por ningún servidor nuestro. Lo que se sube siempre está cifrado. Los permisos de acceso que le da cada servicio (tokens) se guardan en el almacenamiento seguro de su sistema operativo.

El uso que hace Lockspire de la información recibida de las API de Google cumple la [Política de datos de usuario de los servicios de API de Google](https://developers.google.com/terms/api-services-user-data-policy), incluidos los requisitos de uso limitado. Lockspire solo usa Google Drive para guardar y leer el archivo cifrado de su bóveda. No lee sus otros archivos ni comparte ningún dato con terceros.

## Autocompletado y extensión del navegador

- **En Android,** el servicio de autocompletado lee la estructura de la pantalla (qué campo es usuario y cuál contraseña, y qué app o sitio los pide) solo para ofrecerle sus cuentas. Esa información no sale de su dispositivo.
- **La extensión para Chrome y Edge** habla únicamente con la app de Lockspire instalada en su propio equipo (native messaging). No envía nada a internet.
- **Guardar contraseñas desde el navegador.** Cuando usted envía un formulario con una contraseña, la extensión lee el usuario y la contraseña de ese formulario para ofrecerle guardarlos. Solo se los pasa a la app de su equipo. Si no responde en 3 minutos, los olvida. No guarda nada en disco ni lee nada de las páginas en otro momento. La lista de sitios donde eligió "Nunca en este sitio" queda cifrada en su equipo.

## Íconos de los sitios (opcional)

Viene desactivado. Si usted lo activa, Lockspire descarga el ícono de cada sitio guardado **directamente de ese sitio**: el sitio ve una visita normal desde su conexión, sin cookies ni ningún dato de su bóveda. Si además activa "Completar los que falten con DuckDuckGo", para los sitios sin ícono se lo pide a DuckDuckGo, que recibe **solo el dominio** (por ejemplo `ejemplo.com`), nunca sus usuarios ni contraseñas. Los íconos se guardan cifrados dentro de la bóveda.

## Lo que Lockspire no hace

- No tiene publicidad.
- No usa analíticas, telemetría ni reportes de errores automáticos.
- No crea cuentas de usuario ni pide su correo.
- No vende ni comparte datos, porque no los tiene.

## Exportaciones

Si usted exporta su bóveda en un formato **sin cifrar** (CSV o JSON), el archivo queda donde usted lo guarde. Lockspire se lo advierte antes y le recuerda borrarlo.

## Donaciones

"Invíteme un café", en Acerca de, es opcional y solo existe en las versiones de Google Play y de Microsoft Store. El pago lo procesa la tienda: Lockspire solo recibe si el pago se completó, no ve ningún dato del pago y no guarda nada. Se aplica la política de privacidad de Google Play o de Microsoft.

## Cambios y contacto

Si esta política cambia, la nueva versión se publica en esta misma dirección, con la fecha arriba. Para preguntas, abra un _issue_ en [github.com/Gaanmori/lockspire](https://github.com/Gaanmori/lockspire/issues).

---

# Lockspire Privacy Policy

_Last updated: September 30, 2026_

Lockspire is an open-source (AGPLv3) password manager that runs on your device. **We have no servers and we collect no data about you.**

## What Lockspire stores and where

- **Your vault.** Your passwords, cards, documents and notes are stored in a file on your device. The file is **encrypted with your master password** (Argon2id and XChaCha20-Poly1305). Nobody can read it without that password, including Lockspire's developers.
- **Your master password.** It is never stored or sent anywhere. If you enable fingerprint or Windows Hello unlock, a key derived from it is stored on your device. On Android it is protected by secure hardware (Android Keystore) and released only with your fingerprint. On Windows it is encrypted and bound to your Windows session (DPAPI), and Lockspire requires Windows Hello before using it.
- **Preferences.** Theme, lock timeout and other settings are stored on your device.

## Sync

If you turn it on, Lockspire copies **the encrypted vault file** to the cloud you choose:

- **Google Drive:** into the app's private folder (`appDataFolder`), visible only to Lockspire.
- **Microsoft OneDrive:** into Lockspire's app folder.
- **WebDAV:** to the server you configure.

The connection goes **directly from your device to that service**, never through a server of ours. What is uploaded is always encrypted. The access permissions (tokens) each service grants are kept in your operating system's secure storage.

Lockspire's use of information received from Google APIs will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements. Lockspire uses Google Drive only to store and read your encrypted vault file. It does not read your other files or share any data with third parties.

## Autofill and browser extension

- **On Android,** the autofill service reads the screen structure (which field is the username or password, and which app or site asks for it) only to offer your accounts. That information never leaves your device.
- **The Chrome and Edge extension** talks only to the Lockspire app installed on your own computer (native messaging). It sends nothing to the internet.
- **Saving passwords from the browser.** When you submit a form with a password, the extension reads that form's username and password to offer saving them. It passes them only to the app on your computer. If you don't answer within 3 minutes, it forgets them. It stores nothing on disk and reads nothing from pages at any other time. The list of sites where you chose "Never on this site" is kept encrypted on your computer.

## Site icons (optional)

Off by default. If you turn it on, Lockspire downloads each saved site's icon **directly from that site**: the site sees a normal visit from your connection, with no cookies and no data from your vault. If you also turn on "Fill in the missing ones with DuckDuckGo", icons for sites without one are requested from DuckDuckGo, which receives **only the domain** (e.g. `example.com`), never your usernames or passwords. Icons are stored encrypted inside the vault.

## What Lockspire does not do

- No advertising.
- No analytics, telemetry or automatic crash reports.
- No user accounts, and it never asks for your email.
- It does not sell or share data, because it has none.

## Exports

If you export your vault in an **unencrypted** format (CSV or JSON), the file stays wherever you save it. Lockspire warns you beforehand and reminds you to delete it.

## Donations

"Buy me a coffee", in About, is optional and only exists in the Google Play and Microsoft Store versions. The store processes the payment: Lockspire only receives whether the payment went through, sees no payment data and stores nothing. Google Play's or Microsoft's privacy policy applies.

## Changes and contact

If this policy changes, the new version is published at this same address with the date above. For questions, open an issue at [github.com/Gaanmori/lockspire](https://github.com/Gaanmori/lockspire/issues).
