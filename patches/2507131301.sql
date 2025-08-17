--
-- PostgreSQL database dump
--

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

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
-- Name: files; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA files;


ALTER SCHEMA files OWNER TO postgres;

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
-- Name: entities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.entities (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.entities OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.groups ()
INHERITS (public.entities);


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

	SELECT * INTO v_group FROM access.groups WHERE name=a_name;

	IF v_group IS NULL THEN

	    INSERT INTO access.groups (name)
	    VALUES (a_name)
		ON CONFLICT DO NOTHING
	    RETURNING * INTO v_group;

	END IF;

    RETURN v_group;

END
$$;


ALTER FUNCTION access.add_group(a_name text) OWNER TO postgres;

--
-- Name: objects; Type: TABLE; Schema: access; Owner: postgres
--

CREATE TABLE access.objects (
    description text
)
INHERITS (public.entities);


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

	SELECT * INTO v_object FROM access.objects WHERE name=a_name;

	IF v_object IS NULL THEN

	    INSERT INTO access.objects (name)
	    VALUES (a_name)
		ON CONFLICT DO NOTHING
	    RETURNING * INTO v_object;

	END IF;

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
-- Name: add_rule(text, text, access.access_type[]); Type: FUNCTION; Schema: access; Owner: postgres
--

CREATE FUNCTION access.add_rule(a_group text, a_object text, a_access access.access_type[]) RETURNS access.rules
    LANGUAGE plpgsql
    AS $$BEGIN

RETURN access.add_rule(
	(access.add_group(a_group)).id,
	(access.add_object(a_object)).id,
	a_access
);

END$$;


ALTER FUNCTION access.add_rule(a_group text, a_object text, a_access access.access_type[]) OWNER TO postgres;

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
    username text,
    password text,
    avatar_id uuid
)
INHERITS (public.entities);


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

CREATE TABLE crm.clients ()
INHERITS (public.entities);


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
-- Name: matrix; Type: VIEW; Schema: access; Owner: postgres
--

CREATE VIEW access.matrix AS
 SELECT m.user_id,
    o.name AS object,
    r.access
   FROM ((access.rules r
     JOIN access.objects o ON ((o.id = r.object_id)))
     JOIN access.members m ON ((m.group_id = r.group_id)));


ALTER VIEW access.matrix OWNER TO postgres;

--
-- Name: companies; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.companies ()
INHERITS (public.entities);


ALTER TABLE crm.companies OWNER TO postgres;

--
-- Name: contracts; Type: TABLE; Schema: crm; Owner: postgres
--

CREATE TABLE crm.contracts ()
INHERITS (public.entities);


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
    parent_id uuid,
    author_id uuid NOT NULL,
    description text NOT NULL
)
INHERITS (public.entities);


ALTER TABLE crm.tasks OWNER TO postgres;

--
-- Name: params; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    type customs.param_type NOT NULL,
    name text NOT NULL,
    "default" text
);


ALTER TABLE customs.params OWNER TO postgres;

--
-- Name: COLUMN params."default"; Type: COMMENT; Schema: customs; Owner: postgres
--

COMMENT ON COLUMN customs.params."default" IS 'Значение по умолчанию';


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
-- Name: params_objects; Type: TABLE; Schema: customs; Owner: postgres
--

CREATE TABLE customs.params_objects (
    param_id uuid NOT NULL,
    object_id uuid NOT NULL
);


ALTER TABLE customs.params_objects OWNER TO postgres;

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
-- Name: files; Type: TABLE; Schema: files; Owner: postgres
--

CREATE TABLE files.files (
    body bytea,
    mime text DEFAULT 'application/octet-stream'::text NOT NULL
)
INHERITS (public.entities);


ALTER TABLE files.files OWNER TO postgres;

--
-- Name: avatars; Type: TABLE; Schema: files; Owner: postgres
--

CREATE TABLE files.avatars (
)
INHERITS (files.files);


ALTER TABLE files.avatars OWNER TO postgres;

--
-- Name: avatars id; Type: DEFAULT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.avatars ALTER COLUMN id SET DEFAULT public.uuid_generate_v4();


--
-- Name: avatars created; Type: DEFAULT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.avatars ALTER COLUMN created SET DEFAULT now();


--
-- Name: avatars mime; Type: DEFAULT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.avatars ALTER COLUMN mime SET DEFAULT 'application/octet-stream'::text;


--
-- Name: avatars updated; Type: DEFAULT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.avatars ALTER COLUMN updated SET DEFAULT now();


--
-- Data for Name: groups; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.groups (id, created, name, updated) FROM stdin;
a4608db9-4d64-4b38-833f-3fa1ea59c249	2025-07-20 19:31:12.173955+00	Администраторы	2025-08-17 06:47:24.839465+00
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

COPY access.objects (id, created, name, description, updated) FROM stdin;
a05eb8b7-5d6b-428e-ba5d-9271c128db03	2025-07-20 19:31:12.173955+00	settings	Настройки	2025-08-17 06:48:05.831273+00
e060a0ea-7837-45af-bd20-e97a3598267c	2025-07-30 19:14:05.823037+00	User	Пользователь	2025-08-17 06:48:05.831273+00
f37590d7-717f-4583-a141-5a9613857d4e	2025-08-15 15:16:46.23512+00	access.users.list	Список пользователей	2025-08-17 06:48:05.831273+00
0ba3c61f-4b61-4e78-9c5c-867ec00f6867	2025-08-15 15:28:05.6095+00	settings.params.list	Список параметров	2025-08-17 06:48:05.831273+00
6f38e4f6-1e2a-4504-b05f-752d5604e8fa	2025-08-15 15:26:52.079526+00	access.groups.list	Список групп пользователей	2025-08-17 06:48:05.831273+00
e837bdd2-abee-4fa1-9c9c-d11783ebc67f	2025-08-17 06:28:33.814724+00	access.groups.group.rules.list	\N	2025-08-17 06:48:05.831273+00
\.


--
-- Data for Name: rules; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.rules (object_id, group_id, access) FROM stdin;
a05eb8b7-5d6b-428e-ba5d-9271c128db03	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
e060a0ea-7837-45af-bd20-e97a3598267c	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
f37590d7-717f-4583-a141-5a9613857d4e	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
0ba3c61f-4b61-4e78-9c5c-867ec00f6867	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
6f38e4f6-1e2a-4504-b05f-752d5604e8fa	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
e837bdd2-abee-4fa1-9c9c-d11783ebc67f	a4608db9-4d64-4b38-833f-3fa1ea59c249	{read,write}
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.sessions (id, created, archived, user_id, token) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: access; Owner: postgres
--

COPY access.users (id, created, username, password, name, updated, avatar_id) FROM stdin;
80d33387-faed-4218-b3eb-f87aa78c63d9	2025-07-20 19:31:12.173955+00	test	$2a$06$0gNeVeHPY0RdT9gAuE0ceeLD0N9FZvv0phuT61grlKv9iQiqLojaC	Тестовый Тест Тестович	2025-08-11 20:28:00+00	878bf420-aa3d-4c0d-b3a2-15c68a5bce14
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.clients (id, created, name, updated) FROM stdin;
07eafde9-dfe4-4564-b685-ecc70bcb1903	2025-07-20 19:31:12.173955+00	Test Клиент	2025-08-17 06:49:45.804014+00
\.


--
-- Data for Name: companies; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.companies (id, created, name, updated) FROM stdin;
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.contracts (id, created, name, updated) FROM stdin;
\.


--
-- Data for Name: phones; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.phones (created, client_id, number) FROM stdin;
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: crm; Owner: postgres
--

COPY crm.tasks (id, created, name, parent_id, author_id, description, updated) FROM stdin;
\.


--
-- Data for Name: params; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params (id, created, type, name, "default") FROM stdin;
27c56111-356f-4c16-9cd8-0636a59f44b4	2025-07-27 19:01:58.832508+00	string	Юридический адрес	\N
83c5d6fb-44b3-4645-acce-7eefb6342460	2025-07-27 19:31:26.069295+00	string	Физический адрес	\N
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
-- Data for Name: params_objects; Type: TABLE DATA; Schema: customs; Owner: postgres
--

COPY customs.params_objects (param_id, object_id) FROM stdin;
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
-- Data for Name: avatars; Type: TABLE DATA; Schema: files; Owner: postgres
--

