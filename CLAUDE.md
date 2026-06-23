# CLAUDE.md

Maintainer guide for `sakiladb/postgres` — a Postgres Docker image preloaded with
the Sakila example database, published to
[Docker Hub](https://hub.docker.com/r/sakiladb/postgres) and GHCR.

## How the image is built

`Dockerfile` is a two-stage build:

1. **`dumper` stage** — starts from `postgres:N-alpine`, copies the four SQL files
   into `/docker-entrypoint-initdb.d/`, neuters the entrypoint's `exec "$@"` so the
   server doesn't stay running, then runs the entrypoint once to initialize the DB
   into `$PGDATA` (`/data`).
2. **final stage** — starts from `postgres:N-alpine` again and copies the populated
   `/data` from the dumper stage, so the published image ships with Sakila already
   loaded (no init at container start).

The SQL files run in order: `0-` creates a temp `postgres` superuser (the dump was
authored as `postgres`), `1-` schema, `2-` data, `3-` reassigns ownership to the
`sakila` user and drops the temp `postgres` user.

## How releases work

There is **one long-lived branch per Postgres major version** (`postgres-9` …
`postgres-15`) and the publish is triggered by **pushing a semver tag `vN.0.0`**.

- `.github/workflows/docker-publish.yml` builds on every branch / PR / tag push, but
  **only pushes to a registry on `v*.*.*` tag pushes**
  (`push: ${{ startsWith(github.ref, 'refs/tags/v') ... }}`). Branch and PR pushes are
  build-only smoke tests — they do not publish.
- Each release tag points to a commit **on its matching `postgres-N` branch**
  (e.g. `v15.0.0` lives on `postgres-15`).
- The tag's Docker metadata config is `type=semver,pattern={{major}}`, so pushing
  `v15.0.0` produces the Docker tag **`15`** (major only) **plus `latest`** (the
  metadata-action default `latest=auto`). Images are multi-arch
  (`linux/amd64,linux/arm64`), published to both Docker Hub and `ghcr.io`, and
  cosign-signed.

### ⚠️ Two gotchas

1. **`latest=auto` makes the *last tag pushed* win `latest`.** The metadata-action
   re-points `latest` on every semver tag push; it does not compare against existing
   tags. When releasing multiple versions, **push the highest version's tag last** so
   `latest` ends up on the newest Postgres.
2. **Branch new versions from the latest `postgres-N` branch** (and keep `master` in
   sync with it). The workflow has evolved over time (GHCR publishing, action version
   bumps); branching from a stale source silently loses those.

### Releasing a new major version (e.g. Postgres 16)

```bash
git fetch origin

# 1. Branch from the latest version branch (NOT from a stale master).
git switch -c postgres-16 origin/postgres-15

# 2. Bump BOTH `FROM postgres:15-alpine` lines in Dockerfile to 16-alpine
#    (the `as dumper` stage on line 1 and the final stage on line 19).
$EDITOR Dockerfile

git commit -am "postgres-16"

# 3. Push the branch — this runs a build-only smoke test (no publish).
git push -u origin postgres-16

# 4. Once the branch build is green, tag and push to publish.
#    The tag push builds + pushes Docker tags `16` and `latest` to Docker Hub + GHCR.
git tag v16.0.0
git push origin v16.0.0
```

Releasing several versions at once (e.g. 16 and 17): branch `postgres-17` from
`postgres-16`, and **push `v17.0.0` last** so `latest` points at 17.

After a release, keep `master` current: `master` should match the newest
`postgres-N` branch (apart from the pinned Postgres version) so it stays a valid base
to branch from.

## Conventions

- Default DB / user / password: `sakila` / `sakila` / `p_ssW0rd` (see README).
- No AI attribution in commits, tags, or PRs.
