# QA Canonical Data Foundation

**Documento auditado:** `docs/02_architecture/CANONICAL_DATA_FOUNDATION_PODOLOGIA.md`  
**Objetivo:** Validar si el Canonical Data Foundation de Agenda Podológica es suficientemente sólido para servir como contrato conceptual previo a la Arquitectura de Datos y al diseño futuro de Supabase.  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual, sin modificación del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

El documento es suficientemente sólido como contrato conceptual previo a la Arquitectura de Datos. Define con claridad la naturaleza de los datos, separa estado vigente de hechos históricos, protege el núcleo clínico, incorpora captura instantánea y evita caer en diseño técnico prematuro.

Las observaciones no invalidan el documento, pero sí deben resolverse antes de usarlo como base directa para diseño de datos. Los puntos más importantes son: versionar explícitamente acuerdos con Centros Médicos, fortalecer auditoría de Fotografías Clínicas e Informes de Sesión, precisar la relación flexible entre Cobro y trabajo clínico, y ajustar algunas reglas de inmutabilidad demasiado rígidas para permitir correcciones sin sobrescribir evidencia histórica.

---

## Resumen ejecutivo

El Canonical Data Foundation cumple bien su rol: no diseña tablas, no introduce SQL, no especifica Supabase, no define APIs y no escribe código. Se mantiene en el plano correcto: qué es verdad, dónde vive esa verdad, qué puede recalcularse, qué debe preservarse y qué reglas de integridad no deben romperse.

La clasificación general de entidades es consistente. Paciente, Historia Clínica, Atención Clínica, Cobro, Consentimiento, Liquidación, Dashboard y Reportes están ubicados en categorías razonables. También es correcto que algunos conceptos tengan doble naturaleza, como Historia Clínica, Atención cerrada, Cobro, Informe generado y Organización.

El principio de captura instantánea está bien identificado y es uno de los mayores aciertos del documento. Protege cobros, documentos, liquidaciones y cambios de configuración. Sin embargo, necesita una extensión explícita para acuerdos con Centros Médicos: no basta con guardar la configuración vigente; los acuerdos deben tener vigencia temporal o versiones para evitar conflictos al recalcular liquidaciones.

La política de eliminación es clínicamente prudente. La regla "nada clínico se elimina" es adecuada para historia clínica, atenciones cerradas, consentimientos, fotografías y cobros. Aun así, el documento debería reconocer excepciones controladas por obligación legal, duplicados evidentes o datos cargados por error antes de adquirir valor clínico.

La cobertura de auditoría es buena en clínica y cobros básicos, pero insuficiente en evidencia visual y documentos entregados. Una fotografía clínica no debería figurar como "sin auditoría", porque su captura, archivo y cambios de asociación tienen impacto clínico. Un informe de sesión generado y entregado tampoco debería quedar sin auditoría.

La escalabilidad conceptual es buena para profesionales independientes, centros médicos, múltiples profesionales, documentación clínica, evolución avanzada, planes de tratamiento y expansión SaaS. Las observaciones pendientes son de precisión contractual, no de arquitectura de fondo.

---

## Hallazgos críticos

No se detectan hallazgos críticos que obliguen a rechazar el documento.

El fundamento conceptual es coherente con la arquitectura aprobada y puede evolucionar hacia Arquitectura de Datos sin rehacerse desde cero.

---

## Hallazgos medios

### 1. Acuerdos con Centros Médicos requieren versionado explícito

El documento clasifica "Centro Médico (acuerdo)" como Configuración y declara que sus cambios requieren trazabilidad. Eso es correcto, pero insuficiente.

Los acuerdos con centros no son solo configuración vigente: tienen vigencia temporal, condiciones económicas y efectos sobre liquidaciones futuras e históricas. Si una comisión cambia el día 15 del mes, la liquidación del período no puede depender únicamente del acuerdo "actual". Debe existir una versión del acuerdo o al menos una fecha efectiva clara.

Riesgo: liquidaciones en proceso podrían recalcularse con reglas equivocadas si el acuerdo cambia antes de confirmarlas.

Recomendación: clasificar acuerdos con centros como **Configuración versionada con efecto histórico**. La fuente de verdad no debe ser solo "Configuración del Centro Médico", sino "versión vigente del acuerdo para la fecha de la atención o período liquidado".

### 2. Fotografías Clínicas no deberían quedar sin auditoría

