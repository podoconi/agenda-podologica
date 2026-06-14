# AUDITORIA FUNCIONAL BETA

## Alcance

Este documento analiza exclusivamente la Beta actual como producto en uso para una consulta podológica.

Quedan expresamente fuera de alcance:

- Auditoría de código.
- Auditoría de seguridad.
- Auditoría de arquitectura.
- Propuestas tecnológicas.

La base del análisis es el comportamiento funcional observable de la aplicación actual, sus pantallas, formularios, flujos y capacidades operativas orientadas al trabajo clínico diario.

## 1. Módulos existentes

La Beta actual ya muestra una estructura funcional reconocible. Los módulos existentes son los siguientes:

### 1.1 Autenticación

Permite ingreso de usuaria profesional mediante cuenta y acceso con proveedor externo. Funcionalmente, este módulo actúa como puerta de entrada al sistema.

### 1.2 Dashboard

Es la vista de resumen operativo. Reúne indicadores rápidos, próximas atenciones, citas atendidas, recordatorios próximos y una vista básica de frecuencia de patologías y volumen de visitas.

### 1.3 Gestión de Pacientes

Permite crear, editar, buscar, listar y eliminar pacientes. Es el módulo base del producto, ya que toda la operación clínica se organiza alrededor de la ficha del paciente.

### 1.4 Ficha del Paciente

Concentra la información personal y clínica principal:

- Identificación del paciente.
- Edad y sexo.
- Teléfono.
- Dirección.
- Patologías.
- Medicamentos.
- Alergias.
- Última atención.
- Último cobro registrado.

Además, desde aquí se accede al historial clínico, al registro de nuevas atenciones y al agendamiento de nuevas citas.

### 1.5 Agenda / Citas

Permite registrar, visualizar y modificar citas. La Beta ya reconoce al menos tres estados operativos de cita:

- Agendada.
- Atendida.
- Cancelada.

### 1.6 Registro de Atención Clínica

Es el módulo donde se registra lo ocurrido en una sesión clínica. Incluye:

- Fecha de atención.
- Tratamiento realizado.
- Hallazgos o condiciones observadas en la sesión.
- Monto cobrado.
- Fotografías clínicas.
- Notas adicionales.
- Sugerencia de próxima atención.

### 1.7 Historial de Atenciones

Dentro de la ficha del paciente, la aplicación mantiene una secuencia de atenciones previas. Esto permite revisar evolución, tratamientos realizados, cobros previos y material fotográfico asociado.

### 1.8 Fotografías Clínicas

Existe un módulo funcional de captura o carga de imágenes durante la atención. Su objetivo producto es documentar visualmente la evolución clínica del paciente.

### 1.9 Seguimiento y Recordatorios

La Beta incluye una lógica de seguimiento para futuras atenciones. La profesional puede sugerir una fecha próxima y definir anticipación del recordatorio. Esto alimenta un widget de recordatorios próximos en el dashboard.

### 1.10 Comunicación y Ubicación

Desde la ficha del paciente existen atajos funcionales para:

- Contactar por WhatsApp.
- Abrir ubicación en mapa.

Este módulo no es clínico en sí mismo, pero sí operacional.

## 2. Flujos de usuario

Los flujos actuales muestran que la aplicación ya cubre un ciclo clínico básico, aunque todavía con algunas discontinuidades funcionales.

### 2.1 Flujo de inicio de sesión

1. La podóloga accede a la pantalla de ingreso.
2. Inicia sesión o se registra.
3. Una vez autenticada, entra a la aplicación principal.
4. Desde allí puede navegar entre dashboard, pacientes y agenda.

### 2.2 Flujo de alta de paciente

1. La podóloga crea un nuevo paciente.
2. Registra datos personales y de contacto.
3. Registra antecedentes relevantes:
   - Patologías.
   - Medicamentos.
   - Alergias.
4. Guarda la ficha.
5. El paciente queda disponible para futuras atenciones y citas.

### 2.3 Flujo de búsqueda y apertura de ficha

1. La podóloga ingresa a la lista de pacientes.
2. Busca por nombre.
3. Abre la ficha del paciente.
4. Desde esa ficha consulta antecedentes, historial y acciones disponibles.

