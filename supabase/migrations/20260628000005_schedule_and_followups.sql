-- ============================================================================
-- Migration 05: Schedule and Followups
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 05 (via v1.1)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- seguimiento
-- ----------------------------------------------------------------------------
CREATE TABLE public.seguimiento (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id         UUID NOT NULL,
  profesional_id      UUID NOT NULL,
  tipo                TEXT NOT NULL,
  urgencia            TEXT NOT NULL DEFAULT 'normal'
                      CHECK (urgencia IN ('normal', 'prioritario', 'urgente')),
  estado              TEXT NOT NULL DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente', 'contactado', 'agendado',
                                        'completado', 'vencido', 'descartado')),
  origen              TEXT NOT NULL DEFAULT 'manual'
                      CHECK (origen IN ('manual', 'automatico_cierre_atencion')),
  atencion_clinica_id UUID,
  cita_id             UUID,
  notas               TEXT,
  fecha_limite        TIMESTAMPTZ,
  resuelto_en         TIMESTAMPTZ,
  creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en      TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_seguimiento_org_estado_urgencia
  ON public.seguimiento (organizacion_id, estado, urgencia);

CREATE INDEX idx_seguimiento_paciente_estado
  ON public.seguimiento (paciente_id, estado);

-- ----------------------------------------------------------------------------
-- cita
-- ----------------------------------------------------------------------------
CREATE TABLE public.cita (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id             UUID NOT NULL
                              REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id                 UUID NOT NULL,
  profesional_id              UUID NOT NULL,
  tipo_atencion_id            UUID,
  tipo_atencion_nombre_snapshot TEXT,
  inicio                      TIMESTAMPTZ NOT NULL,
  duracion_minutos            INTEGER NOT NULL CHECK (duracion_minutos > 0),
  estado                      TEXT NOT NULL DEFAULT 'agendada'
                              CHECK (estado IN ('agendada', 'confirmada', 'atendida',
                                                'cancelada', 'inasistida', 'reprogramada')),
  motivo_cancelacion          TEXT,
  notas                       TEXT,
  cita_anterior_id            UUID,
  seguimiento_id              UUID,
  atencion_clinica_id         UUID,
  creado_en                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en              TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, cita_anterior_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, seguimiento_id)
    REFERENCES public.seguimiento(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_cita_profesional_inicio
  ON public.cita (profesional_id, inicio);

CREATE INDEX idx_cita_org_inicio_estado
  ON public.cita (organizacion_id, inicio, estado);

CREATE INDEX idx_cita_paciente_estado
  ON public.cita (paciente_id, estado);

-- ----------------------------------------------------------------------------
-- ALTER: seguimiento.cita_id FK (cita now exists)
-- ----------------------------------------------------------------------------
ALTER TABLE public.seguimiento
  ADD CONSTRAINT fk_seguimiento_cita
  FOREIGN KEY (organizacion_id, cita_id)
  REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT;

-- ----------------------------------------------------------------------------
-- transicion_cita (append-only)
-- ----------------------------------------------------------------------------
CREATE TABLE public.transicion_cita (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cita_id         UUID NOT NULL,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id  UUID NOT NULL,
  estado_anterior TEXT NOT NULL,
  estado_nuevo    TEXT NOT NULL,
  motivo          TEXT,
  ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES public.cita(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_transicion_cita_cita_id
  ON public.transicion_cita (cita_id);
