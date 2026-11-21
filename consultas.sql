-- =====================================================================
--  Florería Ángeles · SIG de clientes, pedidos y fechas importantes
--  Archivo : db/consultas.sql   (ejecutar DESPUÉS de schema.sql y seed.sql)
--  Consultas de negocio (Q), indicadores de la Tabla 1 de la E1 (K) y
--  validaciones de integridad (V). Todas son de solo lectura (SELECT).
--  Resultados e interpretación: docs/04-sql-consultas.md
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE floreria_angeles;

-- Parámetros. Se fijan para que los resultados sean reproducibles en
-- cualquier computador. En la operación real: SET @fecha_ref = CURDATE();
SET @fecha_ref      = '2026-11-23';    -- "hoy" de la demostración
SET @telefono       = '+56900001001';  -- cliente que escribe por WhatsApp (Q1 a Q4)
SET @dias_horizonte = 14;              -- ventana de fechas próximas (Q5)
SET @inicio_periodo = '2026-09-01';    -- inicio del período de medición (K3)


-- ---------------------------------------------------------------------
-- V0 · Filas cargadas por tabla (verificación rápida después del seed)
-- ---------------------------------------------------------------------
SELECT 'cliente' AS tabla, COUNT(*) AS filas FROM cliente
UNION ALL SELECT 'direccion',        COUNT(*) FROM direccion
UNION ALL SELECT 'producto',         COUNT(*) FROM producto
UNION ALL SELECT 'pedido',           COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido',   COUNT(*) FROM detalle_pedido
UNION ALL SELECT 'fecha_importante', COUNT(*) FROM fecha_importante
UNION ALL SELECT 'recordatorio',     COUNT(*) FROM recordatorio;


-- =====================================================================
-- A. FICHA DEL CLIENTE (BPMN to-be: "Ingresar teléfono del cliente" ->
--    "Recuperar datos, dirección y fechas clave (BD)")
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1 · Ficha del cliente a partir de su teléfono            [RF02, RF03]
-- ---------------------------------------------------------------------
SELECT c.id_cliente,
       CONCAT_WS(' ', c.nombre, c.apellido)                         AS cliente,
       c.telefono,
       c.email,
       CASE WHEN c.acepta_recordatorios = 1 THEN 'Sí' ELSE 'No' END AS acepta_recordatorios,
       CONCAT(d.calle, ' ', d.numero, COALESCE(CONCAT(', ', d.depto), ''),
              ', ', co.nombre)                                      AS direccion_habitual,
       d.referencia,
       (SELECT COUNT(*) FROM pedido p
         WHERE p.id_cliente = c.id_cliente
           AND p.cod_estado <> 'CANCELADO')                         AS pedidos_realizados,
       (SELECT MAX(DATE(p.fecha_hora_ingreso)) FROM pedido p
         WHERE p.id_cliente = c.id_cliente)                         AS ultimo_pedido
FROM cliente c
LEFT JOIN direccion d ON d.id_cliente = c.id_cliente AND d.es_habitual = 1
LEFT JOIN comuna co   ON co.id_comuna = d.id_comuna
WHERE c.telefono = @telefono;

-- ---------------------------------------------------------------------
-- Q2 · Fechas importantes registradas del cliente           [RF09]
-- ---------------------------------------------------------------------
SELECT o.nombre                                               AS ocasion,
       f.relacion,
       CONCAT(LPAD(f.dia, 2, '0'), '-', LPAD(f.mes, 2, '0'))  AS dia_mes,
       f.anio,
       f.dias_anticipacion,
       f.nota
FROM fecha_importante f
JOIN cliente c      ON c.id_cliente = f.id_cliente
JOIN tipo_ocasion o ON o.id_ocasion = f.id_ocasion
WHERE c.telefono = @telefono
  AND f.activa = 1
ORDER BY f.mes, f.dia;

