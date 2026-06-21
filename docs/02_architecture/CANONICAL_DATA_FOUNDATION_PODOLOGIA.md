# Canonical Data Foundation — Agenda Podológica

**Versión:** 1.0  
**Estado:** Fundacional  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuentes:** DOMINIO_CANONICO_PODOLOGIA_v1.1.md · ARQUITECTURA_CONCEPTUAL_v1.1.md · INSIGHTS_CLIENTE_CONSTANZA_001.md

---

## Propósito de este documento

Este documento define la naturaleza de cada dato en Agenda Podológica: qué es canónico, qué se deriva, qué se configura, qué se referencia y qué es histórico. Define dónde vive la verdad de cada concepto, qué puede recalcularse y qué no, qué debe ser inmutable y bajo qué condiciones algo puede cambiar.

No diseña tablas, no escribe SQL, no especifica Supabase, no define APIs, no produce código. Es el contrato conceptual de datos que debe existir antes de cualquier decisión técnica sobre almacenamiento o estructura.

Toda decisión posterior sobre bases de datos, modelo relacional o esquemas debe poder justificarse contra este documento.

---

## 1. Marco de clasificación

Cada entidad o conjunto de información en el sistema pertenece a uno o más de estos tipos. Los tipos no son excluyentes: una entidad puede ser simultáneamente Canónica e Histórica.

---

**Canónico**

Información que representa la realidad del negocio de forma primaria y definitiva. Es la fuente de verdad dentro del sistema. No se puede derivar de ningún otro dato. Si se pierde, no puede reconstruirse desde otra fuente.

Ejemplo: el nombre del paciente, el tratamiento registrado en una atención cerrada.

---

**Derivado**

Información que se calcula o construye a partir de datos canónicos o históricos. Puede recalcularse siempre que sus fuentes existan. No tiene valor independiente: es una proyección.

Ejemplo: el Dashboard, los Reportes, la Evolución Clínica en Fase 1.

---

**Configuración**

Parámetros que el profesional define para personalizar el comportamiento del sistema. Pueden cambiar en cualquier momento. Su valor actual representa la preferencia vigente del profesional. Los cambios en configuración no deben alterar registros históricos ya cerrados.

Ejemplo: el catálogo de Tipos de Atención, los valores del Arancel, las Zonas Domiciliarias.

---

**Referencial**

Información sobre entidades externas que el sistema conoce a través de una relación, pero que no posee completamente. El sistema registra el vínculo y los términos acordados, no la entidad en sí.

Ejemplo: Centro Médico. El sistema no gestiona el centro; gestiona la relación comercial y operativa de la profesional con él.

---

**Histórico**

Registro de un hecho que ocurrió en el pasado. Es inmutable por naturaleza: lo que pasó no puede cambiarse. Todo lo Histórico debe preservarse indefinidamente, independientemente del estado actual de las entidades relacionadas.

Ejemplo: una Atención Clínica cerrada, un Cobro generado, un Consentimiento firmado.

---

## 2. Clasificación de entidades

### Vista consolidada

| Entidad | Tipo | Inmutable | Requiere auditoría |
|---|---|---|---|
| Paciente (identidad) | Canónico | No | Sí |
| Historia Clínica | Canónico + Histórico | Parcial | Sí |
| Atención Clínica (abierta) | Canónico | No | Sí |
| Atención Clínica (cerrada) | Canónico + Histórico | Sí | Sí |
| Evolución Clínica (Fase 1) | Derivado | — | No |
| Cita (futura) | Canónico | No | Sí |
| Cita (pasada) | Canónico + Histórico | Sí | Sí |
| Seguimiento (activo) | Canónico | No | Sí |
| Seguimiento (cerrado) | Canónico + Histórico | Sí | Sí |
| Fotografía Clínica | Canónico + Histórico | Sí | No |
| Cobro (monto y tipo) | Histórico | Sí | Sí |
| Cobro (estado de pago) | Canónico | No | Sí |
| Arancel / Tipos de Atención | Configuración | No | Opcional |
| Centro Médico (identidad) | Referencial | No | Sí |
| Centro Médico (acuerdo) | Configuración | No | Sí |
| Zonas Domiciliarias | Configuración | No | No |
| Liquidación (borrador) | Derivado | No | No |
| Liquidación (confirmada) | Histórico | Sí | Sí |
| Consentimiento firmado | Histórico | Sí | Sí |
| Informe de Sesión (generado) | Derivado + Histórico | Sí (generado) | No |
| Dashboard | Derivado | — | No |
| Reportes | Derivado | — | No |
| Organización (identidad) | Canónico | No | Sí |
| Organización (configuración) | Configuración | No | Sí |
| Profesional (identidad) | Canónico | No | Sí |

