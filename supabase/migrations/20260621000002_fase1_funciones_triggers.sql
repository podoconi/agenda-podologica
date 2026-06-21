-- =============================================================================
-- FASE 1 — FUNCIONES Y TRIGGERS
-- Blueprint: SUPABASE_SCHEMA_BLUEPRINT_v1.2.md · Secciones 5, 6, 4.2 (Tipo B)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Función auxiliar central RLS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION obtener_mi_organizacion_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT organizacion_id FROM profesional WHERE auth_user_id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- 2. Trigger AFTER INSERT ON auth.users → crear profesional
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_nombre text;
  v_nombre_docs text;
BEGIN
  v_org_id := (NEW.raw_user_meta_data->>'organizacion_id')::uuid;
  v_nombre := NEW.raw_user_meta_data->>'nombre_completo';
  v_nombre_docs := COALESCE(
    NEW.raw_user_meta_data->>'nombre_para_documentos', v_nombre
  );

  IF v_org_id IS NULL OR v_nombre IS NULL THEN
    RAISE EXCEPTION 'organizacion_id y nombre_completo son requeridos en raw_user_meta_data';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM organizacion_clinica WHERE id = v_org_id) THEN
    RAISE EXCEPTION 'organizacion_clinica % no existe', v_org_id;
  END IF;

  INSERT INTO profesional (
    id, auth_user_id, organizacion_id, nombre_completo,
    email, nombre_para_documentos, estado, creado_en
  ) VALUES (
    gen_random_uuid(), NEW.id, v_org_id, v_nombre,
    NEW.email, v_nombre_docs, 'activo', now()
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ---------------------------------------------------------------------------
-- 3. Trigger genérico actualizado_en
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_set_actualizado_en()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON organizacion_clinica
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON profesional
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON tipo_atencion
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON paciente
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON entrada_clinica
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON seguimiento
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON cita
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();
CREATE TRIGGER set_actualizado_en BEFORE UPDATE ON atencion_clinica
  FOR EACH ROW EXECUTE FUNCTION trg_set_actualizado_en();

-- ---------------------------------------------------------------------------
-- 4. Triggers append-only (sección 5.2)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_deny_update_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% sobre % no está permitido. Tabla append-only.',
    TG_OP, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER deny_update ON evento_auditoria_minima
  BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();
CREATE TRIGGER deny_delete ON evento_auditoria_minima
  BEFORE DELETE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();

CREATE TRIGGER deny_update ON transicion_atencion
  BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();
CREATE TRIGGER deny_delete ON transicion_atencion
  BEFORE DELETE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();

CREATE TRIGGER deny_update ON transicion_cita
  BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();
CREATE TRIGGER deny_delete ON transicion_cita
  BEFORE DELETE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();

CREATE TRIGGER deny_update ON transicion_pago
  BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();
CREATE TRIGGER deny_delete ON transicion_pago
  BEFORE DELETE FOR EACH ROW EXECUTE FUNCTION trg_deny_update_delete();

-- ---------------------------------------------------------------------------
-- 5. Trigger inmutabilidad: entrada_clinica (sección 5.1)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_entrada_clinica_inmutabilidad()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.descripcion       IS DISTINCT FROM NEW.descripcion
  OR OLD.tipo              IS DISTINCT FROM NEW.tipo
  OR OLD.historia_clinica_id IS DISTINCT FROM NEW.historia_clinica_id
  OR OLD.registrado_por    IS DISTINCT FROM NEW.registrado_por
  OR OLD.registrado_en     IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'entrada_clinica: columnas protegidas no pueden modificarse.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inmutabilidad_entrada BEFORE UPDATE ON entrada_clinica
  FOR EACH ROW EXECUTE FUNCTION trg_entrada_clinica_inmutabilidad();

-- ---------------------------------------------------------------------------
-- 6. Trigger inmutabilidad: cobro snapshots (sección 5.1)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_cobro_inmutabilidad()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.monto                          IS DISTINCT FROM NEW.monto
  OR OLD.tipo_atencion_nombre_snapshot  IS DISTINCT FROM NEW.tipo_atencion_nombre_snapshot
  OR OLD.modalidad                      IS DISTINCT FROM NEW.modalidad
  OR OLD.recargo_zona_snapshot          IS DISTINCT FROM NEW.recargo_zona_snapshot
  OR OLD.valor_acordado_centro_snapshot IS DISTINCT FROM NEW.valor_acordado_centro_snapshot
  OR OLD.concepto                       IS DISTINCT FROM NEW.concepto
  OR OLD.categoria_origen               IS DISTINCT FROM NEW.categoria_origen
  OR OLD.registrado_en                  IS DISTINCT FROM NEW.registrado_en
  THEN
    RAISE EXCEPTION 'cobro: columnas snapshot no pueden modificarse.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inmutabilidad_cobro BEFORE UPDATE ON cobro
  FOR EACH ROW EXECUTE FUNCTION trg_cobro_inmutabilidad();

-- ---------------------------------------------------------------------------
-- 7. Trigger inmutabilidad: valor_arancel (sección 5.1 — regla especial)
--    Mecanismo verificable: usa session var app.rpc_context
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_valor_arancel_inmutabilidad()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.rpc_context', true) IS DISTINCT FROM 'cerrar_arancel' THEN
    RAISE EXCEPTION 'valor_arancel: UPDATE directo no permitido. Use RPC cerrar_arancel.';
  END IF;

  IF OLD.tipo_atencion_id IS DISTINCT FROM NEW.tipo_atencion_id
  OR OLD.organizacion_id  IS DISTINCT FROM NEW.organizacion_id
  OR OLD.modalidad        IS DISTINCT FROM NEW.modalidad
  OR OLD.valor            IS DISTINCT FROM NEW.valor
  OR OLD.vigente_desde    IS DISTINCT FROM NEW.vigente_desde
  OR OLD.configurado_por  IS DISTINCT FROM NEW.configurado_por
  OR OLD.creado_en        IS DISTINCT FROM NEW.creado_en
  THEN
    RAISE EXCEPTION 'valor_arancel: columnas protegidas no pueden modificarse.';
  END IF;

  IF OLD.vigente_hasta IS NOT NULL THEN
    RAISE EXCEPTION 'valor_arancel: vigente_hasta ya tiene valor y no puede modificarse.';
  END IF;

  IF NEW.vigente_hasta IS NULL THEN
    RAISE EXCEPTION 'valor_arancel: vigente_hasta debe recibir una fecha válida.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER inmutabilidad_arancel BEFORE UPDATE ON valor_arancel
  FOR EACH ROW EXECUTE FUNCTION trg_valor_arancel_inmutabilidad();

-- ---------------------------------------------------------------------------
-- 8. Trigger inmutabilidad: atencion_clinica cerrada (sección 5.1)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_atencion_clinica_inmutabilidad()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.estado = 'cerrada' THEN
    IF OLD.tratamiento     IS DISTINCT FROM NEW.tratamiento
    OR OLD.hallazgos       IS DISTINCT FROM NEW.hallazgos
    OR OLD.notas_clinicas  IS DISTINCT FROM NEW.notas_clinicas
    OR OLD.indicaciones    IS DISTINCT FROM NEW.indicaciones
    OR OLD.fecha_cierre    IS DISTINCT FROM NEW.fecha_cierre
    OR OLD.paciente_id     IS DISTINCT FROM NEW.paciente_id
    OR OLD.profesional_id  IS DISTINCT FROM NEW.profesional_id
    OR OLD.modalidad       IS DISTINCT FROM NEW.modalidad
    THEN
      RAISE EXCEPTION 'atencion_clinica cerrada: columnas clínicas no pueden modificarse.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inmutabilidad_atencion BEFORE UPDATE ON atencion_clinica
  FOR EACH ROW EXECUTE FUNCTION trg_atencion_clinica_inmutabilidad();

-- ---------------------------------------------------------------------------
-- 9. Triggers Tipo B diferidos (paso 12b — blueprint sección 13)
--    Tabla destino atencion_clinica ya existe en este punto.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_validar_atencion_clinica_tenant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_ref_org uuid;
BEGIN
  IF NEW.atencion_clinica_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT organizacion_id INTO v_ref_org
    FROM atencion_clinica WHERE id = NEW.atencion_clinica_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '% atencion_clinica_id % no existe.',
      TG_TABLE_NAME, NEW.atencion_clinica_id;
  END IF;

  IF v_ref_org IS DISTINCT FROM NEW.organizacion_id THEN
    RAISE EXCEPTION '% atencion_clinica_id % pertenece a otra organización.',
      TG_TABLE_NAME, NEW.atencion_clinica_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Paso 12b: triggers sobre seguimiento y cita
CREATE TRIGGER tipo_b_atencion ON seguimiento
  BEFORE INSERT OR UPDATE OF atencion_clinica_id
  FOR EACH ROW EXECUTE FUNCTION trg_validar_atencion_clinica_tenant();

CREATE TRIGGER tipo_b_atencion ON cita
  BEFORE INSERT OR UPDATE OF atencion_clinica_id
  FOR EACH ROW EXECUTE FUNCTION trg_validar_atencion_clinica_tenant();

-- Paso 14: trigger sobre cobro
CREATE TRIGGER tipo_b_atencion ON cobro
  BEFORE INSERT OR UPDATE OF atencion_clinica_id
  FOR EACH ROW EXECUTE FUNCTION trg_validar_atencion_clinica_tenant();
