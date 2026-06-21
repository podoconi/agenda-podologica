# QA Modelo Conceptual de Datos v1.1

**Documento auditado:** `docs/02_architecture/DATA_MODEL_CONCEPTUAL_v1.1.md`  
**Fuente principal de contraste:** `docs/03_qa/QA_DATA_MODEL_CONCEPTUAL_v1.md`  
**Fuentes conceptuales relacionadas:** `DOMINIO_CANONICO_PODOLOGIA_v1.1.md`, `ARQUITECTURA_CONCEPTUAL_v1.1.md`, `CANONICAL_DATA_FOUNDATION_PODOLOGIA.md`, `INSIGHTS_CLIENTE_CONSTANZA_001.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoria conceptual, sin modificacion del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

`DATA_MODEL_CONCEPTUAL_v1.1.md` incorpora correctamente las observaciones principales de `QA_DATA_MODEL_CONCEPTUAL_v1.md` y mantiene la estructura conceptual previamente aprobada. No se altera la separacion de los 9 Bounded Contexts, se corrige la dependencia indebida de BC7 hacia BC2, se agregan los eventos documentales, visuales y comerciales solicitados, y se refuerzan los limites de BC5, BC6, BC8 y BC3/BC2.

Las observaciones restantes no invalidan el documento, pero deben resolverse antes de pasar a Arquitectura de Datos Relacional Conceptual. El punto mas importante es evitar que los nuevos eventos entre BC6 y BC7 se lean como una dependencia circular o como traslado de reglas comerciales hacia BC6.

---

## Resumen ejecutivo

La version 1.1 cumple el objetivo de revision: corrige los problemas detectados en v1 sin romper el modelo conceptual. Los 9 Bounded Contexts se mantienen: Identidad y Organizacion, Clinico, Agenda, Seguimiento, Configuracion Operacional, Economico, Relaciones Comerciales, Documental y Analitico.

BC7 Relaciones Comerciales queda mejor aislado de BC2 Clinico. La Liquidacion ya no se construye desde AtencionClinica ni desde contenido clinico, sino desde Cobros y snapshots economicos originados por BC6. Cualquier referencia a trabajo clinico queda expresada como identificador opaco o dato ya capturado en el snapshot economico.

BC8 sigue siendo la fuente de verdad documental. BC2 puede mantener una proyeccion auxiliar de lectura sobre consentimiento o informes, pero no modifica HistoriaClinica ni AtencionClinica por eventos documentales. Esta correccion preserva el nucleo clinico.

Los eventos solicitados fueron incorporados: `InformeDeSesionGenerado`, `InformeDeSesionEntregado`, `FotografiaClinicaCapturada`, `FotografiaClinicaAsociada`, `AcuerdoCentroVersionado`, `ConsentimientoRevocado` y `ConsentimientoReemplazado`. En el documento aparecen con tildes en los nombres conceptuales, lo cual es aceptable en esta etapa.

El documento sigue evitando diseno tecnico prematuro. Las menciones a tablas, SQL, Supabase, migraciones, API, UI o codigo aparecen como exclusiones o advertencias conceptuales, no como diseno de implementacion.

---

## Hallazgos criticos

No se detectan hallazgos criticos.

La version 1.1 puede considerarse conceptualmente apta para servir como entrada a la Arquitectura de Datos Relacional Conceptual, con las observaciones medias resueltas o explicitamente controladas.

---

## Hallazgos medios

### 1. Posible dependencia circular conceptual entre BC6 y BC7

La correccion principal de BC7 es adecuada: BC7 depende de BC6 para liquidar desde cobros y snapshots economicos, no desde BC2. Sin embargo, el evento `AcuerdoCentroVersionado` declara a BC6 como consumidor para tomar nota de que cobros futuros de ese centro usaran nuevos terminos.

Esto puede leerse como una dependencia de BC6 hacia BC7. Como BC7 ya depende de BC6 para liquidaciones, existe riesgo de introducir una relacion circular BC6 <-> BC7.

Recomendacion: aclarar que BC7 es la autoridad de acuerdos comerciales y que BC6 solo captura snapshots economicos al momento del cobro. Si BC6 necesita datos de centro, deben llegar como parametros/snapshots ya resueltos, no como reglas comerciales vivas de BC7.

### 2. El evento `LiquidacionConfirmada` tambien puede reforzar el acoplamiento BC7 -> BC6 -> BC7

`LiquidacionConfirmada` indica que BC6 marca cobros como liquidados. Conceptualmente es razonable, pero debe cuidarse que BC6 no incorpore el ciclo completo de liquidaciones ni reglas de centros.

Riesgo: que BC6 empiece a conocer estados comerciales de liquidacion mas alla de una marca economica minima.

Recomendacion: mantener en BC6 solo una referencia economica minima al estado de liquidacion del cobro, sin trasladar reglas de calculo, acuerdo, comision o validacion comercial.

### 3. La proyeccion documental de BC2 esta bien planteada, pero la frase "ni dependa de BC8" requiere precision

BC2 declara que puede mantener una proyeccion de lectura del estado documental y que esa proyeccion no forma parte del modelo clinico ni depende de BC8. Mas adelante, la interaccion BC8 -> BC2 indica que BC2 actualiza esa proyeccion por eventos documentales.

La intencion es correcta, pero la redaccion puede parecer contradictoria: si la proyeccion nace de eventos de BC8, si existe una dependencia de lectura/proyeccion, aunque no una dependencia estructural ni canonica.

Recomendacion: expresar que BC2 no depende estructuralmente de BC8 y que su flujo clinico no queda bloqueado por documentos, pero que puede mantener una proyeccion no autoritativa alimentada por eventos de BC8.

### 4. `AcuerdoCentroVersionado` esta incorporado, pero debe quedar asociado a autoridad comercial, no economica

El evento fue agregado correctamente y ayuda a sostener trazabilidad de acuerdos. El riesgo es que la reaccion de BC6 se entienda como aplicacion de reglas comerciales futuras desde el contexto economico.

Recomendacion: en la arquitectura siguiente, el versionado del acuerdo debe permanecer bajo BC7. BC6 debe registrar montos y snapshots, no interpretar acuerdos de centros.

---

## Hallazgos menores

### 1. Los 9 Bounded Contexts se conservan correctamente

La estructura aprobada no fue alterada. No se agregan contextos innecesarios ni se elimina ninguno de los contextos requeridos para el alcance actual.

### 2. BC7 ya no depende de BC2 Clinico

La version 1.1 corrige el hallazgo principal de v1. BC7 liquida desde BC6 y declara explicitamente que no accede a contenido clinico.

### 3. Liquidacion queda correctamente construida desde Cobros y snapshots economicos

La raiz `Liquidacion` contiene items economicos basados en Cobros de BC6 y referencia esos cobros por identidad. Esto es coherente con captura instantanea y separacion de contextos.

### 4. Las referencias clinicas en BC7 quedan opacas

El documento declara que cualquier referencia al trabajo clinico es un identificador opaco o un atributo de modalidad incluido en el snapshot economico. Esto protege BC2.

### 5. BC8 mantiene autoridad documental

BC8 queda como fuente de verdad para consentimientos e informes. La generacion, firma, revocacion, reemplazo, entrega y preservacion de documentos viven en BC8.

### 6. BC2 solo mantiene proyeccion documental auxiliar

BC2 no incorpora documentos a HistoriaClinica ni a AtencionClinica. La proyeccion de lectura es aceptable siempre que no bloquee el flujo clinico ni se vuelva fuente de verdad.

### 7. Los eventos faltantes fueron agregados

La version 1.1 agrega correctamente los eventos solicitados para informes, fotografias, acuerdos y consentimientos. Esta correccion mejora trazabilidad documental, visual y comercial.

### 8. BC5 queda mejor limitado

BC5 se restringe a catalogos, valores base y parametros consultables. El documento prohibe expresamente reglas transaccionales, clinicas, comerciales de centros y permisos.

### 9. BC6 corrige el riesgo de cobros independientes

El documento aclara que un Cobro no puede existir sin trabajo clinico o concepto administrativo validado. Esto corrige la ambiguedad de la version anterior.

### 10. La relacion BC3 -> BC2 queda bien expresada por evento

`CitaAtendida` nace en BC3 y BC2 puede reaccionar sin dependencia estructural. La atencion puede existir sin cita previa, lo cual preserva el modelo clinico.

### 11. MembresiaOrganizacion queda bien acotada

En Fase 1 se mantiene como objeto de valor dentro de Profesional. La version 1.1 deja abierta su evolucion a entidad independiente en un escenario SaaS multi-organizacion.

### 12. No hay diseno tecnico prematuro

No se proponen tablas, SQL, Supabase, migraciones, APIs, UI ni codigo. Las menciones a esos conceptos funcionan como exclusiones o advertencias, no como especificacion tecnica.

---

## Riesgos pendientes

### 1. Circularidad BC6/BC7 durante la arquitectura relacional

Si BC6 necesita leer reglas vivas de BC7 para generar cobros, y BC7 necesita leer cobros de BC6 para liquidar, se formara una dependencia circular dificil de sostener. La solucion conceptual es separar autoridad de acuerdo, captura de snapshot economico y calculo de liquidacion.

### 2. Proyecciones auxiliares convertidas en fuentes de verdad

La proyeccion documental en BC2 y los modelos analiticos de BC9 deben mantenerse derivados. Si se usan como autoridad, se romperia la fuente de verdad documental de BC8 y la integridad de los contextos fuente.

### 3. BC5 puede crecer si se agregan modalidades y centros sin control

Aunque v1.1 delimita bien BC5, la presion futura por valores por modalidad, centros, permisos o reglas clinicas puede volverlo demasiado amplio. El limite debe conservarse durante el diseno de datos.

### 4. Planes de tratamiento aun no tienen frontera definitiva

El documento reconoce el riesgo de Plan de Tratamiento. La decision futura debera evitar que AtencionClinica, Seguimiento y EvolucionClinica se mezclen en una misma entidad conceptual.

### 5. SaaS multi-organizacion puede exigir promover MembresiaOrganizacion

La nota incorporada es correcta, pero el diseno futuro debe evitar cerrar el camino a multiples profesionales, multiples organizaciones o roles por membresia.

---

## Recomendaciones concretas

1. Aprobar `DATA_MODEL_CONCEPTUAL_v1.1.md` como base para la Arquitectura de Datos Relacional Conceptual.

2. Mantener los 9 Bounded Contexts sin agregar nuevos contextos en esta etapa.

3. Conservar BC7 como consumidor de Cobros/snapshots de BC6 para liquidaciones, sin acceso a BC2.

4. Precisar que `AcuerdoCentroVersionado` no convierte a BC6 en consumidor de reglas comerciales vivas de BC7.

5. Precisar que `LiquidacionConfirmada` solo puede reflejar en BC6 un estado economico minimo del cobro, no trasladar logica de liquidacion.

6. Ajustar la redaccion conceptual de la proyeccion documental de BC2: no dependencia estructural de BC8, si proyeccion no autoritativa alimentada por eventos.

7. Mantener BC8 como unica fuente de verdad documental para consentimientos e informes.

8. Mantener BC5 como Shared Kernel restringido a catalogos, valores base y parametros consultables.

9. Mantener la regla de BC6: no hay Cobro sin trabajo clinico o concepto administrativo validado.

10. En la siguiente etapa, validar explicitamente que no se generen claves conceptuales o relaciones que reintroduzcan BC7 -> BC2 o BC6 <-> BC7 como dependencia circular fuerte.

---

## Conclusion final

`DATA_MODEL_CONCEPTUAL_v1.1.md` incorpora correctamente las observaciones de `QA_DATA_MODEL_CONCEPTUAL_v1.md` y mantiene sana la estructura conceptual aprobada. La separacion de contextos mejora, los eventos faltantes fueron agregados y el modelo queda mas preparado para documentos clinicos, centros medicos, multi-profesionalidad, SaaS y planes de tratamiento.

El veredicto es **Aprobado con observaciones**. La version es apta para avanzar a Arquitectura de Datos Relacional Conceptual, cuidando especialmente que BC6 y BC7 no queden circularmente acoplados y que las proyecciones documentales no se conviertan en fuente de verdad.
