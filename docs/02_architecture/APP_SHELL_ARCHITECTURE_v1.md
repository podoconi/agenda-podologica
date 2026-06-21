# App Shell Architecture v1

**Proyecto:** Agenda Podologica (Podoconi)  
**Version:** 1.0  
**Estado:** Aprobado para implementacion  
**Fecha:** 2026-06-21  
**Autor:** Roberto Rojas  
**Fuentes de decision:**
- `PODOCONI_DESIGN_SYSTEM_v1.md` (fuente oficial de diseno visual)
- `ARQUITECTURA_CONCEPTUAL_v1.1.md` (modulos, bounded contexts, faseo)
- `SUPABASE_SCHEMA_BLUEPRINT_v1.2.md` (entidades, relaciones, tenant isolation)
- `UI_UX_PRO_MAX_SKILL_ANALYSIS.md` (recomendaciones UX/UI)
- `.claude/skills/ui-ux-pro-max` (catalogos: ux-guidelines, web-interface, stacks/shadcn, stacks/nextjs)

**Stack objetivo:** Next.js App Router + Tailwind CSS + shadcn/ui  
**Alcance:** Arquitectura documental del shell de aplicacion. No contiene codigo, componentes, wireframes ni mockups.

---

## 1. Objetivos del AppShell

### 1.1 Que problemas resuelve

El AppShell es la estructura persistente que envuelve toda la aplicacion autenticada. Resuelve:

1. **Orientacion.** El profesional debe saber en todo momento donde esta, que puede hacer y como llegar a donde necesita. La navegacion principal, los breadcrumbs y el estado activo resuelven este problema.
2. **Acceso rapido.** El podologe trabaja entre pacientes con pausas de segundos. Necesita llegar a cualquier paciente, cita o seccion del sistema sin recorrer menus. La busqueda global y el Command Palette resuelven este problema.
3. **Contexto persistente.** Al navegar entre secciones, el profesional no debe perder de vista que paciente esta atendiendo ni que tarea estaba haciendo. El header contextual y la persistencia de estado en URL resuelven este problema.
4. **Consistencia responsive.** El shell se usa en desktop de recepcion, tablet en box clinico y movil en atencion domiciliaria. La misma estructura funcional debe adaptarse sin perdida de capacidades.
5. **Feedback del sistema.** Notificaciones, errores y confirmaciones deben tener un lugar predecible y consistente. El sistema de overlays y toasts resuelve este problema.

### 1.2 Que experiencia debe entregar

El AppShell debe sentirse como un instrumento de trabajo: siempre disponible, nunca intrusivo, predecible en cada interaccion. No debe sentirse como un portal web ni como un dashboard corporativo.

**Experiencia objetivo:** El profesional abre la aplicacion, ve su agenda del dia, toca un paciente, registra la atencion, cierra el cobro y vuelve a la agenda. Todo sin perder contexto ni buscar menus.

### 1.3 Principios UX del shell

| Principio | Aplicacion |
|---|---|
| **Minima carga cognitiva** | El shell muestra solo la navegacion de primer nivel. La complejidad aparece cuando el usuario navega hacia ella, nunca antes. |
| **Velocidad operacional** | Acceso a cualquier paciente en 2 clics o 1 shortcut de teclado. Navegacion entre areas en 1 clic. |
| **Contexto permanente** | La sidebar y el header nunca desaparecen. El usuario siempre sabe donde esta. |
| **Mobile first** | Toda decision de layout parte del viewport mas pequeno y se enriquece hacia desktop. |
| **Accesibilidad nativa** | Navegacion completa por teclado. Skip links. Landmarks ARIA. Focus management en overlays. |
| **Escalabilidad sin re-arquitectura** | Agregar nuevas areas funcionales (Fase 2, Fase 3) debe requerir solo agregar un item a la sidebar, no reestructurar el shell. |

---

## 2. Estructura global

### 2.1 Anatomia del shell

```
+-------+--------------------------------------------------+
|       | [Header contextual]                              |
|       | Breadcrumbs · Titulo · Acciones · Notificaciones |
|       +--------------------------------------------------+
|  S    |                                                  |
|  I    |  [Area principal]                                |
|  D    |                                                  |
|  E    |  Contenido de la ruta activa.                    |
|  B    |  Scroll independiente.                           |
|  A    |  max-w-7xl centrado.                             |
|  R    |                                                  |
|       |                                                  |
+-------+--------------------------------------------------+
```

Sobre todo el layout, el **overlay system** puede proyectar Dialogs, Sheets, AlertDialogs, Popovers, Dropdowns y Toasts en capas superiores con z-index gestionado.

### 2.2 Responsabilidades de cada zona

| Zona | Responsabilidad | Persistencia |
|---|---|---|
| **Sidebar** | Navegacion de primer nivel. Identidad de organizacion. Selector de profesional (centros). Perfil de usuario. | Permanente en desktop. Drawer en movil. |
| **Header contextual** | Breadcrumbs. Titulo de la vista actual. Acciones rapidas contextuales. Acceso a busqueda global. Notificaciones. | Sticky en el tope del area principal. Siempre visible. |
| **Area principal** | Contenido de la ruta activa. Formularios, tablas, fichas, dashboard. Scroll propio. | Cambia con cada navegacion. |
| **Zona de acciones** | Botones primarios contextuales (dentro del header). Acciones batch (dentro de DataTable). | Contextual a la vista. |
| **Zona de notificaciones** | Toasts transitorios. Badge de notificaciones pendientes en header. | Transitoria (toasts). Persistente (badge). |
| **Overlay system** | Dialogs, Sheets, AlertDialogs, Popovers, Dropdowns, Command Palette. | Temporales. Se proyectan sobre el layout sin destruirlo. |

### 2.3 Flujo de scroll

- **Sidebar:** Scroll interno independiente si su contenido excede la altura del viewport.
- **Header:** Sticky. No scrollea con el contenido.
- **Area principal:** Scroll vertical propio. Es la unica zona con scroll de contenido.
- **Overlays:** Los modales y sheets tienen scroll interno propio cuando su contenido excede la altura disponible.

El body de la pagina no tiene scroll propio. El scroll pertenece al area principal.

---

## 3. Areas funcionales de primer nivel

### 3.1 Navegacion propuesta

