USE OBLIGATORIO;
SET NAMES utf8mb4;

 -- TRIGGER 1: validacion al programar un partido (misma edicion, minimo 5 jugadores, sin rival repetido, un partido por fecha)
 -- usa $$ como delimitador para poder usar ; dentro del trigger

DROP TRIGGER IF EXISTS trg_partido_valida_equipos;

DELIMITER $$

CREATE TRIGGER trg_partido_valida_equipos
BEFORE INSERT ON partido        -- se ejecuta antes de insertar un partido
FOR EACH ROW                    -- ejecuta la validacion para cada fila que se inserta
BEGIN                           -- abre el bloque de codigo del trigger
    -- crea variables temporales para guardar el torneo y la cantidad de jugadores de cada equipo
    DECLARE v_torneo_local INT;
    DECLARE v_torneo_visitante INT;
    DECLARE v_jugadores_local INT;
    DECLARE v_jugadores_visitante INT;

-- REGLA 1: Misma edicion del torneo: ambos equipos deben pertenecer al mismo torneo que el partido.
    -- busca el torneo del equipo local y lo guarda en la variable. NEW es la fila que se esta por insertar.
    SELECT id_torneo INTO v_torneo_local
    FROM equipo WHERE id_equipo = NEW.id_equipo_local;

    SELECT id_torneo INTO v_torneo_visitante
    FROM equipo WHERE id_equipo = NEW.id_equipo_visitante;

    -- si alguno de los dos equipos no pertenece al torneo del partido, se lanza un error y se cancela la insercion
    IF v_torneo_local <> NEW.id_torneo OR v_torneo_visitante <> NEW.id_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben pertenecer a la edicion del torneo del partido';
    END IF;

-- REGLA 2: Minimo de 5 jugadores por equipo: ambos equipos deben tener al menos 5 jugadores en su plantel.
    SELECT COUNT(*) INTO v_jugadores_local
    FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo_local;

    SELECT COUNT(*) INTO v_jugadores_visitante
    FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo_visitante;

    IF v_jugadores_local < 5 OR v_jugadores_visitante < 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben tener al menos 5 jugadores en su plantel';
    END IF;

