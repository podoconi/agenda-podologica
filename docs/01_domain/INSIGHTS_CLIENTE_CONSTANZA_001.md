# Insights de Cliente — Constanza Cortés, Podóloga Clínica
## Registro de requerimientos funcionales — Entrega 001

**Fecha:** Junio 2026  
**Fuente:** Constanza Cortés, podóloga clínica activa y usuaria de la Beta.  
**Rol en el proyecto:** Experta de dominio. Su práctica real es la referencia funcional del producto.  
**Registrado por:** Roberto Rojas  
**Documento relacionado:** DOMINIO_CANONICO_PODOLOGIA_v1.1.md

---

## Propósito de este documento

Este documento registra formalmente los requerimientos, observaciones y contexto de trabajo aportados por Constanza en su calidad de experta de dominio. No es un documento de diseño técnico. No contiene tablas, SQL, arquitectura ni código.

Su función es ampliar el entendimiento del dominio con conocimiento que solo puede provenir de una podóloga en ejercicio activo. Lo que aquí se registra debe informar futuras revisiones del Dominio Canónico, decisiones de producto y priorización de funcionalidades.

---

## 1. Modo real de trabajo de una podóloga

Una podóloga activa no trabaja en un único contexto ni bajo una única modalidad. La práctica real combina distintos ambientes de atención, cada uno con sus propias reglas operativas, económicas y de relación con el paciente.

---

### 1.1 Atención domiciliaria particular

La podóloga se desplaza al domicilio del paciente. Es una modalidad frecuente, especialmente para pacientes con movilidad reducida, adultos mayores, o pacientes que prefieren la comodidad de la atención en casa.

**Características operacionales:**
- La agenda la gestiona exclusivamente la profesional.
- El paciente es siempre particular: la relación es directa y el cobro es directo.
- El desplazamiento implica costos reales para la profesional: tiempo, combustible, distancia.
- El precio de la atención puede variar según la zona o sector del paciente.
- La profesional debe poder registrar a qué sector fue, cuánto cobró y cuánto corresponde al traslado.

**Necesidad funcional clave:** poder cobrar un valor diferenciado por sector o distancia, y que ese diferencial quede registrado junto con la atención.

---

### 1.2 Atención en centro médico

La podóloga trabaja en instalaciones que no son propias. Un centro médico le ofrece espacio, equipamiento y pacientes a cambio de una comisión o un valor acordado por atención.

**Características operacionales:**
- La agenda puede ser gestionada por la profesional, por el centro, o de forma compartida.
- Los pacientes pueden ser derivados por el centro o ser pacientes propios de la profesional que asisten al centro.
- El cobro no siempre es directo: el centro cobra al paciente y luego liquida a la profesional según lo acordado.
- La relación económica con el centro puede ser por porcentaje (comisión), por monto fijo por atención, o mediante liquidación mensual.
- Los valores por tipo de atención pueden variar según el centro: lo que la profesional cobra en un centro puede ser distinto a lo que cobra en otro.

**Necesidad funcional clave:** registrar la relación con cada centro, los valores acordados por tipo de atención en ese centro, y llevar control de lo que el centro le adeuda.

---

### 1.3 Atención en CESFAM o centro municipal

La podóloga presta servicios en centros de salud públicos o municipales. En este contexto, la relación operativa y económica es fundamentalmente distinta.

**Características operacionales:**
- Los pacientes pertenecen al sistema público de salud. La podóloga los atiende pero no los "posee" como pacientes propios.
- El pago proviene de la institución, no del paciente directamente.
- La agenda puede estar controlada por la institución.
- Los registros clínicos pueden tener requerimientos institucionales adicionales.

**Implicación para el dominio:** este contexto introduce la posibilidad de que el paciente no sea "propiedad" de la profesional sino de una institución, y que la profesional sea más bien un prestador de servicio. Esta distinción impacta en cómo se gestiona el historial clínico y a quién pertenece la información.

**Decisión para Fase 1:** este contexto queda reconocido como modalidad real pero no es el foco del alcance inicial. La plataforma en Fase 1 está orientada a la práctica privada (particular y centros médicos). El contexto CESFAM se registra aquí para que no sea ignorado en el diseño conceptual futuro.

---

### 1.4 Atención en consulta multidisciplinaria

La podóloga trabaja junto a otros profesionales de salud (kinesiólogo, nutricionista, médico, etc.) en un espacio compartido. Pueden derivarse pacientes entre sí y haber coordinación clínica entre especialidades.