### 2.4 Flujo de registro de atención

1. Desde la ficha del paciente, la podóloga selecciona registrar nueva atención.
2. Ingresa fecha de atención.
3. Registra tratamiento realizado.
4. Marca condiciones observadas durante la sesión.
5. Registra monto cobrado.
6. Adjunta fotografías si corresponde.
7. Añade notas clínicas.
8. Puede sugerir fecha de próxima atención.
9. Guarda la atención.
10. La atención pasa a formar parte del historial clínico.

### 2.5 Flujo de agendamiento

1. Desde agenda o desde ficha del paciente, la podóloga agenda una nueva cita.
2. Selecciona paciente.
3. Define fecha y hora.
4. Asigna estado inicial.
5. La cita queda visible en la agenda.

### 2.6 Flujo de continuidad clínica

1. La podóloga revisa historial del paciente.
2. Revisa tratamientos y registros anteriores.
3. Observa si existe sugerencia de próxima atención.
4. Consulta recordatorios próximos en dashboard.
5. Usa esa información para contactar o reagendar al paciente.

### 2.7 Flujo de cierre de atención

En la Beta actual, el cierre de atención existe de forma parcial. El cierre práctico hoy ocurre cuando:

1. Se registra la atención.
2. Se registra el monto cobrado.
3. Se deja nota clínica.
4. Se sugiere una próxima visita o se agenda una nueva cita.

Sin embargo, no existe un cierre integral de episodio clínico-administrativo. No se observa un flujo completo que consolide atención realizada, pago, próxima acción y estado final del caso.

## 3. Casos de uso reales

Desde la perspectiva de una podóloga en operación diaria, hoy la aplicación permite estos casos de uso concretos:

### 3.1 Registrar un nuevo paciente

La profesional puede cargar pacientes nuevos con sus antecedentes básicos y clínicos iniciales.

### 3.2 Consultar antecedentes antes de atender

Puede abrir la ficha para revisar patologías, medicamentos, alergias, historial previo y datos de contacto antes de iniciar una atención.

### 3.3 Registrar una atención podológica

Puede dejar trazabilidad de lo realizado en una sesión clínica, incluyendo tratamiento, observaciones, cobro y evidencia fotográfica.

### 3.4 Revisar evolución clínica previa

Puede mirar atenciones anteriores para comprender recurrencias, evolución del cuadro y frecuencia de asistencia.

### 3.5 Agendar una nueva cita

Puede programar una futura atención para el paciente dentro del mismo entorno de trabajo.

### 3.6 Gestionar seguimiento de pacientes

Puede dejar sugerida una próxima atención y recibir apoyo visual mediante recordatorios próximos.

### 3.7 Contactar al paciente rápidamente

Puede usar el teléfono y el acceso a WhatsApp para comunicación rápida y la dirección con mapa para referencia territorial.

### 3.8 Mantener una agenda clínica básica

Puede ver citas cargadas, su estado y el nombre del paciente vinculado.

### 3.9 Tener una visión resumida del negocio clínico

Puede apoyarse en el dashboard para entender volumen de pacientes, próximas atenciones y parte del movimiento clínico reciente.

## 4. Funcionalidades críticas

Estas son las funcionalidades que hoy representan el corazón operativo de la Beta. Si alguna falla, el valor principal del producto cae de forma inmediata.

### 4.1 Ficha del paciente

Es el centro de la operación. La aplicación gira alrededor de tener una ficha accesible, entendible y confiable.

Justificación:

- Sin ficha no existe continuidad clínica.
- Sin ficha no existe contexto para atender.
- Sin ficha no existe historial utilizable.

### 4.2 Historial de atenciones

Es la memoria clínica del sistema.

Justificación:

- Permite seguir la evolución del paciente.
- Evita depender de memoria informal o registros externos.
- Sostiene la calidad y continuidad de la atención.

### 4.3 Registro de atención

Es la acción clínica central del producto.

Justificación:

- Materializa el trabajo realizado.
- Documenta lo cobrado, observado y ejecutado.
- Convierte la app en una herramienta clínica real y no solo administrativa.

### 4.4 Agenda de citas

Es crítica porque organiza la demanda futura y la continuidad operativa.

Justificación:

- Ordena la atención diaria.
- Permite visualizar carga de trabajo.
- Vincula el seguimiento con una fecha concreta.

### 4.5 Seguimiento y recordatorios

Aunque hoy es imperfecto, es funcionalmente crítico porque responde a una necesidad central del modelo podológico: la recurrencia.

Justificación:

- Muchos pacientes requieren controles periódicos.
- El retorno oportuno del paciente es parte del resultado clínico.
- Ayuda a no perder seguimiento.

## 5. Funcionalidades secundarias

Estas funcionalidades agregan valor, mejoran la experiencia o enriquecen el trabajo, pero no son el núcleo mínimo que sostiene la operación clínica.

### 5.1 Dashboard de indicadores

Es útil para ordenar la visión general, pero no reemplaza la operación clínica directa.

### 5.2 Gráficos y conteos

Ayudan a interpretar actividad y frecuencia, pero hoy tienen más valor de apoyo que de ejecución.

### 5.3 Atajos de WhatsApp

Mejoran la rapidez de comunicación, pero no son el núcleo clínico.

### 5.4 Enlace a mapas

Es una ayuda operacional interesante, sobre todo para atención domiciliaria o referencia geográfica.

### 5.5 Registro fotográfico

Hoy agrega mucho valor clínico, pero la operación básica podría seguir existiendo sin él. Por eso, en el estado actual de la Beta, funciona como secundaria de alto valor.

## 6. Funcionalidades incompletas

La Beta ya tiene varias ideas correctas, pero algunas se perciben iniciadas y todavía no maduras como producto.

### 6.1 Seguimiento clínico y agenda como dos lógicas separadas

La aplicación contiene recordatorios y también agenda, pero ambas piezas no se sienten plenamente integradas en un único flujo de continuidad del paciente.

Se percibe una madurez parcial porque:

- El recordatorio sugiere una futura atención.
- La agenda programa una cita.
- Pero no queda claro que ambas pertenezcan al mismo ciclo operativo.

### 6.2 Cierre administrativo de la atención

Se registra un monto cobrado, pero no existe una experiencia completa de cobro.

Se percibe incompleta porque falta, funcionalmente:

- Estado de pago.
- Medio de pago.
- saldo pendiente.
- comprobante.
- cierre diario o caja.

### 6.3 Evolución clínica estructurada

La Beta registra tratamiento, hallazgos y notas, pero la evolución clínica aún no se ve como una línea de seguimiento estructurado por problema, pie, dedo, lesión o plan terapéutico.

### 6.4 Uso longitudinal de fotografías

Las fotos existen y eso ya es valioso, pero aún no se percibe una experiencia madura de comparación temporal, selección clínica o lectura evolutiva ordenada.

### 6.5 Explotación funcional del dashboard

El dashboard ya resume información, pero todavía no parece una verdadera consola de gestión clínica.

Se percibe iniciado, pero no maduro, porque:

- resume actividad;
- muestra recordatorios;
- pero no parece guiar decisiones operativas complejas.

### 6.6 Gestión clínica por tipo de paciente

La app registra antecedentes, pero no parece convertirlos todavía en seguimiento diferenciado para pacientes de riesgo, crónicos, diabéticos o recurrentes.

## 7. Problemas operacionales detectados

Esta sección se enfoca en problemas de uso real desde una consulta clínica, no en causas técnicas.

### 7.1 Riesgo de duplicidad y confusión en la ficha

El problema reportado de bloques repetidos en la ficha o en el registro de atención tiene impacto operacional alto.

Consecuencia clínica:

- La podóloga puede dudar qué sección completar.
- Puede registrar información dos veces.
- Puede creer que guardó algo en un bloque cuando el bloque válido era otro.
- Aumenta el tiempo de atención y la desconfianza en la ficha.

### 7.2 Separación poco clara entre atención realizada, próxima atención y cita agendada

Hoy el producto maneja varios conceptos cercanos:

- atención ya realizada;
- sugerencia de próxima atención;
- cita en agenda.

Operacionalmente esto puede generar dudas como:

- si una sugerencia equivale o no a una cita;
- si un recordatorio significa que ya existe reserva;
- qué acción concreta debe hacer la podóloga después de una atención.

