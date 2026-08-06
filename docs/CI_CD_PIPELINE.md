# NDU Project — Staging → Production CI/CD Pipeline

Automated release pipeline that:

1. **Auto-deploys** every push to `main` → `staging.nduproject.com`
2. **Auto-notifies stakeholders** → opens a tracking Issue with `@mentions` (no SMTP, no API keys)
3. **Escalates to `chimmie`** → posts a final-approval request comment on the same Issue
4. **Opens a promotion PR** → requests owner review (`@NduProject`)
5. **On owner merge** → publishes to `nduproject.com` (production)

Optionally supports **SILENT_ACTORS** — a repo variable that lists GitHub usernames whose pushes / PR merges skip every workflow entirely (no build, no deploy, no `@mentions`). See [`docs/SILENT_ACTORS.md`](docs/SILENT_ACTORS.md) for setup.

```
   ┌──────────┐  push to main  ┌─────────────────────┐
   │  main    │ ──────────────▶│ Workflow A          │
   │  branch  │                │ Auto-Deploy Staging │
   └──────────┘                └──────────┬──────────┘
                                          │ publishes to gh-pages branch
                                          ▼
                                 ┌─────────────────────┐
                                 │ staging.nduproject  │
                                 │       .com          │
                                 └──────────┬──────────┘
                                            │ workflow_run: success
                                            ▼
                                 ┌─────────────────────┐
                                 │ Workflow B          │
                                 │ Open Promotion PR   │
                                 │ main → production   │
                                 │ Requests @NduProject│
                                 └──────────┬──────────┘
                                            │ Owner reviews staging
                                            │ Owner clicks "Merge"
                                            ▼
                                 ┌─────────────────────┐
                                 │ Workflow C          │
                                 │ Deploy to Production│
                                 │ → production-pages  │
                                 └──────────┬──────────┘
                                            ▼
                                 ┌─────────────────────┐
                                 │   nduproject.com    │
                                 │      (LIVE)         │
                                 └─────────────────────┘
```

---

## Branch model

| Branch | Purpose | Serves |
|--------|---------|--------|
| `main` | Active development | — |
| `gh-pages` | Staging build output | `staging.nduproject.com` |
| `production` | Promotion target (PR base) | — |
| `production-pages` | Production build output | `nduproject.com` |

---

## Workflows

### Workflow A — `auto-deploy-staging.yml`

- **Trigger:** Push to `main` (or manual dispatch)
- **Does:** `flutter build web --release` → publishes to `gh-pages` branch
- **Result:** Live at https://staging.nduproject.com/ within ~90 s
- **CNAME:** `staging.nduproject.com` (force-written, never overwritten)

### Workflow B — `staging-notify-and-escalate.yml`

- **Trigger:** Successful completion of Workflow A (via `workflow_run`)
- **Does:** Runs 5 chained jobs:
  - **B.1** Opens a tracking Issue that `@mentions` stakeholders (from `STAKEHOLDER_GITHUB_LOGINS` repo variable, default `@NduProject`)
  - **B.2** Pauses at the `staging-review` GitHub Environment (required reviewers = stakeholder team)
  - **B.3** Posts a comment on the same Issue `@mentioning` `chimmie` (from `FINAL_APPROVER_LOGIN` repo variable, default `@chimmie`)
  - **B.4** Pauses at the `final-approval` GitHub Environment (required reviewer = chimmie)
  - **B.5** Opens a PR `main → production`, requests review from `@NduProject`, links back to tracking Issue
- **Zero SMTP / zero third-party mail actions** — GitHub emails `@mentioned` users natively
- **Audit trail:** The tracking Issue is the single source of truth for each staging deploy cycle

### Workflow C — `deploy-production.yml`

- **Trigger:** PR merged into `production` branch (or manual dispatch)
- **Environment:** Uses GitHub `production` environment (configure required reviewers in repo settings)
- **Does:** `flutter build web --release` → publishes to `gh-pages` branch (serves `nduproject.com`)
- **Result:** Live at https://nduproject.com/ within ~90 s
- **Cross-repo dispatch:** Optionally triggers `NDU-Production` repo via `repository_dispatch` if `PRODUCTION_DISPATCH_TOKEN` secret is set

