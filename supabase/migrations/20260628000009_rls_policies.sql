-- ============================================================================
-- Migration 09: RLS Policies
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 09
-- No FORCE ROW LEVEL SECURITY (decision C1 v1.2)
-- ============================================================================

-- ============================================================================
-- Enable RLS on all 16 tables
-- ============================================================================

ALTER TABLE public.organizacion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitacion_profesional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profesional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_auditoria_minima ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipo_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.valor_arancel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paciente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historia_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrada_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seguimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_cita ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atencion_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cobro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transicion_pago ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- invitacion_profesional: no policies (only service_role / SECURITY DEFINER)
-- ============================================================================

-- ============================================================================
-- organizacion_clinica
-- ============================================================================

CREATE POLICY select_own_org ON public.organizacion_clinica
  FOR SELECT USING (id = public.obtener_mi_organizacion_id());

CREATE POLICY update_own_org ON public.organizacion_clinica
  FOR UPDATE USING (id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- profesional
-- ============================================================================

CREATE POLICY select_profesional ON public.profesional
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_own_profesional ON public.profesional
  FOR UPDATE USING (
    organizacion_id = public.obtener_mi_organizacion_id()
    AND auth_user_id = auth.uid()
  );

-- ============================================================================
-- evento_auditoria_minima
-- ============================================================================

CREATE POLICY select_auditoria ON public.evento_auditoria_minima
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- tipo_atencion
-- ============================================================================

CREATE POLICY select_tipo_atencion ON public.tipo_atencion
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_tipo_atencion ON public.tipo_atencion
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_tipo_atencion ON public.tipo_atencion
  FOR UPDATE USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- valor_arancel
-- ============================================================================

CREATE POLICY select_valor_arancel ON public.valor_arancel
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_valor_arancel ON public.valor_arancel
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- paciente
-- ============================================================================

CREATE POLICY select_paciente ON public.paciente
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_paciente ON public.paciente
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_paciente ON public.paciente
  FOR UPDATE USING (
    organizacion_id = public.obtener_mi_organizacion_id()
    AND estado != 'archivado'
  );

-- ============================================================================
-- historia_clinica
-- ============================================================================

CREATE POLICY select_historia ON public.historia_clinica
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_historia ON public.historia_clinica
  FOR UPDATE USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- entrada_clinica
-- ============================================================================

CREATE POLICY select_entrada ON public.entrada_clinica
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_entrada ON public.entrada_clinica
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_entrada ON public.entrada_clinica
  FOR UPDATE USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- seguimiento
-- ============================================================================

CREATE POLICY select_seguimiento ON public.seguimiento
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_seguimiento ON public.seguimiento
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_seguimiento ON public.seguimiento
  FOR UPDATE USING (
    organizacion_id = public.obtener_mi_organizacion_id()
    AND estado NOT IN ('completado', 'descartado')
  );

-- ============================================================================
-- cita
-- ============================================================================

CREATE POLICY select_cita ON public.cita
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_cita ON public.cita
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_cita ON public.cita
  FOR UPDATE USING (
    organizacion_id = public.obtener_mi_organizacion_id()
    AND estado NOT IN ('atendida', 'cancelada', 'inasistida')
  );

-- ============================================================================
-- transicion_cita
-- ============================================================================

CREATE POLICY select_transicion_cita ON public.transicion_cita
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- atencion_clinica
-- ============================================================================

CREATE POLICY select_atencion ON public.atencion_clinica
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_atencion ON public.atencion_clinica
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY update_atencion ON public.atencion_clinica
  FOR UPDATE USING (
    organizacion_id = public.obtener_mi_organizacion_id()
    AND estado = 'registrada'
  );

-- ============================================================================
-- transicion_atencion
-- ============================================================================

CREATE POLICY select_transicion_atencion ON public.transicion_atencion
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- cobro
-- ============================================================================

CREATE POLICY select_cobro ON public.cobro
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());

CREATE POLICY insert_cobro ON public.cobro
  FOR INSERT WITH CHECK (organizacion_id = public.obtener_mi_organizacion_id());

-- ============================================================================
-- transicion_pago
-- ============================================================================

CREATE POLICY select_transicion_pago ON public.transicion_pago
  FOR SELECT USING (organizacion_id = public.obtener_mi_organizacion_id());
