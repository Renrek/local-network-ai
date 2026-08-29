#!/bin/sh
set -eu

localai_password="$(tr -d '\r\n' < /run/secrets/localai_postgres_password)"

psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=ON_ERROR_STOP=1 \
  --set=localai_user="$LOCALAI_POSTGRES_USER" \
  --set=localai_db="$LOCALAI_POSTGRES_DB" \
  --set=localai_password="$localai_password" <<'SQL'
CREATE ROLE :"localai_user" LOGIN PASSWORD :'localai_password';
CREATE DATABASE :"localai_db" OWNER :"localai_user";
SQL
