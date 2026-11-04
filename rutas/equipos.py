"""ABM de equipos y de sus planteles (jugadores inscriptos en cada equipo)."""
from flask import Blueprint, flash, redirect, render_template, request, url_for

from db import consultar, consultar_uno, ejecutar
from utiles import intentar, mostrar_errores, solo_admin, torneo_activo
from validaciones import Validador

bp = Blueprint("equipos", __name__, url_prefix="/equipos")


def buscar_equipo(id_equipo):
    return consultar_uno(
        """SELECT e.*, f.nombre AS facultad, t.nombre AS torneo, t.estado AS estado_torneo
           FROM equipo e
           JOIN facultad f ON f.id_facultad = e.id_facultad
           JOIN torneo t   ON t.id_torneo = e.id_torneo
           WHERE e.id_equipo = %s""", (id_equipo,))


@bp.route("/")
@solo_admin
def lista():
    id_torneo = torneo_activo()
    equipos = consultar(
        """SELECT e.id_equipo, e.nombre, f.nombre AS facultad,
                  CONCAT(j.nombre, ' ', j.apellido) AS capitan,
                  (SELECT COUNT(*) FROM equipo_jugador_torneo x WHERE x.id_equipo = e.id_equipo) AS jugadores
           FROM equipo e
           JOIN facultad f ON f.id_facultad = e.id_facultad
           JOIN jugador j  ON j.ci_jugador = e.ci_capitan
           WHERE e.id_torneo = %s
           ORDER BY e.nombre""", (id_torneo,))
    torneo = consultar_uno("SELECT * FROM torneo WHERE id_torneo = %s", (id_torneo,))
    return render_template("equipos.html", equipos=equipos, torneo=torneo)


@bp.route("/nuevo", methods=["GET", "POST"])
@solo_admin
def nuevo():
    id_torneo = torneo_activo()
    torneo = consultar_uno("SELECT * FROM torneo WHERE id_torneo = %s", (id_torneo,))
    if request.method == "POST":
        v = Validador(request.form)
        v.texto("nombre", "Nombre", 20)
        v.entero("id_facultad", "Facultad", 1)
        v.entero("ci_capitan", "Capitan", 1)
        v.entero("numero_camiseta", "Camiseta del capitan", 1, 99)
        if v.ok:
            d = v.datos

            def accion():
                # El equipo y su capitan en el plantel se guardan juntos: o se guardan ambos o ninguno
                id_equipo = ejecutar(
                    "INSERT INTO equipo (nombre, id_torneo, id_facultad, ci_capitan) VALUES (%s, %s, %s, %s)",
                    (d["nombre"], id_torneo, d["id_facultad"], d["ci_capitan"]))
                ejecutar(
                    """INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta)
                       VALUES (%s, %s, %s, %s)""", (id_equipo, d["ci_capitan"], id_torneo, d["numero_camiseta"]))

            if intentar(accion, "Equipo inscripto. Ahora agregue el resto del plantel (minimo 5 jugadores)."):
                return redirect(url_for("equipos.lista"))
        else:
            mostrar_errores(v)
    facultades = consultar("SELECT * FROM facultad ORDER BY nombre")
    # candidatos a capitan: jugadores que no estan en ningun equipo de esta edicion
    candidatos = consultar(
        """SELECT j.ci_jugador, j.nombre, j.apellido, j.id_facultad, f.nombre AS facultad
           FROM jugador j JOIN facultad f ON f.id_facultad = j.id_facultad
           WHERE NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo x
                             WHERE x.ci_jugador = j.ci_jugador AND x.id_torneo = %s)
           ORDER BY f.nombre, j.apellido""", (id_torneo,))
    return render_template("equipo_nuevo.html", torneo=torneo, facultades=facultades,
                           candidatos=candidatos, datos=request.form)


