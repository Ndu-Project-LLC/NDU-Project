# Setup Guide — Separate Staging Repo for staging.nduproject.com

This guide walks you through creating a **separate GitHub repository** that serves `staging.nduproject.com`, and wiring the main NDU-Project repo to auto-deploy to it whenever a staging build completes.

---

## Architecture

```
push to main (Ndu-Project-LLC/NDU-Project)
        │
        ▼
┌──────────────────────────────────┐
│ auto-deploy-staging.yml          │   ← existing workflow
│  · flutter build web             │
│  · push to gh-pages branch       │   ← legacy (kept for fallback)
└────────────┬─────────────────────┘
             │
             │ workflow_run: completed
             ▼
┌──────────────────────────────────┐
│ deploy-to-staging-repo.yml       │   ← NEW workflow (this PR)
│  · flutter build web             │
│  · force-push build/web          │
│    → Ndu-Project-LLC/ndu-staging │
│      :main                       │
└────────────┬─────────────────────┘
             │
             │ git push --force
             │ (using ACCESS_TOKEN)
             ▼
┌──────────────────────────────────┐
│ Ndu-Project-LLC/ndu-staging      │   ← NEW separate repo
│  · branch: main                  │
│  · GitHub Pages: enabled         │
│  · CNAME: staging.nduproject.com │
└────────────┬─────────────────────┘
             │
             ▼
   https://staging.nduproject.com
```

---

## Step-by-Step Setup (10 minutes)

### Step 1 — Create the `ndu-staging` repository on GitHub

1. Go to https://github.com/organizations/Ndu-Project-LLC/repositories/new
2. **Repository name:** `ndu-staging`
3. **Description:** `Static hosting target for staging.nduproject.com — auto-populated by NDU-Project CI`
4. **Visibility:** Public (required for free GitHub Pages on custom domains) — or Private if you have GitHub Pro/Team
5. **Initialize:** ✅ Add a README file
6. Click **Create repository**

### Step 2 — Push the local staging repo content

The local repo at `/home/z/my-project/ndu_staging_repo/` is already initialized with:
- `CNAME` → `staging.nduproject.com`
- `.nojekyll`
- `index.html` (placeholder)
- `README.md`
- `.github/workflows/staging-pages-audit.yml`

Run:

```bash
cd /home/z/my-project/ndu_staging_repo
git remote add origin https://github.com/Ndu-Project-LLC/ndu-staging.git
git push -u origin main --force
```

(The `--force` is to overwrite the README that GitHub auto-created in Step 1.)

### Step 3 — Enable GitHub Pages on the staging repo

1. Go to https://github.com/Ndu-Project-LLC/ndu-staging/settings/pages
2. **Source:** Deploy from a branch
3. **Branch:** `main` / `(root)`
4. Click **Save**
5. **Custom domain:** enter `staging.nduproject.com` → click **Set**
6. ✅ **Enforce HTTPS** (wait ~5 minutes for SSL provisioning)

### Step 4 — Configure DNS (CNAME record)

In your DNS provider (Cloudflare, Namecheap, etc.), add:

| Type  | Name     | Value                          | TTL  |
|-------|----------|--------------------------------|------|
| CNAME | staging  | ndu-project-llc.github.io.     | Auto |

