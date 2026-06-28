# QA Supabase SQL Phase 1 Blueprint v1.1

**Documento auditado:** `docs/02_architecture/SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md`  
**QA de entrada:** `docs/03_qa/QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md`  
**Alcance:** Auditoria tecnica del blueprint SQL previo a migraciones reales. No se modifica el blueprint, no se crea SQL final, no se crean migraciones y no se aplica nada en Supabase.

## Veredicto

**Rechazado para conversion directa a 11 migraciones SQL reales.**

La v1.1 corrige de forma sustantiva varios problemas de v1.0: mueve `obtener_mi_organizacion_id()` despues de `profesional`, endurece el patron general de `SECURITY DEFINER`, reemplaza la autoasociacion por metadata con un flujo de invitacion, declara un contrato de columnas mutables y amplia el QA hostil.

Sin embargo, aun no esta lista para migraciones reales porque mantiene bloqueos tecnicos en tres zonas que no pueden quedar como "verificar en dry-run": `FORCE ROW LEVEL SECURITY` en tablas que deben ser escritas por RPCs `SECURITY DEFINER`, modelo de privilegios incompleto para los defaults de Supabase, y rollback con comandos globales sobre todo el schema `public`. Tambien quedan observaciones relevantes sobre `anon`, QA hostil no ejecutable y la incorporacion de `invitacion_profesional` como tabla 16.

## Hallazgos criticos

### C1. `FORCE ROW LEVEL SECURITY` puede bloquear el propio flujo privilegiado que el blueprint necesita

El blueprint aplica `FORCE ROW LEVEL SECURITY` a `invitacion_profesional`, `evento_auditoria_minima`, `transicion_atencion`, `transicion_cita` y `transicion_pago` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:967-975`, `1089-1093`). Luego reconoce que las RPCs `SECURITY DEFINER` quedan sujetas a las policies en esas tablas y que podria ser necesario retirar `FORCE RLS` o crear policies de INSERT para el owner (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:995`).

Ese punto no es menor: las RPCs T00 necesitan insertar auditoria y transiciones, y `handle_new_user()` necesita leer y actualizar `invitacion_profesional`. El documento no define policies para `invitacion_profesional` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1100-1107`) ni policies INSERT para las tablas append-only. Si el owner queda sujeto a RLS, el flujo puede fallar. Si `postgres` o `service_role` bypassean RLS por atributos especiales, entonces `FORCE RLS` no entrega la proteccion que el documento dice buscar.

**Impacto:** migraciones potencialmente aplicables pero RPCs y signup bloqueados en runtime, o proteccion FORCE RLS meramente aparente. Antes de migraciones reales debe decidirse explicitamente: sin `FORCE` en tablas escritas por RPC, o policies especificas para el rol owner/definer, probadas con el mismo rol efectivo que usara Supabase.

### C2. El modelo GRANT/REVOKE sigue incompleto frente a Supabase

La v1.1 agrega una matriz de permisos por tabla (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:142-166`) y un bloque consolidado de `REVOKE/GRANT` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1231-1277`). Pero el bloque real solo revoca permisos puntuales y concede `SELECT` a `anon` sobre `organizacion_clinica`; no concede explicitamente `SELECT/INSERT/UPDATE` a `authenticated` para las tablas donde la matriz dice que debe existir acceso directo.

Esto deja dos riesgos simultaneos:

- En proyectos con defaults amplios, `anon` y `authenticated` pueden conservar permisos no previstos sobre tablas nuevas si no se revocan de forma explicita.
- En proyectos con defaults restringidos, la app puede fallar por falta de grants aunque las policies RLS existan.

La documentacion actual de Supabase separa ambos controles: los grants determinan si un rol alcanza una tabla o funcion por la Data API, y RLS decide que filas puede ver o modificar. Tambien indica que en proyectos existentes los objetos nuevos en `public` pueden recibir grants automaticos a `anon`, `authenticated` y `service_role`.

**Impacto:** exposicion accidental o migraciones funcionalmente incompletas, segun el estado real de default privileges del proyecto. Antes de crear SQL real, la migracion 10 debe partir de un modelo cerrado: `REVOKE` base sobre objetos Fase 1, `GRANT` explicitos por tabla/rol/operacion, grants de secuencias si aplican, y verificacion contra `information_schema.role_table_grants` / `role_routine_grants`.

### C3. El rollback propuesto ejecuta revocaciones globales peligrosas sobre `public`

El rollback comienza con:

```sql
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
```

(`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1430-1435`)

Esto no esta acotado a objetos de Fase 1. En un proyecto Supabase real, `public` puede contener objetos externos al blueprint, extensiones, tablas auxiliares, views o funciones de administracion. Un rollback asi podria romper otras superficies de API o scripts que no pertenecen a esta fase.

**Impacto:** rollback destructivo por alcance, aunque no haga `DROP` de objetos ajenos. Debe reemplazarse por `REVOKE` objeto-por-objeto, usando la lista exacta de funciones/tablas creadas por Fase 1.

## Hallazgos medios

### M1. `invitacion_profesional` es aceptable como control de seguridad, pero requiere aprobacion arquitectonica explicita

La tabla nueva se declara como artefacto de seguridad de onboarding y no como entidad clinica (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:56`, `277-316`). Conceptualmente es aceptable dentro de Fase 1 porque corrige un riesgo critico de tenant takeover y no adelanta flujos clinicos de Fase 2.

