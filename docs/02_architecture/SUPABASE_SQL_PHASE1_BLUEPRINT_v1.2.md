# Supabase SQL Phase 1 Blueprint — Agenda Podologica

**Version:** 1.2
**Estado:** Corregido — incorpora hallazgos de QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1_1.md
**Fecha:** Junio 2026
**Autor:** Roberto Rojas + Claude
**Fuente canonica:** `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`
**QA de entrada v1.1:** `QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1_1.md` — rechazado (3 criticos, 8 medios)
**Siguiente paso:** Revision → aprobacion → creacion de archivos `.sql` de migracion

---

## Cambios en esta version

Esta version corrige los 3 hallazgos criticos y los hallazgos medios relevantes del QA v1.1. El modelo de datos, el faseo y el alcance Fase 1 no cambian. Se mantienen las 16 tablas (15 de dominio + `invitacion_profesional`).

- **C1 — FORCE RLS eliminado:** Se elimina `FORCE ROW LEVEL SECURITY` de las 5 tablas donde estaba. La proteccion de escritura en tablas sensibles descansa en: (a) ausencia de policies INSERT/UPDATE/DELETE para roles de aplicacion, (b) REVOKE explicito de privilegios, (c) triggers append-only, (d) validaciones manuales dentro de RPCs. Decision determinista, sin "verificar en dry-run".
- **C2 — Modelo GRANT/REVOKE cerrado:** Reescrito como lista cerrada de objetos Fase 1. Primero REVOKE base sobre cada tabla y funcion Fase 1 para `anon`, `authenticated` y `PUBLIC`. Luego GRANT explicitos por tabla/rol/operacion segun la matriz aprobada. Incluye verificacion conceptual con `information_schema.role_table_grants`, `role_routine_grants`, `has_table_privilege`, `has_function_privilege`.
- **C3 — Rollback acotado:** Reescrito objeto por objeto. Solo afecta objetos de Fase 1. Sin `REVOKE ALL ON ALL ... IN SCHEMA public`.
- **M1 — `invitacion_profesional` aprobada:** Arquitectura aprueba explicitamente la tabla 16 como artefacto de seguridad de onboarding.
- **M2 — Invitacion mejorada:** Email normalizado con `lower(trim(...))`. Campo `expira_en` agregado. UNIQUE absoluto reemplazado por indice unico parcial solo para invitaciones pendientes. Historial de invitaciones permitido.
- **M3 — Verificacion por OID:** QA hostil verifica `prosecdef` y `has_function_privilege` por OID, no solo por nombre.
- **M4 — SELECT anon sobre organizacion_clinica eliminado:** `anon` no tiene acceso a ninguna tabla Fase 1. Si se necesita validacion publica de invitacion, sera via endpoint server-side o funcion minima especifica.
- **M5 — search_path confirmado:** Se mantiene `SET search_path = public, pg_temp` como patron. Se documenta que `search_path = ''` es alternativa valida pero no se adopta.
- **M6 — Triggers como barrera principal:** Se declara explicitamente que los triggers son la barrera principal de proteccion de columnas, no `GRANT UPDATE(columna)`. El blueprint no promete column-level grants.
- **M7 — QA hostil ejecutable:** Reescrito con firmas reales, asserts sobre causa del error y pseudo-SQL suficientemente exacto para convertir directamente en SQL runnable.
- **M8 — SET LOCAL cerrado:** El cierre depende del modelo de grants cerrado (C2). Ahora verificable.
- **m3 — service_role:** Verificacion de `.env` separada como checklist operacional, no SQL QA.

---

## Resumen ejecutivo

16 tablas Fase 1 (15 dominio + 1 seguridad), 11 archivos de migracion.

**Alcance Fase 1:**
- 16 tablas (Identity, Security, Audit, Clinical, Operational, Configuration, Economic)
- 8 tablas ancla con `UNIQUE (organizacion_id, id)`
- 20+ FK compuestas Tipo A
- 3 triggers Tipo B diferidos
- 4 triggers append-only
- 3 triggers de inmutabilidad parcial + 5 triggers de proteccion de columnas
- 1 trigger de inmutabilidad total con excepcion controlada (`valor_arancel`)
- 1 funcion auxiliar central (`obtener_mi_organizacion_id`)
- 1 trigger `auth.users` → `profesional` (con validacion de invitacion)
- 5 RPCs T00 (atomicas con auditoria)
- 4 RPCs controladas
- Modelo cerrado de privilegios (REVOKE base + GRANT explicito)
- Policies RLS completas (sin FORCE)
- Triggers como barrera principal de proteccion de columnas
- Suite QA ejecutable con pruebas funcionales y hostiles

**Fuera de alcance:** Tablas Fase 2, columnas Fase 2, Storage buckets, SQL ejecutado en Supabase.

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
| 08 | `08_triggers_and_guards.sql` | Triggers `updated_at`, append-only, inmutabilidad, proteccion de columnas, Tipo B diferidos | 02-07 |
| 09 | `09_rls_policies.sql` | RLS enable (sin FORCE), todas las policies Fase 1 | 01-08 |
| 10 | `10_rpc_and_privileges.sql` | RPCs T00, RPCs controladas, REVOKE base + GRANT cerrado | 01-09 |
| 11 | `11_qa_phase1.sql` | Tests funcionales + hostiles ejecutables en transaccion con ROLLBACK | 01-10 |

**Sin cambios en cantidad ni nombres respecto a v1.1.** El contenido de migraciones 09 y 10 cambia sustancialmente.

---

## 2. Estandar obligatorio para funciones privilegiadas

Sin cambios respecto a v1.1. Toda funcion `SECURITY DEFINER`:

- `SET search_path = public, pg_temp`
- Nombres calificados (`public.tabla`)
- Sin SQL dinamico (excepcion: `validate_cross_tenant_ref()` con `TG_ARGV`)
- Post-creacion: `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` (excepto triggers internos)

