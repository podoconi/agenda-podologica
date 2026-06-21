# Supabase Schema Blueprint — Agenda Podológica

**Versión:** 1.1  
**Estado:** Revisado — incorpora hallazgos de QA_SUPABASE_SCHEMA_BLUEPRINT_v1.md  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuente canónica:** `RELATIONAL_DATA_ARCHITECTURE_v1.1.md`  
**Siguiente paso:** migraciones SQL por fase (pendiente de segunda auditoría)

---

## Cambios en esta versión

Esta versión corrige los tres hallazgos críticos y todos los hallazgos medios de `QA_SUPABASE_SCHEMA_BLUEPRINT_v1.md`. El modelo de datos, las 24 tablas y el faseo no cambian.

- **Regla transversal de integridad tenant (crítico 1):** Nueva sección 4. Toda FK debe apuntar a registros de la misma `organizacion_id`. Se define el mecanismo por tipo de relación: FK compuesta, trigger de validación o validación en RPC.
- **Mecanismos de inmutabilidad (crítico 2):** Nueva sección 5. Se elimina cualquier afirmación de que RLS bloquea columnas. Se definen los mecanismos reales: triggers `BEFORE UPDATE` anti-mutación, RPCs como único canal de escritura y privilegios por columna. Las menciones en el catálogo de tablas se actualizan para referenciar estos mecanismos.
- **Creación de `profesional` (crítico 3):** Sección 6.3 reescrita. Estrategia única: trigger de base de datos `AFTER INSERT ON auth.users`. Se elimina la mención de Edge Function como alternativa. Se describe el contrato de atomicidad real y el flujo de onboarding en dos pasos.
- **Fortalecimiento T00 (medio 2):** Sección 12 actualizada. `evento_auditoria_minima` solo puede escribirse desde las RPCs T00 (SECURITY DEFINER). Se agrega índice compuesto `(entidad_tipo, entidad_id)`.
- **Validación Storage (medio 6):** Sección 7 actualizada. Las operaciones de subida deben validar que el prefijo de ruta corresponda a la `organizacion_id` y entidad propietaria declaradas en la metadata.
- **Disciplina de faseo (medio 3):** Las columnas `relacion_centro_id` y `zona_domiciliaria_id` ya no aparecen en las definiciones de tablas de Fase 1. Se listan únicamente en la subsección "Extensiones de Fase 2" de cada tabla.
- **Regla de precedencia Fase 2 (medio 4):** Nueva sección 14.1. Define el rol de `valor_arancel`, `zona_domiciliaria.recargo` y `acuerdo_comercial` sin solapamiento de cobro.

---

## Propósito y alcance

Este documento transforma la Arquitectura de Datos Relacional Conceptual (v1.1) en especificaciones de implementación para Supabase / PostgreSQL. Define las tablas, columnas, claves, relaciones, índices, modelo de acceso RLS, mecanismos de inmutabilidad, integración con Supabase Auth, buckets de Storage y el orden de migración por fases.

No contiene SQL ejecutable. No contiene migraciones listas para correr. Los fragmentos de pseudocódigo en este documento son contratos conceptuales, no código listo para ejecutar. El texto que describe estructuras (`FK compuesta`, `trigger BEFORE UPDATE`, `SECURITY DEFINER`, `STABLE`) describe el mecanismo esperado, no la sintaxis exacta de la migración.

Toda migración futura debe rastrear cada decisión a este documento. Las desviaciones requieren justificación explícita y actualización de este documento antes de implementarse.

---

## Convenciones generales

### Esquema
Todas las tablas de la aplicación residen en el esquema `public`. Las tablas de Supabase Auth residen en el esquema `auth` y son administradas por Supabase; no se crean ni modifican manualmente.

### Nomenclatura
- Tablas: `snake_case`, singular, en español. Ejemplo: `atencion_clinica`.
- Columnas: `snake_case`, en español. Ejemplo: `fecha_inicio`.
- Claves foráneas simples: `{entidad_referenciada}_id`. Ejemplo: `organizacion_id`.
- Claves foráneas con múltiples referencias a la misma entidad: sufijo descriptivo. Ejemplo: `cita_anterior_id`.
- Columnas snapshot: sufijo `_snapshot`. Ejemplo: `tipo_atencion_nombre_snapshot`.

### Clave primaria
Toda tabla tiene una columna `id` de tipo UUID generado automáticamente al momento del INSERT. Inmutable, sin significado de negocio.

### Timestamps estándar
- `creado_en`: timestamp con zona horaria, NOT NULL, valor por defecto = momento del INSERT. Inmutable.
- `actualizado_en`: timestamp con zona horaria, nullable, actualizado automáticamente por trigger en cada UPDATE. Solo presente en tablas cuyos registros pueden modificarse.

Tablas de log inmutable no tienen `actualizado_en`.

### Comportamiento de FKs ante eliminación
Dado que la política del sistema prohíbe la eliminación física de registros, toda FK usa `RESTRICT`. Las referencias opcionales (nullable) a entidades de otros contextos usan `SET NULL` para evitar bloqueos ante cambios de estado en el referenciado. Las referencias cross-context opacas se rigen por la Regla Transversal de Integridad Tenant (sección 4).

---

## 4. Regla Transversal de Integridad Tenant

### 4.1 Principio

Toda FK de una fila con `organizacion_id = X` debe apuntar únicamente a registros que también tienen `organizacion_id = X`. El modelo RLS filtra visibilidad de filas pero no valida la consistencia entre organizaciones de una FK al momento del INSERT. Esta sección define el mecanismo que sí lo garantiza.

Las únicas excepciones son las referencias globales sin tenant: `profesional.auth_user_id → auth.users.id`.

### 4.2 Clasificación de relaciones por mecanismo

**Tipo A — FK compuesta (intra-dominio, alta frecuencia)**

Para relaciones entre tablas del mismo Bounded Context o dentro del mismo aggregate, se usa una clave foránea compuesta `(organizacion_id, {entidad}_id)`. Esto requiere un constraint UNIQUE en `(organizacion_id, id)` en la tabla referenciada y garantiza a nivel de base de datos que la FK no puede cruzar organizaciones.

