# Arquitectura de Datos Relacional Conceptual — Agenda Podológica

**Versión:** 1.0  
**Estado:** Fundacional  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuentes:** DATA_MODEL_CONCEPTUAL_v1.1.md · CANONICAL_DATA_FOUNDATION_PODOLOGIA.md · ARQUITECTURA_CONCEPTUAL_v1.1.md · DOMINIO_CANONICO_PODOLOGIA_v1.1.md

---

## Propósito de este documento

Este documento transforma el Modelo Conceptual de Datos (Bounded Contexts, Aggregate Roots, Domain Events) en una Arquitectura de Datos Relacional Conceptual: el mapa de entidades, sus atributos conceptuales, sus relaciones, sus reglas de integridad y sus restricciones de negocio.

No contiene SQL. No contiene migraciones. No especifica Supabase. No define tipos de datos. No produce código. Es el documento que debe existir antes de diseñar tablas, políticas o procedimientos almacenados.

Este documento es la **Base Canónica** de la que se derivarán:
- Supabase Schema (tablas, columnas, tipos)
- Migraciones (evolución controlada del esquema)
- Row Level Security Policies (control de acceso por fila)
- RPCs y funciones (operaciones transaccionales)

Toda decisión de implementación futura debe poder justificarse contra este documento o debe provocar una revisión explícita del mismo.

---

## Nota sobre la transición de DDD a Relacional

En el Modelo Conceptual de Datos, la unidad de organización es el **Aggregate Root** — una entidad que protege la consistencia de un grupo de conceptos relacionados. En el modelo relacional, la unidad es la **entidad** — que generalmente corresponde a una tabla.

La transición introduce la siguiente distinción importante: un Aggregate Root puede volverse **varias entidades relacionadas** en el modelo relacional. Por ejemplo, el Aggregate Root `AtenciónClínica` da origen a la entidad principal `AtenciónClínica` y a la entidad `TransiciónDeAtención` (que registra cada cambio de estado). El agregado es una frontera de consistencia; la entidad es una frontera de almacenamiento.

Este documento describe entidades relacionales, no solo Aggregate Roots. Donde un Aggregate Root genera múltiples entidades, se documenta cada una.

---

## 1. Principios de diseño relacional conceptual

Estos principios rigen todas las decisiones de este documento.

---

**Principio 1 — Una entidad, una responsabilidad**

Cada entidad del modelo relacional tiene exactamente una responsabilidad. Las entidades que mezclan datos de naturaleza distinta (clínica + económica, por ejemplo) deben separarse.

---

**Principio 2 — Los snapshots son ciudadanos de primera clase**

Cuando se crea un registro histórico, los valores mutables que lo afectan (precio, nombre del tipo, datos del paciente en un documento) deben capturarse como atributos propios del registro, no como referencias vivas a las entidades originales. Un cobro que referencia al tipo de atención para obtener su precio actual es un diseño incorrecto.

---

**Principio 3 — Los identificadores técnicos no son claves de negocio**

Toda entidad tiene un identificador técnico generado por el sistema (UUID o equivalente). Ese identificador es la referencia que cruza contextos y tablas. Las claves naturales de negocio (RUT del paciente, nombre del tipo de atención) son restricciones de unicidad adicionales, no la clave primaria.

---

**Principio 4 — La eliminación es un estado, no una operación**

Nada clínico se elimina físicamente. Los registros se archivan, se cierran, se anulan o se desactivan. Las entidades que puedan ser "eliminadas" por el usuario tienen un campo de estado que refleja ese hecho y las excluyen de las vistas operativas, pero el registro persiste.

---

**Principio 5 — La trazabilidad mínima es transversal**

Las cinco acciones del T00 (creación de paciente, registro de atención, cierre de atención, modificación de cita, actualización de historia clínica) generan registros de auditoría de forma atómica con la acción principal. No hay acción clínica crítica sin su rastro.

---

**Principio 6 — Las relaciones entre contextos son por ID opaco**

Cuando una entidad de BC6 referencia a una AtenciónClínica de BC2, lo hace por el identificador técnico de la atención, sin acceso al contenido clínico. El modelo relacional debe respetar esta frontera: las tablas de BC6 no tienen joins directos al contenido clínico de BC2 en operaciones de negocio.

---

**Principio 7 — OrganizaciónClínica es el ancla de todo**

Toda entidad del sistema que no sea BC1 (Identidad) tiene una referencia directa o transitiva a la OrganizaciónClínica propietaria. Esto habilita la multi-tenancy y define la frontera de visibilidad de los datos.

---

## 2. Clasificación de entidades

### 2.1 Por dominio

| Dominio | Entidades |
|---|---|
| **Identity** | OrganizaciónClínica · Profesional |
| **Core Clinical** | Paciente · HistoriaClínica · EntradaClínica · AtenciónClínica · FotografíaClínica |
| **Operational** | Cita · TransiciónDeCita · Seguimiento · IntentoDeContacto |
| **Configuration** | TipoDeAtención · ValorArancel · ZonaDomiciliaria |
| **Economic** | Cobro · TransiciónDePago |
| **Commercial** | RelaciónConCentro · AcuerdoComercial · Liquidación · ÍtemDeLiquidación |
| **Documentary** | Consentimiento · InformeDeSesión |
| **Analytics** | *(sin entidades propias — proyecciones derivadas)* |

---

### 2.2 Por naturaleza

**Entidades históricas** — Inmutables una vez en el estado indicado. Preservadas permanentemente.

| Entidad | Estado que activa la inmutabilidad |
|---|---|
| AtenciónClínica (contenido clínico) | `cerrada` |
| EntradaClínica | Desde su creación |
| TransiciónDeCita | Desde su creación |
| TransiciónDePago | Desde su creación |
| FotografíaClínica (imagen) | Desde su captura |
| Cobro (snapshot económico) | Desde su creación |
| Consentimiento (firma + contenido) | `firmado` |
| InformeDeSesión (contenido) | `generado` |
| AcuerdoComercial (versión vencida) | Cuando un nuevo acuerdo lo reemplaza |
| Liquidación (ítems y montos) | `confirmada` |
| ÍtemDeLiquidación | Cuando la liquidación es `confirmada` |
| IntentoDeContacto | Desde su creación |

