# Supabase SQL Phase 1 Blueprint — Agenda Podologica

**Version:** 1.0
**Estado:** Borrador para revision
**Fecha:** Junio 2026
**Autor:** Roberto Rojas + Claude
**Fuente canonica:** `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`
**QA de entrada:** `QA_SUPABASE_SCHEMA_BLUEPRINT_v1_2.md` — aprobado sin hallazgos criticos
**Siguiente paso:** Revision → aprobacion → creacion de archivos `.sql` de migracion

---

## Resumen ejecutivo

Este documento traduce el blueprint conceptual v1.2 en un plan SQL ejecutable para Fase 1 de Agenda Podologica. Cubre las 15 tablas del MVP clinico, organizadas en 11 archivos de migracion granulares y auditables.

**Alcance Fase 1:**
- 15 tablas (Identity, Audit, Clinical, Operational, Configuration, Economic)
- 8 tablas ancla con `UNIQUE (organizacion_id, id)`
- 20+ FK compuestas Tipo A
- 3 triggers Tipo B diferidos
- 4 triggers append-only
- 3 triggers de inmutabilidad parcial
- 1 trigger de inmutabilidad total con excepcion controlada (`valor_arancel`)
- 1 funcion auxiliar central (`obtener_mi_organizacion_id`)
- 1 trigger `auth.users` → `profesional`
- 5 RPCs T00 (atomicas con auditoria)
- 4 RPCs controladas
- Policies RLS completas para las 15 tablas
- Suite de QA con pruebas positivas, negativas y cross-tenant

**Fuera de alcance explicito:**
- Tablas Fase 2: `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, `fotografia_clinica`, `consentimiento`, `informe_sesion`, `intento_contacto`
- Columnas Fase 2: `relacion_centro_id`, `zona_domiciliaria_id` en tablas Fase 1
- Storage buckets
- SQL ejecutado en Supabase

---

## Tabla de migraciones propuestas

| # | Archivo | Contenido | Dependencias |
|---|---------|-----------|--------------|
| 01 | `01_extensions_and_helpers.sql` | Extensiones PostgreSQL, funcion `obtener_mi_organizacion_id()`, funcion helper `set_updated_at()` | Ninguna |
| 02 | `02_identity_and_auth.sql` | `organizacion_clinica`, `profesional`, trigger `auth.users` → `profesional` | 01 |
| 03 | `03_audit_and_catalogs.sql` | `evento_auditoria_minima`, `tipo_atencion`, `valor_arancel` | 02 |
| 04 | `04_patients_and_clinical_history.sql` | `paciente`, `historia_clinica`, `entrada_clinica` | 02, 03 |
| 05 | `05_schedule_and_followups.sql` | `seguimiento`, `cita`, `transicion_cita`, ALTER `seguimiento.cita_id` | 02, 03, 04 |
| 06 | `06_clinical_care.sql` | `atencion_clinica`, `transicion_atencion` | 02, 03, 04, 05 |
| 07 | `07_billing.sql` | `cobro`, `transicion_pago` | 02, 04, 06 |
| 08 | `08_triggers_and_guards.sql` | Triggers `updated_at`, append-only, inmutabilidad, Tipo B diferidos | 02-07 |
| 09 | `09_rls_policies.sql` | Todas las policies RLS de Fase 1 | 01-08 |
| 10 | `10_rpc_phase1.sql` | RPCs T00 + RPCs controladas | 01-09 |
| 11 | `11_qa_phase1.sql` | Tests de validacion en transaccion con ROLLBACK | 01-10 |

**Principio de orden:** Cada archivo puede ejecutarse solo si los anteriores ya se aplicaron. No hay dependencias circulares. No hay estados intermedios peligrosos dentro de un archivo individual.

---

## Migracion 01 — Extensiones y helpers

### Extensiones

```sql
-- Requerida para generacion de UUIDs como PK
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Requerida para indices de texto parcial (busquedas futuras)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
```

**Nota:** `uuid-ossp` ya viene habilitada por defecto en Supabase. Se incluye el `IF NOT EXISTS` como defensa idem-potente. `pg_trgm` se incluye anticipando indices de busqueda por nombre en Fase 1.

### Funcion: `obtener_mi_organizacion_id()`

```sql
CREATE OR REPLACE FUNCTION obtener_mi_organizacion_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organizacion_id
  FROM profesional
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$;
```

**Contrato:**
- Entrada: ninguna (usa `auth.uid()` internamente)
- Salida: UUID de la `organizacion_id` del profesional autenticado
- Retorna NULL si no hay sesion o si el profesional no existe
- `SECURITY DEFINER`: se ejecuta con privilegios del owner, no del caller
- `STABLE`: PostgreSQL puede cachear el resultado dentro de una transaccion
- `SET search_path = public`: previene ataques de path injection

**Riesgo operacional:** Esta funcion depende de que la tabla `profesional` exista. Se declara en migracion 01 pero la tabla se crea en migracion 02. Esto requiere que la funcion se cree con `CREATE OR REPLACE` y que no se invoque hasta despues de migracion 02. Alternativa: mover la declaracion al final de migracion 02. Se recomienda evaluar en dry-run.

### Funcion helper: `set_updated_at()`

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$;
```

**Proposito:** Trigger generico reutilizable que actualiza `actualizado_en` en cada UPDATE. Se asigna a todas las tablas mutables en migracion 08.

---

## Migracion 02 — Identity y Auth

### Tabla: `organizacion_clinica`

```sql
CREATE TABLE organizacion_clinica (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre_legal    TEXT NOT NULL,
  nombre_fantasia TEXT,
  identificacion_fiscal TEXT UNIQUE,
  email           TEXT,
  telefono        TEXT,
  direccion       TEXT,
  zona_horaria    TEXT NOT NULL DEFAULT 'America/Santiago',
  duracion_cita_defecto_minutos INTEGER NOT NULL DEFAULT 60,
  estado          TEXT NOT NULL DEFAULT 'activa'
                  CHECK (estado IN ('activa', 'suspendida', 'cerrada')),
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ
);
```

**Sin `UNIQUE (organizacion_id, id)`:** Esta tabla es la raiz tenant. No tiene `organizacion_id` propio.

### Tabla: `profesional`

```sql
CREATE TABLE profesional (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id          UUID NOT NULL UNIQUE
                        REFERENCES auth.users(id) ON DELETE RESTRICT,
  organizacion_id       UUID NOT NULL
                        REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo       TEXT NOT NULL,
  email                 TEXT NOT NULL UNIQUE,
  nombre_para_documentos TEXT NOT NULL,
  especialidad          TEXT,
  numero_colegiado      TEXT,
  estado                TEXT NOT NULL DEFAULT 'activo'
                        CHECK (estado IN ('activo', 'suspendido', 'desactivado')),
  creado_en             TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en        TIMESTAMPTZ,

  UNIQUE (organizacion_id, id)
);
```

**FK Tipo D:** `auth_user_id` → `auth.users(id)` es la unica referencia global sin tenant.
**Ancla:** `UNIQUE (organizacion_id, id)` habilita FK compuestas entrantes.