---

### Detalle por entidad

---

**Paciente**

Tipo: Canónico.

El registro del paciente es la fuente de verdad sobre quién es esa persona en la plataforma. La identidad (nombre, identificación), los datos de contacto y la dirección son canónicos y pertenecen a la Organización Clínica.

Los datos de contacto y dirección pueden cambiar: la persona se muda, cambia de teléfono. Estos cambios deben poder registrarse. Sin embargo, el historial de cambios relevantes (dirección usada en documentos emitidos) debe preservarse mediante el principio de captura instantánea aplicado a los documentos que los referencian.

El estado del paciente (activo, en seguimiento, inactivo, archivado) es canónico y mutable. El paciente archivado no se elimina: existe para siempre en el historial de la organización.

El origen del paciente (particular, proveniente de centro médico, agendado por tercero) es canónico y estable. Puede corregirse si fue mal registrado, pero no cambia como parte del ciclo de vida normal.

---

**Historia Clínica**

Tipo: Canónico + Histórico.

La Historia Clínica es el perfil clínico permanente del paciente. Tiene dos naturalezas simultáneas: es canónica porque representa la realidad clínica actual del paciente, e histórica porque cada entrada registrada es un hecho del pasado que no puede borrarse.

Los antecedentes actuales (patologías activas, medicamentos en uso, alergias) son canónicos y mutables: el paciente puede incorporar un nuevo medicamento, una patología puede remitir. Pero una entrada registrada no se elimina: se marca como "resuelta" o "inactiva" si ya no está vigente. La entrada original permanece como registro histórico de lo que se conocía en ese momento.

Las observaciones clínicas de largo plazo son históricas: representan lo que el profesional observó y documentó en un momento dado.

Inmutabilidad: las entradas originales de Historia Clínica son inmutables. Solo se pueden agregar correcciones o anotaciones posteriores. Nunca sobrescribir ni eliminar.

---

**Atención Clínica**

Tipo: Canónico mientras está abierta. Canónico + Histórico una vez cerrada.

La Atención Clínica pasa por dos estados con naturalezas de dato distintas:

En estado **abierta** (iniciada o registrada): es canónico y mutable. El profesional puede completar, ajustar y enriquecer el registro antes de cerrar. Los cambios no requieren trazabilidad exhaustiva todavía.

En estado **cerrada**: es canónico e histórico inmutable. El contenido clínico de la atención (tratamiento realizado, hallazgos, notas, indicaciones) no puede ser modificado por ningún actor. Es el registro definitivo de lo que ocurrió en esa sesión.

El monto cobrado registrado al cierre es un dato histórico e inmutable. No refleja el valor actual del Arancel: refleja el valor que aplicó en ese momento. Si el profesional cambia sus precios después, las atenciones pasadas conservan los montos originales.

Una atención cerrada puede recibir anotaciones posteriores (notas clínicas de seguimiento), pero esas anotaciones son adiciones, no modificaciones al contenido original.

---

**Evolución Clínica**

Tipo en Fase 1: Derivado puro.

La Evolución Clínica en Fase 1 no tiene datos propios. Es una lectura organizada e interpretada del historial de atenciones cerradas del paciente. Puede recalcularse en cualquier momento a partir de las atenciones existentes. No genera ningún dato canónico.

