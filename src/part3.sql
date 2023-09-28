-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде
-- Ник пира 1, ник пира 2, количество переданных пир поинтов.
-- Количество отрицательное, если пир 2 получил от пира 1 больше поинтов.
CREATE OR REPLACE FUNCTION fnc_get_transferred_points()
    RETURNS TABLE
            (
                Peer1        varchar,
                Peer2        varchar,
                PointsAmount integer
            )
AS
$$
SELECT CASE WHEN checkingpeer < checkedpeer THEN checkingpeer ELSE checkedpeer END        as Peer1,
       CASE WHEN checkingpeer > checkedpeer THEN checkingpeer ELSE checkedpeer END        as Peer2,
       SUM(CASE WHEN checkingpeer < checkedpeer THEN pointsamount ELSE -pointsamount END) as PointsAmount
FROM transferredpoints
GROUP BY Peer1, Peer2
ORDER BY Peer1, Peer2;
$$ language sql;

SELECT *
FROM fnc_get_transferred_points();

-- 2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- В таблицу включать только задания, успешно прошедшие проверку (определять по таблице Checks).
-- Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включать все успешные проверки.
CREATE OR REPLACE FUNCTION fnc_get_checked_tasks()
    RETURNS TABLE
            (
                peer varchar,
                task varchar,
                xp   integer
            )
AS
$$
SELECT c.peer, c.task, xp.xpamount
FROM checks c
         JOIN xp ON c.id = xp."Check"
         JOIN p2p ON p2p."Check" = c.id
WHERE p2p.state = 'Success';
$$
    language sql;

SELECT *
FROM fnc_get_checked_tasks();


-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
-- Параметры функции: день, например 12.05.2022.
-- Функция возвращает только список пиров.
CREATE OR REPLACE FUNCTION fnc_get_peers_day_online(day date) RETURNS setof varchar
AS
$$
SELECT vin.nickname
FROM (SELECT nickname, COUNT(*) AS count
      FROM peers p
               JOIN timetracking tt ON tt.peer = p.nickname
      WHERE tt.state = 1
        AND tt."Date" = day
      GROUP BY nickname) AS vin
         JOIN (SELECT nickname, COUNT(*) AS count
               FROM peers p
                        JOIN timetracking tt ON tt.peer = p.nickname
               WHERE tt.state = 2
                 AND tt."Date" = day
               GROUP BY nickname) AS vout
              ON vin.nickname = vout.nickname AND vin.count = vout.count AND vin.count = 1;
$$ language sql;

SELECT *
FROM fnc_get_peers_day_online('2023-09-14');

SELECT *
FROM fnc_get_peers_day_online('2023-09-11');

SELECT *
FROM fnc_get_peers_day_online('2023-09-25');


