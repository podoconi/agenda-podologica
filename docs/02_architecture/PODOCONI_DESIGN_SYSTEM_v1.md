# Podoconi Design System v1

**Proyecto:** Agenda Podologica  
**Version:** 1.0  
**Estado:** Aprobado para implementacion  
**Fecha:** 2026-06-21  
**Autor:** Roberto Rojas  
**Fuentes de decision:**
- `UI_UX_PRO_MAX_SKILL_ANALYSIS.md`
- `.claude/skills/ui-ux-pro-max` (catalogos CSV: styles, colors, typography, ux-guidelines, products, stacks/shadcn, stacks/nextjs, ui-reasoning)
- `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md`
- `ARQUITECTURA_CONCEPTUAL_v1.1.md`

**Stack objetivo:** Next.js App Router + Tailwind CSS + shadcn/ui  
**Alcance:** Documento arquitectonico de diseno visual. No contiene codigo, componentes, wireframes ni mockups.

---

## 1. Filosofia de Diseno

### 1.1 Personalidad visual

Podoconi es una herramienta clinica operacional. Su interfaz debe transmitir:

- **Confianza profesional.** El podologe debe sentir que trabaja con un instrumento serio.
- **Calidez humana.** No es un sistema hospitalario frio; atiende personas con nombre, contexto y seguimiento.
- **Eficiencia silenciosa.** Cada pantalla debe resolver una tarea sin distracciones.
- **Claridad inmediata.** La informacion relevante debe ser visible sin explorar ni adivinar.

### 1.2 Tono

| Dimension | Descripcion |
|---|---|
| Formalidad | Profesional sin ser corporativo. Sobrio sin ser austero. |
| Calidez | Humano, cercano al paciente y al profesional. |
| Densidad | Moderada: suficiente informacion para operar, sin saturar. |
| Movimiento | Minimo y funcional. La interfaz no se mueve por estetica. |
| Decoracion | Cero decoracion innecesaria. Cada elemento cumple una funcion. |

### 1.3 Principios de diseno

1. **Accesibilidad primero.** Contraste, foco, teclado y semantica son restricciones de entrada, no mejoras opcionales.
2. **Operacion sobre ornamentacion.** La tarea clinica diaria tiene prioridad sobre la estetica.
3. **Consistencia sistemica.** Un solo lenguaje visual en colores, tipografia, iconos, espaciado y estados.
4. **Feedback explicito.** Toda accion del usuario produce una respuesta visible e inmediata.
5. **Mobile first con mejora progresiva.** La interfaz parte en movil y gana estructura en breakpoints mayores.
6. **Contexto antes que estilo.** El tipo de tarea, la urgencia y el rol del usuario determinan la presentacion.
7. **Minima carga cognitiva.** Priorizar lo que el profesional necesita ahora, no todo lo que el sistema puede mostrar.

### 1.4 Anti-patrones

| Anti-patron | Razon |
|---|---|
| Neumorphism como estilo dominante | Sombras suaves perjudican contraste y affordance en contexto clinico. |
| Glassmorphism pesado | Blur y transparencias comprometen legibilidad en textos clinicos y datos de paciente. |
| Brutalismo | Incongruente con la seriedad profesional y la calidez humana del producto. |
| Animaciones excesivas | Distraen de la tarea clinica. Riesgo de motion sickness. |
| Dashboards corporativos densos | El podologe no es un analista de BI; necesita su agenda y pendientes. |
| Colores neon o vibrantes | Fatiga visual en uso diario prolongado. Incongruentes con contexto de salud. |
| Emojis como iconos de interfaz | Inconsistencia visual y problemas de accesibilidad. Usar SVG (Lucide). |
| Color como unico indicador de estado | Inaccessible para daltonismo. Siempre acompanar con texto o icono. |
| Decoracion sin funcion | Ilustraciones, patrones y ornamentos que no comunican informacion. |

---

## 2. Usuarios objetivo

### 2.1 Podologo independiente

| Aspecto | Necesidad UX |
|---|---|
| Contexto | Trabaja solo, es clinico y administrativo al mismo tiempo. |
| Dispositivo principal | Tablet o desktop en consulta. Movil para consultas rapidas. |
| Frecuencia | Uso diario intensivo, 6-10 horas. |
| Prioridad UX | Velocidad operacional. Minimos clics para registrar atencion. |
| Necesidad clave | Ver agenda del dia, registrar atencion y cerrar cobro en flujo continuo. |
| Riesgo UX | Fatiga por formularios largos. Interrupciones frecuentes entre pacientes. |

### 2.2 Atencion domiciliaria

| Aspecto | Necesidad UX |
|---|---|
| Contexto | Atiende en domicilio del paciente, sin escritorio fijo. |
| Dispositivo principal | Movil o tablet pequena. Conectividad variable. |
| Frecuencia | Varias visitas diarias con desplazamiento entre ellas. |
| Prioridad UX | Interfaz tactil optimizada. Formularios cortos. |
| Necesidad clave | Consultar ficha del paciente y registrar atencion en movil. |
| Riesgo UX | Targets tactiles pequenos. Formularios que requieren teclado extenso. |

### 2.3 Centro podologico pequeno

| Aspecto | Necesidad UX |
|---|---|
| Contexto | 2-5 profesionales, 1-2 box de atencion, recepcion compartida. |
| Dispositivo principal | Desktop en recepcion, tablet en box clinico. |
| Frecuencia | Uso continuo durante horario comercial. |
| Prioridad UX | Gestion de agenda multi-profesional. Visibilidad de disponibilidad. |
| Necesidad clave | Agendar citas para multiples profesionales. Ver estado general del centro. |
| Riesgo UX | Confusion entre agendas de diferentes profesionales. Colision de citas. |

### 2.4 Personal administrativo

| Aspecto | Necesidad UX |
|---|---|
| Contexto | No es clinico. Gestiona citas, cobros y datos de pacientes. |
| Dispositivo principal | Desktop. |
| Frecuencia | Uso diario continuo. |
| Prioridad UX | Eficiencia en busqueda de pacientes. Gestion de cobros pendientes. |
| Necesidad clave | Buscar paciente, agendar cita, registrar pago. |
| Riesgo UX | Acceso accidental a informacion clinica sensible. |

---

## 3. Paleta semantica oficial

### 3.1 Justificacion general

