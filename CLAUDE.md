# CLAUDE.md

Maintainer guide for **`sakiladb/postgres`** — a PostgreSQL Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database (via [jOOQ](https://www.jooq.org/sakila)),
published to [Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and
[GitHub Container Registry](https://github.com/sakiladb/postgres/pkgs/container/postgres).

> One of the [`sakiladb`](https://github.com/sakiladb) image family (`postgres`, `mysql`, `mariadb`,
> `sqlserver`, `oracle`, `clickhouse`, `rqlite`). The release machinery in
> [How releases work](#how-releases-work) is **shared across the family**; the build details
> in [How the image is built](#how-the-image-is-built) are **PostgreSQL-specific**. The org-level
> landing page ([github.com/sakiladb](https://github.com/sakiladb)) is rendered from the
> [`sakiladb/.github`](https://github.com/sakiladb/.github) repo (`profile/README.md`); edit it
> there to change the family overview.

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

The standard Sakila database, preloaded and owned by the `sakila` user: **16 tables + 7 views**,
kept consistent with the other sakiladb variants (the `sq` fixture contract). Two ways this image is
trimmed from the upstream jOOQ Postgres dump so it lines up with the rest of the family:

- **`film_text`** is present (populated from `film`) for parity with the other variants. The jOOQ
  dump instead shipped a `film.fulltext` `tsvector` column (GiST index + trigger) for full-text
  search; we removed it so `film` exposes the same columns everywhere. `film_text` keeps the same
  three columns as every other variant, but full-text search still **works** — via a *functional*
  GIN index (no stored `tsvector` column), so FTS is added "under" the table, invisible to the
  schema. Mutation-maintenance triggers keep it in sync with `film` (see below).
- **`payment` is a plain table.** The jOOQ dump's empty `payment_p2007_*` inheritance partitions are
  dropped — they were vestigial (all payment rows live in the parent) and made Postgres report 21
  tables instead of 16.

These customizations live in `1-postgres-sakila-schema.sql` (with the `film_text` populate, its FTS
index, and the mutation triggers in `3-postgres-sakila-user.sql`), clearly commented.

Beyond the table/view set, the schema is reconciled to the canonical `sakiladb/mysql` image wherever
it's cheap and `sq`-invisible: `customer.active` is `boolean` (matching `staff.active` and MySQL's
intent), column order / nullability / FK-column indexes match MySQL, and a set of
**mutation-maintenance triggers** (in `3-…`) gives writable parity with MySQL — they keep `film_text`
in sync with `film` (`ins_film` / `upd_film` / `del_film`) and stamp `create_date` / `payment_date` /
`rental_date` on insert. All of this is invisible to `sq` (it counts tables/views, not triggers or
column types for these tables), so the fixture contract is unchanged.

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
| `1-postgres-sakila-schema.sql` | Schema: tables, views, indexes (incl. FK-column indexes). Also creates `film_text` and drops the `payment_p2007_*` partitions. |
| `2-postgres-sakila-insert-data.sql` | Data (`Insert into …` statements). |
| `3-postgres-sakila-user.sql` | Populate `film_text` from `film`; add its functional FTS GIN index and the mutation-maintenance triggers; reassign ownership of everything to `sakila`; drop the temp `postgres` user; log the completion message. |

This all happens at **build** time, in the dumper stage — `3-…` logs `sakiladb/postgres has
successfully initialized.` into the build output. At **runtime** the final image just starts
Postgres against the pre-baked data dir (the entrypoint logs `Skipping initialization`), so it is
ready in about a second and that build-time message does *not* reappear.

### Readiness (HEALTHCHECK)

The final stage declares a Docker `HEALTHCHECK` (`pg_isready -U sakila -d sakila`), so the container
reports `healthy` once Postgres accepts connections — consumers wait on that rather than grepping
logs. `pg_isready` can exit `2`/`3` (values Docker reserves), so the check normalizes any failure to
exit `1`. The `sakila` user/db are hardcoded because the final stage does not carry the build
stage's `POSTGRES_*` env vars.

> **Family convention:** every `sakiladb` image declares a `HEALTHCHECK` using its engine's
> native readiness probe (`pg_isready`, `mysqladmin ping`, `sqlcmd … SELECT 1`,
> `healthcheck.sh SAKILA`, …). The probe command differs per engine; the readiness *contract*
> (`healthy` = ready to serve) is uniform.

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

### Attestations (provenance + SBOM)

Beyond the cosign signature, each release attaches two supply-chain attestations to the published
image, in the `build` job after the push. The job needs `attestations: write`:

- **SLSA build provenance** via `actions/attest-build-provenance` — one step per registry
  (`subject-name` differs, same `subject-digest` = `steps.build-and-push.outputs.digest`).
- **An SPDX SBOM** generated by `anchore/sbom-action`, attested via `actions/attest` (the unified
  action — **not** the deprecated `actions/attest-sbom`, whose bundle wouldn't verify over OCI).

Both use `push-to-registry: true`, so they land in GitHub's attestation store **and** as OCI
referrers on Docker Hub and GHCR (what Docker Scout reads). Two load-bearing gotchas:

- **`SYFT_FILE_METADATA_SELECTION: none` on the SBOM step is required.** Syft's default file
  cataloging records per-file metadata for every file in the image; on a large image the SPDX
  exceeds `actions/attest`'s **16 MiB predicate limit** and the step fails (this broke a mysql
  release). It keeps the component (package) inventory and drops the heavy per-file data.
- **GHCR has no OCI Referrers API** — it uses the referrers-tag fallback (`sha256-<digest>`).
  Transparent to `gh attestation verify` and Scout; only a raw referrers-API `curl` is affected.

The release workflow **self-verifies**: a **Verify attestations** step gates the release on both the
GitHub-store and registry-referrer copies of provenance + SBOM, across both registries (referrer reads
are retried to absorb post-push lag). To spot-check a published image by hand (both should exit 0):

```bash
gh attestation verify oci://ghcr.io/sakiladb/postgres:18 --repo sakiladb/postgres
gh attestation verify oci://ghcr.io/sakiladb/postgres:18 --repo sakiladb/postgres \
  --predicate-type https://spdx.dev/Document          # the SBOM (add --bundle-from-oci for the referrer)
```

> **Porting caveat — oracle differs.** Oracle builds per-arch on native runners and stitches the
> manifest in a separate `merge` job, so its attest steps live **there** and key on the manifest-list
> digest captured from `docker buildx imagetools inspect ... --format '{{.Manifest.Digest}}'`, not a
> build-push output. The single-job repos (this one, mysql, mariadb, sqlserver, clickhouse, rqlite)
> use the pattern above verbatim.

The release also syncs this README to the Docker Hub repository description (`peter-evans/dockerhub-description`,
`continue-on-error`, full-description only; GHCR renders the linked repo README automatically).

### The `latest` tag

`latest` must always point at the **newest** major version. The workflow never auto-assigns it
(`flavor: latest=false`); it emits `latest` **only when the tag's major equals the `LATEST_MAJOR`
env var** in the workflow. That env var is the one piece of state that cannot be derived from a tag
("which major is currently newest"). Because `latest` is gated on a fixed value rather than push
order, **tag-push order is irrelevant** and republishing an old version can never steal `latest`.

### Recipe: release a new major version (e.g. Postgres 19)

```bash
git switch master && git pull
# 1. In .github/workflows/docker-publish.yml, bump:  LATEST_MAJOR: "19"
# 2. (Optional) bump the Dockerfile's `ARG PG_VERSION=19` default, for local builds.
git commit -am "postgres 19 is now the newest"
git push origin master                       # build-only smoke test (builds pg19 via the new default)

# 3. Tag to publish `19` + `latest` (Docker Hub + GHCR):
git tag v19.0.0 && git push origin v19.0.0
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
   **sakiladb Release** cell to the new tag (e.g. `v14.0.1`); for a brand-new major, add the row
   with its **Docker Hub** and **GitHub Container Registry** cells. When the newest major changes,
   move the `:latest` annotation to the new top row. Add a dated **Changelog** entry if the change
   is user-visible.

> **Legacy branches.** Earlier releases used one long-lived `postgres-N` branch per version. Those
> branches were obsolete under the tag-driven model and have been deleted (June 2026); `master` is now
> the only branch. The immutable `vN.0.x` tags preserve every release (`git checkout vN.0.x` rebuilds
> it exactly).

## Porting this template to another sakiladb variant

This repo (README + CLAUDE.md + `Dockerfile` + workflow) is the reference template for the family.
The **release machinery** — the tag-driven workflow, `latest` gating, multi-registry push, and
cosign signing — is identical everywhere and should be copied as-is. Everything below is per-engine
and must be adapted, not blind-copied:

- **Identity.** Image name, default port (`5432`), engine name, the `sq` driver-guide link, and the
  lineage sentence. Note `sakiladb/mysql` is the *origin* of the family, **not** a jOOQ Postgres
  port — its lineage wording differs ("the MySQL Sakila", full stop).
- **HEALTHCHECK probe.** Swap `pg_isready` for the engine's native probe (`mysqladmin ping`,
  `sqlcmd … SELECT 1`, …). The readiness *contract* (`healthy` = ready to serve) stays uniform.
- **Architectures.** Do **not** blind-copy "multi-arch (`amd64`, `arm64`)". `sakiladb/sqlserver` is
  **amd64-only**. State the arches the image actually publishes.
- **The "Differences" section is engine-specific.** Postgres folds identifiers to lower-case; Oracle
  upper-cases and caps identifiers at 30 chars; ClickHouse is columnar; rqlite is SQLite. Rewrite it
  per engine — don't carry over Postgres's quirks.
- **Version scheme & table.** The major tracks the engine's upstream version, numbered differently
  per engine (PostgreSQL `9`–`18`, MySQL `5.6`/`5.7`/`8`, SQL Server `2017`/`2019`/…, Oracle `23`).
  Adjust the scheme explanation and the "Available versions" rows; set `LATEST_MAJOR` to that
  engine's newest major.
- **Schema customizations.** The `film_text` / partition trimming here is PG-specific. Each variant
  reconciles to the same **16 tables + 7 views** in its own way; keep `sq`'s expectations
  (`testh/sakila/sakila.go`) in lockstep — a schema change is always a cross-repo change.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the major version only (`18`); `latest` on the newest. Git tags are
  `v{POSTGRES_MAJOR}.{MINOR}.{PATCH}` — the major tracks the upstream PostgreSQL version, the
  minor/patch track sakiladb's own revisions. In practice only the patch moves (the minor stays
  `0`), so release tags look like `v15.0.0`, `v15.0.1`, ….
- **Trigger syntax must stay portable to pg 9.** The mutation triggers in `3-…` use
  `EXECUTE PROCEDURE`, not `EXECUTE FUNCTION` — the latter is pg 11+ syntax and fails the build on
  the older majors this image still publishes (`9`/`10`).
- **No AI attribution** in commits, tags, PRs, or any other content.