La tabla consolidada marca Fotografía Clínica como "Requiere auditoría: No". Esto es débil para un dato clínico visual que el propio documento considera canónico, histórico e inmutable.

Aunque la imagen no se modifique, sí importan los eventos: captura, carga, archivo, corrección de descripción, cambio de asociación a atención o paciente, y eventual descarte si hubo error antes de validarse.

Riesgo: una fotografía mal asociada o archivada sin trazabilidad puede afectar continuidad clínica y confianza legal del registro.

Recomendación: marcar Fotografías Clínicas con auditoría al menos media. La imagen debe ser inmutable, pero sus metadatos y asociaciones deben dejar rastro.

### 3. Informes de Sesión generados y entregados requieren auditoría documental

El Informe de Sesión generado aparece como Derivado + Histórico, inmutable al generarse, pero "Requiere auditoría: No". Esto es insuficiente si el documento fue impreso o enviado al paciente.

Un informe entregado comunica oficialmente una versión de la atención. Debe quedar registro mínimo de cuándo se generó, quién lo generó, desde qué atención, con qué datos capturados y si fue entregado/enviado.

Riesgo: no poder demostrar qué fue comunicado al paciente o a un tercero.

Recomendación: diferenciar "borrador de informe" sin auditoría fuerte de "informe generado/entregado" con auditoría documental obligatoria.

### 4. La fuente de verdad de "cuánto se cobró en una sesión específica" es demasiado estrecha

La tabla de fuente de verdad dice: "Cuánto se cobró en una sesión específica → Cobro registrado en esa atención". Esto calza con Fase 1, pero puede tensionarse con el Dominio Canónico, donde una atención puede generar cero, uno o más cobros, y un cobro puede abarcar un conjunto de atenciones.

Riesgo: diseñar más adelante un modelo de datos demasiado rígido, incapaz de representar controles gratuitos, paquetes, ajustes o cobros agrupados.

Recomendación: cambiar el concepto a "cuánto se cobró por trabajo clínico específico" o "registro económico asociado a la atención o conjunto de atenciones", preservando la flexibilidad conceptual ya aprobada.

### 5. Inmutabilidad de Cita pasada puede ser demasiado rígida

El documento declara "Cita (pasada)" como Canónico + Histórico e inmutable. La regla es correcta para el hecho operativo principal, pero puede ser demasiado rígida si impide registrar correcciones posteriores, motivo de cancelación agregado, o aclaración de una inasistencia mal marcada.

Recomendación: mantener inmutable el hecho original una vez resuelto, pero permitir anotaciones/correcciones posteriores trazadas. Esto replica la lógica de Atención Clínica cerrada: no se sobrescribe, se agrega contexto.

### 6. Consentimiento firmado está bien protegido, pero falta definir revocación o reemplazo

El consentimiento firmado está correctamente clasificado como Histórico + Canónico e inmutable. Sin embargo, el documento no explicita qué ocurre si un consentimiento debe ser revocado, reemplazado por una nueva versión o invalidado por error administrativo.

Riesgo: confundir "inmutable" con "siempre vigente". Un consentimiento firmado puede existir históricamente, pero dejar de ser válido para un procedimiento futuro.

Recomendación: agregar estado documental o regla conceptual: vigente, reemplazado, revocado, invalidado por error, siempre sin modificar ni eliminar el documento original.

---

## Hallazgos menores

### 1. "Centro Médico (identidad)" como solo Referencial puede quedar corto

El sistema no posee al centro médico, pero sí posee el registro interno de la relación con ese centro. La identidad externa es referencial, mientras que el vínculo profesional-centro es canónico/referencial dentro de la organización.

Recomendación: distinguir "entidad externa Centro Médico" de "relación de la profesional con el Centro Médico".

### 2. Zonas Domiciliarias podrían requerir auditoría baja

La tabla consolidada marca Zonas Domiciliarias sin auditoría. Como sus recargos afectan cobros futuros, conviene registrar al menos cambios de valor y fecha de cambio, aunque no sea auditoría clínica.

### 3. Historia Clínica tiene una buena regla, pero falta nombrar corrección de error

El documento permite agregar correcciones o anotaciones posteriores. Conviene explicitar que una entrada errónea se corrige con una nueva entrada de rectificación, no editando la original.

### 4. Profesional ↔ Organización está formulado para Fase 1, pero debe anticipar membresías futuras

La relación obligatoria "todo profesional tiene membresía activa en una organización" es correcta para Fase 1, pero en expansión SaaS un profesional puede tener membresías históricas, inactivas o múltiples organizaciones.