La observacion es de gobierno del blueprint: Fase 1 pasa de 15 a 16 tablas y agrega provisioning externo con `service_role` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1606-1609`). Esa decision debe quedar aprobada por arquitectura antes de materializar migraciones, idealmente con el alcance minimo: invitacion por email/token, consumo unico, expiracion/revocacion y owner operacional del primer profesional.

### M2. El flujo `auth.users -> invitacion_profesional -> profesional` elimina el riesgo principal, pero conserva riesgos operativos

La v1.1 ya no toma `organizacion_id`, nombre ni datos de perfil desde metadata cliente; solo toma `token`, busca la invitacion por token + email y crea el profesional con datos server-side (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:344-411`). Eso elimina el riesgo original de autoasociarse a un tenant ajeno solo conociendo un `organizacion_id`.

Quedan pendientes operativos: no se define expiracion automatica, no se normaliza email/case sensitivity, no se documenta si un email puede tener invitaciones en multiples organizaciones, y `UNIQUE (email, organizacion_id)` impide una segunda invitacion historica para el mismo email/org aunque la anterior este consumida o revocada (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:294`). No bloquean el concepto, pero si deben resolverse antes de SQL final.

### M3. `REVOKE EXECUTE FROM PUBLIC` y `GRANT EXECUTE TO authenticated` estan bien planteados, pero incompletos como politica cerrada

El patron para funciones invocables es correcto: revocar a `PUBLIC` y conceder solo a `authenticated` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:107-117`, `1236-1261`). Tambien es correcto que `handle_new_user()` no reciba grant de aplicacion.

La brecha es que el bloque depende de firmas exactas todavia expresadas como plan. Si la migracion real cambia tipos, parametros por defecto o overloads, puede quedar una funcion `SECURITY DEFINER` expuesta por privilegios heredados/default. El QA debe validar por OID todas las funciones `prosecdef = true`, no solo las nombradas.

### M4. `anon` no deberia tener `SELECT` sobre `organizacion_clinica` si el onboarding ya es por token

La v1.1 concede `GRANT SELECT ON public.organizacion_clinica TO anon` para "flujo de registro" (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:207-214`, `1274-1277`). Pero el nuevo flujo por invitacion no necesita que un usuario anonimo liste o consulte organizaciones; el token y el email bastan para validar el signup.

La tabla contiene datos potencialmente innecesarios para anon: nombre legal, fantasia, email, telefono, direccion, zona horaria y estado (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:258-272`). Si existe una pantalla publica de verificacion de invitacion, deberia resolverse con una funcion minima o endpoint server-side, no con SELECT anon directo sobre la tabla raiz tenant.

