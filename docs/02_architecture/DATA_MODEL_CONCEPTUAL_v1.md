# Modelo Conceptual de Datos — Agenda Podológica

**Versión:** 1.0  
**Estado:** Fundacional  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuentes:** DOMINIO_CANONICO_PODOLOGIA_v1.1.md · ARQUITECTURA_CONCEPTUAL_v1.1.md · CANONICAL_DATA_FOUNDATION_PODOLOGIA.md · INSIGHTS_CLIENTE_CONSTANZA_001.md

---

## Propósito de este documento

Este documento traduce el dominio canónico y la arquitectura conceptual de Agenda Podológica al lenguaje del diseño de modelos de datos: identifica los Bounded Contexts, las raíces de agregado, las entidades que viven dentro de cada contexto, cómo los contextos se relacionan, qué eventos cruzan sus fronteras, qué dependencias están permitidas y cuáles están prohibidas.

No diseña tablas, no escribe SQL, no especifica Supabase, no define migraciones, no produce código. Es el modelo conceptual que debe existir antes de cualquier decisión técnica de implementación.

Este documento sigue los principios del Domain-Driven Design (DDD). Los términos clave —Bounded Context, Aggregate Root, Domain Event— se usan con su significado técnico preciso.

---

## Lectura rápida: Los 9 Bounded Contexts

| # | Contexto | Módulos origen | Core |
|---|---|---|---|
| BC1 | Identidad y Organización | M01, M02 | Quién eres y a qué organización perteneces |
| BC2 | Clínico | M03, M04, M05, M08 | El corazón: paciente, historia, atención |
| BC3 | Agenda | M06 | Programación de tiempo clínico |
| BC4 | Seguimiento | M07 | Continuidad post-atención |
| BC5 | Configuración Operacional | M10, M12 | Catálogos y parámetros compartidos |
| BC6 | Económico | M09 | Registro económico de la atención |
| BC7 | Relaciones Comerciales | M11, M13 | Centros médicos y liquidaciones |
| BC8 | Documental | M14 | Documentos clínicos generados |
| BC9 | Analítico | M15, M16 | Proyecciones y reportes derivados |

---

## 1. Bounded Contexts

Un Bounded Context es un límite dentro del cual un modelo conceptual es consistente y coherente. Dentro de un contexto, los términos tienen definiciones claras y unívocas. El mismo concepto puede tener definiciones distintas en contextos distintos: eso es intencional y correcto.

La siguiente sección describe cada contexto con su responsabilidad, su lenguaje interno y cómo entiende el concepto central de "Paciente" — porque la forma en que cada contexto ve al paciente revela con precisión la naturaleza de cada contexto.

---

### BC1 — Identidad y Organización

**Responsabilidad:** Gestionar quién existe en el sistema, con qué credenciales accede, a qué organización pertenece y qué configuración general define esa organización.

**Dominio:** Fundacional. Sin este contexto, ningún otro contexto puede operar. Toda entidad de cualquier otro contexto pertenece a una Organización Clínica que existe aquí.

**Lo que sabe hacer:**
- Autenticar al profesional
- Saber que el profesional pertenece a una organización
- Guardar preferencias generales de la organización (nombre, horarios por defecto, zona horaria)
- Determinar si el profesional tiene acceso válido

**Lo que no hace:**
- No sabe qué atenciones realizó el profesional
- No sabe cuánto cobró
- No sabe qué pacientes existen

**El "Paciente" en este contexto:** No existe. El profesional es el sujeto central. El paciente no tiene representación en BC1.

---

### BC2 — Clínico

**Responsabilidad:** Gestionar la identidad clínica del paciente, su historia médica completa y el registro de todo lo que ocurre en cada sesión de atención.

**Dominio:** Core del producto. Si este contexto falla o está incompleto, Agenda Podológica no es un sistema clínico — es solo una agenda.

**Lo que sabe hacer:**
- Registrar y gestionar la identidad del paciente
- Mantener la historia clínica completa (antecedentes, patologías, medicamentos, alergias)
- Registrar lo que ocurrió en cada atención (tratamiento, hallazgos, notas, indicaciones)
- Gestionar fotografías clínicas (documentación visual de la evolución)
- Presentar la evolución clínica longitudinal del paciente (en Fase 1 como vista derivada)

**Lo que no hace:**
- No sabe qué cobros generó el paciente
- No sabe si tiene cita agendada
- No sabe si debe recibir seguimiento
- No sabe si firmó consentimiento

**El "Paciente" en este contexto:** Es un **sujeto clínico**. Tiene antecedentes de salud, recibe tratamientos, su cuerpo evoluciona. El sistema lo conoce por lo que tiene y por lo que se le ha hecho.

---

### BC3 — Agenda

**Responsabilidad:** Gestionar la programación del tiempo clínico del profesional: citas, disponibilidad y la secuencia de compromisos del día.

**Dominio:** Operacional. Convierte el trabajo clínico en algo programado y predecible.

**Lo que sabe hacer:**
- Crear, confirmar, modificar y cancelar citas
- Gestionar la disponibilidad horaria del profesional
- Organizar el día de trabajo
- Registrar qué ocurrió con cada cita (atendida, cancelada, inasistida, reprogramada)

