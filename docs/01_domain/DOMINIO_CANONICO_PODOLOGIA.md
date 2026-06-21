# Dominio Canónico — Agenda Podológica

**Versión:** 1.0  
**Estado:** Fundacional  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuentes:** PROJECT_CHARTER.md · AUDITORIA_FUNCIONAL_BETA.md · PODOLOGIA_NEXTGEN_VISION.md

---

## Propósito de este documento

Este documento define el modelo conceptual de dominio de Agenda Podológica. No es un diseño de base de datos ni una especificación técnica. Es el vocabulario compartido del negocio: qué existe, qué significa, cómo vive y cómo se relaciona cada cosa en el mundo real de la podología clínica.

Toda decisión posterior de arquitectura, datos o código debe poder referenciarse contra este documento. Si algo no tiene nombre aquí, todavía no existe como concepto validado en el dominio.

---

## 1. Entidades fundamentales del negocio

Una entidad es algo que existe en el dominio de la podología con identidad propia, ciclo de vida propio y relevancia suficiente como para ser gestionado, consultado o rastreado de forma independiente.

---

### 1.1 Paciente

**¿Qué es?**

La persona que recibe atención podológica. Es el eje de toda la operación clínica. No existe atención, cita, seguimiento ni cobro sin un paciente que los origine. El paciente no es solo un nombre en una lista: es la razón de ser del sistema.

El paciente posee una identidad (nombre, contacto, dirección), un perfil clínico persistente (su historia clínica) y una historia de interacciones con el profesional que se construye con el tiempo.

**Ciclo de vida:**

- **Nuevo** — Ha sido registrado en el sistema. Su ficha existe pero puede estar incompleta. Aún no tiene atenciones registradas.
- **Activo** — Tiene una relación vigente con el profesional. Ha sido atendido y existe expectativa de continuidad.
- **En seguimiento pendiente** — Ha concluido una atención y existe una sugerencia o necesidad de retorno que todavía no se ha concretado.
- **Inactivo** — No tiene actividad reciente ni seguimiento pendiente. Puede ser recuperado en cualquier momento.
- **Archivado** — Ha sido retirado del flujo operativo activo. Su historial se preserva pero no aparece en la operación diaria.

---

### 1.2 Historia Clínica

**¿Qué es?**

El registro clínico permanente y acumulativo del paciente. No es un formulario que se llena una vez: es un documento vivo que se enriquece con cada atención. Contiene el contexto clínico que permite al profesional conocer al paciente antes de atenderlo y dar continuidad inteligente a su tratamiento.

La historia clínica incluye: antecedentes personales, patologías conocidas, medicamentos en uso, alergias, factores de riesgo, observaciones permanentes del profesional y cualquier información clínica que trascienda una sola sesión.

La historia clínica pertenece al paciente y existe desde el momento en que se registra. Es indisociable de él.

**Ciclo de vida:**

- **Iniciada** — Se crea cuando el paciente es registrado. Puede estar incompleta.
- **En construcción** — Se enriquece con cada atención y actualización del profesional.
- **Consolidada** — Contiene información clínica suficiente para dar contexto a cualquier atención futura.
- **Archivada** — El paciente fue archivado. La historia se conserva pero no se modifica activamente.

---

### 1.3 Atención Clínica

**¿Qué es?**

El registro de lo que ocurrió en una sesión clínica concreta. Es la acción central del producto: el momento en que el profesional atiende al paciente, realiza tratamientos, observa hallazgos, registra procedimientos y deja constancia del trabajo realizado.

Cada atención es un evento discreto y puntual. Tiene fecha, contenido clínico (tratamientos, hallazgos, notas) y puede generar un cobro, fotografías y una sugerencia de seguimiento. La suma de todas las atenciones de un paciente forma su historial clínico.

Una atención es distinta de una cita. La cita es la reserva del tiempo. La atención es el registro de lo que sucedió durante ese tiempo.

**Ciclo de vida:**

- **Iniciada** — El profesional ha comenzado el registro de la sesión. No está cerrada.
- **Registrada** — El registro está completo. Se documentó el tratamiento, los hallazgos, el cobro y cualquier observación relevante.
- **Cerrada** — La atención forma parte del historial. Su contenido clínico es inmutable.

---

### 1.4 Evolución Clínica

**¿Qué es?**