Tipo si pasa a entidad (Fase 2 o posterior): las notas de evolución por problema clínico específico que el profesional registre explícitamente pasarían a ser Canónico + Histórico. Solo ocurre si se valida esa necesidad.

---

**Cita**

Tipo: Canónico mientras es futura o activa. Canónico + Histórico una vez resuelta.

Una cita futura o confirmada es canónica y mutable: puede reagendarse, confirmarse, cancelarse. Los cambios de estado deben rastrearse.

Una cita pasada (atendida, cancelada, inasistida) es histórica: el hecho de que existió, cuándo fue, con quién, qué estado tuvo y cómo fue resuelta es un registro permanente.

La reprogramación no borra la cita original: crea una nueva cita y la original queda con estado "reprogramada". El historial de reprogramaciones es parte del registro operativo.

---

**Seguimiento**

Tipo: Canónico mientras está activo. Canónico + Histórico cuando se cierra.

El seguimiento activo representa el estado real de la relación con el paciente en este momento. Es canónico y mutable a través de su ciclo de vida (generado → pendiente → contactado → agendado → completado/vencido/descartado).

Un seguimiento completado o descartado es histórico: quedó el registro de que existió, qué acción lo generó, cuánto tiempo tardó en resolverse y cómo terminó. Este historial forma parte de la relación longitudinal con el paciente.

---

**Fotografía Clínica**

Tipo: Canónico + Histórico.

La imagen en sí es el dato más inmutable del sistema. Captura una realidad visual en un instante específico. No puede ser alterada. Puede ser archivada pero no eliminada.

Los metadatos de la fotografía (paciente, fecha, atención asociada, descripción) son canónicos y parcialmente ajustables: una descripción puede corregirse, una asociación errónea puede rectificarse. La imagen en sí nunca se modifica.

---

**Cobro**

Tipo: Histórico en su dimensión de monto y origen. Canónico en su dimensión de estado de pago.

El cobro tiene dos naturalezas que merecen tratamiento distinto:

El **hecho económico** (monto, tipo de atención aplicada, fecha de registro, motivo) es histórico e inmutable desde el momento de su generación. Este monto es una captura instantánea del valor vigente en ese momento, no una referencia viva al Arancel actual.

El **estado del pago** (pendiente, pagado parcialmente, pagado, anulado) es canónico y mutable. El estado puede avanzar legítimamente. Una anulación no borra el cobro: registra que fue anulado, por quién y cuándo.

Nunca se elimina un cobro. La anulación es la forma canónica de invalidar un cobro sin destruir su registro histórico.

---

**Arancel y Tipos de Atención**

Tipo: Configuración.

El catálogo de tipos de atención y sus valores es pura configuración: el profesional lo define y puede modificarlo cuando lo necesite. El estado actual del catálogo es la verdad vigente de los precios y tipos disponibles.

Los cambios al Arancel no afectan cobros ya registrados. El principio de captura instantánea garantiza que cada cobro preserva el valor que tenía el tipo de atención en el momento de su registro.

Un tipo de atención puede ser renombrado o desactivado. Los cobros históricos que lo referencian conservan la descripción capturada al momento, no el nombre actual del tipo.

---

**Centro Médico**

Tipo: Referencial + Configuración.

El Centro Médico es una entidad externa. El sistema no posee al centro: registra la relación de la profesional con él. La identidad del centro (nombre, contacto) es referencial.

Los términos del acuerdo (modalidad de relación, comisión, valores por tipo de atención en ese centro) son configuración: pueden cambiar cuando la profesional renegocia. Los cambios en el acuerdo aplican a atenciones futuras. Las atenciones pasadas conservan los valores que correspondían según el acuerdo vigente en su momento.

Los cambios en los términos del acuerdo requieren trazabilidad: si la comisión cambia del 30% al 25%, las liquidaciones futuras usan el 25% y las pasadas mantienen el 30%. Esta distinción temporal es crítica.