---

**Entidades configurables** — Representan la preferencia vigente del profesional. Pueden cambiar. Los cambios no afectan registros históricos.

| Entidad | Lo que puede cambiar |
|---|---|
| TipoDeAtención | Nombre, descripción, estado (activo/inactivo) |
| ValorArancel | El valor vigente (creando una nueva versión) |
| ZonaDomiciliaria | Nombre, descripción, recargo, estado |
| ConfiguraciónOrganización | Preferencias generales, horarios, zona horaria |

---

**Entidades derivadas** — No son tablas en el modelo relacional. Son proyecciones calculadas desde entidades canónicas.

| Proyección | Se deriva de |
|---|---|
| EvoluciónClínica (Fase 1) | AtenciónClínica + EntradaClínica |
| VistaDashboard | Cita + Cobro + Seguimiento + AtenciónClínica |
| ReporteFinanciero | Cobro + Liquidación |
| ReporteAsistencial | AtenciónClínica + Paciente + TipoDeAtención |

---

**Entidades auditables** — Requieren registro de quién realizó qué acción y cuándo.

| Entidad | Nivel de auditoría |
|---|---|
| Paciente | T00: creación |
| AtenciónClínica | T00: registro, cierre |
| EntradaClínica | T00: adición a historia clínica |
| Cita | T00: toda modificación de estado |
| Cobro | Extended: cambios de estado, anulación |
| Consentimiento | Extended: generación, firma, revocación, reemplazo |
| Liquidación | Extended: confirmación |
| AcuerdoComercial | Extended: toda versión nueva |
| Profesional | Base: creación, cambios de estado |
| OrganizaciónClínica | Base: cambios en configuración relevante |

---

## 3. Claves y restricciones de unicidad

### 3.1 Claves técnicas conceptuales

Toda entidad del modelo relacional tiene una **clave técnica**: un identificador generado por el sistema en el momento de la creación. Esta clave:

- Es inmutable desde la creación
- No tiene significado de negocio
- Es el identificador que usan las referencias entre tablas y entre contextos
- No es visible al usuario en la interfaz (el usuario ve el nombre del paciente, no su UUID)
- Debe ser globalmente única dentro del sistema (UUID v4 o equivalente)

---

### 3.2 Claves naturales de negocio

Una clave natural es un identificador que tiene significado en el mundo real, fuera del sistema.

| Entidad | Clave natural | Condiciones |
|---|---|---|
| Profesional | Email | Globalmente único en el sistema |
| Paciente | RUT (identificación nacional) | Único dentro de OrganizaciónClínica; **no obligatorio** — hay pacientes sin RUT (extranjeros, niños) |
| TipoDeAtención | Nombre | Único y activo dentro de OrganizaciónClínica |
| ZonaDomiciliaria | Nombre | Único y activo dentro de OrganizaciónClínica |
| OrganizaciónClínica | RUT de la organización o del profesional | Único en el sistema |

---

### 3.3 Restricciones de unicidad de negocio

Estas restricciones expresan reglas del negocio que el modelo de datos debe garantizar, más allá de la clave técnica.

| Restricción | Entidad | Descripción |
|---|---|---|
| Email único de profesional | Profesional | Un email no puede pertenecer a dos profesionales distintos en el sistema |
| RUT único de paciente por org | Paciente | Si se registra un RUT, debe ser único dentro de la organización (soft: no todos los pacientes tienen RUT) |
| Nombre único de tipo de atención | TipoDeAtención | Dentro de una organización, no pueden existir dos tipos activos con el mismo nombre |
| Nombre único de zona | ZonaDomiciliaria | Dentro de una organización, no pueden existir dos zonas activas con el mismo nombre |
| Una historia clínica por paciente | HistoriaClínica | Un paciente tiene exactamente una historia clínica |
| Un acuerdo vigente por centro | AcuerdoComercial | En un momento dado, solo puede existir un acuerdo con fechas de vigencia sin fecha de fin por relación con centro |
| Una liquidación en borrador por período y centro | Liquidación | No pueden existir dos borradores de liquidación para el mismo centro en el mismo período |
| Citas no superpuestas por profesional | Cita | Un profesional no puede tener dos citas activas con horario superpuesto (restricción de integridad operacional, no de datos, pero debe diseñarse desde el modelo) |

---

## 4. Catálogo de entidades

---

### ENTIDAD: OrganizaciónClínica

**Dominio:** Identity  
**Naturaleza:** Canónica · Auditable  
**Aggregate Root de BC1**

**Propósito**  
Es el contenedor propietario de todos los datos del sistema. Define el límite de tenancy: todos los pacientes, atenciones, cobros, documentos y configuraciones pertenecen a una y solo una organización. En Fase 1, representa la práctica individual de un profesional podólogo.

**Atributos conceptuales**

- Identificación del negocio (nombre legal o comercial, RUT o identificación fiscal)
- Datos de presentación (nombre de fantasía, logotipo referenciado)
- Datos de contacto (teléfono, email de contacto, dirección de atención)
- Configuración operativa: zona horaria, idioma, duración por defecto de las citas, horario de atención estándar
- Estado de la cuenta (activa, suspendida, cerrada)
- Fecha de creación en el sistema

**Relaciones obligatorias**  
Ninguna hacia afuera. Todo lo demás existe en relación a esta entidad.

**Relaciones opcionales**  
Ninguna.

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El RUT o identificación fiscal es inmutable (cambio de RUT implicaría una nueva organización). El nombre y la configuración pueden cambiar.

**Reglas de auditoría**  
Creación. Cambios en configuración operativa relevante (zona horaria, horario de atención).

**Política de eliminación**  
No se elimina. Si la organización cierra, el estado cambia a "cerrada". Los datos se preservan por motivos legales y clínicos.

**Dependencias permitidas**  
Ninguna. BC1 no depende de ningún otro contexto.

