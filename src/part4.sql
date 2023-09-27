create database part4;

create table if not exists peer_projects
(
);
create table if not exists school_info
(
);
create table if not exists TableNameNew
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
CREATE OR REPLACE PROCEDURE fnc_drop_tables_by_name() AS
$$
DECLARE
    row record;
BEGIN
    FOR row IN (SELECT table_name
                FROM information_schema.tables
                WHERE table_name ILIKE 'TableName%')
        LOOP
            EXECUTE 'DROP TABLE ' || quote_ident(row.table_name) || ' CASCADE;';
        END LOOP;
END;
$$ language plpgsql;

CALL fnc_drop_tables_by_name();


-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен
-- и параметров всех скалярных SQL функций пользователя в текущей базе данных.
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться
-- в одну строку. Выходной параметр возвращает количество найденных функций.
CREATE OR REPLACE FUNCTION fnc_some_fnc_1(p232 varchar, p111 bigint) RETURNS void AS
$$$$language sql;
CREATE OR REPLACE FUNCTION fnc_some_fnc_2(dogf varchar, pool bigint, sad char) RETURNS void AS
$$$$language sql;
CREATE OR REPLACE FUNCTION fnc_some_fnc_3(param2323 varchar) RETURNS void AS
$$$$language sql;
CREATE OR REPLACE FUNCTION fnc_some_fnc_4() RETURNS void AS
$$$$language sql;

CREATE OR REPLACE PROCEDURE fnc_get_funcs_with_params(OUT func_count integer) AS
$$
DECLARE
    func record;
BEGIN
    func_count := 0;
    FOR func in (SELECT routine_name, string_agg(parameter_name, ', ') as params
                 FROM information_schema.routines rt
                          LEFT JOIN information_schema.parameters pm ON rt.specific_name = pm.specific_name
                 WHERE routine_type = 'FUNCTION'
                   AND rt.specific_schema = 'public'
                 GROUP BY routine_name
                 ORDER BY routine_name)
        LOOP
            IF func IS NOT NULL THEN
                RAISE NOTICE 'Name: %, Params: %', func.routine_name, func.params;
            END IF;
            func_count := func_count + 1;
        END LOOP;
END;
$$ language plpgsql;

DO
$$
    DECLARE
        func_count integer;
    BEGIN
        CALL fnc_get_funcs_with_params(func_count);
        RAISE NOTICE 'Func found: %', func_count;
    END;
$$;


-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры
-- в текущей базе данных. Выходной параметр возвращает количество уничтоженных триггеров.
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

CREATE OR REPLACE TRIGGER trg_another_trigger
    AFTER DELETE OR UPDATE
    ON super_table
    FOR EACH ROW
EXECUTE PROCEDURE fnc_trigger_function();


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

DO
$$
    DECLARE
        triggers_dropped integer;
    BEGIN
        CALL fnc_drop_all_triggers(triggers_dropped);
        RAISE NOTICE 'Triggers dropped: %', triggers_dropped;
    END;
$$;


-- 4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания
-- типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.
CREATE OR REPLACE PROCEDURE fnc_print_objects_with_substr(IN substr varchar) AS
$$
DECLARE
    row record;
BEGIN
    FOR row IN (SELECT routine_name, routine_type
                FROM information_schema.routines
                WHERE (routine_type = 'FUNCTION' OR routine_type = 'PROCEDURE')
                  AND specific_schema = 'public'
                  AND routine_definition ILIKE '%' || substr || '%')
        LOOP
            RAISE NOTICE 'Name: %, Type desc: %', row.routine_name, row.routine_type;
        END LOOP;
END;
$$ language plpgsql;

CALL fnc_print_objects_with_substr('like');