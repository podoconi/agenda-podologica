# QA_DOMINIO_CANONICO
## Auditoria conceptual del Dominio Canonico de Agenda Podologica

**Fecha:** 2026-06-14  
**Documento auditado:** `docs/01_domain/DOMINIO_CANONICO_PODOLOGIA.md`  
**Alcance:** validacion conceptual del modelo de dominio como base futura para arquitectura, base de datos e implementacion.  
**Restriccion aplicada:** no se modifica el documento auditado, no se crea arquitectura, no se proponen tablas, SQL, Supabase ni codigo.

---

## Veredicto

**Aprobado con observaciones.**

El documento es conceptualmente solido, esta bien alineado con la decision fundacional de no arrastrar implementacion desde la Beta y evita, en general, diseñar tecnologia. Las 10 entidades fundamentales estan correctamente orientadas al negocio podologico y cubren el ciclo minimo de paciente, historia, atencion, agenda, seguimiento, fotografia, cobro, profesional y organizacion.

No obstante, existen rigideces que conviene corregir antes de usar este documento como contrato para arquitectura o base de datos. Las mas relevantes son: la obligatoriedad de exactamente un cobro por atencion, la pertenencia de un profesional a exactamente una organizacion activa, la dependencia absoluta de fotografia clinica respecto de una atencion especifica, y la falta de tratamiento mas canonico para plan de tratamiento, consentimiento, derivacion, insumos y documentos clinicos.

---

## Resumen ejecutivo

El modelo separa adecuadamente los conceptos centrales:

- **Paciente** como eje de la operacion.
- **Historia Clinica** como perfil clinico persistente.
- **Atencion Clinica** como registro discreto de una sesion.
- **Evolucion Clinica** como lectura longitudinal.
- **Cita** como reserva de tiempo.
- **Seguimiento** como continuidad entre sesiones.
- **Fotografia Clinica** como evidencia visual.
- **Cobro** como dimension economica.
- **Profesional** como actor clinico.
- **Organizacion Clinica** como contenedor operativo y de visibilidad.

La diferenciacion entre Cita, Atencion y Seguimiento es especialmente valiosa, porque corrige una ambiguedad funcional detectada en la Beta. Tambien es correcta la decision de tratar la Evolucion Clinica como narrativa longitudinal, no como sinonimo de historial ni como una atencion individual.

El documento respeta la prohibicion de diseñar tablas, SQL, Supabase o codigo. Las menciones a arquitectura, datos o implementacion aparecen como contexto de uso futuro del documento, no como especificacion tecnica. La unica palabra con carga tecnica visible es `tenant`, usada para explicar el limite organizacional; no invalida el documento, pero deberia suavizarse si se quiere conservar una pureza conceptual estricta.

La base es apta para iniciar discusiones de Fase 1, siempre que antes se ajusten las reglas demasiado absolutas que podrian limitar una futura plataforma SaaS.

---

## Hallazgos criticos

No se identificaron hallazgos criticos.

El documento no contiene diseño tecnico prematuro, no propone tablas, no especifica SQL, no menciona Supabase como implementacion, no define codigo y no reutiliza arquitectura de la Beta.

---

## Hallazgos medios

### 1. La relacion "Atencion Clinica genera exactamente un Cobro" es demasiado rigida

**Evidencia:** en relaciones conceptuales se declara que una Atencion Clinica genera exactamente un Cobro. En la definicion de Cobro tambien se afirma que no se cobra sin haber atendido.

**Problema conceptual:** la regla protege correctamente el orden clinico sobre el administrativo, pero el "exactamente uno" puede no representar todos los escenarios reales:

- atenciones gratuitas o de control sin cobro;
- cobros agrupados por varias atenciones;
- pagos anticipados, abonos o paquetes;
- anulaciones administrativas;
- venta de insumos o productos no ligada directamente a una atencion;
- atenciones incluidas en convenio o plan ya pagado.

**Riesgo:** si esta regla pasa intacta a arquitectura, puede forzar una operacion economica artificial y dificultar evolucion hacia una plataforma SaaS mas completa.

**Recomendacion concreta:** mantener el principio "el cobro no es el proposito de la atencion", pero flexibilizar la cardinalidad conceptual: una atencion puede originar cero, uno o mas registros economicos, y un registro economico puede responder a una atencion, a un conjunto de atenciones o a otro hecho administrativo validado.

---

### 2. "Profesional pertenece a exactamente una Organizacion Clinica activa" limita escenarios SaaS