**Clave natural**  
RUT u otra identificación fiscal.

---

### ENTIDAD: Profesional

**Dominio:** Identity  
**Naturaleza:** Canónica · Auditable  
**Aggregate Root de BC1**

**Propósito**  
La persona que accede y opera el sistema. Realiza las atenciones clínicas, gestiona la agenda y es el sujeto de la práctica profesional que el producto apoya.

**Atributos conceptuales**

- Nombre completo
- Email (identificador de autenticación)
- Credenciales de acceso (contraseña protegida, estado de la cuenta, mecanismo de recuperación)
- Datos profesionales (especialidad, número de colegiado si aplica)
- Datos de presentación (como aparece en documentos clínicos generados: nombre para firmar consentimientos e informes)
- Referencia a OrganizaciónClínica (membresía)
- Estado de acceso (activo, suspendido, desactivado)
- Fecha de creación en el sistema

**Nota sobre MembresíaOrganización**  
En Fase 1, la membresía es un objeto de valor simple (el profesional pertenece a una organización desde su creación). No tiene ciclo de vida propio. En un escenario SaaS futuro con múltiples organizaciones o invitaciones, la membresía necesitará una entidad propia. El diseño de la tabla de Profesional debe evitar cerrar esa puerta: mantener la referencia a organización como una relación separable, no como columna inline irreemplazable.

**Relaciones obligatorias**  
Pertenece a OrganizaciónClínica.

**Relaciones opcionales**  
Ninguna en Fase 1.

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El email puede corregirse con trazabilidad. Los datos profesionales pueden actualizarse.

**Reglas de auditoría**  
Creación. Cambios de estado de acceso. Cambios de email.

**Política de eliminación**  
No se elimina. Se desactiva el acceso.

**Dependencias permitidas**  
OrganizaciónClínica.

**Clave natural**  
Email (globalmente único en el sistema).

---

### ENTIDAD: Paciente

**Dominio:** Core Clinical  
**Naturaleza:** Canónica · Auditable · T00  
**Aggregate Root de BC2**

**Propósito**  
La persona que recibe atención podológica. Es el sujeto clínico central del sistema. Todo el trabajo clínico gira alrededor de esta entidad.

**Atributos conceptuales**

- Nombre completo
- Identificación (RUT u otro documento; opcional pero preferible)
- Fecha de nacimiento
- Género (cuando relevante clínicamente)
- Datos de contacto: teléfono principal, teléfono alternativo, email
- Dirección (calle, número, ciudad, referencias)
- Origen del paciente (particular / proveniente de centro médico / administrado por tercero)
- Referencia a RelaciónConCentro (si origen es centro; opcional)
- Estado (activo / en seguimiento / inactivo / archivado)
- Notas generales (no clínicas — observaciones de contexto)
- Referencia a OrganizaciónClínica
- Fecha de primer registro en el sistema

**Relaciones obligatorias**  
Pertenece a OrganizaciónClínica. Tiene exactamente una HistoriaClínica (se crea simultáneamente con el paciente).

**Relaciones opcionales**  
Vinculado a RelaciónConCentro (si origen = centro médico).

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El nombre y RUT son canónicos: los cambios deben quedar trazados (no sobrescribir silenciosamente). Los datos de contacto y dirección son mutables.

**Reglas de auditoría**  
T00: creación (quién y cuándo). Modificaciones de nombre o identificación (quién, cuándo, valor anterior).

**Política de eliminación**  
Archivado exclusivamente. Estado cambia a "archivado". El registro persiste para siempre. Los datos de contacto pueden ser anonimizados en casos de solicitud de olvido (sujeto a consideraciones legales en Chile), pero el identificador técnico y los registros clínicos asociados se mantienen.

**Dependencias permitidas**  
OrganizaciónClínica. RelaciónConCentro (cuando origen = centro).

**Clave natural**  
RUT + OrganizaciónClínica (cuando RUT disponible; no obligatorio).

**Restricción de unicidad**  
[RUT, organización] único cuando RUT está presente (soft constraint: no bloqueante si no hay RUT).

---

### ENTIDAD: HistoriaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica + Histórica · Auditable · T00  
**Entidad contenida en el Aggregate Root Paciente — tabla propia en el modelo relacional**

**Propósito**  
El perfil clínico permanente del paciente. Contiene todo lo que el profesional sabe sobre la salud del paciente antes de cada atención. Es la memoria clínica de largo plazo.

**Atributos conceptuales**

- Referencia al Paciente (1:1 obligatoria)
- Resumen general de salud (campo libre de largo plazo)
- Referencia a OrganizaciónClínica
- Fecha de creación (igual a la del Paciente)

**Nota:** La historia clínica como entidad es principalmente un contenedor. Su contenido real vive en las EntradaClínica individuales.

**Relaciones obligatorias**  
Pertenece exactamente a un Paciente. Pertenece a OrganizaciónClínica.

**Relaciones opcionales**  
Ninguna.

**Reglas de inmutabilidad**  
La historia clínica no se puede cerrar, eliminar ni modificar como entidad. Su contenido crece por adición (nuevas EntradaClínica), nunca por eliminación o modificación de entradas existentes.

**Reglas de auditoría**  
T00: toda adición de EntradaClínica (quién y cuándo).

**Política de eliminación**  
Nunca. Se archiva con el Paciente.

**Restricción de unicidad**  
Existe exactamente una HistoriaClínica por Paciente.

---

### ENTIDAD: EntradaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Histórica · Auditable · T00  
**Objeto de valor en HistoriaClínica — tabla propia en el modelo relacional**

**Propósito**  
Registro individual de un hecho clínico de largo plazo del paciente: una patología, un medicamento en uso, una alergia o una observación relevante para todas las atenciones futuras.

**Atributos conceptuales**

- Referencia a HistoriaClínica
- Tipo de entrada (patología / medicamento / alergia / observación / otro)
- Descripción del hecho clínico (texto libre)
- Estado de la entrada (activo / resuelto / inactivo)
- Fecha de registro
- Referencia al Profesional que la registró
- Notas adicionales (aclaraciones posteriores, no modificaciones)

