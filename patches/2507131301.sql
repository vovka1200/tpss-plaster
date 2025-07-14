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
    RETURNS access.groups
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_group access.groups;
BEGIN

    INSERT INTO access.groups (name)
    VALUES (a_name)
    RETURNING * INTO v_group;

    RETURN v_group;

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
    RETURNS access.users
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_user access.users DEFAULT NULL;
BEGIN

    INSERT INTO access.users (username,
                              password,
                              name)
    VALUES (a_username,
            crypt(a_password, gen_salt('bf')),
            a_name)
    RETURNING * INTO v_user;

    INSERT INTO access.members (group_id, user_id)
    VALUES (a_group, v_user.id)
    ON CONFLICT DO NOTHING;

    RETURN v_user;

END;
$BODY$;

ALTER FUNCTION access.add_user(text, text, text, uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION access.add_user(text, text, text, uuid)
    IS 'Добавляет пользователя';

SELECT access.add_user(
               'test', '123', 'Тестовый Тест Тестович',
               (SELECT id FROM access.add_group('Администраторы'))
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

-- FUNCTION: access.add_object(text)

-- DROP FUNCTION IF EXISTS access.add_object(text);

CREATE OR REPLACE FUNCTION access.add_object(
    a_name text)
    RETURNS access.objects
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_object access.objects;
BEGIN

    INSERT INTO access.objects (name)
    VALUES (a_name)
    RETURNING * INTO v_object;

    RETURN v_object;

END
$BODY$;

ALTER FUNCTION access.add_object(text)
    OWNER TO postgres;

-- FUNCTION: access.add_rule(uuid, uuid, access.access_type[])

-- DROP FUNCTION IF EXISTS access.add_rule(uuid, uuid, access.access_type[]);

CREATE OR REPLACE FUNCTION access.add_rule(
    a_group uuid,
    a_object uuid,
    a_access access.access_type[])
    RETURNS access.rules
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_rules access.rules;
BEGIN

    INSERT INTO access.rules (group_id, object_id, access)
    VALUES (a_group, a_object, a_access)
    RETURNING * INTO v_rules;

    RETURN v_rules;

END
$BODY$;

ALTER FUNCTION access.add_rule(uuid, uuid, access.access_type[])
    OWNER TO postgres;

-- SCHEMA: crm

-- DROP SCHEMA IF EXISTS crm ;

CREATE SCHEMA IF NOT EXISTS crm
    AUTHORIZATION postgres;

GRANT ALL ON SCHEMA crm TO postgres;

GRANT USAGE ON SCHEMA crm TO tpss;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA crm
    GRANT INSERT, SELECT, UPDATE ON TABLES TO tpss;

-- FUNCTION: crm.is_phone(text)

-- DROP FUNCTION IF EXISTS crm.is_phone(text);

CREATE OR REPLACE FUNCTION crm.is_phone(
    a_number text)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
BEGIN
    -- 8 (800) 000-00-00
    RETURN a_number ~ '^\d \(\d{3}\) \d{3}-\d{2}-\d{2}$';

END
$BODY$;

ALTER FUNCTION crm.is_phone(text)
    OWNER TO postgres;


-- Table: crm.clients

-- DROP TABLE IF EXISTS crm.clients;

CREATE TABLE IF NOT EXISTS crm.clients
(
    id      uuid                     NOT NULL DEFAULT uuid_generate_v4(),
    created timestamp with time zone NOT NULL DEFAULT now(),
    name    text COLLATE pg_catalog."default",
    CONSTRAINT clients_pkey PRIMARY KEY (id)
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS crm.clients
    OWNER to postgres;

REVOKE ALL ON TABLE crm.clients FROM tpss;

GRANT ALL ON TABLE crm.clients TO postgres;

GRANT INSERT, SELECT, UPDATE ON TABLE crm.clients TO tpss;

-- Table: crm.phones

-- DROP TABLE IF EXISTS crm.phones;

CREATE TABLE IF NOT EXISTS crm.phones
(
    client_id uuid                              NOT NULL,
    "number"  text COLLATE pg_catalog."default" NOT NULL,
    note      text COLLATE pg_catalog."default",
    CONSTRAINT phones_client_fkey FOREIGN KEY (client_id)
        REFERENCES crm.clients (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT phones_number_check CHECK (crm.is_phone(number))
)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS crm.phones
    OWNER to postgres;

REVOKE ALL ON TABLE crm.phones FROM tpss;

GRANT ALL ON TABLE crm.phones TO postgres;

GRANT INSERT, SELECT, UPDATE ON TABLE crm.phones TO tpss;
-- Index: fki_phones_client_fkey

-- DROP INDEX IF EXISTS crm.fki_phones_client_fkey;

CREATE INDEX IF NOT EXISTS fki_phones_client_fkey
    ON crm.phones USING btree
        (client_id ASC NULLS LAST)
    TABLESPACE pg_default;

-- FUNCTION: crm.add_client(text)

-- DROP FUNCTION IF EXISTS crm.add_client(text);

CREATE OR REPLACE FUNCTION crm.add_client(
    a_name text)
    RETURNS crm.clients
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS
$BODY$
DECLARE
    v_client crm.clients;
BEGIN

    INSERT INTO crm.clients(name)
    VALUES (a_name)
    RETURNING * INTO v_client;

    RETURN v_client;
END
$BODY$;

ALTER FUNCTION crm.add_client(text)
    OWNER TO postgres;
