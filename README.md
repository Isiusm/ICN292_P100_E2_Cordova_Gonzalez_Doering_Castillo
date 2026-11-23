# ICN292_P100_E2_Cordova_Gonzalez_Doering_Castillo

# Sistema de Información para la Gestión — Florería Ángeles

Proyecto de Entrega 2: diseño y materialización de un Sistema de Información para la Gestión (SIG) para Florería Ángeles. La solución organiza la información de clientes, direcciones, pedidos y fechas importantes; modela el proceso mediante BPMN; implementa una base de datos relacional en MySQL; y automatiza la generación de recordatorios mediante n8n.

> **Alcance importante:** los registros cargados en la base son datos sintéticos de prueba. La automatización se probó enviando el correo a una cuenta propia del equipo. No se envían mensajes automáticos a clientes ni se afirma que el sistema haya aumentado las ventas.

---

## 1. Problema que aborda el sistema

Florería Ángeles recibe principalmente pedidos personalizados por WhatsApp. Antes de la propuesta, los antecedentes de clientes y pedidos se encontraban dispersos en conversaciones, lo que dificultaba recuperar datos, consultar compras anteriores y mantener un registro de cumpleaños y aniversarios.

El SIG busca centralizar esos antecedentes para que Paulina pueda:

- Identificar a un cliente mediante su teléfono o RUT.
- Consultar sus datos, direcciones e historial de pedidos.
- Registrar y revisar pedidos, productos, pagos y entregas.
- Registrar fechas importantes que el cliente comparta voluntariamente.
- Revisar recordatorios próximos y decidir si corresponde contactar al cliente por WhatsApp.

El contacto comercial continúa siendo una decisión y una acción manual de Paulina.

## 2. Cómo funciona la solución

### 2.1 Proceso general (BPMN TO-BE)

![Modelo BPMN TO-BE de Florería Ángeles](assets/01_bpmn_to_be.png)

El proceso comienza cuando el cliente realiza una solicitud. Paulina revisa si ya existe una ficha y recupera sus antecedentes; si corresponde, registra o actualiza al cliente, sus direcciones y fechas importantes. Luego registra el pedido, sus productos y condiciones. El proceso considera validaciones antes de avanzar: dirección de destino, bloque horario AM/PM y comprobante de pago verificado. Durante la preparación se registra la información correspondiente y, para cerrar la orden, se conserva evidencia de entrega con fecha y hora. Si el cliente rechaza el diseño o desiste, el pedido se cancela registrando el motivo.

### 2.2 Subproceso de fechas importantes

![Subproceso BPMN de gestión de recordatorios](assets/02_subproceso_recordatorios.png)

Este subproceso complementa el flujo principal. El sistema revisa las fechas guardadas, identifica las próximas y genera avisos para Paulina. Ella revisa cada aviso y decide si contacta al cliente por WhatsApp. Después registra el resultado de la gestión. Si el contacto deriva en una compra, se continúa con el registro del pedido en el proceso principal.

### 2.3 Automatización en n8n

![Flujo de automatización de fechas importantes en n8n](assets/03_flujo_n8n.png)

El flujo implementa la revisión periódica del subproceso anterior mediante cinco etapas conectadas:

1. **Revisión diaria:** un nodo *Schedule Trigger* inicia el flujo automáticamente según la programación configurada.
2. **Consulta de clientes:** un nodo MySQL consulta la base de datos del SIG y obtiene los registros de clientes y sus fechas importantes.
3. **Identificación de fechas próximas:** un bloque JavaScript calcula los días restantes y selecciona las fechas que ocurrirán dentro de los próximos siete días.
4. **Generación de recordatorios:** otro bloque prepara un mensaje personalizado con nombre, teléfono, tipo de ocasión, fecha y días restantes.
5. **Notificación por correo:** el nodo de correo envía a Paulina el recordatorio en formato HTML.

**Importante:** n8n automatiza la revisión y el aviso interno. No contacta directamente a los clientes ni envía mensajes por WhatsApp.

### 2.4 Evidencia de prueba del correo

![Correo recibido durante la prueba de la automatización](assets/04_correo_prueba.png)