| Tabla origen | FK simple (actual) | FK compuesta requerida |
|---|---|---|
| `historia_clinica` | `paciente_id` | `(organizacion_id, paciente_id)` → `paciente(organizacion_id, id)` |
| `entrada_clinica` | `historia_clinica_id` | `(organizacion_id, historia_clinica_id)` → `historia_clinica(organizacion_id, id)` |
| `atencion_clinica` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `transicion_atencion` | `atencion_clinica_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `cita` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `transicion_cita` | `cita_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `seguimiento` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `cobro` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `transicion_pago` | `cobro_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `fotografia_clinica` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `consentimiento` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `informe_sesion` | `paciente_id`, `profesional_id` | ambas compuestas con `organizacion_id` |
| `relacion_centro` | (ya tiene `organizacion_id` directo) | — |
| `acuerdo_comercial` | `relacion_centro_id` | `(organizacion_id, relacion_centro_id)` → `relacion_centro(organizacion_id, id)` |
| `liquidacion` | `relacion_centro_id` | `(organizacion_id, relacion_centro_id)` → `relacion_centro(organizacion_id, id)` |
| `item_liquidacion` | `liquidacion_id` | `(organizacion_id, liquidacion_id)` → `liquidacion(organizacion_id, id)` |

**Consecuencia:** Toda tabla referenciada como destino de una FK compuesta debe tener un constraint `UNIQUE (organizacion_id, id)`. Esto se declara en la migración de la tabla destino.

---

**Tipo B — Trigger de validación (cross-context, referencias opcionales)**

Para referencias entre Bounded Contexts distintos donde la FK es opcional y el mecanismo de FK compuesta no aplica directamente (porque la referencia puede ser null o porque el contexto de origen no es responsable de la organización del destino), se usa un trigger `BEFORE INSERT OR UPDATE` en la tabla origen que valida que el registro referenciado exista y tenga la misma `organizacion_id`.

| Tabla origen | Columna FK | Contexto cruzado |
|---|---|---|
| `cobro` | `atencion_clinica_id` | BC6 → BC2 (opaco) |
| `seguimiento` | `atencion_clinica_id` | BC4 → BC2 (opaco) |
| `cita` | `atencion_clinica_id` | BC3 → BC2 |
| `consentimiento` | `atencion_clinica_id` | BC8 → BC2 |
| `informe_sesion` | `atencion_clinica_id` | BC8 → BC2 |
| `item_liquidacion` | `cobro_id` | BC7 → BC6 (opaco) |

El trigger valida: cuando la columna FK no es NULL, el registro referenciado existe y su `organizacion_id` es igual al `organizacion_id` de la fila que se inserta o actualiza. Si no coincide, la operación es rechazada con error de integridad.

---

**Tipo C — Validación en RPC obligatoria (referencias polimórficas)**

Para referencias polimórficas donde no existe una tabla destino fija, la validación se realiza exclusivamente dentro de las RPCs T00.

| Tabla | Columnas | Mecanismo |
|---|---|---|
| `evento_auditoria_minima` | `entidad_tipo` + `entidad_id` | La RPC T00 valida antes del INSERT: (a) que `entidad_tipo` corresponde a la operación, (b) que existe un registro con ese `id` en la tabla indicada, (c) que ese registro tiene la misma `organizacion_id`. Ningún INSERT directo en esta tabla está permitido fuera de las RPCs T00. |

---

**Tipo D — Sin restricción tenant (referencias globales)**

| Tabla | Columna | Razón |
|---|---|---|
| `profesional` | `auth_user_id` | Referencia a `auth.users`, entidad global del sistema. No tiene `organizacion_id`. |

---

### 4.3 Tablas que requieren UNIQUE (organizacion_id, id)

Para habilitar FK compuestas (Tipo A), las siguientes tablas necesitan el constraint adicional `UNIQUE (organizacion_id, id)`:

`organizacion_clinica` · `profesional` · `paciente` · `historia_clinica` · `atencion_clinica` · `cita` · `cobro` · `seguimiento` · `relacion_centro` · `liquidacion`

Este constraint no duplica la PK; la complementa como punto de anclaje para FKs compuestas entrantes.

---

## 5. Mecanismos de inmutabilidad de columnas

RLS controla si una fila puede ser leída, insertada, actualizada o eliminada. **RLS no controla qué columnas específicas pueden cambiar dentro de un UPDATE**. Para proteger columnas históricas o snapshots se requieren mecanismos adicionales.

### 5.1 Trigger BEFORE UPDATE anti-mutación

Un trigger `BEFORE UPDATE` inspecciona las columnas protegidas y rechaza la operación si alguna fue modificada. Se define por tabla según las columnas que deben ser inmutables.

Patrón: si `OLD.columna_protegida != NEW.columna_protegida`, se eleva una excepción y el UPDATE completo revierte.

| Tabla | Condición de activación | Columnas protegidas por trigger |
|---|---|---|
| `atencion_clinica` | `OLD.estado = 'cerrada'` | `tratamiento`, `hallazgos`, `notas_clinicas`, `indicaciones`, `fecha_cierre`, `paciente_id`, `profesional_id`, `modalidad` |
| `cobro` | Siempre (snapshot inmutable desde creación) | `monto`, `tipo_atencion_nombre_snapshot`, `modalidad`, `recargo_zona_snapshot`, `valor_acordado_centro_snapshot`, `concepto`, `categoria_origen`, `registrado_en` |
| `consentimiento` | `OLD.estado IN ('firmado', 'revocado', 'reemplazado')` | `contenido_documento`, `paciente_nombre_snapshot`, `profesional_nombre_snapshot`, `plantilla_version`, `firma_paciente_en`, `firma_profesional_en` |
| `liquidacion` | `OLD.estado IN ('confirmada', 'pagada')` | `monto_total`, `acuerdo_comercial_id`, `periodo_inicio`, `periodo_fin`, `relacion_centro_id` |
| `entrada_clinica` | Siempre | `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en` |
| `valor_arancel` | Siempre | todas las columnas (no debe actualizarse nunca — crear nuevo registro) |
| `acuerdo_comercial` | Siempre | todas las columnas (no debe actualizarse nunca — crear nuevo registro) |

### 5.2 RPC como único canal de escritura (tablas append-only)

Las tablas de log son append-only: solo admiten INSERT, nunca UPDATE ni DELETE. El mecanismo de protección es doble:

- **RLS**: no concede permiso de UPDATE ni DELETE a ningún rol de aplicación.
- **Trigger BEFORE UPDATE/DELETE**: rechaza cualquier operación de modificación como defensa en profundidad, en caso de que los privilegios sean mal configurados.

Aplica a: `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`, `intento_contacto`.

### 5.3 RPCs controladas como único canal para transiciones de estado

Para entidades con inmutabilidad parcial (campo `estado` mutable pero contenido inmutable), la única vía de cambio de estado debe ser una RPC definida con `SECURITY DEFINER`. El rol de aplicación no recibe permiso de UPDATE directo sobre estas tablas; todo cambio pasa por la RPC.

| Tabla | RPC controlada | Qué puede cambiar vía RPC |
|---|---|---|
| `atencion_clinica` | `cerrar_atencion` | `estado`, `fecha_cierre` |
| `cobro` | `registrar_pago`, `anular_cobro` | `estado_pago`, `medio_pago`, `fecha_pago`, `motivo_anulacion` |
| `consentimiento` | `firmar_consentimiento`, `revocar_consentimiento`, `reemplazar_consentimiento` | `estado`, campos de firma, `motivo_revocacion`, `consentimiento_reemplazado_id` |
| `liquidacion` | `confirmar_liquidacion`, `registrar_pago_liquidacion` | `estado`, `confirmada_por`, `confirmada_en` |
| `paciente` | `archivar_paciente` | `estado = 'archivado'` |

---

## 6. Integración con Supabase Auth

### 6.1 Modelo de autenticación

Supabase gestiona la autenticación a través de `auth.users`. La aplicación no crea ni modifica esta tabla. Cada profesional tiene exactamente una entrada en `auth.users` y exactamente una entrada en la tabla `profesional` del esquema `public`.

El vínculo es `profesional.auth_user_id → auth.users(id)`, con constraint UNIQUE.

### 6.2 Función auxiliar central

```
funcion: obtener_mi_organizacion_id()
  entrada: ninguna (usa auth.uid() internamente)
  salida: UUID (organizacion_id del profesional autenticado)
  comportamiento: SELECT organizacion_id FROM profesional WHERE auth_user_id = auth.uid()
  propiedades: SECURITY DEFINER, STABLE
