# Ficha de Google Play

Textos y respuestas listos para copiar en Play Console. Imágenes en `docs/store/assets/`; se regeneran con `python tools/generate_store_assets.py`.

- **Idioma predeterminado:** español (España), `es-ES`. Traducción: inglés (Estados Unidos), `en-US`.
- **Categoría:** Herramientas. **Etiquetas:** gestor de contraseñas, seguridad.
- **Correo de contacto:** el de la cuenta de desarrollador (obligatorio, es público). **Sitio web:** `https://github.com/Gaanmori/lockspire`.
- **Política de privacidad:** `https://gaanmori.github.io/lockspire/privacy-policy`.

## Ficha principal

### Nombre de la app (máx. 30)

```
Lockspire: contraseñas seguras
```

```
Lockspire: Password Manager
```

### Descripción breve (máx. 80)

```
Contraseñas cifradas en su dispositivo, sin servidores ni anuncios. Libre.
```

```
Encrypted passwords on your device. No servers, no ads. Open source.
```

### Descripción completa (máx. 4000)

```
Lockspire guarda sus contraseñas, tarjetas, documentos y notas en una bóveda cifrada que vive en su dispositivo. No hay servidores de Lockspire, no hay cuentas que crear y nadie más que usted puede abrirla.

CIFRADO SERIO
• Su contraseña maestra nunca se guarda ni se envía a ningún lado.
• La bóveda se cifra con XChaCha20-Poly1305 y la clave se deriva con Argon2id, con parámetros exigentes, usando libsodium.
• Desbloqueo con huella protegido por el hardware seguro del teléfono.
• Bloqueo automático y borrado del portapapeles tras copiar una contraseña.

AUTOCOMPLETADO
• Rellena usuario y contraseña en apps y sitios web con el autocompletado de Android y Credential Manager.
• Sugerencias en la barra del teclado, en los teclados compatibles.

SINCRONIZACIÓN EN SU PROPIA NUBE (OPCIONAL)
• Google Drive, Microsoft OneDrive o su propio servidor WebDAV.
• Solo se sube el archivo cifrado, directamente desde su dispositivo.
• Si edita en dos dispositivos a la vez, Lockspire combina los cambios campo por campo, sin preguntarle nada.

ORGANIZADO Y CÓMODO
• Generador de contraseñas y de frases de contraseña.
• Historial de cada contraseña: recupere la anterior si la cambió por error.
• Importa desde SafeInCloud, Bitwarden, KeePassXC y archivos CSV (por ejemplo, de Chrome o Firefox). Exporta a Bitwarden y Chrome, o como copia cifrada.
• Temas claro y oscuro, colores de varios sistemas operativos o el color que usted elija.
• En español y en inglés.

TAMBIÉN EN SU ORDENADOR
Lockspire tiene versión para Windows y Linux, con extensión para Chrome y Edge que rellena y guarda contraseñas en el navegador.

LIBRE Y SIN ANUNCIOS
• Código abierto bajo licencia AGPLv3: cualquiera puede revisar cómo protege sus datos.
• Sin publicidad, sin analíticas y sin telemetría.
• Si Lockspire le resulta útil, puede invitarme un café desde "Acerca de". Es totalmente opcional y no desbloquea nada.

Código fuente: github.com/Gaanmori/lockspire
```

```
Lockspire keeps your passwords, cards, documents and notes in an encrypted vault that lives on your device. There are no Lockspire servers, no accounts to create, and nobody but you can open it.

SERIOUS ENCRYPTION
• Your master password is never stored or sent anywhere.
• The vault is encrypted with XChaCha20-Poly1305 and the key is derived with Argon2id, with demanding parameters, using libsodium.
• Fingerprint unlock protected by your phone's secure hardware.
• Auto-lock, and the clipboard is cleared after you copy a password.

AUTOFILL
• Fills usernames and passwords in apps and websites through Android Autofill and Credential Manager.
• Suggestions in the keyboard bar, on supported keyboards.

SYNC WITH YOUR OWN CLOUD (OPTIONAL)
• Google Drive, Microsoft OneDrive or your own WebDAV server.
• Only the encrypted file is uploaded, straight from your device.
• If you edit on two devices at once, Lockspire merges the changes field by field, without asking you anything.

ORGANIZED AND CONVENIENT
• Password and passphrase generator.
• History for every password: get the old one back if you changed it by mistake.
• Imports from SafeInCloud, Bitwarden, KeePassXC and CSV files (for example, from Chrome or Firefox). Exports to Bitwarden and Chrome, or as an encrypted backup.
• Light and dark themes, colors from several operating systems, or any color you choose.
• In English and Spanish.

ALSO ON YOUR COMPUTER
Lockspire has Windows and Linux versions, with a Chrome and Edge extension that fills and saves passwords in the browser.

FREE AND AD-FREE
• Open source under the AGPLv3 license: anyone can check how it protects your data.
• No ads, no analytics, no telemetry.
• If you find Lockspire useful, you can buy me a coffee from "About". It is completely optional and unlocks nothing.

Source code: github.com/Gaanmori/lockspire
```

