# QA Arquitectura de Datos Relacional Conceptual v1.1

**Documento auditado:** `docs/02_architecture/RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Fuente principal de contraste:** `docs/03_qa/QA_RELATIONAL_DATA_ARCHITECTURE_v1.md`  
**Fuentes conceptuales relacionadas:** `DATA_MODEL_CONCEPTUAL_v1.1.md`, `ARQUITECTURA_CONCEPTUAL_v1.1.md`, `CANONICAL_DATA_FOUNDATION_PODOLOGIA.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual, sin modificación del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

`RELATIONAL_DATA_ARCHITECTURE_v1.1.md` resuelve los bloqueos críticos detectados en `QA_RELATIONAL_DATA_ARCHITECTURE_v1.md` y ya puede utilizarse como base formal para construir `SUPABASE_SCHEMA_BLUEPRINT_v1.md`.

La versión 1.1 incorpora correctamente `EventoAuditoríaMínima`, formaliza `TransiciónDeAtención`, elimina la dependencia estructural de `Cobro` hacia `Liquidación`, mueve `Liquidación` e `ÍtemDeLiquidación` a Fase 2, resuelve `ConfiguraciónOrganización`, ajusta el faseo de `ValorArancel` y evita que `Paciente` dependa de `RelaciónConCentro` en Fase 1.

Las observaciones restantes no bloquean el avance. Deben tratarse como criterios de control para el blueprint, especialmente en el faseo de referencias opcionales a BC7, la precisión de recargos domiciliarios versus valores arancelarios y el resguardo de T00 como trazabilidad atómica.

---

## Resumen ejecutivo

La arquitectura relacional conceptual v1.1 está sustancialmente más madura que v1. El cambio de 22 a 24 entidades está justificado: las dos nuevas entidades (`EventoAuditoríaMínima` y `TransiciónDeAtención`) no son duplicidades, sino correcciones necesarias para sostener T00 desde Fase 1.

La transición DDD -> relacional queda bien expresada. Los Aggregate Roots principales se mantienen como entidades canónicas, mientras que los cambios de estado, historiales y detalles que requieren persistencia propia pasan a entidades relacionales separadas. Esto es correcto para `EntradaClínica`, `TransiciónDeAtención`, `TransiciónDeCita`, `TransiciónDePago`, `AcuerdoComercial` e `ÍtemDeLiquidación`.

T00 queda cubierto desde Fase 1 mediante `EventoAuditoríaMínima`, complementado por entidades específicas de transición. La relación con M21 queda bien delimitada: M21 no inicia la auditoría, solo la consulta y amplía en Fase 3.

BC6 y BC7 ya no quedan circularmente acoplados. `Cobro` no contiene referencia estructural a `Liquidación`, y el estado de liquidación de un cobro se define como proyección derivada desde `ÍtemDeLiquidación`. Esta corrección protege el límite entre registro económico básico y cierre comercial con centros.

El documento mantiene lenguaje predominantemente conceptual. Hay menciones a schema, migraciones, base de datos y referencias técnicas, pero aparecen como delimitación del alcance o como vocabulario conceptual de identificación; no hay SQL, diseño de Supabase, migraciones, APIs, tipos de datos concretos ni código.

---

## Hallazgos críticos

No se detectan hallazgos críticos.

Los bloqueos que impedían avanzar desde v1 fueron resueltos de manera suficiente para usar el documento como base del blueprint.

---

## Hallazgos medios

### 1. Las referencias opcionales a BC7 en AtenciónClínica y Cobro requieren control de fase

`Paciente` ya resuelve correctamente la relación con `RelaciónConCentro`: en Fase 1 mantiene origen como categoría/texto, y la referencia estructural aparece solo en Fase 2.

En `AtenciónClínica` y `Cobro`, la referencia opcional a `RelaciónConCentro` sigue apareciendo como parte de los atributos conceptuales. Esto es correcto para Fase 2, pero el blueprint debe evitar que esa referencia obligue a construir BC7 en Fase 1.

Recomendación: en el blueprint, marcar toda referencia a `RelaciónConCentro` como capacidad de Fase 2, sin impacto estructural obligatorio sobre Fase 1.

### 2. ValorArancel domiciliario y recargo de ZonaDomiciliaria deben evitar duplicidad conceptual

La v1.1 corrige que Fase 1 sea solo valor base particular. Sin embargo, en Fase 2 aparece `ValorArancel (domiciliaria)` con razón "recargos por zona", mientras `ZonaDomiciliaria` también posee recargo asociado.

Riesgo: duplicar el concepto de recargo domiciliario entre `ValorArancel` y `ZonaDomiciliaria`.

Recomendación: en el blueprint, distinguir con claridad entre valor base por modalidad y recargo específico por zona. El recargo de zona debe seguir perteneciendo a `ZonaDomiciliaria` y ser capturado como snapshot en `Cobro`.

### 3. EventoAuditoríaMínima usa referencia genérica a entidad afectada

Conceptualmente es correcto que `EventoAuditoríaMínima` registre la entidad afectada por referencia técnica. Para el blueprint, esta referencia genérica debe quedar controlada para cubrir solo los cinco tipos T00 definidos.

Recomendación: mantener el alcance cerrado a `Paciente`, `AtenciónClínica`, `Cita` e `HistoriaClínica`/`EntradaClínica` según evento. No convertir `EventoAuditoríaMínima` en una auditoría universal de Fase 1.

