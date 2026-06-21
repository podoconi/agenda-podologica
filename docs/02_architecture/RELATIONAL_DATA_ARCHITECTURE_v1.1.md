# Arquitectura de Datos Relacional Conceptual — Agenda Podológica

**Versión:** 1.1  
**Estado:** Revisado — incorpora observaciones de QA_RELATIONAL_DATA_ARCHITECTURE_v1.md  
**Fecha original:** Junio 2026  
**Fecha de revisión:** Junio 2026  
**Autor:** Roberto Rojas  
**Revisor QA:** Codex (OpenAI)  
**Fuentes:** RELATIONAL_DATA_ARCHITECTURE_v1.md · QA_RELATIONAL_DATA_ARCHITECTURE_v1.md · DATA_MODEL_CONCEPTUAL_v1.1.md · CANONICAL_DATA_FOUNDATION_PODOLOGIA.md · ARQUITECTURA_CONCEPTUAL_v1.1.md

---

## Cambios en esta versión

Esta versión corrige los bloqueos críticos y observaciones medias identificados por `QA_RELATIONAL_DATA_ARCHITECTURE_v1.md`. La estructura general del documento se conserva. Los cambios son de precisión, corrección de fases e incorporación de entidades omitidas.

- **T00 desde Fase 1 resuelto**: se agrega `EventoAuditoríaMínima` como entidad transversal de Fase 1. Cubre los 5 eventos mínimos de trazabilidad. M21 Auditoría Operacional en Fase 3 es el módulo consultable avanzado sobre estos datos; no es el inicio del almacenamiento.
- **TransiciónDeAtención incorporada**: se agrega formalmente al catálogo como entidad histórica para registrar cambios de estado de `AtenciónClínica`. Es Fase 1 y forma parte de T00. El total de entidades pasa de 22 a 24.
- **Circularidad BC6/BC7 eliminada**: `Cobro` ya no tiene referencia estructural a `Liquidación`. La relación fluye únicamente desde `Liquidación → ÍtemDeLiquidación → Cobro`. Si se necesita saber si un cobro fue liquidado, ese dato es una proyección derivada desde BC7, no un campo autoritativo de BC6.
- **Fases corregidas**: `Liquidación` e `ÍtemDeLiquidación` se mueven a Fase 2 (coherente con M13 Liquidaciones en `ARQUITECTURA_CONCEPTUAL_v1.1.md`). `EventoAuditoríaMínima` y `TransiciónDeAtención` se incorporan a Fase 1.
- **ConfiguraciónOrganización resuelta**: se clarifica que no es una entidad separada; sus atributos son parte de `OrganizaciónClínica`. Se retira de la lista de entidades configurables.
- **ValorArancel faseado**: Fase 1 cubre exclusivamente el valor base para atención particular. Modalidades domiciliarias y centros son Fase 2.
- **Paciente faseado respecto de BC7**: en Fase 1, el origen del paciente existe como categoría; la referencia estructural a `RelaciónConCentro` es Fase 2.
- **Restricciones de unicidad completadas**: se agregan reglas para vigencias de arancel, solapamiento de acuerdos, duplicidad de ítems de liquidación, unicidad de liquidación confirmada por período y centro, y relación uno a uno entre consentimiento reemplazado y reemplazante.
- **Política de eliminación uniformada**: "descartar" siempre significa cambio de estado; eliminación física es una excepción gobernada, no parte del flujo normal.
- **Lenguaje técnico suavizado**: se retiran o neutralizan menciones a identificadores técnicos específicos, referencias a tecnologías de implementación, terminología de capas de base de datos y lenguaje de diseño de esquemas.

---

## Propósito de este documento

Este documento transforma el Modelo Conceptual de Datos (Bounded Contexts, Aggregate Roots, Domain Events) en una Arquitectura de Datos Relacional Conceptual: el mapa de entidades, sus atributos conceptuales, sus relaciones, sus reglas de integridad y sus restricciones de negocio.

No contiene SQL. No contiene migraciones. No especifica tecnologías de implementación. No define tipos de datos. No produce código. Es el documento que debe existir antes de diseñar el schema de base de datos, sus políticas de acceso y sus operaciones transaccionales.

Este documento es la **Base Canónica** de la que se derivarán en fases posteriores el diseño de schema, las migraciones, las políticas de control de acceso y las operaciones de base de datos.

Toda decisión de implementación futura debe poder justificarse contra este documento o debe provocar una revisión explícita del mismo.

---

## Nota sobre la transición de DDD a relacional

En el Modelo Conceptual de Datos, la unidad de organización es el **Aggregate Root** — una entidad que protege la consistencia de un grupo de conceptos relacionados. En el modelo relacional, la unidad es la **entidad** — que generalmente corresponde a una unidad de almacenamiento persistente.

La transición introduce la siguiente distinción: un Aggregate Root puede dar origen a **varias entidades relacionadas** en el modelo relacional. Por ejemplo, el Aggregate Root `AtenciónClínica` da origen a la entidad principal `AtenciónClínica` y a la entidad `TransiciónDeAtención` (que registra cada cambio de estado). El agregado es una frontera de consistencia; la entidad es una frontera de almacenamiento.

Este documento describe entidades relacionales, no solo Aggregate Roots. Donde un Aggregate Root genera múltiples entidades, se documenta cada una.

---

## 1. Principios de diseño relacional conceptual

---

**Principio 1 — Una entidad, una responsabilidad**

Cada entidad del modelo relacional tiene exactamente una responsabilidad. Las entidades que mezclan datos de naturaleza distinta deben separarse.

---

**Principio 2 — Los snapshots son ciudadanos de primera clase**

Cuando se crea un registro histórico, los valores mutables que lo afectan deben capturarse como atributos propios del registro, no como referencias vivas a las entidades originales.

---

**Principio 3 — Los identificadores técnicos no son claves de negocio**

Toda entidad tiene un identificador único generado por el sistema. Ese identificador es la referencia que cruza contextos. Las claves naturales de negocio son restricciones de unicidad adicionales, no el identificador primario.

---

**Principio 4 — La eliminación es un estado, no una operación**

Nada clínico se elimina físicamente como parte del flujo normal. Los registros se archivan, se cierran, se anulan o se descartan. "Descartar" siempre significa cambio de estado. La eliminación física es una excepción gobernada y documentada que no forma parte del diseño de datos canónico.

---

**Principio 5 — La trazabilidad mínima es transversal y comienza en Fase 1**