```

Esta función es el único punto de acoplamiento entre `auth.users` y el modelo de datos. Todas las policies RLS que necesitan el tenant del usuario la invocan. Es una función de lectura; no escribe datos.

### 6.3 Creación de `profesional` desde `auth.users`

**Estrategia elegida: trigger de base de datos.**

Se define un trigger `AFTER INSERT ON auth.users` que ejecuta una función en el esquema `public`. Este trigger corre dentro de la misma transacción PostgreSQL que el INSERT en `auth.users`:

- Si la función falla, el INSERT en `auth.users` revierte completo. El usuario no queda registrado en Auth.
- Si tiene éxito, ambas filas existen al mismo tiempo desde el primer commit.

Esta es la única vía de creación del registro `profesional`. No se usa Edge Function como mecanismo de creación principal, porque una Edge Function se ejecuta fuera de la transacción de base de datos y no puede garantizar atomicidad con `auth.users`. Las Edge Functions pueden usarse para notificaciones, webhooks o tareas secundarias post-creación, pero no para la creación del perfil.

**Contrato del trigger:**

El trigger lee `new.raw_user_meta_data` para obtener los datos del profesional provistos durante el flujo de registro:
- `organizacion_id`: UUID de la organización ya existente a la que pertenece el usuario
- `nombre_completo`: nombre del profesional
- `nombre_para_documentos`: nombre tal como aparece en documentos clínicos

**Implicación para el flujo de onboarding:**

El trigger requiere que `organizacion_clinica` exista antes del registro del primer usuario. El flujo de Fase 1 es:

1. Aprovisionamiento: se crea `organizacion_clinica` (vía operación administrativa o endpoint de provisioning con privilegios elevados)
2. Se genera un enlace de registro que incluye el `organizacion_id` como parámetro
3. El profesional completa el registro con email/contraseña; el sistema pasa `organizacion_id` en `raw_user_meta_data`
4. Supabase Auth inserta en `auth.users`; el trigger inserta en `profesional` en la misma transacción
5. El usuario queda activo con perfil completo

**Reconciliación:** Como defensa adicional, una tarea de reconciliación periódica verifica que todo `auth.users` activo tenga su `profesional` correspondiente. Dado el mecanismo de trigger, esta condición no debería violarse; la tarea existe para detectar fallas de configuración del trigger (activación accidental de modo bypass, migraciones incorrectas, etc.).

---

## 7. Storage Buckets

### Bucket: `fotografias-clinicas`

| Atributo | Valor |
|---|---|
| Visibilidad | Privado |
| Acceso | Solo usuarios autenticados de la misma organización |
| Patrón de ruta obligatorio | `{organizacion_id}/{paciente_id}/{fotografia_id}/{nombre_archivo}` |
| Mutabilidad | Objetos subidos son inmutables; no se sobrescriben |
| Eliminación | Prohibida en flujo normal |
| Fase | 2 |

**Validación de ruta:** Al insertar en `fotografia_clinica`, la RPC o trigger de INSERT debe verificar que `storage_path` comience con `{organizacion_id}/{paciente_id}/` donde `organizacion_id` y `paciente_id` son exactamente los valores de la fila que se registra. Si el prefijo no coincide, el INSERT es rechazado. Esto previene que una fila apunte al objeto de otra organización o paciente.

**Política de Storage (concepto):** La policy de `storage.objects` para este bucket debe verificar que el prefijo del path coincida con `obtener_mi_organizacion_id()`. Un usuario solo puede leer o subir objetos cuyo primer segmento de ruta sea su propia `organizacion_id`.

---

### Bucket: `documentos-clinicos`

| Atributo | Valor |
|---|---|
| Visibilidad | Privado |
| Acceso | Solo usuarios autenticados de la misma organización |
| Patrón de ruta obligatorio | `{organizacion_id}/{tipo_documento}/{record_id}/{nombre_archivo}` |
| Tipos de documento | `consentimientos/` · `informes-sesion/` |
| Mutabilidad | Objetos firmados o generados formalmente son inmutables |
| Eliminación | Prohibida en flujo normal |
| Fase | 2 |

**Validación de ruta:** Al insertar en `consentimiento` o en `informe_sesion`, la RPC debe verificar que `storage_path` / `documento_firmado_storage_path` comience con `{organizacion_id}/` donde `organizacion_id` es el valor de la fila. El segmento de `{tipo_documento}` debe coincidir con el tipo de entidad que se registra. Si el prefijo no coincide, el INSERT es rechazado.

**Política de Storage (concepto):** La policy de `storage.objects` para este bucket debe verificar que el primer segmento de ruta coincida con `obtener_mi_organizacion_id()`.

---

## 8. Estados válidos por entidad

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

## 9. Catálogo de tablas

Las definiciones de Fase 1 muestran únicamente las columnas que existen en la migración de Fase 1. Las columnas que se agregan en Fase 2 se listan en una subsección separada "Extensiones de Fase 2" de cada tabla, para claridad de la migración.

---

### Tabla: `organizacion_clinica`
**Dominio:** Identity · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `nombre_legal` | texto | NOT NULL | |
| `nombre_fantasia` | texto | nullable | |
| `identificacion_fiscal` | texto | nullable, UNIQUE global | |
| `email` | texto | nullable | |
| `telefono` | texto | nullable | |
| `direccion` | texto | nullable | |
| `zona_horaria` | texto | NOT NULL | Ej. `America/Santiago` |
| `duracion_cita_defecto_minutos` | entero | NOT NULL | Por defecto 60 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)` — requerido como ancla para FKs compuestas entrantes. En esta tabla, equivale a `UNIQUE (id)` ya que no tiene su propio `organizacion_id`; en la práctica, las FKs de otras tablas a esta entidad son simples.

**RLS:** SELECT solo propia org · UPDATE campos operativos · INSERT/DELETE solo sistema.

---

### Tabla: `profesional`
**Dominio:** Identity · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `auth_user_id` | UUID | NOT NULL, UNIQUE | FK → `auth.users(id)`. Tipo D (global). |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_completo` | texto | NOT NULL | |
| `email` | texto | NOT NULL, UNIQUE global | Espejo de `auth.users.email` |
| `nombre_para_documentos` | texto | NOT NULL | |
| `especialidad` | texto | nullable | |
| `numero_colegiado` | texto | nullable | |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)` — ancla para FKs compuestas Tipo A desde otras tablas.

**Creación:** Exclusivamente vía trigger `AFTER INSERT ON auth.users`. Ver sección 6.3.

**RLS:** SELECT misma org · UPDATE propio perfil · INSERT/DELETE sistema.

---

### Tabla: `evento_auditoria_minima`
**Dominio:** Transversal · **Fase:** 1 · **Log append-only · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `tipo_evento` | texto | NOT NULL | Ver sección 8 — solo 5 valores válidos |
| `entidad_tipo` | texto | NOT NULL | Nombre de la tabla afectada |
| `entidad_id` | UUID | NOT NULL | Referencia polimórfica — Tipo C |
| `estado_anterior` | texto | nullable | |
| `estado_nuevo` | texto | nullable | |
| `resumen_contextual` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Escritura exclusiva vía RPCs T00:** Esta tabla no puede ser objetivo de un INSERT directo desde el rol de la aplicación. El rol de aplicación no tiene permiso `INSERT` sobre esta tabla. Solo las RPCs T00 definidas con `SECURITY DEFINER` pueden escribir en ella. Las RPCs validan antes de cada INSERT: (a) que `tipo_evento` corresponde a la operación ejecutada, (b) que existe un registro con `entidad_id` en la tabla `entidad_tipo`, (c) que ese registro tiene la misma `organizacion_id` que la fila a insertar.

**Inmutabilidad:** RLS no concede UPDATE ni DELETE. Trigger `BEFORE UPDATE OR DELETE` rechaza cualquier intento como defensa en profundidad (sección 5.2).

**RLS:** SELECT misma org · INSERT solo via RPCs T00 (SECURITY DEFINER) · UPDATE nunca · DELETE nunca.

---

### Tabla: `paciente`
**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_completo` | texto | NOT NULL | |
| `rut` | texto | nullable | Unicidad parcial por organización |
| `fecha_nacimiento` | fecha | nullable | |
| `telefono_principal` | texto | nullable | |
| `telefono_alternativo` | texto | nullable | |
| `email` | texto | nullable | |
| `direccion` | texto | nullable | |
| `origen_categoria` | texto | nullable | `particular` · `centro_medico` · `administrado_tercero` |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `notas` | texto | nullable | |
| `creado_por` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)` — ancla para FKs compuestas.  
**Unicidad parcial:** `UNIQUE (organizacion_id, rut)` donde `rut IS NOT NULL`.

