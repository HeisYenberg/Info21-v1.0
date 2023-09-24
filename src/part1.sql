CREATE TYPE status AS ENUM ( 'Start', 'Success', 'Failure');

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

CREATE TABLE Checks
(
    ID     BIGSERIAL PRIMARY KEY NOT NULL,
    Peer   VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    Task   VARCHAR               NOT NULL REFERENCES Tasks (Title),
    "Date" DATE                  NOT NULL
);

CREATE TABLE XP
(
    ID       BIGSERIAL PRIMARY KEY NOT NULL,
    "Check"  INTEGER               NOT NULL REFERENCES Checks (ID),
    XPAmount INTEGER               NOT NULL
);

CREATE TABLE Verter
(
    ID      BIGSERIAL PRIMARY KEY NOT NULL,
    "Check" BIGINT                NOT NULL REFERENCES Checks (ID),
    State   status                NOT NULL,
    "Time"  TIME                  NOT NULL
);

CREATE TABLE P2P
(
    ID           BIGSERIAL PRIMARY KEY NOT NULL,
    "Check"      BIGINT                NOT NULL REFERENCES Checks (ID),
    CheckingPeer VARCHAR               NOT NULL REFERENCES Peers (Nickname),
    State        status                NOT NULL,
    "Time"       TIME                  NOT NULL
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

CALL import_from_csv('Peers', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/peers.csv');

CALL import_from_csv('Tasks', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/tasks.csv');

CALL import_from_csv('Checks', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/checks.csv');

CALL import_from_csv('XP', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/xp.csv');

CALL import_from_csv('Peers', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/peers.csv');

CALL export_to_csv('Peers', '/mnt/c/Users/HeisYenberg/Developer/Projects/Info21_v1.0/src/peers.csv');