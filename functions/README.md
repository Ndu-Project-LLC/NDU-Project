# Firebase Cloud Functions - Secure AI Proxy

This directory contains Firebase Cloud Functions that act as a secure proxy for the app's AI completions. Requests are served by a **self-hosted LLM** (see `../llm-server/`) at near-zero cost and only fall back to OpenAI when that server is unreachable. Credentials stay server-side and are never exposed in client code or version control.

## 🔐 Security Benefits

- **API Key Protection**: Your OpenAI API key is stored as a Firebase secret, never in code
- **No Client Exposure**: The key never leaves the server environment
- **GitHub Safe**: Even if you push code to GitHub, the key remains secure
- **Firebase Auth Integration**: Optional user authentication before making AI requests
- **Rate Limiting**: Configurable per-user rate limits to prevent abuse

## 📋 Setup Instructions

### 1. Install Firebase CLI (if not already installed)

```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Firebase Functions

```bash
cd functions
npm install
```

### 3. Set Your OpenAI API Key as a Secret

**IMPORTANT**: This stores your API key securely in Firebase, never in code:

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

When prompted, paste your OpenAI API key (never commit keys to source control).

### 4. Deploy the Cloud Function

```bash
firebase deploy --only functions
```

After deployment, you'll see your function URL:
```
https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/openaiProxy
```

### 5. Verify Your Flutter App Configuration

`lib/services/api_config_secure.dart` already points web, mobile, desktop,
staging, production, and admin builds to the deployed `openaiProxy`. Do not
add a client-side OpenAI key or a direct OpenAI URL.

### 6. Update CORS Settings (Production)

In `functions/index.js`, update the `allowedOrigins` array with your actual app domains:

```javascript
const allowedOrigins = [
  'http://localhost:3000',  // Development
  'https://your-app.web.app',  // Your Firebase hosting domain
  'https://your-custom-domain.com'  // Your custom domain if any
];
```

## 🤖 Self-hosted LLM routing (cost-free AI)

The `openaiProxy` function routes each completion through
`functions/llm-router.js`:

```
Flutter App → Cloud Function (openaiProxy)
            ├─→ Self-hosted LLM  (llm-server/ on the Oracle Always-Free VM) ← primary, ~$0
            └─→ OpenAI API       (only when the VM is unreachable)           ← fallback
```

Configure the self-hosted upstream:

1. Deploy the stack on your VM (see `../llm-server/README.md`) and note its
   public address, e.g. `http://203.0.113.10:8080`.
2. Add the non-secret URL to `functions/.env` (loaded at deploy time):
   ```
   LLM_SERVER_URL=http://203.0.113.10:8080
   LLM_MODEL_NAME=qwen2.5:7b-instruct
   ```
3. Store the gate token as a Firebase secret (paste at the hidden prompt):
   ```bash
   firebase functions:secrets:set LLM_SERVER_API_TOKEN
   ```
4. Redeploy:
   ```bash
   firebase deploy --only functions:openaiProxy
   ```

There is **no client change** — the app still calls the same Cloud Function
with the same OpenAI-format payloads. When `LLM_SERVER_URL` is unset, the
proxy behaves exactly as before (OpenAI only).

Environment variables (all optional):

| Variable | Purpose | Default |
| --- | --- | --- |
| `LLM_SERVER_URL` | Base URL of the self-hosted server (enables local routing) | *(unset — OpenAI only)* |
| `LLM_SERVER_API_TOKEN` | Bearer token required by the gate (Firebase secret) | *(none)* |
| `LLM_MODEL_NAME` | Model requested on the self-hosted server | `qwen2.5:7b-instruct` |
| `LLM_SERVER_TIMEOUT_MS` | Per-request timeout for the local server | `60000` |

## 🔄 How It Works

1. **Client Request**: Your Flutter app sends OpenAI-format requests to your Cloud Function
2. **Authentication**: The function verifies the user's Firebase Auth token
3. **Routing** (`llm-router.js`): The function tries the self-hosted LLM first and falls back to OpenAI only when it is unreachable
4. **Key Injection**: Credentials are added server-side from Firebase secrets
5. **Response**: The upstream's response is returned to your Flutter app

The local-LLM attempt is bounded by `LLM_SERVER_TIMEOUT_MS` (default `60000`)
and network failures (connection refused, DNS, timeout) are treated as a
failed attempt rather than an error — the request then falls back to OpenAI
so AI features stay available while the VM is down. The OpenAI fallback itself
is bounded to 55s so a hung upstream can never outlive the client's request
timeout.

## 🚀 Usage in Flutter App

No code changes needed! The app will automatically use the Cloud Function URL once you update `baseUrl` in `api_config_secure.dart`.

All existing OpenAI service calls will work exactly the same:
```dart
final suggestions = await OpenAiAutocompleteService.instance.fetchSuggestions(...);
final solutions = await OpenAiServiceSecure().generateSolutionsFromBusinessCase(...);
```

## 🛡️ Optional Security Enhancements

### Enable Authentication

Uncomment the auth verification code in `index.js`:

```javascript
const authHeader = req.headers.authorization;
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  res.status(401).json({ error: 'Unauthorized' });
  return;
}
const idToken = authHeader.split('Bearer ')[1];
const decodedToken = await admin.auth().verifyIdToken(idToken);
```

### Implement Rate Limiting

Track user requests in Firestore and block excessive usage:

```javascript
const userId = decodedToken.uid;
const userDoc = await admin.firestore()
  .collection('usage')
  .doc(userId)
  .get();

// Check and update request count
```

## 📊 Monitoring

View function logs:
```bash
firebase functions:log
```

View function usage in Firebase Console:
- Go to Firebase Console > Functions
- Monitor invocations, errors, and execution time

## 💰 Cost Considerations

Firebase Cloud Functions pricing:
- Free tier: 2 million invocations/month
- After free tier: $0.40 per million invocations

With the self-hosted LLM configured, **OpenAI API costs drop to ~$0** because
OpenAI is only called when the VM is down. The Oracle Always-Free VM that
runs the model has no monthly cost.

## 🧪 Tests

Router unit tests (no external services, `node` built-ins only):

```bash
cd functions
npm test
```

## 🔧 Troubleshooting

### "OPENAI_API_KEY not configured" error

```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions
```

### CORS errors

Update `allowedOrigins` in `index.js` with your app's domain.

### Function timeout

Increase timeout in `index.js`:
```javascript
.runWith({
  timeoutSeconds: 120,  // Increase from 60
  ...
})
```

## 📚 Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Secrets Management](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
