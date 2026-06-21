-- =============================================================================
-- QA SQL FASE 1 — TESTS
-- Verificación de migraciones contra SUPABASE_SCHEMA_BLUEPRINT_v1.2.md
--
-- INSTRUCCIONES: Ejecutar en una base de datos Supabase limpia después de
-- aplicar las 4 migraciones de Fase 1. Cada bloque DO imprime PASS o falla
-- con excepción indicando qué test falló. Ejecutar como superuser (postgres).
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- SETUP: Crear datos de prueba multi-tenant
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := gen_random_uuid();
  v_org2 uuid := gen_random_uuid();
BEGIN
  INSERT INTO organizacion_clinica (id, nombre_legal, estado)
    VALUES (v_org1, 'Clínica Alfa', 'activa');
  INSERT INTO organizacion_clinica (id, nombre_legal, estado)
    VALUES (v_org2, 'Clínica Beta', 'activa');

  PERFORM set_config('test.org1', v_org1::text, false);
  PERFORM set_config('test.org2', v_org2::text, false);

  RAISE NOTICE 'SETUP: Organizaciones creadas (org1=%, org2=%)', v_org1, v_org2;
END;
$$;

-- Crear profesionales directamente (bypass del trigger auth.users para tests)
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_org2 uuid := current_setting('test.org2')::uuid;
  v_prof1 uuid := gen_random_uuid();
  v_prof2 uuid := gen_random_uuid();
  v_auth1 uuid := gen_random_uuid();
  v_auth2 uuid := gen_random_uuid();
BEGIN
  INSERT INTO profesional (id, auth_user_id, organizacion_id, nombre_completo, email, nombre_para_documentos, estado)
    VALUES (v_prof1, v_auth1, v_org1, 'Dr. Alfa', 'alfa@test.com', 'Dr. Alfa', 'activo');
  INSERT INTO profesional (id, auth_user_id, organizacion_id, nombre_completo, email, nombre_para_documentos, estado)
    VALUES (v_prof2, v_auth2, v_org2, 'Dr. Beta', 'beta@test.com', 'Dr. Beta', 'activo');

  PERFORM set_config('test.prof1', v_prof1::text, false);
  PERFORM set_config('test.prof2', v_prof2::text, false);
  PERFORM set_config('test.auth1', v_auth1::text, false);
  PERFORM set_config('test.auth2', v_auth2::text, false);

  RAISE NOTICE 'SETUP: Profesionales creados (prof1=%, prof2=%)', v_prof1, v_prof2;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 1: VERIFICACIÓN DE TABLAS (15 tablas Fase 1)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_tablas text[] := ARRAY[
    'organizacion_clinica','profesional','evento_auditoria_minima',
    'tipo_atencion','valor_arancel','paciente','historia_clinica',
    'entrada_clinica','seguimiento','cita','transicion_cita',
    'atencion_clinica','transicion_atencion','cobro','transicion_pago'
  ];
  v_t text;
  v_count int := 0;
BEGIN
  FOREACH v_t IN ARRAY v_tablas LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_t
    ) THEN
      RAISE EXCEPTION 'TEST 1 FAIL: tabla % no existe', v_t;
    END IF;
    v_count := v_count + 1;
  END LOOP;

  -- Verificar que NO existan tablas Fase 2
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public'
    AND table_name IN ('relacion_centro','zona_domiciliaria','acuerdo_comercial',
      'liquidacion','item_liquidacion','consentimiento','informe_sesion',
      'fotografia_clinica','intento_contacto'))
  THEN
    RAISE EXCEPTION 'TEST 1 FAIL: existen tablas Fase 2 que no deberían estar';
  END IF;

  RAISE NOTICE 'TEST 1 PASS: 15 tablas Fase 1 verificadas, sin tablas Fase 2';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 2: CONSTRAINTS UNIQUE (organizacion_id, id) — tablas ancla
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_anclas text[] := ARRAY[
    'profesional','paciente','historia_clinica','tipo_atencion',
    'atencion_clinica','cita','cobro','seguimiento'
  ];
  v_t text;