**Nota sobre `search_path = ''` (correccion M5):** El patron `search_path = ''` con calificacion completa (incluyendo `pg_catalog.now()`) es una alternativa valida y mas estricta. Este blueprint adopta `public, pg_temp` porque: (a) las funciones de `pg_catalog` se resuelven automaticamente sin estar en el path, (b) `pg_temp` al final de la lista explicita evita shadowing por objetos temporales, (c) toda tabla se califica con `public.` como defensa en profundidad. Si la revision de seguridad final prefiere `search_path = ''`, el cambio es mecanico y compatible.

---

## 3. Modelo de privilegios (REESCRITO — correcciones C2, M4)

### 3.1 Roles Supabase

| Rol | Proposito | Acceso en Fase 1 |
|-----|-----------|------------------|
| `postgres` | Superusuario / owner | Owner de tablas y funciones. No se usa desde aplicacion. Bypasea RLS. |
| `authenticated` | Usuario autenticado via Supabase Auth | SELECT/INSERT/UPDATE segun matriz. EXECUTE sobre RPCs autorizadas. |
| `anon` | Usuario no autenticado | **Sin acceso a tablas ni funciones Fase 1.** (correccion M4) |
| `service_role` | Rol administrativo con bypass RLS | No se usa desde frontend. Solo provisioning server-side. |

### 3.2 Owner

Todas las tablas y funciones son propiedad de `postgres`. Las RPCs `SECURITY DEFINER` se ejecutan como `postgres`.

### 3.3 Estrategia de grants: REVOKE base + GRANT explicito

En Supabase, los objetos nuevos en `public` pueden heredar grants automaticos por default privileges. Para garantizar un modelo cerrado, migracion 10 aplica la siguiente secuencia:

**Paso 1 — REVOKE base sobre cada tabla Fase 1:**

```sql
-- Para CADA tabla Fase 1 (16 tablas):
REVOKE ALL ON public.organizacion_clinica FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.invitacion_profesional FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.profesional FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.evento_auditoria_minima FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.tipo_atencion FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.valor_arancel FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.paciente FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.historia_clinica FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.entrada_clinica FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.seguimiento FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.cita FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.transicion_cita FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.atencion_clinica FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.transicion_atencion FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.cobro FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.transicion_pago FROM anon, authenticated, PUBLIC;
```

**Paso 2 — GRANT explicitos para `authenticated`:**

```sql
-- Tablas con SELECT + INSERT + UPDATE
GRANT SELECT, INSERT, UPDATE ON public.tipo_atencion TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.paciente TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.entrada_clinica TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.seguimiento TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.cita TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.atencion_clinica TO authenticated;

-- Tablas con SELECT + INSERT (sin UPDATE directo)
GRANT SELECT, INSERT ON public.valor_arancel TO authenticated;
GRANT SELECT, INSERT ON public.cobro TO authenticated;

-- Tablas con SELECT + UPDATE (sin INSERT directo)
GRANT SELECT, UPDATE ON public.organizacion_clinica TO authenticated;
GRANT SELECT, UPDATE ON public.profesional TO authenticated;
GRANT SELECT, UPDATE ON public.historia_clinica TO authenticated;

-- Tablas con SELECT solo
GRANT SELECT ON public.evento_auditoria_minima TO authenticated;
GRANT SELECT ON public.transicion_atencion TO authenticated;
GRANT SELECT ON public.transicion_cita TO authenticated;
GRANT SELECT ON public.transicion_pago TO authenticated;

-- Tablas sin acceso para authenticated
-- invitacion_profesional: sin GRANT (solo service_role/SECURITY DEFINER)
```

**Paso 3 — `anon` sin acceso (correccion M4):**

```sql
-- anon no recibe GRANT sobre ninguna tabla ni funcion Fase 1.
-- Si se necesita validacion publica de invitacion, sera via
-- endpoint server-side o funcion minima especifica.
```

**Paso 4 — Secuencias:**

Este blueprint usa `uuid_generate_v4()` para todas las PKs. No hay secuencias `SERIAL`/`BIGSERIAL`. No se requieren grants de secuencias.

### 3.4 Grants sobre funciones

```sql
-- REVOKE base de TODAS las funciones SECURITY DEFINER
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

-- GRANT solo a authenticated para RPCs invocables
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

-- handle_new_user: sin GRANT a ningun rol. Solo se ejecuta como trigger.
-- set_updated_at, reject_mutation, guard_*, validate_cross_tenant_ref: triggers, no RPCs.
```

### 3.5 Verificacion de privilegios (QA)

```sql
-- Verificar que anon no tiene privilegios sobre tablas Fase 1
SELECT table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'anon'
  AND table_schema = 'public'
  AND table_name IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago'
  );
-- Esperar: 0 filas

-- Verificar que authenticated tiene exactamente los privilegios previstos
SELECT table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'authenticated'
  AND table_schema = 'public'
  AND table_name IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago'
  )
ORDER BY table_name, privilege_type;
-- Comparar resultado contra la matriz de seccion 3.3

-- Verificar que PUBLIC no tiene EXECUTE sobre funciones SECURITY DEFINER por OID
SELECT p.proname, p.oid
FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND has_function_privilege('PUBLIC', p.oid, 'EXECUTE');
-- Esperar: 0 filas

-- Verificar que anon no tiene EXECUTE sobre RPCs clinicas
SELECT r.routine_name, r.routine_schema
FROM information_schema.role_routine_grants r
WHERE r.grantee = 'anon'
  AND r.routine_schema = 'public';
-- Esperar: 0 filas
```

---

## 4. Decision sobre FORCE RLS (REESCRITA — correccion C1)

### Decision final: NO usar FORCE ROW LEVEL SECURITY en Fase 1.

Todas las 16 tablas usan `ENABLE ROW LEVEL SECURITY` sin `FORCE`.

