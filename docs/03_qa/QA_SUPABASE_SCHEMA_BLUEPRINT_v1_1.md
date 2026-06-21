# QA Supabase Schema Blueprint v1.1

**Documento auditado:** `docs/02_architecture/SUPABASE_SCHEMA_BLUEPRINT_v1.1.md`  
**Informe previo:** `docs/03_qa/QA_SUPABASE_SCHEMA_BLUEPRINT_v1.md`  
**Fuente de contraste:** `docs/02_architecture/RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Fecha:** Junio 2026  
**Alcance:** Auditoria del blueprint v1.1 como base para migraciones SQL de Fase 1. No se modifica el documento auditado y no se propone SQL.

---

## Veredicto

**Rechazado para transformarse directamente en migraciones SQL de Fase 1.**

La version v1.1 resuelve correctamente la mayoria de los bloqueos de v1.0: reconoce que RLS no valida FKs, separa inmutabilidad de RLS, elimina la Edge Function como mecanismo principal de creacion de `profesional`, acota T00 a RPCs, agrega validacion de Storage y explicita que las columnas de Fase 2 no se incluyen fisicamente en Fase 1.

Sin embargo, aun quedan dos bloqueos relevantes para migraciones de Fase 1:

1. La regla transversal de integridad tenant no cubre todas las FKs Fase 1. En particular, quedan referencias simples a `tipo_atencion.id` y algunas referencias a `cita.id` descritas como "por RLS" o "puede ser Tipo A", lo que reabre el riesgo de referencias cruzadas entre organizaciones.
2. `valor_arancel` se declara como nunca actualizable, pero al mismo tiempo el documento indica que un cambio de precio crea un nuevo registro y cierra el anterior con `vigente_hasta`. Esa regla es contradictoria y afecta una tabla de Fase 1.

Por estos puntos, el documento esta cerca de aprobar, pero no debe convertirse todavia en migraciones SQL de Fase 1.

---

## Hallazgos criticos

### 1. Integridad tenant incompleta en FKs hacia `tipo_atencion`

La seccion 4 corrige el problema central de v1.0 al exigir que toda FK respete la misma `organizacion_id`. No obstante, la clasificacion Tipo A omite FKs importantes de Fase 1 hacia `tipo_atencion`:

- `valor_arancel.tipo_atencion_id`
- `cita.tipo_atencion_id`
- `atencion_clinica.tipo_atencion_id`

En el catalogo de tablas estas referencias aparecen como FK simple hacia `tipo_atencion.id`, pero `tipo_atencion` es una tabla tenantizada con `organizacion_id`. Si se migran como FK simple, una organizacion podria asociar aranceles, citas o atenciones a tipos de atencion de otra organizacion si conoce el identificador.

**Impacto:** el bloqueo critico de FKs cruzadas queda parcialmente reabierto en Fase 1.

**Correccion requerida antes de SQL Fase 1:** incorporar `tipo_atencion` como tabla ancla con `UNIQUE (organizacion_id, id)` y exigir FK compuesta o validacion equivalente para toda referencia hacia ella.

### 2. Referencias a `cita.id` aun quedan ambiguas o apoyadas en RLS

La regla tenant esta bien definida para `transicion_cita.cita_id` y `seguimiento.cita_id`, pero no queda igual de cerrada para:

- `atencion_clinica.cita_id`, descrita como FK simple a `cita.id` con nota "mismo contexto, puede ser Tipo A".
- `cita.cita_anterior_id`, descrita como self-reference a `cita.id` con nota "misma org por RLS".

La v1.1 ya reconoce que RLS no valida consistencia de FKs; por lo tanto, mantener una referencia "por RLS" contradice la regla transversal. "Puede ser Tipo A" tampoco es suficiente como contrato para migracion.

**Impacto:** riesgo de migrar referencias de agenda/atencion con integridad tenant incompleta.

**Correccion requerida antes de SQL Fase 1:** declarar explicitamente estas referencias como FK compuesta, trigger de validacion o validacion RPC, sin depender de RLS ni de lenguaje opcional.

### 3. `valor_arancel` combina inmutabilidad total con cierre de vigencia por actualizacion

El documento afirma que `valor_arancel` nunca se actualiza y que un trigger `BEFORE UPDATE` rechaza cualquier UPDATE. En la misma regla, indica que un cambio de precio crea un nuevo registro y cierra el anterior con `vigente_hasta`.

Cerrar el registro anterior requiere modificar `vigente_hasta` o reemplazar ese comportamiento por otra estrategia conceptual. Tal como esta redactado, la migracion podria implementar un trigger que impida el flujo normal de versionado de precios.

**Impacto:** contradiccion funcional en una tabla de Fase 1, con efecto directo sobre arancel basico.

**Correccion requerida antes de SQL Fase 1:** elegir una de estas reglas: permitir solo a una RPC controlada cerrar `vigente_hasta`, o redefinir el versionado como append-only sin UPDATE del registro previo. El blueprint debe decirlo sin ambiguedad.

---

## Hallazgos medios

### 1. `organizacion_clinica` aparece en resumenes con `UNIQUE (organizacion_id, id)`

La tabla `organizacion_clinica` no tiene columna `organizacion_id`, lo cual es correcto: ella misma es el limite tenant. El catalogo lo aclara, pero las secciones 4.3 y 15 la listan entre las tablas que requieren `UNIQUE (organizacion_id, id)`.

No bloquea el modelo si se interpreta como una excepcion, pero en un blueprint listo para SQL conviene eliminar esa contradiccion para que no derive en una migracion imposible o redundante.

### 2. La clasificacion de triggers Tipo B mezcla "opcional" con referencias obligatorias

La definicion de Tipo B habla de referencias cross-context opcionales, pero incluye casos obligatorios de Fase 2 como `item_liquidacion.cobro_id`. La clasificacion conceptual es razonable porque protege una frontera entre contextos, pero la definicion deberia decir "cross-context u opacas" y no depender de que la FK sea nullable.

### 3. El orden de creacion de triggers Tipo B de Fase 1 necesita precision

`cita.atencion_clinica_id` y `seguimiento.atencion_clinica_id` aparecen en tablas que se crean antes de `atencion_clinica`. El documento lista los triggers Tipo B de Fase 1 como artefactos, pero no precisa que algunos deben crearse despues de existir ambas tablas.

No es un bloqueo conceptual, pero si se baja a migracion sin esta nota puede generar errores de orden.

### 4. Storage valida prefijos, pero en documentos clinicos falta amarrar todos los paths de firma

La correccion de Storage es adecuada: buckets privados, prefijo por organizacion y validacion al insertar metadata. Para `consentimiento`, el documento menciona `storage_path` y `documento_firmado_storage_path`, pero la tabla tambien incluye `firma_paciente_storage_path` y `firma_profesional_storage_path`.

Antes de Fase 2 debe quedar explicito que todos los paths documentales y de firma son validados contra organizacion y entidad propietaria. No bloquea SQL Fase 1 porque documentos clinicos son Fase 2.

### 5. `profesional.email` como UNIQUE global puede ser correcto, pero debe mantenerse alineado con Auth

El vinculo `auth.users` -> `profesional` queda mejor resuelto con trigger `AFTER INSERT ON auth.users`, y eliminar Edge Function como mecanismo principal corrige el bloqueo anterior. El uso de `profesional.email` como espejo con UNIQUE global es coherente si se acepta que un email pertenece a un unico profesional global.

Riesgo pendiente: en una evolucion SaaS multi-organizacion, el email global puede dificultar membresias multiples si el mismo usuario necesita actuar en mas de una organizacion. No bloquea Fase 1, pero debe mantenerse como decision consciente.

---

## Hallazgos menores

### 1. La separacion Fase 1 / Fase 2 mejora sustancialmente

Las 15 tablas de Fase 1 estan correctamente listadas y las columnas `relacion_centro_id` y `zona_domiciliaria_id` aparecen como extensiones de Fase 2, no como columnas fisicas de la migracion inicial.

### 2. T00 queda mucho mas solido

`evento_auditoria_minima` se limita a los cinco eventos T00, no recibe INSERT directo desde el rol de aplicacion y solo puede escribirse mediante RPCs T00 con validacion de entidad, tipo y organizacion.

### 3. La inmutabilidad ya no depende de RLS

La v1.1 corrige el error de v1.0: distingue RLS de proteccion de columnas e introduce triggers anti-mutacion, tablas append-only y RPCs controladas. El problema restante no es el mecanismo general, sino la contradiccion puntual de `valor_arancel`.

### 4. `cobro` sigue independiente de `liquidacion`

No se reintroduce dependencia estructural desde `cobro` hacia `liquidacion`. `item_liquidacion` queda en Fase 2 y mantiene una referencia opaca a `cobro`, sin filtrar contenido clinico de BC2.

### 5. La regla economica de Fase 2 esta mejor separada

`valor_arancel`, `zona_domiciliaria.recargo` y `acuerdo_comercial` quedan diferenciados como precio base, recargo de traslado y distribucion interna con centro medico. Esto resuelve el riesgo principal de duplicidad economica detectado en la auditoria anterior.

---

## Riesgos pendientes

### 1. Reabrir cruces tenant por FKs no clasificadas

El mayor riesgo es que el equipo implemente solo las FKs mencionadas en la seccion 4 y deje otras referencias tenantizadas como FK simple. La regla transversal debe aplicarse a todas las FKs, no solo a las listadas inicialmente.

### 2. Convertir "puede ser Tipo A" en decision de implementacion tardia

El blueprint previo a SQL debe ser imperativo en las relaciones de seguridad. Las frases opcionales son utiles en arquitectura conceptual, pero peligrosas en un contrato de migracion.

### 3. Bloquear versionado de aranceles por exceso de inmutabilidad

Si `valor_arancel` se migra como totalmente inmutable y sin canal controlado para cerrar vigencia, el sistema no podra mantener precios vigentes historizados de forma usable.

### 4. Evolucion SaaS con usuario en multiples organizaciones

Fase 1 permite `profesional.organizacion_id` directo, coherente con la arquitectura aprobada. Aun asi, el modelo debe evitar que `auth_user_id` y email global se conviertan en obstaculo cuando aparezca `membresia_organizacion`.

### 5. Storage path spoofing en Fase 2 documental

La mitigacion principal ya existe, pero debe extenderse explicitamente a cada campo de path de documentos y firmas, no solo al documento final.

---

## Recomendacion final

**No avanzar aun a SQL Fase 1.**

La v1.1 esta muy cerca de aprobar, pero requiere una version corta de correccion antes de migraciones. La recomendacion concreta es emitir `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md` o un parche equivalente que:

1. Incluya `tipo_atencion` como tabla ancla de integridad tenant y convierta sus referencias Fase 1 en FK compuesta o validacion equivalente.
2. Cierre explicitamente `atencion_clinica.cita_id` y `cita.cita_anterior_id` sin depender de RLS.
3. Corrija la regla de versionado de `valor_arancel` para permitir cierre controlado de vigencia o adoptar un modelo append-only puro.
4. Limpie la contradiccion de `organizacion_clinica` en los resumenes de `UNIQUE (organizacion_id, id)`.
5. Precise el orden de creacion de triggers Tipo B cuando la tabla destino se crea despues de la tabla origen.

Con esas correcciones, el blueprint deberia quedar aprobable para migraciones SQL de Fase 1 sin necesidad de redisenar la arquitectura.
