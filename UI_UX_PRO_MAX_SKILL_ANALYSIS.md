# Analisis tecnico de UI/UX Pro Max

**Objeto analizado:** `.claude/skills/ui-ux-pro-max`  
**Fecha del analisis:** 2026-06-21  
**Alcance:** analisis documental y estatico completo; no se modifico el skill ni se genero implementacion.

## Resumen ejecutivo

UI/UX Pro Max es un sistema de inteligencia de diseno basado en recuperacion de conocimiento. No es un design system cerrado ni un generador visual autonomo: combina un flujo de trabajo obligatorio, un buscador BM25, reglas de razonamiento por tipo de producto y catalogos CSV de estilos, colores, tipografias, UX, interfaces, iconos, graficos y stacks tecnologicos.

Su filosofia central es **seleccionar el diseno segun producto, industria, audiencia y stack**, priorizando primero accesibilidad e interaccion, luego rendimiento y respuesta, y finalmente estilo visual. Propone generar siempre una recomendacion inicial de sistema de diseno, complementarla con busquedas especializadas y persistirla como un archivo maestro con excepciones por pagina.

El skill es amplio y util como herramienta de descubrimiento y checklist. Contiene 1.429 registros: 741 reglas o referencias generales y 688 recomendaciones para 13 stacks. Su mayor fortaleza es convertir una solicitud ambigua en una direccion visual razonada. Su mayor debilidad es que mezcla principios robustos con preferencias esteticas, datos de marketing no sustentados, reglas dependientes de versiones y especificaciones rigidas generadas por plantilla.

Para Next.js + Tailwind, debe integrarse como **capa de decision y validacion**, no como fuente ejecutable literal. Las recomendaciones elegidas deben convertirse en tokens semanticos, componentes accesibles y patrones responsive del proyecto. Antes de implementar, hay que resolver conflictos entre resultados, verificar compatibilidad con las versiones instaladas y validar contraste, interaccion, rendimiento y comportamiento responsive.

## 1. Alcance y arquitectura interna

### 1.1 Inventario

| Capa | Contenido | Funcion |
|---|---:|---|
| Instruccion | `SKILL.md` | Define prioridades, flujo obligatorio y checklist |
| Motor | 3 scripts Python | Busqueda BM25, razonamiento, salida y persistencia |
| Conocimiento general | 11 CSV, 741 filas | Producto, estilo, color, tipografia, UX, web, iconos, charts y React |
| Adaptadores | 13 CSV, 688 filas | Reglas especificas por tecnologia |
| Cache | 3 archivos `.pyc` | Artefactos compilados; no agregan reglas conceptuales |

Los adaptadores cubren Astro, Flutter, HTML/Tailwind, Jetpack Compose, Next.js, Nuxt UI, Nuxt.js, React Native, React, shadcn/ui, Svelte, SwiftUI y Vue.

### 1.2 Flujo operativo

1. Extraer tipo de producto, industria, estilo esperado y stack.
2. Ejecutar primero `--design-system`, declarado como paso obligatorio.
3. Buscar en paralelo producto, estilo, color, landing y tipografia.
4. Aplicar reglas de `ui-reasoning.csv` para priorizar coincidencias.
5. Complementar con busquedas de UX, charts, web, React o stack.
6. Sintetizar recomendaciones y, opcionalmente, persistir `design-system/MASTER.md`.
7. Permitir excepciones en `design-system/pages/[page].md`, que prevalecen sobre el maestro.
8. Verificar el checklist previo a entrega.

### 1.3 Naturaleza del motor

El buscador usa BM25 sobre columnas seleccionadas y devuelve por defecto tres resultados. Es recuperacion lexica: tokeniza, normaliza y puntua palabras, pero no comprende semantica profunda ni resuelve contradicciones por si solo. El generador agrega una capa de razonamiento basada en categorias y palabras clave, no en evaluacion visual del producto final.

## 2. Filosofia de diseno

