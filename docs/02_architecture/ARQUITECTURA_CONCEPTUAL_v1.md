# Arquitectura Conceptual — Agenda Podológica

**Versión:** 1.0  
**Estado:** Fundacional  
**Fecha:** Junio 2026  
**Autor:** Roberto Rojas  
**Fuentes:** DOMINIO_CANONICO_PODOLOGIA_v1.1.md · INSIGHTS_CLIENTE_CONSTANZA_001.md · PROJECT_CHARTER.md · AUDITORIA_FUNCIONAL_BETA.md

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

---

## 1. Módulos del producto

Un módulo es una unidad funcional cohesionada del producto con responsabilidades claras, pantallas propias y límites definidos con otros módulos. La siguiente lista cubre el producto completo, incluyendo fases futuras.

---

### Grupo A — Fundación (transversal)

Estos módulos no pertenecen a ningún dominio clínico específico pero hacen posible que el resto del producto exista y sea seguro.

---

**M01 — Autenticación y Acceso**

Gestiona la identidad del profesional dentro de la plataforma. Registro, inicio de sesión, recuperación de contraseña, cierre de sesión, y validación de que quien accede tiene permiso para hacerlo.

Es la puerta de entrada al sistema. Todo lo demás está detrás de esta puerta.

Responsabilidad única: saber quién es el usuario y si puede entrar.

---

**M02 — Organización y Configuración**

Gestiona la identidad de la organización clínica y las preferencias generales del profesional. Nombre del centro o consulta, datos de la profesional, logotipo, información de contacto, y configuración básica de operación.

Este módulo también alberga los catálogos configurables del sistema: tipos de atención, parámetros de agenda, zonas domiciliarias y cualquier otro dato que la profesional define una vez y el sistema usa en todos lados.

Responsabilidad única: definir quién es la organización y cómo quiere que funcione el sistema.

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

Contiene: fecha y contexto de la atención (domicilio, consultorio, centro), tipo de atención realizada, tratamientos y procedimientos ejecutados, hallazgos clínicos, notas de la sesión, indicaciones entregadas al paciente, monto cobrado o concepto económico vinculado, y la sugerencia de próxima atención.

El cierre de una atención es el evento más importante del producto. Debe sentirse como el final natural de una sesión clínica: dejó resuelto qué pasó, qué se cobró y qué sigue.

Responsabilidad única: registrar y cerrar cada sesión clínica como un hecho histórico trazable.

---

**M05 — Evolución Clínica**

Proporciona la lectura longitudinal del caso clínico de un paciente: cómo ha evolucionado su estado a través de múltiples atenciones, qué condiciones han mejorado, cuáles persisten, qué tratamientos se han probado.

Este módulo no crea datos propios: los lee e interpreta desde el historial de atenciones del paciente. Es una lente, no un formulario.

Su valor real aparece cuando el paciente tiene varias atenciones registradas. En la primera sesión este módulo está vacío. Con el tiempo se convierte en la herramienta más valiosa para entender a un paciente crónico o recurrente.

Responsabilidad única: hacer que el historial de atenciones sea clínicamente legible, no solo cronológicamente listable.

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

Límite crítico: este módulo gestiona el retorno del paciente, no el objetivo terapéutico del caso. La gestión de planes clínicos con objetivos, frecuencia y criterio de cierre pertenece al futuro Plan de Tratamiento (M17), no a este módulo.

Responsabilidad única: asegurar que ningún paciente que deba volver quede en el olvido.

---

### Grupo D — Visual Clínico

---

**M08 — Fotografías Clínicas**

Gestiona el registro visual del estado clínico del paciente. Captura o carga imágenes, las asocia a una atención o al perfil clínico del paciente, y permite leerlas longitudinalmente como evidencia de evolución.

Su valor principal no es la imagen individual sino la secuencia: las fotografías tomadas a lo largo del tiempo que muestran si un tratamiento funcionó.

Este módulo está fuera del alcance de Fase 1 por decisión documentada en el Project Charter. Se planifica para Fase 2.

Responsabilidad única: documentar visualmente el estado clínico y hacer esa evidencia comparable en el tiempo.

---

### Grupo E — Económico

Este grupo es el más complejo del producto. Sus módulos parecen simples pero se entrelazan de formas no obvias. Cada módulo de este grupo tiene una responsabilidad específica que no debe solaparse con los demás.

---

**M09 — Cobros**

Gestiona el registro económico de cada trabajo clínico realizado. Cada cobro tiene un monto, un tipo de atención asociado, un estado (pendiente, pagado, parcial, anulado), y un medio de pago registrado.

