# Informe — Sistema de Gestión del Torneo Interfacultades de Fútbol 5

Base de Datos 1 — Universidad Católica del Uruguay — Segundo semestre 2026

> Integrantes: Delfina Bruno, Olivia De León, Malena González, Valentina Pérez · Repositorio: https://github.com/maleegg/ObligatorioBD.git 

## 1. Resumen

Se construyó una aplicación web que reemplaza las planillas de cálculo y los grupos de mensajería del torneo. Permite inscribir equipos y armar planteles, programar el fixture, registrar planillas con goles y tarjetas, gestionar sanciones y consultar reportes.

La idea central del diseño es que **las reglas del torneo viven en la base de datos**. La aplicación también valida, pero aunque alguien se conectara directo a MySQL salteándose la app, la base seguiría rechazando un partido superpuesto, un jugador suspendido en la planilla o un plantel con 11 jugadores.

**Tecnologías:** Python 3.11 + Flask (backend y pantallas), MySQL 8 (base), mysql-connector-python (conexión, sin ORM), Docker y Docker Compose.

## 2. Decisiones de implementación

### 2.1 Arquitectura
- **Flask para backend y frontend juntos.** El navegador pide una página, Python consulta MySQL con SQL escrito a mano y devuelve el HTML ya armado (plantillas Jinja). Evita tener dos proyectos separados (por ejemplo una API + una app de React) y alcanza para lo que se pide.
- **Sin ORM.** Todas las consultas están escritas en SQL y usan parámetros (`%s`) en lugar de pegar texto, lo que evita inyección SQL.
- **Una transacción por acción.** Cuando una acción implica varios cambios (por ejemplo, inscribir un equipo y agregar a su capitán al plantel, o guardar la planilla), se guardan todos juntos o ninguno.

### 2.2 Seguridad a nivel de base de datos
Se crearon tres usuarios de MySQL con permisos mínimos (`04_permisos.sql`):

| Usuario de BD | Para qué | Permisos |
|---|---|---|
| `login_app` | Verificar correo y contraseña | Solo `SELECT` sobre `login` |
| `admin_torneo` | Sesiones de administradores | `SELECT, INSERT, UPDATE, DELETE` en todas las tablas. Sin `CREATE`/`DROP`: gestiona datos, no la estructura |
| `planillero_torneo` | Sesiones de planilleros | Escribe solo en `planilla_partido`, `gol` y `tarjeta`, y puede cambiar **únicamente la columna `estado`** de `partido`. Lee lo necesario para armar la planilla. No ve `login` |

Cuando una persona inicia sesión, la app abre la conexión con el usuario de BD de su rol. Así, aunque hubiera un error en la app, la base no dejaría a un planillero borrar un jugador (se probó: MySQL responde *permiso denegado*).

Las sanciones automáticas las crea un trigger: los triggers se ejecutan con los permisos de quien los definió, por eso un planillero puede cargar una roja y la sanción se genera aunque él no tenga permiso de escribir en `sancion_jugador`.

Las contraseñas de la tabla `login` se guardan como **hash con sal (PBKDF2-SHA256)**, nunca en texto plano.

### 2.3 Validación en las tres capas
1. **Frontend:** los formularios usan `required`, `min`, `max`, `maxlength`, `type="email"`, `type="date"`. Además, la pantalla no ofrece opciones inválidas (por ejemplo, los suspendidos aparecen deshabilitados en la planilla).
2. **Backend** (`validaciones.py`): se revisa de nuevo cada campo (obligatorio, largo, número entero en rango, fecha válida, formato de correo, opción permitida), porque el navegador se puede saltear.
3. **Base de datos:** tipos, `NOT NULL`, `UNIQUE`, claves foráneas, `CHECK` y triggers. Los mensajes de los triggers se muestran tal cual al usuario, para que sepa por qué se rechazó.

### 2.3 bis Protección contra ataques
- **Inyección SQL.** Ninguna consulta se arma pegando lo que escribe el usuario: todos los datos viajan como parámetros (`%s`) separados de la orden SQL, y la base los trata siempre como dato, nunca como instrucción. Por ejemplo, si en el login se escribe `' OR '1'='1`, se busca literalmente un correo con ese texto y no se entra. Las únicas partes del SQL que se arman en Python insertan textos fijos escritos por nosotros, nunca datos del usuario.
- **Validación previa.** Los campos numéricos (cédula, minuto, número de fecha, identificadores) se convierten a número en el backend antes de usarse, por lo que no admiten texto.
- **Permisos mínimos como segunda barrera.** Aunque se lograra colar una orden, cada rol se conecta con un usuario de BD limitado (ver 2.2): el usuario del login solo puede leer `login`, el planillero no puede borrar jugadores ni leer contraseñas, y ningún usuario de la app puede borrar tablas. Se verificó que MySQL responde *permiso denegado* en esos casos.
- **Contraseñas con hash.** Si alguien llegara a leer la tabla `login`, vería solo hashes PBKDF2-SHA256 con sal, no las contraseñas reales.
- **XSS (código en los datos).** Las pantallas se generan con Jinja, que escapa automáticamente todo lo que se muestra: si alguien carga código HTML o JavaScript en el nombre de un jugador, se ve como texto y no se ejecuta.
- **Acceso por rol.** Cada página verifica la sesión y el rol antes de mostrarse; un planillero que escriba a mano la dirección de una sección de administración es redirigido.

