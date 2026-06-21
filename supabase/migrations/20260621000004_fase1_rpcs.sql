-- =============================================================================
-- FASE 1 — RPCs (T00 + Controladas)
-- Blueprint: SUPABASE_SCHEMA_BLUEPRINT_v1.2.md · Secciones 5.3 y 12.3
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helper: obtener profesional y org del caller
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _obtener_caller()
RETURNS TABLE(prof_id uuid, org_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT id, organizacion_id FROM profesional WHERE auth_user_id = auth.uid()
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- T00 RPCs
-- ═══════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- T00-1: crear_paciente
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crear_paciente(
  p_nombre_completo text,
  p_rut text DEFAULT NULL,
  p_fecha_nacimiento date DEFAULT NULL,
  p_telefono_principal text DEFAULT NULL,
  p_telefono_alternativo text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_direccion text DEFAULT NULL,
  p_origen_categoria text DEFAULT NULL,
  p_notas text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_paciente_id uuid;
  v_hc_id uuid;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  v_paciente_id := gen_random_uuid();
  v_hc_id := gen_random_uuid();

  INSERT INTO paciente (
    id, organizacion_id, nombre_completo, rut, fecha_nacimiento,
    telefono_principal, telefono_alternativo, email, direccion,
    origen_categoria, estado, notas, creado_por, creado_en
  ) VALUES (
    v_paciente_id, v_org_id, p_nombre_completo, p_rut, p_fecha_nacimiento,
    p_telefono_principal, p_telefono_alternativo, p_email, p_direccion,
    p_origen_categoria, 'activo', p_notas, v_prof_id, now()
  );

  INSERT INTO historia_clinica (
    id, paciente_id, organizacion_id, creado_en
  ) VALUES (
    v_hc_id, v_paciente_id, v_org_id, now()
  );

  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_org_id, v_prof_id, 'paciente_creado',
    'paciente', v_paciente_id, 'activo', now()
  );

  RETURN v_paciente_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- T00-2: registrar_atencion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION registrar_atencion(
  p_paciente_id uuid,
  p_modalidad text,
  p_tipo_atencion_id uuid DEFAULT NULL,
  p_cita_id uuid DEFAULT NULL,
  p_tratamiento text DEFAULT NULL,
  p_hallazgos text DEFAULT NULL,
  p_notas_clinicas text DEFAULT NULL,
  p_indicaciones text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_atencion_id uuid;
  v_tipo_nombre text;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  -- Validar paciente pertenece a la org
  IF NOT EXISTS (
    SELECT 1 FROM paciente WHERE id = p_paciente_id AND organizacion_id = v_org_id
  ) THEN
    RAISE EXCEPTION 'Paciente no encontrado en su organización.';
  END IF;

  -- Snapshot tipo_atencion
  IF p_tipo_atencion_id IS NOT NULL THEN
    SELECT nombre INTO v_tipo_nombre
      FROM tipo_atencion
      WHERE id = p_tipo_atencion_id AND organizacion_id = v_org_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Tipo de atención no encontrado en su organización.';
    END IF;
  END IF;

  -- Validar cita si se provee
  IF p_cita_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM cita WHERE id = p_cita_id AND organizacion_id = v_org_id
    ) THEN
      RAISE EXCEPTION 'Cita no encontrada en su organización.';
    END IF;
  END IF;

  v_atencion_id := gen_random_uuid();

  INSERT INTO atencion_clinica (
    id, organizacion_id, paciente_id, profesional_id,
    tipo_atencion_id, tipo_atencion_nombre_snapshot,
    modalidad, estado, fecha_inicio,
    tratamiento, hallazgos, notas_clinicas, indicaciones,
    cita_id, creado_en
  ) VALUES (
    v_atencion_id, v_org_id, p_paciente_id, v_prof_id,
    p_tipo_atencion_id, v_tipo_nombre,
    p_modalidad, 'registrada', now(),
    p_tratamiento, p_hallazgos, p_notas_clinicas, p_indicaciones,
    p_cita_id, now()
  );

  INSERT INTO transicion_atencion (
    id, atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_atencion_id, v_org_id, v_prof_id,
    '', 'registrada', now()
  );

  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_org_id, v_prof_id, 'atencion_registrada',
    'atencion_clinica', v_atencion_id, 'registrada', now()
  );

  RETURN v_atencion_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- T00-3: cerrar_atencion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cerrar_atencion(
  p_atencion_id uuid,
  p_tratamiento text DEFAULT NULL,
  p_hallazgos text DEFAULT NULL,
  p_notas_clinicas text DEFAULT NULL,
  p_indicaciones text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_estado_actual text;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  SELECT estado INTO v_estado_actual
    FROM atencion_clinica
    WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Atención no encontrada en su organización.';
  END IF;
  IF v_estado_actual != 'registrada' THEN
    RAISE EXCEPTION 'Solo se puede cerrar una atención en estado registrada.';
  END IF;

  UPDATE atencion_clinica SET
    estado = 'cerrada',
    fecha_cierre = now(),
    tratamiento = COALESCE(p_tratamiento, tratamiento),
    hallazgos = COALESCE(p_hallazgos, hallazgos),
    notas_clinicas = COALESCE(p_notas_clinicas, notas_clinicas),
    indicaciones = COALESCE(p_indicaciones, indicaciones)
  WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_atencion (
    id, atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), p_atencion_id, v_org_id, v_prof_id,
    'registrada', 'cerrada', now()
  );

  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_org_id, v_prof_id, 'atencion_cerrada',
    'atencion_clinica', p_atencion_id, 'registrada', 'cerrada', now()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- T00-4: modificar_estado_cita
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION modificar_estado_cita(
  p_cita_id uuid,
  p_nuevo_estado text,
  p_motivo text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_estado_actual text;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  SELECT estado INTO v_estado_actual
    FROM cita WHERE id = p_cita_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cita no encontrada en su organización.';
  END IF;
  IF v_estado_actual IN ('atendida','cancelada','inasistida') THEN
    RAISE EXCEPTION 'Cita en estado terminal no puede modificarse.';
  END IF;

  UPDATE cita SET
    estado = p_nuevo_estado,
    motivo_cancelacion = CASE WHEN p_nuevo_estado = 'cancelada' THEN p_motivo ELSE motivo_cancelacion END
  WHERE id = p_cita_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_cita (
    id, cita_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, motivo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), p_cita_id, v_org_id, v_prof_id,
    v_estado_actual, p_nuevo_estado, p_motivo, now()
  );

  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_org_id, v_prof_id, 'cita_modificada',
    'cita', p_cita_id, v_estado_actual, p_nuevo_estado, now()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- T00-5: agregar_entrada_clinica
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION agregar_entrada_clinica(
  p_historia_clinica_id uuid,
  p_tipo text,
  p_descripcion text,
  p_notas_adicionales text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_entrada_id uuid;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM historia_clinica
    WHERE id = p_historia_clinica_id AND organizacion_id = v_org_id
  ) THEN
    RAISE EXCEPTION 'Historia clínica no encontrada en su organización.';
  END IF;

  v_entrada_id := gen_random_uuid();

  INSERT INTO entrada_clinica (
    id, historia_clinica_id, organizacion_id, tipo, descripcion,
    estado, notas_adicionales, registrado_por, registrado_en
  ) VALUES (
    v_entrada_id, p_historia_clinica_id, v_org_id, p_tipo, p_descripcion,
    'activo', p_notas_adicionales, v_prof_id, now()
  );

  INSERT INTO evento_auditoria_minima (
    id, organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), v_org_id, v_prof_id, 'historia_clinica_actualizada',
    'entrada_clinica', v_entrada_id, 'activo', now()
  );

  RETURN v_entrada_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- RPCs CONTROLADAS FASE 1
