# Agenda Podológica

Plataforma clínica de gestión integral para profesionales de la podología. Permite administrar pacientes, atenciones clínicas, agenda, cobros y documentación clínica desde una interfaz moderna y segura.

## Estado actual

**Arquitectura aprobada. Pendiente implementación Fase 1.**

La documentación de dominio, arquitectura conceptual, modelo de datos y blueprint de Supabase han sido auditados y aprobados. Las migraciones SQL de Fase 1 están diseñadas y pendientes de ejecución.

## Stack aprobado

| Capa | Tecnología |
|---|---|
| Frontend | Next.js + TypeScript |
| Estilos | Tailwind CSS |
| Backend | Supabase (PostgreSQL + Auth + Storage + RLS) |
| Deploy | Vercel |

## Estructura del repositorio

```
agenda-podologica/
├── docs/              # Documentación del proyecto
│   ├── 00_foundation/ # Visión, auditoría Beta, project charter
│   ├── 01_domain/     # Modelo de dominio canónico
│   ├── 02_architecture/ # Arquitectura, modelos de datos, blueprints
│   ├── 03_qa/         # Auditorías y resultados de QA
│   └── 99_archive/    # Documentos históricos o deprecados
├── supabase/          # Schema, migraciones y seeds de Supabase
│   ├── migrations/
│   ├── qa/
│   └── seeds/
├── app/               # App Router de Next.js
├── src/               # Código fuente de la aplicación
│   ├── components/    # Componentes UI reutilizables
│   ├── features/      # Módulos de negocio por feature
│   ├── lib/           # Utilidades y configuraciones
│   ├── hooks/         # React hooks personalizados
│   ├── stores/        # Estado global
│   ├── services/      # Clientes de API y Supabase
│   ├── types/         # Tipos TypeScript compartidos
│   └── styles/        # Estilos globales y configuración Tailwind
├── tests/             # Tests de integración y e2e
├── scripts/           # Scripts de utilidad y automatización
├── public/            # Assets estáticos
└── .github/workflows/ # CI/CD pipelines
```

## Documentación

Leer en este orden antes de contribuir:

1. [Visión del Producto](docs/00_foundation/PODOLOGIA_NEXTGEN_VISION.md)
2. [Auditoría Funcional de la Beta](docs/00_foundation/AUDITORIA_FUNCIONAL_BETA.md)
3. [Project Charter](docs/00_foundation/PROJECT_CHARTER.md)
4. [Dominio Canónico](docs/01_domain/DOMINIO_CANONICO_PODOLOGIA_v1.1.md)
5. [Blueprint de Supabase](docs/02_architecture/SUPABASE_SCHEMA_BLUEPRINT_v1.2.md)

## Advertencia

> **No reutilizar código de la Beta anterior.** La Beta es fuente de conocimiento funcional exclusivamente. Todo el código de esta plataforma es nuevo, diseñado desde la arquitectura aprobada.
