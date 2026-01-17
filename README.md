# Warehouse Management — Multi-Warehouse Orders & Inventory (Rails)

This project implements a multi-warehouse order + inventory system focused on **correctness under concurrency**. It is designed to be a strong portfolio artifact for backend/SDE interviews: transactional guarantees, database constraints, background processing, and production-oriented operations.

## Highlights
- **Concurrency-safe inventory reservations** across multiple warehouses
- **Idempotent order creation** (safe retries)
- **Cancellation and partial fulfillment** flows
- **Background fulfillment** using Sidekiq + Redis (fast path + safety net sweep)
- **Admin UI** (basic auth) for SKUs, warehouses, inventory, and Sidekiq monitoring
- **Minimal user UI** with **JWT login/signup** and “My Orders” scoped to the logged-in user
- **Wallet**: user top-up + pay using wallet + automatic wallet refund on cancellation
- **Dummy hosted payment gateway**: 2-step checkout simulation (provider order → hosted checkout → callback)
- **OpenAPI** documentation and **RSpec** test suite (includes a dedicated concurrency spec)

## Architecture and key decisions
### Correctness via Postgres (source of truth)
All business-critical state lives in Postgres:
- `orders`, `order_lines`
- `inventory_reservations`
- `stock_items` (per SKU per warehouse inventory)

Correctness is guaranteed using:
- **Row-level locks** (`SELECT ... FOR UPDATE` via ActiveRecord `lock`) inside transactions
- **Database constraints** on `stock_items`:
  - `on_hand >= 0`
  - `reserved >= 0`
  - `reserved <= on_hand`
- **Unique indexes**:
  - `stock_items`: unique `(sku_id, warehouse_id)`
  - `orders`: unique `idempotency_key`

### Background work via Sidekiq + Redis
Redis is used only for Sidekiq’s job data (queues, schedules, retries). Business data remains in Postgres.

Fulfillment uses a best-practice pattern:
- **Fast path**: enqueue a fulfillment job shortly after an order is reserved.
- **Safety net**: a cron sweep runs every 4 hours and fulfills eligible reserved orders that were missed/stuck.

### Structured logging
Domain events are emitted via `ActiveSupport::Notifications` and logged as JSON to support debugging and operational visibility in production.

## Tech stack
- Ruby on Rails (Rails 8.x)
- Postgres (data + concurrency control)
- Sidekiq + Redis (background processing)
- RSpec (tests)
- Docker Compose (local Postgres + Redis)

## Local development
### 1) Start Postgres + Redis
Docker ports are mapped for local dev:
- Postgres: host **5434** → container 5432
- Redis: host **6380** → container 6379

```bash
docker-compose up -d
```

### 2) Configure env and install gems
```bash
cp env.example .env
bundle install
```

### 3) Setup database and seed demo data
```bash
bin/rails db:setup
```

### 4) Run the web service
```bash
bin/rails s
```

### 5) Run Sidekiq (jobs + cron schedule)
```bash
bundle exec sidekiq -C config/sidekiq.yml
```

## UI
### User UI (JWT)
- Sign up: `GET /signup`
- Login: `GET /login`
- Place order: `GET /`
- My orders (scoped): `GET /orders`
- Wallet: `GET /wallet`

The UI uses a **JWT stored in an HttpOnly encrypted cookie**. After login, the UI only queries orders associated to the logged-in user.

### Admin UI (basic auth)
Admin pages are protected with HTTP Basic Auth (`ADMIN_USER` / `ADMIN_PASSWORD`):
- Admin home: `GET /admin`
- Inventory: `GET /admin/inventory`
- Warehouses (CRUD): `GET /admin/warehouses`
- SKUs: `GET /admin/skus`
- Sidekiq monitoring: `GET /admin/sidekiq`
- Wallet credit (by user email): `GET /admin/wallets`

## Payments (dummy hosted checkout)
This project includes a **dummy hosted payment gateway** flow (no real network calls):
- `GET /orders/:id/pay`: payment selection page (creates a provider order + a `payments` row in `created` state)
- `GET /orders/:id/checkout`: hosted checkout page (simulates a third-party UI)
- `GET /orders/:id/payment_callback`: simulated callback that verifies a signature and marks the payment as captured

