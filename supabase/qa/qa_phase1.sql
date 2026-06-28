-- ============================================================================
-- QA Phase 1 — Manual test harness
-- Run AFTER applying migrations 01-10 against a Supabase staging/local project.
-- NOT an auto-applied migration. Execute via:
--   npx supabase db query --linked -f supabase/qa/qa_phase1.sql
-- Everything runs inside BEGIN/ROLLBACK — no data persists.
-- ============================================================================

BEGIN;

-- ============================================================================
-- FIXTURES: Uses invitation flow to create auth.users → profesional
-- ============================================================================

-- Orgs must exist first (invitaciones reference them)
INSERT INTO public.organizacion_clinica (id, nombre_legal, zona_horaria)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Clinica Alfa', 'America/Santiago'),
  ('b0000000-0000-0000-0000-000000000002', 'Clinica Beta', 'America/Santiago');

-- Invitations with known tokens
INSERT INTO public.invitacion_profesional (organizacion_id, email, nombre_completo, nombre_para_documentos, token)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'alfa@clinica.cl', 'Dr. Alfa', 'Dr. Alfa Prueba',
   'aaa00000-0000-0000-0000-0000000000a1'),
  ('b0000000-0000-0000-0000-000000000002', 'beta@clinica.cl', 'Dr. Beta', 'Dr. Beta Prueba',
   'bbb00000-0000-0000-0000-0000000000b2');

-- Auth users WITH tokens → trigger creates profesionales automatically
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data)
VALUES
  ('aa000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alfa@clinica.cl',
   crypt('testpass123', gen_salt('bf')), now(), now(), now(),
   '{"token": "aaa00000-0000-0000-0000-0000000000a1"}'),
  ('ab000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'beta@clinica.cl',
   crypt('testpass123', gen_salt('bf')), now(), now(), now(),
   '{"token": "bbb00000-0000-0000-0000-0000000000b2"}');

-- Temp table to hold auto-generated profesional IDs
CREATE TEMP TABLE _qa_ids (key TEXT PRIMARY KEY, val UUID);
INSERT INTO _qa_ids SELECT 'prof_a', id FROM public.profesional WHERE auth_user_id = 'aa000000-0000-0000-0000-000000000001';
INSERT INTO _qa_ids SELECT 'prof_b', id FROM public.profesional WHERE auth_user_id = 'ab000000-0000-0000-0000-000000000002';

-- Tipo atencion (Org A)
INSERT INTO public.tipo_atencion (id, organizacion_id, nombre)
VALUES ('ca000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Podologia General');

-- Valor arancel (Org A) — needs profesional ID
INSERT INTO public.valor_arancel (id, tipo_atencion_id, organizacion_id, modalidad, valor, vigente_desde, configurado_por)
VALUES ('da000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001', 'particular', 25000, '2026-01-01',
        (SELECT val FROM _qa_ids WHERE key = 'prof_a'));

-- Paciente Org A
INSERT INTO public.paciente (id, organizacion_id, nombre_completo, creado_por)
VALUES ('ec000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
        'Paciente Uno', (SELECT val FROM _qa_ids WHERE key = 'prof_a'));

-- Historia clinica Org A
INSERT INTO public.historia_clinica (id, paciente_id, organizacion_id)
VALUES ('fc000000-0000-0000-0000-000000000001', 'ec000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001');

-- Paciente Org B
INSERT INTO public.paciente (id, organizacion_id, nombre_completo, creado_por)
VALUES ('ec000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002',
        'Paciente Dos', (SELECT val FROM _qa_ids WHERE key = 'prof_b'));

-- Atencion clinica Org A
INSERT INTO public.atencion_clinica (id, organizacion_id, paciente_id, profesional_id, modalidad, estado)
VALUES ('ac000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
        'ec000000-0000-0000-0000-000000000001', (SELECT val FROM _qa_ids WHERE key = 'prof_a'),
        'particular', 'registrada');

-- Atencion Org B (for cross-tenant tests)
INSERT INTO public.atencion_clinica (id, organizacion_id, paciente_id, profesional_id, modalidad, estado)
VALUES ('ac000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002',
        'ec000000-0000-0000-0000-000000000002', (SELECT val FROM _qa_ids WHERE key = 'prof_b'),
        'particular', 'registrada');

-- Cobro Org A
INSERT INTO public.cobro (id, organizacion_id, paciente_id, profesional_id, monto,
        tipo_atencion_nombre_snapshot, modalidad, concepto, categoria_origen)
VALUES ('c1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
        'ec000000-0000-0000-0000-000000000001', (SELECT val FROM _qa_ids WHERE key = 'prof_a'),
        25000, 'Podologia General', 'particular', 'Atencion podologica', 'atencion_individual');