### Justificacion

`FORCE RLS` somete al owner de la tabla (normalmente `postgres`) a las policies. En este blueprint, las RPCs `SECURITY DEFINER` se ejecutan como `postgres` y necesitan escribir en tablas donde `authenticated` no tiene policies de escritura:

- `handle_new_user()` lee y actualiza `invitacion_profesional` (sin policies para ningun rol).
- RPCs T00 insertan en `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita` (sin policies INSERT).
- RPCs controladas insertan en `transicion_pago` (sin policies INSERT).

Si se usara `FORCE RLS`, habria que crear policies INSERT para `postgres` en esas tablas, lo cual anularia el proposito de protegerlas (cualquier query directa del owner podria escribir). El resultado seria proteccion meramente aparente.

### Proteccion real sin FORCE

La escritura en tablas sensibles se protege por capas complementarias:

| Capa | Mecanismo | Aplica a |
|------|-----------|----------|
| 1 — Grants | REVOKE INSERT/UPDATE/DELETE de `authenticated` y `anon` | `invitacion_profesional`, `evento_auditoria_minima`, `transicion_*` |
| 2 — RLS | Sin policies INSERT/UPDATE/DELETE para roles de aplicacion | Mismas tablas |
| 3 — Triggers | `reject_mutation()` en tablas append-only | `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita`, `transicion_pago` |
| 4 — RPCs | Validaciones manuales de tenant y estado | Toda escritura privilegiada |

Si un atacante lograra una sesion como `postgres` (no como `authenticated`), ya tendria control total del sistema independientemente de `FORCE RLS`. Para Fase 1, `FORCE RLS` no agrega proteccion practica y si introduce riesgo de bloqueo funcional.

---

## 5. Migraciones — DDL de tablas

### Migracion 01 — Extensiones y helpers

Sin cambios respecto a v1.1. Contiene `uuid-ossp`, `pg_trgm`, `set_updated_at()`.

### Migracion 02 — Identity, onboarding y auth

#### Tabla: `organizacion_clinica`

Sin cambios respecto a v1.1.

#### Tabla: `invitacion_profesional` (MEJORADA — correccion M2)

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
  expira_en       TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  consumida_en    TIMESTAMPTZ
);

-- Solo una invitacion pendiente por email+org (permite historico de consumidas/revocadas)
CREATE UNIQUE INDEX uq_invitacion_pendiente_email_org
  ON public.invitacion_profesional (lower(trim(email)), organizacion_id)
  WHERE estado = 'pendiente';

-- Busqueda rapida por token pendiente
CREATE INDEX idx_invitacion_token_pendiente
  ON public.invitacion_profesional (token)
  WHERE estado = 'pendiente';
```

**Cambios vs v1.1:**
- `expira_en` agregado (default: 7 dias desde creacion).
- `UNIQUE (email, organizacion_id)` absoluto reemplazado por indice unico parcial `WHERE estado = 'pendiente'`. Esto permite que un email tenga invitaciones historicas (consumidas, revocadas, expiradas) en la misma org.
- Email normalizado con `lower(trim(...))` en el indice.
- Indice de token filtrado por `estado = 'pendiente'` para busquedas rapidas.

**Revocacion:** Un administrador puede cambiar `estado` a `'revocada'` via `service_role` para invalidar una invitacion pendiente.
**Expiracion:** El trigger de signup verifica `expira_en` antes de aceptar la invitacion. La limpieza periodica de invitaciones expiradas (cambiar estado a `'expirada'`) es responsabilidad de un cron o script server-side, no del SQL de Fase 1.

#### Trigger: `auth.users` → `profesional` (MEJORADO — correccion M2)

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
  v_token := (NEW.raw_user_meta_data->>'token')::UUID;

  IF v_token IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: token de invitacion requerido';
  END IF;

  -- Buscar invitacion valida: pendiente, mismo email normalizado, no expirada
  SELECT id, organizacion_id, nombre_completo, nombre_para_documentos
  INTO v_invitacion
  FROM public.invitacion_profesional
  WHERE token = v_token
    AND lower(trim(email)) = lower(trim(NEW.email))
    AND estado = 'pendiente'
    AND expira_en > now();

  IF v_invitacion IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: invitacion no encontrada, expirada, revocada o email no coincide';
  END IF;

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

**Cambios vs v1.1:** Agrega verificacion de `expira_en > now()`. Email comparado con `lower(trim(...))`.

#### Tabla: `profesional`

Sin cambios respecto a v1.1.

#### Funcion: `obtener_mi_organizacion_id()`

Sin cambios respecto a v1.1. Al final de migracion 02, despues de `profesional`.

### Migraciones 03-07

Sin cambios en DDL respecto a v1.1. Las tablas `evento_auditoria_minima`, `tipo_atencion`, `valor_arancel`, `paciente`, `historia_clinica`, `entrada_clinica`, `seguimiento`, `cita`, `transicion_cita`, `atencion_clinica`, `transicion_atencion`, `cobro`, `transicion_pago` mantienen exactamente la misma definicion.

---

## 6. Contrato de columnas actualizables (ACLARADO — correccion M6)

**Decision: los triggers son la barrera principal de proteccion de columnas.** Este blueprint no promete `GRANT UPDATE(columna)`. La proteccion es:

1. **Triggers `BEFORE UPDATE`** que rechazan mutacion de columnas protegidas.
2. **Policies RLS** que filtran filas (no columnas).
3. **RPCs como unico canal** para cambios de estado en tablas protegidas.

La razon de no usar `GRANT UPDATE(columna)` es operacional: PostgreSQL requiere declarar la lista completa de columnas permitidas en el GRANT, lo cual introduce fragilidad ante ALTER TABLE futuros. Los triggers son resilientes a cambios de schema porque solo verifican las columnas que deben ser inmutables.

### Tabla de contratos

Sin cambios respecto a v1.1 seccion 5.1. Los triggers definidos en v1.1 seccion 5.2 se mantienen:

- `guard_profesional_immutable()` — protege `auth_user_id`, `organizacion_id`, `email`, `estado`, `creado_en`
- `guard_historia_clinica_immutable()` — protege `paciente_id`, `organizacion_id`, `creado_en`
- `guard_paciente_immutable()` — protege `organizacion_id`, `creado_por`, `creado_en`
- `guard_seguimiento_immutable()` — protege `organizacion_id`, `paciente_id`, `profesional_id`, `origen`, `creado_en`
- `guard_cita_immutable()` — protege `organizacion_id`, `paciente_id`, `profesional_id`, `cita_anterior_id`, `creado_en`
- `guard_entrada_clinica_immutable()` — protege `descripcion`, `tipo`, `historia_clinica_id`, `registrado_por`, `registrado_en`
- `guard_atencion_clinica_immutable()` — protege columnas clinicas cuando `OLD.estado = 'cerrada'`
- `guard_cobro_snapshot_immutable()` — protege todas las columnas snapshot
- `guard_valor_arancel_immutable()` — inmutabilidad total + excepcion `vigente_hasta`

**Sobre `organizacion_clinica` y `estado`:** El campo `estado` de `organizacion_clinica` es actualizable por `authenticated` via UPDATE directo. En Fase 1, todo profesional de la org puede cambiar campos operativos. Si en el futuro se necesita rol "admin" dentro de la org, se agregara un control de rol — fuera de alcance Fase 1.

---

## 7. Migracion 08 — Triggers y guards

Sin cambios en contenido respecto a v1.1. Incluye:

- 8 triggers `updated_at`
- 4 triggers append-only (`reject_mutation`)
- 4 triggers de inmutabilidad (de v1.0: entrada_clinica, atencion_clinica, cobro, valor_arancel)
- 5 triggers de proteccion de columnas (de v1.1: profesional, historia_clinica, paciente, seguimiento, cita)
- 3 triggers Tipo B diferidos (seguimiento, cita, cobro → atencion_clinica)

---

## 8. Migracion 09 — Policies RLS (SIMPLIFICADA — correccion C1)

### Habilitacion de RLS (sin FORCE)

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
```

