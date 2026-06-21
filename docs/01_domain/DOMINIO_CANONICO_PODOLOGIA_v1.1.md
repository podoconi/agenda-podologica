# Dominio Canónico — Agenda Podológica

**Versión:** 1.1  
**Estado:** Revisado — incorpora observaciones de QA_DOMINIO_CANONICO.md  
**Fecha original:** Junio 2026  
**Fecha de revisión:** Junio 2026  
**Autor:** Roberto Rojas  
**Revisor QA:** Codex (OpenAI)  
**Fuentes:** PROJECT_CHARTER.md · AUDITORIA_FUNCIONAL_BETA.md · PODOLOGIA_NEXTGEN_VISION.md · QA_DOMINIO_CANONICO.md

---

## Cambios en esta versión

Esta versión incorpora las observaciones aprobadas de la auditoría conceptual `QA_DOMINIO_CANONICO.md`. No modifica la esencia del documento ni agrega diseño técnico. Los cambios son de precisión conceptual:

- **Cobro ↔ Atención**: se elimina la cardinalidad estricta "exactamente un cobro por atención" y se sustituye por una relación flexible que preserva el principio clínico sin imponer rigidez económica.
- **Profesional ↔ Organización**: se reformula la pertenencia como membresía contextual, acotando el caso de una sola organización al alcance inicial sin declararlo regla permanente del dominio.
- **Fotografía Clínica ↔ Atención**: se amplía el contexto posible de una fotografía. La atención sigue siendo el contexto principal de captura, pero no el único contexto clínico válido.
- **Plan de Tratamiento**: se evalúa explícitamente y se decide su lugar en el dominio. Se justifica la decisión.
- **Conceptos reconocidos fuera del alcance inicial**: se agrega una sección para nombrar entidades clínicas y administrativas reales que el dominio reconoce pero que quedan fuera del alcance de Fase 1.
- **Eventos de negocio**: se completan los eventos faltantes detectados por QA, cubriendo todos los estados definidos en los ciclos de vida.
- **Principio 1**: se reformula para evitar el conflicto con entidades que no son directamente trazables a un paciente (Profesional, Organización, roles, configuración).
- **Principio 4**: se ajusta para preservar el espíritu clínico sin imponer una regla de cardinalidad que puede ser demasiado restrictiva para una plataforma SaaS futura.
- **Lenguaje**: se elimina la palabra "tenant" y se sustituye por lenguaje de negocio.

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

La persona que recibe atención podológica. Es el eje clínico de la plataforma: la razón de ser de la operación clínica. El paciente no es solo un nombre en una lista: posee una identidad (nombre, contacto, dirección), un perfil clínico persistente (su historia clínica) y una historia de interacciones con el profesional que se construye con el tiempo.

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

Cada atención es un evento discreto y puntual. Tiene fecha, contenido clínico (tratamientos, hallazgos, notas) y puede originar registros económicos, fotografías y una sugerencia de seguimiento. La suma de todas las atenciones de un paciente forma su historial clínico.

Una atención es distinta de una cita. La cita es la reserva del tiempo. La atención es el registro de lo que sucedió durante ese tiempo.

**Ciclo de vida:**

- **Iniciada** — El profesional ha comenzado el registro de la sesión. El contenido está incompleto y no forma parte del historial todavía.
- **Registrada** — El profesional ha completado el ingreso de información de la sesión. El contenido puede ser revisado brevemente antes del cierre formal. Aún es editable.
- **Cerrada** — El registro ha sido confirmado como definitivo. Pasa a integrar el historial clínico del paciente. Su contenido clínico es inmutable a partir de este momento.

> La diferencia entre *Registrada* y *Cerrada* es de intención: una atención registrada puede seguir siendo ajustada en la misma sesión de trabajo; una atención cerrada es un hecho histórico que no se modifica. La inmutabilidad comienza con el cierre, no con el registro.

---

### 1.4 Evolución Clínica

**¿Qué es?**

La lectura longitudinal del estado clínico de un paciente a lo largo del tiempo. No es una atención individual sino la narrativa que conecta múltiples atenciones para entender cómo progresa (o regresa) una condición, una lesión o un tratamiento.

La evolución clínica responde preguntas que ninguna atención individual puede responder sola: ¿Mejoró este cuadro desde la primera visita? ¿El tratamiento funcionó? ¿Esta recurrencia es nueva o es la misma de hace tres meses?

