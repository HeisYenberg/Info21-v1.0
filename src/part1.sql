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
    IF NEW.ParentTask IS NULL AND (SELECT COUNT(*) FROM Tasks WHERE Title <> NEW.Title AND ParentTask IS NULL) > 0 THEN
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
    AFTER UPDATE OR INSERT
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
    IF NEW.State = 'Start' AND (SELECT COUNT(*) FROM P2P WHERE "Check" = NEW."Check" AND State = 'Start') > 1 THEN
        RAISE EXCEPTION 'Checking already started!';
    ELSIF NEW.State IN ('Success', 'Failure') THEN
        IF (SELECT COUNT(*) FROM P2P WHERE "Check" = NEW."Check" AND State = 'Start') = 0 OR
           (SELECT COUNT(*) FROM P2P WHERE "Check" = NEW."Check" AND State IN ('Success', 'Failure')) > 1 THEN
            RAISE EXCEPTION 'Checking was not started or already finished!';
        END IF;
        IF NEW."Time" < (SELECT "Time" FROM P2P WHERE "Check" = NEW."Check" AND State = 'Start') THEN
            RAISE EXCEPTION 'End cannot be earlier than the start!';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_update
    AFTER UPDATE OR INSERT
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
    IF (SELECT COUNT(*) FROM P2P WHERE "Check" = NEW."Check" AND State = 'Success') = 0 THEN
        RAISE EXCEPTION 'Successful peer checking has not been completed!';
    ELSIF NEW.State = 'Start' AND (SELECT COUNT(*) FROM Verter WHERE "Check" = NEW."Check" AND State = 'Start') > 1 THEN
        RAISE EXCEPTION 'Checking already started!';
    ELSIF NEW.State IN ('Success', 'Failure') THEN
        IF (SELECT COUNT(*) FROM Verter WHERE "Check" = NEW."Check" AND State = 'Start') = 0 OR
           (SELECT COUNT(*) FROM Verter WHERE "Check" = NEW."Check" AND State IN ('Success', 'Failure')) > 1 THEN
            RAISE EXCEPTION 'Checking was not started or already finished!';
        END IF;
        IF NEW."Time" < (SELECT "Time" FROM Verter WHERE "Check" = NEW."Check" AND State = 'Start') THEN
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

CREATE OR REPLACE FUNCTION fnc_checks_check_state()
    RETURNS TRIGGER AS
$$
BEGIN
    IF (SELECT COUNT(*) FROM P2P WHERE "Check" = NEW."Check" AND State = 'Success') = 0 AND
       (SELECT COUNT(*) FROM Verter WHERE "Check" = NEW."Check" AND State = 'Success') = 0 THEN
        RAISE EXCEPTION 'Successful peer checking has not been completed!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_checks_update
    AFTER UPDATE OR INSERT
    ON Verter
    FOR EACH ROW
EXECUTE FUNCTION fnc_checks_check_state();

CREATE TABLE TransferredPoints
(
    ID           BIGSERIAL PRIMARY KEY NOT NULL,
    CheckingPeer VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    CheckedPeer  VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    PointsAmount INTEGER               NOT NULL,
    CONSTRAINT ch_unique_peers CHECK (CheckingPeer <> CheckedPeer)
);

CREATE OR REPLACE FUNCTION fnc_set_points_amount()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE TransferredPoints
    SET PointsAmount = (SELECT COUNT(*)
                        FROM TransferredPoints
                        WHERE CheckingPeer = NEW.CheckingPeer
                          AND CheckedPeer = NEW.CheckedPeer)
    WHERE ID = NEW.ID;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_checks_update
    AFTER INSERT
    ON TransferredPoints
    FOR EACH ROW
EXECUTE FUNCTION fnc_set_points_amount();

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

CREATE OR REPLACE PROCEDURE import_from_csv(ptable_name VARCHAR, ppath_to_file VARCHAR)
AS
$$
BEGIN
    EXECUTE CONCAT('COPY ', ptable_name, ' FROM ''', ppath_to_file, ''' WITH CSV HEADER;');
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_to_csv(ptable_name VARCHAR, ppath_to_file VARCHAR)
AS
$$
BEGIN
    EXECUTE CONCAT('COPY ', ptable_name, ' TO ''', ppath_to_file, ''' WITH CSV HEADER;');
END
$$ LANGUAGE plpgsql;

TRUNCATE P2P;

INSERT INTO P2P(ID, "Check", CheckingPeer, State, "Time")
VALUES (15, 7, 'scabberr', 'Success', '14:19:57');

INSERT INTO Checks(Peer, Task, "Date")
VALUES ('strangem', 'C2_SimpleBashUtils', NOW());

CALL import_from_csv('Peers', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/peers.csv');

CALL import_from_csv('Tasks', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/tasks.csv');

CALL import_from_csv('Checks', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/checks.csv');

CALL import_from_csv('P2P', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/p2p.csv');

CALL import_from_csv('Verter', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/verter.csv');

CALL import_from_csv('XP', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/xp.csv');

CALL import_from_csv('Friends', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/friends.csv');

CALL import_from_csv('Recommendations',
                     '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/recommendations.csv');

CALL import_from_csv('TransferredPoints',
                     '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/transferredpoints.csv');

CALL export_to_csv('P2P', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/p2p.csv');