COPY files.avatars (id, created, name, body, mime, updated) FROM stdin;
530e25f8-eb60-4da6-9f55-efe3924b0e0b	2025-08-15 17:08:16.069219+00	IMG_20160220_080208.jpg	\\xffd8ffe000104a46494600010100000100010000ffe1006045786966000049492a0008000000020031010200070000002600000069870400010000002e00000000000000476f6f676c650000030000900700040000003032323002a00400010000008002000003a00400010000008002000000000000ffdb0084000302020a0a080909090908080808080705070707080707070707070707070707070707070707070707070707070a0707070809090907070b0d0a080d070809080103040406050607050508080707070808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808ffc00011080280028003011100021101031101ffc4001d000001050101010100000000000000000004020305060701080009ffc40041100001030302030605030203070403010001000203040511062107123141516171819108131422a132425223b11516c124334353d1e1f0171862f17292a234ffc4001a010003010101010000000000000000000000020301040506ffc4001d110101010101010101010100000000000000011102120313213141ffda000c03010002110311003f00f075c0ecbb27d5cd19b5f5879d5a75aac0d6f67de3cd6f9d6b79d3370c42078612df96944492e556d6c5535c1fb173f5558c8ab7aae7ad0d953c2ba4abc1a91b533ee0a85ad2ad148795356526eb09c2997141bc52ab190a46125090b715b0a90aa9b64f0216690953abbac8542b4fb9984ba4072bd1a53699b5f2d2be48d8f925aa47c920af974c4eba56d6470a8d6c702dd69e821caa462c364d2ae791857e631ade9ab3163402ab8123596fe6c612617d2eda46ec22c7324c3cab2d7ea1129d94ec5251f6da62370a7629a124b981284be53d5eacfad5b1e3d16e335b5e8dd78c90068f04d06b402490309b46809a7e5eab11206a803b52e03753aa1bba5c087a0be87bd2e05ea8a220672b4c16e3790ded4c0dc1a832374e0937a19403725c477a7a6d485bea8386173d8d1bf2d248dd74054863f12e9d23a42cd0fb0974057c6b34019a6c25b5b4f534b9532d3e254dc9709734ab4a30cc814804a858098a2db29404966394022429e1a81aa8709e2743b58b68890a40a754829c51ad391b9668333200474480fbe94a9fa0ec16b2b7d816cb794f3a07e1a229bd014290add0721a72100e1725a427e5a850fc7bb8c9b2de62319edda225e57672ac72db4879975f2d68d66ae21b856d2a7e0a9cae1b5915ed672fdaa16ab195563b74ad33ca9e465a516264f47da9ff0070f454868d4a867019e812b622ebeb8153362b37572be9105346a740cb7d2a7853971d82708931a8d54d35c54287ce9c953d04828d2d713cadaf9395f2cb1b1f295523e4bc8af974c4eba5356470a956c3d4ac19dd205b6df491819d95f960db5def95d86aeae605aa93519ed2ba700a7ea5206cb9ec7268fb6dedce233f84a79d2f9a6c38919598b4ad269f019bf729e292aa95920f9a3cd6f926a46bc671e8b306b41e145c9df35a3b32025c1af50c2f386f925c1aaeeae710d2563583ea3d7ae8dc46536019a5b5cba638cf86dba30349d2f4443b27cd6f9094d4fc416c23979b7e9d54829d4dad5d2bb00ecb427a8ee6ece16826eda83e58dfcfb90158ff00d4e6f36323bbaa70d1b476a86bbb54ec36af74b7169ed498d3f1b8158dd1102aeb0ef2a5d0eb6059a0d38a5d08bb84286d441b872a0b48ff001c6f7ad8cc4d5b2a4395060a95bb24601f9192806e60404a1125dba01e0e5b29a932ee9e54e87f91badb4414d894ea91ce650f4d7dce9e50f98c4f01c2dc2a0243947c8122a301679075932dc07626ac0948a34f283332a40064724a40efacc2850fc7d9e6d97abe1188d65b438ee92c560e75a5ade8b3d344dbdbba6f54a97150930b105ac24fb12e2b2b35785b218b6b15672424bd4f0b897b0d2ee9cd177f983954eb621aa0a9536a12f332ae9105f352e84f5b2e781854853556de6395480453da3214ec6ea36e96fe55cdd4322d4eb1f2c3be053c653802e89c92be7316de4d0da85e4f1f3d246d7caf13a5393566124a95363ac7ee920a2fea4e15a528bb453973b6cae89d068f67d2ce2cc905567402dd290b0a5d71d8374d5c70e469e46bda6ef236f458ae2cf7ed481b1841e403628be6efea9758b6beca39774ba04694d4ad82504ed82943d0ba5389ec9001cc3b92e05a2b256c8cfd43b516298f28f1c6d01ae7969ef2b60c56f80b75c38e7bcf5dd1a31e84aee25b636751d3c9668c79ab89fc55324e3076cf7acc2ae1a175a0e5183bede6b302f6de21e0819580f5eaf827675ec280c21b5ee1565a49eb8f04ecd6f3a26e84306e83342b6eadc6d952add68365bb7337aa9d6a7a0a94d80632a877ac016e1790ded4800525d038aca045605b29141d57363b70a902a14375cbc79ad3b54d36ed90130e910438c4022ae9414a1132dbc200574184b29a9c8c27953a70c68b447ce729daa436c87293cb45b68b09e4044f2613c08b9abb75480c9ae5d1e01b65c52f9091a3a9ca4b027e89a128395156028007515e1500092bd6520296a32a5607e40d7d4602f4af68c57ea2f841d94ef4ac7d497c713b9449ad5a2db2e42e89c112464d9161159d555f96e14ac562a14ecc95b1a92a8a4c0552a35cddd455c1b6fabe5282d5823bd0c29d650b59730a54ba80acabcad30459a0fc2f56e4a3229d5a0582dd5bb22c002f6dc85cfd46eabce5cf5a68a58728054e594e02bbb9847ce72de8d082b97a3c71463694d0af2275d21358c24b54ac3694d1ba41560b6d8cb87a26855c340d8407fdc3b56ca1e87a2b1c7f4fd06709a741906b2b26e4f9ab6a162a36f8487add3c8d274dcf823d162b226b574a5d18c78214c4d68485c1b93e0b9f535a6f37e218b758cb2f37a91cefb5502634adeea5876271b1f45b81b0db78b6e8da399c7a63aa7c3b32d7dc4412b9dbf78496007c39bb868246dd4a8506b5a6b179c804a9e864575b9b9cff0015d3a469bc2b8e42edf3858123aab5418e5232902e9c38d5e1f19c9f040415eda3e7b9fea9cabb694d4d860dd3c8d59ad1a8399dd54ac6b55d25a93a0cf828536b427ea10d6ee53b552bef129b18ce566053ddc618e590007aedd52869765ac2581c3c0a507ebb50868dca589b17e26ebe00ec7b405687891e1c37e6381f23e0b5add28e1e5014f41c95ca843d4cf403f348942366a90b1a1f3948da4393c4e92f722881a77a45209b2bf757c6ac1708b6f459814faf714044e4e568395270175de82126bae0a95e825ad17c054af4168a6b9052d06eaaa495a11b53545520464b31414f5364a5c0fc82bad6e42e9c262b529dd186826ddd55205d6dcfd8268cd193cb8589456aed117245623e1a100e56ca7afab6afb13fa282a2a6e67296a953125a804690cb29116260ab1b84b8547b9eb6c54852b1a5028918229d56407bea085ba4c2a5ba128c38190e547ae4e6d43cb75d055a44dde65581c494e4f328d0ef3a2740b6b976f1d03ec00955bd10f4d4580a37a00f385cbad685a42a872efdc9a562c96daae539f15a1a95835502c033e09a0466b0735c3623bd5a159abdc1ae4c6895b75ec732c6c59e7bb07347a25c32c767d43cacc24ee11f4f5664e9ba8045cf6f2ddf1e2af01ea4d45cac20a2803477a648e2d2efcaaf3d155fbd5334388072a9ec1ca2bb066c14baea0037dba13d171f5d052e8642e9dad2081cc3fba7867abf4fd1c7140d7733412df0cf45790314d615625ab6b33d4e3f28b035bd1da65b1464f86542867fad75372c8e195d7c9c0d935d60019560bfe94d6049eab9be908d4ac3ab7977cf8ae0ebfd09abd7133ed1bf82ae319d714f567fb3f303d8518d63fc3ed667e73727f77faacb03db566d70d14ecfbbf68feca560572f3ad727395d3e4acc359bbe6bc11de16f90daf850435807801e2929f96c50566c146aa4cd581610cb6f40260323b9023aad68679194cd2e36acf2992e0a9396104a2f209306525e41fa58f9565a749b6b063aa4b4216e0012b2508c95cd0552504cbc84750acdb555bb5002762b52a6ad56f20ec13162eb6e1b745aac18fee52a527e9814b4e04d164a958d1b0d1e14ec33f186b6c4f1d87d97a984c4449404761f64616b94cd20f43ec884a9fa6b96076ad89da285f426a6862a6f2deefc2855623a6b9b526b6a365a846947592601e97554a5d65c9d95212806caa912a6a68f3d87d95312d066dceee3ec931d0229ac2e3d87d92e01c347bfb8fb23009a7d2ee1d87d96e049c5a60b863073e4a601d4680901ce0fb2708a934cbc761f64f26870e997f71f6597e6cd3b1e917f71f64b8d3cdd0ef3d87d92d80e3b4049dc7d9258730ed0f2771f651a035469578ec3eca7200adb2bbb8fb2e9e40ea4b23bae0fb2a11222d0e3d87d926046cd62773743ecb3c85b34d69590f61f64de42cffe577e3b51e41a30c918ed4fe402abbdbfb72a8503302e19c1f64ba680d91381fddec99b1294d737631bfb2dc32d7a7daf76dbefe08ee11aa697d345a3272572602b50db48076fc2bc8194ea1b810d2003da3a24e8331fa895b21239bbfa14b1985b752bc1cbb9bd8a6a30fc7ab37e87d94fa6e2cfa46abe73b041f65cf60c4bea8b508dc1c1bbec7a2e9e4236efc447b5a012ec018db2af02a16ed5c7ea1b23b3b1ca286c51f1d99f2cb7c395428641ab7597cc7b9c33deafc840535f5c307255c2f3a73881c9b9ca9fd0ebd51718da02f3fa808afe28f3e304aac8cc07ab75e73c1cb9ced85490aceac37ce47876fd72b2c0f41697e2797b5adc9e8029581a2439745cd9f15d985576aafe18edd1e4350e18f11585ed1e4143ae4dcb739f50038c63a2e7b1501597527b526268b37229987a9b511083a66dfa8414cdd4e4758a9290b8ea32a92b0e162db41265c29da01d75d94ef27467f8d9497900ab7530016ce02b773d5991b2a4e021edfa81c4f556c2a5a96e1976e561178b0dd1819b8094c557ea5630676ef4ba755e6e2930bf9463b94c8b1d96ebcdbf7f6268749452ee8c0918deb3cb7583d5fc3cdbdfd31ecbb45a83aef85ea23d31ec9748af5d3e15a9b1f68fff0095ba9a8b76f86600fdac38ff00f12974962ad71f86a931f6c6ef62a9559157acf879a80768ddec54a9953bcf02ea5a73f25dec54f18ac4fc2da907fdd11ee8c26827e899d8725852629e9d834ecce3fa0f72ac8cd6b9c3ee09492639d871b1e8af198f4069cf86aa72dfbda01f254d2f959a83e18a93b87b05cfe8e97a6f86aa31d83d96e81e3e1e68bc3f08d0625f876a4ee1ec12fa0669fe1fe941ecf6532ea566e035211d89f5ba11bf0e3467b07b055e7a61c1f0df45e1ec1574127e1ea8c777b050b4c73ff6fb483f8fe14ef40ccdc07a53dc90e4ff00edf697b71f846024fc3ad19ec6fb2d901327c32d0f70f60a900777c37d1f70f60b48763f873a3ee6a00e3f0cb45e1dfd8aa0c0e055333a009bf80f8e0e53f705a0453700695dfa804d81da8f862a171db1f85c9694b3f0cf4606c1beca7a68647c33519ec1ec134ad8ec1f0c5459e8df60af299314dc00a467e9c7e14fe9d1126ce19c23a0185cf287dffa4d049b103b974c069df0cf46eebcbec1275003aaf851a03d037d82af9362bf59f083467a01ecb70622ddf08349fc47b24bcb30f51fc30c10eec68efe8a779181ef5c01649d5bf8472652ebfe169aefd9f856e4aafd7fc27e3a47f8474c454df0b0fec88fb28d2a22b3e15261ff0004fb23908fff00dad4dff24fb15d30c4c9f0c338ff00827d92f47047e1b6a47fc177b15c7d43a4283e1e6a7fe4bbd8a7958e56fc3d54ff00c977b1548ca062f86faaff0092ef62b534ed8f81b56cff0082eefe85206916fd1358198313ba63b55f5b555d4bc30ac3b889dec56e901e9fd0b5f1bc16c4ff0062a561a36dd1f4b58701ec70e837cf450b146c36cb092ddc7ff6952d3b3e9338e894c8d9748bfb90dd269ac0f1d852b52b152c98e8512a48ab87ce69d8154802d35cea33b828b42769e4908dd4f40c6da4b82ead3e81b859c80b06aa175b53c9d82783509358df9dc2a60d464d6b7b4a86a528fa173bb51aac1f25d9c1a708c3317e2a712a68d840cf723c852f446b49247b4bb3d428607a9b465f766efd813c845fe0add93e34a6d7a62ebc1b6ef8c070ed4da353907c681f0f64ac4edb7e32b3d83d92e993b4ff00172d3fb5bec12eb313945f14cc7750cf60ba4c95a7e3a44ffe1ec129854face191bfb37f24484a8796c70c9b82cf4c27c42a0ee1c2f6487000f6d94f04a32c7c006839dbb1dd3aa6c56356b36996c63f4376007b265528294776136b458870b83d7f53225a725525065949bacb40d7d3eca7e8191480a673ebb252a5d3ca64469f9e8e58873daba3d2923868973de8a53a1496834da5c278738f8f2af2036232b9fd02dd1a3d834ea528f642e38552740506ecb3d83269094d3b02e9687bd37e806cb6ddb65bfa0269e970a569471a7d942d34365a3a27e6b610ea65d5c99c8e15cfdf4416ca451941f828f0bb79a04ba354b015153f9a2f4716d8125e81e6c63b96fa0e88b1fb4146871d103fb429c3098a95bfc42b429dfa669fda3d9152114d46cfe23d9429470b6b0fec6fb2594c0aaa8e31fb07b2e9e69813db1ff06fb05b4e57d233f837d82e6e8c6e3a467f06fb0490d0a6d3b3f837d95a52d2853b3fe5b7d82dd257cca567f06fb04ba42ffc2d87f6b7d91e940b3d9987f6b4fa04f3a4e8ba6b133f837d826b443e74c346f803d14ee1dd65940e814aa6219681dc95bae4b403b82568416a04f4094da78d90772ace5307258013d13ce5864e8e1dcb6f2d1d0e8f0a7790908f4a86850f69ea26bac60f62cbf41a8f1a587727e7e8351b5ba3c13b0579f41a15dc3a0eff00ce8a5e9911770e1863a2795d1cb3ed5760f940f5ed57d52bcb9c56909c8f1544e83d016cd810a1866f5a66a7900c94611a1dbaf1908d66897dd96695f9024abd87d7cd970a560d154b3bd2e0d4836797b329b06b8ebd4cde8e2b6961f66b5a86fee2a75482e9789756486890fe56c2d6cfc297d7ccf1891d8d8f6f4558957b33445b5cd887cceb81d7ae564245ba1aa68d8278b7253eac2cab429954d50b1a5cd581470a68d6a6c0e7d5adc2d2db5e8f29d205d06518961f96e4dc24c6e18756356c8b4346ecd4e78eb2e80a8e14a75684f203ad972abcc07c46aa1f3e9d70d81f369d2e03e29d1203ada455903a69c279014da609b03e898729684c178c24009ad5d93905aace41223dd6d02042a543e8e9d705871f1c69701f6b557980a11ae980e08b649533c19b295a787226a7e68a7a38575f3d2673e9571ded52db0159e93ae8a7dd46f4c83e2e892f4a417054b427f2d05739414d948890c0b7facc381a16330eb181668c3b0c012d69c3184ba77236846b5f7d38580e32008ca0630808ca0b8e5ca3cd0f9ce0027ca449c758ce44d810f23c14fe412c980460745582afe5cd894b75bf9934e5b8ed480d3ca9f15c7df34745986c74bd7175ca388faa897275cb7086c096436189215d11b82194f84406e5a5caac3a95af747f342f70df6255a1de09e25da4899c08ed3fdd3cad1ba36de00d93da8b40a11851a64dd25510a5632b93dcdd9eaa76215f9a505a0bbbd7ad629a21d612146c1a47d38695b8347b6b400b706a2aaeaf3d029d34114560964e8d77a0ca9d52379e167008bf95cf61ec3b84d0b5eaad19c376d3005addf0ad12abcb657118c2524131c250b72e7c839596aa94a1a4ef53acb5daea008c6680fa74b8348740a920af853a7913a6df4e9ef050ef88a85e4d84f292a6724d11402994e42cc0fa2ce53c813d6f8156409486996d07a48d72d80db589703a4a6901f8a3569015f296e03cc8826c0f9d0acbc874b52790e08576603f1b12e82db129de80c6c2a5682c51a3c83e29d6780f8429f0e229e9d301420d94ea67852ecb9fa3c2e9edcb2528a6d0615bd26efc95cea9c6316e11c7469bc086048b3c290dc8485d7e4a6dccca3c9ca6d2a958dc3cda40a74d823fc394dbe5d7d2e1379679760a3042df2534694028f252db1a9e345c54c1524075d43b279c840d7d596154f2013aeee28f2471f5ee5be412db9b9379071b584a301c15042a33c8d66a97302686f259b973fddea9f0f85b6ad661b0ec5725cdd72863e92b572f5cb70d3ab5471b818d7a68dc2a4bba6c4df495fb26307a9b97344e69ed04278d796b8adc3f05ce7f792551aa559ad6d6059a9ac14f167a2c32469a87256e3282bb43ca51e53b1e05a7b935bd8ba75b86ee1a9187b3fecb3462ab71b8646c56eb7008909381929a518d43869c1a92a8b4807190b2c347b3b85df0d0210d73da3b0ee32a561e372b7e968a36ecd1ddd3082d154b6b1d89b52a79b664b6a70432d4a77a5e10eb4a4f46205bd369440b4e55cbafa5b429da67ccb327941dff00070ab0c69f6455b59819f67f05cfd34eb6cc3b944112da425c06859530391d9c2603a2b726078d3a6d0e0a75cb4ee3a95640e1a354e603aca557c070d029c210ca7215603c625a1f1a7480b8a956dec1e753a95ec162349e8096c590b00c8a997427af9d1a631e8a049a674c096f47131d2e548894a5b66375961c53d812612877b02c4698918a921f5d8a25485373054c3c3216ab0a744b7d15f32353d31c8e249add3b4f4bba536a51ef49393ea3ea0655a725d721722b0ffcbca85a5c21d4e9631c6b53ca06c2e549422ae76fe629fd009fe069b416fb22df408658967a0f9f66297d07ccb4154d6e9c92ca5368d3915a485ba6d75f6d29f59a48b490a36a3a6dd6e254698d4d6d728e18c8b5b8ac048b4b9611d7db5c9b0a685bc91baa0513887a48c8dd876656c2ebcb1aaab0c13729db7c2dc2ca98d3f7e0eed4d8b45b29abdab422af15209d8ad4ebc1557a75ddcb354c464da78f725d180e3d24f7b806b534a31b0f087e1fa49651cec38dba8db0ab063df5c28e0cc34b18c019c03eaba6c6468f338e7940d973f50f1c65bf2370b9e969d65ac6126a74fb28822d213252850b548666a64b2b5c8a05594a3a1882ecac2be402a169b4914a13735ae3a9d74c310e80adb4d861f487b94694dba12a60d962dc02238025049a45a0fb2996e8264856e8262a65cf69dd929564a0910ab734088a995b40a6c2a70865d4aab0142953038da4481cfa6c2e4bd02840a5683f0d0656ca0e8a5c2aca0f30abea45b215ba6d3b1314ad3ba5ab9ef474d69da4e63855940ab9b795dca9802c212ae7cb4b89520312fa69f6448f4536fa6ca6fd1681df4f84bfa2b1f3189bd03c29d1a47d1c5ba359a91a7a5dd3334fc940ad229a8e9e9f055643691151a8f663ff00270b87abfd696d893a6f8c68d0fa366eb341df97badf40b6449f413ca97d07c2159e81d6c012fa04be057f49eb869937a1a4fc85be99a5b614de869d6d3e52687cea15add0efa14a6d25b6e097069c36f097184c96d0b4a64db36430d43646bb208ec213c2bc55f153a01cc73a460c632760ba70b1e46d35c4992395cd71e848598ac6936be29646e7f29714a966712232373f9589b277d337b427c3246cfa10cc761e0b70377e17fc3102439e0763b729e42bd15a7b483299a1a18ddbb76cad0b132b81ed0a9690e738ef0a1d01d056371d428f5413f3867aa803bf58076842a50901fdc100d4c07f20b303e8601fc82dc07be9c7f20baeff00881c6347f20b9ec33bb7f20b39521afa919fd41757278f9d7268ed0a97a2b90dc5a7b428de814e734fee0b3d030ea66ff21eeb7d010ca01fc824bd171f3e268fdc125e8603ff00116f7849a30e191a7f704ba30653d183da3dd530c323a069ed1ee8c29975a1b9ea3dd360a5189a3b47ba194d7dbfc82c84c0d35586fee0ba3936130d634f68f74d5b898829411d47ba8d3614fa16ff0021eeb93f33ebefa36f78f74df98d3d1c8d1fb826fcc681a9b80cf50b7f31a7296607b42af940fd44cd1fb8295e4d84c554dfe43dd2793c2dd726ff0026fba5f273906b06c3b87057f2db5c1abc4aee62425f2c4bc61a7f704d39209fa66ff21eeab3961b3081fb8295e5a260a76ff2097c8151d3b7f904be4132db5bfc825bc8082de3f9052c024500fe413c06c538cfea0aa1234910cf50b6048be91a07ea0ada744d4d2373d42dd0699001da14a875f00ef0a36071b18ef4616be9a01de8c73d2628467a8460871d4be28c7442d94bff00c96e99cf923bc250eb231deb701cf923bd180cc87c53da2c2e193c54ad46c381a3bd12b31f08c77aaca63b0e3bd66374eb88434c3a2ca0e6cb708069cfee4e4219225d030918eab740094f294a140e2be8a6d4d339b8c920f664ae99518fcb3f884e18ba8a473b180493dd954d5631783553877ad50a66a87e0f54a9d6cb7a906d8ed202b635e8be11e910298484767325c0b90d6a1870c2476754153916aa2e6e4927d565a0fc17fc0eaa77a0664d54ecf5497a0186a97f7a8da0e0d56fef53053352487f72a6182556ad91bda8c061daca4fe47dd3607ccd6f20fdc7dd181d1afdff00c8ae8a91126bf7ff0022a3618c375fc9fc8a243be1ae64fe4ab03835bbfbd65070eb57ff0022a56071daedff00c8a301a3afe4fe4536038de21c9fc8fba9e1b0dcbaf253fb8fbacf2301d46b393f915be461516bb97f91f74de461c3c46947fc429f1a6dbc479bfe61f746106b78a12e3fde1f74b85a165e234a7fe2146329affd44947ee3ee961b0cd6ebf90fee2ba3936227fcf53e7fde1fca6adc58a8f893386ffbc2a34d85c5c499c9ff007853c896a5e9f5b4e47eb29b19a92a5d53376b8a6c834747aaddda56e0d264d76e6f6a6bc971037ce263fbd46f2650ae7c4a9cfe990a4f26866878953b7f5484fba69c1d3745c42924d8b8a6c0b5516a67b5bb12970a4cdc5395bfb8fba690ba61fc6697f99f7559cb05dbf8ab2b8eee3ee97c9938ce2cbc7ee3ee97c8485bb8b0e27f57e51e026a6e27380fd5f94b78088a8e2e11fbbf2b9fc03078ce7f97e51e40d878b048fd5f94f3909aa2e2d803777e53790ec9c691fcbf2b9f4e01fc6419fd5f9548093c621fcbf2b287071ac7f24b80fc7c646ff2fca3194a9b8d8dfe5f946236394dc6a667f57e5182414fe38c79fd5f9462d0e3f8ccc3fbbf2a9e1afa1e31b07eefca6fcc0c3c6a887eefca7fcc171f1b62fe43dd37e61c938d111ed1eeb9af27b0ec3c668bbc7ba5f0958723e30479ebf947860c7f16a3c755be4d8ec5c578cf6fe5358e7d3e38bb10ed494e769b8cd0f784ab1c978bb0f78487c222e2943de1575224f1621ef1ee95865fc5288f68f74a0dc9c518bbd2e829dc58831be3b95e54de43f8bdb7c758cfe98f1db7549558f065e74f7cb7e3d13e8a98d3da7c3c744a46a9c3bb31a9979707a8f156f41eb9a6229adc583af29f3e88d63cf943ab5c65393fb8ff0075b69da6d8ef5f6754a1331dcb2173da5c2a29d28c744c81843a75983083752d5a6093dc0bd003495ca980a6cd94c0c492a6186df509706193323014d993075d2aa506cd6e12e032faf28901afad2ab207595ca5e4da259588c1a4bab10343baad034d7d42cd69dfa94b6b2c37949a5111392e94c4d3ac862637ae8e4e7004d4272d56a2e51a65c2d5a346374b3a47132cb0b405be99862a998e8b7d0c350d2129bd0c3cfd3c0abfa322ee1a1f2a77a08ea7e1f0cf459a70d75e1f0ec0a9283364d25c8ecacd28f639e64e403ede9e8974bab5ff00e9ab641e995b2b15ebc70b08fd20aaca5d42c564319c60f724d5134dd3dcc3272b7d00b536a733f482b7401aaaa940e87f2b42a1557771796951c0228e42460a3c84ac772e51d5680b35fce7b56032dba1ef2b9fc9c93763de9f01b17427bd6d81dfaa2903e7dc48ef59a4262a927bd1acc1120c0ea8d18104a7bcfba35a5c7772177ff01e17427b4acd071d55e27dd37a809151e27dd1ea34a6d71ef2b9ff008ada2a9ab8f795b895a3d97023b5630fb2e64f694b4da5b2ea476fe5475c8e497727b4acd563e8aa48ed2931694f36e67bcacc3e9d17527b4ad2931d79effca5c05b2e873d4fbac07a5ae38ea97022aa2e071d7f2992c53b52dff941dfbc6fbf557e548c6eefa36399f9f32a98ca9cd33a0d8d1846255ae705f86c6098978f1df60a33a6ad9c4fb8111b80e9823c15256bcb6fb862438ef2ab0cbfe9bbc7dbd55702f36cafcae2c0988aa96e03ada95a0bf9995b80154c994980c3027900595387c1e98189e458dc3594d831ce74630eb1c9414f729fb01640b3d87d84d3a066462ace813f2917a2eb86549e869f6bd25e869a99c93db74d2a4ab1b0969454254f41c91c974864aa4294d2af0c9fb358c9fee9a9b57fb0dac354ab56cf900053c66236e75191b2dc1806dd45cc774f8316282da309b06088edf853bd34ec56eca4bd076a2d800ce113a06594208dc2a4e82b9aba00c60c754da9e80d31235d2018dce12eb1a940d11fea1dc9a562cb6c64720e81574aaf6a8e17fcc7733001daa1e95474da2cb1b8216e80dfe561da137a066af4cb483f68e8537a0c5759e8c2c79763bcaa056619363ec8002694a5069cf403ad916f939974c8c0f9b549683adaa50a1f3a75229915851a6c7cead27b51a3098aa10538c9d747b61d15492fd0166653bf4a0a6ca92fd683cc7ad9f43da5b2a15a7d11b44c72e7b56de99a2d92614af6673e7a4d4cb6bf29cd04095524369874a53e374e36a54aa86cd4a505415184602a5b8e52807349b230b8ce35fbc81d55f932a96e94f37556c4eac90576dd518957b235b52451b4fcb23d3aaf3245eb0bd7b585d0907b8aeae11af32d7c987fa95d7cb16cb057ec15f4f17eb55c54a9d62a3b8a9581250cab64073e72ac065cf5339224580dbc250e3a34a08746aa99a74483c305a90538d7213ae48b970421ad4f1485722dd69c6468d212604829992993442be11aac2999634f143423453b8d894ec308012e1b484cd3b470971c25262ed61d220ee7cd68c5b69eca1a969712544c091a7aaead56b403a5ca4a0ba79f951026a0b86064aa81105c9ae2a1e4e998a3c6e52e00f70aad952057eaef81a775408bb9cbf346028d219d2f6ce59803de14e86b57ba60e6023b82781036cb8b98f55d0ba52ea424632a18819a97972ac8788b958535878684092c3c097bd30c9187385b1ac235b68b3193ca36548142aaa42364d280a5bd8a9a087b926830f296d0f82ca0a892e039204d603385cdd40f837092404b8ae8e414c62ada4110b54ad02a262c075b0a303e254b9f9971d6b57673f318783f0ab7818704ea17e631c6c89713c1714883487049948a3af0969b0de54c6bec2d1a19f36f84c346ba8b0329b068299caf0aa06b88d3c0a7d34e02281e2b024b43d4177ba970eaa5e4d59eeb194fca3eaa922763ce77d77dfea552331336776ca9ad5c6d1704d5bab4d0d525c1a9782b9641a74566530d12c9521b4a281af82c1ae4ae4a34db1048e48d42902929c57c1ab13a4bdea1608e31ca7548e82b3453f1846a569d7157bcb434b322421874a9c105e807212839442dc30594a5c0ed3b33fd929b574d336419c9f3598d68940c002d06ae3518595980e9ab54c61bb8dc158a121af53b024a2976ca02bf7dd57cbb0f2db74f025748d6927989f155bc9d6fbbeac01b80a560576ab55eca4155b85d4c920013685badb4fc8012a6449d0bfefe6f54605eedf5dcedfc2000b9c3f76c981aa0a8c15b2278b552d40c2b48c3b36085b62a8d1364a4b03894e87bddb9af1d07720317d75a3f93eef54ba1994f09073f8ed5ba0c39cb741b256c05062680c3dd84d80b64d954b01642e6ea074296025cd4c0eb4a5f443b1392e8151c89e0779d5e406dcedd3f30d828745d3306187bd6da30e4414e8c3a1aa3625871af53a690b8e6523e0c12e52d690e72cc4f4d909b19a61d0ef95983524eb8646130d0136e9a53336e23cbca15250cee9eb7ee45a0aafbbf2953b43d6134ea9029fad24fe91f2299af38d69ccb8f1213b2c6814f66e5a7e6c766509d3564972ae356aa1a8460d4cc5224a611148a606c32a0da2e191035d79407cc195b80d49190970b0f1a7384aa436d62dd14dc811a9d35f296531418a1439f25648ca580a93946bae72e8f2632f0b30e6a56246e1a7350c703b0b219d8dead215c7c69684ee9fb6e4ae7a5d5e291c1bb26535274755f694e342193bd2d1a8fb9dd9ad0a43502dbc9cf5cae903229d4fa801dd3531039729023acd40e91ddfdbdeb605967acf943ae3f0ba2d3aad5baacb8e32a36815435c5ca5a164b1d06f93e6b02d3709fed03c90448514c047e9959812fa2ee1cd9f55a161ab6e72a7a145bd5f79250df1c2b4662f7435f98c1f22ab1a91171042d08c9eac02974007ddc299dc35e168445f695b2b12e061dad34e16bf38dbf0b7c854236656e03869d6c05009a00b530e5368269e90e56fa02668125065c0e14f00704e5180736252c2119c2dc0798e54804318af0151b5269b4a72df435f08d6fb1a223a759e869d2dc26d4f4d97a5d1ae46e52c6e8a6b96791a573a7c263e784b830312b30614d62c18e98d348a334e2abc06f4549030b96f5cafce516045de752e5dd54ec0f7ccd1aa46a8faf07f48f914c779e049fd4cf5c1253b2aca35ab8b3e581e09e4469db5566154ab25beb13604ec354a7d0170d428048c53ad30a8ead0d2cd4a7c05c73a607649f2b6c10e9abd94ac5207f98a3457d949a4a5315ab5c90a8d0eb4a7e79252252bab9e51a6f9d3e1a3b853abc2247a953603a8a8494943b25ca3969f8574c29ea56e5e025ea3357cb7d2f2b73e0b97a287a0ac2e9709dbab348de54d20d0958e2968d51ae7392fc152b06ad7a3f4b46f1971f1dd75281350401aec33a29d0aec7642f77329059689c2119f05b033ed61ad039fca0f822d3a36d8fc9cf7a9da174d3eec1dd2e85da1ab184c1da8ae59083e3afcb30a92049e93afe525250b78b864285a19cead873287776eaf0d89eb0ea2c80dee5694ab18b8add002b2e984a11551715339fa7acc84d01b6dc304aa4811da92844b193b742a9818b5cadbc87d4a4c068f44b600f95941a794ba04c13a4d062a27ca6803b9ca980ba76a300f2d461014ad4b80e441348074415202cb54f0ba4909706b9859834e472adc1a79b26509e9123568d390c69c695215a3496958a9c7392370d72a518758b3061c715490281c43b1be46ec33f954818d5c786729fd87d9650addc385d2e7f41f64943dd4e2a961545e20cdfd23e454ac33ce0e3f79f32a9c46513095d522352b455dba0458e82b729948b0d2d522b2c1f1cca353b1250cc9301f86a161b04b655b1af9d22e894d8546f29ed077e6153a6d75b228747d3cd5cd60d3888532f72e880812abec261c72cf430c656ac524a03ced52018529296d03692d252c4a88a9b7e15e2545d9e83ee053d62db592631e5851a70369a6c3f3ea93598b4ca13ca310f79aac0c2ca315a650f39ca4a3128d2e60c0f2db6492ac71b6f2e1927c5560764c342d0a6eb6d5003301606494f6d7c93079ce339f04de02f8ea6200f4f04bf98582d757b611f985a68eb3ed5bf9831517254bcb31254f78fb54af031f526a60dc79ae7bc0c5c2d5a843f00152bf3180750d40cae8c6abf66aee59328c0b7535eb2728c05575473f44c15da8baf29fc25f06c194579cacf2c0f77bb72eeab3921eb25cf9c615e72cd40ebcb2606de69fd354195a40c25d0182531331480d02a9439ca9016f896072072a01cd2a74b091025521d10a7829f8c2bc4e9c7b5481b8c20152c584032d430546e52d4f1d794b58f84ab0daf8cc9719e8ae75424a4b1255a1fe4c04cb42613ba782becefbaae9576d2d6663bf50cf98ca4d0b1bb4743ff002c7b24b404768b87fe58f653a14ea890aecb092a81afe43f2cf9151b1af3d359f79f329b98ca218c5d72235294f4bb29a912d6c9b09948b351c8969ac49c52292760f8a556bc930e453a9de5a9113848dc36fab0b34c432b02b6a7a7beac2d316da952a34436b146c1ae3ebf090c48aaca70739d1e8f8ec954b3d0c35f50ba8c57d429835f523b54a8130d6354ad03455aa4250efa92e5446ad761a2fb415ba548d6919094e26969f032b9e55300dc2ed82ab06222798bd0305db1984946242a2318ca48d41dd2fb8180ad02b35fa8c969dd66851eba732bb0b342c165b3e02ecd02ab22c6c9b4114d2905685869aa8e16e07d5536ca7a6c371576c968c037490819f5498301e8ed68ff009fcb9db3859831a16a0ae2efb87729e155887506f8f44604f32f7867559806d97537795810d7db8e4e479aaab812dd7d20a5254a5cea0b980a7d490b6fd4263940f254d26b4a0f13333e0b9fd28caeff00016c842dd08991398dbca60553c7928022a61c053a03b58880e450270258d532c758f4aa428aa415d695689d3addd2870330b01265ca01e89a805b98b975b619730ad84a53589a2763e7313612b8d72da587a148bc1458962d0871c2714045310e49e8357d08fce3659a17efa72b741a148b43170365ddd24a56bd8bfa67c8a8d33cfaf1f79f329a5652a372bc4aa6a91f90a26944434f829d5953948f5954d1cd91459a96a3e9baed9113823c2cb0d8555d4e1aa1d46a0a6bcae7a62e82ea4aa4a98d86e7ba785c14fb9ecb7181a3be105258c372dec952aa68ab7dcd4e9844f7dc25305ff1e2b64363bfe345756b5c6df8ac016aaee4a4c02ecb525c51e42c3533f2f54d8cafb4dd673bf0951ad92d56f022f44310b5149fdd06c483e5c337ee5cf21d52b8bc2b481c8eac3774d603b4571e6724bc81d76ae01ab30334bd5c7729b020a479722c02ac16cfbb2a5605ea9e0c059e800af8b253cec130516cabcf40731bb2a7a08eb8d4e1486a1e3b8fdcb0688b85dc007c9668d51a8ae41b31778e51a35a6d2eb06ba3233d9854c0cfee17de590e0f6a02cf6cd4198baa401a1d4584a126ebd023aac36abf597ee53ea998bb69cbe07b424b5341ea0fff00d00a4d66344d1b7cc37d30890c89d691e1a5fe6556051686a0bc2a98438260229e5c25a0e5555f36c92d04b022505b0e1383b21d94696110a59548779d52515f73aac4ebe6bf0b4c240ca010e8d0080e40111e572e36d3e02d8436d4d13af9c536a7638e09e9642e22a55d121e74a91590c632985865f1637498c68fc28972e4606b6d62d0e36158181bcaf47a414be203bfa27c8ff651e8cf3a42d3ce7cca58ca2db12bc4aa4296ab0944a3e2a9ca75a54b503d253ea5e17852a3525048bba52e08ca6304b9bf2a5dc32a5514cee65c95b83a8a02124a5151b4e55e1520e765519600a9a43d8821a116172d3151b8a953695264ad8a61ea6a2255e432569ed790b200535060a780b96942ae048e9f800727f2066a2a8c9c050a2c1dc38a2feaeea552ad958fe5184929701caf0139919a82e2033653c0a2cd7655902bf5f7d39eaa9813166b8e067d56e031aa75603b03e0a78653d8f2e29a40b1daec0e704b6058a874f39bba8d0907b30b970186d2eea920393d2602e8e6043d4d661570202babd53c27a8196b3ee53bc8d456a1ba1236f24b791aa757cef033949e469cb6ea278db2ba71419254976e9025a8eb9c1b853c0624b9382502682fc553ca7a4dc2e595be5a9cd0fa8087614fae54582f75993cddaa3e5b898d137024e15a729acfafa9c9a7f44d819ae9b81cd1bf8a0c9b7c794c1d6c49280f2330a740a81c880f06a769f9a0d973f54b02b025d3c11c8a9057dc8ad13a4b82a18544e4025c101f34201f6394b0a5fcc4b584652d690f2b35984bc2e9248eb0a955a438f9549691f42dcad163b5415b12691c2187ee49631b03225305b2349ad79c89caf4ea2a6eb98bfa67c8a9d25602e8f0f3e653480e465561087821292417464a17913d4d26122b83a9a4598312d4b50ba25031b549b43863ca9da673fc38152b414db50591210db6054d0721b484d29c41b6b53ce9a0e6b502a1d704c1141600b93ae1839fa6c2270694fc7670174f3c2d289a7a30155941d5d08252a615f6b092d0229a8f092d521e6da398a88ab669ab6f21cac4aad46ab65485405caf385590ea9de2f39185819ddf350969c25002df5ae795942d8fab2d8f1e09421ad96d7487707aad865ead5a4c01d15205f2c1660188a0e5c19b6029d08a6d012573d4e54b5358c61522f00dfe98862b42f4a0cd094f2b9ea26e9467b95a9620e4a53dcb0f01d5d973d8975457ef969206c12b710b6bb2389e855ed6ad149613dca34248db4f725d088afb7a60099484159e406ae9b0b3c84a69566f909a720bbdeabe57f213e0ab390b970d2efde7c535a1ae5c5e1f1f5ec496852e5b661428361aa760391c6a7a0874195ba57591a652524bb07d532b2a6aa06cb9bb89e816ae6f14b4a2d5dbc718ca4e15f70b8416a3d10fb425d3c25c5208512b3cd31c11ab58e6c28c4a561e47cd6a59159cbe2c5b8a612635ae691f342d5a1418b2c3bece14ac29b965d95f88c69fc1f04957c0da63a55c1dc3429b0e14643ebce1f2f62bd572a8faf87f4cf91412bcf6e77de7cca7c07617a6294f9b252b641d13800b17907c452298918b65a30509536944d34c9b425227a9da5171952b416245ba43825468382447a69423251e8c321b212bab4d47d35bcb54f12af9ee4484d71ef568694974fba82c580126a748963496886db2053b541f4536eb5b56aa68bed050953970acc30a68c6795975cb8aac3a0ef356434b94c2813cff0031deab285cf4c59c2285924a0cec942c9a5b4defd16c32fb49a7bc1520494366e5d914112e9c254e8261d3782b9909463ade0278bcaaedea8b230a92b6a9f5165c154952b00d5dab3d8a9e93c443acdbf44baa42ff00c2723a2cd3e049f4e03d425d3394da65a3f6aa7a609ff0c1dca7e8079edc31d16843d659b3d89a508a92c0ba02a97db09ca5d09cd1b429b4327e2531c2bb941db395ba17dd0f56703750f41b2d92f1f68c9f059a1273ee3f2b70220c5bacc05baa7017361a862f2b711a5d3bb7413d1de4dd31bd8d78d96d87d0c13f3c1a1d0d5d1e31b0a5c7f4b8dc364284e903cd6aaca784162b4823a58ad393151acb1cba770a561e7443025c5a7470b1361f4a6c695275c309b0e65efcacb1a6be5a9585b5c7c7b2e8e21656b9c16c655ec3b69644b83e903ec28c835e7466d95d7a933ae233bec3e455b96579f8b3eef529a42d3b24498ae363525a0d84215895a68536187451e118cd3d94a30a85c9ca9485d90a5d428f88e02891f48fdd3812d3b2014118cd11148b3cb352505c0f7a6f47b5da9ae715ba95a67ea53cac74d4029f5b86df325c5cb8ea92e12d18e9429b40cf3a5c3c196a9b2e08c62fad7618b0baa7ea8ba10d3829e08cd0dc4f375568ac235456661598441693a5e63ea97c86c76bb480c1b25c09ca1b40252e05cacf4202c8659a02a900ae45b41e6153a0d39ca3e52c0b51326c3556abe709f06a26a005a5d454b105b402a8a60b29b03c512552132c584860ef956da4053ce960012542a406a4a955901b73c15b6805576b0e52b41769a0e424f82c94316e24527fb417f8a7940dd095dbf546069f66aa29b02f16fa8cb5570029e4dd36030fdd72f9357c423ca34eb5b859896174c77598dc493d9b2a74b606f949f8ee1a3a574deb5b0a6ae2fa73add7005cbe502f9d5f9878f9ce5d11b092f5695b4969496bcda25a14a9e12d4bab438d72d3c3919487903ccf4daac32e6acb594b894ad4abeaa6ecba38ac95ab70363cb95af4a46e0fd82e1fa742d258dc850950bd3ccb3bd74c3b3dd7432c3e457572cac267d9dea5570b4fc5ba5a538f66149487a01942b1274ef54c35a2e295661344b29728546d35b5314f39b80a7d421f864c852c21d580fc3227900b685490a5109fc971d1d5734e59a9085a08fc2a4e4a76e943caccfaaace4d14e9eec422f2ac8769eee4a30d5d9ae584a9d0dfe66214f1b1f1bef325c3a46c5763f31a3c528d6b9737e2007bc25c2b38d40ecb4fbaa4346792bb2eebdaab1587ef4ccc584e9a6f87163cefeab286c1052e1a16604a51c7b84b605868a350864ac3b2780509d6d04baa54e80f2d5ac86c4655ce992e95ab8542dc4350d57589b0ba1db5492ba21e272b298c3998598781eacacc32365954a91175350b6045cf32b408ff00acdd747300ea5195b7909180295e41df939052790c5f8a51609f554f2103c2b879de4f8aa606c0e000c26c0b1582b3ed5a09aeafc2608b76a1c2879353a2ee8f2953d4d79c9fc25c2c89da59825c3e0cfa9d9276ae1b695cbe8b5f15dbc75aca5355ac2e9123943c91c62243c2f93299b1f7c946b498d3dae3bc8a8c28daa4e0bf96b159c3bc89b54f2f82930d18d31c9735654ebe6851a952246a7e296368e0751e1cad6af1b5cf1ecb8bba5ea07861d9425ae5e9e619c755ed48e850b597e83e457540c26b19f77a94b4101a5737503e4dcc0718574c81274c56d03e9e5c295a1210cc9fd4092a7aa4ba0a964052e87d12c070bd4f014c7a6341ac916eb4fb5eb74c76288adb487482173da05c939231e89f92abd5f6819cfaaece6047b762a541e923ca4089afa4dd283d474985805dba4feb0f30a361db2df64c5333c926066f7d9bfa44aa730d19952d4e5c7cd74c36ae2ca4e68c234abb686a1c00b02fd144a74a3692351b189da0282248350d34f28542c950834075154960a0669f2af13a80a89b74c9a3eab72b4a1fe528d07630a54c4554e0268d4555dc82bc3a1e5b8049844656578461d05595fbf55944071ce494b2993b6c90a7813d134aac85495047fea99958ff00186ceec3dde694aa2f05e43cee1e2534aad5fef75e5b955953a9ad1b732e09bd12276fac21a96f5148a8b695ce2a56ac26689cd092d072ce4f3a9d0d0e8307194940bf9490b6be8d884ad71e86c71a10bc21e9d33d08402654c0db1c8029b1a9540a53a629a88a43ad6aa1e1e1185529a930801f9f29415f2160196da71cc32b3126f9c2c0c0161e34495c97042636acc33cb12b7395db2a4cff005b0c30faaaca186d449f77a94f41d8e50a5607ce6a6903e6c2ab00d8caca06520cae6ea81cd6a9fa02622b740a8de9b424608414c0e1a6402994a969a096d3a4d69d0c59e8c22172a145652e07cc0ab211f54420aace803ff010a61cff000901287ced3c0a03e6588203ea6d3603f3e45658dd5ab52dd0081adee184483593dfaf7f696f9a6c6eb3e65761feab4dad4ec7543e58f4509d35a069898615205c699f9415314145959631374d458514c5322418dd453ec855135010680671b258506d77faae8e42bb5d2e0fba64ec00faa43096d528d66166a54ab51d73a909b90aed64eaf0e86a9ac54c222ea2ad258743d5d58ca85109a5ad19eaa5a6582dd700ba605b6db20215a15376c033ee86543f1274ff00351c8ec7614a579f385d4fcb2bbcdc9755abadd22e7711d53ea7563d15652d4b7a245d2f34396295e948afc36ec146ac2aaed1cc16680b6cb47deb42d2ca4e5401ac4a95a4e508da6df16521a5299121784a76394eddd00a95a983e8e24010c814ea05162433e604290431a9e1e1520542982d4020c584a0ec4e402fea08424da782f3f39dd2e1e35d9625823b1312e19e60a78b24aafa499f7121b861f22ad2879da593ef3e6556502213b2607a29564a0e90ab01f647b2ca055239737502419229f907e15be4088e6dd3604853d42603209900689425b1b1df98930cfb996618ec29a42882156407e2722c23a429dec16020100a6032298762d04123280262a72e3800add09c878572548c6eb4a7ab7e14a5e5cf54d68d67973f8549b9bb7aa4b46a5cf05248a2037d972c5205a1a0742efbb3b6cab2b62f1a7eb39b194da66a361b602d4684954d2e0a8a01a32014188ab7828555fb86c83442575c804b0aabdcb5200ba390ad576a1194c11c6f832b198261ba82a5461c15ea3588ab9dc53f2158adbaabc2222aae2ab6844d6deb090e82a8bbe546b6110d71ef52b1a9ab6d791daba605f2c173548cabc5924ce1656558b5651668dde442991e69b1518865909ed250ad49d0550e7e6f1cf7a74eb5bd270fcc6e4377f64b612262e16a711b851bc9e006dbf0dc94de570e64cf62cc04da80e6dd684a573f7d8a0100a64ac2404a8d8586a5a6904c545948bc7c693953b0d3da804313010c6a015f35220fb994e9e3e675443c284b8543c75d22729b2d407709412c407cf76eb7126d9c0883aa5346cd2c6b5b0964690cf2c87f2e5475266dc479f2d3eaadcd0f3dc8efbcf995d3cd07e193655021ae53941e6b974c090826185b408830a56019034653f98131186e12e00ec684b8064385805b1e1203aca80b4d04b670b71a744e13619f32a52c84171ceab2011155050ea95d3385c5d5fe838c957440534a707e2889386a60d3f4170ccc982e07b3b364686c141c1d85a39b1f84b294e4948da7dc63fb2acaca9bb7ea62f6f7a0a87bd17019c78a8da19e4b73e790b0f9612e2f103a974535c0bb1e29b1b1429f309419a6e87d520b4648ee4817c0f6b82c402d4510c20c8d963010aab379a901068cc7545d88e9e2961597df7503c7fe7557e42aaed4326538111dedc83626adb772546b13f0d6654697005c2a13c62ab71955e115eabb8a6084a8abca0efa9b947ea48d89582ba01d484b8d3a6ed0f61540b1e9dba34f45bacad2f4fd77459acabcdc6a79a95c3c14e9180d6e89a991eef96c277ec19d93c56ae7c3ae1c9f9ad6cedc7fa2ac4ebd3560d114cd6fda426c244d47a72908c39c32970f03dc34453386d85962ea1eaae196dfd21ec92c0c86e5a4eaa37eec7633ddd89281b461ff00b9a90256290155c2d8f8b42c46c7cd52b0d05455584b8bc866a6ab29886e3dd0c7c1898160a010d59503ad6245238d1ba0d1d7313c3c3b1302d29e73020062f4a0e53b32806268f053a4ddbe1f5b9ca5c346cf353ffaa56c36ca74a67942abb56c89c667ade9720faa79148c4ee368c395e0a1cdbf09e274d98709843d4ed28521750fc0d904a1a96f041427532db96c958762b9ac04497740130df080b300a8ef2a9aa418cb96525aac38dbbeeb2368975cd5254e96db8ecb6d739cff001bdbf0a3682e2ba28556096dd92c8e882e3b8e15f1cf843aefd9ea92c6634ce0f69f33b813d854aa91eb0b040d8a30ddb231e6a3aac8b153d502d593b27f152d4b61f98ad3b67f11568b7fcb706e53fb1fc5aabedb96ef8e88f63f8c76e1a5f9672ecf6e54b58b4416b0f8cee15f9a5d653adf478e657854a68de18911f383e2ad18bad05016ff0065ca304d4b103151bcd6f2e703080cd351ea4001c9ef595acbb516ac6e0e48f75c527f5667371d4609ec5d5c408975dc67a85d5c82e9eb813d53d0b3d91b9510b8d2d0ecb003ba5010b70295792423029d73996790abdc6fdca8c0acd5eae2568444b7971ed2802edb79703be5675c9dabe89bde7b573de4359a0bf8680338089ca78d3b44cc67219d46c3c1744e58def4be908e98733da09233d3295b8a4eaa9d9cef73000739ee282e0ab2561fa77bbb8274944a4d74ef9dcbbf5210c6896ab892d049f151c5756ab46b163480ec776fba31bab5cd6e8aa19801bbf9650cd50f50f0501048f3d96b191ea5d2ef80e4027b3a26efeb155769a57b9dbb5dec5427d42e566d3e5ffb71e6bae7d204d1e1c93fb82debb80e47c30dbaa8da58f8f0e881d546a911955a4c83beeb60aa2eab7ba23fa1c7b3a154953a62df70246e31dbbeca3a22521ac0463213caa4352d604f20a763add93612922b7b92e0d102525318d00a75ba2620a36b4beaba39ed2c6f5c088b05375d9e36f73775e777f469b31eea33e84b5e4194755ea4848cff00598c34faa79148c92a80715482a32780e5513a164a228108863210a42decca09519554a109d3cc93648c1109c84029b0ee8039900c26c068053b561d4ec53b4cf9e775b28496765489d150b7ed596a61e48d4ed02638b64aa439031348b44adc1b88c1ff00ed74623887b2d03a59c346772029d831ebce10699fa766fdc0f728751b2adf5dac035d82a362b2ac360be070ce7c57348969cbb6a000615672cd67f36b4025049ed4d835788352891b907b11835946bbd57f2c939ef55c6ea47877ac9b246727c15242a035dd5b81c93b75548163e1b6bf8fe5f238f878aa4acc5faaeb63c6463bd29b10b3d5b4a062abaac8f96e3dc0a063c53c63d70e6170071b95831e7fb9eaf99fbf395cfe5442cd7f97f9957e600e351483f714d2858b4eea3713b9ee08b4374d14c71c7a14c1ad5a684e101dbd5af64d81976a6a5c146066f7fe8535819b5d685ee3da92c08a92d27c5203d4fa79e7bd604ec1c3c988db2a969d6dd37a12768ed52a135a9db2c6d072474440db3817c58821637e6e39863aaaca5c7a1af1f12946e8b67349e5c0f0d945b8f3645c601357b9bcff00d3cec3b1057a5b4bd535f4afc77274f195dc2d3cb2e47794171a6e9a8b30fa27f29eaa1ac2f26376dde92c3cab1e95d62fe5fb5c7a053a79179b2eb573b67bfb4053a791a650d15248d064603b0eedd79ddf55a9da5e1dd139b9644dfc29cea855359f0b893881b8f25dbcda148a4e185535ff007138eaa96826f56095bd09469620e3b54ef3804fe562913d6dd3e59f749b81de8156fa2d3b4952dc16349e9d0755ba9d66dc47f87799c0fc86e06e761d9d8b9fd08f396a1d05554cf22427aabf35481e1bbf7f92eae60a31f73db65d189d2ed53927753b02e14d0ec971bae7ca5cfd34f3225cd69b5d859ba7e4637fe0935374d6c3147baf3fb4ed38e1ba948e7b5e3fa93d57d12b19feb41961f22b7148c8238f73e6530ae1660a64ebe920ca04015f4642148118d41688752e508d75b6d09009a7b605b01d96dc32a920194f4216d80f1b285cd5682596a1853a675966194425171d942a254f8b563659873acb537b54eb2c7d35083b342cd343d6dd35338fdac27d329a55a350d2dc217cdfef18e1e985d1e895a4699e02471383bc4149a9ae9a82611b481fc7090d1e72e27eb87c40919ed2930e7f843c6a91ecc3bc934f9a3abcea5d6f867367c5527cc6b00d4dc597366d8f6adfcc6b4de1f7188966e7b0a4fcc6b20e307185c5cec1ed28f2352dc0fe26bbe5924a6f2d5af88bc4ce68f628c0c027e3c490d40c1edf44c6c6b361f8a02f0039dddda94d8b8b38f4c2dfd633e6818a26b5f88b3ca5ad703d47540c799f57ea035321cf6940c49d9341f345b04b1a8fa9e1cbc67ed3eca9004a7e1d9e6fb87fa2ca174d2fc2d8f9bd4152b037bd37a29ad60c7804da17cb6590ec9b41abd509e53b260c7f595126d0cd2e16dcacd011ba55a7aacd095a5d0509eae0b40a8b4942de8e09684bdba21d1a33d8a16b3575b4d08e5dc2536aabafacad73303cd03593ddad0e8db919f44da650e7d5ef0e2327bbaa766a43405d4fd4736fd7282bdc7c28d58e3163c309d3d4fdf24046505d4fe9abb06b00f44fe939caafc48a40ec1f10526a921dd3ad01a3c829d3c82ea6fbc8e53a7596ddc45c0032a3d7c82eda6b8c2410dca8cf986ad65e24e7a90bb78e02cdfe6a6c83b3b96f5c853f51400b491e25470b195d56a27c4f381f84d8a4355fab5d23307ffa45e454a70dee4d8dd971c76a4b13adbad1c4663bec25b83f6f7a8f91026ade10d3d6379896e48255798a4799388bf0dff28931b49ebd3b57473705611a8349d4c6eff72ee5e9d0abfa4e936286407ef042cb4babc4337dab34c7217e573f4dd2f99735863b4fd557e6dd6d9c23bdb187ee700af60d6cb1ea7871b3c2e6bf347a71fa8e3c7ea1ee89f2735792eadfb15e963a633bd692e187d5329191c53ee7cca052b9f74c9d194f2ee944115401085220aa69f082d2a08d08d1b1c69016d5b1a7a37655601d4a026035cd5cf62b0e07a9d31f87a2c4e9d89ea912299365f8dfb90b2f5a6783b25511cb950e8ad8f48fc264db170ca96b6371d23f0fec81bccf6349ebd12ead12d5b470c6301ad1d9b2a4e8aa7deeb9bd1a9f495966b2b9100a72bccdc59ba65873e29f0ea2e82bd72f4db755950d685ac2fe7e4f5ec54d66bce3a86f999b73da8b46ad164d4a5acd8e3653b4337d617673e4393dbe698cd2b85996c271e7dc94da8ed69aa0ee33de106c61f7db9173c95860d4f75783b38a553163b799ddd1cefca060b9b4dca7725c8183acd6e319cbb740c69fa7b5ec6c182029956193897063f48f654815dabd571c8efb5b8405834dd312721206e3a5e8fec1e8b9f42fb4346365ba0d5eed20b4ab68621aead58cfaa60cbe4b764a8e87d258dc7a279412348ca7a655409a3e1dca7ae5685cec1a41d1fea52f28ea76ac7285be0daa6dd9c1c4a3c1901a9a89bf4ce38ec2b3cb75e62b91fbcf9958123a46ab964cf88416d7a9b875ae9ac663c0274b5707eb707b5631256bd61d14bd3abc9fbfeab0ec0583c89b75f8728c2d6213535f37d8ad0ae3757969eaba3ae7f8065af5f1f9a0e7b42e7c0d8ac9c4ae9bf72af21a2d87888303759dd0b8c1ad5ae6a94858abdf2a1aedf0ab39522a32d4e1cb6f22b93d61fdbb29589d1b65a891a725c7bd4ef2234cd39c4be4c0738f775592291b0696d470d40e57609f14bb8288d51c398266f2b58dce0ef80b6749d79ef5d7c3f3984b9adc753b2b6918a6a2b6984f29076dba2dd322adf579495a96a4879946c6ebe7b305478eab354bd65c45fa6e8e2176f346a2687e22481facfba0b571d3fc697483f5157e312b16c9cf5492a8cdb5a1d8faabca1943e2dfdd5b41f0cd96683b039400932adc016666536036c6611806c4ab4cf8b54a82e16a2403a99aaf00c6f5dca4e8a79a5a0f55cd41fe619e56eea6160d31a0a695df6b491ef95494379d03c013b3a46f8ee169de85d21a1e281a3007b28754347b1d71070b97aa03eb6d59f2dbca4ef82b96d0c064d61cf29dfbd74c0ad5cf537f50b73db85d3c9754ee2454fd9b77655642e3ca3c4aad710479a6c2b34b65ecc67af6a7c6d4bea2e2173478cf62308c86bef1cd2e7c51822c51deb0d1e48c52206df29927f5f34ac6c366aa1145e8b0cca359de32f3bf7a1aa1484924a0c3ed74fb8cf784c67a2b87da4d8e635c7c101a05468466361f84056aedc38f0404443c32df7089504c53f0c5a7a84fa789eb5f0c236acb4cbb5934935bd0285a6d69561b60092f45ab75152050bd129eb95282d4fcf6232bd65600ecfaaea9f43c64772b1f2150d318a2a6dd3e9569b75305b6971390300092f4cc0f3d4279d13ca26e0fca69d37153ae8707dd3caac42eac6ffb33bc8adaa4795aec4f3bbccae1c1d0ab44279815d1cc72f4d6b4abddca9ea513b557a2d0a15d306dbf533b0acba5e8f5013d4a02729ef88223ee578e65a15fbcdc3032a9a757e92f8739f1494340d3faa1dde970349b0eab70c6e942fb69d5be2b639d36fd4191d55653c464f5f928b5ba36d72e4a956a76ed700d8b00eff95ca145ff00347df8ca781a6e88d7e63c127f2b287a2744f15627b3ee70e6f3dd250b6cf23276ff00e14be833ed77c128a4673607375e8b3d079775ff0009a789ff00d369c780ec54942b115ba58b77823f0ab281acc3baadc66327e2e69432fe9194f83194ff0090641fb4a2c6634cd0da5cb1bb84831bbd4c7d52ca466dac63fb4faabca1954fd7dd5741a927d91a0d432ec9b01f81c9814e726c0f8146015029e974f06ac1a7224f069f926c78fe53e8d351553dc7661eee8b9af47c683a3b87924dfb0efe0a37a18d9f47fc2d39ee0e3e052eb71e86d23c2a65234173413eeb3d0c585da8d80f206e3b3a26bd353f68b77cce83650eba0b0525b3e5904a850f27fc53719441502307ff008f553f2192e96d79cce2ecf519f75d3233507a8759112139edcae9e6142dc35d0918727b30af20605c40ba02f3ea9b198c92ee7c53e3550b8d61e99462749a7a7277ea8c6448880a31480ecf5bc9312b2c6acd70d63969091b2298e85d23fb4a5a6681a6f848e7b3292992f3f0b8b08dba6ea81a1685979486776c80d96d50877fe65013aeb2823a20029ec001e8a7a9e077dac03d16eb0dc700cacd3a728250dee485d4f5aabf296f26abadb23c850bca75275749f6a59c88a75dad39548a4663ac74d6c4acd0cc27a8f96ec7fd9525327ad779042cb4d89f8aab653b5be414b51ba59d33c87a97ab4e8b886b841b857e6955fd5e314cff0022aa1e59b85213291de573e36d5d6dba48b58d77af82e9e639ead367a80063d16d8c9036ab9b0dce542ad0d586b7ed5bab9bbadfcb3a128d02edfaf49dbd11a43b59a91ddcef646841ddb5413f6add6e86a0b9f62d1abbd8abf0862f966ba78a5c0b6d35db18dd6a4b150dfb6ea9a1e27292a799605bedb1f2b727bbb76495baa4d4ea4e69cc79db71e0b91a16e56339e607c53ca1256da83dfe0b684e5b2b248ddcdcc71d709287a07857c5cce03bc1bba850f41455ad7461e718233de942a9779a37fdbc8093b744f28613c73d21c91f3b5bd77d87455943cff455041fbbfe8af29b16086c8241d1560c10740b71fa42da3045368818d87fa29d186aa8eca113673accec7d55f90c9e78f7f52aa0d4b16c8061a30ab08f9b509b41d0e4da0eb42d07a39c0eab95b82e9284c9fa4a6d18b2daf8515121fb1ae3eeb2f631a9688f868aa7905d193d3aa9dfa0c7a27457c2eb5b83247ddd42e6f6b6366b5f09e9e160c31bed85b3a1872aa78e31b6c5668c572baeee7ecd3e1de92d1893d3ba64b9d970f14b7a2b47a7a46b000126b2ab1c5cd45f2298c99c6012a9cf3a57e477c487101d515ad20e40711d73daba27cc9525a5350911b7c82d9c8d357ed419255e46a9772d505a0eea8143b9ddcbcee52e9b159b93c9e85368aae56c39ea8d4eac9a6636818e5dbc51a2266eec8f1f681946a9147b8b5a0edd567a60db1dbf9ca4d3357d17a423047337f086c8d5edb451b461a830aaaa461df0988a35f6610bb9879a0343e156a66cad406b74a46100dd4b42852e2bd719804432b95d750dc8417550b86bc0246b73e1d55241ad9f86d2f3869cf8a7356a1f521a7d94ef29d2a5beb40dd678114bd43aca304e12de148cc3506b76671951c0cbb8917c6727da47a6c53c865274deb501e1a4a2f26d6c16cbd02d182a7796e935355ba9ce46997d6ab4e49686967c80afcc2da81d4d1f346e60ed552314aad1e5927311d5c1240d9ab34c8342c206f8f5e8ab032534ee649c84ee4ecb6d18bb51f04aaaa9a0b5ae23191d573746876d1f0df5a250ce570df1d0a97a597cbbfc24d6160cb1c76cf428f401e84f84faa35003d8ec67b8e167a2379b8fc203cc59f97b81fc51e83ca7c63e0bcb465ce734804f7744da19adb28060154942c34f53ca538592d97c013605aed77a0e230b598d02d1484b7d8a9d62e960b9c71bb326ca7a0debfd6ec7b7113bc36d91a5d67d699c87f31ffbae791468b4151ccd55901f6d1f29e64fe424a17e42cf207d25cfe511cbde0ae7bc86edc3de28e4358e3dc372a7e435164cd78e66f9a272015e692399bcafc74237dd5a40c075c70465327342cfb739f05b28d03a7b47bd8ec3dbd3655946a7df6ac2a68d35f4aa746b38ad6eca65667ad5fd7d57473032ecff00aaa87c42007958b34815b0a6d07a20981e73bff3c56e85d387fa064a89007b0e0f6e36c79a8ab8f5970ebe172220123b8a5b463d13a5781b1440118db1d8b9bae86349b65a1b10d80f65cdd74309bb6a0c0c600f44b29d45bd6ab27ed055a0552a9c5eec2cb426ec3a6b7fca9da17ba40183751d64265b883d15392d625f1477e2281e07f13fd977fce275f92ba86a4ba5c9dfee77f75e9f3c4c22cb41732236a9798c475d2ee77461b54fbadcce7aa4a6c42d4d6051b4c168cba4786b1b9cede69f595ae69be00544cc0ef96edf7e87746a75296af86fa8f9e1bf25e1b9c7428d11b7507c19b5cc04c6ec903bd66a90a9be04d84f43ecb9fd355cbd7c2fb298fe53e9908cd14e6f6782a46a12eff322e80a786556bf5d4836c2d4953d41a85d20c1ca02e7c23b998f0101e91b45cf2c0500e565c3653b1aa6deee6a6c65dab35416e4fa27913d54acd019e56bb7eaad20d7a52c156e8616968df0b9fd28a76a8e34d531cee5614f2a750b47c6b9ddfaf2aba21ab86b52fed49aa4522f772713d4a9c86435c7247dc729f0aa75550f2bb9c1e9badb0babe68ed5db609f0497966ae105eb25139368835bba6901e6cbd534854a688b67cfab6467a3881e09a86fdae7e16a331c6e68eb87294a5865dc15e584478d8003a2acaa442d07c2cc0f787bba8394bd53e3d17c2ee1bc70340e5040db70b9baac5eeaec34cd7f3f34608df1b02b97545475ef10be58022e570e9d0146807a6b563c11261bbe0fe90b74899baf1a240f118c60e07446863df13da01d554a1c1bb91cdb0cab15f9ef7fd3af8242c231838ee4f02267a672bc098b3db0b95605fac361e523d16619a652d6f2302874cc3150ff0099b3b6ca91744516976377273f94e5102cd938093151f43961c2ac81688662e182154066d5b41e5cff00d528172419190a3603f62b8b992039c24b03d0bc3fd7079797d118164b8d61c737aa6c09cd3dab39c7cb7637d97327a94ba6868cb72d2398eeab28d66fa92c1ca9f46aaeea65a3592560d90bb32d6516e7d55f9a198cb060faab4842643b25b08179b3d54244df494c5561886cc090d1d7a2d9fc3b50e1af0466ab90750320f9859687bd3871c0d6c54ec1c83200df1b93e6b83ae8d1b1e9fd3ed8c6397a285e9489b1518482a1aeda94353c89d52aedaac157f97c822a919ce57779c0b45ab4f63af9ae1fa409f8e30d0b93c0415eee2404fe0e83a0bcefbaaf3c91987c49d687d13dbd762bb3889d7e5f6aea7e49718ed27b976429b82bc614daaedd35300718f049a00b28cca33bf7ac38bb470da59e40c6e7f8f459a1ea4e067c1d4bcd1bde32d0438e7b925e58fd1fd23a2a9208236185a5c000761dca7782a75b6ca1072216e7c828de2b609269fb221852bc55604afbcc0d07ec03b3a2a48c79eb8ad48c95e4b5aab033cb570ff99d9c2a4a109c49e1286c0f7e3b09e8a93a0f245669ae690f9908d282abd1a71d12e849697b3163820360b5dcb0d0b741ab8def01108a4df2fa37dd38647a975273b8b1be49c349e0d59c11b8f159687a2ed3681cbf70d94e4002fba2d8e1fa47b2ac8193ea8d1a19fa5be4b428b51a7df9ca5c06df47de94d8124b567a24a5405f74f7da7dd1198a5c15e63775edc276343b15db99812aeb353ca9b1a2db518f54948d33839a75ceaa8e41d038151b43ddb3d7b7e530380e8df1493b02751cf17c8690d19c7675e89e7668f33eade33474d3b6370c6f845e84681a678b6d91bf69c6404be8eaaeacb6d4c927cc64a40ebd76c23c900535739a7facecf677a3c85946b06363040479066df5e26943bb884790f44696a58e687e5bc0c06feedd7411e03f8aae1886d63dcc0319276e89495e7fa3a419c11e09a089aa5b780721561d3b43260a2b563a776429d092a2b4b89eaa34255da75dde928582dd69c3772934cecb6bf14da07434dca3aaa6852ae16c799f981edf44da17ba17e063c0297a0906510c652de82c3a7ae7c8423d869506a2e667a23f4080a7d505b301e2afcb9f1b4699d5a1c00f04bdc6e08d576d0f61705ccdc63d707f2642eae0d8caeaa1c84b2a8cef575375f55d1c8659594a7f2ab28092d115b4a6d96e39c949840f71a77bb66792d3341e11707679a7639ec38c83d3653eba6bf43f867c30640c610d00e0285ec36da0680d0dcecb8e9a18a8b9001dbac522b772be2690553ee9505c55244ea25b67713dabd0e7f8171d376523b14fbef02db36035705ec2af74d46d6f555e268542eda99bdeba3c056e4d46d1d16792aa9ab6bd92b5cd76fb2bf313af087c42e8d2271f2c76e760aac65b0d8a63b007bba29196fd33c1e749bbda7bf70b2d0d32d3c2a8da40e51be0253bd2fc10f87e8799b2168ec2a7a1eaca5d36c84618000004de8885bc573864b5dba6d284a0aa71df286c5a69276f2f5ec4b62b1947132fae8c1c1c7551c6a8da6a474fd4e7f2b2868b6bd398c6de293422b8956ae6a47b71d842cf61e1fbee9331487cc95494a0df6ec84e0d0b500b41f926e50b34206e572c8568319a6b3bf168fc2a418a369f8b9e6cf8e51acc7aa78590c6c602ec762518da19aae9d8cfb9c3a77e16c8554afdc4fa71d1edf70ab20506efc4085ffb87badc0ac5cf54c18fd6128532e77b6b8ec52538396fc1814cb8abea2d680b4e08ee4319abeb0bddd7b55198d3f4c13c83d1261f578a50709868f644e716f9a9d3bd1fc2e8db141ce7a800f8a850d534aeaff9c705db051f255f2d7780f3f2f3e0a9e4d1e5ff00896d139ab6bc0c60e764f791156d3b7e733ed69e8004be4eb7c1ade6c6093dddeba7082a9ab1cefd4328c09585f9fb484605f7455235a328c07f8b5c57fa280398ec1231dc86579aef1aedd580973b24faa42337d5160e43903c534062d12f7aac3c1d56dc1d9158764ae7346ca7403835848d7752a342c70eba908eaa741d8f5c4b9c64a8992d43abdf9dca6d0b14378716e729b43e8eb0f3653684bc170ca9604fd25dc630b30276d05a52d8171a791a1bd520092d10279fb97a3c13160b35e4b13750d8be5bb5473b437bd72d83190f17ae6639401dbbabf06c56241b9448450f54c7d7d55e40ce6a69b3b95bac81a58c0dd2de948668e02f70686e7270b2745c6ffc27f8703316bdc319c1dd17a63d8ba078691d347cb819c770ca875d05de00d030b9bae804acbb60a4c34572e17724a791480f90b938a90a0b3f82cd4eac56eb50f0559f4076e15ad60ec0a3ddd0a26a2e2106b7af7ae390321d51ae4bba2eef98542a7591c76aedd362166d6872b3d16c47dcf529e5cad953c659aa6e02476f8f55594b8134f59a30ee6d8256aed6db802ef961a0e76d829d0d274df0d4bcb5c477153b4ef4a687b38898d1e0029da167ac9f65194b8aadd5a15e52e06a57e02a5a69077d56024bd2b2337e2c529744533115c1f8035a4153e835b76cd1851b020ef14dce0e54c3cbfc7bb2861047e15606510336055e406ea06c9f02bd73952053af75185d25c641af2e84a6c18afd97597cb76e8adc68560e35bb21a3a6c14ed18b9dd7531923079f73e29e5606668c32b79be61cf5eaab284157e87737a177badd0160d16e3d5c7dd2876bad022edfca56e2a3ab2ec7954eb140ddc7b511989db550637542b54d3d0e1bec9702e16b3908c3adf60a60d393f94b4cb49d585b196b7cb650a6c5e78497b20927b73d56c89b42b4ea7e5949f15790d11dc45bb895a49c671ea9e72182d21feb1eeca2f275d2d35214f524e492728cfaa3421e8b567f5704f82dd0bc8d62d6479c8e84a343ce1c5fe283aa7fa7bec484a607a0472b327b1227560d515c1cd3e49a08caa3d41fd52df1c2ac51a7e9eb407b7af667bd6876baca46d8cf628f40247a3b3d8a7414fd2ce6f40a340fa2b09ee53c06ab2d673d3c518166b3ca71d3c168483815a0e5385480fc532a48162b4deb9425bc84d506a5c952bc85b2dd7b1cbbae8e0a5c97707a2b5861da7afdcaf0b9ec6a1f890cf9d2029b9323cc1d55f1cea26ac8b00faadc0cd673d73e2a7d534433285f33f9199eb85cdd74a47a7b805c027bb95f2b7b8ee110cf6be9ad1ac898d0d182022d2e242b5bbe7d142d221a6a839fc28d0899e99c4ffaae890d1f476524f7a790f13f6ab101d565152e4b1aa14955ebbeab6301dd1c4d0cab58f11c6fbaeaf1a18e5ef53b9e719497e61093dd31d5539e4212e17c6146af8879aa814ba5c32dd44c1f6bbc95254f19eeb7bd465f862aca5c35a7b4bd4d43808b3e89ad4de9ce11703666e249812460ee14ed0f47d3e9f631a300740a369c4c53869092872baf016730f8ae5daec02eae792e07a7bb8c755b61a401597e0dea542c564456ad9b9e0cfaaa24ca68b5c88260dced9093a63d17a5757c72b1bd3a053b03ebac3fab092c0f3f719ed7ce37ec5bc879da6ae024e4eed9757301daa6aad8157bb3542851efc080574c81956a0a3e7253052ee761701cd85942d7a2744ba46f3346fd54284ddc348d480363809e152965bf4b1101f9c055942cd37112123aff00f68d081afd5cd3fa4acd082ab864937c9ef4f4ca6ea89081cbe8a6cc7da7b4e970cfaa18b11b47285485c5c2c909c63c92b1a4e9db092dcfaa0e0f576a1f960636ec4b4eb0f0cab1b338076f9c2e7a66d15f0b69da3976ce12ca91147780483deaf3a34426aad43f7602ace82a75200fbba22f4776dcd738fda5736a4b5098b5bf76fb611a198deaa5cd90b81ef28d0ab5d3889213cb9f0468311dab9fefefdd514a90a5739bf68d92a692a97b8b4f9616c0cd6ab4dbc4a5de39558a4681a53527cbc071f05a56a167d490b865d851e8245b76889db0a742c16ad3e241d9dea540cff2a007a25c01aaf478ce708c06196868e81600b516bcf459680f5167761273d80d4f6c76575f3d016fb6bf09ed092b1d9dea5685965b6c81bb2bf0984a53237aae8c30c8ae8412b9ba325ed8d32b494b1ae48fd96c454ad5adc8c95d303348adae7c9860c8271b6e93b0f4cf03be1f81c4af6ee70edc2e1ea07b034e6986c2ddb1d00e89af4aa65d36ca36846d7c8485308b869b256604ac36e18dd04d726958c1d423fa355dbdebf8d83f501eaa920d63fab38de03880e1eeab20d677a8b8ba1dfbbf28e606777bd741dfbbf2bb392abcdd7207684d496a22f5aeb3d0ff00dd25ac52eb354bb9b651b1d5a85bc710a56fe907b94c6a634cd3cd3904b4e3aa06acade1b66405c0f509e51af57f04344411609737380774b6b9f1e806dd18061a463a6ca56b71175956067dd4cd8a55dafe43b64d8622dd5e5dd55a2aad714af6228b99a5523359b69ce23973c027b50c5b2fd77e6e539ee4a5d59d9235f4e1be0af28d603c48b186cdcde394da3556ade314d4a3ecce360a558d63873f1006787faa707c7650b0272f97164ed71c83b79ace608f28f146da69dce90038dcaebe62910ba1f587ce61e6f109a8a94af841dd46a7546d474270554caa5b74df3b93049deb87c0c5b0dd16817c3cb6ba1182df052d0d6a0b5b1edfb8b42e80e5e38394f2c7cdccde9e4a3d06743815003fa8753da9635155fc308633b387baa40afdd6a5b1b086ee770998cbcdbdd2c84e36ca0ed234ed9b9234274f4941cc84aa7b4fd137a154d6b66b05b4080f913f8469b184eaa84c92b9be247e546d6ad3c35718a468c76850b5af40dd6b048c193d816eb407d3068ea8d0067b4090e52e842ea6a2e56e02cd06ec55fcaddd6d29eadd43cdb24c08eb9d0b5ed27c1340c9affa7807730efcabc0206a10c68f40ba2f702d562a6f98ce7f55cf7b026ab00fe127a315f401c134e8222e5a6c6ee3e6ae10569ad3f30b73e092858ea2be48d85ed04e37ef52081b77c46cf138b707b9285eac7c7d95e327cd2e05887195ee1badc07ed1af399df7153a1668b5234fee0a16014cd42d23a859f382d3d4d7369ed0bbe425ab15b5f191b91eea3d27a2aaef11b06c47ba5909a80add7e0742afe9bca2ddabf9faec97d3b791d0d5f324f4a56adc38b4f3311e90a82963dd5e278a3de6d8e9a4e46e7f8fbab418d8f81dc042c20cadcfeedc77a9f55af57d874fb226068002e4ea84cf305cde8c8fad9fb93c0024a95a0ccb736b37dbbd6e051354f19e38739c269ca1ac3b5b7c4c34921a7bc279c8d63ba878a724bd1c7f2b706a8d71b9cb21fd47f29b06826dba677ee29e4303974acc7f7155850f53a225c7ea2b2d25415658246f52542d2c2e8a98f6aad8e9d5b74ce8912b8647682a146bd31a2b4744c887da3380128d7353e991fa9a00ed5ba35481a9e481dfa8ede2a36b717cd1bc670480e77704a6c6aafd64d7b7a8e89e0572e5790ad21b08a7d50c0dc6d95a3599f146f2656f282a90acb6cb4ce6c837ed58cd69d2d710064f625c2a57436a9e79be5fa29ce89a0f8ab652e76de6ab28d6517dd301e318dfa2d6a06a7444d1c44b090373b2cc01b47716be43832524e4f2efd16c878bf716e3654d073b00ddb9f1e8af2291e338b511a49794f4e62b28ad574eeb06cc00092c4eadb53a5b9e227c106576d1a5cb5dea982ed49620474d925a01d7d88038014ad085bd46e030090bab422e3af9b979798fb949422ae93c87a38fba583559bb524a47ea2a906ab8eb1bc9fbb28d2a6ed5a50039c234c9975381b235b43b806a352a84abd45f2dd94ba31b7f0b35fb258b94f772fa946988bc70c9dcc64c6d9e6f4292d6e24acda64370ec6ea169875c3200c146b0e18dc5a374681d6acb424d072eac046e9742897493eec357514d3ed4e3d16e022bb99acc6512056aa670460f927814fd49a4247e397a7551b4347d1d4a63a70d77725006b6b32ef54d21962b633ed4d80ddd2dce9361e4ba342168b40b9afcfaa9da1a57f97dbf487206709031f8b865f35e486f69ec59a1235bc367c4cc85a0d5b2c0e73536812345cbd84a9507a5b64b1b725c7feaa76045b7543c1c64a388e7d58e87513b19c95db8cd4a32e52387daf3ff00451b0f816abe71fde7f2b64660ba1a6791b953b0483194cecec971d3cd5ef445b5ce7e0f82cc3daf4e682b27231189d661352938015a744c6a7c3ce1687b9b239bdc7a22f431e89b1da1b1b76c74014baedb831e1725e860496a080a3cc6a26e15c70baf98156bbeab6b5a7255b0318d71c4e937119ef096c0c56f9595331dda485489e22e0e1db9e72e61ef559062d96de1b4606084d60c4949a02168ec51a311b3d9616f72a68c57aeb59137a108d658a35df520cf54953b15bbadc3986c90b239a7216978e6e8a9ae8c6efa629616b416919c6525a31608b55f2ed94b20c435df5df665360c51752dd9ae0707c573e2ecca4d56e8a4c83db9431a6e95e2db9d819ee1d553966adb73d704b3aab954a6eba97e6069ce09c7a258d5eaed5ac100713b900aa1754ca7ac1f301086276ed7f686f5ec53a457b871ab47d775ed51c2370d492f38cf82791acd2ec7055393e2c36eb69960c0f257867947e23b4bba9de3901c7335ddddab0469dc3bd41f3e92389c77e503f08523cffc7fd18592e40f14b68acd74bea97c4fc059a9d6e9a5f892e70c13e0a921979b55d0391605c69bf4852e81aad872a215cbe52eca9a147b93dc3a2a40aecb56e4f495f0949eaa74a5454c72b35b134c8f646ab005dff49c0dd6e8aa0baf0e0e2d7796e8d2585df6d6248bedf349a168e145708701e71ff54dadc7a434f5f44c3ee3e1e892b4eddaa58dd829536336d59737870e4dff00d16e1568d371bdd18247725c03aa496f5d966046d7d79212e057dd1e5fbaec94275c4630b4202e2d1be51684553da5ae04faa9e81d4b034e40f25a505789f91a479a6c081b310f393de9ccb2548706fda8d03b4fccec6e94266ae438d9281749723cbc8ee8765309fb1410b372464a5090b9534720c646138526aed5c8ec37a652e81b50472fda8d0898c073b0ff0025a134344529dc11deb38ae6c3834745d061747a6e088b4eb5aa37a530f7f8633b5579a634ea268e89358441a6def3f603d4268d7a0386fc3a2d0d739bdc56436b6ab75b80c63c93159f697d301efc0ecdd7399e85d1748191631d364968592260c7e543ae81ba89b650d0addeeefca174730321d6bc492ccfaaebe606475bad5f33b977c12a9603add245dbe7c54a85a2db60601be16f230bb872346d85d30628f7bd481bd165a3140bc7137071e8b9ad18a55db5939fda9f4d8ac54d5177694697115574049ea889d843a2dbaa7c2e3e8eaf04286af8bae9bd4c476acd18b5cd5f96e72ab0629b74b87ddd5564188caba8cf6ae6b0ca8deade4eea74a81a2bd984e32a908bd59b5bf301929cab1515cc3882539f456a9be623033b2a4601b05e476945090bc4648ce7b14c8ade85a72dabce7b51857a8ad6ee78baf6243c8a3df60cbf0a9ca896d397ff0094dc1576b20f881b909c1d87629d2abbc1ca4226033b6c92d3c5878eba4fe6ef8ec49a2bca35fa439643d89a274452c7f2cec574c8658acdc412c384581b4690d78246851e82e4f981c286001708f6469aabd5d6cc857e495569ecc9ea74c9b400a74b1d1004ad889d537bf94cca15866d77132b398ffd90d57eff00660fddbb1ea8684b75d39406fa2cc2a563b2f3381071d0ec9b1ad7b444640ebd9859637016b0d54637295302d297d13bba76ab611b5d9e10c60ce166053759dd73280364b803bdd9684b810b5555bec134a065aeac9ebff44f02ababef84038f1092d03b413b9d873e5ba8da16db3698e57389f1289d159b6b09f33160efc2ace824ec1a7b906fe6b2f665aa183651bf4066a0e3a2e9d0720b877a340a76e39948037487ae4a5094a3bb607294d4243e7070c76a8da02de20f96d046fe5bad9406a7b3fcd01c363ecab011536b7467a950e697123435840ed56bd1b059bb64a86b1ca894e365d3cd2ac7a334cfce9037bf0a1edaf48e93e12885a1ce00e7056fe8c6894f006b0379404ded879b00053fb32a1c27a6265395bd533718630d695c3dd0f9d5d851810177be00ad390a55e2f4485d5cf3819fde6d5ce775d3280749a62369ce3f08bdc05dc6a034602e7ebeb02a377d46e1d0a69d053ef1a8a43da9e7614dbadc9c52dec2ab718495cd7a36a1270ba236b8e8d5625434922a62781ea5c8c2a12a494b63a12163ae20a85875a2d77c25dca4a6e59515ababb07f2bab9a4a81a7ba9254ec69e9e6254ac0abdf2d79391d8a410f62ad3f331e898347b754918dd39a9ed5f50e310427558d2a65f9adce7190811b4574786b73dc8510d471863b9bd51506e5a16ea1f0eddc424a6c46496e7179cf795b1a22e540047d3b15b5b8c0b8854ee2edfbd4d83b87ef11b8177820f1ab5ce95b51192d19db1deb30579838a1a54c65c40ed29a4232c7547615d20d3583ff003bd684ad8af1231db9dbdb652b0364d35afdbca038a950b38bfb5ea7218a92bc615e04157d582b4a8a9ebc29d0af5d35106ee4a7a1956bcd61f33ed69edc250d4f87f6b2ea1e6f0f540c40cb51cb9e6f10b3198ae365cc8709b598b3da6efcae683e48d36362d35380de6f04da6466acb17cddc78858d0da0f4e3a23bf7e536b1a6c75aec2342b979a62e7e565a0553c6a5682dd48dc2400eada00d928571962e67e5c36fc2d813f474ed8f66aac09e6d4e1be892f219bdcacc5d51cde3952b0ab63e976dbb80498d8553c471badc561ba9a62e5b29034b4c55630753c279309c154f4056032eb73b9b2b7a870f2c32076cb96c0b15a67e6fd5e5bad8160a6a103f4ae994236ff0007451a6a9ab6b63e400e12a7415c22603b2d88d435c2b00fc2b256366e08d192e69f10579fdf2de63d711c63e5b73dca523ab9013c2bb788db086055a85573848ffeb149d555ac57d4632b93a0af57dcf09790a8ddae04aece6057e59c76956d006a6b9ab4226aaf78ec50eb9a159bc5c32b9efce853ebe51deba702bb73a81deb702ab5d5892842565502a58cd44551dd76436be61c8568cc45dc25c2a1302b6a90544d4d665d84f61a54b5051f6faa858ac31056f2bf3e2920a97a9a412ee4a7953a8ca7b28056da63b5148076a95a014906414814ca5a02d989f14c1a1dbe1cfe1669a8cb952f30c2353a93d3d6568c1db28d11397598eddc8d53fe2ab78af206108e360e095493160fe765866892c0d0495adc095cde661184dad627c42b5608f349ac88ca9b796c6081d88d51a270b6b1df288778f55ba107c40d20260edbbca6953af217102cbf266e5f1c2e9898089a36ff00cc2a403db4e12507e0948e8a560592d1a99cd1badc5530fd52484044d4ea6216d2a12e3aac8530a26a0d485c08256c2c566c9485f277ee9948f55e81772d272f820f2289acede5c486f9ecb70fe54eb0523fe710e07b0296b2f2bbc9a79bced3ea8d2e34dd3acdb97c82cd2ad748c68db659ac4bd351b5dd309341e34a02a4a11d534e319596842893752b42bda8af6f68d814c156b6ea695eec60f54a1aa5b9998812375b020ee2d70946338c8568167bbb792207c02ade42ab2550c73295e4a4c37b2a7e5b0e8ba925662b1f0bb10a108f9d70558c2e0bc9e8a9a058bd90941515e574587266bc2e6b0186ddc8feea6053359b9bd13e82cea432019486a3a2b9e12a75d75c4929a54d1d78948c7985585c7a5fe1de2e66b7d14fbe5b23d59351e236f90529caf013a9d75f3cb693f42b3a4ec50385d541b22958568b75ba8cae5e8d155adae472d425755657672653af75c42968564dcce7aabf3403abb96cba79e6057ab6ea557f3815eb957295e48a95caa8f7a8d810f2b8952a9da0e6892300d53805694f1c69d95655a2b7a86a300954d2d8ae592e25ce211a95483ede4c994f7a4e2cf4d0903d14ad5a21ee5447fd549a36cb55818ede8b3424e283feab6f4005c3653bd0376f6e42cf40d0b50e64fe82568a870905152c1b213a32cedc38652e88b8d4c21ccf446a9141a8b5e65c78aa15b670e29c3598ff00b21b89fb9828ad4b5bf059ba9da6c63fc57a801cdc0ed4bac4c69fb407c2d711d9da9b4f125474a19b37fe89f5b56cb4e98e7193dc53275e5af881e133db2ba6036193d3656952c79be8aab0e70c7438549462c14eed938c194d1e52e8c49434c935475cd4be822ae522d2aaf5f326c0ac5c5cb30b05e86879a4f558a47a534dd1ff00471e08d3ca16b29dac3bfe775be8fe9f525a584f3340efe8a7acbd18abb49072974bab5e97193f849a54e5450bb9b6ca5d6272cd196a9c0edd6e5cad3956815a7ea2c9c0dc2024f9c6329418aca76b99d1300762b0372761ec9427e3a60005b00b652b4b81d95a0466b070e5d9746850d8e3849694a7372a1d56c2e21852f4ac10232a10872280ab461b90270591b2cd0eb2256bd1cee54ad04f2a9da1dfa70b01ea58d2dada23e62c2d1514dbad850f7d76c3cc2b42bd59f0d6cfe9b7d13741eae922cb5be4a50f299346ba5ba7e1a70b97bedaf38691d4187ab7510abb49a832171746880afbd94bcaa88a9be95d30cafdc6e40a2f2557e6a800ac97001a9aed9579ee840d64eadfad081b8ce026bd32abb5752d2b9af64a8f96a5a173ded357ee97e0113a2a329abcbcab4aa7299116cab2ba6206ef4b9d93e8b01d96c21aeca35cdd27cd2a5f494151c4536ab015c64ec4b4e8581c79bd5205d29e0fb54e8075f6fc84942b72cdc870b40fa5933ba7813546490b057262509d042b5c0a045bac574246e8523af8073f32a4662e9a46b0e13c32f113b2374b5b8339f0d5cf6b550d51a604b8dbc566b209b7d296b430766cb4e21b41f7642a8aba691bb8cf29f2f34da9d4a711b42455148e0002e20f89592b71f9dbc55e153a9647100e0927a615e518a451c9855d18978e44b460e86a973e943d555acd083ae955e150356c5d3204254c1d52d099e1d5a1c65d82950f47e96a57000151b468fd51a7c3b1eea77a66a2ed7135a71e8a8cd7d78b944d38711ddeab0da9dd1f00276f31e4a54c9cb94fcae4ad1d64aae6ca2310fac1e034ab408cd2b67cb727cd6d09a74606cb01c9e9fec4022c4ec1480e5c6b719c7626805599c5d193dcab02b77daa27629a50837428b4a535aa1dd6c2c35725aac75a56c21d864568c2246aa687620941e0d53f4771cd5ba0b8d81682df1240e4486d3ad294b44c116eb6037738fa79856857ac7e1ce2c44df459d54dea16d76037c92ca34a15a153d36538275c9f4a778ce0afe4395d76a713945aaf231e8b96c560b96e5b6c729b9e4c89aaab2ba79e59aad5dee440ca7c6ab32ea7df0a5d400e7d41b2c81075ba8d3c0addd352923a27b59a8237627a82b9e96a22f17c3d0029312096eb7ba4ec2b642acf41a7795752907ba3c27747351558dc9456755ca261054ab9aa463a7394a51ae6ec9e532b770a43cca9aa4071c3f72dd878b4d1cbb28b47360c8417559be69ae672cc6246df61e56adf2cd48d3421bb2ca5a4d6e30a762788413e5d8c2d868b8d9ed9b65562d0f5ecf2b5524225b42d49c6e8b0cd4a9a90ff0065cfd1b46329b2b97a8d2e5a5002b40126a518ca608dabacdb09f41bb1d561d9f15ba1b369c01cc04f779852b4cca38e3c2c15513c803605db0ee4f295f9dfaba80c354623d8797d95a502c3376a7843ad0b3081aa0a6c36a3657a668174698c89ac8b2425856c9c11d379901c2dd0d6aa61e49c371b6547a0b5d6da039a3c97350acd3e8671939ba2c0a9eade14bdd2730cf5056069ba1747f2300edc0f34b809d59613cf94b80ce98a52dc8ec563a3aed6acbcee808ca8bbfc9610025081b26b032485a476f54686814cccb709690fc166e5dd20313d849c95494256d741c901c9ef2a92867973accbcfa85594017b764f28361c9682c394ec0581953c071a16c80eaac0f815b41785c20b11260eb234da0e10b41a74a854b8a54152103b284a86ba767985a58f5ffc3a517f41be8ad699e88929f6185cf4819ccc256c2e3996ab1e3ca972aa715faebbf21598ac3b6cd643b4aaf3c8d4fd25edae5d3cf250977a6e61809ec6eaad36907e73eab9ba834c4fa74853622e7d344f6201b66921da12eb340d5d9183b121755da9d3ec27a269134a505a1ac1b04f216d26772a9e00a94eb4a8d7d364a5adb5236ca11951a953f5386a186a19b28319a8a6ca5f4745be9f74bec2629a9f64d2b346c4c3854618a9a6703ba7919a3a88642a615177aa770079544c83b2b9dcf8774498316034c06f848d913165bb35c71d3b139e2624a2e6eaaf2913fa7a998cec45a65de9e6d94687195f83d542c369e958e721a54870ddd3684554c20acd0044982b74352d1f5a7e580942e16d0c31bc3bf8b87e13c65afce7f88cd03c95524a074739de0ad0ac66cd585c33dc70a90b4754127a2a627a1db4a5318bff000d40d0cfa6c263229f49995adef214ccf5af01744f2f2b88ecca4b4345d4b648c49cd81949411434b93e0a20c4b54c0ec0f25a05496d0e097039a7e121e42302c172b7b4b327fee97028952e6b4903c5570ea5d64e7989f153073e8848370a741aa7d24d69e668c24d096a4a62d2a844d36b81d92503a188745b020353dc393ec07aaa40a1be1fb89f54b2820f457941a0c5407430ac05b429603ec09a4070c69e020b16d0743170e02be4ad05f22010f0b743818b4e7035051948d432bea98b38f3082bd77c00931037d11a1e8ca5b834019ee4a405595a0a0d0cc1284cac7902a46cb61548d42ddd521b14e353ca55a368ea0d545a55254aad341ac7c552d6eac549ac9a7a90a1d51a5d45c5aee8428b741ba540d7d2c630931240dc2d99400b1e9e4d198726b09568311a74d9ee281207934d9ee5b29c28d3a41e8969d2943a7fc1468c72e1a63c16eb31122c05bd895a8cbab7902408aa094392604ec6cd9581da40729e52e0eaa83215252e23e9c3b38c279d0c4c7f87870c153111cfd3ad69c8dcac5240b70a4fb4a4ad33a3a881254ed6344961c302a4e824b4fd17361369571a7a0c04b68445d086ee4a4a5d48e8fbb890900e7b3bd66282abda3988460093526cb0206e30e0efde80d6342c2d310dd643a4aeaf737a0dba2784619f127a27346f931fb49e9bf456943c096687941fff00270fcaa4226a2955f49892a58d6698ba91dcb346027d2a5d3226dd47cd54c6e3f73467d514cf7b69fb59828a273475683e3d14ed0ceeeba9e57540610719c240d32c76dfb478840725d0ede6e63e6a7a063289a36f44c0edb68580e5010fab6e38e9b8406733d464a5d381bac008d92e82ec5061bba9049534b92b30115d543b4e0aa90f69f803dc902d1f20337590335d7155cd22708288249010e8d56038ca754d0758c47a0ebd8b3414188d0f937a0fb951e81e88ae7b00b6b16070b500830a5d0472260fb9100fc2100b73fa798407b0380d4ffeccdf44a1b53e1d8264e852c45343d1652fa5a3c8752ed95e42628fa8a4dd3c328b5926e9b59403e63959e91aeb6e0476a7f467cdb9bbb0953b42e9a6ea5c5b9252c0b2c55d809e07c2e0b6c03e97054e848d3c4111b83a1a6055251874d1b7b9057cda36f7276913db5b9e812552130db867a2953e3e7d003d8974b8067b403d898aa56add1c4b4a18cf61d34e69598165a28b1d56a983be401bfe505c36fac0167a2e02a0d44c2fc63c16eb31621b8d954b0cd3d360ee9d680ef510e43eaa35b6227483f73e6a148d263a7e660493a627f4fd2f2e15652ac35f521ad4d59aa85f6cee95a71e3e690a5f0d34bbe22739ed5d38aad535110e2e292c037e8f2ce6eedd2865dadf5635bb771c202e3c38d59fd307b144357b75e5b20036db75494aa7f1fea9b250ba303f691f85581f9bba8ad1f29e1bde5c7f2a90a6628d535b893a38f3fd92e9b05b6d78ea8d686aa852e9b12da0b4d7cca963b1fb9bfdd352bf4027a20ca08811fb47f651b432f96ced74c1d819f2440b57d688f191dc13813513f33723cd738556aeb77c2dd08cacbb1677a608faaba738dd66857676ed85cfa742d4c441dfcd6e8134571cf9744f81334cd4d200357a6def3b2622c1a7b4fb9aa7408d52f2c8f2a61955754739caa40e08d36021a1303e02c04809341c0c4fa0b7b11a0c059a0e06a341c11ac02237acc07309743994a1d0c4e0b0c402e26a03e7c5d3cc203d99c0487fd9479041ab5674fb84c992f954fa341749385cd6ab1e3ba976cbaa7d092285a964dcaa4eb558a2d43d34e753a8f99eb6fc92b0c1914d4c1d68a3e6282afb6b8795ab759828bb28f4c75855b4c9ba097649684843324d090a69d3016d9729b43e7396e8704ab341c7cab2b4d895230dbe5c20086d1870440a7ea3b000530566ae8080969ce471fdbba95089af87b11022e8ec479b3eaab02e16da3776adec252a231cbff995cf0330d55707f391baede40cd1c0ade8355b31d829f94969a5a96823d02d9c84edc28816029bc847d3000ad9c85868583b13d3175383b2e7a15eb9d6b80e51e492067daaf48f38e6c75dd5e017a76dc591728ebd125855e744534a339070a74c3f51d8dd20e570db75ad7873e242c9f26a703bd3e999fd1c9f6fb2c654851ca9e269382b32105802eafd952551b0701ac81ee6bfb882969decab9461d4ed67700a36856e8f4e61dcd859a01ea2b393b84da1176bad1cfc87c947aa12155646f5efdd67342bd78b43485d7c9152ab6358b3a815cbad5003212d3ab905517bb07c9204f5353b1bb20260c679764f024e825d92d21fabab701b29d085d4d584c783dc960675130025520141a9c1a0d4ba0a3d52e038c5806450a63bb2532cd011f02505c502507f9539092d403c0a03eca014d2903e0a901e84ada05c51671e61483d83c1418a66f90560d4fe5e70a7415353a4a70dce429581e49a9e88f38141d4acdcfaabf06d67d58e5d3cd28073d754b3198f99164ae3b1ab7e9db6e12b316590e14ed6186bf749a5c2db22e8d6a5e85c934242372c0320916e81ad7a6d073e62cf40a056e829c56c05653d80db8ae7a05505460ac9d03975b7072aca15da9b18587415cedf8e8b302b5550ee8c094b6b8772609b0f1cab7b011b2e54640afdff004e672ff55d7c84769b8b19f34bd50d12cb53d024f6924dd40ee7077ec3de9bd858af5a8088c0f003c51ec05b555170ca6f6161a2a9c02b6f4641cd7cfea10a3684ad2b03baac06ef5100d54814eb2dd3fda037b33855b136fb146d118c01d0150a60d1d4873b71e0a6d95e1ef8c1b38155cc3bf2b74cf3ec2fdd3c60b865dd522752b0938d906335ac384291eb3f860d1fcd0737aa5b5adf994f83cbdca54172c800c2c0aaea0d42d66c71dcb7429746d265e61e6a1d50b77cdcb774dc054aecff00f55dfc114aba45ba6ea056aba9483bae7a72e8ad809d94e83b5d6520f36761ba201d64ba871e5eed93858cb001b2291216b8b986e14e852b57bf191e696052c00a901c0eec4da127fe139667d528449ea80719d5660484451a738f5811f33500e533d2e07d239310961403cc280f9e5602e172405909c1e8dd85a0540ece3cc250f66703e3ff00641e415434ea36e0f829d0727725385ca5c0f1ed549b2f4afcc9aa1ea3aadfdd72f519e941ae76ea57a36a35fd56cecc94b4d2e5575b8ba5b5bcad53ac3ef9d4eb30c3e449851346cdd7504ed3ca1202d8e481210270263996d02592a950587a781c322e890106a13761c32e171774154e54bd04ad3d4ed855e7a07db459563ab17da6dd3855ea216e500aa2832520173bb071e89ba0362a1c0ca480cd53416f2ae90add5dbf93750ee848da2523fbae3d2355d2ee6b9bbadf41f5d2dc09ce3c16e872d3080709bd03fa8de1adf455f419bd0ea5067e5cf6add0d0292e40103c96819798c967a2d819bdaa3ff6b68f1ff55d16a4f44d344791a3c0285316da4df214daf2d7c5068b748e7c806c0656e19e336c9895cc3df8562da968da3212913d6c70c2148761a70e3eab3558f6f7c305206d3907b9358c69f554ff007120295086b9531dcac0c8b5ad92673f2d07191ecb702f9a46d0d1100e1be079e54fa8055d687b1a167219d6a584b1777348a2c9559723aa0cdd2989e8a3401a18dc0a984e4d92c23c10159b7d1398f27c55206816b8b99a8a13f494b86fa12a74328d5559fd423c4a5815c2a901c6159a0fb6b1dd16837c880fb953603cd25474e380384c03bc201b7316e07d1b5603f14480e96a01258b01c6314c873097414077a780551ca323cc2ac0f67f044ffb2fa05a17d6551ca014ea8498720b91e43c815e765e975d39941d411efeeb87ba4b545ad628e379a069e3c94f3874c5b6cb458093554af320b8f9f32dc63e648b70b82a090aab0752cc92848c322c0359326029af45071b3a95079bb2af21d74cbab98098dab3b0ebdb95e7760fb5ca00b1b2a7213967abcede8bae1d1b7cb7eea902a35f6d011407a1660a90483e932e053d094929fedc22043b9b82ae015c8876cb9bb0451c0a3e089db65d8b4e32b7c05cdd712583016f80ae477193ea00ecfc26f016fbd5273c7bf68c29867f41c396b65f984f5394f02e94f621ce3d15027751d106443c9605334e69f6baa03fc729f506d774a80d8db8ee1e092991d4b7d1d36ec5ad4771234a89a9247637e527f09e433f2ff5ae9d3155c87b9cef0098845be405b9f44813500c2c5a2634bc797e3c562b1ee8e005286c1e8ad48b35feeef04f20ff00552b01ca4a83f289775ebbecb302bb3d5f36701307291ce38d9677001d417b7308002948144d5b722e0ba21144921c6feaa7d501a9ae24f5f25806521c953a064c40440329e85ae1f954092b4c803837d1350b856b1ad667ff0089f053a1e78d4f51fd723c4a5809646a903bc98481cdc26d0e0913480b0983af72e738b64c709b410e726c0f9c56838d725053501f72a03ee4580e3029521cf96a7a045be005c0395390b155e9a6b402def076dd74c0f4ef06ea08a603c02c0d043ce1004425073e501e3dae8721746b97148d43125adc506e32eff8486c3967a5fbb2832e54f4fb2862a6a718096c2809245ac3b4722dd28f6cc9e08229e44f14895a7aa4f451714ca753a3048a46381c981c150ab2871f2655e5369f8e449dd1a53265c3d14ec4f4bc838e91757300cb5d4e1cbb02cb250f3333eaa3d051eed4049d94ba6e99a4b41ed501a9216b210c3ada759e42a5a8a8dd9385d1ccc08ab4db9dbe575f36604d470e1726948109276f35a168a5bc61b83e4b300fa0a969dfd518167825e7cf92532b757766b1c420262c5562420a026357309880080a75932c901534f165d497e2f6868f01b26185e90d252191ae276ea9e0c683a9406c2e69ebca42a418fcf5f88eb1b585ce03b72b46312b54fb11e486a769aad6289fd171e661e6106d7b6b85174f970e31d89a85ef4fd4b4bc92146968ad474996fdbf8d9632aaf68b690edf64c54e8a118d94d556750520ed4c19b6a2a4cf4440a0ddab033629c04b25c1b21381e09083e9a121c500f5652f39cf72025695c718403b64b7174e3cd3858789b5ff002e21e584a184544dccfcfaa5c024bb0943bf3121dc25382085a0e34a705b0240779b0804732016c72016d725d079a11a0b6047a0f9ec47a0ec413548e39ab9ec343903f056f2d8b2d86bb719ef1d775d5c99ea8e1800611e41205e1b1200d6311a0a6b51a1e4a11655b52c67babdd87612e9b14292005cb342c5414200ca34d8988a71848d455c6a426c2235af4601748d4b851ed4410453bd522906c6f4f45174f329d4e8e86445863e5ca5415ccb650758f54959ae9725b469d2173d695f3137303ef9abab90229e7c154d0bfdba4e687d125a15ef9433bf7a95a345d45000dc8531a0a069c6e9e406a16e4ae9e7901aaed19712535e7022e5806e028deb022aed1103651d18ed8893d538c48d5b0aa4092b447909f02e7639700e7c9442a5ae982305e7cd603bc33d40c78d88f740685798bed4053268f74a6c218493ec98635ad34488da7c138c52f889799398804e1031e56f890a7fe87376ec9db8f3950c3bfb20a9aa5a5426b370b4e6a80f1010cd7ba343d9c728dbb02cabacf55188c28d2d762bae46fbac65425c67767ed4c54d5b6ab037ee4aaa95aeee9d709833065c8e77440a7ea8a7e672705e8fb70667212113b55134e4a009a0a7d9008fa67650163d2b467e684da10fc7caae560f44a18e518cefe48030959808794b877cc91681ae89008e54075ae4028a03ee5402d8d4075a14f01e6b9180eb0a303e7bd180ec6d55a91c2d51b0d1d646b646c4a5a23dc79857867ac3856d3f207904b42ff4d2ee92849c4a7683f1c493d078e679b01746867faa8e4ad0addba9b75bacd4df3616b01cd3ad8646d4395642d394eb6c60ba72a54a298f53821f85ca91483e229a8a2224b53a36208a611cca560298e4276896393630a2565e59aeb5ca761b499026914258e5780446dca02f9607fd98f44b80ed5d937cfaa313a3db43f6acc6226bd98053c551167ade69318569d604a5fc62338eb84bd74147b3c649395cdd4d026eec018b246e2972ea8f96fc63c138c59a3bb7337f29c6272cf5db7e13e8c59adfbff75cec41710a8fe745f2fd3c50101c32d106139dfae501b2554f9663c10148afaa21c9f0e90b45b0c9fdd305f692e5c8d0c1e480aaead90677f340799fe228661d939b5e67a718412a4e1aa2021258784871579f11fdd04c7b9b4bde880d03b825ae95ea4b67cd683eaa559547d413989c7af72c2d39a72ea5c0e7cd3140dfb55f2ec3c92aaa65dafa5e982a35832881175355ca9c176caaca420980fdc80916d7e0a02628eaf98202d562870e05668673f111397019f05a194db5ff006fa040125c9b03ae2b4ee42c53a0636553a1d2e4ba1c5505a03e0500a73b08072155c075ec4640ee11903ec2320174e149212d0b30d0a5b21a25b4eb72ef509e35eb0e1a6d4e07804b42e10049424d8f5307e1a8092c0f1adc3a279433cd49518255212d43d96e8094ccd4ad64c30b74a8d639522c6676ae990b4b84e11630fc2e5cfd146c6146082e062a4520b89351444452d4e8da48c95aa51aea4290949f94b644ca0ab214b8cadbc83bcea779339cd94b8a424841e1e866c14c2ad965b96026c255c6c93fcc08c4d21570602dc2abb73849d91d7f1744daace5afcae6ebac091aca6ce72b675a15e9e8c0ce15e4086af8dc76498751ef366cc9d3c50164b7538e5f60b0249afe51f94684e69cbd839f2c2420305ce94f765605cad74d8404d569018b4203e8038ab05a74edb835604ccd4406e80c6789758e12ec76ca0310e37d57f4067c131b5e796b72b58ef2941167e1b5688e704f7858c7b1b43ead8cb5bd3b3c52559ad506ab635a14ab2a22f9232524e077a52d5589f979c79272a36a6d9ce727cd0aa99a8dc18ec7a260af5556ec88111768f2dca708bd38f20ee908bad1004a00e740d40150e0202eda79bb029432fe3ed217818f05ba198525261be813607084c0e46b70e7a309282cb546829854814ae0b5a0908079d16500e46cc2cf604351e83ec23d07d847b0222d96a457cd4d86821920c2d344d694702ff50b1af5268169110f44a178a6401e8f21c64251e43c817893649211946b9a9d8f915590338b05f8b5d83de553c85ed974cb720a9d81d6566c9a40ec32655e405be45b60390bd42c02db3a4c02a2ab5b805c332603d8536849db5f854a6a919aad4a9437cf444ad70c8af294a122cb41e70ca8531973b097548eb674c78229e3c9caa95274726e80d3f434231f94a54edd9e1010829f28b4132c185cf79323abc1e54dcf38d8afd3c592574cb90c7aa6d60b573f44552f14203920311630b6402a6196aa790234cdb8052bc54d63a2a201eb9ef2a45a6861016c803eacabc3765d1c9282d332b9c55295a1dba84e32a54e89d777530c25c3b8a208f3ad7eab32b893dea90ccd38e6f3f247729c0c2217ec174720f4613529ba6abe57654287a1b8415c5ccca046bb6fad73ce0652d8a45e6d34b866fd7f294545df800775a40d535e1accadd53597ea7ab323d68d405703cab7409a28b2cc14c005452729d92c20fb7cf8dcaa40931585c764509ea2a72429d36aed65847280906b35e36d5f201e89a3594b2ab23d96c6d7329894a0e43696d4274974891b0e46f4b8a1d6a3b2172248098dcba201113d4fb0ec6b939ff4da70cb85d9cff834a63b2b6c1a7846b9e8d2c2a5a571814ad02c6e13ca164d034bfd457943d4fa359888248a6ad14ec2ab19a99861ca2952d4d44a558f0e5e9df6aa73c8653ab23ce7d57473c865559687736477a2f213f6de768dca858127155aac8127048af2010d956d80fc6f50b0162653c02637acc0321725096a6912e81d4f50aa6a30cb948535f3504b1f7d42dd2e1e8e65b68182553a627195872d9026d03a9602ac0f4f0103280bf70be62e1f84a55c6ed6d2560094947cbb149283773672eeba273a643c95a1c308bce3622df4b8dd42dc31c73f653a466badae9cb2220056ba92e5690270355f9e40eb7d572aa75f34d6db30e6dd7177ca913ee80f628632a0b50d1bb099358b4744d0cce13e85c29ab811b25c3aa3c5aa6e6a72077230479aedd6770273df94c65378d03fa007a2240c5e96ca719f555802d4edfd9530a06ae2db2a7607a1b809bc5e89046f9a328073a5522f5576ec0e6ec1ba41585716b88a18f0d19ea02c4e8bb7d499200ef007f0953f4ac575c4038ede89b5494dbc83fdfc169e23cd47dd80b74e920414d08ed65acb9bb2a4624f4e5072f5450b6d251a9d2ea6adb4c411dc904ac9fe2065e9e89a2b1995b87dbe816c6d12234c4afb086d779d09d7d9580fc2161e1e49db0dcc9202a16ae880e80a7d838c7a87319ae48f5d9cc1afa99eb6c1a34bd735834b6a9b4a88250906b365b2859b408fea7aaa4a1eacd0d6d26209d3f4be50db139b523150e11a649d3c496b5e04be9d97472c6637e66e5767302b12d0808ec1aa7a224ae1e825e92cfe0a92848c56ec762bca04456c5b683aeb6a85a0a16f49a04c542b00a8e8d2e0151c5859804c54ab4242381287df4994a0f0b7a5bd330e36851adc3cea459a31d6c28804d3d3aac095a7a55605d5419080b470ea50cdba252b40ab9f232160071b76539002b9b398615e74657be88872cbd361556142ff004c44f4db6cb308a55eb4d739dd1a0dc1610c0ab280b338e765d1cf4166d336f63865eba3ae86250d4b5870d5c3d5189bb7dc43945946d753073774d88d00ea9e51b2531da1bd91da9a1d01aeb51f3465a0a2b632ca327383de95aabf14ad1cf16cb640c16e15659f6fa2b408690ffd550a8fbb3f64d81bdfc3c549f96029511ea2b1300c151b148bb17074441ee4b45653aa385f14ce25c3ff00929d4ea1ee548d8a2f963b36589f966d758f99d9ee4d8a480abeec1a37f25b8783add4e1ece608c39f8a029e112b1670a9187a9eb7eec1454ed5d2d2ed829d62dd0538e5d9216561bc77a32ec7a268bc6736da1763d02d871a685c98b4d4d40eee41ab905014255c9a90a0b69b64242634a2a08ca8f463d0d0bbb94b8ff40936f3dcba2020d31093a069cc53e49aebb65dbcb34ce5658344c12ae7b068b136127951d8ea11e408355b22f217ce125217c9ea9303d8fa3a97110f20a9a962d342774ba6c4a30234ef804dad7812f2dd974f0c67f79a7dd7a1c041416bc949d848d1d9f0579ddd6a59b438ec44ac2e3a4cabca06c7408b43aea151b43e6d0ad0263b7a6071f6e4d804535bd6e0484746a00a750ad07a0814ec030c2b9e9b0a86054661f9697c128c34ca14f18329a815604831b85704d453ec8022cc0e461295a4d0cbf66eb01a926c6cb7a01d8cc95cdd74634f600524e9b015551f31579fd30373837628c2079e9c1dc29842dd1a134a15f7ce01ec54941f8ab7b935eab71210464ae7b46266dadc27e53ab07d4f33765d12255135d56d6ae63a345573745590e84afb79ed456c576b69394e54ab552d555e0b4856903cddabe6febe3c534683902b4223aeccc85590371f87d908681dea1447afec968c31a4f9a8d522ca28f11e54a8aa5dd6f1b90029d2285ad24c47cfde9f14c67f4b2179c63aa6c1885d4ba60b86d94d80669794b19ca7c96605969c2c8ca908225484a88b80c4831de8a9b42b043f60f453a55da961c31232330e235abe614d168ac5269a18e8b62a7869f1dc98b5d1a733d883577fcaa84a90ed2594e911fe4c5ad8547a3f0b9fa58747a700ec52e3fd06e4b1ae880249a6b293a06068f4bca2fa5d18bb396181a1ca6e839fe4b21735696fd2053c8b079f4991dea93903a83481212de4349e1158cb65f551bc87aa6cadc46146c53ca7e869d4ab312b1c28857442ab231f9f3739365d120552a21c9558d944505b80ec45324e1a21dca5602a7b7e5508e436fc24a06b68d2e83828d682fe8c2e8853b0d28548628d122b444546a74c263a450b0850a449601315224c07a5a45be41ca5a547902a6816e0263a45b8040a64c0a14c97a86d3ff489241a3ed36b24ecba27217465296b7753ea07d030382cf4572588059a11d50100154d4862d0a83f5035d2720f257d2a6e9e9dd8dbcd4ab711d72037d906d647a8a77894e3bd36193da526e6ea9faed9abacd072b57275d0d314d5fba9ced9ab353c9b2bcec287a8d9273f6a2422674d529ea53c80fdeb032b308a6541e6056919b7126a031a4aa45a3cef789799c5de2ab17819d2266da6a6665212b75e03509fb7cc2911ed1b7d2910b7c8243c15535a0308f0c2cc6daa3be8b3923c4a54ed50755ef967a268de281d296968d9c3b7d55e2b56cbcd045cbb63a26ae3e942acb7b5a738dbaa9d1c8fb5f2bc9c25ab3e929c8254e802da125e0a205e281f8681e4a8176a077345e8a4caa6dea87aacf24474745e0a9203f1dbc26d3c285bf093634d8a246c078db91e83ada047a07594414f0e51a208c069d6f1dc8c07db6a08c05b6d43b93c21cff0a1dca9016db38ee4a0eb6c63b94e8131e9e1dc9a7677c74c03d89bd848d2698681d153f40b168eb135afce16fe9035eb545b2e209fa366101251b900b6b901f9df5bbaedc481c16cca690c968ed7e08b06886dbd2e0d2cd2a9d07a3a1f049683ceb72c0547409a5073fc3cabc4ca8687c150c24db90d94e476f53a616ca05b631f0a053b01c6d02cc078d026c0547428f20a6d1acc02a2a34b805b6deb01d342abd42ebb0d0e52483571d376b6b46f85d520d7dac26019f6fe14ba83513a4e425bbaf374c967b0929e501e4a0dd520455eed808fc2a40a351694c4dcdeab3598b5b323fb2d683adb61394d02877ad2e39b2574486d3f66b2f2ae5ea25a9e91d9185cdd72cd53eeb70e4914fc8d592c77cce15241ab132d81fb9f35d321835c006744f200ce8c3c22c622aeb6d6b2327cd4e8c796b8d17c3fa7cd5617590d23f230ab0f3a3e5898de8cb59ba466bd2bc00a1c341f2526bd554f77c4606dd31dc91a06e12e5a7084ef48cb5bce0edde9710bdb3abf102527cd3c7570839af65a761b278ad2e7d404b56b9ba055f584b3a251c91a3ea4b5c4159545e21a66b94e8224b7e1c36440b0d15b7654ff008163a2d861439fe911973a2caebe7925086dfe09ba9823915095cbd539e16f51f34e6bfc2d1e68106913e075b428c0e3a89530e5368918054767db38460220a3df08c0705124842c51270799469a812ca64940ba7a4ca9e1c5328fc12d8065352654f4266db4e01e8b3d05eaceed95f0276986c8c036328c05828c0fcf361e72bb6d4935416cc25d224e3a246b34a14898de8e328573d8a096512507d94c8901d8a9952402a2b667aaac49c7db7c13c310ea045688868ca43086d32d05b69025077e88224077e8c2ac8087d320122914e83f4f46a6060a353d075b4aa9d745c2d94c96518e55b9c175f34624a9298b9b83f9dd2f746272dd6d0d0bcbf260b74aa0d4f2046b6ec08c27803d5372152044b28f75986c1d1d3a629eaca7c057e429d72a6df2accd43cafe559784c3c956a7f98562e76f73dc96fcc2534ed99cd29670177a4a82364fe4e88d4b4e719f546040db35272b80494604d71772e8dc41ec52adc791b5edd79e4737d15622ac5233a0558c1a026347d4341977aa43c8f5d7c3fd9bfa5e8b9ced76a2c8e78c04d026edb6de467dde5bad47a45deab035a797c50e6b1856acbee243eab6bb38a02db373a4ae8481a1588530c6fdd8f44cde45cf438dfd515a76cb79c3b054e85c296a0170f4440b53d9f6854ff8045134a84985b0fcb4b9579de12c35f4a9af7a243d1c0a5669e425d4d9549c99d144b7c827e9534e00982953780e4f40a272451234256067d98468082851a0fb28173c23efa05580e328538131db52019052e1530e7c5324b00ba7a552bc849d353a4f0163b6929f02c346c4601ec6a301cf965181e0bb25a775d3ae75a9b43b29dac3d152a2529c6d0aac614da152749e6d12cc0799469e40220a154c02d8c4b114ed8edad7754ed582f5a5e26b3231d3286a8d2d28ec494ce7d215a677e414a0b0c29a50204055650e7d32d05369143a0261a651a04fd3a8da0e36996f54cf994cb39a30afa0df75ddcd1894b5d38ce12f5462c8db728e31157cb3b485981566d9f0ef0431235348005a15db8d4b58ab870f6db9b5c5661713f7183ed4fc97556b852ecaf0aa8dca2dd5f5a4c5419080fa4a00ddd4faa0e50d7051d0664ae21e9824ae2e2e6fa20332b9523c4beea54e1ae1583e43f98f610a54cf2c6a98ff00ace3e24a788588967505561048ce53362734690e9307bc048bc7b53835401b1e07705cec695038b4a680abbd4111125692c65b74bdf36479854912b199de6d9cef2b29b8376f8f93fb28575ac94ef05621d106906533791791d1356876da067214e84dda5a4382205fe9865a15204851c693a87c14602b93aeb09613f48b79eb4485368977727c39f4785be8a71b4a8f40dfd22b4e80986956de81668d71699d75bd00914d8d900e8a6468151c0a508fbe42ac05081501d6a01f8a359e8e2a18167a03a3a54ba1214b4c8099a08374058e9e90e160194d4c500618901e2ba6b761248e3891644ba398ac3b0c5e09eb70f32052b41e8e953489413152aac8bc3a2913f950f4546b3c821f445616a4edc31fdd0e6a94abaee66fe14fae8dca124b7a87a74c25b0aebc4cb14c9b0f0e0a4596329c6d2a95842cd2653eb6d2e1b724a9e96da34834fc748970cfbe9f0b35a5b234346c70a0da7a8e98872632c146f5b405bdc248d94a809496ec049022eef06552050f535bcb9b8f4f15d738302d2fa74b77dd5a704abf549fb3a2dbca355ab84396a9589a83a8a7e4382adad944d25c00624d5253353505e3014eab287a2b6f29cfaa4b14d88aacae024c78abf04b563a190e16f44d435e28327dd72f4dd675ab28086bb09b8a679cf514397b9248444b28fa2ac021b110309a9d31c2fb3992a71e214e99eefe1e59fe5c7e380951c5c2067695a315cd5d78c34b41f05b8cc650603927bcadc186248429d8646cd6ccefeaa1600ecaeecf44fc8485330b975403e8e84a9587a96829f1fdd46a568475df12018ed5858d1686ac72027c136292ac16d839825d36a5be8f0120d71b4ab3069e6d0acc1a4be9d6f5d1b5c651e524ec69468576f3d8d29b48a7df634b11a485a223895a254992853510cb2970a78a43cd895698b11a8d6694d892429e6522629e6d3a2985c548b9a81d494c9b93a5a3a75d5c849dbe2c14d42c94cfc84806b7a29f40a8d99520f1db291774e5cb0432915672ac83a0a553e8d60a8e93c173744a79b6e5bcf448f9b46ba79e9787be995e531c642b49694ea752aca53202a752a7e266173f6d825f0821736ff5d100490e17a33a23e63537a521f8e1597a616e894af49d2238d2ea769f620969c0c58253f1b16ab0b7d3ae7d361831e13cad174a130194b54329cda9a800c6cb68d3cea5c852a34154c180b1a86aaa6e61b2a40889b4e9cefbaec9d03f0d2869c613fa25172d1f38c053bda7d216ed60700a57b4d956b4b1389ca6f4e7f462db42790028d525490918d385ab4e89ae38195b87d515f6973a50ef1cab724f4bd414ff00681e0b7a83425551670b8fa3caaa6a9b70f96eedc821673558f2a6b0b039923bae324aae151b474b9032981f9e93759ad695c1dd3dcb387f88296c33da7a51a1c063a60050d662475f34470e5bd53c18c1ae97c25e412af235da195b8394f8107718ce7c165e486e493231e8a16041ba8883f953816ab453eca9285828e913516953b14ac4ad071db87383d7b56616559e5aafb001e0b4f175d1a3217369b568ab6ec986858e35b8344b189b06be30ae5e9ba5c71614e41a4b98baf983491124ea0d7ce895e469f8235428b99e3099901f2129714857cb596b75f08d252950c6a7024228d314e361594c2e28d4a81f0c2b61c744174403e06a5d094a02809d73764b4154e764a1e65a6a06677217a3239a0a6d3439ddc1524560ea7a087b1c3dd4ba863efa28c7685c9d42d853608c76ae6909044b47163a85d3ca863e923ef57d35226a767614fa99b6c6cef542e888a2677a5b063afa6677ae7bc1e43f0d137bd42fcda6aaad8d4d8c94c8b6a7c3e9f16d48348fa24989da75b6c3d815bca7871b6a3dcb70a5c76d3dc8c3c873fc38f721591c34aeee52f26c366de7b91e4a31b42309b004fa3df64684bd21c2d2a518f486057176dba68740415cccf5dd3c81391b399a93d276a0af74182b3d12d44dbef059d7bd26b29eaed4cc73bf504c9e2b77fa66bc65bbf6ab48e7c55edf0fdd83df84f22921bbf5947383e49e45a43925bb99a004c7c330d9b0567345830d22ada9d84980ae6a68afdf6cb9ea9f9e549590711f44f334e078aae198e4d662cfb4848031841737cd207a47845a4439ad3e4866bd1d64b47ca6fb28f96ea0789179063c67754906b06b80697124ab41a76d73039c2a68d48410871c7a29da03d7dac30eca5403a88c614a81f6c760250b0d0cd956d160d92849496a561a8e9404bacc465f2a1cde8b4cb8f0f2f6e7601f00a186c6ab554db05b06130d126830afa44da31cf92b7ae03bf294bc074d2aeb9c829b0f7a8f5038e8d2b61d8e996698e1a44f28a41a44e9d2db4aa5acd3aca34d0c532896018234862a087753d02638f74604a454e9e1c4b69c2d02983014f409b657301fbce11a138cbb43ff00302781f4b758bf984d43f392e7c7468e8576ca84542af8ec79b671f7578ac1349f115cbd5c52750c3cfc51b476a85e4ae33e2a1bd32a73e64759f13c3f92b4e1482d9f138d3da9fc145d37c4d33b4acf29d2aa7e25d83b55180c7c50b3bd361c447f142cef59619254ff0016718ed53bcc2da3a0f8b384f6a59c25a259f175004de1494543f1890744b7e62d111fc57c1e0a7e0898b6fc5741e0abe544c1f89d80f724b0b83697e2769fb70a76292245bf1274e7b922d23aef88084f72af9219771c223dc92c2e2dda2f528a9dc7e12316efa0df0a69dafa4a6c2704b254a657f5256fd8405b21e33181ef0fce4e32ad21db469e87fa40f8051bcb98d5d63cff00e7459e433ed5d6ddb62a9382d64af824336398f5c2e9e7e61a35be98c4c25ffc73ba3ca78cd2bb892c6ce478adc3c89aa7d522658b489ab3bf74b54913150d0a1cd3d886adbb86ff0065d1a85892b6e1dfdd2a24dd2d3cdd174f10cacea2d340b7a2dab303e2268e232e03bca850ce74f595cf91bb76e3f2a509af6770934a96c6ddbb02a42b49bf48238cefd88c6bcf5aa2fbcd211938dd0148bc5bdc41210cd2f47c47041f2468d59a8ede79f650d541dfe721d8298687fa62424a1314d4dcaccfaacc090d2ff76e98f5659e71d3b54ea5600f944b92b0fddac79684da6c48e8fa7e57b7cc230ed958ec81e4b303ac8965186dcc5831c91aafd745258d52f404c0cc75579d072a62ca9754076d324a4946c0c52b5587084d2b29b30e55e54e96da652d29d6c4ab0da762622b4b6c2a56985430a983cc8b74e0646131c4080a5a1f4d0150d0c878a5a8dd1fe9246ea902954fae6423a9f75480fc5c43783d4a6a1e2dacb565744e91910b35895a556077e9e053eb2859348e7b12d25a43b4901d89617413ac18ef5d106971da31de8ac75f6f3dcb9ed0e3ad27c56e9e102c8974c50b3f9a352a16a2d7e6b352a027a1776655f46142deef14ba0ec36c778acb54892a581de292ad2a4a10477a7e624285c9c3bd6d877c2eef1deb9ab75f1d5720ef57e4de8edbb59cc4f6a7a4d4a506b19b9fb573f4dd7b83e112bcc8c3cca158f4556c40138590b88ea998615b588d8e2dd2854f524b87e0ab72a681b750b5cefcae88d699658b0c0b92c411f79c0e62a5796328d75a90346329e40aae9980be50ff0010af205938835e1b1e3c30aac8f3ccf64e79f9bc50a468ba5ec81a10b45ca8e3012e2905ba7cae7c65aa96a1a37177a842156db2c0433d026d644952b095be8f1f5c6d80b53de8453753688123318ec2a56a9157d1bc23687e71db9e8889f4dd6df45f261f4558e7ac8f885ae1dcd81d3a24c74466f3e5c7992e0ea3e9c7d84231c3d17a6e8f194ade526face539528bde5d969c49babc4acaeba980578d821919215362b28ab4c3c992a35a1ed950f7cdeaa3605fa9ed982a3793a4a5a51852bc81d64b30e60423962f74f4fb7fe6cbb798346c74e4f62ad8d95daca1dc29d8aca1e4a153bcb35c6d1a85e4ba50a728919a51a72ba212d7df4c4a9d8e7e7fd3eca3293cbb7920d2145374762a6295c7d1f6d2f82e78c7cda7f05d5cd3c13051f82ceeaf0e7d1f82e1a72e180f72e8863ec853e14ec2cf0458d8358dc762958dd7c7c4ad909ac9b8af636bd5e42aab67d1edc6e8bc849b742c6a17934af23c9a549ec56959811fa34f72e9e69881a44f72aca9d2c695f04c85a06af4b1ee4919a8f9349f82bc1a6ce953dc8ad3474bf82850259a40a55a14745a5d31aa8d284762349403b4993d8b35139fe47dfa7e137a5ef279fa1f6e8b751a6e3d12426d6be1a471d8b5ba51d30baa4508ff002a159d42112e942b92c66a3a7d309f92e9fb758b07a7e13d2ea5469c237f55cfd1e57ae7e102a791a72a1557a2ae553cc4e1646e058e9d3ea621b4f8fc95a18ceb7be1f9f8f1c2b4026d757820f92b4add5e65d5219103e0b308add4eb2e76b92f96319e2154b89ed4de42ebc2fa2260e63e0a92046f14a5d8256a9b65b6e483fdd0a45f6df6fc041e0f968364d87d3504679946c73de86d4db01531a9ba1a21c8a569a43f152003b14fd291dc653fa617f4e30b75a95b2da1a46400a90955de245786c440383baac4abceb5f525e727bca314e68274b858a53a25ca471d893a26a5b14e793355445c70a2eabcbea4fb0f2aa6a5794fd2dbc382d9d249086d7b26f65b43d4c18384dad1562a1e57732dc0b73660567938a6d1e5378093b9dc3e9a9cc87b06546718183567c6008de5b8e8485d13f89da9bb17c5f31ee0a963652f517c5e318f0a78b4a061f8c2614f792e9c8fe2f99e0a17965a96a5f8ad8dc3b12f92e9cffdceb3c3dd361752145f12b19ed1eeb307313149f1171778f74b8eae47c7c7788f6b7dd2f93f4259c6b8fbc7b84b7972d890a5e2f447f7b7dc249f3262463e25c47f7b7dc2bcf9a912749c4188fef6ff00fb059dfcd5e5231eb68bf9b7dc2e5bf33a529b51c27f7b7dc2242ea420ad88ff00c46fb85590c95a7319fdedf70b31944b9b19fdedf709719ae8a38ff937dc2d9c97545d6744d3dc7d72af396ab3146a9e4d60ea78bbd4ef2552e7e10f2fea6fe142424a85afe1fb7b1aaf2292ab75fa271d89d346cda3fc16e92c0355a23c12c4c13f45abf2dc32ed1be0b69b1f3743f82856e088f461ee48786dfa3cf7214865fa28f72dc61ea4d11e0b7134bc9a1463a7e11e56aeb7406dd118850953a177e8b0a1e7d0db744d28c0afd0fe1f85d7cf4abe8f47f823aa431368bdba2e4662324d15e0afc171d8f446fd12da3c8d97486dd1429f1a3f07e2309f5f252a791e87b554f38ca21e24e34ba5c2eb66fb55792e320d791306647636c9576622387f726cc481d8b7462e97db3b8b3184f2b15fa1b1b80dc279422ebb4b871e9feab42d56ea06c34ceffe90190eafbb891d8ee290266ca19cace99c20d8faeb5441fb539df58ee2ee6fb933756c867692a7639d20f7b70a5793c22a2af0147a86439ba927af6a9791ab3407edfcac90c5d5b4f27bab484234cdd486bb27bd3e1595ebdbf9748e1e24234ea7474e309f59ca3eaa97052eab40b26dd4ad73f94dd1b526adc7220b92ace6c56cacc1f6e97758874b950c396adc73d0d5f458dd5e1e444dc24e56e4276e1db1cee72a9b178b5e531b1de27c05d6f781d794ff00652c2d8fce6bde8f95d3bf19fd456ea55ca4d253b77dd6eb1dafd2d50eec3fdd2e9914ed27500f42ac70f51a62a73b02b30a1dba7ab074e659e5859b6567ff00259857cda1adcedcdf9523c85c74b5e0e7eff7296af0609ae0ded77b94535111dd6bfbdfee562760865cee037cbfdcaea9ca584546b7af6ed97fb954c31307126bc1fd6ff72b2c38a6f186b81ff78ef72a1d72795214bc71ae1ff11dee570b12d43c7fad1ff11dee53f30eb75a3e23eabb6477b94d8ceaadb6ff00882a83ff0011dffec5679735e973b171de7271ce7dd104ad334feb77483249f52af1d117cb24dcc56da64fcb0e146f49d4edc2f25fd42d91c92ab35d177054917950f3db01ec4b5532cd3a3b94ed658e546996e3b1372e7c453b4d8cabf262dba4dab2ab23aed320285361bff2fb5310f41a55a50a472a34b8f04f8da1e2d36d4d89a463b0e7b13e368e8eca31d14ec2547d669f19e8a35869da6c77295a7c34fd2ed3d8afcf440926986854b4e5bb4b354b5b81c68f6f705d5c1b0e43a31aa16b7c9e9347b7c14e8c1b66d261a52566341b1d360218b33291422981aed0602e8e4b8ce7516986cd961ed562e24f86fc2a645923cd2eb3173bada801d112a6af494015e508b82df9774ef5b680fada9f9699fe4527a0f355ace64703bee56c6e2df414b800aa432424873d1383905061318750b7753a8ac51c408598a18ac876c29d85afad964077f549e50b53534586a491d466ff0056590e7c0955912b59d69ed4ee7970ecdc22c3440ea88f72542ab8ac534872a89f2fae8ed94ad56a1a18fee52b53ab25bdaa76ba383d3302d4f4cb624edd1d6e3ba72d5bed732791cd5cd4152709e2d22ab45585eee43e498d8b65bade18404da6c5c69a970329a56c81eff525f1161e8765b612b2d8384cc2e2e38dce54ad46c5860e0ac65bd8974a360e04465bd02cd384aae03c5dc15274645ffe8a47cd8c05594a926702620de83bd50b62b757c1c8f9ba04307d0f02e2233b2e55647d59c178c7604b4e8e7707a33dcb0e92b4701a23dc9598b2d17c39c2e38d974fb46c01a93e15e1033b74256fb6321bd702a3693b0ed096f6753ee1c19603d8a77b015dc1d8d72b25465670ad815b95619a3e19b72aa4e965a1e1bb425ae3e9a4693e1633ae7c5246f35a858b4a06ec0f44f1d7cb43d3f0f290a7d55716d2de65cdd74874ffd9	image/jpeg	2025-08-17 06:46:07.96047+00
878bf420-aa3d-4c0d-b3a2-15c68a5bce14	2025-08-15 17:09:07.798147+00	IMG_20160220_080208.jpg	\\xffd8ffe000104a46494600010100000100010000ffe1006045786966000049492a0008000000020031010200070000002600000069870400010000002e00000000000000476f6f676c650000030000900700040000003032323002a00400010000008002000003a00400010000008002000000000000ffdb0084000302020a0a080909090908080808080705070707080707070707070707070707070707070707070707070707070a0707070809090907070b0d0a080d070809080103040406050607050508080707070808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808ffc00011080280028003011100021101031101ffc4001d000001050101010100000000000000000004020305060701080009ffc40041100001030302030605030203070403010001000203040511062107123141516171819108131422a132425223b11516c124334353d1e1f0171862f17292a234ffc4001a010003010101010000000000000000000000020301040506ffc4001d110101010101010101010100000000000000011102120313213141ffda000c03010002110311003f00f075c0ecbb27d5cd19b5f5879d5a75aac0d6f67de3cd6f9d6b79d3370c42078612df96944492e556d6c5535c1fb173f5558c8ab7aae7ad0d953c2ba4abc1a91b533ee0a85ad2ad148795356526eb09c2997141bc52ab190a46125090b715b0a90aa9b64f0216690953abbac8542b4fb9984ba4072bd1a53699b5f2d2be48d8f925aa47c920af974c4eba56d6470a8d6c702dd69e821caa462c364d2ae791857e631ade9ab3163402ab8123596fe6c612617d2eda46ec22c7324c3cab2d7ea1129d94ec5251f6da62370a7629a124b981284be53d5eacfad5b1e3d16e335b5e8dd78c90068f04d06b402490309b46809a7e5eab11206a803b52e03753aa1bba5c087a0be87bd2e05ea8a220672b4c16e3790ded4c0dc1a832374e0937a19403725c477a7a6d485bea8386173d8d1bf2d248dd74054863f12e9d23a42cd0fb0974057c6b34019a6c25b5b4f534b9532d3e254dc9709734ab4a30cc814804a858098a2db29404966394022429e1a81aa8709e2743b58b68890a40a754829c51ad391b9668333200474480fbe94a9fa0ec16b2b7d816cb794f3a07e1a229bd014290add0721a72100e1725a427e5a850fc7bb8c9b2de62319edda225e57672ac72db4879975f2d68d66ae21b856d2a7e0a9cae1b5915ed672fdaa16ab195563b74ad33ca9e465a516264f47da9ff0070f454868d4a867019e812b622ebeb8153362b37572be9105346a740cb7d2a7853971d82708931a8d54d35c54287ce9c953d04828d2d713cadaf9395f2cb1b1f295523e4bc8af974c4eba5356470a956c3d4ac19dd205b6df491819d95f960db5def95d86aeae605aa93519ed2ba700a7ea5206cb9ec7268fb6dedce233f84a79d2f9a6c38919598b4ad269f019bf729e292aa95920f9a3cd6f926a46bc671e8b306b41e145c9df35a3b32025c1af50c2f386f925c1aaeeae710d2563583ea3d7ae8dc46536019a5b5cba638cf86dba30349d2f4443b27cd6f9094d4fc416c23979b7e9d54829d4dad5d2bb00ecb427a8ee6ece16826eda83e58dfcfb90158ff00d4e6f36323bbaa70d1b476a86bbb54ec36af74b7169ed498d3f1b8158dd1102aeb0ef2a5d0eb6059a0d38a5d08bb84286d441b872a0b48ff001c6f7ad8cc4d5b2a4395060a95bb24601f9192806e60404a1125dba01e0e5b29a932ee9e54e87f91badb4414d894ea91ce650f4d7dce9e50f98c4f01c2dc2a0243947c8122a301679075932dc07626ac0948a34f283332a40064724a40efacc2850fc7d9e6d97abe1188d65b438ee92c560e75a5ade8b3d344dbdbba6f54a97150930b105ac24fb12e2b2b35785b218b6b15672424bd4f0b897b0d2ee9cd177f983954eb621aa0a9536a12f332ae9105f352e84f5b2e781854853556de6395480453da3214ec6ea36e96fe55cdd4322d4eb1f2c3be053c653802e89c92be7316de4d0da85e4f1f3d246d7caf13a5393566124a95363ac7ee920a2fea4e15a528bb453973b6cae89d068f67d2ce2cc905567402dd290b0a5d71d8374d5c70e469e46bda6ef236f458ae2cf7ed481b1841e403628be6efea9758b6beca39774ba04694d4ad82504ed82943d0ba5389ec9001cc3b92e05a2b256c8cfd43b516298f28f1c6d01ae7969ef2b60c56f80b75c38e7bcf5dd1a31e84aee25b636751d3c9668c79ab89fc55324e3076cf7acc2ae1a175a0e5183bede6b302f6de21e0819580f5eaf827675ec280c21b5ee1565a49eb8f04ecd6f3a26e84306e83342b6eadc6d952add68365bb7337aa9d6a7a0a94d80632a877ac016e1790ded4800525d038aca045605b29141d57363b70a902a14375cbc79ad3b54d36ed90130e910438c4022ae9414a1132dbc200574184b29a9c8c27953a70c68b447ce729daa436c87293cb45b68b09e4044f2613c08b9abb75480c9ae5d1e01b65c52f9091a3a9ca4b027e89a128395156028007515e1500092bd6520296a32a5607e40d7d4602f4af68c57ea2f841d94ef4ac7d497c713b9449ad5a2db2e42e89c112464d9161159d555f96e14ac562a14ecc95b1a92a8a4c0552a35cddd455c1b6fabe5282d5823bd0c29d650b59730a54ba80acabcad30459a0fc2f56e4a3229d5a0582dd5bb22c002f6dc85cfd46eabce5cf5a68a58728054e594e02bbb9847ce72de8d082b97a3c71463694d0af2275d21358c24b54ac3694d1ba41560b6d8cb87a26855c340d8407fdc3b56ca1e87a2b1c7f4fd06709a741906b2b26e4f9ab6a162a36f8487add3c8d274dcf823d162b226b574a5d18c78214c4d68485c1b93e0b9f535a6f37e218b758cb2f37a91cefb5502634adeea5876271b1f45b81b0db78b6e8da399c7a63aa7c3b32d7dc4412b9dbf78496007c39bb868246dd4a8506b5a6b179c804a9e864575b9b9cff0015d3a469bc2b8e42edf3858123aab5418e5232902e9c38d5e1f19c9f040415eda3e7b9fea9cabb694d4d860dd3c8d59ad1a8399dd54ac6b55d25a93a0cf828536b427ea10d6ee53b552bef129b18ce566053ddc618e590007aedd52869765ac2581c3c0a507ebb50868dca589b17e26ebe00ec7b405687891e1c37e6381f23e0b5add28e1e5014f41c95ca843d4cf403f348942366a90b1a1f3948da4393c4e92f722881a77a45209b2bf757c6ac1708b6f459814faf714044e4e568395270175de82126bae0a95e825ad17c054af4168a6b9052d06eaaa495a11b53545520464b31414f5364a5c0fc82bad6e42e9c262b529dd186826ddd55205d6dcfd8268cd193cb8589456aed117245623e1a100e56ca7afab6afb13fa282a2a6e67296a953125a804690cb29116260ab1b84b8547b9eb6c54852b1a5028918229d56407bea085ba4c2a5ba128c38190e547ae4e6d43cb75d055a44dde65581c494e4f328d0ef3a2740b6b976f1d03ec00955bd10f4d4580a37a00f385cbad685a42a872efdc9a562c96daae539f15a1a95835502c033e09a0466b0735c3623bd5a159abdc1ae4c6895b75ec732c6c59e7bb07347a25c32c767d43cacc24ee11f4f5664e9ba8045cf6f2ddf1e2af01ea4d45cac20a2803477a648e2d2efcaaf3d155fbd5334388072a9ec1ca2bb066c14baea0037dba13d171f5d052e8642e9dad2081cc3fba7867abf4fd1c7140d7733412df0cf45790314d615625ab6b33d4e3f28b035bd1da65b1464f86542867fad75372c8e195d7c9c0d935d60019560bfe94d6049eab9be908d4ac3ab7977cf8ae0ebfd09abd7133ed1bf82ae319d714f567fb3f303d8518d63fc3ed667e73727f77faacb03db566d70d14ecfbbf68feca560572f3ad727395d3e4acc359bbe6bc11de16f90daf850435807801e2929f96c50566c146aa4cd581610cb6f40260323b9023aad68679194cd2e36acf2992e0a9396104a2f209306525e41fa58f9565a749b6b063aa4b4216e0012b2508c95cd0552504cbc84750acdb555bb5002762b52a6ad56f20ec13162eb6e1b745aac18fee52a527e9814b4e04d164a958d1b0d1e14ec33f186b6c4f1d87d97a984c4449404761f64616b94cd20f43ec884a9fa6b96076ad89da285f426a6862a6f2deefc2855623a6b9b526b6a365a846947592601e97554a5d65c9d95212806caa912a6a68f3d87d95312d066dceee3ec931d0229ac2e3d87d92e01c347bfb8fb23009a7d2ee1d87d96e049c5a60b863073e4a601d4680901ce0fb2708a934cbc761f64f26870e997f71f6597e6cd3b1e917f71f64b8d3cdd0ef3d87d92d80e3b4049dc7d9258730ed0f2771f651a035469578ec3eca7200adb2bbb8fb2e9e40ea4b23bae0fb2a11222d0e3d87d926046cd62773743ecb3c85b34d69590f61f64de42cffe577e3b51e41a30c918ed4fe402abbdbfb72a8503302e19c1f64ba680d91381fddec99b1294d737631bfb2dc32d7a7daf76dbefe08ee11aa697d345a3272572602b50db48076fc2bc8194ea1b810d2003da3a24e8331fa895b21239bbfa14b1985b752bc1cbb9bd8a6a30fc7ab37e87d94fa6e2cfa46abe73b041f65cf60c4bea8b508dc1c1bbec7a2e9e4236efc447b5a012ec018db2af02a16ed5c7ea1b23b3b1ca286c51f1d99f2cb7c395428641ab7597cc7b9c33deafc840535f5c307255c2f3a73881c9b9ca9fd0ebd51718da02f3fa808afe28f3e304aac8cc07ab75e73c1cb9ced85490aceac37ce47876fd72b2c0f41697e2797b5adc9e8029581a2439745cd9f15d985576aafe18edd1e4350e18f11585ed1e4143ae4dcb739f50038c63a2e7b1501597527b526268b37229987a9b511083a66dfa8414cdd4e4758a9290b8ea32a92b0e162db41265c29da01d75d94ef27467f8d9497900ab7530016ce02b773d5991b2a4e021edfa81c4f556c2a5a96e1976e561178b0dd1819b8094c557ea5630676ef4ba755e6e2930bf9463b94c8b1d96ebcdbf7f6268749452ee8c0918deb3cb7583d5fc3cdbdfd31ecbb45a83aef85ea23d31ec9748af5d3e15a9b1f68fff0095ba9a8b76f86600fdac38ff00f12974962ad71f86a931f6c6ef62a9559157acf879a80768ddec54a9953bcf02ea5a73f25dec54f18ac4fc2da907fdd11ee8c26827e899d8725852629e9d834ecce3fa0f72ac8cd6b9c3ee09492639d871b1e8af198f4069cf86aa72dfbda01f254d2f959a83e18a93b87b05cfe8e97a6f86aa31d83d96e81e3e1e68bc3f08d0625f876a4ee1ec12fa0669fe1fe941ecf6532ea566e035211d89f5ba11bf0e3467b07b055e7a61c1f0df45e1ec1574127e1ea8c777b050b4c73ff6fb483f8fe14ef40ccdc07a53dc90e4ff00edf697b71f846024fc3ad19ec6fb2d901327c32d0f70f60a900777c37d1f70f60b48763f873a3ee6a00e3f0cb45e1dfd8aa0c0e055333a009bf80f8e0e53f705a0453700695dfa804d81da8f862a171db1f85c9694b3f0cf4606c1beca7a68647c33519ec1ec134ad8ec1f0c5459e8df60af299314dc00a467e9c7e14fe9d1126ce19c23a0185cf287dffa4d049b103b974c069df0cf46eebcbec1275003aaf851a03d037d82af9362bf59f083467a01ecb70622ddf08349fc47b24bcb30f51fc30c10eec68efe8a779181ef5c01649d5bf8472652ebfe169aefd9f856e4aafd7fc27e3a47f8474c454df0b0fec88fb28d2a22b3e15261ff0004fb23908fff00dad4dff24fb15d30c4c9f0c338ff00827d92f47047e1b6a47fc177b15c7d43a4283e1e6a7fe4bbd8a7958e56fc3d54ff00c977b1548ca062f86faaff0092ef62b534ed8f81b56cff0082eefe85206916fd1358198313ba63b55f5b555d4bc30ac3b889dec56e901e9fd0b5f1bc16c4ff0062a561a36dd1f4b58701ec70e837cf450b146c36cb092ddc7ff6952d3b3e9338e894c8d9748bfb90dd269ac0f1d852b52b152c98e8512a48ab87ce69d8154802d35cea33b828b42769e4908dd4f40c6da4b82ead3e81b859c80b06aa175b53c9d82783509358df9dc2a60d464d6b7b4a86a528fa173bb51aac1f25d9c1a708c3317e2a712a68d840cf723c852f446b49247b4bb3d428607a9b465f766efd813c845fe0add93e34a6d7a62ebc1b6ef8c070ed4da353907c681f0f64ac4edb7e32b3d83d92e993b4ff00172d3fb5bec12eb313945f14cc7750cf60ba4c95a7e3a44ffe1ec129854face191bfb37f24484a8796c70c9b82cf4c27c42a0ee1c2f6487000f6d94f04a32c7c006839dbb1dd3aa6c56356b36996c63f4376007b265528294776136b458870b83d7f53225a725525065949bacb40d7d3eca7e8191480a673ebb252a5d3ca64469f9e8e58873daba3d2923868973de8a53a1496834da5c278738f8f2af2036232b9fd02dd1a3d834ea528f642e38552740506ecb3d83269094d3b02e9687bd37e806cb6ddb65bfa0269e970a569471a7d942d34365a3a27e6b610ea65d5c99c8e15cfdf4416ca451941f828f0bb79a04ba354b015153f9a2f4716d8125e81e6c63b96fa0e88b1fb4146871d103fb429c3098a95bfc42b429dfa669fda3d9152114d46cfe23d9429470b6b0fec6fb2594c0aaa8e31fb07b2e9e69813db1ff06fb05b4e57d233f837d82e6e8c6e3a467f06fb0490d0a6d3b3f837d95a52d2853b3fe5b7d82dd257cca567f06fb04ba42ffc2d87f6b7d91e940b3d9987f6b4fa04f3a4e8ba6b133f837d826b443e74c346f803d14ee1dd65940e814aa6219681dc95bae4b403b82568416a04f4094da78d90772ace5307258013d13ce5864e8e1dcb6f2d1d0e8f0a7790908f4a86850f69ea26bac60f62cbf41a8f1a587727e7e8351b5ba3c13b0579f41a15dc3a0eff00ce8a5e9911770e1863a2795d1cb3ed5760f940f5ed57d52bcb9c56909c8f1544e83d016cd810a1866f5a66a7900c94611a1dbaf1908d66897dd96695f9024abd87d7cd970a560d154b3bd2e0d4836797b329b06b8ebd4cde8e2b6961f66b5a86fee2a75482e9789756486890fe56c2d6cfc297d7ccf1891d8d8f6f4558957b33445b5cd887cceb81d7ae564245ba1aa68d8278b7253eac2cab429954d50b1a5cd581470a68d6a6c0e7d5adc2d2db5e8f29d205d06518961f96e4dc24c6e18756356c8b4346ecd4e78eb2e80a8e14a75684f203ad972abcc07c46aa1f3e9d70d81f369d2e03e29d1203ada455903a69c279014da609b03e898729684c178c24009ad5d93905aace41223dd6d02042a543e8e9d705871f1c69701f6b557980a11ae980e08b649533c19b295a787226a7e68a7a38575f3d2673e9571ded52db0159e93ae8a7dd46f4c83e2e892f4a417054b427f2d05739414d948890c0b7facc381a16330eb181668c3b0c012d69c3184ba77236846b5f7d38580e32008ca0630808ca0b8e5ca3cd0f9ce0027ca449c758ce44d810f23c14fe412c980460745582afe5cd894b75bf9934e5b8ed480d3ca9f15c7df34745986c74bd7175ca388faa897275cb7086c096436189215d11b82194f84406e5a5caac3a95af747f342f70df6255a1de09e25da4899c08ed3fdd3cad1ba36de00d93da8b40a11851a64dd25510a5632b93dcdd9eaa76215f9a505a0bbbd7ad629a21d612146c1a47d38695b8347b6b400b706a2aaeaf3d029d34114560964e8d77a0ca9d52379e167008bf95cf61ec3b84d0b5eaad19c376d3005addf0ad12abcb657118c2524131c250b72e7c839596aa94a1a4ef53acb5daea008c6680fa74b8348740a920af853a7913a6df4e9ef050ef88a85e4d84f292a6724d11402994e42cc0fa2ce53c813d6f8156409486996d07a48d72d80db589703a4a6901f8a3569015f296e03cc8826c0f9d0acbc874b52790e08576603f1b12e82db129de80c6c2a5682c51a3c83e29d6780f8429f0e229e9d301420d94ea67852ecb9fa3c2e9edcb2528a6d0615bd26efc95cea9c6316e11c7469bc086048b3c290dc8485d7e4a6dccca3c9ca6d2a958dc3cda40a74d823fc394dbe5d7d2e1379679760a3042df2534694028f252db1a9e345c54c1524075d43b279c840d7d596154f2013aeee28f2471f5ee5be412db9b9379071b584a301c15042a33c8d66a97302686f259b973fddea9f0f85b6ad661b0ec5725cdd72863e92b572f5cb70d3ab5471b818d7a68dc2a4bba6c4df495fb26307a9b97344e69ed04278d796b8adc3f05ce7f792551aa559ad6d6059a9ac14f167a2c32469a87256e3282bb43ca51e53b1e05a7b935bd8ba75b86ee1a9187b3fecb3462ab71b8646c56eb7008909381929a518d43869c1a92a8b4807190b2c347b3b85df0d0210d73da3b0ee32a561e372b7e968a36ecd1ddd3082d154b6b1d89b52a79b664b6a70432d4a77a5e10eb4a4f46205bd369440b4e55cbafa5b429da67ccb327941dff00070ab0c69f6455b59819f67f05cfd34eb6cc3b944112da425c06859530391d9c2603a2b726078d3a6d0e0a75cb4ee3a95640e1a354e603aca557c070d029c210ca7215603c625a1f1a7480b8a956dec1e753a95ec162349e8096c590b00c8a997427af9d1a631e8a049a674c096f47131d2e548894a5b66375961c53d812612877b02c4698918a921f5d8a25485373054c3c3216ab0a744b7d15f32353d31c8e249add3b4f4bba536a51ef49393ea3ea0655a725d721722b0ffcbca85a5c21d4e9631c6b53ca06c2e549422ae76fe629fd009fe069b416fb22df408658967a0f9f66297d07ccb4154d6e9c92ca5368d3915a485ba6d75f6d29f59a48b490a36a3a6dd6e254698d4d6d728e18c8b5b8ac048b4b9611d7db5c9b0a685bc91baa0513887a48c8dd876656c2ebcb1aaab0c13729db7c2dc2ca98d3f7e0eed4d8b45b29abdab422af15209d8ad4ebc1557a75ddcb354c464da78f725d180e3d24f7b806b534a31b0f087e1fa49651cec38dba8db0ab063df5c28e0cc34b18c019c03eaba6c6468f338e7940d973f50f1c65bf2370b9e969d65ac6126a74fb28822d213252850b548666a64b2b5c8a05594a3a1882ecac2be402a169b4914a13735ae3a9d74c310e80adb4d861f487b94694dba12a60d962dc02238025049a45a0fb2996e8264856e8262a65cf69dd929564a0910ab734088a995b40a6c2a70865d4aab0142953038da4481cfa6c2e4bd02840a5683f0d0656ca0e8a5c2aca0f30abea45b215ba6d3b1314ad3ba5ab9ef474d69da4e63855940ab9b795dca9802c212ae7cb4b89520312fa69f6448f4536fa6ca6fd1681df4f84bfa2b1f3189bd03c29d1a47d1c5ba359a91a7a5dd3334fc940ad229a8e9e9f055643691151a8f663ff00270b87abfd696d893a6f8c68d0fa366eb341df97badf40b6449f413ca97d07c2159e81d6c012fa04be057f49eb869937a1a4fc85be99a5b614de869d6d3e52687cea15add0efa14a6d25b6e097069c36f097184c96d0b4a64db36430d43646bb208ec213c2bc55f153a01cc73a460c632760ba70b1e46d35c4992395cd71e848598ac6936be29646e7f29714a966712232373f9589b277d337b427c3246cfa10cc761e0b70377e17fc3102439e0763b729e42bd15a7b483299a1a18ddbb76cad0b132b81ed0a9690e738ef0a1d01d056371d428f5413f3867aa803bf58076842a50901fdc100d4c07f20b303e8601fc82dc07be9c7f20baeff00881c6347f20b9ec33bb7f20b39521afa919fd41757278f9d7268ed0a97a2b90dc5a7b428de814e734fee0b3d030ea66ff21eeb7d010ca01fc824bd171f3e268fdc125e8603ff00116f7849a30e191a7f704ba30653d183da3dd530c323a069ed1ee8c29975a1b9ea3dd360a5189a3b47ba194d7dbfc82c84c0d35586fee0ba3936130d634f68f74d5b898829411d47ba8d3614fa16ff0021eeb93f33ebefa36f78f74df98d3d1c8d1fb826fcc681a9b80cf50b7f31a7296607b42af940fd44cd1fb8295e4d84c554dfe43dd2793c2dd726ff0026fba5f273906b06c3b87057f2db5c1abc4aee62425f2c4bc61a7f704d39209fa66ff21eeab3961b3081fb8295e5a260a76ff2097c8151d3b7f904be4132db5bfc825bc8082de3f9052c024500fe413c06c538cfea0aa1234910cf50b6048be91a07ea0ada744d4d2373d42dd0699001da14a875f00ef0a36071b18ef4616be9a01de8c73d2628467a8460871d4be28c7442d94bff00c96e99cf923bc250eb231deb701cf923bd180cc87c53da2c2e193c54ad46c381a3bd12b31f08c77aaca63b0e3bd66374eb88434c3a2ca0e6cb708069cfee4e4219225d030918eab740094f294a140e2be8a6d4d339b8c920f664ae99518fcb3f884e18ba8a473b180493dd954d5631783553877ad50a66a87e0f54a9d6cb7a906d8ed202b635e8be11e910298484767325c0b90d6a1870c2476754153916aa2e6e4927d565a0fc17fc0eaa77a0664d54ecf5497a0186a97f7a8da0e0d56fef53053352487f72a6182556ad91bda8c061daca4fe47dd3607ccd6f20fdc7dd181d1afdff00c8ae8a91126bf7ff0022a3618c375fc9fc8a243be1ae64fe4ab03835bbfbd65070eb57ff0022a56071daedff00c8a301a3afe4fe4536038de21c9fc8fba9e1b0dcbaf253fb8fbacf2301d46b393f915be461516bb97f91f74de461c3c46947fc429f1a6dbc479bfe61f746106b78a12e3fde1f74b85a165e234a7fe2146329affd44947ee3ee961b0cd6ebf90fee2ba3936227fcf53e7fde1fca6adc58a8f893386ffbc2a34d85c5c499c9ff007853c896a5e9f5b4e47eb29b19a92a5d53376b8a6c834747aaddda56e0d264d76e6f6a6bc971037ce263fbd46f2650ae7c4a9cfe990a4f26866878953b7f5484fba69c1d3745c42924d8b8a6c0b5516a67b5bb12970a4cdc5395bfb8fba690ba61fc6697f99f7559cb05dbf8ab2b8eee3ee97c9938ce2cbc7ee3ee97c8485bb8b0e27f57e51e026a6e27380fd5f94b78088a8e2e11fbbf2b9fc03078ce7f97e51e40d878b048fd5f94f3909aa2e2d803777e53790ec9c691fcbf2b9f4e01fc6419fd5f9548093c621fcbf2b287071ac7f24b80fc7c646ff2fca3194a9b8d8dfe5f946236394dc6a667f57e5182414fe38c79fd5f9462d0e3f8ccc3fbbf2a9e1afa1e31b07eefca6fcc0c3c6a887eefca7fcc171f1b62fe43dd37e61c938d111ed1eeb9af27b0ec3c668bbc7ba5f0958723e30479ebf947860c7f16a3c755be4d8ec5c578cf6fe5358e7d3e38bb10ed494e769b8cd0f784ab1c978bb0f78487c222e2943de1575224f1621ef1ee95865fc5288f68f74a0dc9c518bbd2e829dc58831be3b95e54de43f8bdb7c758cfe98f1db7549558f065e74f7cb7e3d13e8a98d3da7c3c744a46a9c3bb31a9979707a8f156f41eb9a6229adc583af29f3e88d63cf943ab5c65393fb8ff0075b69da6d8ef5f6754a1331dcb2173da5c2a29d28c744c81843a75983083752d5a6093dc0bd003495ca980a6cd94c0c492a6186df509706193323014d993075d2aa506cd6e12e032faf28901afad2ab207595ca5e4da259588c1a4bab10343baad034d7d42cd69dfa94b6b2c37949a5111392e94c4d3ac862637ae8e4e7004d4272d56a2e51a65c2d5a346374b3a47132cb0b405be99862a998e8b7d0c350d2129bd0c3cfd3c0abfa322ee1a1f2a77a08ea7e1f0cf459a70d75e1f0ec0a9283364d25c8ecacd28f639e64e403ede9e8974bab5ff00e9ab641e995b2b15ebc70b08fd20aaca5d42c564319c60f724d5134dd3dcc3272b7d00b536a733f482b7401aaaa940e87f2b42a1557771796951c0228e42460a3c84ac772e51d5680b35fce7b56032dba1ef2b9fc9c93763de9f01b17427bd6d81dfaa2903e7dc48ef59a4262a927bd1acc1120c0ea8d18104a7bcfba35a5c7772177ff01e17427b4acd071d55e27dd37a809151e27dd1ea34a6d71ef2b9ff008ada2a9ab8f795b895a3d97023b5630fb2e64f694b4da5b2ea476fe5475c8e497727b4acd563e8aa48ed2931694f36e67bcacc3e9d17527b4ad2931d79effca5c05b2e873d4fbac07a5ae38ea97022aa2e071d7f2992c53b52dff941dfbc6fbf557e548c6eefa36399f9f32a98ca9cd33a0d8d1846255ae705f86c6098978f1df60a33a6ad9c4fb8111b80e9823c15256bcb6fb862438ef2ab0cbfe9bbc7dbd55702f36cafcae2c0988aa96e03ada95a0bf9995b80154c994980c3027900595387c1e98189e458dc3594d831ce74630eb1c9414f729fb01640b3d87d84d3a066462ace813f2917a2eb86549e869f6bd25e869a99c93db74d2a4ab1b0969454254f41c91c974864aa4294d2af0c9fb358c9fee9a9b57fb0dac354ab56cf900053c66236e75191b2dc1806dd45cc774f8316282da309b06088edf853bd34ec56eca4bd076a2d800ce113a06594208dc2a4e82b9aba00c60c754da9e80d31235d2018dce12eb1a940d11fea1dc9a562cb6c64720e81574aaf6a8e17fcc7733001daa1e95474da2cb1b8216e80dfe561da137a066af4cb483f68e8537a0c5759e8c2c79763bcaa056619363ec8002694a5069cf403ad916f939974c8c0f9b549683adaa50a1f3a75229915851a6c7cead27b51a3098aa10538c9d747b61d15492fd0166653bf4a0a6ca92fd683cc7ad9f43da5b2a15a7d11b44c72e7b56de99a2d92614af6673e7a4d4cb6bf29cd04095524369874a53e374e36a54aa86cd4a505415184602a5b8e52807349b230b8ce35fbc81d55f932a96e94f37556c4eac90576dd518957b235b52451b4fcb23d3aaf3245eb0bd7b585d0907b8aeae11af32d7c987fa95d7cb16cb057ec15f4f17eb55c54a9d62a3b8a9581250cab64073e72ac065cf5339224580dbc250e3a34a08746aa99a74483c305a90538d7213ae48b970421ad4f1485722dd69c6468d212604829992993442be11aac2999634f143423453b8d894ec308012e1b484cd3b470971c25262ed61d220ee7cd68c5b69eca1a969712544c091a7aaead56b403a5ca4a0ba79f951026a0b86064aa81105c9ae2a1e4e998a3c6e52e00f70aad952057eaef81a775408bb9cbf346028d219d2f6ce59803de14e86b57ba60e6023b82781036cb8b98f55d0ba52ea424632a18819a97972ac8788b958535878684092c3c097bd30c9187385b1ac235b68b3193ca36548142aaa42364d280a5bd8a9a087b926830f296d0f82ca0a892e039204d603385cdd40f837092404b8ae8e414c62ada4110b54ad02a262c075b0a303e254b9f9971d6b57673f318783f0ab7818704ea17e631c6c89713c1714883487049948a3af0969b0de54c6bec2d1a19f36f84c346ba8b0329b068299caf0aa06b88d3c0a7d34e02281e2b024b43d4177ba970eaa5e4d59eeb194fca3eaa922763ce77d77dfea552331336776ca9ad5c6d1704d5bab4d0d525c1a9782b9641a74566530d12c9521b4a281af82c1ae4ae4a34db1048e48d42902929c57c1ab13a4bdea1608e31ca7548e82b3453f1846a569d7157bcb434b322421874a9c105e807212839442dc30594a5c0ed3b33fd929b574d336419c9f3598d68940c002d06ae3518595980e9ab54c61bb8dc158a121af53b024a2976ca02bf7dd57cbb0f2db74f025748d6927989f155bc9d6fbbeac01b80a560576ab55eca4155b85d4c920013685badb4fc8012a6449d0bfefe6f54605eedf5dcedfc2000b9c3f76c981aa0a8c15b2278b552d40c2b48c3b36085b62a8d1364a4b03894e87bddb9af1d07720317d75a3f93eef54ba1994f09073f8ed5ba0c39cb741b256c05062680c3dd84d80b64d954b01642e6ea074296025cd4c0eb4a5f443b1392e8151c89e0779d5e406dcedd3f30d828745d3306187bd6da30e4414e8c3a1aa3625871af53a690b8e6523e0c12e52d690e72cc4f4d909b19a61d0ef95983524eb8646130d0136e9a53336e23cbca15250cee9eb7ee45a0aafbbf2953b43d6134ea9029fad24fe91f2299af38d69ccb8f1213b2c6814f66e5a7e6c766509d3564972ae356aa1a8460d4cc5224a611148a606c32a0da2e191035d79407cc195b80d49190970b0f1a7384aa436d62dd14dc811a9d35f296531418a1439f25648ca580a93946bae72e8f2632f0b30e6a56246e1a7350c703b0b219d8dead215c7c69684ee9fb6e4ae7a5d5e291c1bb26535274755f694e342193bd2d1a8fb9dd9ad0a43502dbc9cf5cae903229d4fa801dd3531039729023acd40e91ddfdbdeb605967acf943ae3f0ba2d3aad5baacb8e32a36815435c5ca5a164b1d06f93e6b02d3709fed03c90448514c047e9959812fa2ee1cd9f55a161ab6e72a7a145bd5f79250df1c2b4662f7435f98c1f22ab1a91171042d08c9eac02974007ddc299dc35e168445f695b2b12e061dad34e16bf38dbf0b7c854236656e03869d6c05009a00b530e5368269e90e56fa02668125065c0e14f00704e5180736252c2119c2dc0798e54804318af0151b5269b4a72df435f08d6fb1a223a759e869d2dc26d4f4d97a5d1ae46e52c6e8a6b96791a573a7c263e784b830312b30614d62c18e98d348a334e2abc06f4549030b96f5cafce516045de752e5dd54ec0f7ccd1aa46a8faf07f48f914c779e049fd4cf5c1253b2aca35ab8b3e581e09e4469db5566154ab25beb13604ec354a7d0170d428048c53ad30a8ead0d2cd4a7c05c73a607649f2b6c10e9abd94ac5207f98a3457d949a4a5315ab5c90a8d0eb4a7e79252252bab9e51a6f9d3e1a3b853abc2247a953603a8a8494943b25ca3969f8574c29ea56e5e025ea3357cb7d2f2b73e0b97a287a0ac2e9709dbab348de54d20d0958e2968d51ae7392fc152b06ad7a3f4b46f1971f1dd75281350401aec33a29d0aec7642f77329059689c2119f05b033ed61ad039fca0f822d3a36d8fc9cf7a9da174d3eec1dd2e85da1ab184c1da8ae59083e3afcb30a92049e93afe525250b78b864285a19cead873287776eaf0d89eb0ea2c80dee5694ab18b8add002b2e984a11551715339fa7acc84d01b6dc304aa4811da92844b193b742a9818b5cadbc87d4a4c068f44b600f95941a794ba04c13a4d062a27ca6803b9ca980ba76a300f2d461014ad4b80e441348074415202cb54f0ba4909706b9859834e472adc1a79b26509e9123568d390c69c695215a3496958a9c7392370d72a518758b3061c715490281c43b1be46ec33f954818d5c786729fd87d9650addc385d2e7f41f64943dd4e2a961545e20cdfd23e454ac33ce0e3f79f32a9c46513095d522352b455dba0458e82b729948b0d2d522b2c1f1cca353b1250cc9301f86a161b04b655b1af9d22e894d8546f29ed077e6153a6d75b228747d3cd5cd60d3888532f72e880812abec261c72cf430c656ac524a03ced52018529296d03692d252c4a88a9b7e15e2545d9e83ee053d62db592631e5851a70369a6c3f3ea93598b4ca13ca310f79aac0c2ca315a650f39ca4a3128d2e60c0f2db6492ac71b6f2e1927c5560764c342d0a6eb6d5003301606494f6d7c93079ce339f04de02f8ea6200f4f04bf98582d757b611f985a68eb3ed5bf9831517254bcb31254f78fb54af031f526a60dc79ae7bc0c5c2d5a843f00152bf3180750d40cae8c6abf66aee59328c0b7535eb2728c05575473f44c15da8baf29fc25f06c194579cacf2c0f77bb72eeab3921eb25cf9c615e72cd40ebcb2606de69fd354195a40c25d0182531331480d02a9439ca9016f896072072a01cd2a74b091025521d10a7829f8c2bc4e9c7b5481b8c20152c584032d430546e52d4f1d794b58f84ab0daf8cc9719e8ae75424a4b1255a1fe4c04cb42613ba782becefbaae9576d2d6663bf50cf98ca4d0b1bb4743ff002c7b24b404768b87fe58f653a14ea890aecb092a81afe43f2cf9151b1af3d359f79f329b98ca218c5d72235294f4bb29a912d6c9b09948b351c8969ac49c52292760f8a556bc930e453a9de5a9113848dc36fab0b34c432b02b6a7a7beac2d316da952a34436b146c1ae3ebf090c48aaca70739d1e8f8ec954b3d0c35f50ba8c57d429835f523b54a8130d6354ad03455aa4250efa92e5446ad761a2fb415ba548d6919094e26969f032b9e55300dc2ed82ab06222798bd0305db1984946242a2318ca48d41dd2fb8180ad02b35fa8c969dd66851eba732bb0b342c165b3e02ecd02ab22c6c9b4114d2905685869aa8e16e07d5536ca7a6c371576c968c037490819f5498301e8ed68ff009fcb9db3859831a16a0ae2efb87729e155887506f8f44604f32f7867559806d97537795810d7db8e4e479aaab812dd7d20a5254a5cea0b980a7d490b6fd4263940f254d26b4a0f13333e0b9fd28caeff00016c842dd08991398dbca60553c7928022a61c053a03b58880e450270258d532c758f4aa428aa415d695689d3addd2870330b01265ca01e89a805b98b975b619730ad84a53589a2763e7313612b8d72da587a148bc1458962d0871c2714045310e49e8357d08fce3659a17efa72b741a148b43170365ddd24a56bd8bfa67c8a8d33cfaf1f79f329a5652a372bc4aa6a91f90a26944434f829d5953948f5954d1cd91459a96a3e9baed9113823c2cb0d8555d4e1aa1d46a0a6bcae7a62e82ea4aa4a98d86e7ba785c14fb9ecb7181a3be105258c372dec952aa68ab7dcd4e9844f7dc25305ff1e2b64363bfe345756b5c6df8ac016aaee4a4c02ecb525c51e42c3533f2f54d8cafb4dd673bf0951ad92d56f022f44310b5149fdd06c483e5c337ee5cf21d52b8bc2b481c8eac3774d603b4571e6724bc81d76ae01ab30334bd5c7729b020a479722c02ac16cfbb2a5605ea9e0c059e800af8b253cec130516cabcf40731bb2a7a08eb8d4e1486a1e3b8fdcb0688b85dc007c9668d51a8ae41b31778e51a35a6d2eb06ba3233d9854c0cfee17de590e0f6a02cf6cd4198baa401a1d4584a126ebd023aac36abf597ee53ea998bb69cbe07b424b5341ea0fff00d00a4d66344d1b7cc37d30890c89d691e1a5fe6556051686a0bc2a98438260229e5c25a0e5555f36c92d04b022505b0e1383b21d94696110a59548779d52515f73aac4ebe6bf0b4c240ca010e8d0080e40111e572e36d3e02d8436d4d13af9c536a7638e09e9642e22a55d121e74a91590c632985865f1637498c68fc28972e4606b6d62d0e36158181bcaf47a414be203bfa27c8ff651e8cf3a42d3ce7cca58ca2db12bc4aa4296ab0944a3e2a9ca75a54b503d253ea5e17852a3525048bba52e08ca6304b9bf2a5dc32a5514cee65c95b83a8a02124a5151b4e55e1520e765519600a9a43d8821a116172d3151b8a953695264ad8a61ea6a2255e432569ed790b200535060a780b96942ae048e9f800727f2066a2a8c9c050a2c1dc38a2feaeea552ad958fe5184929701caf0139919a82e2033653c0a2cd7655902bf5f7d39eaa9813166b8e067d56e031aa75603b03e0a78653d8f2e29a40b1daec0e704b6058a874f39bba8d0907b30b970186d2eea920393d2602e8e6043d4d661570202babd53c27a8196b3ee53bc8d456a1ba1236f24b791aa757cef033949e469cb6ea278db2ba71419254976e9025a8eb9c1b853c0624b9382502682fc553ca7a4dc2e595be5a9cd0fa8087614fae54582f75993cddaa3e5b898d137024e15a729acfafa9c9a7f44d819ae9b81cd1bf8a0c9b7c794c1d6c49280f2330a740a81c880f06a769f9a0d973f54b02b025d3c11c8a9057dc8ad13a4b82a18544e4025c101f34201f6394b0a5fcc4b584652d690f2b35984bc2e9248eb0a955a438f9549691f42dcad163b5415b12691c2187ee49631b03225305b2349ad79c89caf4ea2a6eb98bfa67c8a9d25602e8f0f3e653480e465561087821292417464a17913d4d26122b83a9a4598312d4b50ba25031b549b43863ca9da673fc38152b414db50591210db6054d0721b484d29c41b6b53ce9a0e6b502a1d704c1141600b93ae1839fa6c2270694fc7670174f3c2d289a7a30155941d5d08252a615f6b092d0229a8f092d521e6da398a88ab669ab6f21cac4aad46ab65485405caf385590ea9de2f39185819ddf350969c25002df5ae795942d8fab2d8f1e09421ad96d7487707aad865ead5a4c01d15205f2c1660188a0e5c19b6029d08a6d012573d4e54b5358c61522f00dfe98862b42f4a0cd094f2b9ea26e9467b95a9620e4a53dcb0f01d5d973d8975457ef969206c12b710b6bb2389e855ed6ad149613dca34248db4f725d088afb7a60099484159e406ae9b0b3c84a69566f909a720bbdeabe57f213e0ab390b970d2efde7c535a1ae5c5e1f1f5ec496852e5b661428361aa760391c6a7a0874195ba57591a652524bb07d532b2a6aa06cb9bb89e816ae6f14b4a2d5dbc718ca4e15f70b8416a3d10fb425d3c25c5208512b3cd31c11ab58e6c28c4a561e47cd6a59159cbe2c5b8a612635ae691f342d5a1418b2c3bece14ac29b965d95f88c69fc1f04957c0da63a55c1dc3429b0e14643ebce1f2f62bd572a8faf87f4cf91412bcf6e77de7cca7c07617a6294f9b252b641d13800b17907c452298918b65a30509536944d34c9b425227a9da5171952b416245ba43825468382447a69423251e8c321b212bab4d47d35bcb54f12af9ee4484d71ef568694974fba82c580126a748963496886db2053b541f4536eb5b56aa68bed050953970acc30a68c6795975cb8aac3a0ef356434b94c2813cff0031deab285cf4c59c2285924a0cec942c9a5b4defd16c32fb49a7bc1520494366e5d914112e9c254e8261d3782b9909463ade0278bcaaedea8b230a92b6a9f5165c154952b00d5dab3d8a9e93c443acdbf44baa42ff00c2723a2cd3e049f4e03d425d3394da65a3f6aa7a609ff0c1dca7e8079edc31d16843d659b3d89a508a92c0ba02a97db09ca5d09cd1b429b4327e2531c2bb941db395ba17dd0f56703750f41b2d92f1f68c9f059a1273ee3f2b70220c5bacc05baa7017361a862f2b711a5d3bb7413d1de4dd31bd8d78d96d87d0c13f3c1a1d0d5d1e31b0a5c7f4b8dc364284e903cd6aaca784162b4823a58ad393151acb1cba770a561e7443025c5a7470b1361f4a6c695275c309b0e65efcacb1a6be5a9585b5c7c7b2e8e21656b9c16c655ec3b69644b83e903ec28c835e7466d95d7a933ae233bec3e455b96579f8b3eef529a42d3b24498ae363525a0d84215895a68536187451e118cd3d94a30a85c9ca9485d90a5d428f88e02891f48fdd3812d3b2014118cd11148b3cb352505c0f7a6f47b5da9ae715ba95a67ea53cac74d4029f5b86df325c5cb8ea92e12d18e9429b40cf3a5c3c196a9b2e08c62fad7618b0baa7ea8ba10d3829e08cd0dc4f375568ac235456661598441693a5e63ea97c86c76bb480c1b25c09ca1b40252e05cacf4202c8659a02a900ae45b41e6153a0d39ca3e52c0b51326c3556abe709f06a26a005a5d454b105b402a8a60b29b03c512552132c584860ef956da4053ce960012542a406a4a955901b73c15b6805576b0e52b41769a0e424f82c94316e24527fb417f8a7940dd095dbf546069f66aa29b02f16fa8cb5570029e4dd36030fdd72f9357c423ca34eb5b859896174c77598dc493d9b2a74b606f949f8ee1a3a574deb5b0a6ae2fa73add7005cbe502f9d5f9878f9ce5d11b092f5695b4969496bcda25a14a9e12d4bab438d72d3c3919487903ccf4daac32e6acb594b894ad4abeaa6ecba38ac95ab70363cb95af4a46e0fd82e1fa742d258dc850950bd3ccb3bd74c3b3dd7432c3e457572cac267d9dea5570b4fc5ba5a538f66149487a01942b1274ef54c35a2e295661344b29728546d35b5314f39b80a7d421f864c852c21d580fc3227900b685490a5109fc971d1d5734e59a9085a08fc2a4e4a76e943caccfaaace4d14e9eec422f2ac8769eee4a30d5d9ae584a9d0dfe66214f1b1f1bef325c3a46c5763f31a3c528d6b9737e2007bc25c2b38d40ecb4fbaa4346792bb2eebdaab1587ef4ccc584e9a6f87163cefeab286c1052e1a16604a51c7b84b605868a350864ac3b2780509d6d04baa54e80f2d5ac86c4655ce992e95ab8542dc4350d57589b0ba1db5492ba21e272b298c3998598781eacacc32365954a91175350b6045cf32b408ff00acdd747300ea5195b7909180295e41df939052790c5f8a51609f554f2103c2b879de4f8aa606c0e000c26c0b1582b3ed5a09aeafc2608b76a1c2879353a2ee8f2953d4d79c9fc25c2c89da59825c3e0cfa9d9276ae1b695cbe8b5f15dbc75aca5355ac2e9123943c91c62243c2f93299b1f7c946b498d3dae3bc8a8c28daa4e0bf96b159c3bc89b54f2f82930d18d31c9735654ebe6851a952246a7e296368e0751e1cad6af1b5cf1ecb8bba5ea07861d9425ae5e9e619c755ed48e850b597e83e457540c26b19f77a94b4101a5737503e4dcc0718574c81274c56d03e9e5c295a1210cc9fd4092a7aa4ba0a964052e87d12c070bd4f014c7a6341ac916eb4fb5eb74c76288adb487482173da05c939231e89f92abd5f6819cfaaece6047b762a541e923ca4089afa4dd283d474985805dba4feb0f30a361db2df64c5333c926066f7d9bfa44aa730d19952d4e5c7cd74c36ae2ca4e68c234abb686a1c00b02fd144a74a3692351b189da0282248350d34f28542c950834075154960a0669f2af13a80a89b74c9a3eab72b4a1fe528d07630a54c4554e0268d4555dc82bc3a1e5b8049844656578461d05595fbf55944071ce494b2993b6c90a7813d134aac85495047fea99958ff00186ceec3dde694aa2f05e43cee1e2534aad5fef75e5b955953a9ad1b732e09bd12276fac21a96f5148a8b695ce2a56ac26689cd092d072ce4f3a9d0d0e8307194940bf9490b6be8d884ad71e86c71a10bc21e9d33d08402654c0db1c8029b1a9540a53a629a88a43ad6aa1e1e1185529a930801f9f29415f2160196da71cc32b3126f9c2c0c0161e34495c97042636acc33cb12b7395db2a4cff005b0c30faaaca186d449f77a94f41d8e50a5607ce6a6903e6c2ab00d8caca06520cae6ea81cd6a9fa02622b740a8de9b424608414c0e1a6402994a969a096d3a4d69d0c59e8c22172a145652e07cc0ab211f54420aace803ff010a61cff000901287ced3c0a03e6588203ea6d3603f3e45658dd5ab52dd0081adee184483593dfaf7f696f9a6c6eb3e65761feab4dad4ec7543e58f4509d35a069898615205c699f9415314145959631374d458514c5322418dd453ec855135010680671b258506d77faae8e42bb5d2e0fba64ec00faa43096d528d66166a54ab51d73a909b90aed64eaf0e86a9ac54c222ea2ad258743d5d58ca85109a5ad19eaa5a6582dd700ba605b6db20215a15376c033ee86543f1274ff00351c8ec7614a579f385d4fcb2bbcdc9755abadd22e7711d53ea7563d15652d4b7a245d2f34396295e948afc36ec146ac2aaed1cc16680b6cb47deb42d2ca4e5401ac4a95a4e508da6df16521a5299121784a76394eddd00a95a983e8e24010c814ea05162433e604290431a9e1e1520542982d4020c584a0ec4e402fea08424da782f3f39dd2e1e35d9625823b1312e19e60a78b24aafa499f7121b861f22ad2879da593ef3e6556502213b2607a29564a0e90ab01f647b2ca055239737502419229f907e15be4088e6dd3604853d42603209900689425b1b1df98930cfb996618ec29a42882156407e2722c23a429dec16020100a6032298762d04123280262a72e3800add09c878572548c6eb4a7ab7e14a5e5cf54d68d67973f8549b9bb7aa4b46a5cf05248a2037d972c5205a1a0742efbb3b6cab2b62f1a7eb39b194da66a361b602d4684954d2e0a8a01a32014188ab7828555fb86c83442575c804b0aabdcb5200ba390ad576a1194c11c6f832b198261ba82a5461c15ea3588ab9dc53f2158adbaabc2222aae2ab6844d6deb090e82a8bbe546b6110d71ef52b1a9ab6d791daba605f2c173548cabc5924ce1656558b5651668dde442991e69b1518865909ed250ad49d0550e7e6f1cf7a74eb5bd270fcc6e4377f64b612262e16a711b851bc9e006dbf0dc94de570e64cf62cc04da80e6dd684a573f7d8a0100a64ac2404a8d8586a5a6904c545948bc7c693953b0d3da804313010c6a015f35220fb994e9e3e675443c284b8543c75d22729b2d407709412c407cf76eb7126d9c0883aa5346cd2c6b5b0964690cf2c87f2e5475266dc479f2d3eaadcd0f3dc8efbcf995d3cd07e193655021ae53941e6b974c090826185b408830a56019034653f98131186e12e00ec684b8064385805b1e1203aca80b4d04b670b71a744e13619f32a52c84171ceab2011155050ea95d3385c5d5fe838c957440534a707e2889386a60d3f4170ccc982e07b3b364686c141c1d85a39b1f84b294e4948da7dc63fb2acaca9bb7ea62f6f7a0a87bd17019c78a8da19e4b73e790b0f9612e2f103a974535c0bb1e29b1b1429f309419a6e87d520b4648ee4817c0f6b82c402d4510c20c8d963010aab379a901068cc7545d88e9e2961597df7503c7fe7557e42aaed4326538111dedc83626adb772546b13f0d6654697005c2a13c62ab71955e115eabb8a6084a8abca0efa9b947ea48d89582ba01d484b8d3a6ed0f61540b1e9dba34f45bacad2f4fd77459acabcdc6a79a95c3c14e9180d6e89a991eef96c277ec19d93c56ae7c3ae1c9f9ad6cedc7fa2ac4ebd3560d114cd6fda426c244d47a72908c39c32970f03dc34453386d85962ea1eaae196dfd21ec92c0c86e5a4eaa37eec7633ddd89281b461ff00b9a90256290155c2d8f8b42c46c7cd52b0d05455584b8bc866a6ab29886e3dd0c7c1898160a010d59503ad6245238d1ba0d1d7313c3c3b1302d29e73020062f4a0e53b32806268f053a4ddbe1f5b9ca5c346cf353ffaa56c36ca74a67942abb56c89c667ade9720faa79148c4ee368c395e0a1cdbf09e274d98709843d4ed28521750fc0d904a1a96f041427532db96c958762b9ac04497740130df080b300a8ef2a9aa418cb96525aac38dbbeeb2368975cd5254e96db8ecb6d739cff001bdbf0a3682e2ba28556096dd92c8e882e3b8e15f1cf843aefd9ea92c6634ce0f69f33b813d854aa91eb0b040d8a30ddb231e6a3aac8b153d502d593b27f152d4b61f98ad3b67f11568b7fcb706e53fb1fc5aabedb96ef8e88f63f8c76e1a5f9672ecf6e54b58b4416b0f8cee15f9a5d653adf478e657854a68de18911f383e2ad18bad05016ff0065ca304d4b103151bcd6f2e703080cd351ea4001c9ef595acbb516ac6e0e48f75c527f5667371d4609ec5d5c408975dc67a85d5c82e9eb813d53d0b3d91b9510b8d2d0ecb003ba5010b70295792423029d73996790abdc6fdca8c0acd5eae2568444b7971ed2802edb79703be5675c9dabe89bde7b573de4359a0bf8680338089ca78d3b44cc67219d46c3c1744e58def4be908e98733da09233d3295b8a4eaa9d9cef73000739ee282e0ab2561fa77bbb8274944a4d74ef9dcbbf5210c6896ab892d049f151c5756ab46b163480ec776fba31bab5cd6e8aa19801bbf9650cd50f50f0501048f3d96b191ea5d2ef80e4027b3a26efeb155769a57b9dbb5dec5427d42e566d3e5ffb71e6bae7d204d1e1c93fb82debb80e47c30dbaa8da58f8f0e881d546a911955a4c83beeb60aa2eab7ba23fa1c7b3a154953a62df70246e31dbbeca3a22521ac0463213caa4352d604f20a763add93612922b7b92e0d102525318d00a75ba2620a36b4beaba39ed2c6f5c088b05375d9e36f73775e777f469b31eea33e84b5e4194755ea4848cff00598c34faa79148c92a80715482a32780e5513a164a228108863210a42decca09519554a109d3cc93648c1109c84029b0ee8039900c26c068053b561d4ec53b4cf9e775b28496765489d150b7ed596a61e48d4ed02638b64aa439031348b44adc1b88c1ff00ed74623887b2d03a59c346772029d831ebce10699fa766fdc0f728751b2adf5dac035d82a362b2ac360be070ce7c57348969cbb6a000615672cd67f36b4025049ed4d835788352891b907b11835946bbd57f2c939ef55c6ea47877ac9b246727c15242a035dd5b81c93b75548163e1b6bf8fe5f238f878aa4acc5faaeb63c6463bd29b10b3d5b4a062abaac8f96e3dc0a063c53c63d70e6170071b95831e7fb9eaf99fbf395cfe5442cd7f97f9957e600e351483f714d2858b4eea3713b9ee08b4374d14c71c7a14c1ad5a684e101dbd5af64d81976a6a5c146066f7fe8535819b5d685ee3da92c08a92d27c5203d4fa79e7bd604ec1c3c988db2a969d6dd37a12768ed52a135a9db2c6d072474440db3817c58821637e6e39863aaaca5c7a1af1f12946e8b67349e5c0f0d945b8f3645c601357b9bcff00d3cec3b1057a5b4bd535f4afc77274f195dc2d3cb2e47794171a6e9a8b30fa27f29eaa1ac2f26376dde92c3cab1e95d62fe5fb5c7a053a79179b2eb573b67bfb4053a791a650d15248d064603b0eedd79ddf55a9da5e1dd139b9644dfc29cea855359f0b893881b8f25dbcda148a4e185535ff007138eaa96826f56095bd09469620e3b54ef3804fe562913d6dd3e59f749b81de8156fa2d3b4952dc16349e9d0755ba9d66dc47f87799c0fc86e06e761d9d8b9fd08f396a1d05554cf22427aabf35481e1bbf7f92eae60a31f73db65d189d2ed53927753b02e14d0ec971bae7ca5cfd34f3225cd69b5d859ba7e4637fe0935374d6c3147baf3fb4ed38e1ba948e7b5e3fa93d57d12b19feb41961f22b7148c8238f73e6530ae1660a64ebe920ca04015f4642148118d41688752e508d75b6d09009a7b605b01d96dc32a920194f4216d80f1b285cd5682596a1853a675966194425171d942a254f8b563659873acb537b54eb2c7d35083b342cd343d6dd35338fdac27d329a55a350d2dc217cdfef18e1e985d1e895a4699e02471383bc4149a9ae9a82611b481fc7090d1e72e27eb87c40919ed2930e7f843c6a91ecc3bc934f9a3abcea5d6f867367c5527cc6b00d4dc597366d8f6adfcc6b4de1f7188966e7b0a4fcc6b20e307185c5cec1ed28f2352dc0fe26bbe5924a6f2d5af88bc4ce68f628c0c027e3c490d40c1edf44c6c6b361f8a02f0039dddda94d8b8b38f4c2dfd633e6818a26b5f88b3ca5ad703d47540c799f57ea035321cf6940c49d9341f345b04b1a8fa9e1cbc67ed3eca9004a7e1d9e6fb87fa2ca174d2fc2d8f9bd4152b037bd37a29ad60c7804da17cb6590ec9b41abd509e53b260c7f595126d0cd2e16dcacd011ba55a7aacd095a5d0509eae0b40a8b4942de8e09684bdba21d1a33d8a16b3575b4d08e5dc2536aabafacad73303cd03593ddad0e8db919f44da650e7d5ef0e2327bbaa766a43405d4fd4736fd7282bdc7c28d58e3163c309d3d4fdf24046505d4fe9abb06b00f44fe939caafc48a40ec1f10526a921dd3ad01a3c829d3c82ea6fbc8e53a7596ddc45c0032a3d7c82eda6b8c2410dca8cf986ad65e24e7a90bb78e02cdfe6a6c83b3b96f5c853f51400b491e25470b195d56a27c4f381f84d8a4355fab5d23307ffa45e454a70dee4d8dd971c76a4b13adbad1c4663bec25b83f6f7a8f91026ade10d3d6379896e48255798a4799388bf0dff28931b49ebd3b57473705611a8349d4c6eff72ee5e9d0abfa4e936286407ef042cb4babc4337dab34c7217e573f4dd2f99735863b4fd557e6dd6d9c23bdb187ee700af60d6cb1ea7871b3c2e6bf347a71fa8e3c7ea1ee89f2735792eadfb15e963a633bd692e187d5329191c53ee7cca052b9f74c9d194f2ee944115401085220aa69f082d2a08d08d1b1c69016d5b1a7a37655601d4a026035cd5cf62b0e07a9d31f87a2c4e9d89ea912299365f8dfb90b2f5a6783b25511cb950e8ad8f48fc264db170ca96b6371d23f0fec81bccf6349ebd12ead12d5b470c6301ad1d9b2a4e8aa7deeb9bd1a9f495966b2b9100a72bccdc59ba65873e29f0ea2e82bd72f4db755950d685ac2fe7e4f5ec54d66bce3a86f999b73da8b46ad164d4a5acd8e3653b4337d617673e4393dbe698cd2b85996c271e7dc94da8ed69aa0ee33de106c61f7db9173c95860d4f75783b38a553163b799ddd1cefca060b9b4dca7725c8183acd6e319cbb740c69fa7b5ec6c182029956193897063f48f654815dabd571c8efb5b8405834dd312721206e3a5e8fec1e8b9f42fb4346365ba0d5eed20b4ab68621aead58cfaa60cbe4b764a8e87d258dc7a279412348ca7a655409a3e1dca7ae5685cec1a41d1fea52f28ea76ac7285be0daa6dd9c1c4a3c1901a9a89bf4ce38ec2b3cb75e62b91fbcf9958123a46ab964cf88416d7a9b875ae9ac663c0274b5707eb707b5631256bd61d14bd3abc9fbfeab0ec0583c89b75f8728c2d6213535f37d8ad0ae3757969eaba3ae7f8065af5f1f9a0e7b42e7c0d8ac9c4ae9bf72af21a2d87888303759dd0b8c1ad5ae6a94858abdf2a1aedf0ab39522a32d4e1cb6f22b93d61fdbb29589d1b65a891a725c7bd4ef2234cd39c4be4c0738f775592291b0696d470d40e57609f14bb8288d51c398266f2b58dce0ef80b6749d79ef5d7c3f3984b9adc753b2b6918a6a2b6984f29076dba2dd322adf579495a96a4879946c6ebe7b305478eab354bd65c45fa6e8e2176f346a2687e22481facfba0b571d3fc697483f5157e312b16c9cf5492a8cdb5a1d8faabca1943e2dfdd5b41f0cd96683b039400932adc016666536036c6611806c4ab4cf8b54a82e16a2403a99aaf00c6f5dca4e8a79a5a0f55cd41fe619e56eea6160d31a0a695df6b491ef95494379d03c013b3a46f8ee169de85d21a1e281a3007b28754347b1d71070b97aa03eb6d59f2dbca4ef82b96d0c064d61cf29dfbd74c0ad5cf537f50b73db85d3c9754ee2454fd9b77655642e3ca3c4aad710479a6c2b34b65ecc67af6a7c6d4bea2e2173478cf62308c86bef1cd2e7c51822c51deb0d1e48c52206df29927f5f34ac6c366aa1145e8b0cca359de32f3bf7a1aa1484924a0c3ed74fb8cf784c67a2b87da4d8e635c7c101a05468466361f84056aedc38f0404443c32df7089504c53f0c5a7a84fa789eb5f0c236acb4cbb5934935bd0285a6d69561b60092f45ab75152050bd129eb95282d4fcf6232bd65600ecfaaea9f43c64772b1f2150d318a2a6dd3e9569b75305b6971390300092f4cc0f3d4279d13ca26e0fca69d37153ae8707dd3caac42eac6ffb33bc8adaa4795aec4f3bbccae1c1d0ab44279815d1cc72f4d6b4abddca9ea513b557a2d0a15d306dbf533b0acba5e8f5013d4a02729ef88223ee578e65a15fbcdc3032a9a757e92f8739f1494340d3faa1dde970349b0eab70c6e942fb69d5be2b639d36fd4191d55653c464f5f928b5ba36d72e4a956a76ed700d8b00eff95ca145ff00347df8ca781a6e88d7e63c127f2b287a2744f15627b3ee70e6f3dd250b6cf23276ff00e14be833ed77c128a4673607375e8b3d079775ff0009a789ff00d369c780ec54942b115ba58b77823f0ab281acc3baadc66327e2e69432fe9194f83194ff0090641fb4a2c6634cd0da5cb1bb84831bbd4c7d52ca466dac63fb4faabca1954fd7dd5741a927d91a0d432ec9b01f81c9814e726c0f8146015029e974f06ac1a7224f069f926c78fe53e8d351553dc7661eee8b9af47c683a3b87924dfb0efe0a37a18d9f47fc2d39ee0e3e052eb71e86d23c2a65234173413eeb3d0c585da8d80f206e3b3a26bd353f68b77cce83650eba0b0525b3e5904a850f27fc53719441502307ff008f553f2192e96d79cce2ecf519f75d3233507a8759112139edcae9e6142dc35d0918727b30af20605c40ba02f3ea9b198c92ee7c53e3550b8d61e99462749a7a7277ea8c6448880a31480ecf5bc9312b2c6acd70d63969091b2298e85d23fb4a5a6681a6f848e7b3292992f3f0b8b08dba6ea81a1685979486776c80d96d50877fe65013aeb2823a20029ec001e8a7a9e077dac03d16eb0dc700cacd3a728250dee485d4f5aabf296f26abadb23c850bca75275749f6a59c88a75dad39548a4663ac74d6c4acd0cc27a8f96ec7fd9525327ad779042cb4d89f8aab653b5be414b51ba59d33c87a97ab4e8b886b841b857e6955fd5e314cff0022aa1e59b85213291de573e36d5d6dba48b58d77af82e9e639ead367a80063d16d8c9036ab9b0dce542ad0d586b7ed5bab9bbadfcb3a128d02edfaf49dbd11a43b59a91ddcef646841ddb5413f6add6e86a0b9f62d1abbd8abf0862f966ba78a5c0b6d35db18dd6a4b150dfb6ea9a1e27292a799605bedb1f2b727bbb76495baa4d4ea4e69cc79db71e0b91a16e56339e607c53ca1256da83dfe0b684e5b2b248ddcdcc71d709287a07857c5cce03bc1bba850f41455ad7461e718233de942a9779a37fdbc8093b744f28613c73d21c91f3b5bd77d87455943cff455041fbbfe8af29b16086c8241d1560c10740b71fa42da3045368818d87fa29d186aa8eca113673accec7d55f90c9e78f7f52aa0d4b16c8061a30ab08f9b509b41d0e4da0eb42d07a39c0eab95b82e9284c9fa4a6d18b2daf8515121fb1ae3eeb2f631a9688f868aa7905d193d3aa9dfa0c7a27457c2eb5b83247ddd42e6f6b6366b5f09e9e160c31bed85b3a1872aa78e31b6c5668c572baeee7ecd3e1de92d1893d3ba64b9d970f14b7a2b47a7a46b000126b2ab1c5cd45f2298c99c6012a9cf3a57e477c487101d515ad20e40711d73daba27cc9525a5350911b7c82d9c8d357ed419255e46a9772d505a0eea8143b9ddcbcee52e9b159b93c9e85368aae56c39ea8d4eac9a6636818e5dbc51a2266eec8f1f681946a9147b8b5a0edd567a60db1dbf9ca4d3357d17a423047337f086c8d5edb451b461a830aaaa461df0988a35f6610bb9879a0343e156a66cad406b74a46100dd4b42852e2bd719804432b95d750dc8417550b86bc0246b73e1d55241ad9f86d2f3869cf8a7356a1f521a7d94ef29d2a5beb40dd678114bd43aca304e12de148cc3506b76671951c0cbb8917c6727da47a6c53c865274deb501e1a4a2f26d6c16cbd02d182a7796e935355ba9ce46997d6ab4e49686967c80afcc2da81d4d1f346e60ed552314aad1e5927311d5c1240d9ab34c8342c206f8f5e8ab032534ee649c84ee4ecb6d18bb51f04aaaa9a0b5ae23191d573746876d1f0df5a250ce570df1d0a97a597cbbfc24d6160cb1c76cf428f401e84f84faa35003d8ec67b8e167a2379b8fc203cc59f97b81fc51e83ca7c63e0bcb465ce734804f7744da19adb28060154942c34f53ca538592d97c013605aed77a0e230b598d02d1484b7d8a9d62e960b9c71bb326ca7a0debfd6ec7b7113bc36d91a5d67d699c87f31ffbae791468b4151ccd55901f6d1f29e64fe424a17e42cf207d25cfe511cbde0ae7bc86edc3de28e4358e3dc372a7e435164cd78e66f9a272015e692399bcafc74237dd5a40c075c70465327342cfb739f05b28d03a7b47bd8ec3dbd3655946a7df6ac2a68d35f4aa746b38ad6eca65667ad5fd7d57473032ecff00aaa87c42007958b34815b0a6d07a20981e73bff3c56e85d387fa064a89007b0e0f6e36c79a8ab8f5970ebe172220123b8a5b463d13a5781b1440118db1d8b9bae86349b65a1b10d80f65cdd74309bb6a0c0c600f44b29d45bd6ab27ed055a0552a9c5eec2cb426ec3a6b7fca9da17ba40183751d64265b883d15392d625f1477e2281e07f13fd977fce275f92ba86a4ba5c9dfee77f75e9f3c4c22cb41732236a9798c475d2ee77461b54fbadcce7aa4a6c42d4d6051b4c168cba4786b1b9cede69f595ae69be00544cc0ef96edf7e87746a75296af86fa8f9e1bf25e1b9c7428d11b7507c19b5cc04c6ec903bd66a90a9be04d84f43ecb9fd355cbd7c2fb298fe53e9908cd14e6f6782a46a12eff322e80a786556bf5d4836c2d4953d41a85d20c1ca02e7c23b998f0101e91b45cf2c0500e565c3653b1aa6deee6a6c65dab35416e4fa27913d54acd019e56bb7eaad20d7a52c156e8616968df0b9fd28a76a8e34d531cee5614f2a750b47c6b9ddfaf2aba21ab86b52fed49aa4522f772713d4a9c86435c7247dc729f0aa75550f2bb9c1e9badb0babe68ed5db609f0497966ae105eb25139368835bba6901e6cbd534854a688b67cfab6467a3881e09a86fdae7e16a331c6e68eb87294a5865dc15e584478d8003a2acaa442d07c2cc0f787bba8394bd53e3d17c2ee1bc70340e5040db70b9baac5eeaec34cd7f3f34608df1b02b97545475ef10be58022e570e9d0146807a6b563c11261bbe0fe90b74899baf1a240f118c60e07446863df13da01d554a1c1bb91cdb0cab15f9ef7fd3af8242c231838ee4f02267a672bc098b3db0b95605fac361e523d16619a652d6f2302874cc3150ff0099b3b6ca91744516976377273f94e5102cd938093151f43961c2ac81688662e182154066d5b41e5cff00d528172419190a3603f62b8b992039c24b03d0bc3fd7079797d118164b8d61c737aa6c09cd3dab39c7cb7637d97327a94ba6868cb72d2398eeab28d66fa92c1ca9f46aaeea65a3592560d90bb32d6516e7d55f9a198cb060faab4842643b25b08179b3d54244df494c5561886cc090d1d7a2d9fc3b50e1af0466ab90750320f9859687bd3871c0d6c54ec1c83200df1b93e6b83ae8d1b1e9fd3ed8c6397a285e9489b1518482a1aeda94353c89d52aedaac157f97c822a919ce57779c0b45ab4f63af9ae1fa409f8e30d0b93c0415eee2404fe0e83a0bcefbaaf3c91987c49d687d13dbd762bb3889d7e5f6aea7e49718ed27b976429b82bc614daaedd35300718f049a00b28cca33bf7ac38bb470da59e40c6e7f8f459a1ea4e067c1d4bcd1bde32d0438e7b925e58fd1fd23a2a9208236185a5c000761dca7782a75b6ca1072216e7c828de2b609269fb221852bc55604afbcc0d07ec03b3a2a48c79eb8ad48c95e4b5aab033cb570ff99d9c2a4a109c49e1286c0f7e3b09e8a93a0f245669ae690f9908d282abd1a71d12e849697b3163820360b5dcb0d0b741ab8def01108a4df2fa37dd38647a975273b8b1be49c349e0d59c11b8f159687a2ed3681cbf70d94e4002fba2d8e1fa47b2ac8193ea8d1a19fa5be4b428b51a7df9ca5c06df47de94d8124b567a24a5405f74f7da7dd1198a5c15e63775edc276343b15db99812aeb353ca9b1a2db518f54948d33839a75ceaa8e41d038151b43ddb3d7b7e530380e8df1493b02751cf17c8690d19c7675e89e7668f33eade33474d3b6370c6f845e84681a678b6d91bf69c6404be8eaaeacb6d4c927cc64a40ebd76c23c900535739a7facecf677a3c85946b06363040479066df5e26943bb884790f44696a58e687e5bc0c06feedd7411e03f8aae1886d63dcc0319276e89495e7fa3a419c11e09a089aa5b780721561d3b43260a2b563a776429d092a2b4b89eaa34255da75dde928582dd69c3772934cecb6bf14da07434dca3aaa6852ae16c799f981edf44da17ba17e063c0297a0906510c652de82c3a7ae7c8423d869506a2e667a23f4080a7d505b301e2afcb9f1b4699d5a1c00f04bdc6e08d576d0f61705ccdc63d707f2642eae0d8caeaa1c84b2a8cef575375f55d1c8659594a7f2ab28092d115b4a6d96e39c949840f71a77bb66792d3341e11707679a7639ec38c83d3653eba6bf43f867c30640c610d00e0285ec36da0680d0dcecb8e9a18a8b9001dbac522b772be2690553ee9505c55244ea25b67713dabd0e7f8171d376523b14fbef02db36035705ec2af74d46d6f555e268542eda99bdeba3c056e4d46d1d16792aa9ab6bd92b5cd76fb2bf313af087c42e8d2271f2c76e760aac65b0d8a63b007bba29196fd33c1e749bbda7bf70b2d0d32d3c2a8da40e51be0253bd2fc10f87e8799b2168ec2a7a1eaca5d36c84618000004de8885bc573864b5dba6d284a0aa71df286c5a69276f2f5ec4b62b1947132fae8c1c1c7551c6a8da6a474fd4e7f2b2868b6bd398c6de293422b8956ae6a47b71d842cf61e1fbee9331487cc95494a0df6ec84e0d0b500b41f926e50b34206e572c8568319a6b3bf168fc2a418a369f8b9e6cf8e51acc7aa78590c6c602ec762518da19aae9d8cfb9c3a77e16c8554afdc4fa71d1edf70ab20506efc4085ffb87badc0ac5cf54c18fd6128532e77b6b8ec52538396fc1814cb8abea2d680b4e08ee4319abeb0bddd7b55198d3f4c13c83d1261f578a50709868f644e716f9a9d3bd1fc2e8db141ce7a800f8a850d534aeaff9c705db051f255f2d7780f3f2f3e0a9e4d1e5ff00896d139ab6bc0c60e764f791156d3b7e733ed69e8004be4eb7c1ade6c6093dddeba7082a9ab1cefd4328c09585f9fb484605f7455235a328c07f8b5c57fa280398ec1231dc86579aef1aedd580973b24faa42337d5160e43903c534062d12f7aac3c1d56dc1d9158764ae7346ca7403835848d7752a342c70eba908eaa741d8f5c4b9c64a8992d43abdf9dca6d0b14378716e729b43e8eb0f3653684bc170ca9604fd25dc630b30276d05a52d8171a791a1bd520092d10279fb97a3c13160b35e4b13750d8be5bb5473b437bd72d83190f17ae6639401dbbabf06c56241b9448450f54c7d7d55e40ce6a69b3b95bac81a58c0dd2de948668e02f70686e7270b2745c6ffc27f8703316bdc319c1dd17a63d8ba078691d347cb819c770ca875d05de00d030b9bae804acbb60a4c34572e17724a791480f90b938a90a0b3f82cd4eac56eb50f0559f4076e15ad60ec0a3ddd0a26a2e2106b7af7ae390321d51ae4bba2eef98542a7591c76aedd362166d6872b3d16c47dcf529e5cad953c659aa6e02476f8f55594b8134f59a30ee6d8256aed6db802ef961a0e76d829d0d274df0d4bcb5c477153b4ef4a687b38898d1e0029da167ac9f65194b8aadd5a15e52e06a57e02a5a69077d56024bd2b2337e2c529744533115c1f8035a4153e835b76cd1851b020ef14dce0e54c3cbfc7bb2861047e15606510336055e406ea06c9f02bd73952053af75185d25c641af2e84a6c18afd97597cb76e8adc68560e35bb21a3a6c14ed18b9dd7531923079f73e29e5606668c32b79be61cf5eaab284157e87737a177badd0160d16e3d5c7dd2876bad022edfca56e2a3ab2ec7954eb140ddc7b511989db550637542b54d3d0e1bec9702e16b3908c3adf60a60d393f94b4cb49d585b196b7cb650a6c5e78497b20927b73d56c89b42b4ea7e5949f15790d11dc45bb895a49c671ea9e72182d21feb1eeca2f275d2d35214f524e492728cfaa3421e8b567f5704f82dd0bc8d62d6479c8e84a343ce1c5fe283aa7fa7bec484a607a0472b327b1227560d515c1cd3e49a08caa3d41fd52df1c2ac51a7e9eb407b7af667bd6876baca46d8cf628f40247a3b3d8a7414fd2ce6f40a340fa2b09ee53c06ab2d673d3c518166b3ca71d3c168483815a0e5385480fc532a48162b4deb9425bc84d506a5c952bc85b2dd7b1cbbae8e0a5c97707a2b5861da7afdcaf0b9ec6a1f890cf9d2029b9323cc1d55f1cea26ac8b00faadc0cd673d73e2a7d534433285f33f9199eb85cdd74a47a7b805c027bb95f2b7b8ee110cf6be9ad1ac898d0d182022d2e242b5bbe7d142d221a6a839fc28d0899e99c4ffaae890d1f476524f7a790f13f6ab101d565152e4b1aa14955ebbeab6301dd1c4d0cab58f11c6fbaeaf1a18e5ef53b9e719497e61093dd31d5539e4212e17c6146af8879aa814ba5c32dd44c1f6bbc95254f19eeb7bd465f862aca5c35a7b4bd4d43808b3e89ad4de9ce11703666e249812460ee14ed0f47d3e9f631a300740a369c4c53869092872baf016730f8ae5daec02eae792e07a7bb8c755b61a401597e0dea542c564456ad9b9e0cfaaa24ca68b5c88260dced9093a63d17a5757c72b1bd3a053b03ebac3fab092c0f3f719ed7ce37ec5bc879da6ae024e4eed9757301daa6aad8157bb3542851efc080574c81956a0a3e7253052ee761701cd85942d7a2744ba46f3346fd54284ddc348d480363809e152965bf4b1101f9c055942cd37112123aff00f68d081afd5cd3fa4acd082ab864937c9ef4f4ca6ea89081cbe8a6cc7da7b4e970cfaa18b11b47285485c5c2c909c63c92b1a4e9db092dcfaa0e0f576a1f960636ec4b4eb0f0cab1b338076f9c2e7a66d15f0b69da3976ce12ca91147780483deaf3a34426aad43f7602ace82a75200fbba22f4776dcd738fda5736a4b5098b5bf76fb611a198deaa5cd90b81ef28d0ab5d3889213cb9f0468311dab9fefefdd514a90a5739bf68d92a692a97b8b4f9616c0cd6ab4dbc4a5de39558a4681a53527cbc071f05a56a167d490b865d851e8245b76889db0a742c16ad3e241d9dea540cff2a007a25c01aaf478ce708c06196868e81600b516bcf459680f5167761273d80d4f6c76575f3d016fb6bf09ed092b1d9dea5685965b6c81bb2bf0984a53237aae8c30c8ae8412b9ba325ed8d32b494b1ae48fd96c454ad5adc8c95d303348adae7c9860c8271b6e93b0f4cf03be1f81c4af6ee70edc2e1ea07b034e6986c2ddb1d00e89af4aa65d36ca36846d7c8485308b869b256604ac36e18dd04d726958c1d423fa355dbdebf8d83f501eaa920d63fab38de03880e1eeab20d677a8b8ba1dfbbf28e606777bd741dfbbf2bb392abcdd7207684d496a22f5aeb3d0ff00dd25ac52eb354bb9b651b1d5a85bc710a56fe907b94c6a634cd3cd3904b4e3aa06acade1b66405c0f509e51af57f04344411609737380774b6b9f1e806dd18061a463a6ca56b71175956067dd4cd8a55dafe43b64d8622dd5e5dd55a2aad714af6228b99a5523359b69ce23973c027b50c5b2fd77e6e539ee4a5d59d9235f4e1be0af28d603c48b186cdcde394da3556ade314d4a3ecce360a558d63873f1006787faa707c7650b0272f97164ed71c83b79ace608f28f146da69dce90038dcaebe62910ba1f587ce61e6f109a8a94af841dd46a7546d474270554caa5b74df3b93049deb87c0c5b0dd16817c3cb6ba1182df052d0d6a0b5b1edfb8b42e80e5e38394f2c7cdccde9e4a3d06743815003fa8753da9635155fc308633b387baa40afdd6a5b1b086ee770998cbcdbdd2c84e36ca0ed234ed9b9234274f4941cc84aa7b4fd137a154d6b66b05b4080f913f8469b184eaa84c92b9be247e546d6ad3c35718a468c76850b5af40dd6b048c193d816eb407d3068ea8d0067b4090e52e842ea6a2e56e02cd06ec55fcaddd6d29eadd43cdb24c08eb9d0b5ed27c1340c9affa7807730efcabc0206a10c68f40ba2f702d562a6f98ce7f55cf7b026ab00fe127a315f401c134e8222e5a6c6ee3e6ae10569ad3f30b73e092858ea2be48d85ed04e37ef52081b77c46cf138b707b9285eac7c7d95e327cd2e05887195ee1badc07ed1af399df7153a1668b5234fee0a16014cd42d23a859f382d3d4d7369ed0bbe425ab15b5f191b91eea3d27a2aaef11b06c47ba5909a80add7e0742afe9bca2ddabf9faec97d3b791d0d5f324f4a56adc38b4f3311e90a82963dd5e278a3de6d8e9a4e46e7f8fbab418d8f81dc042c20cadcfeedc77a9f55af57d874fb226068002e4ea84cf305cde8c8fad9fb93c0024a95a0ccb736b37dbbd6e051354f19e38739c269ca1ac3b5b7c4c34921a7bc279c8d63ba878a724bd1c7f2b706a8d71b9cb21fd47f29b06826dba677ee29e4303974acc7f7155850f53a225c7ea2b2d25415658246f52542d2c2e8a98f6aad8e9d5b74ce8912b8647682a146bd31a2b4744c887da3380128d7353e991fa9a00ed5ba35481a9e481dfa8ede2a36b717cd1bc670480e77704a6c6aafd64d7b7a8e89e0572e5790ad21b08a7d50c0dc6d95a3599f146f2656f282a90acb6cb4ce6c837ed58cd69d2d710064f625c2a57436a9e79be5fa29ce89a0f8ab652e76de6ab28d6517dd301e318dfa2d6a06a7444d1c44b090373b2cc01b47716be43832524e4f2efd16c878bf716e3654d073b00ddb9f1e8af2291e338b511a49794f4e62b28ad574eeb06cc00092c4eadb53a5b9e227c106576d1a5cb5dea982ed49620474d925a01d7d88038014ad085bd46e030090bab422e3af9b979798fb949422ae93c87a38fba583559bb524a47ea2a906ab8eb1bc9fbb28d2a6ed5a50039c234c9975381b235b43b806a352a84abd45f2dd94ba31b7f0b35fb258b94f772fa946988bc70c9dcc64c6d9e6f4292d6e24acda64370ec6ea169875c3200c146b0e18dc5a374681d6acb424d072eac046e9742897493eec357514d3ed4e3d16e022bb99acc6512056aa670460f927814fd49a4247e397a7551b4347d1d4a63a70d77725006b6b32ef54d21962b633ed4d80ddd2dce9361e4ba342168b40b9afcfaa9da1a57f97dbf487206709031f8b865f35e486f69ec59a1235bc367c4cc85a0d5b2c0e73536812345cbd84a9507a5b64b1b725c7feaa76045b7543c1c64a388e7d58e87513b19c95db8cd4a32e52387daf3ff00451b0f816abe71fde7f2b64660ba1a6791b953b0483194cecec971d3cd5ef445b5ce7e0f82cc3daf4e682b27231189d661352938015a744c6a7c3ce1687b9b239bdc7a22f431e89b1da1b1b76c74014baedb831e1725e860496a080a3cc6a26e15c70baf98156bbeab6b5a7255b0318d71c4e937119ef096c0c56f9595331dda485489e22e0e1db9e72e61ef559062d96de1b4606084d60c4949a02168ec51a311b3d9616f72a68c57aeb59137a108d658a35df520cf54953b15bbadc3986c90b239a7216978e6e8a9ae8c6efa629616b416919c6525a31608b55f2ed94b20c435df5df665360c51752dd9ae0707c573e2ecca4d56e8a4c83db9431a6e95e2db9d819ee1d553966adb73d704b3aab954a6eba97e6069ce09c7a258d5eaed5ac100713b900aa1754ca7ac1f301086276ed7f686f5ec53a457b871ab47d775ed51c2370d492f38cf82791acd2ec7055393e2c36eb69960c0f257867947e23b4bba9de3901c7335ddddab0469dc3bd41f3e92389c77e503f08523cffc7fd18592e40f14b68acd74bea97c4fc059a9d6e9a5f892e70c13e0a921979b55d0391605c69bf4852e81aad872a215cbe52eca9a147b93dc3a2a40aecb56e4f495f0949eaa74a5454c72b35b134c8f646ab005dff49c0dd6e8aa0baf0e0e2d7796e8d2585df6d6248bedf349a168e145708701e71ff54dadc7a434f5f44c3ee3e1e892b4eddaa58dd829536336d59737870e4dff00d16e1568d371bdd18247725c03aa496f5d966046d7d79212e057dd1e5fbaec94275c4630b4202e2d1be51684553da5ae04faa9e81d4b034e40f25a505789f91a479a6c081b310f393de9ccb2548706fda8d03b4fccec6e94266ae438d9281749723cbc8ee8765309fb1410b372464a5090b9534720c646138526aed5c8ec37a652e81b50472fda8d0898c073b0ff0025a134344529dc11deb38ae6c3834745d061747a6e088b4eb5aa37a530f7f8633b5579a634ea268e89358441a6def3f603d4268d7a0386fc3a2d0d739bdc56436b6ab75b80c63c93159f697d301efc0ecdd7399e85d1748191631d364968592260c7e543ae81ba89b650d0addeeefca174730321d6bc492ccfaaebe606475bad5f33b977c12a9603add245dbe7c54a85a2db60601be16f230bb872346d85d30628f7bd481bd165a3140bc7137071e8b9ad18a55db5939fda9f4d8ac54d5177694697115574049ea889d843a2dbaa7c2e3e8eaf04286af8bae9bd4c476acd18b5cd5f96e72ab0629b74b87ddd5564188caba8cf6ae6b0ca8deade4eea74a81a2bd984e32a908bd59b5bf301929cab1515cc3882539f456a9be623033b2a4601b05e476945090bc4648ce7b14c8ade85a72dabce7b51857a8ad6ee78baf6243c8a3df60cbf0a9ca896d397ff0094dc1576b20f881b909c1d87629d2abbc1ca4226033b6c92d3c5878eba4fe6ef8ec49a2bca35fa439643d89a274452c7f2cec574c8658acdc412c384581b4690d78246851e82e4f981c286001708f6469aabd5d6cc857e495569ecc9ea74c9b400a74b1d1004ad889d537bf94cca15866d77132b398ffd90d57eff00660fddbb1ea8684b75d39406fa2cc2a563b2f3381071d0ec9b1ad7b444640ebd9859637016b0d54637295302d297d13bba76ab611b5d9e10c60ce166053759dd73280364b803bdd9684b810b5555bec134a065aeac9ebff44f02ababef84038f1092d03b413b9d873e5ba8da16db3698e57389f1289d159b6b09f33160efc2ace824ec1a7b906fe6b2f665aa183651bf4066a0e3a2e9d0720b877a340a76e39948037487ae4a5094a3bb607294d4243e7070c76a8da02de20f96d046fe5bad9406a7b3fcd01c363ecab011536b7467a950e697123435840ed56bd1b059bb64a86b1ca894e365d3cd2ac7a334cfce9037bf0a1edaf48e93e12885a1ce00e7056fe8c6894f006b0379404ded879b00053fb32a1c27a6265395bd533718630d695c3dd0f9d5d851810177be00ad390a55e2f4485d5cf3819fde6d5ce775d3280749a62369ce3f08bdc05dc6a034602e7ebeb02a377d46e1d0a69d053ef1a8a43da9e7614dbadc9c52dec2ab718495cd7a36a1270ba236b8e8d5625434922a62781ea5c8c2a12a494b63a12163ae20a85875a2d77c25dca4a6e59515ababb07f2bab9a4a81a7ba9254ec69e9e6254ac0abdf2d79391d8a410f62ad3f331e898347b754918dd39a9ed5f50e310427558d2a65f9adce7190811b4574786b73dc8510d471863b9bd51506e5a16ea1f0eddc424a6c46496e7179cf795b1a22e540047d3b15b5b8c0b8854ee2edfbd4d83b87ef11b8177820f1ab5ce95b51192d19db1deb30579838a1a54c65c40ed29a4232c7547615d20d3583ff003bd684ad8af1231db9dbdb652b0364d35afdbca038a950b38bfb5ea7218a92bc615e04157d582b4a8a9ebc29d0af5d35106ee4a7a1956bcd61f33ed69edc250d4f87f6b2ea1e6f0f540c40cb51cb9e6f10b3198ae365cc8709b598b3da6efcae683e48d36362d35380de6f04da6466acb17cddc78858d0da0f4e3a23bf7e536b1a6c75aec2342b979a62e7e565a0553c6a5682dd48dc2400eada00d928571962e67e5c36fc2d813f474ed8f66aac09e6d4e1be892f219bdcacc5d51cde3952b0ab63e976dbb80498d8553c471badc561ba9a62e5b29034b4c55630753c279309c154f4056032eb73b9b2b7a870f2c32076cb96c0b15a67e6fd5e5bad8160a6a103f4ae994236ff0007451a6a9ab6b63e400e12a7415c22603b2d88d435c2b00fc2b256366e08d192e69f10579fdf2de63d711c63e5b73dca523ab9013c2bb788db086055a85573848ffeb149d555ac57d4632b93a0af57dcf09790a8ddae04aece6057e59c76956d006a6b9ab4226aaf78ec50eb9a159bc5c32b9efce853ebe51deba702bb73a81deb702ab5d5892842565502a58cd44551dd76436be61c8568cc45dc25c2a1302b6a90544d4d665d84f61a54b5051f6faa858ac31056f2bf3e2920a97a9a412ee4a7953a8ca7b28056da63b5148076a95a014906414814ca5a02d989f14c1a1dbe1cfe1669a8cb952f30c2353a93d3d6568c1db28d11397598eddc8d53fe2ab78af206108e360e095493160fe765866892c0d0495adc095cde661184dad627c42b5608f349ac88ca9b796c6081d88d51a270b6b1df288778f55ba107c40d20260edbbca6953af217102cbf266e5f1c2e9898089a36ff00cc2a403db4e12507e0948e8a560592d1a99cd1badc5530fd52484044d4ea6216d2a12e3aac8530a26a0d485c08256c2c566c9485f277ee9948f55e81772d272f820f2289acede5c486f9ecb70fe54eb0523fe710e07b0296b2f2bbc9a79bced3ea8d2e34dd3acdb97c82cd2ad748c68db659ac4bd351b5dd309341e34a02a4a11d534e319596842893752b42bda8af6f68d814c156b6ea695eec60f54a1aa5b9998812375b020ee2d70946338c8568167bbb792207c02ade42ab2550c73295e4a4c37b2a7e5b0e8ba925662b1f0bb10a108f9d70558c2e0bc9e8a9a058bd90941515e574587266bc2e6b0186ddc8feea6053359b9bd13e82cea432019486a3a2b9e12a75d75c4929a54d1d78948c7985585c7a5fe1de2e66b7d14fbe5b23d59351e236f90529caf013a9d75f3cb693f42b3a4ec50385d541b22958568b75ba8cae5e8d155adae472d425755657672653af75c42968564dcce7aabf3403abb96cba79e6057ab6ea557f3815eb957295e48a95caa8f7a8d810f2b8952a9da0e6892300d53805694f1c69d95655a2b7a86a300954d2d8ae592e25ce211a95483ede4c994f7a4e2cf4d0903d14ad5a21ee5447fd549a36cb55818ede8b3424e283feab6f4005c3653bd0376f6e42cf40d0b50e64fe82568a870905152c1b213a32cedc38652e88b8d4c21ccf446a9141a8b5e65c78aa15b670e29c3598ff00b21b89fb9828ad4b5bf059ba9da6c63fc57a801cdc0ed4bac4c69fb407c2d711d9da9b4f125474a19b37fe89f5b56cb4e98e7193dc53275e5af881e133db2ba6036193d3656952c79be8aab0e70c7438549462c14eed938c194d1e52e8c49434c935475cd4be822ae522d2aaf5f326c0ac5c5cb30b05e86879a4f558a47a534dd1ff00471e08d3ca16b29dac3bfe775be8fe9f525a584f3340efe8a7acbd18abb49072974bab5e97193f849a54e5450bb9b6ca5d6272cd196a9c0edd6e5cad3956815a7ea2c9c0dc2024f9c6329418aca76b99d1300762b0372761ec9427e3a60005b00b652b4b81d95a0466b070e5d9746850d8e3849694a7372a1d56c2e21852f4ac10232a10872280ab461b90270591b2cd0eb2256bd1cee54ad04f2a9da1dfa70b01ea58d2dada23e62c2d1514dbad850f7d76c3cc2b42bd59f0d6cfe9b7d13741eae922cb5be4a50f299346ba5ba7e1a70b97bedaf38691d4187ab7510abb49a832171746880afbd94bcaa88a9be95d30cafdc6e40a2f2557e6a800ac97001a9aed9579ee840d64eadfad081b8ce026bd32abb5752d2b9af64a8f96a5a173ded357ee97e0113a2a329abcbcab4aa7299116cab2ba6206ef4b9d93e8b01d96c21aeca35cdd27cd2a5f494151c4536ab015c64ec4b4e8581c79bd5205d29e0fb54e8075f6fc84942b72cdc870b40fa5933ba7813546490b057262509d042b5c0a045bac574246e8523af8073f32a4662e9a46b0e13c32f113b2374b5b8339f0d5cf6b550d51a604b8dbc566b209b7d296b430766cb4e21b41f7642a8aba691bb8cf29f2f34da9d4a711b42455148e0002e20f89592b71f9dbc55e153a9647100e0927a615e518a451c9855d18978e44b460e86a973e943d555acd083ae955e150356c5d3204254c1d52d099e1d5a1c65d82950f47e96a57000151b468fd51a7c3b1eea77a66a2ed7135a71e8a8cd7d78b944d38711ddeab0da9dd1f00276f31e4a54c9cb94fcae4ad1d64aae6ca2310fac1e034ab408cd2b67cb727cd6d09a74606cb01c9e9fec4022c4ec1480e5c6b719c7626805599c5d193dcab02b77daa27629a50837428b4a535aa1dd6c2c35725aac75a56c21d864568c2246aa687620941e0d53f4771cd5ba0b8d81682df1240e4486d3ad294b44c116eb6037738fa79856857ac7e1ce2c44df459d54dea16d76037c92ca34a15a153d36538275c9f4a778ce0afe4395d76a713945aaf231e8b96c560b96e5b6c729b9e4c89aaab2ba79e59aad5dee440ca7c6ab32ea7df0a5d400e7d41b2c81075ba8d3c0addd352923a27b59a8237627a82b9e96a22f17c3d0029312096eb7ba4ec2b642acf41a7795752907ba3c27747351558dc9456755ca261054ab9aa463a7394a51ae6ec9e532b770a43cca9aa4071c3f72dd878b4d1cbb28b47360c8417559be69ae672cc6246df61e56adf2cd48d3421bb2ca5a4d6e30a762788413e5d8c2d868b8d9ed9b65562d0f5ecf2b5524225b42d49c6e8b0cd4a9a90ff0065cfd1b46329b2b97a8d2e5a5002b40126a518ca608dabacdb09f41bb1d561d9f15ba1b369c01cc04f779852b4cca38e3c2c15513c803605db0ee4f295f9dfaba80c354623d8797d95a502c3376a7843ad0b3081aa0a6c36a3657a668174698c89ac8b2425856c9c11d379901c2dd0d6aa61e49c371b6547a0b5d6da039a3c97350acd3e8671939ba2c0a9eade14bdd2730cf5056069ba1747f2300edc0f34b809d59613cf94b80ce98a52dc8ec563a3aed6acbcee808ca8bbfc9610025081b26b032485a476f54686814cccb709690fc166e5dd20313d849c95494256d741c901c9ef2a92867973accbcfa85594017b764f28361c9682c394ec0581953c071a16c80eaac0f815b41785c20b11260eb234da0e10b41a74a854b8a54152103b284a86ba767985a58f5ffc3a517f41be8ad699e88929f6185cf4819ccc256c2e3996ab1e3ca972aa715faebbf21598ac3b6cd643b4aaf3c8d4fd25edae5d3cf250977a6e61809ec6eaad36907e73eab9ba834c4fa74853622e7d344f6201b66921da12eb340d5d9183b121755da9d3ec27a269134a505a1ac1b04f216d26772a9e00a94eb4a8d7d364a5adb5236ca11951a953f5386a186a19b28319a8a6ca5f4745be9f74bec2629a9f64d2b346c4c3854618a9a6703ba7919a3a88642a615177aa770079544c83b2b9dcf8774498316034c06f848d913165bb35c71d3b139e2624a2e6eaaf2913fa7a998cec45a65de9e6d94687195f83d542c369e958e721a54870ddd3684554c20acd0044982b74352d1f5a7e580942e16d0c31bc3bf8b87e13c65afce7f88cd03c95524a074739de0ad0ac66cd585c33dc70a90b4754127a2a627a1db4a5318bff000d40d0cfa6c263229f49995adef214ccf5af01744f2f2b88ecca4b4345d4b648c49cd81949411434b93e0a20c4b54c0ec0f25a05496d0e097039a7e121e42302c172b7b4b327fee97028952e6b4903c5570ea5d64e7989f153073e8848370a741aa7d24d69e668c24d096a4a62d2a844d36b81d92503a188745b020353dc393ec07aaa40a1be1fb89f54b2820f457941a0c5407430ac05b429603ec09a4070c69e020b16d0743170e02be4ad05f22010f0b743818b4e7035051948d432bea98b38f3082bd77c00931037d11a1e8ca5b834019ee4a405595a0a0d0cc1284cac7902a46cb61548d42ddd521b14e353ca55a368ea0d545a55254aad341ac7c552d6eac549ac9a7a90a1d51a5d45c5aee8428b741ba540d7d2c630931240dc2d99400b1e9e4d198726b09568311a74d9ee281207934d9ee5b29c28d3a41e8969d2943a7fc1468c72e1a63c16eb31122c05bd895a8cbab7902408aa094392604ec6cd9581da40729e52e0eaa83215252e23e9c3b38c279d0c4c7f87870c153111cfd3ad69c8dcac5240b70a4fb4a4ad33a3a881254ed6344961c302a4e824b4fd17361369571a7a0c04b68445d086ee4a4a5d48e8fbb890900e7b3bd66282abda3988460093526cb0206e30e0efde80d6342c2d310dd643a4aeaf737a0dba2784619f127a27346f931fb49e9bf456943c096687941fff00270fcaa4226a2955f49892a58d6698ba91dcb346027d2a5d3226dd47cd54c6e3f73467d514cf7b69fb59828a273475683e3d14ed0ceeeba9e57540610719c240d32c76dfb478840725d0ede6e63e6a7a063289a36f44c0edb68580e5010fab6e38e9b8406733d464a5d381bac008d92e82ec5061bba9049534b92b30115d543b4e0aa90f69f803dc902d1f20337590335d7155cd22708288249010e8d56038ca754d0758c47a0ebd8b3414188d0f937a0fb951e81e88ae7b00b6b16070b500830a5d0472260fb9100fc2100b73fa798407b0380d4ffeccdf44a1b53e1d8264e852c45343d1652fa5a3c8752ed95e42628fa8a4dd3c328b5926e9b59403e63959e91aeb6e0476a7f467cdb9bbb0953b42e9a6ea5c5b9252c0b2c55d809e07c2e0b6c03e97054e848d3c4111b83a1a6055251874d1b7b9057cda36f7276913db5b9e812552130db867a2953e3e7d003d8974b8067b403d898aa56add1c4b4a18cf61d34e69598165a28b1d56a983be401bfe505c36fac0167a2e02a0d44c2fc63c16eb31621b8d954b0cd3d360ee9d680ef510e43eaa35b6227483f73e6a148d263a7e660493a627f4fd2f2e15652ac35f521ad4d59aa85f6cee95a71e3e690a5f0d34bbe22739ed5d38aad535110e2e292c037e8f2ce6eedd2865dadf5635bb771c202e3c38d59fd307b144357b75e5b20036db75494aa7f1fea9b250ba303f691f85581f9bba8ad1f29e1bde5c7f2a90a6628d535b893a38f3fd92e9b05b6d78ea8d686aa852e9b12da0b4d7cca963b1fb9bfdd352bf4027a20ca08811fb47f651b432f96ced74c1d819f2440b57d688f191dc13813513f33723cd738556aeb77c2dd08cacbb1677a608faaba738dd66857676ed85cfa742d4c441dfcd6e8134571cf9744f81334cd4d200357a6def3b2622c1a7b4fb9aa7408d52f2c8f2a61955754739caa40e08d36021a1303e02c04809341c0c4fa0b7b11a0c059a0e06a341c11ac02237acc07309743994a1d0c4e0b0c402e26a03e7c5d3cc203d99c0487fd9479041ab5674fb84c992f954fa341749385cd6ab1e3ba976cbaa7d092285a964dcaa4eb558a2d43d34e753a8f99eb6fc92b0c1914d4c1d68a3e6282afb6b8795ab759828bb28f4c75855b4c9ba097649684843324d090a69d3016d9729b43e7396e8704ab341c7cab2b4d895230dbe5c20086d1870440a7ea3b000530566ae8080969ce471fdbba95089af87b11022e8ec479b3eaab02e16da3776adec252a231cbff995cf0330d55707f391baede40cd1c0ade8355b31d829f94969a5a96823d02d9c84edc28816029bc847d3000ad9c85868583b13d3175383b2e7a15eb9d6b80e51e492067daaf48f38e6c75dd5e017a76dc591728ebd125855e744534a339070a74c3f51d8dd20e570db75ad7873e242c9f26a703bd3e999fd1c9f6fb2c654851ca9e269382b32105802eafd952551b0701ac81ee6bfb882969decab9461d4ed67700a36856e8f4e61dcd859a01ea2b393b84da1176bad1cfc87c947aa12155646f5efdd67342bd78b43485d7c9152ab6358b3a815cbad5003212d3ab905517bb07c9204f5353b1bb20260c679764f024e825d92d21fabab701b29d085d4d584c783dc960675130025520141a9c1a0d4ba0a3d52e038c5806450a63bb2532cd011f02505c502507f9539092d403c0a03eca014d2903e0a901e84ada05c51671e61483d83c1418a66f90560d4fe5e70a7415353a4a70dce429581e49a9e88f38141d4acdcfaabf06d67d58e5d3cd28073d754b3198f99164ae3b1ab7e9db6e12b316590e14ed6186bf749a5c2db22e8d6a5e85c934242372c0320916e81ad7a6d073e62cf40a056e829c56c05653d80db8ae7a05505460ac9d03975b7072aca15da9b18587415cedf8e8b302b5550ee8c094b6b8772609b0f1cab7b011b2e54640afdff004e672ff55d7c84769b8b19f34bd50d12cb53d024f6924dd40ee7077ec3de9bd858af5a8088c0f003c51ec05b555170ca6f6161a2a9c02b6f4641cd7cfea10a3684ad2b03baac06ef5100d54814eb2dd3fda037b33855b136fb146d118c01d0150a60d1d4873b71e0a6d95e1ef8c1b38155cc3bf2b74cf3ec2fdd3c60b865dd522752b0938d906335ac384291eb3f860d1fcd0737aa5b5adf994f83cbdca54172c800c2c0aaea0d42d66c71dcb7429746d265e61e6a1d50b77cdcb774dc054aecff00f55dfc114aba45ba6ea056aba9483bae7a72e8ad809d94e83b5d6520f36761ba201d64ba871e5eed93858cb001b2291216b8b986e14e852b57bf191e696052c00a901c0eec4da127fe139667d528449ea80719d5660484451a738f5811f33500e533d2e07d239310961403cc280f9e5602e172405909c1e8dd85a0540ece3cc250f66703e3ff00641e415434ea36e0f829d0727725385ca5c0f1ed549b2f4afcc9aa1ea3aadfdd72f519e941ae76ea57a36a35fd56cecc94b4d2e5575b8ba5b5bcad53ac3ef9d4eb30c3e449851346cdd7504ed3ca1202d8e481210270263996d02592a950587a781c322e890106a13761c32e171774154e54bd04ad3d4ed855e7a07db459563ab17da6dd3855ea216e500aa2832520173bb071e89ba0362a1c0ca480cd53416f2ae90add5dbf93750ee848da2523fbae3d2355d2ee6b9bbadf41f5d2dc09ce3c16e872d3080709bd03fa8de1adf455f419bd0ea5067e5cf6add0d0292e40103c96819798c967a2d819bdaa3ff6b68f1ff55d16a4f44d344791a3c0285316da4df214daf2d7c5068b748e7c806c0656e19e336c9895cc3df8562da968da3212913d6c70c2148761a70e3eab3558f6f7c305206d3907b9358c69f554ff007120295086b9531dcac0c8b5ad92673f2d07191ecb702f9a46d0d1100e1be079e54fa8055d687b1a167219d6a584b1777348a2c9559723aa0cdd2989e8a3401a18dc0a984e4d92c23c10159b7d1398f27c55206816b8b99a8a13f494b86fa12a74328d5559fd423c4a5815c2a901c6159a0fb6b1dd16837c880fb953603cd25474e380384c03bc201b7316e07d1b5603f14480e96a01258b01c6314c873097414077a780551ca323cc2ac0f67f044ffb2fa05a17d6551ca014ea8498720b91e43c815e765e975d39941d411efeeb87ba4b545ad628e379a069e3c94f3874c5b6cb458093554af320b8f9f32dc63e648b70b82a090aab0752cc92848c322c0359326029af45071b3a95079bb2af21d74cbab98098dab3b0ebdb95e7760fb5ca00b1b2a7213967abcede8bae1d1b7cb7eea902a35f6d011407a1660a90483e932e053d094929fedc22043b9b82ae015c8876cb9bb0451c0a3e089db65d8b4e32b7c05cdd712583016f80ae477193ea00ecfc26f016fbd5273c7bf68c29867f41c396b65f984f5394f02e94f621ce3d15027751d106443c9605334e69f6baa03fc729f506d774a80d8db8ee1e092991d4b7d1d36ec5ad4771234a89a9247637e527f09e433f2ff5ae9d3155c87b9cef0098845be405b9f44813500c2c5a2634bc797e3c562b1ee8e005286c1e8ad48b35feeef04f20ff00552b01ca4a83f289775ebbecb302bb3d5f36701307291ce38d9677001d417b7308002948144d5b722e0ba21144921c6feaa7d501a9ae24f5f25806521c953a064c40440329e85ae1f954092b4c803837d1350b856b1ad667ff0089f053a1e78d4f51fd723c4a5809646a903bc98481cdc26d0e0913480b0983af72e738b64c709b410e726c0f9c56838d725053501f72a03ee4580e3029521cf96a7a045be005c0395390b155e9a6b402def076dd74c0f4ef06ea08a603c02c0d043ce1004425073e501e3dae8721746b97148d43125adc506e32eff8486c3967a5fbb2832e54f4fb2862a6a718096c2809245ac3b4722dd28f6cc9e08229e44f14895a7aa4f451714ca753a3048a46381c981c150ab2871f2655e5369f8e449dd1a53265c3d14ec4f4bc838e91757300cb5d4e1cbb02cb250f3333eaa3d051eed4049d94ba6e99a4b41ed501a9216b210c3ada759e42a5a8a8dd9385d1ccc08ab4db9dbe575f36604d470e1726948109276f35a168a5bc61b83e4b300fa0a969dfd518167825e7cf92532b757766b1c420262c5562420a026357309880080a75932c901534f165d497e2f6868f01b26185e90d252191ae276ea9e0c683a9406c2e69ebca42a418fcf5f88eb1b585ce03b72b46312b54fb11e486a769aad6289fd171e661e6106d7b6b85174f970e31d89a85ef4fd4b4bc92146968ad474996fdbf8d9632aaf68b690edf64c54e8a118d94d556750520ed4c19b6a2a4cf4440a0ddab033629c04b25c1b21381e09083e9a121c500f5652f39cf72025695c718403b64b7174e3cd3858789b5ff002e21e584a184544dccfcfaa5c024bb0943bf3121dc25382085a0e34a705b0240779b0804732016c72016d725d079a11a0b6047a0f9ec47a0ec413548e39ab9ec343903f056f2d8b2d86bb719ef1d775d5c99ea8e1800611e41205e1b1200d6311a0a6b51a1e4a11655b52c67babdd87612e9b14292005cb342c5414200ca34d8988a71848d455c6a426c2235af4601748d4b851ed4410453bd522906c6f4f45174f329d4e8e86445863e5ca5415ccb650758f54959ae9725b469d2173d695f3137303ef9abab90229e7c154d0bfdba4e687d125a15ef9433bf7a95a345d45000dc8531a0a069c6e9e406a16e4ae9e7901aaed19712535e7022e5806e028deb022aed1103651d18ed8893d538c48d5b0aa4092b447909f02e7639700e7c9442a5ae982305e7cd603bc33d40c78d88f740685798bed4053268f74a6c218493ec98635ad34488da7c138c52f889799398804e1031e56f890a7fe87376ec9db8f3950c3bfb20a9aa5a5426b370b4e6a80f1010cd7ba343d9c728dbb02cabacf55188c28d2d762bae46fbac65425c67767ed4c54d5b6ab037ee4aaa95aeee9d709833065c8e77440a7ea8a7e672705e8fb70667212113b55134e4a009a0a7d9008fa67650163d2b467e684da10fc7caae560f44a18e518cefe48030959808794b877cc91681ae89008e54075ae4028a03ee5402d8d4075a14f01e6b9180eb0a303e7bd180ec6d55a91c2d51b0d1d646b646c4a5a23dc79857867ac3856d3f207904b42ff4d2ee92849c4a7683f1c493d078e679b01746867faa8e4ad0addba9b75bacd4df3616b01cd3ad8646d4395642d394eb6c60ba72a54a298f53821f85ca91483e229a8a2224b53a36208a611cca560298e4276896393630a2565e59aeb5ca761b499026914258e5780446dca02f9607fd98f44b80ed5d937cfaa313a3db43f6acc6226bd98053c551167ade69318569d604a5fc62338eb84bd74147b3c649395cdd4d026eec018b246e2972ea8f96fc63c138c59a3bb7337f29c6272cf5db7e13e8c59adfbff75cec41710a8fe745f2fd3c50101c32d106139dfae501b2554f9663c10148afaa21c9f0e90b45b0c9fdd305f692e5c8d0c1e480aaead90677f340799fe228661d939b5e67a718412a4e1aa2021258784871579f11fdd04c7b9b4bde880d03b825ae95ea4b67cd683eaa559547d413989c7af72c2d39a72ea5c0e7cd3140dfb55f2ec3c92aaa65dafa5e982a35832881175355ca9c176caaca420980fdc80916d7e0a02628eaf98202d562870e05668673f111397019f05a194db5ff006fa040125c9b03ae2b4ee42c53a0636553a1d2e4ba1c5505a03e0500a73b08072155c075ec4640ee11903ec2320174e149212d0b30d0a5b21a25b4eb72ef509e35eb0e1a6d4e07804b42e10049424d8f5307e1a8092c0f1adc3a279433cd49518255212d43d96e8094ccd4ad64c30b74a8d639522c6676ae990b4b84e11630fc2e5cfd146c6146082e062a4520b89351444452d4e8da48c95aa51aea4290949f94b644ca0ab214b8cadbc83bcea779339cd94b8a424841e1e866c14c2ad965b96026c255c6c93fcc08c4d21570602dc2abb73849d91d7f1744daace5afcae6ebac091aca6ce72b675a15e9e8c0ce15e4086af8dc76498751ef366cc9d3c50164b7538e5f60b0249afe51f94684e69cbd839f2c2420305ce94f765605cad74d8404d569018b4203e8038ab05a74edb835604ccd4406e80c6789758e12ec76ca0310e37d57f4067c131b5e796b72b58ef2941167e1b5688e704f7858c7b1b43ead8cb5bd3b3c52559ad506ab635a14ab2a22f9232524e077a52d5589f979c79272a36a6d9ce727cd0aa99a8dc18ec7a260af5556ec88111768f2dca708bd38f20ee908bad1004a00e740d40150e0202eda79bb029432fe3ed217818f05ba198525261be813607084c0e46b70e7a309282cb546829854814ae0b5a0908079d16500e46cc2cf604351e83ec23d07d847b0222d96a457cd4d86821920c2d344d694702ff50b1af5268169110f44a178a6401e8f21c64251e43c817893649211946b9a9d8f915590338b05f8b5d83de553c85ed974cb720a9d81d6566c9a40ec32655e405be45b60390bd42c02db3a4c02a2ab5b805c332603d8536849db5f854a6a919aad4a9437cf444ad70c8af294a122cb41e70ca8531973b097548eb674c78229e3c9caa95274726e80d3f434231f94a54edd9e1010829f28b4132c185cf79323abc1e54dcf38d8afd3c592574cb90c7aa6d60b573f44552f14203920311630b6402a6196aa790234cdb8052bc54d63a2a201eb9ef2a45a6861016c803eacabc3765d1c9282d332b9c55295a1dba84e32a54e89d777530c25c3b8a208f3ad7eab32b893dea90ccd38e6f3f247729c0c2217ec174720f4613529ba6abe57654287a1b8415c5ccca046bb6fad73ce0652d8a45e6d34b866fd7f294545df800775a40d535e1accadd53597ea7ab323d68d405703cab7409a28b2cc14c005452729d92c20fb7cf8dcaa40931585c764509ea2a72429d36aed65847280906b35e36d5f201e89a3594b2ab23d96c6d7329894a0e43696d4274974891b0e46f4b8a1d6a3b2172248098dcba201113d4fb0ec6b939ff4da70cb85d9cff834a63b2b6c1a7846b9e8d2c2a5a571814ad02c6e13ca164d034bfd457943d4fa359888248a6ad14ec2ab19a99861ca2952d4d44a558f0e5e9df6aa73c8653ab23ce7d57473c865559687736477a2f213f6de768dca858127155aac8127048af2010d956d80fc6f50b0162653c02637acc0321725096a6912e81d4f50aa6a30cb948535f3504b1f7d42dd2e1e8e65b68182553a627195872d9026d03a9602ac0f4f0103280bf70be62e1f84a55c6ed6d2560094947cbb149283773672eeba273a643c95a1c308bce3622df4b8dd42dc31c73f653a466badae9cb2220056ba92e5690270355f9e40eb7d572aa75f34d6db30e6dd7177ca913ee80f628632a0b50d1bb099358b4744d0cce13e85c29ab811b25c3aa3c5aa6e6a72077230479aedd6770273df94c65378d03fa007a2240c5e96ca719f555802d4edfd9530a06ae2db2a7607a1b809bc5e89046f9a328073a5522f5576ec0e6ec1ba41585716b88a18f0d19ea02c4e8bb7d499200ef007f0953f4ac575c4038ede89b5494dbc83fdfc169e23cd47dd80b74e920414d08ed65acb9bb2a4624f4e5072f5450b6d251a9d2ea6adb4c411dc904ac9fe2065e9e89a2b1995b87dbe816c6d12234c4afb086d779d09d7d9580fc2161e1e49db0dcc9202a16ae880e80a7d838c7a87319ae48f5d9cc1afa99eb6c1a34bd735834b6a9b4a88250906b365b2859b408fea7aaa4a1eacd0d6d26209d3f4be50db139b523150e11a649d3c496b5e04be9d97472c6637e66e5767302b12d0808ec1aa7a224ae1e825e92cfe0a92848c56ec762bca04456c5b683aeb6a85a0a16f49a04c542b00a8e8d2e0151c5859804c54ab4242381287df4994a0f0b7a5bd330e36851adc3cea459a31d6c28804d3d3aac095a7a55605d5419080b470ea50cdba252b40ab9f232160071b76539002b9b398615e74657be88872cbd361556142ff004c44f4db6cb308a55eb4d739dd1a0dc1610c0ab280b338e765d1cf4166d336f63865eba3ae86250d4b5870d5c3d5189bb7dc43945946d753073774d88d00ea9e51b2531da1bd91da9a1d01aeb51f3465a0a2b632ca327383de95aabf14ad1cf16cb640c16e15659f6fa2b408690ffd550a8fbb3f64d81bdfc3c549f96029511ea2b1300c151b148bb17074441ee4b45653aa385f14ce25c3ff00929d4ea1ee548d8a2f963b36589f966d758f99d9ee4d8a480abeec1a37f25b8783add4e1ece608c39f8a029e112b1670a9187a9eb7eec1454ed5d2d2ed829d62dd0538e5d9216561bc77a32ec7a268bc6736da1763d02d871a685c98b4d4d40eee41ab905014255c9a90a0b69b64242634a2a08ca8f463d0d0bbb94b8ff40936f3dcba2020d31093a069cc53e49aebb65dbcb34ce5658344c12ae7b068b136127951d8ea11e408355b22f217ce125217c9ea9303d8fa3a97110f20a9a962d342774ba6c4a30234ef804dad7812f2dd974f0c67f79a7dd7a1c041416bc949d848d1d9f0579ddd6a59b438ec44ac2e3a4cabca06c7408b43aea151b43e6d0ad0263b7a6071f6e4d804535bd6e0484746a00a750ad07a0814ec030c2b9e9b0a86054661f9697c128c34ca14f18329a815604831b85704d453ec8022cc0e461295a4d0cbf66eb01a926c6cb7a01d8cc95cdd74634f600524e9b015551f31579fd30373837628c2079e9c1dc29842dd1a134a15f7ce01ec54941f8ab7b935eab71210464ae7b46266dadc27e53ab07d4f33765d12255135d56d6ae63a345573745590e84afb79ed456c576b69394e54ab552d555e0b4856903cddabe6febe3c534683902b4223aeccc85590371f87d908681dea1447afec968c31a4f9a8d522ca28f11e54a8aa5dd6f1b90029d2285ad24c47cfde9f14c67f4b2179c63aa6c1885d4ba60b86d94d80669794b19ca7c96605969c2c8ca908225484a88b80c4831de8a9b42b043f60f453a55da961c31232330e235abe614d168ac5269a18e8b62a7869f1dc98b5d1a733d883577fcaa84a90ed2594e911fe4c5ad8547a3f0b9fa58747a700ec52e3fd06e4b1ae880249a6b293a06068f4bca2fa5d18bb396181a1ca6e839fe4b21735696fd2053c8b079f4991dea93903a83481212de4349e1158cb65f551bc87aa6cadc46146c53ca7e869d4ab312b1c28857442ab231f9f3739365d120552a21c9558d944505b80ec45324e1a21dca5602a7b7e5508e436fc24a06b68d2e83828d682fe8c2e8853b0d28548628d122b444546a74c263a450b0850a449601315224c07a5a45be41ca5a547902a6816e0263a45b8040a64c0a14c97a86d3ff489241a3ed36b24ecba27217465296b7753ea07d030382cf4572588059a11d50100154d4862d0a83f5035d2720f257d2a6e9e9dd8dbcd4ab711d72037d906d647a8a77894e3bd36193da526e6ea9faed9abacd072b57275d0d314d5fba9ced9ab353c9b2bcec287a8d9273f6a2422674d529ea53c80fdeb032b308a6541e6056919b7126a031a4aa45a3cef789799c5de2ab17819d2266da6a6665212b75e03509fb7cc2911ed1b7d2910b7c8243c15535a0308f0c2cc6daa3be8b3923c4a54ed50755ef967a268de281d296968d9c3b7d55e2b56cbcd045cbb63a26ae3e942acb7b5a738dbaa9d1c8fb5f2bc9c25ab3e929c8254e802da125e0a205e281f8681e4a8176a077345e8a4caa6dea87aacf24474745e0a9203f1dbc26d3c285bf093634d8a246c078db91e83ada047a07594414f0e51a208c069d6f1dc8c07db6a08c05b6d43b93c21cff0a1dca9016db38ee4a0eb6c63b94e8131e9e1dc9a7677c74c03d89bd848d2698681d153f40b168eb135afce16fe9035eb545b2e209fa366101251b900b6b901f9df5bbaedc481c16cca690c968ed7e08b06886dbd2e0d2cd2a9d07a3a1f049683ceb72c0547409a5073fc3cabc4ca8687c150c24db90d94e476f53a616ca05b631f0a053b01c6d02cc078d026c0547428f20a6d1acc02a2a34b805b6deb01d342abd42ebb0d0e52483571d376b6b46f85d520d7dac26019f6fe14ba83513a4e425bbaf374c967b0929e501e4a0dd520455eed808fc2a40a351694c4dcdeab3598b5b323fb2d683adb61394d02877ad2e39b2574486d3f66b2f2ae5ea25a9e91d9185cdd72cd53eeb70e4914fc8d592c77cce15241ab132d81fb9f35d321835c006744f200ce8c3c22c622aeb6d6b2327cd4e8c796b8d17c3fa7cd5617590d23f230ab0f3a3e5898de8cb59ba466bd2bc00a1c341f2526bd554f77c4606dd31dc91a06e12e5a7084ef48cb5bce0edde9710bdb3abf102527cd3c7570839af65a761b278ad2e7d404b56b9ba055f584b3a251c91a3ea4b5c4159545e21a66b94e8224b7e1c36440b0d15b7654ff008163a2d861439fe911973a2caebe7925086dfe09ba9823915095cbd539e16f51f34e6bfc2d1e68106913e075b428c0e3a89530e5368918054767db38460220a3df08c0705124842c51270799469a812ca64940ba7a4ca9e1c5328fc12d8065352654f4266db4e01e8b3d05eaceed95f0276986c8c036328c05828c0fcf361e72bb6d4935416cc25d224e3a246b34a14898de8e328573d8a096512507d94c8901d8a9952402a2b667aaac49c7db7c13c310ea045688868ca43086d32d05b69025077e88224077e8c2ac8087d320122914e83f4f46a6060a353d075b4aa9d745c2d94c96518e55b9c175f34624a9298b9b83f9dd2f746272dd6d0d0bcbf260b74aa0d4f2046b6ec08c27803d5372152044b28f75986c1d1d3a629eaca7c057e429d72a6df2accd43cafe559784c3c956a7f98562e76f73dc96fcc2534ed99cd29670177a4a82364fe4e88d4b4e719f546040db35272b80494604d71772e8dc41ec52adc791b5edd79e4737d15622ac5233a0558c1a026347d4341977aa43c8f5d7c3fd9bfa5e8b9ced76a2c8e78c04d026edb6de467dde5bad47a45deab035a797c50e6b1856acbee243eab6bb38a02db373a4ae8481a1588530c6fdd8f44cde45cf438dfd515a76cb79c3b054e85c296a0170f4440b53d9f6854ff8045134a84985b0fcb4b9579de12c35f4a9af7a243d1c0a5669e425d4d9549c99d144b7c827e9534e00982953780e4f40a272451234256067d98468082851a0fb28173c23efa05580e328538131db52019052e1530e7c5324b00ba7a552bc849d353a4f0163b6929f02c346c4601ec6a301cf965181e0bb25a775d3ae75a9b43b29dac3d152a2529c6d0aac614da152749e6d12cc0799469e40220a154c02d8c4b114ed8edad7754ed582f5a5e26b3231d3286a8d2d28ec494ce7d215a677e414a0b0c29a50204055650e7d32d05369143a0261a651a04fd3a8da0e36996f54cf994cb39a30afa0df75ddcd1894b5d38ce12f5462c8db728e31157cb3b485981566d9f0ef0431235348005a15db8d4b58ab870f6db9b5c5661713f7183ed4fc97556b852ecaf0aa8dca2dd5f5a4c5419080fa4a00ddd4faa0e50d7051d0664ae21e9824ae2e2e6fa20332b9523c4beea54e1ae1583e43f98f610a54cf2c6a98ff00ace3e24a788588967505561048ce53362734690e9307bc048bc7b53835401b1e07705cec695038b4a680abbd4111125692c65b74bdf36479854912b199de6d9cef2b29b8376f8f93fb28575ac94ef05621d106906533791791d1356876da067214e84dda5a4382205fe9865a15204851c693a87c14602b93aeb09613f48b79eb4485368977727c39f4785be8a71b4a8f40dfd22b4e80986956de81668d71699d75bd00914d8d900e8a6468151c0a508fbe42ac05081501d6a01f8a359e8e2a18167a03a3a54ba1214b4c8099a08374058e9e90e160194d4c500618901e2ba6b761248e3891644ba398ac3b0c5e09eb70f32052b41e8e953489413152aac8bc3a2913f950f4546b3c821f445616a4edc31fdd0e6a94abaee66fe14fae8dca124b7a87a74c25b0aebc4cb14c9b0f0e0a4596329c6d2a95842cd2653eb6d2e1b724a9e96da34834fc748970cfbe9f0b35a5b234346c70a0da7a8e98872632c146f5b405bdc248d94a809496ec049022eef06552050f535bcb9b8f4f15d738302d2fa74b77dd5a704abf549fb3a2dbca355ab84396a9589a83a8a7e4382adad944d25c00624d5253353505e3014eab287a2b6f29cfaa4b14d88aacae024c78abf04b563a190e16f44d435e28327dd72f4dd675ab28086bb09b8a679cf514397b9248444b28fa2ac021b110309a9d31c2fb3992a71e214e99eefe1e59fe5c7e380951c5c2067695a315cd5d78c34b41f05b8cc650603927bcadc186248429d8646cd6ccefeaa1600ecaeecf44fc8485330b975403e8e84a9587a96829f1fdd46a568475df12018ed5858d1686ac72027c136292ac16d839825d36a5be8f0120d71b4ab3069e6d0acc1a4be9d6f5d1b5c651e524ec69468576f3d8d29b48a7df634b11a485a223895a254992853510cb2970a78a43cd895698b11a8d6694d892429e6522629e6d3a2985c548b9a81d494c9b93a5a3a75d5c849dbe2c14d42c94cfc84806b7a29f40a8d99520f1db291774e5cb0432915672ac83a0a553e8d60a8e93c173744a79b6e5bcf448f9b46ba79e9787be995e531c642b49694ea752aca53202a752a7e266173f6d825f0821736ff5d100490e17a33a23e63537a521f8e1597a616e894af49d2238d2ea769f620969c0c58253f1b16ab0b7d3ae7d361831e13cad174a130194b54329cda9a800c6cb68d3cea5c852a34154c180b1a86aaa6e61b2a40889b4e9cefbaec9d03f0d2869c613fa25172d1f38c053bda7d216ed60700a57b4d956b4b1389ca6f4e7f462db42790028d525490918d385ab4e89ae38195b87d515f6973a50ef1cab724f4bd414ff00681e0b7a83425551670b8fa3caaa6a9b70f96eedc821673558f2a6b0b039923bae324aae151b474b9032981f9e93759ad695c1dd3dcb387f88296c33da7a51a1c063a60050d662475f34470e5bd53c18c1ae97c25e412af235da195b8394f8107718ce7c165e486e493231e8a16041ba8883f953816ab453eca9285828e913516953b14ac4ad071db87383d7b56616559e5aafb001e0b4f175d1a3217369b568ab6ec986858e35b8344b189b06be30ae5e9ba5c71614e41a4b98baf983491124ea0d7ce895e469f8235428b99e3099901f2129714857cb596b75f08d252950c6a7024228d314e361594c2e28d4a81f0c2b61c744174403e06a5d094a02809d73764b4154e764a1e65a6a06677217a3239a0a6d3439ddc1524560ea7a087b1c3dd4ba863efa28c7685c9d42d853608c76ae6909044b47163a85d3ca863e923ef57d35226a767614fa99b6c6cef542e888a2677a5b063afa6677ae7bc1e43f0d137bd42fcda6aaad8d4d8c94c8b6a7c3e9f16d48348fa24989da75b6c3d815bca7871b6a3dcb70a5c76d3dc8c3c873fc38f721591c34aeee52f26c366de7b91e4a31b42309b004fa3df64684bd21c2d2a518f486057176dba68740415cccf5dd3c81391b399a93d276a0af74182b3d12d44dbef059d7bd26b29eaed4cc73bf504c9e2b77fa66bc65bbf6ab48e7c55edf0fdd83df84f22921bbf5947383e49e45a43925bb99a004c7c330d9b0567345830d22ada9d84980ae6a68afdf6cb9ea9f9e549590711f44f334e078aae198e4d662cfb4848031841737cd207a47845a4439ad3e4866bd1d64b47ca6fb28f96ea0789179063c67754906b06b80697124ab41a76d73039c2a68d48410871c7a29da03d7dac30eca5403a88c614a81f6c760250b0d0cd956d160d92849496a561a8e9404bacc465f2a1cde8b4cb8f0f2f6e7601f00a186c6ab554db05b06130d126830afa44da31cf92b7ae03bf294bc074d2aeb9c829b0f7a8f5038e8d2b61d8e996698e1a44f28a41a44e9d2db4aa5acd3aca34d0c532896018234862a087753d02638f74604a454e9e1c4b69c2d02983014f409b657301fbce11a138cbb43ff00302781f4b758bf984d43f392e7c7468e8576ca84542af8ec79b671f7578ac1349f115cbd5c52750c3cfc51b476a85e4ae33e2a1bd32a73e64759f13c3f92b4e1482d9f138d3da9fc145d37c4d33b4acf29d2aa7e25d83b55180c7c50b3bd361c447f142cef59619254ff0016718ed53bcc2da3a0f8b384f6a59c25a259f175004de1494543f1890744b7e62d111fc57c1e0a7e0898b6fc5741e0abe544c1f89d80f724b0b83697e2769fb70a76292245bf1274e7b922d23aef88084f72af9219771c223dc92c2e2dda2f528a9dc7e12316efa0df0a69dafa4a6c2704b254a657f5256fd8405b21e33181ef0fce4e32ad21db469e87fa40f8051bcb98d5d63cff00e7459e433ed5d6ddb62a9382d64af824336398f5c2e9e7e61a35be98c4c25ffc73ba3ca78cd2bb892c6ce478adc3c89aa7d522658b489ab3bf74b54913150d0a1cd3d886adbb86ff0065d1a85892b6e1dfdd2a24dd2d3cdd174f10cacea2d340b7a2dab303e2268e232e03bca850ce74f595cf91bb76e3f2a509af6770934a96c6ddbb02a42b49bf48238cefd88c6bcf5aa2fbcd211938dd0148bc5bdc41210cd2f47c47041f2468d59a8ede79f650d541dfe721d8298687fa62424a1314d4dcaccfaacc090d2ff76e98f5659e71d3b54ea5600f944b92b0fddac79684da6c48e8fa7e57b7cc230ed958ec81e4b303ac8965186dcc5831c91aafd745258d52f404c0cc75579d072a62ca9754076d324a4946c0c52b5587084d2b29b30e55e54e96da652d29d6c4ab0da762622b4b6c2a56985430a983cc8b74e0646131c4080a5a1f4d0150d0c878a5a8dd1fe9246ea902954fae6423a9f75480fc5c43783d4a6a1e2dacb565744e91910b35895a556077e9e053eb2859348e7b12d25a43b4901d89617413ac18ef5d106971da31de8ac75f6f3dcb9ed0e3ad27c56e9e102c8974c50b3f9a352a16a2d7e6b352a027a1776655f46142deef14ba0ec36c778acb54892a581de292ad2a4a10477a7e624285c9c3bd6d877c2eef1deb9ab75f1d5720ef57e4de8edbb59cc4f6a7a4d4a506b19b9fb573f4dd7b83e112bcc8c3cca158f4556c40138590b88ea998615b588d8e2dd2854f524b87e0ab72a681b750b5cefcae88d699658b0c0b92c411f79c0e62a5796328d75a90346329e40aae9980be50ff0010af205938835e1b1e3c30aac8f3ccf64e79f9bc50a468ba5ec81a10b45ca8e3012e2905ba7cae7c65aa96a1a37177a842156db2c0433d026d644952b095be8f1f5c6d80b53de8453753688123318ec2a56a9157d1bc23687e71db9e8889f4dd6df45f261f4558e7ac8f885ae1dcd81d3a24c74466f3e5c7992e0ea3e9c7d84231c3d17a6e8f194ade526face539528bde5d969c49babc4acaeba980578d821919215362b28ab4c3c992a35a1ed950f7cdeaa3605fa9ed982a3793a4a5a51852bc81d64b30e60423962f74f4fb7fe6cbb798346c74e4f62ad8d95daca1dc29d8aca1e4a153bcb35c6d1a85e4ba50a728919a51a72ba212d7df4c4a9d8e7e7fd3eca3293cbb7920d2145374762a6295c7d1f6d2f82e78c7cda7f05d5cd3c13051f82ceeaf0e7d1f82e1a72e180f72e8863ec853e14ec2cf0458d8358dc762958dd7c7c4ad909ac9b8af636bd5e42aab67d1edc6e8bc849b742c6a17934af23c9a549ec56959811fa34f72e9e69881a44f72aca9d2c695f04c85a06af4b1ee4919a8f9349f82bc1a6ce953dc8ad3474bf82850259a40a55a14745a5d31aa8d284762349403b4993d8b35139fe47dfa7e137a5ef279fa1f6e8b751a6e3d12426d6be1a471d8b5ba51d30baa4508ff002a159d42112e942b92c66a3a7d309f92e9fb758b07a7e13d2ea5469c237f55cfd1e57ae7e102a791a72a1557a2ae553cc4e1646e058e9d3ea621b4f8fc95a18ceb7be1f9f8f1c2b4026d757820f92b4add5e65d5219103e0b308add4eb2e76b92f96319e2154b89ed4de42ebc2fa2260e63e0a92046f14a5d8256a9b65b6e483fdd0a45f6df6fc041e0f968364d87d3504679946c73de86d4db01531a9ba1a21c8a569a43f152003b14fd291dc653fa617f4e30b75a95b2da1a46400a90955de245786c440383baac4abceb5f525e727bca314e68274b858a53a25ca471d893a26a5b14e793355445c70a2eabcbea4fb0f2aa6a5794fd2dbc382d9d249086d7b26f65b43d4c18384dad1562a1e57732dc0b73660567938a6d1e5378093b9dc3e9a9cc87b06546718183567c6008de5b8e8485d13f89da9bb17c5f31ee0a963652f517c5e318f0a78b4a061f8c2614f792e9c8fe2f99e0a17965a96a5f8ad8dc3b12f92e9cffdceb3c3dd361752145f12b19ed1eeb307313149f1171778f74b8eae47c7c7788f6b7dd2f93f4259c6b8fbc7b84b7972d890a5e2f447f7b7dc249f3262463e25c47f7b7dc2bcf9a912749c4188fef6ff00fb059dfcd5e5231eb68bf9b7dc2e5bf33a529b51c27f7b7dc2242ea420ad88ff00c46fb85590c95a7319fdedf70b31944b9b19fdedf709719ae8a38ff937dc2d9c97545d6744d3dc7d72af396ab3146a9e4d60ea78bbd4ef2552e7e10f2fea6fe142424a85afe1fb7b1aaf2292ab75fa271d89d346cda3fc16e92c0355a23c12c4c13f45abf2dc32ed1be0b69b1f3743f82856e088f461ee48786dfa3cf7214865fa28f72dc61ea4d11e0b7134bc9a1463a7e11e56aeb7406dd118850953a177e8b0a1e7d0db744d28c0afd0fe1f85d7cf4abe8f47f823aa431368bdba2e4662324d15e0afc171d8f446fd12da3c8d97486dd1429f1a3f07e2309f5f252a791e87b554f38ca21e24e34ba5c2eb66fb55792e320d791306647636c9576622387f726cc481d8b7462e97db3b8b3184f2b15fa1b1b80dc279422ebb4b871e9feab42d56ea06c34ceffe90190eafbb891d8ee290266ca19cace99c20d8faeb5441fb539df58ee2ee6fb933756c867692a7639d20f7b70a5793c22a2af0147a86439ba927af6a9791ab3407edfcac90c5d5b4f27bab484234cdd486bb27bd3e1595ebdbf9748e1e24234ea7474e309f59ca3eaa97052eab40b26dd4ad73f94dd1b526adc7220b92ace6c56cacc1f6e97758874b950c396adc73d0d5f458dd5e1e444dc24e56e4276e1db1cee72a9b178b5e531b1de27c05d6f781d794ff00652c2d8fce6bde8f95d3bf19fd456ea55ca4d253b77dd6eb1dafd2d50eec3fdd2e9914ed27500f42ac70f51a62a73b02b30a1dba7ab074e659e5859b6567ff00259857cda1adcedcdf9523c85c74b5e0e7eff7296af0609ae0ded77b94535111dd6bfbdfee562760865cee037cbfdcaea9ca584546b7af6ed97fb954c31307126bc1fd6ff72b2c38a6f186b81ff78ef72a1d72795214bc71ae1ff11dee570b12d43c7fad1ff11dee53f30eb75a3e23eabb6477b94d8ceaadb6ff00882a83ff0011dffec5679735e973b171de7271ce7dd104ad334feb77483249f52af1d117cb24dcc56da64fcb0e146f49d4edc2f25fd42d91c92ab35d177054917950f3db01ec4b5532cd3a3b94ed658e546996e3b1372e7c453b4d8cabf262dba4dab2ab23aed320285361bff2fb5310f41a55a50a472a34b8f04f8da1e2d36d4d89a463b0e7b13e368e8eca31d14ec2547d669f19e8a35869da6c77295a7c34fd2ed3d8afcf440926986854b4e5bb4b354b5b81c68f6f705d5c1b0e43a31aa16b7c9e9347b7c14e8c1b66d261a52566341b1d360218b33291422981aed0602e8e4b8ce7516986cd961ed562e24f86fc2a645923cd2eb3173bada801d112a6af494015e508b82df9774ef5b680fada9f9699fe4527a0f355ace64703bee56c6e2df414b800aa432424873d1383905061318750b7753a8ac51c408598a18ac876c29d85afad964077f549e50b53534586a491d466ff0056590e7c0955912b59d69ed4ee7970ecdc22c3440ea88f72542ab8ac534872a89f2fae8ed94ad56a1a18fee52b53ab25bdaa76ba383d3302d4f4cb624edd1d6e3ba72d5bed732791cd5cd4152709e2d22ab45585eee43e498d8b65bade18404da6c5c69a970329a56c81eff525f1161e8765b612b2d8384cc2e2e38dce54ad46c5860e0ac65bd8974a360e04465bd02cd384aae03c5dc15274645ffe8a47cd8c05594a926702620de83bd50b62b757c1c8f9ba04307d0f02e2233b2e55647d59c178c7604b4e8e7707a33dcb0e92b4701a23dc9598b2d17c39c2e38d974fb46c01a93e15e1033b74256fb6321bd702a3693b0ed096f6753ee1c19603d8a77b015dc1d8d72b25465670ad815b95619a3e19b72aa4e965a1e1bb425ae3e9a4693e1633ae7c5246f35a858b4a06ec0f44f1d7cb43d3f0f290a7d55716d2de65cdd74874ffd9	image/jpeg	2025-08-17 06:46:07.96047+00
\.