La filosofia puede resumirse en siete ideas:

1. **Contexto antes que estilo.** El producto, la industria, la audiencia y la tarea determinan el patron visual.
2. **Usabilidad antes que ornamentacion.** En dashboards y productos operacionales, claridad, velocidad y densidad adecuada tienen precedencia.
3. **Accesibilidad como restriccion de entrada.** Contraste, foco, semantica, teclado y movimiento reducido son reglas prioritarias.
4. **Consistencia sistemica.** Colores, tipografia, iconos, espaciado, estados y efectos deben pertenecer a un mismo lenguaje.
5. **Respuesta visible a cada accion.** Hover, active, loading, exito, error y estados deshabilitados deben ser explicitos.
6. **Mobile first con mejora progresiva.** La interfaz parte en movil y gana estructura en breakpoints mayores.
7. **Maestro global con excepciones locales.** Las paginas heredan un sistema comun y solo documentan desviaciones justificadas.

El skill no promueve una estetica unica. Incluye minimalismo, glassmorphism, brutalismo, dashboards densos y otros estilos, pero exige que la seleccion sea compatible con el producto. Para salud, recomienda accesibilidad, calma, confianza y legibilidad; para herramientas operacionales, minimalismo funcional y jerarquia clara.

## 3. Principios UX

La jerarquia explicita de prioridades es:

| Prioridad | Dominio | Impacto declarado |
|---:|---|---|
| 1 | Accesibilidad | Critico |
| 2 | Touch e interaccion | Critico |
| 3 | Rendimiento | Alto |
| 4 | Layout y responsive | Alto |
| 5 | Tipografia y color | Medio |
| 6 | Animacion | Medio |
| 7 | Seleccion de estilo | Medio |
| 8 | Graficos y datos | Bajo |

Principios recurrentes:

- Toda accion debe producir feedback inmediato y comprensible.
- Las acciones asincronas deben bloquear doble envio y mostrar progreso.
- Los errores deben aparecer cerca de su causa y ser anunciables.
- Las acciones destructivas requieren confirmacion o un mecanismo equivalente de recuperacion.
- El estado activo y la ubicacion actual deben ser visibles.
- El historial, deep linking y boton atras deben conservar comportamiento predecible.
- El contenido asincrono debe reservar espacio para evitar layout shift.
- La animacion debe apoyar comprension, durar normalmente entre 150 y 300 ms y respetar `prefers-reduced-motion`.
- El color nunca debe ser el unico canal para comunicar estado.
- La informacion compleja debe ofrecer progresion de resumen a detalle.

## 4. Reglas de layout

### Reglas firmes

- Usar una anchura maxima consistente para el contenido principal.
- Limitar texto corrido a aproximadamente 65-75 caracteres por linea.
- Evitar scroll horizontal no intencional.
- Reservar dimensiones para imagenes, skeletons y contenido asincrono.
- Definir una escala de `z-index`, preferentemente 0, 10, 20, 30, 40 y 50.
- Evitar `overflow-hidden` como arreglo generico porque puede recortar contenido o foco.
- Contabilizar navbars, safe areas y otros elementos fijos.
- Preferir `dvh` o una solucion equivalente frente a `100vh` en movil.
- Usar grid para estructuras bidimensionales y flex para alineacion lineal.
- Mantener el mismo ancho de contenedor entre secciones relacionadas.

### Convenciones sugeridas

- Contenedor Tailwind: `max-w-7xl mx-auto`.
- Padding de pagina: `px-4 md:px-6 lg:px-8`.
- Gaps principales: `gap-4`, `gap-6`, `gap-8`.
- Dashboard denso: grid de 12 columnas, sidebar de 240 px, header de 56 px, filas de tabla de 36 px y padding de tarjeta de 12 px.

Estas medidas son defaults, no invariantes. El propio skill clasifica algunos dashboards densos como de soporte movil medio, por lo que se deben adaptar a la carga real y no copiar literalmente.

