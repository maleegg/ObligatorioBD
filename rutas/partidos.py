"""ABM de partidos (fixture). Las reglas de programacion las controla la base de datos con triggers;
aca se valida el formato de los datos y se muestra el motivo si la base rechaza algo."""
from datetime import date

from flask import Blueprint, flash, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, login_requerido, mostrar_errores, solo_admin, torneo_activo
from validaciones import Validador

bp = Blueprint("partidos", __name__, url_prefix="/partidos")
ESTADOS = ("programado", "jugado", "postergado", "cancelado")

# Goles de cada equipo: un gol cuenta para el equipo del jugador, salvo que sea gol en contra, que cuenta como gol para el equipo contrario.
SQL_GOLES = """(SELECT COUNT(*) FROM gol g
                JOIN planilla_partido pp ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
                WHERE g.id_partido = p.id_partido
                  AND ((pp.id_equipo = p.id_equipo_{a} AND g.autogol = FALSE)
                    OR (pp.id_equipo = p.id_equipo_{b} AND g.autogol = TRUE)))"""

SQL_PARTIDOS = f"""
    SELECT p.*, t.hora_inicio, t.hora_fin,
           el.nombre AS local, ev.nombre AS visitante,
           c.nombre_cancha, co.nombre AS complejo,
           {SQL_GOLES.format(a="local", b="visitante")} AS goles_local,
           {SQL_GOLES.format(a="visitante", b="local")} AS goles_visitante,
           TIMESTAMP(p.dia, MAKETIME(t.hora_fin, 0, 0)) <= NOW() AS ya_paso
    FROM partido p
    JOIN turno t     ON t.id_turno = p.id_turno
    JOIN equipo el   ON el.id_equipo = p.id_equipo_local
    JOIN equipo ev   ON ev.id_equipo = p.id_equipo_visitante
    JOIN cancha c    ON c.id_cancha = p.id_cancha
    JOIN complejo co ON co.id_complejo = c.id_complejo
"""


def buscar_partido(id_partido):
    return consultar_uno(SQL_PARTIDOS + " WHERE p.id_partido = %s", (id_partido,))


@bp.route("/")
@login_requerido
def lista():
    id_torneo = torneo_activo()
    partidos = consultar(SQL_PARTIDOS + " WHERE p.id_torneo = %s ORDER BY p.numero_fecha, p.dia, t.hora_inicio",
                         (id_torneo,))
    return render_template("partidos.html", partidos=partidos)


def opciones_formulario(id_torneo):
    return {
        "equipos": consultar("SELECT id_equipo, nombre FROM equipo WHERE id_torneo = %s ORDER BY nombre", (id_torneo,)),
        "canchas": consultar(
            """SELECT c.id_cancha, c.nombre_cancha, co.nombre AS complejo
               FROM cancha c JOIN complejo co ON co.id_complejo = c.id_complejo
               ORDER BY co.nombre, c.nombre_cancha"""),
        "turnos": consultar("SELECT * FROM turno ORDER BY hora_inicio"),
        "torneo": consultar_uno("SELECT * FROM torneo WHERE id_torneo = %s", (id_torneo,)),
    }


@bp.route("/nuevo", methods=["GET", "POST"])
@bp.route("/<int:id_partido>/editar", methods=["GET", "POST"])
@solo_admin
def formulario(id_partido=None):
    partido = consultar_uno("SELECT * FROM partido WHERE id_partido = %s", (id_partido,)) if id_partido else None
    if id_partido and not partido:
        flash("El partido no existe.", "error")
        return redirect(url_for("partidos.lista"))
    id_torneo = partido["id_torneo"] if partido else torneo_activo()
    if partido and partido["estado"] == "jugado":
        flash("Un partido jugado no se puede modificar (solo se corrigen sus goles dentro de las 48 horas).", "error")
        return redirect(url_for("partidos.lista"))

    if request.method == "POST":
        v = Validador(request.form)
        v.entero("numero_fecha", "Numero de fecha", 1, 50)
        v.entero("id_equipo_local", "Equipo local", 1)
        v.entero("id_equipo_visitante", "Equipo visitante", 1)
        v.entero("id_cancha", "Cancha", 1)
        v.fecha("dia", "Dia")
        v.entero("id_turno", "Turno", 1)
        # al crear un partido siempre empieza "programado", se marca jugado desde la planilla
        estados_validos = ESTADOS if id_partido else ("programado",)
        v.opcion("estado", "Estado", estados_validos)
        d = v.datos
        if d["id_equipo_local"] and d["id_equipo_local"] == d["id_equipo_visitante"]:
            v.agregar_error("Un equipo no puede jugar contra si mismo.")
        if v.ok:
            valores = (d["numero_fecha"], d["id_equipo_local"], d["id_equipo_visitante"],
                       d["id_cancha"], d["dia"], d["id_turno"], d["estado"])
            if id_partido:
                accion = lambda: ejecutar(
                    """UPDATE partido SET numero_fecha=%s, id_equipo_local=%s, id_equipo_visitante=%s,
                              id_cancha=%s, dia=%s, id_turno=%s, estado=%s
                       WHERE id_partido=%s""", valores + (id_partido,))
            else:
                accion = lambda: ejecutar(
                    """INSERT INTO partido (numero_fecha, id_equipo_local, id_equipo_visitante,
                                            id_cancha, dia, id_turno, estado, id_torneo)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""", valores + (id_torneo,))
            if intentar(accion, "Partido guardado."):
                return redirect(url_for("partidos.lista"))
        else:
            mostrar_errores(v)
        partido = request.form.to_dict()

    return render_template("partido_form.html", partido=partido, editando=bool(id_partido),
                           estados=ESTADOS if id_partido else ("programado",), **opciones_formulario(id_torneo))


@bp.route("/<int:id_partido>/borrar", methods=["POST"])
@solo_admin
def borrar(id_partido):
    intentar(lambda: ejecutar("DELETE FROM partido WHERE id_partido = %s", (id_partido,)), "Partido eliminado.")
    return redirect(url_for("partidos.lista"))


@bp.app_template_filter("fecha_uy")
def fecha_uy(valor):
    """Muestra las fechas como dd/mm/aaaa."""
    if isinstance(valor, date):
        return valor.strftime("%d/%m/%Y")
    return "" if valor is None else valor