**Características operacionales:**
- Los pacientes pueden provenir de otros profesionales del mismo centro.
- Puede haber una historia clínica compartida o coordinada entre disciplinas.
- La agenda puede ser independiente por profesional dentro del mismo espacio físico.
- La operación económica puede ser individual o compartida con el espacio.

**Implicación para el dominio:** la derivación interna entre profesionales de un mismo espacio es un caso real. Aunque Derivación ya está reconocida en el Dominio Canónico v1.1 como concepto futuro, este contexto le da peso funcional concreto.

---

## 2. Origen del paciente

El origen de un paciente determina quién gestiona su relación, quién cobra, y qué información puede o debe compartirse. No todos los pacientes llegan de la misma manera ni tienen la misma relación con la profesional.

---

### 2.1 Paciente particular

El paciente llega directamente a la profesional, ya sea por recomendación, búsqueda propia o continuidad de atención. La profesional gestiona todo: el agendamiento, el historial, el cobro y el seguimiento.

Esta es la relación más directa y completa entre profesional y paciente. El historial clínico pertenece plenamente a la organización de la profesional.

---

### 2.2 Paciente proveniente de centro médico

El paciente fue derivado, captado o pertenece a la cartera de un centro médico donde la profesional trabaja. El centro puede haberle agendado la cita y puede cobrar al paciente directamente.

En este caso, la profesional realiza la atención clínica pero el vínculo administrativo y económico pasa por el centro. La información clínica que registra la profesional es suya, pero la relación comercial con el paciente puede estar intermediada.

---

### 2.3 Paciente administrado o agendado por tercero

Alguien externo (un recepcionista, un coordinador del centro, un familiar del paciente) gestiona la cita en nombre del paciente. La profesional recibe al paciente sin haber gestionado el agendamiento.

**Implicación funcional:** la profesional necesita acceder rápidamente a la ficha del paciente al momento de la atención, con o sin haber intervenido en el agendamiento previo. La información clínica debe ser completamente accesible aunque el origen operativo de la cita sea externo.

---

## 3. Centro Médico como entidad funcional

El Centro Médico emerge de los insights de Constanza como una entidad del dominio que no estaba formalmente reconocida en el Dominio Canónico v1.1. No es lo mismo que la Organización Clínica de la profesional: el Centro Médico es una entidad externa con la cual la profesional establece una relación comercial y operativa.

---

### 3.1 Qué es un Centro Médico

Un lugar externo donde la profesional trabaja bajo una relación acordada. El centro tiene su propia identidad, sus propios pacientes y su propia operación. La profesional es un prestador de servicios dentro de ese centro.

La profesional puede trabajar en múltiples centros médicos simultáneamente, cada uno con condiciones distintas.

---

### 3.2 Información relevante de un Centro Médico

- **Nombre e identidad:** cómo se llama el centro, quién lo representa, cómo contactarlo.
- **Modalidad de relación:** cómo es el acuerdo de trabajo. Puede ser por porcentaje de lo cobrado (comisión), por monto fijo por atención, por jornada, o mediante liquidación mensual de lo acumulado.
- **Tabla de valores por tipo de atención:** el valor que el centro le paga a la profesional por cada tipo de atención realizada puede ser diferente al valor que cobra a sus propios pacientes particulares. Esta tabla puede variar entre centros.
- **Liquidación mensual:** en algunos centros el pago no es inmediato por sesión, sino que se acumula durante el mes y se paga en una liquidación al cierre del período. La profesional necesita saber cuánto le deben, cuándo llega ese pago y verificar que el monto sea correcto.

---

### 3.3 Relación entre Centro Médico y Cobro

El flujo de cobro cuando la profesional trabaja en un centro es distinto al cobro directo:

1. La profesional realiza la atención.
2. El centro cobra al paciente.
3. El centro retiene su porcentaje o cargo.
4. El centro le liquida a la profesional el valor acordado, ya sea por sesión o al fin del mes.

La profesional necesita rastrear este flujo: cuántas atenciones realizó en cada centro, qué valor le corresponde por cada una, cuánto ya recibió y cuánto está pendiente.

---

## 4. Tipos de atención y valorización

No todas las atenciones tienen el mismo valor económico ni el mismo tiempo de ejecución. Constanza identifica tipos de atención con diferencias concretas en complejidad, tiempo y precio.

---

### 4.1 Podología normal

La atención estándar. Incluye revisión general del pie, corte de uñas, tratamiento de callos, hidratación. Es el tipo de atención más frecuente.

---

### 4.2 Onicocriptosis / uña encarnada

