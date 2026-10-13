# Phase 2 — Backend Sync Audit

**Status: BLOCKED / PARTIAL — source fixes proposed; staging relational projections do not consistently match the canonical workbook.**

**Audit date:** 2026-10-13  
**Repository:** `berkah-pos/Berkahtigaputeri`  
**Base revision:** `main@461ced76d69e077847ce20c184a95d34b24bcee3`  
**Fix branch / PR:** `fix/phase-2-workbook-ownership-20261013` / [PR #25](https://github.com/berkah-pos/Berkahtigaputeri/pull/25)

This report records source inspection and read-only database evidence. No staging or production writes, deletions, migrations, or workbook sync operations were executed.

## 1. Canonical acceptance contract

The roadmap in `docs/permanent/DOC_00_MASTER_ROADMAP.md` defines Phase 2 as workbook ownership of tenant, device, service, and feature configuration. Acceptance requires workbook sync to update `app_config` and relational projections, Flutter runtime feature access not to depend on an unsynchronized `tenants.features` fallback, and projections to match workbook-derived configuration after sync.

`docs/permanent/DOC_02_FINAL_POS_RELATIONAL_OWNERSHIP.sql:2-3,29-47` declares that the workbook owns `tenants`, `devices`, `tenant_services`, and `app_config`; feature flags are authoritative in `app_config`, with `tenants.features` only a deprecated compatibility projection.

## 2. Source evidence

### SOURCE-VERIFIED — Flutter feature fallback on base main

At the audited base revision, `pos-app/lib/core/config/config_service.dart:98-132` first attempted to derive features from `app_config`, but on failure queried `public.tenants.features` and cached those results. This contradicted the documented rule that the relational feature projection is not runtime-authoritative.

**Proposed Phase 2 correction in PR #25:** the Home screen derives `TenantFeatures` from its existing `get_effective_config` result; the direct feature-row fetch and `tenants.features` fallback are removed. A missing feature map fails closed. Unit tests cover nested feature JSON, canonical flat feature flags, and missing configuration.

### SOURCE-VERIFIED — incomplete post-sync verification on base main

At the audited base revision, `scripts/sync_excel_to_supabase_legacy.py:505-547` used `_assert_subset` in `verify_remote()`. It rejected missing expected rows but accepted extra database rows, so the verification did not prove that workbook-owned projections exactly matched the workbook inventory.

**Proposed Phase 2 correction in PR #25:** replace subset checks with exact-set checks for `app_config`, `tenants`, `devices`, and `tenant_services`. The verifier reports missing and extra entries but does not delete data. Python regression tests are wired into `.github/workflows/canonical-workbook-validate.yml`.

## 3. STAGING-VERIFIED — read-only database inspection

The connected Supabase account exposed two projects, both explicitly named as staging environments. Queries below were SELECT-only and compared relational rows with key IDs derived from `public.app_config`.

| Check | `berkahtigaputeri-pos-staging-clone` (`txwzhesvcjftybrlhnzs`) | `berkahtigaputeri-pos-staging` (`cztlmwzfrhyafgawphgw`) |
|---|---:|---:|
| `app_config` rows | 352 | 352 |
| `app_config` keyset MD5 | `1fd3d64219ecc7c333453c20da80e295` | `1fd3d64219ecc7c333453c20da80e295` |
| Canonical key distribution | 1 global / 3 templates / 100 tenants / 140 services / 108 devices | Same |
| `tenants` rows | 2 | 103 |
| `devices` rows | 2 | 110 |
| `tenant_services` rows | 0 | 140 |
| Extra tenant projection rows not backed by canonical tenant keys | 2 | 3 |
| Missing canonical tenant projections | 100 | 0 |
| Extra device projection rows not backed by canonical device keys | 2 | 2 |
| Missing canonical device projections | 108 | 0 |
| Extra service projection rows not backed by canonical service keys | 0 | 0 |
| Missing canonical service projections | 140 | 0 |

Both projects also had the required `app_config` columns: `key text NOT NULL`, `value jsonb NOT NULL`, and `updated_at timestamp with time zone NOT NULL`. Both had 352 JSON-object values and no row failing the simple positive-integer version check.

### Runtime conclusion

- **SOURCE-/RUNTIME-VERIFIED:** both staging projects contain the correct 352-key `app_config` inventory and canonical hash.
- **RUNTIME-VERIFIED:** the staging clone is not synchronized with the canonical relational inventory; it has only 2 tenant rows, 2 device rows, and no tenant-service rows.
- **RUNTIME-VERIFIED:** the other staging project has the 100 expected tenant projections, 108 expected device projections, and 140 service projections, but also has 3 extra tenant rows and 2 extra device rows not represented by canonical keys.
- **NOT VERIFIED:** any production project's state. No production project was listed by the connected Supabase account.
- **NOT RUN:** workbook sync against either staging project; no Supabase mutation was authorized or executed in this audit.

## 4. Risks and required disposition

1. Do not mark Phase 2 green yet. The observed staging projections are not aligned across the two accessible projects.
2. Select the single authoritative staging target for Final Pos validation. The clone's missing 100/108/140 projections require workbook sync; the older staging project's three extra tenant rows and two extra device rows require identity-level reconciliation before any deletion or archival decision.
3. Run the canonical sync only through an authorized staged workflow with the expected credentials and a reviewed recovery plan. Verify exact row identities and counts after synchronization.
4. Keep production state unknown unless an explicitly identified production project is made available and read-only checks are performed.
5. The Phase 2 source fix must pass both the Flutter CI workflow and the workbook-validation workflow before merge.

## 5. Acceptance status

**BLOCKED / PARTIAL.** The source corrections are proposed in PR #25. The canonical 352-key contract, schema, keyset hash, and version-field shape passed read-only inspection in both staging projects, but relational ownership did not: one staging project is substantially under-provisioned, and the other has extra tenant/device projections. CI must finish and the staging target must be reconciled before Phase 2 can be certified.

**Next action:** finish CI for PR #25, choose the staging target, and execute a reviewed workbook-to-Supabase sync in that staging environment followed by exact projection verification. Do not use this report as a production-readiness certificate.
