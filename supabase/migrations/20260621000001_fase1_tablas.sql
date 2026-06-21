-- =============================================================================
-- FASE 1 — TABLAS (15 tablas)
-- Blueprint: SUPABASE_SCHEMA_BLUEPRINT_v1.2.md · Sección 13, pasos 1–15
-- =============================================================================

-- Paso 1: organizacion_clinica
CREATE TABLE organizacion_clinica (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre_legal  text NOT NULL,
  nombre_fantasia text,
  identificacion_fiscal text UNIQUE,
  email         text,
  telefono      text,
  direccion     text,
  zona_horaria  text NOT NULL DEFAULT 'America/Santiago',
  duracion_cita_defecto_minutos integer NOT NULL DEFAULT 60,
  estado        text NOT NULL DEFAULT 'activa'
                CHECK (estado IN ('activa','suspendida','cerrada')),
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz
);

-- Paso 2: profesional
CREATE TABLE profesional (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id  uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo text NOT NULL,
  email         text NOT NULL UNIQUE,
  nombre_para_documentos text NOT NULL,
  especialidad  text,
  numero_colegiado text,
  estado        text NOT NULL DEFAULT 'activo'
                CHECK (estado IN ('activo','suspendido','desactivado')),
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_profesional_org_id UNIQUE (organizacion_id, id)
);

