# Agent instructions — canonical Berkah POS source

This personal repository is a **historical redirect only**. The canonical source of truth for current Berkah POS work is [berkah-pos/Berkahtigaputeri](https://github.com/berkah-pos/Berkahtigaputeri).

## Required canonical reads

1. [AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md)
2. [Accepted owner ADR — KVM2, Laravel and PostgreSQL 17](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-17-OWNER-KVM2-LARAVEL-POSTGRESQL-NO-SUPABASE.md)
3. [DOC_00 configuration contract](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md)
4. [DOC_14 target architecture and acceptance gates](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md)
5. [Master roadmap](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_MASTER_ROADMAP.md)
6. [Permanent-document/evidence index](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/README.md)

The accepted ADR is a target decision, not proof that implementation, migration or deployment is complete. Verify current organization `main`, exact candidate SHAs and the evidence tied to those SHAs. Keep implemented-on-main facts, accepted decisions, open-PR-only code, CI, staging observations and production acceptance separate; label missing evidence **NOT RUN / NOT VERIFIED**.

Old code, SQL/RLS/RPC, scripts, workbook artifacts and reports in this mirror are retained only as historical/source-migration evidence. They do not establish current target architecture or runtime authority. Do not execute mutation-capable legacy scripts against unknown/shared resources.

All active application, architecture, database, CI, security, infrastructure and deployment work belongs in the organization repository on a dedicated branch with a reviewed PR.
