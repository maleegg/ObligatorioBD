"""Reportes pedidos en la letra + 3 consultas propias. Son las mismas de Consultas.sql,
pero con el torneo (y la fecha) como parametro en lugar de un número fijo."""
from flask import Blueprint, render_template, request

from db import conexion, consultar_uno
from rutas.partidos import SQL_GOLES
from utiles import solo_admin, torneo_activo

bp = Blueprint("reportes", __name__, url_prefix="/reportes")

REPORTES = [
    ("Tabla de posiciones",
     "PJ jugados, PG ganados, PE empatados, PP perdidos, GF goles a favor, GC en contra, DG diferencia. "
     "Orden: puntos, diferencia de goles y goles a favor.",
     """WITH goles_por_partido AS (
            SELECT p.id_partido, p.id_equipo_local, p.id_equipo_visitante,
                   SUM(CASE WHEN (pp.id_equipo = p.id_equipo_local AND g.autogol = FALSE)
                              OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = TRUE)
                            THEN 1 ELSE 0 END) AS goles_local,
                   SUM(CASE WHEN (pp.id_equipo = p.id_equipo_visitante AND g.autogol = FALSE)
                              OR (pp.id_equipo = p.id_equipo_local AND g.autogol = TRUE)
                            THEN 1 ELSE 0 END) AS goles_visitante
            FROM partido p
            LEFT JOIN gol g               ON g.id_partido = p.id_partido
            LEFT JOIN planilla_partido pp ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
            WHERE p.id_torneo = %(torneo)s AND p.estado = 'jugado'
            GROUP BY p.id_partido, p.id_equipo_local, p.id_equipo_visitante
        ),
        resultados AS (
            SELECT id_equipo_local AS id_equipo, goles_local AS gf, goles_visitante AS gc FROM goles_por_partido
            UNION ALL
            SELECT id_equipo_visitante, goles_visitante, goles_local FROM goles_por_partido
        )
        SELECT e.nombre AS Equipo,
               COUNT(r.id_equipo) AS PJ,
               COALESCE(SUM(r.gf > r.gc), 0) AS PG,
               COALESCE(SUM(r.gf = r.gc), 0) AS PE,
               COALESCE(SUM(r.gf < r.gc), 0) AS PP,
               COALESCE(SUM(r.gf), 0) AS GF,
               COALESCE(SUM(r.gc), 0) AS GC,
               COALESCE(SUM(r.gf) - SUM(r.gc), 0) AS DG,
               COALESCE(SUM(CASE WHEN r.gf > r.gc THEN 3 WHEN r.gf = r.gc THEN 1 ELSE 0 END), 0) AS Puntos
        FROM equipo e
        LEFT JOIN resultados r ON r.id_equipo = e.id_equipo
        WHERE e.id_torneo = %(torneo)s
        GROUP BY e.id_equipo, e.nombre
        ORDER BY Puntos DESC, DG DESC, GF DESC, e.nombre"""),

    ("Tabla de goleadores", "Los 10 jugadores con mas goles (los autogoles no cuentan para el jugador).",
     """SELECT j.nombre AS Nombre, j.apellido AS Apellido, e.nombre AS Equipo, COUNT(*) AS Goles
        FROM gol g
        JOIN partido p           ON p.id_partido = g.id_partido
        JOIN jugador j           ON j.ci_jugador = g.ci_jugador
        JOIN planilla_partido pp ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
        JOIN equipo e            ON e.id_equipo = pp.id_equipo
        WHERE p.id_torneo = %(torneo)s AND g.autogol = FALSE
        GROUP BY j.ci_jugador, j.nombre, j.apellido, e.nombre
        ORDER BY Goles DESC, j.apellido
        LIMIT 10"""),

    ("Fair play por equipo", "1 punto por amarilla y 3 por roja. El mejor equipo es el de menor puntaje.",
     """SELECT e.nombre AS Equipo,
               COALESCE(SUM(t.color = 'amarilla'), 0) AS Amarillas,
               COALESCE(SUM(t.color = 'roja'), 0) AS Rojas,
               COALESCE(SUM(CASE WHEN t.color = 'amarilla' THEN 1 WHEN t.color = 'roja' THEN 3 ELSE 0 END), 0)
                   AS Puntaje
        FROM equipo e
        LEFT JOIN planilla_partido pp ON pp.id_equipo = e.id_equipo
        LEFT JOIN tarjeta t           ON t.id_partido = pp.id_partido AND t.ci_jugador = pp.ci_jugador
        WHERE e.id_torneo = %(torneo)s
        GROUP BY e.id_equipo, e.nombre
        ORDER BY Puntaje ASC, e.nombre"""),

    ("Promedio de goles por partido en cada fecha", "Solo partidos jugados.",
     """SELECT p.numero_fecha AS Fecha,
               COUNT(DISTINCT p.id_partido) AS `Partidos jugados`,
               COUNT(g.id_gol) AS Goles,
               ROUND(COUNT(g.id_gol) / COUNT(DISTINCT p.id_partido), 2) AS Promedio
        FROM partido p
        LEFT JOIN gol g ON g.id_partido = p.id_partido
        WHERE p.id_torneo = %(torneo)s AND p.estado = 'jugado'
        GROUP BY p.numero_fecha
        ORDER BY p.numero_fecha"""),

    ("Promedio de goles por partido en toda la edicion", "Solo partidos jugados.",
     """SELECT COUNT(DISTINCT p.id_partido) AS `Partidos jugados`,
               COUNT(g.id_gol) AS Goles,
               ROUND(COUNT(g.id_gol) / NULLIF(COUNT(DISTINCT p.id_partido), 0), 2) AS Promedio
        FROM partido p
        LEFT JOIN gol g ON g.id_partido = p.id_partido
        WHERE p.id_torneo = %(torneo)s AND p.estado = 'jugado'"""),

    ("Canchas mas utilizadas", "Cuenta partidos jugados y programados.",
     """SELECT c.nombre_cancha AS Cancha, co.nombre AS Complejo, COUNT(*) AS Partidos
        FROM partido p
        JOIN cancha c    ON c.id_cancha = p.id_cancha
        JOIN complejo co ON co.id_complejo = c.id_complejo
        WHERE p.id_torneo = %(torneo)s AND p.estado IN ('jugado', 'programado')
        GROUP BY c.id_cancha, c.nombre_cancha, co.nombre
        ORDER BY Partidos DESC"""),

    ("Turnos mas utilizados", "Cuenta partidos jugados y programados.",
     """SELECT CONCAT(t.hora_inicio, ':00 a ', t.hora_fin, ':00') AS Turno, COUNT(*) AS Partidos
        FROM partido p
        JOIN turno t ON t.id_turno = p.id_turno
        WHERE p.id_torneo = %(torneo)s AND p.estado IN ('jugado', 'programado')
        GROUP BY t.id_turno, t.hora_inicio, t.hora_fin
        ORDER BY Partidos DESC, t.hora_inicio"""),

    ("Jugadores por facultad y por tipo", "Todos los jugadores registrados en el sistema.",
     """SELECT f.nombre AS Facultad, j.tipo AS Tipo, COUNT(*) AS Cantidad
        FROM jugador j
        JOIN facultad f ON f.id_facultad = j.id_facultad
        GROUP BY f.nombre, j.tipo
        ORDER BY f.nombre, j.tipo"""),

    ("Inscriptos que nunca figuraron en una planilla", "Jugadores del plantel que todavia no jugaron en esta edicion.",
     """SELECT j.ci_jugador AS CI, j.nombre AS Nombre, j.apellido AS Apellido, e.nombre AS Equipo
        FROM equipo_jugador_torneo ejt
        JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
        JOIN equipo e  ON e.id_equipo = ejt.id_equipo
        WHERE ejt.id_torneo = %(torneo)s
          AND NOT EXISTS (SELECT 1 FROM planilla_partido pp
                          JOIN partido p ON p.id_partido = pp.id_partido
                          WHERE pp.ci_jugador = ejt.ci_jugador AND p.id_torneo = ejt.id_torneo)
        ORDER BY e.nombre, j.apellido"""),

    ("Sanciones por equipo y por motivo", "",
     """SELECT e.nombre AS Equipo, s.motivo AS Motivo, COUNT(*) AS Cantidad
        FROM sancion_jugador s
        JOIN equipo_jugador_torneo ejt ON ejt.ci_jugador = s.ci_jugador AND ejt.id_torneo = s.id_torneo
        JOIN equipo e                  ON e.id_equipo = ejt.id_equipo
        WHERE s.id_torneo = %(torneo)s
        GROUP BY e.nombre, s.motivo
        ORDER BY e.nombre, s.motivo"""),

    ("Partidos jugados vs. postergados / cancelados", "Porcentaje sobre el total de partidos de la edicion.",
     """SELECT estado AS Estado, COUNT(*) AS Partidos,
               ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS Porcentaje
        FROM partido
        WHERE id_torneo = %(torneo)s
        GROUP BY estado
        ORDER BY Partidos DESC"""),

    ("Extra 1: resultados de los partidos jugados", "Consulta propia: el marcador de cada partido.",
     f"""SELECT p.numero_fecha AS Fecha, p.dia AS Dia, el.nombre AS Local,
                {SQL_GOLES.format(a="local", b="visitante")} AS `Goles local`,
                {SQL_GOLES.format(a="visitante", b="local")} AS `Goles visitante`,
                ev.nombre AS Visitante
         FROM partido p
         JOIN equipo el ON el.id_equipo = p.id_equipo_local
         JOIN equipo ev ON ev.id_equipo = p.id_equipo_visitante
         WHERE p.id_torneo = %(torneo)s AND p.estado = 'jugado'
         ORDER BY p.numero_fecha, p.dia, p.id_turno"""),

    ("Extra 2: jugadores suspendidos en la fecha elegida",
     "Consulta propia: ayuda al planillero y al administrador a saber quien no puede jugar.",
     """SELECT j.ci_jugador AS CI, j.nombre AS Nombre, j.apellido AS Apellido, s.motivo AS Motivo,
               s.numero_fecha_inicio AS `Desde fecha`, s.numero_fecha_inicio + s.cantidad_fechas - 1 AS `Hasta fecha`
        FROM sancion_jugador s
        JOIN jugador j ON j.ci_jugador = s.ci_jugador
        WHERE s.id_torneo = %(torneo)s
          AND %(fecha)s BETWEEN s.numero_fecha_inicio AND s.numero_fecha_inicio + s.cantidad_fechas - 1
        ORDER BY j.apellido"""),

    ("Extra 3: jugadores en riesgo de suspension",
     "Consulta propia: les falta una amarilla para llegar a la siguiente suspension por acumulacion.",
     """SELECT j.ci_jugador AS CI, j.nombre AS Nombre, j.apellido AS Apellido, COUNT(*) AS Amarillas
        FROM tarjeta t
        JOIN partido p ON p.id_partido = t.id_partido
        JOIN jugador j ON j.ci_jugador = t.ci_jugador
        WHERE p.id_torneo = %(torneo)s AND t.color = 'amarilla'
        GROUP BY j.ci_jugador, j.nombre, j.apellido
        HAVING MOD(COUNT(*), 3) = 2
        ORDER BY j.apellido"""),
]


def consultar_tabla(sql, params):
    cursor = conexion().cursor()
    cursor.execute(sql, params)
    filas = cursor.fetchall()
    columnas = list(cursor.column_names)
    cursor.close()
    return columnas, filas


@bp.route("/")
@solo_admin
def ver():
    id_torneo = torneo_activo()
    # por defecto, la proxima fecha a jugarse
    proxima = consultar_uno(
        """SELECT COALESCE(MIN(CASE WHEN estado = 'programado' THEN numero_fecha END),
                           MAX(numero_fecha) + 1, 1) AS fecha
           FROM partido WHERE id_torneo = %s""", (id_torneo,))
    try:
        fecha = int(request.args.get("fecha", proxima["fecha"]))
        if fecha < 1:
            raise ValueError
    except ValueError:
        fecha = proxima["fecha"]
    parametros = {"torneo": id_torneo, "fecha": fecha}
    resultados = []
    for titulo, descripcion, sql in REPORTES:
        columnas, filas = consultar_tabla(sql, parametros)
        resultados.append({"titulo": titulo, "descripcion": descripcion, "columnas": columnas, "filas": filas})
    return render_template("reportes.html", reportes=resultados, fecha=fecha)
