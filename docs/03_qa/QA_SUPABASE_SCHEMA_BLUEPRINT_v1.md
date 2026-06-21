# QA Supabase Schema Blueprint v1

**Documento auditado:** `docs/02_architecture/SUPABASE_SCHEMA_BLUEPRINT_v1.md`  
**Fuente principal de contraste:** `docs/02_architecture/RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Fuente QA relacionada:** `docs/03_qa/QA_RELATIONAL_DATA_ARCHITECTURE_v1_1.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual/técnica de blueprint, sin modificación del documento auditado.

---

## Veredicto

**Rechazado como base inmediata para migraciones SQL por fase.**

El blueprint está muy avanzado y traduce correctamente la mayor parte de `RELATIONAL_DATA_ARCHITECTURE_v1.1.md`: representa las 24 tablas, define una Fase 1 de 15 tablas, mantiene Fase 2 separada, incorpora T00 mediante RPCs, evita que `cobro` dependa de `liquidacion`, y plantea Storage privado para fotografías y documentos.

Sin embargo, todavía no está listo para convertirse en migraciones porque hay dos riesgos estructurales de seguridad/integridad:

1. El modelo RLS basado solo en `organizacion_id = obtener_mi_organizacion_id()` no garantiza por sí mismo que las claves foráneas apunten a registros de la misma organización.
2. El documento delega inmutabilidad de columnas a "policies RLS", pero RLS es control de filas, no control fino de columnas actualizadas.

Ambos puntos pueden producir migraciones inseguras o insuficientes si se trasladan directamente a SQL.

---

## Resumen ejecutivo

El blueprint mantiene coherencia general con la arquitectura relacional v1.1. Las 24 tablas están representadas: 15 en Fase 1, 9 nuevas en Fase 2, más extensiones de columnas para relaciones con centros y zonas. No faltan tablas obligatorias para Fase 1.

La integración `auth.users` ↔ `profesional` está bien orientada: `profesional.auth_user_id` como vínculo 1:1 único, `profesional.organizacion_id` como base de tenancy y `obtener_mi_organizacion_id()` como función auxiliar central. Esta función es suficiente como punto de partida para filtrar filas por organización, pero no es suficiente para validar integridad entre filas relacionadas.

T00 está bien modelado en intención. `evento_auditoria_minima` queda acotado a los cinco eventos mínimos y las operaciones críticas se plantean como RPCs transaccionales. Esto es correcto y debe mantenerse.

Las tablas inmutables y con snapshots están bien identificadas, pero el mecanismo propuesto para proteger campos históricos necesita corrección: no basta con decir que una policy RLS bloquea columnas. Para migraciones reales se requerirán mecanismos adicionales, por ejemplo privilegios por columna, triggers de protección, RPCs controladas o validaciones transaccionales.

El documento no contiene migraciones completas ni SQL ejecutable listo para correr, pero sí incluye fragmentos con `SELECT`, `INSERT`, `UPDATE`, `ALTER TABLE`, nombres de triggers y detalles técnicos. Eso es aceptable para un blueprint técnico, aunque debe mantenerse claramente no ejecutable.

---

## Hallazgos críticos

### 1. RLS por `organizacion_id` no impide referencias cruzadas entre organizaciones

El blueprint establece que todas las tablas incluyen `organizacion_id` y que RLS filtra por `organizacion_id = obtener_mi_organizacion_id()`. Eso protege la visibilidad de la fila principal.

Pero no garantiza que sus FKs pertenezcan a la misma organización. Ejemplos:

- Crear una `atencion_clinica` con `organizacion_id` propia, pero `paciente_id` de otra organización.
- Crear un `cobro` con `organizacion_id` propia, pero `atencion_clinica_id` de otra organización.
- Crear un `item_liquidacion` con `organizacion_id` propia, pero `cobro_id` de otra organización.
- Crear un `evento_auditoria_minima` con `organizacion_id` propia, pero `entidad_id` de otra organización.

Aunque el atacante no pueda leer la fila ajena por RLS, la FK puede existir si conoce o adivina un identificador válido. Esto rompe el aislamiento conceptual entre organizaciones.

**Impacto:** riesgo de cruces de datos entre tenants, inconsistencias clínicas/económicas y auditoría apuntando a registros ajenos.

### 2. RLS no protege columnas inmutables por sí solo

El documento dice que ciertas columnas deben ser "bloqueadas por la policy de UPDATE", por ejemplo snapshots de `cobro`, contenido clínico de `atencion_clinica`, contenido documental de `consentimiento` e información de `liquidacion` confirmada.

