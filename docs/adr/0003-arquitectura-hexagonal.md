# 0003 — Arquitectura: Clean Architecture organizada como Hexagonal, por features

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

El proyecto tiene varios puntos que son literalmente "una interfaz, varias implementaciones intercambiables": proveedores de sync (Drive/OneDrive/Dropbox/WebDAV), la librería de cripto, el almacenamiento seguro (Keystore/Keychain), el canal de Native Messaging, y los mecanismos de autofill nativo por plataforma. Se buscaba una arquitectura que encajara con esto y que además dejara el contexto de cada sesión de trabajo con IA bien acotado.

## Decisión

Clean Architecture (Uncle Bob) organizada como Hexagonal / Puertos y Adaptadores (Cockburn) — no son alternativas que compitan, Clean Architecture es una variante de Hexagonal con capas nombradas explícitamente. Organización "feature-first, layer-second":

```
lib/features/<feature>/
  domain/          # Entidades y PUERTOS (interfaces)
  application/     # Casos de uso (1 responsabilidad cada uno)
  infrastructure/  # ADAPTADORES que implementan los puertos
  presentation/    # Riverpod providers, pantallas, widgets
```

El dominio nunca importa nada de `infrastructure/` ni `presentation/`. Los adaptadores nunca contienen lógica de negocio. Riverpod actúa como composition root (inyecta adaptadores reales en producción, fakes en tests).

SOLID se aplica como consecuencia natural de esta estructura, no como checklist aparte (ver detalle en el plan de desarrollo).

## Consecuencias

- Añadir un proveedor de nube nuevo = un adaptador nuevo en `sync/infrastructure/`, sin tocar dominio ni casos de uso.
- Tests unitarios de casos de uso no necesitan cripto real ni red real — usan puertos falsos; los adaptadores llevan tests de integración/contrato aparte.
- Una sesión de trabajo centrada en una feature concreta (ej. "añadir soporte Dropbox") solo toca su carpeta de `infrastructure/`, sin rozar el resto del código.
