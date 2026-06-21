# QA Modelo Conceptual de Datos v1

**Documento auditado:** `docs/02_architecture/DATA_MODEL_CONCEPTUAL_v1.md`  
**Fuentes de contraste:** `DOMINIO_CANONICO_PODOLOGIA_v1.1.md`, `ARQUITECTURA_CONCEPTUAL_v1.1.md`, `CANONICAL_DATA_FOUNDATION_PODOLOGIA.md`, `QA_CANONICAL_DATA_FOUNDATION.md`, `INSIGHTS_CLIENTE_CONSTANZA_001.md`  
**Fecha:** Junio 2026  
**Resultado:** Auditoría conceptual, sin modificación del documento auditado.

---

## Veredicto

**Aprobado con observaciones.**

El Modelo Conceptual de Datos v1 es coherente con el dominio, la arquitectura conceptual y el Canonical Data Foundation. Los 9 Bounded Contexts están bien motivados, la separación entre clínica, agenda, seguimiento, economía, relaciones comerciales, documentos y analítica es correcta, y el documento evita diseño técnico prematuro.

Las observaciones pendientes no obligan a rechazar el modelo, pero sí deben corregirse antes de convertirlo en arquitectura de datos. Los puntos más relevantes son: ajustar inconsistencias de dependencias entre BC7 y BC2, completar eventos documentales y visuales, aclarar el versionado de acuerdos con centros como evento explícito, y reforzar el control de BC5 para que no derive en contexto de dios.

---

## Resumen ejecutivo

El documento logra una buena traducción DDD del producto. Los contextos reflejan la arquitectura aprobada: BC2 concentra el núcleo clínico; BC3 Agenda y BC4 Seguimiento quedan separados; BC6 Económico no invade clínica; BC7 separa centros médicos y liquidaciones; BC8 preserva documentos clínico-legales; BC9 queda como proyección derivada sin Aggregate Roots.

La decisión de que **AtenciónClínica sea Aggregate Root independiente** es correcta. Una atención tiene ciclo de vida, inmutabilidad, eventos y responsabilidades propias; si viviera dentro de Paciente, el agregado Paciente se volvería demasiado grande y caro de proteger.

La decisión de que **FotografíaClínica sea Aggregate Root independiente** también está justificada por el Dominio Canónico y el CDF: la fotografía puede asociarse a una atención, al perfil del paciente o a un contexto longitudinal; además, la imagen es evidencia clínica inmutable con metadatos propios.

La separación entre **RelaciónConCentro** y **Liquidación** es correcta. La primera representa el vínculo y reglas comerciales con una entidad externa; la segunda representa un cierre económico de período. Esta separación protege la captura instantánea y permite versionar acuerdos.

El principal problema del documento no está en la estructura, sino en algunas fronteras mal expresadas: BC7 declara que no debe depender de BC2, pero Liquidación referencia AtenciónClínica; BC2 declara no saber de documentos, pero aparece como consumidor de ConsentimientoFirmado; y la sección de interacción entre BC2 y BC3 tiene una dirección confusa. Estos ajustes son conceptuales, no estructurales.

---

## Hallazgos críticos

No se detectan hallazgos críticos que obliguen a rechazar el modelo.

El documento puede servir como base conceptual para la etapa siguiente, siempre que las observaciones medias se corrijan antes de diseñar datos persistentes.

---

## Hallazgos medios

### 1. BC7 prohíbe depender de BC2, pero Liquidación referencia AtenciónClínica

El modelo dice correctamente que BC7 Relaciones Comerciales no debe depender de BC2 Clínico porque las liquidaciones no necesitan contenido clínico. Sin embargo, el agregado Liquidación declara que referencia externamente AtenciónClínica por lista de IDs.

Esto no necesariamente rompe el modelo, pero está mal expresado: una liquidación no debería depender de la atención clínica como entidad clínica, sino de hechos económicos o snapshots operacionales ya expuestos por BC6.

Riesgo: abrir una dependencia circular o filtrar datos clínicos a un contexto comercial.

Recomendación: BC7 debe liquidar desde Cobros, Ítems económicos o eventos/snapshots económicos originados por BC6. Si necesita recordar que cierto trabajo provino de una atención, que sea como referencia opaca o snapshot sin acceso a contenido clínico.

### 2. BC2 aparece como consumidor de ConsentimientoFirmado

