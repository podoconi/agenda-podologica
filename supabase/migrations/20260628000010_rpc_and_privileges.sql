-- ============================================================================
-- Migration 10: RPCs and Privileges
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 10 (RPCs via v1.1)
-- ============================================================================

-- ============================================================================
-- 10.1 RPCs T00
-- ============================================================================

-- ----------------------------------------------------------------------------
-- crear_paciente
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_paciente(
  p_nombre_completo TEXT,
  p_rut TEXT DEFAULT NULL,
  p_fecha_nacimiento DATE DEFAULT NULL,
  p_telefono_principal TEXT DEFAULT NULL,
  p_telefono_alternativo TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_direccion TEXT DEFAULT NULL,
  p_origen_categoria TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_paciente_id UUID;
  v_historia_id UUID;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  INSERT INTO public.paciente (
    organizacion_id, nombre_completo, rut, fecha_nacimiento,
    telefono_principal, telefono_alternativo, email, direccion,
    origen_categoria, estado, notas, creado_por
  ) VALUES (
    v_org_id, p_nombre_completo, p_rut, p_fecha_nacimiento,
    p_telefono_principal, p_telefono_alternativo, p_email, p_direccion,
    p_origen_categoria, 'activo', p_notas, v_prof_id
  )
  RETURNING id INTO v_paciente_id;

  INSERT INTO public.historia_clinica (
    paciente_id, organizacion_id
  ) VALUES (
    v_paciente_id, v_org_id
  )
  RETURNING id INTO v_historia_id;

  INSERT INTO public.evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'paciente_creado',
    'paciente', v_paciente_id, 'activo', now()
  );

  RETURN v_paciente_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- registrar_atencion
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_atencion(
  p_paciente_id UUID,
  p_tipo_atencion_id UUID DEFAULT NULL,
  p_modalidad TEXT DEFAULT 'particular',
  p_cita_id UUID DEFAULT NULL,
  p_notas_clinicas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_atencion_id UUID;
  v_tipo_nombre TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.paciente
    WHERE id = p_paciente_id AND organizacion_id = v_org_id
  ) THEN
    RAISE EXCEPTION 'Paciente no encontrado en esta organizacion';
  END IF;

  IF p_tipo_atencion_id IS NOT NULL THEN
    SELECT nombre INTO v_tipo_nombre
    FROM public.tipo_atencion
    WHERE id = p_tipo_atencion_id AND organizacion_id = v_org_id;

    IF v_tipo_nombre IS NULL THEN
      RAISE EXCEPTION 'Tipo de atencion no encontrado en esta organizacion';
    END IF;
  END IF;

  IF p_cita_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.cita
      WHERE id = p_cita_id AND organizacion_id = v_org_id
    ) THEN
      RAISE EXCEPTION 'Cita no encontrada en esta organizacion';
    END IF;
  END IF;

  INSERT INTO public.atencion_clinica (
    organizacion_id, paciente_id, profesional_id,
    tipo_atencion_id, tipo_atencion_nombre_snapshot,
    modalidad, estado, notas_clinicas, cita_id
  ) VALUES (
    v_org_id, p_paciente_id, v_prof_id,
    p_tipo_atencion_id, v_tipo_nombre,
    p_modalidad, 'registrada', p_notas_clinicas, p_cita_id
  )
  RETURNING id INTO v_atencion_id;

  INSERT INTO public.transicion_atencion (
    atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    v_atencion_id, v_org_id, v_prof_id,
    'inexistente', 'registrada'
  );

  INSERT INTO public.evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'atencion_registrada',
    'atencion_clinica', v_atencion_id, 'registrada', now()
  );

  RETURN v_atencion_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- cerrar_atencion
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cerrar_atencion(
  p_atencion_id UUID,
  p_tratamiento TEXT DEFAULT NULL,
  p_hallazgos TEXT DEFAULT NULL,
  p_indicaciones TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT estado INTO v_estado_actual
  FROM public.atencion_clinica
  WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Atencion no encontrada en esta organizacion';
  END IF;

  IF v_estado_actual != 'registrada' THEN
    RAISE EXCEPTION 'Solo se puede cerrar una atencion en estado registrada (actual: %)',
      v_estado_actual;
  END IF;

  UPDATE public.atencion_clinica SET
    estado = 'cerrada',
    fecha_cierre = now(),
    tratamiento = COALESCE(p_tratamiento, tratamiento),
    hallazgos = COALESCE(p_hallazgos, hallazgos),
    indicaciones = COALESCE(p_indicaciones, indicaciones)
  WHERE id = p_atencion_id AND organizacion_id = v_org_id;

  INSERT INTO public.transicion_atencion (
    atencion_clinica_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    p_atencion_id, v_org_id, v_prof_id,
    'registrada', 'cerrada'
  );

  INSERT INTO public.evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'atencion_cerrada',
    'atencion_clinica', p_atencion_id,
    'registrada', 'cerrada', now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- modificar_estado_cita
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.modificar_estado_cita(
  p_cita_id UUID,
  p_estado_nuevo TEXT,
  p_motivo TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF p_estado_nuevo NOT IN ('agendada', 'confirmada', 'atendida',
                            'cancelada', 'inasistida', 'reprogramada') THEN
    RAISE EXCEPTION 'Estado de cita invalido: %', p_estado_nuevo;
  END IF;

  SELECT estado INTO v_estado_actual
  FROM public.cita
  WHERE id = p_cita_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cita no encontrada en esta organizacion';
  END IF;

  IF v_estado_actual IN ('atendida', 'cancelada', 'inasistida') THEN
    RAISE EXCEPTION 'No se puede modificar una cita en estado terminal: %', v_estado_actual;
  END IF;

  UPDATE public.cita SET
    estado = p_estado_nuevo,
    motivo_cancelacion = CASE
      WHEN p_estado_nuevo IN ('cancelada', 'reprogramada') THEN p_motivo
      ELSE motivo_cancelacion
    END
  WHERE id = p_cita_id AND organizacion_id = v_org_id;

  INSERT INTO public.transicion_cita (
    cita_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, motivo
  ) VALUES (
    p_cita_id, v_org_id, v_prof_id,
    v_estado_actual, p_estado_nuevo, p_motivo
  );

  INSERT INTO public.evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id,
    estado_anterior, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'cita_modificada',
    'cita', p_cita_id,
    v_estado_actual, p_estado_nuevo, now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- agregar_entrada_clinica
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agregar_entrada_clinica(
  p_paciente_id UUID,
  p_tipo TEXT,
  p_descripcion TEXT,
  p_notas_adicionales TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_historia_id UUID;
  v_entrada_id UUID;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT id INTO v_historia_id
  FROM public.historia_clinica
  WHERE paciente_id = p_paciente_id AND organizacion_id = v_org_id;

  IF v_historia_id IS NULL THEN
    RAISE EXCEPTION 'Historia clinica no encontrada para el paciente en esta organizacion';
  END IF;

  INSERT INTO public.entrada_clinica (
    historia_clinica_id, organizacion_id, tipo,
    descripcion, notas_adicionales, registrado_por
  ) VALUES (
    v_historia_id, v_org_id, p_tipo,
    p_descripcion, p_notas_adicionales, v_prof_id
  )
  RETURNING id INTO v_entrada_id;

  INSERT INTO public.evento_auditoria_minima (
    organizacion_id, profesional_id, tipo_evento,
    entidad_tipo, entidad_id, estado_nuevo, ocurrido_en
  ) VALUES (
    v_org_id, v_prof_id, 'historia_clinica_actualizada',
    'entrada_clinica', v_entrada_id, 'activo', now()
  );

  RETURN v_entrada_id;
END;
$$;

-- ============================================================================
-- 10.2 RPCs controladas
-- ============================================================================

-- ----------------------------------------------------------------------------
-- registrar_pago
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_pago(
  p_cobro_id UUID,
  p_medio_pago TEXT,
  p_estado_nuevo TEXT DEFAULT 'pagado'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF p_estado_nuevo NOT IN ('pagado_parcial', 'pagado') THEN
    RAISE EXCEPTION 'Estado de pago invalido: %', p_estado_nuevo;
  END IF;

  SELECT estado_pago INTO v_estado_actual
  FROM public.cobro
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cobro no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual IN ('pagado', 'anulado') THEN
    RAISE EXCEPTION 'No se puede registrar pago en cobro con estado: %', v_estado_actual;
  END IF;

  UPDATE public.cobro SET
    estado_pago = p_estado_nuevo,
    medio_pago = p_medio_pago,
    fecha_pago = now()
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO public.transicion_pago (
    cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo
  ) VALUES (
    p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, p_estado_nuevo
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- anular_cobro
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anular_cobro(
  p_cobro_id UUID,
  p_motivo TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  IF p_motivo IS NULL OR p_motivo = '' THEN
    RAISE EXCEPTION 'El motivo de anulacion es obligatorio';
  END IF;

  SELECT estado_pago INTO v_estado_actual
  FROM public.cobro
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Cobro no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual = 'anulado' THEN
    RAISE EXCEPTION 'El cobro ya esta anulado';
  END IF;

  UPDATE public.cobro SET
    estado_pago = 'anulado',
    motivo_anulacion = p_motivo
  WHERE id = p_cobro_id AND organizacion_id = v_org_id;

  INSERT INTO public.transicion_pago (
    cobro_id, organizacion_id, profesional_id,
    estado_anterior, estado_nuevo, notas
  ) VALUES (
    p_cobro_id, v_org_id, v_prof_id,
    v_estado_actual, 'anulado', p_motivo
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- archivar_paciente
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.archivar_paciente(
  p_paciente_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_prof_id UUID;
  v_estado_actual TEXT;
BEGIN
  SELECT id, organizacion_id INTO v_prof_id, v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_prof_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT estado INTO v_estado_actual
  FROM public.paciente
  WHERE id = p_paciente_id AND organizacion_id = v_org_id;

  IF v_estado_actual IS NULL THEN
    RAISE EXCEPTION 'Paciente no encontrado en esta organizacion';
  END IF;

  IF v_estado_actual = 'archivado' THEN
    RAISE EXCEPTION 'El paciente ya esta archivado';
  END IF;

  UPDATE public.paciente SET
    estado = 'archivado'
  WHERE id = p_paciente_id AND organizacion_id = v_org_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- cerrar_arancel
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cerrar_arancel(
  p_valor_arancel_id UUID,
  p_vigente_hasta DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_vigente_hasta_actual DATE;
BEGIN
  SELECT organizacion_id INTO v_org_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid();

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Profesional no encontrado para el usuario autenticado';
  END IF;

  SELECT vigente_hasta INTO v_vigente_hasta_actual
  FROM public.valor_arancel
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Valor de arancel no encontrado en esta organizacion';
  END IF;

  IF v_vigente_hasta_actual IS NOT NULL THEN
    RAISE EXCEPTION 'Este arancel ya tiene vigencia cerrada';
  END IF;

  SET LOCAL app.rpc_cerrar_arancel = 'true';

  UPDATE public.valor_arancel SET
    vigente_hasta = p_vigente_hasta
  WHERE id = p_valor_arancel_id AND organizacion_id = v_org_id;
END;
$$;

-- ============================================================================
-- 10.3 Closed privilege model (REVOKE base + GRANT explicit)
-- ============================================================================

-- === REVOKE base: all Phase 1 tables ===

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

-- === GRANT explicit: authenticated per table ===

GRANT SELECT, UPDATE ON public.organizacion_clinica TO authenticated;
GRANT SELECT, UPDATE ON public.profesional TO authenticated;
GRANT SELECT ON public.evento_auditoria_minima TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.tipo_atencion TO authenticated;
GRANT SELECT, INSERT ON public.valor_arancel TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.paciente TO authenticated;
GRANT SELECT, UPDATE ON public.historia_clinica TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.entrada_clinica TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.seguimiento TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.cita TO authenticated;
GRANT SELECT ON public.transicion_cita TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.atencion_clinica TO authenticated;
GRANT SELECT ON public.transicion_atencion TO authenticated;
GRANT SELECT, INSERT ON public.cobro TO authenticated;
GRANT SELECT ON public.transicion_pago TO authenticated;

-- === REVOKE base: all Phase 1 SECURITY DEFINER functions ===

REVOKE EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.archivar_paciente(UUID) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) FROM anon, authenticated, PUBLIC;

-- === GRANT EXECUTE: only authenticated, only invocable RPCs ===

GRANT EXECUTE ON FUNCTION public.obtener_mi_organizacion_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_paciente(TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_atencion(UUID, UUID, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_atencion(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modificar_estado_cita(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agregar_entrada_clinica(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_pago(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_cobro(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archivar_paciente(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_arancel(UUID, DATE) TO authenticated;
