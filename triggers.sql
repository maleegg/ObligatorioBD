USE OBLIGATORIO;
SET NAMES utf8mb4;
 
DROP TRIGGER IF EXISTS trg_partido_valida_equipos;
 
-- usa $$ como delimitador para poder usar ; dentro del trigger
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
 
-- vuelve al delimitador por defecto (;)
DELIMITER ;