Los cinco eventos T00 generan registros en `EventoAuditoríaMínima` de forma atómica con la acción que los origina, desde el primer día de operación. M21 Auditoría Operacional en Fase 3 es el módulo consultable avanzado sobre esos datos; no es el inicio del almacenamiento de trazabilidad.

---

**Principio 6 — Las relaciones entre contextos son por identificador opaco**

Cuando una entidad de BC6 referencia a una `AtenciónClínica` de BC2, lo hace por el identificador técnico de la atención, sin acceso al contenido clínico. Las entidades de BC7 no tienen relaciones directas con el contenido clínico de BC2.

---

**Principio 7 — OrganizaciónClínica es el ancla de todo**

Toda entidad del sistema que no sea de BC1 tiene una referencia directa o transitiva a la `OrganizaciónClínica` propietaria.

---

**Principio 8 — Las dependencias entre contextos fluyen en una sola dirección**

BC7 puede referenciar cobros de BC6 mediante ítems de liquidación. BC6 no referencia estructuralmente entidades de BC7. Si BC6 necesita mostrar que un cobro fue liquidado, ese dato es una proyección derivada desde BC7, no un campo autoritativo almacenado en BC6.

---

## 2. Clasificación de entidades

### 2.1 Por dominio

| Dominio | Entidades |
|---|---|
| **Identity** | OrganizaciónClínica · Profesional |
| **Core Clinical** | Paciente · HistoriaClínica · EntradaClínica · AtenciónClínica · TransiciónDeAtención · FotografíaClínica |
| **Operational** | Cita · TransiciónDeCita · Seguimiento · IntentoDeContacto |
| **Configuration** | TipoDeAtención · ValorArancel · ZonaDomiciliaria |
| **Economic** | Cobro · TransiciónDePago |
| **Commercial** | RelaciónConCentro · AcuerdoComercial · Liquidación · ÍtemDeLiquidación |
| **Documentary** | Consentimiento · InformeDeSesión |
| **Transversal** | EventoAuditoríaMínima |
| **Analytics** | *(sin entidades propias — proyecciones derivadas)* |

---

### 2.2 Por naturaleza

**Entidades históricas** — Inmutables una vez en el estado indicado. Preservadas permanentemente.

| Entidad | Estado que activa la inmutabilidad |
|---|---|
| AtenciónClínica (contenido clínico) | `cerrada` |
| TransiciónDeAtención | Desde su creación |
| EntradaClínica | Desde su creación |
| TransiciónDeCita | Desde su creación |
| TransiciónDePago | Desde su creación |
| EventoAuditoríaMínima | Desde su creación |
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
| ValorArancel | El valor vigente (creando una nueva versión; el anterior queda como histórico) |
| ZonaDomiciliaria | Nombre, descripción, recargo, estado |
| OrganizaciónClínica (configuración interna) | Preferencias operativas, horarios, zona horaria — son atributos de la entidad, no una entidad separada |

---

**Entidades derivadas** — No son entidades propias en el modelo relacional. Son proyecciones calculadas desde entidades canónicas.

| Proyección | Se deriva de |
|---|---|
| EvoluciónClínica (Fase 1) | AtenciónClínica + EntradaClínica |
| VistaDashboard | Cita + Cobro + Seguimiento + AtenciónClínica |
| ReporteFinanciero | Cobro + Liquidación |
| ReporteAsistencial | AtenciónClínica + Paciente + TipoDeAtención |
| Estado de liquidación de un Cobro | Proyección desde ÍtemDeLiquidación en BC7; no campo autoritativo en Cobro |

---

**Entidades auditables** — Requieren registro de quién realizó qué acción y cuándo.

| Entidad | Nivel de auditoría |
|---|---|
| Paciente | T00: creación |
| AtenciónClínica | T00: registro, cierre (vía TransiciónDeAtención + EventoAuditoríaMínima) |
| EntradaClínica | T00: adición a historia clínica (registra quién y cuándo) |
| Cita | T00: toda modificación de estado (vía TransiciónDeCita + EventoAuditoríaMínima) |
| Cobro | Extended: cambios de estado, anulación |
| Consentimiento | Extended: generación, firma, revocación, reemplazo |
| Liquidación | Extended: confirmación |
| AcuerdoComercial | Extended: toda nueva versión |
| Profesional | Base: creación, cambios de estado |
| OrganizaciónClínica | Base: cambios en configuración relevante |

---

## 3. Claves y restricciones de unicidad

### 3.1 Claves técnicas conceptuales

Toda entidad del modelo relacional tiene una **clave técnica**: un identificador único generado por el sistema en el momento de la creación. Esta clave:

- Es inmutable desde la creación
- No tiene significado de negocio para el usuario
- Es el identificador que usan las referencias entre entidades y entre contextos
- No es visible al usuario en la interfaz
- Debe ser globalmente única dentro del sistema

El mecanismo técnico concreto de generación de este identificador (tipo, formato, longitud) pertenece al diseño del schema, no a este documento.

---

### 3.2 Claves naturales de negocio

Una clave natural es un identificador que tiene significado en el mundo real, fuera del sistema.

| Entidad | Clave natural | Condiciones |
|---|---|---|
| Profesional | Email | Globalmente único en el sistema |
| Paciente | RUT (identificación nacional) | Único dentro de OrganizaciónClínica; **no obligatorio** — hay pacientes sin RUT |
| TipoDeAtención | Nombre | Único y activo dentro de OrganizaciónClínica |
| ZonaDomiciliaria | Nombre | Único y activo dentro de OrganizaciónClínica |
| OrganizaciónClínica | Identificación fiscal o equivalente | Único en el sistema |

---

### 3.3 Restricciones de unicidad de negocio

Estas restricciones expresan reglas del dominio que el modelo de datos debe garantizar, más allá de la clave técnica.

