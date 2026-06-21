# Arquitectura Conceptual — Agenda Podológica

**Versión:** 1.1  
**Estado:** Revisado — incorpora observaciones de QA_ARQUITECTURA_CONCEPTUAL_v1.md  
**Fecha original:** Junio 2026  
**Fecha de revisión:** Junio 2026  
**Autor:** Roberto Rojas  
**Revisor QA:** Codex (OpenAI)  
**Fuentes:** DOMINIO_CANONICO_PODOLOGIA_v1.1.md · INSIGHTS_CLIENTE_CONSTANZA_001.md · PROJECT_CHARTER.md · AUDITORIA_FUNCIONAL_BETA.md · QA_ARQUITECTURA_CONCEPTUAL_v1.md

---

## Cambios en esta versión

Esta versión incorpora las observaciones aprobadas de la auditoría conceptual `QA_ARQUITECTURA_CONCEPTUAL_v1.md`. La estructura general del documento y los 22 módulos identificados se conservan. Los cambios son de precisión conceptual y corrección de límites.

- **M02 ↔ M10**: se separan responsabilidades. M02 es propietario de la identidad de la organización y las preferencias generales. M10 es el propietario funcional del catálogo de tipos de atención y valores. M02 puede exponer esa configuración, pero no la posee.
- **M09 Cobros en Fase 1**: se precisa como "registro económico básico de la atención". Se documenta explícitamente qué no es en Fase 1: no es caja, no es ERP, no es gestión tributaria, no es sistema contable.
- **M10 Arancel en Fase 1**: se limita a tipos de atención configurables y valor base para atención particular. La matriz por centro, recargos por zona y reglas comerciales diferenciadas son Fase 2.
- **M12 Zonas Domiciliarias**: se corrige la dependencia conceptual. Zonas depende de la modalidad de atención domiciliaria (M04) y del registro económico básico (M09), no de Centros Médicos (M11).
- **M14 Documentos Clínicos**: se agregan subcapacidades futuras de firma y se abre una decisión explícita sobre si el consentimiento en blanco debe estar disponible como capacidad mínima de Fase 1.
- **M08 Fotografías Clínicas**: se mantiene en Fase 2 y se agrega criterio de reconsideración formal para adelantar captura simple si la validación con Constanza lo exige.
- **Trazabilidad mínima transversal**: se agrega como capacidad fundacional de Fase 1. M21 Auditoría Operacional completa permanece en Fase 3, pero desde Fase 1 el sistema debe registrar quién creó, registró, cerró o modificó cada entidad clínica crítica.
- **M05 Evolución Clínica**: se precisa el criterio para pasar de vista a entidad. Solo ocurre si existe necesidad validada de seguimiento por problema, lesión, pie, dedo o condición longitudinal, sin absorber Plan de Tratamiento.
- **Nuevo principio**: Agenda Podológica no es ERP, no es contabilidad, no es sistema hospitalario.

---

## Propósito de este documento

Este documento transforma el Dominio Canónico y los Insights de Constanza en una arquitectura conceptual de producto: qué módulos tendrá Agenda Podológica, cómo se relacionan, cuál es el corazón irreducible, en qué orden debe construirse y dónde están los riesgos.

No contiene diseño de tablas, SQL, Supabase, APIs ni código. Es el plano funcional del producto antes de que exista una sola línea de implementación.

---

## Principios de esta arquitectura

Antes de enumerar módulos, estos principios rigen cómo se delimitan, priorizan y protegen.

**El núcleo clínico no se sacrifica por ningún módulo periférico.**
La gestión del paciente, su historia clínica y el registro de atenciones son el producto. Todo lo demás existe para enriquecerlos, no para reemplazarlos.

**Un módulo tiene una responsabilidad principal. No dos.**
Cuando un módulo empieza a crecer hacia responsabilidades de otro módulo, no es una señal de éxito: es una señal de que el límite fue mal trazado desde el inicio.

**La Fase 1 debe ser utilizable, no completa.**
Un sistema clínico incompleto es preferible a un sistema clínico inestable. La Fase 1 define el mínimo que convierte la plataforma en una herramienta real de trabajo diario. Nada más.

**El orden de construcción importa tanto como los módulos.**
Un módulo que depende de otro no puede construirse primero. Las dependencias conceptuales determinan el orden de desarrollo.

**La complejidad económica es el riesgo más subestimado.**
Los módulos de cobro, centros médicos y liquidaciones parecen simples al inicio y se convierten en los más complejos. Deben ser delimitados con especial rigor.

**Agenda Podológica no es ERP, no es contabilidad, no es sistema hospitalario.**
Es una herramienta humana para la operación diaria de una podóloga. Cada vez que una funcionalidad empuje al producto hacia la gestión tributaria, la contabilidad de empresa, el módulo hospitalario o el sistema de inventario industrial, ese es el momento de detener el diseño y preguntar si pertenece aquí. La especificidad del producto es una fortaleza, no una limitación.

---

## 1. Módulos del producto

Un módulo es una unidad funcional cohesionada del producto con responsabilidades claras, pantallas propias y límites definidos con otros módulos. La siguiente lista cubre el producto completo, incluyendo fases futuras.

---

### Grupo A — Fundación (transversal)

Estos módulos no pertenecen a ningún dominio clínico específico pero hacen posible que el resto del producto exista, sea seguro y sea trazable.

---

**M01 — Autenticación y Acceso**

Gestiona la identidad del profesional dentro de la plataforma. Registro, inicio de sesión, recuperación de contraseña, cierre de sesión, y validación de que quien accede tiene permiso para hacerlo.

