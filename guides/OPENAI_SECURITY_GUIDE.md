# OpenAI credential management

NDU uses one server-managed OpenAI credential for every KAZ AI feature.

## Architecture

```text
Flutter client -> Firebase openaiProxy -> OpenAI API
                                      ^
                                      |
                    Firebase secret OPENAI_API_KEY
```

The Flutter web, mobile, desktop, staging, production, and admin builds all
call the same proxy. They do not receive, store, display, or send an OpenAI API
key. The proxy refuses requests when its Firebase secret is unavailable; it
does not accept a client key as a fallback.

## Set or rotate the credential

From the repository root:

```bash
firebase functions:secrets:set OPENAI_API_KEY --project ndu-d3f60
firebase deploy --only functions:openaiProxy --project ndu-d3f60
```

Paste the credential only into the hidden Firebase CLI prompt. Do not put it
in a command-line argument, Dart define, `.env` file, GitHub Actions secret,
Firestore document, runtime JavaScript, issue, or chat.

Creating a new secret version does not update the running Cloud Function until
the function is redeployed.

## Verification

Confirm that no real OpenAI credential exists in tracked files:

```bash
git grep -n -P '(?<![A-Za-z])sk-(?:proj-)?[A-Za-z0-9_-]{30,}'
```

Prefer testing a KAZ AI feature and reviewing `firebase functions:log` over
printing the secret value in a terminal.

## Compromise response

If a credential is pasted into chat, committed, logged, or otherwise exposed:

1. Revoke it in the OpenAI Platform.
2. Create a replacement project key.
3. Set the replacement as the Firebase `OPENAI_API_KEY` secret.
4. Redeploy `functions:openaiProxy`.
5. Review usage and billing for unexpected activity.

Never rely on deleting the exposed text alone; rotation is required.