**Relaciones obligatorias**  
Pertenece a HistoriaClínica. Registrada por Profesional.

**Reglas de inmutabilidad**  
Una EntradaClínica registrada no puede modificarse ni eliminarse. Solo puede cambiar su estado (de "activo" a "resuelto" o "inactivo"). Cualquier corrección se hace agregando una nueva entrada o añadiendo una nota a la existente, nunca sobreescribiendo.

**Reglas de auditoría**  
T00: creación (quién y cuándo). Cambios de estado (quién y cuándo).

**Política de eliminación**  
Nunca. El estado "inactivo" o "resuelto" es la forma de retirar una entrada del flujo activo sin borrarla.

---

### ENTIDAD: AtenciónClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica (abierta) + Histórica (cerrada) · Auditable · T00  
**Aggregate Root de BC2**

**Propósito**  
El registro canónico e inmutable de lo que ocurrió en una sesión clínica. Es el corazón del trabajo clínico del sistema. Una vez cerrada, es la verdad definitiva sobre esa sesión.

**Atributos conceptuales**

*Metadatos de la atención:*
- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Fecha y hora de inicio
- Fecha y hora de cierre (cuando aplica)
- Estado (registrada / cerrada)
- Modalidad (particular / centro médico / domiciliaria)

*Referencia al tipo de atención:*
- Referencia técnica a TipoDeAtención (ID opaco)
- Snapshot: nombre del tipo al momento del registro (capturado al crear/cerrar la atención)

*Contenido clínico (inmutable desde cierre):*
- Tratamiento realizado (descripción del procedimiento ejecutado)
- Hallazgos clínicos (observaciones del estado del paciente)
- Notas clínicas (comentarios del profesional)
- Indicaciones al paciente (instrucciones post-atención)

*Referencias opcionales:*
- Referencia a Cita que originó esta atención (opcional)
- Referencia a ZonaDomiciliaria si modalidad = domiciliaria (opcional)
- Referencia a RelaciónConCentro si modalidad = centro médico (opcional)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
Cita · ZonaDomiciliaria · RelaciónConCentro.

**Reglas de inmutabilidad**  
Una vez estado = "cerrada":
- El contenido clínico (tratamiento, hallazgos, notas, indicaciones) es inmutable
- La fecha y hora de cierre son inmutables
- El Profesional que cerró es inmutable
- El snapshot del nombre del tipo de atención es inmutable

Lo que puede ocurrir después del cierre: adición de anotaciones posteriores (notas de seguimiento), que son registros nuevos asociados, no modificaciones al contenido original.

**Reglas de auditoría**  
T00: creación del registro (quién, cuándo). T00: cierre de la atención (quién, cuándo). Cualquier modificación mientras está en estado "registrada".

**Política de eliminación**  
Nunca, una vez que existe como registro. Un borrador no cerrado con contenido puede tener una vía de cancelación explícita (estado "cancelada"), pero el registro persiste.

**Dependencias permitidas**  
Paciente · Profesional · OrganizaciónClínica · TipoDeAtención (lectura) · Cita (opcional) · ZonaDomiciliaria (opcional) · RelaciónConCentro (opcional).

---

### ENTIDAD: FotografíaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica + Histórica · Auditable  
**Aggregate Root de BC2**

**Propósito**  
Evidencia visual permanente del estado clínico del paciente. Permite la comparación longitudinal del estado de las lesiones o condiciones tratadas.

**Atributos conceptuales**

- Referencia al Paciente
- Referencia a OrganizaciónClínica
- Referencia al Profesional que la capturó
- Fecha y hora de captura
- Descripción del contenido (qué muestra la fotografía: pie derecho, lesión onicocriptosis, etc.)
- Contexto clínico (perfil del paciente / asociada a atención específica)
- Referencia a AtenciónClínica (opcional — cuando está vinculada a una sesión)
- Estado (activa / archivada)
- Referencia al archivo de imagen almacenado (referencia técnica al objeto de almacenamiento, no la imagen en sí)

**Relaciones obligatorias**  
Paciente · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica.

**Reglas de inmutabilidad**  
El archivo de imagen es inmutable desde su captura: el objeto de almacenamiento no puede ser reemplazado ni modificado. Los metadatos (descripción, contexto, asociación a atención) pueden corregirse con trazabilidad.

**Reglas de auditoría**  
Creación (quién, cuándo). Cambios en la asociación a AtenciónClínica.

**Política de eliminación**  
Archivado exclusivamente. La imagen y sus metadatos persisten. El estado "archivada" la retira del flujo activo.

---

### ENTIDAD: Cita

**Dominio:** Operational  
**Naturaleza:** Canónica (futura) + Histórica (pasada) · Auditable · T00  
**Aggregate Root de BC3**

**Propósito**  
Un bloque de tiempo programado para una atención clínica. Organiza el día de trabajo del profesional y formaliza el compromiso con el paciente.

**Atributos conceptuales**

- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Fecha y hora de inicio
- Duración estimada
- Referencia a TipoDeAtención prevista (opcional — puede no estar definido al agendar)
- Snapshot del nombre del tipo de atención prevista (cuando está definido)
- Estado (agendada / confirmada / atendida / cancelada / inasistida / reprogramada)
- Notas del profesional (contexto de la cita)
- Motivo de cancelación o inasistencia (cuando aplica)
- Referencia a la cita anterior si es reprogramación (opcional)
- Referencia a Seguimiento que generó esta cita (opcional)
- Referencia a AtenciónClínica resultante (opcional — vincula cuando la cita resulta en atención)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
TipoDeAtención prevista · AtenciónClínica resultante · Cita previa (si reprogramación) · Seguimiento que la originó.

**Reglas de inmutabilidad**  
Una cita con estado "atendida", "cancelada" o "inasistida" es histórica. El estado, la fecha y hora originales, y el Paciente asociado son inmutables desde ese punto.

**Reglas de auditoría**  
T00: toda modificación de estado (quién, cuándo, estado anterior, estado nuevo). Especialmente reprogramaciones y cancelaciones.

