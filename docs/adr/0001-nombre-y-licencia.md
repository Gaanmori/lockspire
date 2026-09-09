# 0001 — Nombre del proyecto y licencia de código

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

El proyecto necesitaba un nombre definitivo (el provisional era "OpenVault") y una decisión sobre licencia de código / modelo de negocio: el usuario quiere vender la app a precio fijo en Play Store y App Store, sin suscripciones, y valoraba mantener el código abierto por la confianza que da en la categoría de gestores de contraseñas (poder auditar que no hay puertas traseras).

## Decisión

- **Nombre: Lockspire.**
- **Licencia del código: AGPLv3.** Copyleft fuerte: cualquier derivado, incluido software ejecutado como servicio, debe publicarse también bajo AGPL. Impide que un tercero tome el código, lo cierre y lo venda como propio compitiendo directamente. Es la misma licencia que usa Bitwarden.
- **Marca protegida aparte del código:** el nombre "Lockspire" y su logo se registran como marca de forma independiente a la licencia AGPL. Un fork del código no puede usar el nombre ni el logo ni presentarse como "Lockspire oficial" en las tiendas — la protección de ingresos viene de la marca, no de restringir el código.
- **Modelo de negocio:** venta a precio fijo de la build oficial en Play Store / App Store. Se cobra por la build mantenida y de confianza, no por acceso al código.

## Alternativas consideradas

- MIT/Apache-2.0: máxima adopción, pero sin protección frente a que un tercero cierre el código y compita directamente.
- Source-available con licencia restrictiva a medida (estilo Business Source License): máxima protección de ingresos, pero licencia no estándar y menor credibilidad como "de verdad open source" frente a la comunidad de seguridad.

## Pendiente

Verificar disponibilidad del nombre en las consolas de Play Store / App Store, búsqueda formal de marca registrada (EUIPO), compra de dominio y reserva de usuario/organización en GitHub y redes — todo antes de hacer público el repo.
