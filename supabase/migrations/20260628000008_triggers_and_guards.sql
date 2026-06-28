-- ============================================================================
-- Migration 08: Triggers and Guards
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 08 (via v1.1)
-- ============================================================================

-- ============================================================================
-- 8.1 Triggers updated_at
-- ============================================================================

CREATE TRIGGER trg_organizacion_clinica_updated_at
  BEFORE UPDATE ON public.organizacion_clinica
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_profesional_updated_at
  BEFORE UPDATE ON public.profesional
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_tipo_atencion_updated_at
  BEFORE UPDATE ON public.tipo_atencion
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_paciente_updated_at
  BEFORE UPDATE ON public.paciente
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_entrada_clinica_updated_at
  BEFORE UPDATE ON public.entrada_clinica
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_seguimiento_updated_at
  BEFORE UPDATE ON public.seguimiento
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_cita_updated_at
  BEFORE UPDATE ON public.cita
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_atencion_clinica_updated_at
  BEFORE UPDATE ON public.atencion_clinica
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 8.2 Triggers append-only
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reject_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Tabla % es append-only: no se permite % de registros',
    TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE TRIGGER trg_evento_auditoria_append_only
  BEFORE UPDATE OR DELETE ON public.evento_auditoria_minima
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

CREATE TRIGGER trg_transicion_atencion_append_only
  BEFORE UPDATE OR DELETE ON public.transicion_atencion
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

CREATE TRIGGER trg_transicion_cita_append_only
  BEFORE UPDATE OR DELETE ON public.transicion_cita
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

CREATE TRIGGER trg_transicion_pago_append_only
  BEFORE UPDATE OR DELETE ON public.transicion_pago
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

-- ============================================================================
-- 8.3 Triggers de inmutabilidad — entrada_clinica
-- ============================================================================

CREATE OR REPLACE FUNCTION public.guard_entrada_clinica_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.descripcion IS DISTINCT FROM NEW.descripcion
     OR OLD.tipo IS DISTINCT FROM NEW.tipo
     OR OLD.historia_clinica_id IS DISTINCT FROM NEW.historia_clinica_id
     OR OLD.registrado_por IS DISTINCT FROM NEW.registrado_por
     OR OLD.registrado_en IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'entrada_clinica: columnas protegidas no pueden modificarse';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_entrada_clinica_immutable
  BEFORE UPDATE ON public.entrada_clinica
  FOR EACH ROW EXECUTE FUNCTION public.guard_entrada_clinica_immutable();

-- ============================================================================
-- 8.4 Triggers de inmutabilidad — atencion_clinica (conditional)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.guard_atencion_clinica_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.estado = 'cerrada' THEN
    IF OLD.tratamiento IS DISTINCT FROM NEW.tratamiento
       OR OLD.hallazgos IS DISTINCT FROM NEW.hallazgos
       OR OLD.notas_clinicas IS DISTINCT FROM NEW.notas_clinicas
       OR OLD.indicaciones IS DISTINCT FROM NEW.indicaciones
       OR OLD.fecha_cierre IS DISTINCT FROM NEW.fecha_cierre
       OR OLD.paciente_id IS DISTINCT FROM NEW.paciente_id
       OR OLD.profesional_id IS DISTINCT FROM NEW.profesional_id
       OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
    THEN
      RAISE EXCEPTION 'atencion_clinica cerrada: columnas clinicas no pueden modificarse';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atencion_clinica_immutable
  BEFORE UPDATE ON public.atencion_clinica
  FOR EACH ROW EXECUTE FUNCTION public.guard_atencion_clinica_immutable();

-- ============================================================================
-- 8.5 Triggers de inmutabilidad — cobro (snapshot)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.guard_cobro_snapshot_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.monto IS DISTINCT FROM NEW.monto
     OR OLD.tipo_atencion_nombre_snapshot IS DISTINCT FROM NEW.tipo_atencion_nombre_snapshot
     OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
     OR OLD.recargo_zona_snapshot IS DISTINCT FROM NEW.recargo_zona_snapshot
     OR OLD.valor_acordado_centro_snapshot IS DISTINCT FROM NEW.valor_acordado_centro_snapshot
     OR OLD.concepto IS DISTINCT FROM NEW.concepto
     OR OLD.categoria_origen IS DISTINCT FROM NEW.categoria_origen
     OR OLD.registrado_en IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'cobro: columnas snapshot son inmutables';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cobro_snapshot_immutable
  BEFORE UPDATE ON public.cobro
  FOR EACH ROW EXECUTE FUNCTION public.guard_cobro_snapshot_immutable();

