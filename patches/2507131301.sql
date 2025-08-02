--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: access; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA access;


ALTER SCHEMA access OWNER TO postgres;

--
-- Name: crm; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA crm;


ALTER SCHEMA crm OWNER TO postgres;

--
-- Name: customs; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA customs;


ALTER SCHEMA customs OWNER TO postgres;

--
-- Name: erp; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA erp;


ALTER SCHEMA erp OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: access_type; Type: TYPE; Schema: access; Owner: postgres
--

CREATE TYPE access.access_type AS ENUM (
    'read',
    'write'
);


ALTER TYPE access.access_type OWNER TO postgres;

--
-- Name: param_type; Type: TYPE; Schema: customs; Owner: postgres
--

CREATE TYPE customs.param_type AS ENUM (
    'string',
    'int',
    'float'
);


ALTER TYPE customs.param_type OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: groups; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.groups (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text
);


ALTER TABLE access.groups OWNER TO postgres;

--
-- Name: TABLE groups; Type: COMMENT; Schema: access; Owner: postgres
--

COMMENT ON TABLE access.groups IS 'Группы';


--
-- Name: add_group(text); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_group(a_name text) RETURNS access.groups
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_group access.groups;
BEGIN

    INSERT INTO access.groups (name)
    VALUES (a_name)
    RETURNING * INTO v_group;

    RETURN v_group;

END
$$;


ALTER FUNCTION access.add_group(a_name text) OWNER TO postgres;

--
-- Name: objects; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.objects (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text,
    description text
);


ALTER TABLE access.objects OWNER TO postgres;

--
-- Name: add_object(text); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_object(a_name text) RETURNS access.objects
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_object access.objects;
BEGIN

    INSERT INTO access.objects (name)
    VALUES (a_name)
    RETURNING * INTO v_object;

    RETURN v_object;

END
$$;


ALTER FUNCTION access.add_object(a_name text) OWNER TO postgres;

--
-- Name: rules; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.rules (
    object_id uuid NOT NULL,
    group_id uuid NOT NULL,
    access access.access_type[] NOT NULL,
    CONSTRAINT rules_access_check CHECK ((array_length(access, 1) <= 2))
);


ALTER TABLE access.rules OWNER TO postgres;

--
-- Name: add_rule(uuid, uuid, access.access_type[]); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_rule(a_group uuid, a_object uuid, a_access access.access_type[]) RETURNS access.rules
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rules access.rules;
BEGIN

    INSERT INTO access.rules (group_id, object_id, access)
    VALUES (a_group, a_object, a_access)
	ON CONFLICT (group_id, object_id) DO UPDATE
	SET access=EXCLUDED.access
    RETURNING * INTO v_rules;

    RETURN v_rules;

END
$$;


ALTER FUNCTION access.add_rule(a_group uuid, a_object uuid, a_access access.access_type[]) OWNER TO postgres;

--
-- Name: sessions; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL
);


ALTER TABLE access.sessions OWNER TO postgres;

--
-- Name: add_session(uuid); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_session(a_user uuid) RETURNS access.sessions
    LANGUAGE plpgsql
    AS $$DECLARE v_session access.sessions;
BEGIN

UPDATE access.sessions
SET archived=true
WHERE user_id=a_user;

INSERT INTO access.sessions (
	user_id, token
) VALUES (
	a_user, gen_random_uuid()::text
)
RETURNING * INTO v_session;

RETURN v_session;

END$$;


ALTER FUNCTION access.add_session(a_user uuid) OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    username text,
    password text,
    name text
);


ALTER TABLE access.users OWNER TO postgres;

--
-- Name: TABLE users; Type: COMMENT; Schema: access; Owner: postgres
--

COMMENT ON TABLE access.users IS 'Пользователи';


--
-- Name: add_user(text, text, text, uuid); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_user(a_username text, a_password text, a_name text, a_group uuid) RETURNS access.users
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION access.add_user(a_username text, a_password text, a_name text, a_group uuid) OWNER TO postgres;

--
-- Name: FUNCTION add_user(a_username text, a_password text, a_name text, a_group uuid); Type: COMMENT; Schema: access; Owner: postgres
--