**Extensiones de Fase 2:**
- `relacion_centro_id` UUID nullable — FK compuesta Tipo A → `relacion_centro(organizacion_id, id)`. Se agrega en la migración de Fase 2 junto con la tabla `relacion_centro`.

**RLS:** SELECT / INSERT misma org · UPDATE misma org salvo estado = `archivado` · DELETE nunca.

---

### Tabla: `historia_clinica`
**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `paciente_id` | UUID | NOT NULL, UNIQUE | FK compuesta Tipo A → `paciente(organizacion_id, id)`. UNIQUE garantiza 1:1. |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `resumen_general` | texto | nullable | Único campo mutable |
| `creado_en` | timestamp tz | NOT NULL | |

**Creación atómica:** La RPC `crear_paciente` inserta en `paciente`, `historia_clinica` y `evento_auditoria_minima` en una sola transacción.

**RLS:** SELECT misma org · INSERT sistema (RPC `crear_paciente`) · UPDATE solo `resumen_general` · DELETE nunca.

---

### Tabla: `entrada_clinica`
**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `historia_clinica_id` | UUID | NOT NULL | FK compuesta Tipo A → `historia_clinica(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `tipo` | texto | NOT NULL | `patologia` · `medicamento` · `alergia` · `observacion` · `otro` |
| `descripcion` | texto | NOT NULL | Inmutable desde creación — trigger sección 5.1 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `notas_adicionales` | texto | nullable | |
| `registrado_por` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `registrado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo para cambios de estado |

