DROP DATABASE IF EXISTS OBLIGATORIO;
CREATE DATABASE OBLIGATORIO DEFAULT CHARACTER SET utf8 COLLATE utf8_spanish_ci;
USE OBLIGATORIO;

CREATE TABLE login (
                       correo VARCHAR(100) PRIMARY KEY,
                       contrasena VARCHAR(10) NOT NULL,
                       rol ENUM('administrador', 'planillero') NOT NULL
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
                                       PRIMARY KEY (id_torneo, ci_jugador),
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
                       FOREIGN KEY (id_complejo) REFERENCES complejo(id_complejo)
);

CREATE TABLE turno (
                       id_turno INT AUTO_INCREMENT PRIMARY KEY,
                       hora_inicio INT NOT NULL,
                       hora_fin INT NOT NULL,
                       CHECK (hora_fin > hora_inicio)
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
                        nombre_cancha VARCHAR (80) NOT NULL,
                        id_complejo INT NOT NULL,
                        estado ENUM('programado' , 'jugado' , 'postergado' , 'cancelado'),
                        CHECK (id_equipo_local <> id_equipo_visitante),
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
                     minuto INT NOT NULL CHECK (minuto >0),
                     autogol BOOLEAN NOT NULL,
                     FOREIGN KEY (id_partido) REFERENCES partido (id_partido),
                     FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador)
);

CREATE TABLE tarjeta(
                        id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
                        id_partido INT NOT NULL,
                        ci_jugador INT NOT NULL,
                        minuto INT NOT NULL CHECK (minuto>0),
                        color ENUM ('amarilla' , 'roja'),
                        FOREIGN KEY (id_partido) REFERENCES partido (id_partido),
                        FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador)
);

CREATE TABLE sancion_jugador (
                                 id_sancion INT AUTO_INCREMENT PRIMARY KEY,
                                 ci_jugador INT NOT NULL,
                                 id_torneo INT NOT NULL,
                                 motivo ENUM ('roja' , 'acumulacion de amarillas' , 'disciplinaria'),
                                 numero_fecha_inicio INT NOT NULL,
                                 cantidad_fechas INT NOT NULL,
                                 FOREIGN KEY (ci_jugador) REFERENCES jugador (ci_jugador),
                                 FOREIGN KEY (id_torneo) REFERENCES torneo (id_torneo)
);
USE OBLIGATORIO;

INSERT INTO login (correo, contrasena, rol) VALUES
                                                ('admin@ucu.edu.uy', 'admin123', 'administrador'),
                                                ('planillero@ucu.edu.uy', 'plan123', 'planillero');

INSERT INTO facultad (nombre) VALUES
                                  ('Ingeniería'),
                                  ('Derecho'),
                                  ('Ciencias Empresariales'),
                                  ('Ciencias de la Salud'),
                                  ('Psicología'),
                                  ('Ciencias Humanas');

