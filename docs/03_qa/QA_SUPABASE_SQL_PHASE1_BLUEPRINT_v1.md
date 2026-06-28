# QA Supabase SQL Phase 1 Blueprint v1

**Documento auditado:** `docs/02_architecture/SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md`
**Documentos base:** `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`, `QA_SUPABASE_SCHEMA_BLUEPRINT_v1_2.md`
**Alcance:** Auditoria tecnica del blueprint SQL previo a migraciones reales de Fase 1. No se modifica el blueprint, no se crea SQL final, no se crean migraciones y no se aplica nada en Supabase.

## Veredicto

**Rechazado para conversion directa a 11 migraciones `.sql`.**

El blueprint esta bien encaminado como diseno y resuelve varios puntos exigidos por el QA de `SUPABASE_SCHEMA_BLUEPRINT_v1.2`: separa Fase 1/Fase 2, propone FKs compuestas tenant-safe, explicita triggers Tipo B, define inmutabilidad y agrega una suite QA razonable. Sin embargo, no esta listo para transformarse mecanicamente en migraciones reales porque contiene bloqueos de orden/compilacion y huecos de seguridad operacional alrededor de `SECURITY DEFINER`, privilegios, RLS y onboarding por `auth.users`.

La recomendacion es crear una **v1.1 del blueprint SQL** antes de escribir los 11 archivos reales.

## Hallazgos criticos

### C1. `obtener_mi_organizacion_id()` esta en una migracion anterior a la tabla que referencia

El blueprint propone crear `obtener_mi_organizacion_id()` en migracion 01, con `LANGUAGE sql`, `SECURITY DEFINER` y `FROM profesional` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:77-85`). Pero `profesional` se crea recien en migracion 02 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:143-166`).

El propio documento reconoce el riesgo en linea 99 y vuelve a justificarlo en R1 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1864-1868`), pero lo deja como asunto de dry-run. Eso no es suficiente para pasar a migraciones reales. Una funcion SQL con dependencia directa a una relacion no existente puede fallar al crear la funcion o dejar una dependencia fragil segun como se materialice el SQL final. La solucion no debe depender de "no invocarla todavia".

**Impacto:** migracion 01 potencialmente no aplicable; RLS de migracion 09 depende de esta funcion; cualquier falla rompe el orden completo.

**Condicion para v1.1:** mover la funcion al final de migracion 02, despues de `profesional`, o cambiar explicitamente el patron y demostrarlo en dry-run real antes de aprobar.

### C2. Falta un modelo explicito de privilegios para funciones `SECURITY DEFINER`

El blueprint usa `SECURITY DEFINER` en la funcion RLS, el trigger de `auth.users` y todas las RPCs (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:81`, `175`, `1149`, `1213`, `1305`, `1377`, `1456`, `1518`, `1576`, `1632`, `1676`). Tambien reconoce el riesgo de escalacion (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1875-1878`).

Pero no define `REVOKE EXECUTE`, `GRANT EXECUTE`, owner esperado, roles autorizados (`anon`, `authenticated`, `service_role`) ni revocacion de permisos directos sobre tablas. La busqueda del documento no muestra ninguna declaracion `GRANT` o `REVOKE`. En Supabase/PostgreSQL esto es un bloqueo: las funciones pueden quedar ejecutables por roles no previstos si no se revocan privilegios por defecto, y el blueprint no demuestra que solo `authenticated` pueda invocar las RPCs clinicas.

**Impacto:** una RPC `SECURITY DEFINER` mal expuesta puede saltarse RLS y escribir en tablas protegidas con privilegios del owner.

**Condicion para v1.1:** agregar una seccion de privilegios por migracion: owner de funciones, `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC`, grants minimos a `authenticated`, bloqueo a `anon`, grants/revokes sobre tablas y criterio para `service_role`.

### C3. `search_path = public` no es una defensa suficiente para todas las funciones `SECURITY DEFINER`

El blueprint afirma repetidamente que `SET search_path = public` previene ataques de path injection (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:82`, `97`, `176`, `208`, `1127`, `1150`, `1214`, `1306`, `1378`, `1457`, `1519`, `1577`, `1633`, `1677`). Es una mejora frente al `search_path` por defecto, pero el documento no fija `pg_temp` al final ni califica objetos sensibles como `public.profesional`, `public.valor_arancel`, etc.

