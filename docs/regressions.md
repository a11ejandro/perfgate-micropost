# Regression branches

Each branch introduces exactly one isolated performance regression from `main`.
Every branch is **functionally correct** — tests pass, the UI renders correctly,
and the endpoint returns the expected data.

---

## regression/microposts-index-n-plus-one

**File changed:** `app/controllers/microposts_controller.rb`

**Change:** Removed `includes(:user)` from `MicropostsController#index`.

```ruby
# before (healthy)
Micropost.includes(:user).newest_first.page(1).per(20)

# after (regression)
Micropost.newest_first.page(1).per(20)
```

**Effect:** Each row in the index triggers a `SELECT users WHERE id = ?` for
the author. With 20 rows per page, this adds ~20 extra queries.

**Expected Baseline signal:** `microposts.index` — sql_count increases, sql_duration increases.

---

## regression/micropost-show-comment-authors-n-plus-one

**File changed:** `app/controllers/microposts_controller.rb`

**Change:** Removed `includes(:user)` from the comments query in `#show`.

```ruby
# before (healthy)
@micropost.comments.includes(:user).oldest_first.page(1).per(20)

# after (regression)
@micropost.comments.oldest_first.page(1).per(20)
```

**Effect:** Each comment on the page triggers a separate author query.

**Expected Baseline signal:** `microposts.show` — sql_count increases with page size.

---

## regression/microposts-index-comment-count-query

**File changed:** `app/views/microposts/index.html.erb`

**Change:** Replaced `mp.comments_count` (counter cache) with `mp.comments.count` (live COUNT).

```erb
<%# before (healthy) %>
<%= mp.comments_count %>

<%# after (regression) — called twice due to conditional %>
<%= mp.comments.count %> comment<%= "s" if mp.comments.count != 1 %>
```

**Effect:** Two COUNT queries per row — 40 extra queries per page of 20.

**Expected Baseline signal:** `microposts.index` — sql_count increases, sql_duration increases, duration increases.

---

## regression/micropost-search-unindexed-pattern

**File changed:** `app/controllers/microposts_controller.rb`

**Change:** Added `.to_a` before pagination, loading all matching rows into Ruby.

```ruby
# before (healthy)
base.where("content ILIKE ?", "%#{@query}%").page(1).per(20)

# after (regression)
all_matches = base.where("content ILIKE ?", "%#{@query}%").to_a
Kaminari.paginate_array(all_matches).page(1).per(20)
```

**Effect:** Database returns all matching rows; Ruby instantiates them all before
Kaminari discards all but the first page. With 5 000 posts matching `#rails`,
this allocates ~5 000 AR objects instead of 20.

**Expected Baseline signal:** `microposts.search` — duration increases, sql_duration increases, allocations may increase.

---

## regression/comment-create-recount

**File changed:** `app/models/comment.rb`

**Change:** Replaced `counter_cache: true` with an `after_create` callback that
runs `SELECT COUNT` then `UPDATE`.

```ruby
# before (healthy)
belongs_to :micropost, counter_cache: true

# after (regression)
belongs_to :micropost
after_create :recount_comments
def recount_comments
  micropost.update!(comments_count: micropost.comments.count)
end
```

**Effect:** Every comment create adds a SELECT COUNT and an UPDATE (with a full
row-level lock on the micropost) instead of a single atomic increment.

**Expected Baseline signal:** `comments.create` — sql_count +2, sql_duration increases, duration increases.

---

## regression/digest-job-n-plus-one

**File changed:** `app/jobs/micropost_digest_job.rb`

**Change:** Removed `includes(:user)` and changed `mp.comments_count` to `mp.comments.count`.

```ruby
# before (healthy)
microposts = Micropost.includes(:user).newest_first.limit(50)
# ...
author: mp.user.name,
comments_count: mp.comments_count,

# after (regression)
microposts = Micropost.newest_first.limit(50)
# ...
author: mp.user.name,       # N+1: one SELECT per micropost
comments_count: mp.comments.count,  # N+1: one COUNT per micropost
```

**Effect:** For `limit: 50`, adds ~100 extra queries (50 user lookups + 50 COUNTs).

**Expected Baseline signal:** `micropost_digest.perform` — sql_count increases by ~2×limit, duration increases.

---

## regression/digest-job-allocation-growth

**File changed:** `app/jobs/micropost_digest_job.rb`

**Change:** Added JSON round-trip and string duplication per entry while keeping
queries identical to main.

```ruby
# Each entry: serialize to JSON, parse back, rebuild hash, dup strings twice
raw = { ... }
normalized = JSON.parse(raw.to_json)
{ ..., author: normalized["author"].dup, content: normalized["content"].dup }
```

**Effect:** SQL queries unchanged. Each entry allocates multiple intermediate
objects that don't appear on main.

**Expected Baseline signal:** `micropost_digest.perform` — allocations increase significantly, sql_count unchanged.

---

## regression/micropost-show-unbounded-comments

**File changed:** `app/controllers/microposts_controller.rb`, `app/views/microposts/show.html.erb`

**Change:** Removed `.page(…).per(…)` from the comments query.

```ruby
# before (healthy)
@micropost.comments.includes(:user).oldest_first.page(1).per(20)

# after (regression)
@micropost.comments.includes(:user).oldest_first
```

**Effect:** Loads all comments for the micropost regardless of count. A micropost
with many comments returns them all in one response.

**Expected Baseline signal:** `microposts.show` — duration increases, allocations increase proportional to comment count.