**Sin `FORCE ROW LEVEL SECURITY` en ninguna tabla.** Razon documentada en seccion 4.

### Policies

Sin cambios en policies respecto a v1.1 para las 16 tablas:

- `invitacion_profesional`: sin policies (solo service_role/SECURITY DEFINER acceden).
- `organizacion_clinica`: SELECT/UPDATE propria org.
- `profesional`: SELECT misma org, UPDATE solo propio perfil.
- `evento_auditoria_minima`: SELECT misma org.
- `tipo_atencion`: SELECT/INSERT/UPDATE misma org.
- `valor_arancel`: SELECT/INSERT misma org.
- `paciente`: SELECT/INSERT misma org, UPDATE no archivado.
- `historia_clinica`: SELECT/UPDATE misma org.
- `entrada_clinica`: SELECT/INSERT/UPDATE misma org.
- `seguimiento`: SELECT/INSERT misma org, UPDATE no completado/descartado.
- `cita`: SELECT/INSERT misma org, UPDATE no terminal.
- `transicion_cita`: SELECT misma org.
- `atencion_clinica`: SELECT/INSERT misma org, UPDATE solo registrada.
- `transicion_atencion`: SELECT misma org.
- `cobro`: SELECT/INSERT misma org.
- `transicion_pago`: SELECT misma org.

---

## 9. Migracion 10 — RPCs y privilegios

### RPCs

Sin cambios en logica de RPCs respecto a v1.1. Todas usan:
- `SECURITY DEFINER`
- `SET search_path = public, pg_temp`
- Nombres calificados (`public.tabla`)
- Validaciones de tenant manuales

RPCs T00: `crear_paciente`, `registrar_atencion`, `cerrar_atencion`, `modificar_estado_cita`, `agregar_entrada_clinica`.

RPCs controladas: `registrar_pago`, `anular_cobro`, `archivar_paciente`, `cerrar_arancel`.

### Bloque de privilegios (REESCRITO — correcciones C2, M4)

Contenido completo de la seccion de privilegios en migracion 10: ver seccion 3.3 y 3.4 de este documento.

---

## 10. Migracion 11 — QA Fase 1 (REESCRITA — correcciones M3, M7)

### Estrategia

Todos los tests se ejecutan en una transaccion con `ROLLBACK`. Cada test indica la causa esperada del fallo: `permission denied`, `RLS policy violation`, `trigger exception`, `FK violation`, o `function execute denied`.

### 11.1 Tests de estructura

```sql
-- Verificar que las 16 tablas existen
SELECT count(*) FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion',
    'cobro', 'transicion_pago'
  );
-- Esperar: 16

-- Verificar UNIQUE (organizacion_id, id) en 8 tablas ancla
SELECT count(*) FROM pg_constraint c
  JOIN pg_class r ON c.conrelid = r.oid
  JOIN pg_namespace n ON r.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.contype = 'u'
  AND r.relname IN ('profesional', 'paciente', 'historia_clinica', 'tipo_atencion',
                     'atencion_clinica', 'cita', 'cobro', 'seguimiento');
-- Esperar: >= 8 (cada tabla tiene al menos 1 UNIQUE que incluye organizacion_id+id)

-- Verificar RLS habilitado en 16 tablas
SELECT count(*) FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relrowsecurity = true
  AND c.relname IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago'
  );
-- Esperar: 16

-- Verificar que FORCE RLS NO esta habilitado en ninguna tabla
SELECT c.relname FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relforcerowsecurity = true
  AND c.relname IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago'
  );
-- Esperar: 0 filas
```

### 11.2 Tests de privilegios (correccion M3)