En funciones `SECURITY DEFINER`, el patron debe ser mas estricto que "public basta". El blueprint tiene demasiada superficie privilegiada como para aprobar sin una convencion cerrada de `search_path` y calificacion de objetos.

**Impacto:** riesgo de shadowing/path injection si el entorno o permisos permiten objetos temporales o nombres ambiguos. Aunque el riesgo exacto dependa de roles, no puede quedar sin especificar en un blueprint de migracion.

**Condicion para v1.1:** definir un patron unico para funciones privilegiadas, por ejemplo `SET search_path = public, pg_temp` o calificacion completa de objetos, y agregar QA que inspeccione `pg_proc.proconfig`.

### C4. El trigger `auth.users -> profesional` permite alta en una organizacion por metadata sin control de invitacion

La funcion `handle_new_user()` inserta en `profesional` usando `NEW.raw_user_meta_data->>'organizacion_id'`, `nombre_completo` y `nombre_para_documentos` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:172-194`). El contrato indica que si faltan datos el insert revierte (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:204-206`) y que es la unica via de creacion de `profesional` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:206`).

El problema no es solo viabilidad tecnica. Si el registro de usuarios esta disponible al cliente y basta enviar un `organizacion_id` existente en metadata, un usuario podria autoasociarse a una clinica ajena. El blueprint no define invitaciones, allowlist, token de alta, validacion server-side ni una regla que distinga registro autorizado de metadata arbitraria.

**Impacto:** riesgo critico de toma de tenant durante onboarding.

**Condicion para v1.1:** especificar el flujo autorizado de creacion de profesionales: preregistro administrativo, invitacion de un solo uso, validacion contra tabla de invitaciones, o bloqueo de signup publico. El trigger no debe confiar en metadata cliente sin mecanismo adicional.

## Hallazgos medios

### M1. RLS esta incompleto como contrato de UPDATE por columnas

Las policies de UPDATE usan condiciones de fila, por ejemplo `update_own_profesional`, `update_paciente`, `update_entrada`, `update_seguimiento`, `update_cita` y `update_atencion` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:943-948`, `997-1001`, `1025-1027`, `1040-1044`, `1056-1060`, `1081-1085`). El documento delega restricciones de columnas a triggers en algunas tablas, pero no en todas.

Ejemplos sensibles:
- `profesional`: un usuario podria intentar modificar campos que no deberian ser autoservicio si el privilegio UPDATE no esta limitado por columna.
- `paciente`: la policy permite actualizar cualquier fila no archivada de la org; el blueprint no limita columnas ni define si todos los profesionales pueden editar todos los pacientes.
- `historia_clinica`: permite UPDATE por org completa, sin trigger de columna ni privilegios por columna.

**Impacto:** RLS filtra filas, no es por si sola un modelo de autorizacion de campos. Sin `GRANT UPDATE(columna)` o triggers por columnas, el SQL final puede permitir mutaciones demasiado amplias.

**Condicion para v1.1:** declarar columnas actualizables por tabla, mecanismo exacto para protegerlas y tests negativos por columna.

### M2. Falta `FORCE ROW LEVEL SECURITY` o decision explicita sobre owner/bypass

