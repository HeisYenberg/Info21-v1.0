create database part4;

create table if not exists peer_info
(
);
create table if not exists peer_projects
(
);
create table if not exists school_info
(
);
create table if not exists super_table
(
);
create table if not exists TableName23
(
);
create table if not exists TableNameSuper
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
CREATE OR REPLACE PROCEDURE fnc_get_funcs_with_params(OUT func_count integer) AS
$$
DECLARE
    func varchar;
BEGIN
    func_count := 0;
    FOR func in (SELECT fnc_get_function_params('' || specific_name)
                 FROM information_schema.routines
                 WHERE specific_schema = 'public')
        LOOP
            IF func IS NOT NULL THEN
                RAISE NOTICE '%', func;
            END IF;
            func_count = func_count + 1;
        END LOOP;
END;
$$ language plpgsql;

CALL fnc_get_funcs_with_params(0);


CREATE OR REPLACE FUNCTION fnc_trigger_function() RETURNS TRIGGER AS
$$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_some_trigger
    AFTER INSERT OR UPDATE
    ON school_info
    FOR EACH ROW
EXECUTE PROCEDURE fnc_trigger_function();

-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры
-- в текущей базе данных. Выходной параметр возвращает количество уничтоженных триггеров.
CREATE OR REPLACE PROCEDURE fnc_drop_all_triggers(OUT dropped_triggers integer) AS
$$
DECLARE
    trigger record;
BEGIN
    dropped_triggers := 0;

    FOR trigger in (SELECT DISTINCT trigger_name, event_object_table
                    FROM information_schema.triggers
                    WHERE trigger_schema = 'public')
        LOOP
            EXECUTE 'DROP TRIGGER ' || quote_ident(trigger.trigger_name) || ' ON ' ||
                    quote_ident(trigger.event_object_table) || ';';
            dropped_triggers = dropped_triggers + 1;
        END LOOP;
END;
$$ language plpgsql;

CALL fnc_drop_all_triggers(0);