```sql
-- anon no tiene privilegios sobre tablas Fase 1
SELECT count(*) FROM information_schema.role_table_grants
WHERE grantee = 'anon' AND table_schema = 'public'
  AND table_name IN (...lista 16 tablas...);
-- Esperar: 0

-- PUBLIC no conserva EXECUTE sobre funciones SECURITY DEFINER (por OID)
SELECT p.proname FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND has_function_privilege('PUBLIC', p.oid, 'EXECUTE');
-- Esperar: 0 filas

-- anon no tiene EXECUTE sobre funciones Fase 1
SELECT r.routine_name FROM information_schema.role_routine_grants r
WHERE r.grantee = 'anon' AND r.routine_schema = 'public';
-- Esperar: 0 filas

-- search_path de funciones SECURITY DEFINER contiene 'public, pg_temp'
SELECT p.proname, p.proconfig FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND NOT (p.proconfig @> ARRAY['search_path=public, pg_temp']);
-- Esperar: 0 filas (todas deben contener el setting correcto)

-- authenticated tiene acceso a tablas esperadas y NO a invitacion_profesional
SELECT has_table_privilege('authenticated', 'public.invitacion_profesional', 'SELECT');
-- Esperar: false

SELECT has_table_privilege('authenticated', 'public.paciente', 'SELECT');
-- Esperar: true

SELECT has_table_privilege('authenticated', 'public.paciente', 'DELETE');
-- Esperar: false

-- authenticated NO tiene UPDATE sobre valor_arancel
SELECT has_table_privilege('authenticated', 'public.valor_arancel', 'UPDATE');
-- Esperar: false

-- authenticated NO tiene UPDATE sobre cobro
SELECT has_table_privilege('authenticated', 'public.cobro', 'UPDATE');
-- Esperar: false
```

### 11.3 Tests de integridad tenant (FK compuestas)

Sin cambios respecto a v1.0/v1.1. Cross-tenant negativo para cada tabla ancla + Tipo B.

### 11.4 Tests de append-only

Sin cambios respecto a v1.0/v1.1.

### 11.5 Tests de inmutabilidad y proteccion de columnas

```sql
-- entrada_clinica: UPDATE de descripcion → ERROR (trigger)
-- Causa esperada: trigger exception 'columnas protegidas no pueden modificarse'

-- atencion_clinica cerrada: UPDATE de tratamiento → ERROR (trigger)
-- Causa esperada: trigger exception 'columnas clinicas no pueden modificarse'

-- cobro: UPDATE de monto → ERROR (trigger)
-- Causa esperada: trigger exception 'columnas snapshot son inmutables'

-- valor_arancel: UPDATE directo de valor → ERROR (trigger)
-- Causa esperada: trigger exception 'columnas protegidas son inmutables'

-- profesional: UPDATE de organizacion_id → ERROR (trigger)
-- Causa esperada: trigger exception 'columnas de identidad no pueden modificarse'

-- profesional: UPDATE de nombre_completo → OK
-- historia_clinica: UPDATE de paciente_id → ERROR (trigger)
-- historia_clinica: UPDATE de resumen_general → OK
-- paciente: UPDATE de creado_por → ERROR (trigger)
-- paciente: UPDATE de nombre_completo → OK
-- seguimiento: UPDATE de origen → ERROR (trigger)
-- seguimiento: UPDATE de urgencia → OK
-- cita: UPDATE de paciente_id → ERROR (trigger)
-- cita: UPDATE de notas → OK
```

### 11.6 Tests de RPCs T00 y controladas

Sin cambios respecto a v1.0/v1.1. Verifican creacion atomica de registros + transiciones + auditoria.

### 11.7 Tests de RLS

Sin cambios respecto a v1.0/v1.1. Cross-org SELECT/INSERT/UPDATE.

### 11.8 Tests de seguridad hostil (REESCRITO — correccion M7)

Cada prueba incluye la firma real de la RPC y la causa esperada del fallo.

