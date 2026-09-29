# Tests de la app

Cómo están organizados los tests y qué se espera de uno nuevo. Resumen de la
estrategia: muchos tests rápidos de dominio y aplicación, tests de pantallas
donde hay lógica de interfaz, y tests de flujo que recorren la app como un
usuario.

## Dónde va cada test

| Carpeta | Qué prueba | Con qué |
|---|---|---|
| `test/features/<feature>/<capa>/` | Una clase o función, en la misma ruta que en `lib/` (`domain`, `application`, `infrastructure`, `presentation`). | Dobles de los puertos. |
| `test/flows/` | Un recorrido de usuario de punta a punta sobre la app completa: crear la bóveda, agregar, sincronizar entre dos dispositivos, bloqueo automático… | `TestApp` (todo real salvo los bordes, en memoria) y `AppRobot`. |
| `test/integration/` | Adaptadores reales juntos, sin interfaz: libsodium y el archivo de bóveda en disco. | Lo real. |
| `integration_test/` | La app completa con libsodium real y el archivo en disco, en un dispositivo o en el escritorio. | `flutter test integration_test/<archivo> -d windows` (o `-d linux`, o el id del teléfono). |
| `test/support/` | Lo compartido: dobles (`fakes/`), constructores de datos (`builders.dart`), el arnés (`test_app.dart`) y el robot (`app_robot.dart`). | — |
| `test/*.dart` | Reglas de todo el proyecto: registro "usted" (`ui_register_test`), claves de traducción (`l10n_test`), raíz de composición, arranque. | — |

Un test nuevo va junto a lo que prueba. Si reproduce un bug, además de su
test unitario vale la pena un test de flujo: los bugs de 2026-09-29 (slider
del generador, aviso sobre "Bloquear", teclado en pantalla que no contaba
como actividad) solo se veían recorriendo la app.

## Cómo se escribe uno

- **Un comportamiento por test**, con un nombre que lo diga como regla:
  `'bloquear pide la contraseña maestra; una incorrecta se rechaza…'`, no
  `'test unlock 2'`. Los nombres van en español, como la app.
- **Preparar, actuar, comprobar** (Arrange-Act-Assert), separados por una
  línea en blanco. Si hace falta mucha preparación, va a un helper con nombre.
- **Solo lo que importa en los datos:** `anEntry(title: 'Banco', url: …)`.
  El resto lo completa el constructor con valores fijos (`testEpoch`): un
  test no depende del reloj ni del azar.
- **Dobles antes que mocks.** Los puertos tienen dobles en memoria en
  `support/fakes/` que se comportan como el real (el portapapeles registra
  lo copiado, la nube guarda el archivo). Un doble nuevo que sirva a más de
  un test va ahí, no copiado en cada archivo.
- **Sin esperas reales.** En `test/` el reloj es simulado: se avanza con
  `tester.pump(const Duration(minutes: 5))` o `fakeAsync`. Solo
  `integration_test/` espera de verdad (`robot.waitFor`). El robot usa
  `settle()` en vez de `pumpAndSettle()`: con una animación infinita,
  `pumpAndSettle` avanzaba minutos en silencio y disparaba el bloqueo
  automático en medio del test.
- **Nada de plugins en la presentación.** Cada plugin o canal nativo va
  detrás de un puerto con su adaptador en `infrastructure` (CLAUDE.md); así
  los tests usan un doble. `test/app_composition_adapters_test.dart`
  comprueba que sin dobles se conectan los adaptadores reales.
- **Cobertura mínima:** 90 % para dominio, aplicación y presentación
  (`dart run tool/check_coverage.dart`, también en la CI).
- **Textos de la interfaz en español**, tal como en `app_es.arb`: el
  arnés monta la app con el sistema en español. Si un texto cambia, se
  arregla en el robot o en el test que lo nombra.
- **Regresiones con fecha y origen** en un comentario sobre el test
  (`// Regresión (2026-09-29, encontrada por el usuario): …`), y
  comprobando que el test falla sin la corrección.

## Tests de flujo: `TestApp` y `AppRobot`

```dart
testWidgets('una contraseña agregada aparece en la lista', (tester) async {
  await TestApp().pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');

  await robot.addPassword(title: 'Banco', username: 'ana');

  expect(find.text('Banco'), findsOneWidget);
});
```

- **`TestApp`** arranca la app con `startApp()`, el mismo arranque que
  `main()`: raíz de composición, tema y servicios en segundo plano (bloqueo
  automático, sync, íconos). Todo es real, casos de uso y adaptadores de
  preferencias incluidos, salvo los bordes de plataforma, que son dobles en
  memoria:
  - la bóveda y el ancestro del merge, y la criptografía falsa y rápida;
  - el almacenamiento seguro, simulado y propio de cada instancia;
  - la nube (`cloud`, con modo `offline`);
  - el selector de archivos (`files`), los enlaces (`links`) y la versión;
  - la ventana, la bandeja y la sesión del sistema (`desktop: true`);
  - los ajustes de autocompletado, el ícono del lanzador y los íconos de
    apps (`android: true`);
  - la extensión del navegador (`nativeMessaging`), la actividad de
    autocompletado (`pumpAutofill`) y los íconos de sitios (`siteIcons`).

  Los dobles pueden fallar a pedido (`writeError`, `pickError`,
  `saveError`, `offline`…) para probar los mensajes de error. Para lo que
  llega de afuera (un pedido de la extensión), `app.container`.
- **Dos dispositivos:** dos `TestApp` con la misma `cloud`. "Usar" uno es
  montarlo con `pump`.
- **Reabrir la app:** montar otro `TestApp` con el mismo `storage`.
- **Pantalla:** por defecto un teléfono, a 2,625 px por punto (con densidad 1,
  1080 px serían "escritorio"). Para escritorio:
  `pump(tester, size: desktopSize, pixelRatio: 1)`.
- **`AppRobot`** reúne las acciones de usuario (`createVault`, `addPassword`,
  `lock`, `unlock`, `configureWebdav`, `syncNow`…). Una acción que usa más
  de un test va al robot.

## Correr

```bash
flutter test                      # todo lo de test/ (unos 400 tests, ~1 min)
flutter test test/flows           # solo los recorridos
flutter test --coverage           # con cobertura en coverage/lcov.info
flutter test integration_test/app_real_crypto_flow_test.dart -d windows
```
