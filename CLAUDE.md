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
there is no initialization cost at container start. The base-image version is parameterized by an
`ARG PG_VERSION` (default = newest), which the release workflow sets per build:

1. **`dumper` stage** — `FROM postgres:${PG_VERSION}-alpine`, copies the four SQL files into
   `/docker-entrypoint-initdb.d/`, neuters the entrypoint's `exec "$@"` (so the server doesn't stay
   running), then runs the entrypoint once to initialize the database into `$PGDATA` (`/data`).
2. **final stage** — `FROM postgres:${PG_VERSION}-alpine` again, copies the populated `/data` from
   the dumper stage. The published image ships with Sakila already loaded.

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

Releases are **tag-driven**. There is a single long-lived branch, `master`, and **pushing a semver
tag `vN.0.x` publishes PostgreSQL N**. The major version is read from the tag name, so the tag is
the sole source of truth for what gets built — there are **no per-version branches**.

- `.github/workflows/docker-publish.yml` builds on every push / PR / tag, but **only pushes to a
  registry on `v*.*.*` tags** (`push: ${{ startsWith(github.ref, 'refs/tags/v') … }}`). Branch
  pushes, PRs, and manual `workflow_dispatch` runs are build-only smoke tests.
- The **"Determine PostgreSQL major version" step** computes the major: from the tag (`v14.0.1` →
  `14`) on a tag push; from the `pg_version` input on a manual run; otherwise `LATEST_MAJOR`. It is
  passed to the build as `--build-arg PG_VERSION=N`, and the `Dockerfile`'s
  `FROM postgres:${PG_VERSION}-alpine` builds the matching image. The step validates that the major
  is digits-only.
- The tag produces the Docker tag **`{{major}}`** (`v14.0.1` → `14`), built multi-arch
  (`linux/amd64,linux/arm64`), pushed to **both Docker Hub and GHCR**, and **cosign-signed**.

### The `latest` tag

`latest` must always point at the **newest** major version. The workflow never auto-assigns it
(`flavor: latest=false`); it emits `latest` **only when the tag's major equals the `LATEST_MAJOR`
env var** in the workflow. That env var is the one piece of state that cannot be derived from a tag
("which major is currently newest"). Because `latest` is gated on a fixed value rather than push
order, **tag-push order is irrelevant** and republishing an old version can never steal `latest`.

### Recipe: release a new major version (e.g. Postgres 16)

```bash
git switch master && git pull
# 1. In .github/workflows/docker-publish.yml, bump:  LATEST_MAJOR: "16"
# 2. (Optional) bump the Dockerfile's `ARG PG_VERSION=16` default, for local builds.
git commit -am "postgres 16 is now the newest"
git push origin master                       # build-only smoke test (builds pg16 via the new default)

# 3. Tag to publish `16` + `latest` (Docker Hub + GHCR):
git tag v16.0.0 && git push origin v16.0.0
```

That's it — no new branch, and nothing to "demote": the previous newest stops getting `latest`
automatically, because `latest` now keys off `LATEST_MAJOR`.

### Recipe: republish or build any version (e.g. rebuild Postgres 14)

No branch needed — just tag `master`. `vN.0.0` already exists, so bump to the next **unused** patch
(`git tag -l 'v14.*'` first — e.g. Postgres 9 already has both `v9.0.0` and `v9.0.1`, so its next
rebuild is `v9.0.2`).

```bash
git switch master && git pull
git tag v14.0.1 && git push origin v14.0.1   # builds & publishes `14`; `latest` untouched (14 ≠ LATEST_MAJOR)
```

To preview an arbitrary version's build **without** publishing, run the workflow manually
(GitHub ▸ Actions ▸ Docker ▸ Run workflow ▸ `pg_version = 14`), or build locally:
`docker build --build-arg PG_VERSION=14 .`.

After any release:

1. **Verify the published artifact** — pull the image, confirm the schema (`16 tables + 7 views`)
   and the PostgreSQL version, and confirm `latest` still points at the newest major.
2. **Update the README "Available versions" table** — it is maintained by hand. Set the row's
   **Release** cell to the new tag (e.g. `v14.0.1`), and fill in the **GitHub Container Registry**
   cell (replace `—` with `ghcr.io/sakiladb/postgres:N`) the first time a version is published under
   the GHCR-enabled workflow. Add a dated **Changelog** entry if the change is user-visible.

> **Legacy branches.** Earlier releases used one long-lived `postgres-N` branch per version. Those
> branches are obsolete under the tag-driven model and can be deleted — the immutable `vN.0.x` tags
> preserve every release (`git checkout vN.0.x` rebuilds it exactly).

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the major version only (`15`); `latest` on the newest. Git tags are semver
  `vN.0.x`.
- **No AI attribution** in commits, tags, PRs, or any other content.