INSERT INTO jugador (ci_jugador, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo) VALUES
                                                                                                   (40000101, 'Martín', 'Pérez', 'martin.perez@correo.ucu.edu.uy', '2003-04-09', 1, 'grado'),
                                                                                                   (40000102, 'Lucía', 'González', 'lucia.gonzalez@correo.ucu.edu.uy', '2004-06-14', 1, 'grado'),
                                                                                                   (40000103, 'Diego', 'Rodríguez', 'diego.rodriguez@correo.ucu.edu.uy', '1999-08-19', 1, 'posgrado'),
                                                                                                   (40000104, 'Sofía', 'Fernández', 'sofia.fernandez@correo.ucu.edu.uy', '2001-10-24', 1, 'grado'),
                                                                                                   (40000105, 'Joaquín', 'López', 'joaquin.lopez@correo.ucu.edu.uy', '1981-12-02', 1, 'docente'),
                                                                                                   (40000106, 'Valentina', 'Martínez', 'valentina.martinez@correo.ucu.edu.uy', '2003-02-07', 1, 'grado'),
                                                                                                   (40000201, 'Mateo', 'Silva', 'mateo.silva@correo.ucu.edu.uy', '2004-05-12', 2, 'grado'),
                                                                                                   (40000202, 'Camila', 'Pereira', 'camila.pereira@correo.ucu.edu.uy', '2005-07-17', 2, 'grado'),
                                                                                                   (40000203, 'Nicolás', 'Sosa', 'nicolas.sosa@correo.ucu.edu.uy', '2001-09-22', 2, 'grado'),
                                                                                                   (40000204, 'Florencia', 'Cabrera', 'florencia.cabrera@correo.ucu.edu.uy', '2000-11-27', 2, 'posgrado'),
                                                                                                   (40000205, 'Federico', 'Núñez', 'federico.nunez@correo.ucu.edu.uy', '1982-01-05', 2, 'docente'),
                                                                                                   (40000206, 'Agustina', 'Suárez', 'agustina.suarez@correo.ucu.edu.uy', '1983-03-10', 2, 'funcionario'),
                                                                                                   (40000301, 'Santiago', 'Díaz', 'santiago.diaz@correo.ucu.edu.uy', '2005-06-15', 3, 'grado'),
                                                                                                   (40000302, 'Micaela', 'Romero', 'micaela.romero@correo.ucu.edu.uy', '2001-08-20', 3, 'grado'),
                                                                                                   (40000303, 'Bruno', 'Álvarez', 'bruno.alvarez@correo.ucu.edu.uy', '2002-10-25', 3, 'grado'),
                                                                                                   (40000304, 'Josefina', 'Méndez', 'josefina.mendez@correo.ucu.edu.uy', '2003-12-03', 3, 'grado'),
                                                                                                   (40000305, 'Facundo', 'Castro', 'facundo.castro@correo.ucu.edu.uy', '1983-02-08', 3, 'funcionario'),
                                                                                                   (40000306, 'Carolina', 'Ramírez', 'carolina.ramirez@correo.ucu.edu.uy', '2002-04-13', 3, 'posgrado'),
                                                                                                   (40000401, 'Tomás', 'Acosta', 'tomas.acosta@correo.ucu.edu.uy', '2001-07-18', 4, 'grado'),
                                                                                                   (40000402, 'Paula', 'Benítez', 'paula.benitez@correo.ucu.edu.uy', '2002-09-23', 4, 'grado'),
                                                                                                   (40000403, 'Gonzalo', 'Morales', 'gonzalo.morales@correo.ucu.edu.uy', '2003-11-01', 4, 'grado'),
                                                                                                   (40000404, 'Victoria', 'Olivera', 'victoria.olivera@correo.ucu.edu.uy', '2004-01-06', 4, 'grado'),
                                                                                                   (40000405, 'Rodrigo', 'Vázquez', 'rodrigo.vazquez@correo.ucu.edu.uy', '2001-03-11', 4, 'posgrado'),
                                                                                                   (40000406, 'Laura', 'Hernández', 'laura.hernandez@correo.ucu.edu.uy', '1985-05-16', 4, 'docente'),
                                                                                                   (40000501, 'Emiliano', 'Rivero', 'emiliano.rivero@correo.ucu.edu.uy', '2002-08-21', 5, 'grado'),
                                                                                                   (40000502, 'Julieta', 'Torres', 'julieta.torres@correo.ucu.edu.uy', '1998-10-26', 5, 'posgrado'),
                                                                                                   (40000503, 'Ignacio', 'Ferreira', 'ignacio.ferreira@correo.ucu.edu.uy', '2004-12-04', 5, 'grado'),
                                                                                                   (40000504, 'Antonella', 'Gómez', 'antonella.gomez@correo.ucu.edu.uy', '2005-02-09', 5, 'grado'),
                                                                                                   (40000505, 'Maximiliano', 'Medina', 'maximiliano.medina@correo.ucu.edu.uy', '1985-04-14', 5, 'docente'),
                                                                                                   (40000506, 'Daniela', 'Correa', 'daniela.correa@correo.ucu.edu.uy', '2002-06-19', 5, 'grado'),
                                                                                                   (40000601, 'Felipe', 'Techera', 'felipe.techera@correo.ucu.edu.uy', '2003-09-24', 6, 'grado'),
                                                                                                   (40000602, 'Rocío', 'Machado', 'rocio.machado@correo.ucu.edu.uy', '2004-11-02', 6, 'grado'),
                                                                                                   (40000603, 'Lucas', 'Viera', 'lucas.viera@correo.ucu.edu.uy', '2005-01-07', 6, 'grado'),
                                                                                                   (40000604, 'Natalia', 'Sánchez', 'natalia.sanchez@correo.ucu.edu.uy', '1985-03-12', 6, 'funcionario'),
                                                                                                   (40000605, 'Andrés', 'Bentancor', 'andres.bentancor@correo.ucu.edu.uy', '2001-05-17', 6, 'posgrado'),
                                                                                                   (40000606, 'Mariana', 'De los Santos', 'mariana.delossantos@correo.ucu.edu.uy', '2003-07-22', 6, 'grado');

