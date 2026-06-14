# PROJECT CHARTER
## Agenda Podológica — Next Generation

**Versión:** 1.0  
**Estado:** Aprobado  
**Fecha:** Junio 2026  
**Responsable:** Roberto Rojas

---

## 1. Nombre del Producto

**Agenda Podológica**

Nombre de trabajo para la plataforma clínica de nueva generación destinada a profesionales de la podología. El nombre definitivo de marca puede evolucionar en fases posteriores.

---

## 2. Propósito

Construir desde cero una plataforma clínica profesional, escalable y trazable, diseñada específicamente para el trabajo podológico real.

Esta plataforma reemplaza la necesidad que tuvo la Beta: dar al profesional de podología una herramienta que centralice la ficha del paciente, la agenda, el registro de atenciones y el seguimiento clínico, con el nivel de calidad técnica y funcional que merece un sistema de uso clínico diario.

El punto de partida es el conocimiento acumulado en la Beta, no su código.

---

## 3. Alcance Inicial

El alcance de la primera iteración se limita a los dominios de mayor valor clínico y operativo, identificados como críticos en la auditoría funcional de la Beta:

**Dentro del alcance inicial:**

- Gestión de pacientes (registro, ficha, búsqueda).
- Historia clínica básica (antecedentes, patologías, medicamentos, alergias).
- Registro de atenciones clínicas.
- Historial de atenciones por paciente.
- Agenda de citas (crear, visualizar, gestionar estados).
- Seguimiento básico y recordatorios de próxima atención.
- Autenticación de usuario profesional.

**Fuera del alcance inicial:**

- Fotografías clínicas (se planifica para fase 2).
- Gestión completa de pagos y caja.
- Reportes y analítica avanzada.
- Multiusuario y roles diferenciados.
- Comunicación con pacientes (WhatsApp, mensajes).
- Inventario de insumos.
- Auditoría operacional avanzada.

El alcance puede crecer en fases posteriores. Nada entra al alcance sin decisión documentada.

---

## 4. Principio Fundamental: La Beta es Conocimiento, No Código

La Beta ubicada en `C:\Users\rroja\Podoconi\pacientes` existió y fue útil. Cumplió su rol.

Sin embargo:

- **No se migra código** desde la Beta hacia este proyecto.
- **No se reutiliza arquitectura** de la Beta.
- **No se reutiliza ninguna integración** (Firebase ni ninguna otra) de la Beta.
- **No se copian componentes, hooks, ni lógica** de la Beta.

La Beta es la única fuente legítima de conocimiento funcional y operacional. Sus documentos (`AUDITORIA_FUNCIONAL_BETA.md`, `PODOLOGIA_NEXTGEN_VISION.md`) son el insumo de diseño. Nada más.

Cualquier referencia a "cómo lo hacía la Beta" es una referencia a su comportamiento funcional observable, nunca a su implementación técnica.

---

## 5. Stack Objetivo Preliminar

El stack tecnológico es una decisión preliminar sujeta a refinamiento en la fase de arquitectura. Se establece aquí como punto de partida acordado.

| Capa | Tecnología |
|---|---|
| Frontend | React + TypeScript |
| Framework web | Next.js (App Router) |
| Estilos | Tailwind CSS |
| Backend / BaaS | Supabase |
| Base de datos | PostgreSQL (vía Supabase) |
| Autenticación | Supabase Auth |
| Storage | Supabase Storage |
| Deploy | Vercel |

**Criterios que motivaron esta elección:**

- Supabase provee modelo canónico relacional (PostgreSQL) con RLS nativo, adecuado para datos clínicos con separación por tenant.
- Vercel + Next.js son el estándar industrial para plataformas React con SSR y deploy continuo.
- TypeScript es obligatorio: sin tipos no hay contrato, y sin contrato no hay calidad sostenible.
- El stack es completamente diferente al de la Beta (Firebase + React sin tipado estricto).

---

## 6. Roles del Equipo

