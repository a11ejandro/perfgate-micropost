# Workloads

Five stable Baseline workloads are defined in `spec/baseline/workloads_spec.rb`.

All setup (record lookup, fixture creation) runs **outside** `Baseline.measure`.
Assertions run **outside** the measured block. Only the single application action
sits inside `Baseline.measure`.

---

## microposts.index

```
GET /microposts
```

Measures: paginated micropost listing with author names and comment counts.

Healthy implementation: `Micropost.includes(:user).newest_first.page(1).per(20)` — one
query for microposts, one for users, no per-row queries.

Common regression: removing `includes(:user)` triggers N+1 author queries.

---

## microposts.show

```
GET /microposts/:id
```

Measures: micropost detail page including a paginated page of comments with authors.

Healthy implementation: two includes — one for the micropost's user, one for
comments+user. No per-comment author query.

Common regression: removing `includes(:user)` from comments query.

---

## microposts.search

```
GET /microposts/search?q=rails
```

Measures: ILIKE content search, paginated, with author names.

Healthy implementation: `WHERE content ILIKE ? LIMIT 20 OFFSET 0` — single query
with database-side pagination.

Common regression: loading all matching records into Ruby before paginating.

---

## comments.create

```
POST /microposts/:micropost_id/comments
```

Measures: comment insert + counter cache update on the micropost.

Healthy implementation: `Comment#create!` with `counter_cache: true` — two queries:
INSERT on comments, UPDATE on microposts (increment only, no SELECT COUNT).

Common regression: replacing counter cache with `micropost.comments.count` + `update!`.

---

## micropost_digest.perform

```ruby
MicropostDigestJob.new.perform(limit: 50)
```

Measures: background job that builds a structured digest of recent microposts with
author names and comment counts.

Healthy implementation: `Micropost.includes(:user).newest_first.limit(50)` — two
queries (microposts+users eager-loaded, comments_count from counter cache column).

Common regressions:
- Accessing `mp.user.name` without eager loading → N+1 author queries.
- Calling `mp.comments.count` instead of reading `mp.comments_count` → N+1 COUNT queries.
- Excessive object allocation (JSON round-trips, repeated `dup`).
