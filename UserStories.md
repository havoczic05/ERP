# Documento de Historias de Usuario (User Stories)
## Proyecto: Mini ERP para Importadora de Componentes Electrónicos
**Versión:** 1.3 (Sincronizado con PRD v1.3)  
**Framework Base:** Ruby on Rails 8 (Hotwire / Turbo)  
**Moneda Base:** Dólares Americanos (USD)  

---

## 🛠️ Épica 1: Maestro de Clientes e Inventario

### US1.1 - Validaciones Críticas y Registro Único de Clientes
**Como** Vendedor o Administrador,  
**Quiero** registrar un nuevo cliente con validaciones fiscales y de unicidad estrictas,  
**Para** garantizar datos limpios de cara a la futura facturación electrónica y evitar registros duplicados.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Registro exitoso de un cliente con RUC válido**
  * **Dado** que estoy en el formulario de creación de clientes,
  * **Cuando** ingreso un número de RUC de 11 dígitos numéricos que no existe en el sistema,
  * **Y** completo la Razón Social y el teléfono de contacto,
  * **Entonces** el sistema me permite guardar el registro exitosamente y aplica un índice único en la base de datos.
* **Escenario: Intento de registro de RUC/Documento duplicado**
  * **Dado** que el RUC "20123456789" ya se encuentra asignado a un cliente existente,
  * **Cuando** intento guardar un nuevo cliente con ese mismo número de RUC,
  * **Entonces** el sistema bloquea el guardado por validación de modelo (`validates :document_number, uniqueness: true`) y muestra un mensaje de error: "El número de documento ya se encuentra registrado".
* **Escenario: Validación por expresiones regulares del formato de RUC**
  * **Dado** que elijo el tipo de documento "RUC",
  * **Cuando** ingreso un valor que contiene letras, caracteres especiales o que no tiene exactamente 11 dígitos,
  * **Entonces** el sistema impide el envío del formulario y resalta el campo con la alerta de formato incorrecto.

### US1.2 - Consulta de Inventario y Alerta de Stock Bajo
**Como** Vendedor o Administrador,  
**Quiero** visualizar la lista de componentes electrónicos con sus marcas y stock por almacén único,  
**Para** conocer la disponibilidad inmediata y detectar productos en estado crítico de reposición.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Visualización de indicador visual de Stock Bajo**
  * **Dado** que estoy en la vista de índice (Index) de Inventario,
  * **Cuando** un componente electrónico tiene una cantidad física igual o menor a 9 unidades en el almacén,
  * **Entonces** el sistema renderiza el producto mostrando SKU, nombre, marca y precio sugerido,
  * **Y** añade una etiqueta visual de alerta crítica que indica "Stock Bajo (< 10 unidades)".

---

## 💼 Épica 2: Ciclo de Ventas y Cotizaciones

### US2.1 - Creación de Documento Reactivo con Punto de Acceso Restringido
**Como** Vendedor o Administrador,  
**Quiero** iniciar la creación de un documento comercial interactivo mediante un botón ubicado únicamente en el índice de ventas,  
**Para** formular cotizaciones o ventas con edición de precios en tiempo real sin recargas de página y cumpliendo la arquitectura estricta del sistema.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Verificación de Punto de Acceso Exclusivo para "Nuevo Documento"**
  * **Dado** que navego por el sistema ERP en vistas como el Dashboard, Navbar o Sidebar,
  * **Entonces** confirmo que no existe ningún botón, enlace rápido o formulario flotante para crear un documento nuevo.
  * **Cuando** ingreso específicamente a la vista de índice del Módulo de Ventas (`/sales`),
  * **Entonces** visualizo de forma exclusiva el botón "Nuevo Documento" que redirige a la ruta `../new`.
* **Escenario: Autocompletado asíncrono de Clientes en el formulario**
  * **Dado** que estoy en la pantalla de creación `../new`,
  * **Cuando** digito un RUC existente en el campo de búsqueda de cliente,
  * **Entonces** un Turbo Frame realiza una petición asíncrona y autocompleta los campos de Razón Social y contacto de inmediato sin refrescar el resto del formulario.
* **Escenario: Modificación de precios "En Caliente"**
  * **Dado** que selecciono un componente y este se añade a la lista de detalles con su precio unitario base por defecto,
  * **Cuando** modifico manualmente el valor dentro del input de precio unitario,
  * **Entonces** Turbo Streams recalcula instantáneamente el subtotal de esa fila y el monto total neto general reflejado al final del documento.

