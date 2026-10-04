-- DOC_08 - RPC EFFECTIVE CONFIG P6
-- Copy paste ini di Supabase SQL Editor dan Run untuk membuat RPC.
-- Setelah sukses, test dengan:
-- SELECT get_effective_config('berkah_sumber','infinix_xos_123','pos');

CREATE OR REPLACE FUNCTION get_effective_config(p_tenant text, p_device text, p_service text) RETURNS jsonb AS $$
DECLARE result jsonb := '{}'::jsonb; r record; BEGIN FOR r IN SELECT value FROM app_config WHERE key IN ('global','tenant:'||p_tenant,'tenant:'||p_tenant||':service:'||p_service,'device:'||p_device) ORDER BY CASE WHEN key='global' THEN 1 WHEN key='tenant:'||p_tenant THEN 2 WHEN key='tenant:'||p_tenant||':service:'||p_service THEN 3 WHEN key='device:'||p_device THEN 4 END LOOP result := result || r.value; END LOOP; RETURN result; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
