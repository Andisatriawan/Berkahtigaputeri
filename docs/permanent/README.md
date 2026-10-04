# DOCS PERMANENT - FINAL POS ARCHITECTURE AUTHORITY

This folder contains the durable architecture, security, schema, operational and verification record for Berkah POS.

## Read order

Every engineer or AI agent must start with:

1. `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md` - sole authority for Final Pos configuration inheritance.
2. `DOC_00_MASTER_ROADMAP.md` - ordered correction and delivery roadmap.
3. `DOC_01_3_LAYER_CONFIG.md` - legacy filename, now rewritten as the Final Pos config contract.
4. `DOC_02_SUPABASE_SCHEMA_V1.sql` and `DOC_02_VERIFICATION.md` - schema and verification baseline.
5. `DOC_03_RLS_AUTH.sql` and `DOC_03_VERIFICATION.md` - RLS/auth baseline.
6. `DOC_04_ADMIN_ARCHITECTURE.md` and `DOC_04_VERIFICATION.md` - Admin architecture and verification.
7. `DOC_05_FEATURE_FLAGS.md` / `DOC_05_FEATURE_FLAGS.sql` - service/feature configuration.
8. `DOC_06_AUDIT_VERSIONING.md` - audit and versioning contract.
9. `DOC_07_FINAL_VERIFICATION.md` - existing verification record pending historical archival/re-certification in the correction roadmap.
10. `DOC_08_RPC_EFFECTIVE_CONFIG.sql` - effective-config RPC.
11. `DOC_09_APK_VERIFICATION.md` - APK/config verification, pending canonical-auth updates in later correction phases.

When an older document conflicts with `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`, the architecture decision wins and the conflicting document must be corrected.

## Canonical Final Pos model

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

Canonical workbook:

```text
config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx
```

Workbook structure is validated by `scripts/sync_excel_to_supabase.py`; do not infer its binary contents through the GitHub text API.

Canonical `APP_CONFIG_EXPORT` inventory:

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

Canonical schema shape:

```text
app_config(key PRIMARY KEY, value JSONB, updated_at)
```

## Effective-config rule

For one `(tenant_id, device_id, service)` request, resolve and merge only:

```text
global
template:<tenant.template_id>
tenant:<tenant_id>
tenant:<tenant_id>:service:<service>
device:<device_id>
```

POS and Akuntansi service rows are not combined into the same effective configuration.

## Repository operating rule

- Make implementation changes on a branch and merge through review/PR.
- Do not treat a historical commit as a permanently frozen architecture authority.
- Do not restore any inheritance model that omits TEMPLATE.
- Keep historical verification only when clearly labelled historical.
- Keep `btp-admin/` as the published Admin path.

## Live Admin

https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