-- 4) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов
CREATE OR REPLACE PROCEDURE prc_peer_points_change(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        SELECT Peer1 AS Peer, SUM(pointsamount) AS PointsChange
        FROM (SELECT checkingpeer as Peer1, checkedpeer as Peer2, pointsamount
              FROM transferredpoints
              UNION ALL
              SELECT checkedpeer as Peer1, checkingpeer as Peer2, -pointsamount
              FROM transferredpoints) as checks_div
        GROUP BY Peer1;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_peer_points_change();
FETCH ALL rc;
END;

-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов

CREATE OR REPLACE PROCEDURE prc_peer_points_change_by_task1(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        SELECT Peer1 AS Peer, SUM(pointsamount) AS PointsChange
        FROM (SELECT Peer1, Peer2, pointsamount
              FROM fnc_get_transferred_points()
              UNION ALL
              SELECT Peer2 as Peer1, Peer1 as Peer2, -pointsamount
              FROM fnc_get_transferred_points()) as checks_div
        GROUP BY Peer1;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_peer_points_change_by_task1();
FETCH ALL rc;
END;

-- 6) Определить самое часто проверяемое задание за каждый день
-- При одинаковом количестве проверок каких-то заданий в определенный день, вывести их все.
-- Формат вывода: день, название задания

CREATE OR REPLACE PROCEDURE prc_most_freq_checked_task(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH TaskCounts AS (SELECT "Date",
                                   Task,
                                   RANK() OVER (PARTITION BY "Date" ORDER BY COUNT(*) DESC) AS rank
                            FROM checks
                            GROUP BY "Date", task)
        SELECT "Date" AS Day, Task
        FROM TaskCounts
        WHERE rank = 1
        ORDER BY "Date";
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_most_freq_checked_task();
FETCH ALL rc;
END;

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например "CPP".
-- Результат вывести отсортированным по дате завершения.
-- Формат вывода: ник пира, дата завершения блока (т.е. последнего выполненного задания из этого блока)

CREATE OR REPLACE PROCEDURE prc_get_peers_done_block(block VARCHAR, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        SELECT Peer, "Date" AS Day
        FROM checks
                 JOIN p2p ON p2p."Check" = checks.id
        WHERE p2p.state = 'Success'
          AND task = (SELECT MAX(title) FROM tasks WHERE title ILIKE block || '%');
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_get_peers_done_block('C');
FETCH ALL rc;
END;

-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира, проверяться у которого рекомендует наибольшее число друзей.
-- Формат вывода: ник пира, ник найденного проверяющего

CREATE OR REPLACE PROCEDURE pr_most_recommended_peer(IN rc REFCURSOR = 'rc')
AS
$$
BEGIN
    OPEN rc FOR
        SELECT Peers.Nickname AS Peer,
               (SELECT RecommendedPeer
                FROM Recommendations
                         INNER JOIN Friends ON Recommendations.Peer = Friends.Peer2
                WHERE Friends.Peer1 = Peers.Nickname
                GROUP BY RecommendedPeer
                ORDER BY COUNT(RecommendedPeer)
                LIMIT 1)      AS MostRecommended
        FROM Peers;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL pr_most_recommended_peer();
FETCH ALL rc;
END;

-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
-- Пир считается приступившим к блоку, если он проходил хоть одну проверку любого задания из этого блока (по таблице Checks)
--
-- Параметры процедуры: название блока 1, например SQL, название блока 2, например A.
-- Формат вывода: процент приступивших только к первому блоку, процент приступивших только ко второму блоку, процент приступивших к обоим, процент не приступивших ни к одному

CREATE OR REPLACE PROCEDURE prc_blocks_percentage(block1 VARCHAR, block2 VARCHAR, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH peers_blocks AS (SELECT Peers.Nickname,
                                     CASE
                                         WHEN EXISTS (SELECT 1
                                                      FROM Checks
                                                      WHERE Checks.Peer = Peers.Nickname
                                                        AND Checks.Task LIKE CONCAT(block1, '%')) THEN 1
                                         ELSE 0 END AS started_block1,
                                     CASE
                                         WHEN EXISTS (SELECT 1
                                                      FROM Checks
                                                      WHERE Checks.Peer = Peers.Nickname
                                                        AND Checks.Task LIKE CONCAT(block2, '%')) THEN 1
                                         ELSE 0 END AS started_block2
                              FROM Peers)
        SELECT ROUND((COUNT(*) FILTER (WHERE started_block1 = 1) * 100.0 /
                      COUNT(*)), 2) AS StartedBlock1,
               ROUND((COUNT(*) FILTER (WHERE started_block2 = 1) * 100.0 /
                      COUNT(*)), 2) AS StartedBlock2,
               ROUND((COUNT(*) FILTER (WHERE started_block1 = 1 AND started_block2 = 1) * 100.0 /
                      COUNT(*)), 2) AS StartedBothBlocks,
               ROUND((COUNT(*) FILTER (WHERE started_block1 = 0 AND started_block2 = 0) * 100.0 /
                      COUNT(*)), 2) AS DidntStartAnyBlock
        FROM peers_blocks;
END
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_blocks_percentage('C', 'DO');
FETCH ALL rc;
END;

-- 10) Determine the percentage of peers who have ever successfully passed a check on their birthday
-- Also determine the percentage of peers who have ever failed a check on their birthday.
-- Output format: percentage of peers who have ever successfully passed a check on their birthday, percentage of peers who have ever failed a check on their birthday

CREATE OR REPLACE PROCEDURE prc_birthday_checks(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH birthday_checks AS (SELECT Peers.Nickname,
                                        CASE
                                            WHEN EXISTS (SELECT 1
                                                         FROM Checks
                                                                  INNER JOIN P2P ON Checks.id = P2P."Check"
                                                                  INNER JOIN Verter ON Checks.id = Verter."Check"
                                                         WHERE Checks.Peer = Peers.Nickname
                                                           AND P2P.State = 'Success'
                                                           AND Verter.state = 'Success') THEN 1
                                            ELSE 0 END AS check_state
                                 FROM Peers
                                          INNER JOIN Checks ON Peers.Nickname = Checks.Peer
                                 WHERE EXTRACT(MONTH FROM Peers.Birthday) = EXTRACT(MONTH FROM Checks."Date")
                                   AND EXTRACT(DAY FROM Peers.Birthday) = EXTRACT(DAY FROM Checks."Date"))
        SELECT CASE
                   WHEN COUNT(*) = 0 THEN NULL
                   ELSE ROUND((COUNT(*) FILTER (WHERE check_state = 1) * 100.0 /
                               COUNT(*))) END AS SuccessfulChecks,
               CASE
                   WHEN COUNT(*) = 0 THEN NULL
                   ELSE ROUND((COUNT(*) FILTER (WHERE check_state = 0) * 100.0 /
                               COUNT(*))) END AS UnsuccessfulChecks
        FROM birthday_checks;
END
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_birthday_checks();
FETCH ALL rc;
END;

-- 11) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE prc_peers_did_tasks(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH peers_tasks AS (SELECT Peers.Nickname,
                                    CASE
                                        WHEN EXISTS (SELECT 1
                                                     FROM Checks
                                                     WHERE Checks.Peer = Peers.Nickname
                                                       AND Checks.Task = task1) THEN 1
                                        ELSE 0 END AS did_task1,
                                    CASE
                                        WHEN EXISTS (SELECT 1
                                                     FROM Checks
                                                     WHERE Checks.Peer = Peers.Nickname
                                                       AND Checks.Task = task2) THEN 1
                                        ELSE 0 END AS did_task2,
                                    CASE
                                        WHEN EXISTS (SELECT 1
                                                     FROM Checks
                                                     WHERE Checks.Peer = Peers.Nickname
                                                       AND Checks.Task = task3) THEN 1
                                        ELSE 0 END AS did_task3
                             FROM Peers)
        SELECT Nickname
        FROM peers_tasks
        WHERE did_task1 = 1
          AND did_task2 = 1
          AND did_task3 = 0;
END
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_peers_did_tasks('C2_SimpleBashUtils', 'C2_SimpleBashUtils', 'C8_3DViewer_v1.0');
FETCH ALL rc;
END;

-- 12) Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей.
-- Формат вывода: название задачи, количество предшествующих

CREATE OR REPLACE PROCEDURE prc_preceding_tasks(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH RECURSIVE preceding_tasks AS (SELECT Title AS Task,
                                                  0     AS PrevCount
                                           FROM Tasks
                                           WHERE parenttask IS NULL
                                           UNION
                                           SELECT Tasks.Title,
                                                  preceding_tasks.PrevCount + 1 AS PrevCount
                                           FROM Tasks
                                                    INNER JOIN preceding_tasks ON Tasks.parenttask = preceding_tasks.Task)
        SELECT *
        FROM preceding_tasks;
END
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_preceding_tasks();
FETCH ALL rc;
END;

-- 13) Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks
-- Parameters of the procedure: the N number of consecutive successful checks .
-- The time of the check is the start time of the P2P step.
-- Successful consecutive checks are the checks with no unsuccessful checks in between.
-- The amount of XP for each of these checks must be at least 80% of the maximum.
-- Output format: list of days

CREATE OR REPLACE PROCEDURE prc_lucky_days(N INTEGER, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH successfull_checks AS (SELECT Checks."Date",
                                           COUNT(*) AS count_checks
                                    FROM Checks
                                             INNER JOIN P2P ON Checks.id = P2P."Check"
                                             INNER JOIN Verter ON Checks.id = Verter."Check"
                                    WHERE P2P.State = 'Success'
                                      AND Verter.State = 'Success'
                                    GROUP BY Checks."Date")
        SELECT "Date"
        FROM successfull_checks
        WHERE count_checks >= N;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_lucky_days(1);
FETCH ALL rc;
END;

-- 14) Определить пира с наибольшим количеством XP
-- Формат вывода: ник пира, количество XP

CREATE OR REPLACE PROCEDURE prc_peer_with_max_xp(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        SELECT Peer,
               SUM(XPAmount) AS XP
        FROM checks
                 INNER JOIN xp ON checks.ID = xp."Check"
        GROUP BY Peer
        ORDER BY XP DESC
        LIMIT 1;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_peer_with_max_xp();
FETCH ALL rc;
END;

-- 15) Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
-- Параметры процедуры: время, количество раз N.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE prc_came_before(before_time TIME, N INTEGER, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH visited_before AS (SELECT Peer, count(*) visits
                                FROM timetracking
                                WHERE "Time" < before_time
                                  AND state = 1
                                GROUP BY Peer, "Date")
        SELECT Peer
        FROM visited_before
        WHERE visits >= N;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_came_before('10:00:00', 1);
FETCH ALL rc;
END;

-- 16) Определить пиров, выходивших за последние N дней из кампуса больше M раз
-- Параметры процедуры: количество дней N, количество раз M.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE prc_going_outs(N INTEGER, M INTEGER, rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        WITH last_days AS (SELECT *
                           FROM timetracking
                           ORDER BY "Date" DESC
                           LIMIT N),
             going_outs AS (SELECT peer,
                                   COUNT(*) - 1 AS count_outs
                            FROM last_days
                            WHERE state = 2
                            GROUP BY peer, "Date")
        SELECT peer
        FROM going_outs
        WHERE count_outs > M;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_going_outs(12, 1);
FETCH ALL rc;
END;

-- 17) Определить для каждого месяца процент ранних входов
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время (будем называть это общим числом входов).
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов).
-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов.
-- Формат вывода: месяц, процент ранних входов

CREATE OR REPLACE PROCEDURE prc_early_entries(IN rc REFCURSOR = 'rc') AS
$$
BEGIN
    OPEN rc FOR
        SELECT TO_CHAR(Peers.Birthday, 'Month')                                 AS Month,
               (SUM(CASE WHEN "Time" < '12:00:00' THEN 1 END) * 100 / COUNT(*)) AS EarlyEntries
        FROM Peers
                 LEFT JOIN timetracking ON EXTRACT(MONTH FROM Peers.Birthday) = EXTRACT(MONTH FROM timetracking."Date")
        GROUP BY Month;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prc_early_entries();
FETCH ALL rc;
END;