# ICN292_P100_E2_Cordova_Gonzalez_Doering_Castillo
# 🌸 Sistema de Información para la Gestión – Florería Ángeles

**Entrega 2 | Proyecto SIG | Universidad Mayor**

## 1. Descripción del proyecto

Este proyecto consiste en el diseño y desarrollo de un Sistema de Información para la Gestión (SIG) aplicado a **Florería Ángeles**, con el propósito de mejorar la administración de clientes, pedidos, fechas importantes y seguimiento comercial.

La solución integra una base de datos relacional en MySQL, consultas SQL, un modelo Entidad-Relación normalizado y un flujo de automatización desarrollado en n8n.

El sistema busca facilitar la gestión de la información, reducir tareas manuales y permitir una atención más oportuna y organizada de los clientes.

## 2. Objetivos del proyecto

- Centralizar la información de clientes, productos y pedidos.
- Diseñar una base de datos relacional normalizada hasta Tercera Forma Normal (3FN).
- Mejorar la trazabilidad de los pedidos y sus estados.
- Gestionar fechas importantes de los clientes, como cumpleaños y aniversarios.
- Automatizar la identificación y notificación de fechas próximas.
- Apoyar la toma de decisiones mediante consultas SQL e indicadores de gestión.

## 3. Tecnologías utilizadas

| Tecnología | Aplicación |
|---|---|
| MySQL 8.0 | Gestión de la base de datos relacional. |
| MySQL Workbench | Diseño del modelo Entidad-Relación y administración de la base de datos. |
| n8n | Automatización del proceso de recordatorios. |
| JavaScript | Procesamiento y comparación de fechas dentro de n8n. |
| BPMN / Bizagi | Modelamiento de procesos AS-IS y TO-BE. |
| GitHub | Control de versiones y documentación del proyecto. |
| LaTeX | Elaboración del informe académico. |

## 4. Arquitectura y componentes del sistema

### 4.1. Base de datos relacional

Se desarrolló una base de datos denominada `floreria_angeles`, estructurada mediante entidades relacionadas que permiten organizar la información y evitar redundancias.

Entre sus principales tablas se encuentran:

- `cliente`: información y datos de contacto de los clientes.
- `producto`: catálogo de productos disponibles.
- `categoria_producto`: clasificación de productos.
- `pedido`: información general de cada pedido.
- `detalle_pedido`: productos, cantidades y precios asociados a cada pedido.
- `canal_venta`: canales mediante los cuales se reciben los pedidos.
- `tipo_ocasion`: clasificación de fechas y ocasiones importantes.
- `fecha_importante`: registro de cumpleaños, aniversarios y otras fechas relevantes.
- `direccion`: direcciones asociadas a los clientes.
- `comuna`: información territorial.
- `estado_pedido`: estados y seguimiento de los pedidos.
- `recordatorio`: registro de recordatorios y seguimiento de contacto.

El modelo contempla claves primarias (PK), claves foráneas (FK) y relaciones entre entidades, incluyendo la resolución de relaciones muchos a muchos mediante tablas intermedias.

### 4.2. Automatización mediante n8n

Se implementó un flujo automatizado para identificar fechas importantes próximas y generar notificaciones por correo electrónico.

El proceso se compone de cinco etapas:

1. **Revisión diaria de fechas:** un activador programado inicia automáticamente el flujo.
2. **Consulta de clientes:** se recuperan los registros y las fechas importantes desde MySQL.
3. **Identificación de fechas próximas:** mediante JavaScript se calculan los días restantes y se seleccionan las fechas dentro de los próximos siete días.
4. **Generación de recordatorios:** se construyen mensajes personalizados con los datos del cliente y la fecha correspondiente.
5. **Notificación por correo electrónico:** se envía un mensaje automático con la información necesaria para anticipar el contacto comercial.

La implementación fue probada mediante registros de prueba y el envío de un correo electrónico de demostración.

## 5. Modelamiento de procesos

