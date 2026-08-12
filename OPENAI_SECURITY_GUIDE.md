# OpenAI API Key Security Implementation Guide

## 🎯 Overview

This guide explains how to securely use OpenAI API in your app by moving the API key from client code to a Firebase Cloud Function. This prevents the key from being exposed in your source code, even when pushed to GitHub.

## 🔑 GitHub Secret Name

The canonical OpenAI API key GitHub secret is named **`API_Key`** on the `Ndu-Project-LLC/NDU-Project` repository. All CI/CD workflows in `.github/workflows/` read it via `${{ secrets.API_Key }}` and inject it at build time through `--dart-define`:

- `--dart-define=OPENAI_API_KEY` — read by `lib/services/api_config_secure.dart`
- `--dart-define=OPENAI_PROXY_API_KEY` — read by `lib/openai/openai_config.dart`

A fallback to the legacy `OPENAI_PROXY_API_KEY` secret is kept for safety during the secret-name migration. To rotate the key, update the `API_Key` GitHub secret at:
> **GitHub → NDU-Project-LLC/NDU-Project → Settings → Secrets and variables → Actions → `API_Key`**

The key then takes effect on the next workflow run (push to `staging` triggers `deploy-staging.yml`, or run `Promote Staging → Production` for `nduproject.com`).

> ⚠️ **Note**: The Cloud Function proxy (`functions/index.js`) uses Firebase secrets (`firebase functions:secrets:set OPENAI_API_KEY`), which is a **separate** secret store from GitHub. The Flutter client never sees the server-side key — it only sends requests to the proxy URL.

## ⚠️ Current Security Issue

**Problem**: Your OpenAI API key is currently hardcoded in `lib/services/api_config_secure.dart`:
```dart
static const String _defaultApiKey = 'sk-proj-6Qb-...';
```

**Risk**: 
- Anyone with access to your code can see and use your API key
- If pushed to GitHub (even private repos), the key is exposed
- GitHub automatically scans for API keys and may flag/revoke them
- Malicious actors could rack up charges on your OpenAI account

## ✅ Solution: Firebase Cloud Function Proxy

Your API key is stored securely in Firebase Cloud's secret manager and only accessible by your Cloud Function. Your Flutter app never sees the actual key.

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│             │         │  Cloud Function  │         │   OpenAI    │
│ Flutter App │────────▶│  (Has API Key)   │────────▶│     API     │
│ (No API Key)│         │   Secure Proxy   │         │             │
└─────────────┘         └──────────────────┘         └─────────────┘
```

## 🚀 Quick Start Deployment

### Step 1: Install Dependencies

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Install Cloud Function dependencies
cd functions
npm install
cd ..
```

### Step 2: Set Your API Key as a Firebase Secret

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

