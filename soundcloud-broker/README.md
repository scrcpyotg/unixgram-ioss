# Unixgram iOS — SoundCloud OAuth broker

The iOS app must never contain `SOUNDCLOUD_CLIENT_SECRET`.

This tiny Edge Function only does two things:

1. Exchanges the authorization `code` + PKCE `code_verifier` for a SoundCloud token.
2. Rotates SoundCloud's single-use `refresh_token`.

It does **not** store Unixgram passwords, SoundCloud passwords, or user tokens.

## Supabase deployment

Create/use a Supabase project that you are comfortable using for Unixgram iOS.

Deploy `supabase/functions/soundcloud-oauth` as a public Edge Function (`verify_jwt = false`), because SoundCloud OAuth happens before the app has any Supabase user JWT.

Set one server-side secret:

```bash
supabase secrets set SOUNDCLOUD_CLIENT_SECRET='YOUR_SOUNDLOUD_CLIENT_SECRET' --project-ref YOUR_PROJECT_REF
```

Deploy:

```bash
supabase functions deploy soundcloud-oauth --project-ref YOUR_PROJECT_REF --no-verify-jwt
```

The resulting URL is:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/soundcloud-oauth
```

In the Unixgram SoundCloud screen tap **Войти**. On the first run it will ask for this HTTPS broker URL and store only the URL in UserDefaults.

`Client ID` is public and already included in the iOS source. `Client Secret` belongs only in Supabase secrets.

## SoundCloud application

Redirect URI must be exactly:

```text
unixgramfork://soundcloud/callback
```

The iOS flow uses OAuth 2.1 Authorization Code + PKCE. Access tokens are stored in iOS Keychain. The refresh token is replaced after every refresh.
