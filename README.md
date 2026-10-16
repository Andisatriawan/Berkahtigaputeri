# Berkah POS — Personal Repository Redirect

> **Canonical repository:** [berkah-pos/Berkahtigaputeri](https://github.com/berkah-pos/Berkahtigaputeri)
>
> This personal repository is a legacy snapshot, not the authoritative source for current code, architecture, CI, migration, staging, or release status. Use the organization repository for all active work.

## Current authority and status

The owner architecture decision was accepted and merged in organization PR [#49](https://github.com/berkah-pos/Berkahtigaputeri/pull/49). It selects a **Laravel Central API on KVM2/Coolify with PostgreSQL 17**, with a central database and separate tenant databases/restricted runtime roles. See the [owner ADR](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-16-OWNER-ARCHITECTURE-DECISION.md).

An accepted target is not proof of implementation. At organization main baseline d7ee23cfaada3405416b01d9e127e32b07fb1a38, Flutter still uses supabase_flutter and the repository root has no composer.json or composer.lock. Laravel target implementation, migration, production deployment, and production acceptance must not be claimed until verified against current organization source and exact-head evidence.

Start with the [organization README](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/README.md), [agent operating contract](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md), and [DOC_14 target architecture and acceptance gates](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md). Recheck the actual current branch and evidence rather than relying on this dated snapshot.

## Historical material

The Supabase SQL, schema/RLS/RPC references, sync script, workbook contract and reports retained in this personal repository are legacy source and migration context. They are **not current instructions to select Supabase as the target runtime**. Do not delete historical artifacts blindly or run mutation-capable scripts against an unknown/shared project.

Migration/source-of-truth identification and production deployment/acceptance remain blocked or **NOT RUN / NOT VERIFIED** until the canonical organization repository records direct evidence and owner approval.

## Where to make changes

Do not originate application, architecture, CI, infrastructure or release changes from this personal mirror. Work from the canonical organization repository on a dedicated branch and submit a reviewed pull request there. This repository is retained for historical reference and redirection only.
