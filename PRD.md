# Documento de Requerimientos de Producto (PRD)
## Proyecto: Mini ERP para Importadora de Componentes Electrónicos
**Versión:** 1.3 (Auditado y Blindado)  
**Framework Base:** Ruby on Rails 8  
**Moneda Base:** Dólares Americanos (USD)  

---

## 1. Visión General del Proyecto
Este documento define los requerimientos funcionales y no funcionales para el desarrollo de un Mini ERP web a medida. La plataforma está diseñada específicamente para una empresa importadora y comercializadora de componentes electrónicos al por mayor y menor. El sistema tiene como objetivo optimizar y centralizar tres pilares operativos fundamentales: el control de inventario físico, el ciclo de ventas/cotizaciones, y el seguimiento de créditos mediante cuentas por cobrar fraccionadas.

---

## 2. Objetivos del Sistema
* **Centralización Operativa:** Eliminar el uso de hojas de cálculo dispersas para el control de stock y ventas.
* **Flexibilidad Comercial:** Permitir la modificación de precios unitarios en tiempo real durante la atención al cliente para adaptarse a negociaciones minoristas y mayoristas.
* **Control Financiero y Control de Riesgo:** Monitorear la liquidez, evitar quiebres de stock comercial y gestionar deudas mediante alertas, cuotas rígidas y control estricto de clientes.

---

## 3. Especificaciones Funcionales por Módulo

### 3.1. Módulo de Clientes (Maestro Base)
El sistema debe garantizar la integridad de la base de datos de clientes, preparando el terreno para la futura facturación electrónica.

* **RF1.1 - Registro de Datos:** Almacenamiento obligatorio de Razón Social / Nombre completo, N° de Documento (RUC o DNI) y Número de Contacto.
* **RF1.2 - Validación de Unicidad Absoluta:** El sistema impedirá el registro de dos clientes con el mismo RUC o número de documento. A nivel de base de datos se aplicará un índice único (`unique: true`).
* **RF1.3 - Validación Estricta de RUC:** Cuando el tipo de documento del cliente sea un RUC, el sistema validará mediante expresiones regulares (`ActiveModel::Validations`) que contenga exactamente 11 dígitos numéricos y un formato inicial válido antes de permitir el guardado.
* **RF1.4 - Autocompletado Inteligente:** Al crear un documento en la ruta `../new`, el ingreso del RUC disparará una búsqueda asíncrona para autocompletar los campos de datos del cliente de manera automática si ya se encuentra registrado.

### 3.2. Módulo de Inventario (Multi-almacén)
El modelo conceptual soporta una arquitectura multi-almacén para garantizar la escalabilidad futura del negocio. No obstante, inicialmente operará configurando un único almacén principal, ya que la empresa cuenta actualmente con una sola locación física.

* **RF2.1 - Atributos Técnicos del Producto:** * SKU (Único, String)
  * Nombre comercial
  * Marca / Fabricante
  * Almacén (Relación / Asociación)
  * Stock (Integer - Número de unidades disponibles)
  * Precio Unitario Base en USD (Decimal 10,2)
* **RF2.2 - Bloqueo de Stock Negativo (Quiebre de Stock):** El sistema **prohibirá estrictamente** confirmar una transacción de tipo "Venta" si la cantidad solicitada de un componente electrónico supera el stock físico disponible en el almacén. Se mostrará una alerta en la interfaz impidiendo la confirmación y el guardado.
* **RF2.3 - Control de Bajo Stock:** El sistema marcará visualmente con una alerta de criticidad a cualquier producto que cuente con un stock disponible menor a 10 unidades en el almacén principal.

### 3.3. Módulo de Ventas y Ciclo de Vida del Documento
El núcleo transaccional reside en la creación unificada de documentos comerciales en la ruta `../new` de Ruby on Rails 8.