**Política de eliminación**  
No se elimina. Una cita errónea se cancela con motivo. La historial de estados persiste.

---

### ENTIDAD: TransiciónDeCita

**Dominio:** Operational  
**Naturaleza:** Histórica (log inmutable)  
**Objeto de valor en Cita — tabla propia en el modelo relacional**

**Propósito**  
Registro completo e inmutable de cada cambio de estado de una cita. Permite auditar el historial operativo y reconstruir la secuencia de decisiones sobre una cita.

**Atributos conceptuales**

- Referencia a Cita
- Estado anterior
- Estado nuevo
- Referencia al Profesional que realizó el cambio
- Fecha y hora del cambio
- Motivo o notas del cambio

**Reglas de inmutabilidad**  
Cada registro es inmutable desde su creación. Es un log append-only.

---

### ENTIDAD: Seguimiento

**Dominio:** Operational  
**Naturaleza:** Canónica (activo) + Histórica (cerrado) · Auditable  
**Aggregate Root de BC4**

**Propósito**  
Registro de la necesidad de mantener contacto con el paciente para asegurar la continuidad de su cuidado entre atenciones.

**Atributos conceptuales**

- Referencia al Paciente
- Referencia al Profesional responsable
- Referencia a OrganizaciónClínica
- Tipo de seguimiento (control rutinario / seguimiento por condición específica / recordatorio de retorno / otro)
- Nivel de urgencia (normal / prioritario / urgente)
- Estado (pendiente / contactado / agendado / completado / vencido / descartado)
- Origen del seguimiento (manual / automático desde cierre de atención)
- Referencia a AtenciónClínica que lo originó (ID opaco, opcional)
- Referencia a Cita resultante (opcional)
- Notas del profesional
- Fecha de creación
- Fecha límite de contacto (cuando aplica)
- Fecha de resolución (cuando cerrado)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica origen (ID opaco) · Cita resultante.

**Reglas de inmutabilidad**  
Un seguimiento completado o descartado es histórico. La fecha de creación, el origen y el paciente asociado son inmutables desde la creación.

**Reglas de auditoría**  
Cambios de estado significativos (contactado, agendado, completado, descartado).

**Política de eliminación**  
No se elimina. Cierre mediante cambio de estado a "completado" o "descartado".

---

### ENTIDAD: IntentoDeContacto

**Dominio:** Operational  
**Naturaleza:** Histórica (log inmutable)  
**Objeto de valor en Seguimiento — tabla propia en el modelo relacional**

**Propósito**  
Registro de cada intento del profesional de contactar al paciente durante el proceso de seguimiento.

**Atributos conceptuales**

- Referencia a Seguimiento
- Canal del intento (teléfono / WhatsApp / email / presencial / otro)
- Resultado del intento (no contestó / contactado sin éxito / contactado y agendado / otro)
- Notas del profesional
- Fecha y hora del intento

**Reglas de inmutabilidad**  
Inmutable desde su creación.

---

### ENTIDAD: TipoDeAtención

**Dominio:** Configuration (Shared Kernel BC5)  
**Naturaleza:** Configurable · Auditable (cambios)  
**Aggregate Root de BC5**

**Propósito**  
Catálogo de tipos de atención disponibles en la organización. Es la referencia compartida que usan tanto el contexto Clínico (para registrar qué se hizo) como el contexto Económico (para saber qué valor aplicar).

**Atributos conceptuales**

- Nombre del tipo de atención (ej: "Podología Normal", "Onicocriptosis", "Pie Diabético")
- Descripción clínica (qué procedimientos incluye)
- Estado (activo / inactivo)
- Referencia a OrganizaciónClínica
- Fecha de creación

**Regla de Shared Kernel:** Cuando BC2 o BC6 referencian a un TipoDeAtención, capturan el nombre como snapshot en el mismo momento. Los registros históricos nunca consultan el nombre actual: usan el snapshot capturado.

**Relaciones obligatorias**  
OrganizaciónClínica.

**Reglas de inmutabilidad**  
El nombre puede cambiar, pero los snapshots ya capturados en atenciones y cobros son inmutables. El identificador técnico es inmutable.

**Reglas de auditoría**  
Cambios de nombre (para comprender cobros históricos con nombre diferente). Cambios de estado.

**Política de eliminación**  
No se elimina si existen referencias en atenciones o cobros. Se desactiva (estado = "inactivo"). Un tipo inactivo no aparece en el catálogo de nuevas atenciones pero sigue siendo referenciable en registros históricos.

**Restricción de unicidad**  
[nombre, organización] único entre tipos activos.

---

### ENTIDAD: ValorArancel

**Dominio:** Configuration (BC5)  
**Naturaleza:** Configurable + Histórica (versiones vencidas)  
**Objeto de valor en TipoDeAtención — tabla propia en el modelo relacional**

**Propósito**  
Precio asociado a un tipo de atención para un contexto dado. Permite al profesional mantener un arancel actualizado sin afectar cobros ya registrados.

**Atributos conceptuales**

- Referencia a TipoDeAtención
- Modalidad de aplicación (particular / domiciliaria — Fase 1; centros en Fase 2+)
- Valor (precio)
- Fecha de inicio de vigencia
- Fecha de fin de vigencia (nulo si es el valor vigente actualmente)
- Referencia al Profesional que lo configuró

**Versionado:** Cuando el profesional cambia el precio de un tipo de atención, el registro anterior recibe una fecha de fin de vigencia y se crea un nuevo registro con la nueva fecha de inicio. El cobro nuevo usará el nuevo valor; los cobros anteriores mantienen sus snapshots.

**Reglas de inmutabilidad**  
Un registro con fecha de fin de vigencia es histórico e inmutable. Solo el registro vigente (sin fecha de fin) puede ser "reemplazado" por uno nuevo.

---

### ENTIDAD: ZonaDomiciliaria

**Dominio:** Configuration (BC5)  
**Naturaleza:** Configurable · Auditable (cambios de recargo)  
**Aggregate Root de BC5**

