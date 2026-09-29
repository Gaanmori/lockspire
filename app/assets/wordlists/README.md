# Lista de palabras del generador "fácil de recordar"

Una palabra por línea en `en.txt`. La carga `AssetWordListAdapter`
(`lib/features/vault/infrastructure/`) detrás de `WordListPort`. Antes eran
líneas de código Dart (revisión 2026-09-25, hallazgo C3).

**Siempre en inglés, sea cual sea el idioma de la app (ADR 0032).** Hubo una
lista en español (`dadoware-bonito-es`, GFDL 1.3) que se usaba si el sistema
estaba en español. Se quitó el 2026-09-29 a pedido del usuario: sus frases
salían con menos fuerza en el medidor, y una sola lista ASCII evita teclas
muertas y la ñ al teclear la contraseña en otro dispositivo.

Palabras usadas por `generateMemorablePassword` (ver
`password_generator.dart`): solo palabras de una pieza en minúscula, de a lo
sumo 7 letras. Son cortas a propósito: menos fricción al teclearlas a mano en
otro dispositivo, y entran varias palabras completas dentro del largo que
pida el usuario.

**No es un secreto ni tiene por qué serlo** (principio de Kerckhoffs, mismo
criterio que el resto del modelo criptográfico en `docs/THREAT_MODEL.md`): la
seguridad está en que `Random.secure()` elige impredeciblemente qué
palabras, no en que la lista sea desconocida.

**Procedencia y licencia — inglés (`englishWordList`, 4438
palabras):** EFF Large Wordlist de la Electronic Frontier
Foundation (eff.org/files/2016/07/18/eff_large_wordlist.txt,
ver eff.org/deeplinks/2016/07/new-wordlists-random-passphrases).
Licencia Creative Commons Attribution 4.0 International (CC BY
4.0, eff.org/copyright). Filtrada de las 7776 palabras originales
a 7772 sin guion interno, y de ahí a las 4438 de 7 letras o
menos.
