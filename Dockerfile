FROM postgres:12.2-alpine AS sakila-base
ENV POSTGRES_PASSWORD="p_ssW0rd"
ENV POSTGRES_DB="sakila"
COPY ./postgres-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./postgres-sakila-insert-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./postgres-sakila-user.sql /docker-entrypoint-initdb.d/step_3.sql