> **Important:** The value is `ndu-project-llc.github.io.` (the organization's GitHub Pages domain), NOT the repo name. GitHub Pages uses the `CNAME` file inside the repo to route to the correct repository.

Verify DNS propagation:

```bash
dig staging.nduproject.com +short
# Should return: ndu-project-llc.github.io.
```

### Step 5 — Create a Deploy Token (PAT)

You need a Personal Access Token that the main repo's CI can use to push to the `ndu-staging` repo.

**Option A — Classic PAT (simpler, broader scope):**
1. Go to https://github.com/settings/tokens/new
2. **Note:** `NDU staging deploy token`
3. **Expiration:** 90 days (or longer if you prefer)
4. **Scopes:** ✅ `repo` (full repo access)
5. Click **Generate token** → copy the value (starts with `ghp_`)

**Option B — Fine-grained PAT (more secure, narrower scope):**
1. Go to https://github.com/settings/personal-access-tokens/new
2. **Token name:** `NDU staging deploy token`
3. **Expiration:** 90 days
4. **Repository access:** Only select repositories → `Ndu-Project-LLC/ndu-staging`
5. **Permissions:**
   - Repository permissions → Contents: **Read and write**
   - Repository permissions → Metadata: **Read-only** (auto-required)
6. Click **Generate token** → copy the value (starts with `github_pat_`)

### Step 6 — Add the token as a secret in the main NDU-Project repo

1. Go to https://github.com/Ndu-Project-LLC/NDU-Project/settings/secrets/actions
2. Click **New repository secret**
3. **Name:** `ACCESS_TOKEN`
4. **Secret:** paste the token value from Step 5
5. Click **Add secret**

### Step 7 — Verify the workflow file is in the main repo

The new workflow file should already be in the main repo after merging this PR:

```
.github/workflows/deploy-to-staging-repo.yml
```

Verify it appears at:
https://github.com/Ndu-Project-LLC/NDU-Project/actions

You should see a workflow named **"Deploy to Staging Repo"**.

---

## Testing the Deployment

### Manual trigger (recommended for first test)

1. Go to https://github.com/Ndu-Project-LLC/NDU-Project/actions/workflows/deploy-to-staging-repo.yml
2. Click **Run workflow**
3. **Ref:** `main` (or whichever branch has the workflow file)
4. Click **Run workflow**
5. Watch the run — it should:
   - ✅ Checkout source repo
   - ✅ Setup Flutter
   - ✅ Build web (release)
   - ✅ Stage CNAME + .nojekyll
   - ✅ Push to Ndu-Project-LLC/ndu-staging:main
   - ✅ Print deployment summary

### Automatic trigger

After the first manual test, the workflow will auto-fire whenever `auto-deploy-staging.yml` completes successfully on `main`.

### Verify the live site

1. Wait ~90 seconds after the workflow completes (GitHub Pages rebuild time)
2. Open https://staging.nduproject.com
3. You should see the NDU Project Flutter app load
4. Check the browser console — no 404s on `main.dart.js`, `flutter.js`, `canvaskit/`, etc.

---

## Troubleshooting

### "Bad credentials" or 403 on push

→ The `ACCESS_TOKEN` secret is missing, expired, or doesn't have write access to `ndu-staging`. Regenerate the token (Step 5) and update the secret (Step 6).

### Pages shows 404

→ Check that GitHub Pages is enabled on `ndu-staging` (Step 3) and the CNAME file is intact. The audit workflow at `.github/workflows/staging-pages-audit.yml` will fail loudly if CNAME or .nojekyll is missing.

### Custom domain not resolving

→ DNS propagation can take up to 24 hours (usually 5–15 minutes). Verify with `dig staging.nduproject.com +short` — it should return `ndu-project-llc.github.io.`

### "Ref X is not allowed" on workflow_dispatch

→ The workflow file only exists on `main` (or whichever branch you merged it to). Run the workflow from that branch, or cherry-pick the workflow file to the branch you want to deploy from.

### SSL certificate not provisioned

→ GitHub Pages SSL provisioning can take 5–30 minutes after the custom domain is set. If it's been > 1 hour, remove the custom domain and re-add it.

---

## Rollback

To roll back to a previous staging deploy:

```bash
cd /home/z/my-project/ndu_staging_repo   # or wherever you have ndu-staging cloned
git pull origin main
git log --oneline                         # find the commit you want
git checkout <commit-sha> -- .
git commit -m "rollback: revert to <commit-sha>"
git push origin main
```

Pages will rebuild in ~60 seconds.

---

## Files Added

| File | Location | Purpose |
|------|----------|---------|
| `deploy-to-staging-repo.yml` | main repo: `.github/workflows/` | Cross-repo deploy workflow |
| `SETUP_STAGING_REPO.md` | main repo: root (this file) | Setup guide |
| `CNAME` | staging repo: root | Custom domain config |
| `.nojekyll` | staging repo: root | Disable Jekyll |
| `index.html` | staging repo: root | Placeholder (overwritten on first deploy) |
| `README.md` | staging repo: root | Explains the repo is auto-populated |
| `staging-pages-audit.yml` | staging repo: `.github/workflows/` | Post-deploy audit |

---

## Cost

- **GitHub Pages:** Free for public repos (1 GB storage, 100 GB/month bandwidth)
- **PAT:** Free
- **DNS:** Whatever your DNS provider charges (usually free)
- **Total monthly cost:** $0

---

## Questions?

- Workflow source: `.github/workflows/deploy-to-staging-repo.yml` in the main repo
- Staging repo: https://github.com/Ndu-Project-LLC/ndu-staging
- Live URL: https://staging.nduproject.com