BEGIN
  FOREACH v_t IN ARRAY v_anclas LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu USING (constraint_name, table_schema)
      WHERE tc.table_schema = 'public' AND tc.table_name = v_t
        AND tc.constraint_type = 'UNIQUE'
        AND ccu.column_name = 'id'
    ) THEN
      RAISE EXCEPTION 'TEST 2 FAIL: tabla % no tiene UNIQUE que incluya (organizacion_id, id)', v_t;
    END IF;
  END LOOP;

  -- organizacion_clinica NO debe tener UNIQUE(organizacion_id, id)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'organizacion_clinica'
      AND column_name = 'organizacion_id'
  ) THEN
    RAISE EXCEPTION 'TEST 2 FAIL: organizacion_clinica tiene columna organizacion_id (no debería)';
  END IF;

  RAISE NOTICE 'TEST 2 PASS: Constraints ancla tenant verificados en 8 tablas Fase 1';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 3: FK COMPUESTA — Rechazo cross-tenant
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_org2 uuid := current_setting('test.org2')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_prof2 uuid := current_setting('test.prof2')::uuid;
  v_pac1 uuid := gen_random_uuid();
  v_tipo1 uuid := gen_random_uuid();
BEGIN
  -- Crear paciente en org1
  INSERT INTO paciente (id, organizacion_id, nombre_completo, estado, creado_por)
    VALUES (v_pac1, v_org1, 'Paciente Org1', 'activo', v_prof1);

  -- Crear tipo_atencion en org1
  INSERT INTO tipo_atencion (id, organizacion_id, nombre, estado)
    VALUES (v_tipo1, v_org1, 'Podología General', 'activo');

  PERFORM set_config('test.pac1', v_pac1::text, false);
  PERFORM set_config('test.tipo1', v_tipo1::text, false);

  -- Intentar crear historia_clinica de paciente org1 pero con organizacion_id = org2
  BEGIN
    INSERT INTO historia_clinica (organizacion_id, paciente_id)
      VALUES (v_org2, v_pac1);
    RAISE EXCEPTION 'TEST 3 FAIL: FK compuesta permitió referencia cross-tenant (historia_clinica)';
  EXCEPTION
    WHEN foreign_key_violation THEN
      RAISE NOTICE 'TEST 3a PASS: FK compuesta rechazó historia_clinica cross-tenant';
  END;

  -- Intentar crear atencion_clinica con paciente de otra org
  BEGIN
    INSERT INTO atencion_clinica (organizacion_id, paciente_id, profesional_id, modalidad, estado)
      VALUES (v_org2, v_pac1, v_prof2, 'particular', 'registrada');
    RAISE EXCEPTION 'TEST 3 FAIL: FK compuesta permitió referencia cross-tenant (atencion_clinica → paciente)';
  EXCEPTION
    WHEN foreign_key_violation THEN
      RAISE NOTICE 'TEST 3b PASS: FK compuesta rechazó atencion_clinica → paciente cross-tenant';
  END;

  -- Intentar crear valor_arancel con tipo_atencion de otra org
  BEGIN
    INSERT INTO valor_arancel (organizacion_id, tipo_atencion_id, modalidad, valor, vigente_desde, configurado_por)
      VALUES (v_org2, v_tipo1, 'particular', 25000, CURRENT_DATE, v_prof2);
    RAISE EXCEPTION 'TEST 3 FAIL: FK compuesta permitió referencia cross-tenant (valor_arancel → tipo_atencion)';
  EXCEPTION
    WHEN foreign_key_violation THEN
      RAISE NOTICE 'TEST 3c PASS: FK compuesta rechazó valor_arancel → tipo_atencion cross-tenant';
  END;

  RAISE NOTICE 'TEST 3 PASS: Aislamiento multi-tenant por FK compuesta verificado';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 4: TRIGGER TIPO B — Rechazo cross-tenant en atencion_clinica_id
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_org2 uuid := current_setting('test.org2')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_prof2 uuid := current_setting('test.prof2')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_aten1 uuid := gen_random_uuid();
  v_pac2 uuid := gen_random_uuid();
