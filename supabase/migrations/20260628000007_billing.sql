-- ============================================================================
-- Migration 07: Billing
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 07 (via v1.1)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- cobro
-- ----------------------------------------------------------------------------
CREATE TABLE public.cobro (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id               UUID NOT NULL
                                REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                   UUID NOT NULL,
  profesional_id                UUID NOT NULL,
  monto                         DECIMAL NOT NULL CHECK (monto >= 0),
  tipo_atencion_nombre_snapshot TEXT NOT NULL,
  modalidad                     TEXT NOT NULL
                                CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  recargo_zona_snapshot         DECIMAL,
  valor_acordado_centro_snapshot DECIMAL,
  concepto                      TEXT NOT NULL,
  categoria_origen              TEXT NOT NULL
                                CHECK (categoria_origen IN (
                                  'atencion_individual', 'conjunto_atenciones',
                                  'recargo_administrativo', 'anticipo'
                                )),
  atencion_clinica_id           UUID,
  estado_pago                   TEXT NOT NULL DEFAULT 'pendiente'
                                CHECK (estado_pago IN ('pendiente', 'pagado_parcial',
                                                       'pagado', 'anulado')),
  medio_pago                    TEXT,
  fecha_pago                    TIMESTAMPTZ,
  motivo_anulacion              TEXT,
  registrado_en                 TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_cobro_org_estado
  ON public.cobro (organizacion_id, estado_pago);

CREATE INDEX idx_cobro_paciente
  ON public.cobro (paciente_id);

-- ----------------------------------------------------------------------------
-- transicion_pago (append-only)
-- ----------------------------------------------------------------------------
CREATE TABLE public.transicion_pago (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cobro_id        UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  notas           TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cobro_id)
    REFERENCES public.cobro(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_transicion_pago_cobro_id
  ON public.transicion_pago (cobro_id);