--
-- Data for Name: files; Type: TABLE DATA; Schema: files; Owner: postgres
--

COPY files.files (id, created, name, body, mime, updated) FROM stdin;
\.


--
-- Data for Name: entities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.entities (id, name, created, updated) FROM stdin;
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
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: crm; Owner: postgres
--

ALTER TABLE ONLY crm.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


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
-- Name: params_objects params_objects_param_id_object_id_key; Type: CONSTRAINT; Schema: customs; Owner: postgres
--

ALTER TABLE ONLY customs.params_objects
    ADD CONSTRAINT params_objects_param_id_object_id_key UNIQUE (param_id, object_id);


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
-- Name: avatars avatars_pkey; Type: CONSTRAINT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.avatars
    ADD CONSTRAINT avatars_pkey PRIMARY KEY (id);


--
-- Name: files files_pkey; Type: CONSTRAINT; Schema: files; Owner: postgres
--

ALTER TABLE ONLY files.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


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
-- Name: fki_users_avatar_fkey; Type: INDEX; Schema: access; Owner: postgres
--

CREATE INDEX fki_users_avatar_fkey ON access.users USING btree (avatar_id);


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
-- Name: users users_avatar_fkey; Type: FK CONSTRAINT; Schema: access; Owner: postgres
--

ALTER TABLE ONLY access.users
    ADD CONSTRAINT users_avatar_fkey FOREIGN KEY (avatar_id) REFERENCES files.avatars(id);


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
-- Name: SCHEMA files; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA files TO tpss;


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
-- Name: TABLE matrix; Type: ACL; Schema: access; Owner: postgres
--

