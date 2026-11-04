### PERMISOS

admin_torneo: gestiona toda la información del torneo. No tiene DROP ni CREATE: gestiona datos, no la estructura.

planillero_torneo: solo registra planillas, goles, tarjetas y marca partidos como jugado. No puede tocar equipos, jugadores ni sanciones, y tampoco ve la tabla login (solo escribe en planilla_partido, gol y tarjeta).

login_app: un usuario mínimo que solo puede leer la tabla login. La app lo usa para verificar el correo y la contraseña, para que la verificación de credenciales no requiera un usuario con más permisos de los necesarios. Con eso decide con cuál de los otros dos usuarios abre la conexión.