| Restricción | Entidad | Descripción |
|---|---|---|
| Email único de profesional | Profesional | Un email no puede pertenecer a dos profesionales distintos en el sistema |
| RUT único de paciente por org | Paciente | Si se registra un RUT, debe ser único dentro de la organización (soft: no todos los pacientes tienen RUT) |
| Nombre único de tipo activo | TipoDeAtención | Dentro de una organización, no pueden existir dos tipos activos con el mismo nombre |
| Nombre único de zona activa | ZonaDomiciliaria | Dentro de una organización, no pueden existir dos zonas activas con el mismo nombre |
| Una historia clínica por paciente | HistoriaClínica | Un paciente tiene exactamente una historia clínica |
| Un valor arancel vigente por tipo y modalidad | ValorArancel | No pueden existir dos registros de ValorArancel sin fecha de fin para el mismo TipoDeAtención y la misma modalidad |
| Sin solapamiento de vigencias de acuerdo | AcuerdoComercial | Para una misma RelaciónConCentro, los períodos de vigencia de los acuerdos no pueden solaparse |
| Un acuerdo vigente por relación con centro | AcuerdoComercial | Solo puede existir un AcuerdoComercial sin fecha de fin por RelaciónConCentro en un momento dado |
| No duplicar ítem por cobro en liquidación | ÍtemDeLiquidación | Un mismo Cobro no puede aparecer más de una vez dentro de la misma Liquidación |
| Unicidad de liquidación confirmada por período y centro | Liquidación | No pueden existir dos liquidaciones confirmadas para el mismo centro y el mismo período exacto, salvo que se modele explícitamente una rectificación con vínculo a la original |
| Consentimiento reemplazado tiene un único reemplazante | Consentimiento | Un consentimiento puede ser reemplazado por exactamente un consentimiento posterior; no puede ser reemplazado dos veces |
| Citas no superpuestas por profesional | Cita | Un profesional no puede tener dos citas activas (agendada o confirmada) con horario superpuesto |

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

- Identificación del negocio (nombre legal o comercial, identificación fiscal)
- Datos de presentación (nombre de fantasía)
- Datos de contacto (teléfono, email, dirección de atención)
- Configuración operativa: zona horaria, duración por defecto de las citas, horario de atención estándar
- Estado de la cuenta (activa, suspendida, cerrada)
- Fecha de creación en el sistema

*Nota sobre la configuración interna:* Los atributos de configuración son parte de esta entidad, no una entidad separada. No existe una entidad `ConfiguraciónOrganización` en el catálogo relacional.

**Relaciones obligatorias**  
Ninguna hacia afuera. Todo lo demás existe en relación a esta entidad.

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. La identificación fiscal es inmutable. Los demás atributos pueden cambiar.

**Reglas de auditoría**  
Creación. Cambios en configuración operativa relevante.

**Política de eliminación**  
No se descarta. Si la organización cierra, el estado cambia a "cerrada". Los datos se preservan.

**Dependencias permitidas**  
Ninguna.

**Clave natural**  
Identificación fiscal o equivalente.

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
- Datos de presentación (como aparece en documentos clínicos: nombre para firmar consentimientos e informes)
- Referencia a OrganizaciónClínica
- Estado de acceso (activo, suspendido, desactivado)
- Fecha de creación en el sistema

**Nota sobre membresía y SaaS**  
En Fase 1, la relación de Profesional con OrganizaciónClínica es directa y no tiene ciclo de vida propio. En un escenario SaaS futuro, esa membresía necesitaría identidad propia con invitaciones, roles y estados. El diseño de la relación entre Profesional y Organización debe ser separable sin reestructuración destructiva, de modo que esa evolución sea posible.

**Relaciones obligatorias**  
Pertenece a OrganizaciónClínica.

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El email puede corregirse con trazabilidad.

**Reglas de auditoría**  
Creación. Cambios de estado. Cambios de email.

**Política de eliminación**  
No se descarta. Se desactiva el acceso.

**Dependencias permitidas**  
OrganizaciónClínica.

**Clave natural**  
Email (globalmente único en el sistema).

---

### ENTIDAD: EventoAuditoríaMínima

**Dominio:** Transversal  
**Naturaleza:** Histórica (log inmutable) · T00  
**Entidad nueva en v1.1 — Fase 1**

**Propósito**  
Registro transversal de los cinco eventos mínimos de trazabilidad que el sistema debe preservar desde el primer día de operación. Es la base de datos sobre la que M21 Auditoría Operacional en Fase 3 construirá su interfaz consultable avanzada.

Existe desde Fase 1, opera en silencio (no tiene módulo visible propio en Fase 1), y es atómico con la acción que lo origina: si la acción ocurre, el evento se registra; no hay acción T00 sin su registro.

**Eventos cubiertos**

| Tipo de evento | Cuándo se genera |
|---|---|
| `PacienteCreado` | Al registrar un nuevo paciente |
| `AtenciónRegistrada` | Al crear el borrador de una atención clínica |
| `AtenciónCerrada` | Al cerrar formalmente una atención clínica |
| `CitaModificada` | Al cambiar el estado de una cita (cualquier transición) |
| `HistoriaClínicaActualizada` | Al agregar una EntradaClínica a la historia de un paciente |

**Atributos conceptuales**

- Tipo de evento (de los cinco listados)
- Referencia técnica a la entidad afectada (Paciente, AtenciónClínica, Cita o HistoriaClínica según corresponda)
- Referencia al Profesional que ejecutó la acción
- Referencia a OrganizaciónClínica
- Fecha y hora del evento
- Resumen contextual del evento (estado anterior → estado nuevo, cuando aplica)

**Relaciones obligatorias**  
Profesional · OrganizaciónClínica · entidad afectada (por referencia técnica).

**Reglas de inmutabilidad**  
Completamente inmutable desde su creación. Es un log append-only. Ningún actor puede modificar ni eliminar un evento registrado.

**Política de eliminación**  
Nunca. Es el soporte de auditoría clínica y operacional.

**Relación con entidades de transición específicas**  
`TransiciónDeAtención` registra los detalles del cambio de estado de `AtenciónClínica` dentro del dominio clínico. `TransiciónDeCita` registra los detalles de la cita dentro del dominio de agenda. `EventoAuditoríaMínima` registra el hecho transversal para trazabilidad de auditoría. Cuando ocurre un evento T00, se generan registros en ambos lugares de forma atómica.

**Relación con M21**  
M21 Auditoría Operacional (Fase 3) es el módulo que permite consultar y filtrar estos registros de forma avanzada, cruzarlos con otras entidades y exportarlos. No crea los datos: los consulta. Si M21 no existiera, los datos de trazabilidad existirían igualmente desde Fase 1.

---

### ENTIDAD: Paciente

**Dominio:** Core Clinical  
**Naturaleza:** Canónica · Auditable · T00  
**Aggregate Root de BC2**

**Propósito**  
La persona que recibe atención podológica. Es el sujeto clínico central del sistema.

**Atributos conceptuales**