### 7.3 Continuidad clínica poco cerrada

La app ayuda a registrar una sesión, pero no termina de cerrar el ciclo completo del paciente.

En la práctica clínica, al terminar una atención suele requerirse:

- dejar evolución;
- definir control;
- registrar cobro;
- confirmar si quedó o no agendado;
- decidir próxima acción.

Hoy estas piezas existen, pero no aparecen como un cierre integrado.

### 7.4 Cobro registrado, pero gestión económica incompleta

Desde uso real, anotar un monto no alcanza para gestionar económicamente una consulta.

Faltan preguntas funcionales críticas:

- ¿se pagó o no se pagó?;
- ¿cómo se pagó?;
- ¿queda saldo?;
- ¿se anuló?;
- ¿se emitió algún respaldo?;
- ¿qué se cobró hoy en total?

### 7.5 Historial clínico útil, pero todavía poco analizable

El historial existe, pero no parece ofrecer todavía una lectura clínica comparativa suficientemente potente.

Esto puede dificultar:

- ver recurrencias;
- detectar empeoramiento;
- identificar patrones por pie o lesión;
- preparar controles más estandarizados.

### 7.6 Recordatorios con valor clínico, pero con ambigüedad operativa

La idea de recordatorio es correcta, pero desde el uso diario puede generar ambigüedad si no se distingue con claridad entre:

- paciente que debe volver;
- paciente ya contactado;
- paciente ya agendado;
- paciente que no respondió;
- paciente que canceló.

### 7.7 Ausencia de visión operacional de agenda más allá de la cita individual

La Beta parece manejar la cita puntual, pero no una operación de agenda más completa.

Desde el uso clínico pueden faltar situaciones como:

- reprogramar con trazabilidad;
- bloquear horarios;
- ordenar prioridades;
- distinguir controles de primera consulta;
- separar atención clínica de seguimiento comercial o administrativo.

### 7.8 Limitada explotación de antecedentes clínicos

Registrar patologías, medicamentos y alergias es muy valioso. El problema es que aún no se ve suficiente traducción práctica de esos datos dentro del seguimiento cotidiano.

En una clínica moderna, estos antecedentes deberían ayudar a priorizar, alertar y segmentar.

## 8. Funcionalidades que deben mantenerse

Estas funcionalidades merecen preservarse en la futura versión porque ya expresan correctamente necesidades reales del trabajo podológico.

### 8.1 Ficha centralizada del paciente

Debe mantenerse.

Justificación:

- Es el núcleo de continuidad clínica.
- Reduce dispersión de información.
- Ordena la relación longitudinal con el paciente.

### 8.2 Historial de atenciones por paciente

Debe mantenerse.

Justificación:

- Es indispensable para evolución clínica.
- Permite revisar antecedentes sin depender de memoria.
- Aporta trazabilidad asistencial.

### 8.3 Registro de tratamiento realizado

Debe mantenerse.

Justificación:

- Es el contenido clínico central de cada sesión.
- Es la base para evaluar evolución y consistencia de atención.

### 8.4 Registro de antecedentes clínicos generales

Patologías, medicamentos y alergias deben mantenerse.

Justificación:

- Son fundamentales para seguridad clínica y contextualización del paciente.
- Son información base para personalizar la atención.

### 8.5 Monto asociado a cada atención

Debe mantenerse, aunque más maduro.

Justificación:

- Vincula clínica con operación económica.
- Aporta memoria de valorización del trabajo realizado.

### 8.6 Agendamiento desde la ficha del paciente

Debe mantenerse.

Justificación:

- Reduce fricción entre atención y continuidad.
- Facilita cerrar la sesión con un próximo paso claro.

### 8.7 Fotografías clínicas

Debe mantenerse.

Justificación:

- Tiene enorme valor para seguimiento evolutivo.
- Mejora la calidad del registro clínico.
- Puede ser diferencial fuerte del producto final.

### 8.8 Recordatorios de próxima atención

Debe mantenerse como concepto.

Justificación:

- Responde a una necesidad real de recurrencia.
- Ayuda a sostener adherencia del paciente.
- Es especialmente relevante en podología de control periódico.

### 8.9 Atajos de contacto y ubicación

