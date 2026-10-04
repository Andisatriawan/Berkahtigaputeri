# Copilot Instructions - Berkah POS Final Pos

Before any code change, read:

- `docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`
- `docs/permanent/DOC_00_MASTER_ROADMAP.md`
- `docs/permanent/DOC_01_3_LAYER_CONFIG.md` (legacy filename; Final Pos content)
- `scripts/sync_excel_to_supabase.py` when working with workbook/config synchronization

## Canonical architecture

The only supported effective-config inheritance is:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
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

The canonical workbook is `config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx`; its validator requires exactly 352 exported keys: 1 global + 3 templates + 100 tenants + 140 services + 108 devices.

## Rules

- Do not implement an inheritance path that omits TEMPLATE.
- Resolve only the requested service; never merge POS and Akuntansi service rows into one effective configuration.
- Do not restore the legacy `app_config(device_id, key, value)` schema.
- Use a branch + PR for changes; do not push implementation changes directly to `main`.
- Official Admin code stays under `btp-admin/`; do not create a duplicate root `complete-settings.html` implementation.
- Historical verification does not override `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`.
- Follow correction phases in `DOC_00_MASTER_ROADMAP.md` in order.
- Preserve GitHub Pages publication of `btp-admin/`.

Live Admin: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
