# ADR 0035 — Donaciones en Microsoft Store

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario preguntó qué alternativas había en Windows sabiendo que la app se publica en Microsoft Store. Eligió complementos de la Store en vez de un enlace externo.
- **Amplía:** ADR 0033, que deja las donaciones solo en Google Play.

## Contexto

La política 10.8.2 de Microsoft Store permite recibir donaciones voluntarias con la API de pagos de Microsoft o con una API de terceros segura. La 10.8.1 deja que las apps que no son juegos usen en PC la compra dentro de la app de la Store. Se eligió la Store por dos razones:
- da la misma experiencia que en Google Play: precio en moneda local y pago sin salir de la app;
- no hace falta avisar de un pago de terceros en Partner Center.

## Decisión

- **Complementos:** tres consumibles "manejados por el desarrollador" (`UnmanagedConsumable`) en Partner Center. Su **id del producto** es el mismo que en Play (`donation_coffee`, `donation_coffee_and_cake`, `donation_lunch`, en `donation_products.dart`). La app los busca por ese id (`InAppOfferToken`), así que el Store ID que asigna Microsoft no va en el código.
- **Código nativo** (ADR 0021): `windows/runner/store_donations.cpp`, en C++/WinRT sobre `Windows.Services.Store`, canal `com.lockspire.lockspire/store_donations`. No tiene lógica de negocio:
  - `offers`: los complementos con su precio;
  - `purchase(storeId)`: abre el diálogo de la Store sobre la ventana (`IInitializeWithWindow`), devuelve el estado y confirma lo comprado (`ReportConsumableFulfillmentAsync` con cantidad 1) para que se pueda volver a donar;
  - `fulfillPending`: al arrancar, confirma las compras que quedaron sin confirmar.
  - Sin identidad de paquete MSIX no hay complementos, así que la sección no aparece.
  - La Store responde desde otro hilo. Las respuestas vuelven al hilo de la interfaz con un mensaje registrado de la ventana (`RunOnUi`).
- **Adaptador:** `MicrosoftStoreDonationAdapter` implementa el mismo `DonationPort`, así que la pantalla no cambia.
- **Cómo se elige:** la versión de la Store se compila con `--dart-define=LOCKSPIRE_STORE=msstore`. Windows y Linux descargados de GitHub no muestran la sección.

## Consecuencias

- **Enlace nuevo:** el runner enlaza `windowsapp.lib`.
- **Comisión:** Microsoft cobra la suya sobre cada donación.
- **Verificación pendiente:** solo se puede probar con la app empaquetada como MSIX, instalada desde la Store (o como paquete de prueba asociado a la app en Partner Center) y con los complementos creados. El MSIX sigue pendiente (MVP, punto 5).