El problema es técnico-conceptual: RLS evalúa si una fila puede ser leída, insertada, actualizada o eliminada; no restringe de forma nativa qué columnas específicas pueden cambiar dentro de un `UPDATE`.

**Impacto:** si las migraciones implementan solo RLS, podrían permitir cambios indebidos en campos históricos o snapshots.

### 3. La atomicidad de creación de profesional queda ambigua si se usa Edge Function

El blueprint dice que el perfil `profesional` puede crearse mediante trigger `AFTER INSERT` en `auth.users` o una Edge Function al confirmar email, y luego exige que sea atómico con Auth.

La opción de trigger puede aproximar esa atomicidad dentro de base de datos. La opción de Edge Function no garantiza la misma transacción con `auth.users`.

**Impacto:** riesgo de usuarios autenticados sin perfil profesional, lo que rompe `obtener_mi_organizacion_id()` y puede bloquear acceso legítimo o crear estados huérfanos.

---

## Hallazgos medios

### 1. `obtener_mi_organizacion_id()` es suficiente para filtro base, no para toda la seguridad

La función es correcta como helper central de RLS para resolver la organización del usuario. No obstante, debe complementarse con validaciones de consistencia para cada FK crítica.

Recomendación: las migraciones deben exigir que toda FK relevante pertenezca a la misma `organizacion_id` que la fila, ya sea mediante claves compuestas, triggers de validación, RPCs obligatorias o constraints equivalentes.

### 2. `evento_auditoria_minima` está bien acotado, pero su referencia polimórfica requiere validación fuerte

La tabla limita `tipo_evento` a los cinco T00, lo cual es correcto. Pero `entidad_tipo` + `entidad_id` es una referencia polimórfica, por lo que no tendrá una FK simple hacia la entidad afectada.

Riesgo: eventos apuntando a entidades inexistentes o de otra organización.

Recomendación: las RPCs T00 deben ser la única vía de escritura y deben validar tipo, entidad y organización en la misma transacción.

### 3. Fase 2 está bien separada, pero el documento mezcla columnas Fase 2 dentro de tablas Fase 1

`paciente.relacion_centro_id`, `atencion_clinica.zona_domiciliaria_id`, `atencion_clinica.relacion_centro_id`, `cobro.zona_domiciliaria_id` y `cobro.relacion_centro_id` aparecen en las tablas, correctamente marcadas como columnas Fase 2.

Esto no bloquea, pero el blueprint de migración de Fase 1 debe excluirlas físicamente hasta la migración Fase 2, tal como el propio documento indica.

### 4. ValorArancel, ZonaDomiciliaria y AcuerdoComercial aún requieren una regla explícita de no duplicación lógica

La separación general es correcta:

- `valor_arancel`: precio vigente por tipo/modalidad;
- `zona_domiciliaria`: recargo de traslado;
- `acuerdo_comercial`: reglas del centro;
- `cobro`: snapshots históricos.

Pero `valor_arancel` permite modalidad `domiciliaria` y `zona_domiciliaria` tiene `recargo`. Si no se define el rol de cada uno en Fase 2, se puede duplicar el recargo.

### 5. El modelo de índices es razonable, pero falta un índice compuesto para auditoría por entidad

`evento_auditoria_minima` indexa `entidad_id`, pero como la referencia es polimórfica, conviene indexar conceptualmente por `(entidad_tipo, entidad_id)` para evitar colisiones semánticas y acelerar el trail de una entidad concreta.

### 6. Storage privado está bien planteado, pero falta amarrar metadata contra ruta

Los buckets son privados, con rutas por organización, paciente/documento y record. La intención es correcta.

Riesgo pendiente: que una fila de metadata apunte a un `storage_path` de otra organización o paciente.

Recomendación: las operaciones de subida y registro deben validar que el prefijo de ruta corresponda a la `organizacion_id` y entidad propietaria.

### 7. El documento contiene pseudocódigo SQL y operaciones, aunque no migraciones ejecutables

Hay fragmentos como `SELECT organizacion_id`, `INSERT`, `UPDATE`, `ALTER TABLE`, `CHECK`, `UNIQUE PARCIAL`, `SECURITY DEFINER` y `STABLE`. No constituyen migraciones ejecutables completas, pero sí son lenguaje técnico.

No bloquea por sí mismo, pero conviene rotularlo como pseudocódigo/contrato y no como SQL listo.

---

## Hallazgos menores

### 1. Las 24 tablas están correctamente representadas

El catálogo contiene las 24 tablas esperadas: 15 de Fase 1 y 9 nuevas de Fase 2.

### 2. Fase 1 contiene las 15 tablas correctas