- Nombre completo
- Identificación (RUT u otro documento; opcional pero preferible)
- Fecha de nacimiento
- Datos de contacto: teléfono principal, teléfono alternativo, email
- Dirección (descripción libre)
- Origen del paciente (categoría: particular / proveniente de centro médico / administrado por tercero)
- Estado (activo / en seguimiento / inactivo / archivado)
- Notas generales (observaciones no clínicas de contexto)
- Referencia a OrganizaciónClínica
- Fecha de primer registro en el sistema

**Nota de faseo sobre origen del paciente**  
En Fase 1, el origen existe como categoría o texto descriptivo. No hay referencia estructural a `RelaciónConCentro` en Fase 1, porque esa entidad no existe hasta Fase 2. Cuando Fase 2 incorpore `RelaciónConCentro`, la referencia puede agregarse sin romper el modelo: el campo de origen evoluciona de categoría a referencia estructural opcional.

**Relaciones obligatorias**  
Pertenece a OrganizaciónClínica. Tiene exactamente una HistoriaClínica.

**Relaciones opcionales**  
Referencia a RelaciónConCentro (Fase 2, cuando origen = centro médico).

**Reglas de inmutabilidad**  
El identificador técnico es inmutable. El nombre y RUT son canónicos: los cambios deben quedar trazados.

**Reglas de auditoría**  
T00: creación (quién y cuándo, registrado en EventoAuditoríaMínima).

**Política de eliminación**  
Archivado exclusivamente. Estado cambia a "archivado". El registro persiste permanentemente.

**Dependencias permitidas**  
OrganizaciónClínica.

**Clave natural**  
RUT + OrganizaciónClínica (cuando RUT disponible).

---

### ENTIDAD: HistoriaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica + Histórica · Auditable · T00  
**Entidad contenida en el Aggregate Root Paciente**

**Propósito**  
El perfil clínico permanente del paciente. Contenedor de todas las EntradaClínica que conforman el conocimiento de largo plazo sobre la salud del paciente.

**Atributos conceptuales**

- Referencia al Paciente (relación 1:1 obligatoria)
- Resumen general de salud (campo libre de largo plazo)
- Referencia a OrganizaciónClínica
- Fecha de creación (igual a la del Paciente)

**Relaciones obligatorias**  
Pertenece exactamente a un Paciente. Pertenece a OrganizaciónClínica.

**Reglas de inmutabilidad**  
La HistoriaClínica como entidad no puede cerrarse, descartarse ni modificarse. Crece por adición de EntradaClínica; nunca por eliminación o modificación de entradas existentes.

**Reglas de auditoría**  
T00: toda adición de EntradaClínica genera un registro en EventoAuditoríaMínima (tipo `HistoriaClínicaActualizada`).

**Política de eliminación**  
Nunca. Se preserva con el Paciente para siempre.

**Restricción de unicidad**  
Existe exactamente una HistoriaClínica por Paciente.

---

### ENTIDAD: EntradaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Histórica · Auditable · T00  
**Objeto de valor en HistoriaClínica**

**Propósito**  
Registro individual de un hecho clínico de largo plazo del paciente: una patología, un medicamento en uso, una alergia u observación relevante para todas las atenciones futuras.

**Atributos conceptuales**

- Referencia a HistoriaClínica
- Tipo de entrada (patología / medicamento / alergia / observación / otro)
- Descripción del hecho clínico (texto libre)
- Estado de la entrada (activo / resuelto / inactivo)
- Fecha de registro
- Referencia al Profesional que la registró
- Notas adicionales (aclaraciones posteriores, no modificaciones del contenido original)

**Relaciones obligatorias**  
Pertenece a HistoriaClínica. Registrada por Profesional.

**Reglas de inmutabilidad**  
Una EntradaClínica registrada no puede modificarse ni descartarse. Solo puede cambiar su estado (activo → resuelto / inactivo). El contenido original es inmutable.

**Reglas de auditoría**  
Creación registra quién y cuándo. Genera un `EventoAuditoríaMínima` de tipo `HistoriaClínicaActualizada`.

**Política de eliminación**  
Nunca. El estado "inactivo" o "resuelto" retira la entrada del flujo activo sin borrarla.

---

### ENTIDAD: AtenciónClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica (abierta) + Histórica (cerrada) · Auditable · T00  
**Aggregate Root de BC2**

**Propósito**  
El registro canónico e inmutable de lo que ocurrió en una sesión clínica. Una vez cerrada, es la verdad definitiva sobre esa sesión.

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
- Referencia técnica a TipoDeAtención
- Snapshot del nombre del tipo al momento del registro (capturado al crear o cerrar)

*Contenido clínico (inmutable desde cierre):*
- Tratamiento realizado
- Hallazgos clínicos
- Notas clínicas
- Indicaciones al paciente

*Referencias opcionales:*
- Referencia a Cita que originó la atención
- Referencia a ZonaDomiciliaria (si modalidad = domiciliaria)
- Referencia a RelaciónConCentro (si modalidad = centro médico)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
Cita · ZonaDomiciliaria · RelaciónConCentro.

**Reglas de inmutabilidad**  
Una vez estado = "cerrada": el contenido clínico, la fecha y hora de cierre, y el profesional que cerró son inmutables. Las anotaciones posteriores se registran como nuevas EntradaClínica o como notas de seguimiento; nunca modifican el contenido original.

**Reglas de auditoría**  
T00: registro y cierre. Se generan registros en `TransiciónDeAtención` y en `EventoAuditoríaMínima` de forma atómica.

**Política de eliminación**  
Un borrador sin contenido significativo puede descartarse (cambio de estado a "descartada"). Una atención con cualquier contenido clínico registrado no puede descartarse.

---

### ENTIDAD: TransiciónDeAtención

**Dominio:** Core Clinical  
**Naturaleza:** Histórica (log inmutable) · T00  
**Entidad nueva en v1.1 — Fase 1**

**Propósito**  
Registro inmutable de cada cambio de estado de una `AtenciónClínica`. Permite auditar el ciclo de vida clínico de una sesión y es el mecanismo de trazabilidad T00 para los eventos de registro y cierre de atención dentro del dominio clínico.

**Atributos conceptuales**

- Referencia a AtenciónClínica
- Estado anterior
- Estado nuevo
- Referencia al Profesional que realizó el cambio
- Fecha y hora del cambio
- Motivo o notas (cuando aplica)

**Relaciones obligatorias**  
AtenciónClínica · Profesional.