```sql
-- === anon no ejecuta RPCs clinicas ===

SET ROLE anon;

-- crear_paciente con firma real (9 params: nombre, rut, fecha_nac, tel1, tel2, email, dir, origen, notas)
SELECT public.crear_paciente(
  'Paciente Test'::TEXT,
  NULL::TEXT, NULL::DATE, NULL::TEXT, NULL::TEXT,
  NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
);
-- Causa esperada: permission denied for function crear_paciente

SELECT public.registrar_atencion(
  uuid_generate_v4()::UUID,
  NULL::UUID, 'particular'::TEXT, NULL::UUID, NULL::TEXT
);
-- Causa esperada: permission denied for function registrar_atencion

SELECT public.cerrar_atencion(
  uuid_generate_v4()::UUID,
  NULL::TEXT, NULL::TEXT, NULL::TEXT
);
-- Causa esperada: permission denied for function cerrar_atencion

SELECT public.modificar_estado_cita(
  uuid_generate_v4()::UUID,
  'confirmada'::TEXT, NULL::TEXT
);
-- Causa esperada: permission denied for function modificar_estado_cita

SELECT public.agregar_entrada_clinica(
  uuid_generate_v4()::UUID,
  'patologia'::TEXT, 'Test'::TEXT, NULL::TEXT
);
-- Causa esperada: permission denied for function agregar_entrada_clinica

SELECT public.registrar_pago(
  uuid_generate_v4()::UUID,
  'efectivo'::TEXT, 'pagado'::TEXT
);
-- Causa esperada: permission denied for function registrar_pago

SELECT public.anular_cobro(
  uuid_generate_v4()::UUID,
  'motivo test'::TEXT
);
-- Causa esperada: permission denied for function anular_cobro

SELECT public.archivar_paciente(uuid_generate_v4()::UUID);
-- Causa esperada: permission denied for function archivar_paciente

SELECT public.cerrar_arancel(uuid_generate_v4()::UUID, '2026-12-31'::DATE);
-- Causa esperada: permission denied for function cerrar_arancel

SELECT public.obtener_mi_organizacion_id();
-- Causa esperada: permission denied for function obtener_mi_organizacion_id

RESET ROLE;

-- === anon no tiene acceso a tablas ===

SET ROLE anon;
SELECT * FROM public.organizacion_clinica LIMIT 1;
-- Causa esperada: permission denied for table organizacion_clinica (o RLS: 0 filas si GRANT existiera)

SELECT * FROM public.paciente LIMIT 1;
-- Causa esperada: permission denied for table paciente
RESET ROLE;

-- === Signup fraudulento ===
-- (Estas pruebas requieren simular INSERT en auth.users.
--  En entorno real Supabase, se prueban via Supabase Auth API.
--  En SQL puro, se simulan con INSERT directo en auth.users si el esquema existe.)

-- Signup sin token:
-- INSERT INTO auth.users (email, raw_user_meta_data)
-- VALUES ('test@test.com', '{}');
-- Causa esperada: trigger exception 'token de invitacion requerido'

-- Signup con token invalido (UUID aleatorio):
-- INSERT INTO auth.users (email, raw_user_meta_data)
-- VALUES ('test@test.com', '{"token": "00000000-0000-0000-0000-000000000000"}');
-- Causa esperada: trigger exception 'invitacion no encontrada'

-- Signup con token valido pero email diferente:
-- (crear invitacion para 'admin@clinica.com', intentar signup con 'hacker@evil.com')
-- Causa esperada: trigger exception 'invitacion no encontrada... email no coincide'

-- Signup con invitacion expirada:
-- (crear invitacion con expira_en en el pasado, intentar signup)
-- Causa esperada: trigger exception 'invitacion no encontrada... expirada'

-- Signup con invitacion consumida:
-- (crear invitacion, consumirla, intentar segunda vez con mismo token)
-- Causa esperada: trigger exception 'invitacion no encontrada'

-- Signup exitoso:
-- (crear invitacion pendiente, hacer signup con token + email correcto)
-- Verificar: profesional creado, invitacion estado = 'consumida'

-- === Cross-tenant via RPC ===

-- (Con dos orgs y profesionales autenticados de cada una)

-- SET ROLE authenticated;
-- SET LOCAL role = 'authenticated';
-- SET LOCAL request.jwt.claims = '{"sub": "<uuid_prof_org_A>"}';

-- Intentar registrar_atencion con paciente de org B:
-- SELECT public.registrar_atencion('<paciente_org_B>', NULL, 'particular', NULL, NULL);
-- Causa esperada: exception 'Paciente no encontrado en esta organizacion'

-- Intentar cerrar_atencion con atencion de org B:
-- SELECT public.cerrar_atencion('<atencion_org_B>', NULL, NULL, NULL);
-- Causa esperada: exception 'Atencion no encontrada en esta organizacion'

-- Intentar registrar_pago con cobro de org B:
-- SELECT public.registrar_pago('<cobro_org_B>', 'efectivo', 'pagado');
-- Causa esperada: exception 'Cobro no encontrado en esta organizacion'

-- === SET LOCAL + UPDATE directo sobre valor_arancel ===

SET ROLE authenticated;
SET LOCAL app.rpc_cerrar_arancel = 'true';
UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31'
  WHERE id = uuid_generate_v4();
-- Causa esperada: permission denied for table valor_arancel
-- (authenticated no tiene UPDATE sobre valor_arancel — el error ocurre ANTES del trigger)
RESET ROLE;

-- === UPDATE por columna en tablas protegidas ===

-- (Con sesion authenticated de un profesional valido)
-- UPDATE public.profesional SET organizacion_id = uuid_generate_v4() WHERE ...;
-- Causa esperada: trigger exception 'columnas de identidad no pueden modificarse'

-- UPDATE public.profesional SET nombre_completo = 'Nuevo Nombre' WHERE ...;
-- Causa esperada: OK (columna permitida)
```

---

## 11. Indices de Fase 1

Sin cambios respecto a v1.1, excepto los indices de `invitacion_profesional` que ahora son:

| Tabla | Indice | Tipo |
|-------|--------|------|
| `invitacion_profesional` | `(lower(trim(email)), organizacion_id) WHERE estado = 'pendiente'` | parcial unique |
| `invitacion_profesional` | `(token) WHERE estado = 'pendiente'` | parcial btree |

Indices restantes de las 15 tablas de dominio: identicos a v1.0/v1.1.

---

## 12. Rollback logico (REESCRITO — correccion C3)

### Principio: solo objetos Fase 1, objeto por objeto

El rollback no usa `REVOKE ALL ON ALL ... IN SCHEMA public`. Solo opera sobre objetos creados por las migraciones de Fase 1.

### Paso 1 — Revocar grants de funciones Fase 1

```sql
REVOKE EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.archivar_paciente(UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) FROM authenticated;
```

### Paso 2 — Revocar grants de tablas Fase 1

```sql
REVOKE ALL ON public.organizacion_clinica FROM authenticated;
REVOKE ALL ON public.profesional FROM authenticated;
REVOKE ALL ON public.evento_auditoria_minima FROM authenticated;
REVOKE ALL ON public.tipo_atencion FROM authenticated;
REVOKE ALL ON public.valor_arancel FROM authenticated;
REVOKE ALL ON public.paciente FROM authenticated;
REVOKE ALL ON public.historia_clinica FROM authenticated;
REVOKE ALL ON public.entrada_clinica FROM authenticated;
REVOKE ALL ON public.seguimiento FROM authenticated;
REVOKE ALL ON public.cita FROM authenticated;
REVOKE ALL ON public.transicion_cita FROM authenticated;
REVOKE ALL ON public.atencion_clinica FROM authenticated;
REVOKE ALL ON public.transicion_atencion FROM authenticated;
REVOKE ALL ON public.cobro FROM authenticated;
REVOKE ALL ON public.transicion_pago FROM authenticated;
REVOKE ALL ON public.invitacion_profesional FROM authenticated;
```

