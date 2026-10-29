USE OBLIGATORIO;

DROP TRIGGER IF EXISTS trg_partido_valida_equipos;

DELIMITER $$

CREATE TRIGGER trg_partido_valida_equipos
BEFORE INSERT ON partido
FOR EACH ROW
BEGIN
    DECLARE v_torneo_local INT;
    DECLARE v_torneo_visitante INT;
    DECLARE v_jugadores_local INT;
    DECLARE v_jugadores_visitante INT;

    SELECT id_torneo INTO v_torneo_local
    FROM equipo WHERE id_equipo = NEW.id_equipo_local;

    SELECT id_torneo INTO v_torneo_visitante
    FROM equipo WHERE id_equipo = NEW.id_equipo_visitante;

    IF v_torneo_local <> NEW.id_torneo OR v_torneo_visitante <> NEW.id_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben pertenecer a la edicion del torneo del partido';
    END IF;

    SELECT COUNT(*) INTO v_jugadores_local
    FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo_local;

    SELECT COUNT(*) INTO v_jugadores_visitante
    FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo_visitante;

    IF v_jugadores_local < 5 OR v_jugadores_visitante < 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben tener al menos 5 jugadores en su plantel';
    END IF;

    IF EXISTS (
        SELECT 1 FROM partido
        WHERE id_torneo = NEW.id_torneo
          AND estado <> 'cancelado'
          AND ((id_equipo_local = NEW.id_equipo_local AND id_equipo_visitante = NEW.id_equipo_visitante)
            OR (id_equipo_local = NEW.id_equipo_visitante AND id_equipo_visitante = NEW.id_equipo_local))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estos equipos ya tienen un partido en esta edicion';
    END IF;

    IF EXISTS (
        SELECT 1 FROM partido
        WHERE id_torneo = NEW.id_torneo
          AND numero_fecha = NEW.numero_fecha
          AND estado <> 'cancelado'
          AND (id_equipo_local IN (NEW.id_equipo_local, NEW.id_equipo_visitante)
            OR id_equipo_visitante IN (NEW.id_equipo_local, NEW.id_equipo_visitante))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Uno de los equipos ya juega en esa fecha del torneo';
    END IF;
END$$

DELIMITER ;