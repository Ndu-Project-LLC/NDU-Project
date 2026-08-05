# SILENT_ACTORS — Muting Notifications for Specific Users

> A repo variable that lists GitHub usernames whose pushes / PR merges / manual
> dispatches will **skip every CI/CD workflow entirely** — no build, no deploy,
> no Issue `@mentions`, no escalation gates, no promotion PR.

## Quick start

```bash
# 1. Install the gated workflows on your repo
bash scripts/apply_silent_actors.sh NduProject/NDU-Project

# 2. Set the SILENT_ACTORS variable.
#    For CHAMA18 — and to also attribute any 'z.ai' activity to CHAMA18:
bash scripts/set_silent_actors.sh CHAMA18,z.ai

# 3. Verify
gh variable list --repo NduProject/NDU-Project

# 4. Trigger a push from CHAMA18 — check the Actions tab.
#    You should see: "Skipping entire workflow — @CHAMA18 is in SILENT_ACTORS."
```

## Attributing one user's activity to another

If you have activity coming from multiple GitHub identities that should all be
treated as the same silent actor, list **both** names separated by a comma.
The gate is case-insensitive and matches against `github.actor`, so any of
these will all skip the workflow identically:

```bash
# Both CHAMA18 and z.ai skip the workflow silently
bash scripts/set_silent_actors.sh CHAMA18,z.ai
```

| `github.actor` | Behavior |
|---|---|
| `CHAMA18` | ✅ Workflow skips (matches `CHAMA18` in list) |
| `chama18` | ✅ Workflow skips (case-insensitive match) |
| `z.ai` | ✅ Workflow skips (matches `z.ai` in list) |
| `Z.AI` | ✅ Workflow skips (case-insensitive match) |
| `alickv26` | ❌ Workflow runs normally (not in list) |

Use this pattern when:
- You push from multiple machines with different git configs
- You have a bot account (e.g. `z.ai`) that should be treated the same as your personal account (`CHAMA18`)
- You're migrating from one GitHub username to another and want both silent during the transition

## How it works

Every workflow starts with a tiny **gate job** that runs first:

```yaml
jobs:
  gate:
    runs-on: ubuntu-latest
    outputs:
      should_skip: ${{ steps.check.outputs.should_skip }}
    steps:
      - id: check
        run: |
          ACTOR="${{ github.actor }}"
          SILENT="${{ vars.SILENT_ACTORS }}"
          if echo ",$SILENT," | grep -iq ",$ACTOR,"; then
            echo "should_skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "should_skip=false" >> "$GITHUB_OUTPUT"
          fi

  build-and-deploy:
    needs: gate
    if: needs.gate.outputs.should_skip != 'true'
    runs-on: ubuntu-latest
    # ... rest of the original workflow
```

If `github.actor` is in the `SILENT_ACTORS` list, the gate job outputs
`should_skip=true` and every downstream job's `if:` condition fails — the
workflow visibly stops with a green check on the gate, no further work done.

## What gets muted

| Source of notification | Muted? |
|---|---|
| `staging-notify-and-escalate.yml` Issue `@mention` to stakeholders | ✅ Yes — workflow skips |
| `staging-notify-and-escalate.yml` `@chimmie` final-approval comment | ✅ Yes — workflow skips |
| `auto-deploy-staging.yml` (build + deploy to staging) | ✅ Yes — workflow skips |
| `deploy-production.yml` (build + deploy to production) | ✅ Yes — workflow skips |
| Promotion PR opened by `open-promotion-pr` job | ✅ Yes — workflow skips |
| Direct pushes to `main` | ✅ Yes — gate fires |
| PR merges into `main` or `production` | ✅ Yes — `github.actor` is the merger |
| `workflow_dispatch` (manual trigger) | ✅ Yes — `github.actor` is the dispatcher |

## What does NOT get muted

GitHub has notification channels that exist **outside** of workflows. The
`SILENT_ACTORS` gate cannot mute these — workarounds are listed for each.

### 1. GitHub native "watching" push emails