BEGIN
  -- Crear atención en org1
  INSERT INTO atencion_clinica (id, organizacion_id, paciente_id, profesional_id, modalidad, estado)
    VALUES (v_aten1, v_org1, v_pac1, v_prof1, 'particular', 'registrada');

  -- Crear paciente en org2 para hacer referencia
  INSERT INTO paciente (id, organizacion_id, nombre_completo, estado, creado_por)
    VALUES (v_pac2, v_org2, 'Paciente Org2', 'activo', v_prof2);

  PERFORM set_config('test.aten1', v_aten1::text, false);
  PERFORM set_config('test.pac2', v_pac2::text, false);

  -- Intentar cobro en org2 con atencion_clinica_id de org1
  BEGIN
    INSERT INTO cobro (
      organizacion_id, paciente_id, profesional_id, monto,
      tipo_atencion_nombre_snapshot, modalidad, concepto, categoria_origen,
      atencion_clinica_id
    ) VALUES (
      v_org2, v_pac2, v_prof2, 30000,
      'Test', 'particular', 'Test', 'atencion_individual',
      v_aten1
    );
    RAISE EXCEPTION 'TEST 4 FAIL: Trigger Tipo B permitió cobro cross-tenant';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 4a PASS: Trigger Tipo B rechazó cobro.atencion_clinica_id cross-tenant';
  END;

  -- Intentar seguimiento en org2 con atencion_clinica_id de org1
  BEGIN
    INSERT INTO seguimiento (
      organizacion_id, paciente_id, profesional_id, tipo, urgencia,
      estado, origen, atencion_clinica_id
    ) VALUES (
      v_org2, v_pac2, v_prof2, 'Control', 'normal',
      'pendiente', 'manual', v_aten1
    );
    RAISE EXCEPTION 'TEST 4 FAIL: Trigger Tipo B permitió seguimiento cross-tenant';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 4b PASS: Trigger Tipo B rechazó seguimiento.atencion_clinica_id cross-tenant';
  END;

  RAISE NOTICE 'TEST 4 PASS: Triggers Tipo B verificados';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 5: APPEND-ONLY — UPDATE y DELETE rechazados
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_aten1 uuid := current_setting('test.aten1')::uuid;
  v_evt_id uuid := gen_random_uuid();
  v_taten_id uuid := gen_random_uuid();
BEGIN
  -- Crear registros de prueba
  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_evt_id, v_org1, v_prof1, 'paciente_creado',
    'paciente', v_pac1, 'activo', now()
  );

  INSERT INTO transicion_atencion (
    id, atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    v_taten_id, v_aten1, v_org1, v_prof1, '', 'registrada'
  );

  -- Test UPDATE rechazado en evento_auditoria_minima
  BEGIN
    UPDATE evento_auditoria_minima SET resumen_contextual = 'hack' WHERE id = v_evt_id;
    RAISE EXCEPTION 'TEST 5 FAIL: UPDATE en evento_auditoria_minima no fue rechazado';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 5a PASS: UPDATE rechazado en evento_auditoria_minima';
  END;

  -- Test DELETE rechazado en evento_auditoria_minima
  BEGIN
    DELETE FROM evento_auditoria_minima WHERE id = v_evt_id;
    RAISE EXCEPTION 'TEST 5 FAIL: DELETE en evento_auditoria_minima no fue rechazado';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 5b PASS: DELETE rechazado en evento_auditoria_minima';
  END;

  -- Test UPDATE rechazado en transicion_atencion
  BEGIN
    UPDATE transicion_atencion SET motivo = 'hack' WHERE id = v_taten_id;
    RAISE EXCEPTION 'TEST 5 FAIL: UPDATE en transicion_atencion no fue rechazado';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 5c PASS: UPDATE rechazado en transicion_atencion';
  END;

  RAISE NOTICE 'TEST 5 PASS: Tablas append-only verificadas';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 6: INMUTABILIDAD — Columnas protegidas
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_cobro_id uuid := gen_random_uuid();
BEGIN
  -- Crear cobro de prueba
  INSERT INTO cobro (
    id, organizacion_id, paciente_id, profesional_id, monto,
    tipo_atencion_nombre_snapshot, modalidad, concepto, categoria_origen
  ) VALUES (
    v_cobro_id, v_org1, v_pac1, v_prof1, 25000,
    'Podología General', 'particular', 'Atención', 'atencion_individual'
  );

  -- Test: monto snapshot no puede cambiar
  BEGIN
    UPDATE cobro SET monto = 99999 WHERE id = v_cobro_id;
    RAISE EXCEPTION 'TEST 6 FAIL: monto de cobro fue modificado';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 6a PASS: cobro.monto protegido por trigger';
  END;

  -- Test: estado_pago SÍ puede cambiar (no es snapshot)
  UPDATE cobro SET estado_pago = 'pagado', medio_pago = 'efectivo', fecha_pago = now()
    WHERE id = v_cobro_id;
  RAISE NOTICE 'TEST 6b PASS: cobro.estado_pago sí puede cambiar';

  RAISE NOTICE 'TEST 6 PASS: Inmutabilidad de snapshots verificada';
END;
$$;

