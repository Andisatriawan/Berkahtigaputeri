# DOC_06 — Audit & Atomic Versioning

## Status

Canonical Phase 6 contract for `public.app_config` writes.

Configuration inheritance remains:

`GLOBAL → TEMPLATE → TENANT → SERVICE → DEVICE`

Every `app_config.value` JSON object must contain a positive integer `version`.

## Only normal update path: atomic RPC

The only normal write path for an **existing** `app_config` key is:

```sql
public.update_app_config_atomic(
  p_key text,
  p_new_value jsonb,
  p_expected_version integer
)
```

Do not implement client-side `read version → compare → upsert`. That sequence is race-prone because two writers can observe the same version before either write commits.

The canonical function is defined by `DOC_06_ATOMIC_VERSIONING_RPC.sql`. It:

1. locks the requested row with `SELECT ... FOR UPDATE`;
2. fails with `P0002` if the key does not exist;
3. reads the locked row's current positive integer `version`;
4. fails with SQLSTATE `40001` when it differs from `p_expected_version`;
5. overwrites any caller-supplied `version` with `p_expected_version + 1`;
6. updates with a second `WHERE version = p_expected_version` guard;
7. fails with SQLSTATE `40001` if that guarded update does not affect a row;
8. returns the stored JSON value, including the new version.

Because the row is locked before the comparison, two transactions starting with the same expected version cannot both succeed. One acquires the row lock and writes `N+1`; the other waits, then sees `N+1` and fails with `40001` when it resumes.

## Authorization

The RPC is `SECURITY DEFINER SET search_path = ''` and is granted to `authenticated` and `service_role` for PostgREST exposure.

`SECURITY DEFINER` must not weaken Phase 5 isolation. The function therefore performs an internal authorization guard:

- `service_role` JWT: allowed for controlled administrative synchronization;
- canonical authenticated admin `satria@berkahtigaputeri.com`: allowed;
- ordinary authenticated device users: rejected with `42501`.

`anon` has no execute grant.

## Admin behavior

Classic Admin and Template Admin load the current positive `value.version` and call the RPC directly with the corresponding `p_expected_version`.

On SQLSTATE `40001`, the UI must not overwrite server state. It reloads the latest row and displays:

> Data changed by another admin, please reload

The client never assigns the stored version itself.

## Workbook synchronization

`scripts/sync_excel_to_supabase.py` is a **versioned administrative replacement** operation.

For every workbook-owned `app_config` key:

- missing key → bootstrap once with `version: 1`;
- existing key at live version `N` → replace through `update_app_config_atomic(..., p_expected_version=N)` and store `N+1`;
- normal mode → fail closed if another writer changes the key after the importer read it;
- `--force-version` → explicitly refresh the latest live version after `40001` and retry the same atomic RPC.

`--force-version` does **not** disable compare-and-swap and does not accept a caller-chosen target version. It only authorizes the administrative importer to replace a row after refreshing the newest version; the server still performs the lock/check/bump atomically.

## Bootstrap and seed rule

A genuinely missing canonical key may be inserted at `version: 1`. This is the only bootstrap exception to the update-RPC rule.

All `app_config` `INSERT` seeds in `DOC_02_SUPABASE_SCHEMA_V1.sql` include `"version": 1`.

`DOC_05_FEATURE_FLAGS.sql` also inserts at version `1`, but an `ON CONFLICT DO UPDATE` represents another semantic write and therefore stores the existing database version plus one:

```sql
value = (excluded.value - 'version')
  || jsonb_build_object(
    'version',
    (app_config.value ->> 'version')::integer + 1
  )
```

A conflict must never reset a newer row to version `1`.

## Audit history

`trg_app_config_audit` records `old_value`, `new_value`, actor, timestamp, and the resulting version. Because the version bump occurs in the same database transaction as the semantic change, audit rows observe the committed transition rather than a client-side guess.

## Acceptance checks

Phase 6 is green only when all of the following are true:

- every canonical `app_config` row has a positive integer version;
- wrong `p_expected_version` fails with SQLSTATE `40001`;
- correct `p_expected_version=N` succeeds with stored `version=N+1`;
- a stale second writer using the same `N` fails with `40001`;
- row locking guarantees two concurrent callers using the same `N` cannot both succeed;
- caller-supplied `version` cannot override the server-generated version;
- Admin and Template Admin use the RPC rather than direct `app_config` upsert;
- workbook replacement bumps existing rows and bootstraps only missing rows at version `1`;
- `--force-version` refreshes and retries conflicts without disabling CAS;
- `DOC_02` and `DOC_05` seeds cannot reset a newer version to `1`.