### Paso 3 — Drop policies RLS (por tabla)

```sql
-- Para cada tabla, drop todas las policies Fase 1:
-- Patron: DROP POLICY IF EXISTS nombre_policy ON public.tabla;
-- organizacion_clinica: select_own_org, update_own_org
-- profesional: select_profesional, update_own_profesional
-- evento_auditoria_minima: select_auditoria
-- tipo_atencion: select_tipo_atencion, insert_tipo_atencion, update_tipo_atencion
-- valor_arancel: select_valor_arancel, insert_valor_arancel
-- paciente: select_paciente, insert_paciente, update_paciente
-- historia_clinica: select_historia, update_historia
-- entrada_clinica: select_entrada, insert_entrada, update_entrada
-- seguimiento: select_seguimiento, insert_seguimiento, update_seguimiento
-- cita: select_cita, insert_cita, update_cita
-- transicion_cita: select_transicion_cita
-- atencion_clinica: select_atencion, insert_atencion, update_atencion
-- transicion_atencion: select_transicion_atencion
-- cobro: select_cobro, insert_cobro
-- transicion_pago: select_transicion_pago
-- invitacion_profesional: (sin policies)
```

### Paso 4 — Deshabilitar RLS

```sql
ALTER TABLE public.organizacion_clinica DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitacion_profesional DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profesional DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_auditoria_minima DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipo_atencion DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.valor_arancel DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.paciente DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.historia_clinica DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrada_clinica DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.seguimiento DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cita DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_cita DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.atencion_clinica DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_atencion DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cobro DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_pago DISABLE ROW LEVEL SECURITY;
```

### Paso 5 — Drop triggers Fase 1

```sql
-- Append-only
DROP TRIGGER IF EXISTS trg_evento_auditoria_append_only ON public.evento_auditoria_minima;
DROP TRIGGER IF EXISTS trg_transicion_atencion_append_only ON public.transicion_atencion;
DROP TRIGGER IF EXISTS trg_transicion_cita_append_only ON public.transicion_cita;
DROP TRIGGER IF EXISTS trg_transicion_pago_append_only ON public.transicion_pago;

-- Inmutabilidad
DROP TRIGGER IF EXISTS trg_entrada_clinica_immutable ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_atencion_clinica_immutable ON public.atencion_clinica;
DROP TRIGGER IF EXISTS trg_cobro_snapshot_immutable ON public.cobro;
DROP TRIGGER IF EXISTS trg_valor_arancel_immutable ON public.valor_arancel;

-- Proteccion de columnas (v1.1+)
DROP TRIGGER IF EXISTS trg_profesional_immutable ON public.profesional;
DROP TRIGGER IF EXISTS trg_historia_clinica_immutable ON public.historia_clinica;
DROP TRIGGER IF EXISTS trg_paciente_immutable ON public.paciente;
DROP TRIGGER IF EXISTS trg_seguimiento_immutable ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_immutable ON public.cita;

-- Tipo B
DROP TRIGGER IF EXISTS trg_seguimiento_validate_atencion ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_validate_atencion ON public.cita;
DROP TRIGGER IF EXISTS trg_cobro_validate_atencion ON public.cobro;

-- Updated_at (8 tablas)
DROP TRIGGER IF EXISTS trg_organizacion_clinica_updated_at ON public.organizacion_clinica;
DROP TRIGGER IF EXISTS trg_profesional_updated_at ON public.profesional;
DROP TRIGGER IF EXISTS trg_tipo_atencion_updated_at ON public.tipo_atencion;
DROP TRIGGER IF EXISTS trg_paciente_updated_at ON public.paciente;
DROP TRIGGER IF EXISTS trg_entrada_clinica_updated_at ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_seguimiento_updated_at ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_updated_at ON public.cita;
DROP TRIGGER IF EXISTS trg_atencion_clinica_updated_at ON public.atencion_clinica;
```

### Paso 6 — Drop trigger de auth.users

```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
```

### Paso 7 — Drop funciones Fase 1

```sql
-- RPCs
DROP FUNCTION IF EXISTS public.cerrar_arancel(UUID, DATE);
DROP FUNCTION IF EXISTS public.archivar_paciente(UUID);
DROP FUNCTION IF EXISTS public.anular_cobro(UUID, TEXT);
DROP FUNCTION IF EXISTS public.registrar_pago(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.modificar_estado_cita(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.cerrar_atencion(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

-- Soporte
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.obtener_mi_organizacion_id();
DROP FUNCTION IF EXISTS public.validate_cross_tenant_ref();
DROP FUNCTION IF EXISTS public.guard_entrada_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_atencion_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_cobro_snapshot_immutable();
DROP FUNCTION IF EXISTS public.guard_valor_arancel_immutable();
DROP FUNCTION IF EXISTS public.guard_profesional_immutable();
DROP FUNCTION IF EXISTS public.guard_historia_clinica_immutable();
DROP FUNCTION IF EXISTS public.guard_paciente_immutable();
DROP FUNCTION IF EXISTS public.guard_seguimiento_immutable();
DROP FUNCTION IF EXISTS public.guard_cita_immutable();
DROP FUNCTION IF EXISTS public.reject_mutation();
DROP FUNCTION IF EXISTS public.set_updated_at();
```

### Paso 8 — Drop tablas en orden inverso

```sql
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
```

### Paso 9 — Verificacion post-rollback

```sql
SELECT count(*) FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (...lista 16 tablas...);
-- Esperar: 0

SELECT count(*) FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND proname IN (...lista 23 funciones...);
-- Esperar: 0

SELECT count(*) FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass
  AND tgname = 'on_auth_user_created';
-- Esperar: 0
```