**Propósito**  
Área geográfica definida manualmente por el profesional para aplicar un recargo de traslado en atenciones domiciliarias.

**Atributos conceptuales**

- Nombre de la zona (ej: "Zona Norte", "Sector Centro", "Periferia")
- Descripción geográfica en texto libre (sin GPS ni mapas — descripción manual de límites)
- Recargo asociado (valor adicional por traslado a esta zona)
- Estado (activa / inactiva)
- Referencia a OrganizaciónClínica
- Fecha de creación

**Relaciones obligatorias**  
OrganizaciónClínica.

**Reglas de inmutabilidad**  
El recargo puede cambiar. Los cobros ya registrados capturan el recargo como snapshot: no cambian cuando la zona cambia.

**Reglas de auditoría**  
Cambios en el valor del recargo (para entender cobros históricos con recargo diferente al actual).

**Política de eliminación**  
No se elimina si existen cobros asociados. Se desactiva.

**Restricción de unicidad**  
[nombre, organización] único entre zonas activas.

---

### ENTIDAD: Cobro

**Dominio:** Economic  
**Naturaleza:** Histórica (snapshot económico) · Canónica (estado de pago) · Auditable  
**Aggregate Root de BC6**

**Propósito**  
El registro canónico del hecho económico del trabajo clínico. Captura en forma permanente e inmutable cuánto se cobró, por qué concepto y en qué estado se encuentra el pago.

**Atributos conceptuales**

*Snapshot económico (inmutable desde creación):*
- Monto capturado al momento del registro (no referencia viva al arancel)
- Nombre/descripción del tipo de atención al momento del registro (snapshot — no referencia viva)
- Modalidad del cobro (particular / domiciliaria / centro médico)
- Snapshot del recargo de zona si modalidad = domiciliaria (opcional)
- Snapshot del valor acordado con el centro si modalidad = centro médico (opcional)
- Concepto del cobro (descripción libre del trabajo que lo origina)

*Metadatos del cobro:*
- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Fecha de registro
- Referencia a AtenciónClínica (ID opaco, opcional)
- Referencia a ZonaDomiciliaria (ID, opcional — el recargo ya está en snapshot)
- Referencia a RelaciónConCentro (ID, opcional — el valor acordado ya está en snapshot)

*Estado del pago (mutable):*
- Estado actual (pendiente / pagado_parcial / pagado / anulado)
- Medio de pago registrado (efectivo / transferencia / tarjeta / otro)
- Fecha de pago (cuando aplica)
- Motivo de anulación (cuando aplica)
- Referencia a Liquidación (cuando ha sido liquidado con un centro, opcional)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica (ID opaco) · ZonaDomiciliaria (ID) · RelaciónConCentro (ID) · Liquidación.

**Reglas de inmutabilidad**  
El snapshot económico (monto, tipo descripción, recargos capturados) es inmutable desde la creación del registro. El estado del pago es mutable.

**Reglas de auditoría**  
Todo cambio de estado del pago (quién, cuándo, estado anterior, estado nuevo). Anulaciones especialmente.

**Política de eliminación**  
Nunca. La anulación es la forma de invalidar un cobro: el estado cambia a "anulado" con motivo y trazabilidad. El registro persiste.

---

### ENTIDAD: TransiciónDePago

**Dominio:** Economic  
**Naturaleza:** Histórica (log inmutable)  
**Objeto de valor en Cobro — tabla propia en el modelo relacional**

**Propósito**  
Log inmutable de cada cambio de estado del cobro. Permite auditar el ciclo de vida económico de cada registro.

**Atributos conceptuales**

- Referencia a Cobro
- Estado anterior
- Estado nuevo
- Referencia al Profesional que realizó el cambio
- Fecha y hora del cambio
- Notas o motivo

**Reglas de inmutabilidad**  
Inmutable desde su creación.

---

### ENTIDAD: RelaciónConCentro

**Dominio:** Commercial  
**Naturaleza:** Canónica (identidad) + Configurable (acuerdo) · Auditable  
**Aggregate Root de BC7**

**Propósito**  
El vínculo de la organización con un centro médico externo. No representa al centro en sí, sino la relación comercial y operativa. Un cambio en los términos del acuerdo no destruye la relación: la versiona.

**Atributos conceptuales**

- Nombre del centro médico externo
- Datos de contacto del centro (dirección, teléfono, contacto)
- Modalidad de la relación (el profesional atiende en el centro / el centro deriva pacientes / ambas)
- Estado del vínculo (activo / inactivo)
- Referencia a OrganizaciónClínica
- Fecha de inicio del vínculo

**Relaciones obligatorias**  
OrganizaciónClínica. Al menos un AcuerdoComercial vigente desde la creación.

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El nombre del centro puede corregirse. El historial de acuerdos es inmutable.

**Reglas de auditoría**  
Creación del vínculo. Cambios en los términos del acuerdo (genera evento `AcuerdoCentroVersionado`). Desactivación del vínculo.

**Política de eliminación**  
No se elimina si existen Cobros o Liquidaciones asociadas. Se desactiva el vínculo.

---

### ENTIDAD: AcuerdoComercial

**Dominio:** Commercial  
**Naturaleza:** Configurable (vigente) + Histórica (vencido) · Auditable  
**Entidad contenida en RelaciónConCentro — tabla propia en el modelo relacional**

**Propósito**  
Una versión específica y con vigencia temporal de los términos comerciales de la relación con el centro. Permite cambiar condiciones sin perder el historial.

**Atributos conceptuales**

- Referencia a RelaciónConCentro
- Tipo de acuerdo (porcentaje de comisión / valor fijo por atención / valor fijo mensual)
- Parámetros del acuerdo (porcentaje o valor según tipo)
- Observaciones (condiciones especiales, excepciones)
- Fecha de inicio de vigencia
- Fecha de fin de vigencia (nulo si es el acuerdo vigente)
- Referencia al Profesional que registró la versión