COMMENT ON FUNCTION access.add_user(a_username text, a_password text, a_name text, a_group uuid) IS 'Добавляет пользователя';


--
-- Name: clients; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.clients (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text
);


ALTER TABLE crm.clients OWNER TO postgres;

--
-- Name: add_client(text); Type: FUNCTION; Schema: crm; Owner: postgres
--

CREATE FUNCTION crm.add_client(a_name text) RETURNS crm.clients
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_client crm.clients;
BEGIN

    INSERT INTO crm.clients(name)
    VALUES (a_name)
    RETURNING * INTO v_client;

    RETURN v_client;
END
$$;


ALTER FUNCTION crm.add_client(a_name text) OWNER TO postgres;

--
-- Name: is_phone(text); Type: FUNCTION; Schema: crm; Owner: postgres
--

CREATE FUNCTION crm.is_phone(a_number text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- 8 (800) 000-00-00
    RETURN a_number ~ '^\d \(\d{3}\) \d{3}-\d{2}-\d{2}$';

END
$_$;


ALTER FUNCTION crm.is_phone(a_number text) OWNER TO postgres;

--
-- Name: members; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.members (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL
);


ALTER TABLE access.members OWNER TO postgres;

--
-- Name: TABLE members; Type: COMMENT; Schema: access; Owner: postgres
--

COMMENT ON TABLE access.members IS 'Участники групп';


--
-- Name: contracts; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.contracts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL
);


ALTER TABLE crm.contracts OWNER TO postgres;

--
-- Name: phones; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.phones (
    created timestamp with time zone DEFAULT now() NOT NULL,
    client_id uuid NOT NULL,
    number numeric
);


ALTER TABLE crm.phones OWNER TO postgres;

--
-- Name: tasks; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.tasks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    parent_id uuid,
    author_id uuid NOT NULL,
    description text NOT NULL
);


ALTER TABLE crm.tasks OWNER TO postgres;

--
-- Name: params; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params (
    id uuid NOT NULL,
    created timestamp with time zone,
    type customs.param_type NOT NULL,
    name text NOT NULL
);


ALTER TABLE customs.params OWNER TO postgres;

--
-- Name: params_float; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params_float (
    param_id uuid,
    object_id uuid NOT NULL,
    value double precision
);


ALTER TABLE customs.params_float OWNER TO postgres;

--
-- Name: params_int; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params_int (
    param_id uuid,
    object_id uuid NOT NULL,
    value bigint
);


ALTER TABLE customs.params_int OWNER TO postgres;

--
-- Name: params_string; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params_string (
    param_id uuid,
    object_id uuid NOT NULL,
    value text
);


ALTER TABLE customs.params_string OWNER TO postgres;

--
-- Name: equipment; Type: TABLE; Schema: erp; Owner: postgres
--

CREATE TABLE erp.equipment (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL
);


ALTER TABLE erp.equipment OWNER TO postgres;

--
-- Name: service_objects; Type: TABLE; Schema: erp; Owner: postgres
--

CREATE TABLE erp.service_objects (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL
);


ALTER TABLE erp.service_objects OWNER TO postgres;

--
-- Data for Name: groups; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.groups (id, created, name) FROM stdin;
a4608db9-4d64-4b38-833f-3fa1ea59c249	2025-07-20 19:31:12.173955+00	Администраторы
\.


--
-- Data for Name: members; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.members (group_id, user_id) FROM stdin;
a4608db9-4d64-4b38-833f-3fa1ea59c249	80d33387-faed-4218-b3eb-f87aa78c63d9
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.objects (id, created, name, description) FROM stdin;
a05eb8b7-5d6b-428e-ba5d-9271c128db03	2025-07-20 19:31:12.173955+00	settings	\N
\.