## 5. Sistema visual

El sistema visual se compone de cinco capas:

1. **Patron de pagina:** orden de secciones, CTA y estrategia de conversion.
2. **Estilo:** lenguaje estetico, efectos, complejidad, rendimiento y compatibilidad.
3. **Paleta:** roles primario, secundario, CTA, fondo, texto y borde.
4. **Tipografia:** pareja de fuentes, personalidad, uso y carga.
5. **Efectos:** sombras, movimiento, hover, profundidad y feedback.

Reglas visuales transversales:

- Usar un solo set coherente de iconos, con preferencia por Lucide o Heroicons.
- No usar emojis como iconos de interfaz.
- Verificar logos oficiales, no reconstruirlos de memoria.
- Mantener dimensiones de iconos estables y atributos de ancho/alto en SVG.
- Evitar hovers que desplacen el layout.
- Mantener contraste minimo 4.5:1 para texto normal.
- En modo claro, asegurar opacidad, bordes y texto suficientes.
- Usar nombres de color semanticos en vez de colores ligados al componente.

Para salud, los catalogos sugieren azul/cian, verde de salud y fondos claros. Es una orientacion contextual, no una obligacion: la paleta final debe validarse contra identidad de marca, contraste y diferenciacion de estados.

## 6. Patrones de navegacion

- Navegacion principal persistente para destinos de primer nivel.
- Sidebar para aplicaciones y dashboards con varias areas funcionales.
- Toggle o drawer accesible para la sidebar en movil.
- Estado activo visible mediante color, peso, fondo o subrayado.
- Breadcrumbs solo cuando existe una jerarquia real de tres o mas niveles.
- Deep links para vistas, filtros o estados que deban compartirse o restaurarse.
- Historial estable: no romper el boton atras con estado local opaco.
- Links internos mediante el mecanismo de routing del stack; en Next.js, `next/link`.
- Tabs para secciones hermanas, no para sustituir navegacion jerarquica profunda.
- Menus de acciones mediante patrones semanticos de menu, no `div` posicionados manualmente.
- Las barras fijas deben reservar espacio y no ocultar el primer contenido.

Para dashboards, la progresion recomendada es sidebar + header contextual + contenido principal. En drill-down se agregan breadcrumbs, retorno facil, contexto preservado y URLs profundas.

## 7. Reglas responsive

- Construir mobile first y agregar `md`, `lg` y `xl` segun necesidad.
- Cuerpo de texto de al menos 16 px en movil.
- Targets tactiles de al menos 44 x 44 px y, como recomendacion, 8 px entre targets adyacentes.
- Imagenes fluidas, proporciones reservadas y recursos adecuados por viewport.
- Tablas anchas con scroll controlado, columnas prioritarias o representacion alternativa en tarjetas.
- Evitar duplicar contenido distinto por breakpoint; cambiar presentacion, no significado.
- Reducir animaciones y complejidad visual en movil.
- Simplificar dashboards ejecutivos y densos en pantallas pequenas.
- Usar container queries para componentes cuyo comportamiento dependa de su contenedor.

El skill contiene dos juegos de viewports de prueba:

- UX general: 320, 375, 414, 768, 1024 y 1440 px.
- Checklist/Tailwind: 375, 768, 1024, 1440 px, y en otra regla 320, 375, 768, 1024, 1280, 1536 px.

La integracion debe unificar esta inconsistencia en una matriz propia. Se recomienda cubrir como minimo 320/375, 768, 1024, 1280/1440 y 1536, mas pruebas en anchos intermedios donde realmente se rompe el contenido.

## 8. Patrones de formularios

### Estructura

- Cada control tiene etiqueta visible y nombre accesible.
- El placeholder es ayuda, nunca sustituto de la etiqueta.
- Se usan tipos de input, `inputmode` y `autocomplete` apropiados.
- Los campos obligatorios se identifican de forma textual y consistente.
- Los inputs tienen altura y espaciado estables; el adaptador Tailwind sugiere `h-10 px-3`.
- Los grupos complejos usan fieldset/legend o componentes semanticos equivalentes.

