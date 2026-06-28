# Supabase SQL Phase 1 Blueprint — Agenda Podologica

**Version:** 1.1
**Estado:** Corregido — incorpora hallazgos de QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md
**Fecha:** Junio 2026
**Autor:** Roberto Rojas + Claude
**Fuente canonica:** `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`
**QA de entrada v1.0:** `QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md` — rechazado (4 criticos, 5 medios)
**Siguiente paso:** Revision → aprobacion → creacion de archivos `.sql` de migracion

---

## Cambios en esta version

Esta version corrige los 4 hallazgos criticos y 5 hallazgos medios del QA v1.0. El modelo de datos, el faseo y el alcance Fase 1 no cambian salvo la incorporacion de `invitacion_profesional` como tabla de seguridad de onboarding.

- **C1 — Forward reference eliminada:** `obtener_mi_organizacion_id()` movida al final de migracion 02, despues de crear `profesional`. Migracion 01 ya no contiene funciones con dependencias a tablas inexistentes.
- **C2 — Modelo de privilegios completo:** Nueva seccion 3 define owners, roles Supabase (`anon`, `authenticated`, `service_role`, `postgres`), `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC` para toda funcion `SECURITY DEFINER`, `GRANT EXECUTE` minimos, y permisos directos por tabla.
- **C3 — SECURITY DEFINER endurecido:** Todas las funciones privilegiadas usan `SET search_path = public, pg_temp`. Referencias a tablas usan nombres calificados (`public.profesional`, `public.paciente`, etc.). QA incluye inspeccion de `pg_proc.proconfig`.
- **C4 — Onboarding seguro:** Nueva tabla `invitacion_profesional` (16 tablas Fase 1). El trigger `auth.users → profesional` valida contra una invitacion existente, no contra metadata cliente. La invitacion es de un solo uso.
- **M1 — Columnas actualizables explicitas:** Nueva seccion 5 declara columnas mutables por tabla y mecanismo exacto (trigger, RPC, `GRANT UPDATE(columna)`).
- **M2 — FORCE RLS y bypass documentado:** Nueva seccion 6 define owner esperado, decision sobre FORCE RLS, y como las RPCs `SECURITY DEFINER` compensan el bypass.
- **M3 — QA hostil ampliado:** Migracion 11 incluye pruebas de roles (`anon`, `authenticated`, `PUBLIC`), signup fraudulento, cross-tenant via RPC, UPDATE por columna, y `SET LOCAL` + UPDATE directo.
- **M4 — SET LOCAL acotado:** El mecanismo `app.rpc_cerrar_arancel` queda acotado por: (a) `authenticated` no tiene `UPDATE` sobre `valor_arancel`, (b) QA prueba que `SET LOCAL` + UPDATE directo falla.
- **M5 — Rollback completo:** Seccion de rollback expandida con checklist de objetos: triggers `auth.users`, funciones, policies, indices, grants, tablas, y verificacion post-rollback.

---

## Resumen ejecutivo

Este documento traduce el blueprint conceptual v1.2 en un plan SQL ejecutable para Fase 1 de Agenda Podologica. Cubre 16 tablas del MVP clinico (15 de dominio + 1 de seguridad de onboarding), organizadas en 11 archivos de migracion granulares y auditables.

**Alcance Fase 1:**
- 16 tablas (Identity, Security, Audit, Clinical, Operational, Configuration, Economic)
- 8 tablas ancla con `UNIQUE (organizacion_id, id)`
- 20+ FK compuestas Tipo A
- 3 triggers Tipo B diferidos
- 4 triggers append-only
- 3 triggers de inmutabilidad parcial
- 1 trigger de inmutabilidad total con excepcion controlada (`valor_arancel`)
- 1 funcion auxiliar central (`obtener_mi_organizacion_id`)
- 1 trigger `auth.users` → `profesional` (con validacion de invitacion)
- 5 RPCs T00 (atomicas con auditoria)
- 4 RPCs controladas
- Modelo completo de privilegios (GRANT/REVOKE por rol)
- Policies RLS completas para las 16 tablas
- Contrato explicito de columnas actualizables por tabla
- Suite QA con pruebas funcionales, hostiles y cross-tenant