**Lo que no hace:**
- No sabe qué se hizo clínicamente en la cita
- No sabe cuánto se cobró
- No sabe si el paciente debe volver
- No gestiona la disponibilidad de centros médicos externos

**El "Paciente" en este contexto:** Es una **persona con un turno**. El contexto solo necesita saber su nombre, su contacto y para qué tipo de atención viene. No necesita su historia clínica.

---

### BC4 — Seguimiento

**Responsabilidad:** Gestionar la continuidad de la relación con el paciente después de una atención: recordarle que debe volver, confirmar que se reprogramó, asegurar que no se pierda en el tiempo.

**Dominio:** Operacional. Cierra el ciclo asistencial entre atenciones.

**Lo que sabe hacer:**
- Crear seguimientos (manualmente o como consecuencia de una atención)
- Gestionar el ciclo de vida del seguimiento (pendiente → contactado → agendado → completado/vencido/descartado)
- Filtrar pacientes por urgencia de contacto
- Conectar con Agenda para convertir un seguimiento en cita

**Lo que no hace:**
- No sabe qué se hizo clínicamente en la atención que lo originó
- No sabe cuánto se cobró
- No gestiona comunicaciones (no envía mensajes)

**El "Paciente" en este contexto:** Es una **persona que debe volver**. El seguimiento no necesita su historia clínica: necesita saber cuándo fue la última atención, qué tipo de seguimiento requiere y cómo contactarle.

---

### BC5 — Configuración Operacional

**Responsabilidad:** Mantener los catálogos y parámetros que otros contextos consultan para operar: tipos de atención disponibles, valores del arancel y zonas de cobertura domiciliaria.

**Dominio:** Soporte compartido. No tiene valor propio sin los contextos que lo consumen.

**Lo que sabe hacer:**
- Mantener el catálogo de tipos de atención (con nombre, descripción y valor base)
- Gestionar el arancel vigente (valor por tipo de atención, por modalidad)
- Definir zonas domiciliarias con sus recargos

**Lo que no hace:**
- No registra cobros
- No registra atenciones
- No sabe qué pasó en ninguna sesión clínica

**Carácter especial:** Este contexto actúa como **Shared Kernel** — su modelo de "TipoDeAtención" es referenciado tanto por el contexto Clínico (para registrar qué se realizó) como por el contexto Económico (para calcular qué valor cobrar). Esta dualidad es intencional y debe gestionarse con cuidado para que no se convierta en un contexto de dios.

**El "Paciente" en este contexto:** No existe. La configuración es del profesional, no del paciente.

---

### BC6 — Económico

**Responsabilidad:** Registrar el hecho económico de cada atención: cuánto se cobró, a quién, por qué concepto, en qué estado se encuentra el pago y qué medio se usó.

**Dominio:** Operacional y financiero. Convierte el trabajo clínico en registro económico sin ser un sistema contable.

**Lo que sabe hacer:**
- Generar cobros asociados a una atención (o de forma independiente)
- Capturar el monto como snapshot del arancel vigente en ese momento
- Gestionar el estado del pago (pendiente, parcial, pagado, anulado)
- Registrar el medio de pago

**Lo que no hace:**
- No sabe qué se hizo clínicamente
- No gestiona caja ni flujo de caja
- No liquida con centros médicos
- No calcula impuestos
- No emite documentos tributarios

**El "Paciente" en este contexto:** Es un **pagador**. El contexto solo necesita saber quién es el responsable del pago, no su historia clínica.

---

### BC7 — Relaciones Comerciales

**Responsabilidad:** Gestionar la relación de la profesional con entidades externas: centros médicos, sus términos de acuerdo y las liquidaciones periódicas que se derivan de ese trabajo.

**Dominio:** Comercial. No es clínico. Es la interfaz entre la práctica profesional y el mundo externo de negocios.

**Lo que sabe hacer:**
- Registrar centros médicos y los términos de la relación (comisión, valor acordado, modalidad)
- Identificar qué atenciones corresponden a cada centro en un período
- Calcular y confirmar liquidaciones periódicas
- Registrar cambios en los términos del acuerdo con trazabilidad temporal

**Lo que no hace:**
- No sabe qué ocurrió clínicamente en las atenciones del centro
- No gestiona la agenda del centro
- No es un sistema de facturación B2B

**El "Paciente" en este contexto:** Es un **paciente proveniente de un centro** o **administrado por un tercero**. El contexto solo necesita saber el origen del paciente para determinar a qué centro corresponde la liquidación.

---

### BC8 — Documental

**Responsabilidad:** Generar, mantener y preservar documentos clínicos formales: consentimientos informados y reportes de sesión. Gestionar firmas cuando corresponda.

**Dominio:** Clínico-legal. Los documentos aquí tienen implicaciones legales que van más allá de la operación diaria.

**Lo que sabe hacer:**
- Generar informes de sesión a partir de atenciones cerradas
- Generar y gestionar consentimientos informados
- Registrar firmas (del paciente y del profesional)
- Preservar la versión del documento en el momento de su generación o firma
- Permitir entrega del documento (impresión, correo)

**Lo que no hace:**
- No emite documentos tributarios
- No firma contratos comerciales
- No gestiona expedientes legales

**El "Paciente" en este contexto:** Es un **firmante y destinatario**. El contexto necesita sus datos de identificación para el documento y su firma o confirmación para el consentimiento.

---

