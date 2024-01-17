CREATE DATABASE info21;

CREATE TABLE Peers
(
    Nickname VARCHAR PRIMARY KEY NOT NULL,
    Birthday DATE
);

CREATE TABLE Tasks
(
    Title      VARCHAR PRIMARY KEY NOT NULL,
    ParentTask VARCHAR,
    MaxXP      INTEGER             NOT NULL
);

CREATE OR REPLACE FUNCTION fnc_handle_parent_task()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.ParentTask IS NULL AND (SELECT COUNT(*) FROM Tasks) > 0 THEN
        RAISE EXCEPTION 'Where can be only one starting task!';
    ELSIF NEW.ParentTask IS NOT NULL AND (SELECT COUNT(*)
                                          FROM Tasks
                                          WHERE Title = NEW.ParentTask) = 0 THEN
        RAISE EXCEPTION 'Parent task not found!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tasks_update
    BEFORE UPDATE OR INSERT
    ON Tasks
    FOR EACH ROW
EXECUTE FUNCTION fnc_handle_parent_task();

CREATE TYPE status AS ENUM ( 'Start', 'Success', 'Failure');

CREATE TABLE Checks
(
    ID     BIGSERIAL PRIMARY KEY NOT NULL,
    Peer   VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    Task   VARCHAR               NOT NULL REFERENCES Tasks (Title),
    "Date" DATE                  NOT NULL
);

CREATE TABLE P2P
(
    ID           BIGSERIAL PRIMARY KEY NOT NULL,
    "Check"      BIGINT                NOT NULL REFERENCES Checks (ID),
    CheckingPeer VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    State        status                NOT NULL,
    "Time"       TIME                  NOT NULL
);

CREATE OR REPLACE FUNCTION fnc_p2p_check_state()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.State = 'Start' AND (SELECT COUNT(*)
                                FROM P2P
                                WHERE "Check" = NEW."Check"
                                  AND State = 'Start') > 1 THEN
        RAISE EXCEPTION 'Checking already started!';
    ELSIF NEW.State IN ('Success', 'Failure') THEN
        IF (SELECT COUNT(*)
            FROM P2P
            WHERE "Check" = NEW."Check" AND State = 'Start') = 0 OR
           (SELECT COUNT(*)
            FROM P2P
            WHERE "Check" = NEW."Check"
              AND State IN ('Success', 'Failure')) > 1 THEN
            RAISE EXCEPTION 'Checking was not started or already finished!';
        END IF;
        IF NEW."Time" < (SELECT "Time"
                         FROM P2P
                         WHERE "Check" = NEW."Check" AND State = 'Start') THEN
            RAISE EXCEPTION 'End cannot be earlier than the start!';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_update
    BEFORE UPDATE OR INSERT
    ON P2P
    FOR EACH ROW
EXECUTE FUNCTION fnc_p2p_check_state();

CREATE TABLE Verter
(
    ID      BIGSERIAL PRIMARY KEY NOT NULL,
    "Check" BIGINT                NOT NULL REFERENCES Checks (ID),
    State   status                NOT NULL,
    "Time"  TIME                  NOT NULL
);

CREATE OR REPLACE FUNCTION fnc_verter_check_state()
    RETURNS TRIGGER AS
$$
BEGIN
    IF (SELECT COUNT(*)
        FROM P2P
        WHERE "Check" = NEW."Check" AND State = 'Success') = 0 THEN
        RAISE EXCEPTION 'Successful peer checking has not been completed!';
    ELSIF NEW.State = 'Start' AND (SELECT COUNT(*)
                                   FROM Verter
                                   WHERE "Check" = NEW."Check"
                                     AND State = 'Start') > 1 THEN
        RAISE EXCEPTION 'Checking already started!';
    ELSIF NEW.State IN ('Success', 'Failure') THEN
        IF (SELECT COUNT(*)
            FROM Verter
            WHERE "Check" = NEW."Check" AND State = 'Start') = 0 OR
           (SELECT COUNT(*)
            FROM Verter
            WHERE "Check" = NEW."Check"
              AND State IN ('Success', 'Failure')) > 1 THEN
            RAISE EXCEPTION 'Checking was not started or already finished!';
        END IF;
        IF NEW."Time" < (SELECT "Time"
                         FROM Verter
                         WHERE "Check" = NEW."Check" AND State = 'Start') THEN
            RAISE EXCEPTION 'End cannot be earlier than the start!';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verter_update
    AFTER UPDATE OR INSERT
    ON Verter
    FOR EACH ROW
EXECUTE FUNCTION fnc_verter_check_state();

