# QA SQL Phase 1 Migrations v1

**Archivos auditados:** `supabase/migrations/20260628000001` a `20260628000011` y `supabase/rollback/rollback_phase1.sql`  
**Contratos de entrada:** `docs/02_architecture/SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md` y `docs/03_qa/QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1_2.md`  
**Alcance:** Auditoria estatica local. No se modifican migraciones, no se aplican migraciones, no se ejecuta `db push`, no se toca Supabase remoto.

## Veredicto

**Rechazado para dry-run inmediato en Supabase staging.**

Las migraciones nuevas `20260628` reflejan bien el blueprint v1.2 en la mayor parte del nucleo: orden 01-10 coherente, onboarding por invitacion con `UPDATE ... RETURNING`, RLS sin `FORCE`, privilegios cerrados para tablas y funciones, `anon` sin grants, y rollback acotado por objeto.

El rechazo no es por el diseno principal, sino por el paquete ejecutable tal como esta hoy en el repo:

1. Persisten migraciones antiguas `20260621*` en `supabase/migrations`, anteriores por timestamp e incompatibles con la nueva Fase 1.
2. `20260628000011_qa_phase1.sql` esta timestamped dentro de `supabase/migrations` aunque el propio archivo dice que no debe autoaplicarse como migracion.
3. Ese QA no es ejecutable tal como esta: inserta profesionales con `auth_user_id` inexistentes en `auth.users`, por lo que falla por FK antes de llegar a los tests principales.

## Hallazgos criticos

### C1. Las migraciones antiguas `20260621*` se aplicarian antes y colisionarian con Fase 1 v1.2

En `supabase/migrations` siguen presentes:

- `20260621000001_fase1_tablas.sql`
- `20260621000002_fase1_funciones_triggers.sql`
- `20260621000003_fase1_rls.sql`
- `20260621000004_fase1_rpcs.sql`

Estas migraciones crean las mismas tablas y funciones base con un modelo anterior, por ejemplo `organizacion_clinica`, `profesional`, `paciente`, `cita`, `atencion_clinica`, `cobro`, RLS y RPCs (`supabase/migrations/20260621000001_fase1_tablas.sql:7`, `24`, `101`, `199`, `266`, `326`; `20260621000002_fase1_funciones_triggers.sql:19-59`; `20260621000003_fase1_rls.sql:11-212`; `20260621000004_fase1_rpcs.sql:25-484`).

Como sus timestamps son anteriores a `20260628`, un dry-run limpio aplicaria primero la version vieja y luego fallaria al intentar crear objetos ya existentes en la version nueva, por ejemplo `public.organizacion_clinica` en `20260628000002_identity_and_auth.sql:9`.

**Impacto:** dry-run staging no determinista/fallido; mezcla de modelos de seguridad v1.0/v1.2; riesgo de aplicar el trigger antiguo de `auth.users` que confiaba en metadata cliente.

**Condicion para dry-run:** mover esas migraciones a `archive/`, renombrarlas con extension no reconocida por Supabase como `.disabled`, o eliminarlas si ya fueron reemplazadas oficialmente. No deben convivir en la carpeta activa.

### C2. `20260628000011_qa_phase1.sql` no debe estar como migracion autoaplicable

El archivo QA declara explicitamente:

- "It is NOT an auto-applied migration"
- "rename or remove the timestamp prefix if using supabase CLI auto-migration, or run via psql directly"

(`supabase/migrations/20260628000011_qa_phase1.sql:5-10`)

Pero el archivo esta en `supabase/migrations` con timestamp valido. Por tanto, cualquier flujo normal de Supabase CLI lo trataria como una migracion mas. Ademas termina con `ROLLBACK` (`20260628000011_qa_phase1.sql:449`), lo que lo hace conceptualmente distinto al resto del set.

**Impacto:** el set de 11 migraciones no es un paquete aplicable como migraciones normales. El archivo 11 debe sacarse del flujo autoaplicable o convertirse en un script QA manual fuera de `migrations`.

**Condicion para dry-run:** renombrar a algo como `supabase/qa/qa_phase1.sql`, `supabase/migrations/20260628000011_qa_phase1.sql.disabled`, o mantenerlo fuera de `supabase/migrations` y ejecutarlo manualmente contra staging despues de aplicar 01-10.

### C3. El QA real falla por FK antes de ejecutar sus pruebas

El QA inserta profesionales directamente:

```sql
INSERT INTO public.profesional (id, auth_user_id, organizacion_id, ...)
VALUES (..., 'ua000000-0000-0000-0000-000000000001', ...);
```

(`supabase/migrations/20260628000011_qa_phase1.sql:27-43`)

Pero `profesional.auth_user_id` referencia `auth.users(id)` (`supabase/migrations/20260628000002_identity_and_auth.sql:55-60`). El QA no crea filas correspondientes en `auth.users`, ni usa el flujo real de signup con `invitacion_profesional`. En un entorno limpio, ese insert directo debe fallar por foreign key violation antes de llegar a privilegios, RLS, RPCs o rollback.