### BC9 — Analítico

**Responsabilidad:** Proyectar el estado del negocio a través de vistas calculadas y reportes derivados. Es un contexto de solo lectura: no modifica nada.

**Dominio:** Proyección derivada. No tiene datos propios. Existe únicamente para transformar datos de otros contextos en visibilidad operativa.

**Lo que sabe hacer:**
- Presentar el dashboard cotidiano (agenda del día, cobros pendientes, seguimientos urgentes)
- Generar reportes de períodos (ingresos, atenciones por tipo, pacientes activos)
- Agregar información de múltiples contextos en una sola vista

**Lo que no hace:**
- No registra nada
- No modifica nada en ningún otro contexto
- No es el sistema de BI/analytics empresarial

**El "Paciente" en este contexto:** Es un **dato agregado**. No es una persona individual: es un punto en un conteo, un promedio, un porcentaje.

---

## 2. Aggregate Roots

Una raíz de agregado es la entidad que controla y protege la consistencia de un grupo de entidades relacionadas. Para modificar algo dentro del agregado, se debe pasar por la raíz. Las referencias entre agregados distintos se hacen siempre por identidad (no por referencia directa al objeto).

---

### BC1 — Identidad y Organización

**OrganizaciónClínica** (raíz)
- Contiene: configuración general, zona horaria, preferencias operativas
- Protege: que toda entidad del sistema tenga una organización propietaria

**Profesional** (raíz independiente dentro de BC1)
- Contiene: identidad, credenciales de acceso, membresía a la organización
- Protege: que solo accedan al sistema quienes tienen credenciales válidas

*Relación entre raíces:* Profesional referencia a OrganizaciónClínica por identidad. Un Profesional siempre pertenece a una organización.

---

### BC2 — Clínico

**Paciente** (raíz principal)
- Contiene: identidad (nombre, identificación, contacto, dirección), origen del paciente, estado clínico general
- Protege a: HistoriaClínica (que siempre existe y pertenece a un único paciente)
- HistoriaClínica no tiene identidad propia separada del Paciente: existe dentro del agregado Paciente

**AtenciónClínica** (raíz independiente)
- Contiene: todo lo ocurrido en la sesión (tratamiento, hallazgos, notas, indicaciones, estado)
- Referencia externamente por identidad: Paciente, Profesional, OrganizaciónClínica, TipoDeAtención
- Protege: la inmutabilidad del contenido clínico una vez cerrada

**FotografíaClínica** (raíz independiente)
- Contiene: la imagen, sus metadatos, su contexto clínico
- Referencia externamente: Paciente, AtenciónClínica (opcional)
- Protege: la integridad e inmutabilidad de la evidencia visual

*Por qué AtenciónClínica no está dentro del agregado Paciente:* Porque tiene su propio ciclo de vida, su propia lógica de inmutabilidad y su propio contexto de acceso. No es un dato del paciente — es un evento clínico que involucra al paciente.

---

### BC3 — Agenda

**Cita** (raíz)
- Contiene: fecha y hora, duración, tipo de atención prevista, estado, historial de cambios de estado
- Referencia externamente: Paciente (solo nombre y contacto), Profesional, TipoDeAtención (opcional)
- Protege: la consistencia del estado de la cita a través de sus transiciones (no puede pasar de "cancelada" a "confirmada")

---

### BC4 — Seguimiento

**Seguimiento** (raíz)
- Contiene: tipo de seguimiento, urgencia, estado, historial de intentos de contacto, notas
- Referencia externamente: Paciente, AtenciónClínica que lo originó (opcional), Cita resultante (opcional)
- Protege: que el ciclo de vida del seguimiento sea coherente

---

### BC5 — Configuración Operacional

**TipoDeAtención** (raíz)
- Contiene: nombre, descripción clínica, estado (activo/inactivo)
- Protege: que el catálogo sea la fuente de verdad de qué tipos existen

**Arancel** (raíz, dentro de TipoDeAtención o relacionada)
- Contiene: valor base para atención particular, valores por modalidad (Fase 2+)
- Protege: que el valor del arancel vigente sea siempre accesible y que las variaciones históricas no se pierdan

**ZonaDomiciliaria** (raíz)
- Contiene: nombre de la zona, descripción geográfica manual, recargo asociado
- Protege: que las zonas sean válidas y consultables por el contexto Económico

---

### BC6 — Económico

**Cobro** (raíz)
- Contiene: monto capturado (snapshot), tipo de atención aplicado (snapshot de descripción), estado del pago, medio de pago, fecha
- Referencia externamente: Paciente, AtenciónClínica (opcional), Profesional, OrganizaciónClínica
- Protege: la inmutabilidad del hecho económico y la correcta transición del estado de pago

---

### BC7 — Relaciones Comerciales

**RelacióConCentro** (raíz — representa el vínculo, no el centro en sí)
- Contiene: nombre del centro, datos de contacto, modalidad de relación, términos del acuerdo vigente, historial de cambios de términos
- Protege: que los términos del acuerdo estén siempre disponibles para el período correcto

**Liquidación** (raíz independiente)
- Contiene: período cubierto, centro asociado, atenciones incluidas, monto calculado, estado (borrador/confirmada/pagada)
- Referencia externamente: RelacióConCentro, AtenciónClínica (por lista de IDs), Cobros relacionados
- Protege: que una liquidación confirmada sea inmutable

