#!/bin.bash

psql -c "
CREATE DATABASE tpss
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;
" \
-c "CREATE ROLE tpss WITH
    	LOGIN
    	NOSUPERUSER
    	NOCREATEDB
    	NOCREATEROLE
    	INHERIT
    	NOREPLICATION
    	NOBYPASSRLS
    	CONNECTION LIMIT -1
    	PASSWORD '123';" \
-c "COMMENT ON DATABASE tpss IS 'v25.07.13.13:00';"