---

**Zonas de Atención Domiciliaria**

Tipo: Configuración.

Las zonas y sus recargos son configuración pura. El profesional las define y puede modificarlas. Los cobros registrados capturan el recargo aplicado en ese momento como dato histórico, no como referencia viva a la configuración de zonas actual.

---

**Liquidación**

Tipo: Derivado mientras está en elaboración. Histórico una vez confirmada.

Una liquidación en elaboración es derivada: se calcula sumando las atenciones del período en el centro con los valores acordados. Puede recalcularse.

Una liquidación confirmada y aceptada es histórica: representa el acuerdo económico cerrado entre la profesional y el centro para ese período. Es inmutable. El que el centro haya pagado o no es el estado del cobro correspondiente, que sí es mutable.

---

**Documentos Clínicos**

Tipo del Informe de Sesión: Derivado en su contenido original; Histórico en su versión generada.

El Informe de Sesión extrae datos de una atención cerrada y los organiza para presentación. Es derivado hasta que se genera formalmente. Una vez generado y entregado (impreso o enviado), el documento producido es histórico: representa lo que fue comunicado al paciente en ese momento.

Tipo del Consentimiento firmado: Histórico + Canónico.

El consentimiento firmado es el documento clínico-legal más riguroso en términos de inmutabilidad. Una vez firmado, no puede modificarse. Debe conservarse con: el contenido exacto del documento, la identidad del paciente y la profesional al momento de la firma, la fecha y hora de la firma, y la versión de la plantilla utilizada.

La plantilla base del consentimiento es Configuración: puede actualizarse para usos futuros. Los consentimientos ya firmados conservan la versión de la plantilla que estaba vigente al momento de la firma.

---

**Dashboard**

Tipo: Derivado puro.

El Dashboard no genera ni almacena ningún dato propio. Es una proyección calculada en tiempo real de datos de otros módulos. Si el sistema se reinicia, el Dashboard se reconstruye correctamente a partir de los datos existentes. Nunca es canónico.

---

**Reportes**

Tipo: Derivado puro.

Los reportes son agregaciones calculadas desde datos históricos y canónicos. Pueden regenerarse en cualquier momento con el mismo resultado si los datos fuente no han cambiado. Su valor está en la presentación organizada de información existente, no en datos propios.

---

**Organización Clínica**

Tipo: Canónico (identidad) + Configuración (parámetros).

La identidad de la organización (nombre, información de contacto, datos de la profesional) es canónica. Puede actualizarse pero los registros históricos generados bajo la configuración anterior reflejan lo que estaba vigente en ese momento.

Los parámetros operativos (configuración de agenda, preferencias de notificación, valores por defecto) son configuración pura.

---

**Profesional**

Tipo: Canónico (identidad) + Configuración (preferencias de acceso).

La identidad del profesional es canónica. Sus credenciales de acceso son configuración. Las acciones que realizó (atenciones registradas, citas gestionadas) son parte de los registros históricos de esas entidades, no del registro del profesional mismo.

---

## 3. Fuente de verdad por concepto

Cada concepto tiene exactamente una fuente de verdad dentro del sistema. Cuando existe duda sobre cuál es el valor correcto de algo, esta es la respuesta.

| Concepto | Fuente de verdad |
|---|---|
| Quién es el paciente | Registro del Paciente (M03) |
| Qué antecedentes clínicos tiene el paciente | Historia Clínica del Paciente (M03, sección clínica) |
| Qué ocurrió en una sesión clínica | Atención Clínica cerrada (M04) |
| Cuánto se cobró en una sesión específica | Cobro registrado en esa atención (M09) |
| Cuánto vale hoy un tipo de atención | Arancel vigente en M10 |
| Qué valor se cobró en una atención pasada | El cobro histórico de esa atención, no el Arancel actual |
| Qué citas tiene hoy el profesional | Agenda activa (M06) |
| Si un paciente debe volver | Seguimiento activo del paciente (M07) |
| Qué acordó la profesional con un centro | Configuración del Centro Médico en M11 |
| Qué debe el centro a la profesional este mes | Liquidación en proceso de ese centro (M13) |
| Si el paciente firmó consentimiento | Consentimiento registrado en M14 |
| Cómo está yendo el día de la profesional | Dashboard (M15) — derivado, no canónico |