**Reglas de inmutabilidad**  
Un acuerdo con fecha de fin de vigencia es histórico e inmutable. Solo el acuerdo vigente (sin fecha de fin) puede ser "reemplazado" creando uno nuevo y cerrando el anterior.

**Reglas de auditoría**  
Toda creación de nueva versión del acuerdo.

**Restricción de unicidad**  
Solo puede existir un AcuerdoComercial sin fecha de fin por RelaciónConCentro en un momento dado.

---

### ENTIDAD: Liquidación

**Dominio:** Commercial  
**Naturaleza:** Derivada (borrador) + Histórica (confirmada) · Auditable  
**Aggregate Root de BC7**

**Propósito**  
Resumen económico del trabajo realizado en un centro médico durante un período específico. Una vez confirmada, es el registro legal del cierre económico con ese centro.

**Atributos conceptuales**

- Referencia a RelaciónConCentro
- Referencia a OrganizaciónClínica
- Período cubierto (fecha de inicio y fin)
- Referencia al AcuerdoComercial aplicado (snapshot de términos vigentes al cierre)
- Monto total calculado
- Estado (borrador / confirmada / pagada)
- Fecha de confirmación (cuando aplica)
- Notas del período
- Referencia al Profesional que confirmó

**Relaciones obligatorias**  
RelaciónConCentro · OrganizaciónClínica.

**Reglas de inmutabilidad**  
El monto total y los ítems incluidos son inmutables una vez estado = "confirmada". La referencia al acuerdo aplicado es inmutable desde la confirmación.

**Reglas de auditoría**  
Confirmación (quién, cuándo). Cambios de estado.

**Política de eliminación**  
Borradores pueden cancelarse. Liquidaciones confirmadas son históricas: no se eliminan.

**Restricción de unicidad**  
[RelaciónConCentro, período] debe tener a lo sumo una liquidación en estado "borrador". Pueden existir múltiples liquidaciones confirmadas de distintos períodos para el mismo centro.

---

### ENTIDAD: ÍtemDeLiquidación

**Dominio:** Commercial  
**Naturaleza:** Histórica (una vez liquidación confirmada)  
**Entidad contenida en Liquidación — tabla propia en el modelo relacional**

**Propósito**  
Cada hecho económico incluido en una liquidación. Registra los cobros del período que corresponden al centro y que forman la base del cálculo.

**Atributos conceptuales**

- Referencia a Liquidación
- Referencia al Cobro de BC6 (ID del cobro — referencia opaca)
- Monto del cobro al momento de la inclusión (snapshot)
- Tipo de atención (snapshot del nombre — no referencia viva a BC2)
- Fecha del hecho económico
- Modalidad

**Reglas de inmutabilidad**  
Inmutables una vez la liquidación está confirmada.

**Nota crítica:** El ÍtemDeLiquidación no accede al contenido clínico de la atención que originó el cobro. Solo conoce datos económicos del Cobro. Esta frontera garantiza que BC7 no depende de BC2.

---

### ENTIDAD: Consentimiento

**Dominio:** Documentary  
**Naturaleza:** Histórica (firmado) · Auditable  
**Aggregate Root de BC8**

**Propósito**  
Documento clínico-legal que acredita que el paciente conoce y acepta el tratamiento. Es el documento de mayor criticidad legal del sistema.

**Atributos conceptuales**

*Snapshots capturados al momento de generación (inmutables):*
- Datos del paciente al momento (nombre, identificación)
- Datos del profesional al momento (nombre, datos de presentación)
- Versión de la plantilla utilizada (identificador de versión + contenido de la plantilla capturado)
- Contenido del documento generado

*Firma:*
- Estado de la firma del paciente (pendiente / firmado / no aplica)
- Datos de la firma del paciente (imagen de firma o confirmación, fecha y hora)
- Estado de la firma del profesional (pendiente / firmado)
- Datos de la firma del profesional (imagen de firma o confirmación, fecha y hora)

*Estado documental:*
- Estado (borrador / generado / firmado / revocado / reemplazado)
- Fecha de generación formal
- Motivo de revocación (cuando aplica)
- Referencia al Consentimiento que lo reemplaza (cuando aplica)
- Referencia al Consentimiento que este reemplaza (cuando aplica)

*Metadatos:*
- Referencia al Paciente (ID + snapshot de datos)
- Referencia al Profesional (ID + snapshot de datos)
- Referencia a OrganizaciónClínica
- Referencia a AtenciónClínica (ID, opcional)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica (ID) · Consentimiento previo (si reemplaza).

**Reglas de inmutabilidad**  
El contenido del documento, los datos de firma y la fecha de firma son inmutables una vez estado = "firmado". La revocación y el reemplazo son eventos que cambian el estado del consentimiento pero no modifican el contenido original.

**Reglas de auditoría**  
Generación formal. Firma del paciente. Firma del profesional. Revocación. Reemplazo.

**Política de eliminación**  
Nunca. Revocación o reemplazo con trazabilidad completa.

---

### ENTIDAD: InformeDeSesión

**Dominio:** Documentary  
**Naturaleza:** Derivada (borrador) + Histórica (generado) · Auditable  
**Aggregate Root de BC8**

**Propósito**  
Reporte del trabajo realizado en una sesión clínica, para entrega al paciente. Una vez generado formalmente, es un documento histórico inmutable que representa lo que se comunicó.

**Atributos conceptuales**

*Snapshot capturado al momento de generación (inmutable desde estado "generado"):*
- Datos del paciente al momento
- Datos del profesional al momento
- Datos clínicos de la atención (tratamiento realizado, indicaciones — extraídos de AtenciónClínica al momento de generación)
- Fecha y hora de la atención

*Estado documental:*
- Estado (borrador / generado / entregado)
- Fecha de generación formal
- Canal de entrega (impresión / correo / otro)
- Fecha de entrega (cuando aplica)

*Metadatos:*
- Referencia al Paciente (ID + snapshot)
- Referencia al Profesional (ID + snapshot)
- Referencia a AtenciónClínica (ID — el snapshot del contenido se captura al generar)
- Referencia a OrganizaciónClínica