### 4. Algunas menciones técnicas deben mantenerse fuera del diseño conceptual final

El documento ya retiró decisiones prematuras fuertes. Aun así, conserva expresiones como "schema", "base de datos", "referencia técnica" y "objeto de almacenamiento".

No bloquea el avance, porque no hay SQL ni diseño de Supabase, pero conviene que el blueprint sea quien traduzca esos términos a decisiones técnicas concretas.

---

## Hallazgos menores

### 1. Los bloqueos críticos de v1 fueron resueltos

T00, `TransiciónDeAtención`, circularidad BC6/BC7, fase de Liquidación, `ConfiguraciónOrganización`, `ValorArancel` y `Paciente` respecto de BC7 fueron corregidos.

### 2. EventoAuditoríaMínima cubre correctamente T00 desde Fase 1

La entidad cubre los cinco eventos mínimos: `PacienteCreado`, `AtenciónRegistrada`, `AtenciónCerrada`, `CitaModificada` e `HistoriaClínicaActualizada`. Además, se exige atomicidad con la acción principal.

### 3. TransiciónDeAtención existe formalmente y está alineada con T00

La entidad registra cambios de estado de `AtenciónClínica` y se vincula explícitamente con los eventos T00 de registro y cierre.

### 4. Cobro ya no depende estructuralmente de Liquidación

La relación fluye desde `Liquidación` hacia `ÍtemDeLiquidación` y desde allí hacia `Cobro`. El estado de liquidación de un cobro queda como proyección, no como campo autoritativo de BC6.

### 5. Liquidación e ÍtemDeLiquidación están correctamente en Fase 2

La corrección alinea el modelo relacional con M13 Liquidaciones aprobado como Fase 2.

### 6. ConfiguraciónOrganización fue resuelta

Ya no aparece como entidad independiente. Queda correctamente absorbida como atributos internos de `OrganizaciónClínica`.

### 7. La política de eliminación es consistente

"Descartar" queda definido como cambio de estado. Las entidades clínicas, documentales, económicas e históricas preservan registros y evitan eliminación física como flujo normal.

### 8. Las restricciones de unicidad son suficientes para avanzar

Se agregaron restricciones clave para arancel vigente, vigencias de acuerdos, ítems de liquidación, liquidaciones confirmadas y consentimientos reemplazados. Son suficientes como contrato conceptual previo al blueprint.

---

## Riesgos pendientes

### 1. Convertir EventoAuditoríaMínima en auditoría universal

La entidad debe sostener T00 desde Fase 1, no absorber toda auditoría extendida. Los eventos extendidos de cobros, documentos, acuerdos y liquidaciones deben seguir sus propios ciclos y madurar hacia M21.

### 2. Reintroducir dependencia BC6/BC7 durante el blueprint

Aunque el documento corrigió la circularidad, el diseño posterior podría reintroducirla si intenta almacenar estado de liquidación autoritativo dentro de `Cobro`.

### 3. Duplicar valores económicos entre arancel, zona y acuerdo comercial

El blueprint debe respetar la regla de snapshots: `ValorArancel`, `ZonaDomiciliaria` y `AcuerdoComercial` son fuentes vigentes; `Cobro`, `Liquidación` e `ÍtemDeLiquidación` preservan capturas históricas.

### 4. Cerrar prematuramente el camino SaaS

La nota sobre membresía futura está bien, pero el blueprint debe evitar que `Profesional` quede imposibilitado de evolucionar hacia membresías con roles, estados e invitaciones.

---

## Recomendaciones

1. Usar `RELATIONAL_DATA_ARCHITECTURE_v1.1.md` como base formal para `SUPABASE_SCHEMA_BLUEPRINT_v1.md`.

2. En el blueprint, preservar `EventoAuditoríaMínima` como entidad de Fase 1 y limitarla a los cinco eventos T00.

3. Mantener `TransiciónDeAtención` y `TransiciónDeCita` como logs específicos de dominio, complementarios a la auditoría mínima transversal.

4. No agregar referencia estructural de `Cobro` a `Liquidación`; calcular el estado de liquidación como lectura derivada desde BC7.

5. Fasear explícitamente referencias a `RelaciónConCentro` en `Paciente`, `AtenciónClínica` y `Cobro` para que Fase 1 no dependa de BC7.

6. Separar en el blueprint valor base, recargo domiciliario y acuerdo comercial para evitar duplicidades económicas.

7. Mantener `ConfiguraciónOrganización` como atributos de `OrganizaciónClínica`, no como entidad propia.

8. Trasladar cualquier decisión concreta de tipos, constraints técnicos, índices, policies o mecanismos de implementación al blueprint, no a este documento.

---

## Conclusión final

`RELATIONAL_DATA_ARCHITECTURE_v1.1.md` corrige adecuadamente los bloqueos de v1 y queda conceptualmente apto para derivar `SUPABASE_SCHEMA_BLUEPRINT_v1.md`.

El veredicto es **Aprobado con observaciones**. Las observaciones no impiden avanzar; funcionan como guardrails para que el blueprint no reintroduzca acoplamientos, duplicidades económicas o decisiones técnicas prematuras que la arquitectura conceptual ya logró contener.
