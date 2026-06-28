# QA Supabase SQL Phase 1 Blueprint v1.2

**Documento auditado:** `docs/02_architecture/SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md`  
**QA de entrada:** `docs/03_qa/QA_SUPABASE_SQL_PHASE1_BLUEPRINT_v1_1.md`  
**Alcance:** Auditoria tecnica del blueprint SQL previo a migraciones reales de Fase 1. No se modifica el blueprint, no se crea SQL final, no se crean migraciones y no se aplica nada en Supabase.

## Veredicto

**Aprobado con observaciones para transformarse en 11 archivos reales de migracion SQL.**

La v1.2 corrige los bloqueos criticos de v1.1: elimina `FORCE ROW LEVEL SECURITY` de forma determinista, cierra el modelo de privilegios con `REVOKE` base + `GRANT` explicito, elimina acceso `anon`, acota el rollback a objetos Fase 1, mejora `invitacion_profesional` y vuelve el QA hostil mucho mas discriminante.

No quedan riesgos criticos evidentes en `SECURITY DEFINER`, RLS, Auth o privilegios. La aprobacion no significa que la conversion pueda ser mecanica copiando solo v1.2: el documento usa varias referencias a v1.1 para DDL, policies, triggers y RPCs. Al crear los 11 `.sql`, esas piezas deben materializarse de forma completa en los archivos finales y verificarse con un dry-run limpio.

## Hallazgos criticos

**No se detectan hallazgos criticos.**

Los puntos que causaron el rechazo de v1.1 estan resueltos a nivel de decision arquitectonica/SQL blueprint:

- `FORCE RLS` fue eliminado de todas las tablas Fase 1 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:256-283`, `455-478`).
- `anon` no recibe grants sobre tablas ni funciones Fase 1 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:97-99`, `161-167`).
- Las tablas Fase 1 reciben `REVOKE ALL` base por objeto antes de grants explicitos (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:105-159`).
- El rollback ya no usa comandos globales sobre todo `public` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:842-878`).

## Hallazgos medios

### M1. v1.2 no es completamente autocontenida para generar SQL final

Varias secciones indican "sin cambios respecto a v1.1" en lugar de reproducir el SQL completo: DDL de migraciones 03-07 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:409-411`), contrato/triggers (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:425-451`), policies (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:480-499`) y RPCs (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:503-519`).

Esto no bloquea la aprobacion, pero si impide convertir v1.2 como fuente unica y mecanica. La conversion a migraciones reales debe integrar explicitamente las definiciones completas de v1.1 mas las correcciones de v1.2, evitando que una referencia resumida se transforme en SQL incompleto.

### M2. Grants de funciones deberian revocar tambien a `anon` y `authenticated` antes del grant final

El modelo de tablas esta bien cerrado: `REVOKE ALL` por tabla para `anon`, `authenticated` y `PUBLIC`, seguido de grants explicitos (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:109-159`). En funciones, en cambio, el bloque revoca `EXECUTE` desde `PUBLIC` y luego concede a `authenticated` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:173-203`).

Esto es razonable para funciones nuevas con privilegio por defecto via `PUBLIC`, pero la logica declarada de "modelo cerrado" seria mas robusta si cada funcion Fase 1 revocara explicitamente desde `anon`, `authenticated` y `PUBLIC`, y luego concediera solo las invocables a `authenticated`. El QA por OID reduce el riesgo, pero la migracion real deberia adoptar la forma mas cerrada.

### M3. El QA hostil es suficientemente discriminante como blueprint, pero aun contiene bloques no ejecutables

La v1.2 mejora mucho el QA: usa firmas reales para RPCs, valida `PUBLIC` por OID, verifica privilegios de `authenticated`, prueba `SET LOCAL` + UPDATE directo y declara causa esperada de fallo (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:584-631`, `678-821`).

Persisten fragmentos que no son SQL final: `IN (...lista 16 tablas...)`, `...lista 23 funciones...`, placeholders como `<paciente_org_B>`, y escenarios de signup descritos como comentarios (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:587-590`, `752-801`, `1023-1032`). Para migracion 11, esos bloques deben convertirse en SQL runnable o en un harness externo claramente versionado.

### M4. `invitacion_profesional` es correcta y operable, con un ajuste recomendado para concurrencia

La tabla 16 queda bien justificada como artefacto de seguridad de onboarding, no como adelanto de Fase 2. Cumple los puntos solicitados: token unico (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:309`), email normalizado en indice parcial (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:318-321`), `expira_en` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:314`), historial permitido por reemplazo del unique absoluto (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:329-336`) y un solo uso por cambio a `consumida` (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:384-387`).

Recomendacion para SQL real: en `handle_new_user()`, considerar bloquear la invitacion seleccionada con `FOR UPDATE` o hacer un `UPDATE ... WHERE token = ... AND estado = 'pendiente' AND expira_en > now() RETURNING ...`. Asi el consumo de token queda determinista ante doble signup concurrente, no solo protegido indirectamente por constraints de `auth.users`/`profesional`.

### M5. `organizacion_clinica.estado` queda demasiado abierto para un campo operacional sensible

El blueprint decide que todo profesional de la organizacion puede actualizar campos operativos de `organizacion_clinica`, incluido `estado`, y posterga roles admin para una fase futura (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:439`). Es una decision aceptable para Fase 1 si el producto todavia no modela administradores internos.