-- ═══════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- registrar_pago
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION registrar_pago(
  p_cobro_id uuid,
  p_medio_pago text,
  p_estado_pago text DEFAULT 'pagado'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_estado_actual text;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  SELECT estado_pago INTO v_estado_actual
    FROM cobro WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cobro no encontrado en su organización.';
  END IF;
  IF v_estado_actual IN ('pagado','anulado') THEN
    RAISE EXCEPTION 'Cobro en estado % no puede recibir pago.', v_estado_actual;
  END IF;

  UPDATE cobro SET
    estado_pago = p_estado_pago,
    medio_pago = p_medio_pago,
    fecha_pago = now()
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_pago (
    id, cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    gen_random_uuid(), p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, p_estado_pago, now()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- anular_cobro
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION anular_cobro(
  p_cobro_id uuid,
  p_motivo text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
  v_estado_actual text;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  SELECT estado_pago INTO v_estado_actual
    FROM cobro WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cobro no encontrado en su organización.';
  END IF;
  IF v_estado_actual = 'anulado' THEN
    RAISE EXCEPTION 'Cobro ya está anulado.';
  END IF;

  UPDATE cobro SET
    estado_pago = 'anulado',
    motivo_anulacion = p_motivo
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO transicion_pago (
    id, cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, notas, ocurrido_en
  ) VALUES (
    gen_random_uuid(), p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, 'anulado', p_motivo, now()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- archivar_paciente
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION archivar_paciente(p_paciente_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof_id uuid;
  v_org_id uuid;
BEGIN
  SELECT prof_id, org_id INTO v_prof_id, v_org_id FROM _obtener_caller();
  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  UPDATE paciente SET estado = 'archivado'
  WHERE id = p_paciente_id
    AND organizacion_id = v_org_id
    AND estado != 'archivado';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Paciente no encontrado, no pertenece a su organización o ya está archivado.';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- cerrar_arancel
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cerrar_arancel(
  p_arancel_id uuid,
  p_vigente_hasta date
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
BEGIN
  v_org_id := obtener_mi_organizacion_id();
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no autenticado.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM valor_arancel
    WHERE id = p_arancel_id AND organizacion_id = v_org_id AND vigente_hasta IS NULL
  ) THEN
    RAISE EXCEPTION 'Arancel no encontrado, no pertenece a su organización o ya fue cerrado.';
  END IF;

  PERFORM set_config('app.rpc_context', 'cerrar_arancel', true);

  UPDATE valor_arancel
    SET vigente_hasta = p_vigente_hasta
    WHERE id = p_arancel_id AND organizacion_id = v_org_id;

  PERFORM set_config('app.rpc_context', '', true);
END;
$$;
