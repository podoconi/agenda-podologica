# QA SQL Phase 1 Operational Package v1

**Paquete auditado:** `supabase/migrations/`, `supabase/qa/qa_phase1.sql`, `supabase/rollback/rollback_phase1.sql`  
**QA anterior:** `docs/03_qa/QA_SQL_PHASE1_MIGRATIONS_v1.md`  
**Alcance:** Reauditoria operacional estatica posterior a correcciones. No se modifican archivos, no se aplican migraciones, no se ejecuta `db push`, no se toca Supabase remoto.

## Veredicto

**Aprobado con observaciones para dry-run.**

Los bloqueos criticos del QA anterior fueron corregidos:

- `supabase/migrations/` tiene activas solo las 10 migraciones reales `20260628000001` a `20260628000010`.
- Las migraciones antiguas `20260621*` fueron movidas a `supabase/migrations/archive/`.
- `qa_phase1.sql` salio del flujo autoaplicable y ahora vive en `supabase/qa/`.
- `qa_phase1.sql` crea fixtures en `auth.users`, usa `SET LOCAL ROLE anon`, `SET LOCAL ROLE authenticated`, intenta simular claims, prueba cross-tenant via RPC, `SET LOCAL + UPDATE`, y termina con `ROLLBACK`.
- `rollback_phase1.sql` revoca sobre objetos Fase 1 desde `anon`, `authenticated` y `PUBLIC`, y sigue acotado objeto por objeto.

El paquete queda apto para dry-run en staging limpio de las migraciones reales `01` a `10`. La observacion principal es que el QA manual debe validarse contra el mecanismo real de `auth.uid()` del entorno Supabase usado para staging.

## Hallazgos criticos

**No se detectan hallazgos criticos.**

Los tres bloqueos anteriores quedaron resueltos:

- Las migraciones antiguas ya no estan como archivos SQL activos de primer nivel en `supabase/migrations`.
- El QA ya no tiene timestamp ni reside en la carpeta de migraciones activas.
- El QA ahora crea filas de `auth.users` antes de insertar `profesional`.

## Hallazgos medios

### M1. El QA usa `request.jwt.claims`; debe confirmarse que alimenta `auth.uid()` en staging

