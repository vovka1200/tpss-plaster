COMMENT ON DATABASE tpss
    IS 'v25.07.13.13:01';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA access
    AUTHORIZATION postgres;

GRANT USAGE ON SCHEMA access TO tpss;

-- Table: access.users

-- DROP TABLE IF EXISTS access.users;

CREATE TABLE IF NOT EXISTS access.users
(
    id       uuid                     NOT NULL DEFAULT uuid_generate_v4(),
    created  timestamp with time zone NOT NULL DEFAULT now(),
    username text COLLATE pg_catalog."default",
    password text COLLATE pg_catalog."default",
    name     text COLLATE pg_catalog."default",
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT users_username_uniq UNIQUE (username)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.users
    OWNER to postgres;

COMMENT ON TABLE access.users
    IS 'Пользователи';

-- Extension: pgcrypto

-- DROP EXTENSION pgcrypto;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- FUNCTION: access.add_user(text, text, text)

-- DROP FUNCTION IF EXISTS access.add_user(text, text, text);

CREATE OR REPLACE FUNCTION access.add_user(
    a_username text,
    a_password text,
    a_name text)
    RETURNS uuid
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_id uuid DEFAULT NULL;
BEGIN

    INSERT INTO access.users (username,
                              password,
                              name)
    VALUES (a_username,
            crypt(a_password, gen_salt('bf')),
            a_name)
    RETURNING id INTO v_id;

    RETURN v_id;

END;
$BODY$;

ALTER FUNCTION access.add_user(text, text, text)
    OWNER TO postgres;

COMMENT ON FUNCTION access.add_user(text, text, text)
    IS 'Добавляет пользователя';

SELECT access.add_user(
               'test',
               '123',
               'Тестовый Тест Тестович'
       );