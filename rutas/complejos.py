"""ABM de complejos deportivos y sus canchas."""
from flask import Blueprint, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, mostrar_errores, solo_admin
from validaciones import Validador

bp = Blueprint("complejos", __name__, url_prefix="/complejos")
SUPERFICIES = ("sintetico", "parquet")


@bp.route("/")
@solo_admin
def lista():
    complejos = consultar("SELECT * FROM complejo ORDER BY nombre")
    canchas = consultar("SELECT * FROM cancha ORDER BY nombre_cancha")
    for complejo in complejos:
        complejo["canchas"] = [c for c in canchas if c["id_complejo"] == complejo["id_complejo"]]
    return render_template("complejos.html", complejos=complejos)


@bp.route("/nuevo", methods=["GET", "POST"])
@bp.route("/<int:id_complejo>/editar", methods=["GET", "POST"])
@solo_admin
def formulario(id_complejo=None):
    complejo = consultar_uno("SELECT * FROM complejo WHERE id_complejo = %s", (id_complejo,)) if id_complejo else None
    if request.method == "POST":
        v = Validador(request.form)
        v.texto("nombre", "Nombre", 100)
        v.texto("direccion", "Direccion", 100)
        v.texto("departamento", "Departamento", 80)
        if v.ok:
            d = v.datos
            if id_complejo:
                accion = lambda: ejecutar(
                    "UPDATE complejo SET nombre=%s, direccion=%s, departamento=%s WHERE id_complejo=%s",
                    (d["nombre"], d["direccion"], d["departamento"], id_complejo))
            else:
                accion = lambda: ejecutar(
                    "INSERT INTO complejo (nombre, direccion, departamento) VALUES (%s, %s, %s)",
                    (d["nombre"], d["direccion"], d["departamento"]))
            if intentar(accion, "Complejo guardado."):
                return redirect(url_for("complejos.lista"))
        else:
            mostrar_errores(v)
        complejo = request.form.to_dict()
    return render_template("complejo_form.html", complejo=complejo, editando=bool(id_complejo))


@bp.route("/<int:id_complejo>/borrar", methods=["POST"])
@solo_admin
def borrar(id_complejo):
    intentar(lambda: ejecutar("DELETE FROM complejo WHERE id_complejo = %s", (id_complejo,)), "Complejo eliminado.")
    return redirect(url_for("complejos.lista"))


@bp.route("/<int:id_complejo>/canchas/nueva", methods=["GET", "POST"])
@bp.route("/canchas/<int:id_cancha>/editar", methods=["GET", "POST"])
@solo_admin
def cancha_formulario(id_complejo=None, id_cancha=None):
    cancha = consultar_uno("SELECT * FROM cancha WHERE id_cancha = %s", (id_cancha,)) if id_cancha else None
    if cancha:
        id_complejo = cancha["id_complejo"]
    complejo = consultar_uno("SELECT * FROM complejo WHERE id_complejo = %s", (id_complejo,))
    if not complejo:
        return redirect(url_for("complejos.lista"))
    if request.method == "POST":
        v = Validador(request.form)
        v.texto("nombre_cancha", "Nombre de la cancha", 80)
        v.opcion("superficie", "Superficie", SUPERFICIES)
        v.booleano("techada")
        if v.ok:
            d = v.datos
            if id_cancha:
                accion = lambda: ejecutar(
                    "UPDATE cancha SET nombre_cancha=%s, superficie=%s, techada=%s WHERE id_cancha=%s",
                    (d["nombre_cancha"], d["superficie"], d["techada"], id_cancha))
            else:
                accion = lambda: ejecutar(
                    "INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES (%s, %s, %s, %s)",
                    (d["nombre_cancha"], id_complejo, d["superficie"], d["techada"]))
            if intentar(accion, "Cancha guardada."):
                return redirect(url_for("complejos.lista"))
        else:
            mostrar_errores(v)
        cancha = request.form.to_dict()
        cancha["techada"] = request.form.get("techada") == "1"
    return render_template("cancha_form.html", cancha=cancha, complejo=complejo,
                           superficies=SUPERFICIES, editando=bool(id_cancha))


@bp.route("/canchas/<int:id_cancha>/borrar", methods=["POST"])
@solo_admin
def cancha_borrar(id_cancha):
    intentar(lambda: ejecutar("DELETE FROM cancha WHERE id_cancha = %s", (id_cancha,)), "Cancha eliminada.")
    return redirect(url_for("complejos.lista"))