La paleta se basa en las recomendaciones del catalogo UI/UX Pro Max para Healthcare App (entrada #9: Calm cyan + health green) y Medical Clinic (entrada #61: Medical teal + health green), adaptada para un producto clinico operacional que prioriza legibilidad y confianza.

Se rechaza la paleta de neumorphism (pasteles suaves) por insuficiente contraste. Se rechaza la paleta de Healthcare App pura (neon cyan) por fatiga visual en uso prolongado.

La seleccion final combina:
- **Teal/cyan moderado** como primario: transmite calma, salud y profesionalismo sin ser frio.
- **Slate neutro** como base: maxima legibilidad con tonalidad calida-neutra.
- **Verde de salud** para exito: asociacion natural con bienestar y salud.
- **Ambar/rojo controlado** para alertas: urgencia sin agresividad.

### 3.2 Tokens semanticos de color

Todos los valores se expresan en formato HSL para compatibilidad nativa con shadcn/ui y Tailwind CSS. Los valores exactos se definiran en la implementacion; aqui se documenta el rol, la intencion y el rango cromatico.

#### Base

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `background` | Fondo principal de la aplicacion | Slate muy claro (hsl ~210 20% 98%) | Fondo neutro no blanco puro; reduce fatiga visual en uso prolongado. |
| `foreground` | Texto principal sobre background | Slate muy oscuro (hsl ~222 47% 11%) | Contraste 12:1+ sobre background. Legibilidad maxima. |
| `card` | Fondo de tarjetas y superficies elevadas | Blanco (hsl 0 0% 100%) | Separacion visual clara del fondo. |
| `card-foreground` | Texto sobre card | Igual a foreground | Consistencia. |
| `muted` | Fondo de areas secundarias, separadores | Slate claro (hsl ~210 20% 96%) | Jerarquia visual sin distraer. |
| `muted-foreground` | Texto secundario, metadata, hints | Slate medio (hsl ~215 16% 47%) | Contraste 4.5:1+ sobre muted. Cumple WCAG AA. |
| `border` | Bordes de tarjetas, separadores, inputs | Slate claro (hsl ~214 20% 88%) | Visible sin dominar. |
| `input` | Borde de campos de formulario | Ligeramente mas oscuro que border | Distinguir inputs del borde general. |
| `ring` | Anillo de foco para accesibilidad | Derivado de primary | Visible en :focus-visible. 3px minimo. |

#### Primario

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `primary` | Acciones principales, botones primarios, links, sidebar activo | Teal moderado (hsl ~186 60% 36%) | Cyan-teal de salud: calma, profesionalismo, confianza. Fuente: colors.csv #9 Healthcare + #61 Medical Clinic. |
| `primary-foreground` | Texto sobre primary | Blanco | Contraste 4.5:1+ sobre primary. |

#### Secundario

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `secondary` | Botones secundarios, acciones alternativas | Slate claro (hsl ~210 20% 96%) | Neutro, no compite con primary. |
| `secondary-foreground` | Texto sobre secondary | Slate oscuro | Contraste 4.5:1+. |

#### Acento

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `accent` | Hover de items de menu, badges de categoria, elementos destacados | Teal muy claro (hsl ~186 40% 94%) | Variacion suave de primary para fondos de hover y seleccion. |
| `accent-foreground` | Texto sobre accent | Teal oscuro | Contraste 4.5:1+. |

#### Estado: Exito

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `success` | Confirmaciones, pagos completados, estado saludable | Verde de salud (hsl ~152 56% 40%) | Asociacion universal con exito y bienestar. Fuente: colors.csv #9 health green #059669. |
| `success-foreground` | Texto sobre success | Blanco | Contraste 4.5:1+. |

#### Estado: Advertencia

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `warning` | Cobros pendientes, citas proximas, seguimientos vencidos | Ambar (hsl ~38 92% 50%) | Atencion sin alarma. Fuente: ux-guidelines.csv #33 error feedback, #37 color-only. |
| `warning-foreground` | Texto sobre warning | Oscuro (no blanco) | Contraste 4.5:1+ sobre ambar. |

#### Estado: Peligro

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `danger` | Errores, eliminaciones, conflictos de cita, alertas clinicas | Rojo controlado (hsl ~0 72% 51%) | Urgencia sin agresividad. Siempre acompanado de texto/icono. |
| `danger-foreground` | Texto sobre danger | Blanco | Contraste 4.5:1+. |

#### Estado: Informativo

| Token | Rol | Rango cromatico | Justificacion |
|---|---|---|---|
| `info` | Notas informativas, tooltips, ayuda contextual | Azul sereno (hsl ~217 91% 60%) | Neutral-informativo. No compite con primary teal. |
| `info-foreground` | Texto sobre info | Blanco | Contraste 4.5:1+. |

### 3.3 Reglas cromaticas obligatorias

1. Nunca usar color como unico canal para comunicar estado. Siempre acompanar con icono y/o texto.
2. Validar contraste con herramienta automatizada (axe, Lighthouse, plugin de contraste), no visualmente.
3. Los tokens semanticos son la unica forma valida de referenciar colores en componentes. Prohibido usar hexadecimales directos o clases de color Tailwind genericas (`bg-blue-500`).
4. Modo oscuro: definir variantes `.dark` para todos los tokens. Prioridad secundaria en v1 pero la arquitectura de tokens debe soportarlo desde el inicio.

---

## 4. Tipografia oficial

### 4.1 Evaluacion de candidatas

| Fuente | Categoria | Fortalezas | Debilidades | Evaluacion |
|---|---|---|---|---|
| **Inter** | Sans-serif, variable | Maxima versatilidad. 9 pesos. Excelente para datos y UI. Metricamente compatible con system-ui. Catalogo: #5 Minimal Swiss, ideal para dashboards y admin. | Personalidad neutra, puede sentirse generica. | Aprobada como alternativa viable. |
| **Figtree** | Sans-serif, variable | Amable sin ser infantil. Excelente legibilidad. Personalidad calida. Catalogo: #30 Medical Clean, recomendada para healthcare. | Menos pesos que Inter. Menos probada en interfaces densas. | **Seleccionada como fuente principal de headings.** |
| **Atkinson Hyperlegible** | Sans-serif | Disenada explicitamente para maxima legibilidad. Diferenciacion de caracteres ambiguos (I/l/1, O/0). Catalogo: #48 Accessibility First. | Solo 2 pesos (Regular, Bold). No tiene variable font. Personalidad marcada que puede no combinar con todas las interfaces. | **Seleccionada como fuente de accesibilidad para texto clinico largo.** |
| **Noto Sans** | Sans-serif, variable | Cobertura Unicode universal. Excelente para texto corrido. Catalogo: #30 body font para Medical Clean. | Personalidad neutra. Peso de descarga mayor por cobertura Unicode. | Aprobada como fallback universal. |

### 4.2 Decision tipografica

**Pareja seleccionada:** Figtree (headings + UI) / Atkinson Hyperlegible (texto clinico largo)

**Justificacion:** Combina la calidez profesional de Figtree con la legibilidad clinica de Atkinson Hyperlegible. Figtree aporta la personalidad calida que diferencia a Podoconi de un HIS hospitalario. Atkinson Hyperlegible asegura legibilidad en los contextos mas criticos: fichas clinicas, consentimientos, notas de evolucion.

**Fuente monospace:** JetBrains Mono para codigo o datos tabulares que requieran alineacion.

**Carga:** Via `next/font/google` con `display: swap` y subsets `['latin', 'latin-ext']` para soporte completo de espanol.

### 4.3 Escala tipografica

Escala modular con ratio 1.25 (Major Third), base 16px.

| Nivel | Nombre token | Tamano | Peso | Line-height | Uso |
|---|---|---|---|---|---|
| H1 | `text-3xl` | 30px / 1.875rem | 700 (Bold) | 1.2 | Titulo de pagina. Una sola instancia por vista. |
| H2 | `text-2xl` | 24px / 1.5rem | 600 (SemiBold) | 1.3 | Secciones principales dentro de pagina. |
| H3 | `text-xl` | 20px / 1.25rem | 600 (SemiBold) | 1.4 | Subsecciones, titulos de tarjeta. |
| H4 | `text-lg` | 18px / 1.125rem | 500 (Medium) | 1.4 | Titulos de grupo de formulario, labels de seccion. |
| H5 | `text-base` | 16px / 1rem | 600 (SemiBold) | 1.5 | Titulos menores, columnas de tabla. |
| H6 | `text-sm` | 14px / 0.875rem | 600 (SemiBold) | 1.5 | Overlines, titulos de badge. |
| Body | `text-base` | 16px / 1rem | 400 (Regular) | 1.6 | Texto principal de la interfaz. |
| Body small | `text-sm` | 14px / 0.875rem | 400 (Regular) | 1.5 | Texto secundario, metadata, tablas en modo compact. |
| Caption | `text-xs` | 12px / 0.75rem | 400 (Regular) | 1.4 | Timestamps, conteos, labels de grafico. Solo en contextos no criticos. |
| Clinico | `text-base` | 16px / 1rem | 400 (Regular) | 1.75 | Notas clinicas, evoluciones, consentimientos. Usa Atkinson Hyperlegible. Line-height expandido para legibilidad. |
| KPI valor | `text-3xl` | 30px / 1.875rem | 700 (Bold) | 1.1 | Valor numerico destacado en KpiCard. |
| KPI label | `text-sm` | 14px / 0.875rem | 500 (Medium) | 1.4 | Label descriptivo del KPI. |

### 4.4 Reglas tipograficas obligatorias

1. Texto base movil minimo 16px. Nunca reducir body text por debajo de 14px.
2. Longitud de linea maxima: 75 caracteres (`max-w-prose`). Texto clinico: 65 caracteres.
3. Jerarquia secuencial de headings: no saltar niveles (H1 → H3 sin H2).
4. Usar `next/font` para cargar fuentes. Nunca `<link>` externo.
5. Truncar solo donde la perdida de contenido sea aceptable. Siempre ofrecer acceso al valor completo (tooltip, expand).
6. Usar font stack con fallback metricamente compatible: `'Figtree', 'Inter', system-ui, sans-serif`.

---

## 5. Sistema de Espaciado

### 5.1 Escala oficial

Base: 4px. Escala armonica con progresion consistente.

| Token | Valor | Equivalente Tailwind | Uso principal |
|---|---|---|---|
| `space-1` | 4px | `1` | Espacio minimo entre icono y texto. |
| `space-2` | 8px | `2` | Gap entre elementos adyacentes dentro de un grupo. |
| `space-3` | 12px | `3` | Padding interno de badges, chips. |
| `space-4` | 16px | `4` | Padding interno de inputs, botones. Gap entre campos de formulario. |
| `space-6` | 24px | `6` | Padding interno de tarjetas. Gap entre tarjetas. |
| `space-8` | 32px | `8` | Separacion entre secciones dentro de una pagina. |
| `space-12` | 48px | `12` | Separacion entre secciones mayores. |
| `space-16` | 64px | `16` | Padding vertical de secciones de pagina completa. |

### 5.2 Reglas de espaciado

1. Usar `gap` en contenedores en lugar de margenes repetidos en hijos.
2. Padding de pagina responsive: `px-4 md:px-6 lg:px-8`.
3. Consistencia por tipo de componente: todas las tarjetas usan `space-6` de padding interno.
4. Densidad `compact` reduce padding interno a `space-3` y gaps a `space-2`.
5. Valores arbitrarios (`[7px]`) prohibidos excepto para alineacion con APIs externas.

---

## 6. Elevaciones

### 6.1 Escala de sombras

| Token | Valor CSS | Uso |
|---|---|---|
| `shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | Separacion sutil: inputs, badges. |
| `shadow-md` | `0 4px 6px -1px rgba(0,0,0,0.07), 0 2px 4px -2px rgba(0,0,0,0.05)` | Tarjetas, botones elevados. Nivel por defecto para Card. |
| `shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -4px rgba(0,0,0,0.04)` | Dropdowns, popovers, tooltips. |
| `shadow-xl` | `0 20px 25px -5px rgba(0,0,0,0.08), 0 8px 10px -6px rgba(0,0,0,0.04)` | Modales, dialogs, sheets. |

### 6.2 Reglas de elevacion

1. Mayor elevacion = mayor importancia contextual y mayor proximidad al usuario.
2. Las sombras son suaves y con baja opacidad para mantener sobriedad clinica.
3. No usar sombras para decoracion. Solo para jerarquia de profundidad.
4. Hovers de tarjetas pueden transicionar de `shadow-md` a `shadow-lg` (200ms ease-out).
5. En modo oscuro, las sombras deben adaptarse con menor opacidad o reemplazarse por bordes sutiles.

---

## 7. Border Radius

### 7.1 Escala

| Token | Valor | Uso |
|---|---|---|
| `radius-sm` | 4px | Badges, chips, tags. Elementos compactos. |
| `radius-md` | 6px | Inputs, selects, botones. Valor por defecto para controles. |
| `radius-lg` | 8px | Tarjetas, dialogs, sheets. Superficies principales. |
| `radius-xl` | 12px | Contenedores prominentes, modales de contenido. |
| `radius-full` | 9999px | Avatares, badges de estado circulares, toggles. |

### 7.2 Reglas

1. Todos los controles interactivos usan `radius-md` por defecto.
2. Las tarjetas usan `radius-lg`.
3. No mezclar radios arbitrarios. Usar exclusivamente la escala definida.
4. Los radios internos deben ser menores o iguales a los radios externos del contenedor.

---

## 8. Breakpoints oficiales

### 8.1 Definicion

| Nombre | Ancho minimo | Uso |
|---|---|---|
| `mobile` | 0px (base) | Telefono. Estilos sin prefijo en Tailwind. |
| `tablet` | 768px (`md`) | Tablet vertical. Sidebar colapsable. |
| `desktop` | 1024px (`lg`) | Desktop. Sidebar visible. Layout completo. |
| `wide` | 1280px (`xl`) | Monitor amplio. Paneles laterales, tablas extendidas. |

### 8.2 Matriz de pruebas responsive obligatoria

Toda pantalla debe probarse en estos anchos antes de aprobar:

| Ancho | Dispositivo representativo | Prioridad |
|---|---|---|
| 320px | iPhone SE, dispositivos legacy | Obligatoria |
| 375px | iPhone 13/14/15 | Obligatoria |
| 768px | iPad vertical | Obligatoria |
| 1024px | iPad horizontal, laptop pequeno | Obligatoria |
| 1280px | Laptop, monitor estandar | Obligatoria |
| 1440px | Monitor amplio | Recomendada |
| 1536px | Monitor ultrawide | Recomendada |

### 8.3 Reglas responsive

1. Mobile first: estilos base para movil, mejoras con `md:`, `lg:`, `xl:`.
2. Sidebar se transforma en Sheet/Drawer en pantallas < 1024px.
3. Tablas con prioridad de columnas en movil. Scroll horizontal controlado o vista alternativa en tarjetas.
4. Formularios de una columna en movil. Multiples columnas solo cuando la relacion entre campos lo justifique.
5. Targets tactiles minimo 44x44px incluso cuando el control visual sea menor.
6. Usar `min-h-dvh` en lugar de `min-h-screen` para evitar problemas con barras del navegador movil.
7. No duplicar contenido por breakpoint. Cambiar presentacion, no significado.

---

## 9. Layout del producto

### 9.1 AppShell

Estructura general de la aplicacion autenticada:

```
+--+--------------------------------------+
|  |  Header contextual                   |
|  +--------------------------------------+
|S |                                      |
|I |  Area principal                      |
|D |                                      |
|E |  (contenido de la ruta activa)       |
|B |                                      |
|A |                                      |
|R |                                      |
+--+--------------------------------------+
```

- **Desktop (>= 1024px):** Sidebar fija a la izquierda (ancho: 240px colapsada a 64px). Header contextual arriba. Area principal ocupa el resto.
- **Tablet (768-1023px):** Sidebar como Drawer/Sheet que se abre con toggle. Header visible con boton de menu hamburguesa.
- **Movil (< 768px):** Sidebar como Sheet full-width. Header compacto con titulo de pagina y menu hamburguesa.

### 9.2 Sidebar

| Aspecto | Especificacion |
|---|---|
| Ancho expandida | 240px |
| Ancho colapsada | 64px (solo iconos) |
| Contenido | Logo/nombre, navegacion principal, selector de organizacion (si aplica), usuario/perfil al fondo. |
| Comportamiento | Colapsable por toggle manual. En movil, se abre como Sheet con overlay. |
| Scroll | Scroll interno independiente si el contenido excede la altura. |
| z-index | `z-sidebar` (20). |

### 9.3 Header contextual

| Aspecto | Especificacion |
|---|---|
| Altura | 56px |
| Contenido | Breadcrumbs (si la ruta tiene profundidad >= 3), titulo de pagina, acciones contextuales (boton primario de la vista). |
| Posicion | Sticky en el tope del area principal. |
| z-index | `z-sticky` (10). |

### 9.4 Drawer movil

| Aspecto | Especificacion |
|---|---|
| Tipo | Sheet de shadcn/ui con `side="left"`. |
| Overlay | Fondo oscurecido (`rgba(0,0,0,0.5)`). |
| Cierre | Click en overlay, gesto swipe, boton de cierre, tecla Escape. |
| Foco | Trap de foco dentro del drawer. Devolucion de foco al cerrar. |

### 9.5 Breadcrumbs

| Aspecto | Especificacion |
|---|---|
| Cuando aparecen | Solo cuando la ruta tiene 3 o mas niveles de profundidad. |
| Formato | `Inicio > Pacientes > Juan Perez` |
| Ultimo segmento | Texto sin link (ubicacion actual). |
| Movil | Colapsados. Solo mostrar nivel anterior como link de retorno. |

### 9.6 Area principal

| Aspecto | Especificacion |
|---|---|
| Ancho maximo | `max-w-7xl` para contenido general. `max-w-4xl` para formularios y texto largo. |
| Centrado | `mx-auto` con padding responsive. |
| Scroll | Scroll vertical del area principal, independiente de sidebar y header. |
| Padding | `px-4 md:px-6 lg:px-8` horizontal. `py-6 lg:py-8` vertical. |

---

## 10. Navegacion

### 10.1 Jerarquia de navegacion

| Nivel | Mecanismo | Ejemplo |
|---|---|---|
| 1. Areas funcionales | Sidebar | Agenda, Pacientes, Atenciones, Cobros, Configuracion. |
| 2. Vistas dentro de area | Tabs o sub-navegacion | Pacientes > Lista / Busqueda avanzada. |
| 3. Detalle | Ruta profunda + breadcrumbs | Pacientes > Juan Perez > Historia clinica. |
| 4. Acciones modales | Dialog, Sheet, AlertDialog | Crear cita, confirmar eliminacion logica. |

### 10.2 Persistencia

- La sidebar mantiene estado activo en la navegacion de primer nivel.
- Los filtros importantes se representan como search params en la URL para permitir compartir y restaurar estado.
- El historial del navegador se preserva. No usar `replace` excepto para flujos de autenticacion.

### 10.3 Estados activos

| Elemento | Estado activo |
|---|---|
| Item de sidebar | Fondo `accent`, texto `accent-foreground`, borde lateral izquierdo `primary` (3px). |
| Tab activo | Texto `primary`, borde inferior `primary` (2px). |
| Breadcrumb actual | Texto `foreground`, sin link, peso `medium`. |
| Breadcrumb ancestro | Texto `muted-foreground`, link funcional. |

### 10.4 Deep linking

- Toda vista que un usuario pueda querer compartir o regresar debe tener URL propia.
- Filtros de tabla (busqueda, estado, fecha) deben reflejarse en search params.
- Las tabs de contenido deben reflejarse en la URL.
- Los modales no tienen URL propia (son acciones, no destinos).

### 10.5 Navegacion movil

- Menu hamburguesa en el header abre la sidebar como Sheet.
- La navegacion principal se mantiene identica en estructura al desktop.
- Los breadcrumbs se simplifican a un link de retorno al nivel anterior.
- Las acciones contextuales del header se colapsan en un DropdownMenu.

---

## 11. Componentes base oficiales

Todos los componentes se basan en shadcn/ui como primitiva, extendidos con variantes especificas de Podoconi. Para cada componente se define: proposito, variantes, estados y accesibilidad.

### 11.1 Button

| Aspecto | Especificacion |
|---|---|
| Proposito | Ejecutar acciones. |
| Variantes | `default` (primary), `secondary`, `outline`, `ghost`, `destructive`, `link`. |
| Tamanos | `sm` (32px alto), `default` (40px), `lg` (48px). |
| Estados | default, hover, focus, active, disabled, loading. |
| Loading | Spinner inline + texto cambia a "Guardando..." o similar. Boton deshabilitado durante carga. Conservar geometria. |
| Accesibilidad | `cursor-pointer`. Focus ring visible (3px). `aria-disabled` cuando loading. `aria-label` si solo tiene icono. |

### 11.2 IconButton

| Aspecto | Especificacion |
|---|---|
| Proposito | Accion con icono sin texto. |
| Variantes | `ghost`, `outline`. |
| Tamano | Minimo 44x44px para target tactil. Icono 20px. |
| Accesibilidad | **Obligatorio** `aria-label` descriptivo. Tooltip con el nombre de la accion. |

### 11.3 Input

| Aspecto | Especificacion |
|---|---|
| Proposito | Entrada de texto de una linea. |
| Variantes | `default`, `error`. |
| Altura | 40px (`h-10`). Padding `px-3`. |
| Estados | default, focus (ring primary 2px), error (borde danger, mensaje debajo), disabled (opacity 50%). |
| Accesibilidad | Siempre con `<label>` asociado via `htmlFor`. Usar `type`, `inputmode`, `autocomplete` apropiados. |

### 11.4 Textarea

| Aspecto | Especificacion |
|---|---|
| Proposito | Entrada de texto multilinea. Notas clinicas, evoluciones. |
| Altura minima | 80px. Permitir resize vertical. |
| Accesibilidad | Label obligatorio. `aria-describedby` para instrucciones. |

### 11.5 Select

| Aspecto | Especificacion |
|---|---|
| Proposito | Seleccion de una opcion de una lista. |
| Variantes | `default`, `error`. |
| Estructura | `Select > SelectTrigger > SelectValue` + `SelectContent > SelectItem`. |
| Accesibilidad | Label obligatorio. Navegacion por teclado nativa del componente shadcn. |

### 11.6 Checkbox

| Aspecto | Especificacion |
|---|---|
| Proposito | Seleccion booleana o multiple. |
| Tamano | Caja de 20x20px. Target tactil 44x44px. |
| Accesibilidad | Label clickeable asociado. `aria-checked`. |

### 11.7 Switch

| Aspecto | Especificacion |
|---|---|
| Proposito | Activar/desactivar una opcion con efecto inmediato. |
| Tamano | 44px ancho, 24px alto. |
| Accesibilidad | `role="switch"`, `aria-checked`. Label obligatorio. |

### 11.8 Badge

| Aspecto | Especificacion |
|---|---|
| Proposito | Etiqueta de categoria o clasificacion. |
| Variantes | `default`, `secondary`, `outline`, `destructive`. |
| Tamano | Compacto. Padding `space-1` vertical, `space-2` horizontal. Texto `text-xs`. |
| Accesibilidad | Texto legible. No transmitir informacion solo por color. |

### 11.9 StatusBadge

| Aspecto | Especificacion |
|---|---|
| Proposito | Indicador de estado con significado semantico. |
| Variantes | `confirmada`, `pendiente`, `atendida`, `cancelada`, `noshow`, `pagado`, `pendiente-pago`. |
| Composicion | Icono semantico + texto descriptivo + fondo del color de estado. |
| Accesibilidad | **Nunca solo color.** Siempre icono + texto. `aria-label` con el estado completo. |

### 11.10 Card

| Aspecto | Especificacion |
|---|---|
| Proposito | Contenedor de una unidad de contenido cohesivo. |
| Estructura | `Card > CardHeader > CardTitle + CardDescription` + `CardContent` + `CardFooter`. |
| Elevacion | `shadow-md` por defecto. |
| Radius | `radius-lg`. |
| Uso | Solo para unidades reales de contenido, no como contenedor universal. |

### 11.11 Dialog

| Aspecto | Especificacion |
|---|---|
| Proposito | Ventana modal para formularios, detalles o confirmaciones. |
| Estructura | `Dialog > DialogContent > DialogHeader > DialogTitle + DialogDescription` + contenido + `DialogFooter`. |
| Cierre | Boton X, tecla Escape, click en overlay. |
| Accesibilidad | Focus trapping. Focus devuelto al trigger al cerrar. `DialogTitle` y `DialogDescription` obligatorios. |
| z-index | `z-modal` (40). |

### 11.12 Sheet

| Aspecto | Especificacion |
|---|---|
| Proposito | Panel lateral para navegacion, filtros, detalles secundarios. |
| Lados | `left` (sidebar movil), `right` (detalles, filtros). |
| Accesibilidad | Misma accesibilidad que Dialog: focus trap, escape, overlay. |

### 11.13 Toast

| Aspecto | Especificacion |
|---|---|
| Proposito | Notificacion transitoria no bloqueante. |
| Implementacion | Sonner integrado con shadcn/ui. |
| Variantes | `toast()`, `toast.success()`, `toast.error()`, `toast.warning()`. |
| Duracion | 5 segundos. Auto-dismiss. Pausar en hover. |
| Posicion | Bottom-right en desktop. Bottom-center en movil. |
| Accesibilidad | `role="status"`, `aria-live="polite"`. Errores criticos: `aria-live="assertive"`. |
| z-index | `z-toast` (50). |

### 11.14 AlertDialog

| Aspecto | Especificacion |
|---|---|
| Proposito | Confirmacion de acciones destructivas o irreversibles. |
| Estructura | Titulo + descripcion + boton Cancel + boton Action (destructive). |
| Accesibilidad | Focus automatico en boton Cancel (accion segura). No cerrar con click en overlay. |

### 11.15 Table

| Aspecto | Especificacion |
|---|---|
| Proposito | Presentacion de datos tabulares simples. |
| Estructura | `Table > TableHeader > TableRow > TableHead` + `TableBody > TableRow > TableCell`. |
| Semantica | Usar elementos de tabla semanticos, no div grids. |
| Responsive | Scroll horizontal contenido en movil (`overflow-x-auto`). Sticky primera columna si es identificadora. |

### 11.16 DataTable

| Aspecto | Especificacion |
|---|---|
| Proposito | Tabla con ordenamiento, filtrado, paginacion y seleccion. |
| Implementacion | TanStack Table + componente Table de shadcn/ui. |
| Funcionalidades | Ordenamiento por columna, busqueda/filtro, paginacion (25 filas por defecto), seleccion de filas para acciones batch. |
| Estados | Loading (skeleton que coincida con geometria), vacio (EmptyState), error. |
| Accesibilidad | Headers con `aria-sort`. Paginacion navegable por teclado. |

### 11.17 EmptyState

| Aspecto | Especificacion |
|---|---|
| Proposito | Guiar al usuario cuando no hay datos que mostrar. |
| Composicion | Icono grande (48px, muted), titulo descriptivo, texto explicativo breve, boton de accion primaria. |
| Ejemplos | "No hay citas para hoy. Agenda la primera cita.", "No se encontraron pacientes. Intenta con otro termino." |

### 11.18 Skeleton

| Aspecto | Especificacion |
|---|---|
| Proposito | Placeholder de carga que coincide con la geometria del contenido final. |
| Regla | Las dimensiones del skeleton deben coincidir con las del contenido cargado para evitar layout shift. |
| Animacion | Pulse suave (`animate-pulse`). |

### 11.19 KpiCard

| Aspecto | Especificacion |
|---|---|
| Proposito | Indicador de metrica clave en el dashboard. |
| Composicion | Label descriptivo (`text-sm`, `muted-foreground`), valor numerico grande (`text-3xl`, `bold`), indicador de tendencia opcional (flecha + porcentaje), icono semantico. |
| Variantes | `default` (fondo `card`), `highlighted` (fondo suave del color semantico). |

### 11.20 DatePicker

| Aspecto | Especificacion |
|---|---|
| Proposito | Seleccion de fecha. Esencial para citas y atenciones. |
| Implementacion | Popover con calendario. Input de texto como trigger. |
| Formato | `dd/mm/yyyy` (formato latinoamericano). |
| Accesibilidad | Navegacion por teclado del calendario. `aria-label` en el input. Soporte de escritura manual. |

---

## 12. Formularios

### 12.1 Stack recomendado

**React Hook Form + Zod + FormField de shadcn/ui.**

**Justificacion:** React Hook Form minimiza re-renders y maneja formularios complejos con eficiencia. Zod provee validacion type-safe que se comparte entre cliente y servidor. FormField de shadcn/ui integra labels, controles y mensajes de error con semantica ARIA correcta. Esta combinacion esta recomendada por el adaptador shadcn (#16-19) y el analisis de la skill.

Formularios simples (1-3 campos, sin logica condicional) pueden usar Server Actions con validacion Zod en servidor, sin React Hook Form.

### 12.2 Reglas de formularios

#### Labels

| Regla | Detalle |
|---|---|
| Label siempre visible | Nunca usar placeholder como sustituto de label. |
| Posicion | Arriba del input. Alineacion izquierda. |
| Label de campo obligatorio | Asterisco (*) despues del texto del label. |
| Label de campo opcional | Texto "(opcional)" despues del label. |

#### Placeholders

| Regla | Detalle |
|---|---|
| Funcion | Ejemplo del formato esperado, no descripcion del campo. |
| Ejemplo | `placeholder="11.222.333-4"` para RUT, no `placeholder="Ingrese su RUT"`. |
| No usar como label | El placeholder desaparece al escribir. |

#### Validacion

| Regla | Detalle |
|---|---|
| Momento | Validar on blur para campos individuales. Validar todo al submit. |
| Donde | Cliente (Zod + React Hook Form) para feedback inmediato. Servidor (Zod + Server Action) como fuente de verdad. |
| Mensajes | Especificos y accionables. "El RUT debe tener formato XX.XXX.XXX-X", no "Campo invalido". |

#### Feedback de errores

| Regla | Detalle |
|---|---|
| Posicion | Inmediatamente debajo del campo con error. |
| Asociacion | Via `aria-describedby`. Componente `FormMessage` de shadcn. |
| Visual | Texto `danger`, borde `danger` en el input. Icono de alerta opcional. |
| Conservar valor | Nunca borrar lo que el usuario escribio al mostrar error. |
| Anuncio | Errores globales con `role="alert"`. Errores de campo con `aria-live="polite"`. |

#### Loading y confirmaciones

| Regla | Detalle |
|---|---|
| Submit en progreso | Deshabilitar boton. Mostrar spinner inline. Mantener geometria del boton. Texto cambia a "Guardando...". |
| Exito | Toast de confirmacion (`toast.success()`). Redireccion o cierre de dialog segun contexto. |
| Error de servidor | Toast de error (`toast.error()`) con mensaje claro. Formulario permanece con datos. |

#### Inputs especificos

| Regla | Detalle |
|---|---|
| Tipos HTML | Usar `type="email"`, `type="tel"`, `type="date"`. |
| Inputmode | `inputmode="numeric"` para RUT, telefono, montos. |
| Autocomplete | `autocomplete="given-name"`, `autocomplete="tel"`, etc. |
| Teclados movil | Los inputs de monto deben invocar teclado numerico. |

---

## 13. Dashboard Clinico Oficial

### 13.1 Patron conceptual

El dashboard de Podoconi es un **dashboard operacional sobrio**, no un dashboard corporativo de BI. El profesional necesita saber que tiene que hacer ahora, no analizar tendencias.

Fuente: UI_UX_PRO_MAX_SKILL_ANALYSIS.md seccion 9: "Para Agenda Podologica, el patron mas compatible es un dashboard operacional sobrio: agenda y pendientes primero, indicadores secundarios despues, y analitica avanzada separada de los flujos clinicos diarios."

### 13.2 Prioridad de contenido

| Prioridad | Bloque | Descripcion | Tipo visual |
|---|---|---|---|
| 1 | **Agenda del dia** | Lista de citas del dia actual, ordenadas por hora. Estado de cada cita (confirmada, pendiente, atendida, no-show). | Lista cronologica con StatusBadge. |
| 2 | **Pendientes de accion** | Citas sin confirmar, cobros pendientes, seguimientos vencidos. Agrupados por urgencia. | Lista con conteo y color de urgencia. |
| 3 | **Seguimientos proximos** | Pacientes con seguimiento programado en los proximos 7 dias. | Lista con fecha y tipo de seguimiento. |
| 4 | **Cobros pendientes** | Atenciones realizadas con pago pendiente. Monto total. | KpiCard + lista resumida. |
| 5 | **KPIs secundarios** | Atenciones del mes, pacientes nuevos del mes, tasa de asistencia. | KpiCards en fila. |

### 13.3 Layout del dashboard

- **Desktop:** 2 columnas. Columna izquierda (2/3): Agenda del dia. Columna derecha (1/3): Pendientes + Seguimientos + Cobros. KPIs en fila superior.
- **Tablet:** 1 columna. Bloques apilados en orden de prioridad.
- **Movil:** 1 columna. Bloques apilados. KPIs reducidos a 2 visibles + scroll horizontal para el resto.

### 13.4 Anti-patrones del dashboard

- No usar graficos de linea/barra en el dashboard principal. La analitica pertenece a una vista separada.
- No mostrar mas de 6 KPIs.
- No usar colores decorativos. Cada color transmite estado.
- No cargar datos que el usuario no va a mirar en los primeros 10 segundos.

---

## 14. Densidad

### 14.1 Modos

| Modo | Uso | Caracteristicas |
|---|---|---|
| `comfortable` | Vista por defecto. Formularios, fichas de paciente, agenda. | Padding `space-4` a `space-6`. Altura de fila de tabla 48px. Gap `space-4`. Texto `text-base`. |
| `compact` | Tablas de datos, listados largos, historial de atenciones. | Padding `space-2` a `space-3`. Altura de fila de tabla 36px. Gap `space-2`. Texto `text-sm`. |

### 14.2 Reglas

1. El modo por defecto es `comfortable`.
2. `compact` solo en DataTable, listados historicos y pantallas donde la cantidad de datos justifique mayor densidad.
3. El usuario no elige la densidad manualmente en v1. El sistema asigna segun el componente.
4. En movil, forzar `comfortable` para mantener targets tactiles adecuados.

---

## 15. Estados visuales

Todos los componentes interactivos deben implementar la siguiente tabla de estados:

| Estado | Visual | Comportamiento |
|---|---|---|
| `default` | Apariencia normal. Colores base del componente. | Interaccion disponible. |
| `hover` | Cambio sutil de fondo o borde. `cursor-pointer`. | Solo en dispositivos con hover. Transicion 150-200ms. |
| `focus` | Ring de foco visible (3px, color `ring`). Via `:focus-visible`. | Activado por teclado. No remover outline. |
| `active` | Escala sutil (`scale-[0.98]`) o cambio de fondo. | Feedback instantaneo de presion. |
| `disabled` | `opacity-50`. `cursor-not-allowed`. | No interactuable. `aria-disabled="true"`. |
| `loading` | Spinner inline. Texto adaptado. Boton deshabilitado. | Prevenir doble envio. Conservar geometria. |
| `success` | Fondo/borde `success`. Icono checkmark. | Transitorio (1-2s) o persistente segun contexto. |
| `warning` | Fondo/borde `warning`. Icono alerta. | Para estados que requieren atencion pero no son errores. |
| `error` | Fondo/borde `danger`. Mensaje de error. | Persistente hasta correccion. |

---

## 16. Accesibilidad

### 16.1 Objetivo de conformidad

| Nivel | Alcance | Justificacion |
|---|---|---|
| **WCAG AA** | Toda la aplicacion. Objetivo minimo obligatorio. | Estandar base para aplicaciones web profesionales. |
| **WCAG AAA** | Texto clinico (fichas, evoluciones, consentimientos). Formularios de paciente. | Contenido medico-legal que debe ser leido con absoluta claridad por cualquier persona. |

### 16.2 Checklist obligatorio

#### Contraste

- [ ] Texto normal: ratio minimo 4.5:1 (AA). Texto clinico: 7:1 (AAA).
- [ ] Texto grande (>= 18px bold o >= 24px regular): ratio minimo 3:1 (AA).
- [ ] Componentes de UI y graficos: ratio minimo 3:1 contra fondo adyacente.
- [ ] Contraste validado con herramienta automatizada, no visualmente.

#### Teclado

- [ ] Toda funcionalidad accesible solo con teclado.
- [ ] Orden de tabulacion coincide con orden visual y del DOM.
- [ ] Sin trampas de teclado (excepto modales con focus trap intencional).
- [ ] Skip link al inicio de la pagina para saltar navegacion.
- [ ] Atajos de teclado documentados para acciones frecuentes.

#### Semantica

- [ ] HTML semantico: `<nav>`, `<main>`, `<article>`, `<section>`, `<header>`, `<footer>`.
- [ ] Jerarquia de headings secuencial (H1 > H2 > H3). Un solo H1 por pagina.
- [ ] Tablas con `<th>` y `scope`. DataTable con `aria-sort`.
- [ ] Listas con `<ul>/<ol>` y `<li>`.
- [ ] Formularios con `<label>`, `<fieldset>`, `<legend>`.

#### ARIA

- [ ] `aria-label` en botones de solo icono.
- [ ] `aria-describedby` para mensajes de error y ayuda de inputs.
- [ ] `aria-live="polite"` para actualizaciones asincronas no urgentes.
- [ ] `role="alert"` para errores criticos y notificaciones urgentes.
- [ ] `aria-expanded` para secciones colapsables.
- [ ] `aria-current="page"` en item de sidebar activo.

#### Imagenes y medios

- [ ] `alt` descriptivo para imagenes informativas.
- [ ] `alt=""` y `aria-hidden="true"` para imagenes decorativas.
- [ ] Iconos SVG con `aria-hidden="true"` cuando acompanan texto. Con `aria-label` cuando son solos.

#### Formularios

- [ ] Cada input tiene label visible y asociado programaticamente.
- [ ] Campos obligatorios indicados con asterisco + texto, no solo asterisco.
- [ ] Mensajes de error asociados via `aria-describedby`.
- [ ] Errores anunciados a lectores de pantalla via `aria-live` o `role="alert"`.
- [ ] Tipos de input, `inputmode` y `autocomplete` correctos.

#### Movimiento

- [ ] Respetar `prefers-reduced-motion`. Reducir o eliminar animaciones.
- [ ] Ninguna animacion dura mas de 300ms para micro-interacciones.
- [ ] No usar animaciones como unica forma de comunicar cambios de estado.

#### Modales y overlays

- [ ] Focus trap dentro de modales y sheets.
- [ ] Focus devuelto al elemento trigger al cerrar.
- [ ] Cierre con tecla Escape.
- [ ] `aria-modal="true"` y role apropiado.

#### Testing

- [ ] axe-core o herramienta equivalente sobre todos los flujos principales.
- [ ] Navegacion completa por teclado verificada manualmente.
- [ ] Testing con lector de pantalla (NVDA o VoiceOver) en flujos criticos.
- [ ] Zoom de navegador a 200% sin perdida de funcionalidad.

---

## 17. Motion

### 17.1 Principios

1. **El movimiento apoya la comprension, no decora.** Cada animacion debe tener una razon funcional.
2. **Brevedad.** Las micro-interacciones duran entre 150-300ms.
3. **Suavidad.** Usar curvas de easing, nunca `linear` para interacciones de UI.
4. **Respeto.** Honrar `prefers-reduced-motion` sin excepcion.

### 17.2 Duraciones

| Token | Valor | Uso |
|---|---|---|
| `duration-fast` | 150ms | Hover, toggle, cambio de estado inmediato. |
| `duration-normal` | 200ms | Transiciones de fondo, borde, color. |
| `duration-slow` | 300ms | Apertura de dialog, sheet, dropdown. Skeleton fade-out. |

### 17.3 Easing

| Tipo | Valor CSS | Uso |
|---|---|---|
| `ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | Elementos que entran a la vista (dialogs, toasts). |
| `ease-in-out` | `cubic-bezier(0.45, 0, 0.55, 1)` | Cambios de estado in-situ (color, opacidad). |
| `ease-in` | `cubic-bezier(0.55, 0.05, 0.68, 0.19)` | Elementos que salen de la vista (cierre de modales). |

### 17.4 Restricciones

- No usar animaciones continuas excepto para indicadores de loading.
- No animar `width`, `height`, `top`, `left`. Usar `transform` y `opacity`.
- No usar parallax.
- No usar transiciones de pagina animadas.
- Skeleton: usar `animate-pulse` de Tailwind. Es la unica animacion continua permitida fuera de spinners.

### 17.5 Reduced motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

Cuando el usuario tiene `prefers-reduced-motion`, todas las animaciones se eliminan excepto cambios de estado instantaneos. Los spinners de loading se reemplazan por texto "Cargando..." o barra de progreso estatica.

---

## 18. Design Tokens

Compilacion completa de todos los tokens semanticos necesarios para produccion.

### 18.1 Colores

```
--background
--foreground

--card
--card-foreground

--popover
--popover-foreground

--primary
--primary-foreground

--secondary
--secondary-foreground

--muted
--muted-foreground

--accent
--accent-foreground

--border
--input
--ring

--success
--success-foreground

--warning
--warning-foreground

--danger
--danger-foreground

--info
--info-foreground
```

### 18.2 Spacing

```
--space-1: 4px
--space-2: 8px
--space-3: 12px
--space-4: 16px
--space-6: 24px
--space-8: 32px
--space-12: 48px
--space-16: 64px
```

### 18.3 Border Radius

```
--radius-sm: 4px
--radius-md: 6px
--radius-lg: 8px
--radius-xl: 12px
--radius-full: 9999px
```

### 18.4 Shadows

```
--shadow-sm: 0 1px 2px rgba(0,0,0,0.05)
--shadow-md: 0 4px 6px -1px rgba(0,0,0,0.07), 0 2px 4px -2px rgba(0,0,0,0.05)
--shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -4px rgba(0,0,0,0.04)
--shadow-xl: 0 20px 25px -5px rgba(0,0,0,0.08), 0 8px 10px -6px rgba(0,0,0,0.04)
```

### 18.5 Z-index

| Token | Valor | Uso |
|---|---|---|
| `--z-base` | 0 | Contenido normal. |
| `--z-sticky` | 10 | Header contextual, elementos sticky. |
| `--z-sidebar` | 20 | Sidebar fija. |
| `--z-dropdown` | 30 | Dropdowns, popovers, tooltips. |
| `--z-modal` | 40 | Dialogs, AlertDialogs, Sheets. |
| `--z-toast` | 50 | Toasts. Siempre sobre todo. |

### 18.6 Typography

```
--font-sans: 'Figtree', 'Inter', system-ui, sans-serif
--font-clinical: 'Atkinson Hyperlegible', 'Figtree', system-ui, sans-serif
--font-mono: 'JetBrains Mono', ui-monospace, monospace

--text-xs: 0.75rem / 1.4
--text-sm: 0.875rem / 1.5
--text-base: 1rem / 1.6
--text-lg: 1.125rem / 1.4
--text-xl: 1.25rem / 1.4
--text-2xl: 1.5rem / 1.3
--text-3xl: 1.875rem / 1.2

--font-weight-regular: 400
--font-weight-medium: 500
--font-weight-semibold: 600
--font-weight-bold: 700
```

### 18.7 Motion

```
--duration-fast: 150ms
--duration-normal: 200ms
--duration-slow: 300ms

--ease-out: cubic-bezier(0.16, 1, 0.3, 1)
--ease-in-out: cubic-bezier(0.45, 0, 0.55, 1)
--ease-in: cubic-bezier(0.55, 0.05, 0.68, 0.19)
```

### 18.8 Layout

```
--sidebar-width: 240px
--sidebar-width-collapsed: 64px
--header-height: 56px
--content-max-width: 80rem (max-w-7xl)
--form-max-width: 56rem (max-w-4xl)
--table-row-height-comfortable: 48px
--table-row-height-compact: 36px
```

---

## 19. Integracion tecnica futura

### 19.1 Next.js App Router

| Directriz | Detalle |
|---|---|
| Server Components por defecto | Mantener componentes en servidor a menos que requieran interaccion. Datos y composicion en servidor. |
| Client Components como hojas | Marcar `'use client'` solo en componentes que usan hooks, eventos o estado local. Push down al minimo. |
| Layouts persistentes | Usar `layout.tsx` para AppShell (sidebar + header). Navegacion no se re-renderiza entre rutas. |
| Route groups | Organizar por area funcional: `(app)/agenda`, `(app)/pacientes`, `(auth)/login`. |
| Loading por ruta | `loading.tsx` con Skeleton que coincida con la geometria final. |
| Error por ruta | `error.tsx` con mensaje claro y boton de reintento. |
| Streaming | `<Suspense>` para datos lentos. Skeleton por secciones independientes. |
| Links | `next/link` para toda navegacion interna. `prefetch={false}` para links de baja prioridad. |
| Fuentes | `next/font/google` para Figtree y Atkinson Hyperlegible. Aplicar en `layout.tsx` raiz. |
| Imagenes | `next/image` para todas las imagenes. `width`/`height` o `fill`. `priority` solo para LCP. |
| Metadata | `generateMetadata` para paginas dinamicas (ficha paciente). `metadata` exportado para paginas estaticas. |

### 19.2 Tailwind CSS

| Directriz | Detalle |
|---|---|
| Tokens semanticos | Mapear todos los design tokens como CSS variables en `globals.css` y extenderlos en `tailwind.config`. |
| Naming | Usar nombres semanticos (`bg-primary`, `text-muted-foreground`), nunca colores genericos (`bg-blue-500`). |
| Responsive | Mobile first. Prefijos `md:`, `lg:`, `xl:` para mejora progresiva. |
| Valores arbitrarios | Prohibidos excepto para alineacion con APIs externas. Usar la escala de tokens. |
| Dark mode | Configurar `darkMode: 'class'`. Definir tokens en `:root` y `.dark`. |
| Version | Verificar compatibilidad de sintaxis con la version instalada. No mezclar v3 y v4. |

### 19.3 shadcn/ui

| Directriz | Detalle |
|---|---|
| Instalacion | Via CLI (`npx shadcn@latest add`). Inicializar con `npx shadcn@latest init`. |
| Imports | `@/components/ui/` con path aliases configurados en `tsconfig.json`. |
| Tematizacion | CSS variables en `globals.css` siguiendo la convencion `primary`/`primary-foreground`. |
| Variantes | Extender con `cva` (class-variance-authority) para variantes especificas de Podoconi. |
| Composicion | Usar `asChild` para composicion de componentes. Usar compound components (`Card > CardHeader`). |
| Customizacion | Modificar archivos de componentes copiados cuando la variante no sea suficiente. Usar `cn()` para merge de clases. |
| Formularios | React Hook Form + `FormField` + `FormLabel` + `FormControl` + `FormMessage` + Zod. |
| Sidebar | Usar componente Sidebar de shadcn con `SidebarProvider` en layout. `SidebarTrigger` para toggle movil. |
| Charts | `ChartContainer` con `chartConfig` para tematizacion consistente (si se agregan graficos en el futuro). |
| Toasts | Sonner. `<Toaster />` en `layout.tsx` raiz. Usar `toast.success()`, `toast.error()`. |
| Accesibilidad | Confiar en la accesibilidad built-in de los componentes. No sobreescribir atributos ARIA. |

### 19.4 Server vs Client Components

| Criterio | Server Component | Client Component |
|---|---|---|
| Muestra datos sin interaccion | Si | No |
| Usa hooks (`useState`, `useEffect`) | No | Si |
| Responde a eventos (`onClick`, `onChange`) | No | Si |
| Accede a base de datos directamente | Si | No |
| Usa APIs del navegador | No | Si |
| Es un formulario interactivo | No | Si |
| Renderiza layout o composicion | Si | No |

**Regla general:** El 80% de los componentes de Podoconi deben ser Server Components. Solo formularios, componentes de interaccion (datepicker, dropdowns, toggles) y logica de estado local deben ser Client Components.

### 19.5 Seguridad en implementacion

1. Validar y autorizar toda Server Action. La validacion en cliente es solo UX; el servidor es la fuente de verdad.
2. Nunca exponer variables de entorno de servidor al cliente. Usar `NEXT_PUBLIC_` solo para valores no sensibles.
3. Sanitizar todo input de usuario antes de renderizar.
4. Configurar Content Security Policy en headers.
5. Middleware para proteccion de rutas autenticadas.

---

## Resumen ejecutivo

Este documento define el sistema de diseno completo para Podoconi Agenda Podologica. Establece un lenguaje visual clinico, sobrio, humano y profesional que prioriza la operacion diaria del podologe sobre la estetica decorativa.

**Decisiones criticas:**

1. **Estilo visual:** Minimalismo funcional + Accesibilidad etica. Rechazados: neumorphism, glassmorphism pesado, brutalismo.
2. **Paleta:** Teal/cyan moderado como primario (salud + confianza). Slate neutro como base. Verde de salud para exito. Tokens semanticos exclusivos.
3. **Tipografia:** Figtree (headings + UI) + Atkinson Hyperlegible (texto clinico). Rechazada Inter como unica fuente por personalidad demasiado neutra para un producto con identidad humana.
4. **Dashboard:** Operacional sobrio. Agenda del dia primero. KPIs secundarios. Sin graficos de BI en pantalla principal.
5. **Formularios:** React Hook Form + Zod + shadcn FormField. Validacion on blur + on submit.
6. **Accesibilidad:** WCAG AA obligatorio global. AAA en texto clinico, formularios y consentimientos.

**Riesgos identificados:**

| Riesgo | Mitigacion |
|---|---|
| Atkinson Hyperlegible solo tiene 2 pesos (Regular, Bold) | Usar solo para texto clinico largo. Figtree para el resto de la UI. |
| El catalogo UI/UX Pro Max recomienda neumorphism para salud | Rechazado con justificacion: contraste insuficiente y affordance debil. Documentado en anti-patrones. |
| Tokens de color definidos conceptualmente, no verificados contra WCAG | Los valores HSL exactos deben validarse con herramienta de contraste al momento de implementacion. |
| Modo oscuro no cubierto completamente en v1 | La arquitectura de tokens lo soporta. Implementacion en fase posterior. |
| Python no disponible para ejecutar el CLI de UI/UX Pro Max | Analisis realizado sobre datos CSV directamente. Recomendacion: instalar Python para iteraciones futuras. |

**Recomendaciones para implementacion futura:**

1. Comenzar por el AppShell (Sidebar + Header + Layout) como primera implementacion.
2. Implementar sistema de tokens en `globals.css` antes de cualquier componente.
3. Configurar Figtree y Atkinson Hyperlegible con `next/font` en el layout raiz.
4. Inicializar shadcn/ui y agregar componentes incrementalmente segun necesidad por pantalla.
5. Automatizar validacion de accesibilidad con axe-core en pipeline de CI.
6. Validar contraste de todos los tokens de color antes de implementar pantallas.
7. Instalar Python para habilitar el CLI de UI/UX Pro Max en sesiones futuras.

---

**Ninguna pantalla podra implementarse sin respetar este documento.**

**Toda desviacion requiere justificacion explicita y actualizacion de este documento antes de implementarse.**