**Impacto:** QA no ejecutable tal como esta; no puede certificar la migracion 01-10; bloqueo para dry-run con QA.

**Condicion para dry-run:** el QA debe crear usuarios de fixture en `auth.users` de forma compatible con Supabase local/staging, o bien ejecutar fixtures usando el Auth API/server-side harness. Alternativamente, si se mantiene como SQL puro, debe insertar primero los `auth.users` requeridos con todas las columnas obligatorias del entorno real.

## Hallazgos medios

### M1. El QA no prueba realmente cross-tenant via RPC ni `anon` ejecutando RPCs

El archivo QA verifica privilegios con `has_function_privilege` y prueba FKs/Tipo B directos (`20260628000011_qa_phase1.sql:156-210`, `216-273`). Eso es util, pero no equivale a ejecutar RPCs como `authenticated` con claims de usuarios de org A/B.

La seccion solicitada por el blueprint era "cross-tenant via RPC"; el SQL actual no llama `registrar_atencion`, `cerrar_atencion`, `registrar_pago`, etc. bajo identidad de org A contra registros de org B. Tampoco hace `SET ROLE anon` y llamadas reales a RPCs; solo consulta privilegios.

**Impacto:** QA hostil insuficiente como prueba final. Puede aprobar el modelo de grants, pero no demuestra que las validaciones manuales dentro de RPCs bloqueen acceso cross-tenant.

### M2. `SET LOCAL + UPDATE directo` no prueba falta de UPDATE de `authenticated`

El QA reconoce que corre como `postgres` y por eso "test the trigger path" (`20260628000011_qa_phase1.sql:410-421`). Luego usa `SET LOCAL app.rpc_cerrar_arancel = 'true'` y actualiza como owner (`20260628000011_qa_phase1.sql:424-437`).

Eso valida el trigger, pero no la garantia central pedida: que un usuario `authenticated` no pueda ejecutar `SET LOCAL` + `UPDATE public.valor_arancel` por falta de privilegio. La verificacion `has_table_privilege('authenticated', 'public.valor_arancel', 'UPDATE') = false` existe (`20260628000011_qa_phase1.sql:189-191`), pero falta una prueba operacional con `SET ROLE authenticated`.

**Impacto:** el riesgo esta mitigado por grants en la migracion 10, pero el QA no reproduce el ataque de forma completa.

### M3. `handle_new_user()` corrige concurrencia, pero no testea token malformado

La migracion 02 implementa `UPDATE public.invitacion_profesional ... RETURNING ... INTO v_invitacion` para consumir la invitacion de forma atomica (`20260628000002_identity_and_auth.sql:94-102`). Eso cumple la observacion de concurrencia del QA v1.2.

El cast de token sigue siendo directo:

```sql
v_token := (NEW.raw_user_meta_data->>'token')::UUID;
```

(`20260628000002_identity_and_auth.sql:88`)

Un token textual no casteable rechazara el signup, lo cual es aceptable, pero el QA no lo cubre. Tampoco cubre signup sin token/expirado/reusado de forma ejecutable.

### M4. Rollback acotado, pero revoca solo `authenticated`

`rollback_phase1.sql` ya no usa `REVOKE ALL ON ALL ... IN SCHEMA public`; opera objeto por objeto y en orden inverso (`supabase/rollback/rollback_phase1.sql:13-197`). Eso corrige el hallazgo critico de v1.1.

La observacion: revoca funciones y tablas solo desde `authenticated` (`rollback_phase1.sql:13-43`). Si por un fallo parcial, una migracion manual o defaults de Supabase quedaran grants a `anon`/`PUBLIC`, el rollback no los limpia antes de dropear. Como luego elimina objetos, el impacto practico es bajo, pero por simetria con el modelo cerrado conviene revocar desde `anon, authenticated, PUBLIC`.

### M5. La migracion QA no debe contarse como una de las 11 migraciones aplicables

El blueprint hablaba de 11 archivos, pero el propio SQL de QA indica que debe ejecutarse manualmente. Operacionalmente, el set aplicable deberia ser:

- 10 migraciones reales (`01` a `10`)
- 1 script QA manual posterior
- 1 rollback manual

Mantener "11 migraciones aplicables" genera ambiguedad peligrosa en staging.

## Hallazgos menores

### m1. Orden de migraciones nuevas 01-10 es correcto

El orden nuevo respeta dependencias:

- 01 extensiones y `set_updated_at()` (`20260628000001_extensions_and_helpers.sql:6-18`)
- 02 identidad, invitacion, `profesional`, trigger `auth.users` y `obtener_mi_organizacion_id()` despues de `profesional` (`20260628000002_identity_and_auth.sql:9-145`)
- 03-07 tablas de dominio en orden dependiente
- 08 triggers y guards despues de existir todas las tablas (`20260628000008_triggers_and_guards.sql:10-352`)
- 09 RLS despues de helper y tablas (`20260628000009_rls_policies.sql:11-201`)
- 10 RPCs y privilegios despues de RLS (`20260628000010_rpc_and_privileges.sql:13-625`)

