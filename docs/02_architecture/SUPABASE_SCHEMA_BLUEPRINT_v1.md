# Supabase Schema Blueprint — Agenda Podológica

**Versión:** 1.0  
**Estado:** Borrador — pendiente de QA  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuente canónica:** `RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Siguiente paso:** migraciones SQL por fase

---

## Propósito y alcance

Este documento transforma la Arquitectura de Datos Relacional Conceptual (v1.1) en especificaciones de implementación para Supabase / PostgreSQL. Define las tablas, columnas, claves, relaciones, índices, modelo de acceso RLS, integración con Supabase Auth, buckets de Storage y el orden de migración por fases.

No contiene SQL. No contiene migraciones ejecutables. No define policies reales. No escribe funciones ni RPCs. Es el contrato de diseño que precede a esos artefactos.

Toda migración futura debe rastrear cada decisión a este documento. Las desviaciones respecto del blueprint requieren justificación explícita y actualización de este documento antes de implementarse.

---

## Convenciones generales

### Esquema
Todas las tablas de la aplicación residen en el esquema `public`. Las tablas de Supabase Auth (como `auth.users`) residen en el esquema `auth` y son administradas por Supabase; no se crean ni modifican manualmente.

### Nomenclatura
- Tablas: `snake_case`, singular, en español. Ejemplo: `atencion_clinica`.
- Columnas: `snake_case`, en español. Ejemplo: `fecha_inicio`.
- Claves foráneas: `{entidad_referenciada}_id`. Ejemplo: `organizacion_id`.
- Claves foráneas con múltiples referencias a la misma entidad: sufijo descriptivo. Ejemplo: `cita_anterior_id`, `liquidacion_rectificada_id`.
- Columnas snapshot: sufijo `_snapshot`. Ejemplo: `tipo_atencion_nombre_snapshot`.

### Clave primaria
Toda tabla tiene una columna `id` de tipo UUID generado automáticamente por el sistema al momento del INSERT. La clave primaria es técnica, inmutable y sin significado de negocio.

### Timestamps estándar
- `creado_en`: timestamp con zona horaria, NOT NULL, valor por defecto = momento del INSERT. Inmutable.
- `actualizado_en`: timestamp con zona horaria, nullable, actualizado automáticamente por trigger en cada UPDATE. Solo presente en tablas cuyos registros pueden modificarse.

Tablas de log inmutable (tablas de transición, `evento_auditoria_minima`, `intento_contacto`) no tienen `actualizado_en`.

### Claves foráneas: comportamiento ante eliminación
En ninguna tabla se aplica `CASCADE DELETE`. Dado que la política del sistema prohíbe la eliminación física de registros clínicos, económicos y documentales, toda referencia foránea a registros que no pueden eliminarse es `RESTRICT`. Las referencias a registros que pueden cambiar de estado (como `atencion_clinica_id` opcional en `seguimiento`) usan `SET NULL` si el campo es nullable, de forma que un cambio de estado del referenciado no bloquea el registro secundario.

Las referencias entre contextos distintos (cross-context references, ej. `cobro.atencion_clinica_id`) son técnicamente opacas: el campo almacena el identificador técnico pero BC6 no accede al contenido clínico de BC2 por esta referencia.

### Tipo `estado` y enumeraciones
Los estados de cada entidad se implementan como restricciones de texto con los valores específicos documentados aquí. La lista exacta de valores permitidos para cada campo `estado` está definida en la sección de cada tabla.

### `organizacion_id` en todas las tablas
Todas las tablas llevan `organizacion_id` como columna directa, incluyendo tablas de log y de transición. Esto simplifica el modelo de RLS (filtro directo sin join) y es el patrón estándar de multi-tenancy en Supabase.

---

## 1. Integración con Supabase Auth

### 1.1 Modelo de autenticación

Supabase gestiona la autenticación a través de `auth.users`. La aplicación no crea ni modifica esta tabla. Cada profesional que accede al sistema tiene exactamente una entrada en `auth.users` y exactamente una entrada en la tabla `profesional` del esquema `public`.

El vínculo entre ambas es `profesional.auth_user_id`, que referencia `auth.users(id)` con restricción UNIQUE.

```
auth.users.id (UUID)  ←──(1:1)──→  profesional.auth_user_id
```

### 1.2 Función auxiliar de contexto

Las políticas RLS de todas las tablas requieren saber la `organizacion_id` del profesional autenticado. La función auxiliar que provee este dato tiene la forma conceptual:

```
obtener_mi_organizacion_id()
  → SELECT organizacion_id
    FROM profesional
    WHERE auth_user_id = auth.uid()
