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
    CONSTRAINT users_username_uni UNIQUE (username)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.users
    OWNER to postgres;

COMMENT ON TABLE access.users
    IS 'Пользователи';

GRANT INSERT, SELECT, UPDATE ON TABLE access.users TO tpss;

-- Table: access.groups

-- DROP TABLE IF EXISTS access.groups;

CREATE TABLE IF NOT EXISTS access.groups
(
    id      uuid                     NOT NULL DEFAULT uuid_generate_v4(),
    created timestamp with time zone NOT NULL DEFAULT now(),
    name    text COLLATE pg_catalog."default",
    CONSTRAINT groups_pkey PRIMARY KEY (id),
    CONSTRAINT groups_name_uni UNIQUE (name)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.groups
    OWNER to postgres;

COMMENT ON TABLE access.groups
    IS 'Группы';

GRANT INSERT, SELECT, UPDATE ON TABLE access.groups TO tpss;

-- Table: access.members

-- DROP TABLE IF EXISTS access.members;

CREATE TABLE IF NOT EXISTS access.members
(
    group_id uuid NOT NULL,
    user_id  uuid NOT NULL,
    CONSTRAINT members_group_member_uni UNIQUE (group_id, user_id),
    CONSTRAINT members_group_fkey FOREIGN KEY (group_id)
        REFERENCES access.groups (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT members_user_fkey FOREIGN KEY (user_id)
        REFERENCES access.users (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.members
    OWNER to postgres;

COMMENT ON TABLE access.members
    IS 'Участники групп';
-- Index: fki_members_group_fkey

-- DROP INDEX IF EXISTS access.fki_members_group_fkey;

CREATE INDEX IF NOT EXISTS fki_members_group_fkey
    ON access.members USING btree
        (group_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fki_members_user_fkey

-- DROP INDEX IF EXISTS access.fki_members_user_fkey;

CREATE INDEX IF NOT EXISTS fki_members_user_fkey
    ON access.members USING btree
        (user_id ASC NULLS LAST)
    TABLESPACE pg_default;

GRANT INSERT, SELECT, UPDATE ON TABLE access.members TO tpss;

-- Extension: pgcrypto

-- DROP EXTENSION pgcrypto;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- FUNCTION: access.add_group(text)

-- DROP FUNCTION IF EXISTS access.add_group(text);

CREATE OR REPLACE FUNCTION access.add_group(
    a_name text)
    RETURNS uuid
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_id uuid;
BEGIN

    INSERT INTO access.groups (name)
    VALUES (a_name)
    RETURNING id INTO v_id;

    RETURN v_id;

END
$BODY$;

ALTER FUNCTION access.add_group(text)
    OWNER TO postgres;

-- FUNCTION: access.add_user(text, text, text)

-- DROP FUNCTION IF EXISTS access.add_user(text, text, text, uuid);

CREATE OR REPLACE FUNCTION access.add_user(
    a_username text,
    a_password text,
    a_name text,
    a_group uuid
)
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

    INSERT INTO access.members (group_id, user_id)
    SELECT id, v_id
    FROM access.groups
    WHERE name = 'Администраторы'
    ON CONFLICT DO NOTHING;

    RETURN v_id;

END;
$BODY$;

ALTER FUNCTION access.add_user(text, text, text, uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION access.add_user(text, text, text, uuid)
    IS 'Добавляет пользователя';

SELECT access.add_user(
               'test', '123', 'Тестовый Тест Тестович',
               access.add_group('Администраторы')
       );

-- Table: access.objects

-- DROP TABLE IF EXISTS access.objects;

CREATE TABLE IF NOT EXISTS access.objects
(
    id   uuid NOT NULL DEFAULT uuid_generate_v4(),
    name text COLLATE pg_catalog."default",
    CONSTRAINT objects_pkey PRIMARY KEY (id)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.objects
    OWNER to postgres;

-- Type: access_type

-- DROP TYPE IF EXISTS access.access_type;

CREATE TYPE access.access_type AS ENUM
    ('read', 'write');

ALTER TYPE access.access_type
    OWNER TO postgres;

-- Table: access.rules

-- DROP TABLE IF EXISTS access.rules;

CREATE TABLE IF NOT EXISTS access.rules
(
    object_id uuid                 NOT NULL,
    group_id  uuid                 NOT NULL,
    access    access.access_type[] NOT NULL,
    CONSTRAINT rules_group_fkey FOREIGN KEY (group_id)
        REFERENCES access.groups (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT rules_object_fkey FOREIGN KEY (object_id)
        REFERENCES access.objects (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT rules_access_check CHECK (array_length(access, 1) <= 2)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.rules
    OWNER to postgres;
-- Index: fki_rules_group_fkey

-- DROP INDEX IF EXISTS access.fki_rules_group_fkey;

CREATE INDEX IF NOT EXISTS fki_rules_group_fkey
    ON access.rules USING btree
        (group_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fki_rules_object_fkey

-- DROP INDEX IF EXISTS access.fki_rules_object_fkey;

CREATE INDEX IF NOT EXISTS fki_rules_object_fkey
    ON access.rules USING btree
        (object_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: rules_uni_idx

-- DROP INDEX IF EXISTS access.rules_uni_idx;

CREATE UNIQUE INDEX IF NOT EXISTS rules_uni_idx
    ON access.rules USING btree
        (group_id ASC NULLS LAST, object_id ASC NULLS LAST)
    WITH (deduplicate_items=True)
    TABLESPACE pg_default;