---

## Setup checklist

### 1. Add the workflow files to the repo

Copy the three files from `.github/workflows/` into the same path in your target repo:

```
.github/workflows/auto-deploy-staging.yml
.github/workflows/promote-to-production.yml
.github/workflows/deploy-production.yml
```

Commit them to `main` and push. Workflow A will fire immediately on the push (no further config needed for it).

### 2. Remove or disable the old workflows (optional but recommended)

The repo currently has these overlapping workflows:

- `build_web.yml` — builds on push to `main`, deploys to Azure SWA
- `deploy-staging.yml` — deploys to Firebase staging on push to `staging` branch

To avoid duplicate deploys, either delete these or rename them to `.disabled`:

```bash
mv .github/workflows/build_web.yml .github/workflows/build_web.yml.disabled
mv .github/workflows/deploy-staging.yml .github/workflows/deploy-staging.yml.disabled
git commit -am "ci: retire old build/staging workflows (replaced by auto-deploy-staging.yml)"
git push
```

> Keep `pr-notification.yml` — it complements Workflow B by adding email review requests on PRs.

### 3. Create the `production` branch

Workflow B creates this automatically on first run if it doesn't exist. To create it manually (recommended):

```bash
git checkout main
git pull
git checkout -b production
git push -u origin production
```

### 4. Configure the GitHub `production` environment (REQUIRED)

This is the human-gate that prevents accidental production deploys:

1. Go to **Settings → Environments** in the repo
2. Click **New environment** → name it `production`
3. Under **Required reviewers**, add `@NduProject` (and any other owners)
4. (Optional) Set **Deployment branches** to `Selected branches → production`

Now Workflow C will pause and ask for explicit approval before publishing to `nduproject.com`, even if someone merges the promotion PR.

### 5. Configure GitHub Pages

You need **two** Pages sites — one per branch:

#### Staging (https://staging.nduproject.com)

1. **Settings → Pages**
2. **Source:** Deploy from a branch
3. **Branch:** `gh-pages` / root
4. **Custom domain:** `staging.nduproject.com` (already in the `CNAME` file)
5. Click **Save**
6. In your DNS provider, ensure the CNAME record for `staging.nduproject.com` points to `<your-github-username>.github.io` (this is already configured per the existing `STAGING_DEPLOYMENT_COMPLETE.md`)

#### Production (https://nduproject.com)

1. **Settings → Pages** (scroll to bottom if two sites are configured)
2. **Source:** Deploy from a branch
3. **Branch:** `production-pages` / root
4. **Custom domain:** `nduproject.com` (already in the `CNAME` file written by Workflow C)
5. Click **Save**
6. In your DNS provider:
   - **Apex domain** (`nduproject.com`): add A records pointing to GitHub Pages IPs:
     ```
     185.199.108.153
     185.199.109.153
     185.199.110.153
     185.199.111.153
     ```
   - **www subdomain** (`www.nduproject.com`): CNAME → `<your-github-username>.github.io`

> ⚠️ GitHub Pages only supports **one custom domain per repo** at the apex level. If you need both `staging.nduproject.com` AND `nduproject.com` from the same repo, the production site must be in a **separate repo** (e.g. `NDU-Project-Production`) whose `production-pages` branch serves `nduproject.com`. The same Workflow C file works — just point its `publish_branch` to `gh-pages` in the production repo and configure cross-repo push via a deploy key.

### 6. Verify the reviewer handle

Workflow B requests review from `@NduProject`. Confirm this GitHub user/team exists and has review access:

- **Settings → Collaborators and teams** → ensure `NduProject` is listed with **Write** access (required for review requests)
- If the owner's GitHub username is different, edit `promote-to-production.yml`:

  ```yaml
  --reviewer "NduProject"   # change to the actual handle, e.g. "chimmie-ndu"
  ```

- To request reviews from multiple owners, comma-separate: `--reviewer "NduProject,chimmie-ndu"`

### 7. Smoke-test the pipeline

