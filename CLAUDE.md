# CLAUDE.md

Maintainer guide for **`sakiladb/postgres`** — a PostgreSQL Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database (via [jOOQ](https://www.jooq.org/sakila)),
published to [Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres).

> One of the [`sakiladb`](https://github.com/sakiladb) image family (`postgres`, `mysql`,
> `sqlserver`, `oracle`, `clickhouse`, `rqlite`). The release machinery in
> [How releases work](#how-releases-work) is **shared across the family**; the build details
> in [How the image is built](#how-the-image-is-built) are **PostgreSQL-specific**.

## Purpose

These images exist primarily as **test fixtures for the [`sq`](https://github.com/neilotoole/sq) CLI**.
`sq`'s suite runs against every variant and asserts a uniform Sakila schema, so each image must
expose the **same object set: 16 tables + 7 views** (see [The dataset](#the-dataset)). Treat that
as a hard consistency contract.

Because the schema is coupled to `sq`'s tests, **a schema change here is a cross-repo change**:
`sq`'s expectations must be updated in lockstep or its suite breaks against the new image. The
relevant `sq` files are `testh/sakila/sakila.go` (the canonical `AllTbls`/`AllTblsViews` sets and
per-table column/count constants), `libsq/driver/driver_test.go` (per-image table/view counts), and
`cli/cmd_inspect_test.go`.

## The dataset

The standard Sakila database, preloaded and owned by the `sakila` user: **16 tables + 7 views**.
Two PostgreSQL-specific points worth knowing:

- **Full-text search** uses the `film.fulltext` `tsvector` column (GiST-indexed, maintained by the
  `film_fulltext_trigger`), not MySQL's separate `film_text` table. A `film_text` table is *also*
  included (populated from `film`) purely so the object set matches the other variants.
- **`payment` is a plain table.** The upstream jOOQ dump's empty `payment_p2007_*` inheritance
  partitions are dropped — they were vestigial (all payment rows live in the parent) and made
  Postgres report 21 tables instead of 16.

Both customizations live at the bottom of `1-postgres-sakila-schema.sql` (with the `film_text`
populate in `3-postgres-sakila-user.sql`), clearly commented.

## How the image is built

*(PostgreSQL-specific.)* `Dockerfile` is a two-stage build that bakes the data into the image so
there is no initialization cost at container start:

1. **`dumper` stage** — `FROM postgres:N-alpine`, copies the four SQL files into
   `/docker-entrypoint-initdb.d/`, neuters the entrypoint's `exec "$@"` (so the server doesn't stay
   running), then runs the entrypoint once to initialize the database into `$PGDATA` (`/data`).
2. **final stage** — `FROM postgres:N-alpine` again, copies the populated `/data` from the dumper
   stage. The published image ships with Sakila already loaded.

The four init SQL files run in order, as the `sakila` superuser:

| File | Role |
|------|------|
| `0-postgres-sakila-setup.sql` | Create a temporary `postgres` user (the dump is authored as `postgres`). |
| `1-postgres-sakila-schema.sql` | Schema: tables, views, indexes. Also creates `film_text` and drops the `payment_p2007_*` partitions. |
| `2-postgres-sakila-insert-data.sql` | Data (`Insert into …` statements). |
| `3-postgres-sakila-user.sql` | Populate `film_text` from `film`; reassign ownership of everything to `sakila`; drop the temp `postgres` user; log the completion message. |

The container logs `sakiladb/postgres has successfully initialized.` once `3-…` completes.

## How releases work

*(Shared across the `sakiladb` family.)*

- **One long-lived branch per major version** — `postgres-9` … `postgres-15`. Each branch holds the
  `Dockerfile` pinned to its PostgreSQL version (both `FROM` lines).
- **Publishing is triggered by pushing a semver tag `vN.0.x`.** `.github/workflows/docker-publish.yml`
  builds on every branch / PR / tag push, but **only pushes to a registry on `v*.*.*` tags**
  (`push: ${{ startsWith(github.ref, 'refs/tags/v') … }}`). Branch and PR pushes are build-only
  smoke tests.
- Each release tag points to a commit **on its matching `postgres-N` branch** (e.g. `v15.0.0` lives
  on `postgres-15`).
- The tag produces the Docker tag **`{{major}}`** (`v15.0.0` → `15`), built multi-arch
  (`linux/amd64,linux/arm64`), pushed to **both Docker Hub and GHCR**, and **cosign-signed**.
- **`master` is the canonical base.** It mirrors the newest version's branch except for the version
  pin, so new/updated version branches are cut from it. `master` itself never publishes (no tags).

### The `latest` tag

`latest` must always point at the **newest** PostgreSQL major version. The workflow's
`metadata-action` defaults to `latest=auto`, which re-points `latest` on *every* semver tag push
(it does not compare versions). To stop an older release from stealing `latest`:

> **Every `postgres-N` branch except the newest sets `flavor: latest=false` in its workflow.
> Only the newest version's branch emits `latest`.**

This makes tag-push order irrelevant. The current newest is `postgres-15`, which (like `master`)
uses the default `latest=auto`; non-newest branches set `latest=false` as they are republished
under this pattern (so far: `postgres-12`). When a new newest version arrives, flip the previous
newest to `latest=false` (see below).

### Recipe: release a new major version (e.g. Postgres 16)

```bash
git fetch origin
git switch -c postgres-16 origin/master          # branch from master (modern workflow + latest schema)

# 1. Bump BOTH `FROM postgres:NN-alpine` lines in Dockerfile to 16-alpine.
# 2. This IS the newest version, so leave the workflow's latest handling at the default.
git commit -am "postgres-16"
git push -u origin postgres-16                    # build-only smoke test

# 3. Once the branch build is green, tag to publish (`16` + `latest`, Docker Hub + GHCR):
git tag v16.0.0 && git push origin v16.0.0

# 4. Demote the previous newest so a future rebuild can't reclaim `latest`:
#    set `flavor: latest=false` in postgres-15's workflow, commit, push.
# 5. Sync master to postgres-16 (minus the version pin), so it stays the canonical base.
```

Releasing several at once (16 then 17): branch `postgres-17` from `postgres-16`; only `postgres-17`
keeps `latest=auto`, all lower branches use `latest=false`. Order no longer matters.

### Recipe: republish an existing version (e.g. rebuild Postgres 14)

Use when re-cutting an already-released version with a fixed/updated image. `vN.0.0` already exists,
so bump the patch tag.

```bash
git fetch origin
git switch -c postgres-14 origin/postgres-14      # or check out the existing local branch
git checkout master -- .                          # sync content from the canonical base
# Re-pin the Dockerfile to 14-alpine. Since 14 is NOT the newest, set `flavor: latest=false`.
git commit -am "postgres-14: <what changed>"
git push -u origin postgres-14                     # build-only smoke test
# Once green, bump the patch tag (republishes `14`, leaves `latest` untouched):
git tag v14.0.1 && git push origin v14.0.1
```

After any release, verify the published artifact: pull the image and confirm the schema
(`16 tables + 7 views`), and confirm `latest` still points at the newest version.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the major version only (`15`); `latest` on the newest. Git tags are semver
  `vN.0.x`.
- **No AI attribution** in commits, tags, PRs, or any other content.