* **RF3.1 - Punto de Acceso Restringido:** El botón "Nuevo Documento" para acceder a la ruta de creación (`../new`) **deberá ubicarse única y exclusivamente dentro de la vista de índice (Index) del Módulo de Ventas**. Se prohíbe estrictamente colocar este botón, enlaces o accesos directos de creación en el menú lateral (Sidebar), en el menú superior (Navbar) o dentro del Dashboard de Administración.
* **RF3.2 - Selección General de Almacén:** Se definirá un único almacén global aplicable a todos los ítems agregados en el documento (por defecto, el almacén principal único).
* **RF3.3 - Modificación de Precios "En Caliente":** El sistema cargará el precio unitario base por defecto de cada componente electrónico seleccionado, pero habilitará un campo de edición manual para cambiarlo inmediatamente en la línea de detalle antes del guardado (facilita descuentos por volumen o negociación directa).
* **RF3.4 - Selector de Tipo de Documento:** Un control tipo radio o toggle definirá si el documento es una **"Cotización"** o una **"Venta"**.
* **RF3.5 - Flujo de Transición (Cotización a Venta):** Desde la vista de detalle de una cotización (`../show`), existirá un botón interactivo llamado "Convertir a Venta" que clonará la estructura completa, validará el stock físico disponible y generará la transacción definitiva de venta.
* **RF3.6 - Flujo de Anulaciones y Nota de Crédito Interna:** Si una "Venta" es anulada por el Administrador, el sistema ejecutará de forma automática y en una sola transacción:
  * La devolución del stock de los componentes electrónicos al almacén de origen.
  * La generación de un documento de **Nota de Crédito Interna** vinculado directamente a la venta original.
  * La actualización del saldo pendiente de la venta y de todas sus cuotas asociadas automáticamente a cero (`0.00 USD`), manteniendo el registro histórico intacto con estado "Anulada".

### 3.4. Módulo de Cuentas por Cobrar (Créditos y Amortizaciones)
Este submódulo es aplicable única y estrictamente a los documentos guardados y confirmados bajo el tipo **Venta** (excluye de forma absoluta a las cotizaciones).

* **RF4.1 - Configuración Dinámica de Cuotas:** Fragmentación opcional del pago final a elección del usuario desde 1 hasta 4 cuotas. Los rangos de vencimiento estrictos seleccionables entre cuotas son de: 7, 10, 15, 30 y 45 días.
* **RF4.2 - Cálculo Automático y Redondeo Centesimal:** El sistema dividirá el importe total neto de la venta de forma equitativa entre el número de cuotas seleccionado. El redondeo numérico se aplicará estrictamente al centésimo por exceso o por defecto según la regla estándar (ej: un valor calculated de `4.328 USD` se aproximará automáticamente a `4.33 USD`).
* **RF4.3 - Edición inline en Caliente:** Los montos precalculados de las cuotas y sus respectivas fechas de vencimiento estimadas se mantendrán completamente editables de forma manual por el usuario en el formulario antes de confirmar el guardado.
* **RF4.4 - Gestión de Amortizaciones:** Registro de abonos parciales. Cada abono disminuirá el saldo pendiente de la cuota correspondiente. El estado de cuenta consolidará las ventas con saldos pendientes de cobro y su histórico detallado de abonos.

### 3.5. Módulo de Configuración General (Ajustes de Empresa)
Este módulo permite parametrizar la identidad de la organización que utiliza el sistema ERP para personalizar la documentación comercial de salida.

