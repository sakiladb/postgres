FROM postgres:9-alpine as dumper

COPY ./1-postgres-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./2-postgres-sakila-insert-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./3-postgres-sakila-user.sql /docker-entrypoint-initdb.d/step_3.sql

# From: https://cadu.dev/creating-a-docker-image-with-database-preloaded/
RUN ["sed", "-i", "s/exec \"$@\"/echo \"skipping...\"/", "/usr/local/bin/docker-entrypoint.sh"]

ENV POSTGRES_PASSWORD="p_ssW0rd"
ENV POSTGRES_DB="sakila"
ENV POSTGRES_USER=postgres
ENV PGDATA=/data

RUN ["/usr/local/bin/docker-entrypoint.sh", "postgres"]

# final build stage
FROM postgres:9-alpine

COPY --from=dumper /data $PGDATA
