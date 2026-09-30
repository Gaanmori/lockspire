# ADR 0039 — Perfiles: varias bóvedas en el mismo dispositivo

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario quería que su esposa usara Lockspire en el mismo equipo sin pisarle la bóveda. También hacía falta una bóveda de demostración para las capturas de la Store sin tocar la real.
- **Decisiones del usuario:**
  - si hay más de un perfil, se elige en una lista al abrir;
  - en escritorio los perfiles vienen activos; en Android vienen desactivados y se activan en Ajustes, porque es raro compartir el móvil;
  - cada perfil tiene todo lo suyo, incluidos el tema y el idioma.

## Decisión

### Qué es un perfil

- Un **perfil** es un nombre visible y un id. Cada perfil tiene su propia bóveda, con su propia contraseña maestra, y sus propios ajustes:
  - cuentas de nube y tokens;
  - la clave del desbloqueo biométrico;
  - el bloqueo automático;
  - el tema y el idioma;
  - los íconos de sitios;
  - los sitios de "nunca guardar".
- **El perfil principal** (id `principal`) es la instalación que ya existía. Conserva la ruta de su archivo y sus claves sin prefijo, así que actualizar no mueve nada.
- **Los demás perfiles** usan:
  - el archivo `<datos de la app>/profiles/<id>/vault.lockspire`;
  - claves del almacenamiento seguro con el prefijo `profile.<id>.`. Las da `ProfileScopedSecureStorage`, el único `FlutterSecureStorage` que reciben los adaptadores. En el perfil principal, `readAll` y `deleteAll` excluyen las claves de los demás perfiles y las del dispositivo.
- **La lista de perfiles** es del dispositivo: la clave `device.profiles` guarda los perfiles, el último usado y si están activados en Android.

### Cambiar de perfil

- **Cambiar de perfil reconstruye todo el `ProviderContainer`:**
  1. se bloquea la sesión;
  2. se descarta el contenedor, lo que borra la clave de memoria, cierra el canal IPC del navegador y cancela la sync;
  3. se crea uno nuevo con `activeProfileProvider` apuntando al perfil elegido, y se vuelve a arrancar como en `main()`.
- **Por qué:** seguridad por encima de rendimiento. Así ningún estado de un perfil puede quedar vivo en el otro, aunque un provider lea en vez de escuchar. Tarda lo mismo que abrir la app.

### Interfaz

- **Pantallas de desbloqueo y de crear bóveda:** con más de un perfil, muestran la lista de nombres y recuerdan el último usado. Con uno solo, no cambian.
- **Ajustes → Perfiles:**
  - agregar un perfil y cambiar el nombre del actual;
  - borrar el actual, si no es el principal;
  - en Android, el interruptor para activar los perfiles.
- **Agregar un perfil** no pide contraseña: solo crea uno vacío, que se abre en la pantalla de crear o restaurar bóveda.
- **Borrar un perfil** solo se puede con ese perfil desbloqueado, porque eso prueba que se conoce su contraseña. Borra su carpeta y sus claves después de salir de él. Nadie puede borrar la bóveda de otro.
- **El perfil principal no se borra.** Sus claves sin prefijo no se separan de forma segura de las del dispositivo.

### Fuera del perfil

- **El canal del navegador y el autocompletado de Android** atienden al perfil abierto.
- **El ícono del lanzador de Android** sigue al tema del perfil abierto.

## Consecuencias

- **Los nombres de los perfiles se ven antes de desbloquear.** Es el precio de la lista que eligió el usuario. No revelan nada de las bóvedas.
- **Separación:** la de dos cuentas de Windows sigue siendo más fuerte, porque el sistema aísla los archivos. Con perfiles, las bóvedas son archivos del mismo usuario del sistema, aunque cada una va cifrada con su propia contraseña.
- **Google Drive en Android:** el selector de cuentas es del sistema. Dos perfiles con cuentas de Google distintas funcionan, pero cada conexión pide elegir la cuenta.
- **Agregar una clave del almacenamiento seguro** no requiere nada nuevo: el prefijo lo pone el provider.