La lectura longitudinal del estado clínico de un paciente a lo largo del tiempo. No es una atención individual sino la narrativa que conecta múltiples atenciones para entender cómo progresa (o regresa) una condición, una lesión o un tratamiento.

La evolución clínica responde preguntas que ninguna atención individual puede responder sola: ¿Mejoró este cuadro desde la primera visita? ¿El tratamiento funcionó? ¿Esta recurrencia es nueva o es la misma de hace tres meses?

En podología, la evolución clínica es especialmente relevante porque muchos pacientes presentan condiciones crónicas, recurrentes o de lenta mejoría. Sin evolución clínica, el profesional solo ve atenciones aisladas, no el caso completo.

**Ciclo de vida:**

- **Sin datos** — No hay atenciones suficientes para establecer una evolución.
- **En curso** — El caso tiene atenciones que permiten comparar y trazar una dirección clínica.
- **Estabilizado** — El cuadro no muestra cambios relevantes entre atenciones.
- **Resuelto** — La condición que motivó el seguimiento fue tratada exitosamente.
- **Recurrente** — Una condición considerada resuelta o estable ha vuelto a manifestarse.

---

### 1.5 Cita

**¿Qué es?**

La reserva de un tiempo específico en la agenda del profesional para atender a un paciente. La cita organiza la demanda futura y estructura el flujo de trabajo diario.

Una cita no garantiza una atención: puede ser cancelada, reprogramada o simplemente no cumplida. Tampoco toda atención nace de una cita previa: puede haber atenciones espontáneas o domiciliarias sin cita formal.

La cita tiene una función operacional clara: ordena el tiempo del profesional y crea expectativa de asistencia tanto para el profesional como para el paciente.

**Ciclo de vida:**

- **Agendada** — Ha sido registrada en el sistema. El paciente y el profesional tienen un compromiso de tiempo.
- **Confirmada** — El paciente o el profesional han confirmado explícitamente la asistencia.
- **Atendida** — Se realizó la atención. La cita cumplió su propósito y puede vincularse a un registro de atención.
- **Cancelada** — No se realizará. Puede tener un motivo registrado. Puede originar un nuevo proceso de reagendamiento.
- **Reprogramada** — La cita original fue modificada y existe una nueva cita que la reemplaza. La historia del cambio se preserva.
- **Inasistida** — El paciente no se presentó sin aviso previo.

---

### 1.6 Seguimiento

**¿Qué es?**

El estado de la relación con el paciente entre una atención y la siguiente. El seguimiento responde a la pregunta: ¿qué debe ocurrir para que este paciente retorne en el momento adecuado?

En podología, la recurrencia es la norma, no la excepción. Muchos pacientes necesitan controles periódicos, y la continuidad del tratamiento depende de que vuelvan. El seguimiento es el mecanismo que garantiza que esa recurrencia no quede a la suerte.

El seguimiento puede surgir de una sugerencia del profesional al cerrar una atención, de un plan terapéutico definido, o de la identificación de un paciente que lleva tiempo sin visitar la consulta.

El seguimiento no es lo mismo que una cita. Un seguimiento puede o no convertirse en una cita. Es una señal de que el paciente necesita atención, no una reserva de tiempo.

**Ciclo de vida:**

- **Generado** — El profesional ha sugerido o definido una próxima acción para el paciente al cerrar una atención.
- **Pendiente** — La acción sugerida no ha ocurrido todavía. El paciente debe ser contactado o ya ha sido agendado.
- **Contactado** — El profesional ha tomado contacto con el paciente para coordinar el retorno.
- **Agendado** — El seguimiento derivó en una cita concreta. El paciente tiene fecha reservada.
- **Completado** — El paciente retornó y fue atendido. El seguimiento cumplió su ciclo.
- **Vencido** — El plazo sugerido ha pasado sin que el paciente haya retornado ni sido contactado efectivamente. Requiere atención del profesional.
- **Descartado** — El seguimiento fue cancelado intencionalmente (por ejemplo, porque el paciente declaró no requerir más atención o fue derivado).

---

### 1.7 Fotografía Clínica

**¿Qué es?**

El registro visual del estado clínico del paciente en un momento dado. Generalmente capturada durante una atención, la fotografía clínica documenta condiciones que son difíciles de describir solo con palabras: lesiones, estados del pie, evolución de una afección, resultado de un procedimiento.

