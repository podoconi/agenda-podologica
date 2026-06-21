# QA Arquitectura de Datos Relacional Conceptual v1

**Documento auditado:** `docs/02_architecture/RELATIONAL_DATA_ARCHITECTURE_v1.md`  
**Fuentes de contraste:** `DATA_MODEL_CONCEPTUAL_v1.1.md`, `QA_DATA_MODEL_CONCEPTUAL_v1_1.md`, `ARQUITECTURA_CONCEPTUAL_v1.1.md`, `CANONICAL_DATA_FOUNDATION_PODOLOGIA.md`, `QA_CANONICAL_DATA_FOUNDATION.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual, sin modificación del documento auditado.

---

## Veredicto

**Rechazado como base inmediata para `SUPABASE_SCHEMA_BLUEPRINT_v1.md`.**

El documento está bien encaminado y contiene una transición DDD -> relacional mayormente coherente, pero todavía tiene inconsistencias que pueden producir un blueprint relacional incorrecto si se arrastran a la siguiente fase. Los bloqueos principales son: T00 no queda materialmente resuelto desde Fase 1, BC6 y BC7 quedan circularmente acoplados por referencias mutuas entre Cobro y Liquidación, Liquidación aparece en Fase 3 aunque la arquitectura conceptual la asigna a Fase 2, y se menciona `TransiciónDeAtención` como entidad derivada sin incluirla en las 22 entidades.

No se rechaza la orientación general del modelo. Se rechaza su uso inmediato como contrato para diseño de schema hasta corregir esos puntos.

---

## Resumen ejecutivo

La arquitectura identifica 22 entidades relacionales y, en general, las justifica bien. La separación por dominios es consistente con los Bounded Contexts aprobados: identidad, clínica, agenda/seguimiento, configuración, economía, relaciones comerciales, documentos y analítica derivada.

La transición DDD -> relacional está bien planteada: varias raíces de agregado se descomponen correctamente en entidades principales y entidades históricas de transición o detalle. `HistoriaClínica`, `EntradaClínica`, `TransiciónDeCita`, `TransiciónDePago`, `AcuerdoComercial` e `ÍtemDeLiquidación` son ejemplos razonables de esa traducción.

Los principios de snapshots e inmutabilidad están correctamente recogidos para `AtenciónClínica`, `Cobro`, `Consentimiento`, `InformeDeSesión`, `Liquidación`, `AcuerdoComercial` e `ÍtemDeLiquidación`. También es correcta la intención de que `ÍtemDeLiquidación` conozca solo datos económicos del Cobro y no contenido clínico.

Sin embargo, el documento aún no está listo para servir como base previa al blueprint de Supabase porque deja ambiguas piezas que en la siguiente fase se convertirían en decisiones estructurales. T00 se declara obligatorio desde Fase 1, pero la entidad transversal de auditoría aparece recién en Fase 3. Además, `Cobro` referencia `Liquidación` y `ÍtemDeLiquidación` referencia `Cobro`, lo que reintroduce el riesgo de acoplamiento circular BC6 <-> BC7 ya advertido en QA anterior.

---

## Hallazgos críticos

### 1. T00 no queda cubierto correctamente desde Fase 1

El documento declara que las cinco acciones T00 generan registros de auditoría de forma atómica desde Fase 1. Esto es coherente con la arquitectura conceptual.

El problema es que la vista por fases ubica `TablaAuditoría` recién en Fase 3 como parte de M21 Auditoría Operacional completa. Eso contradice la regla aprobada: M21 puede ser consultable en Fase 3, pero los datos mínimos de trazabilidad deben existir desde Fase 1.

Riesgo: diseñar el blueprint sin una base persistente para auditoría mínima y descubrir en Fase 3 que los eventos clínicos iniciales no fueron guardados.

### 2. BC6 y BC7 quedan circularmente acoplados

`Liquidación` contiene `ÍtemDeLiquidación`, y cada ítem referencia un `Cobro` de BC6. Eso es correcto: BC7 construye liquidaciones desde hechos económicos.

Pero `Cobro` también incluye una referencia opcional a `Liquidación`. Esa referencia inversa puede convertir el modelo en una dependencia bidireccional BC6 <-> BC7. Conceptualmente, BC6 debería registrar el hecho económico y su estado mínimo, mientras BC7 debería poseer el cierre comercial.

Riesgo: que el futuro schema obligue a BC6 a conocer el ciclo de vida comercial de BC7, o que los cobros no puedan evolucionar sin liquidaciones.

### 3. Liquidación está asignada a Fase 3, contradiciendo la arquitectura conceptual

`RELATIONAL_DATA_ARCHITECTURE_v1.md` ubica `Liquidación` e `ÍtemDeLiquidación` en Fase 3. Sin embargo, `ARQUITECTURA_CONCEPTUAL_v1.1.md` asigna M13 Liquidaciones a Fase 2, dependiente de M11 Centros Médicos.

Riesgo: partir Fase 2 con centros y acuerdos, pero sin la entidad necesaria para cerrar el flujo económico con esos centros.

### 4. `TransiciónDeAtención` se menciona como ejemplo, pero no existe en el catálogo de 22 entidades

La nota de transición DDD -> relacional dice que `AtenciónClínica` da origen a `AtenciónClínica` y `TransiciónDeAtención`. Luego el catálogo de 22 entidades no incluye `TransiciónDeAtención`.

Esto puede ser solo un ejemplo mal elegido, pero afecta directamente T00: registro y cierre de atención son dos de los eventos mínimos que deben quedar trazados.

Riesgo: el blueprint no sabrá si los cambios de estado de atención se auditan con una entidad propia, una auditoría transversal o atributos internos.

---

## Hallazgos medios

### 1. `ConfiguraciónOrganización` aparece como entidad configurable fantasma

El resumen por naturaleza lista `ConfiguraciónOrganización` como configurable, pero el catálogo de dominio declara solo 22 entidades y no la incluye. En `OrganizaciónClínica`, la configuración aparece como atributos conceptuales.

Recomendación: decidir si es parte de `OrganizaciónClínica` o una entidad conceptual separada. No debe quedar en una lista de entidades si no forma parte del catálogo canónico.

### 2. `ValorArancel` menciona modalidad domiciliaria en Fase 1

La entidad `ValorArancel` indica modalidad "particular / domiciliaria — Fase 1; centros en Fase 2+". La arquitectura conceptual v1.1 limita Fase 1 a catálogo + valor base particular; zonas y recargos domiciliarios son Fase 2.

Riesgo: adelantar complejidad de M12/Zonas a Fase 1 por una ambigüedad del modelo de datos.

### 3. `Paciente` referencia `RelaciónConCentro`, pero esa entidad no existe en Fase 1

La referencia opcional a centro es correcta para Fase 2, pero debe quedar faseada. En Fase 1, un paciente puede tener origen textual o categórico sin depender de `RelaciónConCentro`.

Riesgo: que el blueprint de Fase 1 obligue a incorporar una relación comercial todavía postergada.

### 4. Las restricciones de unicidad de negocio son incompletas

Las restricciones incluidas son buenas, pero faltan reglas conceptuales importantes para evitar duplicidades:

- un valor arancel vigente por tipo de atención y modalidad;
- no solapamiento de vigencias de `AcuerdoComercial`;
- no duplicar `ÍtemDeLiquidación` para el mismo Cobro dentro de una liquidación confirmada;
- no duplicar liquidaciones confirmadas para el mismo centro y período, salvo que se modele rectificación explícita;
- relación uno a uno entre consentimiento reemplazado y consentimiento reemplazante.

### 5. La política de eliminación de borradores necesita lenguaje uniforme

Algunas entidades dicen que borradores pueden descartarse o cancelarse. Eso es razonable, pero debe quedar claro si "descartar" significa cambio de estado o eliminación física excepcional.

Riesgo: introducir borrado físico en documentos o atenciones por ambigüedad de vocabulario.

### 6. Hay señales de diseño técnico prematuro

El documento evita SQL y no diseña Supabase, pero menciona `UUID v4`, tablas, columnas, RLS, RPCs, procedimientos almacenados y "columna inline". Varias menciones son contextuales o de exclusión, pero `UUID v4` y "columna inline irreemplazable" ya rozan decisiones técnicas.

Recomendación: mantener el documento en lenguaje conceptual y dejar esos detalles para el blueprint técnico.

### 7. Profesional y OrganizaciónClínica no cierran el camino SaaS, pero la solución aún es frágil

La nota sobre `MembresíaOrganización` reconoce bien el futuro SaaS/multi-organización. Aun así, mientras la membresía no sea entidad conceptual, el blueprint debe evitar que Profesional quede estructuralmente amarrado a una sola organización de forma difícil de evolucionar.

### 8. `Cobro` necesita una regla más explícita de respaldo clínico o administrativo validado

El documento modela bien snapshots económicos, pero en la entidad `Cobro` la relación a `AtenciónClínica` es opcional y el respaldo alternativo queda solo como "concepto del cobro".

Recomendación: explicitar la regla conceptual ya aprobada: no puede existir Cobro sin trabajo clínico o concepto administrativo validado.

---

## Hallazgos menores

### 1. Las 22 entidades principales están bien orientadas

No se detectan duplicidades graves entre las 22 entidades declaradas. La separación entre entidad canónica, histórica, configurable y derivada es razonable.

### 2. `ÍtemDeLiquidación` protege correctamente el límite BC7 -> BC2

El documento declara que el ítem solo conoce datos económicos del Cobro y no accede a contenido clínico de la atención. Esta frontera es correcta y debe conservarse.

### 3. Paciente, HistoriaClínica y EntradaClínica respetan la política clínica de no eliminación

El modelo establece archivado para Paciente, no eliminación de HistoriaClínica y no eliminación de EntradaClínica. Esto es coherente con el dominio clínico.

### 4. TipoDeAtención, ValorArancel y ZonaDomiciliaria no convierten por sí mismos a BC5 en contexto de dios

BC5 queda limitado a catálogo, valores/versiones y recargos. El riesgo está en la redacción de fases y modalidades, no en las entidades base.

### 5. Consentimiento e InformeDeSesión respetan snapshots documentales

Ambos capturan datos del paciente, profesional y contenido al momento de generación/firma. La inmutabilidad documental está bien definida.

### 6. FotografíaClínica queda correctamente en Fase 2

La fase es coherente con la arquitectura conceptual y conserva la posibilidad futura de reconsideración si la validación clínica exige adelantar captura simple.

### 7. Analítica sigue sin entidades propias

Dashboard, reportes y evolución clínica en Fase 1 permanecen como proyecciones derivadas. Esto es correcto.

---

## Riesgos pendientes

### 1. Blueprint técnico con auditoría incompleta

Si T00 no se resuelve antes del blueprint, el diseño posterior puede omitir registros de auditoría que son obligatorios desde el primer día.

### 2. Dependencia circular BC6/BC7 convertida en estructura rígida

Una referencia mutua mal interpretada entre Cobro y Liquidación puede hacer que economía básica y relaciones comerciales evolucionen acopladas.

### 3. Fases inconsistentes con la arquitectura aprobada

Liquidación en Fase 3 y ValorArancel domiciliario en Fase 1 contradicen decisiones previas. Eso puede producir un roadmap técnico distinto al roadmap conceptual.

### 4. Entidades fantasma o ejemplos inconsistentes

`ConfiguraciónOrganización`, `TablaAuditoría` y `TransiciónDeAtención` aparecen de formas distintas: algunas como entidad, otras como ejemplo o placeholder. Antes del blueprint debe quedar claro qué pertenece al contrato canónico.

### 5. Tensión SaaS futura en membresía

La nota de evolución existe, pero el siguiente diseño debe preservar la posibilidad de membresías con ciclo de vida propio sin reestructuración destructiva.

---

## Recomendaciones concretas

1. No usar todavía este documento como base directa de `SUPABASE_SCHEMA_BLUEPRINT_v1.md`.

2. Resolver T00 antes del blueprint: definir conceptualmente cómo se almacenan desde Fase 1 creación de paciente, registro de atención, cierre de atención, modificación de cita y actualización de historia clínica.

3. Decidir si existe una entidad conceptual de auditoría mínima desde Fase 1 o si T00 se cubre con entidades históricas específicas, pero no dejar `TablaAuditoría` solo en Fase 3.

4. Eliminar la circularidad conceptual BC6/BC7: BC7 puede referenciar Cobros mediante ítems de liquidación; BC6 no debería depender estructuralmente de Liquidación salvo como proyección o estado económico mínimo no autoritativo.

5. Mover `Liquidación` e `ÍtemDeLiquidación` a Fase 2 o justificar explícitamente por qué se separan de M13 Liquidaciones aprobado como Fase 2.

6. Corregir la mención a `TransiciónDeAtención`: incorporarla conceptualmente si es necesaria para T00, o retirar el ejemplo y explicar qué entidad cubre esos cambios.

7. Resolver `ConfiguraciónOrganización`: dejarla como parte de `OrganizaciónClínica` o declararla entidad conceptual separada; no mantenerla solo en resúmenes.

8. Ajustar `ValorArancel` para que Fase 1 sea valor base particular; modalidades domiciliarias y centros deben quedar como extensión de Fase 2.

9. Fasear la referencia de `Paciente` a `RelaciónConCentro` para no obligar a Fase 1 a depender de BC7.

10. Completar las restricciones de unicidad de negocio antes del blueprint, especialmente vigencias de arancel/acuerdos, duplicidad de ítems de liquidación y duplicidad de liquidaciones por centro/período.

11. Retirar o suavizar menciones técnicas como UUID v4, columnas, RLS, RPCs y procedimientos, manteniendo el documento en nivel conceptual.

---

## Conclusión final

`RELATIONAL_DATA_ARCHITECTURE_v1.md` es una base conceptual prometedora, pero todavía no está lista para pasar a `SUPABASE_SCHEMA_BLUEPRINT_v1.md`. La estructura de 22 entidades es mayormente coherente y no presenta duplicidades graves, pero T00, fases, circularidad BC6/BC7 y entidades ambiguas deben corregirse antes de transformar este modelo en decisiones de schema.

El veredicto es **Rechazado** para avance inmediato. Con las correcciones indicadas, el documento debería poder re-auditarse rápidamente y probablemente pasar a **Aprobado con observaciones** o **Aprobado**.