-- ============================================================================
-- 8.6 Triggers de inmutabilidad — valor_arancel (total + controlled exception)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.guard_valor_arancel_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.tipo_atencion_id IS DISTINCT FROM NEW.tipo_atencion_id
     OR OLD.organizacion_id IS DISTINCT FROM NEW.organizacion_id
     OR OLD.modalidad IS DISTINCT FROM NEW.modalidad
     OR OLD.valor IS DISTINCT FROM NEW.valor
     OR OLD.vigente_desde IS DISTINCT FROM NEW.vigente_desde
     OR OLD.configurado_por IS DISTINCT FROM NEW.configurado_por
     OR OLD.creado_en IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'valor_arancel: columnas protegidas son inmutables';
  END IF;

  IF OLD.vigente_hasta IS DISTINCT FROM NEW.vigente_hasta THEN
    IF OLD.vigente_hasta IS NOT NULL THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta ya establecida, no puede modificarse';
    END IF;
    IF NEW.vigente_hasta IS NULL THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta solo puede cambiar de NULL a fecha valida';
    END IF;
    IF current_setting('app.rpc_cerrar_arancel', true) IS DISTINCT FROM 'true' THEN
      RAISE EXCEPTION 'valor_arancel: vigente_hasta solo puede modificarse via RPC cerrar_arancel';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_valor_arancel_immutable
  BEFORE UPDATE ON public.valor_arancel
  FOR EACH ROW EXECUTE FUNCTION public.guard_valor_arancel_immutable();

-- ============================================================================
-- 8.7 Triggers de proteccion de columnas (v1.1+)
-- ============================================================================

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

CREATE TRIGGER trg_profesional_immutable
  BEFORE UPDATE ON public.profesional
  FOR EACH ROW EXECUTE FUNCTION public.guard_profesional_immutable();

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

CREATE TRIGGER trg_historia_clinica_immutable
  BEFORE UPDATE ON public.historia_clinica
  FOR EACH ROW EXECUTE FUNCTION public.guard_historia_clinica_immutable();

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

CREATE TRIGGER trg_paciente_immutable
  BEFORE UPDATE ON public.paciente
  FOR EACH ROW EXECUTE FUNCTION public.guard_paciente_immutable();

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

CREATE TRIGGER trg_seguimiento_immutable
  BEFORE UPDATE ON public.seguimiento
  FOR EACH ROW EXECUTE FUNCTION public.guard_seguimiento_immutable();

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

CREATE TRIGGER trg_cita_immutable
  BEFORE UPDATE ON public.cita
  FOR EACH ROW EXECUTE FUNCTION public.guard_cita_immutable();

-- ============================================================================
-- 8.8 Triggers Tipo B diferidos (cross-context validation)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_cross_tenant_ref()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  ref_org_id UUID;
  col_name TEXT := TG_ARGV[0];
  ref_table TEXT := TG_ARGV[1];
  ref_value UUID;
BEGIN
  EXECUTE format('SELECT ($1).%I', col_name) INTO ref_value USING NEW;

  IF ref_value IS NULL THEN
    RETURN NEW;
  END IF;

  EXECUTE format(
    'SELECT organizacion_id FROM public.%I WHERE id = $1',
    ref_table
  ) INTO ref_org_id USING ref_value;

  IF ref_org_id IS NULL THEN
    RAISE EXCEPTION 'Referencia invalida: %.% = % no existe en %',
      TG_TABLE_NAME, col_name, ref_value, ref_table;
  END IF;

  IF ref_org_id != NEW.organizacion_id THEN
    RAISE EXCEPTION 'Violacion tenant: %.% referencia registro de otra organizacion',
      TG_TABLE_NAME, col_name;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_seguimiento_validate_atencion
  BEFORE INSERT OR UPDATE ON public.seguimiento
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');

CREATE TRIGGER trg_cita_validate_atencion
  BEFORE INSERT OR UPDATE ON public.cita
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');

CREATE TRIGGER trg_cobro_validate_atencion
  BEFORE INSERT OR UPDATE ON public.cobro
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_cross_tenant_ref('atencion_clinica_id', 'atencion_clinica');