---

## 4. El principio de captura instantánea

Este principio es uno de los más críticos para la integridad de los datos históricos. Determina cuándo un valor debe ser capturado como hecho fijo y cuándo puede ser una referencia viva a la configuración actual.

### Qué es la captura instantánea

Cuando se crea un registro histórico, los valores de configuración que lo afectan deben quedar capturados en ese registro en el momento de su creación, no como referencias vivas a la configuración que exista en el futuro.

### Por qué importa

La profesional puede cambiar el precio de "podología normal" de 15.000 a 18.000 en cualquier momento. Sin captura instantánea, todos los cobros pasados de "podología normal" mostrarían 18.000 retroactivamente. Eso es incorrecto: cada cobro debe mostrar el valor que tuvo cuando se registró.

### Dónde aplica obligatoriamente

- **Cobro ← monto y tipo**: el monto capturado es el valor vigente del tipo de atención al momento del registro. No es una referencia viva al Arancel.
- **Cobro ← descripción del tipo**: si el tipo de atención es renombrado, el cobro conserva el nombre original.
- **Liquidación confirmada ← términos del acuerdo**: si la comisión del centro cambia, las liquidaciones pasadas conservan la tasa que correspondía al período.
- **Informe de Sesión ← datos del paciente y la profesional**: si el paciente cambia de dirección, el informe ya generado muestra la dirección que tenía al momento de la generación.
- **Consentimiento firmado ← versión de la plantilla**: si la plantilla es actualizada, el consentimiento firmado bajo la versión anterior no se ve afectado.

### Dónde no aplica (referencias vivas correctas)

- **Dashboard** siempre refleja el estado actual.
- **Reportes** agregan datos actuales del historial.
- **Seguimientos activos** muestran el nombre y contacto actual del paciente.
- **Agenda** muestra el nombre actual del paciente al mostrar citas.

---

## 5. Qué puede recalcularse

Información que puede ser reconstruida a partir de otras fuentes si se perdiera.

**Puede recalcularse siempre:**
- El contenido del Dashboard: es pura proyección de datos existentes.
- El contenido de un Reporte: es agregación de datos históricos existentes.
- La Evolución Clínica en Fase 1: se reconstituye leyendo el historial de atenciones.
- El borrador de una Liquidación antes de ser confirmada: se recalcula de atenciones del período.
- El Informe de Sesión antes de ser generado formalmente: puede regenerarse desde la atención.

**Puede recalcularse con condiciones:**
- El monto pendiente de cobro de un paciente: se puede derivar sumando cobros en estado "pendiente", pero este cálculo depende de que los cobros estén correctamente registrados.
- El total de ingresos de un período: se puede calcular sumando cobros pagados en ese período.

---

## 6. Qué nunca debe recalcularse

Información que tiene que existir como registro primario, no como cálculo. Si se pierde, no puede reconstruirse con certeza.

**Nunca se recalcula:**

- **El tratamiento registrado en una atención cerrada.** Nadie puede reconstruir desde cero qué se le hizo al paciente en una sesión pasada. Solo el registro original lo sabe.

- **Las entradas de la Historia Clínica.** Los antecedentes que el profesional registró sobre el paciente en un momento dado son conocimiento clínico capturado. No puede derivarse de ningún otro dato.

- **El monto cobrado en cada atención.** El precio de ese cobro específico es un hecho histórico, no un cálculo. Incluso si el Arancel cambia, el cobro pasado no se recalcula.

- **El consentimiento firmado.** El texto del documento, los datos del firmante y la fecha de firma son hechos legales que solo pueden existir como registro primario.

