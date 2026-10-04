# DOC_09 - APK / CONFIG VERIFICATION CURRENT

Status: **CURRENT CODE CONTRACT / PHASE 7 RE-CERTIFICATION**

Flutter app: `pos-app/`

## Current runtime entry surface

`lib/main.dart` opens `HomeScreen`.

The current HomeScreen is a UAT/configuration screen. It provides:

- tenant selector;
- device ID input;
- config refresh;
- source status (`LIVE SUPABASE` / `CACHE OFFLINE`);
- effective POS MDR;
- POS/Akuntansi availability cards.

The cards are informational in the current entry UI. They do not navigate into cashier checkout, QRIS transaction, or PPN-report screens.

## Canonical effective-config order

The current Final Pos merge order is five levels:

```text
GLOBAL <- TEMPLATE <- TENANT <- SERVICE <- DEVICE
```

For one `(tenant_id, device_id, service)` request the keyset is:

```text
global
template:<tenant.template_id>
tenant:<tenant_id>
tenant:<tenant_id>:service:<service>
device:<device_id>
```

TEMPLATE is resolved from the tenant row using:

```text
template_id
```

with legacy compatibility for:

```text
template
```

The resolved template ID is normalized to uppercase.

Only the requested service participates in the effective configuration. POS and Akuntansi are not merged together.

## ConfigService behavior

`lib/core/config/config_service.dart` tries:

```text
get_effective_config(p_tenant, p_device, p_service)
```

first.

If that RPC call fails, the fallback SELECT path resolves the same five keys and merges them in the same order:

```text
GLOBAL
TEMPLATE
TENANT
requested SERVICE
DEVICE
```

The `inherited_from_template` compatibility rule on a service row removes service-level MDR aliases so the template MDR remains authoritative where intended.

If remote access fails completely, the last effective config may be read from SharedPreferences cache.

Cache key:

```text
p6.effective.<tenant>.<device>.<service>
```

## Feature flags

Final Pos feature flags are sourced from `app_config`.

Feature resolution reads:

```text
global
template:<tenant.template_id>
tenant:<tenant_id>
```

and then reads `features` or the supported flat feature aliases from that effective value.

The old `tenants.features` path is deprecated and remains only as a warning-emitting legacy fallback:

```dart
// DEPRECATED: tenants.features removed, Final Pos uses app_config
```

Feature cache key:

```text
p6.features.<tenant>
```

## RLS/auth contract

The Phase 5 backend contract no longer allows anonymous Final Pos config/identity reads.

`get_effective_config(...)` requires an authenticated caller and validates:

1. the requested device exists;
2. the device belongs to the requested tenant;
3. a normal authenticated caller owns the device through `devices.user_id`.

The canonical super admin is authenticated separately and retains its explicit management policy, but the RPC still requires a valid device-to-tenant pair.

Direct fallback SELECTs are also subject to RLS and therefore require an authenticated session.

### Current entry-point limitation

`lib/main.dart` constructs `SupabaseClient` with the publishable key but does not itself perform sign-in or provision an authenticated device session.

Therefore Phase 7 does **not** claim that a fresh install can reach live authenticated config merely by launching the current HomeScreen. Device-auth provisioning/session wiring must exist before the Phase 5 RLS contract can succeed online.

Offline cache may only help after a compatible value has previously been cached.

## TEMPLATE parity

The five-level model is aligned across:

```text
Flutter ConfigService
btp-admin/editor-core.js
public.get_effective_config(...)
```

All three include TEMPLATE before TENANT.

This supersedes the historical `GLOBAL <- TENANT <- SERVICE <- DEVICE` wording.

## Current UAT values in HomeScreen

The current HomeScreen still exposes historical UAT tenant labels:

```text
berkah_sumber
clientA
clientB
```

and documents `infinix_xos_123` as its default UAT device helper.

Those labels are part of the current UI implementation; they are not the canonical 352-key workbook naming scheme. The canonical workbook uses the Final Pos inventory governed by `APP_CONFIG_EXPORT`.

## Verification commands

Repository CI runs:

```text
flutter analyze
flutter test
flutter build appbundle --release
```

The workbook validation command is:

```text
python3 scripts/sync_excel_to_supabase.py --dry-run
```

Canonical workbook inventory:

```text
1 global + 3 template + 100 tenant + 140 service + 108 device = 352
```

## Release-note boundary

Current Play Store release notes may claim the UAT/configuration viewer and status information reachable from HomeScreen.

They must not claim, as current reachable release UX:

- offline cashier checkout;
- QRIS transaction flow;
- PPN report flow.

Those capabilities are not reachable from the current HomeScreen entry path.