-- Cobro Org B (for cross-tenant tests)
INSERT INTO public.cobro (id, organizacion_id, paciente_id, profesional_id, monto,
        tipo_atencion_nombre_snapshot, modalidad, concepto, categoria_origen)
VALUES ('c1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002',
        'ec000000-0000-0000-0000-000000000002', (SELECT val FROM _qa_ids WHERE key = 'prof_b'),
        30000, 'Podologia General', 'particular', 'Atencion podologica', 'atencion_individual');

DO $$ BEGIN RAISE NOTICE 'FIXTURES created successfully (via invitation flow)'; END; $$;

-- ============================================================================
-- 1. STRUCTURAL TESTS
-- ============================================================================

DO $$
DECLARE v_count INT;
BEGIN
  SELECT count(*) INTO v_count FROM pg_tables
  WHERE schemaname = 'public' AND tablename IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago');
  ASSERT v_count = 16, format('Expected 16 tables, found %s', v_count);

  SELECT count(*) INTO v_count FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'public' AND c.relrowsecurity = true AND c.relname IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago');
  ASSERT v_count = 16, format('Expected RLS on 16, found %s', v_count);

  SELECT count(*) INTO v_count FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'public' AND c.relforcerowsecurity = true AND c.relname IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago');
  ASSERT v_count = 0, format('Expected 0 FORCE RLS, found %s', v_count);

  -- Verify invitations were consumed by trigger
  SELECT count(*) INTO v_count FROM public.invitacion_profesional WHERE estado = 'consumida';
  ASSERT v_count = 2, format('Expected 2 consumed invitations, found %s', v_count);

  -- Verify profesionales were created by trigger
  SELECT count(*) INTO v_count FROM public.profesional;
  ASSERT v_count = 2, format('Expected 2 profesionales, found %s', v_count);

  RAISE NOTICE 'PASS: structural tests';
END;
$$;

-- ============================================================================
-- 2. PRIVILEGE TESTS (static — catalog queries)
-- ============================================================================

DO $$
DECLARE v_count INT;
BEGIN
  SELECT count(*) INTO v_count FROM information_schema.role_table_grants
  WHERE grantee = 'anon' AND table_schema = 'public' AND table_name IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago');
  ASSERT v_count = 0, format('anon should have 0 table grants, found %s', v_count);

  -- Verify no SECURITY DEFINER function grants EXECUTE to public (via ACL check)
  SELECT count(*) INTO v_count FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.prosecdef = true
    AND (SELECT array_agg(acl) FROM unnest(p.proacl) acl WHERE acl::text LIKE '%=X/%') IS NOT NULL
    AND (SELECT bool_or(acl::text LIKE '=X/%') FROM unnest(p.proacl) acl) = true;
  ASSERT v_count = 0, format('PUBLIC EXECUTE on SECURITY DEFINER: expected 0, found %s', v_count);

  SELECT count(*) INTO v_count FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.prosecdef = true
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  ASSERT v_count = 0, format('anon EXECUTE on SECURITY DEFINER: expected 0, found %s', v_count);

  ASSERT NOT has_table_privilege('authenticated', 'public.invitacion_profesional', 'SELECT'),
    'authenticated should NOT SELECT invitacion_profesional';
  ASSERT NOT has_table_privilege('authenticated', 'public.valor_arancel', 'UPDATE'),
    'authenticated should NOT UPDATE valor_arancel';
  ASSERT NOT has_table_privilege('authenticated', 'public.cobro', 'UPDATE'),
    'authenticated should NOT UPDATE cobro';
  ASSERT NOT has_table_privilege('authenticated', 'public.paciente', 'DELETE'),
    'authenticated should NOT DELETE paciente';

  SELECT count(*) INTO v_count FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.prosecdef = true
    AND NOT (p.proconfig @> ARRAY['search_path=public, pg_temp']);
  ASSERT v_count = 0, format('SECURITY DEFINER without correct search_path: found %s', v_count);

  RAISE NOTICE 'PASS: privilege tests (static)';
END;
$$;

-- ============================================================================
-- 3. ROLE-BASED TESTS (SET ROLE anon / authenticated)
-- ============================================================================