-- ---------------------------------------------------------------------
-- Q3 · Historial de pedidos del cliente con su monto total  [RF04, RF08]
-- ---------------------------------------------------------------------
SELECT p.id_pedido,
       DATE(p.fecha_hora_ingreso)  AS fecha_pedido,
       p.fecha_entrega,
       o.nombre                    AS ocasion,
       (SELECT GROUP_CONCAT(CONCAT(pr.nombre, ' x', dp.cantidad)
                            ORDER BY dp.id_producto SEPARATOR ', ')
          FROM detalle_pedido dp
          JOIN producto pr ON pr.id_producto = dp.id_producto
         WHERE dp.id_pedido = p.id_pedido) AS productos,
       d.etiqueta                  AS destino,
       e.nombre                    AS estado,
       v.monto_total
FROM pedido p
JOIN cliente c        ON c.id_cliente = p.id_cliente
JOIN tipo_ocasion o   ON o.id_ocasion = p.id_ocasion
JOIN direccion d      ON d.id_direccion = p.id_direccion
JOIN estado_pedido e  ON e.cod_estado = p.cod_estado
JOIN v_pedido_monto v ON v.id_pedido = p.id_pedido
WHERE c.telefono = @telefono
ORDER BY p.fecha_hora_ingreso DESC;

-- ---------------------------------------------------------------------
-- Q4 · Historial de recordatorios y contactos del cliente   [RF12, RF13]
-- ---------------------------------------------------------------------
SELECT r.fecha_ocasion,
       o.nombre                  AS ocasion,
       f.relacion,
       DATE(r.fecha_generacion)  AS generado_el,
       r.estado,
       r.fecha_hora_contacto,
       r.resultado,
       r.id_pedido,
       r.observacion
FROM v_recordatorio_estado r
JOIN fecha_importante f ON f.id_fecha = r.id_fecha
JOIN tipo_ocasion o     ON o.id_ocasion = f.id_ocasion
JOIN cliente c          ON c.id_cliente = r.id_cliente
WHERE c.telefono = @telefono
ORDER BY r.fecha_ocasion DESC;


-- =====================================================================
-- B. FECHAS IMPORTANTES Y RECORDATORIOS (BPMN "Sistema de recordatorio")
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q5 · Fechas importantes de los próximos 14 días           [RF10]
-- Calcula la próxima ocurrencia de cada fecha (este año o el siguiente).
-- Solo clientes que aceptaron recordatorios (consentimiento, Ley 21.719).
-- ---------------------------------------------------------------------
SELECT prox.proxima_fecha,
       DATEDIFF(prox.proxima_fecha, @fecha_ref)  AS dias_restantes,
       CONCAT_WS(' ', c.nombre, c.apellido)      AS cliente,
       c.telefono,
       o.nombre                                  AS ocasion,
       prox.relacion,
       prox.nota,
       CASE WHEN r.id_recordatorio IS NULL THEN 'Aún no' ELSE 'Sí' END AS recordatorio_generado
FROM (
       SELECT x.*,
              CASE WHEN DATEDIFF(x.ocurrencia_este_anio, @fecha_ref) >= 0
                   THEN x.ocurrencia_este_anio
                   ELSE x.ocurrencia_anio_siguiente END AS proxima_fecha
       FROM (
              SELECT f.id_fecha, f.id_cliente, f.id_ocasion, f.relacion, f.nota,
                     DATE_ADD(DATE_ADD(MAKEDATE(YEAR(@fecha_ref), 1),
                                       INTERVAL (f.mes - 1) MONTH),
                              INTERVAL (f.dia - 1) DAY)  AS ocurrencia_este_anio,
                     DATE_ADD(DATE_ADD(MAKEDATE(YEAR(@fecha_ref) + 1, 1),
                                       INTERVAL (f.mes - 1) MONTH),
                              INTERVAL (f.dia - 1) DAY)  AS ocurrencia_anio_siguiente
              FROM fecha_importante f
              WHERE f.activa = 1
            ) AS x
     ) AS prox