Se ejecutó el flujo utilizando los datos de prueba cargados en SQL y se comprobó la recepción del correo generado. La captura corresponde a una prueba realizada en una cuenta propia del equipo; no corresponde a un envío realizado a Paulina ni acredita una puesta en producción.

## 3. Modelo de datos (Entidad–Relación)

![Modelo entidad-relación del SIG de Florería Ángeles](assets/05_modelo_er.png)

El modelo fue desarrollado en MySQL Workbench y considera **12 tablas**: siete entidades principales y cinco tablas de catálogo.

**Entidades principales:**

- `cliente`: datos de identificación y contacto, consentimiento para recordatorios y fechas asociadas.
- `direccion`: direcciones de despacho vinculadas a cada cliente.
- `pedido`: información general de cada orden, estado, fechas, destino, pago y entrega.
- `detalle_pedido`: productos, cantidades y precio cobrado en cada línea del pedido.
- `producto`: catálogo de productos y precio vigente.
- `fecha_importante`: fechas y ocasiones compartidas voluntariamente por los clientes.
- `recordatorio`: ocurrencias generadas, fechas de aviso y registro del contacto.

**Tablas de catálogo:** `comuna`, `categoria_producto`, `canal_venta`, `estado_pedido` y `tipo_ocasion`.

### Relaciones relevantes

- Un cliente puede tener varios pedidos, direcciones y fechas importantes (1:N).
- Un pedido puede contener varios productos y un producto puede estar en distintos pedidos (N:M). Esta relación se resuelve mediante `detalle_pedido`, que registra cantidad y precio cobrado.
- Una fecha importante puede generar varias ocurrencias de recordatorio (1:N).
- Un recordatorio puede asociarse a un pedido cuando el contacto termina en compra.

### Normalización a 3FN

El diseño separa los datos de clientes, direcciones, pedidos, productos y catálogos para reducir duplicidad y evitar anomalías de inserción, actualización y eliminación. La relación N:M entre pedidos y productos se resuelve con `detalle_pedido`. El precio cobrado se conserva en el detalle para no alterar el historial si cambia el precio vigente del producto. Los montos y estados derivados se consultan mediante vistas, evitando almacenar valores calculables duplicados.

## 4. Base de datos y consultas SQL

Los scripts SQL se encuentran en la carpeta `db/` del repositorio y deben ejecutarse en este orden:

| Archivo | Función |
|---|---|
| `db/schema.sql` | Crea la base `floreria_angeles`, las 12 tablas, claves, restricciones, índices y vistas. **El script elimina y vuelve a crear la base si ya existe.** |
| `db/seed.sql` | Inserta los datos sintéticos utilizados para probar el SIG. |
| `db/consultas.sql` | Ejecuta consultas de negocio, indicadores y verificaciones. |
| `db/automatizacion_recordatorios.sql` | Script complementario para generar registros de recordatorios. |
| `db/pruebas_restricciones.sql` | Prueba operaciones inválidas que deben ser rechazadas por las restricciones. |

### Requisitos

- MySQL 8.0.16 o superior, o MariaDB 10.4 o superior (por ejemplo, el incluido en XAMPP).
- MySQL Workbench u otro cliente SQL para ejecutar los scripts.
- Para reproducir el flujo automatizado: una instancia de n8n, acceso a la base MySQL y credenciales SMTP configuradas.

### Procedimiento para ejecutar la base

1. Clonar o descargar este repositorio.
2. Iniciar el servicio MySQL desde XAMPP o desde el servicio instalado en el equipo.
3. Abrir MySQL Workbench y conectarse a la instancia local.
4. Abrir `db/schema.sql` y ejecutar el script completo. Esto crea la base `floreria_angeles` y su estructura. **Atención: si ya existe una base con ese nombre, se elimina y se crea nuevamente.**
5. Abrir `db/seed.sql` y ejecutarlo para cargar los datos de prueba.
6. Abrir `db/consultas.sql` y ejecutar las consultas para revisar los resultados.
7. Comparar las salidas con la documentación disponible en `docs/04-sql-consultas.md`.

Las consultas principales responden preguntas operativas como:

