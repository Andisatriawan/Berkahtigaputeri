# AGENTS COMPLIANCE - FINAL POS

Repository: `berkah-ajb-dev/Berkahtigaputeri`  
Live Admin: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/

## Mandatory read order before coding

1. `docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`
2. `docs/permanent/DOC_00_MASTER_ROADMAP.md`
3. `docs/permanent/DOC_01_3_LAYER_CONFIG.md` - legacy filename; content is the Final Pos contract.
4. `docs/permanent/DOC_02_SUPABASE_SCHEMA_V1.sql`
5. `docs/permanent/DOC_03_RLS_AUTH.sql`
6. `docs/permanent/DOC_04_ADMIN_ARCHITECTURE.md`

If any later or older document conflicts with the canonical architecture decision, follow the decision and correct the stale document in the same change set.

## Canonical Final Pos configuration

The only supported inheritance order is:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

Canonical workbook:

```text
config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx
```

Do not attempt to infer the binary workbook through GitHub's text API. Read `scripts/sync_excel_to_supabase.py` to understand and validate its expected structure.

The workbook validator requires:

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

Schema:

```text
app_config(key PRIMARY KEY, value JSONB, updated_at)
```

For one `(tenant_id, device_id, service)` request, merge only the requested service row. Never combine POS and Akuntansi service rows into the same effective configuration.

## Behavioral reference

At the correction-program baseline, `pos-app/lib/core/config/config_service.dart` already resolves TEMPLATE in its local fallback and is the behavioral reference for merge order while Admin/RPC parity is being completed.

## Engineering constraints

- Make changes on a branch and merge through a PR; do not push implementation changes directly to `main`.
- Do not restore any architecture that omits TEMPLATE.
- Do not restore `app_config(device_id, key, value)`.
- Keep the official Admin under `btp-admin/`; do not create a duplicate root `complete-settings.html` implementation.
- Preserve the intentionally green contracts documented in the roadmap: FEFO physical allocation vs FIFO costing, COA inventory/COGS account mapping, aligned app version metadata, and GitHub Pages publication of `btp-admin/`.
- Historical verification may be retained only when clearly labelled historical and must not override current canonical decisions.

## Execution order

Follow `DOC_00_MASTER_ROADMAP.md` and complete correction phases in sequence. Do not skip ahead when a later phase depends on an earlier contract.