Basada en los modulos de Fase 1 de `ARQUITECTURA_CONCEPTUAL_v1.1.md`, ordenados por frecuencia de acceso diario del profesional.

| Orden | Area | Icono Lucide | Modulo fuente | Justificacion del orden |
|---|---|---|---|---|
| 1 | **Inicio** | `LayoutDashboard` | Dashboard | Punto de entrada. Vista operacional del dia. |
| 2 | **Agenda** | `Calendar` | M06 Agenda | Nervio central del negocio. Consultada decenas de veces al dia. |
| 3 | **Pacientes** | `Users` | M03 Pacientes | Unidad transversal principal. Acceso a fichas, historia, atenciones. |
| 4 | **Atenciones** | `ClipboardCheck` | M04 Atencion Clinica | Registro clinico. Acceso directo sin pasar siempre por paciente. |
| 5 | **Seguimientos** | `BellRing` | M07 Seguimiento | Pendientes de retorno. Alertas vencidas. |
| 6 | **Cobros** | `CreditCard` | M09 Cobros | Registro economico. Pendientes de pago. |

**Separador visual**

| Orden | Area | Icono Lucide | Modulo fuente | Justificacion |
|---|---|---|---|---|
| 7 | **Configuracion** | `Settings` | M02 Organizacion + M10 Arancel | Ajustes de organizacion, tipos de atencion, arancel. Baja frecuencia. |

### 3.2 Reglas de visibilidad por rol

En Fase 1, Podoconi opera con un modelo de roles implicitos basado en la relacion profesional-organizacion. No existe un sistema formal de permisos granulares.

| Area | Profesional titular | Personal administrativo (futuro) |
|---|---|---|
| Inicio | Visible | Visible |
| Agenda | Visible | Visible |
| Pacientes | Visible | Visible (sin acceso a datos clinicos sensibles) |
| Atenciones | Visible | Oculto |
| Seguimientos | Visible | Oculto |
| Cobros | Visible | Visible |
| Configuracion | Visible | Oculto |

La granularidad de permisos por rol es Fase 3 (M22 Roles y Permisos). En Fase 1, la configuracion de visibilidad es estatica.

### 3.3 Iconografia

- Fuente unica de iconos: **Lucide React** (`lucide-react`).
- Tamano en sidebar expandida: 20px con label de texto.
- Tamano en sidebar colapsada: 20px sin label, tooltip con el nombre.
- Nunca usar emojis como iconos de interfaz.
- Todos los iconos con `aria-hidden="true"` cuando acompanan texto.

### 3.4 Areas futuras (Fase 2+)

El shell debe soportar la adicion sin re-arquitectura de:

| Fase | Area | Modulo |
|---|---|---|
| 2 | Centros | M11 Centros Medicos |
| 2 | Documentos | M14 Documentos Clinicos |
| 2 | Fotografias | M08 Fotografias Clinicas |
| 3 | Reportes | M20 Reportes |
| 3 | Auditoria | M21 Auditoria Operacional |

Agregar un area nueva implica: un item en la sidebar, una ruta en el App Router, un layout si es necesario. No requiere cambios en el shell.

---

## 4. Arquitectura de navegacion

### 4.1 Profundidad maxima

**Regla: 3 niveles maximo.**

| Nivel | Ejemplo | Mecanismo |
|---|---|---|
| 1 | Pacientes | Item de sidebar |
| 2 | Pacientes > Juan Perez | Ruta dinamica |
| 3 | Pacientes > Juan Perez > Historia clinica | Tab o sub-ruta |

Profundidad mayor a 3 indica que la informacion arquitectura esta mal organizada. Si una vista necesita un cuarto nivel, debe re-evaluarse si pertenece al area actual o merece su propio espacio.

### 4.2 Estrategia de breadcrumbs

| Profundidad | Breadcrumb en desktop | Breadcrumb en movil |
|---|---|---|
| 1 (area) | No se muestra. El titulo del header es suficiente. | No se muestra. |
| 2 (detalle) | `Pacientes > Juan Perez` | Flecha de retorno + titulo. |
| 3 (sub-detalle) | `Pacientes > Juan Perez > Historia clinica` | Flecha de retorno al nivel 2 + titulo. |

Los breadcrumbs son navegables (links) excepto el ultimo segmento (ubicacion actual). Generados automaticamente por la ruta del App Router.

### 4.3 Deep linking

Toda vista que un usuario pueda necesitar compartir, restaurar o regresar debe tener URL propia:

| Elemento | Representacion en URL |
|---|---|
| Area funcional | `/agenda`, `/pacientes`, `/cobros` |
| Detalle de entidad | `/pacientes/[id]`, `/atenciones/[id]` |
| Sub-vista de entidad | `/pacientes/[id]/historia`, `/pacientes/[id]/cobros` |
| Filtros activos | `?estado=pendiente&fecha=2026-06-21` (search params) |
| Tab activo | `?tab=atenciones` (search param) o ruta `/pacientes/[id]/atenciones` |

Los modales y dialogs NO tienen URL propia. Son acciones, no destinos.

### 4.4 Navegacion movil

- Menu hamburguesa en header abre sidebar como Sheet (`side="left"`).
- Estructura de navegacion identica al desktop.
- Breadcrumbs simplificados a flecha de retorno.
- Acciones contextuales del header colapsan en DropdownMenu.
- Swipe lateral no se usa para navegacion (evitar conflictos con gestos del sistema).

### 4.5 Persistencia de contexto

| Mecanismo | Que persiste |
|---|---|
| URL (search params) | Filtros de tabla, tab activo, pagina actual, termino de busqueda. |
| URL (ruta) | Entidad seleccionada, sub-vista activa. |
| Layout de Next.js | Sidebar y header no se re-renderizan al navegar entre rutas. |
| Estado del servidor | Datos del paciente cargados en el layout de paciente persisten al navegar entre sus sub-vistas. |

Al navegar de `/pacientes/[id]/atenciones` a `/pacientes/[id]/cobros`, el contexto del paciente (nombre, datos) se mantiene por el layout compartido. Solo el contenido del area principal cambia.

### 4.6 Regla transversal del paciente

> **El paciente es la unidad transversal principal de navegacion.**

