# QA Supabase Schema Blueprint v1.2

**Documento auditado:** `docs/02_architecture/SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`  
**Informe previo:** `docs/03_qa/QA_SUPABASE_SCHEMA_BLUEPRINT_v1_1.md`  
**Fuente de contraste:** `docs/02_architecture/RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Fecha:** Junio 2026  
**Alcance:** Auditoria del blueprint v1.2 como base para migraciones SQL de Fase 1. No se modifica el documento auditado, no se genera SQL y no se crean migraciones.

---

## Veredicto

**Aprobado con observaciones para avanzar a migraciones SQL de Fase 1.**

La version v1.2 corrige los tres bloqueos que impedian aprobar v1.1:

1. `tipo_atencion` queda incorporada como tabla ancla tenant con `UNIQUE (organizacion_id, id)`.
2. `valor_arancel`, `cita` y `atencion_clinica` usan FK compuesta hacia `tipo_atencion`.
3. `atencion_clinica.cita_id` y `cita.cita_anterior_id` ya no dependen de RLS ni de lenguaje opcional.
4. `valor_arancel.vigente_hasta` queda como unica excepcion controlada de actualizacion, cerrada por RPC.
5. `organizacion_clinica` ya no figura como tabla con `UNIQUE (organizacion_id, id)`.
6. Los triggers Tipo B diferidos de Fase 1 tienen orden migrable.

No se detectan hallazgos criticos que bloqueen la conversion a migraciones de Fase 1. Las observaciones restantes son de precision de implementacion y de Fase 2.

---

## Hallazgos criticos

No se identifican hallazgos criticos.

Los bloqueos criticos de v1.1 fueron resueltos de forma suficiente para Fase 1:

- Las FKs tenant hacia `tipo_atencion` ya estan clasificadas como Tipo A.
- Las referencias a `cita.id` quedaron cerradas como FK compuesta.
- La inmutabilidad de `valor_arancel` ya no contradice el cierre de vigencia.

---

## Hallazgos medios

### 1. La regla de `cerrar_arancel` requiere implementacion cuidadosa de permisos

El documento define que `valor_arancel.vigente_hasta` solo puede cambiar de `NULL` a una fecha valida mediante RPC `cerrar_arancel`, y que el rol de aplicacion no puede hacer UPDATE directo.

Esto es correcto como contrato. La observacion es que la migracion debe implementar esta regla mediante privilegios/RPC/triggers de forma consistente. En particular, el trigger no debe depender de una nocion ambigua de "proviene de la RPC" si no se define un mecanismo verificable de contexto o permisos.

**Impacto:** no bloquea el avance, pero debe ser tratado como criterio de QA tecnico al revisar la migracion Fase 1.

### 2. `acuerdo_comercial` mantiene una contradiccion menor de Fase 2

En la seccion de triggers, `acuerdo_comercial` aparece como "todas las columnas, no debe actualizarse nunca", pero luego el documento indica que `acuerdo_comercial.vigente_hasta` se cerrara por RPC `cerrar_acuerdo`, siguiendo la misma logica que `valor_arancel`.

Esto no afecta Fase 1 porque `acuerdo_comercial` es Fase 2. Aun asi, antes de construir migraciones Fase 2 conviene alinear esa fila con la regla especial de `vigente_hasta`, tal como ya se hizo para `valor_arancel`.

### 3. El scope de aprobacion debe limitarse a Fase 1

El documento mantiene tablas, Storage y RPCs de Fase 2 en el blueprint global. Esto es esperable y util, pero la aprobacion de este QA aplica a pasar a migraciones SQL de Fase 1, no a ejecutar tambien Fase 2.

**Impacto:** no bloquea; evita que se interprete la aprobacion como autorizacion para migrar documentos, fotografias, centros, zonas, acuerdos o liquidaciones.

---

## Hallazgos menores

### 1. `tipo_atencion` queda correctamente incorporada como tabla ancla tenant

La seccion 4.3 y el resumen consolidado incluyen `tipo_atencion` en la lista de tablas con `UNIQUE (organizacion_id, id)`. Esto permite que `valor_arancel`, `cita` y `atencion_clinica` referencien tipos de atencion sin riesgo de cruces entre organizaciones.

### 2. Las tres FKs hacia `tipo_atencion` quedan bien corregidas

El catalogo declara:

- `valor_arancel.tipo_atencion_id` como FK compuesta Tipo A.
- `cita.tipo_atencion_id` como FK compuesta Tipo A.
- `atencion_clinica.tipo_atencion_id` como FK compuesta Tipo A.

Esto resuelve el principal hueco de tenant integrity detectado en v1.1.

### 3. Las referencias a `cita.id` ya no dependen de RLS

`atencion_clinica.cita_id` y `cita.cita_anterior_id` quedan declaradas como FK compuesta Tipo A. Ya no aparecen las frases "puede ser Tipo A" ni "misma org por RLS" como base de integridad.

### 4. `organizacion_clinica` queda correctamente tratada como raiz tenant

El documento elimina `organizacion_clinica` de la lista de `UNIQUE (organizacion_id, id)` y aclara que sus FKs entrantes son simples hacia `organizacion_clinica.id`. Esto corrige la contradiccion de v1.1.

### 5. El orden de triggers Tipo B de Fase 1 es migrable

La seccion 13 agrega el paso 12b para crear los triggers de `cita.atencion_clinica_id` y `seguimiento.atencion_clinica_id` despues de crear `atencion_clinica`. `cobro.atencion_clinica_id` queda para el paso 14, cuando ambas tablas ya existen.

### 6. Storage documental queda mejor acotado para Fase 2

Aunque no impacta Fase 1, v1.2 corrige la validacion de todos los paths de `consentimiento`: firma de paciente, firma de profesional y documento firmado. Esto reduce el riesgo futuro de path spoofing.

### 7. El documento conserva las 24 tablas y el faseo aprobado

El catalogo mantiene 24 tablas: 15 de Fase 1 y 9 de Fase 2. No se detecta mezcla indebida de columnas `relacion_centro_id` o `zona_domiciliaria_id` dentro de la migracion Fase 1.

---

## Riesgos pendientes

### 1. Validar en migracion que todas las FK compuestas incluyan el orden correcto de columnas

El blueprint ya define el contrato conceptual. La migracion debe respetar exactamente la forma `(organizacion_id, entidad_id)` contra `(organizacion_id, id)` en las tablas ancla.

### 2. Evitar UPDATE directo sobre `valor_arancel`

El avance a SQL Fase 1 depende de que `cerrar_arancel` sea la unica via para cerrar vigencia. Si se concede UPDATE directo al rol de aplicacion, se rompe la garantia de inmutabilidad controlada.

### 3. No adelantar Fase 2 por accidente

Las tablas y extensiones de Fase 2 estan bien separadas, pero la migracion Fase 1 debe excluir fisicamente `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, documentos, fotografias y columnas Fase 2.

### 4. Revisar `acuerdo_comercial.vigente_hasta` antes de Fase 2

El patron de cierre controlado debe replicarse sin contradiccion en `acuerdo_comercial` antes de escribir migraciones de Fase 2.

### 5. Mantener pruebas de aislamiento multi-tenant

El blueprint ya es suficiente para migrar, pero las migraciones deben probar intentos de crear referencias cruzadas entre organizaciones en `tipo_atencion`, `cita`, `atencion_clinica`, `valor_arancel`, `cobro` y tablas de transicion.

---

## Recomendacion final

**Se puede avanzar a migraciones SQL de Fase 1.**

La recomendacion es avanzar con una condicion de QA tecnico: las migraciones deben demostrar que las FKs compuestas, los triggers Tipo B diferidos, la RPC `cerrar_arancel`, las RPCs T00 y las policies RLS respetan el contrato de v1.2.

No se recomienda construir todavia migraciones de Fase 2 sin una correccion menor previa sobre la regla de `acuerdo_comercial.vigente_hasta`.