Se desarrolló el modelamiento de procesos mediante BPMN, considerando:

- **Modelo AS-IS:** representación del funcionamiento inicial del proceso.
- **Modelo TO-BE:** propuesta de mejora mediante la incorporación del sistema de información y automatización.
- **Proceso de recordatorio:** representación específica de la gestión de fechas importantes y contacto con clientes.

El modelo TO-BE busca mejorar la organización, trazabilidad y oportunidad de las actividades comerciales.

## 6. Consultas SQL e indicadores

Se incorporaron consultas SQL y vistas para facilitar la recuperación y análisis de información.

Entre sus aplicaciones se encuentran:

- Consulta de información de clientes.
- Seguimiento de pedidos y estados.
- Cálculo de montos asociados a pedidos.
- Identificación de fechas importantes.
- Organización de recordatorios y seguimiento comercial.

Estas herramientas permiten transformar los registros almacenados en información útil para la gestión de la florería.

## 7. Estructura del proyecto

El repositorio contempla los siguientes componentes:

```text
Floreria-Angeles-SIG/
│
├── db/
│   ├── schema.sql
│   └── seed.sql
│
├── imagenes/
│   ├── DiagramaERR.png
│   ├── ModeloAS-IS.PYME.png
│   ├── ModeloTO-BE.PYME.png
│   ├── Procesorecordatorio.png
│   ├── Flujon8n_E2.png
│   └── FotoCorreo.png
│
├── automatizacion/
│   └── [Exportación del flujo n8n]
│
├── informe/
│   └── [Informe del proyecto]
│
└── README.md
```

*Nota: esta es una estructura de referencia. Los archivos deben organizarse en las carpetas correspondientes antes de subirlos al repositorio.*

## 8. Instalación y ejecución

### Requisitos previos

- MySQL Server 8.0 o superior.
- MySQL Workbench.
- Cuenta o instancia de n8n.
- Credenciales de conexión a MySQL.
- Configuración de correo electrónico mediante SMTP.

### Paso 1. Crear la base de datos

Abrir MySQL Workbench, conectarse a una instancia MySQL 8 y ejecutar el archivo:

```sql
SOURCE db/schema.sql;
```

Este archivo contiene la estructura de la base de datos, sus tablas, relaciones, restricciones y vistas.

### Paso 2. Cargar los datos

Ejecutar el archivo:

```sql
SOURCE db/seed.sql;
```

Este archivo permite cargar los registros necesarios para realizar las pruebas del sistema.

### Paso 3. Configurar n8n

1. Importar el flujo de trabajo exportado desde n8n.
2. Configurar las credenciales de conexión MySQL.
3. Configurar las credenciales SMTP.
4. Verificar las direcciones de correo de origen y destino.
5. Ejecutar el flujo para comprobar su funcionamiento.
6. Activar la programación automática una vez validada la configuración.

## 9. Pruebas y consideraciones

La implementación fue validada mediante registros de prueba, ejecución de consultas SQL y pruebas del flujo de automatización.

Se verificó la identificación de fechas próximas, el cálculo de días restantes, la generación de mensajes personalizados y el envío de notificaciones por correo electrónico.

**Importante:** los datos utilizados para las pruebas son datos de demostración y no representan necesariamente operaciones comerciales reales. Los resultados permiten comprobar el funcionamiento técnico de la solución, pero no constituyen evidencia de aumentos efectivos en ventas o reducciones cuantificadas de pérdidas.

Para una implementación productiva se requiere validar los datos con la empresa, configurar sus credenciales autorizadas y realizar pruebas en su entorno operativo.

## 10. Equipo de trabajo

Proyecto desarrollado por estudiantes de Ingeniería en Sistemas de Información para la Gestión.

**Universidad Mayor – Campus Vitacura**  
**Segundo semestre 2026**

---

*Proyecto académico desarrollado con fines de diseño, implementación y demostración de un Sistema de Información para la Gestión aplicado a Florería Ángeles.*
