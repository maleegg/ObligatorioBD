# Torneo Interfacultades de Fútbol 5 — UCU

Sistema web para organizar el torneo: equipos, jugadores, partidos, planillas, sanciones y reportes.

---

## ¿Cómo funciona? (en 30 segundos)

El proyecto tiene dos partes:

- **La base de datos (MySQL):** el "archivero" donde se guarda todo (jugadores, partidos, goles...).
- **La aplicación (Python):** la "ventanilla" que ves en el navegador, donde tocás botones.

**Docker** es el programa que arma y prende esas dos partes por vos con un solo comando.

---

## Lo que necesitás (una sola vez)

### Instalar Docker Desktop

1. Entrá a **https://www.docker.com/products/docker-desktop/** y tocá **Download**.
2. Si tenés Mac, te pregunta qué tipo. Para saberlo, tocá la manzana  (arriba a la izquierda) → **Acerca de esta Mac**:
   - Si dice **Apple M1, M2, M3 o M4** → elegí **Apple Silicon**.
   - Si dice **Intel** → elegí **Intel**.
3. Abrí el archivo descargado e instalalo como cualquier programa (en Mac: arrastrá la ballena 🐳 a **Aplicaciones**).

---

## Cómo prender el proyecto

### Paso 1 — Abrir Docker Desktop

- **Mac:** `Cmd + Espacio`, escribí **Docker** y Enter.
- **Windows:** buscá **Docker Desktop** en el menú Inicio.

Si te pide iniciar sesión, podés tocar **Skip**.
Esperá hasta que abajo a la izquierda diga **"Engine running"** en verde.

> ⚠️ Sin este paso no funciona nada. Podés minimizar Docker, pero no lo cierres.

### Paso 2 — Abrir la Terminal dentro de la carpeta del proyecto

La Terminal es una ventana donde le escribís órdenes a la computadora. Tiene que estar "parada" en la carpeta del proyecto.

- **Mac:**
  1. `Cmd + Espacio`, escribí **Terminal** y Enter.
  2. Escribí `cd` y **un espacio** (no aprietes Enter todavía).
  3. **Arrastrá la carpeta del proyecto** adentro de la Terminal.
  4. Apretá **Enter**.
- **Windows:** abrí la carpeta del proyecto, hacé clic en la barra de dirección de arriba, escribí `cmd` y Enter.

Para comprobar que estás en el lugar correcto, el texto antes del cursor debería terminar con el nombre de la carpeta, por ejemplo:
```
Olivia@192 proyecto %
```

### Paso 3 — Prender el proyecto

Copiá esto, pegalo en la Terminal y apretá Enter:
```
docker compose up --build
```

Va a salir **mucho texto**. Es normal. **La primera vez tarda unos minutos.**

✅ **Está listo cuando aparece esta línea:**
```
torneo_python_app  | Conexion a MySQL OK
```
Después la Terminal se queda "quieta". Eso está bien: significa que está prendido y esperando.

> **No cierres la Terminal.** Si la cerrás, se apaga el proyecto.

### Paso 4 — Entrar al sistema

1. Abrí **Chrome** o **Safari**.
2. Hacé clic en la barra de arriba (donde se escriben las direcciones web).
3. Escribí **`localhost:5001`** y apretá Enter.

   *"localhost" quiere decir "esta misma computadora": la página no está en internet, funciona en tu compu.*

4. Iniciá sesión con alguno de estos usuarios:

| Para entrar como... | Correo | Contraseña |
|---|---|---|
| **Administrador** (puede hacer todo) | `admin@ucu.edu.uy` | `admin123` |
| **Planillero** (solo carga los partidos) | `planillero@ucu.edu.uy` | `plan123` |

### Paso 5 — Apagarlo

En la Terminal, apretá **`Control + C`** (la tecla Control, no Cmd).

---

## La próxima vez

Es más rápido:

1. Abrir **Docker Desktop** y esperar "Engine running".
2. Abrir la **Terminal** en la carpeta del proyecto.
3. Escribir `docker compose up` y Enter.
4. Entrar a **`localhost:5001`**.

---

## Volver a los datos de prueba originales

Si probaste cosas y querés empezar limpio (o si cambiaste algún archivo de la carpeta `db`), con el proyecto apagado escribí:
```
docker compose down -v
docker compose up --build
```
El `-v` borra los datos guardados y Docker vuelve a crear la base desde cero con los datos de ejemplo.

---

## Si algo sale mal