**Evidencia:** en relaciones conceptuales se afirma que un Profesional pertenece a exactamente una Organizacion Clinica activa.

**Problema conceptual:** la regla simplifica el MVP, pero es demasiado fuerte como principio canonico para SaaS. En podologia real, un profesional podria:

- trabajar en consulta propia y tambien en un centro;
- atender en varias sedes;
- cambiar de organizacion conservando historial profesional;
- ser invitado temporalmente a una organizacion;
- ejercer roles distintos segun contexto.

**Riesgo:** bloquear desde el dominio escenarios multi-organizacion, multi-sede, colaboracion temporal o migracion profesional.

**Recomendacion concreta:** formular la pertenencia como relacion contextual: un profesional puede tener una membresia activa en una organizacion para el alcance inicial, pero el dominio no deberia negar la posibilidad futura de multiples membresias, roles o contextos de trabajo.

---

### 3. La Fotografia Clinica siempre asociada a una Atencion Clinica especifica deja casos clinicos fuera

**Evidencia:** el documento indica que una Fotografia Clinica pertenece a una Atencion Clinica especifica y que fue tomada o cargada en el contexto de una atencion.

**Problema conceptual:** la regla funciona para fotografias capturadas durante una sesion, pero puede excluir usos clinicos razonables:

- fotografia inicial previa a la atencion formal;
- imagen enviada por paciente para seguimiento;
- fotografia de control domiciliario;
- imagen asociada a una condicion o problema longitudinal;
- evidencia visual vinculada a historia clinica, consentimiento o documento, no necesariamente a una atencion cerrada.

**Riesgo:** limitar el valor longitudinal de la fotografia, justo cuando el documento reconoce que su valor principal esta en comparar secuencias a traves del tiempo.

**Recomendacion concreta:** mantener la atencion como contexto principal de captura, pero permitir que una fotografia pueda asociarse al paciente, a una atencion, a una evolucion/problema clinico o a otro contexto clinico validado.

---

### 4. Plan de tratamiento aparece mencionado pero no modelado como concepto canonico

**Evidencia:** Seguimiento puede surgir de un "plan terapeutico definido", pero Plan de Tratamiento no aparece entre las entidades fundamentales ni en el glosario.

**Problema conceptual:** en podologia, muchos casos requieren continuidad por objetivo clinico, no solo por atenciones aisladas. La Evolucion Clinica explica la lectura longitudinal, pero no reemplaza un plan con objetivo, frecuencia, indicaciones, estado y criterio de cierre.

**Riesgo:** que Seguimiento absorba responsabilidades que pertenecen a un plan clinico, mezclando "debe volver" con "que estamos intentando resolver".

**Recomendacion concreta:** definir si Plan de Tratamiento sera entidad canonica, subdominio futuro o concepto explicitamente postergado. No hace falta diseñarlo tecnicamente, pero si nombrarlo con claridad.

---

### 5. Consentimientos, documentos clinicos, derivaciones e insumos estan insuficientemente representados

**Evidencia:** Documentos clinicos aparecen solo en dominio administrativo como fase futura; consentimiento aparece como ejemplo. Derivacion aparece como motivo de descarte de seguimiento. Insumos no aparecen como concepto.

**Problema conceptual:** estos conceptos no necesariamente son Fase 1, pero si son relevantes para una clinica podologica madura:

- consentimiento informado;
- indicaciones entregadas al paciente;
- documentos adjuntos;
- derivaciones a otro profesional o centro;
- uso o venta de insumos;
- respaldo documental de procedimientos.

**Riesgo:** que el dominio base quede demasiado centrado en atencion-agenda-cobro y deje fuera objetos clinico-administrativos que afectan trazabilidad, seguridad y continuidad.

**Recomendacion concreta:** incorporar una seccion de "conceptos reconocidos pero fuera de alcance inicial" o "entidades candidatas futuras" con Plan de Tratamiento, Documento Clinico, Consentimiento, Derivacion e Insumo. Eso preserva foco sin negar su existencia conceptual.

---

## Hallazgos menores

### 1. "Tenant" introduce una palabra tecnica en un documento conceptual

El uso de `tenant` ayuda a expresar aislamiento SaaS, pero pertenece mas al lenguaje de arquitectura que al dominio del negocio. Puede mantenerse como aclaracion, aunque seria mas canonico hablar de "unidad responsable de datos, privacidad y visibilidad".

