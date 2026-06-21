# QA Arquitectura Conceptual v1

**Documento auditado:** `docs/02_architecture/ARQUITECTURA_CONCEPTUAL_v1.md`  
**Documentos de referencia:** `DOMINIO_CANONICO_PODOLOGIA_v1.1.md`, `INSIGHTS_CLIENTE_CONSTANZA_001.md`, `PROJECT_CHARTER.md`, `AUDITORIA_FUNCIONAL_BETA.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoria conceptual, sin modificacion del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

La arquitectura conceptual es coherente con el dominio canonico, los insights de Constanza, el Project Charter y la auditoria funcional de la Beta. Define correctamente el nucleo Pacientes - Atencion Clinica - Agenda, reconoce los 22 modulos necesarios, evita mezclar implementacion tecnica y propone una secuencia de fases razonable.

Las observaciones no invalidan la arquitectura, pero si deben resolverse antes de usar este documento como base directa para diseno tecnico o implementacion. Los principales ajustes requeridos son: afinar limites entre Organizacion/Configuracion y Arancel, justificar mejor la inclusion de Cobros y Arancel basicos en Fase 1, corregir algunas dependencias de Zonas, explicitar firma digital/simple en Documentos Clinicos y dejar mas nitido el criterio para postergar Fotografias Clinicas sin perder su valor diferencial.

---

## Resumen ejecutivo

La arquitectura acierta al reconocer que Agenda Podologica no debe partir desde tecnologia ni pantallas, sino desde un mapa funcional del producto. La division por grupos es comprensible: fundacion, nucleo clinico, operacional, visual clinico, economico, documental, analisis y gestion, y modulos futuros. Esta estructura conversa bien con el Dominio Canonico y con la conclusion de la auditoria Beta: fortalecer el ciclo completo de conocer al paciente, atenderlo, registrar, cerrar, cobrar, definir el siguiente paso y asegurar retorno.

El nucleo esta bien definido. Pacientes con Historia Clinica, Atencion Clinica y Agenda son efectivamente el minimo que convierte la plataforma en una herramienta clinica diaria y no solo en una base de fichas. Seguimiento y Dashboard basico aparecen correctamente como extensiones operacionales de ese nucleo.

Fase 1 es realista si se interpreta de forma estricta como una version utilizable, no completa. La inclusion de Cobros basico y Arancel basico es defendible porque la Beta ya registraba monto cobrado y porque los insights de Constanza muestran que la dimension economica esta unida al cierre de atencion. Sin embargo, la arquitectura debe proteger mejor esa decision para que no se lea como entrada anticipada de pagos, caja, liquidaciones o contabilidad.

La postergacion de Centros Medicos, Liquidaciones, Documentos Clinicos, Reportes, Multiusuario e Inventario es correcta. La postergacion de Zonas tambien es razonable, aunque su dependencia declarada de Centros Medicos no esta bien justificada: las zonas domiciliarias nacen de atencion a domicilio, no de centros medicos.

Documentos Clinicos debe mantenerse en Fase 2, salvo que se decida incorporar en Fase 1 una capacidad minima no integrada, como descarga o impresion de consentimiento en blanco. Fotografias Clinicas tambien puede mantenerse en Fase 2 por coherencia con el Charter, aunque debe quedar como candidato de reconsideracion si se busca un diferencial clinico temprano o si la validacion con usuarias confirma que su ausencia reduce adopcion.

---

## Hallazgos criticos

No se detectan hallazgos criticos que obliguen a rechazar la arquitectura.

El documento auditado no contradice el nucleo del Dominio Canonico, no incorpora SQL, Supabase, API, UI ni codigo, y mantiene una separacion conceptual suficientemente clara para avanzar.

---

## Hallazgos medios

### 1. M02 y M10 tienen solapamiento conceptual

M02 Organizacion y Configuracion declara que alberga "catalogos configurables del sistema", incluyendo tipos de atencion. M10 Arancel y Tipos de Atencion tambien gestiona el catalogo de tipos de atencion y sus valores.

Esto introduce una redundancia funcional parcial: los tipos de atencion viven a la vez en Configuracion y en Arancel. El problema no es grave, pero puede generar ambiguedad futura sobre quien crea, edita y valida esos tipos.

Recomendacion: M02 debe administrar preferencias generales y contenedor de configuracion; M10 debe ser el dueno funcional del catalogo de tipos de atencion y valores. M02 puede enlazar o exponer configuracion, pero no ser propietario del arancel.

### 2. Cobros basico en Fase 1 esta bien, pero requiere limite mas explicito

El Project Charter deja fuera del alcance inicial la "gestion completa de pagos y caja", pero la arquitectura incluye M09 Cobros basico en Fase 1. Esto es aceptable porque la Beta ya registraba monto cobrado y porque el cierre de atencion requiere dejar constancia economica minima.

La tension aparece si "Cobros" se interpreta como modulo financiero completo. En Fase 1 debe quedar reducido a: monto, tipo de atencion, estado simple de pago y medio de pago opcional o minimo. No debe incluir caja diaria, comprobantes, saldos complejos, cuentas por cobrar avanzadas, liquidaciones ni reporteria financiera.

Recomendacion: renombrar internamente el alcance de Fase 1 como "registro economico basico de la atencion" o agregar una nota que distinga Cobros basico de gestion de pagos/caja.

### 3. Arancel basico en Fase 1 esta justificado, pero no debe absorber configuracion general

La inclusion de M10 en Fase 1 es coherente con los insights: Constanza necesita tipos de atencion configurables y valores base. Tambien reduce friccion en la atencion, porque evita escribir montos desde cero.

El riesgo es que Arancel se convierta prematuramente en una matriz completa por centro, modalidad, zona y convenio. Eso pertenece a Fase 2.

Recomendacion: Fase 1 debe limitar M10 a tipos de atencion y valor base particular. Valores por centro, recargos por zona, liquidaciones y reglas comerciales deben quedar fuera.

### 4. Dependencia de Zonas Domiciliarias respecto de Centros Medicos no esta bien fundamentada

El documento excluye M12 Zonas Domiciliarias de Fase 1 indicando que requiere M09 maduro y M11. La dependencia de M09 es correcta, pero la dependencia de M11 no lo es: las zonas domiciliarias provienen de la modalidad de atencion a domicilio particular, no de centros medicos.

Esto no obliga a adelantar M12, pero si conviene corregir su justificacion conceptual. Zonas puede estar en Fase 2 por complejidad de valorizacion domiciliaria y por no ser esencial para el nucleo, no porque dependa de Centros Medicos.

### 5. Documentos Clinicos omite firma digital/simple como subcapacidad y riesgo

M14 reconoce que Consentimiento Informado e Informe de Sesion pueden requerir "posiblemente soporte para firma", pero la arquitectura no incorpora explicitamente la firma digital/simple como riesgo ni como subcapacidad futura.

Dado que el consentimiento informado exige firma del paciente y de la profesional, esto debe quedar nombrado de forma explicita. La firma puede ser simple, manuscrita sobre documento impreso, firma capturada en pantalla, o eventualmente firma electronica avanzada si el marco legal lo exige. No corresponde resolverlo tecnicamente en este documento, pero si reconocerlo.

Recomendacion: agregar a riesgos futuros o al alcance de M14 una subcapacidad "firma digital/simple y trazabilidad de aceptacion", con definicion legal pendiente.

### 6. Documentos Clinicos en Fase 2 es correcto, pero existe una tension con disponibilidad permanente del consentimiento

Los insights de Constanza dicen que el consentimiento debe estar siempre disponible. La arquitectura lo posterga a Fase 2 por complejidad de plantillas, PDF, correo e integracion con datos. La postergacion es razonable si se habla del modulo completo.

Sin embargo, podria evaluarse una capacidad minima en Fase 1: consentimiento en blanco descargable o imprimible, sin integracion, sin envio por correo y sin firma digital. Esto no reemplaza M14, pero reduce riesgo operativo si el consentimiento es requerido desde el primer uso real.

Recomendacion: mantener M14 completo en Fase 2, pero documentar como decision abierta si Fase 1 debe incluir un consentimiento basico estatico.

### 7. Fotografias Clinicas en Fase 2 es coherente con Charter, pero debe quedar como decision vigilada

La arquitectura cumple el Project Charter al dejar M08 Fotografias Clinicas en Fase 2. Tambien reconoce su valor longitudinal. La auditoria Beta, sin embargo, indica que las fotografias ya existian, deben mantenerse y tienen enorme valor para seguimiento evolutivo.

La decision de postergarlas no es contradictoria, pero si tiene riesgo de producto: la ausencia de fotografias puede hacer que Fase 1 sea menos diferenciada para una podologa que ya vio valor en la Beta.

Recomendacion: mantener M08 en Fase 2 por ahora, pero agregar un criterio de reconsideracion: adelantar captura/carga simple de fotografias si la validacion de Fase 1 muestra que su ausencia limita adopcion, continuidad clinica o comparacion visual esencial.

### 8. Evolucion Clinica cambia de "vista" a "entidad" sin criterio de decision suficientemente formal

La arquitectura maneja bien la tension: M05 parte como vista en Fase 1 y podria evolucionar en Fase 2. Esto calza con el Dominio Canonico, que distingue Evolucion Clinica retrospectiva de Plan de Tratamiento prospectivo.

La observacion es que el documento dice "Fase 2 (entidad)" en el resumen, pero no define criterios para activar ese cambio. Sin criterios, podria duplicar informacion de Atencion Clinica o confundirse con Plan de Tratamiento.

Recomendacion: definir que M05 solo pasa de vista a entidad si existe una necesidad validada de agrupar evolucion por problema, lesion, pie, dedo o condicion longitudinal, sin convertirla en plan terapeutico.

---

## Hallazgos menores

### 1. Los 22 modulos estan correctamente identificados, pero algunos nombres podrian alinearse mejor al vocabulario canonico

"Arancel y Tipos de Atencion" esta bien nombrado segun los insights, pero "Cobros" podria inducir a pensar en caja o pagos completos. Para Fase 1 conviene hablar de "Cobro basico asociado a atencion" o precisar el limite en la descripcion.

### 2. Centros Medicos esta bien separado de Organizacion Clinica

La arquitectura corrige una necesidad surgida en los insights: Centro Medico es una entidad externa, no la organizacion clinica propia de la profesional. Este limite esta bien trazado y debe preservarse.

### 3. Dashboard esta bien delimitado frente a Reportes

La separacion entre Dashboard cotidiano y Reportes es consistente con Constanza: el dashboard debe responder "que hago ahora", no mostrar analitica decorativa. Esta es una buena decision arquitectonica.

### 4. Seguimiento esta correctamente separado de Plan de Tratamiento

El documento evita absorber objetivos terapeuticos dentro de Seguimiento. Esto corrige un riesgo detectado en Beta y respeta el Dominio Canonico.

### 5. Falta mencionar con mas fuerza trazabilidad en Fase 1

Auditoria Operacional completa esta postergada a Fase 3, lo cual es razonable. Pero el Dominio Canonico declara que toda accion relevante es trazable. Fase 1 deberia contemplar trazabilidad minima, aunque no exista M21 como modulo visible.

### 6. Comunicacion con Pacientes queda en Fase 3/Fase 4, pero los atajos simples pueden ser una capacidad operacional temprana

La Beta tenia atajos de WhatsApp y mapas. La arquitectura deja M22 para el futuro, correctamente si se entiende como mensajeria integrada. Aun asi, atajos externos simples podrian no requerir un modulo formal completo.

---

## Riesgos futuros

### 1. Riesgo de crecimiento economico descontrolado

Cobros, Arancel, Centros Medicos, Zonas y Liquidaciones forman un bloque de alta complejidad. Si se mezclan antes de tiempo, la plataforma puede convertirse en un sistema contable antes de consolidar su nucleo clinico.

### 2. Riesgo legal-documental en consentimiento informado

Consentimiento Informado no es solo un PDF. Requiere versionado de plantilla, datos usados, fecha, firma, trazabilidad de aceptacion, posible revocacion o reemplazo, y criterio legal de validez de firma simple o digital.

### 3. Riesgo de postergar demasiado la evidencia visual

Fotografias Clinicas no son parte del minimo estricto, pero si son un valor diferencial en podologia. Postergarlas es correcto por alcance, pero puede afectar percepcion de continuidad clinica si la usuaria espera comparar antes/despues desde temprano.

### 4. Riesgo de que Fase 1 sea utilizable solo en escritorio

La arquitectura cita la condicion de exito movil del Charter, pero no la traduce a riesgo arquitectonico. Para una podologa en consulta o domicilio, el uso movil no es accesorio.

### 5. Riesgo de mezclar pacientes propios, pacientes de centro y pacientes institucionales

La arquitectura reconoce origen del paciente, pero Fase 1 debe ser cuidadosa con no modelar en exceso CESFAM o centros complejos. A la vez, debe dejar espacio conceptual para que el origen no sea un texto suelto imposible de usar despues.

### 6. Riesgo de inmutabilidad clinica mal aplicada

Atencion Clinica cerrada debe ser inmutable segun el Dominio Canonico. La arquitectura lo reconoce como riesgo, pero Fase 1 necesitara distinguir entre editar borrador, cerrar atencion y agregar nota posterior.

### 7. Riesgo de que Organizacion y Profesional queden demasiado unipersonales

Fase 1 esta orientada a una podologa independiente, pero el Dominio Canonico establece que la organizacion clinica es el contenedor de datos. La arquitectura debe preservar ese modelo aunque la interfaz inicial sea unipersonal.

---

## Recomendaciones concretas

1. Mantener el veredicto arquitectonico general: la estructura modular es valida y puede usarse como base fundacional.

2. Ajustar el limite M02/M10: M02 configura la organizacion; M10 es propietario funcional de tipos de atencion y valores.

3. Precisar M09 en Fase 1 como registro economico basico de la atencion, no como gestion completa de pagos, caja o contabilidad.

4. Precisar M10 en Fase 1 como catalogo simple de tipos de atencion y valor base; valores por centro y reglas diferenciadas quedan para Fase 2.

5. Corregir la justificacion de M12: Zonas Domiciliarias depende de atencion domiciliaria y cobro, no de Centros Medicos.

6. Mantener M11 Centros Medicos, M13 Liquidaciones y M16 Reportes en Fase 2. La postergacion esta bien justificada por dependencia y complejidad.

7. Mantener M14 Documentos Clinicos completo en Fase 2, pero abrir decision sobre consentimiento en blanco o plantilla estatica en Fase 1 si la operacion lo exige.

8. Incorporar explicitamente firma digital/simple como riesgo documental y subcapacidad futura de M14.

9. Mantener M08 Fotografias Clinicas en Fase 2 por coherencia con el Charter, pero definir un criterio de reconsideracion para adelantar captura simple si la validacion de usuarias lo vuelve necesario.

10. Agregar trazabilidad minima transversal de Fase 1, aunque M21 Auditoria Operacional completa permanezca en Fase 3.

11. Definir criterios para que M05 Evolucion Clinica pase de vista a entidad: solo si se requiere seguimiento longitudinal por problema/lesion/estructura anatomica y sin absorber Plan de Tratamiento.

12. Mantener fuera del documento arquitectura tecnica, SQL, Supabase, API, UI y codigo. El documento auditado cumple bien esta regla.

---

## Conclusion final

La Arquitectura Conceptual v1 de Agenda Podologica esta bien orientada y es coherente con los documentos fundacionales. Sus 22 modulos cubren el producto completo sin omitir capacidades relevantes del dominio. El nucleo Pacientes - Atencion Clinica - Agenda esta correctamente definido y las fases reflejan una estrategia sana: primero utilidad clinica diaria, despues complejidad economica, documental y organizacional.

El documento debe aprobarse con observaciones porque hay ajustes conceptuales importantes, pero no estructurales. La arquitectura no necesita ser reemplazada; necesita ser afinada antes de pasar a diseno tecnico.

La recomendacion QA es avanzar con esta arquitectura como base fundacional, incorporando las observaciones sobre limites modulares, alcance economico de Fase 1, documentos clinicos con firma digital/simple, trazabilidad minima y criterios de reconsideracion para fotografias clinicas.
