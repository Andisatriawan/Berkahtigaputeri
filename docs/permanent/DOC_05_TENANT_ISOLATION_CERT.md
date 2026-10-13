# DOC_05 — Tenant Isolation Certification

**Status: STAGING POLICY/RPC TESTS PASS — FULL PHASE 5 CERTIFICATION PENDING LOAD AND APK/HTTP EVIDENCE**

Audit date: 2026-10-13  
Branch: `audit/phase-5-tenant-isolation`  
Canonical staging project: `cztlmwzfrhyafgawphgw` (`berkahtigaputeri-pos-staging`)  
Staging clone: `txwzhesvcjftybrlhnzs` (`berkahtigaputeri-pos-staging-clone`)  
Production certification: **not claimed**

## Contract and schema verified

The actual schema is the text-keyed contract, not the UUID example in the task prompt:

- `public.tenants.tenant_id TEXT`
- `public.devices.device_id TEXT`, `tenant_id TEXT`, `user_id UUID`
- `public.licences.device_id TEXT`, `tenant_id TEXT`
- `public.app_config(key PRIMARY KEY, value JSONB, updated_at)`

The canonical inventory remains 352 keys: 1 GLOBAL, 3 TEMPLATE, 100 TENANT, 140 SERVICE and 108 DEVICE. The observed keyset MD5 is `1fd3d64219ecc7c333453c20da80e295`.

## Anonymous-access proof

The Phase 5 migration was applied successfully to both named staging projects. After migration, the database audit returned:

- RLS enabled on `tenants`, `devices`, `licences`, and `app_config`.
- **Zero** `anon` table grants and **zero** `PUBLIC` table grants across `tenants`, `devices`, `licences`, `app_config`, `tenant_services`, `config_history`, `accounting_coa`, and `client_status` in the staging clone.
- The effective-config RPC exists with signature `get_effective_config(text,text,text)`, is `SECURITY DEFINER` with an empty search path, and has execute ACL for `authenticated` and `service_role`; no `anon`/PUBLIC execute grant is present.
- The staging clone's 352-key count and MD5 are unchanged after migration.

## Tenant-isolation regression test

`supabase/tests/tenant_isolation.test.sql` was executed against the canonical staging project inside a transaction that ends with `ROLLBACK`. Its 27 planned pgTAP assertions cover:

- RLS enabled for the four core tables and anonymous SELECT/function execution removed.
- Tenant A sees its own tenant/device but not Tenant B's tenant, device, licence, or device configuration.
- Direct reads of GLOBAL, TEMPLATE, TENANT and SERVICE config rows are denied; Tenant A may read only its bound `device:<device_id>` row.
- The RPC output matches independently calculated five-layer merges for POS and Akuntansi, one requested service at a time.
- Cross-tenant device/tenant combinations raise SQLSTATE `42501` with the expected ownership-rejection messages.

The final emitted assertion was `ok 27 - matching Tenant B IDs remain unauthorized to Tenant A`; pgTAP `finish()` returned no failure/plan-mismatch diagnostics. Test users, the test licence and temporary device assignments were rolled back; a subsequent query confirmed zero test users and zero test licence rows remained.

## Runtime model and limitations

**RLS/auth documentation and APK verification describe the same model:** the Flutter client requires an authenticated Supabase session and calls the authenticated effective-config RPC; it does not SELECT raw GLOBAL/TEMPLATE/TENANT/SERVICE rows directly. During transient request failure, it may use only the previously returned effective result cached for the exact tenant/device/service tuple.

Evidence level is **source + staging database**, not production and not installed-APK certification. No screenshot of a live HTTP 403 response was captured in this tool environment; the SQL test proves the denial through SQLSTATE `42501`, not through a separately executed HTTP request. A 50-concurrent-authorized-tenant performance run also remains **not executed**. These gaps must remain open rather than be represented as passed.

## Phase 5 disposition

- Anonymous grants/RLS/RPC ownership gate: **verified on staging**.
- Two-tenant SQL isolation and service-layer merge test: **passed on staging**.
- Source/RLS/APK model alignment: **source verified; installed APK behavior pending**.
- 50-tenant concurrent load, actual HTTP 403 screenshot, and production certification: **pending**.

Phase 5 is not declared fully certified until the pending runtime/load evidence is supplied.