* **RF5.1 - Punto de Acceso en Navbar:** El ingreso a este módulo se ubicará de forma fija y global en el menú de navegación principal (Navbar). Este botón de acceso será visible y funcional únicamente para los usuarios con rol de Administrador; para el rol de Vendedor, el acceso estará completamente oculto y restringido mediante middleware/políticas de Rails.
* **RF5.2 - Formulario de Datos de Empresa:** Interfaz exclusiva donde se ingresa de manera obligatoria la Razón Social / Nombre comercial de la empresa y su número de RUC institucional. El campo RUC validará estrictamente la estructura de 11 dígitos numéricos antes de permitir el guardado.
* **RF5.3 - Gestión de Identidad Visual (Logo):** Opción para arrastrar y cargar un archivo de imagen (Formatos admitidos: PNG, JPG) que funcionará como el logo corporativo oficial dentro del sistema, gestionado mediante `ActiveStorage` de Rails 8.
* **RF5.4 - Inyección Dinámica en PDFs:** Al gatillar la acción de descarga o impresión en formato PDF tanto de una **Cotización** como de un **Documento de Venta**, el sistema consumirá en tiempo de ejecución el Logo, Nombre de la Empresa y RUC guardados en este módulo para estructurar estéticamente el encabezado de dicho archivo PDF.

### 3.6. Vista Exclusiva: Dashboard de Administración
Módulo visual de analítica reservado únicamente para el rol de Administrador. Debe desplegar los siguientes componentes:

* **Métricas Operativas del Mes:** Número de ventas totales del mes actual y Valor monetario total de ventas del mes (en USD).
* **Métricas Operativas del Día:** Número de ventas concretadas hoy y Valor monetario total de ventas de hoy (en USD).
* **Métricas de Riesgo y Liquidez:** Monto acumulado de Cuentas por Cobrar (Suma total de facturas/ventas pendientes), Número de facturas vencidas a la fecha y Monto total acumulado de facturas vencidas.
* **Sección de Alertas y Rankings:**
  * **Ranking Top 5 Productos:** Lista del 1 al 5 de los componentes más vendidos, mostrando el número de unidades vendidas en el mes al lado derecho de cada fila.
  * **Alerta de Bajo Stock:** Listado dinámico de los componentes que tengan menos de 10 unidades en el almacén principal.
* **Paneles Gráficos (Visualización Temporal):**
  * **Gráfico 1:** Número de ventas del mes (Eje X: Días del mes / Eje Y: Cantidad de ventas realizadas).
  * **Gráfico 2:** Monto financiero de ventas del mes (Eje X: Días del mes / Eje Y: Total facturado en USD).
* **Restricción Absoluta del Dashboard:** Esta vista es estrictamente analítica y de consulta para el Administrador. No debe contener bajo ningún escenario botones de acción operativa, accesos directos, formularios de creación rápida ni enlaces a rutas de inserción o alteración de datos (como `../new`).

---

## 4. Matriz de Roles y Control de Accesos

| Módulo / Vista | Rol: Administrador | Rol: Vendedor |
| :--- | :--- | :--- |
| **Dashboard de Métricas** | Acceso Total (Lectura/Escritura) | Acceso Denegado (Oculto) |
| **Configuración General (Navbar)** | Acceso Total (Lectura/Escritura) | Acceso Denegado (Oculto) |
| **Gestión de Inventario (Index)** | Acceso Total | Lectura y Alerta de Stock Bajo |
| **Módulo de Ventas (Index)** | Acceso al Listado y botón "Nuevo Documento" | Acceso al Listado y botón "Nuevo Documento" |
| **Cuentas por Cobrar (Index)** | Acceso Total | Registro de Amortizaciones y Lectura |

---

## 5. Requerimientos No Funcionales (NFR)
* **NFR 5.1 - Moneda Estándar:** Todo el backend y persistencia de base de datos registrará y operará los valores financieros únicamente en Dólares Americanos (USD).
* **NFR 5.2 - Integridad Transaccional:** El descuento de inventario y la creación de la venta/cuotas asociadas deben empaquetarse en un bloque transaccional de base de datos (`ActiveRecord::Base.transaction`) para evitar inconsistencias en fallos de red o errores de validación intermedia.
* **NFR 5.3 - Abstracción para Facturación Electrónica:** Las tablas transaccionales de venta incluirán los campos estructurados `billing_status` (enum) y `billing_response_metadata` (jsonb) para soportar la futura fase de integración de API de facturación electrónica sin alterar el esquema base.