El cobro puede corresponder a una atención directa con paciente particular o a una atención realizada en un centro médico cuyo pago llega después por liquidación.

En Fase 1 este módulo opera de forma básica: monto, tipo de atención, estado de pago, directo al profesional. La complejidad de centros, zonas y liquidaciones es Fase 2.

Responsabilidad única: dejar constancia del hecho económico que cada atención clínica genera.

---

**M10 — Arancel y Tipos de Atención**

Gestiona el catálogo de tipos de atención y sus valores. La profesional define qué tipos de atención ofrece (podología normal, onicocriptosis, pie diabético, y los que ella configure), y asigna un valor base a cada uno.

Este catálogo es la fuente de verdad que el módulo de Cobros usa para pre-completar montos al registrar una atención. La profesional puede modificar el valor en cada atención, pero el Arancel evita que tenga que escribirlo de cero cada vez.

En Fase 2 este módulo se expande para soportar valores diferenciados por centro médico: el mismo tipo de atención puede tener un precio distinto según el centro donde se realiza.

Responsabilidad única: definir qué tipos de atención existen y cuánto valen en cada contexto.

---

**M11 — Centros Médicos**

Gestiona la relación de la profesional con los centros médicos donde trabaja. Cada centro tiene un nombre, una modalidad de relación (comisión por porcentaje, monto fijo por atención, liquidación mensual), y una tabla de valores específica para esa relación.

Los pacientes atendidos en un centro pueden ser pacientes del centro (enviados por él) o pacientes propios de la profesional que asisten al centro. Esta distinción afecta quién cobra al paciente y cómo se liquida a la profesional.

Este módulo es Fase 2.

Responsabilidad única: gestionar la relación comercial y operativa de la profesional con cada centro externo donde trabaja.

---

**M12 — Zonas de Atención Domiciliaria**

Gestiona la configuración de zonas geográficas para la atención a domicilio y el recargo diferenciado que aplica a cada zona. La profesional define sus zonas (por nombre, sector o descripción) y asigna un valor adicional a cada una.

Al registrar una atención domiciliaria, la profesional selecciona la zona e indica si aplica recargo. El sistema usa esa configuración para calcular o sugerir el cobro total.

Este módulo no calcula distancias ni trabaja con mapas: opera sobre zonas definidas manualmente por la profesional.

Este módulo es Fase 2.

Responsabilidad única: reflejar el costo real del traslado en el cobro de atenciones domiciliarias.

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

Gestiona la generación, personalización y distribución de documentos formales asociados a la práctica clínica. En Fase 2 incluye dos documentos:

**Consentimiento Informado:** formulario clínico-legal que autoriza la realización de un procedimiento. Puede generarse en blanco para completar a mano, o pre-rellenado con los datos del paciente y la profesional. Es imprimible y enviable por correo.

**Informe de Sesión:** resumen clínico de una atención ya registrada. Se genera automáticamente con los datos de la atención. Es imprimible y enviable por correo al paciente.

Ambos documentos requieren: plantillas base editables, integración con los datos del paciente y la profesional, generación de documento imprimible, y envío por correo electrónico.

Este módulo esconde complejidad técnica mayor que su descripción funcional sugiere. Ver sección de Riesgos Arquitectónicos.

Este módulo es Fase 2.

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

Información que no debe mostrar: estadísticas acumuladas, tendencias, métricas de productividad, gráficos de evolución mensual. Eso pertenece a Reportes (M16).

El criterio de utilidad del Dashboard es uno solo: al mirarlo, la profesional sabe inmediatamente qué hacer a continuación.

En Fase 1 este módulo opera con una versión básica: agenda del día + seguimientos pendientes. El resumen financiero cotidiano se suma en Fase 2 junto con el módulo de Cobros completo.

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

Registro detallado de quién hizo qué, cuándo y sobre qué entidad. Quién modificó una ficha, quién canceló una cita, quién registró un cobro. No como herramienta punitiva sino como garantía de calidad clínica.

---

**M22 — Comunicación con Pacientes**

Canal de contacto directo con el paciente desde la plataforma: recordatorios de cita, mensajes de seguimiento, confirmaciones. En la Beta existía como atajo a WhatsApp. En la versión futura podría incluir mensajería integrada.

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
    ├── M05 Evolución Clínica (lee atenciones históricas)
    ├── M07 Seguimiento (generado al cerrar atención)
    ├── M08 Fotografías Clínicas (asociadas a una atención)
    ├── M09 Cobros (originados por una atención)
    └── M14 Documentos Clínicos (Informe de Sesión generado desde atención)
