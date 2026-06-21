-- =============================================================================
-- FASE 1 — ROW LEVEL SECURITY
-- Blueprint: SUPABASE_SCHEMA_BLUEPRINT_v1.2.md · Sección 11
-- =============================================================================

-- ---------------------------------------------------------------------------
-- organizacion_clinica
-- ---------------------------------------------------------------------------
ALTER TABLE organizacion_clinica ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_org_select ON organizacion_clinica
  FOR SELECT USING (id = obtener_mi_organizacion_id());

CREATE POLICY pol_org_update ON organizacion_clinica
  FOR UPDATE USING (id = obtener_mi_organizacion_id());

-- INSERT/DELETE: solo sistema (sin policy = denegado para authenticated)

-- ---------------------------------------------------------------------------
-- profesional
-- ---------------------------------------------------------------------------
ALTER TABLE profesional ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_prof_select ON profesional
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_prof_update ON profesional
  FOR UPDATE USING (auth_user_id = auth.uid());

-- INSERT: via trigger AFTER INSERT ON auth.users (SECURITY DEFINER)
-- DELETE: nunca

-- ---------------------------------------------------------------------------
-- evento_auditoria_minima
-- ---------------------------------------------------------------------------
ALTER TABLE evento_auditoria_minima ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_evento_select ON evento_auditoria_minima
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- INSERT: solo via RPCs T00 (SECURITY DEFINER, bypasses RLS)
-- UPDATE: nunca (trigger append-only)
-- DELETE: nunca (trigger append-only)

-- ---------------------------------------------------------------------------
-- tipo_atencion
-- ---------------------------------------------------------------------------
ALTER TABLE tipo_atencion ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_tipo_select ON tipo_atencion
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_tipo_insert ON tipo_atencion
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_tipo_update ON tipo_atencion
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());

-- ---------------------------------------------------------------------------
-- valor_arancel
-- ---------------------------------------------------------------------------
ALTER TABLE valor_arancel ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_arancel_select ON valor_arancel
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_arancel_insert ON valor_arancel
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

-- UPDATE: solo via RPC cerrar_arancel (SECURITY DEFINER) — sin policy
-- DELETE: nunca

-- ---------------------------------------------------------------------------
-- paciente
-- ---------------------------------------------------------------------------
ALTER TABLE paciente ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_pac_select ON paciente
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_pac_insert ON paciente
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_pac_update ON paciente
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado != 'archivado'
  );

-- ---------------------------------------------------------------------------
-- historia_clinica
-- ---------------------------------------------------------------------------
ALTER TABLE historia_clinica ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_hc_select ON historia_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- INSERT: via RPC crear_paciente (SECURITY DEFINER)

CREATE POLICY pol_hc_update ON historia_clinica
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());

-- ---------------------------------------------------------------------------
-- entrada_clinica
-- ---------------------------------------------------------------------------
ALTER TABLE entrada_clinica ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_ec_select ON entrada_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_ec_insert ON entrada_clinica
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_ec_update ON entrada_clinica
  FOR UPDATE USING (organizacion_id = obtener_mi_organizacion_id());

-- ---------------------------------------------------------------------------
-- seguimiento
-- ---------------------------------------------------------------------------
ALTER TABLE seguimiento ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_seg_select ON seguimiento
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_seg_insert ON seguimiento
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_seg_update ON seguimiento
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado NOT IN ('completado','descartado')
  );

-- ---------------------------------------------------------------------------
-- cita
-- ---------------------------------------------------------------------------
ALTER TABLE cita ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_cita_select ON cita
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_cita_insert ON cita
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_cita_update ON cita
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado NOT IN ('atendida','cancelada','inasistida')
  );

-- ---------------------------------------------------------------------------
-- transicion_cita
-- ---------------------------------------------------------------------------
ALTER TABLE transicion_cita ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_tcita_select ON transicion_cita
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- INSERT: via RPC modificar_estado_cita (SECURITY DEFINER)
-- UPDATE/DELETE: nunca (trigger append-only)

-- ---------------------------------------------------------------------------
-- atencion_clinica
-- ---------------------------------------------------------------------------
ALTER TABLE atencion_clinica ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_aten_select ON atencion_clinica
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_aten_insert ON atencion_clinica
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_aten_update ON atencion_clinica
  FOR UPDATE USING (
    organizacion_id = obtener_mi_organizacion_id()
    AND estado = 'registrada'
  );

-- ---------------------------------------------------------------------------
-- transicion_atencion
-- ---------------------------------------------------------------------------
ALTER TABLE transicion_atencion ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_taten_select ON transicion_atencion
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- INSERT: via RPCs T00 (SECURITY DEFINER)
-- UPDATE/DELETE: nunca (trigger append-only)

-- ---------------------------------------------------------------------------
-- cobro
-- ---------------------------------------------------------------------------
ALTER TABLE cobro ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_cobro_select ON cobro
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

CREATE POLICY pol_cobro_insert ON cobro
  FOR INSERT WITH CHECK (organizacion_id = obtener_mi_organizacion_id());

-- UPDATE: solo via RPCs registrar_pago / anular_cobro (SECURITY DEFINER)
-- DELETE: nunca

-- ---------------------------------------------------------------------------
-- transicion_pago
-- ---------------------------------------------------------------------------
ALTER TABLE transicion_pago ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_tpago_select ON transicion_pago
  FOR SELECT USING (organizacion_id = obtener_mi_organizacion_id());

-- INSERT: via RPCs controladas (SECURITY DEFINER)
-- UPDATE/DELETE: nunca (trigger append-only)