Su valor no está en la imagen individual, sino en la posibilidad de comparar imágenes a lo largo del tiempo. Una fotografía sola muestra un estado. Una secuencia de fotografías muestra una evolución.

**Ciclo de vida:**

- **Capturada** — La imagen fue tomada o cargada al sistema en el contexto de una atención.
- **Asociada** — Está vinculada a una atención clínica y forma parte del registro de esa sesión.
- **En revisión** — El profesional la está usando activamente para evaluar evolución o tomar una decisión clínica.
- **Archivada** — Sigue disponible en el historial pero no está en uso activo.

---

### 1.8 Cobro

**¿Qué es?**

El registro económico de lo que el profesional factura o cobra por una atención realizada. Vincula el trabajo clínico con la operación financiera de la consulta.

El cobro no es solo un número: incluye el monto, el estado del pago, el medio con que se realizó, y puede quedar pendiente, pagado parcialmente o anulado. Refleja la salud económica de la atención y, en conjunto, de la operación clínica.

El cobro existe únicamente en relación a una atención. No se cobra sin haber atendido.

**Ciclo de vida:**

- **Generado** — Se ha registrado el monto correspondiente a una atención realizada.
- **Pendiente** — Todavía no ha sido pagado. Puede estar en plazo o vencido.
- **Pagado parcialmente** — Se recibió un pago pero queda saldo pendiente.
- **Pagado** — El monto fue recibido en su totalidad.
- **Anulado** — El cobro fue cancelado por una razón válida. No corresponde a ingreso real.

---

### 1.9 Profesional

**¿Qué es?**

El podólogo o podóloga que usa la plataforma. Es el actor principal del sistema: atiende pacientes, gestiona su agenda, registra atenciones, cobra y toma decisiones clínicas y operativas.

El profesional puede ser independiente (opera solo) o parte de una organización clínica (trabaja con otros en un centro o clínica). En ambos casos es el responsable clínico de los pacientes que atiende.

El profesional tiene una identidad en la plataforma que determina qué puede ver y hacer. En un escenario multiusuario, el profesional solo ve los pacientes que le corresponden, salvo que la organización habilite visibilidad compartida.

**Ciclo de vida:**

- **Registrado** — Ha creado una cuenta y existe en el sistema.
- **Activo** — Usa la plataforma regularmente en su práctica clínica.
- **Inactivo** — No tiene actividad reciente pero su cuenta y datos persisten.
- **Desvinculado** — Ha dejado la organización clínica a la que pertenecía. Sus datos históricos se preservan pero ya no opera en la plataforma.

---

### 1.10 Organización Clínica

**¿Qué es?**

La unidad organizacional dentro de la cual opera uno o más profesionales. Puede ser una consulta unipersonal, un centro con dos o tres podólogos, o una clínica con estructura administrativa, múltiples profesionales y posiblemente múltiples sedes.

La organización clínica es el tenant del sistema: define los límites de privacidad y visibilidad de los datos. Los pacientes, atenciones, citas y cobros pertenecen a la organización. Los profesionales son miembros de ella.

En el caso de un profesional independiente, la organización existe igualmente como contenedor lógico, aunque tenga un solo miembro.

**Ciclo de vida:**

- **Configurada** — Ha sido registrada en el sistema con su información básica y tiene al menos un profesional activo.
- **Activa** — Opera regularmente. Tiene pacientes, atenciones y actividad clínica en curso.
- **En transición** — Está en un cambio de estructura (incorporación de nuevos profesionales, cambio de sede, etc.).
- **Inactiva** — Ha suspendido su operación. Sus datos se preservan.

---

## 2. Relaciones conceptuales

Las relaciones a continuación describen cómo se vinculan las entidades en el dominio del negocio. No representan campos ni claves foráneas: representan dependencias conceptuales y flujos de significado entre entidades.

---

### Organización y sus miembros

- Una **Organización Clínica** agrupa a uno o más **Profesionales**.
- Un **Profesional** pertenece a exactamente una **Organización Clínica** activa.
- Los **Pacientes**, sus **Historias Clínicas**, sus **Atenciones**, **Citas** y **Cobros** pertenecen a la **Organización Clínica**, no a un profesional individual.

---

### El Paciente como centro