Es la puerta de entrada al sistema. Todo lo demás está detrás de esta puerta.

Responsabilidad única: saber quién es el usuario y si puede entrar.

---

**M02 — Organización y Configuración**

Gestiona la identidad de la organización clínica y las preferencias generales del profesional: nombre del centro o consulta, datos de la profesional, logotipo, información de contacto, y parámetros operativos generales (configuración de agenda, notificaciones, preferencias de registro).

M02 no es el propietario funcional del catálogo de tipos de atención ni de los valores económicos. Esa responsabilidad pertenece a M10. M02 puede exponer el acceso a esa configuración desde una vista unificada de ajustes, pero M10 es quien la posee y valida.

La distinción importa: M02 configura quién es la organización y cómo funciona operativamente. M10 configura qué se cobra y cómo se valoriza el trabajo clínico.

Responsabilidad única: definir la identidad de la organización y sus preferencias de operación.

---

**T00 — Trazabilidad Mínima Transversal (Fase 1)**

La trazabilidad mínima no es un módulo visible: es una capacidad silenciosa que el sistema aplica desde Fase 1 a toda acción clínica relevante. No requiere pantalla propia ni interacción del usuario. Funciona en segundo plano.

M21 Auditoría Operacional es el módulo completo de trazabilidad y pertenece a Fase 3. Pero el Dominio Canónico establece que toda acción relevante es trazable. Fase 1 no puede ignorar este principio.

Las acciones que el sistema debe registrar automáticamente desde Fase 1:

- Quién creó un paciente y cuándo.
- Quién registró una atención y cuándo.
- Quién cerró una atención y cuándo.
- Quién modificó el estado de una cita y cuándo.
- Quién actualizó la historia clínica de un paciente y cuándo.

Esta información no necesita ser consultable desde la interfaz en Fase 1. Debe estar almacenada para cuando M21 exista y pueda leerla. Lo que no se guarda desde el inicio no puede recuperarse después.

Responsabilidad: dejar huella trazable de cada acción clínica crítica desde el primer día de operación.

---

### Grupo B — Núcleo Clínico

Estos módulos son el corazón del producto. Su diseño es el más crítico y el más costoso de cambiar. Un error conceptual aquí se propaga a todo lo demás.

---

**M03 — Pacientes**

Gestiona el registro maestro de los pacientes de la organización: su identidad, datos de contacto, dirección, y el perfil clínico persistente que los acompaña a lo largo de toda su relación con el profesional.

Dentro de este módulo vive la **Historia Clínica**: el registro permanente de antecedentes, patologías, medicamentos, alergias, factores de riesgo y observaciones clínicas de largo plazo. La Historia Clínica no es una pantalla separada del paciente: es la sección clínica de su ficha.

También gestiona el **origen del paciente**: si es particular, proveniente de un centro médico, o agendado por tercero. Este dato afecta cómo se opera el cobro y quién gestiona la relación.

Responsabilidad única: conocer a cada paciente, quién es y qué antecedentes clínicos trae.

---

**M04 — Atención Clínica**

Gestiona el registro de lo que ocurrió en cada sesión clínica. Es la acción central del producto: el momento en que el profesional documenta el trabajo realizado con un paciente.

Contiene: fecha y **modalidad de la atención** (domicilio particular, consultorio propio, centro médico), tipo de atención realizada, tratamientos y procedimientos ejecutados, hallazgos clínicos, notas de la sesión, indicaciones entregadas al paciente, referencia al registro económico asociado, y la sugerencia de próxima atención.

El cierre de una atención es el evento más importante del producto. Debe sentirse como el final natural de una sesión clínica: dejó resuelto qué pasó, qué se cobró y qué sigue. Una atención en borrador puede ajustarse; una atención cerrada es inmutable.

Responsabilidad única: registrar y cerrar cada sesión clínica como un hecho histórico trazable.

---

**M05 — Evolución Clínica**

Proporciona la lectura longitudinal del caso clínico de un paciente: cómo ha evolucionado su estado a través de múltiples atenciones, qué condiciones han mejorado, cuáles persisten, qué tratamientos se han probado.

**En Fase 1 este módulo es una vista enriquecida**, no una entidad con gestión propia. Lee e interpreta los datos del historial de atenciones. No crea registros propios.

**Criterio de transición a entidad (Fase 2 o posterior):** M05 solo pasará de vista a entidad gestionable si se valida en uso real que existe la necesidad de hacer seguimiento explícito por problema clínico específico, lesión, pie, dedo o condición longitudinal concreta. La condición de transición es la necesidad validada, no la preferencia de diseño. Si ese seguimiento por problema puede satisfacerse con una vista bien organizada del historial existente, M05 permanece como vista.

Lo que M05 nunca debe absorber, independientemente de si es vista o entidad: la gestión de objetivos terapéuticos prospectivos. Eso pertenece a M17 Plan de Tratamiento.

Responsabilidad única: hacer que el historial de atenciones sea clínicamente legible y comparativo, no solo cronológicamente listable.

---

### Grupo C — Operacional

Estos módulos organizan la actividad diaria del profesional: cuándo atiende, a quién, y qué debe ocurrir después.

---

**M06 — Agenda**

Gestiona las citas: creación, visualización, confirmación, cancelación, reprogramación e inasistencia. Ofrece una vista del día y de la semana.

La Agenda fue identificada en el documento de visión como "el nervio central del negocio": la herramienta que el profesional consulta decenas de veces al día. Su rendimiento, claridad y rapidez no son características opcionales.