Este proyecto opera con un modelo de equipo híbrido humano-IA con responsabilidades diferenciadas y complementarias.

### Roberto Rojas — Dirección de Producto y Arquitectura

- Toma las decisiones de producto: qué se construye, en qué orden, con qué criterios.
- Define y aprueba la arquitectura antes de que se implemente.
- Es la única voz autorizada para ampliar o reducir el alcance.
- Valida que cada entregable cumple con la visión del producto.
- Trabaja en colaboración con ChatGPT para diseño estratégico y arquitectónico.

### Claude (Anthropic) — Implementación

- Implementa lo que Roberto define y aprueba.
- Escribe código TypeScript/React/SQL siguiendo el modelo canónico acordado.
- No toma decisiones de arquitectura por cuenta propia.
- Documenta cada decisión técnica no trivial en el lugar correcto (`docs/`).
- Reporta bloqueos y ambigüedades en lugar de resolverlos unilateralmente.

### Codex (OpenAI) — Auditoría Forense

- Audita el código generado por Claude de forma independiente.
- Identifica problemas de calidad, seguridad, consistencia y alineación con el modelo canónico.
- No implementa. No propone arquitectura. Solo audita.
- Sus hallazgos se documentan en `docs/03_qa/`.

---

## 7. Reglas de Trabajo

Estas reglas no son sugerencias. Son el contrato operativo del proyecto.

### Claude implementa

Todo el código de producción es escrito por Claude. Roberto puede escribir ejemplos, pruebas de concepto o fragmentos en conversación, pero el código que entra al repositorio es responsabilidad de Claude.

### Codex audita

Codex no toca el código de producción. Su único rol es auditar lo que Claude produce y reportar. Los hallazgos de Codex se revisan con Roberto antes de convertirse en cambios.

### Nada pasa a producción sin QA

No existe "subir rápido para probar". Cada funcionalidad que se declare lista debe tener:

- Lógica implementada y verificada localmente.
- Caso de prueba documentado o ejecutado.
- Revisión de Codex completada o justificación documentada de por qué se omite.

### Toda decisión importante queda documentada

Si se decide cambiar el stack, el modelo de datos, un flujo de usuario, o el alcance de una funcionalidad, esa decisión se registra en `docs/` antes de implementarse. Los `git commit` no son documentación suficiente.

### La Beta es conocimiento, no base técnica

Repetido aquí porque es el error más fácil de cometer: cuando alguien diga "en la Beta esto se hacía así", la respuesta correcta es entender la necesidad funcional, no copiar la solución técnica.

---

## 8. Estructura del Repositorio

```
agenda-podologica/
  docs/
    00_foundation/     ← Documentos fundacionales (este archivo vive aquí)
    01_domain/         ← Modelo de dominio, entidades, glosario
    02_architecture/   ← Decisiones de arquitectura (ADRs), diagramas
    03_qa/             ← Hallazgos de auditoría, casos de prueba, resultados
  supabase/
    migrations/        ← Migraciones SQL versionadas
    seed/              ← Datos de prueba y semilla
    qa/                ← Scripts de validación de base de datos
  src/                 ← Código fuente de la aplicación
  README.md
```

---

## 9. Condiciones de Éxito

Este proyecto habrá cumplido su propósito inicial cuando:

1. Una podóloga pueda registrar un paciente nuevo y su historia clínica en menos de 3 minutos.
2. Una podóloga pueda abrir la ficha de un paciente existente, revisar su historial y registrar una nueva atención en el flujo de una consulta real.
3. La agenda permita visualizar el día, crear citas y cambiar su estado sin fricción.
4. El sistema de seguimiento permita identificar pacientes con atención pendiente.
5. Todo lo anterior funcione en un dispositivo móvil con la misma calidad que en escritorio.
6. Ningún dato clínico se pierde por error del sistema.
7. El código sea auditado y no tenga deuda técnica crítica no documentada.

---

*Este charter es el contrato de trabajo del proyecto. Cualquier cambio sustancial a lo aquí definido requiere revisión y nueva versión del documento.*