JOIN cliente c      ON c.id_cliente = prox.id_cliente
JOIN tipo_ocasion o ON o.id_ocasion = prox.id_ocasion
LEFT JOIN recordatorio r ON r.id_fecha = prox.id_fecha
                        AND r.fecha_ocasion = prox.proxima_fecha
WHERE c.acepta_recordatorios = 1
  AND DATEDIFF(prox.proxima_fecha, @fecha_ref) <= @dias_horizonte
ORDER BY prox.proxima_fecha, prox.id_fecha;

-- ---------------------------------------------------------------------
-- Q6 · Bandeja de recordatorios por gestionar (pendientes)  [RF11]
-- BPMN: "Mostrar recordatorios a Paulina" -> "Revisar recordatorios y
-- datos del cliente". Incluye los vencidos de la última semana (siguen
-- pendientes, como indica el BPMN) y datos para priorizar el contacto.
-- ---------------------------------------------------------------------
SELECT r.id_recordatorio,
       r.fecha_ocasion,
       DATEDIFF(r.fecha_ocasion, @fecha_ref)        AS dias_restantes,
       CASE WHEN DATEDIFF(r.fecha_ocasion, @fecha_ref) < 0
            THEN 'Vencido' ELSE 'Por gestionar' END AS situacion,
       CONCAT_WS(' ', c.nombre, c.apellido)         AS cliente,
       c.telefono,
       o.nombre                                     AS ocasion,
       f.relacion,
       f.nota,
       (SELECT COUNT(*) FROM pedido p
         WHERE p.id_cliente = c.id_cliente
           AND p.cod_estado <> 'CANCELADO')         AS pedidos_previos,
       (SELECT MAX(DATE(p.fecha_hora_ingreso)) FROM pedido p
         WHERE p.id_cliente = c.id_cliente)         AS ultimo_pedido
FROM recordatorio r
JOIN fecha_importante f ON f.id_fecha = r.id_fecha
JOIN cliente c          ON c.id_cliente = f.id_cliente
JOIN tipo_ocasion o     ON o.id_ocasion = f.id_ocasion
WHERE r.fecha_hora_contacto IS NULL
  AND DATEDIFF(r.fecha_ocasion, @fecha_ref) >= -7
ORDER BY r.fecha_ocasion, r.id_recordatorio;


-- =====================================================================
-- C. OPERACIÓN DE PEDIDOS (BPMN to-be, flujo principal)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q7 · Agenda de entregas del día por bloque AM/PM          [RF06, RF07, RF08]
-- ---------------------------------------------------------------------
SELECT p.bloque_horario,
       p.id_pedido,
       e.nombre                                    AS estado,
       CONCAT_WS(' ', c.nombre, c.apellido)        AS cliente,
       p.destinatario,
       CONCAT(d.calle, ' ', d.numero, COALESCE(CONCAT(', ', d.depto), ''),
              ', ', co.nombre)                     AS direccion_entrega,
       CASE WHEN p.fecha_hora_pago IS NULL
            THEN 'Pendiente' ELSE 'Verificado' END AS pago,
       v.monto_total
FROM pedido p
JOIN estado_pedido e  ON e.cod_estado = p.cod_estado
JOIN cliente c        ON c.id_cliente = p.id_cliente
JOIN direccion d      ON d.id_direccion = p.id_direccion
JOIN comuna co        ON co.id_comuna = d.id_comuna
JOIN v_pedido_monto v ON v.id_pedido = p.id_pedido
WHERE p.fecha_entrega = @fecha_ref
  AND p.cod_estado <> 'CANCELADO'
ORDER BY p.bloque_horario, p.id_pedido;

-- ---------------------------------------------------------------------
-- Q8 · Pedidos abiertos por estado                          [RF07]
-- ---------------------------------------------------------------------
SELECT e.nombre                         AS estado,
       COUNT(p.id_pedido)               AS pedidos,
       MIN(p.fecha_entrega)             AS entrega_mas_proxima,
       COALESCE(SUM(v.monto_total), 0)  AS monto_total