Esto significa:
1. Desde cualquier vista de un paciente, se puede navegar a todas sus sub-vistas sin volver a la lista.
2. El contexto del paciente (identidad, datos basicos) permanece visible mientras se navega dentro de su ficha.
3. Toda entidad clinica (atencion, seguimiento, cobro, documento) debe tener un link rapido al paciente al que pertenece.
4. La busqueda global prioriza pacientes como resultado principal.
5. Cuando un profesional ve una cita en la agenda, puede llegar al paciente en 1 clic.

---

## 5. Sidebar

### 5.1 Dimensiones

| Estado | Ancho | Contenido visible |
|---|---|---|
| Expandida | 240px | Iconos + labels de texto + organizacion + usuario |
| Colapsada | 64px | Solo iconos + tooltips al hover |
| Drawer movil | 280px (max 85vw) | Identico a expandida. Sheet con overlay. |

### 5.2 Contenido de la sidebar

De arriba a abajo:

| Seccion | Contenido |
|---|---|
| **Identidad** | Logo o nombre de la organizacion. Truncado si excede ancho. En colapsada: solo icono/avatar. |
| **Navegacion principal** | Items de nivel 1 (ver seccion 3.1). Iconos Lucide 20px + label. |
| **Separador** | Linea visual sutil antes de Configuracion. |
| **Configuracion** | Item unico al fondo de la navegacion. |
| **Perfil de usuario** | Avatar (initials), nombre, menu de opciones (perfil, cerrar sesion). Posicionado al fondo de la sidebar. |

### 5.3 Estado expandido

- Items de navegacion muestran icono + label.
- Item activo: fondo `accent`, texto `accent-foreground`, borde izquierdo `primary` de 3px.
- Item hover: fondo `accent` sutil. Transicion `duration-fast` (150ms).
- Item de organizacion muestra nombre completo truncado con ellipsis.
- Item de perfil muestra avatar circular + nombre + menu desplegable.

### 5.4 Estado colapsado

- Solo iconos visibles (20px).
- Tooltip con nombre del area al hover/focus de cada item.
- Item activo: fondo `accent`, borde izquierdo `primary`.
- Organizacion: solo icono/avatar.
- Perfil: solo avatar circular. Click abre DropdownMenu.

### 5.5 Toggle de colapso

- Boton de toggle visible en la base de la sidebar (desktop).
- Icono: `ChevronsLeft` cuando expandida, `ChevronsRight` cuando colapsada.
- `aria-label`: "Colapsar menu" / "Expandir menu".
- La preferencia de estado (expandida/colapsada) se persiste en `localStorage`.

### 5.6 Comportamiento responsive

| Viewport | Comportamiento |
|---|---|
| >= 1024px (desktop) | Sidebar fija. Expandida o colapsada segun preferencia. |
| 768-1023px (tablet) | Sidebar oculta. Se abre como Sheet con toggle en header. |
| < 768px (movil) | Sidebar oculta. Se abre como Sheet con toggle en header. |

### 5.7 Mobile drawer

- Implementacion: componente `Sheet` de shadcn/ui con `side="left"`.
- Trigger: boton hamburguesa (`Menu` icon) en el header.
- Cierre: click en overlay, boton X, tecla Escape, seleccion de item de navegacion.
- Overlay: fondo oscurecido semi-transparente.
- Focus trap activo mientras el drawer esta abierto.
- Focus devuelto al boton hamburguesa al cerrar.
- z-index: `z-modal` (40). Por encima de header y contenido.

### 5.8 Scroll de la sidebar

Si la cantidad de items de navegacion excede la altura del viewport:
- La seccion de navegacion principal tiene scroll interno (`overflow-y-auto`).
- El perfil de usuario permanece fijo al fondo (`sticky bottom`).
- La identidad de la organizacion permanece fija al tope.

### 5.9 Implementacion tecnica

Usar el componente `Sidebar` de shadcn/ui:
- `SidebarProvider` en el layout raiz de la aplicacion autenticada.
- `SidebarTrigger` para toggle en movil.
- `SidebarContent`, `SidebarGroup`, `SidebarGroupLabel`, `SidebarMenu`, `SidebarMenuItem`, `SidebarMenuButton` para estructura semantica.
- El componente gestiona internamente el estado abierto/cerrado, responsive y animaciones.

---

## 6. Header contextual

### 6.1 Dimensiones

| Propiedad | Valor |
|---|---|
| Altura | 56px |
| Posicion | Sticky al tope del area principal |
| z-index | `z-sticky` (10) |
| Padding | `px-4 md:px-6 lg:px-8` |
| Fondo | `background` con borde inferior `border` |

### 6.2 Contenido del header

De izquierda a derecha:

| Zona | Contenido | Responsive |
|---|---|---|
| **Izquierda** | Boton hamburguesa (solo < 1024px). Breadcrumbs (si profundidad >= 2). Titulo de la vista actual. | Hamburguesa desaparece en desktop. |
| **Centro** | Vacio. El titulo ocupa el espacio disponible. | N/A |
| **Derecha** | Acceso a busqueda global (`Search` icon). Notificaciones (badge con conteo). Accion primaria contextual (boton). | Acciones secundarias colapsan en DropdownMenu en movil. |

### 6.3 Acciones rapidas

El header puede contener **una accion primaria contextual** segun la vista activa:

| Vista | Accion primaria |
|---|---|
| Agenda | "Nueva cita" |
| Pacientes | "Nuevo paciente" |
| Atenciones | "Nueva atencion" |
| Cobros | "Registrar cobro" |
| Paciente > detalle | "Agendar cita" |

La accion se renderiza como `Button` con variante `default` (primaria). En movil, se muestra como `IconButton` con tooltip.

### 6.4 Breadcrumbs

Generados automaticamente por la estructura de rutas del App Router.

- **Desktop:** Breadcrumbs completos. Segmentos intermedios como links. Ultimo segmento como texto.
- **Movil:** Simplificados a icono de flecha izquierda (`ArrowLeft`) + titulo de la vista actual. El clic en la flecha navega al nivel anterior.
- **Formato:** Segmentos separados por `/` o `>`. IDs de entidad reemplazados por nombre legible (nombre del paciente, no UUID).

### 6.5 Informacion contextual

El header puede mostrar metadata contextual segun la vista:

| Vista | Metadata |
|---|---|
| Paciente > detalle | Nombre del paciente visible en el titulo del header. |
| Atencion > detalle | Paciente + fecha de la atencion. |
| Agenda (dia especifico) | Fecha seleccionada. |

### 6.6 Comportamiento sticky

- El header permanece visible mientras el usuario scrollea el area principal.
- No se oculta al scrollear hacia abajo (auto-hide desactivado). La perdida de contexto es peor que el espacio vertical ganado.
- En movil, los 56px de header reducen el area visible pero el tradeoff de orientacion permanente lo justifica.

---

## 7. Sistema de overlays

### 7.1 Tipos de overlay y cuando usarlos

| Overlay | Uso correcto | Uso incorrecto | z-index |
|---|---|---|---|
| **Dialog** | Formularios de creacion/edicion. Detalles que requieren atencion completa. Confirmaciones complejas. | Listados. Navegacion. Contenido que el usuario necesita ver junto a otra informacion. | `z-modal` (40) |
| **AlertDialog** | Confirmacion de acciones destructivas o irreversibles (eliminar, anular, cerrar atencion). | Confirmaciones no destructivas. Informacion. | `z-modal` (40) |
| **Sheet** | Sidebar movil. Filtros avanzados. Panel de detalles lateral. Formularios secundarios. | Contenido principal. Acciones criticas que requieren confirmacion. | `z-modal` (40) |
| **Popover** | Selectores de fecha. Menus de acciones contextuales. Filtros rapidos. Informacion de ayuda. | Formularios largos. Contenido con scroll extenso. | `z-dropdown` (30) |
| **DropdownMenu** | Menu de acciones sobre una entidad. Menu de perfil. Acciones batch. | Navegacion principal. Formularios. | `z-dropdown` (30) |
| **Tooltip** | Informacion adicional no esencial. Nombre de iconos sin label. Valor completo de texto truncado. | Informacion critica. Acciones. Contenido interactivo. | `z-dropdown` (30) |
| **Toast** | Confirmacion de exito. Notificacion de error. Feedback transitorio. | Informacion persistente. Acciones que requieren decision. | `z-toast` (50) |
| **Command Palette** | Busqueda global. Acceso rapido a cualquier entidad o accion. | N/A. Siempre Command Palette. | `z-modal` (40) |

### 7.2 Reglas del overlay system

1. **Nunca apilar mas de 2 overlays.** Un Dialog puede abrir un AlertDialog de confirmacion. Pero un Dialog no abre otro Dialog.
2. **Focus trap en modales.** Dialog, AlertDialog y Sheet atrapan el foco. Popover y Dropdown no.
3. **Escape cierra el overlay mas alto.** Siempre. Sin excepcion.
4. **Click en overlay cierra:** Dialog, Sheet, Popover, Dropdown. **No cierra:** AlertDialog (requiere decision explicita).
5. **Focus devuelto al trigger** al cerrar cualquier overlay.
6. **Toasts no bloquean interaccion.** Aparecen y desaparecen sin interrumpir el flujo.
7. **Posicion de toasts:** bottom-right en desktop, bottom-center en movil. Apilado vertical con maximo 3 visibles.

---

## 8. Busqueda global

### 8.1 Command Palette

Podoconi incorpora un Command Palette como mecanismo primario de busqueda y acceso rapido.

**Justificacion:** El podologe trabaja con decenas de pacientes diarios. Navegar por listas y menus es lento. El Command Palette permite encontrar cualquier paciente, ir a cualquier seccion o ejecutar cualquier accion en menos de 3 segundos.

Fuente: shadcn.csv #22 Command component para searchable lists y palettes.

### 8.2 Acceso

| Metodo | Trigger |
|---|---|
| Teclado | `Ctrl+K` (Windows/Linux) / `Cmd+K` (macOS) |
| Mouse/tactil | Click en icono de busqueda (`Search`) en el header |

### 8.3 Implementacion

Componente `Command` de shadcn/ui (basado en cmdk):
- `CommandDialog` como contenedor modal.
- `CommandInput` con placeholder "Buscar pacientes, acciones...".
- `CommandList` con resultados agrupados.
- `CommandGroup` por categoria.
- `CommandItem` por resultado individual.
- `CommandEmpty` cuando no hay resultados: "No se encontraron resultados. Intenta con otro termino."

### 8.4 Entidades indexadas

| Grupo | Entidad | Campos buscables | Ejemplo |
|---|---|---|---|
| **Pacientes** | `paciente` | nombre, apellido, RUT, telefono | "maria" → Maria Lopez, Maria Torres |
| **Citas** | `cita` | nombre paciente + fecha | "maria 21" → Cita Maria Lopez 21/06 |
| **Acciones rapidas** | Comandos | nombre de la accion | "nueva cita" → Abrir formulario de nueva cita |
| **Navegacion** | Areas | nombre del area | "agenda" → Ir a Agenda |

### 8.5 Prioridad de resultados

1. Pacientes (coincidencia en nombre/apellido/RUT).
2. Acciones rapidas (nueva cita, nuevo paciente, registrar cobro).
3. Navegacion (ir a Agenda, ir a Cobros).
4. Citas (coincidencia por nombre de paciente en citas proximas).

### 8.6 Comportamiento

- Busqueda debounced (300ms) para evitar consultas excesivas.
- Maximo 5 resultados por grupo.
- Seleccion con teclado: flechas para navegar, Enter para seleccionar.
- Escape cierra el Command Palette.
- Al seleccionar un paciente: navegar a `/pacientes/[id]`.
- Al seleccionar una accion: ejecutar la accion (abrir dialog correspondiente).
- Al seleccionar navegacion: navegar a la ruta.
- Historial de busquedas recientes: no en v1. Evaluacion futura.

---

## 9. Navegacion centrada en paciente

### 9.1 Estructura de la ficha de paciente

```
Paciente [Juan Perez]
 |
 +-- Resumen
 |    Datos personales, contacto, origen, ultima atencion, proximo seguimiento.
 |
 +-- Historia clinica
 |    Antecedentes, patologias, medicamentos, alergias, factores de riesgo.
 |    Texto clinico largo. Fuente Atkinson Hyperlegible.
 |
 +-- Atenciones
 |    Historial cronologico de atenciones del paciente.
 |    Acceso a detalle de cada atencion.
 |
 +-- Seguimientos
 |    Seguimientos activos y cerrados del paciente.
 |    Estado de retorno.
 |
 +-- Cobros
 |    Historial de cobros del paciente.
 |    Estado de pagos (pendiente, pagado, parcial).
 |
 +-- Documentos (Fase 2)
 |    Consentimientos, informes de sesion.
 |
 +-- Auditoria (Fase 3)
      Log de acciones realizadas sobre este paciente.
```

