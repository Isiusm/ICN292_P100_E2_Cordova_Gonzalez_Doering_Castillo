-- =====================================================================
--  Florería Ángeles · SIG de clientes, pedidos y fechas importantes
--  Archivo : db/schema.sql
--  Motor   : MySQL 8.0+ o MariaDB 10.4+ (el "MySQL" que trae XAMPP)
--  Qué hace: crea la base de datos, sus tablas (PK, FK, UNIQUE, CHECK),
--            índices y la vista que calcula el monto de cada pedido.
--  Orden   : 1) schema.sql   2) seed.sql   3) consultas.sql
--  OJO     : elimina y vuelve a crear la base floreria_angeles.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP DATABASE IF EXISTS floreria_angeles;
CREATE DATABASE floreria_angeles
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE floreria_angeles;

-- ---------------------------------------------------------------------
-- 1. CATÁLOGOS
--    Valores que se repiten en muchas filas. Se guardan una sola vez y
--    se referencian por FK (evita anomalías de actualización).
-- ---------------------------------------------------------------------

-- Comunas de las direcciones de despacho.
CREATE TABLE comuna (
  id_comuna  INT          NOT NULL AUTO_INCREMENT,
  nombre     VARCHAR(60)  NOT NULL,
  PRIMARY KEY (id_comuna),
  CONSTRAINT uq_comuna_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- Canal por el que llega el pedido (BPMN: "llega un mensaje/llamada").
CREATE TABLE canal_venta (
  id_canal  INT          NOT NULL AUTO_INCREMENT,
  nombre    VARCHAR(40)  NOT NULL,
  PRIMARY KEY (id_canal),
  CONSTRAINT uq_canal_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- Categoría de producto (ramos, arreglos, plantas, condolencias, etc.).
CREATE TABLE categoria_producto (
  id_categoria  INT          NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(40)  NOT NULL,
  PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- Ocasión de un pedido o de una fecha importante.
-- es_anual = 1: la ocasión se repite cada año para una persona
-- (cumpleaños, aniversario) y por eso puede registrarse como fecha importante.
CREATE TABLE tipo_ocasion (
  id_ocasion  INT          NOT NULL AUTO_INCREMENT,
  nombre      VARCHAR(40)  NOT NULL,
  es_anual    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (id_ocasion),
  CONSTRAINT uq_ocasion_nombre   UNIQUE (nombre),
  CONSTRAINT chk_ocasion_es_anual CHECK (es_anual IN (0, 1))
) ENGINE=InnoDB;

-- Estados del pedido definidos en el BPMN to-be.
-- La PK es un código fijo porque las reglas CHECK de "pedido" lo usan.
CREATE TABLE estado_pedido (
  cod_estado  VARCHAR(20)  NOT NULL,
  nombre      VARCHAR(40)  NOT NULL,
  orden       TINYINT      NOT NULL,  -- orden de avance en el proceso
  es_final    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (cod_estado),
  CONSTRAINT uq_estado_nombre    UNIQUE (nombre),
  CONSTRAINT uq_estado_orden     UNIQUE (orden),
  CONSTRAINT chk_estado_es_final CHECK (es_final IN (0, 1))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. CLIENTES Y DIRECCIONES  (RF01, RF02, RF03)
-- ---------------------------------------------------------------------

CREATE TABLE cliente (
  id_cliente            INT           NOT NULL AUTO_INCREMENT,
  rut                   VARCHAR(10)   NULL,      -- opcional; formato 12345678-9 (sin puntos)
  nombre                VARCHAR(60)   NOT NULL,
  apellido              VARCHAR(60)   NULL,      -- por WhatsApp a veces solo se conoce el nombre
  telefono              VARCHAR(15)   NOT NULL,  -- número de WhatsApp, formato +569XXXXXXXX
  email                 VARCHAR(100)  NULL,
  acepta_recordatorios  TINYINT(1)    NOT NULL DEFAULT 0,  -- consentimiento (Ley 21.719)
  fecha_consentimiento  DATETIME      NULL,
  fecha_registro        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cliente),
  CONSTRAINT uq_cliente_telefono UNIQUE (telefono),   -- RF03: identificar por teléfono
  CONSTRAINT uq_cliente_rut      UNIQUE (rut),        -- RF03: o por RUT
  CONSTRAINT uq_cliente_email    UNIQUE (email),
  CONSTRAINT chk_cliente_telefono CHECK (telefono LIKE '+%' AND CHAR_LENGTH(telefono) BETWEEN 9 AND 15),
  CONSTRAINT chk_cliente_rut      CHECK (rut IS NULL OR (rut LIKE '%_-_' AND rut NOT LIKE '%.%')),
  CONSTRAINT chk_cliente_email    CHECK (email IS NULL OR email LIKE '%_@_%._%'),
  -- Solo se puede marcar que acepta recordatorios si se registró cuándo lo autorizó.
  CONSTRAINT chk_cliente_consentimiento CHECK (
    acepta_recordatorios IN (0, 1)
    AND (acepta_recordatorios = 0 OR fecha_consentimiento IS NOT NULL)
  )
) ENGINE=InnoDB;

-- Libreta de direcciones de despacho del cliente: su casa y también destinos
-- de terceros a los que suele enviar (casa de la madre, clínica, cementerio).
-- es_habitual vale 1 en la dirección habitual y NULL en las demás: con el
-- UNIQUE (id_cliente, es_habitual) cada cliente tiene como máximo UNA
-- dirección habitual (los NULL no chocan entre sí en un índice UNIQUE).
CREATE TABLE direccion (
  id_direccion  INT           NOT NULL AUTO_INCREMENT,
  id_cliente    INT           NOT NULL,
  etiqueta      VARCHAR(40)   NOT NULL,  -- 'Casa', 'Casa de su madre', 'Clínica (visitas)'...
  calle         VARCHAR(100)  NOT NULL,
  numero        VARCHAR(10)   NOT NULL,
  depto         VARCHAR(20)   NULL,      -- 'Depto 1203', 'Piso 8', etc.
  id_comuna     INT           NOT NULL,
  referencia    VARCHAR(150)  NULL,
  es_habitual   TINYINT(1)    NULL DEFAULT NULL,
  PRIMARY KEY (id_direccion),
  -- Par (id_direccion, id_cliente): lo usa la FK compuesta de pedido para
  -- impedir que un pedido use una dirección de otro cliente (RNF05).
  CONSTRAINT uq_direccion_cliente  UNIQUE (id_direccion, id_cliente),
  CONSTRAINT uq_direccion_habitual UNIQUE (id_cliente, es_habitual),
  CONSTRAINT chk_direccion_habitual CHECK (es_habitual IS NULL OR es_habitual = 1),
  CONSTRAINT fk_direccion_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
  CONSTRAINT fk_direccion_comuna  FOREIGN KEY (id_comuna)  REFERENCES comuna (id_comuna)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. PRODUCTOS
-- ---------------------------------------------------------------------

CREATE TABLE producto (
  id_producto     INT          NOT NULL AUTO_INCREMENT,
  id_categoria    INT          NOT NULL,
  nombre          VARCHAR(80)  NOT NULL,
  precio_vigente  INT          NOT NULL,  -- CLP, IVA incluido; precio de lista actual
  activo          TINYINT(1)   NOT NULL DEFAULT 1,  -- 0 = ya no se ofrece (se conserva el historial)
  PRIMARY KEY (id_producto),
  CONSTRAINT uq_producto_nombre  UNIQUE (nombre),
  CONSTRAINT chk_producto_precio CHECK (precio_vigente > 0),
  CONSTRAINT chk_producto_activo CHECK (activo IN (0, 1)),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria_producto (id_categoria)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. PEDIDOS  (RF05, RF06, RF07, RF08)
--    Las reglas CHECK implementan los controles del BPMN to-be:
--    dirección y bloque AM/PM obligatorios, no avanzar sin pago verificado,
--    foto del arreglo antes de "Listo para despacho", y foto + timestamp
--    de entrega para cerrar la orden.
-- ---------------------------------------------------------------------

CREATE TABLE pedido (
  id_pedido           INT           NOT NULL AUTO_INCREMENT,
  id_cliente          INT           NOT NULL,
  id_canal            INT           NOT NULL,
  id_ocasion          INT           NOT NULL,
  cod_estado          VARCHAR(20)   NOT NULL DEFAULT 'PENDIENTE_PAGO',
  fecha_hora_ingreso  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_entrega       DATE          NOT NULL,  -- fecha comprometida con el cliente
  bloque_horario      CHAR(2)       NOT NULL,  -- 'AM' (hasta 14:00) o 'PM' (14:00 a 20:00)
  id_direccion        INT           NOT NULL,  -- destino del despacho
  destinatario        VARCHAR(80)   NOT NULL,  -- quién recibe (puede ser un tercero)
  mensaje_tarjeta     VARCHAR(255)  NULL,
  costo_despacho      INT           NOT NULL DEFAULT 0,  -- CLP cobrado por el despacho
  medio_pago          VARCHAR(13)   NULL,      -- 'TRANSFERENCIA', 'EFECTIVO' o 'TARJETA'
  comprobante_pago    VARCHAR(255)  NULL,      -- ruta de la imagen del comprobante
  fecha_hora_pago     DATETIME      NULL,      -- cuándo Paulina verificó el pago
  foto_arreglo        VARCHAR(255)  NULL,      -- ruta de la foto del arreglo terminado
  fecha_hora_entrega  DATETIME      NULL,      -- timestamp real de entrega (cierre)
  foto_entrega        VARCHAR(255)  NULL,      -- ruta de la foto de evidencia de entrega
  motivo_cancelacion  VARCHAR(150)  NULL,
  PRIMARY KEY (id_pedido),
  CONSTRAINT fk_pedido_cliente   FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
  CONSTRAINT fk_pedido_canal     FOREIGN KEY (id_canal)   REFERENCES canal_venta (id_canal),
  CONSTRAINT fk_pedido_ocasion   FOREIGN KEY (id_ocasion) REFERENCES tipo_ocasion (id_ocasion),
  CONSTRAINT fk_pedido_estado    FOREIGN KEY (cod_estado) REFERENCES estado_pedido (cod_estado),
  -- FK compuesta: la dirección debe pertenecer al MISMO cliente del pedido.
  CONSTRAINT fk_pedido_direccion FOREIGN KEY (id_direccion, id_cliente)
                                 REFERENCES direccion (id_direccion, id_cliente),
  CONSTRAINT chk_pedido_bloque CHECK (bloque_horario IN ('AM', 'PM')),
  CONSTRAINT chk_pedido_costo  CHECK (costo_despacho >= 0),
  CONSTRAINT chk_pedido_fechas CHECK (fecha_entrega >= DATE(fecha_hora_ingreso)),
  CONSTRAINT chk_pedido_medio_pago CHECK (
    medio_pago IS NULL OR medio_pago IN ('TRANSFERENCIA', 'EFECTIVO', 'TARJETA')
  ),
  -- Un pago verificado tiene medio de pago, y si es transferencia, comprobante.
  CONSTRAINT chk_pedido_pago CHECK (
    (fecha_hora_pago IS NULL AND medio_pago IS NULL AND comprobante_pago IS NULL)
    OR (fecha_hora_pago IS NOT NULL AND medio_pago IS NOT NULL
        AND (medio_pago <> 'TRANSFERENCIA' OR comprobante_pago IS NOT NULL))
  ),
  -- "Pendiente de pago" no tiene pago; los estados de avance exigen pago verificado.
  CONSTRAINT chk_pedido_estado_pago CHECK (
    (cod_estado = 'PENDIENTE_PAGO' AND fecha_hora_pago IS NULL)
    OR (cod_estado IN ('EN_PREPARACION', 'LISTO_DESPACHO', 'ENTREGADO') AND fecha_hora_pago IS NOT NULL)
    OR cod_estado = 'CANCELADO'
  ),
  -- BPMN: "Marcar arreglo terminado y cargar foto" antes de "Listo para despacho".
  CONSTRAINT chk_pedido_foto_arreglo CHECK (
    cod_estado NOT IN ('LISTO_DESPACHO', 'ENTREGADO') OR foto_arreglo IS NOT NULL
  ),
  -- BPMN: "Subir foto de comprobante de entrega" + "Registrar timestamp y cerrar orden".
  -- Solo un pedido entregado tiene datos de entrega, y debe tener ambos.
  CONSTRAINT chk_pedido_cierre CHECK (
    (cod_estado = 'ENTREGADO' AND fecha_hora_entrega IS NOT NULL AND foto_entrega IS NOT NULL)
    OR (cod_estado <> 'ENTREGADO' AND fecha_hora_entrega IS NULL AND foto_entrega IS NULL)
  ),
  CONSTRAINT chk_pedido_entrega_posterior CHECK (
    fecha_hora_entrega IS NULL OR fecha_hora_entrega >= fecha_hora_ingreso
  ),
  -- BPMN: rechazo del arreglo o desistimiento => Cancelado, con motivo.
  CONSTRAINT chk_pedido_cancelacion CHECK (
    (cod_estado = 'CANCELADO' AND motivo_cancelacion IS NOT NULL)
    OR (cod_estado <> 'CANCELADO' AND motivo_cancelacion IS NULL)
  )
) ENGINE=InnoDB;

-- Resuelve la relación N:M entre pedido y producto.
-- precio_unitario es el precio COBRADO en esa venta: si el precio de lista
-- cambia después, el historial de pedidos no se altera.
CREATE TABLE detalle_pedido (
  id_pedido        INT       NOT NULL,
  id_producto      INT       NOT NULL,
  cantidad         SMALLINT  NOT NULL,
  precio_unitario  INT       NOT NULL,
  PRIMARY KEY (id_pedido, id_producto),
  CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedido (id_pedido) ON DELETE CASCADE,
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto (id_producto),
  CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_detalle_precio   CHECK (precio_unitario > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. FECHAS IMPORTANTES Y RECORDATORIOS  (RF09 a RF13)
-- ---------------------------------------------------------------------

-- Fecha que el cliente comparte voluntariamente. Se guarda día y mes (el año
-- es opcional) porque lo que se recuerda es la ocurrencia de cada año.
CREATE TABLE fecha_importante (
  id_fecha           INT           NOT NULL AUTO_INCREMENT,
  id_cliente         INT           NOT NULL,
  id_ocasion         INT           NOT NULL,
  relacion           VARCHAR(40)   NOT NULL,  -- de quién es la fecha: 'Madre', 'Esposa', 'Pareja'...
  dia                TINYINT       NOT NULL,
  mes                TINYINT       NOT NULL,
  anio               SMALLINT      NULL,      -- opcional (p. ej. año del matrimonio)
  dias_anticipacion  TINYINT       NOT NULL DEFAULT 5,  -- con cuántos días de aviso se recuerda
  nota               VARCHAR(150)  NULL,      -- preferencias: flores, colores
  activa             TINYINT(1)    NOT NULL DEFAULT 1,  -- 0 = el cliente pidió no recordarla
  fecha_registro     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_fecha),
  CONSTRAINT uq_fecha_cliente_ocasion UNIQUE (id_cliente, id_ocasion, relacion),
  CONSTRAINT fk_fecha_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
  CONSTRAINT fk_fecha_ocasion FOREIGN KEY (id_ocasion) REFERENCES tipo_ocasion (id_ocasion),
  CONSTRAINT chk_fecha_mes CHECK (mes BETWEEN 1 AND 12),
  CONSTRAINT chk_fecha_dia CHECK (
    dia BETWEEN 1 AND (CASE WHEN mes = 2 THEN 29
                            WHEN mes IN (4, 6, 9, 11) THEN 30
                            ELSE 31 END)
  ),
  CONSTRAINT chk_fecha_anio         CHECK (anio IS NULL OR anio BETWEEN 1900 AND 2100),
  CONSTRAINT chk_fecha_anticipacion CHECK (dias_anticipacion BETWEEN 1 AND 30),
  CONSTRAINT chk_fecha_activa       CHECK (activa IN (0, 1))
) ENGINE=InnoDB;

-- Un recordatorio por cada ocurrencia de una fecha importante (lo genera la
-- revisión periódica del BPMN de recordatorios / flujo n8n).
-- El estado NO se guarda en una columna aparte porque se deduce de los datos:
--   fecha_hora_contacto IS NULL      -> Pendiente
--   fecha_hora_contacto IS NOT NULL  -> Contactado (RF12)
--   id_pedido IS NOT NULL            -> el contacto generó un pedido
-- La vista v_recordatorio_estado (abajo) entrega esos estados ya calculados.
-- No se guarda id_cliente: se obtiene a través de fecha_importante (3FN).
CREATE TABLE recordatorio (
  id_recordatorio      INT           NOT NULL AUTO_INCREMENT,
  id_fecha             INT           NOT NULL,
  fecha_ocasion        DATE          NOT NULL,  -- ocurrencia concreta que se recuerda
  fecha_generacion     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_hora_contacto  DATETIME      NULL,      -- cuándo Paulina contactó por WhatsApp
  id_pedido            INT           NULL,      -- pedido originado por el contacto, si lo hubo
  observacion          VARCHAR(255)  NULL,      -- resultado del contacto en palabras de Paulina
  PRIMARY KEY (id_recordatorio),
  -- Un solo recordatorio por ocurrencia: la generación diaria no duplica.
  CONSTRAINT uq_recordatorio_ocurrencia UNIQUE (id_fecha, fecha_ocasion),
  CONSTRAINT uq_recordatorio_pedido     UNIQUE (id_pedido),
  CONSTRAINT fk_recordatorio_fecha  FOREIGN KEY (id_fecha)  REFERENCES fecha_importante (id_fecha),
  CONSTRAINT fk_recordatorio_pedido FOREIGN KEY (id_pedido) REFERENCES pedido (id_pedido),
  -- Solo puede haber pedido asociado si hubo contacto.
  CONSTRAINT chk_recordatorio_pedido CHECK (id_pedido IS NULL OR fecha_hora_contacto IS NOT NULL),
  CONSTRAINT chk_recordatorio_tiempo CHECK (
    fecha_hora_contacto IS NULL OR fecha_hora_contacto >= fecha_generacion
  )
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. ÍNDICES DE APOYO A LAS CONSULTAS FRECUENTES (RNF01, RNF02)
--    (las PK, UNIQUE y FK ya crean sus propios índices)
-- ---------------------------------------------------------------------

CREATE INDEX idx_pedido_entrega       ON pedido (fecha_entrega, bloque_horario);
CREATE INDEX idx_pedido_ingreso       ON pedido (fecha_hora_ingreso);
CREATE INDEX idx_fecha_mes_dia        ON fecha_importante (mes, dia);
CREATE INDEX idx_recordatorio_ocasion ON recordatorio (fecha_ocasion);

-- ---------------------------------------------------------------------
-- 7. VISTAS (datos derivados: se calculan, no se almacenan)
-- ---------------------------------------------------------------------

-- RF08: monto total de cada pedido = suma de (cantidad x precio cobrado)
-- más el costo de despacho. Al ser una vista, nunca queda desactualizado.
CREATE VIEW v_pedido_monto AS
SELECT p.id_pedido,
       p.id_cliente,
       COALESCE(SUM(d.cantidad * d.precio_unitario), 0)                    AS subtotal_productos,
       p.costo_despacho,
       COALESCE(SUM(d.cantidad * d.precio_unitario), 0) + p.costo_despacho AS monto_total
FROM pedido p
LEFT JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
GROUP BY p.id_pedido, p.id_cliente, p.costo_despacho;

-- RF12/RF13: estado y resultado de cada recordatorio, deducidos de sus datos.
CREATE VIEW v_recordatorio_estado AS
SELECT r.id_recordatorio,
       r.id_fecha,
       f.id_cliente,
       r.fecha_ocasion,
       r.fecha_generacion,
       r.fecha_hora_contacto,
       r.id_pedido,
       r.observacion,
       CASE WHEN r.fecha_hora_contacto IS NULL THEN 'Pendiente'
            ELSE 'Contactado' END                         AS estado,
       CASE WHEN r.fecha_hora_contacto IS NULL THEN NULL
            WHEN r.id_pedido IS NOT NULL THEN 'Con pedido'
            ELSE 'Sin pedido' END                         AS resultado
FROM recordatorio r
JOIN fecha_importante f ON f.id_fecha = r.id_fecha;