La Evolución Clínica es retrospectiva: lee lo que ya ocurrió. No define lo que debe ocurrir. El concepto que orienta la acción futura sobre un problema clínico es el Plan de Tratamiento, reconocido por este dominio como entidad futura (ver sección 6).

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
- **Atendida** — Se realizó la atención. La cita cumplió su propósito y puede vincularse a un registro de atención clínica.
- **Cancelada** — No se realizará. Puede tener un motivo registrado. Puede originar un nuevo proceso de reagendamiento.
- **Reprogramada** — La cita original fue modificada y existe una nueva cita que la reemplaza. La trazabilidad del cambio se preserva.
- **Inasistida** — El paciente no se presentó sin aviso previo.

---

### 1.6 Seguimiento

**¿Qué es?**

El estado de la relación con el paciente entre una atención y la siguiente. El seguimiento responde a la pregunta: ¿qué debe ocurrir para que este paciente retorne en el momento adecuado?

En podología, la recurrencia es la norma, no la excepción. Muchos pacientes necesitan controles periódicos, y la continuidad del tratamiento depende de que vuelvan. El seguimiento es el mecanismo que garantiza que esa recurrencia no quede a la suerte.

El seguimiento puede surgir de una sugerencia del profesional al cerrar una atención, o de la identificación de un paciente que lleva tiempo sin visitar la consulta.

El seguimiento no es lo mismo que una cita. Un seguimiento puede o no convertirse en una cita. Es una señal de que el paciente necesita atención, no una reserva de tiempo.

El seguimiento tampoco reemplaza al Plan de Tratamiento. El seguimiento pregunta "¿cuándo debe volver el paciente?". El Plan de Tratamiento pregunta "¿qué objetivo clínico estamos persiguiendo, con qué frecuencia y bajo qué criterio lo cerramos?". Son conceptos complementarios, no equivalentes.

**Ciclo de vida:**

- **Generado** — El profesional ha sugerido o definido una próxima acción para el paciente al cerrar una atención.
- **Pendiente** — La acción sugerida no ha ocurrido todavía. El paciente debe ser contactado o ya ha sido agendado.
- **Contactado** — El profesional ha tomado contacto con el paciente para coordinar el retorno.
- **Agendado** — El seguimiento derivó en una cita concreta. El paciente tiene fecha reservada.
- **Completado** — El paciente retornó y fue atendido. El seguimiento cumplió su ciclo.
- **Vencido** — El plazo sugerido ha pasado sin que el paciente haya retornado ni sido contactado efectivamente. Requiere atención del profesional.
- **Descartado** — El seguimiento fue cancelado intencionalmente (por ejemplo, porque el paciente declaró no requerir más atención o fue derivado a otro centro).

---

### 1.7 Fotografía Clínica

**¿Qué es?**

El registro visual del estado clínico del paciente en un momento dado. Documenta condiciones que son difíciles de describir solo con palabras: lesiones, estados del pie, evolución de una afección, resultado de un procedimiento.

Su valor no está en la imagen individual, sino en la posibilidad de comparar imágenes a lo largo del tiempo. Una fotografía sola muestra un estado. Una secuencia de fotografías muestra una evolución.

El contexto principal de captura de una fotografía clínica es la atención, pero no el único contexto clínico posible. Una fotografía puede estar asociada a una atención específica, al perfil clínico del paciente de forma directa, o a un problema longitudinal en seguimiento. Lo que no puede existir es una fotografía clínica sin vínculo a un paciente.

**Ciclo de vida:**

- **Capturada** — La imagen fue tomada o cargada al sistema.
- **Asociada** — Está vinculada a un contexto clínico concreto: una atención, el perfil del paciente u otro contexto validado.
- **En revisión** — El profesional la está usando activamente para evaluar evolución o tomar una decisión clínica.
- **Archivada** — Sigue disponible en el historial pero no está en uso activo.

---

### 1.8 Cobro

**¿Qué es?**

El registro económico que documenta la dimensión financiera del trabajo clínico realizado. El cobro no existe como finalidad en sí mismo: existe porque hubo trabajo clínico que lo origina.

El cobro no es solo un número: incluye el monto, el estado del pago, el medio con que se realizó, y puede quedar pendiente, pagado parcialmente o anulado.

Una atención clínica puede originar un cobro, más de uno, o ninguno (atención de control sin costo, atención incluida en un convenio). Un cobro puede corresponder a una sola atención o a un conjunto de atenciones. Lo que no puede existir es un cobro sin que haya habido trabajo clínico que lo justifique.