El blueprint habilita RLS en las 15 tablas (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:899-916`), pero no decide si debe usarse `FORCE ROW LEVEL SECURITY`. Dado que las RPCs `SECURITY DEFINER` normalmente corren como owner y pueden bypassar RLS, esto puede ser intencional para escrituras controladas, pero debe quedar documentado.

**Impacto:** sin una decision explicita, es dificil auditar si el bypass de RLS por RPC es esperado o accidental.

**Condicion para v1.1:** documentar owner de tablas/funciones y si las RPCs deben bypassar RLS o usar validaciones manuales con RLS forzado.

### M3. El QA SQL propuesto es bueno como categorias, pero insuficiente para seguridad hostil

La migracion 11 propone tests de estructura, integridad tenant, Tipo B, append-only, inmutabilidad, RPCs y RLS (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1730-1831`). Cubre cross-tenant basico y casos negativos importantes (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1743-1762`, `1818-1829`).

Faltan pruebas explicitamente hostiles:
- `anon` no puede ejecutar RPCs.
- `authenticated` solo puede ejecutar RPCs permitidas.
- `PUBLIC` no conserva `EXECUTE` sobre funciones `SECURITY DEFINER`.
- `search_path` efectivo de funciones privilegiadas es el esperado.
- un usuario no puede crear `profesional` en org ajena solo enviando metadata.
- pruebas cross-tenant via RPC, no solo inserts directos.
- pruebas de UPDATE por columna en tablas con RLS permisiva.

**Impacto:** se podria aprobar una migracion que pasa QA funcional pero falla controles de exposicion.

### M4. `SET LOCAL app.rpc_cerrar_arancel` es viable, pero debe quedar acotado por privilegios y tests

El trigger de `valor_arancel` verifica `current_setting('app.rpc_cerrar_arancel', true)` y la RPC ejecuta `SET LOCAL app.rpc_cerrar_arancel = 'true'` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:808-824`, `1705-1714`). El mecanismo resuelve mejor que una frase ambigua "proviene de la RPC".

El documento, sin embargo, minimiza el riesgo como si un atacante con SQL arbitrario ya tuviera todo perdido (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1880-1883`). Para aprobar migraciones reales, debe probarse que el rol de aplicacion no tiene ningun camino para ejecutar `SET LOCAL` y luego `UPDATE valor_arancel` directamente en la misma transaccion.

**Impacto:** medio, porque la defensa principal es no conceder UPDATE directo; pero el blueprint aun no define grants/revokes.

### M5. Rollback logico demasiado grueso

El rollback propuesto dice que no habra rollback automatico por migracion y que en produccion se requieren migraciones inversas manuales, con `DROP TABLE` en orden inverso si no hay datos (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1910-1916`). Tambien exige preparar `rollback_phase1.sql` antes de produccion (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:1923-1924`, `1989`).

Esto es aceptable como orientacion, pero no como blueprint listo para migraciones. Debe listar objetos no-tabla: triggers en `auth.users`, funciones, policies, indices, extensiones, grants, custom settings usados por funciones y orden de drops.

**Impacto:** ante una aplicacion parcial o rollback de staging, se pueden dejar funciones `SECURITY DEFINER`, triggers de Auth o policies residuales.

## Hallazgos menores

### m1. Orden general de migraciones es razonable salvo la funcion RLS

La tabla de migraciones propone 01 helpers, 02 identity/auth, 03 catalogos, 04 pacientes, 05 agenda, 06 atencion, 07 facturacion, 08 triggers, 09 RLS, 10 RPCs, 11 QA (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:40-53`). El orden es mayormente migrable y respeta dependencias de tablas. El bloqueo esta concentrado en `obtener_mi_organizacion_id()` antes de `profesional`.

### m2. FKs compuestas tenant-safe estan bien encaminadas

Las tablas ancla declaran `UNIQUE (organizacion_id, id)` y las relaciones internas relevantes usan FK compuesta, por ejemplo `evento_auditoria_minima -> profesional`, `valor_arancel -> tipo_atencion/profesional`, `historia_clinica -> paciente`, `atencion_clinica -> paciente/profesional/tipo_atencion/cita`, y transiciones (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:239-240`, `286-291`, `331-334`, `531-537`, `558-561`, `624-629`).

Esto satisface la direccion del QA v1.2. La condicion pendiente es probar negativos cross-tenant tanto directos como via RPC.

### m3. Triggers Tipo B estan bien ubicados, pero la funcion generica debe mantenerse cerrada

`validate_cross_tenant_ref()` valida `NEW.organizacion_id` contra la tabla referenciada y se aplica a `seguimiento`, `cita` y `cobro` despues de existir `atencion_clinica` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:833-892`). El patron es viable.

