USE OBLIGATORIO;

WITH goles_por_partido AS (
    SELECT p.id_partido,
           p.id_equipo_local,
           p.id_equipo_visitante,
           SUM(CASE WHEN (pp.id_equipo = p.id_equipo_local     AND g.autogol = FALSE)
               OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = TRUE)
                        THEN 1 ELSE 0 END) AS goles_local,
           SUM(CASE WHEN (pp.id_equipo = p.id_equipo_visitante AND g.autogol = FALSE)
               OR (pp.id_equipo = p.id_equipo_local     AND g.autogol = TRUE)
                        THEN 1 ELSE 0 END) AS goles_visitante
    FROM partido p
             LEFT JOIN gol g               ON g.id_partido = p.id_partido
             LEFT JOIN planilla_partido pp ON pp.id_partido = g.id_partido
        AND pp.ci_jugador = g.ci_jugador
    WHERE p.id_torneo = 1
      AND p.estado = 'jugado'
    GROUP BY p.id_partido, p.id_equipo_local, p.id_equipo_visitante
),
     resultados AS (
         SELECT id_equipo_local AS id_equipo, goles_local AS gf, goles_visitante AS gc
         FROM goles_por_partido
         UNION ALL
         SELECT id_equipo_visitante, goles_visitante, goles_local
         FROM goles_por_partido
     )
SELECT e.nombre                                  AS equipo,
       COUNT(r.id_equipo)                        AS pj,
       COALESCE(SUM(r.gf > r.gc), 0)             AS pg,
       COALESCE(SUM(r.gf = r.gc), 0)             AS pe,
       COALESCE(SUM(r.gf < r.gc), 0)             AS pp,
       COALESCE(SUM(r.gf), 0)                    AS gf,
       COALESCE(SUM(r.gc), 0)                    AS gc,
       COALESCE(SUM(r.gf) - SUM(r.gc), 0)        AS dg,
       COALESCE(SUM(CASE WHEN r.gf > r.gc THEN 3
                         WHEN r.gf = r.gc THEN 1
                         ELSE 0 END), 0)         AS puntos
FROM equipo e
         LEFT JOIN resultados r ON r.id_equipo = e.id_equipo
WHERE e.id_torneo = 1
GROUP BY e.id_equipo, e.nombre
ORDER BY puntos DESC, dg DESC, gf DESC;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       e.nombre AS equipo,
       COUNT(*) AS goles
FROM gol g
         JOIN partido p           ON p.id_partido = g.id_partido
         JOIN jugador j           ON j.ci_jugador = g.ci_jugador
         JOIN planilla_partido pp ON pp.id_partido = g.id_partido
    AND pp.ci_jugador = g.ci_jugador
         JOIN equipo e            ON e.id_equipo = pp.id_equipo
WHERE p.id_torneo = 1
  AND g.autogol = FALSE
GROUP BY j.ci_jugador, j.nombre, j.apellido, e.nombre
ORDER BY goles DESC, j.apellido
    LIMIT 10;

SELECT e.nombre AS equipo,
       COALESCE(SUM(t.color = 'amarilla'), 0) AS amarillas,
       COALESCE(SUM(t.color = 'roja'), 0)     AS rojas,
       COALESCE(SUM(CASE WHEN t.color = 'amarilla' THEN 1
                         WHEN t.color = 'roja'     THEN 3
                         ELSE 0 END), 0)      AS puntaje
FROM equipo e
         LEFT JOIN planilla_partido pp ON pp.id_equipo = e.id_equipo
         LEFT JOIN tarjeta t           ON t.id_partido = pp.id_partido
    AND t.ci_jugador = pp.ci_jugador
WHERE e.id_torneo = 1
GROUP BY e.id_equipo, e.nombre
ORDER BY puntaje ASC, e.nombre;

SELECT p.numero_fecha                                         AS fecha,
       COUNT(DISTINCT p.id_partido)                           AS partidos_jugados,
       COUNT(g.id_gol)                                        AS goles,
       ROUND(COUNT(g.id_gol) / COUNT(DISTINCT p.id_partido), 2) AS promedio
FROM partido p
         LEFT JOIN gol g ON g.id_partido = p.id_partido
WHERE p.id_torneo = 1
  AND p.estado = 'jugado'
GROUP BY p.numero_fecha
ORDER BY p.numero_fecha;

SELECT COUNT(DISTINCT p.id_partido)                           AS partidos_jugados,
       COUNT(g.id_gol)                                        AS goles,
       ROUND(COUNT(g.id_gol) / COUNT(DISTINCT p.id_partido), 2) AS promedio
