"""Registro de la planilla de juego: quiénes jugaron, goles y tarjetas. Lo usan planilleros y administradores.
La base de datos controla: plantel, suspendidos, que el jugador figure en la planilla, ventana de 48 horas
y genera las sanciones automaticas por tarjetas."""
from flask import Blueprint, flash, redirect, render_template, request, url_for

from db import consultar, ejecutar
from rutas.partidos import buscar_partido
from utiles import intentar, login_requerido, mostrar_errores
from validaciones import Validador

bp = Blueprint("planillas", __name__, url_prefix="/planilla")


def jugadores_del_equipo(partido, id_equipo):
    """Plantel del equipo, marcando quien figura en la planilla y quien esta suspendido en esa fecha."""
    return consultar(
        """SELECT j.ci_jugador, j.nombre, j.apellido, ejt.numero_camiseta,
                  EXISTS (SELECT 1 FROM planilla_partido pp
                          WHERE pp.id_partido = %s AND pp.ci_jugador = j.ci_jugador) AS en_planilla,
                  EXISTS (SELECT 1 FROM sancion_jugador s
                          WHERE s.ci_jugador = j.ci_jugador AND s.id_torneo = %s
                            AND %s BETWEEN s.numero_fecha_inicio
                                       AND s.numero_fecha_inicio + s.cantidad_fechas - 1) AS suspendido
           FROM equipo_jugador_torneo ejt
           JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
           WHERE ejt.id_equipo = %s
           ORDER BY ejt.numero_camiseta""",
        (partido["id_partido"], partido["id_torneo"], partido["numero_fecha"], id_equipo))


@bp.route("/<int:id_partido>")
@login_requerido
def ver(id_partido):
    partido = buscar_partido(id_partido)
    if not partido:
        flash("El partido no existe.", "error")
        return redirect(url_for("partidos.lista"))
    plantel_local = jugadores_del_equipo(partido, partido["id_equipo_local"])
    plantel_visitante = jugadores_del_equipo(partido, partido["id_equipo_visitante"])
    en_planilla = consultar(
        """SELECT j.ci_jugador, j.nombre, j.apellido, e.nombre AS equipo
           FROM planilla_partido pp
           JOIN jugador j ON j.ci_jugador = pp.ci_jugador
           JOIN equipo e  ON e.id_equipo = pp.id_equipo
           WHERE pp.id_partido = %s ORDER BY e.nombre, j.apellido""", (id_partido,))
    goles = consultar(
        """SELECT g.id_gol, g.minuto, g.autogol, j.nombre, j.apellido, e.nombre AS equipo
           FROM gol g
           JOIN jugador j ON j.ci_jugador = g.ci_jugador
           JOIN planilla_partido pp ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
           JOIN equipo e ON e.id_equipo = pp.id_equipo
           WHERE g.id_partido = %s ORDER BY g.minuto""", (id_partido,))
    tarjetas = consultar(
        """SELECT t.id_tarjeta, t.minuto, t.color, j.nombre, j.apellido, e.nombre AS equipo
           FROM tarjeta t
           JOIN jugador j ON j.ci_jugador = t.ci_jugador
           JOIN planilla_partido pp ON pp.id_partido = t.id_partido AND pp.ci_jugador = t.ci_jugador
           JOIN equipo e ON e.id_equipo = pp.id_equipo
           WHERE t.id_partido = %s ORDER BY t.minuto""", (id_partido,))
    return render_template("planilla.html", partido=partido, plantel_local=plantel_local,
                           plantel_visitante=plantel_visitante, en_planilla=en_planilla,
                           goles=goles, tarjetas=tarjetas)


@bp.route("/<int:id_partido>/jugadores", methods=["POST"])
@login_requerido
def guardar_jugadores(id_partido):
    """Recibe las casillas marcadas y deja la planilla igual a esa seleccion (agrega y quita)."""
    partido = buscar_partido(id_partido)
    if not partido:
        return redirect(url_for("partidos.lista"))
    seleccion = {}
    for id_equipo in (partido["id_equipo_local"], partido["id_equipo_visitante"]):
        for valor in request.form.getlist(f"equipo_{id_equipo}"):
            if not valor.isdigit():
                flash("Seleccion de jugadores invalida.", "error")
                return redirect(url_for("planillas.ver", id_partido=id_partido))
            seleccion[int(valor)] = id_equipo
    actuales = {f["ci_jugador"] for f in consultar(
        "SELECT ci_jugador FROM planilla_partido WHERE id_partido = %s", (id_partido,))}

    def accion():
        for ci in actuales - seleccion.keys():
            ejecutar("DELETE FROM planilla_partido WHERE id_partido = %s AND ci_jugador = %s", (id_partido, ci))
        for ci in seleccion.keys() - actuales:
            ejecutar("INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo) VALUES (%s, %s, %s)",
                     (id_partido, ci, seleccion[ci]))

    intentar(accion, "Planilla guardada.")
    return redirect(url_for("planillas.ver", id_partido=id_partido))


@bp.route("/<int:id_partido>/goles", methods=["POST"])
@login_requerido
def agregar_gol(id_partido):
    v = Validador(request.form)
    v.entero("ci_jugador", "Jugador", 1)
    v.entero("minuto", "Minuto", 1, 60)
    v.booleano("autogol")
    if v.ok:
        intentar(lambda: ejecutar(
            "INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES (%s, %s, %s, %s)",
            (id_partido, v.datos["ci_jugador"], v.datos["minuto"], v.datos["autogol"])), "Gol registrado.")
    else:
        mostrar_errores(v)
    return redirect(url_for("planillas.ver", id_partido=id_partido))


@bp.route("/<int:id_partido>/goles/<int:id_gol>/borrar", methods=["POST"])
@login_requerido
def borrar_gol(id_partido, id_gol):
    intentar(lambda: ejecutar("DELETE FROM gol WHERE id_gol = %s AND id_partido = %s", (id_gol, id_partido)),
             "Gol eliminado.")
    return redirect(url_for("planillas.ver", id_partido=id_partido))


@bp.route("/<int:id_partido>/tarjetas", methods=["POST"])
@login_requerido
def agregar_tarjeta(id_partido):
    v = Validador(request.form)
    v.entero("ci_jugador", "Jugador", 1)
    v.entero("minuto", "Minuto", 1, 60)
    v.opcion("color", "Color", ("amarilla", "roja"))
    if v.ok:
        intentar(lambda: ejecutar(
            "INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES (%s, %s, %s, %s)",
            (id_partido, v.datos["ci_jugador"], v.datos["minuto"], v.datos["color"])),
            "Tarjeta registrada (si corresponde, la sancion se genera automaticamente).")
    else:
        mostrar_errores(v)
    return redirect(url_for("planillas.ver", id_partido=id_partido))


@bp.route("/<int:id_partido>/tarjetas/<int:id_tarjeta>/borrar", methods=["POST"])
@login_requerido
def borrar_tarjeta(id_partido, id_tarjeta):
    intentar(lambda: ejecutar("DELETE FROM tarjeta WHERE id_tarjeta = %s AND id_partido = %s",
                              (id_tarjeta, id_partido)), "Tarjeta eliminada.")
    return redirect(url_for("planillas.ver", id_partido=id_partido))


@bp.route("/<int:id_partido>/jugado", methods=["POST"])
@login_requerido
def marcar_jugado(id_partido):
    intentar(lambda: ejecutar("UPDATE partido SET estado = 'jugado' WHERE id_partido = %s", (id_partido,)),
             "Partido marcado como jugado.")
    return redirect(url_for("planillas.ver", id_partido=id_partido))