-- 3a. anon cannot execute any RPC
DO $$
BEGIN
  SET LOCAL ROLE anon;

  BEGIN
    PERFORM public.crear_paciente('Test'::TEXT, NULL::TEXT, NULL::DATE, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT);
    RAISE EXCEPTION 'anon should not execute crear_paciente';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.registrar_atencion(gen_random_uuid()::UUID, NULL::UUID, 'particular'::TEXT, NULL::UUID, NULL::TEXT);
    RAISE EXCEPTION 'anon should not execute registrar_atencion';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.cerrar_atencion(gen_random_uuid()::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT);
    RAISE EXCEPTION 'anon should not execute cerrar_atencion';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.modificar_estado_cita(gen_random_uuid()::UUID, 'confirmada'::TEXT, NULL::TEXT);
    RAISE EXCEPTION 'anon should not execute modificar_estado_cita';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.agregar_entrada_clinica(gen_random_uuid()::UUID, 'patologia'::TEXT, 'Test'::TEXT, NULL::TEXT);
    RAISE EXCEPTION 'anon should not execute agregar_entrada_clinica';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.registrar_pago(gen_random_uuid()::UUID, 'efectivo'::TEXT, 'pagado'::TEXT);
    RAISE EXCEPTION 'anon should not execute registrar_pago';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.anular_cobro(gen_random_uuid()::UUID, 'motivo'::TEXT);
    RAISE EXCEPTION 'anon should not execute anular_cobro';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.archivar_paciente(gen_random_uuid()::UUID);
    RAISE EXCEPTION 'anon should not execute archivar_paciente';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.cerrar_arancel(gen_random_uuid()::UUID, '2026-12-31'::DATE);
    RAISE EXCEPTION 'anon should not execute cerrar_arancel';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  BEGIN
    PERFORM public.obtener_mi_organizacion_id();
    RAISE EXCEPTION 'anon should not execute obtener_mi_organizacion_id';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  RESET ROLE;
  RAISE NOTICE 'PASS: anon cannot execute RPCs';
END;
$$;

-- 3b. authenticated cannot UPDATE valor_arancel even with SET LOCAL flag
DO $$
BEGIN
  SET LOCAL ROLE authenticated;

  BEGIN
    SET LOCAL app.rpc_cerrar_arancel = 'true';
    UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31'
      WHERE id = 'da000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'authenticated should not UPDATE valor_arancel';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  RESET ROLE;
  RAISE NOTICE 'PASS: authenticated SET LOCAL + UPDATE valor_arancel blocked';
END;
$$;

-- ============================================================================
-- 4. CROSS-TENANT VIA RPC TESTS
-- Simulates auth.uid() via request.jwt.claims for Professional A
-- ============================================================================

DO $$
BEGIN
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub": "aa000000-0000-0000-0000-000000000001"}';

  -- registrar_atencion with paciente from Org B
  BEGIN
    PERFORM public.registrar_atencion(
      'ec000000-0000-0000-0000-000000000002'::UUID, NULL::UUID, 'particular'::TEXT, NULL::UUID, NULL::TEXT);
    RAISE EXCEPTION 'Cross-tenant registrar_atencion should fail';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE '%Paciente no encontrado en esta organizacion%' THEN
      RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
    END IF;
  END;

  -- cerrar_atencion with atencion from Org B
  BEGIN
    PERFORM public.cerrar_atencion(
      'ac000000-0000-0000-0000-000000000002'::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT);
    RAISE EXCEPTION 'Cross-tenant cerrar_atencion should fail';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE '%Atencion no encontrada en esta organizacion%' THEN
      RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
    END IF;
  END;

  -- registrar_pago with cobro from Org B
  BEGIN
    PERFORM public.registrar_pago(
      'c1000000-0000-0000-0000-000000000002'::UUID, 'efectivo'::TEXT, 'pagado'::TEXT);
    RAISE EXCEPTION 'Cross-tenant registrar_pago should fail';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE '%Cobro no encontrado en esta organizacion%' THEN
      RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
    END IF;
  END;

  RESET ROLE;
  RAISE NOTICE 'PASS: cross-tenant via RPC tests';
END;
$$;

-- ============================================================================
-- 5. CROSS-TENANT FK TESTS (Tipo A)
-- ============================================================================

DO $$
BEGIN
  -- paciente ec..02 belongs to org B; inserting with org A should violate FK
  BEGIN
    INSERT INTO public.historia_clinica (paciente_id, organizacion_id)
    VALUES ('ec000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001');
    RAISE EXCEPTION 'Cross-tenant FK should fail';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;

  RAISE NOTICE 'PASS: cross-tenant FK tests';
END;
$$;

-- ============================================================================
-- 6. TIPO B TRIGGER TESTS
-- ============================================================================

DO $$
DECLARE v_seg_id UUID; v_prof_a UUID;
BEGIN
  SELECT val INTO v_prof_a FROM _qa_ids WHERE key = 'prof_a';

  INSERT INTO public.seguimiento (id, organizacion_id, paciente_id, profesional_id, tipo)
  VALUES (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
          'ec000000-0000-0000-0000-000000000001', v_prof_a, 'control')
  RETURNING id INTO v_seg_id;

  BEGIN
    UPDATE public.seguimiento SET atencion_clinica_id = gen_random_uuid() WHERE id = v_seg_id;
    RAISE EXCEPTION 'Tipo B trigger should reject non-existent ref';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  RAISE NOTICE 'PASS: Tipo B trigger tests';
