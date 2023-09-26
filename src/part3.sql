CREATE OR REPLACE PROCEDURE pr_most_checked_task()
AS
$$
BEGIN
    WITH counting_tasks AS (SELECT Checks."Date",
                                   Checks.Task,
                                   COUNT(Checks.Task) AS count_tasks
                            FROM Checks
                            GROUP BY Checks."Date", Checks.Task)
    SELECT "Date",
           Task
    FROM counting_tasks AS ct
    WHERE count_tasks = (SELECT MAX(count_tasks)
                         FROM counting_tasks
                         WHERE "Date" = ct."Date");
END
$$ LANGUAGE plpgsql;

CALL pr_most_checked_task();