### 9.2 Mecanismo de navegacion interna

Las sub-vistas del paciente se implementan como:

**Opcion elegida: Rutas anidadas con layout compartido.**

```
/pacientes/[id]              → Resumen (default)
/pacientes/[id]/historia     → Historia clinica
/pacientes/[id]/atenciones   → Historial de atenciones
/pacientes/[id]/seguimientos → Seguimientos
/pacientes/[id]/cobros       → Cobros
```

**Justificacion:**
- Cada sub-vista tiene URL propia (deep linking).
- El layout del paciente (header con nombre, tabs de navegacion) se comparte entre sub-vistas y no se re-renderiza.
- Cada sub-vista puede tener su propio `loading.tsx` y `error.tsx`.
- Soporta `Suspense` por seccion.

**Descartado:** Tabs sin ruta. No soportan deep linking ni loading por seccion.

### 9.3 Cabecera del paciente

Dentro del layout de paciente, una cabecera persistente muestra:

| Elemento | Contenido |
|---|---|
| Nombre | Nombre completo del paciente. Tipografia H2. |
| Datos rapidos | RUT, telefono, edad. Tipografia `text-sm`, `muted-foreground`. |
| Estado | Badge con estado de ultimo seguimiento si existe. |
| Accion rapida | "Agendar cita" (Button contextual). |

Esta cabecera es parte del layout del paciente, no del header global. Aparece debajo del header global y encima de las tabs/contenido.

### 9.4 Navegacion interna del paciente

Tabs horizontales debajo de la cabecera del paciente:

| Tab | Ruta | Visible en |
|---|---|---|
| Resumen | `/pacientes/[id]` | Siempre |
| Historia | `/pacientes/[id]/historia` | Siempre |
| Atenciones | `/pacientes/[id]/atenciones` | Siempre |
| Seguimientos | `/pacientes/[id]/seguimientos` | Siempre |
| Cobros | `/pacientes/[id]/cobros` | Siempre |
| Documentos | `/pacientes/[id]/documentos` | Fase 2 |

- Tab activo: texto `primary`, borde inferior `primary` (2px).
- Tab inactivo: texto `muted-foreground`.
- En movil: tabs con scroll horizontal si exceden el ancho del viewport.
- `aria-current="page"` en el tab activo.

### 9.5 Reglas de persistencia de contexto del paciente

1. Al navegar entre tabs del paciente, los datos de la cabecera no se recargan.
2. Al salir del paciente (volver a lista), el scroll position de la lista se restaura.
3. Al volver al paciente desde la agenda, se restaura el ultimo tab visitado (via URL).
4. El nombre del paciente aparece en el breadcrumb global: `Pacientes > Juan Perez > Atenciones`.

---

## 10. Timeline clinico

### 10.1 ClinicalTimeline

| Aspecto | Especificacion |
|---|---|
| **Proposito** | Visualizar la historia de interacciones clinicas de un paciente en orden cronologico inverso (mas reciente primero). |
| **Ubicacion** | Vista "Atenciones" dentro de la ficha del paciente (`/pacientes/[id]/atenciones`). |
| **Contenido por item** | Fecha, tipo de atencion (StatusBadge), modalidad, profesional, resumen breve, estado del cobro asociado. |
| **Interaccion** | Click en un item navega al detalle de la atencion. |
| **Casos de uso** | Revisar la secuencia de atenciones de un paciente. Identificar patrones de tratamiento. Encontrar la ultima atencion para comparar con la actual. |
| **Filtros** | Por tipo de atencion, por rango de fecha, por profesional (centros). |
| **Paginacion** | Scroll infinito o paginacion. Primeras 20 atenciones visibles. |

### 10.2 AuditTimeline

| Aspecto | Especificacion |
|---|---|
| **Proposito** | Registrar y visualizar las acciones administrativas y clinicas realizadas sobre una entidad. |
| **Ubicacion** | Vista "Auditoria" dentro de la ficha del paciente (Fase 3). Tambien en entidades individuales (atencion, cobro) como seccion colapsable. |
| **Contenido por item** | Timestamp, accion (creo, modifico, cerro, anulo), usuario, detalle del cambio. |
| **Interaccion** | Solo lectura. Sin navegacion. |
| **Casos de uso** | Verificar quien cerro una atencion. Rastrear cambios de estado en un cobro. Auditoria legal. |
| **Fase** | Los datos se recolectan desde Fase 1 (T00 Trazabilidad Minima). La visualizacion es Fase 3 (M21 Auditoria Operacional). |

### 10.3 Distincion entre timelines

| Dimension | ClinicalTimeline | AuditTimeline |
|---|---|---|
| Audiencia | Podologe en rol clinico | Podologe en rol administrativo/legal |
| Granularidad | Por atencion completa | Por accion individual |
| Proposito | Continuidad clinica | Trazabilidad y responsabilidad |
| Interaccion | Navegable (click a detalle) | Solo lectura |
| Fase | Fase 1 | Visualizacion Fase 3 (datos desde Fase 1) |

---

## 11. Dashboard Container

### 11.1 Proposito

El dashboard container define la estructura espacial del Inicio (`/`), no su contenido. Los widgets y datos del dashboard se disenan como parte de las pantallas clinicas, no del shell.

### 11.2 Estructura del contenedor

```
+--------------------------------------------------+
| [KPI Row]                                        |
| 4-6 KpiCards en fila. Scroll horizontal en movil.|
+--------------------------------------------------+
| [Primary Zone]           | [Secondary Zone]      |
| 2/3 del ancho.           | 1/3 del ancho.        |
| Agenda del dia.          | Pendientes.            |
|                          | Seguimientos.          |
|                          | Cobros pendientes.     |
+--------------------------------------------------+
```

### 11.3 Zonas

