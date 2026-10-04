# DOC_06 — Audit & Atomic Versioning

## Status

Canonical Phase 6 contract for `public.app_config` writes.

The configuration hierarchy remains:

`GLOBAL → TEMPLATE → TENANT → SERVICE → DEVICE`

Every `app_config.value` JSON object must contain a positive integer `version`.

## Atomic write contract

Normal configuration updates do **not** perform a client-side read/check followed by `upsert`. That sequence is race-prone because two writers can observe the same version before either write commits.

The canonical write API is:

```sql
public.update_app_config_atomic(
  key text,
  new_value jsonb,
  expected_version integer
)
```

The RPC performs one PostgreSQL `UPDATE` whose predicate includes both the key and the expected version:

```sql
UPDATE public.app_config
SET value = (new_value - 'version')
      || jsonb_build_object('version', expected_version + 1),
    updated_at = now()
WHERE app_config.key = key
  AND (app_config.value ->> 'version')::integer = expected_version;
```

Therefore only one concurrent writer can win for a given loaded version. A stale writer receives SQLSTATE `40001` with a `VERSION_CONFLICT` message and must reload before retrying.

The client does not control the stored version. Any `version` supplied inside `new_value` is removed; the server writes exactly `expected_version + 1`.

## Client behavior

Admin, Template Admin, and workbook synchronization use the same semantics:

1. load the current row and its positive integer `value.version`;
2. send the desired JSON value plus that loaded version as `expected_version`;
3. accept the server-returned row/version on success;
4. on `40001`, do not overwrite—reload the latest value and let the operator retry intentionally.

Bootstrap insertion is the only exception: a genuinely missing canonical key may be inserted once with `version: 1`. Subsequent updates use the atomic RPC.

## Seed rule

Every seed must contain `"version": 1` on first insert. An `ON CONFLICT DO UPDATE` seed must preserve the database's current version rather than resetting it to 1.

Safe pattern:

```sql
INSERT INTO public.app_config AS current_config (key, value, updated_at)
VALUES (
  'example:key',
  '{"enabled":true,"version":1}'::jsonb,
  now()
)
ON CONFLICT (key) DO UPDATE SET
  value = (current_config.value || (excluded.value - 'version'))
    || jsonb_build_object(
      'version',
      CASE
        WHEN coalesce(current_config.value ->> 'version', '') ~ '^[1-9][0-9]*$'
          THEN (current_config.value ->> 'version')::integer
        ELSE 1
      END
    ),
  updated_at = excluded.updated_at;
```

`DOC_02_SUPABASE_SCHEMA_V1.sql` and `DOC_05_FEATURE_FLAGS.sql` follow this invariant.

## Audit history

`trg_app_config_audit` continues to record `old_value`, `new_value`, actor, timestamp, and the new version after an insert/update. Because the RPC writes the incremented version in the same database statement, audit rows observe the committed version transition rather than a client-side guess.

## Acceptance checks

- legacy rows with missing/invalid versions are normalized once to version 1;
- an atomic write at version `N` returns version `N+1`;
- a second write with stale `expected_version=N` fails with SQLSTATE `40001`;
- anonymous callers cannot execute the RPC;
- authenticated Admin and service-role synchronization can execute it subject to their existing RLS/role privileges;
- seeds never reset a newer version to 1.