Procedimiento que requiere mayor tiempo, instrumental específico y mayor cuidado. Su precio es más alto que la podología normal y el tiempo de la sesión es mayor.

---

### 4.3 Pie diabético

Atención especializada para pacientes con diabetes. Requiere protocolo específico de revisión y mayor atención al riesgo. Tiene implicaciones clínicas adicionales: seguimiento más riguroso, documentación más detallada, alertas de riesgo.

---

### 4.4 Tipos configurables por la profesional

La profesional debe poder definir sus propios tipos de atención según su práctica. El sistema no puede asumir que solo existen los tipos predefinidos. Lo que vale para Constanza puede no valer para otra podóloga con diferente especialización.

**Necesidad funcional:** el catálogo de tipos de atención debe ser editable por la profesional. Cada tipo tiene un nombre, un precio base en atención particular, y puede tener un precio diferente por centro.

---

### 4.5 Tabla dinámica de valores

La combinación de "tipo de atención" y "contexto de trabajo" determina el precio real de una atención. La misma onicocriptosis puede valer un precio en el consultorio propio, otro precio en el Centro Médico A y otro en el Centro Médico B, según lo acordado.

Esta tabla de valores no es estática: la profesional la actualiza cuando cambian los acuerdos con los centros o cuando revisa sus propios precios.

---

## 5. Cobro y gestión financiera

Constanza no necesita un sistema contable. Necesita una visión clara y cotidiana de su flujo de ingresos: qué cobró, qué falta cobrar y qué le deben.

---

### 5.1 Lo recaudado

Lo que la profesional ya tiene en su bolsillo o cuenta: pagos directos recibidos de pacientes particulares, transferencias, efectivo, o liquidaciones ya pagadas por centros médicos.

---

### 5.2 Lo pendiente de pacientes particulares

Pacientes que fueron atendidos pero aún no han pagado. Puede ser porque el cobro queda diferido (cuando la paciente dice que paga la próxima vez) o porque hubo un acuerdo de pago en cuotas.

---

### 5.3 Por cobrar a fin de mes desde centros médicos

Atenciones ya realizadas en centros médicos cuyos pagos todavía no se han liquidado. La profesional sabe que esa plata viene, pero aún no la tiene. Necesita ver ese número claramente para proyectar su mes.

---

### 5.4 Distinción entre pacientes particulares y pacientes de centro

El flujo económico de un paciente particular y de un paciente de centro es fundamentalmente distinto. Mezclarlos en una sola vista genera confusión. La profesional debe poder ver:

- Total recaudado de pacientes particulares.
- Total pendiente de pacientes particulares.
- Total a liquidar por cada centro.
- Total ya liquidado por cada centro.

---

### 5.5 Balance aproximado mensual

No necesita contabilidad formal. Necesita saber si el mes va bien o mal: cuánto lleva recaudado, cuánto tiene proyectado recibir antes de que termine el mes, y si hay cuentas por cobrar que lleven mucho tiempo sin resolverse.

Este balance no es para el contador: es para que la profesional tome decisiones operativas cotidianas.

---

## 6. Atención domiciliaria y cobro diferenciado por zona

La atención domiciliaria tiene una dimensión económica que la hace diferente a la atención en consultorio. Ir a atender a alguien a su casa tiene un costo real para la profesional: tiempo de traslado, combustible, desgaste del vehículo.

---

### 6.1 Cobro diferenciado por sector o zona

La profesional puede definir zonas geográficas de cobertura y asignar un valor adicional a cada zona. Por ejemplo:

- Zona central: sin cobro adicional.
- Sector norte de la ciudad: valor adicional por traslado.
- Sectores alejados o con dificultad de acceso: valor adicional mayor.

El recargo por traslado puede ser un monto fijo por zona, puede incluirse en el valor total de la atención, o puede ser un ítem separado visible en el cobro.

---

### 6.2 Registro del traslado

La profesional debe poder indicar, al registrar una atención domiciliaria, a qué zona o sector fue. Eso permite que el sistema calcule o sugiera el cobro correspondiente y que quede trazabilidad del traslado realizado.

---

### 6.3 Lo que no debe hacer el sistema

El sistema no es un GPS ni una herramienta de logística. No calcula rutas ni distancias en tiempo real. Solo necesita que la profesional pueda definir sus zonas y sus valores, y que esa configuración se aplique de forma simple cuando registra una atención domiciliaria.

---

## 7. Consentimiento informado

El consentimiento informado es un documento clínico y legal que protege tanto al paciente como a la profesional. Constanza lo usa en su práctica y necesita que el sistema lo soporte de forma completa.

