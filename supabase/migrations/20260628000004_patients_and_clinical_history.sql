-- ============================================================================
-- Migration 04: Patients and Clinical History
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 04 (via v1.1)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- paciente
-- ----------------------------------------------------------------------------
CREATE TABLE public.paciente (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo TEXT NOT NULL,
  rut             TEXT,
  fecha_nacimiento DATE,
  telefono_principal TEXT,
  telefono_alternativo TEXT,
  email           TEXT,
  direccion       TEXT,
  origen_categoria TEXT
                  CHECK (origen_categoria IS NULL OR
                         origen_categoria IN ('particular', 'centro_medico', 'administrado_tercero')),
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo', 'en_seguimiento', 'inactivo', 'archivado')),
  notas           TEXT,
  creado_por      UUID NOT NULL,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ,

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, creado_por)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_paciente_rut_org
  ON public.paciente (organizacion_id, rut)
  WHERE rut IS NOT NULL;

CREATE INDEX idx_paciente_org_estado
  ON public.paciente (organizacion_id, estado);

-- ----------------------------------------------------------------------------
-- historia_clinica (1:1 with paciente)
-- ----------------------------------------------------------------------------
CREATE TABLE public.historia_clinica (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  paciente_id     UUID NOT NULL UNIQUE,
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  resumen_general TEXT,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organizacion_id, id),
  FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES public.paciente(organizacion_id, id) ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- entrada_clinica
-- ----------------------------------------------------------------------------
CREATE TABLE public.entrada_clinica (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  historia_clinica_id UUID NOT NULL,
  organizacion_id     UUID NOT NULL
                      REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  tipo                TEXT NOT NULL
                      CHECK (tipo IN ('patologia', 'medicamento', 'alergia', 'observacion', 'otro')),
  descripcion         TEXT NOT NULL,
  estado              TEXT NOT NULL DEFAULT 'activo'
                      CHECK (estado IN ('activo', 'resuelto', 'inactivo')),
  notas_adicionales   TEXT,
  registrado_por      UUID NOT NULL,
  registrado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en      TIMESTAMPTZ,

  FOREIGN KEY (organizacion_id, historia_clinica_id)
    REFERENCES public.historia_clinica(organizacion_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (organizacion_id, registrado_por)
    REFERENCES public.profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_entrada_clinica_historia_estado
  ON public.entrada_clinica (historia_clinica_id, estado);