La Agenda no es solo una lista de citas: es el organizador del ritmo de trabajo diario del profesional. Una cita atendida puede convertirse en una Atención Clínica. Una cita cancelada puede derivar en un Seguimiento.

Responsabilidad única: organizar el tiempo del profesional y conectarlo con los pacientes que debe atender.

---

**M07 — Seguimiento y Recordatorios**

Gestiona el estado de la relación con el paciente entre sesiones. Responde a la pregunta: ¿qué debe ocurrir para que este paciente retorne?

Crea seguimientos al cerrar una atención, los mantiene activos mientras el paciente no ha regresado, genera alertas cuando se acerca o supera la fecha sugerida, y se cierra cuando el paciente retorna o el seguimiento es descartado intencionalmente.

Este módulo también alimenta el Dashboard con la lista de seguimientos pendientes y vencidos.

Límite crítico: este módulo gestiona el retorno del paciente, no el objetivo terapéutico del caso. Un seguimiento puede registrar el motivo del retorno esperado ("control de onicocriptosis", "revisión pie diabético"), pero no es responsable de definir el plan clínico, la frecuencia terapéutica ni el criterio de cierre del caso. Eso pertenece a M17 Plan de Tratamiento, que no existe en Fase 1 ni Fase 2.

Responsabilidad única: asegurar que ningún paciente que deba volver quede en el olvido.

---

### Grupo D — Visual Clínico

---

**M08 — Fotografías Clínicas**

Gestiona el registro visual del estado clínico del paciente. Captura o carga imágenes, las asocia a una atención o al perfil clínico del paciente, y permite leerlas longitudinalmente como evidencia de evolución.

Su valor principal no es la imagen individual sino la secuencia: las fotografías tomadas a lo largo del tiempo que muestran si un tratamiento funcionó.

**Fase asignada: Fase 2.** Esta decisión es coherente con el Project Charter y con el principio de que Fase 1 debe ser utilizable, no completa.

**Criterio de reconsideración:** M08 puede adelantarse a Fase 1 como capacidad de captura simple (sin galería longitudinal ni comparación temporal) si la validación con Constanza durante el uso real de Fase 1 muestra que la ausencia de fotografías limita la adopción, interrumpe la continuidad clínica del paciente existente, o impide una comparación visual que la profesional considera esencial para su práctica diaria. Esta reconsideración requiere decisión documentada antes de implementar.

Responsabilidad única: documentar visualmente el estado clínico y hacer esa evidencia comparable en el tiempo.

---

### Grupo E — Económico

Este grupo es el más complejo del producto. Sus módulos parecen simples pero se entrelazan de formas no obvias. Cada módulo de este grupo tiene una responsabilidad específica que no debe solaparse con los demás.

---

**M09 — Cobros**

Gestiona el registro económico asociado al trabajo clínico realizado. Es el módulo que da constancia de la dimensión financiera de cada atención.

**Alcance de Fase 1 — Registro económico básico de la atención:**

Lo que M09 hace en Fase 1:
- Registrar el monto cobrado asociado a una atención.
- Asociar el cobro a un tipo de atención del catálogo (M10).
- Registrar el estado del cobro: pagado, pendiente, pago parcial, anulado.
- Registrar opcionalmente el medio de pago (efectivo, transferencia, otro).

Lo que M09 **no hace** en Fase 1 y no debe hacerse pasar por "básico":
- Gestión de caja diaria o cierre de caja.
- Emisión de boletas, facturas o comprobantes tributarios.
- Cuentas por cobrar con vencimientos complejos.
- Cobros vinculados a centros médicos o liquidaciones.
- Recargos por zona domiciliaria.
- Resúmenes de ingresos por período.
- Cualquier funcionalidad que pertenezca a un sistema contable o ERP.

En Fase 2 M09 se conecta con M11 Centros Médicos y M12 Zonas para soportar los flujos económicos más complejos identificados en los insights de Constanza.

Responsabilidad única: dejar constancia del hecho económico básico que cada atención clínica genera.

---

**M10 — Arancel y Tipos de Atención**

Es el propietario funcional del catálogo de tipos de atención que la profesional ofrece y de los valores asociados a cada uno.

La profesional define desde aquí qué tipos de atención existen en su práctica (podología normal, onicocriptosis, pie diabético, y los que ella cree necesario agregar o renombrar). El catálogo es completamente configurable.

Este catálogo es la fuente que M09 consulta para pre-completar el monto al registrar una atención. La profesional puede ajustar el valor en cada atención individual sin modificar el catálogo base.

**Alcance de Fase 1:**
- Catálogo editable de tipos de atención con nombre y descripción libre.
- Valor base para atención particular (precio estándar del tipo en la práctica propia).
- No incluye: valores diferenciados por centro médico, recargos por zona, reglas de comisión, matrices de precio por convenio o condición especial.

**Alcance de Fase 2:**
- Valores diferenciados por centro médico: el mismo tipo de atención puede tener un precio distinto según en qué centro se realiza, conforme a lo acordado con ese centro.
- Recargo domiciliario por zona (en coordinación con M12).
- Reglas de comisión vinculadas a centros (en coordinación con M11).

Responsabilidad única: definir qué tipos de atención existen y cuánto valen en cada contexto de trabajo.

---

**M11 — Centros Médicos**

Gestiona la relación de la profesional con los centros médicos externos donde trabaja. Cada centro tiene un nombre, una modalidad de relación acordada (comisión por porcentaje, monto fijo por atención, liquidación mensual), y eventualmente una tabla de valores específica para esa relación (gestionada por M10 en Fase 2).