| Lo que ves | Qué significa | Qué hacer |
|---|---|---|
| `failed to connect to the docker API` o `Cannot connect to the Docker daemon` | Docker Desktop no está abierto | Hacé el **Paso 1** y probá de nuevo |
| `Access denied for user 'login_app'` que se repite y no termina | Quedó guardada una base vieja o incompleta | `Control + C`, después `docker compose down -v` y `docker compose up --build` |
| `La base de datos esta iniciando... reintento` unas pocas veces | La base está arrancando | Nada, esperá. La app se conecta sola |
| `WARNING: This is a development server` (en rojo) | Aviso estándar de Flask | Nada, es normal |
| `mysql_native_password is deprecated` | Aviso de MySQL sobre versiones futuras | Nada, es normal |
| `port is already allocated` | Otro programa usa ese puerto | En `docker-compose.yml` cambiá `"5001:5000"` por `"5002:5000"` y entrá a `localhost:5002` |
| El navegador dice "no se puede acceder al sitio" | El proyecto no está prendido | Revisá que la Terminal siga abierta y que haya salido `Conexion a MySQL OK` |

---

## Recorrido sugerido para probar el sistema

1. **Reportes** (como administrador, menú de arriba): están los 9 reportes pedidos más 3 propios, calculados con los datos de prueba (6 equipos, 3 fechas jugadas).
2. **Cargar una planilla** (como planillero): en la pantalla de inicio aparece el partido *Los Ingenieros vs Psico Team* (fecha 4) para cargar.
   - Maximiliano Medina aparece **suspendido** y el sistema no deja anotarlo.
   - Si le ponés una tarjeta amarilla a Lucía González (sería su 3ra), se crea **sola** su suspensión.
   - Al final tocá **Marcar como jugado**: el partido pasa a contar en la tabla de posiciones.
3. **Programar un partido** (administrador → Partidos → Programar): probá repetir un cruce, poner un equipo dos veces en la misma fecha o usar una cancha ocupada. El sistema lo rechaza y explica por qué.
4. **Armar un equipo** (administrador): arriba a la derecha, en **Edición**, elegí *Torneo 2027-1 (inscripción)*. Ahí se pueden inscribir equipos y armar planteles. En la edición que ya está en curso, los planteles no se pueden modificar.

---

## Para usarlo sin Docker (opcional)

Solo si tenés **MySQL 8** y **Python 3.10 o superior** instalados en la computadora.

1. Crear la base: ejecutar los 4 archivos de la carpeta `db`, **en orden**, con el usuario `root` (desde MySQL Workbench o desde la Terminal):
   ```
   mysql -u root -p < db/01_tablas.sql
   mysql -u root -p < db/02_inserciones.sql
   mysql -u root -p < db/03_triggers.sql
   mysql -u root -p < db/04_permisos.sql
   ```
2. Instalar las librerías de Python:
   ```
   pip install -r requirements.txt
   ```
3. Prender la aplicación:
   - Mac / Linux: `DB_HOST=localhost DB_PORT=3306 python3 main.py`
   - Windows (PowerShell): `$env:DB_HOST="localhost"; $env:DB_PORT="3306"; python main.py`
4. Entrar a **`localhost:5000`** (sin Docker el número es 5000).

---

## Qué hay en cada carpeta

| Archivo o carpeta | Qué tiene |
|---|---|
| `db/01_tablas.sql` | Crea las tablas |
| `db/02_inserciones.sql` | Datos de prueba |
| `db/03_triggers.sql` | Reglas del torneo (por ejemplo, que un suspendido no juegue) |
| `db/04_permisos.sql` | Usuarios de la base con permisos distintos para administrador y planillero |
| `Consultas.sql` | Las consultas de los reportes, para correrlas a mano |
| `main.py` | Arranque de la aplicación, login y pantalla de inicio |
| `db.py` | Conexión con la base de datos |
| `validaciones.py` | Revisión de los datos que se cargan en los formularios |
| `utiles.py` | Control de quién puede entrar a cada sección |
| `rutas/` | Una sección del sistema por archivo (jugadores, equipos, partidos...) |
| `templates/` | Las pantallas (HTML) |
| `static/estilo.css` | Colores y diseño |
| `docker-compose.yml` y `Dockerfile` | Instrucciones para que Docker arme todo |

### Datos para conectarse a la base desde MySQL Workbench (con Docker prendido)

Host `localhost` · Puerto `3307` · Usuario `root` · Contraseña `rootpassword123`