El uso de SQL dinamico esta acotado a `TG_ARGV`, no a parametros de usuario, pero en migraciones reales conviene no exponer la funcion genericamente y mantener nombres de tabla fijos desde el trigger.

### m4. No se detecta adelanto fisico de Fase 2

El blueprint excluye explicitamente tablas, columnas, Storage buckets y RPCs de Fase 2 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.md:33-34`, `1974-1979`). En las tablas Fase 1 revisadas no se detectan columnas `relacion_centro_id` ni `zona_domiciliaria_id`.

## Evaluacion por punto solicitado

1. **Orden de migraciones:** mayormente correcto; bloqueado por `obtener_mi_organizacion_id()` en migracion 01.
2. **`obtener_mi_organizacion_id()` antes de `profesional`:** no aprobado. Debe moverse o demostrarse con prueba real, no dejarse como riesgo.
3. **`SECURITY DEFINER`:** uso justificado conceptualmente, pero no aprobable sin grants/revokes, owner y tests.
4. **`search_path`:** incompleto; `public` solo no alcanza como estandar hostil.
5. **Trigger `auth.users -> profesional`:** tecnicamente viable en Supabase, pero inseguro si confia en metadata cliente sin invitacion/validacion.
6. **FKs compuestas tenant-safe:** aprobado con observaciones; el patron es correcto.
7. **Triggers Tipo B:** aprobado con observaciones; orden y logica son migrables.
8. **Inmutabilidad y append-only:** razonable, pero requiere pruebas por columna y grants coherentes.
9. **`SET LOCAL app.rpc_cerrar_arancel`:** viable como bandera transaccional; depende de bloqueo real de UPDATE directo.
10. **Policies RLS:** incompletas como contrato final; faltan privileges, columnas y decision sobre bypass/owner.
11. **RPCs T00:** funcionalmente trazables; seguridad de exposicion pendiente.
12. **RPCs controladas:** razonables; dependen de privilegios y tests negativos.
13. **QA SQL propuesto:** buena base, insuficiente en seguridad hostil.
14. **Riesgos operacionales:** identificados, pero algunos se dejan como dry-run cuando deberian resolverse en blueprint.
15. **Rollback logico:** insuficiente; debe cubrir objetos, privilegios y trigger sobre `auth.users`.
16. **Fase 2 no adelantada:** aprobado.

## Riesgos pendientes

- Exposicion accidental de RPCs `SECURITY DEFINER` a `PUBLIC` o `anon`.
- Alta fraudulenta de profesional en tenant ajeno via `raw_user_meta_data`.
- RLS que controla filas pero no columnas.
- Funciones privilegiadas con `search_path` menos estricto de lo necesario.
- Rollback que elimina tablas pero deja funciones, policies, triggers o grants.
- QA que prueba integridad directa pero no todos los caminos via RPC.

## Recomendacion final

**No pasar todavia a los 11 archivos reales de migracion `.sql`.**

Crear `SUPABASE_SQL_PHASE1_BLUEPRINT_v1.1.md` con estas correcciones minimas:

1. Mover `obtener_mi_organizacion_id()` despues de `profesional` o justificar con dry-run real y mecanismo exacto.
2. Agregar seccion completa de roles, owners, `REVOKE`, `GRANT`, permisos por tabla y permisos por funcion.
3. Endurecer `SECURITY DEFINER`: `search_path` cerrado, calificacion de objetos y pruebas sobre `pg_proc`.
4. Redisenar o acotar el trigger de `auth.users` para no confiar en metadata cliente sin invitacion/validacion.
5. Definir columnas actualizables por tabla y mecanismo SQL exacto para protegerlas.
6. Ampliar QA con pruebas de roles, grants, anon/authenticated, cross-tenant via RPC y UPDATE por columna.
7. Convertir rollback logico en checklist de objetos: triggers, functions, policies, indexes, grants y tablas.

Despues de esa v1.1, el blueprint probablemente podria quedar **aprobado con observaciones** para transformarse en migraciones reales. En su estado actual, aprobarlo seria demasiado permisivo justo en las zonas que el proyecto necesita tratar con mas hostilidad: `SECURITY DEFINER`, RLS, Auth y rollback.
