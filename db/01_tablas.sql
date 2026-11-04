DROP DATABASE IF EXISTS OBLIGATORIO;
CREATE DATABASE OBLIGATORIO DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_spanish_ci;
USE OBLIGATORIO;
SET NAMES utf8mb4;

-- Los CHECK son la ultima capa de validacion: aunque alguien se saltee la app,
-- la base no acepta datos imposibles (minutos negativos, turnos fuera de horario, etc.)

CREATE TABLE login (
                       correo VARCHAR(100) PRIMARY KEY,
                       contrasena VARCHAR(255) NOT NULL,          -- se guarda el hash, nunca la contrasena real
                       rol ENUM('administrador', 'planillero') NOT NULL,
                       CHECK (correo LIKE '%_@_%._%')
);

CREATE TABLE facultad (
                          id_facultad INT AUTO_INCREMENT PRIMARY KEY,
                          nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE jugador (
                         ci_jugador INT PRIMARY KEY,
                         nombre VARCHAR(20) NOT NULL,
                         apellido VARCHAR(40) NOT NULL,
                         email VARCHAR(100) NOT NULL UNIQUE,
                         fecha_nacimiento DATE NOT NULL,
                         id_facultad INT NOT NULL,
                         tipo ENUM('grado' , 'posgrado' , 'docente' , 'funcionario') NOT NULL,
                         CHECK (ci_jugador > 0),
                         CHECK (email LIKE '%_@_%._%'),
                         FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad)
);

CREATE TABLE torneo (
                        id_torneo INT AUTO_INCREMENT PRIMARY KEY,
                        nombre VARCHAR(20) NOT NULL,
                        anio INT NOT NULL,
                        semestre INT NOT NULL,
                        fecha_inicio DATE NOT NULL,
                        fecha_fin DATE NOT NULL,
                        estado ENUM ('inscripcion' , 'en curso' , 'finalizado') NOT NULL,
                        UNIQUE (anio, semestre),                  -- una edicion por semestre
                        CHECK (semestre IN (1, 2)),
                        CHECK (anio BETWEEN 2000 AND 2100),
                        CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE equipo (
                        id_equipo INT AUTO_INCREMENT PRIMARY KEY,
                        nombre VARCHAR(20) NOT NULL,
                        id_torneo INT NOT NULL,
                        id_facultad INT NOT NULL,
                        ci_capitan INT  NOT NULL,
                        UNIQUE (nombre, id_torneo),
                        FOREIGN KEY (id_torneo) REFERENCES torneo (id_torneo),
                        FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad),
                        FOREIGN KEY (ci_capitan) REFERENCES jugador(ci_jugador)
);

CREATE TABLE equipo_jugador_torneo (
                                       id_equipo INT NOT NULL,
                                       ci_jugador INT NOT NULL,
                                       id_torneo INT NOT NULL,
                                       numero_camiseta INT NOT NULL,
                                       PRIMARY KEY (id_torneo, ci_jugador),      -- un jugador, un solo equipo por edicion
                                       UNIQUE (id_equipo, numero_camiseta),      -- no se repite el numero dentro del equipo
                                       CHECK (numero_camiseta BETWEEN 1 AND 99),
                                       FOREIGN KEY (id_equipo) REFERENCES equipo(id_equipo),
                                       FOREIGN KEY (id_torneo) REFERENCES torneo(id_torneo),
                                       FOREIGN KEY (ci_jugador) REFERENCES jugador(ci_jugador)
);

CREATE TABLE complejo (
                          id_complejo INT AUTO_INCREMENT PRIMARY KEY,
                          nombre VARCHAR (100) NOT NULL,
                          direccion VARCHAR (100) NOT NULL,
                          departamento VARCHAR (80) NOT NULL
);

