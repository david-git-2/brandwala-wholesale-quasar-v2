import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from 'https://esm.sh/google-auth-library@9.15.1'

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
}

type DispatchPayload = {
  notification_id?: string
  user_id?: string
}

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
  })
}

function parseServiceAccount(raw: string | undefined): ServiceAccount | null {
  if (!raw) return null
  try {
    const parsed = JSON.parse(raw) as ServiceAccount
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      return null
    }
    return parsed
  } catch {
    return null
  }
}

async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const client = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })

  const token = await client.getAccessToken()
  if (!token?.token) {
    throw new Error('Failed to obtain FCM access token')
  }

  return token.token
}

async function sendFcmMessage(params: {
  accessToken: string
  projectId: string
  token: string
  title: string
  body: string | null
  linkPath: string | null
}) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${params.projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${params.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: params.token,
          notification: {
            title: params.title,
            body: params.body ?? undefined,
          },
          webpush: params.linkPath
            ? {
                fcmOptions: {
                  link: params.linkPath,
                },
              }
            : undefined,
          data: {
            link_path: params.linkPath ?? '',
          },
        },
      }),
    },
  )

  const payload = await response.json().catch(() => ({}))
  return { ok: response.ok, status: response.status, payload }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const firebaseServiceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? ''

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ success: false, error: 'Missing Supabase env' }, 500)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ success: false, error: 'Unauthorized' }, 401)
  }

  let payload: DispatchPayload
  try {
    payload = (await req.json()) as DispatchPayload
  } catch {
    return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400)
  }

  const notificationId = payload.notification_id
  const userId = payload.user_id

  if (!notificationId || !userId) {
    return jsonResponse({ success: false, error: 'notification_id and user_id are required' }, 400)
  }

  const serviceAccount = parseServiceAccount(firebaseServiceAccountRaw)
  if (!serviceAccount) {
    return jsonResponse({ success: false, error: 'FIREBASE_SERVICE_ACCOUNT not configured' }, 503)
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)

  const { data: notification, error: notificationError } = await supabase
    .from('notifications')
    .select('id, title, body, link_path')
    .eq('id', notificationId)
    .maybeSingle()

  if (notificationError) {
    return jsonResponse({ success: false, error: notificationError.message }, 500)
  }

  if (!notification) {
    return jsonResponse({ success: false, error: 'Notification not found' }, 404)
  }

  const { data: preferences, error: preferencesError } = await supabase
    .from('user_notification_preferences')
    .select('channel_push')
    .eq('user_id', userId)
    .maybeSingle()

  if (preferencesError) {
    return jsonResponse({ success: false, error: preferencesError.message }, 500)
  }

  if (!preferences?.channel_push) {
    return jsonResponse({ success: true, skipped: true, reason: 'channel_push disabled' })
  }

  const { data: subscriptions, error: subscriptionsError } = await supabase
    .from('user_push_subscriptions')
    .select('id, fcm_token')
    .eq('user_id', userId)

  if (subscriptionsError) {
    return jsonResponse({ success: false, error: subscriptionsError.message }, 500)
  }

  if (!subscriptions?.length) {
    return jsonResponse({ success: true, skipped: true, reason: 'no push subscriptions' })
  }

  // Telegram branch deferred to Phase 3.

  let accessToken: string
  try {
    accessToken = await getFcmAccessToken(serviceAccount)
  } catch (error) {
    const message = error instanceof Error ? error.message : 'FCM auth failed'
    return jsonResponse({ success: false, error: message }, 500)
  }

  const results: Array<{ token: string; ok: boolean; status?: number; error?: string }> = []

  for (const subscription of subscriptions) {
    const sendResult = await sendFcmMessage({
      accessToken,
      projectId: serviceAccount.project_id,
      token: subscription.fcm_token,
      title: notification.title,
      body: notification.body,
      linkPath: notification.link_path,
    })

    if (sendResult.ok) {
      await supabase.from('notification_delivery_log').insert({
        notification_id: notificationId,
        user_id: userId,
        channel: 'push',
        status: 'sent',
      })
      await supabase
        .from('user_push_subscriptions')
        .update({ last_used_at: new Date().toISOString() })
        .eq('id', subscription.id)
      results.push({ token: subscription.fcm_token, ok: true })
      continue
    }

    const errorMessage =
      typeof sendResult.payload?.error?.message === 'string'
        ? sendResult.payload.error.message
        : JSON.stringify(sendResult.payload)

    await supabase.from('notification_delivery_log').insert({
      notification_id: notificationId,
      user_id: userId,
      channel: 'push',
      status: 'failed',
      error_message: errorMessage,
    })

    const isUnregistered =
      sendResult.status === 404 ||
      String(errorMessage).includes('UNREGISTERED') ||
      String(errorMessage).includes('registration-token-not-registered')

    if (isUnregistered) {
      await supabase
        .from('user_push_subscriptions')
        .delete()
        .eq('id', subscription.id)
    }

    results.push({ token: subscription.fcm_token, ok: false, status: sendResult.status, error: errorMessage })
  }

  const sentCount = results.filter((item) => item.ok).length

  if (sentCount === 0) {
    const { count } = await supabase
      .from('user_push_subscriptions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)

    if ((count ?? 0) === 0) {
      await supabase
        .from('user_notification_preferences')
        .update({ channel_push: false, updated_at: new Date().toISOString() })
        .eq('user_id', userId)
    }
  }

  return jsonResponse({
    success: sentCount > 0,
    sent_count: sentCount,
    attempted_count: results.length,
    results,
  })
})
