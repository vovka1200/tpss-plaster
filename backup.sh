#!/bin/bash


docker exec postgres psql -h localhost -U postgres -d tpss -c "TRUNCATE TABLE access.sessions"

docker exec postgres pg_dump -h localhost -d tpss -U postgres >patches/2507131301.sql