### 2.4 Dónde se controla cada regla de la letra

| Regla | Cómo se controla |
|---|---|
| Plantel entre 5 y 10 jugadores | Máximo 10: trigger del plantel. Mínimo 5: se exige al programar un partido (durante la inscripción el plantel se va armando de a uno) |
| Máximo 2 docentes/funcionarios por plantel | Trigger del plantel. Además, al editar un jugador no puede pasar a docente/funcionario si su equipo ya tiene 2 |
| Todos los jugadores de la facultad del equipo | Trigger del plantel y trigger del equipo (capitán). Además, al editar un jugador no se le puede cambiar la facultad si integra un equipo |
| Un jugador en un solo equipo por edición | Clave primaria `(id_torneo, ci_jugador)` |
| Planteles solo modificables en inscripción | Triggers de alta, modificación y baja del plantel |
| El capitán es uno de sus jugadores | Al inscribir, la app agrega al capitán al plantel en la misma transacción; al cambiar capitán, un trigger exige que esté en el plantel; no se puede quitar al capitán |
| Equipos de la misma edición y con 5 jugadores | Trigger al insertar y al modificar partidos. Si el partido ya tiene planilla, no se le pueden cambiar los equipos |
| No jugar contra sí mismo | `CHECK (id_equipo_local <> id_equipo_visitante)` |
| No repetir rival (salvo cancelado) | Trigger, en ambos sentidos (A-B y B-A) |
| Un partido por equipo por fecha | Trigger |
| Cancha libre en día y turno | Trigger al insertar y al modificar |
| En la planilla solo jugadores del plantel no suspendidos | Trigger de `planilla_partido` |
| Goles/tarjetas solo de jugadores en la planilla | Triggers de `gol` y `tarjeta` |
| Resultado calculado a partir de los goles | No se guarda el resultado: siempre se calcula con una consulta (un autogol suma al rival) |
| "Jugado" solo si el día y turno ya pasaron | Trigger (compara con la hora actual de Uruguay, UTC-3) |
| Un partido jugado no se elimina | Trigger de borrado; además no puede cambiar de estado (si no, se podría cancelar y luego borrar) |
| Corrección del resultado solo dentro de 48 h | Triggers de `gol`, `tarjeta` y `planilla_partido` |
| Sanción automática por roja o 3 amarillas | Trigger que inserta la sanción para la fecha siguiente; si la tarjeta se borra por error, la sanción también se quita |
| Puntos 3/1/0 y orden por puntos, DG y GF | Consulta de la tabla de posiciones |
| Turnos de una hora entre 18 y 23 | `CHECK` en `turno` |

### 2.5 Otras decisiones
- **Cancha con clave propia (`id_cancha`).** La letra identifica la cancha por `(nombre_cancha, id_complejo)`. Usamos un número `id_cancha` como clave y mantuvimos `(nombre_cancha, id_complejo)` como `UNIQUE`. Así `partido` guarda una sola columna para la cancha y se puede renombrar una cancha sin tocar los partidos.
- **Reglas reutilizadas con procedimientos.** Cuando la misma regla se necesita en varios triggers (por ejemplo al insertar y al modificar), se escribió una vez como procedimiento (`sp_...`) y los triggers lo llaman.
- **Momento de cargar la planilla.** Se puede cargar cuando el partido ya terminó (día y turno pasados), mientras está *programado*; al marcarlo *jugado* empieza a contar en la tabla. Una vez jugado, se puede corregir solo hasta 48 horas después de su disputa. Nunca en partidos cancelados o postergados.
- **Tarjetas: borrar y volver a cargar.** No se permite cambiar el color o el jugador de una tarjeta, porque eso alteraría las sanciones automáticas; se borra y se carga de nuevo, y las sanciones se recalculan.
- **Acumulación de amarillas:** se sanciona a la 3.ª, 6.ª, 9.ª amarilla, etc. (cada 3).
- **Torneos.** Aunque la letra no lo pide explícitamente, se agregó el ABM de torneos porque es necesario para pasar una edición de *inscripción* a *en curso* y a *finalizado*.
- **Zona horaria.** Las reglas de tiempo usan la hora de Uruguay: el servidor MySQL arranca con `--default-time-zone=-03:00` y la app fija la misma zona en cada conexión.

## 3. Mejoras al modelo de datos