**Fuera de alcance explicito:**
- Tablas Fase 2: `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, `fotografia_clinica`, `consentimiento`, `informe_sesion`, `intento_contacto`
- Columnas Fase 2: `relacion_centro_id`, `zona_domiciliaria_id` en tablas Fase 1
- Storage buckets
- SQL ejecutado en Supabase

**Cambio respecto a v1.0:** El conteo pasa de 15 a 16 tablas por la incorporacion de `invitacion_profesional`. Esta tabla no pertenece al dominio clinico ni altera el esquema de v1.2; es un artefacto de seguridad de onboarding requerido por C4 del QA.

---

## 1. Tabla de migraciones propuestas

| # | Archivo | Contenido | Dependencias |
|---|---------|-----------|--------------|
| 01 | `01_extensions_and_helpers.sql` | Extensiones PostgreSQL, funcion helper `set_updated_at()` | Ninguna |
| 02 | `02_identity_and_auth.sql` | `organizacion_clinica`, `invitacion_profesional`, `profesional`, trigger `auth.users` → `profesional`, funcion `obtener_mi_organizacion_id()` | 01 |
| 03 | `03_audit_and_catalogs.sql` | `evento_auditoria_minima`, `tipo_atencion`, `valor_arancel` | 02 |
| 04 | `04_patients_and_clinical_history.sql` | `paciente`, `historia_clinica`, `entrada_clinica` | 02, 03 |
| 05 | `05_schedule_and_followups.sql` | `seguimiento`, `cita`, `transicion_cita`, ALTER `seguimiento.cita_id` | 02, 03, 04 |
| 06 | `06_clinical_care.sql` | `atencion_clinica`, `transicion_atencion` | 02, 03, 04, 05 |
| 07 | `07_billing.sql` | `cobro`, `transicion_pago` | 02, 04, 06 |
| 08 | `08_triggers_and_guards.sql` | Triggers `updated_at`, append-only, inmutabilidad, Tipo B diferidos | 02-07 |
| 09 | `09_rls_policies.sql` | RLS enable, FORCE RLS, todas las policies Fase 1 | 01-08 |
| 10 | `10_rpc_and_privileges.sql` | RPCs T00, RPCs controladas, REVOKE/GRANT completo | 01-09 |
| 11 | `11_qa_phase1.sql` | Tests funcionales + hostiles en transaccion con ROLLBACK | 01-10 |

**Cambios respecto a v1.0:**
- Migracion 01 ya no contiene `obtener_mi_organizacion_id()` (movida a 02, correccion C1).
- Migracion 02 incorpora `invitacion_profesional` y el trigger seguro (correccion C4).
- Migracion 10 renombrada de `10_rpc_phase1.sql` a `10_rpc_and_privileges.sql` para reflejar que incluye GRANT/REVOKE (correccion C2).

**Principio de orden:** Cada archivo puede ejecutarse solo si los anteriores ya se aplicaron. No hay dependencias circulares. No hay forward references. No hay estados intermedios peligrosos dentro de un archivo individual.

---

## 2. Estandar obligatorio para funciones privilegiadas

Toda funcion con `SECURITY DEFINER` en este blueprint debe cumplir los siguientes requisitos. No hay excepciones.

### 2.1 Propiedades obligatorias

```sql
CREATE OR REPLACE FUNCTION public.nombre_funcion(...)
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$ ... $$;
```

- **`SECURITY DEFINER`**: la funcion se ejecuta con privilegios del owner (`postgres`), no del caller.
- **`SET search_path = public, pg_temp`**: previene ataques de shadowing. `pg_temp` se incluye explicitamente para que PostgreSQL no lo resuelva antes que `public`. Sin `pg_temp` en la lista, un atacante podria crear un objeto temporal con el mismo nombre que una tabla referenciada.
- **Nombres calificados**: toda referencia a tabla dentro de la funcion usa el prefijo `public.` (ejemplo: `public.profesional`, `public.paciente`). Esto es defensa en profundidad adicional al `search_path`.
- **Sin SQL dinamico**: no se usa `EXECUTE` con strings construidos a partir de parametros de usuario. La unica excepcion es `validate_cross_tenant_ref()` que usa `TG_ARGV` (valores fijos del trigger, no del usuario) y `format(%I)` para escapar identificadores.

### 2.2 Post-creacion obligatoria

Despues de crear cada funcion `SECURITY DEFINER`:

```sql
REVOKE EXECUTE ON FUNCTION public.nombre_funcion(...) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nombre_funcion(...) TO authenticated;
```

Excepciones:
- `handle_new_user()`: no recibe GRANT a ningun rol de aplicacion. Solo se ejecuta como trigger de `auth.users` por el sistema.
- `set_updated_at()`, `reject_mutation()`, funciones guard: son triggers, no RPCs invocables. No necesitan GRANT explicito a roles.
- `obtener_mi_organizacion_id()`: GRANT a `authenticated` (necesaria para policies RLS).

### 2.3 Verificacion QA

La migracion QA debe inspeccionar `pg_proc.proconfig` para verificar que toda funcion `SECURITY DEFINER` tiene `search_path=public, pg_temp` en su configuracion.

---

## 3. Modelo de privilegios

### 3.1 Roles Supabase

| Rol | Proposito | Acceso esperado en Fase 1 |
|-----|-----------|---------------------------|
| `postgres` | Superusuario / owner de objetos | Owner de todas las tablas y funciones. No se usa desde la aplicacion. |
| `authenticated` | Usuario autenticado via Supabase Auth | SELECT/INSERT/UPDATE segun policies RLS. EXECUTE sobre RPCs autorizadas. |
| `anon` | Usuario no autenticado | SELECT sobre `organizacion_clinica` (solo para flujo de registro). Sin EXECUTE sobre RPCs clinicas. |
| `service_role` | Rol administrativo con bypass RLS | No se usa desde el frontend. Solo para operaciones administrativas server-side (scripts, cron, provisioning). |

### 3.2 Owner de objetos

**Todas las tablas y funciones son propiedad de `postgres`.**

En Supabase, las migraciones se ejecutan como `postgres`. Las funciones `SECURITY DEFINER` heredan los privilegios de `postgres` al ejecutarse. Esto es necesario para que las RPCs puedan escribir en tablas donde `authenticated` no tiene INSERT/UPDATE directo.

### 3.3 Permisos sobre tablas

Los permisos de tabla se configuran en migracion 10, despues de crear las policies RLS. El patron por tabla:

**Tablas con acceso directo para `authenticated` (filtrado por RLS):**

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `organizacion_clinica` | si | no | si (via RLS) | no |
| `profesional` | si | no | si (via RLS, solo propio) | no |
| `invitacion_profesional` | no | no | no | no |
| `evento_auditoria_minima` | si | no | no | no |
| `tipo_atencion` | si | si | si | no |
| `valor_arancel` | si | si | no | no |
| `paciente` | si | si | si | no |
| `historia_clinica` | si | no | si (solo `resumen_general`) | no |
| `entrada_clinica` | si | si | si | no |
| `seguimiento` | si | si | si | no |
| `cita` | si | si | si | no |
| `transicion_cita` | si | no | no | no |
| `atencion_clinica` | si | si | si | no |
| `transicion_atencion` | si | no | no | no |
| `cobro` | si | si | no | no |
| `transicion_pago` | si | no | no | no |

**DELETE nunca** para ninguna tabla. Politica global del sistema.

**Tablas sin acceso directo para `authenticated`:**
- `invitacion_profesional`: solo lectura/escritura via `service_role` o funciones `SECURITY DEFINER` del trigger.
- `evento_auditoria_minima`: INSERT solo via RPCs T00.
- `transicion_atencion`, `transicion_cita`, `transicion_pago`: INSERT solo via RPCs.

### 3.4 Permisos sobre funciones

```sql
-- Revocar EXECUTE de PUBLIC para TODAS las funciones SECURITY DEFINER
REVOKE EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.crear_paciente(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_atencion(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_atencion(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.modificar_estado_cita(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agregar_entrada_clinica(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_pago(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.anular_cobro(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.archivar_paciente(...) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(...) FROM PUBLIC;

-- Conceder EXECUTE solo a authenticated para RPCs invocables
GRANT EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_paciente(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_atencion(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_atencion(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modificar_estado_cita(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agregar_entrada_clinica(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_pago(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_cobro(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archivar_paciente(...) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_arancel(...) TO authenticated;

-- handle_new_user: NO recibe GRANT. Solo se ejecuta como trigger.
-- set_updated_at, reject_mutation, guard_*: triggers, no RPCs.
-- validate_cross_tenant_ref: trigger, no RPC.
```

### 3.5 Permisos para `anon`

```sql
-- anon solo puede leer organizacion_clinica (flujo de registro)
GRANT SELECT ON public.organizacion_clinica TO anon;

-- anon NO ejecuta RPCs clinicas
-- (ya cubierto por REVOKE FROM PUBLIC + no GRANT TO anon)
```

### 3.6 `service_role`

`service_role` bypasea RLS por diseno de Supabase. No se expone al frontend. Se usa solo para:
- Creacion inicial de `organizacion_clinica` (provisioning administrativo).
- Creacion de `invitacion_profesional` (flujo de invitacion server-side).
- Reconciliacion de `auth.users` ↔ `profesional`.

El frontend nunca envia la `service_role` key. Solo existe en variables de entorno del servidor.

---

## 4. Migraciones — DDL de tablas

### Migracion 01 — Extensiones y helpers

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
```

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$;
```

**Cambio vs v1.0:** `obtener_mi_organizacion_id()` ya no esta aqui. Movida a migracion 02.

---

### Migracion 02 — Identity, onboarding y auth

#### Tabla: `organizacion_clinica`

```sql
CREATE TABLE public.organizacion_clinica (
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

**Sin `UNIQUE (organizacion_id, id)`.** Raiz tenant.

#### Tabla: `invitacion_profesional` (NUEVA — correccion C4)

```sql
CREATE TABLE public.invitacion_profesional (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  email           TEXT NOT NULL,
  nombre_completo TEXT NOT NULL,
  nombre_para_documentos TEXT NOT NULL,
  token           UUID NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
  estado          TEXT NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente', 'consumida', 'expirada', 'revocada')),
  creado_por      UUID,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  consumida_en    TIMESTAMPTZ,

  UNIQUE (email, organizacion_id)
);
```

**Proposito:** Tabla de seguridad de onboarding. Un administrador o el sistema crea una invitacion antes de que un profesional pueda registrarse. El trigger de `auth.users` valida contra esta tabla en lugar de confiar en metadata cliente.

**Caracteristicas:**
- `token` UUID unico: identificador de la invitacion que se pasa al flujo de registro.
- `estado = 'pendiente'`: solo las invitaciones pendientes pueden ser consumidas.
- `UNIQUE (email, organizacion_id)`: un email solo puede tener una invitacion activa por organizacion.
- `creado_por`: UUID del profesional que creo la invitacion (NULL para la primera invitacion de provisioning).
- Sin `UNIQUE (organizacion_id, id)`: no es tabla ancla para FK compuestas.

**Flujo de onboarding corregido:**
1. Administrador crea `organizacion_clinica` via `service_role`.
2. Administrador crea `invitacion_profesional` con email, nombre y token.
3. El profesional recibe el token (via email, enlace, etc.).
4. El profesional se registra en Supabase Auth pasando `token` en `raw_user_meta_data`.
5. El trigger `handle_new_user()` busca la invitacion por token + email.
6. Si la invitacion es valida y pendiente: crea `profesional`, marca invitacion como `consumida`.
7. Si no existe o no es valida: el INSERT en `auth.users` revierte completo.

**RLS:** No se concede acceso a `authenticated` ni a `anon`. Solo `service_role` y funciones `SECURITY DEFINER` pueden leer/escribir.

#### Tabla: `profesional`

```sql
CREATE TABLE public.profesional (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id          UUID NOT NULL UNIQUE
                        REFERENCES auth.users(id) ON DELETE RESTRICT,
  organizacion_id       UUID NOT NULL
                        REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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

#### Trigger: `auth.users` → `profesional` (REDISEÑADO — correccion C4)

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_token UUID;
  v_invitacion RECORD;
BEGIN
  -- Extraer token de metadata
  v_token := (NEW.raw_user_meta_data->>'token')::UUID;

  IF v_token IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: token de invitacion requerido';
  END IF;

  -- Buscar invitacion valida por token + email
  SELECT id, organizacion_id, nombre_completo, nombre_para_documentos, estado
  INTO v_invitacion
  FROM public.invitacion_profesional
  WHERE token = v_token
    AND email = NEW.email
    AND estado = 'pendiente';

  IF v_invitacion IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: invitacion no encontrada, expirada o email no coincide';
  END IF;

  -- Crear profesional con datos de la invitacion (no del cliente)
  INSERT INTO public.profesional (
    auth_user_id,
    organizacion_id,
    nombre_completo,
    email,
    nombre_para_documentos
  ) VALUES (
    NEW.id,
    v_invitacion.organizacion_id,
    v_invitacion.nombre_completo,
    NEW.email,
    v_invitacion.nombre_para_documentos
  );

  -- Marcar invitacion como consumida (un solo uso)
  UPDATE public.invitacion_profesional SET
    estado = 'consumida',
    consumida_en = now()
  WHERE id = v_invitacion.id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

**Diferencias criticas vs v1.0:**
- El trigger ya no lee `organizacion_id` ni `nombre_completo` de metadata cliente.
- Los datos del profesional provienen de `invitacion_profesional`, creada previamente por un administrador.
- Solo `token` viene de metadata (para vincular la invitacion).
- El email debe coincidir entre `auth.users.email` y `invitacion_profesional.email`.
- La invitacion debe estar en estado `pendiente`.
- Despues de usar, la invitacion queda `consumida` — un solo uso.
- Un atacante que conozca un `organizacion_id` pero no tenga invitacion valida no puede autoasociarse.

#### Funcion: `obtener_mi_organizacion_id()` (MOVIDA — correccion C1)

```sql
CREATE OR REPLACE FUNCTION public.obtener_mi_organizacion_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT organizacion_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$;
```

**Cambio vs v1.0:** Ahora se crea al final de migracion 02, despues de `profesional`. No hay forward reference. `search_path` incluye `pg_temp`. Referencia calificada `public.profesional`.

---

### Migracion 03 — Auditoria y catalogos

#### Tabla: `evento_auditoria_minima`

```sql
CREATE TABLE public.evento_auditoria_minima (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id   UUID NOT NULL
                    REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

**Append-only. Sin `actualizado_en`. Referencia polimorfica Tipo C. Sin INSERT directo para `authenticated`.**

#### Tabla: `tipo_atencion`

```sql
CREATE TABLE public.tipo_atencion (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  nombre          TEXT NOT NULL,
  descripcion     TEXT,
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo', 'inactivo')),
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ,

  UNIQUE (organizacion_id, id)
);

CREATE UNIQUE INDEX uq_tipo_atencion_nombre_activo
  ON public.tipo_atencion (organizacion_id, nombre)
  WHERE estado = 'activo';
```

#### Tabla: `valor_arancel`

```sql
CREATE TABLE public.valor_arancel (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo_atencion_id UUID NOT NULL,
  organizacion_id  UUID NOT NULL
                   REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  modalidad        TEXT NOT NULL
                   CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  valor            DECIMAL NOT NULL CHECK (valor >= 0),
  vigente_desde    DATE NOT NULL,
  vigente_hasta    DATE,
  configurado_por  UUID NOT NULL,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, configurado_por)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_valor_arancel_vigente
  ON public.valor_arancel (tipo_atencion_id, organizacion_id, modalidad)
  WHERE vigente_hasta IS NULL;
```

---

### Migracion 04 — Pacientes e historia clinica

#### Tabla: `paciente`

```sql
CREATE TABLE public.paciente (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_paciente_rut_org
  ON public.paciente (organizacion_id, rut)
  WHERE rut IS NOT NULL;
```

#### Tabla: `historia_clinica`

```sql
CREATE TABLE public.historia_clinica (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  paciente_id     UUID NOT NULL UNIQUE,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  resumen_general TEXT,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT
);
```

#### Tabla: `entrada_clinica`

```sql
CREATE TABLE public.entrada_clinica (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  historia_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.historia_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, registrado_por)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

---

### Migracion 05 — Agenda y seguimientos

#### Tabla: `seguimiento`

```sql
CREATE TABLE public.seguimiento (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

#### Tabla: `cita`

```sql
CREATE TABLE public.cita (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id             UUID NOT NULL
                              REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_anterior_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, seguimiento_id)
    REFERENCES public.seguimiento(organizacion_id, id) ON DELETE RESTRICT
);
```

#### ALTER: `seguimiento.cita_id`

```sql
ALTER TABLE public.seguimiento
  ADD CONSTRAINT fk_seguimiento_cita
  FOREIGN KEY (organizacion_id, cita_id)
  REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT;
```

#### Tabla: `transicion_cita`

```sql
CREATE TABLE public.transicion_cita (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cita_id         UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  motivo          TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

---

### Migracion 06 — Atencion clinica

#### Tabla: `atencion_clinica`

```sql
CREATE TABLE public.atencion_clinica (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id             UUID NOT NULL
                              REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT
);
```

#### Tabla: `transicion_atencion`

```sql
CREATE TABLE public.transicion_atencion (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  atencion_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id      UUID NOT NULL,
  estado_anterior     TEXT NOT NULL,
  estado_nuevo        TEXT NOT NULL,
  motivo              TEXT,
  ocurrido_en         TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, atencion_clinica_id)
    REFERENCES public.atencion_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

---

### Migracion 07 — Facturacion

#### Tabla: `cobro`

```sql
CREATE TABLE public.cobro (
  id                            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizacion_id               UUID NOT NULL
                                REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
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
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

#### Tabla: `transicion_pago`

```sql
CREATE TABLE public.transicion_pago (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cobro_id        UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  notas           TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cobro_id)
    REFERENCES public.cobro(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);
```

---

## 5. Contrato de columnas actualizables por tabla (correccion M1)

RLS filtra filas, no columnas. Esta seccion define exactamente que columnas puede modificar un UPDATE, y mediante que mecanismo se protegen las demas.

### 5.1 Tabla de contratos

| Tabla | Columnas actualizables | Mecanismo de proteccion de las demas | Via de cambio |
|-------|----------------------|--------------------------------------|---------------|
| `organizacion_clinica` | `nombre_legal`, `nombre_fantasia`, `email`, `telefono`, `direccion`, `zona_horaria`, `duracion_cita_defecto_minutos`, `estado` | Sin trigger adicional en Fase 1 (org es gestionada por admin) | UPDATE directo (RLS) |
| `profesional` | `nombre_completo`, `nombre_para_documentos`, `especialidad`, `numero_colegiado` | Trigger: protege `auth_user_id`, `organizacion_id`, `email`, `estado`, `creado_en` | UPDATE directo (RLS, solo propio perfil) |
| `invitacion_profesional` | Ninguna por `authenticated` | Sin policy UPDATE para `authenticated` | Solo `service_role` o trigger interno |
| `evento_auditoria_minima` | Ninguna | Trigger append-only | Ninguna (append-only) |
| `tipo_atencion` | `nombre`, `descripcion`, `estado` | Trigger: protege `organizacion_id`, `creado_en` | UPDATE directo (RLS) |
| `valor_arancel` | Solo `vigente_hasta` (NULL→fecha) | Trigger inmutabilidad total + flag RPC | Solo via RPC `cerrar_arancel` |
| `paciente` | `nombre_completo`, `rut`, `fecha_nacimiento`, `telefono_principal`, `telefono_alternativo`, `email`, `direccion`, `origen_categoria`, `notas` | Trigger: protege `organizacion_id`, `creado_por`, `creado_en`. Estado: solo via RPC `archivar_paciente` | UPDATE directo (RLS, no archivado). Estado via RPC. |
| `historia_clinica` | Solo `resumen_general` | Trigger: protege `paciente_id`, `organizacion_id`, `creado_en` | UPDATE directo (RLS) |
| `entrada_clinica` | `estado`, `notas_adicionales` | Trigger: protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en` | UPDATE directo (RLS) |
| `seguimiento` | `tipo`, `urgencia`, `estado`, `notas`, `fecha_limite`, `resuelto_en`, `cita_id`, `atencion_clinica_id` | Trigger: protege `organizacion_id`, `paciente_id`, `profesional_id`, `origen`, `creado_en` | UPDATE directo (RLS, no completado/descartado) |
| `cita` | `tipo_atencion_id`, `tipo_atencion_nombre_snapshot`, `inicio`, `duracion_minutos`, `estado`, `motivo_cancelacion`, `notas`, `seguimiento_id`, `atencion_clinica_id` | Trigger: protege `organizacion_id`, `paciente_id`, `profesional_id`, `cita_anterior_id`, `creado_en`. Estado: preferir RPC `modificar_estado_cita` | UPDATE directo (RLS, no terminal). Estado via RPC. |
| `atencion_clinica` | Mientras `registrada`: `tipo_atencion_id`, `tipo_atencion_nombre_snapshot`, `tratamiento`, `hallazgos`, `notas_clinicas`, `indicaciones`, `cita_id` | Trigger: cuando `cerrada`, protege todas las columnas clinicas + `paciente_id`, `profesional_id`, `modalidad`, `fecha_cierre` | UPDATE directo solo mientras `registrada` (RLS). Cierre via RPC. |
| `transicion_atencion` | Ninguna | Trigger append-only | Ninguna |
| `transicion_cita` | Ninguna | Trigger append-only | Ninguna |
| `cobro` | Solo `estado_pago`, `medio_pago`, `fecha_pago`, `motivo_anulacion` | Trigger: protege snapshot (`monto`, `tipo_atencion_nombre_snapshot`, `modalidad`, `recargo_zona_snapshot`, `valor_acordado_centro_snapshot`, `concepto`, `categoria_origen`, `registrado_en`) | Solo via RPCs `registrar_pago`, `anular_cobro` |
| `transicion_pago` | Ninguna | Trigger append-only | Ninguna |

### 5.2 Triggers de proteccion de columnas nuevos en v1.1

**`profesional` — proteccion de columnas de identidad:**

```sql
CREATE OR REPLACE FUNCTION public.guard_profesional_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.auth_user_id IS DISTINCT FROM NEW.auth_user_id
     OR OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.email IS DISTINCT FROM NEW.email
     OR OLD.estado IS DISTINCT FROM NEW.estado
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'profesional: columnas de identidad no pueden modificarse via UPDATE directo';
  END IF;
  RETURN NEW;
END;
$$;
```

**`historia_clinica` — proteccion de vinculo paciente:**

```sql
CREATE OR REPLACE FUNCTION public.guard_historia_clinica_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.paciente_id IS DISTINCT FROM NEW.paciente_id
     OR OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'historia_clinica: columnas de vinculo no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;
```

**`paciente` — proteccion de columnas de sistema:**

```sql
CREATE OR REPLACE FUNCTION public.guard_paciente_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.creado_por IS DISTINCT FROM NEW.creado_por
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'paciente: columnas de sistema no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;
```

**`seguimiento` — proteccion de columnas de origen:**

```sql
CREATE OR REPLACE FUNCTION public.guard_seguimiento_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.paciente_id IS DISTINCT FROM NEW.paciente_id
     OR OLD.profesional_id IS DISTINCT FROM NEW.profesional_id
     OR OLD.origen IS DISTINCT FROM NEW.origen
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'seguimiento: columnas de origen no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;
```

**`cita` — proteccion de columnas de vinculo:**

```sql
CREATE OR REPLACE FUNCTION public.guard_cita_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.paciente_id IS DISTINCT FROM NEW.paciente_id
     OR OLD.profesional_id IS DISTINCT FROM NEW.profesional_id
     OR OLD.cita_anterior_id IS DISTINCT FROM NEW.cita_anterior_id
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'cita: columnas de vinculo no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;
```

Estos triggers se crean en migracion 08 junto con los triggers existentes de v1.0.

---

## 6. FORCE RLS, owner y bypass (correccion M2)

### 6.1 Owner de tablas y funciones

Todas las tablas y funciones son propiedad de `postgres` (el usuario con el que Supabase ejecuta migraciones). Esto no cambia.

### 6.2 RLS para `authenticated`

Se habilita `ROW LEVEL SECURITY` en todas las 16 tablas. Se aplica `FORCE ROW LEVEL SECURITY` en las tablas que el owner (`postgres`) no deberia bypassar accidentalmente desde migraciones u operaciones manuales:

```sql
ALTER TABLE public.invitacion_profesional FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evento_auditoria_minima FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_atencion FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_cita FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_pago FORCE ROW LEVEL SECURITY;
```

**Razon:** Estas son las tablas mas sensibles (invitaciones, auditoria, logs de transicion). `FORCE RLS` asegura que incluso el owner debe cumplir las policies al hacer queries directos. Las demas tablas no usan `FORCE` porque el owner necesita acceso completo para mantenimiento y provisioning.

### 6.3 Bypass de RLS por RPCs `SECURITY DEFINER`

Las RPCs `SECURITY DEFINER` se ejecutan como `postgres` (el owner). Por lo tanto, **bypassan RLS por defecto** (excepto en tablas con `FORCE RLS`).

Esto es **intencional y necesario** porque:
- Las RPCs T00 necesitan escribir en `evento_auditoria_minima`, donde `authenticated` no tiene INSERT.
- Las RPCs controladas necesitan UPDATE en tablas donde `authenticated` no tiene UPDATE directo (`cobro`, `valor_arancel`).

**Compensacion:** Cada RPC implementa validaciones manuales equivalentes a RLS:
1. Obtiene `organizacion_id` del profesional autenticado via `auth.uid()`.
2. Valida que la entidad referenciada pertenece a esa organizacion.
3. Valida restricciones de estado (no modificar entidades cerradas/archivadas).
4. Solo entonces ejecuta la operacion.

Estas validaciones se prueban en la suite QA hostil (migracion 11).

Para tablas con `FORCE RLS`, las RPCs `SECURITY DEFINER` tambien estan sujetas a las policies. Dado que las policies de estas tablas solo permiten SELECT (para `authenticated`), las RPCs deben usar `INSERT` directamente como `postgres` — lo cual funciona porque `FORCE RLS` aplica las policies del owner, y las policies de INSERT de estas tablas estan ausentes para `authenticated` pero el owner es `postgres` que tiene permisos implicitos. **Nota:** Si `FORCE RLS` bloquea los INSERTs de las RPCs en estas tablas, la alternativa es (a) no usar `FORCE RLS` en esas tablas y confiar en los triggers append-only, o (b) crear policies INSERT para el owner. Esto debe verificarse en el dry-run.

---

## 7. Migracion 08 — Triggers y guards

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

**Tablas sin `updated_at`** (append-only o snapshot inmutable): `invitacion_profesional` (mutada solo por trigger interno), `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`, `valor_arancel`, `cobro`, `historia_clinica`.

### 8.2 Triggers append-only (BEFORE UPDATE OR DELETE)

```sql
CREATE OR REPLACE FUNCTION public.reject_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Tabla % es append-only: no se permite % de registros',
    TG_TABLE_NAME, TG_OP;
END;
$$;
```

Tablas protegidas: `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago`.

### 8.3 Triggers de inmutabilidad (existentes en v1.0)

Mismas funciones que v1.0, sin cambios:

- `guard_entrada_clinica_immutable()` — protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en`
- `guard_atencion_clinica_immutable()` — protege columnas clinicas cuando `OLD.estado = 'cerrada'`
- `guard_cobro_snapshot_immutable()` — protege todas las columnas snapshot
- `guard_valor_arancel_immutable()` — inmutabilidad total + excepcion controlada `vigente_hasta` via `SET LOCAL`

### 8.4 Triggers de proteccion de columnas (NUEVOS en v1.1 — correccion M1)

Se agregan los triggers definidos en seccion 5.2:

- `guard_profesional_immutable()` → `trg_profesional_immutable`
- `guard_historia_clinica_immutable()` → `trg_historia_clinica_immutable`
- `guard_paciente_immutable()` → `trg_paciente_immutable`
- `guard_seguimiento_immutable()` → `trg_seguimiento_immutable`
- `guard_cita_immutable()` → `trg_cita_immutable`

### 8.5 Triggers Tipo B diferidos (cross-context)

Misma funcion generica `validate_cross_tenant_ref()` de v1.0, con una nota adicional:

**Nota sobre SQL dinamico (correccion C3):** Esta funcion usa `EXECUTE format(...)` con `TG_ARGV` (valores fijos del trigger, no del usuario) y `%I` para escapar identificadores. No usa parametros de usuario en la construccion del SQL. Esto es la unica excepcion justificada al estandar de "sin SQL dinamico".

Aplicacion:
- `trg_seguimiento_validate_atencion` → `seguimiento.atencion_clinica_id`
- `trg_cita_validate_atencion` → `cita.atencion_clinica_id`
- `trg_cobro_validate_atencion` → `cobro.atencion_clinica_id`

---

## 8. Migracion 09 — Policies RLS

### Habilitacion de RLS

```sql
ALTER TABLE public.organizacion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitacion_profesional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profesional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_auditoria_minima ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipo_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.valor_arancel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paciente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historia_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrada_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seguimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atencion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cobro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_pago ENABLE ROW LEVEL SECURITY;

-- FORCE RLS en tablas sensibles (correccion M2)
ALTER TABLE public.invitacion_profesional FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evento_auditoria_minima FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_atencion FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_cita FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_pago FORCE ROW LEVEL SECURITY;
```

### Policies por tabla

Mismas policies que v1.0 para las 15 tablas originales, con una adicion:

#### `invitacion_profesional` (NUEVA)

```sql
-- Sin policies para authenticated ni anon.
-- Solo service_role y SECURITY DEFINER pueden acceder.
```

**No se crean policies.** Con RLS habilitado y sin policies, ningun rol de aplicacion puede acceder a esta tabla. Solo `service_role` (que bypasea RLS) y funciones `SECURITY DEFINER` (que bypassan RLS como owner) pueden leer/escribir.

#### Policies restantes

Sin cambios respecto a v1.0 para: `organizacion_clinica`, `profesional`, `evento_auditoria_minima`, `tipo_atencion`, `valor_arancel`, `paciente`, `historia_clinica`, `entrada_clinica`, `seguimiento`, `cita`, `transicion_cita`, `atencion_clinica`, `transicion_atencion`, `cobro`, `transicion_pago`.

---

## 9. Migracion 10 — RPCs y privilegios

### 10.1 Convenciones de todas las RPCs (ACTUALIZADO — correcciones C2, C3)

- **`SECURITY DEFINER`**: ejecuta con privilegios del owner (`postgres`).
- **`SET search_path = public, pg_temp`**: previene shadowing (correccion C3).
- **Nombres calificados**: toda referencia a tabla usa `public.tabla` (correccion C3).
- **Transaccional**: toda la RPC es una transaccion.
- **Validaciones de tenant**: cada RPC verifica organizacion antes de operar.
- **Post-creacion**: `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` (correccion C2).

### 10.2 RPCs T00

**`crear_paciente`** — misma logica que v1.0, con nombres calificados (`public.profesional`, `public.paciente`, `public.historia_clinica`, `public.evento_auditoria_minima`) y `SET search_path = public, pg_temp`.

**`registrar_atencion`** — misma logica que v1.0, con nombres calificados y search_path corregido.

**`cerrar_atencion`** — misma logica que v1.0, con nombres calificados y search_path corregido.

**`modificar_estado_cita`** — misma logica que v1.0, con nombres calificados y search_path corregido.

**`agregar_entrada_clinica`** — misma logica que v1.0, con nombres calificados y search_path corregido.

**Patron comun actualizado para cada RPC T00:**

```sql
CREATE OR REPLACE FUNCTION public.nombre_rpc(...)
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  -- ... logica especifica de la RPC usando public.tabla ...
END;
$$;

REVOKE EXECUTE ON FUNCTION public.nombre_rpc(...) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nombre_rpc(...) TO authenticated;
```

### 10.3 RPCs controladas

**`registrar_pago`** — misma logica que v1.0, con correcciones C2/C3.

**`anular_cobro`** — misma logica que v1.0, con correcciones C2/C3.

**`archivar_paciente`** — misma logica que v1.0, con correcciones C2/C3.

**`cerrar_arancel`** — misma logica que v1.0, con correcciones C2/C3/M4:

```sql
CREATE OR REPLACE FUNCTION public.cerrar_arancel(
  p_valor_arancel_id UUID,
  p_vigente_hasta DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_vigente_hasta_actual DATE;
BEGIN
  SELECT organizacion_id INTO v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT vigente_hasta INTO v_vigente_hasta_actual
  FROM public.valor_arancel
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Valor de arancel no encontrado en esta organizacion';
  END IF;

  IF v_vigente_hasta_actual IS NOT NULL THEN
    RAISE EXCEPTION 'Este arancel ya tiene vigencia cerrada';
  END IF;

  SET LOCAL app.rpc_cerrar_arancel = 'true';

  UPDATE public.valor_arancel SET
    vigente_hasta = p_vigente_hasta
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) TO authenticated;
```

**Acotacion de `SET LOCAL` (correccion M4):**

El mecanismo `SET LOCAL app.rpc_cerrar_arancel = 'true'` queda seguro por la combinacion de:
1. `authenticated` no tiene policy UPDATE sobre `valor_arancel` → no puede hacer UPDATE directo.
2. `authenticated` no tiene GRANT de UPDATE sobre la tabla `valor_arancel`.
3. Aunque un atacante ejecute `SET LOCAL app.rpc_cerrar_arancel = 'true'` en una sesion, sin el UPDATE grant, la operacion falla antes de llegar al trigger.
4. La suite QA prueba explicitamente este escenario: `SET LOCAL` + UPDATE directo → ERROR.

### 10.4 Bloque completo de REVOKE/GRANT (correccion C2)

Al final de migracion 10, despues de crear todas las RPCs:

```sql
-- === REVOKE EXECUTE de PUBLIC para todas las funciones SECURITY DEFINER ===

REVOKE EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.archivar_paciente(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) FROM PUBLIC;

-- === GRANT EXECUTE a authenticated para RPCs invocables ===

GRANT EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archivar_paciente(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) TO authenticated;

-- === Permisos de tabla: REVOKE UPDATE donde no debe haber ===

REVOKE UPDATE ON public.valor_arancel FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.evento_auditoria_minima FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.transicion_atencion FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.transicion_cita FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.transicion_pago FROM authenticated;
REVOKE ALL ON public.invitacion_profesional FROM authenticated;
REVOKE ALL ON public.invitacion_profesional FROM anon;
REVOKE UPDATE ON public.cobro FROM authenticated;

-- === Permisos para anon ===

GRANT SELECT ON public.organizacion_clinica TO anon;
```

---

## 10. Migracion 11 — QA Fase 1 (AMPLIADA — correcciones M3, M4)

### Estrategia de QA

Todos los tests se ejecutan dentro de una transaccion con `ROLLBACK`. No dejan datos permanentes.

### 11.1 Tests de estructura

```
- Verificar que las 16 tablas existen (15 dominio + 1 onboarding)
- Verificar que UNIQUE (organizacion_id, id) existe en las 8 tablas ancla
- Verificar que los 3 indices parciales unicos existen
- Verificar que RLS esta habilitado en las 16 tablas
- Verificar que FORCE RLS esta habilitado en las 5 tablas sensibles
- Verificar que las policies existen por tabla
- Verificar que los triggers existen por tabla
- Verificar que CHECK constraints existen en todos los campos de estado/tipo
```

### 11.2 Tests de integridad tenant (FK compuestas)

Sin cambios respecto a v1.0. Cross-tenant negativo para cada tabla ancla + Tipo B.

### 11.3 Tests de append-only

Sin cambios respecto a v1.0.

### 11.4 Tests de inmutabilidad

Sin cambios respecto a v1.0, mas:

```
-- NUEVOS: Tests de proteccion por columna (correccion M1)
-- profesional: intentar UPDATE de organizacion_id → ERROR
-- profesional: intentar UPDATE de auth_user_id → ERROR
-- profesional: intentar UPDATE de email → ERROR
-- profesional: UPDATE de nombre_completo → OK
-- historia_clinica: intentar UPDATE de paciente_id → ERROR
-- historia_clinica: UPDATE de resumen_general → OK
-- paciente: intentar UPDATE de organizacion_id → ERROR
-- paciente: intentar UPDATE de creado_por → ERROR
-- paciente: UPDATE de nombre_completo → OK
-- seguimiento: intentar UPDATE de paciente_id → ERROR
-- seguimiento: UPDATE de urgencia → OK
-- cita: intentar UPDATE de paciente_id → ERROR
-- cita: UPDATE de notas → OK
```

### 11.5 Tests de RPCs T00 y controladas

Sin cambios respecto a v1.0.

### 11.6 Tests de RLS

Sin cambios respecto a v1.0.

### 11.7 Tests de seguridad hostil (NUEVO — correccion M3)

```
-- === Roles y privilegios ===

-- anon no puede ejecutar crear_paciente
SET ROLE anon;
SELECT public.crear_paciente('Test'); -- Esperar: ERROR permission denied
RESET ROLE;

-- anon no puede ejecutar registrar_atencion
SET ROLE anon;
SELECT public.registrar_atencion(uuid_generate_v4()); -- Esperar: ERROR
RESET ROLE;

-- Repetir para cada RPC clinica con rol anon → ERROR

-- authenticated puede ejecutar crear_paciente (con sesion valida)
-- (se prueba en 11.5 como test funcional)

-- PUBLIC no conserva EXECUTE sobre funciones privilegiadas
SELECT COUNT(*) FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.prosecdef = true
    AND has_function_privilege('PUBLIC', p.oid, 'EXECUTE');
-- Esperar: 0

-- === search_path de funciones privilegiadas (correccion C3) ===

SELECT p.proname, p.proconfig
FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true;
-- Verificar que TODAS contienen 'search_path=public, pg_temp' en proconfig

-- === Signup fraudulento (correccion C4) ===

-- Intentar signup sin token → ERROR (trigger rechaza)
-- Intentar signup con token invalido → ERROR
-- Intentar signup con token valido pero email diferente → ERROR
-- Intentar signup con invitacion ya consumida → ERROR
-- Signup con token valido + email correcto → OK, invitacion queda 'consumida'
-- Intentar reusar el mismo token → ERROR

-- === Cross-tenant via RPC (correccion M3) ===

-- Profesional de org A ejecuta crear_paciente → paciente en org A
-- Profesional de org A ejecuta registrar_atencion con paciente de org B → ERROR
-- Profesional de org A ejecuta cerrar_atencion con atencion de org B → ERROR
-- Profesional de org A ejecuta modificar_estado_cita con cita de org B → ERROR
-- Profesional de org A ejecuta registrar_pago con cobro de org B → ERROR

-- === SET LOCAL + UPDATE directo (correccion M4) ===

SET ROLE authenticated;
-- Simular sesion de un profesional valido
SET LOCAL app.rpc_cerrar_arancel = 'true';
UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31' WHERE id = '...';
-- Esperar: ERROR (authenticated no tiene UPDATE sobre valor_arancel)
RESET ROLE;

-- === service_role no expuesto ===

-- Verificar que ninguna policy referencia service_role
-- Verificar que la app key de service_role no esta en .env accesible al frontend
-- (verificacion manual, no SQL)
```

---

## 11. Indices de Fase 1

Sin cambios respecto a v1.0 para las 15 tablas originales. Se agrega un indice para `invitacion_profesional`:

| Tabla | Indice | Tipo |
|-------|--------|------|
| `invitacion_profesional` | `(token) WHERE estado = 'pendiente'` | parcial btree |
| `invitacion_profesional` | `(email, organizacion_id)` | unique (inline) |

Indices restantes identicos a v1.0.

---

## 12. Rollback logico completo (correccion M5)

### 12.1 Orden de rollback

El rollback de Fase 1 debe ejecutarse en orden inverso estricto. No basta con `DROP TABLE`. Debe cubrir todos los objetos creados.

### 12.2 Checklist de rollback

```sql
-- === Paso 1: Revocar grants ===
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- === Paso 2: Drop RPCs (funciones invocables) ===
DROP FUNCTION IF EXISTS public.cerrar_arancel(UUID, DATE);
DROP FUNCTION IF EXISTS public.archivar_paciente(UUID);
DROP FUNCTION IF EXISTS public.anular_cobro(UUID, TEXT);
DROP FUNCTION IF EXISTS public.registrar_pago(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.modificar_estado_cita(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.cerrar_atencion(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

-- === Paso 3: Drop policies RLS ===
-- (para cada tabla, drop todas las policies)
-- Patron: DROP POLICY IF EXISTS nombre_policy ON public.tabla;
-- Cubrir las 16 tablas y todas sus policies

-- === Paso 4: Deshabilitar RLS ===
-- (para cada tabla)
-- ALTER TABLE public.tabla DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.tabla NO FORCE ROW LEVEL SECURITY;

-- === Paso 5: Drop triggers de proteccion ===
-- Triggers append-only
DROP TRIGGER IF EXISTS trg_evento_auditoria_append_only ON public.evento_auditoria_minima;
DROP TRIGGER IF EXISTS trg_transicion_atencion_append_only ON public.transicion_atencion;
DROP TRIGGER IF EXISTS trg_transicion_cita_append_only ON public.transicion_cita;
DROP TRIGGER IF EXISTS trg_transicion_pago_append_only ON public.transicion_pago;

-- Triggers de inmutabilidad
DROP TRIGGER IF EXISTS trg_entrada_clinica_immutable ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_atencion_clinica_immutable ON public.atencion_clinica;
DROP TRIGGER IF EXISTS trg_cobro_snapshot_immutable ON public.cobro;
DROP TRIGGER IF EXISTS trg_valor_arancel_immutable ON public.valor_arancel;
DROP TRIGGER IF EXISTS trg_profesional_immutable ON public.profesional;
DROP TRIGGER IF EXISTS trg_historia_clinica_immutable ON public.historia_clinica;
DROP TRIGGER IF EXISTS trg_paciente_immutable ON public.paciente;
DROP TRIGGER IF EXISTS trg_seguimiento_immutable ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_immutable ON public.cita;

-- Triggers Tipo B
DROP TRIGGER IF EXISTS trg_seguimiento_validate_atencion ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_validate_atencion ON public.cita;
DROP TRIGGER IF EXISTS trg_cobro_validate_atencion ON public.cobro;

-- Triggers updated_at (8 tablas)
DROP TRIGGER IF EXISTS trg_organizacion_clinica_updated_at ON public.organizacion_clinica;
DROP TRIGGER IF EXISTS trg_profesional_updated_at ON public.profesional;
DROP TRIGGER IF EXISTS trg_tipo_atencion_updated_at ON public.tipo_atencion;
DROP TRIGGER IF EXISTS trg_paciente_updated_at ON public.paciente;
DROP TRIGGER IF EXISTS trg_entrada_clinica_updated_at ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_seguimiento_updated_at ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_updated_at ON public.cita;
DROP TRIGGER IF EXISTS trg_atencion_clinica_updated_at ON public.atencion_clinica;

-- === Paso 6: Drop trigger de auth.users ===
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- === Paso 7: Drop funciones de soporte ===
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.obtener_mi_organizacion_id();
DROP FUNCTION IF EXISTS public.set_updated_at();
DROP FUNCTION IF EXISTS public.reject_mutation();
DROP FUNCTION IF EXISTS public.guard_entrada_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_atencion_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_cobro_snapshot_immutable();
DROP FUNCTION IF EXISTS public.guard_valor_arancel_immutable();
DROP FUNCTION IF EXISTS public.guard_profesional_immutable();
DROP FUNCTION IF EXISTS public.guard_historia_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_paciente_immutable();
DROP FUNCTION IF EXISTS public.guard_seguimiento_immutable();
DROP FUNCTION IF EXISTS public.guard_cita_immutable();
DROP FUNCTION IF EXISTS public.validate_cross_tenant_ref();

-- === Paso 8: Drop tablas en orden inverso de dependencias ===
DROP TABLE IF EXISTS public.transicion_pago;
DROP TABLE IF EXISTS public.cobro;
DROP TABLE IF EXISTS public.transicion_atencion;
DROP TABLE IF EXISTS public.atencion_clinica;
DROP TABLE IF EXISTS public.transicion_cita;
DROP TABLE IF EXISTS public.cita;
DROP TABLE IF EXISTS public.seguimiento;
DROP TABLE IF EXISTS public.entrada_clinica;
DROP TABLE IF EXISTS public.historia_clinica;
DROP TABLE IF EXISTS public.paciente;
DROP TABLE IF EXISTS public.valor_arancel;
DROP TABLE IF EXISTS public.tipo_atencion;
DROP TABLE IF EXISTS public.evento_auditoria_minima;
DROP TABLE IF EXISTS public.profesional;
DROP TABLE IF EXISTS public.invitacion_profesional;
DROP TABLE IF EXISTS public.organizacion_clinica;

-- === Paso 9: Drop extensiones (opcional — puede afectar otros proyectos) ===
-- DROP EXTENSION IF EXISTS "pg_trgm";
-- No dropear uuid-ossp (requerida por Supabase)
```

### 12.3 Verificacion post-rollback

```sql
-- Verificar que no quedan tablas de Fase 1
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion',
    'cobro', 'transicion_pago'
  );
-- Esperar: 0 filas

-- Verificar que no quedan funciones de Fase 1
SELECT proname FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND proname IN (
    'obtener_mi_organizacion_id', 'handle_new_user', 'set_updated_at',
    'reject_mutation', 'validate_cross_tenant_ref',
    'crear_paciente', 'registrar_atencion', 'cerrar_atencion',
    'modificar_estado_cita', 'agregar_entrada_clinica',
    'registrar_pago', 'anular_cobro', 'archivar_paciente', 'cerrar_arancel',
    'guard_entrada_clinica_immutable', 'guard_atencion_clinica_immutable',
    'guard_cobro_snapshot_immutable', 'guard_valor_arancel_immutable',
    'guard_profesional_immutable', 'guard_historia_clinica_immutable',
    'guard_paciente_immutable', 'guard_seguimiento_immutable',
    'guard_cita_immutable'
  );
-- Esperar: 0 filas

-- Verificar que no queda trigger en auth.users
SELECT tgname FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass
  AND tgname = 'on_auth_user_created';
-- Esperar: 0 filas
```

---

## 13. Riesgos operacionales

### R1 — Trigger en `auth.users` requiere esquema `auth` (sin cambio)

**Riesgo:** El trigger se crea sobre `auth.users`. En entorno local/CI puede no existir.
**Mitigacion:** Dry-run contra instancia Supabase real (staging o proyecto de test).

### R2 — `SECURITY DEFINER` y escalacion de privilegios (REFORZADO)

**Riesgo:** RPCs `SECURITY DEFINER` se ejecutan como `postgres`.
**Mitigacion:** (a) `SET search_path = public, pg_temp` (correccion C3). (b) Nombres calificados. (c) `REVOKE EXECUTE FROM PUBLIC` (correccion C2). (d) Solo `authenticated` tiene GRANT. (e) Sin SQL dinamico en RPCs (solo en trigger Tipo B con `TG_ARGV`). (f) QA inspecciona `pg_proc.proconfig`.

### R3 — `SET LOCAL` como mecanismo de contexto RPC (REFORZADO — correccion M4)

**Riesgo:** Un atacante podria intentar `SET LOCAL app.rpc_cerrar_arancel = 'true'` antes de un UPDATE directo.
**Mitigacion:** `authenticated` no tiene `UPDATE` sobre `valor_arancel` (REVOKE explicito). El UPDATE falla por falta de privilegio antes de llegar al trigger. QA prueba este escenario.

### R4 — Migraciones parcialmente aplicadas (sin cambio)

**Mitigacion:** Cada archivo se ejecuta en transaccion. Supabase CLI lo hace por defecto.

### R5 — Performance de `obtener_mi_organizacion_id()` (sin cambio)

**Mitigacion:** Indice unico en `auth_user_id`. `STABLE` para caching.

### R6 — FORCE RLS puede bloquear INSERTs de RPCs (NUEVO)

**Riesgo:** `FORCE RLS` en tablas como `evento_auditoria_minima` podria bloquear INSERTs desde RPCs `SECURITY DEFINER` si el owner esta sujeto a policies.
**Mitigacion:** Verificar en dry-run. Si bloquea, alternativa: remover `FORCE RLS` de esas tablas y confiar en triggers append-only como defensa primaria.

### R7 — `invitacion_profesional` requiere provisioning externo (NUEVO)

**Riesgo:** Sin un mecanismo server-side para crear invitaciones, no se puede registrar el primer profesional.
**Mitigacion:** El primer profesional se crea via `service_role` en un script de provisioning. La app debe tener un endpoint de invitacion protegido (fuera de alcance SQL, es responsabilidad de la capa de aplicacion).

---

## 14. Criterios de aprobacion para pasar a migraciones reales

1. **Este documento es aprobado** sin hallazgos criticos por revision humana o Codex.
2. **Dry-run exitoso** en proyecto Supabase de staging.
3. **QA `11_qa_phase1.sql` pasa** al 100% en staging, incluyendo tests hostiles.
4. **Revision de seguridad** aprobada: REVOKE/GRANT verificados, `pg_proc.proconfig` inspeccionado, signup fraudulento rechazado.
5. **FORCE RLS verificado**: confirmar que no bloquea INSERTs de RPCs en tablas con FORCE.
6. **Archivo `rollback_phase1.sql`** preparado, probado y verificado con checklist post-rollback.
7. **No se detecta adelanto de Fase 2** en ninguna migracion.

Una vez cumplidos estos 7 criterios, se procedera a crear los 11 archivos `.sql` finales en `supabase/migrations/`.

---

## Changelog — Mapeo hallazgos QA → correcciones

| Hallazgo QA | Tipo | Correccion aplicada en v1.1 |
|-------------|------|----------------------------|
| C1: `obtener_mi_organizacion_id()` antes de `profesional` | Critico | Movida al final de migracion 02, despues de `profesional`. Migracion 01 solo contiene extensiones y `set_updated_at()`. Eliminada forward reference y justificacion por dry-run. |
| C2: Falta modelo de privilegios para `SECURITY DEFINER` | Critico | Nueva seccion 3 con modelo completo: owner (`postgres`), roles (`anon`, `authenticated`, `service_role`), `REVOKE EXECUTE FROM PUBLIC` para toda funcion privilegiada, `GRANT EXECUTE TO authenticated` solo para RPCs invocables, REVOKE de permisos directos sobre tablas protegidas, bloque consolidado en migracion 10. |
| C3: `search_path = public` insuficiente | Critico | Estandar obligatorio (seccion 2): `SET search_path = public, pg_temp` para toda funcion privilegiada. Nombres calificados (`public.tabla`). QA inspecciona `pg_proc.proconfig`. Sin SQL dinamico salvo `validate_cross_tenant_ref` (justificado: usa `TG_ARGV`, no parametros de usuario). |
| C4: Trigger `auth.users → profesional` confia en metadata cliente | Critico | Nueva tabla `invitacion_profesional` (16 tablas Fase 1). Trigger rediseñado: valida contra invitacion existente por `token` + `email`. Datos del profesional provienen de la invitacion, no del cliente. Invitacion de un solo uso. Sin invitacion valida, el registro revierte. |
| M1: RLS incompleto como contrato de UPDATE por columnas | Medio | Nueva seccion 5 con contrato explicito por tabla: columnas actualizables, columnas protegidas, mecanismo exacto (trigger). 5 nuevos triggers de proteccion de columnas: `profesional`, `historia_clinica`, `paciente`, `seguimiento`, `cita`. QA con tests por columna. |
| M2: Falta FORCE RLS / decision sobre owner/bypass | Medio | Nueva seccion 6: owner `postgres`, `FORCE RLS` en 5 tablas sensibles, documentacion de bypass intencional por RPCs, validaciones manuales equivalentes, riesgo R6 sobre posible bloqueo. |
| M3: QA insuficiente para seguridad hostil | Medio | Seccion 11.7 con tests hostiles: `anon` no ejecuta RPCs, `PUBLIC` sin EXECUTE, `pg_proc.proconfig`, signup fraudulento (6 escenarios), cross-tenant via RPC, UPDATE por columna, `SET LOCAL` + UPDATE directo, `service_role` no expuesto. |
| M4: `SET LOCAL` viable pero requiere acotacion | Medio | Acotado por: REVOKE UPDATE sobre `valor_arancel` para `authenticated`, test QA de `SET LOCAL` + UPDATE directo → ERROR por falta de privilegio. Documentado en seccion 9.3 y riesgo R3. |
| M5: Rollback logico demasiado grueso | Medio | Seccion 12 expandida: 9 pasos en orden inverso cubriendo grants, RPCs, policies, RLS, triggers (append-only, inmutabilidad, Tipo B, updated_at, auth.users), funciones, tablas, extensiones. Verificacion post-rollback con queries a `pg_tables`, `pg_proc`, `pg_trigger`. |

---

## Fase 2 no adelantada

- No existen tablas: `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, `fotografia_clinica`, `consentimiento`, `informe_sesion`, `intento_contacto`
- No existen columnas: `relacion_centro_id`, `zona_domiciliaria_id` en tablas Fase 1
- No existen Storage buckets
- No existen RPCs de Fase 2

---

*Este blueprint es el plan SQL ejecutable de Fase 1 de Agenda Podologica, version 1.1. Incorpora las correcciones exigidas por el QA de v1.0 en materia de privilegios, SECURITY DEFINER, onboarding seguro, proteccion por columnas, FORCE RLS y rollback. No es SQL listo para ejecutar: es el paso previo a la creacion de migraciones finales. Cada decision de implementacion debe ser rastreable a este documento o al blueprint conceptual v1.2.*
