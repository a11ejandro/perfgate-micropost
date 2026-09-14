# Dataset

## Performance-workload dataset

Perfgate workloads do not use `db/seeds.rb`. Before each observation,
`WorkloadFixtures.setup` recreates a dedicated deterministic dataset outside the
measured block.

- **PRNG**: `Random.new(12345)` — fixed seed, no external randomness
- **Epoch**: `2024-01-01 00:00:00 UTC` — all timestamps derived from this base
- **Dataset ID**: `perfgate-micropost-workload-fixtures`
- **Schema/generator version**: `2` / `2`
- **Reset**: `TRUNCATE ... RESTART IDENTITY CASCADE` before every observation
- **Cache state**: no explicit PostgreSQL or operating-system cache flush

The first micropost receives 200 comments so the paginated and deliberately
unbounded show-page variants exercise materially different row counts. Remaining
comments are distributed deterministically among the other microposts.

| Table | Rows |
|---|---|---|
| users | 10 |
| microposts | 500 |
| comments | 2 500 |

## Seeding

```bash
RAILS_ENV=test bundle exec rails runner \
  'require Rails.root.join("spec/support/workload_fixtures"); p WorkloadFixtures.setup'
```

The fixture uses `insert_all!` and recalculates the `comments_count` counter
cache with one SQL update after insertion. Configuration in `perfgate.yml` is
the canonical evidence declaration and must be updated whenever the generator
or its scale changes.

## Dataset fingerprinting

Perfgate hashes the complete `dataset` mapping from `perfgate.yml`. A change to
its ID, versions, seed, scale, skew, relationships, or cache-state declaration
makes historical evidence incomparable.

## Application demonstration seed

`db/seeds.rb` remains available for manually exploring the Rails application.
It is not used by the five Perfgate workloads and is not part of their evidence
contract.