---

### BC8 — Documental

**Consentimiento** (raíz)
- Contiene: versión del documento, datos del paciente capturados al momento, datos del profesional capturados al momento, estado, firma del paciente, firma del profesional, fecha/hora de firma
- Referencia externamente: Paciente, Profesional, AtenciónClínica (opcional)
- Protege: la inmutabilidad del documento firmado

**InformeDeSesión** (raíz)
- Contiene: datos de la atención capturados como snapshot, estado (borrador/generado/entregado)
- Referencia externamente: AtenciónClínica, Paciente, Profesional
- Protege: que el informe generado formalmente preserve la información tal como era al momento de su generación

---

### BC9 — Analítico

Este contexto no tiene Aggregate Roots. Tiene **modelos de lectura** (read models) que se construyen a partir de datos de otros contextos. Sus "objetos" son proyecciones, no entidades con ciclo de vida propio.

Modelos de lectura principales:
- **VistaDashboard** — estado del día del profesional
- **ReporteFinanciero** — cobros y estado económico del período
- **ReporteAsistencial** — atenciones, tipos, pacientes

---

## 3. Entidades por contexto

Esta sección detalla qué vive dentro de cada contexto, distinguiendo raíces de agregado, entidades contenidas y objetos de valor.

---

### BC1 — Identidad y Organización

| Concepto | Tipo | Descripción |
|---|---|---|
| OrganizaciónClínica | Aggregate Root | Propietaria de todos los datos del sistema |
| Profesional | Aggregate Root | Quien accede y opera el sistema |
| ConfiguraciónGeneral | Entidad contenida en Organización | Preferencias operativas (horario, zona horaria, etc.) |
| CredencialesAcceso | Objeto de valor de Profesional | Email, contraseña, estado de la cuenta |
| MembresíaOrganización | Objeto de valor de Profesional | Vínculo entre Profesional y Organización |

---

### BC2 — Clínico

| Concepto | Tipo | Descripción |
|---|---|---|
| Paciente | Aggregate Root | Identidad completa del paciente |
| HistoriaClínica | Entidad contenida en Paciente | Perfil clínico completo |
| EntradaClínica | Objeto de valor en HistoriaClínica | Cada antecedente, patología o medicamento registrado |
| AtenciónClínica | Aggregate Root | Registro de una sesión clínica |
| ContenidoClínico | Objeto de valor en AtenciónClínica | Tratamiento, hallazgos, notas, indicaciones |
| FotografíaClínica | Aggregate Root | Evidencia visual del paciente |
| EvolucióClínica | Modelo de lectura (Fase 1) | Vista derivada del historial de atenciones |

---

### BC3 — Agenda

| Concepto | Tipo | Descripción |
|---|---|---|
| Cita | Aggregate Root | Un bloque de tiempo clínico programado |
| DisponibilidadHoraria | Entidad contenida | Configuración de horarios disponibles del profesional |
| TransiciónDeCita | Objeto de valor en Cita | Registro de cada cambio de estado de la cita |

---

### BC4 — Seguimiento

| Concepto | Tipo | Descripción |
|---|---|---|
| Seguimiento | Aggregate Root | Gestión de la continuidad post-atención |
| IntentoDeContacto | Objeto de valor en Seguimiento | Registro de cada intento de comunicarse con el paciente |

---

### BC5 — Configuración Operacional

| Concepto | Tipo | Descripción |
|---|---|---|
| TipoDeAtención | Aggregate Root | Categoría clínica y de facturación |
| ValorArancel | Objeto de valor en TipoDeAtención | Precio para un contexto de atención (particular, centro, etc.) |
| ZonaDomiciliaria | Aggregate Root | Área geográfica con recargo de traslado |
| RecargoDomiciliario | Objeto de valor en ZonaDomiciliaria | Valor adicional por traslado a esa zona |

---

### BC6 — Económico

| Concepto | Tipo | Descripción |
|---|---|---|
| Cobro | Aggregate Root | El hecho económico de una atención |
| SnapshotEconómico | Objeto de valor en Cobro | Tipo de atención y monto capturados al momento del registro |
| TransiciónDePago | Objeto de valor en Cobro | Cada cambio de estado del cobro |

---

### BC7 — Relaciones Comerciales

| Concepto | Tipo | Descripción |
|---|---|---|
| RelaciónConCentro | Aggregate Root | Vínculo comercial con un centro médico externo |
| AcuerdoComercial | Entidad contenida | Términos vigentes (comisión, valores acordados) |
| HistorialDeAcuerdos | Objeto de valor | Versiones anteriores del acuerdo con fechas |
| Liquidación | Aggregate Root | Resumen económico de un período con un centro |
| ÍtemDeLiquidación | Entidad contenida en Liquidación | Cada atención incluida en la liquidación |

---

### BC8 — Documental

| Concepto | Tipo | Descripción |
|---|---|---|
| Consentimiento | Aggregate Root | Documento de consentimiento informado |
| FirmaDocumental | Objeto de valor en Consentimiento | Firma, identidad del firmante, fecha/hora, versión del documento |
| VersiónPlantilla | Objeto de valor en Consentimiento | La plantilla exacta usada al momento de la firma |
| InformeDeSesión | Aggregate Root | Reporte de lo realizado en una sesión clínica |
| ContenidoInforme | Objeto de valor en InformeDeSesión | Snapshot de los datos clínicos capturados al momento de generación |