-- Paso 3: evento_auditoria_minima
CREATE TABLE evento_auditoria_minima (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id uuid NOT NULL,
  tipo_evento   text NOT NULL
                CHECK (tipo_evento IN (
                  'paciente_creado','atencion_registrada','atencion_cerrada',
                  'cita_modificada','historia_clinica_actualizada')),
  entidad_tipo  text NOT NULL,
  entidad_id    uuid NOT NULL,
  estado_anterior text,
  estado_nuevo  text,
  resumen_contextual text,
  ocurrido_en   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_evento_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

-- Paso 4: tipo_atencion
CREATE TABLE tipo_atencion (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre        text NOT NULL,
  descripcion   text,
  estado        text NOT NULL DEFAULT 'activo'
                CHECK (estado IN ('activo','inactivo')),
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_tipo_atencion_org_id UNIQUE (organizacion_id, id)
);

CREATE UNIQUE INDEX uq_tipo_atencion_nombre_activo
  ON tipo_atencion (organizacion_id, nombre) WHERE estado = 'activo';

-- Paso 5: valor_arancel
CREATE TABLE valor_arancel (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_atencion_id uuid NOT NULL,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  modalidad     text NOT NULL
                CHECK (modalidad IN ('particular','domiciliaria','centro_medico')),
  valor         numeric NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  configurado_por uuid NOT NULL,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_arancel_tipo_tenant
    FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_arancel_profesional_tenant
    FOREIGN KEY (organizacion_id, configurado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_valor_arancel_vigente
  ON valor_arancel (tipo_atencion_id, organizacion_id, modalidad)
  WHERE vigente_hasta IS NULL;

-- Paso 6: paciente
CREATE TABLE paciente (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  nombre_completo text NOT NULL,
  rut           text,
  fecha_nacimiento date,
  telefono_principal text,
  telefono_alternativo text,
  email         text,
  direccion     text,
  origen_categoria text
                CHECK (origen_categoria IS NULL
                  OR origen_categoria IN ('particular','centro_medico','administrado_tercero')),
  estado        text NOT NULL DEFAULT 'activo'
                CHECK (estado IN ('activo','en_seguimiento','inactivo','archivado')),
  notas         text,
  creado_por    uuid NOT NULL,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_paciente_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_paciente_profesional_tenant
    FOREIGN KEY (organizacion_id, creado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_paciente_org_estado ON paciente (organizacion_id, estado);
CREATE UNIQUE INDEX uq_paciente_rut ON paciente (organizacion_id, rut) WHERE rut IS NOT NULL;

-- Paso 7: historia_clinica
CREATE TABLE historia_clinica (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paciente_id   uuid NOT NULL UNIQUE,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  resumen_general text,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_historia_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_historia_paciente_tenant
    FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT
);

-- Paso 8: entrada_clinica
CREATE TABLE entrada_clinica (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  historia_clinica_id uuid NOT NULL,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  tipo          text NOT NULL
                CHECK (tipo IN ('patologia','medicamento','alergia','observacion','otro')),
  descripcion   text NOT NULL,
  estado        text NOT NULL DEFAULT 'activo'
                CHECK (estado IN ('activo','resuelto','inactivo')),
  notas_adicionales text,
  registrado_por uuid NOT NULL,
  registrado_en timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT fk_entrada_historia_tenant
    FOREIGN KEY (organizacion_id, historia_clinica_id)
    REFERENCES historia_clinica(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_entrada_profesional_tenant
    FOREIGN KEY (organizacion_id, registrado_por)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_entrada_historia_estado ON entrada_clinica (historia_clinica_id, estado);

-- Paso 9: seguimiento (sin cita_id todavía, sin trigger Tipo B todavía)
CREATE TABLE seguimiento (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id   uuid NOT NULL,
  profesional_id uuid NOT NULL,
  tipo          text NOT NULL,
  urgencia      text NOT NULL DEFAULT 'normal'
                CHECK (urgencia IN ('normal','prioritario','urgente')),
  estado        text NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','contactado','agendado','completado','vencido','descartado')),
  origen        text NOT NULL DEFAULT 'manual'
                CHECK (origen IN ('manual','automatico_cierre_atencion')),
  atencion_clinica_id uuid,
  cita_id       uuid,
  notas         text,
  fecha_limite  timestamptz,
  resuelto_en   timestamptz,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_seguimiento_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_seg_paciente_tenant
    FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_seg_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_seg_org_estado_urgencia ON seguimiento (organizacion_id, estado, urgencia);
CREATE INDEX idx_seg_paciente_estado ON seguimiento (paciente_id, estado);

-- Paso 10: cita (sin trigger Tipo B todavía)
CREATE TABLE cita (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id   uuid NOT NULL,
  profesional_id uuid NOT NULL,
  tipo_atencion_id uuid,
  tipo_atencion_nombre_snapshot text,
  inicio        timestamptz NOT NULL,
  duracion_minutos integer NOT NULL,
  estado        text NOT NULL DEFAULT 'agendada'
                CHECK (estado IN ('agendada','confirmada','atendida','cancelada','inasistida','reprogramada')),
  motivo_cancelacion text,
  notas         text,
  cita_anterior_id uuid,
  seguimiento_id uuid,
  atencion_clinica_id uuid,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_cita_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_cita_paciente_tenant
    FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_tipo_tenant
    FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_anterior_tenant
    FOREIGN KEY (organizacion_id, cita_anterior_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_seguimiento_tenant
    FOREIGN KEY (organizacion_id, seguimiento_id)
    REFERENCES seguimiento(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_cita_prof_inicio ON cita (profesional_id, inicio);
CREATE INDEX idx_cita_org_inicio_estado ON cita (organizacion_id, inicio, estado);
CREATE INDEX idx_cita_paciente_estado ON cita (paciente_id, estado);

-- Paso 10b: FK compuesta seguimiento.cita_id → cita
ALTER TABLE seguimiento
  ADD CONSTRAINT fk_seg_cita_tenant
    FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT;

-- Paso 11: transicion_cita
CREATE TABLE transicion_cita (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cita_id       uuid NOT NULL,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id uuid NOT NULL,
  estado_anterior text NOT NULL,
  estado_nuevo  text NOT NULL,
  motivo        text,
  ocurrido_en   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_tcita_cita_tenant
    FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_tcita_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_tcita_cita ON transicion_cita (cita_id);

-- Paso 12: atencion_clinica
CREATE TABLE atencion_clinica (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id   uuid NOT NULL,
  profesional_id uuid NOT NULL,
  tipo_atencion_id uuid,
  tipo_atencion_nombre_snapshot text,
  modalidad     text NOT NULL
                CHECK (modalidad IN ('particular','domiciliaria','centro_medico')),
  estado        text NOT NULL DEFAULT 'registrada'
                CHECK (estado IN ('registrada','cerrada','descartada')),
  fecha_inicio  timestamptz NOT NULL DEFAULT now(),
  fecha_cierre  timestamptz,
  tratamiento   text,
  hallazgos     text,
  notas_clinicas text,
  indicaciones  text,
  cita_id       uuid,
  creado_en     timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz,
  CONSTRAINT uq_atencion_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_aten_paciente_tenant
    FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_aten_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_aten_tipo_tenant
    FOREIGN KEY (organizacion_id, tipo_atencion_id)
    REFERENCES tipo_atencion(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_aten_cita_tenant
    FOREIGN KEY (organizacion_id, cita_id)
    REFERENCES cita(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_aten_paciente_estado ON atencion_clinica (paciente_id, estado);
CREATE INDEX idx_aten_prof_fecha ON atencion_clinica (profesional_id, fecha_inicio);
CREATE INDEX idx_aten_org_estado_fecha ON atencion_clinica (organizacion_id, estado, fecha_inicio);

-- Paso 13: transicion_atencion
CREATE TABLE transicion_atencion (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  atencion_clinica_id uuid NOT NULL,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id uuid NOT NULL,
  estado_anterior text NOT NULL,
  estado_nuevo  text NOT NULL,
  motivo        text,
  ocurrido_en   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_taten_atencion_tenant
    FOREIGN KEY (organizacion_id, atencion_clinica_id)
    REFERENCES atencion_clinica(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_taten_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_taten_atencion ON transicion_atencion (atencion_clinica_id);

-- Paso 14: cobro
CREATE TABLE cobro (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  paciente_id   uuid NOT NULL,
  profesional_id uuid NOT NULL,
  monto         numeric NOT NULL,
  tipo_atencion_nombre_snapshot text NOT NULL,
  modalidad     text NOT NULL
                CHECK (modalidad IN ('particular','domiciliaria','centro_medico')),
  recargo_zona_snapshot numeric,
  valor_acordado_centro_snapshot numeric,
  concepto      text NOT NULL,
  categoria_origen text NOT NULL
                CHECK (categoria_origen IN (
                  'atencion_individual','conjunto_atenciones',
                  'recargo_administrativo','anticipo')),
  atencion_clinica_id uuid,
  estado_pago   text NOT NULL DEFAULT 'pendiente'
                CHECK (estado_pago IN ('pendiente','pagado_parcial','pagado','anulado')),
  medio_pago    text,
  fecha_pago    timestamptz,
  motivo_anulacion text,
  registrado_en timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_cobro_org_id UNIQUE (organizacion_id, id),
  CONSTRAINT fk_cobro_paciente_tenant
    FOREIGN KEY (organizacion_id, paciente_id)
    REFERENCES paciente(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cobro_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_cobro_org_estado ON cobro (organizacion_id, estado_pago);
CREATE INDEX idx_cobro_paciente ON cobro (paciente_id);

-- Paso 15: transicion_pago
CREATE TABLE transicion_pago (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cobro_id      uuid NOT NULL,
  organizacion_id uuid NOT NULL REFERENCES organizacion_clinica(id) ON DELETE RESTRICT,
  profesional_id uuid NOT NULL,
  estado_anterior text NOT NULL,
  estado_nuevo  text NOT NULL,
  notas         text,
  ocurrido_en   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_tpago_cobro_tenant
    FOREIGN KEY (organizacion_id, cobro_id)
    REFERENCES cobro(organizacion_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_tpago_profesional_tenant
    FOREIGN KEY (organizacion_id, profesional_id)
    REFERENCES profesional(organizacion_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_tpago_cobro ON transicion_pago (cobro_id);

-- Índices adicionales de auditoría
CREATE INDEX idx_evento_org_tipo_fecha
  ON evento_auditoria_minima (organizacion_id, tipo_evento, ocurrido_en);
CREATE INDEX idx_evento_entidad
  ON evento_auditoria_minima (entidad_tipo, entidad_id);

-- Índice de valor_arancel
CREATE INDEX idx_arancel_tipo_modalidad
  ON valor_arancel (tipo_atencion_id, organizacion_id, modalidad);
