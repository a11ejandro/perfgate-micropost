# Baseline Micropost — Implementation Progress

**Status:** Complete (main branch + 8 regression branches)
**Location:** `/Users/alex/Code/baseline-micropost/`
**Spec source:** `baseline_sample_app.md`

---

## What is built

A Rails 7.1 reference application used to demonstrate and regression-test the
Baseline gem. Intentionally minimal — no auth, no rich text, no background
infrastructure beyond PostgreSQL.

---

## Environment decisions

| Decision | Choice | Reason |
|---|---|---|
| Ruby version | 3.3.4 (rbenv) | Already had `rails 7.1.3.4` installed; not the default (3.2.2) |
| Rails version | 7.1.3.4 | Matches the baseline gem's own test matrix (`activerecord ~> 7.1`) |
| Database | PostgreSQL 17 via docker-compose | Spec requires Postgres; docker-compose avoids local installation |
| Docker image | `postgres:17-alpine` | Lightweight; PG 17 matches locally installed `psql` client |
| DB credentials | user: `baseline`, password: `baseline` | Simple dev default; no secrets in repo |
| App location | `/Users/alex/Code/baseline-micropost/` | Standalone sibling repo, not nested inside baseline gem |
| Baseline gem ref | `path: "../baseline/baseline"` | Local path dep during dev; not published |
| Pagination | kaminari 1.2 | Standard Rails pagination gem; no DSL complexity |
| Test framework | rspec-rails 6.1, factory_bot_rails 6 | Perfgate requires RSpec; factory_bot for fixtures |
| DB cleanup | transactional fixtures for normal specs; reset/reseed for Perfgate workloads | Forked workload processes must not inherit Rails test transactions |

---

## What was built (implementation order)

### Step 1 — Rails skeleton
- `rails new baseline-micropost --database=postgresql` with unused components skipped
  (mailer, mailbox, active text, active storage, cable, jbuilder, minitest)
- `docker-compose.yml` with postgres:17-alpine, healthcheck
- `config/database.yml` with ENV-overridable host/port/username/password
- `.ruby-version` = 3.3.4
- `bundle exec rails db:create` — both `_development` and `_test` databases created

### Step 2 — Models and migrations
Three migrations:
- `create_users`: name (not null), email (not null, unique index)
- `create_microposts`: user_id (FK + index), content (not null), comments_count (default 0, not null), created_at index
- `create_comments`: user_id (FK + index), micropost_id (FK, no standalone index), content (not null), created_at index, composite index `(micropost_id, created_at)`

Models: standard validations, `belongs_to :micropost, counter_cache: true` on Comment.

### Step 3 — Deterministic seed (`db/seeds.rb`)
- `PRNG = Random.new(42)`, epoch = `2024-01-01 00:00:00 UTC`
- Sizes configurable via `SAMPLE_USERS`, `SAMPLE_MICROPOSTS`, `SAMPLE_COMMENTS`
- Defaults: 100 / 5 000 / 50 000
- `insert_all!` for bulk performance (~4s for full dataset)
- Counter cache recalculated post-insert with a single SQL UPDATE
- `BASELINE_DATASET_VERSION=micropost-v1`

### Step 4 — Controllers, job, routes, views
- `MicropostsController`: `#index` (paginated, includes user), `#show` (micropost + paginated comments with users), `#search` (ILIKE, paginated)
- `CommentsController`: `#create` with redirect; uses `User.order(:id).first` as author (no auth in MVP)
- `MicropostDigestJob`: `includes(:user)`, reads `comments_count` from counter cache, returns plain hash
- Routes: `resources :microposts, only: %i[index show]` with `collection { get :search }` and nested `resources :comments, only: %i[create]`
- Views: minimal server-rendered ERB; layout with nav

### Step 5 — RSpec suite (29 examples, 0 failures)
- `spec/models/` — user, micropost, comment validations + counter cache
- `spec/requests/microposts_spec.rb` — index, show (with N+1 query-count guard), search, comment create
- `spec/jobs/micropost_digest_job_spec.rb` — output shape + N+1 query-count guard
- `spec/factories/` — user, micropost, comment

### Step 6 — Baseline integration
- `baseline.yml` uses the correct schema keys (`execution`, `metrics`, `comparison.practical_thresholds`, `policy`, `storage`)
- `spec/rails_helper.rb` requires `baseline/rspec` and `database_cleaner/active_record`
- `spec/support/workload_fixtures.rb` — idempotent `find_or_create_by!` fixture for workload specs
- `spec/baseline/workloads_spec.rb` — 5 workloads, all tagged with stable `baseline: { id: "..." }`
- `baseline run` verified end-to-end: all 5 workloads execute, stable timings

```
baseline run: 5 workload(s) -> .baseline/main/runs/<uuid>
  microposts.index              median=3.91ms (n=8)
  microposts.show               median=3.62ms (n=8)
  microposts.search             median=5.96ms (n=8)
  comments.create               median=5.40ms (n=8)
  micropost_digest.perform      median=2.85ms (n=8)
```