- Un **Paciente** posee exactamente una **Historia Clínica**, que existe desde su registro y lo acompaña en toda su relación con la organización.
- Un **Paciente** acumula múltiples **Atenciones Clínicas** a lo largo del tiempo.
- Un **Paciente** puede tener múltiples **Citas** pasadas y futuras.
- Un **Paciente** puede tener uno o más **Seguimientos** activos o históricos.
- La **Evolución Clínica** de un **Paciente** es la lectura integrada de sus **Atenciones** a lo largo del tiempo.

---

### La Atención como evento central

- Una **Atención Clínica** es realizada por un **Profesional** y corresponde a un **Paciente**.
- Una **Atención Clínica** puede originarse desde una **Cita** previa o existir de forma independiente (atención espontánea o domiciliaria).
- Una **Atención Clínica** genera exactamente un **Cobro** (que puede quedar pendiente, pagarse o anularse).
- Una **Atención Clínica** puede generar cero o más **Fotografías Clínicas**.
- Una **Atención Clínica** puede sugerir un **Seguimiento**, definiendo cuándo y bajo qué circunstancias el paciente debe retornar.
- Múltiples **Atenciones Clínicas** contribuyen a la **Evolución Clínica** del paciente.

---

### La Cita y su relación con otros conceptos

- Una **Cita** está siempre asociada a un **Paciente** y a un **Profesional**.
- Una **Cita** atendida puede vincularse a una **Atención Clínica** que la concreta.
- Una **Cita** cancelada puede originar un nuevo proceso de **Seguimiento** o derivar en una nueva **Cita** reprogramada.
- Un **Seguimiento** puede originar una **Cita** cuando el paciente es contactado y acepta retornar.

---

### El Seguimiento como puente entre sesiones

- Un **Seguimiento** es generado por una **Atención Clínica** o por el profesional de forma autónoma.
- Un **Seguimiento** puede derivar en una **Cita** concreta o resolverse de otra manera.
- Un **Seguimiento** completado se cierra cuando el **Paciente** es atendido nuevamente.

---

### Las Fotografías Clínicas y su contexto

- Una **Fotografía Clínica** pertenece a una **Atención Clínica** específica.
- El conjunto de **Fotografías** de un **Paciente** a través del tiempo contribuye a la **Evolución Clínica** visual.

---

### El Cobro y su origen

- Un **Cobro** corresponde siempre a una **Atención Clínica** concreta.
- No existe **Cobro** sin **Atención Clínica** previa.
- Un **Cobro** es responsabilidad del **Profesional** que realizó la atención.

---

## 3. Eventos de negocio relevantes

Los eventos de negocio son hechos que ocurren en el dominio y que tienen consecuencias observables para el sistema o para el profesional. Cada evento marca un cambio de estado relevante.

---

### Eventos del Paciente

- **Paciente registrado** — Un nuevo paciente es dado de alta en el sistema.
- **Historia clínica actualizada** — Se incorpora nueva información clínica permanente al perfil del paciente.
- **Paciente reactivado** — Un paciente inactivo retoma contacto con la consulta.
- **Paciente archivado** — El paciente es retirado del flujo operativo activo.

---

### Eventos de la Atención Clínica

- **Atención iniciada** — El profesional comienza el registro de una sesión clínica.
- **Atención registrada** — El registro completo de la sesión queda cerrado en el historial.
- **Fotografía clínica capturada** — Se documenta visualmente el estado clínico durante una atención.
- **Tratamiento registrado** — Queda constancia de los procedimientos realizados en una sesión.

---

### Eventos de la Cita

- **Cita agendada** — Se reserva un tiempo en la agenda del profesional para un paciente.
- **Cita confirmada** — El paciente o el profesional confirman que la cita se mantendrá.
- **Cita cancelada** — La cita no se realizará. Se registra el motivo si corresponde.
- **Cita reprogramada** — Se modifica la fecha u hora de la cita existente. La trazabilidad del cambio se preserva.
- **Inasistencia registrada** — El paciente no se presentó a su cita sin aviso previo.

---

### Eventos del Seguimiento

- **Seguimiento generado** — Al cerrar una atención, se define que el paciente debe retornar en algún momento.
- **Recordatorio activado** — El sistema alerta al profesional que un seguimiento se acerca a su fecha sugerida.
- **Paciente contactado** — El profesional tomó contacto con el paciente para coordinar su retorno.
- **Seguimiento completado** — El paciente retornó y fue atendido. El ciclo se cierra.
- **Seguimiento vencido** — El plazo pasó sin retorno del paciente. El profesional debe decidir cómo proceder.

