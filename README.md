# sakiladb/postgres

A PostgreSQL Docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) sample
database (via [jOOQ](https://www.jooq.org/sakila)). One of the
[`sakiladb`](https://github.com/sakiladb) image family.

These images exist primarily as test fixtures for [`sq`](https://github.com/neilotoole/sq), a
command-line tool for querying SQL databases and structured data — but they are free for anyone to
use. See sq's [PostgreSQL driver guide](https://sq.io/docs/drivers/postgres).

Available on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres).

## Quick start

```shell
docker run -p 5432:5432 -d sakiladb/postgres:latest
```

The Sakila data is baked into the image, so there is no initialization step at startup — the
container is ready in about a second.

The image declares a Docker
[`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck), so you can wait for
readiness rather than guessing. Its status becomes `healthy` once Postgres is accepting connections:

```shell
docker run -p 5432:5432 -d --name sakila sakiladb/postgres:latest
until [ "$(docker inspect -f '{{.State.Health.Status}}' sakila)" = healthy ]; do sleep 1; done
```

In Docker Compose, gate dependents with `depends_on: { condition: service_healthy }`. (PostgreSQL
also logs its native `database system is ready to accept connections` line.)

> [!TIP]
> Building or testing on GitHub Actions? Pull from GHCR (`ghcr.io/sakiladb/postgres`). Docker Hub
> rate-limits pulls and CI runners share IP addresses, so the limit is reached quickly; GHCR isn't
> throttled the same way, especially from within GitHub's network.

## Connection

| Setting    | Value       |
|------------|-------------|
| host       | `localhost` |
| port       | `5432`      |
| database   | `sakila`    |
| user       | `sakila`    |
| password   | `p_ssW0rd`  |

Any Postgres client works with the settings above. For example, with
[`sq`](https://github.com/neilotoole/sq) ([install](https://sq.io/docs/install)):

```shell
$ sq add 'postgres://sakila:p_ssW0rd@localhost:5432/sakila' --handle @sakila_pg
@sakila_pg  postgres  sakila@localhost:5432/sakila

$ sq '@sakila_pg.actor | .[0:5]'
actor_id  first_name  last_name     last_update
1         PENELOPE    GUINESS       2006-02-15T04:34:33Z
2         NICK        WAHLBERG      2006-02-15T04:34:33Z
3         ED          CHASE         2006-02-15T04:34:33Z
4         JENNIFER    DAVIS         2006-02-15T04:34:33Z
5         JOHNNY      LOLLOBRIGIDA  2006-02-15T04:34:33Z
```

## What's inside

The standard Sakila sample database — **16 tables and 7 views**, all owned by the `sakila` user.

[`sq inspect`](https://sq.io/docs/inspect) shows the whole schema — tables, views, row counts, and
columns — at a glance:

```shell
$ sq inspect @sakila_pg
SOURCE      DRIVER    NAME    FQ NAME        SIZE    TABLES  VIEWS  LOCATION
@sakila_pg  postgres  sakila  sakila.public  15.2MB  16      7      postgres://sakila:xxxxx@localhost:5432/sakila

NAME                        TYPE   ROWS   COLS
actor                       table  200    actor_id, first_name, last_name, last_update
address                     table  603    address_id, address, address2, district, city_id, postal_code, phone, last_update
category                    table  16     category_id, name, last_update
city                        table  600    city_id, city, country_id, last_update
country                     table  109    country_id, country, last_update
customer                    table  599    customer_id, store_id, first_name, last_name, email, address_id, create_date, last_update, active
film                        table  1000   film_id, title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features
film_actor                  table  5462   actor_id, film_id, last_update
film_category               table  1000   film_id, category_id, last_update
film_text                   table  1000   film_id, title, description
inventory                   table  4581   inventory_id, film_id, store_id, last_update
language                    table  6      language_id, name, last_update
payment                     table  16049  payment_id, customer_id, staff_id, rental_id, amount, payment_date, last_update
rental                      table  16044  rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update
staff                       table  2      staff_id, first_name, last_name, address_id, email, store_id, active, username, password, last_update, picture
store                       table  2      store_id, manager_staff_id, address_id, last_update
actor_info                  view   200    actor_id, first_name, last_name, film_info
customer_list               view   599    id, name, address, zip code, phone, city, country, notes, sid
film_list                   view   997    fid, title, description, category, price, length, rating, actors
nicer_but_slower_film_list  view   997    fid, title, description, category, price, length, rating, actors
sales_by_film_category      view   16     category, total_sales
sales_by_store              view   2      store, manager, total_sales
staff_list                  view   2      id, name, address, zip code, phone, city, country, sid
```

## Differences from other sakila variants

Every sakiladb variant exposes the **same Sakila fixture** — the same 16 tables and 7 views, with
the same data (same row counts) — so [`sq`](https://github.com/neilotoole/sq) can assert a uniform
schema across all of them. They all descend from the MySQL Sakila, ported to Postgres via
[jOOQ](https://www.jooq.org/sakila). One representation detail is worth calling out:

- **Identifiers are lower-case.** Postgres folds unquoted identifiers, so view columns that are
  upper- or mixed-case in MySQL appear lower-case here (e.g. `customer_list.id` / `.sid` vs
  `ID` / `SID`). This is inherent to Postgres — the one unavoidable difference from the other
  variants.

`film_text` is **parity, not a difference**: MySQL has a `film_text` table, so this image does too
(populated from `film`), with **working full-text search** via a *functional* GIN index:

```sql
SELECT title FROM film_text
WHERE to_tsvector('english', title || ' ' || coalesce(description, '')) @@ to_tsquery('english', 'astronaut');
```

The index is functional (no stored `tsvector` column), so `film_text` keeps the same three columns as
every other variant — full-text search is added *under* the table, invisible to the schema.

### Not pagila

[pagila](https://github.com/devrimgunduz/pagila) is a *separate*, independently-maintained
Postgres-native Sakila port; it is **not** part of this family. It ships Postgres-specific extras
that this image deliberately does not — for example a `film.fulltext` `tsvector` column and a
partitioned `payment` table. `sakiladb/postgres` is the MySQL Sakila via jOOQ, trimmed to stay
consistent with the other sakiladb variants, so pagila's extras are intentionally absent.

## Available versions

Each PostgreSQL major version is published as its own image tag. `latest` tracks the newest
version (currently 18).

| PostgreSQL | sakiladb Release | Docker Hub                        | GitHub Container Registry                 |
|-----------:|------------------|-----------------------------------|-------------------------------------------|
|         18 | `v18.0.4`        | [`sakiladb/postgres:18`](https://hub.docker.com/r/sakiladb/postgres), [`:latest`](https://hub.docker.com/r/sakiladb/postgres) | [`ghcr.io/sakiladb/postgres:18`](https://github.com/sakiladb/postgres/pkgs/container/postgres), [`:latest`](https://github.com/sakiladb/postgres/pkgs/container/postgres) |
|         17 | `v17.0.3`        | [`sakiladb/postgres:17`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:17`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         16 | `v16.0.3`        | [`sakiladb/postgres:16`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:16`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         15 | `v15.0.4`        | [`sakiladb/postgres:15`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:15`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         14 | `v14.0.4`        | [`sakiladb/postgres:14`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:14`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         13 | `v13.0.5`        | [`sakiladb/postgres:13`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:13`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         12 | `v12.0.5`        | [`sakiladb/postgres:12`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:12`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         11 | `v11.0.4`        | [`sakiladb/postgres:11`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:11`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|         10 | `v10.0.4`        | [`sakiladb/postgres:10`](https://hub.docker.com/r/sakiladb/postgres)            | [`ghcr.io/sakiladb/postgres:10`](https://github.com/sakiladb/postgres/pkgs/container/postgres)            |
|          9 | `v9.0.5`         | [`sakiladb/postgres:9`](https://hub.docker.com/r/sakiladb/postgres)             | [`ghcr.io/sakiladb/postgres:9`](https://github.com/sakiladb/postgres/pkgs/container/postgres)             |

**sakiladb Release** is the git tag the current image was built from (see
[releases](https://github.com/sakiladb/postgres/releases)). Its version is
`v{POSTGRES_MAJOR}.{MINOR}.{PATCH}`: the **major** tracks the upstream PostgreSQL major version,
while the **minor** and **patch** track sakiladb's own revisions of that image. In practice only the
patch is bumped (e.g. a rebuilt Postgres 13 image goes `v13.0.0` → `v13.0.1`), so the minor stays
`0`.

Every version is published to both [Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres) (GHCR
mirroring began with the June 2026 republish).

Images are multi-arch (`linux/amd64`, `linux/arm64`) and are signed with
[cosign](https://github.com/sigstore/cosign).

## Releasing a new version

Maintainers: releases are tag-driven. Pushing a semver tag `vN.0.x` builds and publishes
PostgreSQL N — the version is derived from the tag, so there are no per-version branches. See
[CLAUDE.md](./CLAUDE.md) for the full, repeatable procedure.

## Changelog

### 2026-06-28

- **Maintenance release** (`v18.0.4`): CI and supply-chain hardening (release-gated registry login,
  SHA-pinned third-party actions, Dependabot for GitHub Actions). The Sakila dataset and schema are
  unchanged from the previous release.

### 2026-06-26

Restored the Sakila **data** to be byte-identical to the original MySQL Sakila (`v9.0.5` to `v18.0.3`,
republished all majors). The object set is unchanged (16 tables + 7 views):

- **Accents restored.** The Unicode characters the lineage had stripped from international place names
  (e.g. `Réunion`, `Coruña`, `Huánuco`) are back.
- **`address.phone` restored.** The real phone numbers the jOOQ-Postgres lineage had blanked.
- **`address.district` restored.** The full district column the jOOQ-Postgres lineage had blanked.

### 2026-06-25

Republished every version (`v9.0.4`–`v18.0.2`) and published `16`/`17`/`18` for the first time, so
all majors `9`–`18` are now the same consistent test fixture as the other
[sakiladb](https://github.com/sakiladb) variants — **16 tables and 7 views** — reconciled to the
canonical [`sakiladb/mysql`](https://hub.docker.com/r/sakiladb/mysql) image. Net changes:

- **Schema reconciled to MySQL / the family.** Added `film_text` (populated from `film`, with working
  full-text search via a functional GIN index) and `payment.last_update`; dropped the empty
  `payment_p2007_*` partitions and the Postgres-only `film.fulltext` / `customer.activebool` columns;
  `customer.active` is now `boolean`; and column order, nullability, and FK-column indexes now match
  MySQL.
- **Writable parity with MySQL.** Mutation-maintenance triggers keep `film_text` in sync with `film`,
  stamp `create_date` / `payment_date` / `rental_date` on insert, and bump `last_update` on update —
  all invisible to the fixture's schema.
- **Deterministic view output.** `film_list`, `nicer_but_slower_film_list`, and `actor_info` now sort
  their aggregated columns (cast lists by actor name, films by title), so the views render identically
  across the sakiladb family instead of in arbitrary aggregation order.
- **`latest` now tracks PostgreSQL `18`** (moved up from `15`).
- Every image declares a Docker `HEALTHCHECK` (`pg_isready`) and is mirrored to GitHub Container
  Registry (`ghcr.io/sakiladb/postgres`).

### 2023-08-26

- Published PostgreSQL `9`–`15`.
- The image's root user is now `sakila` (previously `postgres`).

### 2022-12-22

- Initial release.

## License

[BSD 2-Clause](./LICENSE).
