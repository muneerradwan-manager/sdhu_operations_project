// Edge Function: admin-set-email
//
// Sets a new email address on an account. The address is the login itself, so
// it lives in the auth schema and writing it needs the service role, which
// must never reach the client. Hence a function.
//
// Two doors in:
//   * One's own account: anyone approved and unsuspended. The auth-side
//     self-service flow (`auth.updateUser(email)`) mails confirmation links,
//     and this mission hands accounts out in person — nothing is mailed here,
//     the address just changes.
//   * Someone else's: `employees.email` (admins always hold it), and an
//     administrator's account only under an administrator's hand.
//
// Auth refuses a duplicate address by itself; that refusal comes back as
// `email_taken`. The profiles.email mirror follows via the
// on_auth_user_email_changed trigger (migration 0026).
//
// Deploy:  supabase functions deploy admin-set-email

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Matches the app-side Validators.isEmail: something@something.tld.
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

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

    // 2. Whose account, and to what?
    const body = await req.json().catch(() => null);
    const targetId = body?.id;
    const email =
      typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
    if (typeof targetId !== 'string' || !targetId) {
      return json({ error: 'id is required' }, 400);
    }
    if (!EMAIL_RE.test(email)) {
      return json({ error: 'email_invalid' }, 400);
    }

    // 3. May the caller change THIS account's email?
    //
    // Read through the service role rather than as the caller: the answer must
    // not depend on what row-level security lets them see of the permission
    // tables. Anyone approved and unsuspended may change their own; an admin
    // may change anyone's; anyone else needs `employees.email` granted
    // explicitly.
    const { data: me } = await admin
      .from('profiles')
      .select('is_admin, account_status, is_suspended, first_name, father_name, surname')
      .eq('id', callerId)
      .maybeSingle();
    const inGoodStanding =
      me?.account_status === 'approved' && me?.is_suspended !== true;
    const callerIsAdmin = inGoodStanding && me?.is_admin === true;
    let allowed =
      callerIsAdmin || (inGoodStanding && targetId === callerId);
    if (inGoodStanding && !allowed) {
      const { data: granted } = await admin
        .from('user_permissions')
        .select('permissions!inner(code)')
        .eq('user_id', callerId)
        .eq('permissions.code', 'employees.email');
      allowed = (granted?.length ?? 0) > 0;
    }
    if (!allowed) return json({ error: 'forbidden' }, 403);

    const { data: target } = await admin
      .from('profiles')
      .select('id, is_admin, first_name, father_name, surname, email')
      .eq('id', targetId)
      .maybeSingle();
    if (!target) return json({ error: 'not_found' }, 404);
    // An administrator's address is an administrator's business. Otherwise
    // `employees.email` is a way into the account that granted it: point the
    // admin's login at a mailbox you own, recover the password, and the grant
    // no longer bounds anything. (An admin changing their own passes: they ARE
    // callerIsAdmin.)
    if (target.is_admin === true && !callerIsAdmin) {
      return json({ error: 'cannot_set_admin_email' }, 403);
    }

    // 4. Write it, pre-confirmed — the administration vouches for the address
    // the way it does at creation; nothing is mailed to anybody.
    const { error: updateErr } = await admin.auth.admin.updateUserById(
      targetId,
      { email, email_confirm: true },
    );
    if (updateErr) {
      // The duplicate refusal must arrive as a NAME the app can translate, not
      // as whatever the AuthError happens to serialize to (observed: "{}").
      // GoTrue answers a taken address with 422 / code "email_exists"; match
      // on every signal it might carry.
      const err = updateErr as {
        code?: string;
        status?: number;
        message?: string;
      };
      const taken =
        err.code === 'email_exists' ||
        err.status === 422 ||
        /already.*registered/i.test(err.message ?? '');
      const label =
        err.message && err.message !== '{}'
          ? err.message
          : (err.code ?? 'update_failed');
      return json({ error: taken ? 'email_taken' : label }, 400);
    }

    // The address changed in the auth schema under the service role; the
    // profiles.email mirror will move under the same anonymous hand. This is
    // the line that names the caller and both addresses. Best-effort: the log
    // must never undo the act it describes.
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
        old_data: { op: 'set_email', email: target.email },
        new_data: { op: 'set_email', email },
      });
    } catch (_) {
      // Logged nowhere better; the change itself succeeded.
    }

    return json({ id: targetId, email });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