---

### BC9 — Analítico

| Concepto | Tipo | Descripción |
|---|---|---|
| VistaDashboard | Modelo de lectura | Estado del día del profesional |
| ReporteFinanciero | Modelo de lectura | Visión económica del período |
| ReporteAsistencial | Modelo de lectura | Métricas de atenciones y pacientes |

---

## 4. Relaciones entre contextos

Los contextos no se comunican accediendo directamente al modelo interno del otro. Se comunican de tres formas:

**Por identidad:** Un contexto conoce al otro mediante un identificador único. BC3 (Agenda) sabe que la cita es para el Paciente con ID X, pero no accede al modelo de Paciente en BC2. Si necesita el nombre del paciente para mostrar la cita, hace una consulta a BC2 usando ese ID.

**Por eventos:** Cuando algo importante ocurre en un contexto, publica un evento de dominio. Los contextos interesados reaccionan a ese evento de forma asincrónica.

**Por lectura directa de configuración compartida:** BC5 (Configuración Operacional) es un Shared Kernel. BC2 y BC6 pueden leer su catálogo de TiposDeAtención directamente, porque ese catálogo es una referencia de solo lectura.

---

### Mapa de relaciones

```
BC1 — Identidad y Organización
│
│  Toda entidad pertenece a BC1 (por OrganizaciónClínica)
│  Todo acceso pasa por BC1 (autenticación en Profesional)
│
├─────────────────────────────────────────────┐
│                                             │
BC2 — Clínico                         BC5 — Configuración Operacional
│   │   │                                     │
│   │   └──────── lee catálogo ───────────────┘
│   │                                         │
│   ├── notifica ──► BC3 — Agenda             │
│   │                │                        │
│   ├── notifica ──► BC4 — Seguimiento        │
│   │                                         │
│   └── notifica ──► BC6 — Económico ◄── lee valor arancel ──┘
│                    │
│                    └── notifica ──► BC7 — Relaciones Comerciales
│
└── provee datos ──► BC8 — Documental
│
└── todos proveen datos ──► BC9 — Analítico (solo lectura)
```

---

### Cómo interactúa cada par de contextos relevante

**BC2 → BC3 (Clínico → Agenda)**
Cuando se registra una atención en BC2, el profesional puede ver la cita del día desde BC3. La cita no tiene contenido clínico: solo tiene nombre del paciente y tipo de atención previsto. Cuando la cita se "atiende", BC3 publica un evento que BC2 puede usar para facilitar la creación de una nueva atención.

**BC2 → BC4 (Clínico → Seguimiento)**
Cuando una atención clínica se cierra, BC2 publica un evento que BC4 puede consumir para evaluar si debe crearse un seguimiento automático. BC4 no necesita el contenido clínico de la atención: solo necesita saber que ocurrió y cuándo.

**BC2 → BC6 (Clínico → Económico)**
Cuando una atención clínica se cierra, BC6 puede recibir el evento y facilitar la generación del cobro correspondiente. BC6 captura el tipo de atención y el valor del arancel como snapshot en ese momento. BC6 nunca modifica BC2: el cobro es consecuencia de la atención, no parte de ella.

**BC5 → BC2 y BC6 (Configuración → Clínico y Económico)**
BC2 lee el catálogo de TiposDeAtención para saber qué opciones existen al registrar una atención. BC6 lee el valor del arancel para el tipo de atención al generar el cobro. Ambos leen en modo consulta. Ninguno modifica BC5.

**BC6 → BC7 (Económico → Relaciones Comerciales)**
Cuando un cobro corresponde a una atención en un centro médico, BC7 lo toma en cuenta para la liquidación del período. BC7 accede a BC6 para construir la liquidación, pero no modifica los cobros: solo los agrega al cálculo.

**BC2 → BC8 (Clínico → Documental)**
BC8 necesita datos de BC2 para generar documentos: el nombre del paciente, el profesional, el contenido de la atención. Cuando genera el documento, captura esos datos como snapshot. BC8 no modifica BC2.

**Todos → BC9 (Todos → Analítico)**
BC9 lee de todos los demás contextos en modo solo lectura. No tiene acceso de escritura a ninguno. El Dashboard del profesional es construido por BC9 leyendo la agenda del día (BC3), los cobros pendientes (BC6), los seguimientos urgentes (BC4) y el resumen de atenciones recientes (BC2).

---

## 5. Eventos que cruzan contextos

Los eventos de dominio son hechos que han ocurrido dentro de un contexto y que otros contextos necesitan conocer. Los eventos son inmutables: representan algo que ya pasó.

---

### AtenciónClínicaCerrada

**Publicado por:** BC2 — Clínico  
**Cuándo ocurre:** El profesional cierra formalmente el registro de una sesión clínica  
**Datos que lleva:** ID de la atención, ID del paciente, ID del profesional, tipo de atención realizado, fecha/hora de cierre, modalidad (particular / centro / domiciliaria)

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC6 — Económico | Facilita la generación del cobro correspondiente |
| BC4 — Seguimiento | Evalúa si corresponde crear un seguimiento |
| BC8 — Documental | Habilita la generación del informe de sesión |
| BC9 — Analítico | Actualiza métricas del dashboard y reportes |