GRANT SELECT ON TABLE access.matrix TO tpss;


--
-- Name: TABLE companies; Type: ACL; Schema: crm; Owner: postgres
--

GRANT ALL ON TABLE crm.companies TO tpss;


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
-- Name: TABLE params; Type: ACL; Schema: customs; Owner: postgres
--

GRANT ALL ON TABLE customs.params TO tpss;


--
-- Name: TABLE params_float; Type: ACL; Schema: customs; Owner: postgres
--

GRANT ALL ON TABLE customs.params_float TO tpss;


--
-- Name: TABLE params_int; Type: ACL; Schema: customs; Owner: postgres
--

GRANT ALL ON TABLE customs.params_int TO tpss;


--
-- Name: TABLE params_objects; Type: ACL; Schema: customs; Owner: postgres
--

GRANT ALL ON TABLE customs.params_objects TO tpss;


--
-- Name: TABLE params_string; Type: ACL; Schema: customs; Owner: postgres
--

GRANT ALL ON TABLE customs.params_string TO tpss;


--
-- Name: TABLE files; Type: ACL; Schema: files; Owner: postgres
--

GRANT ALL ON TABLE files.files TO tpss;


--
-- Name: TABLE avatars; Type: ACL; Schema: files; Owner: postgres
--

GRANT ALL ON TABLE files.avatars TO tpss;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: crm; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA crm GRANT SELECT,INSERT,UPDATE ON TABLES TO tpss;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: customs; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA customs GRANT ALL ON TABLES TO tpss;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: files; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA files GRANT ALL ON TABLES TO tpss;


--
-- PostgreSQL database dump complete
--