Los pacientes atendidos en un centro pueden ser pacientes derivados por el centro o pacientes propios de la profesional que asisten al centro. Esta distinción afecta quién cobra al paciente y cómo se liquida a la profesional.

Este módulo es Fase 2.

Responsabilidad única: gestionar la relación comercial y operativa de la profesional con cada centro externo donde trabaja.

---

**M12 — Zonas de Atención Domiciliaria**

Gestiona la configuración de zonas geográficas para la atención a domicilio y el recargo diferenciado que aplica a cada zona. La profesional define sus zonas (por nombre o descripción de sector) y asigna un valor adicional a cada una.

Al registrar una atención domiciliaria en M04, la profesional puede indicar la zona. M09 usa esa información para calcular o sugerir el cobro total incluyendo el recargo de traslado.

Este módulo no calcula distancias ni trabaja con mapas: opera sobre zonas definidas manualmente por la profesional.

**Dependencias corregidas:** M12 depende de M04 (que gestiona la modalidad de atención domiciliaria) y de M09 (que registra el cobro sobre el que aplica el recargo de zona). M12 no depende de M11 Centros Médicos: las zonas domiciliarias pertenecen a la atención particular a domicilio, no a la operación en centros. La atención a domicilio en el contexto de un centro médico (si existiera) tiene su propio tratamiento en M11 y M13.

Este módulo es Fase 2.

Responsabilidad única: reflejar el costo real del traslado domiciliario en el cobro de atenciones a domicilio.

---

**M13 — Liquidaciones**

Gestiona el proceso de cierre económico mensual con centros médicos. La profesional ve cuántas atenciones realizó en cada centro durante el período, cuánto le corresponde según lo acordado, cuánto ya recibió y cuánto está pendiente.

Cuando el centro emite una liquidación, la profesional puede comparar lo que el sistema registró contra lo que el centro declaró.

Este módulo es Fase 2, dependiente de M11.

Responsabilidad única: hacer transparente y verificable lo que cada centro médico debe a la profesional.

---

### Grupo F — Documental

---

**M14 — Documentos Clínicos**

Gestiona la generación, personalización y distribución de documentos formales asociados a la práctica clínica. En Fase 2 incluye dos capacidades:

**Consentimiento Informado:** formulario clínico-legal que autoriza la realización de un procedimiento. Puede generarse en blanco para completar a mano, o pre-rellenado con los datos del paciente y la profesional. Es imprimible y enviable por correo electrónico.

**Informe de Sesión:** resumen clínico de una atención ya registrada. Se genera automáticamente con los datos de la atención. Es imprimible y enviable por correo al paciente.

Ambas capacidades requieren: plantillas base configurables, integración con los datos del paciente y la profesional, generación de documento en formato imprimible, y envío por correo electrónico.

**Subcapacidades futuras de firma y trazabilidad documental:**

El consentimiento informado exige firma del paciente y de la profesional. En Fase 2, la firma puede ser manuscrita sobre documento impreso. En Fase 3 o posterior, el módulo deberá soportar:

- Firma simple capturada en pantalla por parte del paciente (trazo sobre dispositivo táctil).
- Firma simple capturada en pantalla por parte de la profesional.
- Registro de fecha y hora exacta de la aceptación.
- Identificación de la versión del documento que fue firmado (para auditoría).
- Trazabilidad documental: qué versión de la plantilla estaba vigente, quién la firmó, cuándo y desde qué dispositivo.

La firma electrónica avanzada (con validez legal equivalente a firma manuscrita) queda fuera de alcance hasta que exista un requerimiento legal o regulatorio específico que la exija en Chile o en el mercado de expansión.

**Decisión abierta — Consentimiento básico en Fase 1:**

Los Insights de Constanza indican que el consentimiento debe estar siempre disponible. M14 completo queda en Fase 2 por complejidad de plantillas, generación de documentos y envío de correo. Sin embargo, existe tensión operativa real: una podóloga que inicia en Fase 1 puede necesitar un consentimiento desde la primera atención.

Esta decisión queda abierta y requiere validación con Constanza antes de la construcción de Fase 1:

- **Opción A:** consentimiento en blanco como archivo estático descargable desde la configuración (sin integración, sin datos del paciente, sin correo). Mínimo esfuerzo, cubre la necesidad básica.
- **Opción B:** no incluir ninguna capacidad de consentimiento en Fase 1 y compensar con instrucciones para uso de formato impreso propio.

Ninguna de estas opciones reemplaza M14 completo. Solo cubren el período entre Fase 1 y Fase 2.

Este módulo es Fase 2 en su versión completa.

Responsabilidad única: producir documentos clínicos formales a partir de los datos que el sistema ya tiene.

---

### Grupo G — Análisis y Gestión

---

**M15 — Dashboard Cotidiano**

La primera pantalla que ve el profesional al abrir la aplicación. Su valor depende de que muestre exactamente lo que necesita saber para organizar su día, sin análisis ni interpretación adicional.

Información que debe mostrar:
- Citas del día con acceso rápido a la ficha del paciente.
- Seguimientos pendientes o vencidos que requieren acción.
- Estimado de cobros del día (lo que hay en agenda y lo que ya se registró).
- Alertas o recordatorios urgentes.

Información que no debe mostrar: estadísticas acumuladas, tendencias, métricas de productividad, gráficos de evolución mensual. Eso pertenece a M16.

El criterio de utilidad del Dashboard es uno solo: al mirarlo, la profesional sabe inmediatamente qué hacer a continuación.

