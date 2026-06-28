-- ============================================================================
-- Migration 06: Clinical Care
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 06 (via v1.1)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- atencion_clinica
-- ----------------------------------------------------------------------------
CREATE TABLE public.atencion_clinica (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id             UUID NOT NULL
                              REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                 UUID NOT NULL,
  profesional_id              UUID NOT NULL,
  tipo_atencion_id            UUID,
  tipo_atencion_nombre_snapshot TEXT,
  modalidad                   TEXT NOT NULL
                              CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  estado                      TEXT NOT NULL DEFAULT 'registrada'
                              CHECK (estado IN ('registrada', 'cerrada', 'descartada')),
  fecha_inicio                TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_cierre                TIMESTAMPTZ,
  tratamiento                 TEXT,
  hallazgos                   TEXT,
  notas_clinicas              TEXT,
  indicaciones                TEXT,
  cita_id                     UUID,
  creado_en                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en              TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_atencion_paciente_estado
  ON public.atencion_clinica (paciente_id, estado);

CREATE INDEX idx_atencion_profesional_fecha
  ON public.atencion_clinica (profesional_id, fecha_inicio);

CREATE INDEX idx_atencion_org_estado_fecha
  ON public.atencion_clinica (organizacion_id, estado, fecha_inicio);

-- ----------------------------------------------------------------------------
-- transicion_atencion (append-only)
-- ----------------------------------------------------------------------------
CREATE TABLE public.transicion_atencion (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  atencion_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id      UUID NOT NULL,
  estado_anterior     TEXT NOT NULL,
  estado_nuevo        TEXT NOT NULL,
  motivo              TEXT,
  ocurrido_en         TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, atencion_clinica_id)
    REFERENCES public.atencion_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_transicion_atencion_atencion_id
  ON public.transicion_atencion (atencion_clinica_id);
