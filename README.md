# Perfgate Micropost

A minimal Rails reference application for [Perfgate](https://github.com/a11ejandro/perfgate),
an open-source CI-native performance assurance tool.

[![Perfgate](https://github.com/a11ejandro/perfgate-micropost/actions/workflows/perfgate.yml/badge.svg)](https://github.com/a11ejandro/perfgate-micropost/actions/workflows/perfgate.yml)

This application is **not a production social platform**. It exists to provide a
simple, deterministic environment for demonstrating how Perfgate detects performance
regressions in Rails applications.

---

## Project purpose

Perfgate Micropost demonstrates five canonical Rails workflows (a paginated index,
a detail page, a search, a write path, and a background job). Performance
observations recreate a dedicated deterministic dataset of 10 users, 500
microposts, and 2 500 comments before each observation.

The `main` branch is intentionally correct: no N+1 queries, counter cache in use,
associations eager-loaded. Eight `regression/*` branches each introduce a single
isolated performance regression that Perfgate is expected to detect.

---

## Domain

| Model | Associations |
|---|---|
| User | has_many :microposts, has_many :comments |
| Micropost | belongs_to :user, has_many :comments (with counter_cache) |
| Comment | belongs_to :user, belongs_to :micropost |

---

## Setup

**Requirements:** Ruby 3.3+, Docker (for PostgreSQL via docker-compose).

```bash
git clone https://github.com/a11ejandro/perfgate-micropost.git
cd perfgate-micropost

# Start PostgreSQL
docker compose up -d

# Install gems
bundle install

# Create databases and run migrations
bundle exec rails db:create db:migrate

# Seed the application demonstration dataset (not used by Perfgate workloads)
bundle exec rails db:seed

# Run the test suite
bundle exec rspec

# Run Perfgate workloads
DB_HOST=127.0.0.1 PGGSSENCMODE=disable \
  bundle exec perfgate run --output .perfgate/main
```

Optional: reduce the dataset size for faster local iteration:

```bash
SAMPLE_USERS=10 SAMPLE_MICROPOSTS=100 SAMPLE_COMMENTS=500 \
  bundle exec rails db:seed
```

---

## Perfgate workloads

Five stable workload IDs are defined in `spec/perfgate/workloads_spec.rb`:

| Workload ID | Endpoint / action | What it measures |
|---|---|---|
| `microposts.index` | `GET /microposts` | Paginated index with eager-loaded authors |
| `microposts.show` | `GET /microposts/:id` | Detail page with paginated comments |
| `microposts.search` | `GET /microposts/search?q=rails` | SQL ILIKE search with pagination |
| `comments.create` | `POST /microposts/:id/comments` | Write path with counter cache update |
| `micropost_digest.perform` | `MicropostDigestJob#perform` | Background job with batched association loading |

See [docs/workloads.md](docs/workloads.md) for full details.

---

## Dataset

The performance fixture is deterministic: seed `12345`, a fixed epoch, declared
cardinalities and skew, and a database reset before every observation. The
fixture intentionally does not claim a cold cache. Its complete contract is in
`perfgate.yml` and is recorded and fingerprinted by Perfgate.

See [docs/dataset.md](docs/dataset.md).

---

## Regression lab

Eight branches demonstrate common Rails performance anti-patterns. Each branch is
functionally correct; only the performance characteristics change.

```bash
# Record a main-branch baseline
DB_HOST=127.0.0.1 PGGSSENCMODE=disable \
  bundle exec perfgate run --output .perfgate/main

# Switch to a regression branch and compare
git checkout regression/microposts-index-n-plus-one
DB_HOST=127.0.0.1 PGGSSENCMODE=disable \
  bundle exec perfgate run \
    --output .perfgate/candidate \
    --compare .perfgate/main \
    --format markdown
```

### Intended regression signals

| Branch | Workload | Expected regression |
|---|---|---|
| `regression/microposts-index-n-plus-one` | `microposts.index` | SQL count |
| `regression/micropost-show-comment-authors-n-plus-one` | `microposts.show` | SQL count |
| `regression/microposts-index-comment-count-query` | `microposts.index` | SQL count and duration |
| `regression/micropost-search-unindexed-pattern` | `microposts.search` | Allocations |
| `regression/comment-create-recount` | `comments.create` | SQL count and write duration |
| `regression/digest-job-n-plus-one` | `micropost_digest.perform` | SQL count |
| `regression/digest-job-allocation-growth` | `micropost_digest.perform` | Allocations |
| `regression/micropost-show-unbounded-comments` | `microposts.show` | Allocations |

See [docs/regressions.md](docs/regressions.md) for code-level detail on each regression.
These are experimental conditions, not established detection rates. Repeated
calibration and held-out trials are required before reporting sensitivity.

---

## Public CI demonstration

The GitHub Actions workflow at
[.github/workflows/perfgate.yml](.github/workflows/perfgate.yml) is the public
demo entry point:

- [Perfgate workflow runs](https://github.com/a11ejandro/perfgate-micropost/actions/workflows/perfgate.yml)
- Example passing PR: TODO
- Example SQL regression PR: TODO
- Example duration/allocation regression PR: TODO
- Example incompatible workload PR: TODO

To make the demo publicly accessible:

1. Keep this app in the public
   [`a11ejandro/perfgate-micropost`](https://github.com/a11ejandro/perfgate-micropost)
   repository so the badge and links above resolve to the studied subject.
2. Keep the Perfgate gem source public. The Gemfile uses the public Git repository,
   pinned by `Gemfile.lock`, so CI can bundle without access to a local checkout.
   To develop both repositories together, use Bundler's ignored local override:
   `bundle config set --local local.perfgate ../baseline`.
3. In GitHub, enable **Settings -> Actions -> General -> Allow actions and
   reusable workflows**. The workflow declares only `contents: read` and
   `actions: read` permissions.
4. Run the workflow once on `main`; it uploads the `perfgate-main` artifact.
5. Open demo PRs from the `regression/*` branches. Public visitors can inspect
   the PR checks, job logs, and Markdown job summaries without cloning the app.

The workflow uses the GitHub CLI (`gh run list` / `gh run download`) to fetch the
latest successful `main` run's `perfgate-main` artifact. The very first PR run may
have no baseline artifact yet; in that case `perfgate run --compare` reports a
missing baseline warning instead of crashing. GitHub Actions artifacts expire, so
the README links to workflow runs and PRs as the durable public demonstration,
not to artifact download URLs.

Rails secret keys, including `config/master.key`, are ignored. The previously
tracked development key has also been removed from local Git history; replacement
keys must remain untracked.

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE). Perfgate is a separate work and
retains its own license.