### Step 7 — Git history
- `main` branch: 3 commits (initial app, fixture fix, docs)
- 8 `regression/*` branches, each off `main`, one commit per branch

---

## Regression branches

| Branch | File(s) changed | Regression | Expected workload signal |
|---|---|---|---|
| `regression/microposts-index-n-plus-one` | `microposts_controller.rb` | Removed `includes(:user)` from index | `microposts.index` sql_count +20/page |
| `regression/micropost-show-comment-authors-n-plus-one` | `microposts_controller.rb` | Removed `includes(:user)` from comments query | `microposts.show` sql_count +N |
| `regression/microposts-index-comment-count-query` | `index.html.erb` | `mp.comments.count` (×2) instead of counter cache | `microposts.index` sql_count +40/page |
| `regression/micropost-search-unindexed-pattern` | `microposts_controller.rb` | `.to_a` before paginate — loads all matches into Ruby | `microposts.search` duration + allocations |
| `regression/comment-create-recount` | `comment.rb` | Replaced `counter_cache: true` with `after_create { micropost.comments.count + update! }` | `comments.create` sql_count +2 |
| `regression/digest-job-n-plus-one` | `micropost_digest_job.rb` | Removed `includes(:user)`, reads `mp.comments.count` | `micropost_digest.perform` sql_count +2×limit |
| `regression/digest-job-allocation-growth` | `micropost_digest_job.rb` | JSON round-trip + `dup` per entry; SQL unchanged | `micropost_digest.perform` allocations |
| `regression/micropost-show-unbounded-comments` | `microposts_controller.rb`, `show.html.erb` | Removed `.page.per` — loads all comments | `microposts.show` duration + allocations |

---

## Known issues / constraints

**Workload fixture transaction behavior.** Perfgate runs workloads in forked child
processes. The workload spec opts out of Rails transactional fixtures and calls
`WorkloadFixtures.setup` before each sample, which deletes and reseeds the small
workload dataset so each measurement starts from identical state.

**CommentsController uses first user as author.** No auth in the MVP. The `create`
action calls `User.order(:id).first`. This is intentional per spec §14 ("no
authentication initially") and kept simple for reproducibility.

**Workload specs run in test env against fixture data, not the seeded dev DB.**
`perfgate run` loads the RSpec suite (RAILS_ENV=test), so workloads operate on the
fixture data from `WorkloadFixtures.setup` (10 users / 50 posts / 200 comments),
not the 100/5000/50000 seed. This keeps `perfgate run` fast and self-contained
but means timing profiles are against a smaller dataset than production-scale seeding.
Increasing workload fixture sizes is a straightforward tuning knob.

**`baseline compare` not yet smoke-tested with regression branches.** The `baseline run`
step works. The full `run → compare` pipeline was verified on the baseline gem's own
test suite and examples but not yet exercised with this app's regression branches.

**Dockerfile is a stale artifact.** `/Users/alex/Code/baseline-micropost/Dockerfile`
was generated by `rails new` — it is a production Rails container definition, unrelated
to the docker-compose Postgres setup. It has not been customized and is not used by
any current workflow.

---

## File structure (key files only)

```
baseline-micropost/
├── app/
│   ├── controllers/
│   │   ├── microposts_controller.rb
│   │   └── comments_controller.rb
│   ├── jobs/
│   │   └── micropost_digest_job.rb
│   ├── models/
│   │   ├── user.rb
│   │   ├── micropost.rb
│   │   └── comment.rb
│   └── views/microposts/
│       ├── index.html.erb
│       └── show.html.erb
├── config/
│   ├── database.yml          # ENV-overridable Postgres credentials
│   └── routes.rb
├── db/
│   ├── migrate/              # 3 migrations
│   └── seeds.rb              # deterministic seed, PRNG(42)
├── spec/
│   ├── baseline/
│   │   └── workloads_spec.rb # 5 Baseline workloads
│   ├── factories/            # user, micropost, comment
│   ├── jobs/
│   ├── models/
│   ├── requests/
│   ├── support/
│   │   ├── workload_fixtures.rb
│   │   └── baseline_workload_support.rb
│   └── rails_helper.rb
├── docs/
│   ├── workloads.md
│   ├── dataset.md
│   └── regressions.md
├── baseline.yml
├── docker-compose.yml        # postgres:17-alpine on 5432
├── Gemfile                   # baseline path: ../baseline/baseline
└── README.md
```

---

## Suggested next steps

1. **Smoke-test `baseline compare` with a regression branch** — record a `main` run,
   switch branch, record candidate, compare; verify Baseline reports the expected
   metric as FAIL/WARN.

2. **Increase workload fixture dataset** — raise `WorkloadFixtures::DATASET_SIZE` to
   make timing signals more stable and representative (currently 50 posts / 200 comments).

3. **Wire up GitHub Actions** — adapt the example workflow from
   `baseline/examples/rails-rspec-app` to this app; the docker-compose postgres
   can be replaced with the `services: postgres:` GHA syntax.

4. **Publish gem to RubyGems.org** — switch Gemfile from `path:` to `gem "baseline", "~> 0.1"`.
