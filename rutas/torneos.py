"""ABM de ediciones del torneo (necesario para pasar de inscripción a en curso y a finalizado)."""
from flask import Blueprint, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, mostrar_errores, solo_admin
from validaciones import Validador

bp = Blueprint("torneos", __name__, url_prefix="/torneos")
ESTADOS = ("inscripcion", "en curso", "finalizado")


def validar(formulario):
    v = Validador(formulario)
    v.texto("nombre", "Nombre", 20)
    v.entero("anio", "Anio", 2000, 2100)
    v.entero("semestre", "Semestre", 1, 2)
    v.fecha("fecha_inicio", "Fecha de inicio")
    v.fecha("fecha_fin", "Fecha de fin")
    v.opcion("estado", "Estado", ESTADOS)
    d = v.datos
    if d["fecha_inicio"] and d["fecha_fin"] and d["fecha_fin"] < d["fecha_inicio"]:
        v.agregar_error("La fecha de fin no puede ser anterior a la de inicio.")
    return v


@bp.route("/")
@solo_admin
def lista():
    torneos = consultar(
        """SELECT t.*, (SELECT COUNT(*) FROM equipo e WHERE e.id_torneo = t.id_torneo) AS equipos
           FROM torneo t ORDER BY anio DESC, semestre DESC""")
    return render_template("torneos.html", torneos=torneos)


@bp.route("/nuevo", methods=["GET", "POST"])
@bp.route("/<int:id_torneo>/editar", methods=["GET", "POST"])
@solo_admin
def formulario(id_torneo=None):
    torneo = consultar_uno("SELECT * FROM torneo WHERE id_torneo = %s", (id_torneo,)) if id_torneo else None
    if request.method == "POST":
        v = validar(request.form)
        if v.ok:
            d = v.datos
            valores = (d["nombre"], d["anio"], d["semestre"], d["fecha_inicio"], d["fecha_fin"], d["estado"])
            if id_torneo:
                accion = lambda: ejecutar(
                    """UPDATE torneo SET nombre=%s, anio=%s, semestre=%s, fecha_inicio=%s, fecha_fin=%s, estado=%s
                       WHERE id_torneo=%s""", valores + (id_torneo,))
            else:
                accion = lambda: ejecutar(
                    """INSERT INTO torneo (nombre, anio, semestre, fecha_inicio, fecha_fin, estado)
                       VALUES (%s, %s, %s, %s, %s, %s)""", valores)
            if intentar(accion, "Torneo guardado."):
                return redirect(url_for("torneos.lista"))
        else:
            mostrar_errores(v)
        torneo = request.form
    return render_template("torneo_form.html", torneo=torneo, estados=ESTADOS, editando=bool(id_torneo))


@bp.route("/<int:id_torneo>/borrar", methods=["POST"])
@solo_admin
def borrar(id_torneo):
    intentar(lambda: ejecutar("DELETE FROM torneo WHERE id_torneo = %s", (id_torneo,)), "Torneo eliminado.")
    return redirect(url_for("torneos.lista"))
