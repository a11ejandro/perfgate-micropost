# Dataset

## Design

The seed is deterministic: every run produces logically equivalent data.

- **PRNG**: `Random.new(42)` — fixed seed, no external randomness
- **Epoch**: `2024-01-01 00:00:00 UTC` — all timestamps derived from this base
- **Content**: generated from small fixed word lists, not Faker
- **Dataset version**: `micropost-v1`

## Default sizes

| Table | Default | ENV override |
|---|---|---|
| users | 100 | `SAMPLE_USERS` |
| microposts | 5 000 | `SAMPLE_MICROPOSTS` |
| comments | 50 000 | `SAMPLE_COMMENTS` |

## Seeding

```bash
# Full dataset
bundle exec rails db:seed

# Small dataset for fast local iteration
SAMPLE_USERS=10 SAMPLE_MICROPOSTS=100 SAMPLE_COMMENTS=500 \
  bundle exec rails db:seed

# Reset and reseed
bundle exec rails db:drop db:create db:migrate db:seed
```

The seed uses `insert_all!` for bulk performance and recalculates the
`comments_count` counter cache via a single SQL UPDATE after insertion.

## Dataset fingerprinting

Set the following environment variable so Baseline records the dataset version
in each run bundle and refuses to compare runs against incompatible data:

```bash
export BASELINE_DATASET_VERSION=micropost-v1
```

The default fallback value is `unspecified`. Baseline will warn (not fail) if you
compare a run with `unspecified` against one with `micropost-v1`.