### M5. `SET search_path = public, pg_temp` y nombres calificados son una mejora suficiente, con una observacion

El estandar nuevo exige `SECURITY DEFINER`, `SET search_path = public, pg_temp`, nombres de tabla calificados y ausencia de SQL dinamico de usuario (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:87-122`). Para este blueprint, esa combinacion es razonable si las migraciones reales cumplen literalmente el contrato.

La observacion: la documentacion de Supabase usa un patron aun mas estricto en ejemplos de triggers de Auth (`security definer set search_path = ''`) con referencias completamente calificadas. No es obligatorio adoptar ese patron, pero el QA debe verificar que no quedan llamadas no calificadas a funciones auxiliares, operadores o objetos resolubles por path dentro de funciones privilegiadas.

### M6. El contrato de columnas actualizables mejora el modelo, pero no esta completamente cerrado por GRANT de columnas

La seccion 5 reconoce correctamente que RLS filtra filas, no columnas (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:827-850`) y agrega triggers de proteccion para varias tablas (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:852-955`). Es una mejora real frente a v1.0.

Pero el documento promete `GRANT UPDATE(columna)` en el resumen de cambios (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:21`) y luego no lo materializa en la seccion de privilegios. La proteccion queda casi toda en triggers. Eso puede ser aceptable, pero debe declararse como decision: triggers como barrera principal, grants de columna solo si se decide implementarlos. Para `organizacion_clinica`, ademas, permitir `estado` por UPDATE directo requiere aclarar quien actua como administrador.

### M7. La suite QA hostil cubre las categorias correctas, pero aun no es ejecutable ni suficientemente discriminante

La v1.1 agrega pruebas para `anon`, `PUBLIC`, `pg_proc.proconfig`, signup fraudulento, cross-tenant via RPC, UPDATE por columna y `SET LOCAL` + UPDATE directo (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1337-1405`). La cobertura conceptual es buena.

Pero varios ejemplos fallarian por firma incorrecta antes de probar permisos, por ejemplo `crear_paciente('Test')` y `registrar_atencion(uuid_generate_v4())` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1342-1349`). Tambien quedan como comentarios las pruebas de signup fraudulento, cross-tenant via RPC y service_role no expuesto. Para migraciones reales, el archivo 11 debe contener SQL runnable o un harness documentado que distinga "permission denied" de "function does not exist", "invalid input" o "missing auth context".

### M8. `SET LOCAL app.rpc_cerrar_arancel` queda mejor acotado, condicionado al cierre real de grants

La v1.1 corrige el punto central: `authenticated` no deberia tener `UPDATE` sobre `valor_arancel`, por lo que `SET LOCAL` + UPDATE directo debe fallar antes del trigger (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1211-1229`, `1391-1398`). La idea es aceptable.

La condicion es que el modelo de grants sea cerrado. Si los defaults de Supabase conservan UPDATE por tabla o si no se revoca de forma verificable, el mecanismo vuelve a depender de disciplina externa.

## Hallazgos menores

### m1. No se detecta adelanto material de Fase 2

El documento excluye tablas, columnas, storage y RPCs de Fase 2 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:51-53`, `1643-1648`). La unica adicion es `invitacion_profesional`, que pertenece a seguridad de onboarding, no a funcionalidad clinica de Fase 2.

### m2. `obtener_mi_organizacion_id()` corrige la forward reference

