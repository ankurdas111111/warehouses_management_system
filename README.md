## Warehouse Management System (Rails) — Multi-Warehouse Inventory, Orders, Wallet & Payments

A production-minded Rails app that demonstrates **correctness under concurrency**, practical system design, and day-to-day engineering discipline (testing, CI, ops tooling).


## This project demonstrates 
- **Concurrency-safe inventory reservations** across warehouses (no overselling)
- **Idempotent order creation** (safe retries via Idempotency-Key)
- **Order lifecycle**: reserve → pay → fulfill; plus cancellation + partial fulfillment
- **Wallet**: top-up + pay with wallet + automatic refund on cancellation
- **Hosted (dummy) payment gateway**: provider order → hosted checkout → callback + signature verification
- **Admin tooling** (HTTP Basic Auth): manage warehouses/SKUs/inventory, export reports, credit wallets, view Sidekiq
- **Operational readiness**: health/readiness endpoints, structured logs, audit trail, basic rate limiting
- **Documentation + tests**: OpenAPI + RSpec (+ concurrency-focused tests)

## Tech stack
- **Rails 8.x**, Ruby 3.4.x
- **Postgres** (source of truth + locking + constraints)
- **Sidekiq + Redis** (background jobs + cron schedule)
- **RSpec** (request specs + concurrency coverage)
- **Docker Compose** (local Postgres + Redis)

## Architecture (high level)
Business-critical state lives in Postgres:
- `stock_items` (SKU × warehouse inventory)
- `inventory_reservations` (per-order reservations)
- `orders`, `order_lines`, `fulfillments`
- `payments`, `wallets`, `wallet_transactions`
- `audit_logs` (admin audit trail)

Correctness approach:
- **Transactions + row locks** (`lock`) for inventory reservation and release
- **DB constraints** on stock items:
  - `on_hand >= 0`
  - `reserved >= 0`
  - `reserved <= on_hand`
- **Uniqueness**:
  - stock item uniqueness `(sku_id, warehouse_id)`
  - idempotency via `orders.idempotency_key`

### Background work: Sidekiq + Redis
Redis is used only for Sidekiq job data (queues/retries/schedules); business data stays in Postgres.

Fulfillment pattern:
- **Fast path**: schedule auto-fulfillment after successful payment
- **Safety net**: cron sweep every 4 hours for eligible reserved orders

Cron schedule config:
- `SIDEKIQ_CRON_ENABLED=0` disables loading `config/sidekiq.yml` schedules.
- `AUTO_FULFILL_DUE_ORDERS_CRON` controls the sweep schedule (default: `0 */4 * * *`).

### Currency
SKU pricing and payments are tracked in integer **INR minor units (paise)** for correctness; UI displays INR.

## Local development (Docker for dependencies)
### 1) Start Postgres + Redis
Local ports:
- Postgres: host **5434** → container 5432
- Redis: host **6380** → container 6379

```bash
cd /Users/ankur.das/LearnLangs/Rails/warehouse_management
docker-compose up -d
```

### 2) Configure env + install gems
```bash
# Create a local .env (gitignored). At minimum, set DB + Redis ports used by docker-compose:
# DB_HOST=localhost
# DB_PORT=5434
# DB_USERNAME=postgres
# DB_PASSWORD=postgres
# REDIS_URL=redis://localhost:6380/0
bundle install
```

### 3) Setup database (migrate + seed)
```bash
bin/rails db:setup
```

### 4) Run the web server
```bash
bin/rails s
```

### 5) Run Sidekiq (jobs + cron schedule)
No manual `REDIS_URL` export needed:

```bash
chmod +x bin/sidekiq
bin/sidekiq
```

### Run Sidekiq locally against remote services (Render + Upstash)
If you deploy the web app on Render but only want to run Sidekiq **on-demand** from your laptop, create a local env file and use the helper script:

```bash
# Create `.env.sidekiq-remote` (gitignored) and set: DATABASE_URL, REDIS_URL, RAILS_MASTER_KEY
chmod +x bin/sidekiq-remote
bin/sidekiq-remote
```

## UI
### User UI (JWT cookie)
- Sign up: `GET /signup`
- Login: `GET /login`
- Place order: `GET /`
- My orders: `GET /orders`
- Wallet: `GET /wallet`

