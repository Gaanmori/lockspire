# 0009 — Merge automático por campo (reemplaza el picker manual de ADR 0006)

- Estado: Aceptado
- Fecha: 2026-09-11
- Reemplaza parcialmente: [ADR 0006](0006-modelo-resolucion-conflictos.md), punto 3 de la Decisión ("conflicto real → se presenta al usuario ambas versiones... o se conservan las dos"). El resto de ADR 0006 (LWW por entrada, tombstones, merge de 3 vías con ancestro común) sigue vigente sin cambios — este ADR no lo edita, solo reemplaza ese punto puntual.

## Contexto

Fase 7 implementó el picker manual que describe ADR 0006: ante un conflicto real (misma entrada cambiada distinto en ambos lados), el usuario elegía qué versión conservar. Se verificó de punta a punta en dispositivo real (Windows + Redmi vía Google Drive), incluyendo un bug real corregido (`SyncStaleMergeException` dejaba al usuario en un loop si los datos cambiaban mientras resolvía).

El usuario decidió cambiar de rumbo: prefiere que nadie tenga que elegir nada, ni siquiera ante un conflicto real. Analizando el motor de merge existente, la mayoría de los "conflictos reales" detectados a nivel de entrada completa no lo son de verdad — si un dispositivo cambió la URL y el otro cambió la contraseña de la misma entrada, son campos distintos, no hay ninguna elección irreconciliable que hacer.

## Decisión

### Nivel 1 — merge por campo, no por entrada completa

Cuando ambos lados cambiaron la misma entrada desde el ancestro común (y no es un caso de tombstone, que sigue resolviéndose igual que en ADR 0006), en vez de tratar toda la entrada como un conflicto, se compara **cada campo por separado** contra su valor en el ancestro — `title` se trata como un campo más para este propósito, junto a las keys de `fields` (usuario, contraseña, URL, notas, etc.).

Por campo: si el valor final coincide en ambos lados, no hay nada que decidir. Si el valor de un lado coincide con el del ancestro (no lo tocó) y el otro difiere, gana el que cambió. Se combinan así todos los campos que solo cambiaron en un lado, en una sola entrada resultante, sin preguntar nada.

La ausencia de un campo (borrado o vaciado) se trata como un valor más, igual que cualquier edición — participa en la misma comparación de tres vías que un string cualquiera.

### Nivel 2 — el residual: mismo campo, valores distintos en los dos lados

Ahí sí hay una elección irreconciliable de verdad. Se resuelve automáticamente: gana el valor del lado cuya entrada tiene `modifiedAt` más reciente — comparación simétrica por timestamp real (no por si el dispositivo que corre el merge lo ve como "local" o "remoto"), así que el resultado es el mismo sin importar qué dispositivo lo calcule. Un empate exacto de timestamp se desempata comparando el string del valor, también determinista.

El valor perdedor se guarda como **historial acotado por campo** (`VaultEntry.fieldHistory`, tope de `maxFieldHistoryPerField` = 3 valores más recientes por campo, deduplicados por valor antes de aplicar el tope) dentro de la misma entrada — no como una entrada nueva, no aparece duplicada en la lista. Es visible solo si el usuario entra al formulario de esa entrada puntual, en una sección colapsable de solo lectura (sin botón de restaurar). El campo `password` se muestra siempre enmascarado ahí, igual criterio de seguridad que el resto del formulario.

## Trade-offs aceptados, explícitos a propósito

1. **La "recencia" es de la entrada completa, no del campo individual.** `modifiedAt` vive a nivel de `VaultEntry` — cada guardado reescribe la entrada entera con un solo timestamp, no hay tracking por campo. Caso real donde esto falla: el dispositivo A cambia la contraseña a las 10:00; el dispositivo B había cambiado la contraseña (a otro valor) a las 9:00, pero edita la URL de la misma entrada a las 11:00 en un guardado aparte — el `modifiedAt` final de B queda en 11:00, más nuevo que el de A, así que el algoritmo elige la contraseña de B como ganadora aunque la editó *antes*. Es una limitación real de la aproximación, no un bug — mismo espíritu que ADR 0006 ya documenta la dependencia del reloj del dispositivo para revivir tombstones. No se agrega un timestamp por campo: cambiaría el esquema de forma más profunda, fuera de alcance de esta pasada.
2. **`fieldHistory` no se combina de ambos lados fuera del camino de conflicto real.** El atajo "ambos lados ya coinciden" (`_sameContent`) sigue comparando solo `title`/`deleted`/`fields`, no `fieldHistory` — si dos entradas tienen contenido real idéntico pero historiales distintos (posible si un dispositivo participó de un merge de Nivel 2 que el otro nunca vio), se conserva arbitrariamente el historial de cualquiera de los dos lados. Se acepta porque el historial es un dato de diagnóstico/auditoría, no autoritativo — no hay ningún riesgo de pérdida de datos de credenciales reales, solo de un registro histórico ya superado. Por el mismo motivo, las ramas triviales (cambió un solo lado, tombstones) tampoco combinan `fieldHistory` de ambos lados — el lado ganador conserva el que ya traía tal cual. El merge por campo (Nivel 1/2) es el único camino donde `fieldHistory` se combina activamente.
3. **Sin schema version nueva.** `fieldHistory` es un campo opcional nuevo dentro del JSON del payload (ver [ADR 0004](0004-formato-boveda-v1.md)) — una entrada vieja sin el campo lo lee como vacío, retrocompatible, no requiere subir `schema_version` ni `format_min_reader_version`.

## Alternativas consideradas

- **Picker manual (lo que implementaba Fase 7):** descartado — es exactamente lo que este ADR reemplaza, por decisión explícita del usuario de no tener que elegir nada nunca.
- **CRDT completo:** sigue descartado por el mismo motivo que ya daba ADR 0006 — la complejidad de implementación y la superficie de bugs adicional en código que maneja datos sensibles no se justifican para este producto.
- **Mantener ambas entradas duplicadas ante un conflicto real:** alternativa que ADR 0006 mencionaba; nunca se implementó (Fase 7 ya la había descartado a favor del picker) y sigue descartada acá — generar una entrada duplicada por cada choque de campo sería peor UX que resolverlo solo con historial oculto.