INSERT INTO torneo (nombre, anio, semestre, fecha_inicio, fecha_fin, estado) VALUES
    ('Torneo 2026-2', 2026, 2, '2026-10-01', '2026-11-30', 'en curso');

INSERT INTO equipo (nombre, id_torneo, id_facultad, ci_capitan) VALUES
                                                                    ('Los Ingenieros', 1, 1, 40000101),
                                                                    ('Leguleyos FC', 1, 2, 40000201),
                                                                    ('Empresarios United', 1, 3, 40000301),
                                                                    ('Salud FC', 1, 4, 40000401),
                                                                    ('Psico Team', 1, 5, 40000501),
                                                                    ('Humanistas', 1, 6, 40000601);

INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
                                                                                          (1, 40000101, 1, 1),
                                                                                          (1, 40000102, 1, 2),
                                                                                          (1, 40000103, 1, 5),
                                                                                          (1, 40000104, 1, 7),
                                                                                          (1, 40000105, 1, 9),
                                                                                          (1, 40000106, 1, 10),
                                                                                          (2, 40000201, 1, 1),
                                                                                          (2, 40000202, 1, 2),
                                                                                          (2, 40000203, 1, 5),
                                                                                          (2, 40000204, 1, 7),
                                                                                          (2, 40000205, 1, 9),
                                                                                          (2, 40000206, 1, 10),
                                                                                          (3, 40000301, 1, 1),
                                                                                          (3, 40000302, 1, 2),
                                                                                          (3, 40000303, 1, 5),
                                                                                          (3, 40000304, 1, 7),
                                                                                          (3, 40000305, 1, 9),
                                                                                          (3, 40000306, 1, 10),
                                                                                          (4, 40000401, 1, 1),
                                                                                          (4, 40000402, 1, 2),
                                                                                          (4, 40000403, 1, 5),
                                                                                          (4, 40000404, 1, 7),
                                                                                          (4, 40000405, 1, 9),
                                                                                          (4, 40000406, 1, 10),
                                                                                          (5, 40000501, 1, 1),
                                                                                          (5, 40000502, 1, 2),
                                                                                          (5, 40000503, 1, 5),
                                                                                          (5, 40000504, 1, 7),
                                                                                          (5, 40000505, 1, 9),
                                                                                          (5, 40000506, 1, 10),
                                                                                          (6, 40000601, 1, 1),
                                                                                          (6, 40000602, 1, 2),
                                                                                          (6, 40000603, 1, 5),
                                                                                          (6, 40000604, 1, 7),
                                                                                          (6, 40000605, 1, 9),
                                                                                          (6, 40000606, 1, 10);

INSERT INTO complejo (nombre, direccion, departamento) VALUES
                                                           ('Complejo Central', 'Av. Italia 3200', 'Montevideo'),
                                                           ('Polideportivo del Este', 'Av. Giannattasio km 20', 'Canelones');

INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
                                                                         ('Cancha 1', 1, 'sintetico', FALSE),
                                                                         ('Cancha 2', 1, 'parquet', TRUE),
                                                                         ('Cancha 1', 2, 'sintetico', TRUE);

INSERT INTO turno (hora_inicio, hora_fin) VALUES
                                              (18, 19),
                                              (19, 20),
                                              (20, 21),
                                              (21, 22),
                                              (22, 23);

