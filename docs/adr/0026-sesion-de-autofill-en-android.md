# ADR 0026 — Sesión de autofill en Android: cuentas directas en el desplegable y el teclado

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Amplía:** ADR 0011 (autofill en Android), ADR 0020 (origen web en autofill)
- **Relaja, con decisión explícita del usuario:** ADR 0011 decía que el servicio nativo "nunca lee ni desencripta la bóveda". Eso sigue siendo cierto (no descifra nada), pero ahora **recibe en memoria**, por un tiempo corto, credenciales que Dart ya descifró.
- **Origen:** en la prueba de Crunchyroll el usuario esperaba, tras rellenar una vez, poder elegir la cuenta directamente en el desplegable o en el teclado. En cambio, cada petición abría Lockspire y pedía la huella, porque en Android la bóveda se bloquea al salir de la app (ADR 0008). El usuario eligió esta opción entre tres (dejarlo como estaba, abrir la lista sin huella, o esta), con la duración del auto-bloqueo.

## Decisión

1. **Inicio de la sesión.** Al desbloquear **para rellenar** (la pantalla de `AutofillActivity`), Dart le pasa al servicio nativo un índice en memoria. Desbloquear la app normal no inicia nada.
   - Contenido: solo las contraseñas no borradas que tienen contraseña y al menos un sitio web o una app Android.
   - Datos por entrada: título, usuario, contraseña, sitios reducidos a `host` + "exige https", y paquetes.
   - Los sitios con puerto explícito se omiten, porque el autofill nativo no conoce el puerto.
2. **Duración.** La del auto-bloqueo configurado. La lista se borra antes si la pantalla se apaga. Solo vive en memoria del proceso: nunca se escribe a disco y muere con el proceso.
3. **Coincidencia en el servicio.** Es deliberadamente mínima; el cálculo de qué sitios tiene cada entrada lo hace Dart (ADR 0021: nativo delgado).
   - **Página web** (el navegador o el WebView informa un dominio): el host de la página es igual al guardado o es subdominio suyo. Una entrada `https` nunca coincide con una página `http`. Son las reglas de ADR 0013/0020; el paquete de la app no cuenta.
   - **App nativa** (sin dominio): el paquete es exactamente uno de los guardados. El sistema garantiza el paquete de la app que pide.
4. **Qué se ve.** Hasta 5 cuentas que coinciden, con título y usuario, en el desplegable y como sugerencia del teclado (Android 11+). Al final sigue la opción "Rellenar con Lockspire", que abre la lista completa con desbloqueo. Si no hay coincidencias, solo aparece esa opción, como antes.

## Consecuencias

- Rellenar una cuenta que coincide pasa de 3 toques (Lockspire → huella → cuenta) a 1, durante el tiempo del auto-bloqueo.
- **Riesgo aceptado por el usuario:** durante esa ventana, quien tenga el teléfono desbloqueado puede rellenar esas cuentas (solo en el sitio o la app que coincide) sin huella. Es el mismo comportamiento que Bitwarden con la bóveda desbloqueada.
- Las credenciales coincidentes viven en memoria del proceso de Lockspire unos minutos, como ya pasa con la bóveda descifrada mientras la app está abierta.
- Cambiar una contraseña durante la ventana no actualiza el índice hasta el próximo desbloqueo para rellenar. Es aceptable por la duración corta.