**Reglas de inmutabilidad**  
Completamente inmutable desde su creación. Es un log append-only.

**Reglas de auditoría**  
Es en sí misma el registro de auditoría del dominio clínico. Para los estados T00 (registro y cierre), se genera simultáneamente un `EventoAuditoríaMínima`.

**Política de eliminación**  
Nunca.

---

### ENTIDAD: FotografíaClínica

**Dominio:** Core Clinical  
**Naturaleza:** Canónica + Histórica · Auditable  
**Aggregate Root de BC2 — Fase 2**

**Propósito**  
Evidencia visual permanente del estado clínico del paciente. Permite la comparación longitudinal del estado de las lesiones o condiciones tratadas.

**Atributos conceptuales**

- Referencia al Paciente
- Referencia a OrganizaciónClínica
- Referencia al Profesional que la capturó
- Fecha y hora de captura
- Descripción del contenido (qué muestra la fotografía)
- Contexto clínico (perfil del paciente / asociada a atención específica)
- Referencia a AtenciónClínica (opcional)
- Estado (activa / archivada)
- Referencia al recurso de imagen almacenado (referencia técnica al objeto de almacenamiento)

**Relaciones obligatorias**  
Paciente · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica.

**Reglas de inmutabilidad**  
El recurso de imagen es inmutable desde su captura. Los metadatos pueden corregirse con trazabilidad.

**Política de eliminación**  
Archivado. La imagen y sus metadatos persisten.

---

### ENTIDAD: Cita

**Dominio:** Operational  
**Naturaleza:** Canónica (futura) + Histórica (pasada) · Auditable · T00  
**Aggregate Root de BC3**

**Propósito**  
Un bloque de tiempo programado para una atención clínica. Organiza el día de trabajo del profesional.

**Atributos conceptuales**

- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Fecha y hora de inicio
- Duración estimada
- Referencia a TipoDeAtención prevista (opcional)
- Snapshot del nombre del tipo previsto (cuando está definido)
- Estado (agendada / confirmada / atendida / cancelada / inasistida / reprogramada)
- Notas del profesional
- Motivo de cancelación o inasistencia (cuando aplica)
- Referencia a Cita anterior si es reprogramación (opcional)
- Referencia a Seguimiento que la generó (opcional)
- Referencia a AtenciónClínica resultante (opcional)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Reglas de inmutabilidad**  
Una cita con estado "atendida", "cancelada" o "inasistida" es histórica.

**Reglas de auditoría**  
T00: toda modificación de estado genera registros en `TransiciónDeCita` y en `EventoAuditoríaMínima` (tipo `CitaModificada`).

**Política de eliminación**  
No se descarta. Una cita errónea se cancela con motivo. El historial persiste.

---

### ENTIDAD: TransiciónDeCita

**Dominio:** Operational  
**Naturaleza:** Histórica (log inmutable) · T00  
**Objeto de valor en Cita**

**Propósito**  
Registro inmutable de cada cambio de estado de una Cita. Junto con `EventoAuditoríaMínima`, cubre el T00 de modificaciones de cita.

**Atributos conceptuales**

- Referencia a Cita
- Estado anterior
- Estado nuevo
- Referencia al Profesional que realizó el cambio
- Fecha y hora del cambio
- Motivo o notas

**Reglas de inmutabilidad**  
Inmutable desde su creación.

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
- Tipo de seguimiento
- Nivel de urgencia (normal / prioritario / urgente)
- Estado (pendiente / contactado / agendado / completado / vencido / descartado)
- Origen del seguimiento (manual / automático desde cierre de atención)
- Referencia a AtenciónClínica que lo originó (referencia técnica opaca, opcional)
- Referencia a Cita resultante (opcional)
- Notas del profesional
- Fecha de creación
- Fecha límite de contacto (cuando aplica)
- Fecha de resolución (cuando cerrado)

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Política de eliminación**  
No se descarta. Cierre mediante cambio de estado a "completado" o "descartado".

---

### ENTIDAD: IntentoDeContacto

**Dominio:** Operational  
**Naturaleza:** Histórica (log inmutable)**  
**Objeto de valor en Seguimiento**

**Propósito**  
Registro de cada intento del profesional de contactar al paciente durante el seguimiento.

**Atributos conceptuales**

- Referencia a Seguimiento
- Canal del intento (teléfono / mensajería / email / presencial / otro)
- Resultado del intento
- Notas del profesional
- Fecha y hora del intento

**Reglas de inmutabilidad**  
Inmutable desde su creación.

---

### ENTIDAD: TipoDeAtención

**Dominio:** Configuration (Shared Kernel BC5)  
**Naturaleza:** Configurable · Auditable**  
**Aggregate Root de BC5**

**Propósito**  
Catálogo de tipos de atención disponibles en la organización. Referencia compartida entre el contexto Clínico y el contexto Económico.

**Atributos conceptuales**

- Nombre del tipo de atención
- Descripción clínica
- Estado (activo / inactivo)
- Referencia a OrganizaciónClínica
- Fecha de creación

**Regla de Shared Kernel:** BC2 y BC6, cuando crean registros históricos, capturan el nombre del tipo como snapshot. Los registros históricos nunca consultan el nombre actual.

**Política de eliminación**  
No se descarta si existen referencias en atenciones o cobros. Se desactiva.

**Restricción de unicidad**  
[nombre, organización] único entre tipos activos.

---

### ENTIDAD: ValorArancel

**Dominio:** Configuration (BC5)  
**Naturaleza:** Configurable + Histórica (versiones vencidas)**  
**Objeto de valor en TipoDeAtención**

**Propósito**  
Precio asociado a un tipo de atención para un contexto dado. Versionado para permitir cambios sin afectar registros históricos.

**Atributos conceptuales**

- Referencia a TipoDeAtención
- Modalidad de aplicación
- Valor (precio)
- Fecha de inicio de vigencia
- Fecha de fin de vigencia (vacía si es el valor vigente)
- Referencia al Profesional que lo configuró

**Faseo de modalidades**

| Fase | Modalidades cubiertas |
|---|---|
| Fase 1 | Particular (valor base único) |
| Fase 2 | Domiciliaria · Centros médicos |

Un registro con fecha de fin de vigencia es histórico e inmutable. Solo el registro vigente puede ser "reemplazado" creando uno nuevo y cerrando el anterior.

**Restricción de unicidad**  
No pueden existir dos registros de ValorArancel sin fecha de fin para el mismo TipoDeAtención y la misma modalidad.