---

## 13. Checklist operacional (no SQL) — correccion m3

Verificaciones que no pertenecen a la migracion SQL pero deben completarse antes de produccion:

- [ ] `SUPABASE_SERVICE_ROLE_KEY` no esta en `.env.local` ni en variables accesibles al frontend.
- [ ] Solo `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY` estan en variables de frontend.
- [ ] El endpoint de creacion de invitaciones esta protegido y solo accesible desde server-side.
- [ ] El primer profesional de cada organizacion se provisiona via script con `service_role`, no via UI publica.

---

## 14. Riesgos pendientes

### R1 — Trigger en `auth.users` requiere esquema `auth`

Sin cambio. Dry-run contra instancia Supabase real.

### R2 — `SECURITY DEFINER` y escalacion

Mitigado por: `search_path = public, pg_temp`, nombres calificados, `REVOKE FROM PUBLIC`, GRANT solo a `authenticated`, QA por OID.

### R3 — `SET LOCAL` como contexto RPC

Mitigado por: `authenticated` no tiene UPDATE sobre `valor_arancel` (REVOKE explicito en modelo cerrado). QA prueba el escenario.

### R4 — Migraciones parcialmente aplicadas

Transaccional por Supabase CLI.

### R5 — Performance de `obtener_mi_organizacion_id()`

Indice unico + STABLE.

### R6 — Provisioning inicial requiere `service_role`

Sin un script server-side que cree la primera `organizacion_clinica` e `invitacion_profesional`, no se puede registrar el primer profesional. Es responsabilidad de la capa de aplicacion, no del SQL.

### R7 — Default privileges de Supabase

El modelo de grants cerrado (REVOKE base + GRANT explicito) mitiga defaults heredados. La verificacion QA con `information_schema.role_table_grants` confirma el estado real.

---

## 15. Criterios de aprobacion para pasar a migraciones reales

1. **Este documento es aprobado** sin hallazgos criticos por revision humana o Codex.
2. **Dry-run exitoso** en proyecto Supabase de staging.
3. **QA `11_qa_phase1.sql` pasa** al 100%, incluyendo tests hostiles y verificacion de privilegios.
4. **Modelo de grants verificado** contra `information_schema.role_table_grants` y `has_function_privilege`.
5. **Signup fraudulento rechazado** en los 5 escenarios negativos.
6. **Archivo `rollback_phase1.sql`** preparado con rollback objeto-por-objeto, probado y verificado.
7. **Checklist operacional** completado (service_role no en frontend, provisioning documentado).
8. **No se detecta adelanto de Fase 2.**

---

## Changelog — Mapeo hallazgos QA v1.1 → correcciones

| Hallazgo QA v1.1 | Tipo | Correccion aplicada en v1.2 |
|-------------------|------|----------------------------|
| C1: FORCE RLS bloquea RPCs SECURITY DEFINER | Critico | Eliminado FORCE RLS de las 5 tablas. Decision determinista documentada en seccion 4. Proteccion por: grants, ausencia de policies, triggers append-only, validaciones en RPCs. |
| C2: Modelo GRANT/REVOKE incompleto frente a Supabase | Critico | Reescrito como lista cerrada en seccion 3.3-3.4. REVOKE base por tabla Fase 1, GRANT explicitos por rol/operacion, verificacion con information_schema y has_*_privilege. Sin dependencia de defaults. |
| C3: Rollback con comandos globales sobre `public` | Critico | Reescrito objeto por objeto en seccion 12. Sin `REVOKE ALL ON ALL`. Solo afecta objetos Fase 1. 9 pasos con verificacion post-rollback. |
| M1: `invitacion_profesional` requiere aprobacion arquitectonica | Medio | Aprobada explicitamente como tabla 16 de seguridad de onboarding. No es entidad clinica, no adelanta Fase 2. |
| M2: Flujo de invitacion con riesgos operativos | Medio | Email normalizado con `lower(trim(...))`. Campo `expira_en` agregado. UNIQUE absoluto reemplazado por indice parcial para pendientes. Historial de invitaciones permitido. Trigger verifica expiracion. |
| M3: REVOKE/GRANT depende de firmas, verificar por OID | Medio | QA usa `pg_proc.prosecdef` + `has_function_privilege(PUBLIC, oid)` para verificar por OID, no solo por nombre. |
| M4: anon no necesita SELECT sobre organizacion_clinica | Medio | SELECT anon eliminado. anon sin acceso a ninguna tabla ni funcion Fase 1. |
| M5: search_path pattern es aceptable | Medio | Confirmado `public, pg_temp`. Nota sobre `search_path = ''` como alternativa valida no adoptada. |
| M6: Contrato de columnas no cerrado por GRANT | Medio | Declarado explicitamente: triggers son barrera principal, no GRANT UPDATE(columna). Razon documentada en seccion 6. |
| M7: QA hostil no ejecutable ni discriminante | Medio | Reescrito con firmas reales (9 params crear_paciente, 5 params registrar_atencion, etc.), causa esperada por prueba (permission denied vs trigger exception vs RLS), pseudo-SQL convertible a runnable. |
| M8: SET LOCAL depende de cierre de grants | Medio | Cerrado por modelo de grants (C2). authenticated no tiene UPDATE sobre valor_arancel. QA prueba SET LOCAL + UPDATE → permission denied. |
| m3: service_role verificacion en SQL QA | Menor | Separado como checklist operacional (seccion 13), no SQL QA. |

---

*Este blueprint es el plan SQL ejecutable de Fase 1 de Agenda Podologica, version 1.2. Incorpora las correcciones exigidas por el QA de v1.1 en materia de FORCE RLS, modelo de grants cerrado, rollback acotado, QA hostil ejecutable y mejoras a invitacion_profesional. No es SQL listo para ejecutar: es el paso previo a la creacion de migraciones finales.*