### m2. Seguridad `SECURITY DEFINER` bien materializada en RPCs y Auth

Las funciones privilegiadas principales usan `SECURITY DEFINER` y `SET search_path = public, pg_temp`, por ejemplo `handle_new_user()` (`20260628000002_identity_and_auth.sql:78-83`), `obtener_mi_organizacion_id()` (`20260628000002_identity_and_auth.sql:134-145`) y las RPCs (`20260628000010_rpc_and_privileges.sql:13-71`, `76-157`, `162-225`, `230-296`, `301-353`, `362-557`).

La migracion 10 revoca `EXECUTE` desde `anon`, `authenticated` y `PUBLIC`, y concede solo a `authenticated` las funciones invocables (`20260628000010_rpc_and_privileges.sql:600-625`). `handle_new_user()` queda sin grant de aplicacion (`20260628000010_rpc_and_privileges.sql:603`, sin grant posterior).

### m3. RLS cumple la decision v1.2

Las 16 tablas tienen `ENABLE ROW LEVEL SECURITY` y no aparece `FORCE ROW LEVEL SECURITY` en las migraciones nuevas (`20260628000009_rls_policies.sql:11-26`). `invitacion_profesional` no tiene policies (`20260628000009_rls_policies.sql:28-30`). Auditoria y transiciones solo tienen SELECT, sin policies de INSERT/UPDATE/DELETE (`20260628000009_rls_policies.sql:56-60`, `156-161`, `179-184`, `196-201`).

### m4. Tenant safety estructural bien cubierta

Las tablas ancla incluyen `UNIQUE (organizacion_id, id)` y las relaciones internas sensibles usan FK compuestas, por ejemplo `paciente -> profesional`, `historia_clinica -> paciente`, `seguimiento/cita -> paciente/profesional`, `atencion_clinica -> paciente/profesional/tipo_atencion/cita`, `cobro/transicion_pago` (`20260628000004_patients_and_clinical_history.sql:30-32`, `53-55`; `20260628000005_schedule_and_followups.sql:31-35`, `68-78`; `20260628000006_clinical_care.sql:31-39`; `20260628000007_billing.sql:36-40`, `63-66`).

### m5. Inmutabilidad y append-only estan bien materializadas

`reject_mutation()` protege auditoria y transiciones contra UPDATE/DELETE (`20260628000008_triggers_and_guards.sql:46-70`). Hay guards para entrada clinica, atencion cerrada, cobro snapshot, valor arancel, profesional, historia, paciente, seguimiento y cita (`20260628000008_triggers_and_guards.sql:76-298`). `valor_arancel` exige `app.rpc_cerrar_arancel = 'true'` y cambio de `vigente_hasta` de NULL a fecha (`20260628000008_triggers_and_guards.sql:159-193`), mientras `cerrar_arancel()` setea la flag local antes del UPDATE (`20260628000010_rpc_and_privileges.sql:520-557`).

## Riesgos pendientes

- Aplicar sin archivar `20260621*` mezcla un modelo viejo rechazado con la Fase 1 v1.2.
- Autoaplicar el QA timestamped puede romper el flujo de migraciones o registrar una migracion cuyo contenido hace `ROLLBACK`.
- El QA actual no corre por FK contra `auth.users` y no prueba RPCs cross-tenant bajo claims reales.
- El rollback no revoca `anon`/`PUBLIC` por simetria, aunque elimina objetos despues.
- El campo `organizacion_clinica.estado` sigue siendo editable por cualquier profesional autenticado de la org, igual que en el blueprint aprobado con observaciones.

## Recomendacion final

**No hacer dry-run en Supabase staging todavia.**

Antes del dry-run:

1. Sacar de `supabase/migrations` las migraciones antiguas `20260621*`: mover a `supabase/migrations/archive/`, renombrar a `.disabled`, o eliminarlas si el equipo confirma que fueron reemplazadas.
2. Sacar `20260628000011_qa_phase1.sql` del flujo de migraciones autoaplicables. Mantenerlo como script manual en una carpeta QA o renombrarlo a `.disabled`.
3. Corregir el QA para crear usuarios `auth.users` validos o usar un harness con Supabase Auth API; luego agregar pruebas reales de `anon`, `authenticated`, `SET ROLE`, claims y cross-tenant via RPC.
4. Opcional pero recomendado: ajustar rollback para revocar grants desde `anon, authenticated, PUBLIC` antes de dropear objetos.

Con esos cambios operacionales, las migraciones reales `20260628000001` a `20260628000010` se ven aptas para un dry-run en staging limpio. Tal como esta el paquete completo hoy, el dry-run debe rechazarse.
