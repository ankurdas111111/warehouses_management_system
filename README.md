# Warehouse Order API (Rails)

Multi-warehouse order reservation + fulfillment system designed to demonstrate **concurrency-safe inventory**:
- Uses **Postgres row locking** (`SELECT ... FOR UPDATE` via ActiveRecord `lock`)
- Enforces invariants with **DB constraints** (`reserved <= on_hand`, non-negative counters, etc.)
- Supports **partial fulfillment** and **cancellation**
- Includes an **RSpec concurrency test** proving “no oversells”

## Requirements
- Ruby **3.4+** (recommended via `rbenv`)
- Docker + `docker-compose` (used to run Postgres + Redis)

## Setup
Start Postgres + Redis (Postgres is mapped to host port **5434**; Redis to **6380**):

```bash
docker-compose up -d
```

Create a local `.env` so you don't have to type `DB_PORT=...` every time:

```bash
cp env.example .env
bundle install
```

Create + migrate DB and seed demo data:

```bash
bin/rails db:setup
```

Run the API server:

```bash
bin/rails s
```

## Minimal UI
- **User order page**: `GET /` (place order)
- **Admin**: `GET /admin` (basic auth; configure `ADMIN_USER`/`ADMIN_PASSWORD`)

Run Sidekiq (background jobs):

```bash
bundle exec sidekiq
```

## Deploy (Render, Docker Web Service) — automated migrations
The Docker image runs `bin/rails db:prepare` automatically on boot when starting Puma/rails server.

- **Default**: migrations run automatically on deploy/restart.
- **Optional seeds**: set `RUN_DB_SEED=1` on Render to run `db:seed` automatically too.

You can disable auto-migrations by setting `RUN_DB_PREPARE=0`.

## API
OpenAPI schema: `docs/openapi.yml`

### Create SKU

```bash
curl -X POST localhost:3000/skus \
  -H 'Content-Type: application/json' \
  -d '{"code":"WIDGET","name":"Widget"}'
```

### Create Warehouse

```bash
curl -X POST localhost:3000/warehouses \
  -H 'Content-Type: application/json' \
  -d '{"code":"WH-A","name":"Warehouse A"}'
```

### Adjust inventory (per warehouse)

```bash
curl -X POST localhost:3000/inventory/adjust \
  -H 'Content-Type: application/json' \
  -d '{"sku_code":"WIDGET","warehouse_code":"WH-A","delta":5}'
```

### View inventory
List everything:

```bash
curl localhost:3000/inventory
```

Filter by SKU:

```bash
curl 'localhost:3000/inventory?sku_code=WIDGET'
```

Filter by Warehouse:

```bash
curl 'localhost:3000/inventory?warehouse_code=WH-A'
```

Filter by Location (warehouse location):

```bash
curl 'localhost:3000/inventory?location=BLR'
```

### Create order (idempotent)

```bash
curl -X POST localhost:3000/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: order-1' \
  -d '{"customer_email":"buyer@example.com","lines":[{"sku_code":"WIDGET","quantity":3}]}'
```

### Cancel order

```bash
curl -X POST localhost:3000/orders/1/cancel
```

### Fulfill order (partial ok)
Use reservation IDs returned from the `POST /orders` response:

```bash
curl -X POST localhost:3000/orders/1/fulfill \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"reservation_id":123,"quantity":1}]}'
```

## Proving “no oversells”
### RSpec concurrency test

```bash
DB_PORT=5434 bundle exec rspec
```

### Simple HTTP load test (requires server running)

```bash
THREADS=50 ruby script/load_test.rb
```

