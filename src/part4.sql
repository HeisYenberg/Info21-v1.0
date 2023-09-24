create database part4;

create table peer_info
(
);
create table peer_projects
(
);
create table school_info
(
);
create table super_table
(
);
create table TableName23
(
);
create table TableNameSuper
(
);

-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.
CREATE OR REPLACE PROCEDURE fnc_drop_tables_by_name(tname varchar = 'TableName', tapsd varchar = '123') AS
$$
DECLARE
    row record;
BEGIN
    FOR row IN (SELECT table_name
                FROM information_schema.tables
                WHERE table_name LIKE (tname || '%'))
        LOOP
            EXECUTE 'DROP TABLE ' || quote_ident(row.table_name) || ' CASCADE;';
        END LOOP;
END;
$$ language plpgsql;

CALL fnc_drop_tables_by_name('peer');
CALL fnc_drop_tables_by_name();

CREATE OR REPLACE FUNCTION fnc_get_function_params(func_name varchar) RETURNS varchar AS
$$
WITH RECURSIVE params AS
                   (SELECT ip.specific_name,
                           (ip.specific_name || ': ' || ip.parameter_name) AS param
                    FROM information_schema.parameters ip
                    WHERE ip.specific_name = func_name
                    UNION
                    SELECT ip.specific_name,
                           (params.param || ', ' || ip.parameter_name) AS param
                    FROM information_schema.parameters ip
                             JOIN params ON ip.specific_name = params.specific_name
                    WHERE param NOT LIKE ('%' || ip.parameter_name || '%'))

SELECT MAX(param)
FROM params;
$$ language sql;

-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен
-- и параметров всех скалярных SQL функций пользователя в текущей базе данных.
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться
-- в одну строку. Выходной параметр возвращает количество найденных функций.
CREATE OR REPLACE PROCEDURE fnc_get_funcs_with_params() AS
$$
-- DECLARE
--     functions tsquery[];
BEGIN
    SELECT fnc_get_function_params('' || routs.specific_name)
    FROM information_schema.routines routs
    WHERE routs.specific_schema = 'public';
--     func_count = COUNT(functions);
END;
$$ language plpgsql;

CALL fnc_get_funcs_with_params();