En Fase 1 opera con versión básica: agenda del día + seguimientos pendientes. El resumen financiero cotidiano se incorpora en Fase 2 junto con M09 completo.

Responsabilidad única: orientar la acción diaria del profesional en segundos.

---

**M16 — Reportes**

Proporciona vistas agregadas de la actividad clínica y económica de la organización a lo largo del tiempo. Permite responder preguntas de gestión: pacientes atendidos por período, ingresos por fuente, tasa de retorno, frecuencia de patologías, seguimientos vencidos.

Este módulo no toma decisiones: presenta información para que el profesional las tome.

Este módulo es Fase 2. En Fase 1 no existe porque el valor de un reporte de gestión requiere suficiente historial de datos para ser significativo.

Responsabilidad única: convertir el historial acumulado del sistema en información de gestión clínica y económica.

---

### Grupo H — Módulos futuros (Fase 3 en adelante)

Estos módulos están reconocidos como parte del dominio pero quedan fuera del alcance de Fase 1 y Fase 2. Se listan aquí para que no sean diseñados de forma improvisada cuando llegue su momento.

---

**M17 — Plan de Tratamiento**

Gestiona el objetivo clínico sostenido en el tiempo para un caso complejo: qué se está tratando, con qué frecuencia, con qué indicaciones y bajo qué criterio se cierra. No es un Seguimiento (que gestiona el retorno) ni una Evolución Clínica (que lee lo ocurrido). Es el instrumento clínico prospectivo.

---

**M18 — Derivaciones**

Gestiona las referencias del profesional a otros profesionales o centros. Crea un registro trazable: quién derivó, a quién, por qué, cuándo y qué respuesta llegó.

---

**M19 — Insumos e Inventario**

Gestiona los materiales clínicos utilizados o entregados en cada atención. Control de stock, consumo por período y eventual venta de productos al paciente.

---

**M20 — Multiusuario y Roles**

Permite que más de un profesional opere en la misma organización clínica con roles y permisos diferenciados. Incluye agenda compartida, visibilidad configurable y trazabilidad por usuario.

---

**M21 — Auditoría Operacional**

Módulo completo de trazabilidad operacional: registro consultable de quién hizo qué, cuándo y sobre qué entidad. Quién modificó una ficha, quién canceló una cita, quién registró un cobro. Permite al responsable de la organización revisar la actividad del equipo.

Nota: la trazabilidad mínima (T00) recolecta los datos necesarios desde Fase 1. M21 los hace consultables y auditables desde Fase 3.

---

**M22 — Comunicación con Pacientes**

Canal de contacto directo con el paciente desde la plataforma: recordatorios de cita, mensajes de seguimiento, confirmaciones. En la Beta existía como atajo a WhatsApp. En la versión futura podría incluir mensajería integrada con trazabilidad.

---

## 2. El núcleo del producto

El núcleo es el conjunto mínimo de módulos que, si alguno falta, el producto pierde su razón de existir.

### Núcleo clínico

```
Pacientes (con Historia Clínica)
          ↓
    Atención Clínica
```

Sin pacientes no hay sujeto. Sin atención clínica no hay registro. Estos dos módulos son el corazón irreducible del producto.

### Núcleo operacional

```
    Agenda
```

La Agenda fue descrita en el documento de visión como "el nervio central del negocio": la herramienta que el profesional consulta decenas de veces al día. Un producto sin Agenda es un sistema de fichas, no una plataforma de trabajo clínico.

### El núcleo completo

El núcleo del producto es la intersección de lo clínico y lo operacional:

```
Pacientes (Historia Clínica)  ←→  Atención Clínica
                    ↕
                  Agenda
```

Pacientes provee el contexto. Agenda organiza el tiempo. Atención Clínica es la acción. Los tres juntos constituyen el producto mínimo con sentido.

Todo lo demás depende de este triángulo.

---

## 3. Dependencias conceptuales

Las dependencias muestran qué módulos deben existir para que otro pueda funcionar. El orden de construcción debe respetar estas dependencias: no se puede construir un módulo antes que sus dependencias.

---

### Cadena principal (orden de construcción obligado)

```
M01 Autenticación y Acceso
    ↓
M02 Organización y Configuración
  + T00 Trazabilidad Mínima (activa desde aquí)
    ↓
M03 Pacientes (Historia Clínica)
    ↓
M04 Atención Clínica
    ↓
M06 Agenda ──────────────────────────┐
    ↓                                │
M07 Seguimiento y Recordatorios      │
    ↓                                │
M15 Dashboard Cotidiano ←────────────┘
```

---

### Ramificaciones desde la Atención Clínica

La Atención Clínica es el hub de dependencias más denso del producto. La mayoría de los módulos periféricos dependen de que exista una atención registrada:

```
M04 Atención Clínica
    ├── M05 Evolución Clínica (vista del historial)
    ├── M07 Seguimiento (generado al cerrar atención)
    ├── M08 Fotografías Clínicas (asociadas a una atención)
    ├── M09 Cobros (registro económico originado por atención)
    └── M14 Documentos Clínicos (Informe de Sesión generado desde atención)
```

---

### Ramificaciones del módulo económico

El grupo económico tiene dependencias internas que determinan su orden de construcción. La dependencia de M12 respecto de M11 ha sido corregida en esta versión:

```
M10 Arancel y Tipos de Atención
    ↓ (informa valores a)
M09 Cobros
    ↓ (datos de cobros a centros alimentan)
M13 Liquidaciones
    ↑
M11 Centros Médicos ──→ M10 Arancel (tabla por centro, Fase 2)

M04 Atención Clínica (modalidad domicilio)
    + M09 Cobros
    ↓
M12 Zonas Domiciliarias
```