INSERT INTO partido (id_cancha, id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante, dia, id_turno, nombre_cancha, id_complejo, estado) VALUES
                                                                                                                                                      (1, 1, 1, 1, 2, '2026-10-05', 1, 'Cancha 1', 1, 'jugado'),
                                                                                                                                                      (1, 1, 1, 3, 4, '2026-10-05', 2, 'Cancha 1', 1, 'jugado'),
                                                                                                                                                      (2, 1, 1, 5, 6, '2026-10-05', 1, 'Cancha 2', 1, 'jugado'),
                                                                                                                                                      (1, 1, 2, 1, 3, '2026-10-12', 2, 'Cancha 1', 1, 'jugado'),
                                                                                                                                                      (2, 1, 2, 2, 5, '2026-10-12', 3, 'Cancha 2', 1, 'jugado'),
                                                                                                                                                      (3, 1, 2, 4, 6, '2026-10-12', 2, 'Cancha 1', 2, 'jugado'),
                                                                                                                                                      (1, 1, 3, 1, 4, '2026-10-19', 1, 'Cancha 1', 1, 'jugado'),
                                                                                                                                                      (1, 1, 3, 2, 6, '2026-10-19', 2, 'Cancha 1', 1, 'jugado'),
                                                                                                                                                      (3, 1, 3, 3, 5, '2026-10-19', 1, 'Cancha 1', 2, 'jugado'),
                                                                                                                                                      (1, 1, 4, 1, 5, '2026-11-02', 3, 'Cancha 1', 1, 'programado'),
                                                                                                                                                      (2, 1, 4, 2, 4, '2026-11-02', 1, 'Cancha 2', 1, 'postergado'),
                                                                                                                                                      (3, 1, 4, 3, 6, '2026-11-02', 1, 'Cancha 1', 2, 'cancelado');

INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo) VALUES
                                                                     (1, 40000101, 1),
                                                                     (1, 40000102, 1),
                                                                     (1, 40000103, 1),
                                                                     (1, 40000104, 1),
                                                                     (1, 40000105, 1),
                                                                     (1, 40000201, 2),
                                                                     (1, 40000202, 2),
                                                                     (1, 40000203, 2),
                                                                     (1, 40000204, 2),
                                                                     (1, 40000205, 2),
                                                                     (2, 40000301, 3),
                                                                     (2, 40000302, 3),
                                                                     (2, 40000303, 3),
                                                                     (2, 40000304, 3),
                                                                     (2, 40000305, 3),
                                                                     (2, 40000401, 4),
                                                                     (2, 40000402, 4),
                                                                     (2, 40000403, 4),
                                                                     (2, 40000404, 4),
                                                                     (2, 40000405, 4),
                                                                     (3, 40000501, 5),
                                                                     (3, 40000502, 5),
                                                                     (3, 40000503, 5),
                                                                     (3, 40000504, 5),
                                                                     (3, 40000505, 5),
                                                                     (3, 40000601, 6),
                                                                     (3, 40000602, 6),
                                                                     (3, 40000603, 6),
                                                                     (3, 40000604, 6),
                                                                     (3, 40000605, 6),
                                                                     (4, 40000101, 1),
                                                                     (4, 40000102, 1),
                                                                     (4, 40000103, 1),
                                                                     (4, 40000104, 1),
                                                                     (4, 40000105, 1),
                                                                     (4, 40000301, 3),
                                                                     (4, 40000302, 3),
                                                                     (4, 40000304, 3),
                                                                     (4, 40000305, 3),
                                                                     (4, 40000306, 3),
                                                                     (5, 40000201, 2),
                                                                     (5, 40000202, 2),
                                                                     (5, 40000203, 2),
                                                                     (5, 40000204, 2),
                                                                     (5, 40000205, 2),
                                                                     (5, 40000501, 5),
                                                                     (5, 40000502, 5),
                                                                     (5, 40000503, 5),
                                                                     (5, 40000504, 5),
                                                                     (5, 40000505, 5),
                                                                     (6, 40000401, 4),
                                                                     (6, 40000402, 4),
                                                                     (6, 40000403, 4),
                                                                     (6, 40000404, 4),
                                                                     (6, 40000405, 4),
                                                                     (6, 40000601, 6),
                                                                     (6, 40000602, 6),
                                                                     (6, 40000603, 6),
                                                                     (6, 40000604, 6),
                                                                     (6, 40000606, 6),
                                                                     (7, 40000101, 1),
                                                                     (7, 40000102, 1),
                                                                     (7, 40000103, 1),
                                                                     (7, 40000104, 1),
                                                                     (7, 40000105, 1),
                                                                     (7, 40000401, 4),
                                                                     (7, 40000402, 4),
                                                                     (7, 40000403, 4),
                                                                     (7, 40000404, 4),
                                                                     (7, 40000405, 4),
                                                                     (8, 40000201, 2),
                                                                     (8, 40000202, 2),
                                                                     (8, 40000203, 2),
                                                                     (8, 40000204, 2),
                                                                     (8, 40000206, 2),
                                                                     (8, 40000601, 6),
                                                                     (8, 40000602, 6),
                                                                     (8, 40000603, 6),
                                                                     (8, 40000604, 6),
                                                                     (8, 40000605, 6),
                                                                     (9, 40000301, 3),
                                                                     (9, 40000302, 3),
                                                                     (9, 40000303, 3),
                                                                     (9, 40000304, 3),
                                                                     (9, 40000305, 3),
                                                                     (9, 40000501, 5),
                                                                     (9, 40000502, 5),
                                                                     (9, 40000503, 5),
                                                                     (9, 40000504, 5),
                                                                     (9, 40000506, 5);

INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
                                                              (1, 40000101, 5, FALSE),
                                                              (1, 40000103, 20, FALSE),
                                                              (1, 40000201, 30, FALSE),
                                                              (2, 40000301, 12, FALSE),
                                                              (2, 40000401, 33, FALSE),
                                                              (3, 40000501, 3, FALSE),
                                                              (3, 40000501, 18, FALSE),
                                                              (3, 40000502, 40, FALSE),
                                                              (4, 40000101, 10, FALSE),
                                                              (4, 40000302, 15, FALSE),
                                                              (4, 40000301, 38, FALSE),
                                                              (5, 40000201, 8, FALSE),
                                                              (5, 40000203, 25, FALSE),
                                                              (5, 40000503, 30, FALSE),
                                                              (5, 40000501, 44, FALSE),
                                                              (6, 40000601, 22, FALSE),
                                                              (6, 40000404, 35, TRUE),
                                                              (7, 40000101, 2, FALSE),
                                                              (7, 40000102, 14, FALSE),
                                                              (7, 40000104, 39, FALSE),
                                                              (7, 40000401, 27, FALSE),
                                                              (8, 40000202, 19, FALSE),
                                                              (8, 40000602, 41, FALSE),
                                                              (9, 40000503, 31, FALSE);

INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
                                                                (1, 40000102, 25, 'amarilla'),
                                                                (2, 40000303, 30, 'roja'),
                                                                (2, 40000402, 15, 'amarilla'),
                                                                (5, 40000205, 20, 'amarilla'),
                                                                (6, 40000402, 10, 'amarilla'),
                                                                (7, 40000402, 33, 'amarilla'),
                                                                (8, 40000601, 12, 'amarilla'),
                                                                (8, 40000202, 36, 'amarilla'),
                                                                (9, 40000304, 28, 'roja');

INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas) VALUES
                                                                                                      (40000303, 1, 'roja', 2, 1),
                                                                                                      (40000402, 1, 'acumulacion de amarillas', 4, 1),
                                                                                                      (40000304, 1, 'roja', 4, 1),
                                                                                                      (40000505, 1, 'disciplinaria', 3, 2);

USE OBLIGATORIO;

WITH goles_por_partido AS (
    SELECT p.id_partido,
           p.id_equipo_local,
           p.id_equipo_visitante,
           SUM(CASE WHEN (pp.id_equipo = p.id_equipo_local     AND g.autogol = FALSE)
               OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = TRUE)
                        THEN 1 ELSE 0 END) AS goles_local,
           SUM(CASE WHEN (pp.id_equipo = p.id_equipo_visitante AND g.autogol = FALSE)
               OR (pp.id_equipo = p.id_equipo_local     AND g.autogol = TRUE)
                        THEN 1 ELSE 0 END) AS goles_visitante
    FROM partido p
             LEFT JOIN gol g               ON g.id_partido = p.id_partido
             LEFT JOIN planilla_partido pp ON pp.id_partido = g.id_partido
        AND pp.ci_jugador = g.ci_jugador
    WHERE p.id_torneo = 1
      AND p.estado = 'jugado'
    GROUP BY p.id_partido, p.id_equipo_local, p.id_equipo_visitante
),
     resultados AS (
         SELECT id_equipo_local AS id_equipo, goles_local AS gf, goles_visitante AS gc
         FROM goles_por_partido
         UNION ALL
         SELECT id_equipo_visitante, goles_visitante, goles_local
         FROM goles_por_partido
     )