--
-- Data for Name: rules; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.rules (object_id, group_id, access) FROM stdin;
a05eb8b7-5d6b-428e-ba5d-9271c128db03	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.sessions (id, created, archived, user_id, token) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.users (id, created, username, password, name) FROM stdin;
80d33387-faed-4218-b3eb-f87aa78c63d9	2025-07-20 19:31:12.173955+00	test	$2a$06$0gNeVeHPY0RdT9gAuE0ceeLD0N9FZvv0phuT61grlKv9iQiqLojaC	Тестовый Тест Тестович
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.clients (id, created, name) FROM stdin;
07eafde9-dfe4-4564-b685-ecc70bcb1903	2025-07-20 19:31:12.173955+00	Test Клиент
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.contracts (id, created, name) FROM stdin;
\.


--
-- Data for Name: phones; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.phones (created, client_id, number) FROM stdin;
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.tasks (id, created, name, parent_id, author_id, description) FROM stdin;
\.


--
-- Data for Name: params; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params (id, created, type, name) FROM stdin;
\.


--
-- Data for Name: params_float; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params_float (param_id, object_id, value) FROM stdin;
\.


--
-- Data for Name: params_int; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params_int (param_id, object_id, value) FROM stdin;
\.


--
-- Data for Name: params_string; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params_string (param_id, object_id, value) FROM stdin;
\.


--
-- Data for Name: equipment; Type: TABLE DATA; Schema: erp; Owner: postgres
--

COPY erp.equipment (id, created, name) FROM stdin;
\.


--
-- Data for Name: service_objects; Type: TABLE DATA; Schema: erp; Owner: postgres
--

COPY erp.service_objects (id, created, name) FROM stdin;
\.


