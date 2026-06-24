# sakiladb/postgres

A PostgreSQL Docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) sample
database (via [jOOQ](https://www.jooq.org/sakila)). One of the
[`sakiladb`](https://github.com/sakiladb) image family.

Available on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres).

## Quick start

```shell
docker run -p 5432:5432 -d sakiladb/postgres:latest
```

The container takes a few moments to start. When it is ready, the logs show:

```
sakiladb/postgres has successfully initialized.
```

Allow a few more seconds after that message (a final server restart) before connecting.

## Connection

| Setting    | Value       |
|------------|-------------|
| host       | `localhost` |
| port       | `5432`      |
| database   | `sakila`    |
| user       | `sakila`    |
| password   | `p_ssW0rd`  |

```shell
$ PGPASSWORD=p_ssW0rd psql -h localhost -d sakila -U sakila -c 'SELECT * FROM actor LIMIT 5'
 actor_id | first_name |  last_name   |     last_update
----------+------------+--------------+---------------------
        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33
        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33
        3 | ED         | CHASE        | 2006-02-15 04:34:33
        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33
        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33
```

## What's inside

The standard Sakila sample database — **16 tables and 7 views**, all owned by the `sakila` user.
Full-text search is available via the `film.fulltext` column.

## Available versions

Each PostgreSQL major version is published as its own image tag. `latest` tracks the newest
version (currently 15).

| PostgreSQL | Release   | Docker Hub                        | GitHub Container Registry      |
|-----------:|-----------|-----------------------------------|--------------------------------|
|         15 | `v15.0.0` | `sakiladb/postgres:15`, `:latest` | —                              |
|         14 | `v14.0.0` | `sakiladb/postgres:14`            | —                              |
|         13 | `v13.0.1` | `sakiladb/postgres:13`            | `ghcr.io/sakiladb/postgres:13` |
|         12 | `v12.0.1` | `sakiladb/postgres:12`            | `ghcr.io/sakiladb/postgres:12` |
|         11 | `v11.0.0` | `sakiladb/postgres:11`            | —                              |
|         10 | `v10.0.0` | `sakiladb/postgres:10`            | —                              |
|          9 | `v9.0.0`  | `sakiladb/postgres:9`             | —                              |

**Release** is the git tag the current image was built from (see
[releases](https://github.com/sakiladb/postgres/releases)).
[Docker Hub](https://hub.docker.com/r/sakiladb/postgres) carries every version.
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres) mirroring
began with the June 2026 republish; a `—` marks versions not yet mirrored there (each is added as it
is republished).

Images are multi-arch (`linux/amd64`, `linux/arm64`) and are signed with
[cosign](https://github.com/sigstore/cosign).

## Releasing a new version

Maintainers: releases are tag-driven. Pushing a semver tag `vN.0.x` builds and publishes
PostgreSQL N — the version is derived from the tag, so there are no per-version branches. See
[CLAUDE.md](./CLAUDE.md) for the full, repeatable procedure.

## Changelog

### 2026-06-23

- **PostgreSQL `12` and `13` republished** to match the other
  [sakiladb](https://github.com/sakiladb) variants as a consistent test fixture: added the
  `film_text` table (populated from `film`) and dropped the empty `payment_p2007_*` partitions, so
  the images now expose the same 16 tables and 7 views as the other variants. Postgres still
  provides full-text search via the `film.fulltext` column; `film_text` is added for cross-variant
  parity. (Remaining versions follow.)
- Images are now also published to GitHub Container Registry (`ghcr.io/sakiladb/postgres`).
- Modernized the GitHub Actions release workflow: current action versions, and a fix for cosign
  image signing.

### 2023-08-26

- Published PostgreSQL `9`–`15`.
- The image's root user is now `sakila` (previously `postgres`).

### 2022-12-22

- Initial release.

## License

[BSD 2-Clause](./LICENSE).