| Zona | Responsabilidad | Responsive |
|---|---|---|
| **KPI Row** | Contenedor para hasta 6 KpiCards. Una fila en desktop, scroll horizontal en movil. | Fila horizontal siempre. Scroll horizontal en < 768px. |
| **Primary Zone** | Bloque principal de contenido operacional. Agenda del dia en v1. | Ancho completo en movil. 2/3 en desktop. |
| **Secondary Zone** | Bloques apilados de informacion secundaria: pendientes, seguimientos, cobros. | Ancho completo en movil. 1/3 en desktop. Debajo de Primary Zone en movil. |

### 11.4 Reglas del container

1. El container define grid, no contenido. Los bloques internos son componentes independientes.
2. El orden en movil sigue la prioridad definida en el Design System seccion 13.2: Agenda > Pendientes > Seguimientos > Cobros > KPIs.
3. Cada bloque tiene su propio `Suspense` boundary con Skeleton que coincide con su geometria final.
4. El container no decide que datos cargar. Cada bloque es un Server Component que carga sus propios datos.

---

## 12. Responsive Strategy

### 12.1 Breakpoints

Heredados del Design System:

| Nombre | Ancho minimo | Prefijo Tailwind |
|---|---|---|
| mobile | 0px | (base) |
| tablet | 768px | `md:` |
| desktop | 1024px | `lg:` |
| wide | 1280px | `xl:` |

### 12.2 Comportamiento del shell por breakpoint

| Componente | Mobile (< 768px) | Tablet (768-1023px) | Desktop (>= 1024px) | Wide (>= 1280px) |
|---|---|---|---|---|
| **Sidebar** | Sheet drawer (280px) | Sheet drawer (280px) | Fija expandida/colapsada | Fija expandida/colapsada |
| **Header** | Hamburguesa + titulo + busqueda | Hamburguesa + breadcrumbs + acciones | Breadcrumbs + titulo + acciones + busqueda | Identico a desktop |
| **Area principal** | Ancho completo. `px-4`. | Ancho completo. `px-6`. | `max-w-7xl mx-auto`. `px-8`. | Identico a desktop. Espacio extra en laterales. |
| **Dashboard** | 1 columna. KPIs scroll horizontal. | 1 columna. KPIs en fila. | 2 columnas (2/3 + 1/3). KPIs en fila. | Identico a desktop. |
| **Ficha paciente** | Tabs scroll horizontal. 1 columna. | Tabs visibles. 1 columna. | Tabs + contenido amplio. | Identico a desktop. |
| **DataTable** | Scroll horizontal. Columnas prioritarias. | Tabla completa con scroll si necesario. | Tabla completa. | Tabla con espacio extra. |
| **Formularios** | 1 columna. | 1 columna. | 1-2 columnas segun relacion de campos. | Identico a desktop. |
| **Command Palette** | Ancho completo menos margins. | 640px centrado. | 640px centrado. | 640px centrado. |

### 12.3 Pruebas responsive obligatorias

Toda modificacion al shell debe verificarse en los anchos definidos en el Design System seccion 8.2:

320px, 375px, 768px, 1024px, 1280px (obligatorias) + 1440px, 1536px (recomendadas).

---

## 13. Accesibilidad del shell

### 13.1 Skip links

Un skip link como primer elemento focusable de la pagina:

- Texto: "Ir al contenido principal"
- Destino: `#main-content` (el `<main>` del area principal).
- Visible solo en foco (oculto visualmente pero accesible por teclado).
- Posicion: absoluto, aparece sobre el header al recibir foco.

### 13.2 Focus management

| Evento | Comportamiento del foco |
|---|---|
| Abrir sidebar movil | Foco al primer item de navegacion. |
| Cerrar sidebar movil | Foco devuelto al boton hamburguesa. |
| Abrir Dialog/Sheet | Foco al primer elemento interactivo del overlay. Focus trap activo. |
| Cerrar Dialog/Sheet | Foco devuelto al elemento que abrio el overlay. |
| Abrir Command Palette | Foco al input de busqueda. |
| Cerrar Command Palette | Foco devuelto al elemento que lo abrio. |
| Navegar entre rutas | Foco al titulo de la nueva vista (H1 o primer heading). |
| Abrir AlertDialog | Foco al boton Cancel (accion segura). |

### 13.3 Keyboard navigation

| Tecla | Accion |
|---|---|
| `Tab` | Navegar entre elementos interactivos en orden del DOM. |
| `Shift+Tab` | Navegar hacia atras. |
| `Enter/Space` | Activar boton, link o item de menu. |
| `Escape` | Cerrar overlay mas alto (Dialog, Sheet, Popover, Command Palette). |
| `Ctrl+K` / `Cmd+K` | Abrir Command Palette. |
| Flechas arriba/abajo | Navegar items dentro de sidebar, DropdownMenu, Command Palette. |
| `Home/End` | Ir al primer/ultimo item en listas de menu. |

### 13.4 Landmarks ARIA

| Landmark | Elemento HTML | Ubicacion |
|---|---|---|
| `<nav aria-label="Menu principal">` | Sidebar | Navegacion principal. |
| `<header role="banner">` | Header contextual | Encabezado de la aplicacion. |
| `<main id="main-content">` | Area principal | Contenido principal. Destino del skip link. |
| `<nav aria-label="Breadcrumbs">` | Breadcrumbs | Navegacion de ubicacion. |
| `<aside aria-label="Filtros">` | Panel de filtros (Sheet) | Cuando se usan filtros laterales. |

### 13.5 ARIA strategy

1. **Semantica HTML primero.** Usar `<nav>`, `<main>`, `<header>`, `<button>`, `<a>` antes de atributos ARIA.
2. **ARIA solo cuando HTML no alcanza.** `aria-label` en botones de solo icono. `aria-current="page"` en sidebar y tabs activos. `aria-expanded` en colapsables.
3. **No sobreescribir ARIA de shadcn/ui.** Los componentes de shadcn tienen ARIA incorporado (Dialog, AlertDialog, Sheet, Command). No modificar.
4. **`aria-live` para actualizaciones asincronas.** Conteo de notificaciones: `aria-live="polite"`. Errores criticos: `role="alert"`.
5. **Anunciar navegacion.** Al cambiar de ruta, el titulo de la nueva pagina debe ser anunciado. Implementar con `document.title` actualizado y foco al heading.