---

### CobroGenerado

**Publicado por:** BC6 — Económico  
**Cuándo ocurre:** Se registra un nuevo cobro en el sistema  
**Datos que lleva:** ID del cobro, ID del paciente, monto capturado, tipo de atención (snapshot), estado inicial, fecha, modalidad

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC7 — Relaciones Comerciales | Si la modalidad es "centro médico", lo registra para la liquidación del período |
| BC9 — Analítico | Actualiza el resumen financiero del dashboard |

---

### CobroAnulado

**Publicado por:** BC6 — Económico  
**Cuándo ocurre:** Un cobro es marcado como anulado  
**Datos que lleva:** ID del cobro, motivo de anulación, quién anuló, fecha/hora

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC7 — Relaciones Comerciales | Si el cobro estaba en una liquidación en borrador, lo excluye |
| BC9 — Analítico | Corrige el resumen financiero |

---

### ConsentimientoFirmado

**Publicado por:** BC8 — Documental  
**Cuándo ocurre:** El consentimiento informado recibe las firmas del paciente y el profesional  
**Datos que lleva:** ID del consentimiento, ID del paciente, ID del profesional, versión del documento, fecha/hora de la firma

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC2 — Clínico | Puede asociar el consentimiento al registro del paciente como referencia histórica |
| BC9 — Analítico | Registra la acción para trazabilidad de auditoría |

---

### SeguimientoCreado

**Publicado por:** BC4 — Seguimiento  
**Cuándo ocurre:** Se crea un nuevo seguimiento, ya sea automáticamente o manualmente  
**Datos que lleva:** ID del seguimiento, ID del paciente, urgencia, tipo de seguimiento, origen (manual / automático desde atención)

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC3 — Agenda | Puede facilitar la creación de una cita para resolver el seguimiento |
| BC9 — Analítico | Actualiza el contador de seguimientos pendientes en el dashboard |

---

### SeguimientoResuelto

**Publicado por:** BC4 — Seguimiento  
**Cuándo ocurre:** Un seguimiento es marcado como completado o descartado  
**Datos que lleva:** ID del seguimiento, ID del paciente, estado final, fecha/hora de resolución

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC9 — Analítico | Actualiza el contador de seguimientos activos |

---

### CitaModificada

**Publicado por:** BC3 — Agenda  
**Cuándo ocurre:** Una cita cambia de estado (reprogramada, cancelada, confirmada, marcada como inasistida)  
**Datos que lleva:** ID de la cita, ID del paciente, estado anterior, estado nuevo, fecha/hora del cambio, motivo (cuando aplica)

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC4 — Seguimiento | Si la cita fue cancelada, puede necesitar reactivar el seguimiento |
| BC9 — Analítico | Actualiza la agenda del dashboard |

---

### LiquidaciónConfirmada

**Publicado por:** BC7 — Relaciones Comerciales  
**Cuándo ocurre:** Una liquidación es aceptada y confirmada por ambas partes  
**Datos que lleva:** ID de la liquidación, ID del centro, período, monto total confirmado, fecha de confirmación

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC6 — Económico | Marca los cobros del período como "liquidados" |
| BC9 — Analítico | Actualiza el resumen de liquidaciones del período |

---

### PacienteRegistrado

**Publicado por:** BC2 — Clínico  
**Cuándo ocurre:** Se registra un nuevo paciente en el sistema  
**Datos que lleva:** ID del paciente, ID de la organización, fecha de registro

**Consumidores:**

| Contexto consumidor | Reacción |
|---|---|
| BC9 — Analítico | Actualiza el total de pacientes activos |

---

## 6. Dependencias permitidas

Una dependencia permitida significa que un contexto puede conocer la identidad de una entidad del otro contexto y puede consultarle información. Las dependencias se declaran aquí porque en la implementación técnica cada una representa una decisión explícita de diseño.

La regla general: **las dependencias fluyen hacia arriba** (desde contextos especializados hacia contextos fundacionales) y **nunca en sentido inverso** hacia el dominio clínico.

```
                  BC1 — Identidad y Organización
                 ↑         ↑       ↑       ↑
    BC2        BC3        BC4     BC6     BC7
  Clínico    Agenda   Seguim.  Económ.  Com.
     ↑                    ↑       ↑
    BC8                  BC4    BC7
  Documental          Seguim.  Com.
                              ↑
                             BC9
                           Analítico
```

**Dependencias explícitamente permitidas:**