**Ciclo de vida:**

- **Generado** — Se ha registrado el registro económico correspondiente al trabajo realizado.
- **Pendiente** — Todavía no ha sido pagado. Puede estar en plazo o vencido.
- **Pagado parcialmente** — Se recibió un pago pero queda saldo pendiente.
- **Pagado** — El monto fue recibido en su totalidad.
- **Anulado** — El cobro fue cancelado por una razón válida. No corresponde a ingreso real.

---

### 1.9 Profesional

**¿Qué es?**

El podólogo o podóloga que usa la plataforma. Es el actor clínico principal del sistema: atiende pacientes, gestiona su agenda, registra atenciones, y toma decisiones clínicas y operativas.

El profesional opera dentro de una organización clínica y tiene una membresía activa en ella que determina qué puede ver y hacer dentro de la plataforma. Para el alcance inicial, un profesional opera dentro de una sola organización activa. El dominio no cierra la posibilidad de que en el futuro un profesional pueda tener membresías en más de un contexto organizacional.

**Ciclo de vida:**

- **Registrado** — Ha creado una cuenta y existe en el sistema.
- **Activo** — Usa la plataforma regularmente en su práctica clínica.
- **Inactivo** — No tiene actividad reciente pero su cuenta y datos persisten.
- **Desvinculado** — Ha dejado la organización clínica a la que pertenecía. Sus datos históricos se preservan pero ya no opera en la plataforma.

---

### 1.10 Organización Clínica

**¿Qué es?**

La unidad responsable de los datos, la privacidad y la visibilidad dentro de la plataforma. Agrupa a uno o más profesionales bajo una misma identidad operativa. Puede ser una consulta unipersonal, un centro con dos o tres podólogos, o una clínica con estructura administrativa, múltiples profesionales y posiblemente múltiples sedes.

Los pacientes, atenciones, citas y cobros pertenecen a la organización clínica. Los profesionales son miembros de ella con roles y niveles de acceso que puede definir la propia organización.

En el caso de un profesional independiente, la organización existe igualmente como contenedor, aunque tenga un solo miembro. Esto garantiza que el modelo sea consistente independientemente del tamaño de la operación.

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

- Una **Organización Clínica** agrupa a uno o más **Profesionales** mediante membresías activas.
- Para el alcance inicial, un **Profesional** tiene una membresía activa en una sola **Organización Clínica**. El dominio no prohíbe que en el futuro un profesional pueda participar en más de un contexto organizacional.
- Los **Pacientes**, sus **Historias Clínicas**, sus **Atenciones**, **Citas** y **Cobros** pertenecen a la **Organización Clínica**, no a un profesional individual.

---

### El Paciente como eje clínico

- Un **Paciente** posee exactamente una **Historia Clínica**, que existe desde su registro y lo acompaña en toda su relación con la organización.
- Un **Paciente** acumula múltiples **Atenciones Clínicas** a lo largo del tiempo.
- Un **Paciente** puede tener múltiples **Citas** pasadas y futuras.
- Un **Paciente** puede tener uno o más **Seguimientos** activos o históricos.
- La **Evolución Clínica** de un **Paciente** es la lectura integrada de sus **Atenciones** a lo largo del tiempo.

---

### La Atención como evento central

- Una **Atención Clínica** es realizada por un **Profesional** y corresponde a un **Paciente**.
- Una **Atención Clínica** puede originarse desde una **Cita** previa o existir de forma independiente (atención espontánea o domiciliaria).
- Una **Atención Clínica** puede originar cero, uno o más registros de **Cobro**. Una atención de control puede no generar cobro; una atención compleja puede generar registros diferenciados por concepto.
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

- Toda **Fotografía Clínica** pertenece a un **Paciente**. Ese vínculo es siempre obligatorio.
- El contexto principal de captura es una **Atención Clínica** específica. Es el caso más frecuente y el que el sistema debe facilitar naturalmente.
- Una **Fotografía Clínica** también puede estar asociada directamente al perfil clínico del paciente (imagen de referencia no ligada a una sesión concreta) o a un problema longitudinal documentado en su **Evolución Clínica**.
- El conjunto de **Fotografías** de un **Paciente** a través del tiempo contribuye a la **Evolución Clínica** visual.

---

### El Cobro y su origen