---

### ENTIDAD: ZonaDomiciliaria

**Dominio:** Configuration (BC5) — Fase 2  
**Naturaleza:** Configurable · Auditable (cambios de recargo)**  
**Aggregate Root de BC5**

**Propósito**  
Área geográfica definida manualmente por el profesional para aplicar un recargo de traslado en atenciones domiciliarias.

**Atributos conceptuales**

- Nombre de la zona
- Descripción geográfica en texto libre (sin GPS ni mapas)
- Recargo asociado
- Estado (activa / inactiva)
- Referencia a OrganizaciónClínica

**Política de eliminación**  
No se descarta si existen cobros asociados. Se desactiva.

**Restricción de unicidad**  
[nombre, organización] único entre zonas activas.

---

### ENTIDAD: Cobro

**Dominio:** Economic  
**Naturaleza:** Histórica (snapshot económico) · Canónica (estado de pago) · Auditable  
**Aggregate Root de BC6**

**Propósito**  
El registro canónico del hecho económico del trabajo clínico. Captura en forma permanente e inmutable cuánto se cobró, por qué concepto y en qué estado se encuentra el pago.

**Sobre el origen del cobro**  
Todo cobro existe porque hubo trabajo clínico o se formalizó un concepto administrativo validado. Un cobro puede estar vinculado a una atención clínica individual, a un conjunto de atenciones, a un recargo de traslado o a un pago anticipado acordado. Lo que no puede ocurrir es un cobro sin ningún respaldo clínico o concepto reconocido. La referencia a `AtenciónClínica` es opcional en la estructura del dato, pero el concepto del cobro siempre debe justificarse.

**Atributos conceptuales**

*Snapshot económico (inmutable desde creación):*
- Monto capturado al momento del registro
- Nombre y descripción del tipo de atención al momento del registro (snapshot)
- Modalidad del cobro (particular / domiciliaria / centro médico)
- Snapshot del recargo de zona si modalidad = domiciliaria (opcional)
- Snapshot del valor acordado con el centro si modalidad = centro médico (opcional)
- Concepto del cobro (descripción del trabajo que lo origina)
- Categoría del origen (atención individual / conjunto de atenciones / recargo administrativo / anticipo)

*Metadatos del cobro:*
- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Fecha de registro
- Referencia a AtenciónClínica (referencia técnica opaca, opcional)
- Referencia a ZonaDomiciliaria (referencia técnica, opcional — el recargo ya está en snapshot)
- Referencia a RelaciónConCentro (referencia técnica, opcional — el valor acordado ya está en snapshot)

*Estado del pago (mutable):*
- Estado actual (pendiente / pagado_parcial / pagado / anulado)
- Medio de pago registrado
- Fecha de pago (cuando aplica)
- Motivo de anulación (cuando aplica)

**Nota sobre estado de liquidación**  
El campo `estado de liquidación` no existe en la entidad Cobro. Si se necesita saber si un cobro fue incluido en una liquidación confirmada, esa información se obtiene como proyección desde BC7 (consultando `ÍtemDeLiquidación`). Esta separación garantiza que BC6 no dependa estructuralmente de BC7.

**Relaciones obligatorias**  
Paciente · Profesional · OrganizaciónClínica.

**Relaciones opcionales**  
AtenciónClínica (referencia técnica opaca) · ZonaDomiciliaria · RelaciónConCentro.

**Reglas de inmutabilidad**  
El snapshot económico es inmutable desde la creación. El estado del pago es mutable.

**Reglas de auditoría**  
Todo cambio de estado del pago. Anulaciones especialmente.

**Política de eliminación**  
Nunca. La anulación cambia el estado a "anulado" con motivo y trazabilidad. El registro persiste.

---

### ENTIDAD: TransiciónDePago

**Dominio:** Economic  
**Naturaleza:** Histórica (log inmutable)**  
**Objeto de valor en Cobro**

**Propósito**  
Log inmutable de cada cambio de estado del cobro.

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

**Dominio:** Commercial — Fase 2  
**Naturaleza:** Canónica (identidad) + Configurable (acuerdo) · Auditable  
**Aggregate Root de BC7**

**Propósito**  
El vínculo de la organización con un centro médico externo. Representa la relación comercial y operativa, no el centro en sí. Los cambios en los términos del acuerdo versionan la relación, no la destruyen.

**Atributos conceptuales**

- Nombre del centro médico externo
- Datos de contacto del centro
- Modalidad de la relación
- Estado del vínculo (activo / inactivo)
- Referencia a OrganizaciónClínica
- Fecha de inicio del vínculo

**Relaciones obligatorias**  
OrganizaciónClínica. Al menos un AcuerdoComercial desde la creación.

**Reglas de auditoría**  
Creación del vínculo. Cambios en términos del acuerdo (genera `AcuerdoCentroVersionado`). Desactivación.

**Política de eliminación**  
No se descarta si existen Cobros o Liquidaciones asociadas. Se desactiva.

---

### ENTIDAD: AcuerdoComercial

**Dominio:** Commercial  
**Naturaleza:** Configurable (vigente) + Histórica (vencido) · Auditable  
**Entidad contenida en RelaciónConCentro**

**Propósito**  
Versión específica y con vigencia temporal de los términos comerciales con un centro. Permite cambiar condiciones sin perder el historial.

**Atributos conceptuales**

- Referencia a RelaciónConCentro
- Tipo de acuerdo (porcentaje de comisión / valor fijo por atención / valor fijo mensual)
- Parámetros del acuerdo (porcentaje o valor según tipo)
- Observaciones (condiciones especiales, excepciones)
- Fecha de inicio de vigencia
- Fecha de fin de vigencia (vacía si es el acuerdo vigente)
- Referencia al Profesional que registró esta versión

**Reglas de inmutabilidad**  
Un acuerdo con fecha de fin es histórico e inmutable. Solo el vigente puede ser "reemplazado" creando uno nuevo y cerrando el anterior.

**Restricciones de unicidad**  
- Solo puede existir un AcuerdoComercial sin fecha de fin por RelaciónConCentro.
- Los períodos de vigencia de los acuerdos de una misma RelaciónConCentro no pueden solaparse.

---

### ENTIDAD: Liquidación

**Dominio:** Commercial — Fase 2 (antes en Fase 3; corregido en v1.1)  
**Naturaleza:** Derivada (borrador) + Histórica (confirmada) · Auditable  
**Aggregate Root de BC7**