@bp.route("/<int:id_equipo>", methods=["GET"])
@solo_admin
def plantel(id_equipo):
    equipo = buscar_equipo(id_equipo)
    if not equipo:
        flash("El equipo no existe.", "error")
        return redirect(url_for("equipos.lista"))
    jugadores = consultar(
        """SELECT ejt.numero_camiseta, j.ci_jugador, j.nombre, j.apellido, j.tipo
           FROM equipo_jugador_torneo ejt JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
           WHERE ejt.id_equipo = %s ORDER BY ejt.numero_camiseta""", (id_equipo,))
    disponibles = consultar(
        """SELECT j.ci_jugador, j.nombre, j.apellido, j.tipo
           FROM jugador j
           WHERE j.id_facultad = %s
             AND NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo x
                             WHERE x.ci_jugador = j.ci_jugador AND x.id_torneo = %s)
           ORDER BY j.apellido""", (equipo["id_facultad"], equipo["id_torneo"]))
    return render_template("equipo_plantel.html", equipo=equipo, jugadores=jugadores, disponibles=disponibles)


@bp.route("/<int:id_equipo>/editar", methods=["POST"])
@solo_admin
def editar(id_equipo):
    v = Validador(request.form)
    v.texto("nombre", "Nombre", 20)
    v.entero("ci_capitan", "Capitan", 1)
    if v.ok:
        intentar(lambda: ejecutar("UPDATE equipo SET nombre = %s, ci_capitan = %s WHERE id_equipo = %s",
                                  (v.datos["nombre"], v.datos["ci_capitan"], id_equipo)),
                 "Equipo actualizado.")
    else:
        mostrar_errores(v)
    return redirect(url_for("equipos.plantel", id_equipo=id_equipo))


@bp.route("/<int:id_equipo>/jugadores", methods=["POST"])
@solo_admin
def agregar_jugador(id_equipo):
    equipo = buscar_equipo(id_equipo)
    v = Validador(request.form)
    v.entero("ci_jugador", "Jugador", 1)
    v.entero("numero_camiseta", "Numero de camiseta", 1, 99)
    if equipo and v.ok:
        intentar(lambda: ejecutar(
            """INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta)
               VALUES (%s, %s, %s, %s)""",
            (id_equipo, v.datos["ci_jugador"], equipo["id_torneo"], v.datos["numero_camiseta"])),
            "Jugador agregado al plantel.")
    else:
        mostrar_errores(v)
    return redirect(url_for("equipos.plantel", id_equipo=id_equipo))


@bp.route("/<int:id_equipo>/jugadores/<int:ci>/camiseta", methods=["POST"])
@solo_admin
def cambiar_camiseta(id_equipo, ci):
    v = Validador(request.form)
    v.entero("numero_camiseta", "Numero de camiseta", 1, 99)
    if v.ok:
        intentar(lambda: ejecutar(
            "UPDATE equipo_jugador_torneo SET numero_camiseta = %s WHERE id_equipo = %s AND ci_jugador = %s",
            (v.datos["numero_camiseta"], id_equipo, ci)), "Camiseta actualizada.")
    else:
        mostrar_errores(v)
    return redirect(url_for("equipos.plantel", id_equipo=id_equipo))


@bp.route("/<int:id_equipo>/jugadores/<int:ci>/quitar", methods=["POST"])
@solo_admin
def quitar_jugador(id_equipo, ci):
    equipo = buscar_equipo(id_equipo)
    if equipo and equipo["ci_capitan"] == ci:
        flash("No se puede quitar al capitan: primero elija otro capitan.", "error")
    else:
        intentar(lambda: ejecutar(
            "DELETE FROM equipo_jugador_torneo WHERE id_equipo = %s AND ci_jugador = %s", (id_equipo, ci)),
            "Jugador quitado del plantel.")
    return redirect(url_for("equipos.plantel", id_equipo=id_equipo))


@bp.route("/<int:id_equipo>/borrar", methods=["POST"])
@solo_admin
def borrar(id_equipo):
    def accion():
        ejecutar("DELETE FROM equipo_jugador_torneo WHERE id_equipo = %s", (id_equipo,))
        ejecutar("DELETE FROM equipo WHERE id_equipo = %s", (id_equipo,))
    intentar(accion, "Equipo eliminado.")
    return redirect(url_for("equipos.lista"))
