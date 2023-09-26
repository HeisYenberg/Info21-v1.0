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
CREATE OR REPLACE FUNCTION fnc_peer_points_change()
    RETURNS TABLE
            (
                peer          varchar,
                points_change integer
            )
AS
$$
SELECT Peer1, SUM(pointsamount) AS points
FROM (SELECT checkingpeer as Peer1, checkedpeer as Peer2, pointsamount
      FROM transferredpoints
      UNION ALL
      SELECT checkedpeer as Peer1, checkingpeer as Peer2, -pointsamount
      FROM transferredpoints) as checks_div
GROUP BY Peer1;
$$ language sql;

SELECT *
FROM fnc_peer_points_change();


-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов
CREATE OR REPLACE FUNCTION fnc_peer_points_change_by_task1()
    RETURNS TABLE
            (
                peer          varchar,
                points_change integer
            )
AS
$$
SELECT Peer1, SUM(pointsamount) AS points
FROM (SELECT Peer1, Peer2, pointsamount
      FROM fnc_get_transferred_points()
      UNION ALL
      SELECT Peer2 as Peer1, Peer1 as Peer2, -pointsamount
      FROM fnc_get_transferred_points()) as checks_div
GROUP BY Peer1;
$$ language sql;

SELECT *
FROM fnc_peer_points_change();


-- 6) Определить самое часто проверяемое задание за каждый день
-- При одинаковом количестве проверок каких-то заданий в определенный день, вывести их все.
-- Формат вывода: день, название задания
CREATE OR REPLACE FUNCTION fnc_most_freq_checked_task()
    RETURNS TABLE
            (
                Day  date,
                Task varchar
            )
AS
$$
WITH TaskCounts AS (SELECT "Date",
                           task,
                           RANK() OVER (PARTITION BY "Date" ORDER BY COUNT(*) DESC) AS rank
                    FROM checks
                    GROUP BY "Date", task)
SELECT "Date", task
FROM TaskCounts
WHERE rank = 1
ORDER BY "Date";
$$ language sql;

SELECT *
FROM fnc_most_freq_checked_task();


-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например "CPP".
-- Результат вывести отсортированным по дате завершения.
-- Формат вывода: ник пира, дата завершения блока (т.е. последнего выполненного задания из этого блока)
CREATE OR REPLACE FUNCTION fnc_get_peers_done_block(block varchar)
    RETURNS TABLE
            (
                Peer varchar,
                Day  date
            )
AS
$$
SELECT peer, "Date"
FROM checks
         JOIN p2p ON p2p."Check" = checks.id
WHERE p2p.state = 'Success'
  AND task = (SELECT MAX(title) FROM tasks WHERE title ILIKE block || '%');
$$ language sql;

SELECT *
FROM fnc_get_peers_done_block('CPP');