**Relaciones obligatorias**  
AtenciónClínica (ID) · Paciente · Profesional · OrganizaciónClínica.

**Reglas de inmutabilidad**  
El snapshot del contenido clínico es inmutable una vez estado = "generado". El canal y fecha de entrega son mutables hasta el cierre.

**Reglas de auditoría**  
Generación (quién, cuándo). Entrega (canal, cuándo).

**Política de eliminación**  
Un borrador puede descartarse. Un informe generado o entregado es histórico: no se elimina.

---

## 5. Mapa de dependencias entre entidades

Este mapa muestra qué entidades deben existir antes de poder crear otra. Es la base del orden de construcción en el modelo relacional.

```
OrganizaciónClínica
│
└── Profesional
    │
    ├── TipoDeAtención ──► ValorArancel
    │
    ├── ZonaDomiciliaria
    │
    └── Paciente
        └── HistoriaClínica
            └── EntradaClínica

AtenciónClínica
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: Cita · ZonaDomiciliaria · RelaciónConCentro

Cita
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: TipoDeAtención · Seguimiento · Cita previa

Seguimiento
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: AtenciónClínica · Cita

Cobro
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: AtenciónClínica · ZonaDomiciliaria · RelaciónConCentro

RelaciónConCentro
├── requiere: OrganizaciónClínica
└── contiene: AcuerdoComercial (al menos uno)

Liquidación
├── requiere: RelaciónConCentro · OrganizaciónClínica
└── contiene: ÍtemDeLiquidación (que referencia Cobro)

Consentimiento
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: AtenciónClínica

InformeDeSesión
└── requiere: AtenciónClínica · Paciente · Profesional · OrganizaciónClínica

FotografíaClínica
├── requiere: Paciente · OrganizaciónClínica
└── referencia opcional: AtenciónClínica

TransiciónDeCita      → requiere: Cita
IntentoDeContacto     → requiere: Seguimiento
TransiciónDePago      → requiere: Cobro
ÍtemDeLiquidación     → requiere: Liquidación · Cobro (ID opaco)
```

---

## 6. Vista consolidada: Entidades por fase de construcción

Este orden respeta las dependencias y prioridades del plan de fases del producto.

---

**Fase 1 — Utilizable (MVP clínico)**

| Entidad | Dominio | Razón |
|---|---|---|
| OrganizaciónClínica | Identity | Base de todo |
| Profesional | Identity | Acceso al sistema |
| TipoDeAtención | Configuration | Catálogo mínimo requerido |
| ValorArancel | Configuration | Necesario para Cobro básico |
| Paciente | Core Clinical | Núcleo clínico |
| HistoriaClínica | Core Clinical | Con Paciente, simultáneo |
| EntradaClínica | Core Clinical | Contenido de la historia |
| AtenciónClínica | Core Clinical | Núcleo clínico |
| Cita | Operational | Agenda diaria |
| TransiciónDeCita | Operational | T00 auditoría |
| Seguimiento | Operational | Continuidad post-atención |
| Cobro | Economic | Registro económico básico |
| TransiciónDePago | Economic | Auditoría de pagos |

---

**Fase 2 — Completo para práctica individual**

| Entidad | Dominio | Razón |
|---|---|---|
| ZonaDomiciliaria | Configuration | Precios diferenciados por zona |
| FotografíaClínica | Core Clinical | Evidencia visual clínica |
| IntentoDeContacto | Operational | Seguimiento enriquecido |
| Consentimiento | Documentary | Documentos clínico-legales |
| InformeDeSesión | Documentary | Reportes de sesión |
| RelaciónConCentro | Commercial | Centros médicos |
| AcuerdoComercial | Commercial | Términos con centros |

---

**Fase 3 — Centro multi-profesional**

| Entidad | Dominio | Razón |
|---|---|---|
| Liquidación | Commercial | Cierre económico con centros |
| ÍtemDeLiquidación | Commercial | Detalle de la liquidación |
| *(TablaAuditoría)* | Transversal | M21 Auditoría Operacional completa |

---

## 7. Resumen: Entidades por clasificación cruzada

```
Por dominio
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Identity (2):         OrganizaciónClínica · Profesional
Core Clinical (5):    Paciente · HistoriaClínica · EntradaClínica
                      AtenciónClínica · FotografíaClínica
Operational (4):      Cita · TransiciónDeCita
                      Seguimiento · IntentoDeContacto
Configuration (3):    TipoDeAtención · ValorArancel · ZonaDomiciliaria
Economic (2):         Cobro · TransiciónDePago
Commercial (4):       RelaciónConCentro · AcuerdoComercial
                      Liquidación · ÍtemDeLiquidación
Documentary (2):      Consentimiento · InformeDeSesión
Analytics (0):        proyecciones derivadas, sin entidades propias

Total: 22 entidades relacionales

Por naturaleza
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Históricas (12):
  EntradaClínica · TransiciónDeCita · TransiciónDePago
  AtenciónClínica (cerrada) · FotografíaClínica (imagen)
  Cobro (snapshot) · Consentimiento (firmado)
  InformeDeSesión (generado) · AcuerdoComercial (vencido)
  Liquidación (confirmada) · ÍtemDeLiquidación (confirmada)
  IntentoDeContacto

Configurables (4):
  TipoDeAtención · ValorArancel · ZonaDomiciliaria
  ConfiguraciónOrganización

Derivadas (sin tabla propia) (4):
  EvoluciónClínica · VistaDashboard
  ReporteFinanciero · ReporteAsistencial

Auditables T00 (5):
  Paciente (creación) · AtenciónClínica (registro/cierre)
  EntradaClínica (adición) · Cita (modificación de estado)
  + HistoriaClínica (cobertura transitiva a través de EntradaClínica)
```

---

*Este documento es la Base Canónica del modelo relacional de Agenda Podológica. No especifica tablas ni columnas: especifica qué existe, para qué sirve y qué reglas lo rigen. Toda decisión de implementación en Supabase, migraciones, políticas y RPCs debe poder rastrear su origen a este documento o justificar explícitamente la desviación.*
