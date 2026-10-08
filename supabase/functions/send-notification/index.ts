// Edge Function: send-notification
//
// Pushes an already-stored notification to its recipients' registered devices
// via FCM HTTP v1. The inbox row is the source of truth and is written first;
// this function is push-only and best-effort. A failed push never loses a
// message — it only means the phone finds out on next open.
//
// **Since 0107 the database is the normal caller.** A trigger on `notifications`
// fires once per INSERT statement and posts one batch per `group_id`, which is
// what makes the nine server-side writers — incidents, escalation, task
// assignment, complaints, evaluations, postings — actually reach a phone. The
// client no longer pushes at all: it writes the row and the trigger does the
// rest. Two callers pushing the same row was the alternative, and a duplicate
// alarm at 3am is its own kind of failure.
//
// Two ways in, and they authorise differently because they know different things:
//
//   * **A signed-in user.** Must be approved, not suspended, and hold the grant
//     matching the send's shape — `notifications.send` for people,
//     `notifications.broadcast_module` for a file topic,
//     `notifications.broadcast_all` for the everyone topic. Unchanged.
//
//   * **The database**, bearing the service_role key from Vault. No permission
//     check, deliberately: the rows already exist, and every one of them was
//     written by an RPC or policy that had already decided who may receive it.
//     Re-deciding here would mean re-implementing nine authorisation rules in
//     TypeScript, where they would drift. The row IS the authorisation.
//
// Three shapes of target:
//
//   { recipient_id }    — one person, fanned out over their devices here.
//   { recipient_ids }   — many people (a server batch), same fan-out.
//   { topic }           — everyone subscribed, fanned out by Google.
//
// Secrets required (set once):
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat firebase/hajjoperations-firebase-adminsdk-*.json)"
//
// Deploy: supabase functions deploy send-notification
//
// The JWT gate is OFF for this function (supabase/config.toml). It has to be:
// a Supabase secret key is not a JWT, so the gateway would reject the trigger's
// call before this file could look at it. Nothing is opened by that — the
// checks below are the gate, and they always were.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function b64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlStr(str: string): string {
  return b64url(new TextEncoder().encode(str));
}

function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der;
}