SELECT e.nombre                                  AS equipo,
       COUNT(r.id_equipo)                        AS pj,
       COALESCE(SUM(r.gf > r.gc), 0)             AS pg,
       COALESCE(SUM(r.gf = r.gc), 0)             AS pe,
       COALESCE(SUM(r.gf < r.gc), 0)             AS pp,
       COALESCE(SUM(r.gf), 0)                    AS gf,
       COALESCE(SUM(r.gc), 0)                    AS gc,
       COALESCE(SUM(r.gf) - SUM(r.gc), 0)        AS dg,
       COALESCE(SUM(CASE WHEN r.gf > r.gc THEN 3
                         WHEN r.gf = r.gc THEN 1
                         ELSE 0 END), 0)         AS puntos
FROM equipo e
         LEFT JOIN resultados r ON r.id_equipo = e.id_equipo
WHERE e.id_torneo = 1
GROUP BY e.id_equipo, e.nombre
ORDER BY puntos DESC, dg DESC, gf DESC;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       e.nombre AS equipo,
       COUNT(*) AS goles
FROM gol g
         JOIN partido p           ON p.id_partido = g.id_partido
         JOIN jugador j           ON j.ci_jugador = g.ci_jugador
         JOIN planilla_partido pp ON pp.id_partido = g.id_partido
    AND pp.ci_jugador = g.ci_jugador
         JOIN equipo e            ON e.id_equipo = pp.id_equipo
WHERE p.id_torneo = 1
  AND g.autogol = FALSE
GROUP BY j.ci_jugador, j.nombre, j.apellido, e.nombre
ORDER BY goles DESC, j.apellido
    LIMIT 10;

SELECT e.nombre AS equipo,
       COALESCE(SUM(t.color = 'amarilla'), 0) AS amarillas,
       COALESCE(SUM(t.color = 'roja'), 0)     AS rojas,
       COALESCE(SUM(CASE WHEN t.color = 'amarilla' THEN 1
                         WHEN t.color = 'roja'     THEN 3
                         ELSE 0 END), 0)      AS puntaje
FROM equipo e
         LEFT JOIN planilla_partido pp ON pp.id_equipo = e.id_equipo
         LEFT JOIN tarjeta t           ON t.id_partido = pp.id_partido
    AND t.ci_jugador = pp.ci_jugador
WHERE e.id_torneo = 1
GROUP BY e.id_equipo, e.nombre
ORDER BY puntaje ASC, e.nombre;

SELECT p.numero_fecha                                         AS fecha,
       COUNT(DISTINCT p.id_partido)                           AS partidos_jugados,
       COUNT(g.id_gol)                                        AS goles,
       ROUND(COUNT(g.id_gol) / COUNT(DISTINCT p.id_partido), 2) AS promedio
FROM partido p
         LEFT JOIN gol g ON g.id_partido = p.id_partido
WHERE p.id_torneo = 1
  AND p.estado = 'jugado'
GROUP BY p.numero_fecha
ORDER BY p.numero_fecha;

SELECT COUNT(DISTINCT p.id_partido)                           AS partidos_jugados,
       COUNT(g.id_gol)                                        AS goles,
       ROUND(COUNT(g.id_gol) / COUNT(DISTINCT p.id_partido), 2) AS promedio
FROM partido p
         LEFT JOIN gol g ON g.id_partido = p.id_partido
WHERE p.id_torneo = 1
  AND p.estado = 'jugado';

SELECT c.nombre_cancha,
       co.nombre  AS complejo,
       COUNT(*)   AS partidos
FROM partido p
         JOIN cancha c    ON c.id_cancha = p.id_cancha
         JOIN complejo co ON co.id_complejo = c.id_complejo