- Todo **Cobro** existe porque hubo trabajo clínico que lo justifica. No hay cobro sin actividad clínica previa.
- Un **Cobro** puede corresponder a una **Atención Clínica** específica, a un conjunto de atenciones, o a un concepto administrativo validado (abono, paquete, ajuste). Lo que no puede existir es un cobro sin relación con trabajo clínico realizado.
- Un **Cobro** es responsabilidad del **Profesional** que realizó la atención o de la **Organización Clínica** según el contexto.

---

## 3. Eventos de negocio relevantes

Los eventos de negocio son hechos que ocurren en el dominio y que tienen consecuencias observables para el sistema o para el profesional. Cada evento marca un cambio de estado relevante.

---

### Eventos del Paciente

- **Paciente registrado** — Un nuevo paciente es dado de alta en el sistema.
- **Historia clínica actualizada** — Se incorpora nueva información clínica permanente al perfil del paciente.
- **Paciente marcado como inactivo** — El paciente pasa al estado inactivo por ausencia de actividad o decisión del profesional.
- **Paciente reactivado** — Un paciente inactivo retoma contacto con la consulta.
- **Paciente archivado** — El paciente es retirado del flujo operativo activo. Su historial se preserva.
- **Historia clínica archivada** — La historia clínica del paciente pasa a estado archivado al archivar al paciente.

---

### Eventos de la Atención Clínica

- **Atención iniciada** — El profesional comienza el registro de una sesión clínica.
- **Tratamiento registrado** — Queda constancia de los procedimientos realizados en una sesión.
- **Atención registrada** — El profesional ha completado el ingreso de información y el registro queda disponible para cierre.
- **Atención cerrada** — El registro es confirmado como definitivo e integra el historial clínico. A partir de este momento su contenido clínico es inmutable.
- **Fotografía clínica capturada** — Se documenta visualmente el estado clínico del paciente.
- **Fotografía clínica archivada** — Una fotografía pasa de uso activo a estado archivado.

---

### Eventos de la Cita

- **Cita agendada** — Se reserva un tiempo en la agenda del profesional para un paciente.
- **Cita confirmada** — El paciente o el profesional confirman que la cita se mantendrá.
- **Cita atendida** — La cita fue cumplida. Puede vincularse a una atención clínica registrada.
- **Cita cancelada** — La cita no se realizará. Se registra el motivo si corresponde.
- **Cita reprogramada** — Se modifica la fecha u hora de la cita existente. La trazabilidad del cambio se preserva.
- **Inasistencia registrada** — El paciente no se presentó a su cita sin aviso previo.

---

### Eventos del Seguimiento

- **Seguimiento generado** — Al cerrar una atención, se define que el paciente debe retornar en algún momento.
- **Recordatorio activado** — El sistema alerta al profesional que un seguimiento se acerca a su fecha sugerida.
- **Paciente contactado** — El profesional tomó contacto con el paciente para coordinar su retorno.
- **Seguimiento agendado** — El seguimiento derivó en una cita concreta.
- **Seguimiento completado** — El paciente retornó y fue atendido. El ciclo se cierra.
- **Seguimiento vencido** — El plazo pasó sin retorno del paciente. El profesional debe decidir cómo proceder.
- **Seguimiento descartado** — El seguimiento fue cancelado intencionalmente con motivo registrado.

---

### Eventos del Cobro

- **Cobro generado** — Se registra el hecho económico correspondiente al trabajo clínico realizado.
- **Pago recibido** — El cobro fue pagado total o parcialmente.
- **Cobro anulado** — El cobro se cancela por una razón válida.

---

### Eventos de la Organización y el Profesional

- **Organización configurada** — Una nueva organización clínica es registrada en el sistema.
- **Organización activada** — La organización comienza operación regular.
- **Organización en transición** — La organización está en proceso de cambio estructural.
- **Organización inactivada** — La organización suspende su operación.
- **Profesional registrado** — Un nuevo profesional crea su cuenta en el sistema.
- **Profesional activado** — El profesional comienza a operar en la plataforma.
- **Profesional inactivado** — El profesional suspende su actividad sin desvincularse.
- **Profesional incorporado a organización** — Un profesional se une a una organización clínica existente.
- **Profesional desvinculado de organización** — Un profesional deja de operar dentro de la organización.

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
- Documentos clínicos (consentimientos, indicaciones; ver sección 6)
- Reportes operativos y financieros (en fases futuras)

El dominio administrativo cierra el ciclo de la atención desde el punto de vista del negocio.

---

### Dominio Empresarial

Contiene la estructura organizacional y de acceso a la plataforma.

Entidades:
- Organización Clínica
- Profesional (en su rol dentro de la organización)
- Roles y permisos (en fases futuras con multiusuario)

