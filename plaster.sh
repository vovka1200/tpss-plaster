#!/bin/bash

if [ -z "$PGHOST" ]; then
  echo "Не определены переменные доступа к БД!"
  exit 1
fi

TAG=$(psql -A -t -c "SELECT regexp_replace(pg_catalog.shobj_description(d.oid, 'pg_database'),'\D','','g')
                 FROM   pg_catalog.pg_database d
                 WHERE  datname = 'tpss'"
                 )
if [ -z "$TAG" ]; then
  TAG="0";
fi
echo "Текущий build tag: $TAG"

for f in $(find patches -type f | sort); do
  n=$(echo "$f" | grep -E -o "[[:digit:]]+")
  if [ "$n" -gt "$TAG" ]; then
    if [[ "$f" == *".sql" ]]; then
      echo "Выполняется psql: $f"
      PGDATABASE="tpss" psql -1 -v ON_ERROR_STOP=1 < "$f" || exit 1
    else
      echo "Выполняется bash: $f"
      bash "$f"
    fi
  else
    echo "Пропускается: $f"
  fi
done