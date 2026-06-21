# QA Arquitectura Conceptual v1.1

**Documento auditado:** `docs/02_architecture/ARQUITECTURA_CONCEPTUAL_v1.1.md`  
**Documento QA base:** `docs/03_qa/QA_ARQUITECTURA_CONCEPTUAL_v1.md`  
**Objetivo:** Validar si la versión 1.1 incorporó correctamente las observaciones del QA anterior sin romper la arquitectura conceptual aprobada.  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual, sin modificación del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

La versión 1.1 incorpora correctamente las observaciones principales levantadas en `QA_ARQUITECTURA_CONCEPTUAL_v1.md` y conserva la arquitectura conceptual aprobada. No se detectan regresiones estructurales, contradicciones graves ni mezcla indebida con SQL, Supabase, API, UI o código.

Las observaciones restantes son menores y de precisión editorial/conceptual: principalmente aclarar la presentación de T00 como capacidad transversal y no como módulo adicional, y alinear la fase de firma simple/trazabilidad documental entre el texto de M14, el mapa conceptual y el resumen de fases.

---

## Resumen ejecutivo

La arquitectura v1.1 cumple su propósito de ser una revisión correctiva, no una reescritura. Mantiene los 22 módulos aprobados, conserva el núcleo Pacientes - Atención Clínica - Agenda, y agrega una capacidad transversal T00 sin alterar indebidamente la estructura modular.

Las observaciones de QA v1 fueron incorporadas de forma sustantiva:

- M02 ya no posee tipos de atención ni valores; M10 queda como propietario funcional del catálogo y arancel.
- M09 queda delimitado como registro económico básico de la atención y excluye explícitamente caja, ERP, tributación, contabilidad, liquidaciones y recargos por zona en Fase 1.
- M10 en Fase 1 queda limitado a catálogo editable y valor base particular.
- M12 corrige su dependencia: depende de M04 y M09, no de M11.
- M14 incorpora firma simple, fecha/hora, versión documental y trazabilidad como subcapacidades futuras.
- La decisión sobre consentimiento básico en Fase 1 queda abierta y explícita.
- M08 mantiene Fase 2, pero con criterio formal de reconsideración.
- T00 Trazabilidad Mínima queda activa desde Fase 1 como base silenciosa para M21.
- M05 define el criterio para pasar de vista a entidad.
- Se agrega el principio de que Agenda Podológica no es ERP, contabilidad ni sistema hospitalario.

El documento sigue siendo conceptual. Las menciones a "tabla de valores", "pantalla" o "dispositivo" se usan en sentido funcional, no como diseño de base de datos, UI o implementación.

---

## Hallazgos críticos

No se detectan hallazgos críticos.

La versión 1.1 no rompe la arquitectura aprobada, no introduce módulos redundantes de alto impacto, no contradice el QA anterior y no cruza hacia diseño técnico.

---

## Hallazgos medios

No se detectan hallazgos medios que bloqueen la aprobación.

Las observaciones solicitadas fueron resueltas de manera suficiente para una versión conceptual fundacional.

---

## Hallazgos menores

### 1. T00 queda bien incorporado, pero debe cuidarse que no se interprete como módulo 23

T00 aparece dentro del Grupo A y en la tabla de fases, junto a M01-M22. El texto aclara correctamente que no es un módulo visible, sino una capacidad silenciosa transversal.

La incorporación es correcta y necesaria, pero conviene mantener siempre la fórmula "22 módulos + T00 capacidad transversal" para evitar que futuras lecturas crean que la estructura modular aprobada pasó a 23 módulos.

### 2. M14 incorpora firma y trazabilidad, pero hay una diferencia de énfasis entre secciones

La descripción de M14 indica que en Fase 2 la firma puede ser manuscrita sobre documento impreso y que en Fase 3 o posterior se soportaría firma simple capturada en pantalla, fecha/hora exacta, versión documental y trazabilidad de firma.

