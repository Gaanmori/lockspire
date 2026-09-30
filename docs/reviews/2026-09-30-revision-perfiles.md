# Revisión de los perfiles (ADR 0039)

- **Fecha:** 2026-09-30
- **Alcance:** la feature `profiles` y lo que tocó en el resto del proyecto: almacenamiento seguro, rutas, arranque, escritorio, sync y el canal del navegador.
- **Pedido del usuario:** revisar seguridad, SOLID y código limpio, y corregir con tests.

## Lo que se revisó y está bien

- **Biometría:** la clave del desbloqueo con huella o Windows Hello se guarda en el almacenamiento seguro del perfil. No hay una clave nativa compartida: activar la huella en un perfil no invalida la de otro.
- **Sync:** si dos perfiles conectan la misma cuenta de nube, el segundo recibe "La nube tiene una bóveda distinta a la suya", por el control de `vault_id`. Ninguno pisa la bóveda del otro.
- **Canal del navegador:** al cambiar de perfil se cierra el servidor IPC, y el nuevo genera otro token. Una conexión del perfil anterior no sirve para el nuevo.
- **Sesión:** cambiar de perfil bloquea la bóveda (descarta la clave y borra el portapapeles) antes de descartar el contenedor.

## Hallazgos corregidos

| # | Tipo | Hallazgo | Corrección y test |
|---|---|---|---|
| P1 | Seguridad y robustez | `TrayManagerAdapter` y `WindowManagerAdapter` se registran en los plugins globales y solo se soltaban al salir. Con perfiles, cada cambio dejaba los viejos escuchando: el menú de la bandeja se abría una vez por cada perfil abierto antes, y había una fuga de memoria. | `dispose()` en los dos adaptadores, conectado a `ref.onDispose`. Tests del adaptador y del provider. El del provider falla sin la corrección. |
| P2 | Seguridad | El id de un perfil va en rutas (`profiles/<id>/`) y en un borrado recursivo sin validar. Una lista manipulada con `../..` podía borrar otra carpeta. | `profile_ids.dart`: solo letras, dígitos y guiones. Los ids inválidos se rechazan al agregar, se descartan al leer la lista y fallan en `profileDirectory`, en `profileKeysPrefix` y al borrar. |
| P3 | Seguridad | Una clave futura que empezara por `device.` o `profile.` rompería el aislamiento del perfil principal. | `ProfileScopedSecureStorage` rechaza los prefijos reservados, con el error dentro del `Future`. |
| P4 | Robustez | Un fallo al guardar (no una validación) dejaba el diálogo de nombre bloqueado, y eliminar un perfil no avisaba si fallaba. | Se muestra cualquier error: en el diálogo o en un aviso abajo. |
| P5 | DIP | `ProfileHost` importaba el controlador de la bóveda para bloquear. | Recibe `onLeave` desde la raíz: `leaveProfile` en `app_composition.dart`. |
| P6 | DRY | El arranque de un perfil estaba duplicado en `main.dart` y en `TestApp`. | `bootProfile` en `app_composition.dart`, usado por los dos. |
| P7 | Cohesión | `principal` estaba en dos constantes. `activeProfileIdProvider` vivía en el archivo del almacenamiento seguro. `profiles` dependía de la presentación de `vault` para la carpeta de datos. | Una constante en `shared/domain/profile_ids.dart`, `shared/active_profile_provider.dart` y `shared/app_data_directory_provider.dart`. |
| P8 | Dominio | La regla "ningún perfil se llama como el principal" vivía en la interfaz. | La valida `ProfileRegistry.add` y `rename`, que reciben el nombre traducido (`mainDisplayName`). Test de dominio. |
| P9 | Limpieza | El texto `profilesMainTag` duplicaba `profilesMainName`. | Eliminado. El subtítulo dice "Principal" solo si el perfil tiene nombre propio. |

## Aceptado, sin cambios

- **Los nombres de los perfiles se ven antes de desbloquear.** Es lo que eligió el usuario (ADR 0039).
- **Agregar un perfil desde la pantalla de desbloqueo no pide contraseña.** El perfil nuevo está vacío y no da acceso a nada. A la vez pasa a ser el último usado, así que en el próximo arranque el dueño vería "Crear bóveda" y lo notaría.
- **Después de cambiar de perfil**, la extensión puede tardar hasta 5 s en reconectar. El servidor nuevo reintenta mientras el viejo termina de cerrarse.

## Resultado

- 686 tests, todos en verde.
- `flutter analyze` sin avisos.
- Cobertura por capa: dominio 95,3 %, aplicación 95,6 %, infraestructura 93,0 %, presentación 93,4 %.