M12 depende de M04 y M09. No depende de M11. Las zonas domiciliarias son una extensión de la atención particular a domicilio, no de la relación con centros médicos.

---

### Dependencias del módulo de documentos

```
M03 Pacientes ──────────────────┐
M04 Atención Clínica ───────────┼──→ M14 Documentos Clínicos
M02 Organización (datos prof.) ─┘
```

---

### Dependencias del Dashboard

```
M06 Agenda ──────────────────┐
M07 Seguimiento ─────────────┼──→ M15 Dashboard
M09 Cobros (básico) ─────────┘
```

---

## 4. MVP — Módulos obligatorios de Fase 1

La Fase 1 debe producir una plataforma utilizable en la práctica clínica diaria de una podóloga independiente. No tiene que ser completa. Tiene que ser confiable, fluida y suficiente.

Los módulos de Fase 1 responden directamente a las condiciones de éxito del Project Charter:

> "Una podóloga pueda registrar un paciente nuevo y su historia clínica en menos de 3 minutos."  
> "Una podóloga pueda abrir la ficha de un paciente existente, revisar su historial y registrar una nueva atención en el flujo de una consulta real."  
> "La agenda permita visualizar el día, crear citas y cambiar su estado sin fricción."  
> "El sistema de seguimiento permita identificar pacientes con atención pendiente."  
> "Todo lo anterior funcione en un dispositivo móvil con la misma calidad que en escritorio."

---

### Módulos de Fase 1

| Módulo | Alcance en Fase 1 | Justificación |
|---|---|---|
| **M01 — Autenticación** | Completo | Sin esto no hay plataforma. |
| **M02 — Organización** | Básico (identidad + preferencias generales) | Perfil de la organización y parámetros operativos. Sin catálogo de atenciones (eso es M10). |
| **T00 — Trazabilidad mínima** | Activo silencioso | Registro de quién/cuándo para entidades clínicas críticas. Base para M21 futuro. |
| **M03 — Pacientes** | Completo | Núcleo. Sin pacientes no hay producto. |
| **M04 — Atención Clínica** | Completo | Corazón clínico del sistema. |
| **M05 — Evolución Clínica** | Vista enriquecida del historial | Accesible desde la ficha del paciente. No requiere módulo gestionable independiente. |
| **M06 — Agenda** | Completo | "El nervio central del negocio". Obligatorio. |
| **M07 — Seguimiento** | Básico (generación + alertas + cierre) | Crítico para la recurrencia podológica. |
| **M09 — Cobros** | Registro económico básico de la atención | Monto + tipo + estado + medio de pago opcional. No caja, no ERP, no liquidaciones. |
| **M10 — Arancel** | Catálogo de tipos + valor base particular | Evita escribir montos desde cero. Sin matriz por centro. |
| **M15 — Dashboard** | Básico (agenda del día + seguimientos pendientes) | Orienta la operación diaria. Resumen financiero se incorpora en Fase 2. |

---

### Qué queda fuera de Fase 1 y por qué

| Módulo | Motivo de exclusión |
|---|---|
| M08 — Fotografías Clínicas | Decisión del Project Charter. Criterio de reconsideración documentado en M08. |
| M11 — Centros Médicos | Requiere M09 y M10 maduros. Complejidad elevada. Fase 2. |
| M12 — Zonas Domiciliarias | Requiere M04 y M09 maduros. Complejidad de valorización domiciliaria. Fase 2. |
| M13 — Liquidaciones | Requiere M11. Fase 2. |
| M14 — Documentos Clínicos | Requiere M03 y M04 maduros. Complejidad de generación de documentos y firma. Fase 2. Decisión abierta sobre consentimiento estático básico. |
| M16 — Reportes | Sin historial suficiente, los reportes no aportan valor. Fase 2. |
| M17–M22 — Módulos futuros | Fase 3 en adelante. |

---

## 5. Fases futuras

---

### Fase 2 — Operación completa de una podóloga independiente

El objetivo de Fase 2 es cubrir la operación completa de una podóloga que trabaja sola con pacientes particulares, en centros médicos, con atenciones domiciliarias, con documentación clínica formal y con visión económica de su práctica.

Módulos nuevos en Fase 2:
- **M08** — Fotografías Clínicas (o antes si lo valida el criterio de reconsideración)
- **M11** — Centros Médicos
- **M12** — Zonas de Atención Domiciliaria
- **M13** — Liquidaciones
- **M14** — Documentos Clínicos completos (Consentimiento + Informe de Sesión)
- **M16** — Reportes básicos

Módulos de Fase 1 que se enriquecen en Fase 2:
- **M05** — Evolución Clínica: puede pasar a entidad si se valida la necesidad según el criterio definido.
- **M09** — Cobros: se conecta con M11 y M12 para soportar cobros por centro y recargos domiciliarios.
- **M10** — Arancel: se expande con tablas de valores diferenciadas por centro médico.
- **M15** — Dashboard: incorpora resumen financiero cotidiano.

---

### Fase 3 — Plataforma para centros con múltiples profesionales

El objetivo de Fase 3 es que la plataforma soporte organizaciones con más de un profesional: agenda compartida, visibilidad configurable, trazabilidad operacional consultable y herramientas de gestión del equipo clínico.

Módulos nuevos en Fase 3:
- **M20** — Multiusuario y Roles
- **M21** — Auditoría Operacional (que hace consultables los datos de T00)