- **Las fotografías clínicas.** La imagen es evidencia original. No puede regenerarse.

- **Los términos acordados en una Liquidación confirmada.** Una vez aprobada, el monto es un hecho histórico legal.

---

## 7. Información inmutable

Una vez que la siguiente información existe en el sistema con el estado indicado, no puede ser modificada por ningún actor bajo ninguna circunstancia. La única operación permitida es agregar anotaciones, no sobrescribir.

| Información | Condición de inmutabilidad |
|---|---|
| Contenido clínico de una Atención | Desde el estado "cerrada" |
| Monto y tipo registrados en un Cobro | Desde el momento de generación |
| Contenido de un Consentimiento firmado | Desde el momento de la firma |
| Imagen de una Fotografía Clínica | Desde la captura |
| Entradas de Historia Clínica ya registradas | En cualquier estado |
| Liquidación confirmada por ambas partes | Desde la confirmación |
| Estado "atendida" de una Cita | Desde que se marcó como atendida |
| Informe de Sesión generado y entregado | Desde la generación formal |

---

## 8. Información mutable y bajo qué condiciones

La información mutable puede cambiar, pero siempre con condiciones claras sobre cuándo, por quién y qué rastro debe dejar ese cambio.

| Información | Puede cambiar | Condición |
|---|---|---|
| Datos de contacto del Paciente | Sí | El paciente cambia de teléfono, dirección. No afecta registros históricos. |
| Estado del Paciente | Sí | Activo → inactivo → archivado. El archivo no borra datos. |
| Entradas de Historia Clínica vigentes | Sí (acotado) | Se puede marcar una patología como "resuelta" o agregar observaciones. No se borra ni sobrescribe la entrada original. |
| Estado de pago de un Cobro | Sí | Pendiente → pagado parcial → pagado. O pendiente → anulado. El historial de cambios debe quedar. |
| Estado de una Cita | Sí | Agendada → confirmada → atendida/cancelada/inasistida. Una vez resuelta, el estado es histórico. |
| Estado de un Seguimiento | Sí | A través de su ciclo de vida completo. |
| Valores del Arancel | Sí | La profesional actualiza sus precios. No afecta cobros ya registrados. |
| Términos del acuerdo con un Centro Médico | Sí | Cuando hay renegociación. Debe quedar trazabilidad de cuándo cambió. |
| Configuración de Zonas Domiciliarias | Sí | La profesional redefine sus zonas. No afecta cobros ya registrados. |
| Preferencias de la Organización | Sí | Sin restricciones de historial. |
| Atención Clínica en borrador | Sí | Solo mientras no está cerrada. |

---

## 9. Política de eliminación

En un sistema clínico, la eliminación de datos es la operación más peligrosa. La regla general es que **nada clínico se elimina**. Se archiva, se cierra, se anula o se descarta. El registro persiste.

### Lo que nunca debe eliminarse

- Registros de Pacientes (aunque estén archivados).
- Entradas de Historia Clínica.
- Atenciones Clínicas cerradas.
- Cobros generados (anular no es eliminar).
- Fotografías Clínicas.
- Consentimientos firmados.
- Liquidaciones confirmadas.
- Registros de Seguimientos (completados o descartados).
- Citas con estado resuelto (atendida, cancelada, inasistida).

### Lo que puede eliminarse con precaución

- Atenciones Clínicas en borrador que no fueron cerradas y no tienen datos clínicos significativos.
- Citas agendadas por error antes de que sean confirmadas o atendidas.
- Borradores de Informes de Sesión no generados formalmente.

### La forma correcta de "eliminar" en Agenda Podológica

| Intención | Acción correcta |
|---|---|
| Quitar un paciente | Archivarlo |
| Cancelar un cobro | Marcarlo como "anulado" |
| Cancelar una cita | Cambiar su estado a "cancelada" |
| Terminar un seguimiento | Cerrarlo como "completado" o "descartado" |
| Cambiar el precio de un tipo de atención | Actualizar el Arancel (cobros pasados no cambian) |
| Dejar de trabajar con un centro | Marcar el Centro como inactivo (historial se preserva) |

