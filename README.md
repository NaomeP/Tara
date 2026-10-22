# Tara

Tara is a React/Vite storefront with an Express API and PostgreSQL database. The storefront includes product discovery, product size selection, a persistent cart and wishlist, English/Tamil switch, responsive layouts, and PWA support. The API owns pricing, stock checks, orders, payment verification, and protected administration.

## Requirements

- Node.js 20 or newer
- PostgreSQL 15 or newer
- pnpm 9 or newer
- Optional: Razorpay merchant credentials for online payments
- Optional: SMTP credentials for order email updates

## Local setup

1. Start the local database with `docker compose up -d db` (or create a PostgreSQL database named `thara` yourself).
2. Copy `.env.example` to `.env`, set a long random `JWT_SECRET`, and confirm `DATABASE_URL`.
3. Set `ADMIN_EMAIL`. Generate the password hash with `node -e "console.log(require('bcryptjs').hashSync('a-long-unique-password', 12))"` and put the result in `ADMIN_PASSWORD_HASH`.
4. Run `pnpm install`, then `pnpm db:setup` to create the schema and starter products.
5. Run `pnpm dev` for the Vite storefront and `pnpm dev:api` in a second terminal for the API.
6. Open `http://localhost:5173`. The admin dashboard is at `http://localhost:5173/admin`.

## Customer accounts

Customer email/password accounts use Supabase Auth. Enable the Email provider in Supabase, then set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` in `.env` to the project URL and public anon/publishable key. The two browser variables must match the server values. Add localhost and production URLs to Supabase Auth's allowed redirect/site URLs, then restart both Vite and the API. Never put a Supabase service-role key in the browser or in source control.

The current store database remains PostgreSQL/Neon. The Express API validates Supabase access tokens with Supabase Auth and scopes account order/address queries to the verified user; guest checkout remains available. This does not make Neon a Supabase database or provide Supabase Postgres RLS. Guest orders created before an account is linked are not automatically exposed in account history.

The storefront can render its design sample catalogue without an API connection. Creating orders and using admin features requires the API and PostgreSQL to be configured.

## Payments and shipping

Set the Razorpay key ID, secret, and webhook secret on the API host. Configure the Razorpay webhook URL as `/api/payments/webhook` for captured-payment events. Never expose secrets in Vite variables. Checkout prices and shipping are recalculated from PostgreSQL on the server. Cash on delivery is enabled only when `ENABLE_COD=true`.

The initial shipping rules use a flat fee and a free-shipping threshold, configurable in paise. The six-digit PIN code is validated at checkout; live courier serviceability, label creation, and tracking require the selected shipping provider integration.

Set SMTP host, port, credentials, secure mode, and sender to send order confirmation and order-status emails. With SMTP unset, orders remain usable and the application logs an email-delivery error only when a configured transport fails.

## Admin and store operations

Admin credentials are provisioned through server environment variables and bcrypt hashes. Admin sessions use short-lived signed tokens. `/admin` includes catalogue and category management, product variants with independent SKU/price/stock, order and returns management, customer/review tools, a content manager for banners/collections/policy pages, a downloadable sales CSV, and an audited Razorpay refund action. Refund requests require a verified captured payment reference; uncertain provider outcomes are held for reconciliation rather than retried automatically. Public storefront-managed content is read from `/api/storefront`.

Apply schema changes explicitly with `pnpm db:migrate` after reviewing its SQL, testing against staging, and taking an approved backup. The API does not run schema DDL at startup by default; `RUN_STARTUP_MIGRATIONS=true` is an emergency compatibility option, not the recommended deployment workflow. `pnpm db:setup` remains the local demo setup and includes starter records; do not use it on production. No production database was modified as part of this code change.

## Deployment checklist

- Provision PostgreSQL with automated backups and TLS; set `DATABASE_URL`, take a backup, review the schema changes, and apply them with `pnpm db:migrate`. Do not run `pnpm db:setup` on production because it adds demo records.
- Set a unique `JWT_SECRET`, admin email/hash, allowed `CLIENT_ORIGIN`, shipping fees, and COD policy.
- Configure Razorpay test keys and webhook, test payment success/failure and refund operations, then replace with approved live credentials.
- Configure SMTP and verify order and status messages.
- Replace the starter catalogue and image URLs with owner-approved product data, accurate photos, policies, support contacts, and prices.
- Connect a courier provider for PIN serviceability, fulfilment, returns, and tracking events.
- Build with `pnpm build`; host the Vite `dist` output and run `pnpm start:api` on a Node host.
- Set up backups, monitoring, security review, and production policies before accepting real orders.

### Railway deployment

Railway can detect the `pnpm start` script in `package.json`; it runs the Express server, which serves the built storefront from `dist`. The server listens on Railway's `PORT` and enables one trusted proxy hop when Railway provides `RAILWAY_PROJECT_ID`, which keeps IP-based API rate limits working behind Railway's ingress. Add the environment variables listed above, connect a PostgreSQL service through its `DATABASE_URL`, back up any existing production data, and run `pnpm db:migrate` once before accepting orders. Do not set `RUN_STARTUP_MIGRATIONS=true` for routine deploys.

## Project notes

This repository does not include production credentials, owner-approved product material, courier contracts, email credentials, or a production database. The starter catalogue is illustrative. A production launch still needs those external accounts and the corresponding provider configuration. The shopping helper answers common questions from local rules and searches the text catalogue; it is not an AI service. Photo search ranks catalogue images by colour similarity in the browser; it does not identify garments or objects semantically. Live courier serviceability, labels and tracking events still require the owner to choose a courier provider and supply its credentials/webhook configuration. Product policies and support details must be reviewed and published by the owner. Product imagery currently uses individual photos; a true 360° viewer needs multiple approved angles or 3D assets per product. The Tamil switch covers selected interface copy; customer-facing product and policy translations need owner review.
