// Edge Function: admin-set-password
//
// Sets a new password on someone else's account — the reset an administration
// performs when an employee is locked out and there is no mail to send a link
// to. The password lives in the auth schema, so writing it needs the service
// role, which must never reach the client. Hence a function.
//
// Flow:
//   1. Verify the caller's JWT.
//   2. Require an approved, unsuspended account holding `employees.password`
//      (admins always hold it).
//   3. Refuse an administrator's account to anyone who is not an administrator.
//   4. Write the password.
//
// Deploy:  supabase functions deploy admin-set-password

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Matches what the app asks of a new account, so a reset cannot leave someone
// with a password they would not have been allowed to choose.
const MIN_PASSWORD_LENGTH = 8;

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

    // 2. May the caller reset anyone's password at all?
    //
    // Read through the service role rather than as the caller: the answer must
    // not depend on what row-level security lets them see of the permission
    // tables. An approved, unsuspended admin always may; anyone else needs
    // `employees.password` granted explicitly.
    const { data: me } = await admin
      .from('profiles')
      .select('is_admin, account_status, is_suspended, first_name, father_name, surname')
      .eq('id', callerId)
      .maybeSingle();
    const inGoodStanding =
      me?.account_status === 'approved' && me?.is_suspended !== true;
    const callerIsAdmin = inGoodStanding && me?.is_admin === true;
    let allowed = callerIsAdmin;
    if (inGoodStanding && !allowed) {
      const { data: granted } = await admin
        .from('user_permissions')
        .select('permissions!inner(code)')
        .eq('user_id', callerId)
        .eq('permissions.code', 'employees.password');
      allowed = (granted?.length ?? 0) > 0;
    }
    if (!allowed) return json({ error: 'forbidden' }, 403);

    // 3. Whose account, and to what?
    const body = await req.json().catch(() => null);
    const targetId = body?.id;
    const password = body?.password;
    if (typeof targetId !== 'string' || !targetId) {
      return json({ error: 'id is required' }, 400);
    }
    if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) {
      return json({ error: 'password_too_short' }, 400);
    }

    const { data: target } = await admin
      .from('profiles')
      .select('id, is_admin, first_name, father_name, surname, email')
      .eq('id', targetId)
      .maybeSingle();
    if (!target) return json({ error: 'not_found' }, 404);
    // An administrator's password is an administrator's business. Otherwise
    // `employees.password` is a way into the account that granted it: reset the
    // admin's password, sign in as him, and the grant no longer bounds anything.
    if (target.is_admin === true && !callerIsAdmin) {
      return json({ error: 'cannot_set_admin_password' }, 403);
    }

    // 4. Write it.
    const { error: updateErr } = await admin.auth.admin.updateUserById(
      targetId,
      { password },
    );
    if (updateErr) return json({ error: updateErr.message }, 400);

    // The password lives in the auth schema, out of the audit trigger's
    // reach. The FACT of the reset is recorded — never the password.
    // Best-effort: the log must never undo the act it describes.
    try {
      const name = (p: Record<string, unknown> | null) =>
        [p?.first_name, p?.father_name, p?.surname]
          .filter(Boolean)
          .join(' ') || null;
      await admin.from('audit_log').insert({
        actor_id: callerId,
        actor_name: name(me),
        action: 'update',
        table_name: 'auth',
        record_id: targetId,
        record_label: name(target) ?? target.email,
        new_data: { op: 'set_password' },
      });
    } catch (_) {
      // Logged nowhere better; the reset itself succeeded.
    }

    return json({ id: targetId });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
