import { createClient } from 'npm:@supabase/supabase-js@2.117.2';

type RequestBody = {
  device_id?: unknown;
  app_version?: unknown;
  package_id?: unknown;
  hardware_mode?: unknown;
  last_transaction_id?: unknown;
  sales_today?: unknown;
};

type LicenceRow = {
  device_id: string;
  tenant_id: string;
  toko_name: string;
  package_id: string;
  expiry_date: string | null;
  max_user: number;
  features: unknown;
  is_blocked: boolean;
  toko_address: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function requiredText(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`invalid_${field}`);
  }
  return value.trim();
}

function optionalText(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text.length === 0 ? null : text;
}

function asConfigObject(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function adminKey(): string {
  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (secretKeys) {
    const parsed = JSON.parse(secretKeys) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!legacy) throw new Error('supabase_admin_key_missing');
  return legacy;
}

function jakartaDate(): string {
  return new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const body = (await req.json()) as RequestBody;
    const deviceId = requiredText(body.device_id, 'device_id');
    const appVersion = optionalText(body.app_version) ?? 'unknown';
    const explicitPackageId = optionalText(body.package_id);
    const packageId = explicitPackageId ??
      (appVersion.includes('/') ? appVersion.split('/').at(-1) ?? null : null);
    const hardwareMode = optionalText(body.hardware_mode)?.toLowerCase() === 'real'
      ? 'REAL'
      : 'SIMULATED';

    const url = Deno.env.get('SUPABASE_URL');
    if (!url) throw new Error('supabase_url_missing');

    const admin = createClient(url, adminKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: licenceData, error: licenceError } = await admin
      .from('licences')
      .select('device_id,tenant_id,toko_name,package_id,expiry_date,max_user,features,is_blocked,toko_address')
      .eq('device_id', deviceId)
      .maybeSingle();
    if (licenceError) throw licenceError;

    const licence = licenceData as LicenceRow | null;
    let blocked = false;
    let reason: string | null = null;

    if (!licence) {
      blocked = true;
      reason = 'licence_not_found';
    } else if (licence.is_blocked) {
      blocked = true;
      reason = 'licence_blocked';
    } else if (licence.expiry_date && licence.expiry_date < jakartaDate()) {
      blocked = true;
      reason = 'licence_expired';
    }

    if (!blocked && licence && packageId && licence.package_id !== packageId) {
      blocked = true;
      reason = 'package_id_mismatch';
    }

    let config: Record<string, unknown> = {};
    if (!blocked && licence) {
      const tenantId = optionalText(licence.tenant_id);
      if (!tenantId) {
        blocked = true;
        reason = 'config_integrity_failed';
      } else {
        const { data: effectiveConfig, error: configError } = await admin.rpc(
          'get_effective_config',
          {
            p_tenant: tenantId,
            p_device: deviceId,
            p_service: 'pos',
          },
        );

        if (configError) {
          const code = String(configError.code ?? '');
          if (['22023', '23514', '42501', 'P0002'].includes(code)) {
            console.error('licence-check config fail-closed', code);
            blocked = true;
            reason = 'config_integrity_failed';
          } else {
            throw configError;
          }
        } else {
          const parsed = asConfigObject(effectiveConfig);
          if (!parsed) {
            blocked = true;
            reason = 'config_integrity_failed';
          } else {
            config = parsed;
          }
        }
      }
    }

    const status: Record<string, unknown> = {
      device_id: deviceId,
      last_seen: new Date().toISOString(),
      app_version: appVersion,
      hardware_mode: hardwareMode,
      updated_at: new Date().toISOString(),
    };
    const lastTransactionId = optionalText(body.last_transaction_id);
    if (lastTransactionId) status.last_transaction_id = lastTransactionId;
    if (
      typeof body.sales_today === 'number' &&
      Number.isFinite(body.sales_today) &&
      body.sales_today >= 0
    ) {
      status.sales_today = Math.trunc(body.sales_today);
    }

    const { error: statusError } = await admin
      .from('client_status')
      .upsert(status, { onConflict: 'device_id' });
    if (statusError) throw statusError;

    return json({
      blocked,
      reason,
      features: blocked ? [] : licence?.features ?? [],
      config: blocked ? {} : config,
      licence: licence
        ? {
            toko_name: licence.toko_name,
            package_id: licence.package_id,
            expiry_date: licence.expiry_date,
            max_user: licence.max_user,
            toko_address: licence.toko_address,
          }
        : null,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('licence-check failed', message);
    if (message.startsWith('invalid_')) return json({ error: message }, 400);
    return json({ error: 'licence_check_failed' }, 500);
  }
});
