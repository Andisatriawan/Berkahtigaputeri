# DOC_13 — Unified Flutter POS App Integration Report

**Status:** IMPLEMENTATION IN PROGRESS — compile/test result NOT VERIFIED  
**Date:** 2026-10-12  
**Base:** `main` commit `62659fbec4b3b084383d9d3e08948aee7772e280`  
**Implementation branch:** `feat/unified-pos-local-first-app`  
**Pull request:** [#21 — unify trial POS flows with modular local-first app](https://github.com/berkah-pos/Berkahtigaputeri/pull/21)

This is a current evidence report, not production certification. Apply the mandatory reporting standard in `docs/permanent/DOC_12_SAAS_DATABASE_OFFLINE_ARCHITECTURE_AND_AGENT_PROTOCOL.md`.

## 1. Decision

The modular `pos-app/` is the canonical integration target because it already has the richer local SQLite data model and business logic for checkout, inventory lots, FEFO allocation, FIFO costing, accounting journals, and an outbox event. The older `berkah-pos-trial/` remains a separate codebase and is not built into the same Android package by combining directories.

Everyday product/cashier/inventory/report screens are being brought into `pos-app/`, calling its existing repositories and services rather than adding the trial app's second, simpler `products/sales/sale_items` database schema.

**Migration boundary — important:** the existing trial APK is not an in-place update of this app. The trial package ID is `id.co.berkahtigaputeri.berkahpos` and its SQLite file is `berkah_pos.db`; the canonical modular app package ID is `com.berkahtigaputeri.pos` and its database is `berkahtigaputeri_pos.db`. This PR preserves the canonical modular app's package/signing identity. It does not migrate already-installed trial-app local data. Any future importer needs an explicit, tested mapping that preserves audit lineage and must not invent missing historical tax, discount, costing, or journal values.

## 2. Source evidence on the base revision

- **SOURCE-VERIFIED:** `pos-app/lib/core/database/pos_database.dart` defines local SQLite tables for products, inventory lots, reservations, cost layers, inventory movements, sales, sale items, journals, journal lines, stock movements, and outbox events.
- **SOURCE-VERIFIED:** `pos-app/lib/features/pos/checkout/sqlite_sale_repository.dart` writes checkout sale details, FEFO allocations, FIFO cost consumption, accounting journal, stock movements, and one pending outbox event inside the same SQLite transaction. It has transaction-ID idempotency/fingerprint checks.
- **SOURCE-VERIFIED:** `pos-app/lib/features/pos/checkout/payment_service.dart` exposes payment methods cash, QRIS and bank transfer, validates requests, and delegates to a sale repository.
- **SOURCE-VERIFIED:** `pos-app/lib/features/products/repositories/sqlite_product_repository.dart` provides product and lot operations.
- **SOURCE-VERIFIED:** `pos-app/lib/core/config/config_service.dart` uses Supabase configuration RPC/data and local cache.
- **SOURCE-VERIFIED:** `pos-app/lib/features/home/home_screen.dart` previously exposed mainly UAT tenant/device configuration and effective-config status; it did not provide a reachable cashier navigation.
- **DOC-ASSERTED / source inventory:** `pos-app/README.md` says the Android host is partial and previous app-host generation occurs only in a CI checkout.
- **SOURCE-VERIFIED:** `berkah-pos-trial/lib/main.dart` contains local product CRUD, SQLite checkout, local reports, an email-only activation-status lookup, and privacy/delete-account/WhatsApp links. Its status lookup does not authenticate account ownership.
- **DOC-ASSERTED:** `docs/HARDENING/TENANT_ISOLATION_TEST.md` says full adversarial two-tenant database testing remains not verified. `docs/permanent/DOC_11_P0_SECURITY_VERIFICATION_20261008.md` says the described Supabase target is staging and lists production security gates that remain open.

## 3. Implementation changes on the feature branch

The following changes have been made on `feat/unified-pos-local-first-app`:

- **`pos-app/lib/main.dart`:** opens the canonical persistent `PosDatabase`. Supabase configuration is optional at build time through `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`; the app no longer silently defaults to the documented staging project. A publishable key and local tenant/device IDs are not authentication.
- **`pos-app/lib/features/home/home_screen.dart`:** replaces the config-only landing screen with dashboard and navigation for Beranda, Produk, Kasir, Stok and Laporan; retains cloud configuration diagnostics and local tenant/device display. Adds privacy-policy, account-deletion-request, and WhatsApp sales links. These links are external destinations; they do not certify backend account lifecycle processing.
- **`pos-app/lib/features/products/repositories/sqlite_product_repository.dart`:** adds deterministic product listing and deletion guarded against existing sale, inventory-lot, or stock-movement history.
- **`pos-app/lib/features/products/product_screen.dart`:** local product create/edit/list and guarded delete UI. Stock is not manually overwritten from the product form; stock receipts go through inventory-lot/cost-layer logic.
- **`pos-app/lib/features/pos/checkout_screen.dart`:** cashier UI using the pre-existing PaymentService/SQLite sale repository, product snapshot pricing, PPN calculator, and supported payment-method enum. It deliberately tells the user that the sale is local and cloud sync is not active.
- **`pos-app/lib/features/inventory/inventory_screen.dart`:** receives stock using the existing lot/cost-layer operation and requires batch/expiry for expiry-tracked products.
- **`pos-app/lib/features/home/reports_screen.dart`:** device-local sales/HPP reporting and a count of non-acknowledged outbox events. It explicitly warns that this is not consolidated multi-device reporting.
- **`pos-app/pubspec.yaml`:** adds `url_launcher` for privacy, delete-account request, and support links.
- **`pos-app/test/home/combined_home_shell_test.dart`:** adds a navigation smoke test using an in-memory SQLite database.
- **`pos-app/tool/prepare_android_host.sh`:** safely fills in missing Android host files without overwriting existing files or canonical app identity/configuration.
- **`pos-app/android/app/src/main/AndroidManifest.xml`:** preserves the Berkah POS app label and existing POS/network permission allowlist in the tracked native host contract.
- **`pos-app/test/products/sqlite_product_repository_test.dart`:** covers product listing/deletion and rejection of deleting a product with inventory-lot history.
- **`.github/workflows/pos-app-ci.yml`:** adds Dart analysis/tests plus host preparation via the shared script and a debug-only AAB compile check. Generated host files are confined to the disposable CI checkout.
- **`pos-app/README.md`:** documents reachable screens, local-first boundaries, environment configuration, build/test commands, and the pending cloud sync API.

The weaker email-only trial status check is intentionally not copied as authentication. An email address or activation status does not prove caller identity. A proper authenticated account/subscription API must be added under the approved SaaS architecture.

## 4. Execution and validation evidence

- **SOURCE-VERIFIED:** Changed files were fetched from the feature branch after writing to confirm they exist.
- **TEST-EXECUTED:** No Flutter test suite or Dart analyzer result is yet available from this environment.
- **CI-OBSERVED:** GitHub Actions created runs for `Canonical POS App CI`, including `38256345772`, `38256650643`, `38256908296`, `38257276346`, `38257716462`, and `38257779580`. They all concluded `startup_failure` before jobs started (the Jobs API returned an empty list). This is not a code test result and does not establish whether the source compiles. A runner/Actions startup problem remains a blocker; obtain a run that actually starts its job before claiming a validation result.
- **NOT RUN:** `flutter pub get`, `flutter analyze`, `flutter test`, Android bundle build, physical-device installation, offline crash/retry tests, live Supabase authentication checks, tenant A/B adversarial tests, Laravel integration tests, and production deployment checks.
- **PR:** Pull request #21 is a draft and is not merged.

## 5. Unimplemented or unverified boundaries

These must not be described as delivered by this screen integration:

1. An authenticated Laravel/PHP transaction API and production deployment on Ubuntu/Docker.
2. A cloud outbox sync worker/API that uploads complete sales, sale lines, stock movements and journals, handles idempotency, returns acknowledgements, and resolves failures.
3. A durable cross-device cloud schema and authoritative consolidated reports.
4. A proven authentication/session and device-enrollment flow compatible with protected Supabase config/RLS.
5. Subscription lifecycle, server-enforced entitlements, payment provider/webhooks, and offline grace policy.
6. Tenant-isolation acceptance tests for ordinary authenticated users across SQL/RPC/API/report/storage paths.
7. Object-storage upload/download, file access policies, independent file backups, database restore drills, monitoring and production security certification.
8. Physical printer/scanner integrations, formal receipt output, end-to-end trial/activation/account deletion workflow, and Play Console release signing verification.

## 6. Next actions and acceptance gates

1. Resolve why GitHub Actions cannot start a job; obtain a run that executes a job and reports results.
2. Fix all Dart analysis, unit-test, widget-test, and Android compile failures; attach current revision and pass output.
3. Add tests for product create/edit/delete guards and checkout UI success/failure behavior.
4. Implement and security-test the authenticated cloud API and durable outbox synchronization before calling sales cloud-synchronized.
5. Execute offline crash/retry, idempotency, stock reconciliation, and tenant A/B hostile-access tests.
6. Keep this PR in draft/unmerged state until required CI results and review are available. No production readiness claim is allowed before the SaaS architecture milestone gates are met.

## Acceptance status

**PARTIAL / NOT VERIFIED.** Screen integration source has been written, but CI startup failures mean compilation/tests have not been confirmed. No SaaS cloud synchronization or production tenant-isolation claim is being made.