---

### 7.1 Disponibilidad permanente

El consentimiento debe estar siempre disponible en la aplicación. No como funcionalidad secundaria o difícil de encontrar, sino como algo accesible en cualquier momento: antes de una atención, desde la ficha del paciente, desde el menú principal.

---

### 7.2 Imprimible en blanco

La profesional debe poder imprimir el consentimiento en blanco para completarlo a mano con el paciente presente. Útil cuando no hay conectividad, cuando el paciente prefiere papel, o cuando la atención es domiciliaria.

---

### 7.3 Rellenable desde la aplicación con datos del paciente y la profesional

El sistema debe poder pre-completar el documento con:
- Nombre del paciente.
- RUT o identificación del paciente.
- Nombre de la profesional.
- Número de registro profesional (si corresponde).
- Fecha.
- Tipo de atención o procedimiento a realizar.

Esto ahorra tiempo y reduce errores en el documento.

---

### 7.4 Imprimible rellenado

Una vez que los datos están ingresados, la profesional debe poder imprimir el documento listo para la firma del paciente y la firma de la profesional.

---

### 7.5 Enviable por correo electrónico

El documento también debe poder enviarse al paciente por correo electrónico: como adjunto en PDF, antes o después de la atención.

---

### 7.6 Contenido mínimo del consentimiento informado

El documento debe incluir:
- Identificación del paciente y la profesional.
- Descripción general de la atención podológica a realizarse.
- Riesgos conocidos y posibles complicaciones de la atención.
- Alcances y limitaciones del procedimiento.
- Declaración de que el paciente ha sido informado y acepta la atención.
- Espacio para firma del paciente.
- Espacio para firma de la profesional.
- Fecha.

El contenido base del consentimiento puede ser una plantilla estándar que la profesional puede personalizar o complementar según su práctica.

---

### 7.7 Vínculo con el paciente y la atención

Un consentimiento firmado debe poder quedar asociado al paciente y eventualmente a una atención específica. Esto permite tener trazabilidad de cuándo se firmó, para qué procedimiento y en qué sesión.

---

## 8. Informe por sesión podológica

El informe de sesión es un documento de resumen clínico generado a partir de una atención registrada. Está pensado para ser entregado al paciente, compartido con otro profesional, o guardado como respaldo.

---

### 8.1 Generado desde una atención

El informe toma los datos de una atención clínica ya registrada: fecha, tratamiento realizado, hallazgos, observaciones y próximo paso sugerido. No requiere ingreso manual adicional si la atención está bien registrada.

---

### 8.2 Imprimible

Debe generarse en un formato que pueda imprimirse de forma limpia: sin elementos de navegación de la app, con el logo o identificación de la profesional, con los datos del paciente visibles, y con el contenido clínico relevante.

---

### 8.3 Enviable por correo electrónico

La profesional debe poder enviarlo directamente al correo del paciente desde la aplicación, como PDF o en cuerpo del mensaje.

---

### 8.4 Simple y rápido

El informe no debe requerir configuración compleja ni muchos pasos. Si la atención está registrada, el informe debe generarse con un solo gesto. La podóloga no puede invertir más de 30 segundos en producir este documento.

---

### 8.5 Contenido mínimo del informe de sesión

- Nombre del paciente.
- Fecha de la atención.
- Tratamiento realizado (en lenguaje claro).
- Hallazgos o condiciones observadas.
- Indicaciones entregadas al paciente (cuidados, productos, reposo).
- Próxima atención sugerida (si aplica).
- Nombre y datos de la profesional.
- Posibilidad de agregar el logo de la organización clínica.

---

## 9. Dashboard cotidiano para la podóloga

El dashboard es la primera pantalla que ve la profesional al abrir la aplicación. Su valor depende de que le diga exactamente lo que necesita saber en ese momento, sin obligarla a navegar o analizar.

Constanza es explícita en lo que no necesita: no necesita gráficos de tendencias, no necesita comparativas anuales, no necesita KPIs de gestión empresarial. Necesita información diaria, orgánica y accionable.

---

### 9.1 Lo que el profesional necesita saber al abrir la app

- **¿A quién atiendo hoy?** — Lista de citas del día con el nombre del paciente y, al tocarla, acceso rápido a su ficha clínica.
- **¿Qué seguimientos tengo pendientes?** — Pacientes que deben volver y todavía no tienen cita ni han sido contactados.
- **¿Quién no ha vuelto en mucho tiempo?** — Pacientes que según el historial deberían haber retornado y no lo han hecho.
- **¿Cuánto voy a cobrar hoy?** — Valor estimado de las atenciones del día según el tipo y contexto.
- **¿Tengo algo urgente?** — Recordatorios próximos a vencer, cobros muy atrasados, seguimientos vencidos.