Módulos existentes que escalan en Fase 3:
- **M02** — Organización: soporte para múltiples profesionales, sedes, roles y configuración de acceso.
- **M06** — Agenda: agenda compartida entre profesionales y vistas por profesional.
- **M15** — Dashboard: versión administrativa para el responsable del centro.
- **M16** — Reportes: reportes de equipo y productividad comparativa.

---

### Fase 4 — Ecosistema clínico avanzado

El objetivo de Fase 4 es extender la plataforma hacia capacidades clínicas que requieren mayor madurez del sistema y de la base de usuarios.

Módulos nuevos en Fase 4:
- **M17** — Plan de Tratamiento
- **M18** — Derivaciones
- **M19** — Insumos e Inventario
- **M22** — Comunicación con Pacientes

---

## 6. Riesgos arquitectónicos

---

### Riesgo 1 — Cobros puede convertirse en sistema contable

**Por qué:** el cobro empieza como "monto por atención" pero los insights de Constanza revelan realidad más compleja: cobros directos, cobros por centro, cobros con comisión, cobros diferenciados por zona, pagos parciales, liquidaciones mensuales, saldos pendientes, cuentas por cobrar. Sin control de alcance en cada fase, este módulo crece hacia un sistema contable dentro de la plataforma clínica.

**Cómo mitigarlo:** el alcance de M09 en Fase 1 está explicitamente delimitado como registro económico básico. Las preguntas que Fase 1 responde son dos: ¿cuánto cobra esta atención? ¿está pagado? Todo lo que va más allá de esas dos preguntas no entra en Fase 1 aunque parezca razonable.

---

### Riesgo 2 — Centro Médico tiene tentáculos en múltiples módulos

**Por qué:** Centro Médico toca: Pacientes (origen del paciente), Agenda (quién agenda), Cobros (quién cobra y cuánto), Arancel (tabla por centro), Liquidaciones (qué le deben a la profesional). Un módulo con cinco puntos de contacto puede generar dependencias circulares y lógica dispersa si no se diseña con cuidado.

**Cómo mitigarlo:** tratar al Centro Médico como entidad de referencia que otros módulos consultan, no como módulo que se introduce en la lógica de otros. M11 sabe quién es el centro y qué acordó con la profesional. Lo demás (cobrar, registrar, liquidar) lo gestionan otros módulos que lo referencian.

---

### Riesgo 3 — Seguimiento puede absorber responsabilidades del Plan de Tratamiento

**Por qué:** Seguimiento ya gestiona retorno del paciente, recordatorios, estados de contacto y vencimientos. Si se le agrega "qué estamos tratando", "cuántas sesiones lleva el plan" y "bajo qué criterio cerramos el caso", el módulo está haciendo el trabajo de un sistema de planes terapéuticos.

**Cómo mitigarlo:** el criterio de corte es explícito: Seguimiento gestiona el retorno. Plan de Tratamiento gestiona el objetivo clínico. Mientras M17 no exista, Seguimiento puede registrar el motivo del retorno esperado pero no es responsable del plan.

---

### Riesgo 4 — El Dashboard puede perder su naturaleza operacional

**Por qué:** la presión de agregar "una métrica más" es permanente. Cada módulo tiene datos que "sería útil ver ahí". Con el tiempo el Dashboard deja de ser operacional y se convierte en un panel de análisis, que es exactamente lo que Constanza rechaza.

**Cómo mitigarlo:** el Dashboard tiene un criterio de admisión estricto y único: solo entra lo que permite tomar una acción concreta en el próximo minuto. Si no dispara acción inmediata, pertenece a Reportes.

---

### Riesgo 5 — Documentos Clínicos esconde complejidad técnica y legal

**Por qué:** Consentimiento Informado e Informe de Sesión parecen "simples de generar". La realidad involucra: gestión de plantillas con variables, generación de documento imprimible, integración de datos del paciente y la profesional, envío por correo electrónico, y firma. La firma en particular tiene dimensiones legales: ¿qué validez tiene una firma capturada en pantalla en Chile? ¿Se requiere firma electrónica avanzada para determinados procedimientos?

**Cómo mitigarlo:** no tratar este módulo como feature pequeño. Requiere decisiones concretas sobre motor de plantillas, generación de documentos y marco legal de firma antes de construirse. La decisión abierta sobre consentimiento básico en Fase 1 debe resolverse antes de comenzar el desarrollo de Fase 1.

---

### Riesgo 6 — El núcleo clínico es el más caro de cambiar

**Por qué:** Pacientes, Historia Clínica y Atención Clínica son la base de todo. Un error conceptual aquí se propaga a Evolución Clínica, Seguimiento, Cobros, Fotografías y Documentos. Cambiar la estructura de una Atención Clínica después de que hay datos reales en producción es la operación más costosa que puede ocurrir.

**Cómo mitigarlo:** invertir proporcionalmente más tiempo de diseño conceptual en M03 y M04 que en cualquier otro módulo. La Atención Clínica requiere consenso explícito sobre: qué información contiene exactamente, cuándo pasa de borrador a registrada, cuándo se considera cerrada, qué es inmutable y qué puede anotarse después sin vulnerar la inmutabilidad.

---

### Riesgo 7 — Evolución Clínica como entidad vs. vista

**Por qué:** si M05 se convierte prematuramente en entidad gestionable sin criterio validado, puede crear duplicación de información respecto a Atención Clínica o absorber funcionalidad de Plan de Tratamiento que todavía no existe.

