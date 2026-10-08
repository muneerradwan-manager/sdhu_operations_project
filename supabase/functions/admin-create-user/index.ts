// Edge Function: admin-create-user
//
// Lets an authenticated ADMIN create a new account (auth user + profile) with
// an email + password, without exposing the service-role key to the app.
//
// Flow:
//   1. Verify the caller's JWT and that their profile is an approved admin.
//   2. Use the service role to create the auth user (email auto-confirmed).
//   3. Fill the new profile row (created by the on_auth_user_created trigger)
//      with the provided details and set account_status = 'approved'.
//
// Deploy:  supabase functions deploy admin-create-user
// Secrets are provided automatically: SUPABASE_URL, SUPABASE_ANON_KEY,
//          SUPABASE_SERVICE_ROLE_KEY.
//
// Call from the app:
//   supabase.functions.invoke('admin-create-user', body: {...})

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

    // 2. Ensure the caller is an approved, non-suspended admin.
    const { data: callerProfile } = await admin
      .from('profiles')
      .select('is_admin, account_status, is_suspended, first_name, father_name, surname')
      .eq('id', callerId)
      .single();
    const isAdmin =
      callerProfile?.is_admin === true &&
      callerProfile?.account_status === 'approved' &&
      callerProfile?.is_suspended !== true;
    if (!isAdmin) return json({ error: 'forbidden' }, 403);

    // 3. Read the payload.
    const body = await req.json();
    const {
      email,
      password,
      first_name,
      father_name,
      surname,
      gender,
      mission_type_id,
      job_title_id,
      phone_sy,
      phone_sa,
      date_of_birth,
      is_external,
      external_organization,
    } = body ?? {};

    if (!email || !password) {
      return json({ error: 'email and password are required' }, 400);
    }

    // 4. Create the auth user (email pre-confirmed).
    const { data: created, error: createErr } =
      await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
    if (createErr || !created?.user) {
      return json({ error: createErr?.message ?? 'create failed' }, 400);
    }
    const newId = created.user.id;

    // 5. Fill the profile (row auto-created by the signup trigger).
    const { error: updateErr } = await admin
      .from('profiles')
      .update({
        first_name,
        father_name,
        surname,
        gender,
        mission_type_id,
        job_title_id,
        phone_sy,
        phone_sa,
        date_of_birth,
        is_external: is_external ?? false,
        external_organization: is_external ? external_organization : null,
        account_status: 'approved',
      })
      .eq('id', newId);
    if (updateErr) return json({ error: updateErr.message }, 400);

    // Creation ran under the service role, which the audit trigger records as
    // nobody. This is the line that names the admin who created the account.
    // Best-effort: the log must never undo the act it describes.
    try {
      const callerName =
        [
          callerProfile?.first_name,
          callerProfile?.father_name,
          callerProfile?.surname,
        ]
          .filter(Boolean)
          .join(' ') || null;
      const newName =
        [first_name, father_name, surname].filter(Boolean).join(' ') || null;
      await admin.from('audit_log').insert({
        actor_id: callerId,
        actor_name: callerName,
        action: 'insert',
        table_name: 'auth',
        record_id: newId,
        record_label: newName ?? email,
        new_data: { op: 'create_user', email },
      });
    } catch (_) {
      // Logged nowhere better; the account itself was created.
    }

    return json({ id: newId });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
