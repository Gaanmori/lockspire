# Threat Model — Lockspire

> Documento vivo, no un ADR: se actualiza a medida que se añaden features (autofill, passkeys, nuevos proveedores de sync). Los ADRs de `docs/adr/` referencian este documento para su justificación de seguridad en vez de repetirla; el propio Threat Model no fija decisiones de arquitectura, esas van en los ADRs correspondientes.

## Activos a proteger

- **Contraseña maestra.** Nunca sale del dispositivo, nunca se almacena en ninguna forma (ni cifrada).
- **Clave derivada** (salida de Argon2id) mientras la bóveda está desbloqueada en memoria.
- **Contenido de la bóveda** (credenciales, passkeys, notas) tanto en reposo (archivo cifrado en disco) como en memoria durante una sesión desbloqueada.
- **Tokens OAuth de los proveedores de nube** (Drive/OneDrive/Dropbox/WebDAV), guardados en el almacenamiento seguro del SO (Keystore/Keychain). No dan acceso al contenido de la bóveda (que sigue cifrado con la clave derivada de la contraseña maestra), pero sí permiten borrar o corromper el archivo remoto si se roban.
- **Clave derivada cacheada tras activar el desbloqueo biométrico** (huella en Android, Windows Hello en escritorio — ver [ADR 0010](adr/0010-desbloqueo-biometrico.md)), guardada en el almacenamiento seguro del SO detrás de biometría/PIN. Es opt-in explícito, nunca reemplaza la derivación Argon2id de la sesión inicial — quien la obtiene tiene el mismo acceso que quien obtiene la clave derivada en memoria durante una sesión desbloqueada.

## Actores / adversarios modelados