---

### Eventos del Cobro

- **Cobro registrado** — Se anota el monto correspondiente a una atención realizada.
- **Pago recibido** — El cobro fue pagado total o parcialmente.
- **Cobro anulado** — El cobro se cancela por una razón válida.

---

### Eventos de la Organización

- **Profesional incorporado** — Un nuevo profesional se une a la organización clínica.
- **Profesional desvinculado** — Un profesional deja de operar dentro de la organización.

---

## 4. Dominios funcionales

Las entidades y sus eventos se agrupan en dominios funcionales según la naturaleza de su propósito dentro del negocio. Esta agrupación orientará la organización modular de la plataforma en fases posteriores.

---

### Dominio Clínico

Contiene todo lo que pertenece al acto de conocer y tratar al paciente desde una perspectiva sanitaria.

Entidades:
- Historia Clínica
- Atención Clínica
- Evolución Clínica
- Fotografía Clínica

El dominio clínico es el núcleo de valor de la plataforma. Todo lo demás existe para servirle.

---

### Dominio Operacional

Contiene lo que organiza la actividad diaria del profesional: cuándo atiende, a quién, y qué debe ocurrir después.

Entidades:
- Cita
- Seguimiento
- Agenda (como vista operacional de citas y seguimientos)

El dominio operacional conecta el tiempo del profesional con las necesidades clínicas del paciente.

---

### Dominio Administrativo

Contiene la gestión económica y documental de la operación clínica.

Entidades:
- Cobro
- Documentos clínicos (consentimientos, indicaciones, en fases futuras)
- Reportes operativos y financieros (en fases futuras)

El dominio administrativo cierra el ciclo de la atención desde el punto de vista del negocio.

---

### Dominio Empresarial

Contiene la estructura organizacional y de acceso a la plataforma.

Entidades:
- Organización Clínica
- Profesional (en su rol dentro de la organización)
- Roles y permisos (en fases futuras con multiusuario)

El dominio empresarial define quién existe en el sistema, a qué tiene acceso y bajo qué estructura opera.

---

### Dominio Transversal

Contiene capacidades que atraviesan todos los dominios sin pertenecer a ninguno en particular.

Capacidades:
- Trazabilidad — quién hizo qué, cuándo y sobre qué entidad.
- Comunicación con el paciente — contacto, recordatorios, mensajes.
- Autenticación y acceso — identidad del profesional, sesión, seguridad.

El dominio transversal no tiene entidades propias pero habilita la confiabilidad de todos los demás dominios.

---

## 5. Principios canónicos

Estos principios no son preferencias de diseño ni aspiraciones. Son restricciones del dominio que deben respetarse en toda decisión futura de producto, arquitectura y código. Cuando exista tensión entre una funcionalidad y un principio canónico, el principio prevalece.

---

**Principio 1 — El Paciente es el eje absoluto del sistema**

No existe ninguna entidad relevante del dominio que no pueda trazarse hasta un paciente. La atención lo requiere. La cita lo involucra. El cobro lo refleja. El seguimiento lo cuida. Toda funcionalidad que no mejore de algún modo la relación con el paciente debe justificar su existencia en el dominio.

---

**Principio 2 — La Historia Clínica es permanente e inviolable**

La historia clínica de un paciente no se elimina. Solo se archiva. Ninguna acción del profesional puede borrar información clínica registrada. Este principio protege la continuidad asistencial y la integridad del historial.

---

**Principio 3 — Una Atención Clínica cerrada es inmutable**

Una vez que una atención es registrada y cerrada, su contenido clínico no se modifica. Puede agregarse información posterior (notas de seguimiento, aclaraciones), pero el registro original es permanente. Esto garantiza la integridad y trazabilidad del historial.

---

**Principio 4 — El Cobro es una consecuencia de la Atención, nunca su propósito**

No existe cobro sin atención previa. El cobro documenta la dimensión económica de algo que ya ocurrió clínicamente. Invertir este orden generaría confusión entre el flujo clínico y el administrativo.

---

**Principio 5 — Cita y Seguimiento son conceptos distintos**

Una cita es un compromiso de tiempo concreto. Un seguimiento es el estado de la relación con un paciente entre sesiones. Un seguimiento puede o no derivar en una cita. Una cita puede o no surgir de un seguimiento. Mezclar ambos conceptos fue uno de los problemas funcionales identificados en la Beta. La plataforma los trata siempre por separado.