**Implementadas**
- `CHECK` adicionales: cédula positiva, formato de correo, semestre 1 o 2, turnos de una hora entre 18 y 23, minuto entre 1 y 60 (el turno dura una hora), camiseta entre 1 y 99, número de fecha y cantidad de fechas de sanción mayores a 0.
- `UNIQUE (id_equipo, numero_camiseta)`: dos jugadores del mismo equipo no comparten número.
- `UNIQUE (anio, semestre)` en `torneo`: una edición por semestre. `UNIQUE (hora_inicio)` en `turno`.
- Contraseñas con hash.
- Segunda edición de prueba en etapa de inscripción, para poder probar el armado de planteles.

**Consideradas para una versión futura**
- Guardar quién cargó cada planilla y cuándo (auditoría), con una tabla de historial.
- Índices adicionales (por ejemplo en `partido(id_torneo, numero_fecha)`) si el volumen de datos creciera.
- ABM de usuarios del sistema (`login`) desde la aplicación.

## 4. Reportes
Están en la sección *Reportes* (solo administradores) y también en `Consultas.sql`. Se calculan para la edición elegida arriba en la pantalla:
tabla de posiciones, goleadores (top 10), fair play, promedio de goles por fecha y por edición, canchas y turnos más usados, jugadores por facultad y tipo, inscriptos que nunca jugaron, sanciones por equipo y motivo, y porcentaje de partidos por estado.

**Consultas propias (3):**
1. **Resultados de los partidos jugados:** el marcador de cada partido, útil para publicar la fecha.
2. **Suspendidos en una fecha:** quién no puede jugar en la fecha elegida; ayuda a planilleros y organizadores.
3. **Jugadores en riesgo de suspensión:** a quienes les falta una amarilla para ser suspendidos.

## 5. Pruebas realizadas
Se cargaron los cuatro scripts en un servidor limpio y se probó la aplicación con ambos roles:
- Todas las pantallas cargan para el administrador; el planillero no puede entrar a secciones de administración.
- La tabla de posiciones coincide con el cálculo hecho a mano (Psico Team 7 pts, Los Ingenieros 6, Empresarios United 4, Humanistas 4, Leguleyos FC 2, Salud FC 1).
- Cada regla de la tabla 2.4 se probó con un caso que debe pasar y otro que debe ser rechazado.
- Permisos: el planillero no puede leer `login`, ni cambiar el día de un partido, ni borrar jugadores; `login_app` no puede leer otras tablas; el administrador no puede borrar tablas.
- Las consultas se ejecutaron con el modo estricto de MySQL 8 (`ONLY_FULL_GROUP_BY`).

## 6. Bitácora

| Fecha | Trabajo realizado |
|---|---|
| 12/10 | Lectura de la letra y diseño del modelo de datos |
| 29/10| Creación de tablas (`01_tablas.sql`) y datos de prueba (`02_inserciones.sql`) |
| 29/10 | Primeros triggers: validación al programar partidos, cancha libre y planilla |
| 29/10 | Usuarios de base de datos y permisos (`04_permisos.sql`) |
| 30/10| Consultas de los reportes (`Consultas.sql`) |
| 3/11 | Dockerfile y docker-compose con servicios de base y app |
| 04/11| Reglas restantes en la base (planteles, capitán, partidos jugados, 48 horas, sanciones automáticas), CHECK adicionales y contraseñas con hash |
| 04/11| Aplicación Flask: login por rol, ABM de torneos, jugadores, equipos y planteles, complejos y canchas, partidos y sanciones; planilla; reportes |
| 04/11| Pruebas de todas las reglas y pantallas, instructivo (README) e informe |
| 04/11| Prueba con Docker: corrección de espacios invisibles en los scripts SQL y del tipo de contraseña de los usuarios de BD para MySQL 8. Revisión final contra la letra: se agregaron controles al editar jugadores y partidos con planilla |

## 7. Bibliografía
- Oracle. *MySQL 8.0 Reference Manual* — CREATE TRIGGER, stored procedures, SIGNAL, CHECK constraints, GRANT. https://dev.mysql.com/doc/refman/8.0/en/
- Oracle. *MySQL Connector/Python Developer Guide*. https://dev.mysql.com/doc/connector-python/en/
- Pallets. *Flask Documentation* (3.x). https://flask.palletsprojects.com/
- Pallets. *Jinja Documentation*. https://jinja.palletsprojects.com/
- Pallets. *Werkzeug — Utilities: password hashing*. https://werkzeug.palletsprojects.com/
- Docker Inc. *Docker Compose documentation*. https://docs.docker.com/compose/
- Docker Hub. *mysql — Official Image (initializing a fresh instance)*. https://hub.docker.com/_/mysql
- Silberschatz, A., Korth, H. F., Sudarshan, S. *Database System Concepts*, 7.ª ed. McGraw-Hill, 2019.
- Material del curso Base de Datos 1, UCU.
