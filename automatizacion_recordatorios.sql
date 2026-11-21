-- =====================================================================
--  Florería Ángeles · Archivo: db/automatizacion_recordatorios.sql
--  Sentencias de la revisión periódica de fechas importantes (BPMN
--  "Sistema de recordatorio"). Es lo que ejecuta el nodo MySQL del flujo
--  n8n una vez al día (ver docs/05-automatizacion-n8n.md).
--  OJO: este archivo SÍ modifica datos (inserta recordatorios). Ejecutarlo
--  después de consultas.sql si se quiere comparar con lo documentado.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE floreria_angeles;

-- Día de ejecución del job. En n8n: SET @fecha_ejecucion = CURDATE();
-- Aquí se simula la corrida del 24-11-2026 (día siguiente a la fecha de
-- referencia del seed, cuya corrida del 23-11 ya está cargada).
SET @fecha_ejecucion = '2026-11-24';

-- ---------------------------------------------------------------------
-- A1 · "Consultar fechas" + "Identificar fechas próximas" +
--      "Generar recordatorios de clientes"
-- Crea un recordatorio por cada fecha activa, de un cliente con
-- consentimiento, cuya próxima ocurrencia cae dentro de sus días de
-- anticipación. NOT EXISTS + UNIQUE (id_fecha, fecha_ocasion) hacen que
-- correrlo dos veces el mismo día no duplique nada (idempotente).
-- ---------------------------------------------------------------------
INSERT INTO recordatorio (id_fecha, fecha_ocasion, fecha_generacion)
SELECT prox.id_fecha,
       prox.proxima_fecha,
       CONCAT(@fecha_ejecucion, ' 08:00:00')   -- en n8n: NOW()
FROM (
       SELECT x.*,
              CASE WHEN DATEDIFF(x.ocurrencia_este_anio, @fecha_ejecucion) >= 0
                   THEN x.ocurrencia_este_anio
                   ELSE x.ocurrencia_anio_siguiente END AS proxima_fecha
       FROM (
              SELECT f.id_fecha, f.id_cliente, f.dias_anticipacion,
                     DATE_ADD(DATE_ADD(MAKEDATE(YEAR(@fecha_ejecucion), 1),
                                       INTERVAL (f.mes - 1) MONTH),
                              INTERVAL (f.dia - 1) DAY)  AS ocurrencia_este_anio,
                     DATE_ADD(DATE_ADD(MAKEDATE(YEAR(@fecha_ejecucion) + 1, 1),
                                       INTERVAL (f.mes - 1) MONTH),
                              INTERVAL (f.dia - 1) DAY)  AS ocurrencia_anio_siguiente
              FROM fecha_importante f
              WHERE f.activa = 1
            ) AS x
     ) AS prox
JOIN cliente c ON c.id_cliente = prox.id_cliente
WHERE c.acepta_recordatorios = 1
  AND DATEDIFF(prox.proxima_fecha, @fecha_ejecucion) <= prox.dias_anticipacion
  AND NOT EXISTS (SELECT 1
                    FROM recordatorio r
                   WHERE r.id_fecha = prox.id_fecha
                     AND r.fecha_ocasion = prox.proxima_fecha);

-- ---------------------------------------------------------------------
-- A2 · "Mostrar recordatorios a Paulina": los generados en esta corrida
-- (n8n usa este resultado para avisarle; el contacto lo hace ella).
-- ---------------------------------------------------------------------
SELECT r.id_recordatorio,
       r.fecha_ocasion,
       DATEDIFF(r.fecha_ocasion, @fecha_ejecucion)  AS dias_restantes,
       CONCAT_WS(' ', c.nombre, c.apellido)         AS cliente,
       c.telefono,
       o.nombre                                     AS ocasion,
       f.relacion
FROM recordatorio r
JOIN fecha_importante f ON f.id_fecha = r.id_fecha
JOIN cliente c          ON c.id_cliente = f.id_cliente
JOIN tipo_ocasion o     ON o.id_ocasion = f.id_ocasion
WHERE DATE(r.fecha_generacion) = @fecha_ejecucion
ORDER BY r.fecha_ocasion, r.id_recordatorio;

-- ---------------------------------------------------------------------
-- A3 · Referencia para la aplicación (no se ejecuta aquí): "Registrar
-- resultado del contacto en SIG" (RF12). Reemplazar los ? por valores.
--
--   UPDATE recordatorio
--      SET fecha_hora_contacto = NOW(),
--          observacion = 'Texto del resultado'
--    WHERE id_recordatorio = ?;
--
--   -- Si el cliente encarga un pedido, después de crearlo:
--   UPDATE recordatorio SET id_pedido = ? WHERE id_recordatorio = ?;
-- ---------------------------------------------------------------------