El dominio empresarial define quién existe en el sistema, a qué tiene acceso y bajo qué estructura opera. Sus entidades no son directamente trazables a un paciente, pero hacen posible que la operación clínica ocurra.

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

Estos principios son restricciones del dominio que deben respetarse en toda decisión futura de producto, arquitectura y código. Cuando exista tensión entre una funcionalidad y un principio canónico, el principio prevalece.

---

**Principio 1 — El Paciente es el eje clínico del sistema**

El Paciente es el centro de toda la actividad clínica de la plataforma. La atención lo requiere. La cita lo involucra. El cobro lo refleja. El seguimiento lo cuida. Toda funcionalidad clínica que no mejore de algún modo la relación con el paciente debe justificar su existencia en el dominio.

Este principio aplica al dominio clínico y operacional. Existen entidades del dominio empresarial y transversal (Profesional, Organización Clínica, roles, configuración) cuya existencia no depende de un paciente concreto, pero cuya razón de ser es hacer posible el trabajo clínico con pacientes.

---

**Principio 2 — La Historia Clínica es permanente e inviolable**

La historia clínica de un paciente no se elimina. Solo se archiva. Ninguna acción del profesional puede borrar información clínica registrada. Este principio protege la continuidad asistencial y la integridad del historial.

---

**Principio 3 — Una Atención Clínica cerrada es inmutable**

Una vez que una atención es cerrada, su contenido clínico no se modifica. Puede agregarse información posterior (notas de seguimiento, aclaraciones), pero el registro original es permanente. La inmutabilidad comienza en el cierre, no en el registro. Esto garantiza la integridad y trazabilidad del historial.

---

**Principio 4 — El Cobro es siempre consecuencia clínica, nunca su propósito**

No existe cobro sin trabajo clínico previo que lo justifique. El cobro documenta la dimensión económica de algo que ya ocurrió clínicamente. Este principio no impone que toda atención genere exactamente un cobro: una atención puede no generar cobro (control gratuito, convenio), o puede generar más de uno (cobros por concepto diferenciado). Lo que el dominio prohíbe es invertir el orden: no se cobra como propósito, se cobra como consecuencia.

---

**Principio 5 — Cita y Seguimiento son conceptos distintos**

Una cita es un compromiso de tiempo concreto en la agenda. Un seguimiento es el estado de la relación con el paciente entre sesiones. Un seguimiento puede o no derivar en una cita. Una cita puede o no surgir de un seguimiento. Mezclar ambos conceptos fue uno de los problemas funcionales identificados en la Beta. La plataforma los trata siempre por separado.

---

**Principio 6 — La Evolución Clínica pertenece al paciente, no a las sesiones**

Las atenciones son eventos discretos. La evolución clínica es la narrativa que los conecta hacia atrás en el tiempo. El sistema debe facilitar esa lectura longitudinal sin obligar al profesional a reconstruirla manualmente. El historial no es una pila de registros: es la historia clínica viva de una persona.

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

## 6. Conceptos reconocidos fuera del alcance inicial

Esta sección existe para nombrar conceptos que el dominio de la podología clínica reconoce como reales y relevantes, pero que quedan fuera del alcance de Fase 1. Nombrarlos aquí los protege de dos riesgos: ser ignorados hasta que sea demasiado tarde para integrarlos bien, o ser absorbidos de manera informal por entidades existentes que no fueron diseñadas para contenerlos.

Ninguno de los conceptos de esta sección está diseñado técnicamente. No tienen atributos definidos, ni ciclos de vida completos, ni relaciones formalizadas. Solo se nombran y se describe su naturaleza, para que existan en el vocabulario del dominio antes de que existan en el código.

---

### Plan de Tratamiento

**Decisión del dominio:** concepto reconocido con identidad propia, candidato a entidad futura. No es parte de Evolución Clínica. No es absorbido por Seguimiento.

**Justificación:**

En podología, muchos casos no se resuelven en una sola atención ni en una serie indeterminada de sesiones. Existe un concepto clínico más preciso: el plan que define qué problema se está tratando, con qué objetivo, con qué frecuencia, con qué indicaciones específicas y bajo qué criterio se declarará exitoso o cerrado.

Este concepto no es equivalente a la Evolución Clínica, que es retrospectiva: lee lo que ya ocurrió. El Plan de Tratamiento es prospectivo: define lo que debe ocurrir.