### Validacion y estados

- Validar normalmente al salir del campo y siempre al enviar.
- Mostrar el error junto al campo afectado.
- Asociar mensajes mediante `aria-describedby` y anunciar errores globales con `role="alert"` o `aria-live`.
- Conservar el valor ingresado cuando existe error.
- Durante envio, deshabilitar el submit, conservar su geometria y mostrar progreso.
- Comunicar exito y error sin depender solo del color.
- Ofrecer mostrar/ocultar contrasena cuando corresponda.

### Integracion recomendada

El adaptador shadcn recomienda React Hook Form, `FormField`, `FormLabel`, `FormControl`, `FormMessage` y Zod. Esta combinacion es adecuada para formularios complejos, pero no es obligatoria: formularios simples pueden usar Server Actions o estado nativo siempre que mantengan semantica, validacion, autorizacion y feedback.

## 9. Patrones dashboard

El skill reconoce patrones especializados en vez de un dashboard universal:

| Patron | Uso adecuado | Riesgo principal |
|---|---|---|
| Data-Dense | Operacion, BI, reportes empresariales | Saturacion y baja adaptacion movil |
| Executive | 4-6 KPIs y resumen estrategico | Exceso de simplificacion |
| Real-Time Monitoring | Estado vivo, alertas y streaming | Carga, parpadeo y ruido |
| Drill-Down | Resumen a detalle preservando contexto | Navegacion profunda confusa |
| Comparative | Periodos, regiones o benchmarks | Dependencia excesiva del color |
| Predictive | Pronostico, confianza y anomalias | Presentar prediccion como certeza |
| User Behavior | Funnel, cohortes y recorridos | Privacidad y complejidad visual |

Reglas comunes:

- Priorizar tareas frecuentes y excepciones operacionales sobre decoracion.
- KPI cards con jerarquia clara y cantidad limitada por vista.
- Filtros visibles, estado persistente y opcion de limpiar.
- Tablas semanticas con ordenamiento, paginacion o virtualizacion cuando sea necesario.
- Skeletons que coincidan con la geometria final.
- Graficos elegidos por tipo de dato, no por estetica.
- Leyendas, etiquetas numericas y alternativa tabular para accesibilidad.
- Color de estado acompanado de texto, icono o patron.
- Vistas densas deben degradarse de forma deliberada en movil.

Para Agenda Podologica, el patron mas compatible es un dashboard operacional sobrio: agenda y pendientes primero, indicadores secundarios despues, y analitica avanzada separada de los flujos clinicos diarios.

## 10. Accesibilidad

La accesibilidad es la capa mas consistente del skill. Sus requisitos principales son:

- Contraste minimo 4.5:1 para texto normal.
- Foco visible mediante `:focus-visible` o equivalente.
- Orden de tabulacion coincidente con el orden visual y del DOM.
- Semantica HTML antes que ARIA.
- Nombre accesible para botones de solo icono.
- `alt` descriptivo para imagenes informativas y tratamiento decorativo para las restantes.
- Jerarquia secuencial de encabezados.
- Skip link en interfaces con navegacion extensa.
- Modales con foco inicial, trapping, cierre y devolucion de foco.
- Actualizaciones asincronas anunciadas mediante regiones vivas cuando corresponde.
- Errores de formulario perceptibles, asociados y anunciados.
- Reduccion o eliminacion de movimiento segun preferencia del usuario.
- Graficos con etiquetas y alternativa tabular.
- Navegacion y acciones completas por teclado.

Limitacion: el catalogo alterna referencias a WCAG AA y, para salud, una regla de razonamiento que exige WCAG AAA. Esa exigencia no se deriva de un analisis normativo del proyecto. Debe establecerse un objetivo formal de conformidad y aplicar AAA selectivamente donde aporte valor, sin declarar cumplimiento solo por seguir el skill.