**Propósito**  
Resumen económico del trabajo realizado en un centro médico durante un período. Una vez confirmada, es el registro legal del cierre económico con ese centro.

**Atributos conceptuales**

- Referencia a RelaciónConCentro
- Referencia a OrganizaciónClínica
- Período cubierto (fecha de inicio y fin)
- Referencia al AcuerdoComercial aplicado (snapshot de términos vigentes al momento del cierre)
- Monto total calculado
- Estado (borrador / confirmada / pagada)
- Fecha de confirmación (cuando aplica)
- Notas del período
- Referencia al Profesional que confirmó

**Relaciones obligatorias**  
RelaciónConCentro · OrganizaciónClínica.

**Reglas de inmutabilidad**  
El monto total, los ítems incluidos y la referencia al acuerdo aplicado son inmutables una vez estado = "confirmada".

**Reglas de auditoría**  
Confirmación (quién, cuándo). Cambios de estado.

**Política de eliminación**  
Un borrador puede descartarse (cambio de estado a "descartada"). Liquidaciones confirmadas son históricas: nunca se descartan.

**Restricciones de unicidad**  
- A lo sumo una liquidación en estado "borrador" por [RelaciónConCentro, período].
- No pueden existir dos liquidaciones confirmadas para el mismo [RelaciónConCentro, período exacto], salvo que se modele explícitamente una rectificación con referencia a la original.

---

### ENTIDAD: ÍtemDeLiquidación

**Dominio:** Commercial  
**Naturaleza:** Histórica (cuando liquidación confirmada)**  
**Entidad contenida en Liquidación**

**Propósito**  
Cada hecho económico incluido en una liquidación. Registra los cobros del período que corresponden al centro.

**Atributos conceptuales**

- Referencia a Liquidación
- Referencia al Cobro de BC6 (referencia técnica opaca — BC7 no accede al contenido clínico del cobro)
- Monto del cobro al momento de la inclusión (snapshot)
- Tipo de atención (snapshot del nombre — no referencia viva a BC2)
- Fecha del hecho económico
- Modalidad

**Reglas de inmutabilidad**  
Inmutables una vez la liquidación está confirmada.

**Restricción de unicidad**  
Un mismo Cobro no puede aparecer más de una vez dentro de la misma Liquidación.

**Nota crítica**  
ÍtemDeLiquidación no accede al contenido clínico de la atención que originó el cobro. Solo conoce datos económicos del Cobro. Esta frontera garantiza que BC7 no depende de BC2.

---

### ENTIDAD: Consentimiento

**Dominio:** Documentary  
**Naturaleza:** Histórica (firmado) · Auditable  
**Aggregate Root de BC8 — Fase 2**

**Propósito**  
Documento clínico-legal que acredita que el paciente conoce y acepta el tratamiento.

**Atributos conceptuales**

*Snapshots capturados al momento de generación:*
- Datos del paciente al momento (nombre, identificación)
- Datos del profesional al momento
- Versión de la plantilla utilizada (identificador + contenido de la plantilla capturado)
- Contenido del documento generado

*Firma:*
- Estado de la firma del paciente (pendiente / firmado)
- Datos de la firma del paciente (imagen o confirmación, fecha y hora)
- Estado de la firma del profesional
- Datos de la firma del profesional

*Estado documental:*
- Estado (borrador / generado / firmado / revocado / reemplazado)
- Fecha de generación formal
- Motivo de revocación (cuando aplica)
- Referencia al Consentimiento reemplazante (cuando aplica)
- Referencia al Consentimiento reemplazado (cuando este reemplaza a uno previo)

*Metadatos:*
- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica
- Referencia a AtenciónClínica (referencia técnica, opcional)

**Reglas de inmutabilidad**  
El contenido del documento, los datos de firma y la fecha de firma son inmutables una vez estado = "firmado". Revocación y reemplazo son eventos que cambian el estado; no modifican el contenido.

**Política de eliminación**  
Nunca. Revocación o reemplazo con trazabilidad completa.

**Restricción de unicidad**  
Un consentimiento puede ser reemplazado por exactamente un consentimiento posterior. La relación reemplazado → reemplazante es 1:1.

---

### ENTIDAD: InformeDeSesión

**Dominio:** Documentary  
**Naturaleza:** Derivada (borrador) + Histórica (generado) · Auditable  
**Aggregate Root de BC8 — Fase 2**

**Propósito**  
Reporte del trabajo realizado en una sesión clínica, para entrega al paciente. Una vez generado formalmente, es un documento histórico inmutable.

**Atributos conceptuales**

*Snapshot al momento de generación:*
- Datos del paciente al momento
- Datos del profesional al momento
- Datos clínicos de la atención (tratamiento realizado, indicaciones, extraídos de AtenciónClínica)
- Fecha y hora de la atención

*Estado documental:*
- Estado (borrador / generado / entregado)
- Fecha de generación formal
- Canal de entrega (impresión / correo / otro)
- Fecha de entrega (cuando aplica)

*Metadatos:*
- Referencia a AtenciónClínica (el snapshot del contenido se captura al generar)
- Referencia al Paciente
- Referencia al Profesional
- Referencia a OrganizaciónClínica

**Reglas de inmutabilidad**  
El snapshot del contenido clínico es inmutable una vez estado = "generado".

**Política de eliminación**  
Un borrador puede descartarse (cambio de estado). Un informe generado o entregado es histórico: no se descarta.

---

## 5. Mapa de dependencias entre entidades

Este mapa muestra qué entidades deben existir antes de poder crear otra. Es la base del orden de construcción en el modelo relacional.

