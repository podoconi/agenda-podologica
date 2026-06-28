-- ============================================================================
-- Rollback Phase 1: Object-by-object, Phase 1 only
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Rollback
--
-- WARNING: This drops ALL Phase 1 objects. Only use on staging or when
-- Phase 1 has no production data.
-- ============================================================================

-- ============================================================================
-- Step 1: Revoke grants on Phase 1 functions
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.archivar_paciente(UUID) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) FROM anon, authenticated, PUBLIC;

-- ============================================================================
-- Step 2: Revoke grants on Phase 1 tables
-- ============================================================================

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

-- ============================================================================
-- Step 3: Drop RLS policies
-- ============================================================================

DROP POLICY IF EXISTS select_own_org ON public.organizacion_clinica;
DROP POLICY IF EXISTS update_own_org ON public.organizacion_clinica;
DROP POLICY IF EXISTS select_profesional ON public.profesional;
DROP POLICY IF EXISTS update_own_profesional ON public.profesional;
DROP POLICY IF EXISTS select_auditoria ON public.evento_auditoria_minima;
DROP POLICY IF EXISTS select_tipo_atencion ON public.tipo_atencion;
DROP POLICY IF EXISTS insert_tipo_atencion ON public.tipo_atencion;
DROP POLICY IF EXISTS update_tipo_atencion ON public.tipo_atencion;
DROP POLICY IF EXISTS select_valor_arancel ON public.valor_arancel;
DROP POLICY IF EXISTS insert_valor_arancel ON public.valor_arancel;
DROP POLICY IF EXISTS select_paciente ON public.paciente;
DROP POLICY IF EXISTS insert_paciente ON public.paciente;
DROP POLICY IF EXISTS update_paciente ON public.paciente;
DROP POLICY IF EXISTS select_historia ON public.historia_clinica;
DROP POLICY IF EXISTS update_historia ON public.historia_clinica;
DROP POLICY IF EXISTS select_entrada ON public.entrada_clinica;
DROP POLICY IF EXISTS insert_entrada ON public.entrada_clinica;
DROP POLICY IF EXISTS update_entrada ON public.entrada_clinica;
DROP POLICY IF EXISTS select_seguimiento ON public.seguimiento;
DROP POLICY IF EXISTS insert_seguimiento ON public.seguimiento;
DROP POLICY IF EXISTS update_seguimiento ON public.seguimiento;
DROP POLICY IF EXISTS select_cita ON public.cita;
DROP POLICY IF EXISTS insert_cita ON public.cita;
DROP POLICY IF EXISTS update_cita ON public.cita;
DROP POLICY IF EXISTS select_transicion_cita ON public.transicion_cita;
DROP POLICY IF EXISTS select_atencion ON public.atencion_clinica;
DROP POLICY IF EXISTS insert_atencion ON public.atencion_clinica;
DROP POLICY IF EXISTS update_atencion ON public.atencion_clinica;
DROP POLICY IF EXISTS select_transicion_atencion ON public.transicion_atencion;
DROP POLICY IF EXISTS select_cobro ON public.cobro;
DROP POLICY IF EXISTS insert_cobro ON public.cobro;
DROP POLICY IF EXISTS select_transicion_pago ON public.transicion_pago;

-- ============================================================================
-- Step 4: Disable RLS
-- ============================================================================

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

-- ============================================================================
-- Step 5: Drop triggers
-- ============================================================================

-- Append-only
DROP TRIGGER IF EXISTS trg_evento_auditoria_append_only ON public.evento_auditoria_minima;
DROP TRIGGER IF EXISTS trg_transicion_atencion_append_only ON public.transicion_atencion;
DROP TRIGGER IF EXISTS trg_transicion_cita_append_only ON public.transicion_cita;
DROP TRIGGER IF EXISTS trg_transicion_pago_append_only ON public.transicion_pago;

-- Immutability
DROP TRIGGER IF EXISTS trg_entrada_clinica_immutable ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_atencion_clinica_immutable ON public.atencion_clinica;
DROP TRIGGER IF EXISTS trg_cobro_snapshot_immutable ON public.cobro;
DROP TRIGGER IF EXISTS trg_valor_arancel_immutable ON public.valor_arancel;

-- Column protection
DROP TRIGGER IF EXISTS trg_profesional_immutable ON public.profesional;
DROP TRIGGER IF EXISTS trg_historia_clinica_immutable ON public.historia_clinica;
DROP TRIGGER IF EXISTS trg_paciente_immutable ON public.paciente;
DROP TRIGGER IF EXISTS trg_seguimiento_immutable ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_immutable ON public.cita;

-- Tipo B
DROP TRIGGER IF EXISTS trg_seguimiento_validate_atencion ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_validate_atencion ON public.cita;
DROP TRIGGER IF EXISTS trg_cobro_validate_atencion ON public.cobro;

-- Updated_at
DROP TRIGGER IF EXISTS trg_organizacion_clinica_updated_at ON public.organizacion_clinica;
DROP TRIGGER IF EXISTS trg_profesional_updated_at ON public.profesional;
DROP TRIGGER IF EXISTS trg_tipo_atencion_updated_at ON public.tipo_atencion;
DROP TRIGGER IF EXISTS trg_paciente_updated_at ON public.paciente;
DROP TRIGGER IF EXISTS trg_entrada_clinica_updated_at ON public.entrada_clinica;
DROP TRIGGER IF EXISTS trg_seguimiento_updated_at ON public.seguimiento;
DROP TRIGGER IF EXISTS trg_cita_updated_at ON public.cita;
DROP TRIGGER IF EXISTS trg_atencion_clinica_updated_at ON public.atencion_clinica;

-- ============================================================================
-- Step 6: Drop trigger on auth.users
-- ============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- ============================================================================
-- Step 7: Drop Phase 1 functions
-- ============================================================================

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

-- Support functions
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

-- ============================================================================
-- Step 8: Drop tables (reverse dependency order)
-- ============================================================================

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

-- ============================================================================
-- Step 9: Post-rollback verification
-- ============================================================================

DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count FROM pg_tables
  WHERE schemaname = 'public' AND tablename IN (
    'organizacion_clinica', 'invitacion_profesional', 'profesional',
    'evento_auditoria_minima', 'tipo_atencion', 'valor_arancel',
    'paciente', 'historia_clinica', 'entrada_clinica',
    'seguimiento', 'cita', 'transicion_cita',
    'atencion_clinica', 'transicion_atencion', 'cobro', 'transicion_pago'
  );
  ASSERT v_count = 0, format('Post-rollback: expected 0 Phase 1 tables, found %s', v_count);

  SELECT count(*) INTO v_count FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND proname IN (
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
  ASSERT v_count = 0, format('Post-rollback: expected 0 Phase 1 functions, found %s', v_count);

  RAISE NOTICE 'Post-rollback verification PASSED';
END;
$$;
