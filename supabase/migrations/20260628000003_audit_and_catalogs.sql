-- ============================================================================
-- Migration 03: Audit and Catalogs
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 03 (via v1.1)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- evento_auditoria_minima (append-only, T00)
-- ----------------------------------------------------------------------------
CREATE TABLE public.evento_auditoria_minima (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id   UUID NOT NULL
                    REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id    UUID NOT NULL,
  tipo_evento       TEXT NOT NULL
                    CHECK (tipo_evento IN (
                      'paciente_creado',
                      'atencion_registrada',
                      'atencion_cerrada',
                      'cita_modificada',
                      'historia_clinica_actualizada'
                    )),
  entidad_tipo      TEXT NOT NULL,
  entidad_id        UUID NOT NULL,
  estado_anterior   TEXT,
  estado_nuevo      TEXT,
  resumen_contextual TEXT,
  ocurrido_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_auditoria_org_tipo_fecha
  ON public.evento_auditoria_minima (organizacion_id, tipo_evento, ocurrido_en);

CREATE INDEX idx_auditoria_entidad
  ON public.evento_auditoria_minima (entidad_tipo, entidad_id);

-- ----------------------------------------------------------------------------
-- tipo_atencion
-- ----------------------------------------------------------------------------
CREATE TABLE public.tipo_atencion (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  nombre          TEXT NOT NULL,
  descripcion     TEXT,
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo', 'inactivo')),
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ,

  UNIQUE (organizacion_id, id)
);

CREATE UNIQUE INDEX uq_tipo_atencion_nombre_activo
  ON public.tipo_atencion (organizacion_id, nombre)
  WHERE estado = 'activo';

CREATE INDEX idx_tipo_atencion_org_estado
  ON public.tipo_atencion (organizacion_id, estado);

-- ----------------------------------------------------------------------------
-- valor_arancel
-- ----------------------------------------------------------------------------
CREATE TABLE public.valor_arancel (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_atencion_id UUID NOT NULL,
  organizacion_id  UUID NOT NULL
                   REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  modalidad        TEXT NOT NULL
                   CHECK (modalidad IN ('particular', 'domiciliaria', 'centro_medico')),
  valor            DECIMAL NOT NULL CHECK (valor >= 0),
  vigente_desde    DATE NOT NULL,
  vigente_hasta    DATE,
  configurado_por  UUID NOT NULL,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),

  FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES public.tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, configurado_por)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_valor_arancel_vigente
  ON public.valor_arancel (tipo_atencion_id, organizacion_id, modalidad)
  WHERE vigente_hasta IS NULL;
