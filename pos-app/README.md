# Berkah POS App

**Canonical Flutter client** for Berkah Tiga Puteri POS. The project combines the everyday trial POS screens with the modular local inventory, checkout, accounting, and Supabase configuration layers under `pos-app/`.

## Current screens

- **Beranda:** local summary for products, sales totals, and pending outbox entries.
- **Produk:** local product catalogue, create/edit, and guarded deletion when inventory or transaction history exists.
- **Kasir:** cart, payment-method selection, Rupiah totals and PPN, backed by the existing atomic `PaymentService` / `SqliteSaleRepository`.
- **Stok:** inventory receipt with lot, unit cost, optional expiry, and required batch/expiry when the product tracks expiry.
- **Laporan:** device-local sales, HPP and non-acknowledged outbox count.
- **Pengaturan:** local tenant/device identity display, opt-in Supabase configuration check, privacy policy, account deletion request link, and sales WhatsApp link.

## Architecture and truth-in-status rules

- SQLite is the local persistence layer, using the canonical `PosDatabase` migrations in `lib/core/database/pos_database.dart`.
- Checkout persists sales, sale lines, FEFO lot allocations, FIFO cost consumption, balanced accounting journal lines, stock movements, and the existing outbox event in a SQLite transaction.
- Prices and totals use integer Rupiah in the modular domain logic.
- The app has a local-first UI. **The Laravel API, authenticated cloud sales synchronization/acknowledgement, and consolidated multi-device reports are not implemented by this UI integration.** The dashboard and reports tell users that outbox events remain local/pending.
- Supabase configuration is enabled only by build-time `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` values. Omitting them leaves local POS available without silently defaulting to the documented staging project. Supplying a publishable key does not authenticate a user or enroll a device; protected configuration access remains subject to existing session/RLS requirements.
- `BERKAH_WHATSAPP_NUMBER` optionally configures the sales WhatsApp phone number at build time. No private service-role, database-admin, or signing secrets belong in the Flutter app.
- This app must not be treated as production multi-tenant SaaS until authenticated identity, server-side tenant authorization, the sync API, adversarial two-tenant tests, backups/restore, and production security gates are verified.

The trial app's email-only status lookup is intentionally not used as authentication: knowing an email or reading an activation status does not prove the caller owns that account. Use the approved authenticated account/subscription API when that backend flow is implemented.

## Local checks

Run from this directory:

```sh
flutter pub get
flutter analyze
flutter test
```

## Android compile check

The tracked Android host is intentionally partial. Prepare it locally, if missing, with:

```sh
bash tool/prepare_android_host.sh
flutter build appbundle --debug
```

The script fills in only missing Android host files and preserves the existing canonical app Gradle configuration and app identity. Review any generated native files before committing them. The GitHub Actions workflow uses the same script in its disposable checkout, then runs a **debug-only** Android App Bundle compile check. That artifact is not a production-signed release and must not be submitted to Play Console.

Production release signing and device/internal-track verification must be configured and validated separately. Never commit keystores, `key.properties`, or signing secrets.

## Permanent architecture rules

Before coding, follow root `AGENTS.md` and read:

1. `docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`
2. `docs/permanent/DOC_00_MASTER_ROADMAP.md`
3. `docs/permanent/DOC_12_SAAS_DATABASE_OFFLINE_ARCHITECTURE_AND_AGENT_PROTOCOL.md`

The canonical configuration inheritance remains `GLOBAL → TEMPLATE → TENANT → SERVICE → DEVICE`. All agents must provide evidence reports as defined in DOC_12.