### US2.2 - Bloqueo de Venta por Quiebre de Stock Físico
**Como** Sistema ERP,  
**Quiero** validar el stock del almacén antes de procesar un documento,  
**Para** prohibir el guardado de ventas que generen saldos negativos y permitir cotizaciones sin restricciones físicas.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Intento de confirmar una Venta que supera el stock disponible**
  * **Dado** que el componente "Transistor BC547" tiene un stock de 20 unidades,
  * **Cuando** ingreso una cantidad de 25 unidades y el selector de documento está marcado como "Venta",
  * **Entonces** el sistema activa una alerta visual en caliente indicando "Stock insuficiente para esta venta",
  * **Y** bloquea el botón de confirmación, impidiendo que la transacción se registre en la base de datos.
* **Escenario: Registro permisivo para una Cotización**
  * **Dado** que el componente tiene un stock de 20 unidades,
  * **Cuando** ingreso una cantidad de 100 unidades pero el selector de documento está marcado como "Cotización",
  * **Entonces** el sistema no aplica ningún bloqueo y permite guardar el registro con normalidad (ya que no afecta el inventario físico).

### US2.3 - Transición Eficiente de Cotización a Venta
**Como** Vendedor o Administrador,  
**Quiero** procesar una cotización aprobada desde su propia vista de detalle,  
**Para** transformarla en una venta firme y descontar el stock con un solo clic.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Conversión exitosa desde el Show de la Cotización**
  * **Dado** que estoy visualizando el detalle de una cotización guardada en la ruta `../show`,
  * **Cuando** hago clic en el botón "Convertir a Venta",
  * **Entonces** el sistema evalúa en tiempo de ejecución si el almacén cuenta con el stock físico para cubrir todos los ítems.
  * **Si tiene stock:** Clona toda la estructura de datos, genera la Venta, realiza el descuento de inventario correspondiente y actualiza el estado de la cotización original.

---

## 💳 Épica 3: Cuentas por Cobrar y Amortizaciones

### US3.1 - Fraccionamiento Automático de Cuotas y Redondeo Centesimal Estándar
**Como** Vendedor o Administrador,  
**Quiero** dividir el monto de una venta a crédito en cuotas rígidas con intervalos predefinidos de días,  
**Para** ofrecer financiamiento exacto controlando las fechas estimadas de cobro con opción de edición manual antes del guardado.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Generación de cuotas equitativas con redondeo matemático centesimal**
  * **Dado** que una venta finaliza con un importe neto total de 100.00 USD y elijo estructurarla en "3 cuotas" cada "30 días",
  * **Cuando** el sistema procesa la división matemática (100.00 / 3 = 33.33333...),
  * **Entonces** Turbo Streams inyecta inline 3 filas de cuotas aplicando redondeo estándar al centésimo (ej. Cuota 1: 33.33 USD, Cuota 2: 33.33 USD, Cuota 3: 33.34 USD para cuadrar el total),
  * **Y** proyecta las fechas de vencimiento sumando exactamente 30, 60 y 90 días calendario a la fecha actual.
* **Escenario: Edición en caliente de montos y fechas proyectadas**
  * **Dado** que las cuotas precalculadas se muestran en pantalla,
  * **Cuando** modifico manualmente los montos de los inputs o altero los selectores de fecha de vencimiento,
  * **Entonces** el sistema valida que la sumatoria siga siendo exactamente igual a 100.00 USD y permite proceder con el guardado personalizado.

### US3.2 - Amortizaciones mediante Ventana Emergente (Modal Asíncrono)
**Como** Vendedor o Administrador,  
**Quiero** capturar abonos parciales a través de un modal emergente desde el índice de cuentas por cobrar,  
**Para** reducir los saldos pendientes de las cuotas sin perder la posición ni recargar el listado actual.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Registro de abono parcial y actualización reactiva**
  * **Dado** que me encuentro revisando el listado de Cuentas por Cobrar de un cliente,
  * **Cuando** presiono el botón "Registrar Pago" sobre una cuota específica con saldo de 80.00 USD,
  * **Entonces** se despliega una ventana modal asíncrona vía Turbo Frames.
  * **Cuando** digito un abono de 30.00 USD y guardo el formulario del modal,
  * **Entonces** el modal se cierra automáticamente, el saldo remanente de la cuota se updates a 50.00 USD en la base de datos, y la fila de la interfaz se refresca en segundo plano mediante Turbo Streams.

