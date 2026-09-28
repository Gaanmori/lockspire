# Listas de palabras del generador "fácil de recordar"

Una palabra por línea: `es.txt` (español) y `en.txt` (inglés). Las carga
`AssetWordListAdapter` (`lib/features/vault/infrastructure/`) detrás de
`WordListPort`. Antes eran 7.550 líneas de código Dart (revisión 2026-09-25,
hallazgo C3).

Palabras usadas por [generateMemorablePassword] — ver
`password_generator.dart`. Ambas listas se filtraron a solo
palabras de una pieza en minúscula, de a lo sumo 7 letras —
cortas a propósito (dos motivos: menos fricción de teclado/IME
al teclear a mano en otro dispositivo, y que entren varias
palabras completas dentro del `targetLength` que pida el
usuario, para no depender solo del relleno con dígitos —ver
el generador— para llegar a la longitud pedida).

**La ñ sí está permitida en `spanishWordList` (ej. `año`,
`niño`, `sueño`) — es una tecla propia en cualquier teclado en
español, sin paso extra de tecleo, a diferencia de los acentos
(á/é/í/ó/ú) y la diéresis (ü), que sí piden una tecla muerta
incluso en teclado español y no existen en la mayoría de
teclados no hispanohablantes — esos siguen excluidos por el
mismo motivo de fricción de siempre. `englishWordList` no tiene
este problema (ASCII puro).

**No es un secreto ni tiene por qué serlo** (principio de
Kerckhoffs, mismo criterio que el resto del modelo criptográfico
de Lockspire documentado en `docs/THREAT_MODEL.md`): la
seguridad de una contraseña "fácil de recordar" está en que
`Random.secure()` elige impredeciblemente qué palabras, no en
que la lista sea desconocida — esconderla no sumaría seguridad
real.

**Procedencia y licencia — español (`spanishWordList`, 3050
palabras):** lista `dadoware-bonito-es` de mir123
(github.com/mir123/dadoware-bonito-es), basada en el corpus de
frecuencia de palabras del castellano de Chile de Sadowsky &
Martínez. Licencia GNU Free Documentation License 1.3 — texto
completo en `app/assets/wordlists/GFDL-1.3-es-wordlist.txt`
(mismo patrón que `app/assets/fonts/OFL.txt` para las fuentes:
atribución en el código + licencia completa incluida en el repo).
Filtrada de las 7776 palabras originales a 6408 sin acentos/ü/
nombres propios/frases (con ñ permitida), y de ahí a las 3050
de 7 letras o menos. **Se evaluó agrandarla más con un corpus
de frecuencia más grande (hermitdave/FrequencyWords, 50k
palabras) y se descartó** — sin curación por categoría
gramatical, esa fuente trae nombres propios y palabras
extranjeras mezclados (viene de subtítulos de películas/series
sin filtrar), y limpiarla en serio es un trabajo de curación
mucho mayor que filtrar por longitud — no se justificaba frente
a la ganancia (los bits por palabra escalan como log2(cantidad),
así que agrandar mucho el banco suma poco por palabra).

**Procedencia y licencia — inglés (`englishWordList`, 4438
palabras):** EFF Large Wordlist de la Electronic Frontier
Foundation (eff.org/files/2016/07/18/eff_large_wordlist.txt,
ver eff.org/deeplinks/2016/07/new-wordlists-random-passphrases).
Licencia Creative Commons Attribution 4.0 International (CC BY
4.0, eff.org/copyright). Filtrada de las 7776 palabras originales
a 7772 sin guion interno, y de ahí a las 4438 de 7 letras o
menos.
