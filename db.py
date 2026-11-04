"""Conexion a MySQL sin ORM: todas las consultas se escriben en SQL a mano.

Cada rol de la app se conecta con SU PROPIO usuario de base de datos:
  - login_app          -> solo lee la tabla login (para verificar correo y contrasena)
  - admin_torneo       -> gestiona todos los datos
  - planillero_torneo  -> solo carga planillas, goles y tarjetas
Asi, aunque hubiera un error en la app, la base no deja que un planillero haga cosas de administrador.
"""
import os

import mysql.connector
from mysql.connector import Error, errorcode
from flask import g, session

CONFIG_BASE = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 3306)),
    "database": os.getenv("DB_NAME", "OBLIGATORIO"),
    "charset": "utf8mb4",
    "collation": "utf8mb4_spanish_ci",
    "autocommit": False,
    "use_pure": True,  # misma implementacion en cualquier maquina (la que se probo)
}

USUARIOS_BD = {
    "login": (os.getenv("DB_LOGIN_USER", "login_app"), os.getenv("DB_LOGIN_PASSWORD", "LoginApp_2026!")),
    "administrador": (os.getenv("DB_ADMIN_USER", "admin_torneo"), os.getenv("DB_ADMIN_PASSWORD", "Admin_Torneo_2026!")),
    "planillero": (os.getenv("DB_PLANILLERO_USER", "planillero_torneo"), os.getenv("DB_PLANILLERO_PASSWORD", "Planillero_2026!")),
}


def nueva_conexion(rol):
    usuario, clave = USUARIOS_BD[rol]
    cnx = mysql.connector.connect(user=usuario, password=clave, **CONFIG_BASE)
    cursor = cnx.cursor()
    # Uruguay es UTC-3 todo el ano. Las reglas "el partido ya paso" y "48 horas" usan NOW().
    cursor.execute("SET time_zone = '-03:00'")
    cursor.close()
    return cnx


def conexion():
    """Una conexion por pedido del navegador, con el usuario de BD del rol logueado."""
    if "cnx" not in g:
        g.cnx = nueva_conexion(session["rol"])
    return g.cnx


def cerrar_conexion(_error=None):
    cnx = g.pop("cnx", None)
    if cnx is not None:
        try:
            cnx.rollback()  # si algo quedo a medias, no se guarda
        finally:
            cnx.close()


def consultar(sql, params=()):
    """SELECT que devuelve una lista de diccionarios ({columna: valor})."""
    cursor = conexion().cursor(dictionary=True)
    cursor.execute(sql, params)
    filas = cursor.fetchall()
    cursor.close()
    return filas


def consultar_uno(sql, params=()):
    filas = consultar(sql, params)
    return filas[0] if filas else None


def ejecutar(sql, params=()):
    """INSERT / UPDATE / DELETE. No confirma: hay que llamar a confirmar()."""
    cursor = conexion().cursor()
    cursor.execute(sql, params)
    ultimo_id = cursor.lastrowid
    cursor.close()
    return ultimo_id


def confirmar():
    conexion().commit()


def deshacer():
    conexion().rollback()


def mensaje_error(e: Error) -> str:
    """Traduce los errores de MySQL a mensajes entendibles para el usuario."""
    if e.errno == errorcode.ER_SIGNAL_EXCEPTION:  # 1644: mensajes de nuestros triggers
        return e.msg
    if e.errno == errorcode.ER_DUP_ENTRY:
        return "Ya existe un registro con esos datos (hay un dato repetido que debe ser unico)."
    if e.errno in (errorcode.ER_ROW_IS_REFERENCED, errorcode.ER_ROW_IS_REFERENCED_2):
        return "No se puede borrar: hay otros datos que dependen de este registro."
    if e.errno in (errorcode.ER_NO_REFERENCED_ROW, errorcode.ER_NO_REFERENCED_ROW_2):
        return "Se hace referencia a un dato que no existe."
    if e.errno in (errorcode.ER_TABLEACCESS_DENIED_ERROR, errorcode.ER_COLUMNACCESS_DENIED_ERROR):
        return "Tu usuario no tiene permiso para hacer esta operacion."
    if e.errno in (3819, 4025):  # CHECK violado (MySQL / MariaDB)
        return "Algun dato no cumple las reglas de validacion de la base de datos."
    return f"Error de base de datos: {e.msg}"