### 2. El principio "toda entidad relevante debe trazarse hasta un paciente" es demasiado absoluto

El principio protege el foco clinico, pero hay entidades relevantes que no siempre nacen de un paciente: Profesional, Organizacion Clinica, roles, horarios, bloqueos de agenda, configuracion, insumos, reportes y documentos organizacionales. Conviene reformularlo como prioridad de producto, no como regla universal.

### 3. Los eventos no cubren todos los cambios de estado definidos

Faltan o estan poco explicitados eventos como:

- Atencion cerrada.
- Cita atendida.
- Seguimiento descartado.
- Fotografia asociada o archivada.
- Paciente marcado como inactivo.
- Historia clinica archivada.
- Organizacion configurada, activada, inactivada o en transicion.
- Profesional registrado, activado o inactivado.

No bloquea el documento, pero reduce su utilidad como base futura de trazabilidad.

### 4. Atencion "registrada" y "cerrada" necesitan una frontera conceptual mas nitida

El ciclo de vida distingue Iniciada, Registrada y Cerrada. Sin embargo, la definicion de Registrada ya dice que el registro completo queda documentado, mientras Cerrada lo vuelve parte del historial e inmutable. La diferencia es plausible, pero deberia quedar mas clara para evitar ambiguedad futura.

### 5. Historia Clinica y Evolucion Clinica estan bien diferenciadas, pero su frontera debe cuidarse

La separacion actual es correcta: Historia Clinica como registro persistente y Evolucion Clinica como lectura longitudinal. El riesgo menor es que Evolucion Clinica se convierta en una entidad operativa sin ciclo propio claro. Por ahora esta bien como concepto; si mas adelante se vuelve gestionable, necesitara criterios de identidad mas precisos.

---

## Riesgos futuros

- Convertir reglas conceptuales rigidas en restricciones tecnicas dificiles de cambiar.
- Diseñar facturacion demasiado dependiente de una atencion unica.
- Bloquear crecimiento SaaS multi-organizacion o multi-sede por una definicion temprana de membresia.
- Perder casos clinicos visuales si toda fotografia debe colgar de una atencion cerrada.
- Sobrecargar Seguimiento con responsabilidades de plan terapeutico, recordatorio, recuperacion de pacientes y continuidad clinica.
- Dejar consentimiento, documentos, derivaciones e insumos como agregados tardios sin lugar claro en el lenguaje del dominio.
- Confundir principios de producto con invariantes absolutas del dominio.

---

## Recomendaciones concretas

1. Mantener el documento como base conceptual aprobada, pero abrir una revision menor antes de arquitectura.
2. Cambiar "exactamente un Cobro" por una formulacion flexible que preserve la prioridad clinica sin imponer cardinalidad.
3. Reescribir la relacion Profesional-Organizacion como membresia contextual, dejando el caso de una sola organizacion como alcance inicial, no como verdad permanente.
4. Redefinir Fotografia Clinica para que su contexto principal sea la atencion, pero no su unico contexto posible.
5. Decidir explicitamente si Plan de Tratamiento sera entidad canonica, concepto futuro o parte de Evolucion Clinica.
6. Agregar una seccion de conceptos reconocidos fuera de alcance inicial: Documento Clinico, Consentimiento, Derivacion e Insumo.
7. Completar eventos de negocio para todos los estados relevantes definidos en ciclos de vida.
8. Reformular el principio del Paciente como eje para evitar conflicto con entidades organizacionales o administrativas no directamente trazables a un paciente.
9. Reemplazar o aclarar `tenant` con lenguaje de negocio si se quiere mantener el documento estrictamente conceptual.
10. Mantener la prohibicion actual de bajar a tablas, SQL, Supabase, rutas, componentes o codigo.

---

## Conclusion final

`DOMINIO_CANONICO_PODOLOGIA.md` es una buena fundacion conceptual para Agenda Podologica. Identifica bien el nucleo del negocio, separa correctamente entidades que en la Beta podian confundirse y mantiene la conversacion en el plano del dominio, no de la tecnologia.

La aprobacion queda condicionada solo por observaciones de refinamiento conceptual. Ninguna obliga a rechazar el documento, pero varias deberian resolverse antes de que el modelo guie arquitectura, base de datos o implementacion.

El siguiente paso recomendado no es crear arquitectura ni tablas, sino ajustar el vocabulario canonico para que sea lo bastante firme en lo clinico y lo bastante flexible para una plataforma SaaS futura.