Wallet payments remain a separate option on the payment page.

## API documentation
OpenAPI schema: `docs/openapi.yml`

## API examples (curl)
### Create a SKU
```bash
curl -X POST localhost:3000/api/skus \
  -H 'Content-Type: application/json' \
  -d '{"code":"WIDGET","name":"Widget"}'
```

### Create a warehouse
```bash
curl -X POST localhost:3000/api/warehouses \
  -H 'Content-Type: application/json' \
  -d '{"code":"WH-A","name":"Warehouse A"}'
```

### View inventory (filters)
```bash
curl localhost:3000/api/inventory
curl 'localhost:3000/api/inventory?sku_code=WIDGET'
curl 'localhost:3000/api/inventory?warehouse_code=WH-A'
curl 'localhost:3000/api/inventory?location=BLR'
```

### Create an order (idempotent)
```bash
curl -X POST localhost:3000/api/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: order-1' \
  -d '{"customer_email":"buyer@example.com","lines":[{"sku_code":"WIDGET","quantity":3}]}'
```

### Cancel an order
```bash
curl -X POST localhost:3000/api/orders/1/cancel
```

### Fulfill an order (partial ok)
Use reservation IDs returned from `POST /orders`:
```bash
curl -X POST localhost:3000/api/orders/1/fulfill \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"reservation_id":123,"quantity":1}]}'
```

## Testing
Run all specs (includes a concurrency-focused spec that validates inventory never oversells under concurrent order creation):

```bash
bundle exec rspec
```

## CI (GitHub Actions)
CI runs on every PR and push to `main`:
- **RSpec** using Postgres service
- **Brakeman** for static security checks
- **Bundler Audit** for gem CVEs
- **RuboCop** for style

Test DB connection details in CI:
- Postgres is available at `localhost:5432`
- CI sets `DATABASE_URL=postgres://postgres:postgres@localhost:5432/warehouse_order_api_test`

## Deployment (Render, Docker)
Recommended Render topology:
- **Web Service**: Rails/Puma
- **Redis**: required for Sidekiq
- **Background Worker**: Sidekiq

### Automated migrations and seeding
The Docker entrypoint runs `bin/rails db:prepare` automatically at boot.
- Default: migrations run automatically on deploy/restart
- Optional seed: set `RUN_DB_SEED=1`
- Disable auto-migrations: set `RUN_DB_PREPARE=0`

### Worker start command (Render Background Worker)
```bash
bundle exec sidekiq -C config/sidekiq.yml
```

## Environment variables
See `env.example` for local defaults.

Common production variables:
- `DATABASE_URL` (Render Postgres)
- `REDIS_URL` (Render Redis)
- `RAILS_MASTER_KEY` (Render)
- `ADMIN_USER`, `ADMIN_PASSWORD` (set strong values in production)
- `JWT_SECRET` (optional; defaults to Rails `secret_key_base`)

## Logs (Render)
In production, Rails logs to **STDOUT**, so can view everything in the Render dashboard for Web/Worker services.

This app emits **structured domain events** (single-line JSON) via `ActiveSupport::Notifications` for important flows:
- **Orders**: `orders.create`, `orders.created`, `orders.cancel`, `orders.cancel.refund_*`, `orders.auto_fulfill`
- **Reservations**: `reservation.created`, `reservation.released`
- **Wallet**: `wallet.credit`, `wallet.debit`, `wallet.balance_changed`, `wallet.insufficient_balance`, `wallet.idempotent_hit`
- **Payments / hosted checkout**: `payments.*`, `gateway.*`
- **Reports**: `reports.orders.*`, `reports.inventory.*`

Render logs: search in the logs panel for:
- `\"event\":\"payments.captured\"` (successful payments)
- `\"order_id\":123` (trace a specific order)
- `\"event\":\"wallet.insufficient_balance\"` (wallet failures)

Recommended env vars:
- `RAILS_LOG_LEVEL=info` (set to `debug` temporarily only when actively debugging)




