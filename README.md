# Rails Coding Challenge

## Overview

Welcome! This challenge focuses on a pattern that comes up constantly in production Rails apps: safely reserving a limited resource (stock, seats, coupon codes, appointment slots — pick your domain) when multiple requests can hit it at the same time, and doing so idempotently so that retries don't double-charge the resource.

Picture a checkout flow where ten requests can try to claim the last five units of a product at the same moment, and any request might get retried (a flaky network, a duplicate click, a job retry) and must not claim twice.

The scaffolding is already in place: the schema, the models, and a runnable demo that fires concurrent reservation attempts at a product with limited stock. Your task is to bring `ReservationService` to life by filling in the two `TODO` methods.

**Time budget: 25 minutes.** AI tools, Stack Overflow, Google — all welcome. We're interested in what you can reason about and explain.

## Getting Started

```
gem install activerecord sqlite3   # if not already available
ruby reservation_challenge.rb
```

## What to Implement

Fill in the two `TODO` methods on `ReservationService`:

1. **`reserve!(product_id:, quantity:, idempotency_key:)`** — orchestrates one reservation attempt. If a reservation already exists for this `idempotency_key`, return it without touching stock again. Otherwise, try to decrement stock; if there isn't enough, return a failure result; if it succeeds, create the `Reservation` record. You'll also need to handle the race where two requests with the *same* idempotency key both pass the "does it exist?" check at once.
2. **`decrement_stock!(product_id, quantity)`** — atomically reduces a product's stock by `quantity`, but only if enough stock remains, and must be safe when called concurrently against the same row. Returns `true` on success, `false` if there wasn't enough stock.

## Constraints

- ActiveRecord + sqlite3 only (no Redis, no extra locking/queueing gems)
- `ruby reservation_challenge.rb` must run when you're done, and the demo output should show stock never going negative and never being over-claimed
- Write at least one test, or make sure the runnable demo clearly demonstrates correctness

## Not Required

- A full Rails app, HTTP layer, or background job framework
- Handling multiple products or a real payment flow

---

AI tools are welcome — we're interested in what you can reason about and explain.