-- REGLA 3: Sin rival repetido: dos equipos no pueden enfrentarse dos veces en la misma edicion (salvo partido cancelado).
    IF EXISTS (                                 -- es verdadero si la subconsulta devuelve al menos una fila
        SELECT 1 FROM partido
        WHERE id_torneo = NEW.id_torneo         -- mira solo partidos de la misma edicion del torneo
          AND estado <> 'cancelado'             -- ignora los partidos cancelados
          -- busca el mismo cruce en cualquiera de los dos sentidos: si ya jugo A contra B, tampoco se permite B contra A
          AND ((id_equipo_local = NEW.id_equipo_local AND id_equipo_visitante = NEW.id_equipo_visitante)
            OR (id_equipo_local = NEW.id_equipo_visitante AND id_equipo_visitante = NEW.id_equipo_local))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estos equipos ya tienen un partido en esta edicion';
    END IF;

-- REGLA 4: Un partido por fecha: un equipo no puede jugar dos partidos en la misma fecha del torneo.
    IF EXISTS (
        SELECT 1 FROM partido
        WHERE id_torneo = NEW.id_torneo
          AND numero_fecha = NEW.numero_fecha   -- mira solo partidos de la misma fecha del torneo
          AND estado <> 'cancelado'
          -- busca si alguno de los dos equipos nuevos ya aparece, de local o de visitante, en esa fecha
          AND (id_equipo_local IN (NEW.id_equipo_local, NEW.id_equipo_visitante)
            OR id_equipo_visitante IN (NEW.id_equipo_local, NEW.id_equipo_visitante))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Uno de los equipos ya juega en esa fecha del torneo';
    END IF;
END$$                           -- cierra el trigger

DELIMITER ;
-- vuelve al delimitador por defecto (;)

-- TRIGGER 2: una cancha no puede tener mas de un partido en el mismo dia y turno

DROP TRIGGER IF EXISTS trg_partido_cancha_libre_insert;
DROP TRIGGER IF EXISTS trg_partido_cancha_libre_update;

DELIMITER $$

CREATE TRIGGER trg_partido_cancha_libre_insert
BEFORE INSERT ON partido
FOR EACH ROW
BEGIN
    IF NEW.estado NOT IN ('cancelado', 'postergado') AND EXISTS (
        SELECT 1 FROM partido
        WHERE id_cancha = NEW.id_cancha
          AND dia = NEW.dia
          AND id_turno = NEW.id_turno
          AND estado NOT IN ('cancelado', 'postergado')
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cancha ya tiene un partido asignado en ese dia y turno';
    END IF;
END$$

CREATE TRIGGER trg_partido_cancha_libre_update
BEFORE UPDATE ON partido
FOR EACH ROW
BEGIN
    IF NEW.estado NOT IN ('cancelado', 'postergado') AND EXISTS (
        SELECT 1 FROM partido
        WHERE id_partido <> NEW.id_partido
          AND id_cancha = NEW.id_cancha
          AND dia = NEW.dia
          AND id_turno = NEW.id_turno
          AND estado NOT IN ('cancelado', 'postergado')
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cancha ya tiene un partido asignado en ese dia y turno';
    END IF;
END$$

DELIMITER ;

-- TRIGGER 3: validacion de la planilla de juego

DROP TRIGGER IF EXISTS trg_planilla_valida_jugador;

DELIMITER $$

CREATE TRIGGER trg_planilla_valida_jugador
BEFORE INSERT ON planilla_partido
FOR EACH ROW
BEGIN
    DECLARE v_torneo INT;
    DECLARE v_fecha INT;
    DECLARE v_local INT;
    DECLARE v_visitante INT;

    SELECT id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante
      INTO v_torneo, v_fecha, v_local, v_visitante
    FROM partido
    WHERE id_partido = NEW.id_partido;

    IF NEW.id_equipo NOT IN (v_local, v_visitante) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El equipo indicado no participa en este partido';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM equipo_jugador_torneo
        WHERE id_equipo = NEW.id_equipo
          AND ci_jugador = NEW.ci_jugador
          AND id_torneo = v_torneo
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador no pertenece al plantel de ese equipo';
    END IF;

    IF EXISTS (
        SELECT 1 FROM sancion_jugador
        WHERE ci_jugador = NEW.ci_jugador
          AND id_torneo = v_torneo
          AND v_fecha BETWEEN numero_fecha_inicio
                          AND numero_fecha_inicio + cantidad_fechas - 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador esta suspendido en la fecha de este partido';
    END IF;
END$$

DELIMITER ;

-- =====================================================================================
-- REGLAS AGREGADAS PARA CUBRIR TODA LA LETRA
-- Los procedimientos (sp_...) agrupan validaciones que usan varios triggers,
-- asi la misma regla no se escribe dos veces. Un trigger puede llamar a un procedimiento con CALL.
-- La hora de "ahora" se toma de NOW(), que usa la zona horaria de Uruguay (-03:00).
-- =====================================================================================

DROP PROCEDURE IF EXISTS sp_validar_plantel;
DROP PROCEDURE IF EXISTS sp_validar_cruce_partido;
DROP PROCEDURE IF EXISTS sp_validar_datos_partido;
DROP PROCEDURE IF EXISTS sp_validar_carga_partido;
DROP PROCEDURE IF EXISTS sp_validar_en_planilla;
DROP PROCEDURE IF EXISTS sp_validar_jugador_en_torneo;

DROP TRIGGER IF EXISTS trg_equipo_insert;
DROP TRIGGER IF EXISTS trg_equipo_update;
DROP TRIGGER IF EXISTS trg_plantel_insert;
DROP TRIGGER IF EXISTS trg_plantel_update;
DROP TRIGGER IF EXISTS trg_plantel_delete;
DROP TRIGGER IF EXISTS trg_partido_datos_insert;
DROP TRIGGER IF EXISTS trg_partido_update;
DROP TRIGGER IF EXISTS trg_partido_delete;
DROP TRIGGER IF EXISTS trg_planilla_carga_insert;
DROP TRIGGER IF EXISTS trg_planilla_update;
DROP TRIGGER IF EXISTS trg_planilla_delete;
DROP TRIGGER IF EXISTS trg_gol_insert;
DROP TRIGGER IF EXISTS trg_gol_update;
DROP TRIGGER IF EXISTS trg_gol_delete;
DROP TRIGGER IF EXISTS trg_tarjeta_insert;
DROP TRIGGER IF EXISTS trg_tarjeta_update;
DROP TRIGGER IF EXISTS trg_tarjeta_delete;
DROP TRIGGER IF EXISTS trg_tarjeta_sancion_automatica;
DROP TRIGGER IF EXISTS trg_tarjeta_quitar_sancion;
DROP TRIGGER IF EXISTS trg_sancion_insert;
DROP TRIGGER IF EXISTS trg_sancion_update;

DELIMITER $$

-- -------------------------------------------------------------------------------------
-- PLANTELES: entre 5 y 10 jugadores, todos de la facultad del equipo, maximo 2
-- docentes/funcionarios, y solo se modifican mientras el torneo esta en inscripcion.
-- (El minimo de 5 se exige al programar un partido, en el TRIGGER 1.)
-- p_excluir_ci: en un UPDATE, el jugador de la fila vieja, para no contarlo dos veces.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_validar_plantel(IN p_equipo INT, IN p_ci INT, IN p_torneo INT, IN p_excluir_ci INT)
BEGIN
    DECLARE v_torneo_equipo INT;
    DECLARE v_facultad_equipo INT;
    DECLARE v_facultad_jugador INT;
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_estado VARCHAR(20);
    DECLARE v_cantidad INT;
    DECLARE v_no_estudiantes INT;

    SELECT id_torneo, id_facultad INTO v_torneo_equipo, v_facultad_equipo
    FROM equipo WHERE id_equipo = p_equipo;

    SELECT id_facultad, tipo INTO v_facultad_jugador, v_tipo
    FROM jugador WHERE ci_jugador = p_ci;

    SELECT estado INTO v_estado FROM torneo WHERE id_torneo = p_torneo;

    IF v_estado <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los planteles solo se pueden modificar mientras el torneo esta en inscripcion';
    END IF;

    IF v_torneo_equipo <> p_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El torneo indicado no coincide con el torneo del equipo';
    END IF;

    IF v_facultad_jugador <> v_facultad_equipo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador debe pertenecer a la facultad que representa el equipo';
    END IF;

    SELECT COUNT(*) INTO v_cantidad
    FROM equipo_jugador_torneo
    WHERE id_equipo = p_equipo
      AND (p_excluir_ci IS NULL OR ci_jugador <> p_excluir_ci);

    IF v_cantidad >= 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El plantel ya tiene 10 jugadores (maximo permitido)';
    END IF;

    IF v_tipo IN ('docente', 'funcionario') THEN
        SELECT COUNT(*) INTO v_no_estudiantes
        FROM equipo_jugador_torneo ejt
        JOIN jugador j ON j.ci_jugador = ejt.ci_jugador
        WHERE ejt.id_equipo = p_equipo
          AND j.tipo IN ('docente', 'funcionario')
          AND (p_excluir_ci IS NULL OR ejt.ci_jugador <> p_excluir_ci);

        IF v_no_estudiantes >= 2 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El plantel ya tiene 2 docentes/funcionarios (maximo permitido)';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_plantel_insert
BEFORE INSERT ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    CALL sp_validar_plantel(NEW.id_equipo, NEW.ci_jugador, NEW.id_torneo, NULL);
END$$

CREATE TRIGGER trg_plantel_update
BEFORE UPDATE ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    -- el capitan no puede salir de su equipo
    IF (NEW.id_equipo <> OLD.id_equipo OR NEW.ci_jugador <> OLD.ci_jugador)
       AND EXISTS (SELECT 1 FROM equipo WHERE id_equipo = OLD.id_equipo AND ci_capitan = OLD.ci_jugador) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede sacar al capitan del plantel: primero elija otro capitan';
    END IF;
    -- si sigue en el mismo equipo no se cuenta dos veces
    IF NEW.id_equipo = OLD.id_equipo THEN
        CALL sp_validar_plantel(NEW.id_equipo, NEW.ci_jugador, NEW.id_torneo, OLD.ci_jugador);
    ELSE
        CALL sp_validar_plantel(NEW.id_equipo, NEW.ci_jugador, NEW.id_torneo, NULL);
    END IF;
END$$

CREATE TRIGGER trg_plantel_delete
BEFORE DELETE ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los planteles solo se pueden modificar mientras el torneo esta en inscripcion';
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- EQUIPOS: se inscriben durante la inscripcion; el capitan es de la facultad del equipo
-- y no esta en otro equipo de esa edicion. Al cambiar de capitan, el nuevo debe estar
-- en el plantel. (La app agrega al capitan al plantel en la misma transaccion del alta.)
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_equipo_insert
BEFORE INSERT ON equipo
FOR EACH ROW
BEGIN
    IF (SELECT estado FROM torneo WHERE id_torneo = NEW.id_torneo) <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden inscribir equipos mientras el torneo esta en inscripcion';
    END IF;

    IF (SELECT id_facultad FROM jugador WHERE ci_jugador = NEW.ci_capitan) <> NEW.id_facultad THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El capitan debe pertenecer a la facultad del equipo';
    END IF;

    IF EXISTS (SELECT 1 FROM equipo_jugador_torneo
               WHERE ci_jugador = NEW.ci_capitan AND id_torneo = NEW.id_torneo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El capitan ya integra otro equipo en esta edicion';
    END IF;
END$$

CREATE TRIGGER trg_equipo_update
BEFORE UPDATE ON equipo
FOR EACH ROW
BEGIN
    IF (NEW.id_torneo <> OLD.id_torneo OR NEW.id_facultad <> OLD.id_facultad)
       AND EXISTS (SELECT 1 FROM equipo_jugador_torneo WHERE id_equipo = OLD.id_equipo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el torneo o la facultad de un equipo que ya tiene plantel';
    END IF;

    IF NEW.ci_capitan <> OLD.ci_capitan
       AND NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                       WHERE id_equipo = NEW.id_equipo AND ci_jugador = NEW.ci_capitan) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El capitan debe ser uno de los jugadores del plantel';
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- PARTIDOS
-- -------------------------------------------------------------------------------------

-- Reglas 1 a 4 del TRIGGER 1, pero para un UPDATE (excluye al propio partido)
CREATE PROCEDURE sp_validar_cruce_partido(IN p_id_partido INT, IN p_torneo INT, IN p_fecha INT,
                                          IN p_local INT, IN p_visitante INT)
BEGIN
    IF (SELECT id_torneo FROM equipo WHERE id_equipo = p_local) <> p_torneo
       OR (SELECT id_torneo FROM equipo WHERE id_equipo = p_visitante) <> p_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben pertenecer a la edicion del torneo del partido';
    END IF;

    IF (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_local) < 5
       OR (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_visitante) < 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben tener al menos 5 jugadores en su plantel';
    END IF;

    IF EXISTS (
        SELECT 1 FROM partido
        WHERE id_partido <> p_id_partido
          AND id_torneo = p_torneo
          AND estado <> 'cancelado'
          AND ((id_equipo_local = p_local AND id_equipo_visitante = p_visitante)
            OR (id_equipo_local = p_visitante AND id_equipo_visitante = p_local))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estos equipos ya tienen un partido en esta edicion';
    END IF;

    IF EXISTS (
        SELECT 1 FROM partido
        WHERE id_partido <> p_id_partido
          AND id_torneo = p_torneo
          AND numero_fecha = p_fecha
          AND estado <> 'cancelado'
          AND (id_equipo_local IN (p_local, p_visitante)
            OR id_equipo_visitante IN (p_local, p_visitante))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Uno de los equipos ya juega en esa fecha del torneo';
    END IF;
END$$

-- Datos generales: torneo no finalizado, dia dentro del torneo, y "jugado" solo si el dia y turno ya pasaron
CREATE PROCEDURE sp_validar_datos_partido(IN p_torneo INT, IN p_dia DATE, IN p_turno INT, IN p_estado VARCHAR(20))
BEGIN
    DECLARE v_estado_torneo VARCHAR(20);
    DECLARE v_inicio DATE;
    DECLARE v_fin DATE;
    DECLARE v_hora_fin INT;

    SELECT estado, fecha_inicio, fecha_fin INTO v_estado_torneo, v_inicio, v_fin
    FROM torneo WHERE id_torneo = p_torneo;

    IF v_estado_torneo = 'finalizado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El torneo ya finalizo: no se pueden programar ni modificar partidos';
    END IF;

    IF p_dia < v_inicio OR p_dia > v_fin THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El dia del partido debe estar dentro de las fechas del torneo';
    END IF;

    SELECT hora_fin INTO v_hora_fin FROM turno WHERE id_turno = p_turno;

    IF p_estado = 'jugado' AND NOW() < TIMESTAMP(p_dia, MAKETIME(v_hora_fin, 0, 0)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un partido solo puede marcarse como jugado cuando su dia y turno ya pasaron';
    END IF;
END$$

CREATE TRIGGER trg_partido_datos_insert
BEFORE INSERT ON partido
FOR EACH ROW
BEGIN
    CALL sp_validar_datos_partido(NEW.id_torneo, NEW.dia, NEW.id_turno, NEW.estado);
END$$

CREATE TRIGGER trg_partido_update
BEFORE UPDATE ON partido
FOR EACH ROW
BEGIN
    -- un partido jugado queda congelado: no cambia de estado (asi tampoco se puede cancelar y luego borrar)
    -- ni de equipos, fecha, dia, turno o cancha. Su resultado se corrige con los goles (ver 48 horas).
    IF OLD.estado = 'jugado' THEN
        IF NEW.estado <> 'jugado' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Un partido jugado no puede cambiar de estado';
        END IF;
        IF NEW.id_torneo <> OLD.id_torneo OR NEW.numero_fecha <> OLD.numero_fecha
           OR NEW.id_equipo_local <> OLD.id_equipo_local OR NEW.id_equipo_visitante <> OLD.id_equipo_visitante
           OR NEW.dia <> OLD.dia OR NEW.id_turno <> OLD.id_turno OR NEW.id_cancha <> OLD.id_cancha THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se pueden modificar los datos de un partido ya jugado';
        END IF;
    ELSE
        CALL sp_validar_datos_partido(NEW.id_torneo, NEW.dia, NEW.id_turno, NEW.estado);
        IF NEW.estado <> 'cancelado' THEN
            CALL sp_validar_cruce_partido(NEW.id_partido, NEW.id_torneo, NEW.numero_fecha,
                                          NEW.id_equipo_local, NEW.id_equipo_visitante);
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_partido_delete
BEFORE DELETE ON partido
FOR EACH ROW
BEGIN
    IF OLD.estado = 'jugado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un partido jugado no puede eliminarse';
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- PLANILLA, GOLES Y TARJETAS
-- Se cargan una vez disputado el partido (dia y turno pasados), nunca en partidos
-- cancelados o postergados, y si el partido ya esta marcado como jugado, solo dentro
-- de las 48 horas posteriores a su disputa.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_validar_carga_partido(IN p_id_partido INT)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_fin DATETIME;

    SELECT p.estado, TIMESTAMP(p.dia, MAKETIME(t.hora_fin, 0, 0))
      INTO v_estado, v_fin
    FROM partido p
    JOIN turno t ON t.id_turno = p.id_turno
    WHERE p.id_partido = p_id_partido;

    IF v_estado IN ('cancelado', 'postergado') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cargar la planilla de un partido cancelado o postergado';
    END IF;

    IF NOW() < v_fin THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El partido todavia no se disputo: la planilla se carga cuando termina';
    END IF;

    IF v_estado = 'jugado' AND NOW() > v_fin + INTERVAL 48 HOUR THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pasaron mas de 48 horas desde el partido: el resultado ya no se puede corregir';
    END IF;
END$$

-- Solo convierten goles o reciben tarjetas los jugadores que figuran en la planilla
CREATE PROCEDURE sp_validar_en_planilla(IN p_id_partido INT, IN p_ci INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM planilla_partido
                   WHERE id_partido = p_id_partido AND ci_jugador = p_ci) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador no figura en la planilla de este partido';
    END IF;
END$$

CREATE TRIGGER trg_planilla_carga_insert
BEFORE INSERT ON planilla_partido
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(NEW.id_partido);
END$$

CREATE TRIGGER trg_planilla_update
BEFORE UPDATE ON planilla_partido
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La planilla no se edita: quite al jugador y vuelva a agregarlo';
END$$

CREATE TRIGGER trg_planilla_delete
BEFORE DELETE ON planilla_partido
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(OLD.id_partido);
    IF EXISTS (SELECT 1 FROM gol WHERE id_partido = OLD.id_partido AND ci_jugador = OLD.ci_jugador)
       OR EXISTS (SELECT 1 FROM tarjeta WHERE id_partido = OLD.id_partido AND ci_jugador = OLD.ci_jugador) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador tiene goles o tarjetas en este partido: borrelos antes de quitarlo';
    END IF;
END$$

CREATE TRIGGER trg_gol_insert
BEFORE INSERT ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(NEW.id_partido);
    CALL sp_validar_en_planilla(NEW.id_partido, NEW.ci_jugador);
END$$

CREATE TRIGGER trg_gol_update
BEFORE UPDATE ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(OLD.id_partido);
    CALL sp_validar_carga_partido(NEW.id_partido);
    CALL sp_validar_en_planilla(NEW.id_partido, NEW.ci_jugador);
END$$

CREATE TRIGGER trg_gol_delete
BEFORE DELETE ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(OLD.id_partido);
END$$

CREATE TRIGGER trg_tarjeta_insert
BEFORE INSERT ON tarjeta
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(NEW.id_partido);
    CALL sp_validar_en_planilla(NEW.id_partido, NEW.ci_jugador);
END$$

-- Cambiar jugador, partido o color alteraria las sanciones automaticas: se borra y se vuelve a cargar
CREATE TRIGGER trg_tarjeta_update
BEFORE UPDATE ON tarjeta
FOR EACH ROW
BEGIN
    IF NEW.id_partido <> OLD.id_partido OR NEW.ci_jugador <> OLD.ci_jugador OR NEW.color <> OLD.color THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Para cambiar jugador o color de una tarjeta, borrela y carguela de nuevo';
    END IF;
    CALL sp_validar_carga_partido(OLD.id_partido);
END$$

CREATE TRIGGER trg_tarjeta_delete
BEFORE DELETE ON tarjeta
FOR EACH ROW
BEGIN
    CALL sp_validar_carga_partido(OLD.id_partido);
END$$

-- SANCION AUTOMATICA: roja -> 1 fecha; cada 3 amarillas en la edicion -> 1 fecha.
-- Se cumple en la fecha siguiente a la del partido.
CREATE TRIGGER trg_tarjeta_sancion_automatica
AFTER INSERT ON tarjeta
FOR EACH ROW
BEGIN
    DECLARE v_torneo INT;
    DECLARE v_fecha INT;
    DECLARE v_amarillas INT;

    SELECT id_torneo, numero_fecha INTO v_torneo, v_fecha
    FROM partido WHERE id_partido = NEW.id_partido;

    IF NEW.color = 'roja' THEN
        INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas)
        VALUES (NEW.ci_jugador, v_torneo, 'roja', v_fecha + 1, 1);
    ELSE
        SELECT COUNT(*) INTO v_amarillas
        FROM tarjeta t
        JOIN partido p ON p.id_partido = t.id_partido
        WHERE t.ci_jugador = NEW.ci_jugador
          AND p.id_torneo = v_torneo
          AND t.color = 'amarilla';

        IF v_amarillas % 3 = 0 THEN
            INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas)
            VALUES (NEW.ci_jugador, v_torneo, 'acumulacion de amarillas', v_fecha + 1, 1);
        END IF;
    END IF;
END$$

-- Si se borra una tarjeta cargada por error, se quita la sancion automatica que habia generado
CREATE TRIGGER trg_tarjeta_quitar_sancion
AFTER DELETE ON tarjeta
FOR EACH ROW
BEGIN
    DECLARE v_torneo INT;
    DECLARE v_fecha INT;
    DECLARE v_amarillas INT;
    DECLARE v_sanciones INT;

    SELECT id_torneo, numero_fecha INTO v_torneo, v_fecha
    FROM partido WHERE id_partido = OLD.id_partido;

    IF OLD.color = 'roja' THEN
        DELETE FROM sancion_jugador
        WHERE ci_jugador = OLD.ci_jugador
          AND id_torneo = v_torneo
          AND motivo = 'roja'
          AND numero_fecha_inicio = v_fecha + 1
        LIMIT 1;
    ELSE
        SELECT COUNT(*) INTO v_amarillas
        FROM tarjeta t
        JOIN partido p ON p.id_partido = t.id_partido
        WHERE t.ci_jugador = OLD.ci_jugador AND p.id_torneo = v_torneo AND t.color = 'amarilla';

        SELECT COUNT(*) INTO v_sanciones
        FROM sancion_jugador
        WHERE ci_jugador = OLD.ci_jugador AND id_torneo = v_torneo AND motivo = 'acumulacion de amarillas';

        IF v_sanciones > FLOOR(v_amarillas / 3) THEN
            DELETE FROM sancion_jugador
            WHERE ci_jugador = OLD.ci_jugador AND id_torneo = v_torneo AND motivo = 'acumulacion de amarillas'
            ORDER BY numero_fecha_inicio DESC
            LIMIT 1;
        END IF;
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- SANCIONES: solo para jugadores inscriptos en algun plantel de esa edicion
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_validar_jugador_en_torneo(IN p_ci INT, IN p_torneo INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                   WHERE ci_jugador = p_ci AND id_torneo = p_torneo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador no esta inscripto en ningun equipo de esa edicion del torneo';
    END IF;
END$$

CREATE TRIGGER trg_sancion_insert
BEFORE INSERT ON sancion_jugador
FOR EACH ROW
BEGIN
    CALL sp_validar_jugador_en_torneo(NEW.ci_jugador, NEW.id_torneo);
END$$

CREATE TRIGGER trg_sancion_update
BEFORE UPDATE ON sancion_jugador
FOR EACH ROW
BEGIN
    CALL sp_validar_jugador_en_torneo(NEW.ci_jugador, NEW.id_torneo);
END$$

DELIMITER ;

-- -------------------------------------------------------------------------------------
-- JUGADORES: al editar un jugador no se pueden romper las reglas de su plantel
-- (que sea de la facultad del equipo y maximo 2 docentes/funcionarios por plantel)
-- -------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_jugador_update;
DROP TRIGGER IF EXISTS trg_partido_con_planilla;

DELIMITER $$

CREATE TRIGGER trg_jugador_update
BEFORE UPDATE ON jugador
FOR EACH ROW
BEGIN
    IF NEW.id_facultad <> OLD.id_facultad AND EXISTS (
        SELECT 1 FROM equipo_jugador_torneo ejt
        JOIN equipo e ON e.id_equipo = ejt.id_equipo
        WHERE ejt.ci_jugador = OLD.ci_jugador AND e.id_facultad <> NEW.id_facultad
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar la facultad: el jugador integra un equipo de su facultad actual';
    END IF;

    -- si pasa a ser docente/funcionario, ninguno de sus equipos puede tener ya 2 de ese tipo
    IF NEW.tipo IN ('docente', 'funcionario') AND OLD.tipo NOT IN ('docente', 'funcionario') AND EXISTS (
        SELECT 1 FROM equipo_jugador_torneo ejt
        WHERE ejt.ci_jugador = OLD.ci_jugador
          AND (SELECT COUNT(*) FROM equipo_jugador_torneo x
               JOIN jugador j ON j.ci_jugador = x.ci_jugador
               WHERE x.id_equipo = ejt.id_equipo
                 AND j.tipo IN ('docente', 'funcionario')) >= 2
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el tipo: su equipo ya tiene 2 docentes/funcionarios';
    END IF;
END$$

-- PARTIDOS: si ya tiene planilla cargada, no se pueden cambiar sus equipos ni su torneo
-- (la planilla quedaria con jugadores de un equipo que ya no juega ese partido)
CREATE TRIGGER trg_partido_con_planilla
BEFORE UPDATE ON partido
FOR EACH ROW
BEGIN
    IF (NEW.id_equipo_local <> OLD.id_equipo_local OR NEW.id_equipo_visitante <> OLD.id_equipo_visitante
        OR NEW.id_torneo <> OLD.id_torneo)
       AND EXISTS (SELECT 1 FROM planilla_partido WHERE id_partido = OLD.id_partido) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El partido ya tiene planilla cargada: no se pueden cambiar sus equipos';
    END IF;
END$$

DELIMITER ;
