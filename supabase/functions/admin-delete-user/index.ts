// Edge Function: admin-delete-user
//
// Removes an account — the auth user, which cascades to the profile and to
// everything hanging off it (module memberships, season participation,
// notifications). Deleting the profile row alone would leave a login behind
// with nothing attached, so the removal has to happen in the auth schema, which
// needs the service role, which must never reach the client. Hence a function.
//
// Flow:
//   1. Verify the caller's JWT.
//   2. Require an approved, unsuspended account holding `employees.delete`
//      (admins always hold it).
//   3. Refuse the three deletions that are mistakes rather than decisions:
//      yourself, another admin, and an id that does not exist.
//   4. Delete the auth user.
//
// Deploy:  supabase functions deploy admin-delete-user

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });

  try {
    // 1. Identify the caller from their bearer token.
    const authHeader = req.headers.get('Authorization') ?? '';
    const caller = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await caller.auth.getUser();
    const callerId = userData?.user?.id;
    if (!callerId) return json({ error: 'unauthorized' }, 401);

    const admin = createClient(url, serviceKey);

    // 2. May the caller delete anyone at all?
    //
    // Read through the service role rather than as the caller: the answer must
    // not depend on what row-level security lets them see of the permission
    // tables. An approved, unsuspended admin always may; anyone else needs
    // `employees.delete` granted explicitly.
    const { data: me } = await admin
      .from('profiles')
      .select('is_admin, account_status, is_suspended, first_name, father_name, surname')
      .eq('id', callerId)
      .maybeSingle();
    const inGoodStanding =
      me?.account_status === 'approved' && me?.is_suspended !== true;
    let allowed = inGoodStanding && me?.is_admin === true;
    if (inGoodStanding && !allowed) {
      const { data: granted } = await admin
        .from('user_permissions')
        .select('permissions!inner(code)')
        .eq('user_id', callerId)
        .eq('permissions.code', 'employees.delete');
      allowed = (granted?.length ?? 0) > 0;
    }
    if (!allowed) return json({ error: 'forbidden' }, 403);

    // 3. Which account?
    const body = await req.json().catch(() => null);
    const targetId = body?.id;
    if (typeof targetId !== 'string' || !targetId) {
      return json({ error: 'id is required' }, 400);
    }
    if (targetId === callerId) {
      return json({ error: 'cannot_delete_self' }, 400);
    }

    const { data: target } = await admin
      .from('profiles')
      .select('id, is_admin, first_name, father_name, surname, email')
      .eq('id', targetId)
      .maybeSingle();
    if (!target) return json({ error: 'not_found' }, 404);
    // An administrator is removed by demoting them first. Otherwise whoever
    // holds `employees.delete` can remove the people who granted it.
    if (target.is_admin === true) {
      return json({ error: 'cannot_delete_admin' }, 400);
    }

    // 4. Delete. The profile, and everything referencing it, cascades.
    const { error: delErr } = await admin.auth.admin.deleteUser(targetId);
    if (delErr) return json({ error: delErr.message }, 400);

    // The cascade runs under the service role, which the audit trigger records
    // as nobody. This is the line that names the hand — written here,
    // best-effort: the log must never undo the act it describes.
    try {
      const name = (p: Record<string, unknown> | null) =>
        [p?.first_name, p?.father_name, p?.surname]
          .filter(Boolean)
          .join(' ') || null;
      await admin.from('audit_log').insert({
        actor_id: callerId,
        actor_name: name(me),
        action: 'delete',
        table_name: 'auth',
        record_id: targetId,
        record_label: name(target) ?? target.email,
        old_data: { op: 'delete_user', email: target.email },
      });
    } catch (_) {
      // Logged nowhere better; the deletion itself succeeded.
    }

    return json({ id: targetId });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