## 11. Tokens de diseno

El generador persistente define una base inicial:

### Color

`--color-primary`, `--color-secondary`, `--color-cta`, `--color-background` y `--color-text`.

### Espaciado

| Token | Valor |
|---|---:|
| `--space-xs` | 4 px |
| `--space-sm` | 8 px |
| `--space-md` | 16 px |
| `--space-lg` | 24 px |
| `--space-xl` | 32 px |
| `--space-2xl` | 48 px |
| `--space-3xl` | 64 px |

### Elevacion

| Token | Uso |
|---|---|
| `--shadow-sm` | Separacion sutil |
| `--shadow-md` | Tarjetas y botones |
| `--shadow-lg` | Dropdowns y modales |
| `--shadow-xl` | Contenido destacado |

### Tokens ausentes o incompletos

El maestro no formaliza de manera suficiente:

- colores `foreground`, `muted`, `border`, `ring`, `success`, `warning`, `danger` e `info`;
- estados hover, active, disabled y selected;
- escala tipografica completa;
- pesos, line-height y tracking;
- radios semanticos;
- alturas de controles;
- z-index semantico;
- duraciones y curvas de movimiento;
- breakpoints;
- ancho de contenedores;
- tokens de charts y modo oscuro.

Por tanto, sus tokens son un punto de partida y no un contrato completo.

## 12. Reglas de espaciado

La escala base es de 4 px y usa principalmente 4, 8, 16, 24, 32, 48 y 64 px. Las reglas favorecen:

- `gap` o `space-y` en el contenedor en vez de margenes repetidos en hijos;
- padding responsive de pagina;
- espaciado interno consistente por tipo de componente;
- mayor densidad solo en superficies de datos;
- margenes negativos exclusivamente para solapamientos intencionales;
- valores arbitrarios solo para necesidades realmente unicas.

Existe una inconsistencia: el maestro genera tarjetas con 24 px, mientras el estilo Data-Dense propone 12 px. Debe resolverse por densidad y contexto mediante variantes, no dejando que una regla sobreescriba silenciosamente a la otra.

## 13. Reglas tipograficas

- Texto base movil de 16 px como minimo.
- Line-height de 1.5 a 1.75 en texto corrido.
- Longitud de linea de 65-75 caracteres.
- Escala modular y limitada; evitar tamanos arbitrarios.
- Diferencia clara de tamano o peso entre encabezados y cuerpo.
- Fuente de fallback metricamente compatible para reducir layout shift.
- En Next.js, cargar fuentes con `next/font` y aplicarlas desde el layout.
- Preferir variable fonts cuando sean compatibles y aporten ahorro.
- Truncar solo donde la perdida de contenido sea aceptable; ofrecer acceso al valor completo.

Parejas relevantes del catalogo:

- Inter / Inter para dashboards y administracion.
- Figtree / Noto Sans para interfaces medicas.
- Lexend / Source Sans 3 para confianza y accesibilidad.
- Atkinson Hyperlegible para maxima legibilidad.
- Plus Jakarta Sans para SaaS amistoso.

La seleccion final debe considerar idioma, cifras, signos clinicos, pesos disponibles, rendimiento y personalidad de marca. No debe elegirse solo por coincidencia de palabras clave.

## 14. Restricciones y limitaciones

### Restricciones explicitas del skill

- No usar emojis como iconos.
- No ocultar estados de foco.
- No usar contraste insuficiente.
- No introducir scroll horizontal en movil.
- No dejar contenido bajo elementos fijos.
- No usar animaciones prolongadas o ignorar movimiento reducido.
- No usar colores o tamanos arbitrarios sin sistema.
- No usar el color como unico indicador.
- No enviar formularios repetidamente durante una operacion asincrona.

### Limitaciones tecnicas detectadas

