"""Punto de entrada de la aplicacion web (Flask).

Flask hace de backend y de frontend: el navegador pide una pagina, Python consulta MySQL
y devuelve el HTML ya armado (plantillas en la carpeta templates/).
"""
import os
import time

from flask import Flask, flash, redirect, render_template, request, session, url_for
from mysql.connector import Error
from werkzeug.security import check_password_hash

from db import cerrar_conexion, consultar, nueva_conexion
from utiles import login_requerido, torneo_activo
from validaciones import Validador

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "cambiar-esta-clave-en-produccion")
app.teardown_appcontext(cerrar_conexion)

# Cada seccion vive en su propio archivo dentro de rutas/
from rutas.torneos import bp as bp_torneos          # noqa: E402
from rutas.jugadores import bp as bp_jugadores      # noqa: E402
from rutas.equipos import bp as bp_equipos          # noqa: E402
from rutas.complejos import bp as bp_complejos      # noqa: E402
from rutas.partidos import bp as bp_partidos        # noqa: E402
from rutas.planillas import bp as bp_planillas      # noqa: E402
from rutas.sanciones import bp as bp_sanciones      # noqa: E402
from rutas.reportes import bp as bp_reportes        # noqa: E402

for blueprint in (bp_torneos, bp_jugadores, bp_equipos, bp_complejos,
                  bp_partidos, bp_planillas, bp_sanciones, bp_reportes):
    app.register_blueprint(blueprint)


@app.context_processor
def datos_comunes():
    """Datos que necesita la barra superior en todas las paginas."""
    if "rol" not in session:
        return {}
    try:
        torneos = consultar("SELECT id_torneo, nombre, estado FROM torneo ORDER BY anio DESC, semestre DESC")
        return {"torneos_menu": torneos, "id_torneo_activo": torneo_activo()}
    except Error:
        return {"torneos_menu": [], "id_torneo_activo": None}


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        v = Validador(request.form)
        v.email("correo", "Correo")
        v.texto("contrasena", "Contrasena", 100)
        if v.ok:
            # Para verificar credenciales se usa login_app, que SOLO puede leer la tabla login
            cnx = nueva_conexion("login")
            try:
                cursor = cnx.cursor(dictionary=True)
                cursor.execute("SELECT correo, contrasena, rol FROM login WHERE correo = %s", (v.datos["correo"],))
                usuario = cursor.fetchone()
                cursor.close()
            finally:
                cnx.close()
            if usuario and check_password_hash(usuario["contrasena"], v.datos["contrasena"]):
                session.clear()
                session["correo"] = usuario["correo"]
                session["rol"] = usuario["rol"]
                return redirect(url_for("inicio"))
        flash("Correo o contrasena incorrectos.", "error")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/torneo-activo", methods=["POST"])
@login_requerido
def elegir_torneo():
    try:
        session["id_torneo"] = int(request.form.get("id_torneo", ""))
    except ValueError:
        flash("Torneo invalido.", "error")
    return redirect(request.referrer or url_for("inicio"))


@app.route("/")
@login_requerido
def inicio():
    id_torneo = torneo_activo()
    pendientes = consultar(
        """SELECT p.id_partido, p.numero_fecha, p.dia, t.hora_inicio, p.estado,
                  el.nombre AS local, ev.nombre AS visitante
           FROM partido p
           JOIN turno t   ON t.id_turno = p.id_turno
           JOIN equipo el ON el.id_equipo = p.id_equipo_local
           JOIN equipo ev ON ev.id_equipo = p.id_equipo_visitante
           WHERE p.id_torneo = %s
             AND p.estado = 'programado'
             AND TIMESTAMP(p.dia, MAKETIME(t.hora_fin, 0, 0)) <= NOW()
           ORDER BY p.dia, t.hora_inicio""",
        (id_torneo,),
    )
    return render_template("inicio.html", pendientes=pendientes)


def esperar_base_de_datos():
    """Al levantar con Docker, MySQL puede tardar unos segundos mas en aceptar conexiones."""
    while True:
        try:
            nueva_conexion("login").close()
            print("Conexion a MySQL OK")
            return
        except Error as e:
            print(f"La base de datos esta iniciando... reintento en 3 segundos ({e})")
            time.sleep(3)


if __name__ == "__main__":
    esperar_base_de_datos()
    app.run(host="0.0.0.0", port=5000, debug=os.getenv("FLASK_DEBUG") == "1")