Deben mantenerse.

Justificación:

- Ahorran tiempo operativo.
- Tienen valor real en la coordinación diaria.
- Alinean la app con el trabajo concreto de la podóloga.

## 9. Funcionalidades que deberían rediseñarse

No se trata de eliminarlas, sino de replantearlas para que respondan mejor al trabajo clínico real.

### 9.1 Relación entre recordatorio, control sugerido y cita agendada

Debe rediseñarse.

Justificación:

- Hoy parecen capas cercanas pero no del todo unificadas.
- El producto necesita una sola narrativa clara de continuidad del paciente.
- La podóloga debe entender en segundos cuál es el próximo estado del caso.

### 9.2 Registro de atención como experiencia de cierre clínico

Debe rediseñarse.

Justificación:

- Hoy registra información útil, pero no parece cerrar el episodio completo.
- Necesita sentirse como el final natural de una atención.
- Debería dejar resuelto qué pasó, qué se cobró y qué sigue.

### 9.3 Dashboard

Debe rediseñarse.

Justificación:

- Hoy informa, pero todavía no dirige suficientemente la operación.
- El dashboard futuro debería ayudar a priorizar acciones del día, seguimientos pendientes y oportunidades de gestión clínica.

### 9.4 Historial clínico

Debe rediseñarse en su lectura funcional.

Justificación:

- Hoy conserva memoria, pero puede evolucionar hacia una lectura más útil para seguimiento comparativo.
- El objetivo no es acumular registros, sino hacerlos clínicamente interpretables.

### 9.5 Gestión del cobro

Debe rediseñarse.

Justificación:

- El monto por sí solo no resuelve la realidad administrativa de una consulta.
- La podóloga necesita una experiencia más clara de ingreso, confirmación y seguimiento económico.

### 9.6 Visualización de fotografías

Debe rediseñarse.

Justificación:

- La foto ya existe como activo clínico.
- El siguiente salto es volverla legible, comparable y útil en la evolución.

### 9.7 Captura de antecedentes clínicos

Debe rediseñarse su aprovechamiento funcional.

Justificación:

- La información ya se registra.
- El valor futuro está en cómo la aplicación la usa para mejorar decisiones y seguimiento.

## 10. Funcionalidades faltantes

Comparando la Beta actual con una clínica podológica moderna, faltan capacidades importantes para una operación madura.

### 10.1 Historia clínica más profunda

Falta una anamnesis podológica más rica, por ejemplo:

- motivo de consulta;
- antecedentes relevantes del problema actual;
- evolución del cuadro;
- factores de riesgo;
- observaciones por zona anatómica.

### 10.2 Evolución clínica estructurada

Falta una forma más clara de seguir problemas específicos en el tiempo, no solo sesiones aisladas.

### 10.3 Gestión de pagos completa

Faltan elementos como:

- estado de pago;
- método de pago;
- saldos;
- caja diaria;
- resumen de ingresos;
- cuentas por cobrar.

### 10.4 Confirmación y reprogramación de citas

Falta una gestión de agenda más madura con acciones claras de:

- confirmar;
- reprogramar;
- justificar cancelación;
- dejar trazabilidad del cambio.

### 10.5 Segmentación de pacientes

Falta distinguir y operar mejor grupos relevantes, por ejemplo:

- pacientes diabéticos;
- pacientes crónicos;
- pacientes frecuentes;
- pacientes inactivos;
- pacientes con seguimiento atrasado.

### 10.6 Planes de tratamiento o control

Falta la lógica de plan clínico sostenido en el tiempo.

Esto es importante porque muchos pacientes no viven una sola atención, sino un proceso.

### 10.7 Reportes funcionales

Faltan reportes de gestión clínica y operativa, por ejemplo:

- pacientes atendidos por período;
- ingresos por período;
- pacientes por retornar;
- cancelaciones;
- frecuencia de patologías;
- productividad clínica.

### 10.8 Gestión documental clínica

Faltan elementos como:

- consentimientos;
- indicaciones entregadas;
- fichas descargables;
- documentos asociados al paciente.

### 10.9 Uso avanzado de fotografías

Falta:

- comparación antes y después;
- selección por atención;
- lectura cronológica más clínica;
- apoyo a seguimiento visual.