--
-- Name: groups groups_name_uni; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.groups
    ADD CONSTRAINT groups_name_uni UNIQUE (name);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: members members_group_member_uni; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.members
    ADD CONSTRAINT members_group_member_uni UNIQUE (group_id, user_id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_uni; Type: CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.users
    ADD CONSTRAINT users_username_uni UNIQUE (username);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: params params_pkey; Type: CONSTRAINT; Schema: customs; Owner: postgres
--

ALTER TABLE ONLY customs.params
    ADD CONSTRAINT params_pkey PRIMARY KEY (id);


--
-- Name: equipment equipment_pkey; Type: CONSTRAINT; Schema: erp; Owner: postgres
--

ALTER TABLE ONLY erp.equipment
    ADD CONSTRAINT equipment_pkey PRIMARY KEY (id);


--
-- Name: service_objects service_objects_pkey; Type: CONSTRAINT; Schema: erp; Owner: postgres
--

ALTER TABLE ONLY erp.service_objects
    ADD CONSTRAINT service_objects_pkey PRIMARY KEY (id);


--
-- Name: fki_members_group_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_members_group_fkey ON access.members USING btree (group_id);


--
-- Name: fki_members_user_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_members_user_fkey ON access.members USING btree (user_id);


--
-- Name: fki_rules_group_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_rules_group_fkey ON access.rules USING btree (group_id);


--
-- Name: fki_rules_object_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_rules_object_fkey ON access.rules USING btree (object_id);


--
-- Name: fki_sessions_user_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_sessions_user_fkey ON access.sessions USING btree (user_id);


--
-- Name: rules_uni_idx; Type: INDEX; Schema: access; Owner: postgres
--

CREATE UNIQUE INDEX rules_uni_idx ON access.rules USING btree (group_id, object_id) WITH (deduplicate_items='true');


--
-- Name: sessions_token_idx; Type: INDEX; Schema: access; Owner: postgres
--

CREATE UNIQUE INDEX sessions_token_idx ON access.sessions USING btree (token) WITH (deduplicate_items='true');


--
-- Name: fki_phones_client_fkey; Type: INDEX; Schema: crm; Owner: postgres
--

CREATE INDEX fki_phones_client_fkey ON crm.phones USING btree (client_id);


--
-- Name: fki_tasks_author_fkey; Type: INDEX; Schema: crm; Owner: postgres
--

CREATE INDEX fki_tasks_author_fkey ON crm.tasks USING btree (author_id);


--
-- Name: fki_tasks_parent_fkey; Type: INDEX; Schema: crm; Owner: postgres
--

CREATE INDEX fki_tasks_parent_fkey ON crm.tasks USING btree (parent_id);


--
-- Name: fki_params_float_param_fkey; Type: INDEX; Schema: customs; Owner: postgres
--

CREATE INDEX fki_params_float_param_fkey ON customs.params_float USING btree (param_id);


--
-- Name: fki_params_int_param_fkey; Type: INDEX; Schema: customs; Owner: postgres
--

CREATE INDEX fki_params_int_param_fkey ON customs.params_int USING btree (param_id);


--
-- Name: fki_params_string_param_fkey; Type: INDEX; Schema: customs; Owner: postgres
--

CREATE INDEX fki_params_string_param_fkey ON customs.params_string USING btree (param_id);


--
-- Name: members members_group_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.members
    ADD CONSTRAINT members_group_fkey FOREIGN KEY (group_id) REFERENCES access.groups(id);


--
-- Name: members members_user_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.members
    ADD CONSTRAINT members_user_fkey FOREIGN KEY (user_id) REFERENCES access.users(id);


--
-- Name: rules rules_group_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.rules
    ADD CONSTRAINT rules_group_fkey FOREIGN KEY (group_id) REFERENCES access.groups(id);


--
-- Name: rules rules_object_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.rules
    ADD CONSTRAINT rules_object_fkey FOREIGN KEY (object_id) REFERENCES access.objects(id);


--
-- Name: sessions sessions_user_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.sessions
    ADD CONSTRAINT sessions_user_fkey FOREIGN KEY (user_id) REFERENCES access.users(id);


--
-- Name: phones phones_client_fkey; Type: FK CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.phones
    ADD CONSTRAINT phones_client_fkey FOREIGN KEY (client_id) REFERENCES crm.clients(id);


--
-- Name: tasks tasks_author_fkey; Type: FK CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.tasks
    ADD CONSTRAINT tasks_author_fkey FOREIGN KEY (author_id) REFERENCES access.users(id);


--
-- Name: tasks tasks_parent_fkey; Type: FK CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.tasks
    ADD CONSTRAINT tasks_parent_fkey FOREIGN KEY (parent_id) REFERENCES crm.tasks(id);


--
-- Name: params_float params_float_fkey; Type: FK CONSTRAINT; Schema: customs; Owner: postgres
--

ALTER TABLE ONLY customs.params_float
    ADD CONSTRAINT params_float_fkey FOREIGN KEY (param_id) REFERENCES customs.params(id);


--
-- Name: params_int params_int_fkey; Type: FK CONSTRAINT; Schema: customs; Owner: postgres
--

ALTER TABLE ONLY customs.params_int
    ADD CONSTRAINT params_int_fkey FOREIGN KEY (param_id) REFERENCES customs.params(id);


--
-- Name: params_string params_string_fkey; Type: FK CONSTRAINT; Schema: customs; Owner: postgres
--

ALTER TABLE ONLY customs.params_string
    ADD CONSTRAINT params_string_fkey FOREIGN KEY (param_id) REFERENCES customs.params(id);


--
-- Name: SCHEMA access; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA access TO tpss;


--
-- Name: SCHEMA crm; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA crm TO tpss;


--
-- Name: SCHEMA customs; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA customs TO tpss;


--
-- Name: SCHEMA erp; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA erp TO tpss;


--
-- Name: TABLE groups; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.groups TO tpss;


--
-- Name: TABLE objects; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.objects TO tpss;


--
-- Name: TABLE rules; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.rules TO tpss;


--
-- Name: TABLE sessions; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.sessions TO tpss;


--
-- Name: TABLE users; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.users TO tpss;


--
-- Name: TABLE clients; Type: ACL; Schema: crm; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE crm.clients TO tpss;


--
-- Name: TABLE members; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE access.members TO tpss;


--
-- Name: TABLE contracts; Type: ACL; Schema: crm; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE crm.contracts TO tpss;


--
-- Name: TABLE phones; Type: ACL; Schema: crm; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE crm.phones TO tpss;


--
-- Name: TABLE tasks; Type: ACL; Schema: crm; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE crm.tasks TO tpss;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: crm; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA crm GRANT SELECT,INSERT,UPDATE ON TABLES TO tpss;


--
-- PostgreSQL database dump complete
--