### US3.3 - Circuito Transaccional de Anulación y Nota de Crédito Interna
**Como** Administrador,  
**Quiero** anular una venta confirmada defectuosa o cancelada por el cliente,  
**Para** reintegrar el stock al almacén y extinguir la deuda asociada en un solo bloque seguro de operaciones.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Anulación atómica y segura de una Venta**
  * **Dado** que estoy visualizando una Venta confirmada que generó deudas pendientes por 500.00 USD,
  * **Cuando** hago clic en "Anular Venta" y confirmo la acción,
  * **Entonces** el backend ejecuta un bloque encapsulado en `ActiveRecord::Base.transaction`:
    * **1.** Incrementa el stock del inventario devolviendo exactamente las unidades ligadas a la venta.
    * **2.** Emite y registra un documento de **Nota de Crédito Interna** enlazado a la venta original.
    * **3.** Cambia el estado de la venta a "Anulada" y setea automáticamente el saldo pendiente de todas sus cuotas a 0.00 USD.

---

## ⚙️ Épica 4: Configuración e Identidad Corporativa

### US4.1 - Gestión de Datos Fiscales y Logo Restringido desde el Navbar
**Como** Administrador,  
**Quiero** disponer de un acceso de configuración fijo en el Navbar superior,  
**Para** administrar la Razón Social, el RUC y el logo corporativo de la empresa bajo políticas de acceso restrictivas.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Ocultamiento y denegación de acceso para Vendedores**
  * **Dado** que inicié sesión en la plataforma con el rol de "Vendedor",
  * **Entonces** el botón de configuración (engranaje) en el Navbar superior se encuentra completamente oculto e inaccesible.
  * **Cuando** intento digitar directamente en la barra de direcciones del navegador la URL del módulo de configuración,
  * **Entonces** las políticas de Rails interceptan la petición, deniegan el acceso y me redirigen con un mensaje de "Acceso Restringido".
* **Escenario: Persistencia exitosa de identidad corporativa por el Administrador**
  * **Dado** que navego con el rol de "Administrador" y presiono el botón de configuración en el Navbar,
  * **Cuando** cargo una imagen en formato PNG/JPG, escribo un RUC corporativo válido de 11 dígitos numéricos y la Razón Social,
  * **Entonces** el sistema guarda el registro utilizando `ActiveStorage` para procesar el archivo multimedia de forma limpia.

### US4.2 - Inyección Parametrizada en Exportaciones PDF
**Como** Vendedor o Administrador,  
**Quiero** exportar cualquier cotización o documento de venta a un archivo PDF descargable,  
**Para** remitirlo formalmente al cliente imprimiendo los datos de identidad corporativa en la cabecera de forma dinámica.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Generación de documento PDF con cabecera dinámica**
  * **Dado** que la empresa guardó previamente en la configuración su Razón Social "Importadora Electrónica S.A.C." y su RUC "20987654321",
  * **Cuando** visualizo un documento comercial y presiono el botón "Descargar PDF",
  * **Entonces** el motor de renderizado PDF extrae en tiempo de ejecución los datos fiscales y el logo del módulo de ajustes, inyectándolos simétricamente en el encabezado superior del archivo generado.

---

## 📊 Épica 5: Dashboard Analítico (Exclusivo Administrador)

### US5.1 - Visualización de KPIs y Alertas bajo Restricción Absoluta de Datos
**Como** Administrador,  
**Quiero** acceder a un panel central de analítica consolidada al iniciar sesión,  
**Para** evaluar el rendimiento mensual, diario y el riesgo financiero del negocio mediante una vista de solo lectura libre de acciones operativas.

#### Criterios de Aceptación (Gherkin):
* **Escenario: Auditoría y Verificación de Restricción Absoluta Operativa**
  * **Dado** que estoy visualizando el Dashboard principal de Administración,
  * **Entonces** verifico detalladamente que la interfaz es de **solo lectura**. No existen inputs, botones de creación rápida, formularios modales ni enlaces que apunten a flujos de inserción o alteración de datos (como `../new`).
* **Escenario: Carga correcta del ecosistema de métricas integradas**
  * **Dado** que el Dashboard se renderiza, la interfaz distribuye ordenadamente los siguientes componentes en rejilla:
    * **Métricas del Mes:** Conteo de ventas y valor facturado acumulado en USD en el mes vigente.
    * **Métricas del Día:** Conteo de ventas y valor facturado acumulado en USD en el día actual.
    * **Riesgo y Liquidez:** Suma agregada de todas las deudas vigentes por cobrar, número de cuotas vencidas a la fecha y monto financiero acumulado vencido.
    * **Rankings:** Una lista del 1 al 5 con los productos más vendidos del mes, indicando sus unidades vendidas a la derecha.
    * **Alertas de Inventario:** Panel dinámico que extrae los componentes electrónicos con stock inferior a 10 unidades.
    * **Gráficos Temporales:** Dos bloques visuales interactivos que grafican el comportamiento diario del mes actual (uno para volumen de transacciones y otro para ingresos brutos en USD).