---

### 9.2 Lo que el dashboard no debe ser

- Una pantalla llena de números que no guían ninguna acción inmediata.
- Un resumen estadístico del mes o el año.
- Una vista de reportes de gestión.
- Información que requiera interpretación para ser útil.

La diferencia entre un dashboard útil y uno decorativo está en si la profesional puede responder "¿qué hago ahora?" después de mirarlo.

---

### 9.3 Información financiera diaria en el dashboard

Un pequeño resumen financiero útil en el dashboard podría ser:
- Cuánto cobré hoy (si ya atendí a alguien).
- Cuánto espero cobrar hoy (atenciones del día que faltan).
- Cuánto tengo pendiente de cobrar de días anteriores (resumen rápido).

No necesita gráficos. Un número claro por concepto es suficiente.

---

### 9.4 Tono del dashboard

El dashboard debe sentirse como una agenda inteligente, no como una consola de control. Debe hablarle a la podóloga como su herramienta de trabajo del día, no como un panel ejecutivo.

---

## 10. Implicaciones para el dominio canónico

Los insights de Constanza introducen conceptos que el Dominio Canónico v1.1 no modela todavía o modela de forma insuficiente. Se registran aquí para informar la próxima revisión del documento de dominio.

---

### Conceptos nuevos que emergen de esta entrega

**Centro Médico (o Centro de Atención)**
Entidad externa con la cual la profesional establece una relación comercial y operativa. Tiene identidad propia, una modalidad de relación acordada, una tabla de valores específica para esa relación, y puede liquidar pagos de forma mensual. No es equivalente a la Organización Clínica de la profesional: es un actor externo dentro del dominio económico.

**Modalidad de Trabajo**
El contexto operativo en que se realiza una atención: domicilio particular, centro médico, CESFAM, consulta multidisciplinaria. Esta modalidad afecta cómo se gestiona la agenda, el cobro, la relación con el paciente y el origen del registro clínico.

**Origen del Paciente**
La razón por la cual un paciente existe en el sistema de la profesional: llegó directamente (particular), fue derivado por un centro, o fue agendado por un tercero. Este origen tiene implicaciones en quién gestiona la relación y cómo se realiza el cobro.

**Tipo de Atención**
Categorización del procedimiento realizado en una sesión: podología normal, onicocriptosis, pie diabético, u otro tipo definido por la profesional. Cada tipo tiene un valor base que puede variar según el contexto (particular vs. centro, domicilio vs. consultorio).

**Arancel / Tabla de Valores**
Estructura de precios configurada por la profesional, que puede variar por tipo de atención, por contexto de trabajo y por centro médico. No es un precio único: es una tabla que el sistema aplica según las condiciones de cada atención.

**Zona de Atención Domiciliaria**
Segmentación geográfica definida por la profesional para la atención a domicilio. Cada zona puede tener un recargo diferenciado que refleja el costo real del traslado.

**Liquidación**
Proceso periódico (generalmente mensual) mediante el cual un Centro Médico le paga a la profesional el valor acumulado por las atenciones realizadas durante el período. La profesional necesita poder comparar lo que el centro le liquida contra lo que ella registró.

**Informe de Sesión**
Documento clínico generado automáticamente a partir de una atención registrada. Pensado para ser compartido con el paciente o con otro profesional. Diferente al Consentimiento Informado: el informe describe lo que ocurrió; el consentimiento autoriza lo que va a ocurrir.

---

### Revisión pendiente del Dominio Canónico

Esta entrega de insights es suficientemente significativa como para justificar una revisión del Dominio Canónico en su próxima versión. Los conceptos de Centro Médico, Modalidad de Trabajo, Origen del Paciente, Tipo de Atención, Arancel e Informe de Sesión deben ser evaluados para determinar cuáles son entidades canónicas de Fase 1, cuáles son entidades futuras y cuáles son atributos de entidades ya existentes.

Esa revisión corresponde al próximo ciclo de trabajo del dominio, no a este documento.

---

*Este documento registra conocimiento de dominio proveniente de una experta clínica activa. Su valor no está en la precisión técnica sino en la fidelidad a la realidad del trabajo podológico. Cualquier decisión de diseño que contradiga lo aquí registrado debe justificarse explícitamente.*