- ¿Quién es el cliente y cuál es su dirección de despacho?
- ¿Qué fechas importantes tiene registradas?
- ¿Qué ha comprado y cuánto pagó en cada pedido?
- ¿A quién debe contactar Paulina hoy?
- ¿Qué pedidos deben entregarse durante el día y en qué bloque horario?
- ¿Cuántos pedidos permanecen abiertos y en qué estado están?

### Vistas

- `v_pedido_monto`: calcula el monto de cada pedido a partir de sus líneas y agrega el costo de despacho una sola vez.
- `v_recordatorio_estado`: obtiene la situación del recordatorio a partir de la información de contacto y del pedido asociado.

## 5. Datos de prueba e indicadores

El piloto simulado utiliza datos sintéticos para el período **01-09-2026 al 23-11-2026**. Entre otros registros, contiene 36 clientes, 61 direcciones, 18 productos, 80 pedidos, 46 fechas importantes y 24 recordatorios.

Resultados calculados sobre esos datos de prueba:

| Indicador | Resultado del piloto | Meta propuesta |
|---|---:|---:|
| Fichas de clientes completas | 86,1 % (31 de 36) | ≥ 90 % |
| Cobertura complementaria de fechas importantes | 92,9 % (26 de 28) | — |
| Recordatorios atendidos | 76,2 % (16 de 21) | ≥ 80 % |

Estos valores permiten comprobar que las consultas e indicadores funcionan sobre el conjunto de prueba. **No representan resultados observados en la operación real de Florería Ángeles.** No se dispone de una línea base real ni de antecedentes para cuantificar ventas perdidas o atribuir un aumento de ventas al SIG.

## 6. Reglas y controles del proceso

La base de datos incorpora restricciones para respaldar controles definidos en el proceso:

- El teléfono y el RUT del cliente se mantienen únicos.
- Los recordatorios requieren consentimiento registrado.
- El pedido debe utilizar una dirección perteneciente al mismo cliente.
- El bloque horario AM/PM debe estar definido.
- No se permite avanzar con la preparación si el pago no está verificado.
- Para cerrar un pedido se requiere evidencia de entrega con fecha y hora.
- Las cancelaciones deben registrar su motivo.
- Se evita duplicar recordatorios para una misma ocurrencia.
- Cantidades y precios de las líneas de pedido deben ser positivos.

El archivo `db/pruebas_restricciones.sql` contiene pruebas para verificar que la base rechace operaciones que incumplen estas reglas.

## 7. Estructura documental del repositorio

La documentación del proyecto se organiza de la siguiente manera:

```text
.
├── README.md
├── db/
│   ├── schema.sql
│   ├── seed.sql
│   ├── consultas.sql
│   ├── automatizacion_recordatorios.sql
│   └── pruebas_restricciones.sql
├── docs/
│   ├── 00-caso-pyme.md
│   ├── 01-requerimientos.md
│   ├── 02-bpmn.md
│   ├── 03-modelo-datos.md
│   ├── 04-sql-consultas.md
│   ├── 05-automatizacion-n8n.md
│   └── DECLARACION_IA.md
├── informe/
├── presentacion/
├── assets/
│   ├── 01_bpmn_to_be.png
│   ├── 02_subproceso_recordatorios.png
│   ├── 03_flujo_n8n.png
│   ├── 04_correo_prueba.png
│   └── 05_modelo_er.png
└── CHANGELOG.md
```

Los nombres y contenidos concretos de las carpetas deben coincidir con los archivos efectivamente incluidos en el repositorio al publicarlo.

## 8. Limitaciones y siguientes pasos

- Configurar la conexión de n8n con las credenciales y destinatario autorizados para el uso real.
- Confirmar con Paulina el procedimiento de revisión y registro del resultado de cada contacto.
- Mantener protegidos los datos personales y registrar fechas importantes solo cuando exista consentimiento.
- Evaluar los indicadores en períodos reales comparables antes de concluir si hubo mejoras operativas o comerciales.

---

## Información académica

**Universidad:** Universidad Técnica Federico Santa María  
**Asignatura:** ICN-292 — Sistemas de Información para la Gestión  
**Entrega:** Entrega 2 — Solución SIG final  
**Semestre:** Segundo semestre 2026  
**Paralelo:** 100  
**Caso:** Florería Ángeles