When prompted, paste your API key (obtain from https://platform.openai.com/api-keys).

### Step 3: Deploy the Cloud Function

```bash
firebase deploy --only functions
```

**Expected Output:**
```
✔  functions[openaiProxy(us-central1)] Successful create operation.
Function URL: https://us-central1-YOUR-PROJECT.cloudfunctions.net/openaiProxy
```

**⚠️ IMPORTANT**: Copy this Function URL! You'll need it in Step 4.

### Step 4: Update Your Flutter App

Edit `lib/services/api_config_secure.dart`:

**BEFORE:**
```dart
class SecureAPIConfig {
  static const String _defaultApiKey = 'sk-proj-6Qb-...';  // ❌ EXPOSED
  static String? _apiKey;
  static const String baseUrl = 'https://api.openai.com/v1';  // ❌ DIRECT
  static const String model = 'gpt-4o-mini';
```

**AFTER:**
```dart
class SecureAPIConfig {
  // No hardcoded API key - it's in Firebase secrets now! ✅
  static String? _apiKey;
  
  // Use Cloud Function URL instead of direct OpenAI API ✅
  static const String baseUrl = 'https://us-central1-YOUR-PROJECT.cloudfunctions.net/openaiProxy';
  static const String model = 'gpt-4o-mini';
```

### Step 5: Update CORS Configuration (Production)

Edit `functions/index.js` and add your app's domain:

```javascript
const allowedOrigins = [
  'http://localhost:3000',              // Development
  'https://YOUR-PROJECT.web.app',       // Firebase hosting
  'https://YOUR-PROJECT.firebaseapp.com' // Firebase hosting
];
```

Then redeploy:
```bash
firebase deploy --only functions
```

### Step 6: Test Your App

Your app should work exactly as before, but now the API key is secure!

## 🔍 Verification

### Check 1: API Key Not in Code
Search your codebase for "sk-proj-" or "sk-" and ensure no API keys are hardcoded.

### Check 2: Function is Working
Check Firebase Console > Functions > openaiProxy to see invocation logs.

### Check 3: Git Safety
Run `git grep "sk-proj"` - should return no results (or only in comments).

## 📊 How It Works Internally

### Client Request (Flutter)
```dart
// Your existing code doesn't change!
final response = await http.post(
  Uri.parse('${SecureAPIConfig.baseUrl}/chat/completions'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'model': 'gpt-4o-mini',
    'messages': [...]
  })
);
```

### Cloud Function Processing
```javascript
// Function receives request
// Adds API key from secure storage
// Forwards to OpenAI
// Returns response to app
```

### OpenAI Response
```
OpenAI sends response → Cloud Function → Flutter App
```

## 🛡️ Security Best Practices

### ✅ DO:
- Store API key in Firebase secrets
- Use Cloud Function as proxy
- Enable Firebase Auth verification (optional)
- Implement rate limiting per user
- Monitor function logs for suspicious activity
- Use environment-specific configurations

### ❌ DON'T:
- Hardcode API keys in source code
- Commit `.env` files to git
- Share API keys in chat/email
- Use the same key for dev and production
- Disable CORS protections

## 💰 Cost Analysis

### Firebase Cloud Functions
- **Free Tier**: 2 million invocations/month
- **Paid**: $0.40 per million invocations after free tier
- **Typical Usage**: ~50,000 AI requests/month = FREE

### OpenAI API
- Your existing OpenAI costs remain the same
- No additional charges for using Cloud Function proxy

### Total Additional Cost
- For most apps: **$0/month** (within free tier)
- High-traffic apps: ~$0.20-$2/month

## 🐛 Troubleshooting

### Issue: "OPENAI_API_KEY not configured"

**Solution:**
```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions
```

### Issue: CORS errors in browser

**Solution:** Add your domain to `allowedOrigins` in `functions/index.js`

### Issue: 401 Unauthorized from OpenAI

**Solution:** Verify your API key is correct:
```bash
firebase functions:secrets:access OPENAI_API_KEY
```

### Issue: Function timeout

**Solution:** Increase timeout in `functions/index.js`:
```javascript
.runWith({
  timeoutSeconds: 120,  // Increase from 60
  secrets: ['OPENAI_API_KEY']
})
```

### Issue: High costs

**Solution:** Implement rate limiting and caching in Cloud Function.

## 🔄 Updating the API Key

There are TWO places the OpenAI API key is stored, depending on which path you want to update:

### Path A — Client-side `--dart-define` (used by direct OpenAI calls)

Update the **`API_Key`** GitHub secret at:
> GitHub → NDU-Project-LLC/NDU-Project → Settings → Secrets and variables → Actions → `API_Key`

The new value takes effect on the next CI build (push to `staging` auto-triggers `deploy-staging.yml`; for `nduproject.com` run `Promote Staging → Production`). No code changes needed.

### Path B — Server-side Cloud Function proxy (recommended for production)

```bash
# Set new key
firebase functions:secrets:set OPENAI_API_KEY

# Redeploy
firebase deploy --only functions
```

The old key is automatically revoked.

## 📈 Monitoring and Logs

### View Function Logs
```bash
firebase functions:log
```

### Firebase Console
- Go to Firebase Console > Functions
- Click on `openaiProxy`
- View metrics: invocations, errors, execution time

### Set Up Alerts
Firebase Console > Functions > openaiProxy > Alerts
- Alert on error rate > 5%
- Alert on execution time > 30s

## 🔐 Advanced Security (Optional)

### Enable Firebase Authentication

Require users to be authenticated before making AI requests:

In `functions/index.js`, uncomment the auth verification code:
```javascript
const authHeader = req.headers.authorization;
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  res.status(401).json({ error: 'Unauthorized' });
  return;
}

const idToken = authHeader.split('Bearer ')[1];
const decodedToken = await admin.auth().verifyIdToken(idToken);
const userId = decodedToken.uid;
```

Then in your Flutter app, add auth token to requests:
```dart
final user = FirebaseAuth.instance.currentUser;
final idToken = await user?.getIdToken();

headers: {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $idToken',
}
```

### Implement Rate Limiting

Track requests per user in Firestore:

```javascript
// In Cloud Function
const userDoc = await admin.firestore()
  .collection('api_usage')
  .doc(userId)
  .get();

const usage = userDoc.data() || { count: 0, resetDate: new Date() };

// Check if limit exceeded
if (usage.count > 1000) {  // 1000 requests per day
  res.status(429).json({ error: 'Rate limit exceeded' });
  return;
}

// Increment counter
await admin.firestore()
  .collection('api_usage')
  .doc(userId)
  .set({ count: usage.count + 1, resetDate: usage.resetDate });
```

## ✅ Deployment Checklist

- [ ] Firebase CLI installed and logged in
- [ ] API key set in Firebase secrets: `firebase functions:secrets:set OPENAI_API_KEY`
- [ ] Cloud Function deployed: `firebase deploy --only functions`
- [ ] Function URL copied and saved
- [ ] `lib/services/api_config_secure.dart` updated with Function URL
- [ ] Hardcoded API key removed from code
- [ ] CORS origins updated with your domains
- [ ] Function tested and working
- [ ] Code committed to git (safely!)
- [ ] Production environment tested
- [ ] Monitoring and alerts configured

## 📚 Resources

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [Firebase Secrets Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [OpenAI API Best Practices](https://platform.openai.com/docs/guides/production-best-practices)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

## 🆘 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Firebase function logs: `firebase functions:log`
3. Check Firebase Console > Functions for error details
4. Ensure your Firebase project has billing enabled (required for Cloud Functions)

---

**Remember**: Never commit API keys to git, even in private repositories. Always use environment variables or secret management services like Firebase Secrets.