CREATE TABLE XP
(
    ID       BIGSERIAL PRIMARY KEY NOT NULL,
    "Check"  INTEGER               NOT NULL REFERENCES Checks (ID),
    XPAmount INTEGER               NOT NULL
);

CREATE TABLE TransferredPoints
(
    ID           BIGSERIAL PRIMARY KEY NOT NULL,
    CheckingPeer VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    CheckedPeer  VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    PointsAmount INTEGER               NOT NULL,
    CONSTRAINT ch_unique_peers CHECK (CheckingPeer <> CheckedPeer)
);

CREATE TABLE Friends
(
    ID    BIGSERIAL PRIMARY KEY NOT NULL,
    Peer1 VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    Peer2 VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    CONSTRAINT ch_unique_peers CHECK (Peer1 <> Peer2)
);

CREATE TABLE Recommendations
(
    ID              BIGSERIAL PRIMARY KEY NOT NULL,
    Peer            VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    RecommendedPeer VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    CONSTRAINT ch_unique_peers CHECK (Peer <> RecommendedPeer)
);

CREATE TABLE TimeTracking
(
    ID     BIGSERIAL PRIMARY KEY NOT NULL,
    Peer   VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    "Date" DATE                  NOT NULL,
    "Time" TIME                  NOT NULL,
    State  INTEGER               NOT NULL,
    CONSTRAINT ch_range_state CHECK (State IN (1, 2))
);

CREATE OR REPLACE FUNCTION fnc_time_tracking_update()
    RETURNS TRIGGER AS
$$
DECLARE
    prev_date          DATE;
    DECLARE prev_time  TIME;
    DECLARE prev_state INTEGER;
BEGIN
    WITH last_peer_state AS (SELECT "Date", "Time", State
                             FROM TimeTracking
                             WHERE Peer = NEW.Peer
                             ORDER BY "Date" DESC, "Time" DESC
                             LIMIT 1)
    SELECT "Date",
           "Time",
           State
    INTO prev_date, prev_time, prev_state
    FROM last_peer_state;
    IF prev_date IS NULL AND NEW.State = 2 THEN
        RAISE EXCEPTION 'First state cannot be exit!';
    ELSIF prev_state = NEW.State THEN
        RAISE EXCEPTION 'Peer cannot be in the same state twice in a row!';
    ELSIF (NEW."Date" < prev_date) OR
          (NEW."Date" = prev_date AND NEW."Time" < prev_time) THEN
        RAISE EXCEPTION 'New state cannot be earlier than the previous!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_time_tracking
    BEFORE INSERT
    ON TimeTracking
    FOR EACH ROW
EXECUTE FUNCTION fnc_time_tracking_update();

CREATE OR REPLACE PROCEDURE import_from_csv(ptable_name VARCHAR, ppath_to_file VARCHAR)
AS
$$
BEGIN
    EXECUTE CONCAT('COPY ', ptable_name, ' FROM ''', ppath_to_file,
                   ''' WITH CSV HEADER;');
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_to_csv(ptable_name VARCHAR, ppath_to_file VARCHAR)
AS
$$
BEGIN
    EXECUTE CONCAT('COPY ', ptable_name, ' TO ''', ppath_to_file,
                   ''' WITH CSV HEADER;');
END
$$ LANGUAGE plpgsql;

DO
$$
    DECLARE
        datasets_folder TEXT := '/mnt/c/Users/HeisYenberg/Developer/Projects/SQL/Info21_v1.0/datasets';
    BEGIN
        CALL import_from_csv('Peers', CONCAT(datasets_folder, 'peers.csv'));
        CALL import_from_csv('Tasks', CONCAT(datasets_folder, 'tasks.csv'));
        CALL import_from_csv('Checks', CONCAT(datasets_folder, 'checks.csv'));
        CALL import_from_csv('P2P', CONCAT(datasets_folder, 'p2p.csv'));
        CALL import_from_csv('Verter', CONCAT(datasets_folder, 'verter.csv'));
        CALL import_from_csv('XP', CONCAT(datasets_folder, 'xp.csv'));
        CALL import_from_csv('Friends', CONCAT(datasets_folder, 'friends.csv'));
        CALL import_from_csv('Recommendations',
                             CONCAT(datasets_folder, 'recommendations.csv'));
        CALL import_from_csv('TimeTracking',
                             CONCAT(datasets_folder, 'timetracking.csv'));
        CALL import_from_csv('TransferredPoints',
                             CONCAT(datasets_folder, 'transferredpoints.csv'));
    END
$$;