---

**Principio 6 — La Evolución Clínica pertenece al paciente, no a las sesiones**

Las atenciones son eventos discretos. La evolución clínica es la narrativa que los conecta. El sistema debe facilitar esa lectura longitudinal sin obligar al profesional a reconstruirla manualmente cada vez. El historial no es una pila de registros: es la historia clínica viva de una persona.

---

**Principio 7 — La continuidad clínica no termina en la atención**

Registrar una atención es necesario pero no suficiente. El ciclo clínico completo incluye definir qué sigue, garantizar el retorno del paciente y cerrar administrativamente el episodio. El sistema debe facilitar ese cierre integral, no dejarlo abierto.

---

**Principio 8 — Toda acción relevante es trazable**

Quién registró una atención, quién modificó una cita, quién actualizó la historia clínica: toda acción que afecte el estado de una entidad clínica deja huella. Esta trazabilidad no es una funcionalidad opcional sino una garantía de calidad clínica y protección legal del profesional.

---

**Principio 9 — Los datos clínicos tienen un único dueño**

El profesional o la organización clínica que genera los datos es su único dueño. La plataforma no tiene derechos sobre ellos. No los analiza, no los comparte ni los comercializa sin consentimiento explícito. Este principio es fundacional para la confianza del usuario clínico.

---

**Principio 10 — El vocabulario del dominio es podológico, no genérico**

Los nombres de las entidades, sus atributos y sus comportamientos deben responder al lenguaje real de la podología. No se adaptan conceptos de sistemas médicos genéricos. No se usan términos ambiguos por comodidad técnica. Si un podólogo no reconoce el concepto en su práctica diaria, el concepto está mal nombrado.

---

**Principio 11 — La simplicidad operativa es una restricción de diseño**

El profesional usa esta plataforma entre paciente y paciente, muchas veces con el paciente presente. Ninguna funcionalidad puede exigir más fricción cognitiva de la estrictamente necesaria. La profundidad clínica debe expresarse en claridad, no en complejidad. Un flujo simple que se usa siempre vale más que un flujo completo que nadie termina.

---

**Principio 12 — El sistema escala sin romper la continuidad**

Un profesional independiente y una clínica con cinco podólogos comparten el mismo dominio conceptual. El sistema no cambia su vocabulario ni sus entidades según el tamaño de la organización. Lo que cambia son las reglas de acceso y visibilidad, no el modelo de dominio.

---

## Glosario mínimo

Términos del dominio con definición concisa para evitar ambigüedades en conversaciones futuras.

| Término | Definición canónica |
|---|---|
| **Paciente** | Persona que recibe atención podológica en la organización clínica. |
| **Historia Clínica** | Registro clínico permanente y acumulativo del paciente. No es una sesión: es el perfil clínico persistente. |
| **Atención Clínica** | Registro de lo ocurrido en una sesión clínica concreta. Evento discreto con fecha y contenido. |
| **Evolución Clínica** | Lectura longitudinal del estado clínico del paciente a través de múltiples atenciones. |
| **Cita** | Reserva de un tiempo en la agenda del profesional para un paciente. Compromiso de tiempo, no garantía de atención. |
| **Seguimiento** | Estado de la relación con el paciente entre sesiones. Señal de que debe retornar; no es una cita. |
| **Recordatorio** | Alerta generada por el sistema cuando un seguimiento se acerca a su fecha sugerida. |
| **Fotografía Clínica** | Registro visual del estado clínico del paciente durante una atención. |
| **Cobro** | Registro económico de lo que se cobra por una atención realizada. Consecuencia de la atención, no causa. |
| **Profesional** | Podólogo o podóloga que opera en la plataforma como actor clínico principal. |
| **Organización Clínica** | Unidad organizacional que agrupa a uno o más profesionales y es propietaria de sus datos clínicos. |
| **Historial clínico** | La secuencia de atenciones de un paciente ordenadas en el tiempo. Resultado acumulado de sus sesiones. |
| **Cierre de atención** | El acto de completar el registro de una sesión clínica, incluyendo lo realizado, lo cobrado y el próximo paso. |

---

*Este documento es el punto de referencia conceptual del dominio. No describe implementación. Describe realidad.*  
*Cualquier cambio sustancial al modelo de dominio requiere revisión y nueva versión de este documento antes de impactar en la arquitectura o el código.*