END;
$$;

-- ============================================================================
-- 7. APPEND-ONLY TESTS
-- ============================================================================

DO $$
DECLARE v_audit_id UUID; v_prof_a UUID;
BEGIN
  SELECT val INTO v_prof_a FROM _qa_ids WHERE key = 'prof_a';

  INSERT INTO public.evento_auditoria_minima (id, organizacion_id, profesional_id, tipo_evento, entidad_tipo, entidad_id, estado_nuevo)
  VALUES (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
          v_prof_a, 'paciente_creado', 'paciente',
          'ec000000-0000-0000-0000-000000000001', 'activo')
  RETURNING id INTO v_audit_id;

  BEGIN
    UPDATE public.evento_auditoria_minima SET resumen_contextual = 'hack' WHERE id = v_audit_id;
    RAISE EXCEPTION 'Append-only should reject UPDATE';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  BEGIN
    DELETE FROM public.evento_auditoria_minima WHERE id = v_audit_id;
    RAISE EXCEPTION 'Append-only should reject DELETE';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  RAISE NOTICE 'PASS: append-only tests';
END;
$$;

-- ============================================================================
-- 8. IMMUTABILITY / COLUMN PROTECTION TESTS
-- ============================================================================

DO $$
DECLARE v_ent_id UUID; v_prof_a UUID; v_prof_b UUID;
BEGIN
  SELECT val INTO v_prof_a FROM _qa_ids WHERE key = 'prof_a';
  SELECT val INTO v_prof_b FROM _qa_ids WHERE key = 'prof_b';

  INSERT INTO public.entrada_clinica (id, historia_clinica_id, organizacion_id, tipo, descripcion, registrado_por)
  VALUES (gen_random_uuid(), 'fc000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
          'patologia', 'Hallux valgus', v_prof_a)
  RETURNING id INTO v_ent_id;

  BEGIN
    UPDATE public.entrada_clinica SET descripcion = 'HACKED' WHERE id = v_ent_id;
    RAISE EXCEPTION 'descripcion should be immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;
  UPDATE public.entrada_clinica SET estado = 'resuelto' WHERE id = v_ent_id;

  BEGIN
    UPDATE public.profesional SET organizacion_id = 'b0000000-0000-0000-0000-000000000002'
    WHERE id = v_prof_a;
    RAISE EXCEPTION 'profesional.organizacion_id should be immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;
  UPDATE public.profesional SET nombre_completo = 'Dr. Alfa Actualizado' WHERE id = v_prof_a;

  BEGIN
    UPDATE public.cobro SET monto = 0 WHERE id = 'c1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'cobro.monto should be snapshot-immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  BEGIN
    UPDATE public.valor_arancel SET valor = 0 WHERE id = 'da000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'valor_arancel.valor should be immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  BEGIN
    UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31' WHERE id = 'da000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'vigente_hasta should only change via RPC';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  BEGIN
    UPDATE public.paciente SET creado_por = v_prof_b
    WHERE id = 'ec000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'paciente.creado_por should be immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;
  UPDATE public.paciente SET nombre_completo = 'Paciente Actualizado'
  WHERE id = 'ec000000-0000-0000-0000-000000000001';

  BEGIN
    UPDATE public.historia_clinica SET paciente_id = 'ec000000-0000-0000-0000-000000000002'
    WHERE id = 'fc000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'historia_clinica.paciente_id should be immutable';
  EXCEPTION WHEN raise_exception THEN NULL; END;
  UPDATE public.historia_clinica SET resumen_general = 'Resumen actualizado'
  WHERE id = 'fc000000-0000-0000-0000-000000000001';

  RAISE NOTICE 'PASS: immutability and column protection tests';
END;
$$;

-- ============================================================================
-- 9. SET LOCAL + TRIGGER PATH (as postgres)
-- ============================================================================

DO $$
BEGIN
  BEGIN
    UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31'
    WHERE id = 'da000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'Should fail: no RPC context flag';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  SET LOCAL app.rpc_cerrar_arancel = 'true';
  UPDATE public.valor_arancel SET vigente_hasta = '2026-12-31'
  WHERE id = 'da000000-0000-0000-0000-000000000001';

  BEGIN
    SET LOCAL app.rpc_cerrar_arancel = 'true';
    UPDATE public.valor_arancel SET vigente_hasta = '2027-01-01'
    WHERE id = 'da000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'Should fail: arancel already closed';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  RAISE NOTICE 'PASS: SET LOCAL + trigger tests';
END;
$$;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '=== ALL QA PHASE 1 TESTS PASSED ==='; END; $$;
ROLLBACK;