Incluye `organizacion_clinica`, `profesional`, `evento_auditoria_minima`, `tipo_atencion`, `valor_arancel`, `paciente`, `historia_clinica`, `entrada_clinica`, `seguimiento`, `cita`, `transicion_cita`, `atencion_clinica`, `transicion_atencion`, `cobro` y `transicion_pago`.

### 3. Fase 2 no invade Fase 1 de forma indebida

Las columnas y tablas Fase 2 aparecen marcadas como extensiones posteriores. La separación debe preservarse en migraciones.

### 4. `cobro` no depende estructuralmente de `liquidacion`

El blueprint elimina cualquier `liquidacion_id` en `cobro` y define el estado de liquidación como consulta derivada desde `item_liquidacion`.

### 5. `item_liquidacion` mantiene la frontera BC7 → BC6

La tabla referencia `cobro` de forma opaca, preserva snapshots económicos y no filtra contenido clínico de BC2.

### 6. Las restricciones de unicidad principales están presentes

Incluye unicidad por RUT/organización, tipo activo, zona activa, arancel vigente, acuerdo vigente, liquidación borrador/confirmada e ítem por cobro dentro de liquidación.

### 7. Los índices conceptuales cubren las consultas clave sin exceso evidente

Pacientes activos, agenda, atenciones, seguimientos, cobros, auditoría, centros, liquidaciones, fotografías y documentos tienen índices razonables.

---

## Riesgos pendientes

### 1. Seguridad multi-tenant insuficiente si se implementa solo con RLS simple

El riesgo más importante es asumir que `organizacion_id` directo más RLS resuelve todo. Debe validarse también la organización de cada FK.

### 2. Inmutabilidad histórica incompleta si se implementa solo con UPDATE limitado por RLS

Snapshots, contenido clínico cerrado, documentos firmados y liquidaciones confirmadas necesitan protección más fuerte que una policy general de UPDATE.

### 3. Estados parciales en Auth/profesional

Si se usa Edge Function para crear `profesional`, puede haber fallos entre Auth y perfil público. El diseño debe elegir un mecanismo con recuperación o atomicidad realista.

### 4. RPCs T00 con permisos excesivos

Las RPCs son necesarias para atomicidad, pero si se definen con privilegios amplios sin validación interna de organización/FKs, pueden saltarse las garantías de RLS.

### 5. Storage path spoofing

La ruta incluye `organizacion_id`, pero eso debe verificarse al registrar metadata y al emitir URLs o permisos de lectura.

---

## Recomendaciones concretas

1. No convertir todavía este blueprint en migraciones SQL.

2. Agregar una regla transversal de integridad tenant: toda FK de una fila debe apuntar a registros con la misma `organizacion_id`, salvo referencias explícitamente globales como `auth.users`.

3. Definir el mecanismo para enforcing de FK intra-organización antes de migrar: claves compuestas, triggers de validación, RPCs obligatorias o una combinación explícita.

4. Corregir el lenguaje de "bloqueado por RLS" para columnas inmutables. Indicar el mecanismo real esperado: privilegios por columna, triggers anti-update, RPCs cerradas o validaciones equivalentes.

5. Elegir un mecanismo único y realista para crear `profesional` desde `auth.users`. Si se usa Edge Function, no describirlo como atómico con Auth sin compensación o reconciliación.

6. Mantener `evento_auditoria_minima` cerrado a los cinco eventos T00 y hacer que solo las RPCs T00 puedan escribirlo.

7. Agregar índice conceptual `(entidad_tipo, entidad_id)` para auditoría polimórfica.

8. Aclarar en Fase 2 la separación entre valor base domiciliario, recargo de zona y acuerdo comercial para evitar doble cobro o doble snapshot.

9. Validar en Storage que `storage_path` coincida con la organización y entidad propietaria antes de guardar metadata.

10. Mantener Fase 1 estrictamente en 15 tablas y dejar columnas `relacion_centro_id`/`zona_domiciliaria_id` para migraciones Fase 2.

---

## Conclusión final

`SUPABASE_SCHEMA_BLUEPRINT_v1.md` es una traducción sólida de la arquitectura relacional conceptual y está cerca de ser utilizable para migraciones. Representa bien las 24 tablas, el faseo, T00, snapshots, Storage y la separación BC6/BC7.

El veredicto es **Rechazado** para migraciones inmediatas porque el modelo de seguridad e inmutabilidad todavía no es suficientemente preciso: RLS por organización no evita referencias cruzadas entre organizaciones, y RLS no basta para bloquear columnas históricas. Corregidos esos puntos, el blueprint debería poder re-auditarse rápidamente y quedar apto para migraciones de Fase 1.
