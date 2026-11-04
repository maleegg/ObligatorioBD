"""ABM de jugadores."""
from datetime import date

from flask import Blueprint, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, mostrar_errores, solo_admin
from validaciones import Validador

bp = Blueprint("jugadores", __name__, url_prefix="/jugadores")
TIPOS = ("grado", "posgrado", "docente", "funcionario")


def validar(formulario, editando):
    v = Validador(formulario)
    if not editando:  # la cedula es la clave: no se cambia al editar
        v.entero("ci_jugador", "Cedula", 1, 99999999)
    v.texto("nombre", "Nombre", 20)
    v.texto("apellido", "Apellido", 40)
    v.email("email", "Email")
    v.fecha("fecha_nacimiento", "Fecha de nacimiento", maxima=date.today())
    v.entero("id_facultad", "Facultad", 1)
    v.opcion("tipo", "Tipo", TIPOS)
    return v


@bp.route("/")
@solo_admin
def lista():
    buscar = (request.args.get("buscar") or "").strip()
    filtro = f"%{buscar}%"
    jugadores = consultar(
        """SELECT j.*, f.nombre AS facultad
           FROM jugador j JOIN facultad f ON f.id_facultad = j.id_facultad
           WHERE %s = '' OR j.nombre LIKE %s OR j.apellido LIKE %s OR CAST(j.ci_jugador AS CHAR) LIKE %s
           ORDER BY j.apellido, j.nombre""",
        (buscar, filtro, filtro, filtro))
    return render_template("jugadores.html", jugadores=jugadores, buscar=buscar)


@bp.route("/nuevo", methods=["GET", "POST"])
@bp.route("/<int:ci>/editar", methods=["GET", "POST"])
@solo_admin
def formulario(ci=None):
    jugador = consultar_uno("SELECT * FROM jugador WHERE ci_jugador = %s", (ci,)) if ci else None
    if request.method == "POST":
        v = validar(request.form, editando=bool(ci))
        if v.ok:
            d = v.datos
            datos = (d["nombre"], d["apellido"], d["email"], d["fecha_nacimiento"], d["id_facultad"], d["tipo"])
            if ci:
                accion = lambda: ejecutar(
                    """UPDATE jugador SET nombre=%s, apellido=%s, email=%s, fecha_nacimiento=%s,
                              id_facultad=%s, tipo=%s
                       WHERE ci_jugador=%s""", datos + (ci,))
            else:
                accion = lambda: ejecutar(
                    """INSERT INTO jugador (ci_jugador, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo)
                       VALUES (%s, %s, %s, %s, %s, %s, %s)""", (d["ci_jugador"],) + datos)
            if intentar(accion, "Jugador guardado."):
                return redirect(url_for("jugadores.lista"))
        else:
            mostrar_errores(v)
        jugador = request.form.to_dict()
        if ci:
            jugador["ci_jugador"] = ci
    facultades = consultar("SELECT * FROM facultad ORDER BY nombre")
    return render_template("jugador_form.html", jugador=jugador, facultades=facultades,
                           tipos=TIPOS, editando=bool(ci), hoy=date.today().isoformat())


@bp.route("/<int:ci>/borrar", methods=["POST"])
@solo_admin
def borrar(ci):
    intentar(lambda: ejecutar("DELETE FROM jugador WHERE ci_jugador = %s", (ci,)), "Jugador eliminado.")
    return redirect(url_for("jugadores.lista"))