El QA simula el usuario autenticado asi:

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "ua000000-0000-0000-0000-000000000001"}';
```

(`supabase/qa/qa_phase1.sql:267-268`)

Las RPCs usan `auth.uid()` indirectamente al buscar `public.profesional.auth_user_id`. Si la definicion de `auth.uid()` del entorno staging lee `request.jwt.claim.sub` en vez de `request.jwt.claims`, las pruebas cross-tenant via RPC fallaran con "Profesional no encontrado para el usuario autenticado" en lugar de las excepciones esperadas de tenant.

**Impacto:** no bloquea el dry-run de migraciones `01-10`, pero puede hacer que el QA manual falle por mecanismo de simulacion de claims, no por error del modelo.

**Recomendacion:** antes de usar el QA como certificacion, verificar en staging/local cual setting lee `auth.uid()` y, si corresponde, ajustar el harness para setear tambien `request.jwt.claim.sub`.

### M2. `crypt()` / `gen_salt()` en fixtures requiere `pgcrypto`

El QA inserta usuarios con:

```sql
crypt('testpass123', gen_salt('bf'))
```

(`supabase/qa/qa_phase1.sql:16-23`)

Las migraciones Fase 1 activan `uuid-ossp` y `pg_trgm`, pero no `pgcrypto` (`supabase/migrations/20260628000001_extensions_and_helpers.sql:6-7`). En muchos entornos Supabase `pgcrypto` puede estar disponible, pero el QA manual depende de ello.

**Impacto:** posible fallo del QA por extension ausente, no por migraciones Fase 1.

**Recomendacion:** confirmar que `pgcrypto` esta disponible en staging/local antes de ejecutar QA, o ajustar el fixture para evitar depender de `crypt()` si Supabase permite `encrypted_password` nulo o un valor dummy aceptable para el harness.

## Hallazgos menores

### m1. Carpeta activa de migraciones esta limpia

Archivos SQL activos de primer nivel en `supabase/migrations/`:

- `20260628000001_extensions_and_helpers.sql`
- `20260628000002_identity_and_auth.sql`
- `20260628000003_audit_and_catalogs.sql`
- `20260628000004_patients_and_clinical_history.sql`
- `20260628000005_schedule_and_followups.sql`
- `20260628000006_clinical_care.sql`
- `20260628000007_billing.sql`
- `20260628000008_triggers_and_guards.sql`
- `20260628000009_rls_policies.sql`
- `20260628000010_rpc_and_privileges.sql`

No hay `20260628000011_qa_phase1.sql` activo en la carpeta de migraciones.

### m2. Migraciones antiguas archivadas

Las migraciones `20260621*` estan dentro de `supabase/migrations/archive/`:

- `20260621000001_fase1_tablas.sql`
- `20260621000002_fase1_funciones_triggers.sql`
- `20260621000003_fase1_rls.sql`
- `20260621000004_fase1_rpcs.sql`

Al no estar como SQL de primer nivel en `supabase/migrations/`, no deberian ser aplicadas por el flujo normal de Supabase CLI. Como precaucion operativa, si el equipo usa scripts propios con busqueda recursiva de `.sql`, deben excluir `archive/`.

### m3. QA fuera del flujo autoaplicable

`qa_phase1.sql` esta en `supabase/qa/qa_phase1.sql`, sin timestamp de migracion. El propio archivo declara que se ejecuta manualmente despues de aplicar migraciones `01-10`, dentro de `BEGIN` / `ROLLBACK` (`supabase/qa/qa_phase1.sql:1-8`, `460-462`).

### m4. QA manual cubre las categorias solicitadas

El QA contiene:

- Fixtures `auth.users` antes de `profesional` (`supabase/qa/qa_phase1.sql:14-37`).
- `SET LOCAL ROLE anon` con llamadas negativas a RPCs (`supabase/qa/qa_phase1.sql:183-240`).
- `SET LOCAL ROLE authenticated` + `SET LOCAL app.rpc_cerrar_arancel` + `UPDATE public.valor_arancel` esperado como bloqueado (`supabase/qa/qa_phase1.sql:243-258`).
- Cross-tenant via RPC para `registrar_atencion`, `cerrar_atencion` y `registrar_pago` (`supabase/qa/qa_phase1.sql:260-306`).
- Tests de FK tenant, Tipo B, append-only, inmutabilidad y trigger `SET LOCAL` como owner (`supabase/qa/qa_phase1.sql:308-458`).
- `ROLLBACK` final (`supabase/qa/qa_phase1.sql:462`).

### m5. Rollback corregido y acotado

`rollback_phase1.sql` revoca funciones desde `anon`, `authenticated` y `PUBLIC` (`supabase/rollback/rollback_phase1.sql:13-22`) y revoca tablas desde los mismos tres roles (`supabase/rollback/rollback_phase1.sql:28-43`). Luego elimina policies, deshabilita RLS, elimina triggers, el trigger de `auth.users`, funciones y tablas Fase 1 en orden inverso (`supabase/rollback/rollback_phase1.sql:49-197`).

No se detectan comandos globales tipo `REVOKE ALL ON ALL ... IN SCHEMA public`.

## Riesgos pendientes

- El QA manual puede requerir ajuste del setting JWT si `auth.uid()` no lee `request.jwt.claims` en el entorno usado.
- El QA manual puede requerir `pgcrypto` para `crypt()` / `gen_salt()`.
- La carpeta `supabase/migrations/archive/` contiene `.sql`; el flujo Supabase CLI normal no deberia aplicarla, pero scripts recursivos propios deben excluirla.

## Recomendacion final

**Proceder con dry-run en staging limpio de las migraciones activas `20260628000001` a `20260628000010`.**

Despues del dry-run:

1. Ejecutar `supabase/qa/qa_phase1.sql` manualmente.
2. Si falla en `auth.uid()` / claims, ajustar el harness de QA, no las migraciones.
3. Si falla por `crypt()` / `gen_salt()`, habilitar/verificar `pgcrypto` en staging o adaptar el fixture de `auth.users`.
4. Probar `supabase/rollback/rollback_phase1.sql` solo en staging/local y confirmar su verificacion post-rollback.

Con esas observaciones, el paquete operacional queda suficientemente ordenado para avanzar a dry-run.