Tampoco es equivalente al Seguimiento, que responde "¿cuándo debe volver el paciente?". El Plan de Tratamiento responde "¿qué estamos intentando resolver, cómo y con qué criterio cerramos el caso?". Un solo plan puede abarcar múltiples seguimientos y múltiples atenciones a lo largo de semanas o meses.

Casos clínicos típicos en podología que viven dentro de un Plan de Tratamiento: paciente diabético en control periódico, tratamiento de onicocriptosis en varias etapas, rehabilitación plantar post-intervención.

El Plan de Tratamiento se reconoce aquí como concepto con identidad propia que merece su propio espacio en el dominio cuando la plataforma evolucione hacia casos clínicos más complejos.

---

### Consentimiento Informado

Documento clínico mediante el cual el paciente autoriza explícitamente la realización de un procedimiento o el uso de su información con fines determinados. En clínicas podológicas modernas es un requisito legal para ciertos procedimientos invasivos.

Su existencia en el dominio es independiente de las atenciones: puede ser firmado antes de la primera atención, antes de un procedimiento específico, o como condición para el tratamiento.

---

### Documento Clínico

Cualquier archivo, formulario, indicación o registro formal que el profesional genera o recibe en el contexto de la atención y que no encaja en la definición de fotografía, atención o historia clínica. Incluye indicaciones entregadas al paciente, fichas descargables, informes para derivación, resúmenes de episodio, y similares.

---

### Derivación

El acto mediante el cual el profesional refiere al paciente a otro profesional o centro para una atención específica que excede su alcance o especialidad. Una derivación puede ser interna (a otro profesional dentro de la misma organización) o externa (a un especialista o institución diferente). Implica trazabilidad: quién derivó, a quién, por qué y qué ocurrió con esa derivación.

---

### Insumo

Material o producto clínico utilizado durante una atención (cintas, apósitos, productos aplicados, ortesis temporales) o entregado al paciente como parte del tratamiento. La gestión de insumos tiene relevancia tanto clínica (qué se usó en qué atención) como operacional (control de stock y consumo por período).

---

## Glosario mínimo

Términos del dominio con definición concisa para evitar ambigüedades en conversaciones futuras.

| Término | Definición canónica |
|---|---|
| **Paciente** | Persona que recibe atención podológica en la organización clínica. Eje clínico del sistema. |
| **Historia Clínica** | Registro clínico permanente y acumulativo del paciente. No es una sesión: es el perfil clínico persistente. |
| **Atención Clínica** | Registro de lo ocurrido en una sesión clínica concreta. Evento discreto con fecha y contenido. Inmutable una vez cerrado. |
| **Evolución Clínica** | Lectura longitudinal y retrospectiva del estado clínico del paciente a través de múltiples atenciones. |
| **Cita** | Reserva de un tiempo en la agenda del profesional para un paciente. Compromiso de tiempo, no garantía de atención. |
| **Seguimiento** | Estado de la relación con el paciente entre sesiones. Señal de que debe retornar; no es una cita ni un plan. |
| **Recordatorio** | Alerta generada por el sistema cuando un seguimiento se acerca a su fecha sugerida. |
| **Fotografía Clínica** | Registro visual del estado clínico del paciente. Contexto principal: atención. Contexto posible: perfil del paciente o problema longitudinal. |
| **Cobro** | Registro económico consecuencia del trabajo clínico realizado. Puede o no corresponder a una atención individual específica. |
| **Profesional** | Podólogo o podóloga que opera en la plataforma como actor clínico principal. Tiene membresía activa en una organización clínica. |
| **Organización Clínica** | Unidad responsable de los datos, privacidad y visibilidad. Agrupa a uno o más profesionales. |
| **Historial clínico** | La secuencia de atenciones de un paciente ordenadas en el tiempo. Resultado acumulado de sus sesiones. |
| **Cierre de atención** | El acto de confirmar como definitivo el registro de una sesión clínica. A partir de este momento el contenido es inmutable. |
| **Membresía** | Vínculo activo entre un Profesional y una Organización Clínica que define su rol y acceso en la plataforma. |
| **Plan de Tratamiento** | Concepto clínico prospectivo que define un objetivo terapéutico, su frecuencia y criterio de cierre. Reconocido por el dominio; fuera del alcance inicial. |

---

*Este documento es el punto de referencia conceptual del dominio. No describe implementación. Describe realidad.*  
*Cualquier cambio sustancial al modelo de dominio requiere revisión y nueva versión de este documento antes de impactar en la arquitectura o el código.*
