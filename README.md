# Baseline Micropost

A minimal Rails reference application for [Baseline](https://github.com/your-org/baseline),
an open-source CI-native performance assurance tool.

This application is **not a production social platform**. It exists to provide a
simple, deterministic environment for demonstrating how Baseline detects performance
regressions in Rails applications.

---

## Project purpose

Baseline Micropost demonstrates five canonical Rails workflows (a paginated index,
a detail page, a search, a write path, and a background job) against a deterministic
dataset of 100 users, 5 000 microposts, and 50 000 comments.

The `main` branch is intentionally correct: no N+1 queries, counter cache in use,
associations eager-loaded. Eight `regression/*` branches each introduce a single
isolated performance regression that Baseline is expected to detect.

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
git clone <repo-url> baseline-micropost
cd baseline-micropost

# Start PostgreSQL
docker compose up -d

# Install gems
bundle install

# Create databases and run migrations
bundle exec rails db:create db:migrate

# Seed the deterministic dataset (100 users / 5000 microposts / 50000 comments)
bundle exec rails db:seed

# Run the test suite
bundle exec rspec

# Run Baseline workloads
BASELINE_DATASET_VERSION=micropost-v1 \
  bundle exec baseline run --output .baseline/main
```

Optional: reduce the dataset size for faster local iteration:

```bash
SAMPLE_USERS=10 SAMPLE_MICROPOSTS=100 SAMPLE_COMMENTS=500 \
  bundle exec rails db:seed
```

---

## Baseline workloads

Five stable workload IDs are defined in `spec/baseline/workloads_spec.rb`:

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

The seed is deterministic: `PRNG = Random.new(42)` with a fixed epoch of
`2024-01-01 00:00:00 UTC`. Repeated seeding produces logically equivalent data.

Set `BASELINE_DATASET_VERSION=micropost-v1` so Baseline can fingerprint the
dataset and refuse to compare runs built against different data.

See [docs/dataset.md](docs/dataset.md).

---

## Regression lab

Eight branches demonstrate common Rails performance anti-patterns. Each branch is
functionally correct; only the performance characteristics change.

```bash
# Record a main-branch baseline
BASELINE_DATASET_VERSION=micropost-v1 \
  bundle exec baseline run --output .baseline/main

# Switch to a regression branch and compare
git checkout regression/microposts-index-n-plus-one
BASELINE_DATASET_VERSION=micropost-v1 \
  bundle exec baseline run \
    --output .baseline/candidate \
    --compare .baseline/main \
    --format markdown
```

### Expected results

| Branch | Workload | Expected regression |
|---|---|---|
| `regression/microposts-index-n-plus-one` | `microposts.index` | SQL count |
| `regression/micropost-show-comment-authors-n-plus-one` | `microposts.show` | SQL count |
| `regression/microposts-index-comment-count-query` | `microposts.index` | SQL count and duration |
| `regression/micropost-search-unindexed-pattern` | `microposts.search` | Duration and SQL duration |
| `regression/comment-create-recount` | `comments.create` | SQL count and write duration |
| `regression/digest-job-n-plus-one` | `micropost_digest.perform` | SQL count |
| `regression/digest-job-allocation-growth` | `micropost_digest.perform` | Allocations |
| `regression/micropost-show-unbounded-comments` | `microposts.show` | Duration and allocations |

See [docs/regressions.md](docs/regressions.md) for code-level detail on each regression.

---

## License

Apache-2.0. See [LICENSE](../baseline/LICENSE) in the Baseline gem repository.
