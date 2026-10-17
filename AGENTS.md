# Agent instructions — personal legacy mirror

> **This repository is non-canonical and historical-only.** Current Berkah POS source, architecture authority, CI evidence and delivery status belong to [berkah-pos/Berkahtigaputeri](https://github.com/berkah-pos/Berkahtigaputeri).

## Required canonical reading order

1. [Canonical AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md)
2. [Accepted owner ADR — KVM2, Laravel and PostgreSQL 17](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-17-OWNER-KVM2-LARAVEL-POSTGRESQL-NO-SUPABASE.md)
3. [DOC_00 canonical configuration/workbook contract](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md)
4. [DOC_14 target architecture and acceptance gates](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md)
5. [Master roadmap](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_MASTER_ROADMAP.md)
6. [Permanent-document/evidence index](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/README.md)

For any implementation, architecture, database, CI, security, infrastructure, or release task, work from the canonical organization repository on a dedicated branch and reviewed PR. Do not create competing implementation or architecture changes in this personal mirror.

The accepted owner ADR defines the target; it does not prove implementation or deployment. Verify the current organization branch, exact candidate SHA, relevant CI, and direct staging/production evidence. Keep accepted design, merged source, open-PR-only changes, CI, staging, and production acceptance distinct.

Old code, SQL/RLS/RPC, scripts, workbook artifacts, reports, and history in this mirror are historical/source-migration evidence only, not current architecture authority. Retain history rather than copying legacy decisions into the canonical repository. Do not execute mutation-capable legacy scripts against unknown/shared resources.

Only maintain this personal repository when explicitly tasked with its redirect/history. Never rewrite historical reports to manufacture a pass or infer test/deployment success from source presence.
