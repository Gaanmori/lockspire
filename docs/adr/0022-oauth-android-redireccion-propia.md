# ADR 0022 — Login OAuth en Android: redirección por dirección propia

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Origen:** OneDrive no conectaba en el Redmi (HyperOS). Diagnosticado con logcat.

## Contexto

El login de OneDrive abre el navegador del sistema. Al terminar, Microsoft redirige a un servidor **loopback** (`http://localhost:PUERTO`) que Lockspire abre mientras espera (RFC 8252). En escritorio funciona. En Android con HyperOS, no: logcat muestra `frozen uid=… reason=tobg`. El sistema **congela** la app en cuanto pasa a segundo plano, así que mientras el usuario está en el navegador nadie atiende la redirección. Es el mismo comportamiento que obligó al reintento del portapapeles (S4).

Google Drive en Android no lo sufre porque usa el login nativo del sistema (Play Services). Sin embargo, el MVP en F-Droid obliga a quitar Play Services, y entonces Google Drive va a necesitar este mismo mecanismo.

## Decisión

- **En Android** el navegador vuelve a la app por una **dirección propia**: `com.lockspire.lockspire://oauth2redirect`. Se usa el esquema con el nombre del paquete, como recomienda RFC 8252 §7.1.
  - `OAuthRedirectActivity` (exportada, sin interfaz) recibe la URI, la entrega a Dart por el canal `com.lockspire.lockspire/oauth_redirect` y trae Lockspire al frente.
  - Lanzar una actividad **descongela** el proceso, así que el congelamiento deja de importar.
- **En escritorio** sigue el loopback, que no tiene ese problema.
- El resto del flujo no cambia: PKCE y `state` de 32 bytes comparado en tiempo constante (S9), con límite de 5 minutos. `waitForOAuthCode` aplica a la dirección propia la misma regla que al loopback (`evaluateOAuthCallback`).
- **Requisito externo:** la URI `com.lockspire.lockspire://oauth2redirect` tiene que estar registrada en la app de Azure, en la plataforma "Aplicaciones móviles y de escritorio".

## Consecuencias

- **Seguridad:** otra app instalada podría registrar el mismo esquema e interceptar la redirección. No le sirve de nada:
  - sin el `state` del login en curso, Lockspire la descarta;
  - un código interceptado no se puede canjear sin el verificador PKCE, que nunca sale del proceso.
  
  Es el modelo de amenaza previsto por RFC 8252 para clientes nativos.
- Si el sistema **mata** (no solo congela) el proceso mientras el usuario está en el navegador, el login en curso se pierde (el verificador vivía en memoria) y hay que reintentar.
- Sirve igual para Google Drive cuando se quite Play Services en el build de F-Droid.