FROM estado_pedido e
LEFT JOIN pedido p         ON p.cod_estado = e.cod_estado
LEFT JOIN v_pedido_monto v ON v.id_pedido = p.id_pedido
WHERE e.es_final = 0
GROUP BY e.cod_estado, e.nombre, e.orden
ORDER BY e.orden;

-- ---------------------------------------------------------------------
-- Q9 · Cumplimiento del bloque horario y lead time (E1, sección 3.3)
-- A tiempo = entregado el día comprometido y antes del cierre del bloque
-- (AM: 14:00, PM: 20:00). Lead time = horas entre el ingreso y la entrega.
-- ---------------------------------------------------------------------
SELECT t.bloque_horario,
       COUNT(*)                                      AS entregas,
       SUM(t.a_tiempo)                               AS a_tiempo,
       ROUND(100.0 * SUM(t.a_tiempo) / COUNT(*), 1)  AS pct_cumplimiento,
       ROUND(AVG(t.minutos) / 60, 1)                 AS lead_time_prom_horas
FROM (
       SELECT p.bloque_horario,
              CASE WHEN DATE(p.fecha_hora_entrega) = p.fecha_entrega
                    AND HOUR(p.fecha_hora_entrega) <
                        (CASE WHEN p.bloque_horario = 'AM' THEN 14 ELSE 20 END)
                   THEN 1 ELSE 0 END                                          AS a_tiempo,
              TIMESTAMPDIFF(MINUTE, p.fecha_hora_ingreso, p.fecha_hora_entrega) AS minutos
       FROM pedido p
       WHERE p.cod_estado = 'ENTREGADO'
     ) AS t
GROUP BY t.bloque_horario
UNION ALL
SELECT 'Total',
       COUNT(*),
       SUM(t.a_tiempo),
       ROUND(100.0 * SUM(t.a_tiempo) / COUNT(*), 1),
       ROUND(AVG(t.minutos) / 60, 1)
FROM (
       SELECT CASE WHEN DATE(p.fecha_hora_entrega) = p.fecha_entrega
                    AND HOUR(p.fecha_hora_entrega) <
                        (CASE WHEN p.bloque_horario = 'AM' THEN 14 ELSE 20 END)
                   THEN 1 ELSE 0 END                                          AS a_tiempo,
              TIMESTAMPDIFF(MINUTE, p.fecha_hora_ingreso, p.fecha_hora_entrega) AS minutos
       FROM pedido p
       WHERE p.cod_estado = 'ENTREGADO'
     ) AS t
ORDER BY bloque_horario;

-- ---------------------------------------------------------------------
-- Q9b · Entregas fuera del bloque comprometido (detalle de Q9)
-- ---------------------------------------------------------------------
SELECT p.id_pedido,
       p.fecha_entrega,
       p.bloque_horario,
       p.fecha_hora_entrega,
       o.nombre   AS ocasion,
       co.nombre  AS comuna
FROM pedido p
JOIN tipo_ocasion o ON o.id_ocasion = p.id_ocasion
JOIN direccion d    ON d.id_direccion = p.id_direccion
JOIN comuna co      ON co.id_comuna = d.id_comuna
WHERE p.cod_estado = 'ENTREGADO'
  AND NOT (DATE(p.fecha_hora_entrega) = p.fecha_entrega
           AND HOUR(p.fecha_hora_entrega) <
               (CASE WHEN p.bloque_horario = 'AM' THEN 14 ELSE 20 END))
ORDER BY p.fecha_hora_entrega;

-- ---------------------------------------------------------------------
-- Q10 · Pedidos y ventas por ocasión (pedidos no cancelados) [RF08]
-- ---------------------------------------------------------------------
SELECT o.nombre                              AS ocasion,
       COUNT(*)                              AS pedidos,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pedido
                                  WHERE cod_estado <> 'CANCELADO'), 1) AS pct_pedidos,
       SUM(v.monto_total)                    AS ventas_clp,
       ROUND(AVG(v.monto_total), 0)          AS ticket_promedio
