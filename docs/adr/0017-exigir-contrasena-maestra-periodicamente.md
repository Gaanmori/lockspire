# 0017 — Exigir la contraseña maestra cada 7, 14 o 30 días aunque se use biometría

- Estado: Aceptado
- Fecha: 2026-09-25
- Complementa: [ADR 0010](0010-desbloqueo-biometrico.md) (desbloqueo biométrico).

## Contexto

Con el desbloqueo biométrico (ADR 0010), un usuario puede pasar semanas sin escribir la contraseña maestra. Hay dos problemas:

1. **Olvidarla.** La contraseña maestra no se puede recuperar (Zero-Knowledge): si se olvida, se pierde la bóveda, incluida la copia en la nube.
2. **La clave derivada queda cacheada** detrás de la biometría todo ese tiempo, con el gating a nivel de app que ADR 0010 documenta como limitación.

El usuario pidió exigir la contraseña cada cierto número de días. Propuso 15, 30 y 45, y se le recomendaron 7, 14 y 30.

## Decisión

Decisiones del usuario ante opciones explícitas:

- **Opciones: 7, 14 y 30 días; 14 por defecto.** Se elige en **Seguridad**, debajo del interruptor de biometría, y solo se muestra donde la biometría está disponible: sin ella, la contraseña se pide siempre.
- **Al vencer, se pide la contraseña una vez.** La pantalla de desbloqueo no dispara ni ofrece la biometría y explica por qué. Al escribir la contraseña correcta el plazo se reinicia y la biometría vuelve a funcionar sola. La clave cacheada **no** se borra: descartado por el usuario frente a "además desactivar la biometría", por la fricción que añade.

Diseño:

- **Regla pura en el dominio**, `isMasterPasswordRequiredAt(lastPasswordUnlock, now, interval)`:
  - sin registro → pedir (cubre también a quien ya tenía la biometría activa antes de esta regla);
  - registro en el futuro (reloj atrasado, a mano o por error) → pedir, porque atrasar el reloj nunca debe alargar el plazo;
  - `now - last >= interval` → pedir.
- **Dos puertos separados** (segregación de interfaces):
  - `MasterPasswordReminderSettingsPort` guarda el ajuste de días; cambia poco.
  - `PasswordUnlockHistoryPort` guarda la fecha del último desbloqueo con contraseña, que se escribe en cada desbloqueo.
  - Ambos usan `flutter_secure_storage`, **fuera de la bóveda**, porque hacen falta antes de desbloquear. Son **por dispositivo**: cada uno lleva su propia cuenta.
- **Caso de uso `CheckMasterPasswordRequiredUseCase`** (capa de aplicación): lee los dos puertos y el reloj y evalúa la regla **en cada llamada**. El provider de Riverpod entrega el caso de uso, nunca el resultado. *Corrección en la misma sesión:* la primera versión exponía el resultado como un provider *auto-dispose* leído con `ref.read(...future)`. Sin nadie escuchándolo, Riverpod lo descartaba a mitad de la lectura, la pantalla se tragaba el error y nunca se ofrecía Windows Hello aunque la fecha estuviera bien guardada (lo comprobó el usuario en Windows). Un valor cacheado, además, habría quedado obsoleto con la app abierta en la bandeja mientras vence el plazo. Hay un test de widget de la pantalla de desbloqueo como regresión.
- **Reloj inyectable** (`clockProvider`) para testear sin esperar días. La fecha se guarda en UTC, así que un cambio de zona horaria no mueve el plazo.
- **Se registra** al crear la bóveda, al desbloquear con contraseña y al restaurar una bóveda con contraseña (Fase 9). Nunca al desbloquear con biometría.
- **La regla se aplica en `VaultSessionController.unlockWithBiometrics()`**, no solo ocultando el botón: aunque la UI lo llamara, con el plazo vencido no desbloquea.

## Consecuencias

- La clave derivada puede seguir cacheada detrás de la biometría de forma indefinida, pero solo se puede **usar** durante el plazo desde el último desbloqueo con contraseña. Eso acota el adversario 4 de `docs/THREAT_MODEL.md` para el activo "clave derivada cacheada tras biometría".
- Quien pueda escribir en el almacenamiento seguro del usuario podría falsificar la fecha y alargar el plazo. Eso ya es el adversario 4 (malware con privilegios de usuario), que puede leer la clave cacheada directamente, así que no se añade un vector nuevo.
- Tras actualizar a esta versión, quien tuviera la biometría activa tendrá que escribir la contraseña una vez (no hay registro previo).

## Alternativas consideradas

- **15, 30 y 45 días** (propuesta inicial del usuario): 45 días sin escribir una contraseña irrecuperable es un riesgo real de olvidarla.
- **Borrar la clave cacheada al vencer**: más estricto, pero obliga a reactivar la biometría cada vez. Descartado por el usuario.
- **Contar desde el último desbloqueo de cualquier tipo**: no serviría, porque la biometría reiniciaría el plazo sin que nunca se escribiera la contraseña.