| Contexto | Puede depender de | Tipo de dependencia |
|---|---|---|
| BC2 — Clínico | BC1 — Identidad | Para saber a qué organización pertenece el paciente |
| BC3 — Agenda | BC1 — Identidad | Para saber quién agenda |
| BC3 — Agenda | BC2 — Clínico | Para obtener nombre/contacto del paciente al mostrar cita |
| BC3 — Agenda | BC5 — Configuración | Para mostrar tipos de atención al agendar |
| BC4 — Seguimiento | BC1 — Identidad | Para saber a qué organización pertenece |
| BC4 — Seguimiento | BC2 — Clínico | Para conocer la fecha de última atención del paciente |
| BC4 — Seguimiento | BC3 — Agenda | Para crear cita desde un seguimiento |
| BC5 — Configuración | BC1 — Identidad | Para saber qué organización define la configuración |
| BC6 — Económico | BC1 — Identidad | Para saber a qué organización pertenece el cobro |
| BC6 — Económico | BC2 — Clínico | Para conocer el paciente y la atención que origina el cobro |
| BC6 — Económico | BC5 — Configuración | Para obtener el valor del arancel vigente |
| BC7 — Relaciones Comerciales | BC1 — Identidad | Para saber a qué organización pertenece el acuerdo |
| BC7 — Relaciones Comerciales | BC6 — Económico | Para obtener los cobros del período a liquidar |
| BC8 — Documental | BC1 — Identidad | Para obtener datos del profesional para los documentos |
| BC8 — Documental | BC2 — Clínico | Para obtener datos del paciente y la atención al generar documentos |
| BC9 — Analítico | Todos los contextos | Solo lectura, para proyección y reportes |

---

## 7. Dependencias prohibidas

Una dependencia prohibida rompe la arquitectura conceptual y crea acoplamiento que dificulta el crecimiento independiente de cada contexto. Las que se listan aquí no son errores técnicos ocasionales: son decisiones de diseño incorrectas que corrompen el modelo.

---

**BC2 — Clínico no debe depender de BC6 — Económico**

La clínica no sabe de dinero. Una atención existe y tiene valor clínico independientemente de si fue cobrada. Si BC2 dependiera de BC6, no podría registrarse una atención sin que exista un cobro, o los datos clínicos estarían contaminados con lógica financiera.

---

**BC2 — Clínico no debe depender de BC3 — Agenda**

Un paciente existe, tiene historia clínica y puede ser atendido sin que nunca haya tenido una cita. La atención clínica debe poder registrarse sin depender del sistema de agenda. Si BC2 dependiera de BC3, no podría registrarse una atención espontánea o de urgencia.

---

**BC2 — Clínico no debe depender de BC8 — Documental**

Los documentos clínicos son consecuencias de la atención, no condiciones previas. Si BC2 dependiera de BC8, una atención no podría cerrarse sin que exista un documento firmado — lo cual es conceptualmente incorrecto y operacionalmente bloqueante.

---

**BC3 — Agenda no debe depender de BC6 — Económico**

La agenda no sabe si el paciente tiene cobros pendientes. La gestión de tiempo y la gestión de pagos son dominios separados. Si BC3 dependiera de BC6, el profesional no podría agendar un paciente con deuda — esa restricción puede ser un comportamiento futuro opcional, pero no una dependencia estructural.

---

**BC6 — Económico no debe depender de BC8 — Documental**

Los cobros existen y son válidos sin documentos firmados. La facturación no espera el consentimiento. Si BC6 dependiera de BC8, no podría registrarse un cobro sin documento adjunto.

---

**BC7 — Relaciones Comerciales no debe depender de BC2 — Clínico**

Las liquidaciones no necesitan acceso al contenido clínico de las atenciones. Solo necesitan saber cuántas atenciones del tipo acordado ocurrieron en el período. Si BC7 dependiera de BC2, los datos clínicos quedarían expuestos a un contexto puramente comercial.

---

**BC5 — Configuración no debe depender de BC2, BC3, BC4, BC6, BC7, BC8**

La configuración operacional no debe conocer ningún dato transaccional del negocio. Los tipos de atención y el arancel son parámetros independientes de lo que haya ocurrido en el sistema. Si BC5 dependiera de datos transaccionales, se rompería la separación entre configuración y operación.

---

**BC1 — Identidad no debe depender de ningún otro contexto**

BC1 es el fundamento. Si BC1 necesitara consultar datos de BC2 para funcionar, el sistema no podría autenticar a nadie hasta que existieran datos clínicos. La identidad y la organización son el suelo sobre el que todo lo demás se construye.

---

**BC9 — Analítico no debe escribir en ningún contexto**

BC9 es pura lectura. Si BC9 empezara a modificar datos para "mejorar la presentación" o "corregir inconsistencias detectadas", se rompería la integridad del modelo completo. El Analítico observa; no interviene.

---

## 8. Riesgos futuros

---

### Riesgo 1 — BC6 Económico crecerá hacia ERP si no se contiene

El contexto Económico empieza como registro de cobros. La presión natural del uso real empujará hacia caja diaria, deudores, comprobantes, impuestos, contabilidad y gestión de flujo. Cada una de esas funcionalidades parece "solo un paso más" desde el cobro básico.

La señal de alerta es cuando alguien pida que el sistema "calcule el IVA" o "cuadre la caja con el banco". En ese momento BC6 estaría tratando de convertirse en un sistema contable.

**Respuesta:** BC6 debe crecer internamente (liquidaciones, cobros múltiples, medios de pago) pero nunca absorbiendo lógica tributaria o contable. Si esa necesidad surge, debería integrarse con un sistema externo especializado.

---

### Riesgo 2 — BC7 Relaciones Comerciales puede volverse inmanejable

El acuerdo con un centro médico comienza como "20% de comisión". Con el tiempo aparecen: valores diferenciados por tipo de atención, exenciones para ciertos pacientes, topes mensuales, ajustes estacionales, liquidaciones parciales anticipadas. Cada regla parece razonable por separado.

**Respuesta:** Diseñar el agregado AcuerdoComercial de forma que pueda versionar sus reglas sin volver los datos históricos inconsistentes. Cada liquidación debe capturar qué versión del acuerdo aplicó.

