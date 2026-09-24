# 0015 — Vincular un sitio web a una entrada existente desde la extensión

- Estado: Aceptado
- Fecha: 2026-09-24
- Amplía: [ADR 0013](0013-native-host-dart-e-ipc.md) (dos mensajes nuevos del protocolo v1).

## Contexto

En la primera prueba real con Chrome, el usuario tenía una entrada de Facebook **sin URL**. La extensión decía "No hay credenciales guardadas para este sitio" y no había forma de usar esa entrada sin ir a la app a editarla a mano. Pidió poder elegir una entrada existente desde la extensión y que después le pregunten si quiere vincular el sitio a esa entrada.

## Decisión

Decisiones tomadas por el usuario ante opciones explícitas:

- **Elegir:** el popup ofrece siempre "Elegir otra entrada de Lockspire…", que muestra la **lista completa** de entradas de contraseña (título y usuario, **nunca contraseñas**) con un **filtro** local por título o usuario, sin distinguir acentos. Mensaje nuevo: `LIST_CREDENTIALS` → `CREDENTIALS`. Requiere la bóveda desbloqueada.
- **Confirmar en la ventana de Lockspire, no en el popup.** Mensaje nuevo: `REQUEST_LINK_ORIGIN {origin, entry_id}`. La app **no modifica nada** al recibirlo: trae su ventana al frente, muestra un diálogo con el dominio en grande y un aviso de phishing, y responde `OK` de inmediato. La respuesta no espera a la decisión, porque el popup suele cerrarse al perder el foco. Es el mismo criterio que ADR 0005 fija para `SAVE_CREDENTIAL`: cualquier cambio en la bóveda pedido por la extensión se confirma en la interfaz de confianza de la app. Así, un clic rápido en el popup mientras se está en un sitio falso (`faceb00k.com`) no basta para darle una contraseña.
- **El vínculo reemplaza la URL de la entrada.** Se guarda el origen **sin un `www.` inicial** (`https://www.facebook.com` → `https://facebook.com`) para que coincida también con `m.` y otros subdominios. Nunca se sube más allá de quitar `www.`: subir hasta el dominio registrable exigiría la Public Suffix List, y hacerlo mal haría coincidir dominios ajenos (`co.uk`).
- **Sitio web y app Android son vínculos separados** (pedido explícito del usuario). Esto solo toca el campo `url`. La vinculación app↔entrada de Android que sigue pendiente (ver `docs/STATE.md`, ADR 0011) usará su propio campo; nunca se mezclará con la URL.

## Consecuencias

- La extensión puede ver los títulos y usuarios de todas las entradas cuando el usuario abre el selector. Aceptado por el usuario frente a la alternativa de "buscar por texto". Las contraseñas siguen viajando solo de a una y solo para una entrada que coincide con el origen (`GET_CREDENTIAL_SECRET`).
- Una segunda instancia de la app (`app-instance`) sigue sin poder pedir nada de esto (solo `PING`/`SHOW_APP`).
- Reemplazar la URL pierde la anterior. El diálogo la muestra antes de confirmar.
- El diálogo relee la entrada al confirmar. Si la bóveda se bloqueó o la entrada se borró mientras estaba abierto, no se guarda nada.

## Alternativas consideradas

- **Confirmar en el popup:** más rápido, pero la confirmación ocurriría en una superficie que se abre sobre la página que se quiere vincular. Descartado por el usuario.
- **Buscador sin lista completa** (la extensión solo recibe lo que coincide con lo tecleado): menos exposición, pero el usuario prefirió ver la lista y filtrarla.
- **Añadir el sitio a una lista de sitios extra** en vez de reemplazar la URL: descartado por el usuario por ahora. Si más adelante se necesitan varios dominios por cuenta (p. ej. `facebook.com` y `messenger.com`), requerirá un campo nuevo y su propio ADR.
