# ADR 0033 — Donaciones: "Invíteme un café"

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario pidió en Acerca de un "invíteme un café" con tres montos para quien quiera donar.
  - Primero eligió Ko-fi fuera de Google Play y la facturación de Play dentro de su versión.
  - El mismo día decidió quitar Ko-fi y dejar solo Google Play: "si no funciona para quienes la bajen de GitHub, da igual".

## Decisión

- **Puerto:** `DonationPort` en `features/about/domain`, con `DonationTier { coffee, coffeeAndCake, lunch }`. Devuelve las opciones con su precio y el resultado del pago: `paid`, `pending`, `cancelled` o `failed`.
- **Pantalla:** `DonationCard` en Acerca de. Solo aparece si hay opciones.
- **Bóveda:** donar nunca toca la bóveda ni ningún dato de la persona.
- **Solo en la versión de Google Play:** se compila con `--dart-define=LOCKSPIRE_STORE=play`. Windows, Linux y el APK de GitHub no muestran la sección.
- **Adaptador:** `PlayBillingDonationAdapter`, con el paquete oficial `in_app_purchase` (BSD), sobre Play Billing. La política de pagos de Play no permite enlazar pagos externos para propinas al desarrollador.
- **Productos:** tres consumibles, `donation_coffee`, `donation_coffee_and_cake` y `donation_lunch`, que se crean en Play Console. El precio en moneda local lo pone Play; la sugerencia es US$3, US$5 y US$10. Un producto que no existe en Play no aparece. Se puede donar más de una vez.
- **Confirmar la compra:** Play reembolsa a los tres días un pago no confirmado. El adaptador se crea al arrancar la app (`startApp`) y confirma cualquier pago que llegue, también uno pendiente de otra sesión.

## Consecuencias

- **Permiso nuevo:** `in_app_purchase` agrega en todas las compilaciones de Android el permiso `com.android.vending.BILLING` y la biblioteca de Play Billing. Fuera de Play no se usa, pero es una dependencia de Google en el APK. Un build de F-Droid tendría que quitarla, igual que `google_sign_in`.
- **Privacidad:** la política suma una sección "Donaciones". Lockspire no ve ningún dato del pago.
- **Otras tiendas:** si más adelante se quiere donar fuera de Play (Ko-fi, GitHub Sponsors), va en un ADR nuevo. El puerto ya lo permite sin tocar la pantalla.
- **Verificación pendiente:** Play Billing solo se puede probar con la cuenta de Play Console creada y los productos dados de alta, desde la pista de pruebas.