```

---

### Ramificaciones del módulo económico

El grupo económico tiene dependencias internas que determinan su orden de construcción:

```
M10 Arancel y Tipos de Atención
    ↓ (informa valores a)
M09 Cobros
    ↓ (datos de cobros a centros alimentan)
M13 Liquidaciones
    ↑
M11 Centros Médicos ──→ M10 Arancel (tabla por centro)
    ↑
M12 Zonas Domiciliarias ──→ M09 Cobros (recargo sobre atención)
```

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

Los módulos de Fase 1 son los que directamente responden a las condiciones de éxito del Project Charter:

> "Una podóloga pueda registrar un paciente nuevo y su historia clínica en menos de 3 minutos."  
> "Una podóloga pueda abrir la ficha de un paciente existente, revisar su historial y registrar una nueva atención en el flujo de una consulta real."  
> "La agenda permita visualizar el día, crear citas y cambiar su estado sin fricción."  
> "El sistema de seguimiento permita identificar pacientes con atención pendiente."  
> "Todo lo anterior funcione en un dispositivo móvil con la misma calidad que en escritorio."

---

### Módulos de Fase 1

| Módulo | Justificación de inclusión |
|---|---|
| **M01 — Autenticación** | Sin esto no hay plataforma. |
| **M02 — Organización y Configuración (básico)** | Perfil de la profesional. Catálogo de tipos de atención. |
| **M03 — Pacientes** | Es el núcleo. Sin pacientes no hay producto. |
| **M04 — Atención Clínica** | Es el corazón clínico del sistema. |
| **M05 — Evolución Clínica (básica)** | Vista del historial que conecta atenciones. No requiere módulo propio completo: puede ser una vista dentro del paciente. |
| **M06 — Agenda** | "El nervio central del negocio". Obligatorio. |
| **M07 — Seguimiento y Recordatorios (básico)** | En el Charter y es crítico para la recurrencia podológica. |
| **M09 — Cobros (básico)** | Monto + tipo + estado de pago. Sin esto la podóloga no puede registrar la dimensión económica de su trabajo. |
| **M10 — Arancel y Tipos de Atención (básico)** | Catálogo editable. Necesario para que el cobro tenga sentido sin escribir montos de cero. |
| **M15 — Dashboard Cotidiano (básico)** | Agenda del día + seguimientos pendientes. Orienta la operación diaria. |

---

### Qué queda fuera de Fase 1 y por qué

| Módulo | Motivo de exclusión |
|---|---|
| M08 — Fotografías Clínicas | Decisión documentada en el Project Charter. |
| M11 — Centros Médicos | Requiere M09 y M10 maduros. Complejidad elevada. Fase 2. |
| M12 — Zonas Domiciliarias | Requiere M09 maduro y M11. Fase 2. |
| M13 — Liquidaciones | Requiere M11. Fase 2. |
| M14 — Documentos Clínicos | Requiere M03 y M04 maduros. Complejidad técnica no trivial. Fase 2. |
| M16 — Reportes | Sin historial suficiente, los reportes no tienen valor real. Fase 2. |
| M17–M22 — Módulos futuros | Ver Fase 3 y más. |

---

## 5. Fases futuras

---

### Fase 2 — Operación completa de una podóloga independiente

El objetivo de Fase 2 es que la plataforma cubra la operación completa de una podóloga que trabaja sola: con pacientes particulares, en centros médicos, con atenciones domiciliarias, con documentación clínica formal y con visión económica de su práctica.

Módulos nuevos en Fase 2:
- **M08** — Fotografías Clínicas
- **M11** — Centros Médicos
- **M12** — Zonas de Atención Domiciliaria
- **M13** — Liquidaciones
- **M14** — Documentos Clínicos (Consentimiento + Informe de Sesión)
- **M16** — Reportes (básicos)

Módulos de Fase 1 que se enriquecen en Fase 2:
- **M05** — Evolución Clínica: de vista básica a módulo con seguimiento estructurado por problema.
- **M09** — Cobros: se conecta con Centros Médicos y Zonas.
- **M10** — Arancel: se expande con tablas de valores diferenciadas por centro.
- **M15** — Dashboard: se incorpora el resumen financiero cotidiano.

---

### Fase 3 — Plataforma para centros con múltiples profesionales

El objetivo de Fase 3 es que la plataforma soporte organizaciones con más de un profesional: agenda compartida, visibilidad configurable, trazabilidad por usuario, y herramientas de gestión del equipo clínico.

Módulos nuevos en Fase 3:
- **M20** — Multiusuario y Roles
- **M21** — Auditoría Operacional

Módulos existentes que escalan en Fase 3:
- **M02** — Organización: soporte para múltiples profesionales, sedes y configuración de acceso.
- **M06** — Agenda: agenda compartida entre profesionales, vistas por profesional.
- **M15** — Dashboard: versión administrativa para el responsable del centro.
- **M16** — Reportes: reportes de equipo, productividad comparativa.

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

Estos son los módulos o relaciones entre módulos que presentan mayor riesgo de crecer de forma descontrolada, ser mal delimitados o generar deuda conceptual que se pague tarde con alto costo.

---

### Riesgo 1 — El módulo de Cobros puede convertirse en un sistema contable

**Por qué:** el cobro empieza como "monto por atención" pero Constanza revela que la realidad es más compleja: cobros directos, cobros por centro, cobros con comisión, cobros diferenciados por zona, pagos parciales, liquidaciones mensuales, saldos pendientes, cuentas por cobrar. Sin control de alcance, este módulo se convierte en una aplicación contable dentro de la plataforma clínica.

**Cómo mitigarlo:** definir con precisión qué preguntas responde Cobros en cada fase y qué preguntas no responde. Fase 1: ¿cuánto cobra esta atención y está pagado? Fase 2: ¿qué le debe cada centro? Lo que queda fuera de esa definición no entra aunque parezca razonable.

---

### Riesgo 2 — Centro Médico tiene tentáculos en múltiples módulos

**Por qué:** el Centro Médico toca: Pacientes (¿de qué centro viene este paciente?), Agenda (¿quién agenda?), Cobros (¿quién cobra y cuánto?), Arancel (tabla de valores por centro), Liquidaciones (¿qué le deben a la profesional?). Un módulo con cinco puntos de contacto es un módulo que puede generar dependencias circulares y lógica dispersa si no se diseña con cuidado.

**Cómo mitigarlo:** tratar al Centro Médico como una entidad de referencia que otros módulos consultan, no como un módulo que se mete en la lógica de otros. El Centro Médico debe saber quién es y qué acordó con la profesional. Lo demás (cobrar, registrar, liquidar) es responsabilidad de otros módulos que lo referencian.

---

### Riesgo 3 — Seguimiento puede absorber responsabilidades del Plan de Tratamiento

**Por qué:** el módulo de Seguimiento ya gestiona retorno del paciente, recordatorios, estados de contacto y vencimientos. Si se le agrega "qué estamos tratando", "cuántas sesiones lleva el plan" y "bajo qué criterio cerramos el caso", el módulo está haciendo el trabajo de un sistema de planes terapéuticos. La confusión ya estaba presente en la Beta.

**Cómo mitigarlo:** el criterio de corte es claro: Seguimiento gestiona el retorno. Plan de Tratamiento gestiona el objetivo clínico. Mientras Plan de Tratamiento no exista, Seguimiento puede indicar un "motivo" o "contexto" del retorno, pero no se convierte en el responsable del plan.

---

### Riesgo 4 — El Dashboard puede perder su naturaleza operacional

**Por qué:** la presión de agregar "una métrica más" al Dashboard es permanente. Cada módulo tiene datos que "sería útil ver ahí". Con el tiempo el Dashboard deja de ser operacional y se convierte en un resumen del sistema, que es lo que Constanza explícitamente rechaza.

**Cómo mitigarlo:** el Dashboard tiene un criterio de admisión estricto: solo entra lo que permite tomar una acción inmediata. Si la información no dispara una acción concreta en el próximo minuto, pertenece a Reportes, no al Dashboard.

---

### Riesgo 5 — Documentos Clínicos esconde complejidad técnica mayor a la aparente

**Por qué:** Consentimiento Informado e Informe de Sesión parecen "simples de generar". La realidad es que involucran: gestión de plantillas (con variables que se rellenan), generación de documentos en formato imprimible, integración de datos del paciente y la profesional, envío por correo electrónico desde la aplicación, y posiblemente soporte para firma. Cada uno de estos pasos tiene complejidad técnica real.

**Cómo mitigarlo:** no tratar este módulo como un "feature pequeño". Requiere decisiones de implementación concretas (motor de plantillas, generador de PDF, integración de correo) que deben planificarse antes de construirlo.

---

### Riesgo 6 — El núcleo clínico es el más caro de cambiar

**Por qué:** Pacientes, Historia Clínica y Atención Clínica son la base de todo. Un error en su diseño se propaga a Evolución Clínica, Seguimiento, Cobros, Fotografías y Documentos. Cambiar la estructura de una Atención Clínica después de que hay datos reales es la operación más costosa que puede ocurrir.

**Cómo mitigarlo:** invertir proporcionalmente más tiempo de diseño conceptual en estos módulos que en cualquier otro. La Atención Clínica en particular requiere consenso explícito sobre: qué información contiene, cuándo se considera "cerrada", qué es inmutable y qué puede anotarse después.

---

### Riesgo 7 — Evolución Clínica como entidad vs. vista

**Por qué:** si Evolución Clínica es solo una vista (leer atenciones históricas), es simple pero tiene capacidad funcional limitada. Si se convierte en una entidad gestionable (con su propio ciclo de vida, sus propios registros de evolución por problema), tiene más valor clínico pero también más complejidad y riesgo de crear duplicación de información.

**Cómo mitigarlo:** en Fase 1, tratarla como vista enriquecida. En Fase 2, evaluar si la práctica real demanda gestionarla como entidad propia. No tomar esa decisión por anticipado.

---

## 7. Mapa conceptual completo

Representación textual del producto completo por capas funcionales, desde la fundación hasta las capacidades futuras. La posición en el mapa refleja dependencias: lo que está más abajo depende de lo que está encima.

```
╔══════════════════════════════════════════════════════════════════════╗
║                           TRANSVERSAL                               ║
║        M01 Autenticación · M02 Organización y Configuración         ║
║                        · Trazabilidad ·                             ║
╠══════════════════════════════════════════════════════════════════════╣
║                        NÚCLEO CLÍNICO                               ║
║                                                                      ║
║           M03 Pacientes ──── Historia Clínica (integrada)           ║
║                    │                                                 ║
║                    ▼                                                 ║
║              M04 Atención Clínica                                   ║
║                    │                                                 ║
║                    ▼                                                 ║
║           M05 Evolución Clínica (longitudinal)                      ║
╠══════════════════════════════════════════════════════════════════════╣
║    OPERACIONAL (Fase 1)          │     VISUAL CLÍNICO (Fase 2)      ║
║                                  │                                   ║
║  M06 Agenda                      │  M08 Fotografías Clínicas        ║
║  M07 Seguimiento y Recordatorios │                                   ║
║  M15 Dashboard Cotidiano         │                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                    ECONÓMICO (Fase 1 básico → Fase 2 completo)      ║
║                                                                      ║
║  M09 Cobros                                                          ║
║  M10 Arancel y Tipos de Atención                                    ║
║  M11 Centros Médicos (Fase 2)                                       ║
║  M12 Zonas de Atención Domiciliaria (Fase 2)                        ║
║  M13 Liquidaciones (Fase 2)                                         ║
╠══════════════════════════════════════════════════════════════════════╣
║   DOCUMENTAL (Fase 2)            │   ANÁLISIS Y GESTIÓN             ║
║                                  │                                   ║
║  M14 Documentos Clínicos         │  M16 Reportes (Fase 2)           ║
║   · Consentimiento Informado     │                                   ║
║   · Informe de Sesión            │                                   ║
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
| M02 | Organización y Configuración | Fase 1 (básico) |
| M03 | Pacientes (Historia Clínica) | Fase 1 |
| M04 | Atención Clínica | Fase 1 |
| M05 | Evolución Clínica | Fase 1 (vista) → Fase 2 (entidad) |
| M06 | Agenda | Fase 1 |
| M07 | Seguimiento y Recordatorios | Fase 1 (básico) |
| M08 | Fotografías Clínicas | Fase 2 |
| M09 | Cobros | Fase 1 (básico) → Fase 2 (completo) |
| M10 | Arancel y Tipos de Atención | Fase 1 (básico) → Fase 2 (completo) |
| M11 | Centros Médicos | Fase 2 |
| M12 | Zonas de Atención Domiciliaria | Fase 2 |
| M13 | Liquidaciones | Fase 2 |
| M14 | Documentos Clínicos | Fase 2 |
| M15 | Dashboard Cotidiano | Fase 1 (básico) → Fase 2 (completo) |
| M16 | Reportes | Fase 2 |
| M17 | Plan de Tratamiento | Fase 3 |
| M18 | Derivaciones | Fase 3 |
| M19 | Insumos e Inventario | Fase 3 |
| M20 | Multiusuario y Roles | Fase 3 |
| M21 | Auditoría Operacional | Fase 3 |
| M22 | Comunicación con Pacientes | Fase 3 |

---

*Este documento es el plano funcional del producto. No describe cómo se implementa: describe qué existe, cómo se relaciona y en qué orden debe construirse.*  
*Cualquier cambio al alcance de un módulo, incorporación de un módulo nuevo o cambio en la asignación de fases requiere revisión y nueva versión de este documento antes de impactar en el desarrollo.*