---

### Riesgo 3 — BC4 Seguimiento puede absorber funcionalidad CRM

El seguimiento clínico es diferente al marketing de retención. La presión de uso puede empujar hacia envío de mensajes masivos de cumpleaños, campañas de vuelta de temporada o notificaciones automatizadas. Esas capacidades pertenecen a un sistema de comunicaciones, no al contexto de continuidad clínica.

**Respuesta:** BC4 gestiona la decisión de cuándo contactar y el registro de que el contacto ocurrió. El canal y el contenido del contacto pertenecen a un futuro BC (Comunicaciones / M22) que todavía no existe.

---

### Riesgo 4 — BC8 Documental tiene complejidad legal subestimada

El consentimiento informado parece un PDF con firma. En realidad involucra: validez legal de la firma digital en Chile, versionado de la plantilla con responsabilidad clínica, retención mínima obligatoria de documentos clínicos, posibilidad de revocación y sus consecuencias clínicas, y eventual integración con firma electrónica avanzada.

**Respuesta:** BC8 debe ser diseñado conservadoramente en Fase 2, empezando con firma capturada en pantalla y documento preservado como imagen. La complejidad legal debe validarse antes de comprometerse a más.

---

### Riesgo 5 — BC2 Clínico estará bajo presión para absorber Plan de Tratamiento

El Plan de Tratamiento (qué se va a hacer en futuras sesiones) tiene una frontera porosa con la Evolución Clínica (qué se ha hecho hasta ahora). En la práctica clínica, los profesionales frecuentemente documentan ambas cosas juntas.

Si BC2 absorbe el Plan de Tratamiento, se convierte parcialmente en un sistema de gestión terapéutica, con compromisos de largo plazo, seguimiento por objetivos y validación de metas. Eso sobrepasa el alcance actual.

**Respuesta:** Si Plan de Tratamiento debe existir, debe ser una entidad con su propio Aggregate Root en BC2, con límites muy claros respecto de Evolución Clínica y Seguimiento. No debe mezclarse en el contenido de AtenciónClínica.

---

### Riesgo 6 — BC9 Analítico puede crear demanda de data warehouse

El dashboard del día es derivado simple. Los reportes por período son agregaciones. Pero en cuanto el producto madure, la presión hacia comparación histórica, análisis de tendencias, comparación entre pacientes y análisis de eficacia clínica puede convertir BC9 en un requerimiento de analytics complejo que ninguna base de datos transaccional puede satisfacer bien.

**Respuesta:** BC9 debe diseñarse desde el inicio como un contexto separado que puede eventualmente ser alimentado por un modelo de datos propio (materialización de eventos), no como consultas directas sobre tablas transaccionales.

---

### Riesgo 7 — Los eventos entre contextos pueden crear dependencias ocultas

Los Domain Events parecen una comunicación limpia y desacoplada. Pero si cada contexto reacciona a eventos del otro de forma incorrecta — modificando datos del otro contexto, asumiendo que el evento es sincrónico, o fallando silenciosamente sin registro — el sistema puede quedar en estados inconsistentes que son difíciles de diagnosticar.

**Respuesta:** Desde Fase 1, el sistema debe registrar los cinco eventos mínimos de trazabilidad (T00) de forma atómica con la acción que los origina. Los eventos entre contextos deben ser idempotentes: si se procesan dos veces, el resultado es el mismo.

---

### Riesgo 8 — BC5 Configuración puede convertirse en contexto de dios

El Shared Kernel (BC5) es un punto de convergencia natural. A medida que crezcan los contextos que lo consumen, existirá la tentación de agregar lógica al catálogo de tipos de atención: reglas de validación, permisos por tipo, configuración clínica específica. Eso convertiría BC5 en un contexto que sabe demasiado.

**Respuesta:** BC5 debe contener solo catálogos y valores. Cualquier lógica de negocio basada en tipos de atención debe vivir en el contexto que la necesita (BC2 para decisiones clínicas, BC6 para decisiones económicas), no en el catálogo compartido.

---

## Resumen: El modelo en una página

```
Capa fundacional
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC1 · Identidad y Organización
  └─ OrganizaciónClínica · Profesional
     (base de propiedad y acceso para todo lo demás)

Capa clínica (corazón del producto)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC2 · Clínico
  └─ Paciente · HistoriaClínica · AtenciónClínica · FotografíaClínica

Capa operacional (hace funcionar el día a día)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC3 · Agenda       └─ Cita · Disponibilidad
 BC4 · Seguimiento  └─ Seguimiento
 BC5 · Configuración └─ TipoDeAtención · Arancel · Zona

Capa económica
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC6 · Económico               └─ Cobro
 BC7 · Relaciones Comerciales  └─ RelaciónConCentro · Liquidación

Capa documental
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC8 · Documental  └─ Consentimiento · InformeDeSesión

Capa de proyección (solo lectura)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BC9 · Analítico  └─ Dashboard · Reportes
```

---

*Este documento define los límites conceptuales del modelo de datos. No es prescriptivo sobre tecnología, motor de base de datos ni estructura de tablas. Es la descripción de cómo el dominio piensa sobre sus datos — la base sobre la que cualquier implementación técnica posterior debe justificarse.*
