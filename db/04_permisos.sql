-- PERMISOS: usuarios de base de datos con permisos diferenciados

DROP USER IF EXISTS 'admin_torneo'@'%';
DROP USER IF EXISTS 'planillero_torneo'@'%';
DROP USER IF EXISTS 'login_app'@'%';

CREATE USER 'admin_torneo'@'%' IDENTIFIED WITH mysql_native_password BY 'Admin_Torneo_2026!';
CREATE USER 'planillero_torneo'@'%' IDENTIFIED WITH mysql_native_password BY 'Planillero_2026!';
CREATE USER 'login_app'@'%' IDENTIFIED WITH mysql_native_password BY 'LoginApp_2026!';

-- administrador: gestiona todos los datos de la base
GRANT SELECT, INSERT, UPDATE, DELETE ON OBLIGATORIO.* TO 'admin_torneo'@'%';

-- planillero: solo registra planillas, goles y tarjetas
GRANT INSERT, UPDATE, DELETE ON OBLIGATORIO.planilla_partido TO 'planillero_torneo'@'%';
GRANT INSERT, UPDATE, DELETE ON OBLIGATORIO.gol TO 'planillero_torneo'@'%';
GRANT INSERT, UPDATE, DELETE ON OBLIGATORIO.tarjeta TO 'planillero_torneo'@'%';
GRANT UPDATE (estado) ON OBLIGATORIO.partido TO 'planillero_torneo'@'%';

-- planillero: puede consultar lo necesario para armar la planilla (no la tabla login)
GRANT SELECT ON OBLIGATORIO.partido TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.equipo TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.jugador TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.equipo_jugador_torneo TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.sancion_jugador TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.planilla_partido TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.gol TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.tarjeta TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.torneo TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.turno TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.cancha TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.complejo TO 'planillero_torneo'@'%';
GRANT SELECT ON OBLIGATORIO.facultad TO 'planillero_torneo'@'%';

-- login_app: solo puede leer la tabla de usuarios del sistema
GRANT SELECT ON OBLIGATORIO.login TO 'login_app'@'%';