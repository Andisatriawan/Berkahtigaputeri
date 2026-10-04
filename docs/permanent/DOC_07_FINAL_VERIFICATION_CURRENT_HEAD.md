# DOC_07 - FINAL VERIFICATION CURRENT HEAD

Status: **CURRENT-HEAD RE-CERTIFIED (repository contract) / 2026-10-04**

Repo: `berkah-ajb-dev/Berkahtigaputeri`

Branch: `fix/final-pos-canonical-sync`

Runtime implementation baseline before this Phase 7 documentation/release-notes pass:

`1e6d225cb1246cc0ab2e24b1f2b47ba3613135ab`

This document replaces the old P1-P5 verification as the current verification authority. The old record is archived as `DOC_07_HISTORICAL_a19cb3f.md`.

## Certification boundary

This verification certifies the repository architecture, workbook contract, RLS/auth design, atomic versioning path, CI gates, and currently reachable Flutter entry UI.

It does **not** claim that every historical DEV/UAT row has already been removed. The canonical workbook-owned keyset is exactly 352 rows; any additional historical row is outside the certified keyset and is intentionally rejected by the fail-closed CI exact-count gate.

## Canonical configuration architecture

The sole current inheritance contract is:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

For one `(tenant_id, device_id, service)` request, exactly these keys participate:

```text
global
template:<tenant.template_id>
tenant:<tenant_id>
tenant:<tenant_id>:service:<service>
device:<device_id>
```

Later layers override earlier layers at the top JSON-object level.

POS and Akuntansi service rows are service-specific. They are not merged together into one effective configuration.

### Parity

The same five-level rule is present in:

- Flutter `pos-app/lib/core/config/config_service.dart`;
- Admin `btp-admin/editor-core.js`;
- PostgreSQL `public.get_effective_config(...)` in `DOC_03_RLS_AUTH.sql`.

TEMPLATE is therefore a required runtime layer, not documentation-only metadata.

## Canonical workbook inventory: 352 keys

Canonical workbook:

```text
config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx
```

Canonical `APP_CONFIG_EXPORT` inventory:

```text
1 global
3 template
100 tenant
140 service
108 device
---------
352 total
```

The workbook parser remains the openpyxl implementation preserved from Phase 2. The Phase 6 canonical sync entry point wraps that parser and uses atomic version semantics for existing `app_config` rows.

`python3 scripts/sync_excel_to_supabase.py --dry-run` is the validation command. The fail-closed sync workflow also runs this command before any remote write.

### DEV snapshot observed during Phase 7 re-certification

At re-certification time DEV still contained 360 total `app_config` rows:

```text
1 global
3 template
101 tenant
145 service
110 device
---------
360 total
```

The eight surplus rows are historical UAT/pilot residue outside the workbook-owned 352-key contract. Seven are the old `berkah_sumber` / `clientA` / `clientB` pilot rows and one is an extra UUID device row.

This document does not relabel those rows canonical. The CI contract remains exactly 352 and must fail closed while an environment contains extras.

## RLS and authenticated effective-config access

`DOC_03_RLS_AUTH.sql` is the current security contract.

RLS is enabled on:

```text
tenants
devices
licences
app_config
config_history
tenant_services
```

Current access model:

- `anon` has no direct read privilege on Final Pos identity/config tables;
- normal authenticated device users are restricted through `devices.user_id`;
- tenant, licence, service and config visibility follows the authenticated device ownership;
- TEMPLATE config is included in the allowed effective-config keyset;
- canonical super admin remains authenticated and receives explicit management policies;
- `get_effective_config(...)` revokes `EXECUTE` from `public`/`anon`;
- the RPC requires an authenticated caller;
- the RPC always validates `device -> tenant`;
- non-admin callers must own the requested device.

The effective-config RPC is `SECURITY DEFINER` by design, with an empty `search_path`, because it must read the five configuration layers while still enforcing its explicit authorization checks.

## Atomic app_config versioning

Normal configuration replacement uses:

```text
update_app_config_atomic(key, new_value, expected_version)
```

The RPC performs compare-and-swap semantics:

```text
UPDATE ... WHERE key = requested_key
           AND current_version = expected_version
```

The server stores exactly `expected_version + 1`. A caller-supplied `version` field is not authoritative.

Admin, Template Admin and the canonical workbook sync use this expected-version contract for existing `app_config` rows.

## Fail-closed CI

`.github/workflows/final-pos-sync.yml` is named:

```text
Final Pos Sync (fail-closed)
```

The workflow:

1. checks out the repository;
2. installs `openpyxl` and `requests`;
3. verifies the canonical workbook asset exists;
4. runs the 352-key workbook dry-run;
5. fails when `SUPABASE_URL` or `SUPABASE_SERVICE_KEY` is missing;
6. runs the workbook-owned sync;
7. queries PostgREST with exact count semantics;
8. fails unless total `app_config` row count is exactly `352`.

No `exit 0` bypass remains for missing secrets or sync failures.

`.github/workflows/build.yml` runs on push and pull request and performs:

```text
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

## Current Flutter release surface

Current `main.dart` opens `HomeScreen`.

The reachable HomeScreen is a UAT/configuration screen that provides:

- tenant selector;
- device ID input;
- refresh/reload;
- config source status (`LIVE SUPABASE` / `CACHE OFFLINE`);
- effective POS MDR display;
- POS/Akuntansi service availability cards.

The service cards do not navigate to cashier, checkout, QRIS transaction, or PPN-report screens. Those lower-level modules may exist in the repository, but they are not reachable from the current application entry UI and are not certified as current release UX.

The current entry point also constructs a Supabase client but does not itself establish an authenticated device session. Under the Phase 5 RLS model, production device-auth provisioning/session wiring remains a prerequisite before claiming fresh-install live authenticated config access.

Play Store release notes must therefore describe the UAT/config surface only.

## Protected green contracts

The correction program preserves:

- FEFO physical allocation and FIFO financial costing as intentionally different;
- COA `1-1040` = Inventory;
- COA `5-5010` = COGS;
- Flutter version `1.0.0+2`;
- Android `versionName 1.0.0` / `versionCode 2`;
- GitHub Pages publishing `btp-admin/`.

## Final current-head matrix

| Contract | Result |
|---|---|
| GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE | PASS |
| Canonical workbook inventory = 352 keys | PASS |
| Admin / Flutter / RPC include TEMPLATE | PASS |
| Service-specific merge | PASS |
| Anonymous Final Pos config/identity reads removed | PASS |
| Authenticated device-to-tenant validation in RPC | PASS |
| Atomic expected-version config writes | PASS |
| Fail-closed sync CI with exact 352 gate | PASS |
| Flutter analyze/test/build required by PR CI | PASS |
| Play Store notes match reachable HomeScreen | PASS |
| DEV total row count is already exactly 352 | **NOT CERTIFIED: 8 historical rows remain** |
| Fresh-install authenticated device session from current `main.dart` | **NOT CERTIFIED** |

The current repository contract is re-certified. Production/release claims must respect the two explicit environment/runtime limitations above rather than inheriting claims from the historical P1-P5 document.