Anyone who **watches** the repo (Watch → Custom → Issues, PRs, Discussions, etc.)
gets an email when commits are pushed to the default branch. This is a per-user
subscription; you cannot control it from the repo side.

**Workarounds:**

| Option | Effect |
|---|---|
| Push to a feature branch instead of `main` | Pushes to non-default branches **don't** notify watchers. Open a PR when ready for review. |
| Have watchers adjust their subscription | Each watcher visits `https://github.com/<owner>/<repo>/subscriptions` and unchecks "Releases", "Discussions", etc. |
| Use a bot account to push | Commits from bots don't trigger watcher notifications. |

### 2. GitHub Actions failure emails to repo admins

If a workflow **fails** (red X), GitHub emails repo admins and the workflow
triggerer automatically, regardless of who triggered it. This is a GitHub
platform-level notification that you cannot mute from inside the workflow.

**Workarounds:**

| Option | Effect |
|---|---|
| Keep workflows green | The cleanest fix. A skipped workflow (via the gate) is green — no failure email. |
| Demote yourself from admin to maintainer | Maintainers don't receive failure emails by default. |
| Disable failure notifications in repo settings | Settings → Actions → General → uncheck "Send notifications for failed deployments" (limited effect). |

### 3. `@mentions` in PR descriptions, issue comments, commit messages

If you `@mention` someone in a PR description or commit message, GitHub will
email them — this is core GitHub behavior that no workflow can suppress.

**Workaround:** Don't `@mention` users in commit messages or PR descriptions
when you want a silent push. Spell out their name without the `@` symbol if you
need to refer to them.

## Managing the SILENT_ACTORS list

### Add a user

```bash
# View current value
gh variable get SILENT_ACTORS --repo NduProject/NDU-Project

# Set new value (replaces the old one — list everyone)
bash scripts/set_silent_actors.sh CHAMA18,z.ai,NduProject
```

### Remove a user

```bash
# Re-set with the updated list (the set command replaces, doesn't append)
bash scripts/set_silent_actors.sh CHAMA18,z.ai
```

### Clear the list entirely (re-enable notifications for everyone)

```bash
bash scripts/set_silent_actors.sh --clear
```

## Verifying the gate is firing

After you push as a silent-actor user:

1. Go to **https://github.com/NduProject/NDU-Project/actions**
2. Click the workflow run that was just triggered
3. You should see the **"Silent-actor gate"** job with a green check ✓
4. The job log should contain: `Skipping entire workflow — @<user> is in SILENT_ACTORS.`
5. All downstream jobs should show as **"Skipped"** (grey circle with a dash)

If you see downstream jobs running instead of skipping, the variable is not set
correctly — check with `gh variable list --repo NduProject/NDU-Project`.

## Audit trail

Even when the gate skips the workflow, GitHub still records:

- The push event itself (visible in the repo's commit history)
- The workflow run entry (visible in the Actions tab, marked as "skipped")
- The actor who triggered the run (`github.actor`)

So silent pushes are **not invisible** — they're just unobtrusive. Anyone who
looks at the commit log or Actions tab can see what was pushed and when.

## Security model

- `SILENT_ACTORS` is a repo **VARIABLE**, not a secret — it's visible to anyone
  with read access to the repo. This is intentional: the list should be
  discoverable so silent-actor users know who they are.
- Only repo admins can set or delete variables. A non-admin silent-actor user
  cannot add themselves to the list.
- The gate job runs as the `github-actions` bot, not as the silent-actor user —
  so a compromised silent-actor account cannot escalate by modifying the gate.

## Files

| Path | Purpose |
|---|---|
| `.github/workflows/auto-deploy-staging.yml` | Workflow A — with gate |
| `.github/workflows/staging-notify-and-escalate.yml` | Workflow B — with gate |
| `.github/workflows/deploy-production.yml` | Workflow C — with gate |
| `scripts/apply_silent_actors.sh` | One-shot installer for the gated workflows |
| `scripts/set_silent_actors.sh` | Setter / clearer for the SILENT_ACTORS variable |
| `docs/SILENT_ACTORS.md` | This document |
