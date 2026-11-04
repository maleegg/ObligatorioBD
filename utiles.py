"""Funciones de apoyo que usan todas las paginas: control de acceso, torneo elegido, guardar con manejo de errores."""
from functools import wraps

from flask import flash, redirect, session, url_for
from mysql.connector import Error

from db import confirmar, consultar_uno, deshacer, mensaje_error


def login_requerido(vista):
    @wraps(vista)
    def envoltura(*args, **kwargs):
        if "rol" not in session:
            flash("Inicia sesion para continuar.", "error")
            return redirect(url_for("login"))
        return vista(*args, **kwargs)
    return envoltura


def solo_admin(vista):
    """Paginas solo para administradores. (La base igual lo impediria por permisos.)"""
    @wraps(vista)
    @login_requerido
    def envoltura(*args, **kwargs):
        if session.get("rol") != "administrador":
            flash("Esa seccion es solo para administradores.", "error")
            return redirect(url_for("inicio"))
        return vista(*args, **kwargs)
    return envoltura


def torneo_activo():
    """Devuelve el id del torneo elegido arriba en la pantalla (o el mas reciente en curso)."""
    id_torneo = session.get("id_torneo")
    if id_torneo and consultar_uno("SELECT 1 AS hay FROM torneo WHERE id_torneo = %s", (id_torneo,)):
        return id_torneo
    fila = consultar_uno(
        "SELECT id_torneo FROM torneo ORDER BY (estado = 'en curso') DESC, anio DESC, semestre DESC LIMIT 1"
    )
    session["id_torneo"] = fila["id_torneo"] if fila else None
    return session["id_torneo"]


def intentar(accion, mensaje_ok):
    """Ejecuta 'accion' (que hace INSERT/UPDATE/DELETE) como una sola transaccion.
    Si la base rechaza algo (trigger, CHECK, clave repetida...), se deshace todo y se muestra el motivo."""
    try:
        accion()
        confirmar()
        flash(mensaje_ok, "ok")
        return True
    except Error as e:
        deshacer()
        flash(mensaje_error(e), "error")
        return False


def mostrar_errores(validador):
    for error in validador.errores:
        flash(error, "error")