WHERE p.id_torneo = 1
  AND p.estado IN ('jugado', 'programado')
GROUP BY c.id_cancha, c.nombre_cancha, co.nombre
ORDER BY partidos DESC;

SELECT t.hora_inicio,
       t.hora_fin,
       COUNT(*) AS partidos
FROM partido p
         JOIN turno t ON t.id_turno = p.id_turno
WHERE p.id_torneo = 1
  AND p.estado IN ('jugado', 'programado')
GROUP BY t.id_turno, t.hora_inicio, t.hora_fin
ORDER BY partidos DESC, t.hora_inicio;

SELECT f.nombre AS facultad,
       j.tipo,
       COUNT(*) AS cantidad
FROM jugador j
         JOIN facultad f ON f.id_facultad = j.id_facultad
GROUP BY f.nombre, j.tipo
ORDER BY f.nombre, j.tipo;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       e.nombre AS equipo
FROM equipo_jugador_torneo ejt
         JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
         JOIN equipo e  ON e.id_equipo = ejt.id_equipo
WHERE ejt.id_torneo = 1
  AND NOT EXISTS (
    SELECT 1
    FROM planilla_partido pp
             JOIN partido p ON p.id_partido = pp.id_partido
    WHERE pp.ci_jugador = ejt.ci_jugador
      AND p.id_torneo = ejt.id_torneo
)
ORDER BY e.nombre, j.apellido;

SELECT e.nombre AS equipo,
       s.motivo,
       COUNT(*) AS cantidad
FROM sancion_jugador s
         JOIN equipo_jugador_torneo ejt ON ejt.ci_jugador = s.ci_jugador
    AND ejt.id_torneo = s.id_torneo
         JOIN equipo e                  ON e.id_equipo = ejt.id_equipo
WHERE s.id_torneo = 1
GROUP BY e.nombre, s.motivo
ORDER BY e.nombre, s.motivo;

SELECT estado,
       COUNT(*) AS partidos,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS porcentaje
FROM partido
WHERE id_torneo = 1
GROUP BY estado
ORDER BY partidos DESC;

SELECT p.numero_fecha AS fecha,
       p.dia,
       el.nombre AS local,
       SUM(CASE WHEN (pp.id_equipo = p.id_equipo_local     AND g.autogol = FALSE)
                  OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = TRUE)
                THEN 1 ELSE 0 END) AS goles_local,
       SUM(CASE WHEN (pp.id_equipo = p.id_equipo_visitante AND g.autogol = FALSE)
                  OR (pp.id_equipo = p.id_equipo_local     AND g.autogol = TRUE)
                THEN 1 ELSE 0 END) AS goles_visitante,
       ev.nombre AS visitante
FROM partido p
    JOIN equipo el                ON el.id_equipo = p.id_equipo_local
    JOIN equipo ev                ON ev.id_equipo = p.id_equipo_visitante
    LEFT JOIN gol g               ON g.id_partido = p.id_partido
    LEFT JOIN planilla_partido pp ON pp.id_partido = g.id_partido
    AND pp.ci_jugador = g.ci_jugador
WHERE p.id_torneo = 1
  AND p.estado = 'jugado'
GROUP BY p.id_partido, p.numero_fecha, p.dia, el.nombre, ev.nombre
ORDER BY p.numero_fecha, p.dia;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       s.motivo,
       s.numero_fecha_inicio,
       s.cantidad_fechas
FROM sancion_jugador s
         JOIN jugador j ON j.ci_jugador = s.ci_jugador
WHERE s.id_torneo = 1
  AND 4 BETWEEN s.numero_fecha_inicio
    AND s.numero_fecha_inicio + s.cantidad_fechas - 1
ORDER BY j.apellido;

SELECT j.ci_jugador,
       j.nombre,
       j.apellido,
       COUNT(*) AS amarillas
FROM tarjeta t
         JOIN partido p ON p.id_partido = t.id_partido
         JOIN jugador j ON j.ci_jugador = t.ci_jugador
WHERE p.id_torneo = 1
  AND t.color = 'amarilla'
GROUP BY j.ci_jugador, j.nombre, j.apellido
HAVING COUNT(*) = 2
ORDER BY j.apellido;