**Inmutabilidad:** Trigger `BEFORE UPDATE` protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en` (sección 5.1).

**RLS:** SELECT / INSERT misma org · UPDATE solo `estado` y `notas_adicionales` · DELETE nunca.

---

### Tabla: `atencion_clinica`
**Dominio:** Core Clinical · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `tipo_atencion_id` | UUID | nullable | FK → `tipo_atencion.id` |
| `tipo_atencion_nombre_snapshot` | texto | nullable | Capturado al registrar o cerrar |
| `modalidad` | texto | NOT NULL | Ver sección 8 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `fecha_inicio` | timestamp tz | NOT NULL | |
| `fecha_cierre` | timestamp tz | nullable | Poblado por RPC `cerrar_atencion` |
| `tratamiento` | texto | nullable | Inmutable cuando estado = `cerrada` — trigger sección 5.1 |
| `hallazgos` | texto | nullable | Inmutable cuando estado = `cerrada` |
| `notas_clinicas` | texto | nullable | Inmutable cuando estado = `cerrada` |
| `indicaciones` | texto | nullable | Inmutable cuando estado = `cerrada` |
| `cita_id` | UUID | nullable | FK → `cita.id` (mismo contexto, puede ser Tipo A) |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo mientras estado = `registrada` |

**Constraint adicional:** `UNIQUE (organizacion_id, id)` — ancla para FKs compuestas.

**Inmutabilidad:** Trigger `BEFORE UPDATE` activo cuando `OLD.estado = 'cerrada'` protege columnas de contenido clínico (sección 5.1). La transición a `cerrada` ocurre exclusivamente via RPC `cerrar_atencion` (sección 5.3).

**Extensiones de Fase 2:**
- `zona_domiciliaria_id` UUID nullable — FK compuesta Tipo A → `zona_domiciliaria(organizacion_id, id)`
- `relacion_centro_id` UUID nullable — FK Tipo B trigger → `relacion_centro.id`

**RLS:** SELECT / INSERT misma org · UPDATE misma org solo mientras `registrada` (estado y contenido) · DELETE nunca.

---

### Tabla: `transicion_atencion`
**Dominio:** Core Clinical · **Fase:** 1 · **Log append-only · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `atencion_clinica_id` | UUID | NOT NULL | FK compuesta Tipo A → `atencion_clinica(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `motivo` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Sección 5.2. **RLS:** SELECT misma org · INSERT sistema (RPC atómica) · UPDATE nunca · DELETE nunca.

---

### Tabla: `fotografia_clinica`
**Dominio:** Core Clinical · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `atencion_clinica_id` | UUID | nullable | FK Tipo B trigger → `atencion_clinica.id` |
| `descripcion` | texto | NOT NULL | |
| `contexto` | texto | NOT NULL | Ver sección 8 |
| `storage_path` | texto | NOT NULL | Ruta en `fotografias-clinicas`. Validada al INSERT (sección 7). Inmutable. |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `capturado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo metadatos: `descripcion`, `estado` |

**RLS:** SELECT / INSERT misma org · UPDATE solo `descripcion` y `estado` · DELETE nunca.

---

### Tabla: `cita`
**Dominio:** Operational · **Fase:** 1 · **T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `tipo_atencion_id` | UUID | nullable | FK → `tipo_atencion.id` |
| `tipo_atencion_nombre_snapshot` | texto | nullable | |
| `inicio` | timestamp tz | NOT NULL | |
| `duracion_minutos` | entero | NOT NULL | |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `motivo_cancelacion` | texto | nullable | |
| `notas` | texto | nullable | |
| `cita_anterior_id` | UUID | nullable | FK self-reference → `cita.id` (misma org por RLS) |
| `seguimiento_id` | UUID | nullable | FK compuesta Tipo A → `seguimiento(organizacion_id, id)` |
| `atencion_clinica_id` | UUID | nullable | FK Tipo B trigger → `atencion_clinica.id` |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.

**RLS:** SELECT / INSERT / UPDATE misma org · UPDATE bloqueado cuando estado terminal (`atendida`, `cancelada`, `inasistida`) · DELETE nunca.

---

### Tabla: `transicion_cita`
**Dominio:** Operational · **Fase:** 1 · **Log append-only · T00**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `cita_id` | UUID | NOT NULL | FK compuesta Tipo A → `cita(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `motivo` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Sección 5.2. **RLS:** SELECT misma org · INSERT sistema (RPC atómica) · UPDATE nunca · DELETE nunca.

---

### Tabla: `seguimiento`
**Dominio:** Operational · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `tipo` | texto | NOT NULL | |
| `urgencia` | texto | NOT NULL | Ver sección 8 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `origen` | texto | NOT NULL | Ver sección 8 |
| `atencion_clinica_id` | UUID | nullable | FK Tipo B trigger → `atencion_clinica.id` (opaco BC4 → BC2) |
| `cita_id` | UUID | nullable | FK compuesta Tipo A → `cita(organizacion_id, id)` |
| `notas` | texto | nullable | |
| `fecha_limite` | timestamp tz | nullable | |
| `resuelto_en` | timestamp tz | nullable | |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.

**RLS:** SELECT / INSERT / UPDATE misma org · UPDATE bloqueado cuando estado = `completado` o `descartado` · DELETE nunca.

---

### Tabla: `intento_contacto`
**Dominio:** Operational · **Fase:** 2 · **Log append-only**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `seguimiento_id` | UUID | NOT NULL | FK compuesta Tipo A → `seguimiento(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `canal` | texto | NOT NULL | Ver sección 8 |
| `resultado` | texto | nullable | |
| `notas` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Sección 5.2. **RLS:** SELECT / INSERT misma org · UPDATE nunca · DELETE nunca.

---

### Tabla: `tipo_atencion`
**Dominio:** Configuration (BC5) · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre` | texto | NOT NULL | |
| `descripcion` | texto | nullable | |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Unicidad parcial:** `UNIQUE (organizacion_id, nombre)` donde `estado = 'activo'`.

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca.

---

### Tabla: `valor_arancel`
**Dominio:** Configuration (BC5) · **Fase:** 1 (modalidad `particular`) / 2 (resto)

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `tipo_atencion_id` | UUID | NOT NULL | FK → `tipo_atencion.id` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `modalidad` | texto | NOT NULL | Ver sección 8 |
| `valor` | decimal | NOT NULL | |
| `vigente_desde` | fecha | NOT NULL | |
| `vigente_hasta` | fecha | nullable | NULL = vigente actual |
| `configurado_por` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `creado_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Registros nunca se actualizan. Trigger `BEFORE UPDATE` rechaza cualquier UPDATE (sección 5.1). Un cambio de precio crea un nuevo registro y cierra el anterior (`vigente_hasta = hoy`).

**Unicidad parcial:** `UNIQUE (tipo_atencion_id, modalidad)` donde `vigente_hasta IS NULL`.

**Fase 1:** Solo se crean registros con `modalidad = 'particular'`. La restricción de unicidad parcial impide modalidades repetidas.

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
| `recargo` | decimal | NOT NULL | |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.  
**Unicidad parcial:** `UNIQUE (organizacion_id, nombre)` donde `estado = 'activa'`.

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca.

---

### Tabla: `cobro`
**Dominio:** Economic · **Fase:** 1

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `monto` | decimal | NOT NULL | **Snapshot — trigger inmutable sección 5.1** |
| `tipo_atencion_nombre_snapshot` | texto | NOT NULL | **Snapshot — trigger inmutable** |
| `modalidad` | texto | NOT NULL | **Snapshot — trigger inmutable** |
| `recargo_zona_snapshot` | decimal | nullable | **Snapshot** — ver sección 14.1 |
| `valor_acordado_centro_snapshot` | decimal | nullable | **Snapshot** — ver sección 14.1 |
| `concepto` | texto | NOT NULL | **Snapshot — trigger inmutable** |
| `categoria_origen` | texto | NOT NULL | **Snapshot — trigger inmutable** |
| `atencion_clinica_id` | UUID | nullable | FK Tipo B trigger → `atencion_clinica.id` (opaco BC6 → BC2) |
| `estado_pago` | texto | NOT NULL | Mutable — solo via RPC `registrar_pago` / `anular_cobro` |
| `medio_pago` | texto | nullable | |
| `fecha_pago` | timestamp tz | nullable | |
| `motivo_anulacion` | texto | nullable | |
| `registrado_en` | timestamp tz | NOT NULL | **Snapshot — trigger inmutable** |

**Sin `actualizado_en`**: el snapshot nunca cambia. Los cambios de estado se registran en `transicion_pago`.

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.

**Inmutabilidad:** Trigger `BEFORE UPDATE` protege todas las columnas snapshot (sección 5.1). Cambios de estado solo via RPCs controladas (sección 5.3).

**Extensiones de Fase 2:**
- `zona_domiciliaria_id` UUID nullable — FK compuesta Tipo A → `zona_domiciliaria(organizacion_id, id)`
- `relacion_centro_id` UUID nullable — FK Tipo B trigger → `relacion_centro.id`

**RLS:** SELECT / INSERT misma org · UPDATE solo via RPCs controladas · DELETE nunca.

---

### Tabla: `transicion_pago`
**Dominio:** Economic · **Fase:** 1 · **Log append-only**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `cobro_id` | UUID | NOT NULL | FK compuesta Tipo A → `cobro(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `estado_anterior` | texto | NOT NULL | |
| `estado_nuevo` | texto | NOT NULL | |
| `notas` | texto | nullable | |
| `ocurrido_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Sección 5.2. **RLS:** SELECT misma org · INSERT sistema · UPDATE nunca · DELETE nunca.

---

### Tabla: `relacion_centro`
**Dominio:** Commercial · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `nombre_centro` | texto | NOT NULL | |
| `contacto_nombre` | texto | nullable | |
| `contacto_telefono` | texto | nullable | |
| `contacto_email` | texto | nullable | |
| `modalidad_relacion` | texto | NOT NULL | |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | |

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.

**RLS:** SELECT / INSERT / UPDATE misma org · DELETE nunca.

---

### Tabla: `acuerdo_comercial`
**Dominio:** Commercial · **Fase:** 2 · **Versionado**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `relacion_centro_id` | UUID | NOT NULL | FK compuesta Tipo A → `relacion_centro(organizacion_id, id)` |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `tipo_acuerdo` | texto | NOT NULL | Ver sección 8 |
| `parametro_porcentaje` | decimal | nullable | |
| `parametro_valor` | decimal | nullable | |
| `observaciones` | texto | nullable | |
| `vigente_desde` | fecha | NOT NULL | |
| `vigente_hasta` | fecha | nullable | NULL = vigente actual |
| `registrado_por` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `creado_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Registros nunca se actualizan (trigger sección 5.1). Cambio de términos = nuevo registro + cierre del anterior.

**Unicidad parcial:** `UNIQUE (relacion_centro_id)` donde `vigente_hasta IS NULL`.

**RLS:** SELECT misma org · INSERT misma org · UPDATE nunca · DELETE nunca.

---

### Tabla: `liquidacion`
**Dominio:** Commercial · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `relacion_centro_id` | UUID | NOT NULL | FK compuesta Tipo A → `relacion_centro(organizacion_id, id)` |
| `acuerdo_comercial_id` | UUID | NOT NULL | FK → `acuerdo_comercial.id` (snapshot del acuerdo aplicado) |
| `periodo_inicio` | fecha | NOT NULL | |
| `periodo_fin` | fecha | NOT NULL | |
| `monto_total` | decimal | NOT NULL | Inmutable desde estado = `confirmada` — trigger sección 5.1 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `confirmada_por` | UUID | nullable | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `confirmada_en` | timestamp tz | nullable | |
| `notas` | texto | nullable | |
| `liquidacion_rectificada_id` | UUID | nullable | FK self-reference → `liquidacion.id` |
| `creado_en` | timestamp tz | NOT NULL | |
| `actualizado_en` | timestamp tz | nullable | Solo mientras borrador |

**Constraint adicional:** `UNIQUE (organizacion_id, id)`.

**Unicidad parcial:**
- `UNIQUE (relacion_centro_id, periodo_inicio, periodo_fin)` donde `estado = 'borrador'`
- `UNIQUE (relacion_centro_id, periodo_inicio, periodo_fin)` donde `estado = 'confirmada'` Y `liquidacion_rectificada_id IS NULL`

**Inmutabilidad:** Trigger `BEFORE UPDATE` activo cuando `OLD.estado IN ('confirmada', 'pagada')` (sección 5.1). Confirmación solo via RPC `confirmar_liquidacion` (sección 5.3).

**RLS:** SELECT / INSERT / UPDATE misma org · UPDATE bloqueado post-confirmación por trigger · DELETE nunca.

---

### Tabla: `item_liquidacion`
**Dominio:** Commercial · **Fase:** 2

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `liquidacion_id` | UUID | NOT NULL | FK compuesta Tipo A → `liquidacion(organizacion_id, id)` |
| `cobro_id` | UUID | NOT NULL | FK Tipo B trigger → `cobro.id` (BC7 → BC6, opaco) |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `monto_snapshot` | decimal | NOT NULL | |
| `tipo_atencion_nombre_snapshot` | texto | NOT NULL | |
| `modalidad` | texto | NOT NULL | |
| `fecha_hecho_economico` | fecha | NOT NULL | |

**Unicidad:** `UNIQUE (liquidacion_id, cobro_id)`.

**Inmutabilidad:** RLS no concede UPDATE. Trigger `BEFORE UPDATE OR DELETE` rechaza cualquier modificación (sección 5.2).

**RLS:** SELECT misma org · INSERT sistema (liquidación en borrador) · UPDATE nunca · DELETE nunca.

---

### Tabla: `consentimiento`
**Dominio:** Documentary · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `atencion_clinica_id` | UUID | nullable | FK Tipo B trigger → `atencion_clinica.id` |
| `paciente_nombre_snapshot` | texto | NOT NULL | Inmutable desde creación |
| `paciente_rut_snapshot` | texto | nullable | Inmutable desde creación |
| `profesional_nombre_snapshot` | texto | NOT NULL | Inmutable desde creación |
| `plantilla_version` | texto | NOT NULL | Inmutable desde creación |
| `contenido_documento` | texto | NOT NULL | Inmutable desde estado = `firmado` — trigger sección 5.1 |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `firma_paciente_storage_path` | texto | nullable | Ruta validada sección 7 |
| `firma_paciente_en` | timestamp tz | nullable | Inmutable desde que se registra |
| `firma_profesional_storage_path` | texto | nullable | |
| `firma_profesional_en` | timestamp tz | nullable | Inmutable desde que se registra |
| `generado_en` | timestamp tz | nullable | |
| `motivo_revocacion` | texto | nullable | |
| `consentimiento_reemplazado_id` | UUID | nullable, UNIQUE | FK self-reference. UNIQUE garantiza relación 1:1. |
| `documento_firmado_storage_path` | texto | nullable | Ruta validada sección 7 |
| `creado_en` | timestamp tz | NOT NULL | |

**Unicidad:** `consentimiento_reemplazado_id` UNIQUE.

**Inmutabilidad:** Trigger `BEFORE UPDATE` activo cuando `OLD.estado IN ('firmado', 'revocado', 'reemplazado')` protege `contenido_documento` y snapshots (sección 5.1). Cambios de estado solo via RPCs (sección 5.3).

**RLS:** SELECT / INSERT misma org · UPDATE solo estado y firmas via RPC · DELETE nunca.

---

### Tabla: `informe_sesion`
**Dominio:** Documentary · **Fase:** 2 · **Storage dependiente**

| Columna | Tipo | Restricción | Notas |
|---|---|---|---|
| `id` | UUID | PK, NOT NULL | |
| `organizacion_id` | UUID | NOT NULL | FK → `organizacion_clinica.id` |
| `paciente_id` | UUID | NOT NULL | FK compuesta Tipo A → `paciente(organizacion_id, id)` |
| `profesional_id` | UUID | NOT NULL | FK compuesta Tipo A → `profesional(organizacion_id, id)` |
| `atencion_clinica_id` | UUID | NOT NULL | FK Tipo B trigger → `atencion_clinica.id` |
| `paciente_nombre_snapshot` | texto | NOT NULL | Inmutable desde generación |
| `profesional_nombre_snapshot` | texto | NOT NULL | Inmutable desde generación |
| `fecha_atencion_snapshot` | timestamp tz | NOT NULL | Inmutable desde generación |
| `tratamiento_snapshot` | texto | nullable | Inmutable desde generación |
| `indicaciones_snapshot` | texto | nullable | Inmutable desde generación |
| `estado` | texto | NOT NULL | Ver sección 8 |
| `canal_entrega` | texto | nullable | Ver sección 8 |
| `generado_en` | timestamp tz | nullable | |
| `entregado_en` | timestamp tz | nullable | |
| `storage_path` | texto | nullable | Ruta validada sección 7 |
| `creado_en` | timestamp tz | NOT NULL | |

**Inmutabilidad:** Trigger `BEFORE UPDATE` activo cuando `OLD.estado IN ('generado', 'entregado')` protege snapshots y `storage_path`.

**RLS:** SELECT / INSERT misma org · UPDATE solo mientras `borrador` · DELETE nunca.

---

## 10. Índices conceptuales

### Índices de Fase 1

| Tabla | Columnas | Tipo | Propósito |
|---|---|---|---|
| `paciente` | `(organizacion_id, estado)` | estándar | Listado de pacientes activos |
| `paciente` | `(organizacion_id, rut)` WHERE `rut IS NOT NULL` | parcial | Búsqueda por RUT |
| `entrada_clinica` | `(historia_clinica_id, estado)` | estándar | Entradas activas de una historia |
| `atencion_clinica` | `(paciente_id, estado)` | estándar | Historial clínico del paciente |
| `atencion_clinica` | `(profesional_id, fecha_inicio)` | estándar | Agenda del profesional |
| `atencion_clinica` | `(organizacion_id, estado, fecha_inicio)` | estándar | Atenciones por estado y fecha |
| `transicion_atencion` | `atencion_clinica_id` | estándar | Ciclo de vida de una atención |
| `cita` | `(profesional_id, inicio)` | estándar | Vista de calendario |
| `cita` | `(organizacion_id, inicio, estado)` | estándar | Agenda diaria |
| `cita` | `(paciente_id, estado)` | estándar | Próximas citas del paciente |
| `transicion_cita` | `cita_id` | estándar | Historial de estados de una cita |
| `seguimiento` | `(organizacion_id, estado, urgencia)` | estándar | Cola de seguimientos por prioridad |
| `seguimiento` | `(paciente_id, estado)` | estándar | Seguimientos activos de un paciente |
| `tipo_atencion` | `(organizacion_id, estado)` | estándar | Catálogo activo |
| `valor_arancel` | `(tipo_atencion_id, modalidad)` WHERE `vigente_hasta IS NULL` | parcial | Precio vigente |
| `cobro` | `(organizacion_id, estado_pago)` | estándar | Cobros pendientes |
| `cobro` | `paciente_id` | estándar | Historial de cobros del paciente |
| `transicion_pago` | `cobro_id` | estándar | Historial de pagos |
| `evento_auditoria_minima` | `(organizacion_id, tipo_evento, ocurrido_en)` | estándar | Auditoría por tipo y período |
| `evento_auditoria_minima` | `(entidad_tipo, entidad_id)` | **compuesto** | Trail de auditoría de una entidad concreta. Evita colisiones semánticas entre entidades de distintas tablas con el mismo UUID. |

### Índices adicionales de Fase 2

| Tabla | Columnas | Tipo | Propósito |
|---|---|---|---|
| `cobro` | `relacion_centro_id` | estándar | Cobros por centro |
| `relacion_centro` | `(organizacion_id, estado)` | estándar | Centros activos |
| `acuerdo_comercial` | `relacion_centro_id` WHERE `vigente_hasta IS NULL` | parcial | Acuerdo vigente |
| `liquidacion` | `(relacion_centro_id, estado)` | estándar | Liquidaciones por centro |
| `item_liquidacion` | `liquidacion_id` | estándar | Ítems de una liquidación |
| `item_liquidacion` | `cobro_id` | estándar | Verificar si cobro fue liquidado |
| `fotografia_clinica` | `(paciente_id, estado)` | estándar | Fotos activas de un paciente |
| `consentimiento` | `(paciente_id, estado)` | estándar | Consentimientos vigentes |
| `informe_sesion` | `atencion_clinica_id` | estándar | Informe de una atención |

---

## 11. Modelo de acceso RLS

### 11.1 Función auxiliar central

```
funcion: obtener_mi_organizacion_id()
  → SELECT organizacion_id FROM profesional WHERE auth_user_id = auth.uid()
  propiedades: SECURITY DEFINER, STABLE
```

Esta función provee solo el filtro de organización del usuario autenticado. **No valida la consistencia de FKs entre organizaciones.** Para esa garantía, ver sección 4 (FK compuesta, trigger Tipo B, validación en RPC).

### 11.2 Operaciones por tabla

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `organizacion_clinica` | solo propia | sistema | campos operativos | nunca |
| `profesional` | misma org | trigger (Auth) | propio perfil | nunca |
| `evento_auditoria_minima` | misma org | solo RPCs T00 (SECURITY DEFINER) | **nunca** | **nunca** |
| `paciente` | misma org | misma org | misma org · no archivado | nunca |
| `historia_clinica` | misma org | sistema (RPC) | solo `resumen_general` | nunca |
| `entrada_clinica` | misma org | misma org | solo `estado` y `notas_adicionales` | nunca |
| `atencion_clinica` | misma org | misma org | misma org · solo mientras `registrada` | nunca |
| `transicion_atencion` | misma org | sistema (RPC atómica) | **nunca** | **nunca** |
| `fotografia_clinica` | misma org | misma org | solo metadatos | nunca |
| `cita` | misma org | misma org | misma org · no terminal | nunca |
| `transicion_cita` | misma org | sistema (RPC atómica) | **nunca** | **nunca** |
| `seguimiento` | misma org | misma org | misma org · no cerrado | nunca |
| `intento_contacto` | misma org | misma org | **nunca** | nunca |
| `tipo_atencion` | misma org | misma org | misma org | nunca |
| `valor_arancel` | misma org | misma org | **nunca** | nunca |
| `zona_domiciliaria` | misma org | misma org | misma org | nunca |
| `cobro` | misma org | misma org | solo via RPCs controladas | nunca |
| `transicion_pago` | misma org | sistema | **nunca** | **nunca** |
| `relacion_centro` | misma org | misma org | misma org | nunca |
| `acuerdo_comercial` | misma org | misma org | **nunca** | nunca |
| `liquidacion` | misma org | misma org | misma org · solo `borrador` (+ trigger) | nunca |
| `item_liquidacion` | misma org | sistema · solo `borrador` | **nunca** | nunca |
| `consentimiento` | misma org | misma org | solo via RPCs | nunca |
| `informe_sesion` | misma org | misma org | solo mientras `borrador` | nunca |

**Nota:** RLS protege la visibilidad de filas. La inmutabilidad de columnas dentro de un UPDATE permitido se garantiza mediante triggers `BEFORE UPDATE` (sección 5.1) y RPCs controladas (sección 5.3), no mediante RLS.

---

## 12. Integridad física de T00

### 12.1 Principio

Los cinco eventos T00 son la garantía mínima de trazabilidad desde Fase 1. `evento_auditoria_minima` es la única tabla que los consolida de forma transversal.

### 12.2 Restricciones de escritura

`evento_auditoria_minima` no puede ser objetivo de un INSERT directo desde el rol de la aplicación. El rol de aplicación no tiene permiso `INSERT` sobre esta tabla. Solo las RPCs T00, definidas como funciones con `SECURITY DEFINER`, pueden escribir en ella.

Cada RPC T00 valida antes del INSERT en `evento_auditoria_minima`:
- Que `tipo_evento` corresponde exactamente a la operación que la RPC ejecuta
- Que `entidad_tipo` es el nombre correcto de la tabla afectada
- Que existe un registro con `entidad_id` en esa tabla
- Que ese registro tiene la misma `organizacion_id` que la fila a insertar en auditoría

Si cualquiera de estas validaciones falla, la RPC revierte la transacción completa.

### 12.3 Operaciones T00 y escrituras atómicas

| RPC | Escrituras en la misma transacción |
|---|---|
| `crear_paciente` | INSERT `paciente` + INSERT `historia_clinica` + INSERT `evento_auditoria_minima` (`paciente_creado`) |
| `registrar_atencion` | INSERT `atencion_clinica` + INSERT `transicion_atencion` + INSERT `evento_auditoria_minima` (`atencion_registrada`) |
| `cerrar_atencion` | UPDATE `atencion_clinica` + INSERT `transicion_atencion` + INSERT `evento_auditoria_minima` (`atencion_cerrada`) |
| `modificar_estado_cita` | UPDATE `cita` + INSERT `transicion_cita` + INSERT `evento_auditoria_minima` (`cita_modificada`) |
| `agregar_entrada_clinica` | INSERT `entrada_clinica` + INSERT `evento_auditoria_minima` (`historia_clinica_actualizada`) |

### 12.4 Relación con M21 Auditoría Operacional (Fase 3)

M21 es un módulo de consulta que lee de `evento_auditoria_minima`. No escribe datos. Su ausencia en Fase 1 y 2 no implica pérdida de registros: los datos T00 existen desde el primer día de operación.

---

## 13. Fases de migración

### Fase 1 — 15 tablas (MVP clínico)

Las siguientes 15 tablas se crean en la migración de Fase 1. Las columnas de Fase 2 (`relacion_centro_id`, `zona_domiciliaria_id`) **no se incluyen físicamente en estas tablas** hasta la migración de Fase 2.

| Paso | Tabla | Dependencias de FK |
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
| 10b | ALTER: `seguimiento.cita_id` | agrega FK opcional a `cita` (misma migración) |
| 11 | `transicion_cita` | `cita` · `organizacion_clinica` · `profesional` |
| 12 | `atencion_clinica` | `paciente` · `profesional` · `organizacion_clinica` · `tipo_atencion` · `cita` |
| 13 | `transicion_atencion` | `atencion_clinica` · `organizacion_clinica` · `profesional` |
| 14 | `cobro` | `paciente` · `profesional` · `organizacion_clinica` · `atencion_clinica` |
| 15 | `transicion_pago` | `cobro` · `organizacion_clinica` · `profesional` |

**Artefactos de Fase 1 además de tablas:**
- Trigger `AFTER INSERT ON auth.users` para crear `profesional`
- Trigger `actualizado_en` para todas las tablas mutables
- Función `obtener_mi_organizacion_id()`
- Triggers `BEFORE UPDATE` de inmutabilidad (sección 5.1): `cobro`, `entrada_clinica`, `valor_arancel`
- Triggers `BEFORE UPDATE OR DELETE` append-only (sección 5.2): `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`
- Triggers Tipo B de validación cross-tenant (sección 4.2): `cobro.atencion_clinica_id`, `seguimiento.atencion_clinica_id`, `cita.atencion_clinica_id`
- Constraints `UNIQUE (organizacion_id, id)` en tablas ancla: `profesional`, `paciente`, `historia_clinica`, `atencion_clinica`, `cita`, `cobro`, `seguimiento`
- Todas las policies RLS de Fase 1
- RPCs T00: `crear_paciente`, `registrar_atencion`, `cerrar_atencion`, `modificar_estado_cita`, `agregar_entrada_clinica`
- RPCs controladas: `registrar_pago`, `anular_cobro`, `archivar_paciente`

---

### Fase 2 — Tablas y extensiones

| Paso | Tabla / Extensión | Notas |
|---|---|---|
| 2.1 | `zona_domiciliaria` | + `UNIQUE (organizacion_id, id)` |
| 2.2 | `relacion_centro` | + `UNIQUE (organizacion_id, id)` |
| 2.3 | `acuerdo_comercial` | Depende de `relacion_centro` |
| 2.4 | `intento_contacto` | Depende de `seguimiento` |
| 2.5 | `fotografia_clinica` | + Storage bucket `fotografias-clinicas` + validación de path |
| 2.6 | `consentimiento` | + Storage bucket `documentos-clinicos` + validación de path |
| 2.7 | `informe_sesion` | Depende de `atencion_clinica` |
| 2.8 | `liquidacion` | + `UNIQUE (organizacion_id, id)` |
| 2.9 | `item_liquidacion` | Depende de `liquidacion` · `cobro` |
| 2.10 | ALTER `paciente` | Agregar `relacion_centro_id` FK compuesta Tipo A |
| 2.11 | ALTER `atencion_clinica` | Agregar `zona_domiciliaria_id` FK Tipo A + `relacion_centro_id` FK Tipo B trigger |
| 2.12 | ALTER `cobro` | Agregar `zona_domiciliaria_id` FK Tipo A + `relacion_centro_id` FK Tipo B trigger |
| 2.13 | Triggers Tipo B nuevos | `atencion_clinica.relacion_centro_id`, `cobro.relacion_centro_id`, `informe_sesion.atencion_clinica_id`, `consentimiento.atencion_clinica_id`, `item_liquidacion.cobro_id` |
| 2.14 | Triggers inmutabilidad | `atencion_clinica` (cerrada), `consentimiento` (firmado), `liquidacion` (confirmada) |
| 2.15 | RPCs Fase 2 | `firmar_consentimiento`, `revocar_consentimiento`, `confirmar_liquidacion`, `registrar_pago_liquidacion` |

---

### Fase 3 — Auditoría avanzada y multi-profesional

| Componente | Descripción |
|---|---|
| M21 Auditoría Operacional | Interfaz de consulta sobre `evento_auditoria_minima`. Los datos ya existen desde Fase 1. Puede requerir vistas o índices adicionales. |
| Eventos extendidos de auditoría | Posibilidad de agregar `tipo_evento` adicionales a `evento_auditoria_minima` más allá de los 5 T00. |
| `membresia_organizacion` | Tabla de membresía con ciclo de vida propio si SaaS escala a profesional en múltiples organizaciones. |

---

## 14. Regla de precedencia para cálculo de cobro en Fase 2

### 14.1 Roles sin solapamiento

En Fase 2 coexisten tres conceptos monetarios distintos que contribuyen al cálculo del monto de un cobro. Para evitar doble cobro, cada uno tiene un rol único y no intercambiable:

| Entidad | Rol | A quién aplica |
|---|---|---|
| `valor_arancel` (modalidad) | **Precio base cobrado al paciente** por tipo de atención y modalidad | Todas las modalidades |
| `zona_domiciliaria.recargo` | **Cargo adicional de traslado** que se suma al precio base domiciliario | Solo modalidad `domiciliaria` |
| `acuerdo_comercial` | **Distribución del cobro** entre profesional y centro — define cuánto del cobro total corresponde al centro | Solo modalidad `centro_medico` |

### 14.2 Cálculo del monto por modalidad

**Modalidad `particular`:**
- `cobro.monto` = `valor_arancel.valor` vigente para (tipo_atencion, 'particular')
- No hay recargo de zona ni acuerdo de centro involucrado

**Modalidad `domiciliaria`:**
- `cobro.monto` = `valor_arancel.valor` (modalidad 'domiciliaria') + `zona_domiciliaria.recargo` (si hay zona asignada)
- `cobro.recargo_zona_snapshot` = el recargo de zona en el momento del cobro
- El snapshot `monto` captura el total ya sumado; no se recalcula posteriormente

**Modalidad `centro_medico`:**
- `cobro.monto` = precio cobrado al paciente (definido por `valor_arancel.valor` para modalidad 'centro_medico')
- `cobro.valor_acordado_centro_snapshot` = el parámetro del `acuerdo_comercial` vigente (porcentaje o valor fijo) en el momento del cobro
- Este snapshot representa la parte que corresponde al centro; lo usa `item_liquidacion` para la liquidación
- El `acuerdo_comercial` no modifica el precio cobrado al paciente; define solo la distribución interna

### 14.3 Invariante de snapshot

Una vez creado el `cobro`, todos los valores monetarios quedan capturados como snapshots independientes de cambios futuros en `valor_arancel`, `zona_domiciliaria` o `acuerdo_comercial`. El trigger de inmutabilidad (sección 5.1) garantiza que estos snapshots no puedan modificarse.

---

## 15. Resumen consolidado

### Tablas por fase

| Fase | Tablas nuevas | Total |
|---|---|---|
| 1 | 15 | 15 |
| 2 | 9 tablas + 3 extensiones ALTER | 24 |
| 3 | 0-1 (`membresia_organizacion` opcional) | 24-25 |

### Constraints UNIQUE (organizacion_id, id) requeridos

Necesarias en: `organizacion_clinica` · `profesional` · `paciente` · `historia_clinica` · `atencion_clinica` · `cita` · `cobro` · `seguimiento` · `relacion_centro` · `liquidacion` · `zona_domiciliaria`

### Triggers requeridos por tipo

| Tipo | Tablas |
|---|---|
| `AFTER INSERT ON auth.users` (creación profesional) | `auth.users` → `profesional` |
| `actualizado_en` (auto-timestamp) | Todas las tablas mutables |
| `BEFORE UPDATE` anti-mutación parcial | `cobro`, `atencion_clinica`, `entrada_clinica`, `valor_arancel`, `acuerdo_comercial`, `consentimiento`, `liquidacion`, `informe_sesion` |
| `BEFORE UPDATE OR DELETE` append-only | `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`, `intento_contacto` |
| `BEFORE INSERT OR UPDATE` validación cross-tenant Tipo B | `cobro.atencion_clinica_id`, `seguimiento.atencion_clinica_id`, `cita.atencion_clinica_id`, `item_liquidacion.cobro_id`, `atencion_clinica.relacion_centro_id`, `consentimiento.atencion_clinica_id`, `informe_sesion.atencion_clinica_id` |
| Validación `storage_path` | INSERT en `fotografia_clinica`, `consentimiento`, `informe_sesion` |

---

## Changelog de correcciones QA

| Hallazgo QA | Tipo | Corrección aplicada en v1.1 |
|---|---|---|
| RLS no impide referencias cruzadas entre organizaciones | Crítico 1 | Sección 4 nueva: regla transversal de integridad tenant. FK compuesta (Tipo A) para relaciones intra-dominio; trigger de validación (Tipo B) para referencias cross-context; validación en RPC (Tipo C) para referencias polimórficas. |
| RLS no protege columnas inmutables | Crítico 2 | Sección 5 nueva: mecanismos de inmutabilidad. Triggers `BEFORE UPDATE` anti-mutación por tabla y condición. RPCs controladas como único canal para transiciones de estado. Eliminada toda mención de "bloqueado por RLS" para columnas específicas. |
| Ambigüedad en creación de `profesional` | Crítico 3 | Sección 6.3 reescrita. Estrategia única: trigger de base de datos `AFTER INSERT ON auth.users`. Se elimina la mención de Edge Function como alternativa. Se describe el contrato de atomicidad real y el flujo de onboarding en dos pasos. Se agrega tarea de reconciliación como defensa adicional. |
| `obtener_mi_organizacion_id()` insuficiente para validar FKs | Medio 1 | Resuelto por sección 4. La función sigue siendo el helper central de RLS; la consistencia de FKs se garantiza por mecanismos distintos documentados en sección 4. |
| Referencia polimórfica en `evento_auditoria_minima` | Medio 2 | Sección 12 actualizada. La tabla solo puede ser escrita por RPCs T00 (SECURITY DEFINER). Cada RPC valida `entidad_tipo`, `entidad_id` y `organizacion_id` antes del INSERT. |
| Columnas Fase 2 mezcladas en tablas Fase 1 | Medio 3 | Las definiciones de tablas en sección 9 ahora muestran solo columnas Fase 1. Las columnas `relacion_centro_id` y `zona_domiciliaria_id` aparecen únicamente en la subsección "Extensiones de Fase 2" de cada tabla. |
| Riesgo de doble cobro entre valor_arancel, zona y acuerdo | Medio 4 | Sección 14 nueva. Roles sin solapamiento definidos. Regla de cálculo por modalidad. Invariante de snapshot. |
| Índice compuesto faltante para auditoría polimórfica | Medio 5 | Índice `(entidad_tipo, entidad_id)` agregado en sección 10. |
| Validación de `storage_path` contra organización | Medio 6 | Sección 7 actualizada con regla de validación de prefijo de ruta en INSERT. Sección 9 referencia la validación en cada tabla con Storage. |

---

*Este blueprint es el contrato técnico de diseño del schema de Agenda Podológica para Supabase. Todo SQL de migración, toda policy RLS y toda función de base de datos debe poder rastrear su origen a este documento. Las desviaciones requieren justificación explícita y actualización de este documento.*
