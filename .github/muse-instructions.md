# Agent instructions — canonical Berkah POS source

This personal repository is a **historical redirect only**. The canonical repository for current source and project authority is [berkah-pos/Berkahtigaputeri](https://github.com/berkah-pos/Berkahtigaputeri). Follow its [AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md) and architecture documents for all active work.

## Authority and status

- The owner ADR is accepted and merged in organization PR [#49](https://github.com/berkah-pos/Berkahtigaputeri/pull/49): Laravel Central API on KVM2/Coolify, PostgreSQL 17, PHP 8.4, Laravel 13, Filament 5, Sanctum, and tenancy package candidate v3.10.1.
- This accepted design does not mean it is implemented. Organization main at baseline d7ee23cfaada3405416b01d9e127e32b07fb1a38 still contains the Supabase-backed Flutter runtime and has no root Composer manifest/lockfile. Re-check current organization source and exact-head CI before any claim.
- Do not treat this repository's Supabase RLS/schema/RPC directions as current runtime policy. Retain them only as historical implementation and migration evidence. Do not run the mutation-capable legacy sync script against an unknown/shared resource without explicit owner approval, verified backup and rollback.

For active tasks, use the organization repository's canonical DOC_00 configuration contract, DOC_14 target architecture, master roadmap, and evidence rules. Separate implemented-on-main facts, accepted target decisions, open-PR-only implementation, exact-SHA CI, staging observations, and production deployment/acceptance; missing states are **NOT RUN / NOT VERIFIED**.

Do not create parallel implementation or architecture changes in this personal mirror. Make changes in the organization repository on a feature branch and submit a reviewed PR.