BC2 declara que no sabe si el paciente firmó consentimiento, lo cual protege bien la independencia clínica. Pero el evento ConsentimientoFirmado lista a BC2 como consumidor para asociar el consentimiento al registro del paciente.

Esto introduce una tensión: si BC2 almacena o gestiona esa asociación, empieza a depender de BC8 Documental.

Recomendación: BC8 debe ser la fuente de verdad documental. BC2 puede mostrar una referencia de lectura o recibir una proyección no autoritativa, pero no debería cambiar su modelo clínico por la existencia de un consentimiento.

### 3. Faltan eventos documentales y visuales importantes

La lista de Domain Events incluye AtenciónClínicaCerrada, CobroGenerado, CobroAnulado, ConsentimientoFirmado, SeguimientoCreado, SeguimientoResuelto, CitaModificada, LiquidaciónConfirmada y PacienteRegistrado.

Faltan eventos relevantes pedidos por el objetivo y ya sugeridos por el CDF:

- InformeDeSesiónGenerado
- InformeDeSesiónEntregado
- FotografíaClínicaCapturada
- FotografíaClínicaAsociada
- AcuerdoCentroVersionado
- ConsentimientoRevocado
- ConsentimientoReemplazado

Riesgo: perder trazabilidad documental/visual o no poder sostener captura instantánea en documentos y acuerdos comerciales.

### 4. BC5 Shared Kernel está bien identificado, pero su alcance necesita una regla más estricta

BC5 como Configuración Operacional es correcto: TipoDeAtención, Arancel y ZonaDomiciliaria son catálogos/valores compartidos. El documento reconoce el riesgo de contexto de dios.

La observación es que BC5 incluye "valor por modalidad" y podría terminar absorbiendo reglas de centros médicos, recargos, validaciones clínicas, permisos o convenios. Eso debe estar más claramente prohibido.

Recomendación: BC5 debe contener vocabulario y valores base/versionados, pero no reglas transaccionales. Las reglas de centro pertenecen a BC7; decisiones económicas a BC6; decisiones clínicas a BC2.

### 5. AcuerdoComercial aparece versionado en entidades, pero no como evento de dominio

El documento incorpora HistorialDeAcuerdos y menciona versionar reglas del acuerdo, lo que responde bien al QA del CDF. Sin embargo, falta el evento explícito **AcuerdoCentroVersionado**.

Riesgo: cambios de términos comerciales no queden integrados al flujo de liquidación ni a auditoría.

Recomendación: agregar un evento de cambio/versionado de acuerdo con fecha efectiva, centro, versión anterior/nueva y alcance de aplicación.

### 6. La relación Cobro "de forma independiente" requiere precisión

BC6 dice que puede generar cobros asociados a una atención "o de forma independiente". El Dominio Canónico permite cobros por conjunto de atenciones o conceptos administrativos validados, pero prohíbe cobros sin trabajo clínico.

Riesgo: leer "independiente" como cobro sin origen clínico.

Recomendación: reemplazar conceptualmente "independiente" por "no necesariamente asociado a una atención individual, pero siempre justificado por trabajo clínico o concepto administrativo validado".

### 7. La dirección BC2 → BC3 en interacciones está confusa

La sección "BC2 → BC3 (Clínico → Agenda)" describe que BC3 publica un evento cuando una cita se atiende y BC2 puede usarlo para facilitar una atención. La dirección del encabezado contradice el contenido y también la prohibición de que BC2 dependa de BC3.

Recomendación: renombrar la interacción como BC3 → BC2 por evento operacional, o dejarla como "BC3 publica, BC2 puede reaccionar sin depender estructuralmente".

---

## Hallazgos menores

### 1. Hay errores tipográficos en nombres de conceptos

Se observan nombres como `RelacióConCentro` y `EvolucióClínica`. Son menores, pero conviene corregirlos antes de que esos nombres se copien a documentos posteriores.

### 2. BC9 sin Aggregate Roots es correcto

BC9 Analítico como contexto de solo lectura con modelos de lectura es una buena decisión. No debe tener raíces de agregado mientras solo derive Dashboard y Reportes.

### 3. RelaciónConCentro como raíz está bien elegida

La raíz no debe ser Centro Médico como entidad externa, sino la relación de la profesional/organización con ese centro. Esto está correctamente modelado.

### 4. InformeDeSesión como Aggregate Root es defendible

