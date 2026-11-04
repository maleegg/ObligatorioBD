"""ABM de sanciones. Las de tarjeta roja y acumulacion de amarillas las crea la base automaticamente;
el administrador puede ademas cargar sanciones disciplinarias de varias fechas (o corregir cualquiera)."""
from flask import Blueprint, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, mostrar_errores, solo_admin, torneo_activo
from validaciones import Validador

bp = Blueprint("sanciones", __name__, url_prefix="/sanciones")
MOTIVOS = ("roja", "acumulacion de amarillas", "disciplinaria")


@bp.route("/")
@solo_admin
def lista():
    sanciones = consultar(
        """SELECT s.*, j.nombre, j.apellido, e.nombre AS equipo,
                  s.numero_fecha_inicio + s.cantidad_fechas - 1 AS fecha_fin
           FROM sancion_jugador s
           JOIN jugador j ON j.ci_jugador = s.ci_jugador
           LEFT JOIN equipo_jugador_torneo ejt ON ejt.ci_jugador = s.ci_jugador AND ejt.id_torneo = s.id_torneo
           LEFT JOIN equipo e ON e.id_equipo = ejt.id_equipo
           WHERE s.id_torneo = %s
           ORDER BY s.numero_fecha_inicio, j.apellido""", (torneo_activo(),))
    return render_template("sanciones.html", sanciones=sanciones)


@bp.route("/nueva", methods=["GET", "POST"])
@bp.route("/<int:id_sancion>/editar", methods=["GET", "POST"])
@solo_admin
def formulario(id_sancion=None):
    sancion = consultar_uno("SELECT * FROM sancion_jugador WHERE id_sancion = %s", (id_sancion,)) if id_sancion else None
    id_torneo = sancion["id_torneo"] if sancion else torneo_activo()
    if request.method == "POST":
        v = Validador(request.form)
        v.entero("ci_jugador", "Jugador", 1)
        v.opcion("motivo", "Motivo", MOTIVOS)
        v.entero("numero_fecha_inicio", "Fecha de inicio", 1, 50)
        v.entero("cantidad_fechas", "Cantidad de fechas", 1, 50)
        if v.ok:
            d = v.datos
            valores = (d["ci_jugador"], d["motivo"], d["numero_fecha_inicio"], d["cantidad_fechas"])
            if id_sancion:
                accion = lambda: ejecutar(
                    """UPDATE sancion_jugador SET ci_jugador=%s, motivo=%s, numero_fecha_inicio=%s, cantidad_fechas=%s
                       WHERE id_sancion=%s""", valores + (id_sancion,))
            else:
                accion = lambda: ejecutar(
                    """INSERT INTO sancion_jugador (ci_jugador, motivo, numero_fecha_inicio, cantidad_fechas, id_torneo)
                       VALUES (%s, %s, %s, %s, %s)""", valores + (id_torneo,))
            if intentar(accion, "Sancion guardada."):
                return redirect(url_for("sanciones.lista"))
        else:
            mostrar_errores(v)
        sancion = request.form.to_dict()
    jugadores = consultar(
        """SELECT j.ci_jugador, j.nombre, j.apellido, e.nombre AS equipo
           FROM equipo_jugador_torneo ejt
           JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
           JOIN equipo e  ON e.id_equipo = ejt.id_equipo
           WHERE ejt.id_torneo = %s ORDER BY e.nombre, j.apellido""", (id_torneo,))
    return render_template("sancion_form.html", sancion=sancion, jugadores=jugadores,
                           motivos=MOTIVOS, editando=bool(id_sancion))


@bp.route("/<int:id_sancion>/borrar", methods=["POST"])
@solo_admin
def borrar(id_sancion):
    intentar(lambda: ejecutar("DELETE FROM sancion_jugador WHERE id_sancion = %s", (id_sancion,)),
             "Sancion eliminada.")
    return redirect(url_for("sanciones.lista"))