Esto está conceptualmente bien como subcapacidad futura. Sin embargo, el mapa conceptual resume "Firma y trazabilidad (F3)" dentro del bloque Documental Fase 2, lo que puede leerse como una pequeña tensión visual.

Recomendación: en una futura revisión, hacer explícito en el mapa que M14 completo es Fase 2, mientras que firma simple digital/trazabilidad documental avanzada es Fase 3+.

### 3. M09 está correctamente limitado, aunque el nombre "Cobros" sigue requiriendo disciplina futura

El alcance de Fase 1 quedó bien protegido. Aun así, el nombre "Cobros" seguirá atrayendo solicitudes de caja, boletas, cuentas por cobrar, cierres y reportes. El nuevo principio anti-ERP ayuda a contener ese riesgo.

### 4. La decisión abierta de consentimiento básico debe resolverse antes de cerrar Fase 1

La arquitectura no debe decidirlo todavía, y hace bien en dejarlo abierto. Pero si se mantiene abierto durante implementación, puede convertirse en ambigüedad de alcance.

---

## Riesgos pendientes

### 1. Riesgo de interpretación de T00 como módulo funcional

Si T00 se implementa como pantalla o flujo propio en Fase 1, se estaría adelantando M21 Auditoría Operacional. Debe mantenerse como registro silencioso mínimo.

### 2. Riesgo legal de firma y consentimiento

La arquitectura reconoce el riesgo, pero la definición legal sigue pendiente. Antes de implementar firma simple digital o consentimiento firmado, deberá aclararse la validez esperada en Chile y el nivel de respaldo necesario.

### 3. Riesgo de expansión económica de M09/M10

Aunque v1.1 delimita bien el alcance, M09 y M10 seguirán siendo puntos de presión natural para funcionalidades financieras. El principio "no ERP" debe aplicarse como criterio de corte real.

### 4. Riesgo de postergar Fotografías Clínicas sin validar adopción

La postergación a Fase 2 es correcta por Charter. El criterio de reconsideración está bien definido, pero debe usarse activamente durante validación con Constanza.

### 5. Riesgo de que la decisión abierta de consentimiento afecte planificación

La opción A de consentimiento estático en Fase 1 parece pequeña, pero aun así introduce una capacidad documental inicial. Debe resolverse antes de planificar alcance cerrado de Fase 1.

---

## Recomendaciones concretas

1. Aprobar `ARQUITECTURA_CONCEPTUAL_v1.1.md` como versión corregida de la arquitectura conceptual.

2. Mantener la fórmula explícita: **22 módulos funcionales + T00 como capacidad transversal mínima**, no como módulo 23.

3. En una próxima revisión menor, alinear el mapa conceptual de M14 para distinguir: M14 completo en Fase 2; firma simple digital y trazabilidad documental avanzada en Fase 3+.

4. Resolver antes de implementar Fase 1 la decisión abierta sobre consentimiento básico: Opción A u Opción B.

5. Mantener M09 en Fase 1 estrictamente como registro económico básico de la atención.

6. Mantener M10 en Fase 1 estrictamente como catálogo editable con valor base particular.

7. Usar el criterio de reconsideración de M08 durante validación real con Constanza, no dejarlo como nota decorativa.

8. Preservar el principio nuevo anti-ERP como regla de corte para cualquier solicitud económica, administrativa o institucional que aparezca en fases futuras.

---

## Conclusión final

La versión 1.1 corrige adecuadamente las observaciones del QA anterior y mantiene intacta la arquitectura conceptual aprobada. El documento queda más preciso, más defendible y mejor preparado para guiar decisiones posteriores sin adelantarse a diseño técnico.

La recomendación QA es aprobar v1.1 con observaciones menores. No requiere rechazo ni reestructuración; solo cuidar las dos precisiones pendientes: T00 como capacidad transversal, y fase/alcance exacto de firma simple y trazabilidad documental en M14.
