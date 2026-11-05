### PERMISOS

admin_torneo: gestiona toda la información del torneo. Gestiona los datos del torneo, no la estructura.

planillero_torneo: solo registra planillas, goles, tarjetas y marca partidos como jugados. No puede tocar equipos, jugadores ni sanciones, y tampoco ve la tabla login, solo escribe en planilla_partido, gol y tarjeta.

login_app: un usuario mínimo que solo puede leer la tabla login. La app lo usa para verificar el correo y la contraseña, para que la verificación de credenciales no requiera un usuario con más permisos de los necesarios. Con eso decide con cuál de los otros dos usuarios abre la conexión.

### FRONTEND Y BACKEND
Flask es una librería de Python que permite que tu programa responda a un navegador. El usuario abre una página (por ejemplo localhost:5000), Python consulta MySQL y devuelve una página HTML con los datos. Con eso se resuelve backend y frontend juntos en Python


### Docker
Los scripts de db/ se ejecutan solo la primera vez, cuando el volumen está vacío. Si después cambian un .sql y quieren que Docker lo aplique, hay que borrar el volumen y empezar de cero:

   docker compose down -v
   docker compose up --build


### REGLAS EN LA BASE (agregadas en 03_triggers.sql)
Todas las reglas de la letra estan en la base, no solo en la app. Si algo se rechaza, el mensaje del trigger se muestra en pantalla.
- Planteles: max 10, max 2 docentes/funcionarios, misma facultad, solo en inscripcion. El minimo de 5 se exige al programar partidos.
- Capitan: al inscribir el equipo la app lo agrega al plantel en la misma transaccion; no se puede quitar; un capitan nuevo debe estar en el plantel.
- Partidos: las reglas 1-4 tambien al modificar; dia dentro del torneo; "jugado" solo si ya paso el turno; un jugado no se borra ni cambia de estado.
- Planilla, goles y tarjetas: solo despues de jugado el turno, nunca en cancelado/postergado, y si ya esta jugado solo dentro de 48 horas.
- Sanciones automaticas: roja -> 1 fecha; cada 3 amarillas -> 1 fecha; se cumplen en la fecha siguiente. Si se borra la tarjeta, se quita la sancion.
- Hora: NOW() con zona de Uruguay (-03:00) en MySQL y en cada conexion de la app.

### LOGIN
Las contrasenas de la tabla login se guardan con hash (PBKDF2-SHA256). Usuarios de prueba: admin@ucu.edu.uy / admin123 y planillero@ucu.edu.uy / plan123.

### CARPETA DE SCRIPTS
docker-compose monta ./db en /docker-entrypoint-initdb.d: la carpeta tiene que llamarse "db" (no "bd").

### MYSQL 8 EN DOCKER
- Los usuarios de BD se crean con mysql_native_password (el conector de Python no se llevaba bien con el metodo por defecto de MySQL 8).
- Los .sql no pueden tener renglones con solo espacios: Docker los ejecuta con --comments y eso rompe DELIMITER.
