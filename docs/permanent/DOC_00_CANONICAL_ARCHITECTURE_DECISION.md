# DOC_00 - CANONICAL ARCHITECTURE DECISION

Status: **ACCEPTED / AUTHORITATIVE**  
Repository: `berkah-ajb-dev/Berkahtigaputeri`  
Baseline for this correction program: `46ffd869c7ddb5e83b3a732b4e311bf2921f8a26`

## Decision

There is exactly one canonical Final Pos configuration inheritance model:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

Later layers override earlier layers only for keys they explicitly define. Unspecified values continue to inherit from the previous layer.

This document is the architecture authority for configuration inheritance. Any documentation, agent instruction, Admin implementation, Flutter implementation, SQL/RPC, test, workflow, or release verification that describes a different inheritance order is stale and must be corrected.

## Canonical workbook and key inventory

The canonical production configuration workbook is:

```text
config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx
```

The workbook contract is validated by `scripts/sync_excel_to_supabase.py`. Its expected sheets are:

```text
README_PRODUCTION
TEMPLATES
GLOBAL
TENANTS_MASTER
DEVICES
SERVICES
APP_CONFIG_EXPORT
```

`APP_CONFIG_EXPORT` contains exactly **352 canonical `app_config` keys**:

```text
1   global
3   templates
100 tenants
140 services
108 devices
---
352 total
```

The canonical templates are:

```text
BASIC
PRO
ENTERPRISE
```

## Canonical `app_config` key forms

```text
global
template:<TEMPLATE_ID>
tenant:<tenant_id>
tenant:<tenant_id>:service:<service>
device:<device_id>
```

Examples:

```text
template:PRO
tenant:tenant_001
tenant:tenant_001:service:pos
device:infinix_001_410
```

`app_config` uses:

```text
app_config(key PRIMARY KEY, value JSONB, updated_at)
```

The legacy `(device_id, key, value)` shape is not canonical.

## Effective configuration algorithm

For a requested `(tenant_id, device_id, service)`:

1. Load `global`.
2. Load `tenant:<tenant_id>` and resolve its `template_id`/`template`.
3. Load `template:<TEMPLATE_ID>`.
4. Load only `tenant:<tenant_id>:service:<service>` for the requested service.
5. Load `device:<device_id>`.
6. Merge in this exact precedence order:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

POS and Akuntansi service rows must never be merged together when resolving one requested service.

## Runtime reference implementation

`pos-app/lib/core/config/config_service.dart` calls the authenticated `get_effective_config` RPC for remote configuration and may use only a previously returned effective-config cache for the exact tenant/device/service tuple during transient offline errors. It must not directly SELECT layered GLOBAL/TEMPLATE/TENANT/SERVICE rows. `ConfigService.mergeLayers()` is the Flutter merge-order reference.

`docs/permanent/DOC_08_RPC_EFFECTIVE_CONFIG.sql` expresses the same Final Pos inheritance order and remains subject to the authentication hardening specified by the correction roadmap.

## Superseded statements

The following concepts are superseded and must not be used as architecture authority:

- any configuration model that omits TEMPLATE;
- any inheritance description equivalent to `GLOBAL -> TENANT -> DEVICE`;
- any instruction that treats an historical commit as a permanently frozen implementation authority;
- any Admin merge that combines POS and Akuntansi service rows for one effective-config request.

Historical verification documents may retain old facts only when explicitly marked **HISTORICAL** and must not override this decision.

## Change control

A future change to the inheritance model requires all of the following in one reviewed change set:

- update this architecture decision;
- update workbook validator/sync logic;
- update RPC and Flutter/Admin resolvers;
- update tests and verification documents;
- provide migration and backward-compatibility impact.

Until such a change is merged, **GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE is the only authority**.