```

Esta función se invoca dentro de las políticas RLS como condición de filtro. No es visible al usuario de la aplicación.

### 1.3 Creación del perfil de profesional

Cuando un usuario completa el registro mediante Supabase Auth, se debe crear automáticamente su registro en `profesional`. El mecanismo recomendado es una función de base de datos invocada desde un trigger `AFTER INSERT` en `auth.users`, o una Edge Function que se ejecuta al confirmar el email.

Esta creación es atómica con el registro en Auth: si falla la creación del profesional, el usuario no debe quedar sin perfil.

### 1.4 Sincronización de email

El campo `profesional.email` refleja el email de `auth.users.email`. Si el email de autenticación cambia, `profesional.email` debe actualizarse en la misma transacción para mantener consistencia. Este cambio debe quedar trazado.

---

## 2. Storage Buckets

### Bucket: `fotografias-clinicas`

| Atributo | Valor |
|---|---|
| Visibilidad | Privado |
| Acceso | Solo usuarios autenticados de la misma organización |
| Patrón de ruta | `{organizacion_id}/{paciente_id}/{fotografia_id}/{nombre_archivo}` |
| Mutabilidad | Los objetos subidos no deben sobrescribirse; son inmutables desde la carga |
| Política de eliminación | Ningún objeto se elimina como parte del flujo normal |
| Fase | Fase 2 — crear en la misma migración que la tabla `fotografia_clinica` |

El campo `fotografia_clinica.storage_path` almacena la ruta relativa dentro de este bucket.

---

### Bucket: `documentos-clinicos`

| Atributo | Valor |
|---|---|
| Visibilidad | Privado |
| Acceso | Solo usuarios autenticados de la misma organización |
| Patrón de ruta | `{organizacion_id}/{tipo_documento}/{record_id}/{nombre_archivo}` |
| Tipos de documento | `consentimientos/` · `informes-sesion/` |
| Mutabilidad | Los objetos firmados o generados formalmente no deben sobrescribirse |
| Política de eliminación | Ningún objeto se elimina como parte del flujo normal |
| Fase | Fase 2 — crear en la misma migración que `consentimiento` e `informe_sesion` |

Los campos `consentimiento.documento_firmado_storage_path` e `informe_sesion.storage_path` almacenan las rutas relativas en este bucket.

---

## 3. Estados válidos por entidad

Estos son los valores de negocio aceptados en cada campo `estado`. En la migración se implementan como restricciones CHECK o como tipos enumerados.

| Tabla | Campo | Valores válidos |
|---|---|---|
| `organizacion_clinica` | `estado` | `activa` · `suspendida` · `cerrada` |
| `profesional` | `estado` | `activo` · `suspendido` · `desactivado` |
| `paciente` | `estado` | `activo` · `en_seguimiento` · `inactivo` · `archivado` |
| `entrada_clinica` | `estado` | `activo` · `resuelto` · `inactivo` |
| `atencion_clinica` | `estado` | `registrada` · `cerrada` · `descartada` |
| `atencion_clinica` | `modalidad` | `particular` · `domiciliaria` · `centro_medico` |
| `fotografia_clinica` | `estado` | `activa` · `archivada` |
| `fotografia_clinica` | `contexto` | `perfil_paciente` · `asociada_atencion` |
| `cita` | `estado` | `agendada` · `confirmada` · `atendida` · `cancelada` · `inasistida` · `reprogramada` |
| `seguimiento` | `urgencia` | `normal` · `prioritario` · `urgente` |
| `seguimiento` | `estado` | `pendiente` · `contactado` · `agendado` · `completado` · `vencido` · `descartado` |
| `seguimiento` | `origen` | `manual` · `automatico_cierre_atencion` |
| `intento_contacto` | `canal` | `telefono` · `mensajeria` · `email` · `presencial` · `otro` |
| `tipo_atencion` | `estado` | `activo` · `inactivo` |
| `valor_arancel` | `modalidad` | `particular` · `domiciliaria` · `centro_medico` |
| `zona_domiciliaria` | `estado` | `activa` · `inactiva` |
| `cobro` | `modalidad` | `particular` · `domiciliaria` · `centro_medico` |
| `cobro` | `categoria_origen` | `atencion_individual` · `conjunto_atenciones` · `recargo_administrativo` · `anticipo` |
| `cobro` | `estado_pago` | `pendiente` · `pagado_parcial` · `pagado` · `anulado` |
| `relacion_centro` | `estado` | `activo` · `inactivo` |
| `acuerdo_comercial` | `tipo_acuerdo` | `porcentaje_comision` · `valor_fijo_por_atencion` · `valor_fijo_mensual` |
| `liquidacion` | `estado` | `borrador` · `confirmada` · `pagada` · `descartada` |
| `consentimiento` | `estado` | `borrador` · `generado` · `firmado` · `revocado` · `reemplazado` |
| `informe_sesion` | `estado` | `borrador` · `generado` · `entregado` · `descartado` |
| `informe_sesion` | `canal_entrega` | `impresion` · `correo` · `otro` |
| `evento_auditoria_minima` | `tipo_evento` | `paciente_creado` · `atencion_registrada` · `atencion_cerrada` · `cita_modificada` · `historia_clinica_actualizada` |

---

## 4. Catálogo de tablas

---

### Tabla: `organizacion_clinica`

**Dominio:** Identity · **Fase:** 1 · **Multi-tenancy root**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | Generado automáticamente |
| `nombre_legal` | texto | NOT NULL | |
| `nombre_fantasia` | texto | nullable | |
| `identificacion_fiscal` | texto | nullable, UNIQUE | RUT empresa u otro. Único en el sistema. |
| `email` | texto | nullable | |
| `telefono` | texto | nullable | |
| `direccion` | texto | nullable | |
| `zona_horaria` | texto | NOT NULL | Ej. `America/Santiago` |
| `duracion_cita_defecto_minutos` | entero | NOT NULL | Por defecto 60 |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Auto-actualizado en UPDATE |

**Restricciones de unicidad:** `identificacion_fiscal` UNIQUE cuando no es null.

**RLS:**
- SELECT: solo el profesional cuya `organizacion_id` coincide
- UPDATE: campos operativos permitidos (no `identificacion_fiscal`, no `id`)
- INSERT / DELETE: solo sistema (provisioning)

---

### Tabla: `profesional`

**Dominio:** Identity · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `auth_user_id` | UUID | NOT NULL, UNIQUE | FK → `auth.users(id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_completo` | texto | NOT NULL | |
| `email` | texto | NOT NULL, UNIQUE | Espejo de `auth.users.email`. Único global. |
| `nombre_para_documentos` | texto | NOT NULL | Nombre que aparece en consentimientos e informes |
| `especialidad` | texto | nullable | |
| `numero_colegiado` | texto | nullable | |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Restricciones de unicidad:** `auth_user_id` UNIQUE · `email` UNIQUE.

**Nota SaaS:** La relación `profesional → organizacion_clinica` es directa en Fase 1. En una expansión SaaS multi-organización, esta relación necesitará una tabla intermedia de membresía con ciclo de vida propio. El campo `organizacion_id` en `profesional` puede quedar como referencia a la organización principal; la membresía activa se determinaría desde la tabla intermedia.

**RLS:**
- SELECT: misma organización
- UPDATE: solo el propio profesional puede editar su perfil; campos de estado solo por sistema
- INSERT: sistema (trigger post-auth)
- DELETE: nunca

---

### Tabla: `evento_auditoria_minima`

**Dominio:** Transversal · **Fase:** 1 · **Log inmutable · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `tipo_evento` | texto | NOT NULL | Ver sección 3 |
| `entidad_tipo` | texto | NOT NULL | Nombre de la tabla afectada: `paciente`, `atencion_clinica`, `cita`, `historia_clinica` |
| `entidad_id` | UUID | NOT NULL | ID del registro afectado (referencia polimórfica) |
| `estado_anterior` | texto | nullable | Vacío cuando el evento es una creación |
| `estado_nuevo` | texto | nullable | |
| `resumen_contextual` | texto | nullable | Descripción libre del cambio |
| `ocurrido_en` | timestamp tz | NOT NULL | Momento exacto del evento |

**Sin `actualizado_en`.** Esta tabla no tiene columna de actualización porque es completamente inmutable.

**Restricciones físicas de inmutabilidad:**
- RLS: solo INSERT y SELECT. No UPDATE. No DELETE.
- La tabla no debe tener habilitados triggers de UPDATE en producción.
- Los registros de esta tabla nunca se modifican ni eliminan bajo ninguna circunstancia operacional.

**Atomicidad T00:** Cada acción que genera un `EventoAuditoríaMínima` debe escribir en ambas tablas (la entidad principal y esta tabla) dentro de la misma transacción de base de datos. Si el INSERT en `evento_auditoria_minima` falla, la transacción completa debe revertirse.

**RLS:**
- SELECT: misma organización
- INSERT: misma organización · solo sistema (nunca desde el cliente directamente)
- UPDATE: nunca
- DELETE: nunca

---

### Tabla: `paciente`

**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_completo` | texto | NOT NULL | |
| `rut` | texto | nullable | Unicidad parcial: único por organización cuando se informa |
| `fecha_nacimiento` | fecha | nullable | |
| `telefono_principal` | texto | nullable | |
| `telefono_alternativo` | texto | nullable | |
| `email` | texto | nullable | |
| `direccion` | texto | nullable | |
| `origen_categoria` | texto | nullable | `particular` · `centro_medico` · `administrado_tercero` |
| `relacion_centro_id` | UUID | nullable | FK → `relacion_centro.id`. **Columna Fase 2** — agregar en migración de Fase 2 |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `notas` | texto | nullable | |
| `creado_por` | UUID | NOT NULL | FK → `profesional.id` |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Restricciones de unicidad:**
- `(organizacion_id, rut)` UNIQUE PARCIAL donde `rut IS NOT NULL`

**Política de eliminación:** Estado `archivado` es el estado terminal. No se elimina físicamente.

**RLS:**
- SELECT / INSERT / UPDATE: misma organización
- UPDATE bloqueado por RLS cuando estado = `archivado` (registro terminal)
- DELETE: nunca

---

### Tabla: `historia_clinica`

**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `paciente_id` | UUID | NOT NULL, UNIQUE | FK → `paciente.id`. Relación 1:1 estricta. |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `resumen_general` | texto | nullable | Mutable: resumen de largo plazo del profesional |
| `creado_en` | timestamp tz | NOT NULL | Creada simultáneamente con el paciente |

**Sin `actualizado_en`** para el contenido estructural. Si `resumen_general` se decide auditar, agregar `actualizado_en`.

**Restricciones de unicidad:** `paciente_id` UNIQUE (una sola historia por paciente).

**Creación atómica:** La tabla `historia_clinica` se crea en la misma transacción que el paciente. El sistema nunca crea un `paciente` sin su `historia_clinica`.

**RLS:**
- SELECT: misma organización
- INSERT: sistema (atómico con paciente)
- UPDATE: solo `resumen_general`
- DELETE: nunca

---

### Tabla: `entrada_clinica`

**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `historia_clinica_id` | UUID | NOT NULL | FK → `historia_clinica.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `tipo` | texto | NOT NULL | `patologia` · `medicamento` · `alergia` · `observacion` · `otro` |
| `descripcion` | texto | NOT NULL | **Inmutable desde creación** |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `notas_adicionales` | texto | nullable | Aclaraciones posteriores — no modifica `descripcion` |
| `registrado_por` | UUID | NOT NULL | FK → `profesional.id` |
| `registrado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo para cambios de estado |

**RLS:**
- SELECT: misma organización
- INSERT: misma organización
- UPDATE: solo campo `estado` y `notas_adicionales`. El campo `descripcion` NO debe ser actualizable por RLS.
- DELETE: nunca

---

### Tabla: `atencion_clinica`

**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `tipo_atencion_id` | UUID | nullable | FK → `tipo_atencion.id`. Referencia viva para consulta |
| `tipo_atencion_nombre_snapshot` | texto | nullable | Snapshot capturado al registrar o al cerrar |
| `modalidad` | texto | NOT NULL | Ver sección 3 |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `fecha_inicio` | timestamp tz | NOT NULL | |
| `fecha_cierre` | timestamp tz | nullable | Poblado al cerrar. Inmutable desde cierre. |
| `tratamiento` | texto | nullable | **Inmutable desde que estado = `cerrada`** |
| `hallazgos` | texto | nullable | **Inmutable desde que estado = `cerrada`** |
| `notas_clinicas` | texto | nullable | **Inmutable desde que estado = `cerrada`** |
| `indicaciones` | texto | nullable | **Inmutable desde que estado = `cerrada`** |
| `cita_id` | UUID | nullable | FK → `cita.id` |
| `zona_domiciliaria_id` | UUID | nullable | FK → `zona_domiciliaria.id`. **Columna Fase 2** |
| `relacion_centro_id` | UUID | nullable | FK → `relacion_centro.id`. **Columna Fase 2** |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo mientras estado = `registrada` |

**RLS:**
- SELECT: misma organización
- INSERT: misma organización
- UPDATE: solo mientras estado = `registrada`. Los campos de contenido clínico (`tratamiento`, `hallazgos`, `notas_clinicas`, `indicaciones`) y `fecha_cierre` deben ser protegidos por RLS contra modificación cuando estado = `cerrada`.
- DELETE: nunca

---

### Tabla: `transicion_atencion`

**Dominio:** Core Clinical · **Fase:** 1 · **Log inmutable · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `atencion_clinica_id` | UUID | NOT NULL | FK → `atencion_clinica.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `motivo` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Atomicidad T00:** Un cambio de estado en `atencion_clinica` debe escribir en esta tabla Y en `evento_auditoria_minima` en la misma transacción.

**RLS:**
- SELECT: misma organización
- INSERT: sistema (atómico con cambio de estado en `atencion_clinica`)
- UPDATE: nunca
- DELETE: nunca

---

### Tabla: `fotografia_clinica`

**Dominio:** Core Clinical · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `atencion_clinica_id` | UUID | nullable | FK → `atencion_clinica.id` |
| `descripcion` | texto | NOT NULL | |
| `contexto` | texto | NOT NULL | Ver sección 3 |
| `storage_path` | texto | NOT NULL | Ruta relativa en bucket `fotografias-clinicas`. **Inmutable desde creación.** |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `capturado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo para cambios de metadatos (descripcion, estado) |

**RLS:**
- SELECT / INSERT: misma organización
- UPDATE: solo metadatos (`descripcion`, `estado`). El `storage_path` no debe ser actualizable.
- DELETE: nunca

---

### Tabla: `cita`

**Dominio:** Operational · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `tipo_atencion_id` | UUID | nullable | FK → `tipo_atencion.id` |
| `tipo_atencion_nombre_snapshot` | texto | nullable | Capturado al agendar si tipo está definido |
| `inicio` | timestamp tz | NOT NULL | |
| `duracion_minutos` | entero | NOT NULL | |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `motivo_cancelacion` | texto | nullable | |
| `notas` | texto | nullable | |
| `cita_anterior_id` | UUID | nullable | FK → `cita.id` (self-reference para reprogramación) |
| `seguimiento_id` | UUID | nullable | FK → `seguimiento.id` |
| `atencion_clinica_id` | UUID | nullable | FK → `atencion_clinica.id` (enlace al resultado) |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo mientras no histórica |

**Restricción de no solapamiento:** A nivel de aplicación / función de base de datos, un profesional no puede tener dos citas con estado `agendada` o `confirmada` con horarios superpuestos. Esta verificación no se expresa como constraint de tabla simple sino como validación transaccional.

**RLS:**
- SELECT / INSERT / UPDATE: misma organización
- UPDATE bloqueado cuando estado es terminal (`atendida`, `cancelada`, `inasistida`)
- DELETE: nunca

---

### Tabla: `transicion_cita`

**Dominio:** Operational · **Fase:** 1 · **Log inmutable · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `cita_id` | UUID | NOT NULL | FK → `cita.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `motivo` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Atomicidad T00:** Cada cambio de estado en `cita` debe escribir en esta tabla Y en `evento_auditoria_minima` en la misma transacción.

**RLS:** SELECT misma org · INSERT sistema · UPDATE nunca · DELETE nunca.

---

### Tabla: `seguimiento`

**Dominio:** Operational · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `tipo` | texto | NOT NULL | Texto libre que describe el tipo de seguimiento |
| `urgencia` | texto | NOT NULL | Ver sección 3 |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `origen` | texto | NOT NULL | Ver sección 3 |
| `atencion_clinica_id` | UUID | nullable | FK → `atencion_clinica.id`. Referencia opaca entre BC4 y BC2. |
| `cita_id` | UUID | nullable | FK → `cita.id` |
| `notas` | texto | nullable | |
| `fecha_limite` | timestamp tz | nullable | |
| `resuelto_en` | timestamp tz | nullable | Poblado al cerrar con estado terminal |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**RLS:**
- SELECT / INSERT / UPDATE: misma organización
- UPDATE bloqueado cuando estado = `completado` o `descartado`
- DELETE: nunca

---

### Tabla: `intento_contacto`

**Dominio:** Operational · **Fase:** 2 · **Log inmutable**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `seguimiento_id` | UUID | NOT NULL | FK → `seguimiento.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `canal` | texto | NOT NULL | Ver sección 3 |
| `resultado` | texto | nullable | |
| `notas` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**RLS:** SELECT / INSERT misma org · UPDATE nunca · DELETE nunca.

---

### Tabla: `tipo_atencion`

**Dominio:** Configuration (BC5 Shared Kernel) · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre` | texto | NOT NULL | |
| `descripcion` | texto | nullable | |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Restricciones de unicidad:**
- `(organizacion_id, nombre)` UNIQUE PARCIAL donde `estado = 'activo'`

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca (desactivar en lugar de eliminar).

---

### Tabla: `valor_arancel`

**Dominio:** Configuration (BC5) · **Fase:** 1 (modalidad `particular`) / 2 (resto)

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `tipo_atencion_id` | UUID | NOT NULL | FK → `tipo_atencion.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `modalidad` | texto | NOT NULL | Ver sección 3 |
| `valor` | decimal | NOT NULL | Precio capturado en esta versión |
| `vigente_desde` | fecha | NOT NULL | |
| `vigente_hasta` | fecha | nullable | NULL = valor vigente actual |
| `configurado_por` | UUID | NOT NULL | FK → `profesional.id` |
| `creado_en` | timestamp tz | NOT NULL | |

**Sin `actualizado_en`**: los registros son inmutables. Un cambio de precio cierra el registro anterior (`vigente_hasta = hoy`) y crea uno nuevo.

**Restricciones de unicidad:**
- `(tipo_atencion_id, modalidad)` UNIQUE PARCIAL donde `vigente_hasta IS NULL` — solo un valor vigente por tipo y modalidad

**Fase 1:** Solo se crean registros con `modalidad = 'particular'`.  
**Fase 2:** Se agregan registros para `domiciliaria` y `centro_medico`.

**RLS:** SELECT misma org · INSERT misma org · UPDATE nunca · DELETE nunca.

---

### Tabla: `zona_domiciliaria`

**Dominio:** Configuration (BC5) · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre` | texto | NOT NULL | |
| `descripcion` | texto | nullable | |
| `recargo` | decimal | NOT NULL | Monto o porcentaje del recargo de traslado |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Restricciones de unicidad:**
- `(organizacion_id, nombre)` UNIQUE PARCIAL donde `estado = 'activa'`

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca.

---

### Tabla: `cobro`

**Dominio:** Economic · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `monto` | decimal | NOT NULL | **Snapshot — inmutable desde creación** |
| `tipo_atencion_nombre_snapshot` | texto | NOT NULL | Snapshot del nombre al momento del registro |
| `modalidad` | texto | NOT NULL | Ver sección 3 |
| `recargo_zona_snapshot` | decimal | nullable | Snapshot si modalidad = domiciliaria |
| `valor_acordado_centro_snapshot` | decimal | nullable | Snapshot si modalidad = centro_medico |
| `concepto` | texto | NOT NULL | Descripción del trabajo que origina el cobro |
| `categoria_origen` | texto | NOT NULL | Ver sección 3 |
| `atencion_clinica_id` | UUID | nullable | FK → `atencion_clinica.id`. **Referencia opaca BC6 → BC2** |
| `zona_domiciliaria_id` | UUID | nullable | FK → `zona_domiciliaria.id`. **Columna Fase 2** |
| `relacion_centro_id` | UUID | nullable | FK → `relacion_centro.id`. **Columna Fase 2** |
| `estado_pago` | texto | NOT NULL | Ver sección 3 |
| `medio_pago` | texto | nullable | |
| `fecha_pago` | timestamp tz | nullable | |
| `motivo_anulacion` | texto | nullable | |
| `registrado_en` | timestamp tz | NOT NULL | |

**Sin `actualizado_en`**: el snapshot económico es inmutable. Los cambios de estado se registran en `transicion_pago`. El campo `estado_pago` es mutable pero rastreado.

**Nota sobre estado de liquidación:** El campo `estado de liquidación` no existe en esta tabla. Para determinar si un cobro fue incluido en una liquidación confirmada, se consulta `item_liquidacion` en BC7. Esta tabla no tiene referencia a `liquidacion`.

**RLS:**
- SELECT / INSERT: misma organización
- UPDATE: solo `estado_pago`, `medio_pago`, `fecha_pago`, `motivo_anulacion`. El snapshot económico (`monto`, los campos `_snapshot`, `modalidad`, `concepto`, `categoria_origen`) debe ser protegido contra UPDATE por RLS.
- DELETE: nunca

---

### Tabla: `transicion_pago`

**Dominio:** Economic · **Fase:** 1 · **Log inmutable**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `cobro_id` | UUID | NOT NULL | FK → `cobro.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `notas` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**RLS:** SELECT misma org · INSERT sistema · UPDATE nunca · DELETE nunca.

---

### Tabla: `relacion_centro`

**Dominio:** Commercial · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_centro` | texto | NOT NULL | Nombre del centro médico externo |
| `contacto_nombre` | texto | nullable | |
| `contacto_telefono` | texto | nullable | |
| `contacto_email` | texto | nullable | |
| `modalidad_relacion` | texto | NOT NULL | Descripción del tipo de vínculo |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca (desactivar).

---

### Tabla: `acuerdo_comercial`

**Dominio:** Commercial · **Fase:** 2 · **Versionado**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `relacion_centro_id` | UUID | NOT NULL | FK → `relacion_centro.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` (denormalizado para RLS) |
| `tipo_acuerdo` | texto | NOT NULL | Ver sección 3 |
| `parametro_porcentaje` | decimal | nullable | Usado cuando tipo = `porcentaje_comision` |
| `parametro_valor` | decimal | nullable | Usado cuando tipo = `valor_fijo_*` |
| `observaciones` | texto | nullable | |
| `vigente_desde` | fecha | NOT NULL | |
| `vigente_hasta` | fecha | nullable | NULL = acuerdo vigente actual |
| `registrado_por` | UUID | NOT NULL | FK → `profesional.id` |
| `creado_en` | timestamp tz | NOT NULL | |

**Sin `actualizado_en`**: los registros son inmutables. Un cambio de términos cierra el registro anterior y crea uno nuevo.

**Restricciones de unicidad:**
- `(relacion_centro_id)` UNIQUE PARCIAL donde `vigente_hasta IS NULL` — un solo acuerdo vigente por relación
- No solapamiento de vigencias para la misma `relacion_centro_id`: validación transaccional (no expresable como simple constraint de tabla)

**RLS:** SELECT misma org · INSERT misma org · UPDATE nunca · DELETE nunca.

---

### Tabla: `liquidacion`

**Dominio:** Commercial · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `relacion_centro_id` | UUID | NOT NULL | FK → `relacion_centro.id` |
| `acuerdo_comercial_id` | UUID | NOT NULL | FK → `acuerdo_comercial.id`. Snapshot del acuerdo aplicado. |
| `periodo_inicio` | fecha | NOT NULL | |
| `periodo_fin` | fecha | NOT NULL | |
| `monto_total` | decimal | NOT NULL | **Inmutable desde que estado = `confirmada`** |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `confirmada_por` | UUID | nullable | FK → `profesional.id` |
| `confirmada_en` | timestamp tz | nullable | |
| `notas` | texto | nullable | |
| `liquidacion_rectificada_id` | UUID | nullable | FK → `liquidacion.id` (self-reference para rectificaciones) |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo mientras borrador |

**Restricciones de unicidad:**
- `(relacion_centro_id, periodo_inicio, periodo_fin)` UNIQUE PARCIAL donde `estado = 'borrador'` — un solo borrador por centro y período
- `(relacion_centro_id, periodo_inicio, periodo_fin)` UNIQUE PARCIAL donde `estado = 'confirmada'` Y `liquidacion_rectificada_id IS NULL` — no dos liquidaciones confirmadas del mismo período salvo rectificación

**RLS:**
- SELECT / INSERT: misma organización
- UPDATE: solo mientras estado = `borrador`. Cuando estado = `confirmada`, `monto_total`, `acuerdo_comercial_id`, `periodo_inicio`, `periodo_fin` no deben ser actualizables.
- DELETE: nunca

---

### Tabla: `item_liquidacion`

**Dominio:** Commercial · **Fase:** 2 · **Referencia opaca BC7 → BC6**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `liquidacion_id` | UUID | NOT NULL | FK → `liquidacion.id` |
| `cobro_id` | UUID | NOT NULL | FK → `cobro.id`. **Referencia opaca: BC7 no accede al contenido clínico de BC2 a través de esta referencia.** |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `monto_snapshot` | decimal | NOT NULL | Snapshot del monto al incluir el cobro |
| `tipo_atencion_nombre_snapshot` | texto | NOT NULL | Snapshot del tipo al incluir |
| `modalidad` | texto | NOT NULL | |
| `fecha_hecho_economico` | fecha | NOT NULL | |

**Restricciones de unicidad:**
- `(liquidacion_id, cobro_id)` UNIQUE — un cobro no puede aparecer dos veces en la misma liquidación

**Inmutabilidad:** Una vez que la `liquidacion` asociada tiene estado = `confirmada`, ningún ítem puede modificarse ni eliminarse.

**RLS:**
- SELECT: misma organización
- INSERT: misma organización · solo cuando la liquidación asociada está en estado `borrador`
- UPDATE: nunca
- DELETE: nunca

---

### Tabla: `consentimiento`

**Dominio:** Documentary · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `atencion_clinica_id` | UUID | nullable | FK → `atencion_clinica.id` |
| `paciente_nombre_snapshot` | texto | NOT NULL | **Inmutable desde creación** |
| `paciente_rut_snapshot` | texto | nullable | **Inmutable desde creación** |
| `profesional_nombre_snapshot` | texto | NOT NULL | **Inmutable desde creación** |
| `plantilla_version` | texto | NOT NULL | Identificador de la versión de plantilla utilizada |
| `contenido_documento` | texto | NOT NULL | Texto completo del documento. **Inmutable desde que estado = `firmado`** |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `firma_paciente_storage_path` | texto | nullable | Ruta en `documentos-clinicos` para imagen de firma |
| `firma_paciente_en` | timestamp tz | nullable | **Inmutable desde que se registra** |
| `firma_profesional_storage_path` | texto | nullable | |
| `firma_profesional_en` | timestamp tz | nullable | **Inmutable desde que se registra** |
| `generado_en` | timestamp tz | nullable | Momento de generación formal |
| `motivo_revocacion` | texto | nullable | |
| `consentimiento_reemplazado_id` | UUID | nullable, UNIQUE | FK → `consentimiento.id`. UNIQUE enforce la relación 1:1 de reemplazo. |
| `documento_firmado_storage_path` | texto | nullable | Ruta al PDF firmado en `documentos-clinicos` |
| `creado_en` | timestamp tz | NOT NULL | |

**Restricciones de unicidad:**
- `consentimiento_reemplazado_id` UNIQUE — un consentimiento solo puede ser reemplazado una vez

**RLS:**
- SELECT / INSERT: misma organización
- UPDATE: solo campos de estado y firma. `contenido_documento`, `paciente_nombre_snapshot`, `profesional_nombre_snapshot`, `plantilla_version` no actualizables por RLS una vez estado ≠ `borrador`.
- DELETE: nunca

---

### Tabla: `informe_sesion`

**Dominio:** Documentary · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK → `paciente.id` |
| `profesional_id` | UUID | NOT NULL | FK → `profesional.id` |
| `atencion_clinica_id` | UUID | NOT NULL | FK → `atencion_clinica.id` |
| `paciente_nombre_snapshot` | texto | NOT NULL | **Inmutable desde generación** |
| `profesional_nombre_snapshot` | texto | NOT NULL | **Inmutable desde generación** |
| `fecha_atencion_snapshot` | timestamp tz | NOT NULL | **Inmutable desde generación** |
| `tratamiento_snapshot` | texto | nullable | **Inmutable desde generación** |
| `indicaciones_snapshot` | texto | nullable | **Inmutable desde generación** |
| `estado` | texto | NOT NULL | Ver sección 3 |
| `canal_entrega` | texto | nullable | Ver sección 3 |
| `generado_en` | timestamp tz | nullable | |
| `entregado_en` | timestamp tz | nullable | |
| `storage_path` | texto | nullable | Ruta al archivo generado en `documentos-clinicos` |
| `creado_en` | timestamp tz | NOT NULL | |

**RLS:**
- SELECT / INSERT: misma organización
- UPDATE: solo mientras estado = `borrador`. Los campos snapshot y el `storage_path` no deben ser actualizables una vez estado = `generado`.
- DELETE: nunca

---

## 5. Índices conceptuales

Esta sección lista los índices que deben crearse por su impacto directo en los patrones de consulta más frecuentes. Los índices se expresan conceptualmente; el SQL de creación pertenece a las migraciones.

### Índices de Fase 1

| Tabla | Columnas indexadas | Tipo | Propósito |
|---|---|---|---|
| `paciente` | `(organizacion_id, estado)` | estándar | Listado de pacientes activos de la organización |
| `paciente` | `(organizacion_id, rut)` WHERE `rut IS NOT NULL` | parcial | Búsqueda rápida por RUT |
| `historia_clinica` | `paciente_id` | cubierto por UNIQUE | Lookup 1:1 ya garantizado |
| `entrada_clinica` | `(historia_clinica_id, estado)` | estándar | Entradas activas de una historia |
| `atencion_clinica` | `(paciente_id, estado)` | estándar | Historial clínico del paciente |
| `atencion_clinica` | `(profesional_id, fecha_inicio)` | estándar | Agenda del profesional |
| `atencion_clinica` | `(organizacion_id, estado, fecha_inicio)` | estándar | Vista de atenciones por estado y fecha |
| `transicion_atencion` | `atencion_clinica_id` | estándar | Ciclo de vida de una atención |
| `cita` | `(profesional_id, inicio)` | estándar | Vista de calendario |
| `cita` | `(organizacion_id, inicio, estado)` | estándar | Agenda diaria de la organización |
| `cita` | `(paciente_id, estado)` | estándar | Próximas citas del paciente |
| `transicion_cita` | `cita_id` | estándar | Historial de estados de una cita |
| `seguimiento` | `(organizacion_id, estado, urgencia)` | estándar | Cola de seguimientos pendientes por prioridad |
| `seguimiento` | `(paciente_id, estado)` | estándar | Seguimientos activos de un paciente |
| `tipo_atencion` | `(organizacion_id, estado)` | estándar | Catálogo activo de la organización |
| `valor_arancel` | `(tipo_atencion_id, modalidad)` WHERE `vigente_hasta IS NULL` | parcial | Lookup del precio vigente |
| `cobro` | `(organizacion_id, estado_pago)` | estándar | Cobros pendientes de cobro |
| `cobro` | `(paciente_id)` | estándar | Historial de cobros del paciente |
| `transicion_pago` | `cobro_id` | estándar | Historial de pagos de un cobro |
| `evento_auditoria_minima` | `(organizacion_id, tipo_evento, ocurrido_en)` | estándar | Consultas de auditoría por tipo y período |
| `evento_auditoria_minima` | `entidad_id` | estándar | Trail de auditoría de una entidad específica |

### Índices adicionales de Fase 2

| Tabla | Columnas indexadas | Tipo | Propósito |
|---|---|---|---|
| `cobro` | `relacion_centro_id` | estándar | Cobros asociados a un centro |
| `relacion_centro` | `(organizacion_id, estado)` | estándar | Centros activos de la organización |
| `acuerdo_comercial` | `relacion_centro_id` WHERE `vigente_hasta IS NULL` | parcial | Acuerdo vigente de una relación |
| `liquidacion` | `(relacion_centro_id, estado)` | estándar | Liquidaciones de un centro |
| `item_liquidacion` | `liquidacion_id` | estándar | Ítems de una liquidación |
| `item_liquidacion` | `cobro_id` | estándar | Verificar si un cobro fue liquidado |
| `fotografia_clinica` | `(paciente_id, estado)` | estándar | Fotos activas de un paciente |
| `consentimiento` | `(paciente_id, estado)` | estándar | Consentimientos vigentes de un paciente |
| `informe_sesion` | `atencion_clinica_id` | estándar | Informe de una atención específica |

---

## 6. Modelo de acceso RLS

### 6.1 Función auxiliar central

Todas las políticas RLS dependen de una función que resuelve la organización del usuario autenticado:

```
funcion: obtener_mi_organizacion_id()
  entrada: ninguna (usa auth.uid() internamente)
  salida: UUID (organizacion_id del profesional autenticado)
  comportamiento: SELECT organizacion_id FROM profesional WHERE auth_user_id = auth.uid()
  nota: debe ser SECURITY DEFINER y marcada como STABLE para Supabase
```

Esta función es el único punto de acoplamiento entre `auth.users` y el modelo de datos de la aplicación.

### 6.2 Política de operaciones por tabla

La siguiente tabla resume las políticas RLS por tabla. "org" significa que la condición es `organizacion_id = obtener_mi_organizacion_id()`.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `organizacion_clinica` | solo propia | sistema | campos permitidos | nunca |
| `profesional` | misma org | sistema (trigger) | propio perfil | nunca |
| `evento_auditoria_minima` | misma org | sistema (atómico) | **nunca** | **nunca** |
| `paciente` | misma org | misma org | misma org · no archivado | nunca |
| `historia_clinica` | misma org | sistema (con paciente) | solo `resumen_general` | nunca |
| `entrada_clinica` | misma org | misma org | solo `estado` y `notas_adicionales` | nunca |
| `atencion_clinica` | misma org | misma org | misma org · solo si `registrada` | nunca |
| `transicion_atencion` | misma org | sistema (atómico) | **nunca** | **nunca** |
| `fotografia_clinica` | misma org | misma org | solo metadatos | nunca |
| `cita` | misma org | misma org | misma org · no terminal | nunca |
| `transicion_cita` | misma org | sistema (atómico) | **nunca** | **nunca** |
| `seguimiento` | misma org | misma org | misma org · no cerrado | nunca |
| `intento_contacto` | misma org | misma org | **nunca** | nunca |
| `tipo_atencion` | misma org | misma org | misma org | nunca |
| `valor_arancel` | misma org | misma org | **nunca** | nunca |
| `zona_domiciliaria` | misma org | misma org | misma org | nunca |
| `cobro` | misma org | misma org | solo `estado_pago` y campos de pago | nunca |
| `transicion_pago` | misma org | sistema | **nunca** | **nunca** |
| `relacion_centro` | misma org | misma org | misma org | nunca |
| `acuerdo_comercial` | misma org | misma org | **nunca** | nunca |
| `liquidacion` | misma org | misma org | misma org · solo `borrador` | nunca |
| `item_liquidacion` | misma org | sistema · solo `borrador` | **nunca** | nunca |
| `consentimiento` | misma org | misma org | solo campos de estado/firma | nunca |
| `informe_sesion` | misma org | misma org | solo mientras `borrador` | nunca |

### 6.3 Filas con protección de contenido dentro del UPDATE

Para algunas tablas, el UPDATE está permitido pero limitado a columnas específicas. Las siguientes columnas deben ser **explícitamente bloqueadas por la policy de UPDATE**:

| Tabla | Columnas que NO deben actualizarse por policy |
|---|---|
| `entrada_clinica` | `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en` |
| `atencion_clinica` (cerrada) | `tratamiento`, `hallazgos`, `notas_clinicas`, `indicaciones`, `fecha_cierre`, `paciente_id`, `profesional_id` |
| `cobro` | `monto`, `tipo_atencion_nombre_snapshot`, `modalidad`, `recargo_zona_snapshot`, `valor_acordado_centro_snapshot`, `concepto`, `categoria_origen`, `registrado_en` |
| `consentimiento` (firmado) | `contenido_documento`, `paciente_nombre_snapshot`, `profesional_nombre_snapshot`, `plantilla_version`, `firma_paciente_en`, `firma_profesional_en` |
| `liquidacion` (confirmada) | `monto_total`, `acuerdo_comercial_id`, `periodo_inicio`, `periodo_fin`, `relacion_centro_id` |

---

## 7. Integridad física de T00

### 7.1 Principio

Los cinco eventos T00 son la garantía mínima de trazabilidad del sistema. Deben existir en la base de datos desde el primer día de operación. Su ausencia es una violación de integridad de datos.

### 7.2 Operaciones T00 y sus escrituras atómicas

Cada operación T00 requiere múltiples INSERTs / UPDATEs en una sola transacción de base de datos. Si cualquier escritura falla, la transacción completa debe revertirse.

| Operación | Escrituras requeridas en la misma transacción |
|---|---|
| Crear paciente | INSERT `paciente` + INSERT `historia_clinica` + INSERT `evento_auditoria_minima` (tipo: `paciente_creado`) |
| Registrar atención | INSERT `atencion_clinica` + INSERT `transicion_atencion` (registrada) + INSERT `evento_auditoria_minima` (tipo: `atencion_registrada`) |
| Cerrar atención | UPDATE `atencion_clinica` SET estado='cerrada' + INSERT `transicion_atencion` (registrada → cerrada) + INSERT `evento_auditoria_minima` (tipo: `atencion_cerrada`) |
| Modificar cita | UPDATE `cita` SET estado=nuevo_estado + INSERT `transicion_cita` + INSERT `evento_auditoria_minima` (tipo: `cita_modificada`) |
| Agregar entrada clínica | INSERT `entrada_clinica` + INSERT `evento_auditoria_minima` (tipo: `historia_clinica_actualizada`) |

### 7.3 Mecanismo recomendado

La atomicidad de estas operaciones T00 debe implementarse mediante funciones de base de datos (RPCs Supabase) que envuelvan las escrituras en un bloque de transacción explícito. El cliente de la aplicación llama a la función RPC; no ejecuta los INSERTs por separado.

Esta decisión:
- Garantiza que nunca exista una atención sin su `transicion_atencion` correspondiente
- Garantiza que `evento_auditoria_minima` siempre esté completo
- Evita el riesgo de que un error de red entre llamadas deje el sistema en estado parcial

### 7.4 Relación con M21 Auditoría Operacional (Fase 3)

M21 es un módulo de consulta sobre los datos almacenados en `evento_auditoria_minima`. No escribe datos: los lee, filtra, cruza y exporta. Su ausencia en Fase 1 y Fase 2 no implica pérdida de datos: los registros T00 existen desde el primer día aunque no tengan interfaz de consulta.

---

## 8. Fases de migración

### Fase 1 — MVP clínico (15 tablas)

Orden estricto por dependencias de clave foránea:

| Paso | Tabla | Dependencias |
|---|---|---|
| 1 | `organizacion_clinica` | ninguna |
| 2 | `profesional` | `organizacion_clinica` · `auth.users` |
| 3 | `evento_auditoria_minima` | `organizacion_clinica` · `profesional` |
| 4 | `tipo_atencion` | `organizacion_clinica` |
| 5 | `valor_arancel` | `tipo_atencion` · `organizacion_clinica` · `profesional` |
| 6 | `paciente` | `organizacion_clinica` · `profesional` |
| 7 | `historia_clinica` | `paciente` · `organizacion_clinica` |
| 8 | `entrada_clinica` | `historia_clinica` · `organizacion_clinica` · `profesional` |
| 9 | `seguimiento` | `paciente` · `profesional` · `organizacion_clinica` |
| 10 | `cita` | `paciente` · `profesional` · `organizacion_clinica` · `tipo_atencion` · `seguimiento` |
| 11 | `transicion_cita` | `cita` · `organizacion_clinica` · `profesional` |
| 12 | `atencion_clinica` | `paciente` · `profesional` · `organizacion_clinica` · `tipo_atencion` · `cita` |
| 13 | `transicion_atencion` | `atencion_clinica` · `organizacion_clinica` · `profesional` |
| 14 | `cobro` | `paciente` · `profesional` · `organizacion_clinica` · `atencion_clinica` |
| 15 | `transicion_pago` | `cobro` · `organizacion_clinica` · `profesional` |

**Funciones / triggers de Fase 1:**
- Trigger `auth.users` → crear `profesional` automáticamente post-registro
- Trigger `actualizado_en` → para tablas mutables
- Función `obtener_mi_organizacion_id()` para RLS
- RPCs T00: crear paciente · registrar atención · cerrar atención · modificar cita · agregar entrada clínica
- Todas las políticas RLS de las 15 tablas

**Observación sobre `seguimiento` y `cita`:** La tabla `seguimiento` (paso 9) se crea antes de `cita` (paso 10) para que `cita` pueda referenciar `seguimiento_id`. Y `cita` se crea antes de `atencion_clinica` (paso 12) para que `atencion_clinica` pueda referenciar `cita_id`. A su vez, `seguimiento` referencia `cita` como opcional. Esta circularidad opcional entre `seguimiento` y `cita` se resuelve agregando la FK `seguimiento.cita_id` como columna nullable después de crear `cita` (ALTER TABLE en la misma migración de Fase 1, paso 10b).

---

### Fase 2 — Práctica individual completa (11 tablas + extensiones)

| Paso | Tabla / Extensión | Descripción |
|---|---|---|
| 2.1 | `zona_domiciliaria` | Tabla nueva |
| 2.2 | `relacion_centro` | Tabla nueva |
| 2.3 | `acuerdo_comercial` | Tabla nueva · depende de `relacion_centro` |
| 2.4 | `intento_contacto` | Tabla nueva · depende de `seguimiento` |
| 2.5 | `fotografia_clinica` | Tabla nueva + Storage bucket `fotografias-clinicas` |
| 2.6 | `consentimiento` | Tabla nueva + Storage bucket `documentos-clinicos` |
| 2.7 | `informe_sesion` | Tabla nueva · depende de `atencion_clinica` |
| 2.8 | `liquidacion` | Tabla nueva · depende de `relacion_centro` · `acuerdo_comercial` |
| 2.9 | `item_liquidacion` | Tabla nueva · depende de `liquidacion` · `cobro` |
| 2.10 | Extensiones de `paciente` | Agregar columna `relacion_centro_id` (nullable FK) |
| 2.11 | Extensiones de `atencion_clinica` | Agregar columnas `zona_domiciliaria_id` y `relacion_centro_id` (nullable FKs) |
| 2.12 | Extensiones de `cobro` | Agregar columnas `zona_domiciliaria_id` y `relacion_centro_id` (nullable FKs) |
| 2.13 | Nuevos registros `valor_arancel` | No es cambio de schema — se agregan registros para modalidades `domiciliaria` y `centro_medico` |

**Funciones / triggers de Fase 2:**
- Políticas RLS para las 9 tablas nuevas
- Políticas de Storage para ambos buckets
- RPCs adicionales: confirmar liquidación (atómica) · firmar consentimiento · generar informe

---

### Fase 3 — Centro multi-profesional / auditoría avanzada

| Componente | Descripción |
|---|---|
| M21 Auditoría Operacional | Vista o interfaz de consulta sobre `evento_auditoria_minima`. No crea tablas nuevas en Fase 3; puede agregar columnas o vistas materializadas si el volumen lo justifica. |
| Eventos extendidos de auditoría | Se pueden agregar nuevos `tipo_evento` a `evento_auditoria_minima` para cubrir eventos más allá de los 5 T00 originales. |
| Tabla `membresia_organizacion` | Si SaaS escala a profesional en múltiples organizaciones, se introduce una tabla que formaliza el ciclo de vida de la membresía (invitación, rol, estado) desacoplando la relación directa `profesional.organizacion_id`. |
| Roles y permisos | Modelo de permisos granular por rol (propietario, colaborador, administrador) sobre las políticas RLS existentes. |

---

## 9. Resumen consolidado

### Conteo de tablas por fase

| Fase | Tablas nuevas | Total acumulado |
|---|---|---|
| Fase 1 | 15 | 15 |
| Fase 2 | 9 tablas nuevas + 3 extensiones de columnas | 24 |
| Fase 3 | 0-1 (opcional: `membresia_organizacion`) | 24-25 |

### Distribución de tablas por dominio

| Dominio | Tablas | Fase |
|---|---|---|
| Identity | `organizacion_clinica` · `profesional` | 1 |
| Transversal | `evento_auditoria_minima` | 1 |
| Core Clinical | `paciente` · `historia_clinica` · `entrada_clinica` · `atencion_clinica` · `transicion_atencion` | 1 |
| Core Clinical | `fotografia_clinica` | 2 |
| Operational | `cita` · `transicion_cita` · `seguimiento` | 1 |
| Operational | `intento_contacto` | 2 |
| Configuration | `tipo_atencion` · `valor_arancel` | 1 |
| Configuration | `zona_domiciliaria` | 2 |
| Economic | `cobro` · `transicion_pago` | 1 |
| Commercial | `relacion_centro` · `acuerdo_comercial` · `liquidacion` · `item_liquidacion` | 2 |
| Documentary | `consentimiento` · `informe_sesion` | 2 |

### Buckets de Storage

| Bucket | Tablas asociadas | Fase |
|---|---|---|
| `fotografias-clinicas` | `fotografia_clinica` | 2 |
| `documentos-clinicos` | `consentimiento` · `informe_sesion` | 2 |

### Operaciones atómicas T00 requeridas (RPCs de Fase 1)

| RPC | Escrituras en la misma transacción |
|---|---|
| `crear_paciente` | `paciente` + `historia_clinica` + `evento_auditoria_minima` |
| `registrar_atencion` | `atencion_clinica` + `transicion_atencion` + `evento_auditoria_minima` |
| `cerrar_atencion` | UPDATE `atencion_clinica` + `transicion_atencion` + `evento_auditoria_minima` |
| `modificar_estado_cita` | UPDATE `cita` + `transicion_cita` + `evento_auditoria_minima` |
| `agregar_entrada_clinica` | `entrada_clinica` + `evento_auditoria_minima` |

---

*Este blueprint es el contrato técnico de diseño del schema de Agenda Podológica para Supabase. Todo SQL de migración, toda policy RLS y toda función de base de datos debe poder rastrear su origen a este documento. Las desviaciones requieren justificación explícita y actualización de este documento.*