La funcion aparece despues de `profesional` en migracion 02 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:413-430`). Ese hallazgo critico de v1.0 queda resuelto.

### m3. La declaracion de `service_role` es correcta, pero queda fuera del SQL

El blueprint declara que `service_role` no se expone al frontend y se usa solo para provisioning, invitaciones y reconciliacion (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:217-224`). Es correcto como principio, pero la verificacion propuesta incluye revisar `.env` de frontend (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md:1400-1404`), algo que no pertenece a un SQL QA puro. Conviene separarlo como checklist operacional fuera de migracion 11.

## Evaluacion por punto solicitado

1. **`invitacion_profesional` como tabla 16:** aceptable como excepcion de seguridad de Fase 1, pero requiere aprobacion arquitectonica explicita por cambiar el conteo y agregar provisioning externo.
2. **Flujo Auth corregido:** elimina el riesgo principal de autoasociacion a tenant ajeno, porque la organizacion proviene de invitacion server-side y no de metadata cliente.
3. **`FORCE RLS` y RPCs:** no aprobado; el documento reconoce una incertidumbre que puede bloquear auditoria/transiciones/signup.
4. **Roles/owners/GRANT/REVOKE:** incompleto; hay matriz, pero faltan grants/revokes exhaustivos y verificacion de defaults Supabase.
5. **`REVOKE EXECUTE FROM PUBLIC` / `GRANT EXECUTE TO authenticated`:** bien planteado para RPCs invocables, pero debe verificarse por OID y firmas reales.
6. **`anon` sobre `organizacion_clinica`:** no recomendado; expone informacion innecesaria para un flujo basado en invitacion.
7. **`search_path` y calificacion:** razonable si se cumple literalmente; considerar `search_path = ''` para funciones de Auth o justificar el patron elegido.
8. **Columnas actualizables:** mejora suficiente como contrato conceptual, pero debe alinearse con grants de columna o declarar triggers como unica barrera.
9. **QA hostil:** cubre categorias correctas, pero no esta listo como SQL ejecutable y algunas pruebas pueden fallar por causa equivocada.
10. **Rollback logico:** no aprobado; los `REVOKE ALL ON ALL ... IN SCHEMA public` son demasiado amplios.
11. **Fase 2:** no se detecta adelanto material.

## Riesgos pendientes

- RPCs `SECURITY DEFINER` bloqueadas por `FORCE RLS` en tablas append-only o de invitacion.
- Exposicion o bloqueo accidental por depender de default privileges en Supabase.
- `anon` con acceso a datos de organizaciones que no necesita para registrarse.
- QA hostil que no detecta la causa real de los fallos.
- Rollback que afecta objetos ajenos a Fase 1 dentro de `public`.
- Provisioning inicial e invitaciones dependientes de capa server-side todavia no especificada.

## Recomendacion final

**No pasar todavia a migraciones reales.**

La v1.1 esta bastante mas cerca que v1.0 y puede servir como base de una v1.2 corta. Para aprobarla, resolver antes:

1. Decidir y probar el modelo exacto de `FORCE RLS` para `invitacion_profesional`, auditoria y transiciones.
2. Reescribir grants/revokes como lista cerrada de objetos Fase 1, con revocacion base y grants explicitos por rol.
3. Eliminar `SELECT` anon sobre `organizacion_clinica` salvo que exista una justificacion de producto muy concreta.
4. Convertir el QA hostil en pruebas ejecutables con firmas reales y asserts sobre causa del error.
5. Reemplazar rollback global por rollback acotado objeto-por-objeto.

Con esos ajustes, el blueprint podria quedar **aprobado con observaciones** para transformarse en los 11 archivos SQL. En su estado actual, aprobarlo seria demasiado riesgoso justo en las capas que deben ser mas deterministas: privilegios, RLS, Auth y rollback.

## Referencias tecnicas externas

- [PostgreSQL Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html): documenta que los owners normalmente bypassean RLS, pero `ALTER TABLE ... FORCE ROW LEVEL SECURITY` puede someter al owner a las policies; superusuarios y roles con `BYPASSRLS` siguen bypasseando RLS.
- [Supabase: Hardening the Data API](https://supabase.com/docs/guides/api/securing-your-api) y [Supabase: Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): documentan que grants y RLS son capas separadas para la Data API, y que los proyectos existentes pueden tener grants automaticos por defecto en objetos nuevos de `public`.
