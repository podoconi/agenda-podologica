-- ============================================================================
-- Migration 02: Identity, Onboarding and Auth
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 02
-- ============================================================================

-- ----------------------------------------------------------------------------
-- organizacion_clinica
-- ----------------------------------------------------------------------------
CREATE TABLE public.organizacion_clinica (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre_legal    TEXT NOT NULL,
  nombre_fantasia TEXT,
  identificacion_fiscal TEXT UNIQUE,
  email           TEXT,
  telefono        TEXT,
  direccion       TEXT,
  zona_horaria    TEXT NOT NULL DEFAULT 'America/Santiago',
  duracion_cita_defecto_minutos INTEGER NOT NULL DEFAULT 60,
  estado          TEXT NOT NULL DEFAULT 'activa'
                  CHECK (estado IN ('activa', 'suspendida', 'cerrada')),
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- invitacion_profesional (tabla 16 — seguridad de onboarding)
-- ----------------------------------------------------------------------------
CREATE TABLE public.invitacion_profesional (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id UUID NOT NULL
                  REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  email           TEXT NOT NULL,
  nombre_completo TEXT NOT NULL,
  nombre_para_documentos TEXT NOT NULL,
  token           UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  estado          TEXT NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente', 'consumida', 'expirada', 'revocada')),
  creado_por      UUID,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expira_en       TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  consumida_en    TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_invitacion_pendiente_email_org
  ON public.invitacion_profesional (lower(trim(email)), organizacion_id)
  WHERE estado = 'pendiente';

CREATE INDEX idx_invitacion_token_pendiente
  ON public.invitacion_profesional (token)
  WHERE estado = 'pendiente';

-- ----------------------------------------------------------------------------
-- profesional
-- ----------------------------------------------------------------------------
CREATE TABLE public.profesional (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id           UUID NOT NULL UNIQUE
                         REFERENCES auth.users(id) ON DELETE RESTRICT,
  organizacion_id        UUID NOT NULL
                         REFERENCES public.organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo        TEXT NOT NULL,
  email                  TEXT NOT NULL UNIQUE,
  nombre_para_documentos TEXT NOT NULL,
  especialidad           TEXT,
  numero_colegiado       TEXT,
  estado                 TEXT NOT NULL DEFAULT 'activo'
                         CHECK (estado IN ('activo', 'suspendido', 'desactivado')),
  creado_en              TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en         TIMESTAMPTZ,

  UNIQUE (organizacion_id, id)
);

-- ----------------------------------------------------------------------------
-- Trigger: auth.users → profesional (with invitation validation)
-- Uses UPDATE...RETURNING to prevent concurrent double-consumption of token
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_token UUID;
  v_invitacion RECORD;
BEGIN
  v_token := (NEW.raw_user_meta_data->>'token')::UUID;

  IF v_token IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: token de invitacion requerido';
  END IF;

  UPDATE public.invitacion_profesional SET
    estado = 'consumida',
    consumida_en = now()
  WHERE token = v_token
    AND lower(trim(email)) = lower(trim(NEW.email))
    AND estado = 'pendiente'
    AND expira_en > now()
  RETURNING id, organizacion_id, nombre_completo, nombre_para_documentos
  INTO v_invitacion;

  IF v_invitacion IS NULL THEN
    RAISE EXCEPTION 'Registro rechazado: invitacion no encontrada, expirada, revocada o email no coincide';
  END IF;

  INSERT INTO public.profesional (
    auth_user_id,
    organizacion_id,
    nombre_completo,
    email,
    nombre_para_documentos
  ) VALUES (
    NEW.id,
    v_invitacion.organizacion_id,
    v_invitacion.nombre_completo,
    NEW.email,
    v_invitacion.nombre_para_documentos
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- obtener_mi_organizacion_id (after profesional exists — fixes C1)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.obtener_mi_organizacion_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT organizacion_id
  FROM public.profesional
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$;
