# Agenda Podológica

Plataforma clínica de nueva generación para profesionales de la podología.

## Estado

En desarrollo. Fase fundacional.

## Documentación

La documentación del proyecto vive en `docs/`:

| Carpeta | Contenido |
|---|---|
| `docs/00_foundation/` | Visión del producto, auditoría de la Beta, project charter |
| `docs/01_domain/` | Modelo de dominio, entidades, glosario clínico |
| `docs/02_architecture/` | Decisiones de arquitectura (ADRs), diagramas |
| `docs/03_qa/` | Hallazgos de auditoría, casos de prueba, resultados |

## Punto de partida obligatorio

Antes de contribuir, leer en orden:

1. [Visión del Producto](docs/00_foundation/PODOLOGIA_NEXTGEN_VISION.md)
2. [Auditoría Funcional de la Beta](docs/00_foundation/AUDITORIA_FUNCIONAL_BETA.md)
3. [Project Charter](docs/00_foundation/PROJECT_CHARTER.md)

## Stack

- **Frontend:** React + TypeScript + Next.js
- **Estilos:** Tailwind CSS
- **Backend:** Supabase (PostgreSQL + Auth + Storage)
- **Deploy:** Vercel

## Principio fundamental

Este proyecto no reutiliza código de la Beta anterior. La Beta es fuente de conocimiento funcional únicamente. Todo el código es nuevo.