FROM partido p
         LEFT JOIN gol g ON g.id_partido = p.id_partido
WHERE p.id_torneo = 1
  AND p.estado = 'jugado';

SELECT c.nombre_cancha,
       co.nombre  AS complejo,
       COUNT(*)   AS partidos
FROM partido p
         JOIN cancha c    ON c.id_cancha = p.id_cancha
         JOIN complejo co ON co.id_complejo = c.id_complejo
WHERE p.id_torneo = 1
  AND p.estado IN ('jugado', 'programado')
GROUP BY c.id_cancha, c.nombre_cancha, co.nombre
ORDER BY partidos DESC;

SELECT t.hora_inicio,
       t.hora_fin,
       COUNT(*) AS partidos
FROM partido p
         JOIN turno t ON t.id_turno = p.id_turno
WHERE p.id_torneo = 1
  AND p.estado IN ('jugado', 'programado')
GROUP BY t.id_turno, t.hora_inicio, t.hora_fin
ORDER BY partidos DESC, t.hora_inicio;

SELECT f.nombre AS facultad,
       j.tipo,
       COUNT(*) AS cantidad
FROM jugador j
         JOIN facultad f ON f.id_facultad = j.id_facultad
GROUP BY f.nombre, j.tipo
ORDER BY f.nombre, j.tipo;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       e.nombre AS equipo
FROM equipo_jugador_torneo ejt
         JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
         JOIN equipo e  ON e.id_equipo = ejt.id_equipo
WHERE ejt.id_torneo = 1
  AND NOT EXISTS (
    SELECT 1
    FROM planilla_partido pp
             JOIN partido p ON p.id_partido = pp.id_partido
    WHERE pp.ci_jugador = ejt.ci_jugador
      AND p.id_torneo = ejt.id_torneo
)
ORDER BY e.nombre, j.apellido;

SELECT e.nombre AS equipo,
       s.motivo,
       COUNT(*) AS cantidad
FROM sancion_jugador s
         JOIN equipo_jugador_torneo ejt ON ejt.ci_jugador = s.ci_jugador
    AND ejt.id_torneo = s.id_torneo
         JOIN equipo e                  ON e.id_equipo = ejt.id_equipo
WHERE s.id_torneo = 1
GROUP BY e.nombre, s.motivo
ORDER BY e.nombre, s.motivo;

SELECT estado,
       COUNT(*) AS partidos,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS porcentaje
FROM partido
WHERE id_torneo = 1
GROUP BY estado
ORDER BY partidos DESC;

SELECT p.numero_fecha AS fecha,
       p.dia,
       el.nombre AS local,
       SUM(CASE WHEN (pp.id_equipo = p.id_equipo_local     AND g.autogol = FALSE)
                  OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = TRUE)
                THEN 1 ELSE 0 END) AS goles_local,
       SUM(CASE WHEN (pp.id_equipo = p.id_equipo_visitante AND g.autogol = FALSE)
                  OR (pp.id_equipo = p.id_equipo_local     AND g.autogol = TRUE)
                THEN 1 ELSE 0 END) AS goles_visitante,
       ev.nombre AS visitante
FROM partido p
    JOIN equipo el                ON el.id_equipo = p.id_equipo_local
    JOIN equipo ev                ON ev.id_equipo = p.id_equipo_visitante
    LEFT JOIN gol g               ON g.id_partido = p.id_partido
    LEFT JOIN planilla_partido pp ON pp.id_partido = g.id_partido
    AND pp.ci_jugador = g.ci_jugador
WHERE p.id_torneo = 1
  AND p.estado = 'jugado'
GROUP BY p.id_partido, p.numero_fecha, p.dia, el.nombre, ev.nombre
ORDER BY p.numero_fecha, p.dia;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       s.motivo,
       s.numero_fecha_inicio,
       s.cantidad_fechas
FROM sancion_jugador s
         JOIN jugador j ON j.ci_jugador = s.ci_jugador
WHERE s.id_torneo = 1
  AND 4 BETWEEN s.numero_fecha_inicio
    AND s.numero_fecha_inicio + s.cantidad_fechas - 1
ORDER BY j.apellido;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       COUNT(*) AS amarillas
FROM tarjeta t
         JOIN partido p ON p.id_partido = t.id_partido
         JOIN jugador j ON j.ci_jugador = t.ci_jugador
WHERE p.id_torneo = 1
  AND t.color = 'amarilla'
GROUP BY j.ci_jugador, j.nombre, j.apellido
HAVING COUNT(*) = 2
ORDER BY j.apellido;