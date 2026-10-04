# DOC_01 - FINAL POS CONFIG CONTRACT

> Filename retained for compatibility with existing links. The old layer count is superseded. This document now defines the canonical Final Pos contract.

Repository: `berkah-ajb-dev/Berkahtigaputeri`

## Authority

`DOC_00_CANONICAL_ARCHITECTURE_DECISION.md` is authoritative.

The only canonical inheritance order is:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

## Purpose

Final Pos configuration must scale across many tenants without copying every setting into every store. Templates provide reusable package defaults, tenant rows hold tenant identity/overrides, service rows isolate POS versus Akuntansi behavior, and device rows provide the highest-precedence device-specific override.

The canonical configuration table is:

```text
app_config(key PRIMARY KEY, value JSONB, updated_at)
```

The legacy `app_config(device_id, key, value)` shape is not valid for Final Pos.

## Canonical workbook inventory

The configuration dataset originates from:

```text
config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx
```

`scripts/sync_excel_to_supabase.py` validates these workbook sheets:

```text
README_PRODUCTION
TEMPLATES
GLOBAL
TENANTS_MASTER
DEVICES
SERVICES
APP_CONFIG_EXPORT
```

`APP_CONFIG_EXPORT` must contain exactly:

```text
1   global
3   templates
100 tenants
140 services
108 devices
---
352 canonical keys
```

Canonical template IDs are `BASIC`, `PRO`, and `ENTERPRISE`.

## GLOBAL

Key:

```text
global
```

Contains defaults that can apply to all tenants unless overridden later in the inheritance chain.

## TEMPLATE

Key form:

```text
template:<TEMPLATE_ID>
```

Examples:

```text
template:BASIC
template:PRO
template:ENTERPRISE
```

A tenant row identifies its template through `template_id` or the compatibility field `template`. Template values are merged after GLOBAL and before TENANT.

Templates are the reusable source for package-level defaults. A tenant assigned to `PRO` inherits later changes to `template:PRO` unless the tenant, requested service, or device explicitly overrides the same field.

## TENANT

Key form:

```text
tenant:<tenant_id>
```

Example:

```text
tenant:tenant_001
```

The tenant layer stores tenant-specific identity/configuration and the template assignment required to resolve the TEMPLATE layer.

Tenant overrides must not mutate `global`, a template row, or another tenant.

## SERVICE

Key form:

```text
tenant:<tenant_id>:service:<service>
```

Typical services:

```text
tenant:tenant_001:service:pos
tenant:tenant_001:service:akuntansi
```

Effective configuration is resolved for **one requested service at a time**. POS and Akuntansi service rows must not be merged together into one effective-config result.

Service rows derived from a template may be retained for audit/export. When a field is intentionally inherited from the template, the effective resolver must preserve that inheritance rather than accidentally materializing a stale duplicated override.

## DEVICE

Key form:

```text
device:<device_id>
```

Example from the workbook validator contract:

```text
device:infinix_001_410
```

DEVICE is the highest-precedence configuration layer and is used for device-specific behavior such as hardware mode, printer configuration and other terminal overrides.

A device used in an effective-config request must belong to the requested tenant under the authenticated tenant/device authorization model.

## Effective configuration resolution

For `(tenant_id, device_id, service)`:

```text
1. global
2. template:<tenant.template_id>
3. tenant:<tenant_id>
4. tenant:<tenant_id>:service:<service>
5. device:<device_id>
```

Merge precedence:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

Later layers override earlier layers only for keys they explicitly contain.

## Required behavioral parity

All effective-config implementations must produce the same result for the same `(tenant_id, device_id, service)`:

- Supabase `get_effective_config` RPC;
- Flutter `ConfigService`;
- classic `btp-admin` editor;
- Final Pos Template Admin where it presents effective values;
- verification tests.

At the correction-program baseline, Flutter `pos-app/lib/core/config/config_service.dart` already contains TEMPLATE resolution and is the local-merge behavioral reference while other implementations are brought into parity.

## Compliance rules

- Do not implement an inheritance chain that omits TEMPLATE.
- Do not merge POS and Akuntansi service rows when resolving one requested service.
- Do not write tenant values into `global` or template values into tenant/device rows.
- Do not write device-specific values into tenant/service rows.
- Do not restore the legacy `(device_id, key, value)` schema.
- Do not use historical verification text as authority when it conflicts with `DOC_00_CANONICAL_ARCHITECTURE_DECISION.md`.
- SQL, Admin, Flutter, workbook sync, tests and release verification must all follow this contract.
