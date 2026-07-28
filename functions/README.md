# Firebase Cloud Functions - OpenAI Secure Proxy

This directory contains Firebase Cloud Functions that act as a secure proxy for OpenAI API calls, ensuring your API key is never exposed in client code or version control.

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

### 5. Update Your Flutter App Configuration

Edit `lib/services/api_config_secure.dart`:

```dart
// Change this line:
static const String baseUrl = 'https://api.openai.com/v1';

// To your Cloud Function URL:
static const String baseUrl = 'https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/openaiProxy';
```

**Also remove the hardcoded API key** from the same file:

```dart
// Remove or comment out:
static const String _defaultApiKey = 'sk-proj-...';
```

### 6. Update CORS Settings (Production)

In `functions/index.js`, update the `allowedOrigins` array with your actual app domains:

```javascript
const allowedOrigins = [
  'http://localhost:3000',  // Development
  'https://your-app.web.app',  // Your Firebase hosting domain
  'https://your-custom-domain.com'  // Your custom domain if any
];
```

## 🔄 How It Works

1. **Client Request**: Your Flutter app sends OpenAI requests to your Cloud Function
2. **Authentication** (optional): The function verifies the user's Firebase Auth token
3. **Key Injection**: The function adds your secure API key from Firebase secrets
4. **Proxy**: The function forwards the request to OpenAI
5. **Response**: OpenAI's response is returned to your Flutter app

```
Flutter App → Cloud Function → OpenAI API
            ↑ (API key added here, never exposed to client)
```

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

Your OpenAI API costs remain the same.

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