FROM pedido p
JOIN tipo_ocasion o   ON o.id_ocasion = p.id_ocasion
JOIN v_pedido_monto v ON v.id_pedido = p.id_pedido
WHERE p.cod_estado <> 'CANCELADO'
GROUP BY o.id_ocasion, o.nombre
ORDER BY pedidos DESC, o.id_ocasion;

-- ---------------------------------------------------------------------
-- Q11 · Peso de las ocasiones que se repiten cada año (las que el módulo
--       de recordatorios permite anticipar)                  [RF09-RF11]
-- ---------------------------------------------------------------------
SELECT CASE WHEN o.es_anual = 1
            THEN 'Cumpleaños y aniversarios'
            ELSE 'Otras ocasiones' END       AS grupo,
       COUNT(*)                              AS pedidos,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pedido
                                  WHERE cod_estado <> 'CANCELADO'), 1) AS pct_pedidos,
       SUM(v.monto_total)                    AS ventas_clp,
       ROUND(100.0 * SUM(v.monto_total) /
             (SELECT SUM(vm.monto_total)
                FROM v_pedido_monto vm
                JOIN pedido pp ON pp.id_pedido = vm.id_pedido
               WHERE pp.cod_estado <> 'CANCELADO'), 1) AS pct_ventas,
       SUM(CASE WHEN EXISTS (SELECT 1 FROM recordatorio r
                              WHERE r.id_pedido = p.id_pedido)
                THEN 1 ELSE 0 END)           AS originados_por_recordatorio
FROM pedido p
JOIN tipo_ocasion o   ON o.id_ocasion = p.id_ocasion
JOIN v_pedido_monto v ON v.id_pedido = p.id_pedido
WHERE p.cod_estado <> 'CANCELADO'
GROUP BY o.es_anual
ORDER BY o.es_anual DESC;


-- =====================================================================
-- D. INDICADORES (Tabla 1 de la E1)
-- =====================================================================