---

## 10. Entidades que requieren auditoría

Auditar significa registrar automáticamente: quién realizó la acción, cuándo, sobre qué entidad y desde qué estado al estado anterior.

### Prioridad alta — Auditoría clínica obligatoria

Estas entidades tienen impacto directo en la continuidad clínica o la protección legal del profesional.

| Entidad | Acciones a auditar |
|---|---|
| **Historia Clínica** | Toda adición o modificación de antecedentes. Quién la hizo y cuándo. |
| **Atención Clínica** | Quién inició, quién registró, quién cerró y cuándo en cada transición. |
| **Consentimiento Informado** | Quién lo generó, quién lo firmó, cuándo, bajo qué versión de plantilla. |
| **Cobro** | Cambios de estado del pago (quién marcó como pagado, quién anuló y con qué motivo). |
| **Paciente** | Creación (quién y cuándo). Modificación de datos de identificación clínica relevantes. |

### Prioridad media — Auditoría operacional importante

| Entidad | Acciones a auditar |
|---|---|
| **Cita** | Cada cambio de estado: confirmación, cancelación, reprogramación. Quién modificó y cuándo. |
| **Seguimiento** | Cambios de estado relevantes: contactado, agendado, vencido, descartado. |
| **Centro Médico (acuerdo)** | Cambios en los términos del acuerdo comercial. Fecha efectiva del cambio. |
| **Liquidación** | Aprobación o rechazo. Quién y cuándo. |

### Prioridad baja — Auditoría de configuración

No es clínicamente crítica pero puede ser relevante para entender el contexto de registros históricos.

| Entidad | Acciones a auditar |
|---|---|
| **Arancel** | Cambios de valor en tipos de atención. Fecha del cambio (para entender por qué un cobro pasado tenía cierto precio). |
| **Organización** | Cambios en configuración operativa relevante. |

---

## 11. Relaciones obligatorias

Estas relaciones deben existir siempre. No puede crearse la entidad secundaria sin la entidad primaria, y la entidad primaria no puede ser eliminada si existe la secundaria (la forma correcta es archivar).

| Relación | Descripción |
|---|---|
| Paciente → Organización Clínica | Todo paciente pertenece a una organización. Sin organización no hay paciente. |
| Paciente → Historia Clínica (1:1) | Todo paciente tiene exactamente una Historia Clínica. Se crean simultáneamente. |
| Atención Clínica → Paciente | Toda atención corresponde a un paciente. No existe atención sin paciente. |
| Atención Clínica → Profesional | Toda atención fue realizada por un profesional identificado. |
| Atención Clínica → Organización Clínica | Toda atención pertenece a la organización (para fines de privacidad y propiedad). |
| Cita → Paciente | Toda cita está vinculada a un paciente. |
| Cita → Profesional | Toda cita está asignada a un profesional. |
| Cita → Organización Clínica | Toda cita pertenece a la organización. |
| Cobro → Trabajo clínico | Todo cobro existe porque hubo trabajo clínico. No hay cobro en el vacío. |
| Cobro → Organización Clínica | Todo cobro pertenece a la organización. |
| Seguimiento → Paciente | Todo seguimiento existe en relación a un paciente. |
| Fotografía Clínica → Paciente | Toda fotografía pertenece a un paciente. Sin ese vínculo no tiene contexto clínico. |
| Profesional → Organización Clínica | Todo profesional tiene membresía activa en una organización. |

---

## 12. Relaciones opcionales

Estas relaciones pueden existir o no, según el contexto operativo. Su ausencia es un estado válido.