CREATE TABLE cancha(
                       nombre_cancha VARCHAR (80) NOT NULL,
                       id_cancha INT AUTO_INCREMENT PRIMARY KEY,
                       id_complejo INT NOT NULL,
                       superficie ENUM ('sintetico' , 'parquet') NOT NULL,
                       techada BOOLEAN NOT NULL,
                       UNIQUE (nombre_cancha, id_complejo),
                       FOREIGN KEY (id_complejo) REFERENCES complejo(id_complejo)
);

CREATE TABLE turno (
                       id_turno INT AUTO_INCREMENT PRIMARY KEY,
                       hora_inicio INT NOT NULL,
                       hora_fin INT NOT NULL,
                       UNIQUE (hora_inicio),
                       CHECK (hora_fin > hora_inicio),
                       CHECK (hora_inicio >= 18 AND hora_fin <= 23),  -- turnos entre las 18 y las 23
                       CHECK (hora_fin = hora_inicio + 1)             -- turnos de una hora
);

CREATE TABLE partido(
                        id_partido INT AUTO_INCREMENT PRIMARY KEY,
                        id_cancha INT NOT NULL,
                        id_torneo INT NOT NULL,
                        numero_fecha INT NOT NULL,
                        id_equipo_local INT NOT NULL,
                        id_equipo_visitante INT NOT NULL,
                        dia DATE NOT NULL,
                        id_turno INT NOT NULL,
                        estado ENUM('programado' , 'jugado' , 'postergado' , 'cancelado') NOT NULL DEFAULT 'programado',
                        CHECK (id_equipo_local <> id_equipo_visitante),
                        CHECK (numero_fecha >= 1),
                        FOREIGN KEY (id_torneo) REFERENCES torneo(id_torneo),
                        FOREIGN KEY (id_equipo_local) REFERENCES equipo(id_equipo),
                        FOREIGN KEY (id_equipo_visitante) REFERENCES equipo(id_equipo),
                        FOREIGN KEY (id_turno) REFERENCES turno(id_turno),
                        FOREIGN KEY (id_cancha) REFERENCES cancha(id_cancha)
);

CREATE TABLE planilla_partido(
                                 id_partido INT NOT NULL,
                                 ci_jugador INT NOT NULL,
                                 id_equipo INT NOT NULL,
                                 PRIMARY KEY (id_partido, ci_jugador),
                                 FOREIGN KEY (id_partido) REFERENCES partido(id_partido),
                                 FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador),
                                 FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo)
);

CREATE TABLE gol (
                     id_gol INT AUTO_INCREMENT PRIMARY KEY,
                     id_partido INT NOT NULL,
                     ci_jugador INT NOT NULL,
                     minuto INT NOT NULL CHECK (minuto BETWEEN 1 AND 60),   -- el turno dura una hora
                     autogol BOOLEAN NOT NULL,
                     FOREIGN KEY (id_partido) REFERENCES partido (id_partido),
                     FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador)
);

CREATE TABLE tarjeta(
                        id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
                        id_partido INT NOT NULL,
                        ci_jugador INT NOT NULL,
                        minuto INT NOT NULL CHECK (minuto BETWEEN 1 AND 60),
                        color ENUM ('amarilla' , 'roja') NOT NULL,
                        FOREIGN KEY (id_partido) REFERENCES partido (id_partido),
                        FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador)
);

CREATE TABLE sancion_jugador (
                                 id_sancion INT AUTO_INCREMENT PRIMARY KEY,
                                 ci_jugador INT NOT NULL,
                                 id_torneo INT NOT NULL,
                                 motivo ENUM ('roja' , 'acumulacion de amarillas' , 'disciplinaria') NOT NULL,
                                 numero_fecha_inicio INT NOT NULL,
                                 cantidad_fechas INT NOT NULL,
                                 CHECK (numero_fecha_inicio >= 1),
                                 CHECK (cantidad_fechas >= 1),
                                 FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador),
                                 FOREIGN KEY (id_torneo) REFERENCES torneo (id_torneo)
);