Auth model: JWT stored in an **encrypted, HttpOnly cookie**.

### Admin UI (HTTP Basic Auth)
Admin pages are protected by `ADMIN_USER` / `ADMIN_PASSWORD`:
- Admin home: `GET /admin`
- Inventory: `GET /admin/inventory`
- Warehouses (CRUD): `GET /admin/warehouses`
- SKUs: `GET /admin/skus`
- Reports (CSV): `GET /admin/reports`
- Wallet credit (by email): `GET /admin/wallets`
- Sidekiq UI: `GET /admin/sidekiq`

## Payments
### Hosted (dummy) checkout
No external network calls; this simulates a typical gateway pattern:
- `GET /orders/:order_id/pay` → payment selection + provider order creation
- `GET /checkout/:payment_id` → hosted checkout screen
- `GET /orders/:order_id/payment_callback` → callback verifies signature and marks payment captured

Wallet payments remain a separate option on the payment page.

## API
### Versioned API (preferred)
All JSON endpoints are available under `/api/v1/*`.

Legacy compatibility:
- `/api/*` routes exist for backward compatibility (same controllers).

OpenAPI schema: `docs/openapi.yml`

### Curl examples (v1)
Create a warehouse:

```bash
curl -X POST localhost:3000/api/v1/warehouses \
  -H 'Content-Type: application/json' \
  -d '{"code":"WH-A","name":"Warehouse A"}'
```

Create a SKU:

```bash
curl -X POST localhost:3000/api/v1/skus \
  -H 'Content-Type: application/json' \
  -d '{"code":"WIDGET","name":"Widget"}'
```

Inventory snapshot:

```bash
curl 'localhost:3000/api/v1/inventory?sku_code=WIDGET'
curl 'localhost:3000/api/v1/inventory?warehouse_code=WH-A'
curl 'localhost:3000/api/v1/inventory?location=BLR'
```

Create an order (idempotent):

```bash
curl -X POST localhost:3000/api/v1/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: order-1' \
  -d '{"customer_email":"buyer@example.com","lines":[{"sku_code":"WIDGET","quantity":3}]}'
```

Cancel an order:

```bash
curl -X POST localhost:3000/api/v1/orders/1/cancel
```

Fulfill (partial supported):

```bash
curl -X POST localhost:3000/api/v1/orders/1/fulfill \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"reservation_id":123,"quantity":1}]}'
```

## Observability & ops
### Health endpoints
- **Liveness**: `GET /healthz`
- **Readiness**: `GET /readyz` (checks DB + Redis if `REDIS_URL` is set)

### Structured logs (Render-friendly)
Domain events are emitted via `ActiveSupport::Notifications` and logged as single-line JSON.
Common searches:
- `\"event\":\"payments.captured\"`
- `\"event\":\"reservation.created\"`
- `\"order_id\":123`

### Admin audit trail
High-signal admin actions are persisted in `audit_logs` (exports, wallet credits, CRUD actions).

### Rate limiting
Simple, dependency-free middleware rate-limits sensitive endpoints (login/signup/payment API).
Disable with `RATE_LIMITING_ENABLED=0`.

## Testing
```bash
bundle exec rspec
```

## CI (GitHub Actions)
CI runs on push/PR:
- RSpec (with Postgres service)
- RuboCop
- Brakeman
- Bundler Audit

## Deployment (Render)
Recommended Render topology:
- **Web Service**: Rails/Puma (Dockerfile)
- **Postgres**: Render Postgres (persistent data)
- **Redis**: Render Redis (Sidekiq)
- **Background Worker**: Sidekiq

Worker start command:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

### Automated migrations
Container entrypoint runs `bin/rails db:prepare` at boot.
Controls:
- `RUN_DB_PREPARE=0` disables auto-migrations
- `RUN_DB_SEED=1` runs seed after prepare

## Environment variables
Common production vars:
- `DATABASE_URL`
- `REDIS_URL`
- `RAILS_MASTER_KEY`
- `ADMIN_USER`, `ADMIN_PASSWORD`
- `JWT_SECRET` (optional; defaults to Rails `secret_key_base`)
- `RAILS_LOG_LEVEL=info`
