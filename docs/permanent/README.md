# DOCS PERMANENT — FINAL POS ARCHITECTURE AUTHORITY

This folder contains the durable architecture, security, schema, operational, and verification record for Berkah POS.

## Read order

1. `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md` — sole authority for Final Pos inheritance.
2. `DOC_00_MASTER_ROADMAP.md` — ordered correction/delivery roadmap.
3. `DOC_01_3_LAYER_CONFIG.md` — legacy filename; content is the Final Pos five-level contract.
4. `DOC_02_SUPABASE_SCHEMA_V1.sql`, `DOC_02_FINAL_POS_RELATIONAL_OWNERSHIP.sql`, `DOC_02_VERIFICATION.md` — schema/workbook ownership.
5. `DOC_03_RLS_AUTH.sql`, `DOC_03_RLS_AUTH_FIXED.sql`, `DOC_03_VERIFICATION.md` — current authenticated tenant-isolation contract.
6. `DOC_04_ADMIN_ARCHITECTURE.md`, `DOC_04_VERIFICATION.md` — Admin architecture.
7. `DOC_05_FEATURE_FLAGS.md`, `DOC_05_FEATURE_FLAGS.sql` — service/feature configuration.
8. `DOC_06_AUDIT_VERSIONING.md`, `DOC_06_ATOMIC_VERSIONING_RPC.sql` — atomic version integrity.
9. `DOC_07_FINAL_VERIFICATION_CURRENT_HEAD.md` — **active current-head re-certification authority**.
10. `DOC_07_FINAL_VERIFICATION_HISTORICAL_a19cb3f.md` — historical old 3-layer/a19cb3f certification only; **not current authority**.
11. `DOC_08_RPC_EFFECTIVE_CONFIG.sql` — authenticated effective-config RPC reference.
12. `DOC_09_APK_VERIFICATION.md` — APK/config verification and release-surface boundary.

When an older document conflicts with `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md` or current DOC_07, the current Final Pos authority wins.

## Canonical model

```text
GLOBAL → TEMPLATE → TENANT → SERVICE → DEVICE
```

Canonical workbook:

`config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx`

Canonical inventory:

```text
1 global + 3 templates + 100 tenants + 140 services + 108 devices = 352 keys
```

Canonical key forms:

```text
global
template:<TEMPLATE_ID>
tenant:<tenant_id>
tenant:<tenant_id>:service:<service>
device:<device_id>
```

POS and Akuntansi service rows are service-specific and are not merged together.

## Security boundary

Anonymous direct reads of Final Pos backing tables are not allowed. Anonymous execution of `get_effective_config(...)` is also revoked. Runtime cloud config requires authentication, and normal authenticated callers are scoped by `devices.user_id = auth.uid()` plus device-to-tenant validation.

## Repository operating rule

- Work on branches and merge through review/PR.
- Do not push Final Pos implementation directly to `main`.
- Do not restore inheritance that omits TEMPLATE.
- Do not re-enable anonymous Final Pos table/RPC reads.
- Keep `btp-admin/` as the published Admin path.
- Treat `DOC_07_FINAL_VERIFICATION_CURRENT_HEAD.md` as the active certification.
- Keep historical verification clearly labelled historical.

## Live Admin

https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
