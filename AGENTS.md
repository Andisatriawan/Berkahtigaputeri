# Agent instructions — personal legacy mirror

> **This repository is non-canonical.** Active Berkah POS source, architecture authority, CI evidence and delivery status belong to [berkah-pos/Berkahtigaputeri](https://github.com/berkah-pos/Berkahtigaputeri). Read the [canonical AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md) and follow that repository's instructions before doing any active project work.

## Required behavior

1. Treat this repository's code, SQL, architecture notes, roadmap, and agent rules as a legacy snapshot, not as authority for new implementation.
2. For any Berkah POS implementation, architecture, database, CI, security, deployment or release task, work from the canonical organization repository on a dedicated branch and reviewed PR. Do not create competing implementation changes here.
3. Read and follow the merged [owner architecture ADR](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-16-OWNER-ARCHITECTURE-DECISION.md), canonical [configuration contract](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md), [DOC_14 target architecture](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md), and [master roadmap](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_MASTER_ROADMAP.md) from the organization repository.
4. The accepted target is Laravel Central API + PostgreSQL 17. **Do not claim it is implemented or deployed from the ADR alone.** At organization main baseline d7ee23cfaada3405416b01d9e127e32b07fb1a38, Flutter remains Supabase-backed and root Composer files are absent; recheck current main before making status claims.
5. Keep evidence categories separate: implemented on main, accepted ADR target, open-PR-only implementation, CI tied to exact SHA, staging observations, and production deployment/acceptance. Mark missing evidence **NOT RUN / NOT VERIFIED**.
6. Preserve legacy Supabase schemas, RLS/RPC SQL, migration data/reports and workbook artifacts as historical/migration inputs unless an owner-approved cutover and retention decision says otherwise. The legacy scripts/sync_excel_to_supabase.py contains mutation-capable write paths when cloud credentials are supplied; never treat it as a harmless read-only validator or run it against an unknown/shared resource without explicit approval, verified backup and rollback.
7. Do not rewrite historical reports to manufacture a pass, delete history blindly, or infer test/deployment success from source presence or another commit's green CI.

This repository's instructions intentionally redirect active work to the organization source of truth. Update the relevant organization docs through that repository's review process; retain this mirror for historical reference.
