# Canonical repository notice

This personal repository is a **historical personal copy**, not the source of truth for Berkah POS architecture, implementation status, CI evidence or release decisions.

**Use the canonical organization repository:** https://github.com/berkah-pos/Berkahtigaputeri

Start with the organization repo's [AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md), [accepted owner ADR](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-16-OWNER-ARCHITECTURE-DECISION.md), [DOC_00 configuration contract](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md), [DOC_14 target architecture](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md), [master roadmap](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_MASTER_ROADMAP.md) and [permanent-document index](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/README.md).

The local instructions and architecture copies in this repository describe an older Supabase-oriented direction and may conflict with the accepted target. **Do not use those local instructions as current authority, and do not copy old Supabase runtime rules into new work.** Keep existing code, SQL and reports as historical/source-migration evidence; do not erase them merely because the architecture decision changed.

Status note dated 2026-10-16: the owner ADR selecting Laravel Central API + PostgreSQL 17 is accepted, but the canonical organization `main` still contains a Supabase-backed Flutter runtime. The accepted target is not proof of implementation or deployment. Check the canonical repository's dated evidence and exact PR head SHA before making delivery claims.
