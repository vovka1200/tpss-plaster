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
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    created timestamp with time zone NOT NULL DEFAULT now(),
    username text COLLATE pg_catalog."default",
    password text COLLATE pg_catalog."default",
    name text COLLATE pg_catalog."default",
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT users_username_uniq UNIQUE (username)
)

    TABLESPACE pg_default;

ALTER TABLE IF EXISTS access.users
    OWNER to postgres;

COMMENT ON TABLE access.users
    IS 'Пользователи';