---

## 14. Performance

### 14.1 Streaming

El shell usa Server Components por defecto. Las zonas de contenido que dependen de datos lentos usan `<Suspense>` con Skeleton:

| Zona | Boundary | Fallback |
|---|---|---|
| Dashboard - KPIs | Un `Suspense` por KpiCard o uno para toda la fila. | Skeleton con geometria de KpiCard. |
| Dashboard - Agenda | Un `Suspense` para el bloque de agenda. | Skeleton con geometria de lista de citas. |
| Dashboard - Secundario | Un `Suspense` por bloque secundario. | Skeleton por bloque. |
| Ficha paciente - cabecera | Un `Suspense` para los datos del paciente. | Skeleton con geometria de cabecera. |
| Ficha paciente - contenido | Un `Suspense` por tab/sub-ruta. | Skeleton del contenido del tab. |

### 14.2 Loading por ruta

Cada ruta significativa tiene su `loading.tsx`:

```
(app)/loading.tsx              → Skeleton del dashboard
(app)/agenda/loading.tsx       → Skeleton de la agenda
(app)/pacientes/loading.tsx    → Skeleton de la lista de pacientes
(app)/pacientes/[id]/loading.tsx → Skeleton de la ficha
```

El shell (sidebar + header) permanece visible y funcional durante la carga. Solo el area principal muestra el skeleton.

### 14.3 Lazy loading

| Componente | Estrategia |
|---|---|
| Command Palette | `dynamic()` import. No se carga hasta que el usuario presiona `Ctrl+K` o click en busqueda. |
| Contenido de Dialog/Sheet | `dynamic()` import para formularios pesados. El Dialog wrapper se carga; su contenido se importa lazily. |
| Charts (futuro) | `dynamic(() => import('./Chart'), { ssr: false })`. Sin SSR por dependencia de DOM. |
| DataTable | Cargada con la ruta. No lazy (es el contenido principal). |

### 14.4 Prefetch

- `next/link` con prefetch por defecto para items de sidebar (rutas de primer nivel).
- `prefetch={false}` para links dentro de listas y tablas (muchos items, bajo porcentaje de click).
- `prefetch={false}` para links en Command Palette (resultados de busqueda).

### 14.5 Virtualizacion

- Listas con mas de 50 items: virtualizar con `@tanstack/react-virtual` o equivalente.
- ClinicalTimeline: virtualizar si el paciente tiene mas de 50 atenciones.
- Command Palette results: limitados a 5 por grupo (no requiere virtualizacion).
- DataTable: paginacion server-side (25 filas). No virtualizar.

---

## 15. Next.js App Router

### 15.1 Route groups

```
app/
 |
 +-- (auth)/
 |    +-- login/page.tsx
 |    +-- registro/page.tsx
 |    +-- recuperar/page.tsx
 |    +-- layout.tsx              → Layout de autenticacion. Sin sidebar. Centrado.
 |
 +-- (app)/
 |    +-- layout.tsx              → AppShell: SidebarProvider + Sidebar + Header + Main.
 |    +-- page.tsx                → Dashboard (Inicio).
 |    +-- loading.tsx             → Skeleton del dashboard.
 |    +-- error.tsx               → Error global del shell.
 |    |
 |    +-- agenda/
 |    |    +-- page.tsx           → Vista de agenda.
 |    |    +-- loading.tsx
 |    |
 |    +-- pacientes/
 |    |    +-- page.tsx           → Lista de pacientes.
 |    |    +-- loading.tsx
 |    |    +-- [id]/
 |    |         +-- layout.tsx    → Layout del paciente: cabecera + tabs.
 |    |         +-- page.tsx      → Resumen del paciente.
 |    |         +-- loading.tsx
 |    |         +-- historia/
 |    |         |    +-- page.tsx
 |    |         +-- atenciones/
 |    |         |    +-- page.tsx
 |    |         +-- seguimientos/
 |    |         |    +-- page.tsx
 |    |         +-- cobros/
 |    |              +-- page.tsx
 |    |
 |    +-- atenciones/
 |    |    +-- page.tsx           → Lista de atenciones.
 |    |    +-- [id]/
 |    |         +-- page.tsx      → Detalle de atencion.
 |    |
 |    +-- seguimientos/
 |    |    +-- page.tsx           → Lista de seguimientos.
 |    |
 |    +-- cobros/
 |    |    +-- page.tsx           → Lista de cobros.
 |    |    +-- [id]/
 |    |         +-- page.tsx      → Detalle de cobro.
 |    |
 |    +-- configuracion/
 |         +-- page.tsx           → Configuracion general.
 |         +-- arancel/
 |              +-- page.tsx      → Tipos de atencion y valores.
 |
 +-- (marketing)/                 → Landing publica (futuro).
      +-- page.tsx
      +-- layout.tsx              → Layout publico. Sin AppShell.
```

### 15.2 Layouts

| Layout | Ubicacion | Contenido | Persistencia |
|---|---|---|---|
| **Root layout** | `app/layout.tsx` | `<html>`, `<body>`, fuentes (`next/font`), `<Toaster />`, `TooltipProvider`. | Toda la aplicacion. |
| **Auth layout** | `(auth)/layout.tsx` | Contenedor centrado. Sin sidebar ni header. Logo de Podoconi. | Rutas de autenticacion. |
| **App layout** | `(app)/layout.tsx` | `SidebarProvider`, `Sidebar`, Header, `<main>`. El AppShell completo. | Toda la aplicacion autenticada. No se re-renderiza al navegar. |
| **Patient layout** | `(app)/pacientes/[id]/layout.tsx` | Cabecera del paciente + tabs de navegacion interna. | Todas las sub-vistas del paciente. |

### 15.3 Server vs Client en el shell

| Componente del shell | Server/Client | Justificacion |
|---|---|---|
| Sidebar (estructura) | Server | Renderiza items de navegacion estaticos. |
| Sidebar toggle state | Client | Requiere `useState` para expandir/colapsar. |
| SidebarTrigger (movil) | Client | Requiere interaccion. |
| Header (estructura) | Server | Breadcrumbs y titulo derivados de la ruta. |
| Header acciones | Client | Botones con `onClick`. |
| Command Palette | Client | Busqueda interactiva con input y resultados dinamicos. |
| Toaster | Client | Notificaciones transitorias con estado. |
| Area principal (page.tsx) | Server (default) | Carga de datos. Client solo donde hay interaccion. |
| Patient layout | Server | Datos del paciente cargados en servidor. |
| Patient tabs | Client | Interaccion de navegacion con estado activo visual. |