**Cómo mitigarlo:** el criterio de transición está documentado en la descripción de M05. No se toma la decisión por anticipado. Se toma cuando exista evidencia de uso real que la justifique.

---

### Riesgo 8 — Trazabilidad recolectada tardíamente no puede recuperarse

**Por qué:** M21 Auditoría Operacional está en Fase 3. Si los datos de trazabilidad no se recolectan desde Fase 1, cuando M21 exista no habrá historial previo disponible. Lo que no se guardó desde el inicio no puede reconstruirse.

**Cómo mitigarlo:** T00 Trazabilidad Mínima está activa desde Fase 1 como capacidad silenciosa. Los datos se almacenan aunque no sean consultables desde la interfaz hasta que M21 los exponga.

---

## 7. Mapa conceptual completo

Representación textual del producto completo por capas funcionales. La posición en el mapa refleja dependencias: lo que está más abajo depende de lo que está encima.

```
╔══════════════════════════════════════════════════════════════════════╗
║                           TRANSVERSAL                               ║
║        M01 Autenticación · M02 Organización y Configuración         ║
║              T00 Trazabilidad Mínima (silenciosa, Fase 1)           ║
╠══════════════════════════════════════════════════════════════════════╣
║                        NÚCLEO CLÍNICO                               ║
║                                                                      ║
║           M03 Pacientes ──── Historia Clínica (integrada)           ║
║                    │                                                 ║
║                    ▼                                                 ║
║              M04 Atención Clínica                                   ║
║                    │                                                 ║
║                    ▼                                                 ║
║         M05 Evolución Clínica (vista Fase 1 → entidad si validado)  ║
╠══════════════════════════════════════════════════════════════════════╣
║    OPERACIONAL (Fase 1)          │     VISUAL CLÍNICO (Fase 2)      ║
║                                  │                                   ║
║  M06 Agenda                      │  M08 Fotografías Clínicas        ║
║  M07 Seguimiento y Recordatorios │  (criterio de reconsideración)   ║
║  M15 Dashboard Cotidiano         │                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                    ECONÓMICO                                         ║
║                                                                      ║
║  M09 Cobros (registro básico Fase 1 → completo Fase 2)              ║
║  M10 Arancel y Tipos (catálogo Fase 1 → matriz por centro Fase 2)   ║
║  M11 Centros Médicos (Fase 2)                                       ║
║  M12 Zonas Domiciliarias (Fase 2, depende M04 + M09, no M11)        ║
║  M13 Liquidaciones (Fase 2, depende M11)                            ║
╠══════════════════════════════════════════════════════════════════════╣
║   DOCUMENTAL (Fase 2)            │   ANÁLISIS Y GESTIÓN             ║
║                                  │                                   ║
║  M14 Documentos Clínicos         │  M16 Reportes (Fase 2)           ║
║   · Consentimiento Informado     │                                   ║
║   · Informe de Sesión            │                                   ║
║   · Firma y trazabilidad (F3)    │                                   ║
║   [Decisión abierta: F1 básico]  │                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                         FUTURO (Fase 3+)                            ║
║                                                                      ║
║  M17 Plan de Tratamiento         M20 Multiusuario y Roles           ║
║  M18 Derivaciones                M21 Auditoría Operacional          ║
║  M19 Insumos e Inventario        M22 Comunicación con Pacientes     ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

### Resumen de fases por módulo

| Módulo | Nombre | Fase |
|---|---|---|
| M01 | Autenticación y Acceso | Fase 1 |
| M02 | Organización y Configuración | Fase 1 (identidad + prefs, sin catálogo de atenciones) |
| T00 | Trazabilidad Mínima Transversal | Fase 1 (silenciosa) |
| M03 | Pacientes (Historia Clínica) | Fase 1 |
| M04 | Atención Clínica | Fase 1 |
| M05 | Evolución Clínica | Fase 1 (vista) → entidad solo si necesidad validada |
| M06 | Agenda | Fase 1 |
| M07 | Seguimiento y Recordatorios | Fase 1 (básico) |
| M08 | Fotografías Clínicas | Fase 2 (criterio de reconsideración documentado) |
| M09 | Cobros | Fase 1 (registro básico) → Fase 2 (completo con centros y zonas) |
| M10 | Arancel y Tipos de Atención | Fase 1 (catálogo + valor base particular) → Fase 2 (matriz por centro) |
| M11 | Centros Médicos | Fase 2 |
| M12 | Zonas de Atención Domiciliaria | Fase 2 (depende M04 + M09) |
| M13 | Liquidaciones | Fase 2 (depende M11) |
| M14 | Documentos Clínicos | Fase 2 completo (decisión abierta sobre consentimiento básico en F1) |
| M15 | Dashboard Cotidiano | Fase 1 (básico) → Fase 2 (con resumen financiero) |
| M16 | Reportes | Fase 2 |
| M17 | Plan de Tratamiento | Fase 3 |
| M18 | Derivaciones | Fase 3 |
| M19 | Insumos e Inventario | Fase 3 |
| M20 | Multiusuario y Roles | Fase 3 |
| M21 | Auditoría Operacional | Fase 3 (lee datos de T00 desde Fase 1) |
| M22 | Comunicación con Pacientes | Fase 3 |

---

*Este documento es el plano funcional del producto. No describe cómo se implementa: describe qué existe, cómo se relaciona y en qué orden debe construirse.*  
*Cualquier cambio al alcance de un módulo, incorporación de un módulo nuevo o cambio en la asignación de fases requiere revisión y nueva versión de este documento antes de impactar en el desarrollo.*