1. Make a trivial commit on `main` (e.g. update `NDU_BUILD_STAMP`)
2. Push — Workflow A fires immediately
3. After ~2 min, verify https://staging.nduproject.com/ shows the new build
4. Workflow B opens a promotion PR within ~30 s of A's success
5. Review the PR, click **Merge**
6. Workflow C fires — the `production` environment will pause for review approval
7. Approve in the GitHub Actions UI → deploy completes in ~3 min
8. Verify https://nduproject.com/ shows the new build

---

## Rollback procedure

### Quick rollback (most cases)

1. Find the promotion PR you just merged (search for `promote:` in PR list)
2. Click **Revert** — GitHub opens a new PR
3. Merge the revert PR — Workflow C redeploys the previous build

### Tagged rollback (if revert isn't possible)

Each production deploy creates an annotated tag:

```
production-20260729-120000-abc1234
```

To restore a specific tagged version:

```bash
git checkout production
git reset --hard production-20260729-120000-abc1234
git push --force-with-lease origin production
```

Workflow C fires on the push (if you've configured it to also trigger on push, currently it only triggers on PR merge — adjust the `on:` block in `deploy-production.yml` to add `push: branches: [production]` if you want this behaviour).

---

## Notifications

| Event | Where the owner is notified |
|-------|-----------------------------|
| Staging deploy completes | GitHub Actions run summary (visible in PR / commit checks) |
| Promotion PR opened | GitHub notification (email + web), review request on `@NduProject` |
| Promotion PR merged | GitHub PR comment from Workflow C |
| Production deploy succeeds | GitHub PR comment + Actions run summary |
| Production deploy fails | GitHub PR comment + Actions run summary (failure alert) |

The existing `pr-notification.yml` workflow also adds an email-prompt comment to every PR reminding the owner to verify their GitHub email settings for `chimmie@nduproject.com`.

---

## Silent actors (mute your own pushes)

If you want your pushes / PR merges / manual dispatches to **skip every workflow entirely** (no build, no deploy, no `@mentions`, no escalation gates), use the `SILENT_ACTORS` repo variable.

```bash
# 1. Install the gated workflows (one-shot)
bash scripts/apply_silent_actors.sh NduProject/NDU-Project

# 2. Set the variable with your GitHub username
bash scripts/set_silent_actors.sh alickv26

# 3. Verify
gh variable list --repo NduProject/NDU-Project
```

See [`docs/SILENT_ACTORS.md`](docs/SILENT_ACTORS.md) for full details on what's muted and what's not.

---

## File map

```
ndu-cicd-pipeline/
├── .github/
│   └── workflows/
│       ├── auto-deploy-staging.yml          # Workflow A — with SILENT_ACTORS gate
│       ├── staging-notify-and-escalate.yml  # Workflow B — with SILENT_ACTORS gate
│       └── deploy-production.yml             # Workflow C — with SILENT_ACTORS gate
├── docs/
│   ├── SETUP_CHECKLIST.md                   # Print-friendly setup checklist
│   └── SILENT_ACTORS.md                     # How to mute notifications for specific users
├── scripts/
│   ├── apply_silent_actors.sh               # One-shot installer for gated workflows
│   ├── set_silent_actors.sh                 # Setter / clearer for the SILENT_ACTORS variable
│   ├── apply_staging_escalation.sh          # One-shot installer for staging-notify-and-escalate.yml
│   └── one_shot_staging_deploy.sh           # Local-build + force-push to gh-pages (bypass CI)
└── README.md                                # This file
```

---

## Security notes

- All three workflows use the built-in `GITHUB_TOKEN` — **no PATs or long-lived secrets required** for the basic flow
- The `production` GitHub Environment should have **Required reviewers** configured — this is the human gate
- `SILENT_ACTORS` is a repo **VARIABLE** (not a secret) — visible to anyone with read access so silent-actor users know who they are. Only admins can set or delete it.
- If you later add Firebase/Azure secrets, store them as repository secrets (never commit them to the repo)
- **Never paste GitHub tokens in chat** — if a token is leaked, revoke it immediately at https://github.com/settings/tokens