### Trigger: `auth.users` → `profesional`

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profesional (
    auth_user_id,
    organizacion_id,
    nombre_completo,
    email,
    nombre_para_documentos
  ) VALUES (
    NEW.id,
    (NEW.raw_user_meta_data->>'organizacion_id')::UUID,
    NEW.raw_user_meta_data->>'nombre_completo',
    NEW.email,
    NEW.raw_user_meta_data->>'nombre_para_documentos'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

**Contrato del trigger:**
- Lee `raw_user_meta_data` para `organizacion_id`, `nombre_completo`, `nombre_para_documentos`
- Lee `NEW.email` para el campo `email` del profesional
- Si falla (organizacion_id invalido, datos faltantes), el INSERT en `auth.users` revierte completo
- Es la unica via de creacion de `profesional`
- `SECURITY DEFINER`: necesario para INSERT en `public.profesional` desde contexto `auth`
- `SET search_path = public`: previene ataques de search_path

**Prerequisito de onboarding:** `organizacion_clinica` debe existir antes del registro del primer usuario. El flujo pasa `organizacion_id` via `raw_user_meta_data` al registrar.

---

## Migracion 03 — Auditoria y catalogos

### Tabla: `evento_auditoria_minima`

```sql
CREATE TABLE evento_auditoria_minima (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id   UUID NOT NULL
                    REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id    UUID NOT NULL,
  tipo_evento       TEXT NOT NULL
                    CHECK (tipo_evento IN (
                      'paciente_creado',
                      'atencion_registrada',
                      'atencion_cerrada',
                      'cita_modificada',
                      'historia_clinica_actualizada'
                    )),
  entidad_tipo      TEXT NOT NULL,
  entidad_id        UUID NOT NULL,
  estado_anterior   TEXT,
  estado_nuevo      TEXT,
  resumen_contextual TEXT,
  ocurrido_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Append-only:** Sin `actualizado_en`. No admite UPDATE ni DELETE.
**Referencia polimorfica (Tipo C):** `entidad_tipo` + `entidad_id` se validan exclusivamente dentro de las RPCs T00.
**Sin INSERT directo:** El rol de aplicacion no tendra permiso INSERT. Solo RPCs `SECURITY DEFINER`.

### Tabla: `tipo_atencion`

```sql
CREATE TABLE tipo_atencion (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id UUID NOT NULL
                  REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre          TEXT NOT NULL,
  descripcion     TEXT,
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo', 'inactivo')),
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ,

  UNIQUE (organizacion_id, id)
);

-- Unicidad parcial: no puede haber dos tipos activos con el mismo nombre en la misma org
CREATE UNIQUE INDEX uq_tipo_atencion_nombre_activo
  ON tipo_atencion (organizacion_id, nombre)
  WHERE estado = 'activo';
```

### Tabla: `valor_arancel`

```sql
CREATE TABLE valor_arancel (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo_atencion_id UUID NOT NULL,
  organizacion_id  UUID NOT NULL
                   REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  modalidad        TEXT NOT NULL
                   CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  valor            DECIMAL NOT NULL CHECK (valor >= 0),
  vigente_desde    DATE NOT NULL,
  vigente_hasta    DATE,
  configurado_por  UUID NOT NULL,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, configurado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

-- Solo un arancel vigente por combinacion tipo+org+modalidad
CREATE UNIQUE INDEX uq_valor_arancel_vigente
  ON valor_arancel (tipo_atencion_id, organizacion_id, modalidad)
  WHERE vigente_hasta IS NULL;
```

**Sin `actualizado_en`:** El registro es inmutable salvo `vigente_hasta` (transicion controlada por RPC).
**Fase 1:** Solo se permiten registros con `modalidad = 'particular'`. La restriccion se aplica a nivel de RPC/aplicacion, no de CHECK, para evitar tener que alterar el CHECK en Fase 2.
**Inmutabilidad:** Trigger en migracion 08 protege todas las columnas. `vigente_hasta` solo acepta transicion `NULL → fecha` via RPC `cerrar_arancel`.

---

## Migracion 04 — Pacientes e historia clinica

### Tabla: `paciente`

```sql
CREATE TABLE paciente (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id UUID NOT NULL
                  REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo TEXT NOT NULL,
  rut             TEXT,
  fecha_nacimiento DATE,
  telefono_principal TEXT,
  telefono_alternativo TEXT,
  email           TEXT,
  direccion       TEXT,
  origen_categoria TEXT
                  CHECK (origen_categoria IS NULL OR
                         origen_categoria IN ('particular', 'centro_medico', 'administrado_tercero')),
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo', 'en_seguimiento', 'inactivo', 'archivado')),
  notas           TEXT,
  creado_por      UUID NOT NULL,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, creado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

-- Unicidad parcial: un RUT solo puede existir una vez por organizacion (cuando no es NULL)
CREATE UNIQUE INDEX uq_paciente_rut_org
  ON paciente (organizacion_id, rut)
  WHERE rut IS NOT NULL;
```

### Tabla: `historia_clinica`

```sql
CREATE TABLE historia_clinica (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  paciente_id     UUID NOT NULL UNIQUE,
  organizacion_id UUID NOT NULL
                  REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  resumen_general TEXT,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT
);
```

**Relacion 1:1:** `paciente_id UNIQUE` garantiza que cada paciente tiene exactamente una historia clinica.
**Sin `actualizado_en`:** Solo `resumen_general` es mutable; la tabla no necesita tracking temporal de cambios.

### Tabla: `entrada_clinica`

```sql
CREATE TABLE entrada_clinica (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  historia_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  tipo                TEXT NOT NULL
                      CHECK (tipo IN ('patologia', 'medicamento', 'alergia', 'observacion', 'otro')),
  descripcion         TEXT NOT NULL,
  estado              TEXT NOT NULL DEFAULT 'activo'
                      CHECK (estado IN ('activo', 'resuelto', 'inactivo')),
  notas_adicionales   TEXT,
  registrado_por      UUID NOT NULL,
  registrado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en      TIMESTAMPTZ,

  FOREIGN KEY (organizacion_id, historia_clinica_id)
    REFERENCES historia_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, registrado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Inmutabilidad parcial:** Trigger en migracion 08 protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en`. Solo `estado` y `notas_adicionales` son mutables.

---

## Migracion 05 — Agenda y seguimientos

### Tabla: `seguimiento`

```sql
CREATE TABLE seguimiento (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id     UUID NOT NULL
                      REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id         UUID NOT NULL,
  profesional_id      UUID NOT NULL,
  tipo                TEXT NOT NULL,
  urgencia            TEXT NOT NULL DEFAULT 'normal'
                      CHECK (urgencia IN ('normal', 'prioritario', 'urgente')),
  estado              TEXT NOT NULL DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente', 'contactado', 'agendado',
                                        'completado', 'vencido', 'descartado')),
  origen              TEXT NOT NULL DEFAULT 'manual'
                      CHECK (origen IN ('manual', 'automatico_cierre_atencion')),
  atencion_clinica_id UUID,
  cita_id             UUID,
  notas               TEXT,
  fecha_limite        TIMESTAMPTZ,
  resuelto_en         TIMESTAMPTZ,
  creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en      TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Nota:** `seguimiento.cita_id` se agrega como FK compuesta en esta misma migracion, despues de crear `cita`. `seguimiento.atencion_clinica_id` recibe su trigger Tipo B en migracion 08 (paso 12b del blueprint), porque `atencion_clinica` se crea en migracion 06.

### Tabla: `cita`

```sql
CREATE TABLE cita (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id             UUID NOT NULL
                              REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                 UUID NOT NULL,
  profesional_id              UUID NOT NULL,
  tipo_atencion_id            UUID,
  tipo_atencion_nombre_snapshot TEXT,
  inicio                      TIMESTAMPTZ NOT NULL,
  duracion_minutos            INTEGER NOT NULL CHECK (duracion_minutos > 0),
  estado                      TEXT NOT NULL DEFAULT 'agendada'
                              CHECK (estado IN ('agendada', 'confirmada', 'atendida',
                                                'cancelada', 'inasistida', 'reprogramada')),
  motivo_cancelacion          TEXT,
  notas                       TEXT,
  cita_anterior_id            UUID,
  seguimiento_id              UUID,
  atencion_clinica_id         UUID,
  creado_en                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en              TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_anterior_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, seguimiento_id)
    REFERENCES seguimiento(organizacion_id, id) ON DELETE RESTRICT
);
```

**Auto-referencia compuesta:** `cita_anterior_id` usa FK compuesta hacia si misma: `(organizacion_id, cita_anterior_id)` → `(organizacion_id, id)`.
**Trigger Tipo B diferido:** `cita.atencion_clinica_id` recibe su trigger en migracion 08 (la tabla `atencion_clinica` no existe aun).

### ALTER: `seguimiento.cita_id`

```sql
ALTER TABLE seguimiento
  ADD CONSTRAINT fk_seguimiento_cita
  FOREIGN KEY (organizacion_id, cita_id)
  REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT;
```

**Razon:** `seguimiento` se crea antes que `cita`. La FK compuesta hacia `cita` se agrega en el mismo archivo de migracion, despues del CREATE de `cita`.

### Tabla: `transicion_cita`

```sql
CREATE TABLE transicion_cita (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cita_id         UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  motivo          TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Append-only:** Sin `actualizado_en`. Trigger de proteccion en migracion 08.

---

## Migracion 06 — Atencion clinica

### Tabla: `atencion_clinica`

```sql
CREATE TABLE atencion_clinica (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id             UUID NOT NULL
                              REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                 UUID NOT NULL,
  profesional_id              UUID NOT NULL,
  tipo_atencion_id            UUID,
  tipo_atencion_nombre_snapshot TEXT,
  modalidad                   TEXT NOT NULL
                              CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  estado                      TEXT NOT NULL DEFAULT 'registrada'
                              CHECK (estado IN ('registrada', 'cerrada', 'descartada')),
  fecha_inicio                TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_cierre                TIMESTAMPTZ,
  tratamiento                 TEXT,
  hallazgos                   TEXT,
  notas_clinicas              TEXT,
  indicaciones                TEXT,
  cita_id                     UUID,
  creado_en                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en              TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT
);
```

### Tabla: `transicion_atencion`

```sql
CREATE TABLE transicion_atencion (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  atencion_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id      UUID NOT NULL,
  estado_anterior     TEXT NOT NULL,
  estado_nuevo        TEXT NOT NULL,
  motivo              TEXT,
  ocurrido_en         TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, atencion_clinica_id)
    REFERENCES atencion_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Append-only:** Sin `actualizado_en`. Trigger de proteccion en migracion 08.

---

## Migracion 07 — Facturacion

### Tabla: `cobro`

```sql
CREATE TABLE cobro (
  id                            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id               UUID NOT NULL
                                REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                   UUID NOT NULL,
  profesional_id                UUID NOT NULL,
  monto                         DECIMAL NOT NULL CHECK (monto >= 0),
  tipo_atencion_nombre_snapshot TEXT NOT NULL,
  modalidad                     TEXT NOT NULL
                                CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  recargo_zona_snapshot         DECIMAL,
  valor_acordado_centro_snapshot DECIMAL,
  concepto                      TEXT NOT NULL,
  categoria_origen              TEXT NOT NULL
                                CHECK (categoria_origen IN (
                                  'atencion_individual', 'conjunto_atenciones',
                                  'recargo_administrativo', 'anticipo'
                                )),
  atencion_clinica_id           UUID,
  estado_pago                   TEXT NOT NULL DEFAULT 'pendiente'
                                CHECK (estado_pago IN ('pendiente', 'pagado_parcial',
                                                       'pagado', 'anulado')),
  medio_pago                    TEXT,
  fecha_pago                    TIMESTAMPTZ,
  motivo_anulacion              TEXT,
  registrado_en                 TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Sin `actualizado_en`:** El snapshot es inmutable. Cambios de estado se registran en `transicion_pago`.
**Tipo B:** `cobro.atencion_clinica_id` recibe trigger de validacion en migracion 08 (cross-context BC6 → BC2).

### Tabla: `transicion_pago`

```sql
CREATE TABLE transicion_pago (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cobro_id        UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  notas           TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cobro_id)
    REFERENCES cobro(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Append-only:** Sin `actualizado_en`. Trigger de proteccion en migracion 08.

---

## Migracion 08 — Triggers y guards

Esta migracion concentra todos los mecanismos de proteccion. Se divide en secciones logicas dentro del mismo archivo.

### 8.1 Triggers `updated_at`

Tablas mutables que reciben trigger `set_updated_at()`:

| Tabla | Trigger name |
|-------|-------------|
| `organizacion_clinica` | `trg_organizacion_clinica_updated_at` |
| `profesional` | `trg_profesional_updated_at` |
| `tipo_atencion` | `trg_tipo_atencion_updated_at` |
| `paciente` | `trg_paciente_updated_at` |
| `entrada_clinica` | `trg_entrada_clinica_updated_at` |
| `seguimiento` | `trg_seguimiento_updated_at` |
| `cita` | `trg_cita_updated_at` |
| `atencion_clinica` | `trg_atencion_clinica_updated_at` |

**Tablas sin `updated_at`** (append-only o snapshot inmutable): `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`, `valor_arancel`, `cobro`, `historia_clinica`.

Patron para cada una:

```sql
CREATE TRIGGER trg_{tabla}_updated_at
  BEFORE UPDATE ON {tabla}
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
```

### 8.2 Triggers append-only (BEFORE UPDATE OR DELETE)

Tablas protegidas: `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`.

```sql
CREATE OR REPLACE FUNCTION reject_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Tabla % es append-only: no se permite % de registros',
    TG_TABLE_NAME, TG_OP;
END;
$$;
```

Se aplica a cada tabla:

```sql
CREATE TRIGGER trg_{tabla}_append_only
  BEFORE UPDATE OR DELETE ON {tabla}
  FOR EACH ROW
  EXECUTE FUNCTION reject_mutation();
```

### 8.3 Trigger de inmutabilidad: `entrada_clinica`

```sql
CREATE OR REPLACE FUNCTION guard_entrada_clinica_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.descripcion IS DISTINCT FROM NEW.descripcion
     OR OLD.tipo IS DISTINCT FROM NEW.tipo
     OR OLD.historia_clinica_id IS DISTINCT FROM NEW.historia_clinica_id
     OR OLD.registrado_por IS DISTINCT FROM NEW.registrado_por
     OR OLD.registrado_en IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'entrada_clinica: columnas protegidas no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_entrada_clinica_immutable
  BEFORE UPDATE ON entrada_clinica
  FOR EACH ROW
  EXECUTE FUNCTION guard_entrada_clinica_immutable();
```

### 8.4 Trigger de inmutabilidad: `atencion_clinica` (condicional)

```sql
CREATE OR REPLACE FUNCTION guard_atencion_clinica_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.estado = 'cerrada' THEN
    IF OLD.tratamiento IS DISTINCT FROM NEW.tratamiento
       OR OLD.hallazgos IS DISTINCT FROM NEW.hallazgos
       OR OLD.notas_clinicas IS DISTINCT FROM NEW.notas_clinicas
       OR OLD.indicaciones IS DISTINCT FROM NEW.indicaciones
       OR OLD.fecha_cierre IS DISTINCT FROM NEW.fecha_cierre
       OR OLD.paciente_id IS DISTINCT FROM NEW.paciente_id
       OR OLD.profesional_id IS DISTINCT FROM NEW.profesional_id
       OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
    THEN
      RAISE EXCEPTION 'atencion_clinica cerrada: columnas clinicas no pueden modificarse';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atencion_clinica_immutable
  BEFORE UPDATE ON atencion_clinica
  FOR EACH ROW
  EXECUTE FUNCTION guard_atencion_clinica_immutable();
```

### 8.5 Trigger de inmutabilidad: `cobro` (snapshot)

```sql
CREATE OR REPLACE FUNCTION guard_cobro_snapshot_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.monto IS DISTINCT FROM NEW.monto
     OR OLD.tipo_atencion_nombre_snapshot IS DISTINCT FROM NEW.tipo_atencion_nombre_snapshot
     OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
     OR OLD.recargo_zona_snapshot IS DISTINCT FROM NEW.recargo_zona_snapshot
     OR OLD.valor_acordado_centro_snapshot IS DISTINCT FROM NEW.valor_acordado_centro_snapshot
     OR OLD.concepto IS DISTINCT FROM NEW.concepto
     OR OLD.categoria_origen IS DISTINCT FROM NEW.categoria_origen
     OR OLD.registrado_en IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'cobro: columnas snapshot son inmutables';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cobro_snapshot_immutable
  BEFORE UPDATE ON cobro
  FOR EACH ROW
  EXECUTE FUNCTION guard_cobro_snapshot_immutable();
```

### 8.6 Trigger de inmutabilidad: `valor_arancel` (total + excepcion controlada)

```sql
CREATE OR REPLACE FUNCTION guard_valor_arancel_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Todas las columnas excepto vigente_hasta son absolutamente inmutables
  IF OLD.tipo_atencion_id IS DISTINCT FROM NEW.tipo_atencion_id
     OR OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
     OR OLD.valor IS DISTINCT FROM NEW.valor
     OR OLD.vigente_desde IS DISTINCT FROM NEW.vigente_desde
     OR OLD.configurado_por IS DISTINCT FROM NEW.configurado_por
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'valor_arancel: columnas protegidas son inmutables';
  END IF;

  -- vigente_hasta: solo permite transicion NULL -> fecha valida
  IF OLD.vigente_hasta IS DISTINCT FROM NEW.vigente_hasta THEN
    -- No permitir reapertura (fecha -> NULL)
    IF OLD.vigente_hasta IS NOT NULL THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta ya establecida, no puede modificarse';
    END IF;
    -- No permitir fecha invalida
    IF NEW.vigente_hasta IS NULL THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta solo puede cambiar de NULL a fecha valida';
    END IF;
    -- Verificar que viene de la RPC (via setting de sesion)
    IF current_setting('app.rpc_cerrar_arancel', true) IS DISTINCT FROM 'true' THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta solo puede modificarse via RPC cerrar_arancel';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_valor_arancel_immutable
  BEFORE UPDATE ON valor_arancel
  FOR EACH ROW
  EXECUTE FUNCTION guard_valor_arancel_immutable();
```

**Mecanismo de verificacion de contexto RPC:** Se usa `current_setting('app.rpc_cerrar_arancel', true)` como flag de sesion. La RPC `cerrar_arancel` establece `SET LOCAL app.rpc_cerrar_arancel = 'true'` antes de ejecutar el UPDATE. El `SET LOCAL` es transaccional: se revierte automaticamente al final de la transaccion. Cualquier UPDATE directo no tendra esta flag, y el trigger lo rechazara.

**Este es el mecanismo que resuelve el hallazgo medio 1 del QA v1.2:** La verificacion de "proviene de la RPC" no es ambigua — usa un setting de sesion transaccional verificable.

### 8.7 Triggers Tipo B diferidos (cross-context)

Funcion generica de validacion cross-tenant:

```sql
CREATE OR REPLACE FUNCTION validate_cross_tenant_ref()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  ref_org_id UUID;
  col_name TEXT := TG_ARGV[0];
  ref_table TEXT := TG_ARGV[1];
  ref_value UUID;
BEGIN
  EXECUTE format('SELECT ($1).%I', col_name) INTO ref_value USING NEW;

  IF ref_value IS NULL THEN
    RETURN NEW;
  END IF;

  EXECUTE format(
    'SELECT organizacion_id FROM %I WHERE id = $1',
    ref_table
  ) INTO ref_org_id USING ref_value;

  IF ref_org_id IS NULL THEN
    RAISE EXCEPTION 'Referencia invalida: %.% = % no existe en %',
      TG_TABLE_NAME, col_name, ref_value, ref_table;
  END IF;

  IF ref_org_id != NEW.organizacion_id THEN
    RAISE EXCEPTION 'Violacion tenant: %.% referencia registro de otra organizacion',
      TG_TABLE_NAME, col_name;
  END IF;

  RETURN NEW;
END;
$$;
```

**Aplicacion — Paso 12b (despues de crear `atencion_clinica`):**

```sql
-- seguimiento.atencion_clinica_id → atencion_clinica
CREATE TRIGGER trg_seguimiento_validate_atencion
  BEFORE INSERT OR UPDATE ON seguimiento
  FOR EACH ROW
  EXECUTE FUNCTION validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');

-- cita.atencion_clinica_id → atencion_clinica
CREATE TRIGGER trg_cita_validate_atencion
  BEFORE INSERT OR UPDATE ON cita
  FOR EACH ROW
  EXECUTE FUNCTION validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');
```

**Aplicacion — Paso 14 (junto con tabla `cobro`):**

```sql
-- cobro.atencion_clinica_id → atencion_clinica
CREATE TRIGGER trg_cobro_validate_atencion
  BEFORE INSERT OR UPDATE ON cobro
  FOR EACH ROW
  EXECUTE FUNCTION validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');
```

---

## Migracion 09 — Policies RLS

### Habilitacion de RLS

```sql
ALTER TABLE organizacion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE profesional ENABLE ROW LEVEL SECURITY;
ALTER TABLE evento_auditoria_minima ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipo_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE valor_arancel ENABLE ROW LEVEL SECURITY;
ALTER TABLE paciente ENABLE ROW LEVEL SECURITY;
ALTER TABLE historia_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE entrada_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE seguimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE transicion_cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE atencion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE transicion_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE cobro ENABLE ROW LEVEL SECURITY;
ALTER TABLE transicion_pago ENABLE ROW LEVEL SECURITY;
```

### Policies por tabla

#### `organizacion_clinica`

```sql
-- SELECT: solo su propia organizacion
CREATE POLICY select_own_org ON organizacion_clinica
  FOR SELECT USING (id = obtener_mi_organizacion_id());

-- UPDATE: campos operativos de su propia org
CREATE POLICY update_own_org ON organizacion_clinica
  FOR UPDATE USING (id = obtener_mi_organizacion_id());
```

**Sin INSERT ni DELETE** para el rol de aplicacion. La creacion de organizaciones es administrativa.

#### `profesional`

```sql
-- SELECT: misma organizacion
CREATE POLICY select_profesional ON profesional
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- UPDATE: solo su propio perfil
CREATE POLICY update_own_profesional ON profesional
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND auth_user_id = auth.uid()
  );
```

**Sin INSERT:** Creacion exclusiva via trigger `auth.users`.
**Sin DELETE:** Nunca.

#### `evento_auditoria_minima`

```sql
-- SELECT: misma organizacion
CREATE POLICY select_auditoria ON evento_auditoria_minima
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());
```

**Sin INSERT/UPDATE/DELETE para el rol de aplicacion.** Los INSERTs ocurren dentro de RPCs T00 con `SECURITY DEFINER`, que bypassean RLS.

#### `tipo_atencion`

```sql
CREATE POLICY select_tipo_atencion ON tipo_atencion
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_tipo_atencion ON tipo_atencion
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_tipo_atencion ON tipo_atencion
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());
```

#### `valor_arancel`

```sql
CREATE POLICY select_valor_arancel ON valor_arancel
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_valor_arancel ON valor_arancel
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());
```

**Sin UPDATE policy para el rol de aplicacion.** El UPDATE a `vigente_hasta` ocurre via RPC `cerrar_arancel` con `SECURITY DEFINER`.

#### `paciente`

```sql
CREATE POLICY select_paciente ON paciente
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_paciente ON paciente
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_paciente ON paciente
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado != 'archivado'
  );
```

#### `historia_clinica`

```sql
CREATE POLICY select_historia ON historia_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_historia ON historia_clinica
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());
```

**Sin INSERT para rol de aplicacion:** Creacion via RPC `crear_paciente` con `SECURITY DEFINER`.

#### `entrada_clinica`

```sql
CREATE POLICY select_entrada ON entrada_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_entrada ON entrada_clinica
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_entrada ON entrada_clinica
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());
```

**Nota:** El trigger de inmutabilidad restringe que columnas pueden cambiar. RLS solo controla si la fila puede ser accedida.

#### `seguimiento`

```sql
CREATE POLICY select_seguimiento ON seguimiento
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_seguimiento ON seguimiento
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_seguimiento ON seguimiento
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado NOT IN ('completado', 'descartado')
  );
```

#### `cita`

```sql
CREATE POLICY select_cita ON cita
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_cita ON cita
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_cita ON cita
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado NOT IN ('atendida', 'cancelada', 'inasistida')
  );
```

#### `transicion_cita`

```sql
CREATE POLICY select_transicion_cita ON transicion_cita
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());
```

**Sin INSERT/UPDATE/DELETE para el rol de aplicacion.** Escritura via RPCs T00.

#### `atencion_clinica`

```sql
CREATE POLICY select_atencion ON atencion_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_atencion ON atencion_clinica
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY update_atencion ON atencion_clinica
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado = 'registrada'
  );
```

**Nota:** El UPDATE directo solo se permite mientras `estado = 'registrada'`. La transicion a `cerrada` ocurre via RPC `cerrar_atencion` con `SECURITY DEFINER`.

#### `transicion_atencion`

```sql
CREATE POLICY select_transicion_atencion ON transicion_atencion
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());
```

**Sin INSERT/UPDATE/DELETE para el rol de aplicacion.** Escritura via RPCs T00.

#### `cobro`

```sql
CREATE POLICY select_cobro ON cobro
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY insert_cobro ON cobro
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());
```

**Sin UPDATE policy para el rol de aplicacion.** Cambios de estado via RPCs controladas (`registrar_pago`, `anular_cobro`) con `SECURITY DEFINER`.

#### `transicion_pago`

```sql
CREATE POLICY select_transicion_pago ON transicion_pago
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());
```

**Sin INSERT/UPDATE/DELETE para el rol de aplicacion.** Escritura via RPCs.

---

## Migracion 10 — RPCs Fase 1

### Convenciones de todas las RPCs

- **`SECURITY DEFINER`**: necesario para escribir en tablas donde el rol de aplicacion no tiene INSERT/UPDATE directo
- **`SET search_path = public`**: previene ataques de path injection
- **Transaccional**: toda la RPC es una transaccion. Si falla cualquier paso, revierte todo
- **Validaciones de tenant**: cada RPC verifica que los datos referenciados pertenezcan a la misma organizacion

### 10.1 RPCs T00

#### `crear_paciente`

```sql
CREATE OR REPLACE FUNCTION crear_paciente(
  p_nombre_completo TEXT,
  p_rut TEXT DEFAULT NULL,
  p_fecha_nacimiento DATE DEFAULT NULL,
  p_telefono_principal TEXT DEFAULT NULL,
  p_telefono_alternativo TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_direccion TEXT DEFAULT NULL,
  p_origen_categoria TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_paciente_id UUID;
  v_historia_id UUID;
BEGIN
  -- Obtener contexto del profesional autenticado
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Insertar paciente
  INSERT INTO paciente (
    organizacion_id, nombre_completo, rut, fecha_nacimiento,
    telefono_principal, telefono_alternativo, email, direccion,
    origen_categoria, estado, notas, creado_por
  ) VALUES (
    v_org_id, p_nombre_completo, p_rut, p_fecha_nacimiento,
    p_telefono_principal, p_telefono_alternativo, p_email, p_direccion,
    p_origen_categoria, 'activo', p_notas, v_prof_id
  )
  RETURNING id INTO v_paciente_id;

  -- Insertar historia clinica (1:1 atomica)
  INSERT INTO historia_clinica (
    paciente_id, organizacion_id
  ) VALUES (
    v_paciente_id, v_org_id
  )
  RETURNING id INTO v_historia_id;

  -- Insertar evento de auditoria T00
  INSERT INTO evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'paciente_creado',
    'paciente', v_paciente_id, 'activo', now()
  );

  RETURN v_paciente_id;
END;
$$;
```

#### `registrar_atencion`

```sql
CREATE OR REPLACE FUNCTION registrar_atencion(
  p_paciente_id UUID,
  p_tipo_atencion_id UUID DEFAULT NULL,
  p_modalidad TEXT DEFAULT 'particular',
  p_cita_id UUID DEFAULT NULL,
  p_notas_clinicas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_atencion_id UUID;
  v_tipo_nombre TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Validar paciente pertenece a la misma org
  IF NOT EXISTS (
    SELECT 1 FROM paciente
    WHERE id = p_paciente_id AND organizacion_id = v_org_id
  ) THEN
    RAISE EXCEPTION 'Paciente no encontrado en esta organizacion';
  END IF;

  -- Capturar snapshot del tipo de atencion si se proporciona
  IF p_tipo_atencion_id IS NOT NULL THEN
    SELECT nombre INTO v_tipo_nombre
    FROM tipo_atencion
    WHERE id = p_tipo_atencion_id AND organizacion_id = v_org_id;

    IF v_tipo_nombre IS NULL THEN
      RAISE EXCEPTION 'Tipo de atencion no encontrado en esta organizacion';
    END IF;
  END IF;

  -- Validar cita si se proporciona
  IF p_cita_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM cita
      WHERE id = p_cita_id AND organizacion_id = v_org_id
    ) THEN
      RAISE EXCEPTION 'Cita no encontrada en esta organizacion';
    END IF;
  END IF;

  -- Insertar atencion clinica
  INSERT INTO atencion_clinica (
    organizacion_id, paciente_id, profesional_id,
    tipo_atencion_id, tipo_atencion_nombre_snapshot,
    modalidad, estado, notas_clinicas, cita_id
  ) VALUES (
    v_org_id, p_paciente_id, v_prof_id,
    p_tipo_atencion_id, v_tipo_nombre,
    p_modalidad, 'registrada', p_notas_clinicas, p_cita_id
  )
  RETURNING id INTO v_atencion_id;

  -- Insertar transicion inicial
  INSERT INTO transicion_atencion (
    atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    v_atencion_id, v_org_id, v_prof_id,
    'inexistente', 'registrada'
  );

  -- Insertar evento de auditoria T00
  INSERT INTO evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'atencion_registrada',
    'atencion_clinica', v_atencion_id, 'registrada', now()
  );

  RETURN v_atencion_id;
END;
$$;
```

#### `cerrar_atencion`

```sql
CREATE OR REPLACE FUNCTION cerrar_atencion(
  p_atencion_id UUID,
  p_tratamiento TEXT DEFAULT NULL,
  p_hallazgos TEXT DEFAULT NULL,
  p_indicaciones TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Obtener estado actual y validar organizacion
  SELECT estado INTO v_estado_actual
  FROM atencion_clinica
  WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Atencion no encontrada en esta organizacion';
  END IF;

  IF v_estado_actual != 'registrada' THEN
    RAISE EXCEPTION 'Solo se puede cerrar una atencion en estado registrada (actual: %)',
      v_estado_actual;
  END IF;

  -- Actualizar atencion (el trigger de inmutabilidad permite porque estado aun es 'registrada')
  UPDATE atencion_clinica SET
    estado = 'cerrada',
    fecha_cierre = now(),
    tratamiento = COALESCE(p_tratamiento, tratamiento),
    hallazgos = COALESCE(p_hallazgos, hallazgos),
    indicaciones = COALESCE(p_indicaciones, indicaciones)
  WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  -- Insertar transicion
  INSERT INTO transicion_atencion (
    atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    p_atencion_id, v_org_id, v_prof_id,
    'registrada', 'cerrada'
  );

  -- Insertar evento de auditoria T00
  INSERT INTO evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'atencion_cerrada',
    'atencion_clinica', p_atencion_id,
    'registrada', 'cerrada', now()
  );
END;
$$;
```

#### `modificar_estado_cita`

```sql
CREATE OR REPLACE FUNCTION modificar_estado_cita(
  p_cita_id UUID,
  p_estado_nuevo TEXT,
  p_motivo TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Validar estado nuevo
  IF p_estado_nuevo NOT IN ('agendada', 'confirmada', 'atendida',
                            'cancelada', 'inasistida', 'reprogramada') THEN
    RAISE EXCEPTION 'Estado de cita invalido: %', p_estado_nuevo;
  END IF;

  -- Obtener estado actual
  SELECT estado INTO v_estado_actual
  FROM cita
  WHERE id = p_cita_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cita no encontrada en esta organizacion';
  END IF;

  -- No permitir cambios desde estados terminales
  IF v_estado_actual IN ('atendida', 'cancelada', 'inasistida') THEN
    RAISE EXCEPTION 'No se puede modificar una cita en estado terminal: %', v_estado_actual;
  END IF;

  -- Actualizar cita
  UPDATE cita SET
    estado = p_estado_nuevo,
    motivo_cancelacion = CASE
      WHEN p_estado_nuevo IN ('cancelada', 'reprogramada') THEN p_motivo
      ELSE motivo_cancelacion
    END
  WHERE id = p_cita_id AND organizacion_id = v_org_id;

  -- Insertar transicion
  INSERT INTO transicion_cita (
    cita_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, motivo
  ) VALUES (
    p_cita_id, v_org_id, v_prof_id,
    v_estado_actual, p_estado_nuevo, p_motivo
  );

  -- Insertar evento de auditoria T00
  INSERT INTO evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'cita_modificada',
    'cita', p_cita_id,
    v_estado_actual, p_estado_nuevo, now()
  );
END;
$$;
```

#### `agregar_entrada_clinica`

```sql
CREATE OR REPLACE FUNCTION agregar_entrada_clinica(
  p_paciente_id UUID,
  p_tipo TEXT,
  p_descripcion TEXT,
  p_notas_adicionales TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_historia_id UUID;
  v_entrada_id UUID;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Obtener historia clinica del paciente (misma org)
  SELECT id INTO v_historia_id
  FROM historia_clinica
  WHERE paciente_id = p_paciente_id AND organizacion_id = v_org_id;

  IF v_historia_id IS NULL THEN
    RAISE EXCEPTION 'Historia clinica no encontrada para el paciente en esta organizacion';
  END IF;

  -- Insertar entrada clinica
  INSERT INTO entrada_clinica (
    historia_clinica_id, organizacion_id, tipo,
    descripcion, notas_adicionales, registrado_por
  ) VALUES (
    v_historia_id, v_org_id, p_tipo,
    p_descripcion, p_notas_adicionales, v_prof_id
  )
  RETURNING id INTO v_entrada_id;

  -- Insertar evento de auditoria T00
  INSERT INTO evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'historia_clinica_actualizada',
    'entrada_clinica', v_entrada_id, 'activo', now()
  );

  RETURN v_entrada_id;
END;
$$;
```

### 10.2 RPCs controladas

#### `registrar_pago`

```sql
CREATE OR REPLACE FUNCTION registrar_pago(
  p_cobro_id UUID,
  p_medio_pago TEXT,
  p_estado_nuevo TEXT DEFAULT 'pagado'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF p_estado_nuevo NOT IN ('pagado_parcial', 'pagado') THEN
    RAISE EXCEPTION 'Estado de pago invalido: %', p_estado_nuevo;
  END IF;

  SELECT estado_pago INTO v_estado_actual
  FROM cobro
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cobro no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual IN ('pagado', 'anulado') THEN
    RAISE EXCEPTION 'No se puede registrar pago en cobro con estado: %', v_estado_actual;
  END IF;

  UPDATE cobro SET
    estado_pago = p_estado_nuevo,
    medio_pago = p_medio_pago,
    fecha_pago = now()
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_pago (
    cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, p_estado_nuevo
  );
END;
$$;
```

#### `anular_cobro`

```sql
CREATE OR REPLACE FUNCTION anular_cobro(
  p_cobro_id UUID,
  p_motivo TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF p_motivo IS NULL OR p_motivo = '' THEN
    RAISE EXCEPTION 'El motivo de anulacion es obligatorio';
  END IF;

  SELECT estado_pago INTO v_estado_actual
  FROM cobro
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cobro no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual = 'anulado' THEN
    RAISE EXCEPTION 'El cobro ya esta anulado';
  END IF;

  UPDATE cobro SET
    estado_pago = 'anulado',
    motivo_anulacion = p_motivo
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_pago (
    cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, notas
  ) VALUES (
    p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, 'anulado', p_motivo
  );
END;
$$;
```

#### `archivar_paciente`

```sql
CREATE OR REPLACE FUNCTION archivar_paciente(
  p_paciente_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT estado INTO v_estado_actual
  FROM paciente
  WHERE id = p_paciente_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Paciente no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual = 'archivado' THEN
    RAISE EXCEPTION 'El paciente ya esta archivado';
  END IF;

  UPDATE paciente SET
    estado = 'archivado'
  WHERE id = p_paciente_id AND organizacion_id = v_org_id;
END;
$$;
```

#### `cerrar_arancel`

```sql
CREATE OR REPLACE FUNCTION cerrar_arancel(
  p_valor_arancel_id UUID,
  p_vigente_hasta DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_vigente_hasta_actual DATE;
BEGIN
  SELECT organizacion_id INTO v_org_id
  FROM profesional
  WHERE auth_user_id = auth.uid();

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- Validar que el arancel existe y pertenece a la org
  SELECT vigente_hasta INTO v_vigente_hasta_actual
  FROM valor_arancel
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Valor de arancel no encontrado en esta organizacion';
  END IF;

  IF v_vigente_hasta_actual IS NOT NULL THEN
    RAISE EXCEPTION 'Este arancel ya tiene vigencia cerrada';
  END IF;

  -- Establecer flag de sesion para que el trigger permita el UPDATE
  SET LOCAL app.rpc_cerrar_arancel = 'true';

  UPDATE valor_arancel SET
    vigente_hasta = p_vigente_hasta
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;
END;
$$;
```

**Mecanismo de flag de sesion:** `SET LOCAL app.rpc_cerrar_arancel = 'true'` establece un setting de sesion que solo vive durante la transaccion actual. El trigger `guard_valor_arancel_immutable` verifica esta flag via `current_setting('app.rpc_cerrar_arancel', true)`. Cualquier UPDATE directo (sin pasar por esta RPC) no tendra la flag y sera rechazado.

---

## Migracion 11 — QA Fase 1

### Estrategia de QA

Todos los tests se ejecutan dentro de una transaccion con `ROLLBACK` al final. No dejan datos permanentes. Pueden ejecutarse multiples veces sin efectos secundarios.

```sql
BEGIN;
-- ... tests ...
ROLLBACK;
```

### Categorias de tests

#### 11.1 Tests de estructura

```
- Verificar que las 15 tablas existen
- Verificar que UNIQUE (organizacion_id, id) existe en las 8 tablas ancla
- Verificar que los indices parciales existen
- Verificar que RLS esta habilitado en las 15 tablas
- Verificar que las policies existen por tabla
- Verificar que los triggers existen por tabla
```

#### 11.2 Tests de integridad tenant (FK compuestas)

```
-- Crear org A y org B con sus profesionales
-- Crear paciente en org A
-- Intentar crear historia_clinica con paciente de org A pero organizacion_id de org B
-- Esperar: ERROR de FK compuesta
-- Intentar crear atencion_clinica con paciente de org A pero profesional de org B
-- Esperar: ERROR de FK compuesta
```

**Tests cross-tenant negativos (requisito Codex):**

```
-- Para cada tabla ancla, verificar:
-- 1. INSERT con organizacion_id de org B y entidad_id de org A → ERROR
-- 2. INSERT con organizacion_id de org A y entidad_id de org A → OK
-- Tablas a cubrir: paciente, profesional, tipo_atencion, cita, seguimiento,
--                  atencion_clinica, cobro, historia_clinica
```

#### 11.3 Tests de triggers Tipo B

```
-- Crear atencion_clinica en org A
-- Intentar asignar cita.atencion_clinica_id con atencion de org B
-- Esperar: ERROR del trigger validate_cross_tenant_ref
-- Intentar asignar seguimiento.atencion_clinica_id con atencion de org B
-- Esperar: ERROR del trigger validate_cross_tenant_ref
-- Intentar asignar cobro.atencion_clinica_id con atencion de org B
-- Esperar: ERROR del trigger validate_cross_tenant_ref
```

#### 11.4 Tests de append-only

```
-- Insertar en evento_auditoria_minima (via RPC)
-- Intentar UPDATE → ERROR
-- Intentar DELETE → ERROR
-- Repetir para: transicion_atencion, transicion_cita, transicion_pago
```

#### 11.5 Tests de inmutabilidad

```
-- entrada_clinica: intentar UPDATE de descripcion → ERROR
-- atencion_clinica cerrada: intentar UPDATE de tratamiento → ERROR
-- cobro: intentar UPDATE de monto → ERROR
-- valor_arancel: intentar UPDATE de valor → ERROR
-- valor_arancel: intentar UPDATE directo de vigente_hasta → ERROR
-- valor_arancel: via RPC cerrar_arancel → OK
-- valor_arancel: intentar cerrar arancel ya cerrado → ERROR
```

#### 11.6 Tests de RPCs T00

```
-- crear_paciente: verificar que crea paciente + historia_clinica + evento_auditoria
-- registrar_atencion: verificar atencion + transicion + evento
-- cerrar_atencion: verificar UPDATE + transicion + evento
-- modificar_estado_cita: verificar UPDATE + transicion + evento
-- agregar_entrada_clinica: verificar entrada + evento
```

#### 11.7 Tests de RPCs controladas

```
-- registrar_pago: verificar cobro.estado_pago cambia + transicion_pago creada
-- anular_cobro: verificar estado_pago = 'anulado' + motivo + transicion_pago
-- archivar_paciente: verificar estado = 'archivado'
-- archivar_paciente: intentar UPDATE de paciente archivado → ERROR RLS
-- cerrar_arancel: verificar vigente_hasta cambia de NULL a fecha
-- cerrar_arancel: intentar cerrar arancel ya cerrado → ERROR
```

#### 11.8 Tests de RLS

```
-- Profesional de org A no puede SELECT pacientes de org B
-- Profesional de org A no puede INSERT paciente con organizacion_id de org B
-- UPDATE bloqueado en paciente archivado
-- UPDATE bloqueado en cita con estado terminal
-- UPDATE bloqueado en seguimiento completado/descartado
-- UPDATE bloqueado en atencion_clinica con estado != 'registrada'
-- INSERT directo en evento_auditoria_minima → ERROR (sin policy)
-- INSERT directo en transicion_atencion → ERROR (sin policy)
```

---

## Indices de Fase 1

Estos indices se crean en las migraciones de cada tabla (migraciones 02-07). Se listan aqui consolidados para referencia.

| Tabla | Indice | Tipo |
|-------|--------|------|
| `paciente` | `(organizacion_id, estado)` | btree |
| `paciente` | `(organizacion_id, rut) WHERE rut IS NOT NULL` | parcial unique |
| `entrada_clinica` | `(historia_clinica_id, estado)` | btree |
| `atencion_clinica` | `(paciente_id, estado)` | btree |
| `atencion_clinica` | `(profesional_id, fecha_inicio)` | btree |
| `atencion_clinica` | `(organizacion_id, estado, fecha_inicio)` | btree |
| `transicion_atencion` | `(atencion_clinica_id)` | btree |
| `cita` | `(profesional_id, inicio)` | btree |
| `cita` | `(organizacion_id, inicio, estado)` | btree |
| `cita` | `(paciente_id, estado)` | btree |
| `transicion_cita` | `(cita_id)` | btree |
| `seguimiento` | `(organizacion_id, estado, urgencia)` | btree |
| `seguimiento` | `(paciente_id, estado)` | btree |
| `tipo_atencion` | `(organizacion_id, estado)` | btree |
| `valor_arancel` | `(tipo_atencion_id, organizacion_id, modalidad) WHERE vigente_hasta IS NULL` | parcial unique |
| `cobro` | `(organizacion_id, estado_pago)` | btree |
| `cobro` | `(paciente_id)` | btree |
| `transicion_pago` | `(cobro_id)` | btree |
| `evento_auditoria_minima` | `(organizacion_id, tipo_evento, ocurrido_en)` | btree |
| `evento_auditoria_minima` | `(entidad_tipo, entidad_id)` | btree |

---

## Riesgos operacionales

### R1 — Orden de creacion de `obtener_mi_organizacion_id()`

**Riesgo:** La funcion referencia `profesional`, que se crea en migracion 02. Si la funcion se crea en migracion 01, la referencia es invalida hasta que migracion 02 se aplique.
**Mitigacion:** PostgreSQL acepta funciones con referencias forward en SQL/plpgsql (la tabla no se resuelve hasta la primera invocacion). Sin embargo, si el dry-run detecta problemas, mover la funcion al final de migracion 02.
**Impacto si falla:** Ninguno en dry-run. En produccion, las policies RLS fallarian hasta aplicar migracion 02.

### R2 — Trigger en `auth.users` requiere esquema `auth`

**Riesgo:** El trigger `on_auth_user_created` se crea sobre `auth.users`. En Supabase esto es posible, pero en un entorno local (tests, CI) puede no existir el esquema `auth`.
**Mitigacion:** Para ambientes de test, proveer un mock del esquema auth o skip del trigger. El dry-run debe ejecutarse contra una instancia Supabase real (staging o proyecto de test).

### R3 — `SECURITY DEFINER` y escalacion de privilegios

**Riesgo:** Todas las RPCs usan `SECURITY DEFINER`, lo que les da los privilegios del owner de la funcion (normalmente `postgres`). Si una RPC tiene un bug de SQL injection o logica incorrecta, el atacante puede escalar privilegios.
**Mitigacion:** (a) `SET search_path = public` en toda RPC. (b) Todos los parametros se usan via binds, nunca concatenacion de strings. (c) Revision de seguridad obligatoria antes de aprobar las migraciones finales.

### R4 — `SET LOCAL` como mecanismo de contexto RPC

**Riesgo:** El patron `SET LOCAL app.rpc_cerrar_arancel = 'true'` podria ser imitado si un atacante logra ejecutar SQL arbitrario en la misma transaccion.
**Mitigacion:** (a) RLS no permite UPDATE directo sobre `valor_arancel`. (b) El unico camino es via la RPC `SECURITY DEFINER`. (c) Un atacante con SQL arbitrario ya tiene acceso a `SECURITY DEFINER`, asi que el setting no agrega superficie de ataque nueva.

### R5 — Migraciones parcialmente aplicadas

**Riesgo:** Si una migracion falla a mitad de camino, el schema queda en estado inconsistente.
**Mitigacion:** Cada archivo de migracion debe ejecutarse dentro de una transaccion. Si falla cualquier statement, toda la migracion revierte. Supabase CLI ejecuta migraciones en transacciones por defecto.

### R6 — Performance de `obtener_mi_organizacion_id()` en policies RLS

**Riesgo:** Esta funcion se invoca en cada operacion de lectura/escritura. Si la tabla `profesional` crece significativamente, puede convertirse en cuello de botella.
**Mitigacion:** (a) `profesional` tiene un indice unico en `auth_user_id`, asi que la busqueda es O(1). (b) `STABLE` permite caching intra-transaccion. (c) Monitorear `pg_stat_user_functions` despues del despliegue.

---

## Estrategia de dry-run y rollback logico

### Dry-run

1. **Ambiente:** Proyecto Supabase de staging o proyecto desechable (no produccion).
2. **Proceso:** Ejecutar las 11 migraciones en orden contra el proyecto de staging.
3. **Verificacion:**
   - Todas las migraciones completan sin error.
   - `11_qa_phase1.sql` pasa todos los tests.
   - `obtener_mi_organizacion_id()` retorna NULL sin sesion (no falla).
   - Las policies RLS bloquean acceso sin autenticacion.
4. **Limpieza:** El proyecto de staging se puede resetear con `supabase db reset`.

### Rollback logico

No se implementa un sistema de rollback automatico por migracion. El rollback es:

1. **Antes de produccion:** `supabase db reset` en staging.
2. **En produccion (si se aplicaron migraciones):** Se requieren migraciones inversas manuales. Para Fase 1, dado que no hay datos en produccion al momento de aplicar, el rollback es `DROP TABLE` en orden inverso. Se recomienda preparar un archivo `rollback_phase1.sql` con los DROPs antes de aplicar en produccion.

### Validacion pre-produccion

Antes de aplicar en produccion, se debe verificar:

1. Dry-run exitoso en staging.
2. QA `11_qa_phase1.sql` pasa sin errores.
3. Revision de seguridad aprobada (RPCs, RLS, triggers).
4. Archivo `rollback_phase1.sql` preparado y probado en staging.

---

## Checklist QA para aprobacion

### Estructura

- [ ] Las 15 tablas Fase 1 existen
- [ ] `UNIQUE (organizacion_id, id)` en 8 tablas ancla
- [ ] 3 indices parciales unicos: `paciente.rut`, `tipo_atencion.nombre`, `valor_arancel.vigente`
- [ ] RLS habilitado en las 15 tablas
- [ ] Policies creadas para cada tabla segun blueprint
- [ ] CHECK constraints en todos los campos de estado/tipo

### FK compuestas y tenant safety

- [ ] Todas las FK Tipo A usan orden `(organizacion_id, entidad_id)` → `(organizacion_id, id)`
- [ ] Test cross-tenant negativo para cada tabla ancla
- [ ] Triggers Tipo B creados para `cita.atencion_clinica_id`, `seguimiento.atencion_clinica_id`, `cobro.atencion_clinica_id`
- [ ] Tests cross-tenant negativos para Tipo B

### Inmutabilidad

- [ ] `entrada_clinica`: trigger protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en`
- [ ] `atencion_clinica`: trigger protege columnas clinicas cuando `estado = 'cerrada'`
- [ ] `cobro`: trigger protege todas las columnas snapshot
- [ ] `valor_arancel`: trigger protege todas las columnas; `vigente_hasta` solo cambia via RPC
- [ ] Append-only: UPDATE y DELETE rechazados en `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`

### RPCs

- [ ] `crear_paciente` crea atomicamente: paciente + historia_clinica + evento_auditoria
- [ ] `registrar_atencion` crea: atencion + transicion + evento
- [ ] `cerrar_atencion` actualiza atencion + crea transicion + crea evento
- [ ] `modificar_estado_cita` actualiza cita + crea transicion + crea evento
- [ ] `agregar_entrada_clinica` crea entrada + crea evento
- [ ] `registrar_pago` actualiza cobro + crea transicion_pago
- [ ] `anular_cobro` actualiza cobro + crea transicion_pago + requiere motivo
- [ ] `archivar_paciente` cambia estado a archivado
- [ ] `cerrar_arancel` es la **unica** via para modificar `vigente_hasta`
- [ ] El rol de aplicacion **no tiene** UPDATE directo sobre `valor_arancel`

### Seguridad

- [ ] Todas las RPCs usan `SECURITY DEFINER` + `SET search_path = public`
- [ ] No hay concatenacion de strings SQL en RPCs (solo binds)
- [ ] `obtener_mi_organizacion_id()` es `STABLE` + `SECURITY DEFINER`
- [ ] Trigger `auth.users` → `profesional` usa `SECURITY DEFINER`

### Fase 2 no adelantada

- [ ] No existen tablas: `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, `fotografia_clinica`, `consentimiento`, `informe_sesion`, `intento_contacto`
- [ ] No existen columnas: `relacion_centro_id`, `zona_domiciliaria_id` en tablas Fase 1
- [ ] No existen Storage buckets
- [ ] No existen RPCs de Fase 2

---

## Criterios de aprobacion para pasar a migraciones reales

1. **Este documento es aprobado** sin hallazgos criticos por revision humana.
2. **Dry-run exitoso** en proyecto Supabase de staging.
3. **QA `11_qa_phase1.sql` pasa** al 100% en staging.
4. **Revision de seguridad** aprobada para RPCs y triggers `SECURITY DEFINER`.
5. **Archivo `rollback_phase1.sql`** preparado y probado.
6. **No se detecta adelanto de Fase 2** en ninguna migracion.

Una vez cumplidos estos 6 criterios, se procedera a crear los 11 archivos `.sql` finales en `supabase/migrations/`.

---

*Este blueprint es el plan SQL ejecutable de Fase 1 de Agenda Podologica. Traduce el contrato conceptual de SUPABASE_SCHEMA_BLUEPRINT_v1.2 a pseudocodigo SQL auditable. No es SQL listo para ejecutar: es el paso previo a la creacion de migraciones finales. Cada decision de implementacion debe ser rastreable a este documento o al blueprint v1.2.*