-- ---------------------------------------------------------------------
-- K1 · Fichas de clientes completas (%)                      meta >= 90 %
-- Datos mínimos: nombre, apellido, teléfono y dirección habitual de despacho
-- (nombre y teléfono ya son obligatorios por diseño: NOT NULL).
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                    AS fichas_registradas,
       SUM(CASE WHEN c.apellido IS NOT NULL
                 AND d.id_direccion IS NOT NULL THEN 1 ELSE 0 END) AS fichas_completas,
       ROUND(100.0 * SUM(CASE WHEN c.apellido IS NOT NULL
                               AND d.id_direccion IS NOT NULL THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 1)                             AS pct_fichas_completas
FROM cliente c
LEFT JOIN direccion d ON d.id_cliente = c.id_cliente AND d.es_habitual = 1;

-- ---------------------------------------------------------------------
-- K1b · Fichas incompletas y dato faltante (lista de trabajo para Paulina)
-- ---------------------------------------------------------------------
SELECT c.id_cliente,
       CONCAT_WS(' ', c.nombre, c.apellido)  AS cliente,
       c.telefono,
       CONCAT_WS(' y ',
                 CASE WHEN c.apellido IS NULL THEN 'apellido' END,
                 CASE WHEN d.id_direccion IS NULL THEN 'dirección habitual' END) AS falta
FROM cliente c
LEFT JOIN direccion d ON d.id_cliente = c.id_cliente AND d.es_habitual = 1
WHERE c.apellido IS NULL
   OR d.id_direccion IS NULL
ORDER BY c.id_cliente;

-- ---------------------------------------------------------------------
-- K2 · Cobertura de fechas importantes (indicador complementario)
-- El KPI "Fechas importantes registradas (%)" de la E1 divide por las
-- fechas COMUNICADAS por los clientes, dato que no queda en la base.
-- Lo calculable aquí: de los clientes que aceptaron recordatorios,
-- cuántos tienen al menos una fecha activa registrada.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                        AS clientes_con_consentimiento,
       SUM(CASE WHEN EXISTS (SELECT 1 FROM fecha_importante f
                              WHERE f.id_cliente = c.id_cliente
                                AND f.activa = 1)
                THEN 1 ELSE 0 END)                     AS con_fecha_registrada,
       ROUND(100.0 * SUM(CASE WHEN EXISTS (SELECT 1 FROM fecha_importante f
                                            WHERE f.id_cliente = c.id_cliente
                                              AND f.activa = 1)
                              THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 1)                 AS pct_cobertura,
       (SELECT COUNT(*) FROM fecha_importante f
         WHERE f.activa = 1)                           AS fechas_activas
FROM cliente c
WHERE c.acepta_recordatorios = 1;

-- ---------------------------------------------------------------------
-- K3 · Recordatorios atendidos (%) por mes de la ocasión     meta >= 80 %
-- Se miden los recordatorios cuya ocasión ya ocurrió dentro del período
-- [@inicio_periodo, @fecha_ref]. Atendido = Paulina registró el contacto.
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(r.fecha_ocasion, '%Y-%m')                     AS mes,
       COUNT(*)                                                  AS recordatorios,
       SUM(CASE WHEN r.fecha_hora_contacto IS NOT NULL
                THEN 1 ELSE 0 END)                               AS con_contacto,
       ROUND(100.0 * SUM(CASE WHEN r.fecha_hora_contacto IS NOT NULL
                              THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 1)                           AS pct_atendidos,
       SUM(CASE WHEN r.id_pedido IS NOT NULL THEN 1 ELSE 0 END)  AS generaron_pedido
FROM recordatorio r
WHERE DATEDIFF(r.fecha_ocasion, @inicio_periodo) >= 0
  AND DATEDIFF(r.fecha_ocasion, @fecha_ref) <= 0
GROUP BY DATE_FORMAT(r.fecha_ocasion, '%Y-%m')
UNION ALL
SELECT 'Total período',
       COUNT(*),
       SUM(CASE WHEN r.fecha_hora_contacto IS NOT NULL THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN r.fecha_hora_contacto IS NOT NULL
                              THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1),
       SUM(CASE WHEN r.id_pedido IS NOT NULL THEN 1 ELSE 0 END)
FROM recordatorio r
WHERE DATEDIFF(r.fecha_ocasion, @inicio_periodo) >= 0
  AND DATEDIFF(r.fecha_ocasion, @fecha_ref) <= 0
ORDER BY mes;


-- =====================================================================
-- E. VALIDACIONES DE INTEGRIDAD (reglas que cruzan tablas y no se pueden
--    expresar con FK o CHECK). Todas deben devolver 0 casos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- V1 · Reglas de negocio entre tablas
-- ---------------------------------------------------------------------
SELECT 'Recordatorio asociado a un pedido de otro cliente' AS regla,
       COUNT(*)                                            AS casos
FROM recordatorio r
JOIN fecha_importante f ON f.id_fecha = r.id_fecha
JOIN pedido p           ON p.id_pedido = r.id_pedido
WHERE p.id_cliente <> f.id_cliente
UNION ALL
SELECT 'Fecha importante activa de un cliente sin consentimiento', COUNT(*)
FROM fecha_importante f
JOIN cliente c ON c.id_cliente = f.id_cliente
WHERE f.activa = 1
  AND c.acepta_recordatorios = 0
UNION ALL
SELECT 'Fecha importante con una ocasión que no es anual', COUNT(*)
FROM fecha_importante f
JOIN tipo_ocasion o ON o.id_ocasion = f.id_ocasion
WHERE o.es_anual = 0
UNION ALL
SELECT 'Pedido sin productos', COUNT(*)
FROM pedido p
WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.id_pedido = p.id_pedido);
