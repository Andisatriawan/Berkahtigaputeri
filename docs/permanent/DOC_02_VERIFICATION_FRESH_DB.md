# Fresh DB rebuild verification - P0-2 Fix
## Steps to verify fix
1. Create empty Supabase project
2. Run in order:
   - DOC_02_SUPABASE_SCHEMA_V1.sql
   - DOC_02_FINAL_POS_RELATIONAL_OWNERSHIP.sql (now self-contained with ADD IF NOT EXISTS)
   - DOC_03_RLS_AUTH.sql
3. Expected: No error "column user_id does not exist"
4. Before fix: fails at ALTER COLUMN user_id because column missing
5. After fix: passes with ADD COLUMN IF NOT EXISTS

CI: Add job that runs psql -f in order on ephemeral DB
