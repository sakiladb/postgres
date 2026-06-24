# sakiladb/postgres

Postgres docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jooq](https://www.jooq.org/sakila)).
See on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`



```shell script
docker run -p 5432:5432 -d sakiladb/postgres:latest
```

Or use a specific version of postgres (see all available image tags
on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres/tags).)

```shell script
docker run -p 5432:5432 -d sakiladb/postgres:15
```

## Available versions

Each PostgreSQL major version is published as its own image tag. `latest` tracks the
newest version (currently 15).

| PostgreSQL | Docker Hub                          | GitHub Container Registry         |
|-----------:|-------------------------------------|-----------------------------------|
|         15 | `sakiladb/postgres:15`, `:latest`   | —                                 |
|         14 | `sakiladb/postgres:14`              | —                                 |
|         13 | `sakiladb/postgres:13`              | —                                 |
|         12 | `sakiladb/postgres:12`              | `ghcr.io/sakiladb/postgres:12`    |
|         11 | `sakiladb/postgres:11`              | —                                 |
|         10 | `sakiladb/postgres:10`              | —                                 |
|          9 | `sakiladb/postgres:9`               | —                                 |

[Docker Hub](https://hub.docker.com/r/sakiladb/postgres) carries every version.
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres)
mirroring began with the June 2026 republish; a `—` marks versions not yet mirrored
there (they'll be added as each is republished).

To verify that all is well:

```shell script
$ PGPASSWORD=p_ssW0rd psql -h localhost -d sakila -U sakila -c 'SELECT * FROM actor LIMIT 5'
 actor_id | first_name |  last_name   |     last_update
----------+------------+--------------+---------------------
        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33
        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33
        3 | ED         | CHASE        | 2006-02-15 04:34:33
        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33
        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33
```

## Releasing a new version

Maintainers: each Postgres major version has a `postgres-N` branch, and a release is
published by pushing a `vN.0.0` tag. See [CLAUDE.md](./CLAUDE.md) for the full,
repeatable procedure.

## Changelog

### 2026-06-23

- **PostgreSQL `12` republished** to match the other
  [sakiladb](https://github.com/sakiladb) variants as a consistent test fixture:
  added the `film_text` table (populated from `film`) and dropped the empty
  `payment_p2007_*` partitions, so the image now exposes the same 16 tables and
  7 views as the other variants. Postgres still provides full-text search via the
  `film.fulltext` column; `film_text` is added for cross-variant parity.
- Images are now also published to GitHub Container Registry (`ghcr.io/sakiladb/postgres`).
- Modernized the GitHub Actions release workflow: current action versions, and a fix
  for cosign image signing.

### 2023-08-26

- Published PostgreSQL `9`–`15`.
- The image's root user is now `sakila` (previously `postgres`).

### 2022-12-22

- Initial release.
