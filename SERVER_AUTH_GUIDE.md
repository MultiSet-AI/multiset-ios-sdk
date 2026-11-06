# Authenticating Through Your Own Server

The Quick Start gives the SDK your `clientId` and `clientSecret`. Both then ship inside your app,
where anyone who unpacks it can read the secret. This guide moves the secret to your server:
your server gets MultiSet access tokens, your app fetches them from your own API, and the SDK
sends them on every MultiSet request.

Requires MultiSet iOS SDK 2.2.0 or later.

## How it works

```
Your app ──── your sign-in ───► Your API ──── client ID + secret ───► MultiSet  POST /v1/m2m/token
Your app ◄────── token ──────── Your API ◄──── {token, expiresOn} ────────────┘

MultiSet SDK ──── Authorization: Bearer <token> ───► MultiSet API   (every request)
```

You give the SDK a **token provider**: a function that returns a token. The SDK calls it when it
starts, shortly before the current token expires, and when MultiSet refuses a token. How the
function gets the token is up to you: any URL, method, headers, response format or networking
library.

## 1. Server: hand out tokens

Your server requests a token from MultiSet with your client ID and secret:

```bash
curl -X POST https://api.multiset.ai/v1/m2m/token -u "$MULTISET_CLIENT_ID:$MULTISET_CLIENT_SECRET"
# {"token": "<JWT>", "expiresOn": "2026-11-03T11:36:01.356Z"}
```

Tokens currently last 30 minutes. Expose an endpoint that hands one to your signed-in users. A
minimal example in Node.js 18+ with Express:

```js
const express = require("express");

const app = express();
app.use(express.json());

const basicAuth = Buffer.from(
  `${process.env.MULTISET_CLIENT_ID}:${process.env.MULTISET_CLIENT_SECRET}`
).toString("base64");
const FIVE_MINUTES = 5 * 60 * 1000;
let cached = null; // { token, expiresOn }

async function newMultiSetToken() {
  const response = await fetch("https://api.multiset.ai/v1/m2m/token", {
    method: "POST",
    headers: { Authorization: `Basic ${basicAuth}` },
  });
  if (!response.ok) throw new Error(`MultiSet token request failed: HTTP ${response.status}`);
  cached = await response.json();
  return cached;
}

// requireSignedInUser is your own sign-in middleware.
app.post("/multiset/token", requireSignedInUser, async (req, res) => {
  try {
    const stillGood = cached && Date.parse(cached.expiresOn) - Date.now() > FIVE_MINUTES;
    res.json(req.body?.forceNew || !stillGood ? await newMultiSetToken() : cached);
  } catch {
    res.status(502).json({ error: "MultiSet token unavailable" });
  }
});
```

Rules for the endpoint:

- **Keep the secret on the server**, in an environment variable or a secret manager. Never send
  it to the app.
- **Require your own sign-in, over HTTPS.** Whoever holds a token can call the MultiSet API as
  your account until it expires.
- **Caching is fine.** Hand out a new token once the cached one has less than 5 minutes left,
  and always a new one when the app asks after a refusal (`forceNew` above).
- **Use the app's environment.** Request tokens from the host that the app's
  `MultiSetConfig.baseURL` points at. That is `https://api.multiset.ai` unless you changed it.

## 2. App: give the SDK a token provider

Remove `clientId` and `clientSecret` from the app and pass `.tokenProvider` instead:

```swift
import MultiSetSDK

let tokenProvider = ClosureTokenProvider { reason in
    var request = URLRequest(url: URL(string: "https://api.example.com/multiset/token")!,
                             timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("Bearer \(MyAppSession.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["forceNew": reason == .rejected])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    struct TokenResponse: Decodable { let token: String }
    return try JSONDecoder().decode(TokenResponse.self, from: data).token
}

let config = MultiSetConfig(credentials: .tokenProvider(tokenProvider), mapCode: "YOUR_MAP_CODE")
MultiSet.shared.initialize(config: config, callback: self)
```

`MyAppSession.accessToken` stands for however your app proves its user to your API. You can
also conform a type of your own to `MultiSetTokenProvider` instead of using
`ClosureTokenProvider`.

The SDK passes a reason with each call:

| Reason | When the SDK asks | What to return |
|---|---|---|
| `.initial` | `initialize(config:callback:)` | A valid token |
| `.expiring` | The first request in the last 5 minutes of the token's life | A valid token; a cached one is fine |
| `.rejected` | MultiSet refused the current token with HTTP 401 | A newly issued token, not a cached one |

- **Return only the token string.** The expiry is inside the token (the JWT's `exp` claim) and
  the SDK reads it from there. Your API may return `expiresOn` too; the app doesn't need it.
- A request refused with a 401 is retried once with the new token.
- Requests made at the same time share one call to your provider.
- The provider is called on the main actor, one call at a time. Await your network request
  instead of blocking. The SDK does not time out your call, so give your request a timeout.
  `MultiSet.shared.release()` cancels a call in flight.

## 3. Handle failures

- **At startup:** if the provider throws or returns an empty string,
  `onAuthenticationFailure(error:)` receives `"Token provider failed: …"`. A second `initialize`
  is ignored while the SDK is initialized, so to retry, call `MultiSet.shared.release()` and then
  `initialize(config:callback:)` again.
- **Later:** a failed renewal fails only the request that needed the new token. The next request
  asks your provider again.

## Checklist

- [ ] `clientId` and `clientSecret` are gone from the app, its configuration and its repository
- [ ] The token endpoint requires your sign-in and uses HTTPS
- [ ] `.rejected` gets a newly issued token
- [ ] The provider's request has a timeout
- [ ] A failed sign-in can be retried with `release()` followed by `initialize(config:callback:)`

## Try it in the demo app

Set `SDKConfig.tokenServerURL` to an endpoint that answers a GET with `{"token": "<JWT>"}`. The
demo's `TokenServerProvider` adds `?reason=initial`, `expiring` or `rejected` to the URL, and the
demo then never uses its `clientId` or `clientSecret`.