### Imágenes

- **Ícono (512 × 512):** `assets/play-icon-512.png`.
- **Imagen destacada (1024 × 500):** `assets/feature-graphic-1024x500-es.png` y `-en.png`.
- **Capturas del teléfono:** `assets/screenshots/es-01` a `es-06` (1080 × 2400), en este orden:
  1. la lista de la bóveda;
  2. una entrada con el generador;
  3. una tarjeta;
  4. la sincronización;
  5. los temas;
  6. la lista en modo oscuro.
- Se hicieron con una bóveda de demostración en un emulador, nunca con la real. Sirven también para la ficha en inglés.
- No usar en las capturas los temas con nombres de marcas (Pixel, Ubuntu, Windows): Google puede objetarlo.

## Contenido de la app (Política de la app)

| Formulario | Respuesta |
|---|---|
| **Política de privacidad** | La dirección de arriba. |
| **Anuncios** | No, la app no contiene anuncios. |
| **Acceso a la app** | Toda la funcionalidad está disponible sin restricciones. No hay cuenta: el revisor crea su propia bóveda. |
| **Clasificación de contenido** | Categoría "Utilidad, productividad, comunicación u otro". Todas las preguntas: No. Tampoco hay contenido generado por usuarios que se comparta, ni ubicación, ni compras de artículos digitales aparte de las donaciones. Resultado esperado: PEGI 3 / Para todos. |
| **Público objetivo** | 18 años o más. Así la app no entra en el programa de familias, que tiene requisitos propios. |
| **App de noticias** | No. |
| **Apps gubernamentales** | No. |
| **Funciones financieras** | Ninguna. Guardar datos de tarjetas en una bóveda no es un servicio financiero. |
| **Salud** | No. |

## Seguridad de los datos

- Google define "recoger" como enviar datos fuera del dispositivo, al desarrollador o a terceros. Los datos que solo se procesan en el dispositivo no cuentan.
- Tampoco cuenta lo que el usuario envía a un servicio que él mismo elige y configura, como su Google Drive o su WebDAV.

| Pregunta | Respuesta |
|---|---|
| ¿La app recoge o comparte alguno de los tipos de datos obligatorios? | **No.** |
| ¿Los datos se cifran en tránsito? | Sí: la sincronización solo usa HTTPS. Solo se responde si se declara algún dato; con "No" arriba, no aparece. |
| ¿Se pueden solicitar borrados? | No aplica: no hay cuentas ni datos en servidores nuestros. |

**Por qué "No", punto por punto:**
- **La bóveda:** se guarda en el dispositivo. Si se sincroniza, va cifrada a la nube del usuario, y nosotros no la recibimos.
- **El autocompletado:** lee la pantalla solo en el dispositivo.
- **Los íconos de los sitios:** son opcionales, vienen desactivados y los pide el usuario. El respaldo con DuckDuckGo recibe solo el dominio, cuando el usuario lo activa.
- **Las donaciones:** las procesa Google Play Billing, y la app no recibe datos del pago.

## Permisos y declaraciones

- **Permisos:** `INTERNET` (sincronización e íconos) y los que añaden las bibliotecas: biometría y facturación de Play.
  - No usa permisos sensibles: ni SMS, ni llamadas, ni ubicación, ni `QUERY_ALL_PACKAGES`, ni accesibilidad.
  - Por eso Play no debería pedir declaraciones de permisos.
- **Servicio de autocompletado y proveedor de credenciales:** no necesitan declaración, porque se protegen con `BIND_AUTOFILL_SERVICE` y `BIND_CREDENTIAL_PROVIDER_SERVICE`.

## Prueba cerrada

- **Requisito para cuentas personales nuevas:** 12 probadores que mantengan la app instalada durante 14 días seguidos antes de poder pedir la producción.
- **Cómo:**
  - crear una lista de correos (cuentas de Google) en Play Console → Pruebas → Prueba cerrada;
  - subir el AAB;
  - compartir el enlace de participación.
- **Lo que pregunta Google después**, para anotarlo mientras dure la prueba:
  - cómo se reclutó a los probadores;
  - qué comentarios dieron;
  - qué se cambió.