Aunque deriva de AtenciónClínica, una vez generado/entregado adquiere identidad histórica, snapshot y ciclo documental propio. La raíz está justificada.

### 5. Consentimiento como raíz independiente está bien elegido

El consentimiento puede existir antes de una atención específica y tiene vida documental/legal propia. Su independencia respecto de AtenciónClínica es coherente con el Dominio Canónico.

### 6. El documento evita diseño técnico prematuro

Las menciones a tablas, SQL, Supabase, migraciones, APIs y código aparecen como exclusiones o lenguaje incidental. No se proponen tablas, no se escribe SQL y no se diseña Supabase.

---

## Riesgos futuros

### 1. Dependencias ocultas mediante lectura directa

BC3, BC4, BC6, BC7 y BC8 necesitan datos de BC2 o BC5. Si esa lectura se implementa sin snapshots o proyecciones controladas, los contextos quedarán acoplados al modelo clínico.

### 2. BC5 puede crecer como catálogo universal

Si TipoDeAtención empieza a cargar reglas clínicas, económicas, de centros, permisos o comportamiento de agenda, BC5 dejará de ser Shared Kernel y se volverá contexto de dios.

### 3. Eventos insuficientes para documentos y fotografías

Sin eventos de informe generado/entregado y fotografía capturada/asociada, el sistema podría no cumplir la trazabilidad documental y visual exigida por el CDF.

### 4. Plan de Tratamiento puede presionar a BC2

El modelo reconoce el riesgo. Cuando Plan de Tratamiento llegue, deberá ser raíz propia o subcontexto claramente delimitado dentro de BC2, sin mezclarse con AtenciónClínica ni Seguimiento.

### 5. Multi-profesional y SaaS pueden tensionar Profesional ↔ Organización

El modelo usa MembresíaOrganización como objeto de valor de Profesional. Para SaaS y múltiples organizaciones, la membresía podría necesitar identidad y ciclo de vida propio en una revisión futura.

### 6. Liquidaciones pueden capturar información clínica de más

Si BC7 trabaja directamente con atenciones en vez de cobros/snapshots económicos, puede filtrar datos clínicos a un contexto comercial.

---

## Recomendaciones concretas

1. Aprobar el modelo conceptual con observaciones antes de avanzar a arquitectura de datos.

2. Mantener los 9 Bounded Contexts; no sobra ninguno y no falta uno obligatorio para el alcance actual.

3. Mantener BC2 Clínico aislado de Agenda, Económico y Documental como autoridad clínica.

4. Ajustar BC7 para que liquide desde BC6 o desde snapshots económicos, no desde AtenciónClínica como entidad clínica.

5. Aclarar que cualquier referencia de BC7 a AtenciónClínica es opaca y no concede acceso a contenido clínico.

6. Evitar que BC2 consuma ConsentimientoFirmado como modificación de su agregado; BC8 debe preservar la autoridad documental.

7. Agregar eventos: InformeDeSesiónGenerado, InformeDeSesiónEntregado, FotografíaClínicaCapturada, FotografíaClínicaAsociada, AcuerdoCentroVersionado, ConsentimientoRevocado y ConsentimientoReemplazado.

8. Precisar que BC5 no contiene reglas de negocio transaccionales; solo catálogos, valores base y parámetros consultables.

9. Precisar que Cobro puede no asociarse a una atención individual, pero nunca puede existir sin trabajo clínico o concepto administrativo validado.

10. Corregir el encabezado de interacción BC2/BC3 para que la dirección conceptual no contradiga las dependencias prohibidas.

11. Evaluar en futura versión si MembresíaOrganización debe pasar de objeto de valor a entidad con ciclo de vida, especialmente para expansión SaaS.

12. Mantener BC9 sin Aggregate Roots mientras sea derivado y de solo lectura.

---

## Conclusión final

El Modelo Conceptual de Datos v1 está bien planteado y es coherente con el dominio, la arquitectura conceptual, el CDF y los insights de Constanza. La separación de contextos es madura, los Aggregate Roots principales están bien elegidos y el documento respeta la captura instantánea, la inmutabilidad y la política de eliminación en su intención general.

El veredicto es **Aprobado con observaciones** porque aún hay ajustes importantes de frontera y eventos. Corregidos esos puntos, el modelo quedará apto para evolucionar hacia SaaS, centros médicos, multi-profesional, documentos clínicos, evolución clínica avanzada y planes de tratamiento sin hipotecar el diseño futuro.
