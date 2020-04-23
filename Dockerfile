FROM postgres:12.2 AS sakila-base
ENV POSTGRES_PASSWORD="p_ssW0rd"
ENV POSTGRES_DB="sakila"
COPY ./1-postgres-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./2-postgres-sakila-insert-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./3-postgres-sakila-user.sql /docker-entrypoint-initdb.d/step_3.sql