1. **Busqueda lexica limitada.** BM25 depende fuertemente de las palabras exactas y devuelve pocos candidatos por defecto.
2. **Conflictos no resueltos.** Salud puede seleccionar neumorphism, aunque sus sombras suaves suelen perjudicar contraste y affordance.
3. **Plantilla demasiado rigida.** El maestro genera radios, sombras, paddings y comportamientos de hover fijos sin derivarlos completamente del estilo elegido.
4. **Tokens incompletos.** Faltan varios roles necesarios para un design system de produccion.
5. **Versiones mezcladas.** El adaptador Tailwind menciona configuracion `content`/JIT de v3 y sintaxis de gradiente de v4. Debe aplicarse segun la version instalada.
6. **Next.js sensible a version.** Partial Prerendering, configuracion, caching y patrones de routing deben contrastarse con la version real.
7. **Afirmaciones no sustentadas.** Algunos CSV incluyen porcentajes de conversion o engagement sin fuente; no deben usarse como evidencia.
8. **Severidad no normalizada.** Aparecen `Critical`, `High`, `HIGH`, simbolos y calificaciones WCAG sin un esquema unico.
9. **Sin validacion automatizada.** El skill recomienda contraste, responsive y accesibilidad, pero no ejecuta axe, Lighthouse, tests visuales ni medicion de contraste.
10. **Sin evaluacion visual.** La generacion no inspecciona screenshots ni verifica que el resultado implementado cumpla la intencion.
11. **Runtime no disponible en esta sesion.** `python` y `py` no estaban expuestos en el shell actual, por lo que el CLI no pudo ejecutarse; el analisis se realizo sobre todo el codigo y los datos de forma estatica.

## 15. Recomendaciones

### Para usar el skill con rigor

1. Tratar la salida del generador como propuesta, no como decision final.
2. Formular consultas con producto, industria, audiencia, tarea, densidad y stack.
3. Revisar al menos los dominios UX, web, typography, color y stack despues de generar el sistema.
4. Registrar por que se acepta o rechaza cada recomendacion relevante.
5. Normalizar severidades y separar `must`, `should` y `could`.
6. Eliminar o etiquetar afirmaciones de conversion que no tengan fuente.
7. Versionar los datos por compatibilidad con Tailwind, Next.js y librerias.
8. Completar tokens semanticos antes de construir componentes.
9. Agregar validacion automatizada de contraste, teclado, HTML y responsive.
10. Verificar visualmente desktop y movil; el checklist textual no basta.

### Para Agenda Podologica

- Priorizar una interfaz clinica operacional, sobria y de alta legibilidad.
- Evitar neumorphism como estilo dominante pese a su recomendacion para salud.
- Separar flujos frecuentes de agenda, paciente y atencion de la analitica secundaria.
- Usar color semantico con texto e icono, especialmente para estados clinicos, agenda y cobros.
- Optimizar formularios para carga repetitiva, teclado, autocompletado y recuperacion de errores.
- Mantener densidad moderada: suficiente para operar, sin convertir cada pantalla en dashboard.
- Reservar dashboards densos para roles y tareas que realmente los necesitan.

## 16. Integracion con Next.js + Tailwind

### 16.1 Arquitectura recomendada

1. **App Router como estructura:** layouts para navegacion persistente y grupos de rutas por area funcional.
2. **Server Components por defecto:** datos y composicion en servidor; Client Components solo para interaccion local.
3. **Tailwind como capa de tokens y utilidades:** mapear roles semanticos, no dispersar hexadecimales por componentes.
4. **Componentes base accesibles:** usar primitives probadas o shadcn/ui, conservando semantica y foco.
5. **Variantes consistentes:** modelar tamano, tono, densidad y estado con `cva` o una estrategia equivalente.
6. **Formularios por complejidad:** HTML/Server Actions para casos simples; React Hook Form + Zod para interaccion compleja.
7. **Carga y errores por ruta:** `loading`, `error`, skeletons geometricamente estables y mensajes anunciables.
8. **Imagenes y fuentes optimizadas:** `next/image`, dimensiones o `fill`, `sizes`, `next/font` y prioridad solo para LCP.
9. **URLs como estado compartible:** filtros importantes, tabs y drill-down representados en search params o rutas.
10. **Seguridad en servidor:** validar y autorizar toda Server Action o Route Handler; la validacion de cliente es solo UX.