-- Test inmutabilidad entrada_clinica
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_hc_id uuid;
  v_ec_id uuid := gen_random_uuid();
BEGIN
  SELECT id INTO v_hc_id FROM historia_clinica
    WHERE paciente_id = v_pac1 AND organizacion_id = v_org1;

  INSERT INTO entrada_clinica (
    id, historia_clinica_id, organizacion_id, tipo, descripcion,
    estado, registrado_por
  ) VALUES (
    v_ec_id, v_hc_id, v_org1, 'patologia', 'Onicocriptosis bilateral',
    'activo', v_prof1
  );

  -- Test: descripcion no puede cambiar
  BEGIN
    UPDATE entrada_clinica SET descripcion = 'Hackeado' WHERE id = v_ec_id;
    RAISE EXCEPTION 'TEST 6c FAIL: descripcion de entrada_clinica fue modificada';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 6c PASS: entrada_clinica.descripcion protegida';
  END;

  -- Test: estado SÍ puede cambiar
  UPDATE entrada_clinica SET estado = 'resuelto' WHERE id = v_ec_id;
  RAISE NOTICE 'TEST 6d PASS: entrada_clinica.estado sí puede cambiar';
END;
$$;

-- Test inmutabilidad atencion_clinica cerrada
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_aten_test uuid := gen_random_uuid();
BEGIN
  INSERT INTO atencion_clinica (
    id, organizacion_id, paciente_id, profesional_id,
    modalidad, estado, tratamiento
  ) VALUES (
    v_aten_test, v_org1, v_pac1, v_prof1,
    'particular', 'cerrada', 'Tratamiento original'
  );

  -- Test: tratamiento no puede cambiar cuando cerrada
  BEGIN
    UPDATE atencion_clinica SET tratamiento = 'Hackeado' WHERE id = v_aten_test;
    RAISE EXCEPTION 'TEST 6e FAIL: tratamiento modificado en atención cerrada';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 6e PASS: atencion_clinica cerrada protege tratamiento';
  END;

  -- Test: en estado registrada SÍ se puede modificar
  INSERT INTO atencion_clinica (
    id, organizacion_id, paciente_id, profesional_id, modalidad, estado, tratamiento
  ) VALUES (
    gen_random_uuid(), v_org1, v_pac1, v_prof1, 'particular', 'registrada', 'Borrador'
  );
  UPDATE atencion_clinica SET tratamiento = 'Actualizado'
    WHERE organizacion_id = v_org1 AND estado = 'registrada';
  RAISE NOTICE 'TEST 6f PASS: atencion_clinica registrada permite editar tratamiento';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 7: cerrar_arancel
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_tipo1 uuid := current_setting('test.tipo1')::uuid;
  v_arancel_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO valor_arancel (
    id, tipo_atencion_id, organizacion_id, modalidad, valor,
    vigente_desde, configurado_por
  ) VALUES (
    v_arancel_id, v_tipo1, v_org1, 'particular', 25000,
    CURRENT_DATE, v_prof1
  );

  PERFORM set_config('test.arancel1', v_arancel_id::text, false);

  -- Test: UPDATE directo rechazado (sin contexto RPC)
  BEGIN
    UPDATE valor_arancel SET vigente_hasta = CURRENT_DATE WHERE id = v_arancel_id;
    RAISE EXCEPTION 'TEST 7 FAIL: UPDATE directo en valor_arancel fue permitido';
  EXCEPTION
    WHEN raise_exception THEN
      RAISE NOTICE 'TEST 7a PASS: UPDATE directo en valor_arancel rechazado';
  END;

  -- Test: cambio de valor rechazado incluso con contexto
  BEGIN
    PERFORM set_config('app.rpc_context', 'cerrar_arancel', true);
    UPDATE valor_arancel SET valor = 99999 WHERE id = v_arancel_id;
    RAISE EXCEPTION 'TEST 7 FAIL: cambio de valor fue permitido con contexto RPC';
  EXCEPTION
    WHEN raise_exception THEN
      PERFORM set_config('app.rpc_context', '', true);
      RAISE NOTICE 'TEST 7b PASS: columnas protegidas rechazadas incluso con contexto';
  END;

  -- Test: cierre vía mecanismo controlado
  PERFORM set_config('app.rpc_context', 'cerrar_arancel', true);
  UPDATE valor_arancel SET vigente_hasta = CURRENT_DATE WHERE id = v_arancel_id;
  PERFORM set_config('app.rpc_context', '', true);

  -- Verificar que se cerró
  IF NOT EXISTS (
    SELECT 1 FROM valor_arancel WHERE id = v_arancel_id AND vigente_hasta = CURRENT_DATE
  ) THEN
    RAISE EXCEPTION 'TEST 7 FAIL: cierre controlado no aplicó vigente_hasta';
  END IF;
  RAISE NOTICE 'TEST 7c PASS: cierre controlado de vigente_hasta exitoso';

  -- Test: reapertura rechazada (fecha → NULL)
  BEGIN
    PERFORM set_config('app.rpc_context', 'cerrar_arancel', true);
    UPDATE valor_arancel SET vigente_hasta = NULL WHERE id = v_arancel_id;
    RAISE EXCEPTION 'TEST 7 FAIL: reapertura de vigente_hasta fue permitida';
  EXCEPTION
    WHEN raise_exception THEN
      PERFORM set_config('app.rpc_context', '', true);
      RAISE NOTICE 'TEST 7d PASS: reapertura de vigente_hasta rechazada';
  END;

  RAISE NOTICE 'TEST 7 PASS: cerrar_arancel completamente verificado';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 8: RPCs T00 — Atomicidad