Recomendación: formular la relación como "todo profesional que opera datos clínicos lo hace bajo una membresía organizacional activa".

### 5. Dashboard como fuente de verdad puede prestarse a confusión

La tabla indica "Cómo está yendo el día de la profesional → Dashboard — derivado, no canónico". Está bien si se lee como vista operacional, pero el Dashboard nunca debe ser fuente de verdad de ningún dato primario.

Recomendación: mantener explícito que es fuente de lectura operacional, no fuente de datos.

---

## Riesgos futuros

### 1. Recalcular liquidaciones con acuerdos incorrectos

Sin versiones efectivas de acuerdos con centros, una liquidación en borrador puede cambiar injustificadamente al modificarse la configuración actual del centro.

### 2. Confundir estado actual con verdad histórica

El documento combate bien este riesgo, pero los puntos sensibles siguen siendo: datos del paciente en documentos, nombres de tipos de atención, acuerdos con centros y valores por zona.

### 3. Falta de auditoría sobre evidencia clínica visual

Las fotografías pueden ser diferenciales clínicos y evidencia de evolución. Sin auditoría de captura/asociación/archivo, se pierde confiabilidad.

### 4. Documentos generados sin prueba de entrega

Consentimientos e informes requieren trazabilidad documental. Incluso si la firma simple digital queda para después, la generación y entrega de documentos debería dejar rastro.

### 5. Eliminación excepcional no definida

La política "nada clínico se elimina" es correcta como regla general, pero tarde o temprano aparecerán casos de duplicados, archivos corruptos, carga accidental o solicitud legal. El contrato debe permitir excepciones gobernadas, no silenciosas.

### 6. Expansión SaaS y membresías múltiples

La arquitectura soporta expansión SaaS, pero el CDF debe cuidar que Profesional, Organización y Membresía no queden modelados como una relación demasiado unipersonal.

---

## Recomendaciones concretas

1. Aprobar el documento como base conceptual, con ajustes antes de Arquitectura de Datos.

2. Cambiar "Centro Médico (acuerdo)" a configuración versionada con vigencia temporal y efecto histórico.

3. Ajustar la fuente de verdad de acuerdos: usar la versión del acuerdo vigente para la fecha de atención o período liquidado.

4. Marcar Fotografías Clínicas como entidad que requiere auditoría, al menos para captura, archivo, cambio de metadatos y cambio de asociación.

5. Marcar Informes de Sesión generados/entregados como documentos que requieren auditoría mínima.

6. Precisar la fuente de verdad del cobro para soportar cero, uno, múltiples o cobros agrupados asociados a trabajo clínico.

7. Mantener inmutabilidad fuerte para Atención cerrada, Consentimiento firmado, Fotografía y Cobro, pero agregar mecanismo de corrección por anotación, anulación, reemplazo o nueva versión, nunca por sobrescritura.

8. Agregar estados documentales para consentimiento: vigente, reemplazado, revocado o invalidado, preservando siempre el original.

9. Incorporar eliminación excepcional gobernada para errores previos a validación clínica, duplicados evidentes, archivos corruptos o exigencias legales documentadas.

10. Reformular Profesional ↔ Organización como membresía organizacional activa para operar, dejando espacio a múltiples membresías futuras.

11. Agregar un principio de integridad adicional: **las correcciones no sobrescriben hechos; los rectifican con trazabilidad**.

12. Agregar un principio de integridad adicional: **los acuerdos económicos externos son versionados por vigencia temporal**.

---

## Conclusión final

El Canonical Data Foundation de Agenda Podológica está bien orientado y es suficientemente sólido para actuar como contrato conceptual previo a la Arquitectura de Datos. Protege correctamente el núcleo clínico, define fuentes de verdad, distingue datos canónicos de derivados y establece una política prudente de captura histórica.

El documento debe aprobarse con observaciones porque los problemas detectados son corregibles y no alteran su estructura. Antes de avanzar al diseño futuro de Supabase, conviene resolver especialmente tres puntos: versionado de acuerdos con centros, auditoría de evidencia documental/visual y flexibilidad conceptual de cobros frente a trabajo clínico.

Con esos ajustes, el CDF quedaría en muy buena posición para soportar profesionales independientes, centros médicos, múltiples profesionales, documentación clínica, evolución avanzada, planes de tratamiento y expansión SaaS sin hipotecar el modelo de datos futuro.