### 16.2 Traduccion de tokens a Tailwind

Crear una capa semantica equivalente a:

- `background`, `foreground`, `card`, `muted`, `border`, `input`, `ring`;
- `primary`, `secondary`, `accent`, `success`, `warning`, `danger`, `info` y sus foregrounds;
- escala de spacing coherente con 4/8/16/24/32/48/64;
- radios `sm`, `md`, `lg` por rol;
- sombras por elevacion, no por componente;
- z-index `base`, `sticky`, `dropdown`, `overlay`, `modal`, `toast`;
- duraciones `fast`, `normal`, `slow` dentro del rango recomendado;
- densidades `comfortable` y `compact` para formularios y tablas.

La sintaxis concreta debe corresponder a la version instalada de Tailwind. No se deben combinar recetas de v3 y v4 en una misma configuracion.

### 16.3 Componentes prioritarios

- `AppShell`, `Sidebar`, `TopBar`, `Breadcrumbs` y navegacion movil.
- `Button`, `IconButton`, `Input`, `Select`, `Checkbox`, `DatePicker` y `FormField`.
- `Dialog`, `AlertDialog`, `Sheet`, `DropdownMenu`, `Tooltip` y `Toast`.
- `Card` solo para unidades reales de contenido, no como contenedor universal.
- `DataTable`, filtros, paginacion y estados vacio/carga/error.
- `StatusBadge` con texto e icono, no solo color.
- `Kpi`, `ChartContainer` y alternativa tabular cuando exista analitica.

### 16.4 Responsive en implementacion

- Base movil sin prefijo y mejoras con breakpoints.
- Sidebar transformada en sheet/drawer en pantallas pequenas.
- Tablas con prioridad de columnas, scroll contenido o vista alternativa.
- Formularios de una columna en movil y multiples columnas solo cuando la relacion entre campos lo justifique.
- Targets tactiles de 44 px aun cuando el control visual sea menor.
- `min-width: 0`, truncado deliberado y wrapping para evitar overflow en grids y flex.
- Container queries para tarjetas o paneles reutilizados en anchos distintos.

### 16.5 Verificacion obligatoria

- Typecheck, lint y tests de componentes.
- Navegacion completa por teclado.
- axe o herramienta equivalente sobre flujos principales.
- Contraste medido, no estimado visualmente.
- Pruebas en la matriz responsive acordada y en anchos intermedios.
- Verificacion de layout shift y dimensiones de medios.
- `prefers-reduced-motion`, zoom de navegador y texto ampliado.
- Estados loading, error, vacio, permisos insuficientes y datos largos.
- Lighthouse como senal complementaria, no como unica prueba.

## Conclusion

UI/UX Pro Max es una base de consulta extensa y bien orientada para iniciar y revisar decisiones de interfaz. Su estructura favorece el razonamiento contextual, la consistencia y una buena disciplina de accesibilidad. Sin embargo, no constituye por si sola un design system listo para produccion ni reemplaza investigacion de usuarios, criterio de producto, verificacion normativa o QA visual.

La integracion correcta con Next.js + Tailwind consiste en usar el skill para descubrir y justificar patrones, convertir las decisiones aceptadas en tokens semanticos y componentes, y cerrar el ciclo con pruebas automatizadas y visuales. Para Agenda Podologica, conviene tomar su nucleo de accesibilidad, formularios, navegacion operacional y responsive; moderar sus recomendaciones esteticas; y evitar que los patrones de landing o dashboard desplacen la tarea clinica principal.