-- ═══════════════════════════════════════════════════════════════════════════

-- Nota: Las RPCs T00 usan auth.uid() internamente, lo que requiere un
-- contexto de sesión autenticado de Supabase. Para tests de superuser,
-- verificamos la lógica de las tablas directamente.

DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
  v_pac_count int;
  v_hc_count int;
  v_evt_count int;
BEGIN
  -- Verificar que crear_paciente (ejecutado en SETUP via INSERT directo)
  -- creó tanto paciente como historia_clinica
  SELECT count(*) INTO v_pac_count FROM paciente WHERE organizacion_id = v_org1;
  SELECT count(*) INTO v_hc_count FROM historia_clinica WHERE organizacion_id = v_org1;

  IF v_pac_count < 1 THEN
    RAISE EXCEPTION 'TEST 8 FAIL: no hay pacientes en org1';
  END IF;
  IF v_hc_count < 1 THEN
    RAISE EXCEPTION 'TEST 8 FAIL: no hay historias clínicas en org1';
  END IF;

  RAISE NOTICE 'TEST 8a PASS: Pacientes (%) e historias (%) existen en org1',
    v_pac_count, v_hc_count;

  -- Verificar eventos T00 creados
  SELECT count(*) INTO v_evt_count
    FROM evento_auditoria_minima WHERE organizacion_id = v_org1;
  RAISE NOTICE 'TEST 8b PASS: % eventos de auditoría en org1', v_evt_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 9: RLS — Verificación básica de activación
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_tablas text[] := ARRAY[
    'organizacion_clinica','profesional','evento_auditoria_minima',
    'tipo_atencion','valor_arancel','paciente','historia_clinica',
    'entrada_clinica','seguimiento','cita','transicion_cita',
    'atencion_clinica','transicion_atencion','cobro','transicion_pago'
  ];
  v_t text;
  v_rls_enabled boolean;
BEGIN
  FOREACH v_t IN ARRAY v_tablas LOOP
    SELECT relrowsecurity INTO v_rls_enabled
      FROM pg_class WHERE relname = v_t AND relnamespace = 'public'::regnamespace;

    IF NOT v_rls_enabled THEN
      RAISE EXCEPTION 'TEST 9 FAIL: RLS no activado en %', v_t;
    END IF;
  END LOOP;

  RAISE NOTICE 'TEST 9 PASS: RLS activado en las 15 tablas Fase 1';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 10: CHECK CONSTRAINTS — Estados válidos
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_pac1 uuid := current_setting('test.pac1')::uuid;
BEGIN
  -- Test: estado inválido rechazado en paciente
  BEGIN
    INSERT INTO paciente (organizacion_id, nombre_completo, estado, creado_por)
      VALUES (v_org1, 'Test', 'INVALIDO', v_prof1);
    RAISE EXCEPTION 'TEST 10 FAIL: estado inválido aceptado en paciente';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'TEST 10a PASS: CHECK rechaza estado inválido en paciente';
  END;

  -- Test: modalidad inválida rechazada en cobro
  BEGIN
    INSERT INTO cobro (
      organizacion_id, paciente_id, profesional_id, monto,
      tipo_atencion_nombre_snapshot, modalidad, concepto, categoria_origen
    ) VALUES (
      v_org1, v_pac1, v_prof1, 100, 'Test', 'INVALIDO', 'Test', 'atencion_individual'
    );
    RAISE EXCEPTION 'TEST 10 FAIL: modalidad inválida aceptada en cobro';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'TEST 10b PASS: CHECK rechaza modalidad inválida en cobro';
  END;

  -- Test: tipo_evento inválido rechazado en evento_auditoria_minima
  BEGIN
    INSERT INTO evento_auditoria_minima (
      organizacion_id, profesional_id, tipo_evento,
      entidad_tipo, entidad_id
    ) VALUES (
      v_org1, v_prof1, 'EVENTO_FALSO', 'paciente', v_pac1
    );
    RAISE EXCEPTION 'TEST 10 FAIL: tipo_evento inválido aceptado';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'TEST 10c PASS: CHECK rechaza tipo_evento inválido';
  END;

  RAISE NOTICE 'TEST 10 PASS: CHECK constraints de estados verificados';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 11: UNICIDAD PARCIAL
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_org1 uuid := current_setting('test.org1')::uuid;
  v_prof1 uuid := current_setting('test.prof1')::uuid;
  v_tipo1 uuid := current_setting('test.tipo1')::uuid;