| Relación | Por qué es opcional |
|---|---|
| Cita ↔ Atención Clínica | No toda cita resulta en una atención registrada. No toda atención proviene de una cita previa. |
| Atención Clínica ↔ Cobro (específico) | Una atención puede no generar cobro (control gratuito, convenio). Un cobro puede abarcar más de una atención. |
| Atención Clínica ↔ Fotografía Clínica | No toda atención incluye documentación fotográfica. |
| Atención Clínica ↔ Seguimiento | Una atención puede no generar seguimiento (caso concluido, alta definitiva). |
| Paciente ↔ Centro Médico | Solo aplica a pacientes que provienen de o son gestionados por un centro. |
| Atención Clínica ↔ Liquidación | Solo aplica a atenciones realizadas en centros médicos con liquidación. |
| Seguimiento ↔ Atención que lo generó | Un seguimiento puede ser creado autónomamente por el profesional, sin que derive de una atención específica. |
| Cita ↔ Seguimiento | Una cita puede no estar vinculada a un seguimiento. Un seguimiento puede resolverse sin cita formal. |
| Fotografía Clínica ↔ Atención Clínica | La atención es el contexto principal pero una foto puede estar asociada directamente al perfil del paciente. |

---

## 13. Principios de integridad de datos

Estos son los principios que debe respetar cualquier decisión futura de diseño de datos.

---

**Principio 1 — Los registros clínicos no se eliminan**

Nada con contenido clínico puede ser borrado permanentemente del sistema. El archivo, la cancelación y la anulación son las formas legítimas de retirar algo del flujo activo. El historial siempre se preserva.

---

**Principio 2 — La captura instantánea protege la veracidad histórica**

Cuando se crea un registro histórico, los valores de configuración relevantes (precios, términos de acuerdos, datos del paciente en documentos) deben capturarse como hechos en ese momento. Los cambios futuros en la configuración no alteran registros pasados.

---

**Principio 3 — El monto cobrado es un hecho, no un cálculo**

El valor registrado en un Cobro es el precio que correspondía en el momento de la atención. No es la referencia al precio actual del catálogo. Si el precio del catálogo cambia, ese cambio aplica a atenciones futuras, no a cobros ya registrados.

---

**Principio 4 — Una atención cerrada es inmutable**

El contenido clínico de una atención cerrada no puede ser modificado por ningún actor. Es el registro definitivo de lo que ocurrió. Si hay algo que agregar después (una nota de seguimiento, una aclaración), se agrega como anotación posterior, nunca como modificación del registro original.

---

**Principio 5 — La fuente de verdad es única**

Cada concepto tiene exactamente un lugar en el sistema donde vive su verdad. Si el mismo dato existe en dos lugares con valores distintos, uno es el canónico y el otro es una copia o derivación. La ambigüedad sobre cuál es la fuente de verdad es un defecto de diseño.

---

**Principio 6 — El estado vigente y el historial coexisten**

Saber que un paciente está inactivo hoy no borra el hecho de que estuvo activo antes. Saber que el precio de una atención es 18.000 hoy no cambia que en el pasado era 15.000. El sistema debe soportar la coexistencia del estado actual y el historial sin contradicción.

---

**Principio 7 — La auditoría silenciosa existe desde Fase 1**

Los cinco eventos clínicos mínimos (creación de paciente, registro de atención, cierre de atención, modificación de cita, actualización de historia clínica) deben quedar trazados desde el primer día de operación, aunque no sean consultables en la interfaz hasta que exista el módulo de auditoría completo en Fase 3.

---

**Principio 8 — La configuración cambia; los hechos no**

La configuración del sistema (precios, zonas, términos con centros, preferencias) puede cambiar cuando el profesional lo necesite. Los hechos históricos (cobros registrados, atenciones cerradas, consentimientos firmados) nunca cambian como consecuencia de ese ajuste. La arquitectura de datos debe garantizar esta separación.

---

*Este documento es el contrato conceptual de datos de Agenda Podológica. No especifica tablas ni esquemas: especifica qué es verdad, dónde vive y cómo se protege.*  
*Cualquier decisión de diseño de base de datos que contradiga estos principios requiere revisión explícita de este documento y justificación documentada antes de implementarse.*