### 15.4 Middleware

```
middleware.ts (raiz del proyecto)
```

- Protege todas las rutas `(app)/*` verificando sesion de Supabase Auth.
- Redirige a `/login` si no hay sesion.
- Matcher: `['/(app)(.*)', '/']`.
- No aplica a rutas `(auth)/*` ni `(marketing)/*`.
- Edge-compatible. No usa APIs de Node.js.

---

## 16. Riesgos futuros

### 16.1 Riesgos de escalabilidad UX

| Riesgo | Probabilidad | Impacto | Mitigacion |
|---|---|---|---|
| **Sidebar saturada en Fase 2+** | Alta | Medio | La sidebar soporta hasta 10 items con scroll. Agrupar items relacionados en secciones con `SidebarGroupLabel`. Evaluar mega-menu o sub-navegacion si supera 10 items. |
| **Command Palette lenta con muchos pacientes** | Media | Alto | Busqueda server-side con debounce. Indexar pacientes con busqueda por trigrama en PostgreSQL. Limitar resultados a 5 por grupo. |
| **Cabecera de paciente demasiado alta en movil** | Media | Medio | En movil, la cabecera colapsa a 1 linea (nombre + accion) con las tabs debajo. No superar 120px combinados. |
| **Deep linking complejo con muchos filtros** | Baja | Bajo | Usar `nuqs` o `next-usequerystate` para serializar filtros a URL de forma tipada. Estandarizar nombres de params. |
| **Multi-profesional requiere selector de agenda** | Alta (Fase 2) | Alto | El header contextual debe soportar un selector de profesional cuando la organizacion tiene multiples profesionales. Reservar espacio en el header para este selector. |
| **Modo oscuro rompe contraste** | Media | Medio | Los tokens de color del Design System estan preparados para `.dark`. Pero deben validarse contra WCAG al implementar. No activar modo oscuro sin validacion de contraste. |
| **Formularios largos en Dialog** | Media | Medio | Limitar Dialogs a formularios de 5-8 campos. Formularios complejos (atencion clinica) deben ser paginas completas, no modales. |
| **Notificaciones en tiempo real** | Baja (Fase 3) | Alto | El badge de notificaciones en el header es un placeholder. Supabase Realtime puede alimentarlo. La arquitectura del header lo soporta. |

### 16.2 Decisiones diferidas

| Decision | Motivo del diferimiento | Fase estimada |
|---|---|---|
| Selector de profesional en header | Solo aplica cuando hay multiples profesionales por organizacion. | Fase 2 |
| Notificaciones push | Requiere infraestructura de Realtime y permisos de navegador. | Fase 3 |
| Modo oscuro | Requiere validacion de contraste de toda la paleta. Tokens listos, implementacion no. | Post Fase 1 |
| Favoritos / accesos rapidos | Command Palette cubre el caso de uso por ahora. | Evaluacion post-lanzamiento |
| Vista de semana en agenda | Fase 1 se enfoca en vista de dia. La estructura de layout lo soporta. | Fase 1 (iteracion) |
| Internacionalizacion | v1 es solo espanol (Chile). La estructura de archivos de Next.js soporta i18n futuro. | Post Fase 2 |

---

## Resumen ejecutivo

Este documento define la arquitectura del shell de aplicacion sobre el cual se construira toda la UI de Podoconi. El shell es la capa persistente que rodea toda la experiencia autenticada: sidebar de navegacion, header contextual, sistema de overlays, busqueda global y estructura responsive.

**Decisiones criticas tomadas:**

1. **Navegacion de 7 items.** Inicio, Agenda, Pacientes, Atenciones, Seguimientos, Cobros, Configuracion. Orden por frecuencia de uso diario. Extensible sin re-arquitectura.
2. **Command Palette como busqueda primaria.** `Ctrl+K` para acceso instantaneo a pacientes, acciones y navegacion. Basado en shadcn Command (cmdk). Critico para velocidad operacional con decenas de pacientes diarios.
3. **Navegacion de paciente por rutas anidadas.** Cada sub-vista del paciente tiene URL propia. Layout compartido preserva contexto (cabecera + tabs). Deep linking completo.
4. **Profundidad maxima de 3 niveles.** Area > Detalle > Sub-detalle. Mas profundidad indica problema arquitectonico, no necesidad de mas niveles.
5. **Sidebar persistente en desktop, Drawer en movil.** Componente Sidebar de shadcn/ui. Estado expandido/colapsado persistido en localStorage.
6. **Overlays con reglas estrictas.** Maximo 2 apilados. Focus trap en modales. Escape siempre cierra. Click en overlay cierra todo menos AlertDialog.
7. **Header siempre visible.** Sin auto-hide. El contexto (breadcrumbs, titulo, acciones) justifica los 56px permanentes.
8. **Streaming con Suspense por zona.** Cada bloque del dashboard y cada sub-vista del paciente tiene su boundary. El shell nunca se bloquea esperando datos.

**Riesgos identificados:**

- Sidebar saturada en fases futuras (mitigacion: agrupamiento con SidebarGroupLabel).
- Command Palette lenta con muchos pacientes (mitigacion: busqueda server-side con trigrama).
- Formularios largos en Dialog (mitigacion: limitar a 5-8 campos; formularios complejos como paginas).
- Multi-profesional requiere selector en header (espacio reservado para Fase 2).

**Recomendaciones para implementacion:**

1. Implementar primero el AppShell vacio: sidebar + header + area principal + routing.
2. Agregar Command Palette como segunda implementacion del shell.
3. Implementar el layout de paciente con rutas anidadas antes de cualquier pantalla clinica.
4. Configurar middleware de autenticacion desde el inicio.
5. Cada `page.tsx` nuevo debe incluir su `loading.tsx` correspondiente.
6. Validar navegacion por teclado del shell completo antes de implementar pantallas.

---

**Toda pantalla futura se construye dentro de este shell.**

**Toda desviacion de esta arquitectura requiere justificacion explicita y actualizacion de este documento.**