```
OrganizaciónClínica
│
├── Profesional
│
├── TipoDeAtención
│   └── ValorArancel
│
├── ZonaDomiciliaria (Fase 2)
│
└── Paciente
    └── HistoriaClínica
        └── EntradaClínica → genera EventoAuditoríaMínima

AtenciónClínica
├── requiere: Paciente · Profesional · OrganizaciónClínica
├── genera: TransiciónDeAtención → genera EventoAuditoríaMínima
└── referencia opcional: Cita · ZonaDomiciliaria · RelaciónConCentro

Cita
├── requiere: Paciente · Profesional · OrganizaciónClínica
├── genera: TransiciónDeCita → genera EventoAuditoríaMínima
└── referencia opcional: TipoDeAtención · Seguimiento · Cita previa

Seguimiento
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: AtenciónClínica (opaco) · Cita
    └── contiene: IntentoDeContacto

Cobro
├── requiere: Paciente · Profesional · OrganizaciónClínica
├── genera: TransiciónDePago
└── referencia opcional: AtenciónClínica (opaco) · ZonaDomiciliaria · RelaciónConCentro
    [NO referencia directa a Liquidación — la relación fluye desde Liquidación]

RelaciónConCentro (Fase 2)
├── requiere: OrganizaciónClínica
└── contiene: AcuerdoComercial (al menos uno vigente)

Liquidación (Fase 2)
├── requiere: RelaciónConCentro · OrganizaciónClínica
└── contiene: ÍtemDeLiquidación
    └── referencia: Cobro (por referencia técnica opaca desde BC7 → BC6)

Consentimiento (Fase 2)
├── requiere: Paciente · Profesional · OrganizaciónClínica
└── referencia opcional: AtenciónClínica

InformeDeSesión (Fase 2)
└── requiere: AtenciónClínica · Paciente · Profesional · OrganizaciónClínica

FotografíaClínica (Fase 2)
├── requiere: Paciente · OrganizaciónClínica
└── referencia opcional: AtenciónClínica

EventoAuditoríaMínima (Fase 1 — transversal)
└── requiere: Profesional · OrganizaciónClínica · entidad afectada (por referencia técnica)
```

---

## 6. Vista consolidada: entidades por fase de construcción

---

**Fase 1 — Utilizable (MVP clínico)**

| Entidad | Dominio | Razón |
|---|---|---|
| OrganizaciónClínica | Identity | Base de todo |
| Profesional | Identity | Acceso al sistema |
| EventoAuditoríaMínima | Transversal | T00: trazabilidad mínima desde día uno |
| TipoDeAtención | Configuration | Catálogo requerido por Atención y Cobro |
| ValorArancel (particular) | Configuration | Valor base particular en Fase 1 |
| Paciente | Core Clinical | Núcleo clínico |
| HistoriaClínica | Core Clinical | Con Paciente, simultáneo |
| EntradaClínica | Core Clinical | Contenido de la historia |
| AtenciónClínica | Core Clinical | Núcleo clínico |
| TransiciónDeAtención | Core Clinical | T00: trazabilidad de registro y cierre |
| Cita | Operational | Agenda diaria |
| TransiciónDeCita | Operational | T00: trazabilidad de modificación de cita |
| Seguimiento | Operational | Continuidad post-atención |
| Cobro | Economic | Registro económico básico |
| TransiciónDePago | Economic | Trazabilidad de cobros |

---

**Fase 2 — Completo para práctica individual**

| Entidad | Dominio | Razón |
|---|---|---|
| ZonaDomiciliaria | Configuration | Precios diferenciados por traslado |
| ValorArancel (domiciliaria) | Configuration | Recargos por zona |
| FotografíaClínica | Core Clinical | Evidencia visual clínica |
| IntentoDeContacto | Operational | Seguimiento enriquecido |
| RelaciónConCentro | Commercial | Centros médicos |
| AcuerdoComercial | Commercial | Términos del acuerdo con centros |
| Liquidación | Commercial | Cierre económico con centros |
| ÍtemDeLiquidación | Commercial | Detalle de la liquidación |
| Consentimiento | Documentary | Documentos clínico-legales |
| InformeDeSesión | Documentary | Reportes de sesión |
| ValorArancel (centros) | Configuration | Valores diferenciados por centro |

---

**Fase 3 — Centro multi-profesional / auditoría avanzada**

| Entidad / Módulo | Razón |
|---|---|
| M21 Auditoría Operacional (interfaz) | Módulo consultable sobre `EventoAuditoríaMínima` + eventos extendidos. Los datos ya existen desde Fase 1; Fase 3 agrega la interfaz y los eventos adicionales. |
| Membresía multi-organización | Si SaaS escala a Profesional en múltiples orgs |

---

## 7. Resumen: entidades por clasificación cruzada

```
Por dominio
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Transversal (1):      EventoAuditoríaMínima
Identity (2):         OrganizaciónClínica · Profesional
Core Clinical (6):    Paciente · HistoriaClínica · EntradaClínica
                      AtenciónClínica · TransiciónDeAtención · FotografíaClínica
Operational (4):      Cita · TransiciónDeCita
                      Seguimiento · IntentoDeContacto
Configuration (3):    TipoDeAtención · ValorArancel · ZonaDomiciliaria
Economic (2):         Cobro · TransiciónDePago
Commercial (4):       RelaciónConCentro · AcuerdoComercial
                      Liquidación · ÍtemDeLiquidación
Documentary (2):      Consentimiento · InformeDeSesión
Analytics (0):        proyecciones derivadas, sin entidades propias

Total: 24 entidades relacionales

Por naturaleza
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Históricas (14):
  EntradaClínica · TransiciónDeAtención · TransiciónDeCita
  TransiciónDePago · EventoAuditoríaMínima · IntentoDeContacto
  AtenciónClínica (cerrada) · FotografíaClínica (imagen)
  Cobro (snapshot) · Consentimiento (firmado)
  InformeDeSesión (generado) · AcuerdoComercial (vencido)
  Liquidación (confirmada) · ÍtemDeLiquidación (cuando confirmada)

Configurables (3):
  TipoDeAtención · ValorArancel · ZonaDomiciliaria
  [ConfiguraciónOrganización no es entidad separada: son atributos de OrganizaciónClínica]

Derivadas (sin entidad propia) (5):
  EvoluciónClínica · VistaDashboard
  ReporteFinanciero · ReporteAsistencial
  Estado de liquidación de un Cobro (proyección desde BC7)

Auditables T00 (5 eventos mínimos):
  PacienteCreado → EventoAuditoríaMínima
  AtenciónRegistrada → TransiciónDeAtención + EventoAuditoríaMínima
  AtenciónCerrada → TransiciónDeAtención + EventoAuditoríaMínima
  CitaModificada → TransiciónDeCita + EventoAuditoríaMínima
  HistoriaClínicaActualizada → EntradaClínica.quién/cuándo + EventoAuditoríaMínima
```

---

*Este documento es la Base Canónica del modelo relacional de Agenda Podológica. No especifica estructuras técnicas de almacenamiento ni mecanismos de implementación: especifica qué existe, para qué sirve y qué reglas lo rigen. Toda decisión de diseño de schema posterior debe poder rastrear su origen a este documento o justificar explícitamente la desviación.*