async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(claim))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  });
  const j = await res.json();
  if (!j.access_token) throw new Error('token exchange failed: ' + JSON.stringify(j));
  return j.access_token;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const saRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });

  try {
    // Three shapes of target. See the header for why there are three.
    //
    // `data` is what the notification is ABOUT, and it is the only reason a tap
    // on the phone's own tray can go anywhere. Without it the push carries a
    // sentence and nothing else: the app opens where it was left, and "تم
    // إسنادك إلى ملف تشغيلي" leads nowhere.
    const {
      recipient_id,
      recipient_ids,
      topic,
      title,
      body,
      data,
    } = (await req.json()) ?? {};

    // One list, however the caller spelled it. Duplicates collapse: a batch
    // that named somebody twice must not ring their phone twice.
    const people: string[] = [
      ...new Set(
        [
          ...(Array.isArray(recipient_ids) ? recipient_ids : []),
          ...(recipient_id ? [recipient_id] : []),
        ].filter((id) => typeof id === 'string' && id.length > 0),
      ),
    ];

    if (!title || (people.length === 0 && !topic)) {
      return json(
        { error: 'title and one of recipient_id / recipient_ids / topic are required' },
        400,
      );
    }

    const admin = createClient(url, serviceKey);

    // Is this the database calling? Compared against the key this function was
    // given, so the claim is only as good as the secret itself — and that
    // secret lives in Vault, reachable only by `security definer` code owned by
    // the database. The length floor stops the degenerate case where the env
    // var is unset and both sides are the empty string.
    const bearer = (req.headers.get('Authorization') ?? '').replace(
      /^Bearer\s+/i,
      '',
    );
    const fromDatabase = serviceKey.length > 20 && bearer === serviceKey;

    // A user, then, and the full check they always got. Skipped for the
    // database not out of trust in the network but because the rows it is
    // announcing already exist: each was written by an RPC or a policy that
    // decided who may receive it. Deciding again here would mean a second copy
    // of nine authorisation rules, in another language, free to drift.
    if (!fromDatabase) {
      const caller = createClient(url, anonKey, {
        global: {
          headers: { Authorization: req.headers.get('Authorization') ?? '' },
        },
      });
      const { data: u } = await caller.auth.getUser();
      const callerId = u?.user?.id;
      if (!callerId) {
        // Two very different failures used to come out of here wearing the same
        // word, and telling them apart cost a deploy-and-retry cycle: a phone
        // with no session, and the DATABASE presenting a key that does not
        // match this function's own. The second is the one that happens while
        // setting the trigger up, and "unauthorized" is no help at all for it —
        // the caller is the database, it has a key, and it believes it is
        // authorised.
        //
        // A JWT carries two dots; an API key carries none. That is enough to
        // say which of the two this was, and to say it without ever echoing any
        // part of the key back.
        const looksLikeApiKey = bearer.length > 20 && !bearer.includes('.');
        return json(
          {
            error: 'unauthorized',
            ...(looksLikeApiKey
              ? {
                  hint:
                    'bearer looks like an API key but does not match this ' +
                    "function's SUPABASE_SERVICE_ROLE_KEY — check that the " +
                    'push_service_key secret in Vault is the same value',
                }
              : {}),
          },
          401,
        );
      }

      // The shape of the send decides which permission it needs — the same
      // three the database enforces on the inbox rows (0073): one person, one
      // file's topic, or the everyone topic.
      const requiredCode = people.length > 0
        ? 'notifications.send'
        : topic === 'all'
          ? 'notifications.broadcast_all'
          : 'notifications.broadcast_module';

      // `has_permission` reads auth.uid(), which a service-role call does not
      // carry — so the grant is read directly, the way admin-delete-user does.
      const { data: prof } = await admin
        .from('profiles')
        .select('is_admin, account_status, is_suspended')
        .eq('id', callerId)
        .single();
      const active =
        prof?.account_status === 'approved' && !prof?.is_suspended;
      if (!active) return json({ error: 'forbidden' }, 403);
      if (!prof?.is_admin) {
        const { data: grant } = await admin
          .from('user_permissions')
          .select('permission_id, permissions!inner(code)')
          .eq('user_id', callerId)
          .eq('permissions.code', requiredCode)
          .maybeSingle();
        if (!grant) return json({ error: 'forbidden' }, 403);
      }
    }
    // A topic is never taken verbatim. This app has exactly two shapes of
    // topic — `all`, and `module_<uuid>` — and anything else is refused, so a
    // grant-holder cannot use this function to push to an arbitrary FCM topic
    // string. A module topic must also name a module that exists: the DB rule
    // (0073) is that `broadcast_module` may address any file, but it has to be
    // a file, not a guess.
    //
    // Note on confidentiality: FCM topic subscription is client-controlled, so
    // a topic push is a megaphone, not an envelope — anything secret belongs
    // in the RLS-guarded inbox row, not in the push's title or body.
    if (topic && topic !== 'all') {
      const m = /^module_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/.exec(
        topic,
      );
      if (!m) return json({ error: 'invalid topic' }, 400);
      const { data: module } = await admin
        .from('modules')
        .select('id')
        .eq('id', m[1])
        .maybeSingle();
      if (!module) return json({ error: 'unknown module' }, 400);
    }

    if (!saRaw) {
      // Push not configured — the in-app notification still exists.
      return json({ pushed: 0, note: 'FIREBASE_SERVICE_ACCOUNT not set' });
    }
    const sa = JSON.parse(saRaw);

    const accessToken = await getAccessToken(sa);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    // FCM will only carry strings here, and rejects the whole message if it is
    // handed anything else — so a nested value is dropped rather than allowed
    // to lose the notification it was riding on. Nothing this app targets with
    // is nested; if that changes, this is the line to widen.
    const payload = (() => {
      if (!data || typeof data !== 'object') return null;
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(data)) {
        if (v === null || v === undefined) continue;
        if (typeof v === 'object') continue;
        out[k] = String(v);
      }
      return Object.keys(out).length ? out : null;
    })();

    // An emergency must not arrive looking like a circular.
    //
    // Everything here is already `priority: high`, which is about DELIVERY —
    // whether Android wakes the app out of doze. It says nothing about how the
    // phone announces what arrived, and that is a separate setting: the channel.
    // A man with the notification shade full of routine postings will not
    // notice one more line, so 0088's alarms go to their own channel, which the
    // app registers with its own sound and can be left un-muted when the rest
    // are silenced.
    const urgent = payload?.type === 'incident';
    const channel = urgent ? 'incidents' : 'general';

    const send = async (target: Record<string, unknown>) => {
      const r = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            ...target,
            notification: { title, body: body ?? '' },
            ...(payload ? { data: payload } : {}),
            android: {
              priority: 'high',
              notification: {
                channel_id: channel,
                ...(urgent ? { default_sound: true, notification_priority: 'PRIORITY_MAX' } : {}),
              },
            },
          },
        }),
      });
      return r.ok;
    };

    if (topic) {
      const ok = await send({ topic });
      return json({ pushed: ok ? 1 : 0, topic });
    }

    // One query for the whole batch rather than one per person. A broadcast
    // that arrives here as a list — an incident going to everyone holding
    // `incidents.receive` — would otherwise open a round trip per recipient
    // before sending anything, which is exactly the shape 0041 removed.
    const { data: tokens } = await admin
      .from('device_tokens')
      .select('token')
      .in('user_id', people);
    if (!tokens || tokens.length === 0) return json({ pushed: 0, people: people.length });

    // Concurrently, and in bounded slices. Sequentially, an incident going to
    // forty phones is forty round trips end to end — and this is the one
    // message in the system where seconds are the entire point. The cap is
    // there because an unbounded fan-out of five hundred opens five hundred
    // sockets at once and FCM starts refusing them.
    const unique = [...new Set(tokens.map((t) => t.token as string))];
    let pushed = 0;
    for (let i = 0; i < unique.length; i += 25) {
      const results = await Promise.all(
        unique.slice(i, i + 25).map((token) => send({ token })),
      );
      pushed += results.filter(Boolean).length;
    }
    return json({ pushed, people: people.length, devices: unique.length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