Riesgo residual: un profesional autenticado podria suspender/desactivar la organizacion si la policy y los grants lo permiten. No es un bloqueo SQL, pero debe quedar como riesgo de producto/operacion antes de salida a produccion.

## Hallazgos menores

### m1. El uso de `SET search_path = public, pg_temp` es aceptable si se cumple literalmente

La v1.2 mantiene `SET search_path = public, pg_temp`, nombres calificados y sin SQL dinamico de usuario (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:77-86`, `503-511`). Es suficiente para aprobar esta fase. El QA real debe comprobar por `pg_proc.proconfig` todas las funciones `SECURITY DEFINER`.

### m2. El token malformado deberia tener prueba hostil propia

`handle_new_user()` castea el token desde metadata a UUID (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:351`). Un token ausente se maneja, y token invalido UUID se prueba conceptualmente (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:757-765`), pero conviene agregar caso de token no casteable, por ejemplo texto arbitrario, para confirmar que el signup revierte sin crear `profesional`.

### m3. Rollback acotado aprobado, con pequenas omisiones de simetria

El rollback ya opera objeto por objeto y solo sobre Fase 1 (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:842-1018`). Para mayor simetria con el modelo cerrado, conviene revocar tambien `anon`/`PUBLIC` en funciones/tablas Fase 1 durante rollback, aunque no deberian tener grants si la migracion 10 se aplico correctamente.

### m4. No se detecta adelanto de Fase 2

El documento mantiene fuera de alcance tablas, columnas, Storage buckets y SQL ejecutado en Supabase (`SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2.md:53`). La busqueda del blueprint no muestra incorporacion de `zona_domiciliaria`, `relacion_centro`, `acuerdo_comercial`, `liquidacion`, `item_liquidacion`, `fotografia_clinica`, `consentimiento`, `informe_sesion` ni `intento_contacto` fuera de la declaracion de fuera de alcance.

## Evaluacion por punto solicitado

1. **Eliminar FORCE RLS:** aprobado. La decision es segura y determinista para este modelo porque evita bloquear RPCs `SECURITY DEFINER` y compensa con grants, RLS, triggers y validaciones manuales.
2. **REVOKE base + GRANT explicito:** aprobado con observacion. Tablas quedan bien cerradas; funciones deberian revocar explicitamente tambien `anon` y `authenticated` antes del grant final.
3. **`anon` sin acceso:** aprobado. No recibe grants de tablas ni funciones Fase 1, y el QA lo verifica.
4. **`authenticated` solo con privilegios esperados:** aprobado con observacion. La matriz es coherente; debe materializarse completa y verificarse contra `information_schema`.
5. **`SET LOCAL app.rpc_cerrar_arancel`:** aprobado. `authenticated` no tiene UPDATE directo sobre `valor_arancel`, por lo que el intento debe fallar antes del trigger.
6. **Rollback acotado:** aprobado. Ya no hay `REVOKE ALL ON ALL ... IN SCHEMA public`.
7. **`invitacion_profesional`:** aprobado con observacion de concurrencia. Token unico, email normalizado, `expira_en`, indice parcial, historial y consumo unico estan cubiertos.
8. **QA hostil:** aprobado como blueprint; requiere conversion final de placeholders/comentarios a SQL runnable.
9. **Fase 2:** aprobado. No se detecta adelanto material.
10. **SECURITY DEFINER/RLS/Auth/privilegios:** sin riesgos criticos pendientes.

## Riesgos pendientes

- Error de traduccion al pasar de blueprint resumido a SQL real, porque v1.2 referencia v1.1 en varias zonas.
- Grants de funciones menos cerrados que los grants de tablas si no se revoca explicitamente `anon`/`authenticated`.
- Doble consumo concurrente de invitacion si el trigger no bloquea fila o consume con `UPDATE ... RETURNING`.
- QA hostil incompleto si los placeholders no se reemplazan por datos fixtures y asserts reales.
- Campo `organizacion_clinica.estado` editable por cualquier profesional de la organizacion hasta que exista rol admin.

## Recomendacion final

**Puede pasar a migraciones SQL reales, con observaciones obligatorias de conversion.**

Recomiendo crear los 11 archivos `.sql` a partir de v1.2 como fuente de decisiones y de v1.1 como fuente de definiciones completas donde v1.2 dice "sin cambios". Antes de considerar terminada la conversion:

1. Materializar todo SQL faltante: DDL, triggers, policies, RPCs, grants, rollback y QA.
2. Aplicar `REVOKE EXECUTE` de funciones desde `anon`, `authenticated` y `PUBLIC`, luego conceder solo lo necesario.
3. Convertir migracion 11 en SQL/harness ejecutable sin placeholders.
4. Probar dry-run completo en proyecto Supabase limpio y revisar `pg_proc`, `information_schema`, RLS y rollback.

Con esas condiciones, la v1.2 esta suficientemente madura para salir de blueprint y entrar a migraciones reales.

## Referencias tecnicas externas

- [PostgreSQL Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html): base para validar la decision de no usar `FORCE ROW LEVEL SECURITY` con RPCs `SECURITY DEFINER`.
- [Supabase: Hardening the Data API](https://supabase.com/docs/guides/api/securing-your-api) y [Supabase: Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): base para revisar grants, RLS y exposicion de `anon`/`authenticated`.