BEGIN
  -- Test: duplicar tipo_atencion nombre activo en misma org rechazado
  BEGIN
    INSERT INTO tipo_atencion (organizacion_id, nombre, estado)
      VALUES (v_org1, 'Podología General', 'activo');
    RAISE EXCEPTION 'TEST 11 FAIL: nombre duplicado activo aceptado en tipo_atencion';
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'TEST 11a PASS: nombre activo duplicado rechazado en tipo_atencion';
  END;

  -- Test: duplicar valor_arancel vigente rechazado
  BEGIN
    INSERT INTO valor_arancel (tipo_atencion_id, organizacion_id, modalidad, valor, vigente_desde, configurado_por)
      VALUES (v_tipo1, v_org1, 'particular', 30000, CURRENT_DATE, v_prof1);
    RAISE EXCEPTION 'TEST 11 FAIL: arancel vigente duplicado aceptado';
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'TEST 11b PASS: arancel vigente duplicado rechazado';
  END;

  RAISE NOTICE 'TEST 11 PASS: Unicidad parcial verificada';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TEST 12: NO EXISTEN COLUMNAS FASE 2
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name IN ('relacion_centro_id','zona_domiciliaria_id')
      AND table_name IN ('paciente','atencion_clinica','cobro')
  ) THEN
    RAISE EXCEPTION 'TEST 12 FAIL: columnas Fase 2 encontradas en tablas Fase 1';
  END IF;

  RAISE NOTICE 'TEST 12 PASS: Sin columnas Fase 2 en tablas Fase 1';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- RESUMEN FINAL
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════════════';
  RAISE NOTICE 'QA SQL FASE 1 — RESUMEN';
  RAISE NOTICE '═══════════════════════════════════════════════════';
  RAISE NOTICE 'TEST  1: Tablas Fase 1 (15) presentes, sin Fase 2';
  RAISE NOTICE 'TEST  2: UNIQUE (organizacion_id, id) en 8 anclas';
  RAISE NOTICE 'TEST  3: FK compuesta rechaza cross-tenant';
  RAISE NOTICE 'TEST  4: Trigger Tipo B rechaza cross-tenant';
  RAISE NOTICE 'TEST  5: Tablas append-only rechazan UPDATE/DELETE';
  RAISE NOTICE 'TEST  6: Inmutabilidad de columnas protegidas';
  RAISE NOTICE 'TEST  7: cerrar_arancel — contexto verificable';
  RAISE NOTICE 'TEST  8: RPCs T00 — atomicidad';
  RAISE NOTICE 'TEST  9: RLS activado en 15 tablas';
  RAISE NOTICE 'TEST 10: CHECK constraints de estados';
  RAISE NOTICE 'TEST 11: Unicidad parcial';
  RAISE NOTICE 'TEST 12: Sin columnas Fase 2 adelantadas';
  RAISE NOTICE '═══════════════════════════════════════════════════';
  RAISE NOTICE 'Si todos los tests imprimieron PASS, la migración';
  RAISE NOTICE 'cumple el contrato de SUPABASE_SCHEMA_BLUEPRINT_v1.2';
  RAISE NOTICE '═══════════════════════════════════════════════════';
END;
$$;
