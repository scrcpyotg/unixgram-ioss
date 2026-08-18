import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CLIENT_ID = "jG9yuXJwXZh9XweetqXH6S71dCTEGpR2";
const REDIRECT_URI = "unixgramfork://soundcloud/callback";
const TOKEN_URL = "https://secure.soundcloud.com/oauth/token";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, authorization, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

async function soundCloudToken(params: URLSearchParams, clientSecret: string): Promise<Response> {
  params.set("client_id", CLIENT_ID);
  params.set("client_secret", clientSecret);

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      "accept": "application/json; charset=utf-8",
      "content-type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  const text = await response.text();
  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    payload = { error: "soundcloud_invalid_response", message: text.slice(0, 500) };
  }

  return json(payload, response.status);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const clientSecret = Deno.env.get("SOUNDCLOUD_CLIENT_SECRET");
  if (!clientSecret) {
    return json({ error: "server_misconfigured", message: "SOUNDCLOUD_CLIENT_SECRET is not set" }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const action = String(body.action ?? "");

  if (action === "exchange") {
    const code = String(body.code ?? "");
    const verifier = String(body.code_verifier ?? "");

    if (!code || code.length > 4096 || verifier.length < 43 || verifier.length > 128) {
      return json({ error: "invalid_exchange_payload" }, 400);
    }

    const params = new URLSearchParams({
      grant_type: "authorization_code",
      redirect_uri: REDIRECT_URI,
      code,
      code_verifier: verifier,
    });

    return await soundCloudToken(params, clientSecret);
  }

  if (action === "refresh") {
    const refreshToken = String(body.refresh_token ?? "");
    if (!refreshToken || refreshToken.length > 4096) {
      return json({ error: "invalid_refresh_payload" }, 400);
    }

    const params = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    });

    return await soundCloudToken(params, clientSecret);
  }

  return json({ error: "unknown_action" }, 400);
});