1. **Atacante con acceso al archivo de bóveda en la nube** (proveedor comprometido, cuenta de nube del usuario comprometida, o interceptación). Debe ser computacionalmente inviable extraer secretos sin la contraseña maestra. Mitigado por [ADR 0002](adr/0002-motor-criptografico.md) (Argon2id + XChaCha20-Poly1305, Zero-Knowledge).
2. **Acceso de solo-lectura al disco o a un backup del dispositivo** (dispositivo perdido/robado apagado, backup filtrado). Misma mitigación que (1) — el archivo en reposo debe resistir esto sin depender de que el dispositivo esté a salvo.
3. **Modificación/tamper del archivo de bóveda en tránsito o en la nube** (ataque de integridad o downgrade de parámetros). Mitigado por el AEAD + AAD anti-downgrade de [ADR 0002](adr/0002-motor-criptografico.md), reforzado por el versionado explícito y el rechazo (no degradación silenciosa) de formatos desconocidos en [ADR 0004](adr/0004-formato-boveda-v1.md).
4. **Malware o proceso local con privilegios de usuario mientras la bóveda está desbloqueada** (memory scraping, keylogging). Fuera de alcance mitigarlo por completo — si el sistema operativo del usuario está comprometido a ese nivel, ningún gestor de contraseñas sobrevive. Lo que sí es responsabilidad de Lockspire: minimizar el tiempo que la clave derivada permanece en memoria y aplicar auto-lock por inactividad, implementado en [ADR 0008](adr/0008-sesion-auto-lock.md). **Extensión de este actor para el desbloqueo biométrico ([ADR 0010](adr/0010-desbloqueo-biometrico.md)):** quien puede disparar o falsificar el prompt biométrico del SO, o leer directamente el almacenamiento seguro sin pasar por él, gana el mismo acceso que poseer la clave cacheada. En Android eso requiere comprometer el Android Keystore (hardware/TEE-backed) — mismo nivel que "compromiso del SO", ya excluido más abajo. **En Windows el gating es solo a nivel de app** (el adaptador exige el prompt de Windows Hello antes de leer, no el sistema operativo al liberar el secreto) — asimetría documentada y aceptada en el ADR, no resuelta acá porque Windows no expone un primitivo equivalente al Keystore accesible desde Flutter.
5. **Sitio web malicioso o extensión de terceros intentando hablar con el native host** para exfiltrar credenciales o forzar un desbloqueo. Mitigado por el manifest de Native Messaging (que restringe qué extensión, por ID, puede lanzar el host) y, sobre todo, porque el host **nunca** pide ni recibe la contraseña maestra — el desbloqueo ocurre solo dentro de la UI propia de la app. Ver [ADR 0005](adr/0005-protocolo-native-messaging.md).
6. **Proceso local no autorizado hablando directamente con el socket/pipe IPC de la app**, sin pasar por el navegador. Mitigado por permisos de sistema operativo sobre el socket/pipe (solo el mismo usuario del SO puede conectar) más un token de sesión como defensa en profundidad. Ver [ADR 0005](adr/0005-protocolo-native-messaging.md).
7. **Fuerza bruta offline contra un archivo de bóveda robado.** Mitigado por los parámetros agresivos de Argon2id fijados en [ADR 0002](adr/0002-motor-criptografico.md) (memoria ≥256 MiB, iteraciones ≥3-4).
8. **Archivo de exportación en texto plano de otro gestor de contraseñas, dejado en disco durante/después de una importación** (implementado en Fase 6: importar desde SafeInCloud, formato XML — ver `docs/STATE.md`). A diferencia del resto de los activos de esta lista, este riesgo no lo introduce Lockspire — lo trae el propio formato de exportación del gestor de origen (confirmado: la exportación XML de SafeInCloud **no está cifrada**, es texto plano completo). Mientras ese archivo exista en disco, es un actor (2) sin ninguna mitigación de Lockspire, porque el contenido nunca pasó por el cifrado de la bóveda. **Mitigado, con las tres medidas ya implementadas** (`lib/features/vault/presentation/screens/import_screen.dart`, `lib/features/vault/infrastructure/safeincloud_xml_import_source.dart`): (a) el flujo de importación lee el archivo elegido por el usuario (`PlatformFile.readAsBytes()`) y lo parsea en memoria, sin copiarlo ni dejar ningún archivo temporal propio en texto plano; (b) solo alcanzable con la bóveda ya desbloqueada — la pantalla de import cuelga de `vault_unlocked_screen.dart`; (c) al terminar una importación exitosa, un diálogo no descartable sin acción le indica al usuario que borre el archivo de exportación original — Lockspire no lo borra por su cuenta. XXE: verificado que `package:xml` no resuelve entidades externas por diseño (`decodeEntity` solo hace lookup en una tabla fija o referencias numéricas, sin I/O) — confirmado además con un test que usa un payload XXE real apuntando a un archivo local.

## Explícitamente fuera de alcance

- Compromiso total del sistema operativo (root/jailbreak malicioso, malware a nivel de kernel).
- Ataques físicos avanzados (cold boot attacks, side-channel de hardware).
- Auto-type en aplicaciones de escritorio Windows fuera del navegador — ya excluido explícitamente en `CLAUDE.md`.
- Disponibilidad de los servicios de los proveedores de nube del usuario (DoS contra Drive/OneDrive/etc. no es responsabilidad de Lockspire).
- Compromiso de la cadena de distribución (fork malicioso, build modificada) — la mitigación es de marca/distribución oficial (ver ADR 0001), no de este documento.

## Diagrama de confianza

```
[Extensión de navegador]
        │  Native Messaging (stdio, longitud-prefijada — restricción de la API del navegador)
        ▼
[native-host, relay delgado]
        │  IPC local autenticado (named pipe / unix socket + token de sesión)
        ▼
[App Flutter en background — bóveda desbloqueada en memoria]
        │  lectura/escritura atómica (temp + fsync + rename)
        ▼
[Archivo de bóveda cifrado en disco]
        │  SyncPort adapters — llamadas OAuth/API vía HTTPS directas
        ▼
[Google Drive / OneDrive / Dropbox / WebDAV]
```

Nota importante: Lockspire habla **directamente** con las APIs de los proveedores de nube (OAuth + llamadas HTTP) a través de los adaptadores `SyncPort` — no depende de que el usuario tenga un cliente de sincronización de escritorio de terceros vigilando una carpeta local.