### 10.10 Operación multiagenda o clínica más compleja

Si la plataforma evoluciona, faltan capacidades para escenarios más robustos:

- más de una profesional;
- más de una agenda;
- recursos o boxes;
- trazabilidad de quién atendió.

### 10.11 Inventario e insumos

Falta un dominio operacional de control de materiales e insumos clínicos.

### 10.12 Auditoría funcional

Falta visibilidad sobre cambios relevantes del uso, por ejemplo:

- quién registró una atención;
- quién modificó una cita;
- qué cambios ocurrieron en una ficha.

Esto no se plantea aquí como seguridad, sino como trazabilidad funcional de la operación.

## 11. Mapa funcional de la futura plataforma

La futura Podología Clínica Next Generation debería estructurarse como una plataforma por dominios funcionales claros. A continuación se propone un mapa base.

### 11.1 Pacientes

Dominio para:

- registro maestro de pacientes;
- identificación;
- contacto;
- dirección;
- clasificación;
- estado de actividad.

### 11.2 Historia Clínica

Dominio para:

- anamnesis;
- antecedentes;
- patologías;
- medicamentos;
- alergias;
- observaciones permanentes.

### 11.3 Agenda

Dominio para:

- citas;
- confirmaciones;
- reprogramaciones;
- cancelaciones;
- carga diaria;
- planificación operativa.

### 11.4 Atención Clínica

Dominio para:

- apertura de sesión;
- tratamiento realizado;
- hallazgos;
- procedimientos;
- notas de atención;
- cierre de la sesión.

### 11.5 Evolución Clínica

Dominio para:

- seguimiento longitudinal;
- controles;
- recurrencias;
- evolución por problema;
- comparativa entre atenciones.

### 11.6 Fotografías Clínicas

Dominio para:

- captura;
- organización;
- comparación;
- lectura temporal;
- documentación visual del caso.

### 11.7 Seguimiento y Recordatorios

Dominio para:

- próximos controles;
- pacientes por retornar;
- estados de seguimiento;
- acciones pendientes;
- recuperación de pacientes inactivos.

### 11.8 Comunicación con Pacientes

Dominio para:

- contacto rápido;
- recordatorios de cita;
- confirmaciones;
- mensajes de seguimiento;
- registro de interacción.

### 11.9 Pagos y Caja

Dominio para:

- cobros;
- estados de pago;
- medios de pago;
- saldos;
- cierres diarios;
- rendimiento económico.

### 11.10 Reportes y Gestión

Dominio para:

- indicadores clínicos;
- indicadores operativos;
- productividad;
- recurrencia;
- ingresos;
- seguimiento de agenda.

### 11.11 Inventario

Dominio para:

- insumos;
- materiales;
- control de stock;
- consumos clínicos.

### 11.12 Auditoría Operacional

Dominio para:

- trazabilidad de acciones;
- cambios en fichas;
- cambios en agenda;
- seguimiento de actividad del equipo.

### 11.13 Configuración Clínica

Dominio para:

- parámetros de atención;
- catálogos clínicos;
- motivos frecuentes;
- tipos de control;
- reglas operativas del centro.

## Conclusión general

La Beta actual ya tiene una virtud muy importante: no es solo una maqueta administrativa, sino una herramienta que efectivamente intenta acompañar la práctica clínica real de una podóloga.

Su núcleo funcional actual está bien orientado:

- paciente;
- ficha;
- atención;
- historial;
- agenda;
- seguimiento.

Ese núcleo debe preservarse.

Sin embargo, la Beta todavía opera más como un sistema de registro clínico básico con apoyo administrativo, que como una plataforma clínica integral.

La mayor oportunidad funcional hacia la siguiente generación no está en agregar módulos aislados, sino en fortalecer la continuidad del ciclo completo:

1. conocer al paciente;
2. atenderlo;
3. registrar con claridad;
4. cerrar clínica y administrativamente;
5. definir el siguiente paso;
6. asegurar su retorno;
7. convertir la información acumulada en gestión clínica real.

Si la futura plataforma logra ordenar ese ciclo con claridad, consistencia y baja fricción, va a convertirse en una herramienta realmente diferencial para la operación podológica diaria.
