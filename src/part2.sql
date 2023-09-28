-- Задание 1: Процедура добавления P2P проверки
CREATE OR REPLACE PROCEDURE AddP2PCheck(
    p_checking_peer VARCHAR,
    p_checked_peer VARCHAR,
    p_task_title VARCHAR,
    p_status status,
    p_check_time TIME
)
AS
$$
DECLARE
    p_check_id BIGINT := (SELECT MAX(ID) + 1
                          FROM Checks);
    p2p_id     BIGINT := (SELECT MAX(ID) + 1
                          FROM P2P);
BEGIN
    IF p_status = 'Start' THEN
        INSERT INTO Checks(ID, Peer, Task, "Date")
        VALUES (p_check_id, p_checked_peer, p_task_title, current_date);

        INSERT INTO P2P(ID, "Check", CheckingPeer, State, "Time")
        VALUES (p2p_id, p_check_id, p_checking_peer, p_status, p_check_time);
    ELSE
        WITH t1 AS (SELECT C.ID as not_success_state
                    FROM Checks C
                             JOIN P2P P ON C.ID = P."Check"
                    WHERE State IN ('Success', 'Failure'))
        SELECT C.ID
        INTO p_check_id
        FROM Checks C
                 JOIN P2P P ON C.ID = P."Check"
        WHERE C.ID NOT IN (SELECT not_success_state FROM t1);
        INSERT INTO P2P(ID, "Check", CheckingPeer, State, "Time")
        VALUES (p2p_id, p_check_id, p_checking_peer, p_status, p_check_time);
    END IF;
END
$$ LANGUAGE plpgsql;

-- Задание 2: Процедура добавления проверки Verter'ом
CREATE OR REPLACE PROCEDURE AddVerterCheck(
    p_checking_peer VARCHAR,
    p_task_title VARCHAR,
    p_status status,
    p_check_time TIME
)
AS
$$
DECLARE
    check_id  BIGINT;
    verter_id BIGINT := (SELECT MAX(ID) + 1
                         FROM Verter);
BEGIN
    SELECT C.ID
    INTO check_id
    FROM Checks C
             JOIN P2P P ON C.ID = P."Check"
    WHERE C.Task = p_task_title
      AND P.checkingpeer = p_checking_peer
      AND P.State = 'Success'
    ORDER BY C."Date" DESC
    LIMIT 1;

    INSERT INTO Verter(ID, "Check", State, "Time")
    VALUES (verter_id, check_id, p_status, p_check_time);
END
$$ LANGUAGE plpgsql;

-- Задание 3: Триггер после добавления записи со статутом "начало" в таблицу P2P
CREATE OR REPLACE FUNCTION AfterInsertP2P()
    RETURNS TRIGGER AS
$$
DECLARE
    checked_peer VARCHAR := (SELECT Peer
                             FROM Checks
                             WHERE ID = New."Check");
BEGIN
    IF NEW.State = 'Start' THEN
        IF (SELECT COUNT(*)
            FROM TransferredPoints
            WHERE CheckingPeer = NEW.CheckingPeer
               OR CheckedPeer = checked_peer) > 0 THEN
            UPDATE TransferredPoints
            SET PointsAmount = PointsAmount + 1
            WHERE CheckingPeer = NEW.CheckingPeer
               OR CheckedPeer = checked_peer;
        ELSE
            INSERT INTO TransferredPoints
            VALUES ((SELECT COUNT(*) + 1 FROM TransferredPoints), NEW.CheckingPeer, checked_peer, 1);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER P2PAfterInsert
    AFTER INSERT
    ON P2P
    FOR EACH ROW
EXECUTE FUNCTION AfterInsertP2P();

-- Задание 4: Триггер перед добавлением записи в таблицу XP
CREATE OR REPLACE FUNCTION BeforeInsertXP()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.XPAmount <= (SELECT MaxXP
                        FROM Tasks T
                                 JOIN Checks C ON C.Task = T.Title
                        WHERE C.ID = NEW."Check") THEN
        IF EXISTS(SELECT 1
                  FROM Checks
                           JOIN Verter ON checks.id = verter."Check"
                  WHERE Verter.State = 'Success') THEN
            RETURN NEW;
        END IF;
    END IF;
    RAISE EXCEPTION 'Запись не прошла проверку';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER XpBeforeInsert
    BEFORE INSERT
    ON XP
    FOR EACH ROW
EXECUTE FUNCTION BeforeInsertXP();

CALL AddP2PCheck('strangem', 'butterba', 'D01_Linux', 'Start', '12:00:00');
CALL AddP2PCheck('strangem', 'butterba', 'D01_Linux', 'Success', '12:10:00');

CALL AddVerterCheck('strangem', 'D01_Linux', 'Start', '12:01:00');
CALL AddVerterCheck('strangem', 'D01_Linux', 'Success', '12:01:59');

INSERT INTO XP
VALUES (31, 31, 300);