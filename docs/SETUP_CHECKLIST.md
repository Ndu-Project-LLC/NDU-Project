# NDU CI/CD Pipeline — Setup Checklist

Print this and tick off each step.

---

## 1. Install the workflow files

- [ ] Copy `.github/workflows/auto-deploy-staging.yml` → target repo
- [ ] Copy `.github/workflows/staging-notify-and-escalate.yml` → target repo *(replaces the old promote-to-production.yml)*
- [ ] Copy `.github/workflows/deploy-production.yml` → target repo
- [ ] Disable the old `promote-to-production.yml` (or run `scripts/apply_staging_escalation.sh` which does this for you)
- [ ] Commit and push to `main` → Workflow A fires immediately

## 1b. Configure the two approval environments (NO API KEY NEEDED)

GitHub automatically emails every required reviewer a "Deployment review
requested" notification when a workflow pauses at an environment. This is the
primary notification channel — no SMTP, no secrets, no app password.

- [ ] Repo **Settings → Environments → New environment → `staging-review`**
  - [ ] Add **Required reviewers** → stakeholder team (e.g. `@NduProject`)
- [ ] Repo **Settings → Environments → New environment → `final-approval`**
  - [ ] Add **Required reviewers** → `chimmie`

## 1c. (Optional) Set repo VARIABLES for @mention handles

These are repo *variables* (not secrets) — visible in the Actions log, which
is fine for @-mention handles. They control who gets @mentioned in the review
Issue and the final-approval comment.

- [ ] Repo **Settings → Secrets and variables → Actions → Variables tab**:
  - [ ] `STAKEHOLDER_GITHUB_LOGINS` — e.g. `@alice,@bob` or `@NduProject/owners` (defaults to `@NduProject`)
  - [ ] `FINAL_APPROVER_LOGIN` — e.g. `@chimmie` (defaults to `@chimmie`)

> **No secrets of any kind are required.** All notifications use the built-in
> `GITHUB_TOKEN` and native GitHub email delivery.

## 2. Retire old workflows

- [ ] `mv .github/workflows/build_web.yml .github/workflows/build_web.yml.disabled`
- [ ] `mv .github/workflows/deploy-staging.yml .github/workflows/deploy-staging.yml.disabled`
- [ ] Keep `pr-notification.yml` (still useful)
- [ ] Commit and push

## 3. Create the `production` branch

- [ ] `git checkout -b production && git push -u origin production`

## 4. Configure GitHub `production` environment (the human gate)

- [ ] Repo **Settings → Environments → New environment → `production`**
- [ ] Add **Required reviewers** → `@NduProject`
- [ ] (Optional) Restrict **Deployment branches** to `production` only

## 5. Configure GitHub Pages — staging

- [ ] **Settings → Pages → Source: Deploy from a branch**
- [ ] **Branch:** `gh-pages` / root
- [ ] **Custom domain:** `staging.nduproject.com` (already in CNAME)
- [ ] Verify DNS: `dig staging.nduproject.com` returns GitHub Pages IPs

## 6. Configure GitHub Pages — production

- [ ] **Settings → Pages → Add another site** (or use a separate production repo)
- [ ] **Branch:** `production-pages` / root
- [ ] **Custom domain:** `nduproject.com` (already in CNAME)
- [ ] Configure DNS apex A records (4× `185.199.108-111.153`)
- [ ] Configure `www.nduproject.com` CNAME → `<user>.github.io`

## 7. Verify reviewer access

- [ ] Repo **Settings → Collaborators** → `NduProject` has **Write** access
- [ ] If different handle, edit `promote-to-production.yml` line: `--reviewer "ACTUAL_HANDLE"`
- [ ] For multiple owners: `--reviewer "owner1,owner2"`

## 8. Smoke-test the pipeline

- [ ] Push a trivial change to `main`
- [ ] ~2 min later: verify https://staging.nduproject.com/ shows new build
- [ ] ~30 s later: a new Issue opens in the repo, @mentioning stakeholders (GitHub emails them the full Issue body — the "detailed message" with changelog + screen inventory)
- [ ] Stakeholders also receive GitHub's native "Deployment review requested" email with a direct Approve/Reject link
- [ ] Open the Actions run, click the **staging-review** environment, click **Review deployments → Approve** (or comment `APPROVE` on the Issue)
- [ ] ~1 min later: chimmie gets @mentioned in a comment on the same Issue AND receives a "Deployment review requested" email
- [ ] Click the **final-approval** environment, click **Review deployments → Approve**
- [ ] ~30 s later: promotion PR opened with `@NduProject` reviewer (GitHub emails them natively)
- [ ] Click **Merge** on the PR
- [ ] Workflow C runs automatically (no separate env approval needed — chimmie already approved)
- [ ] ~3 min later: verify https://nduproject.com/ shows new build
- [ ] Verify rollback tag `production-<timestamp>-<sha>` was created

## 9. Done

- [ ] Bookmark the Actions tab: `https://github.com/Ndu-Project-LLC/NDU-Project/actions`
- [ ] Subscribe to email notifications for the `production` environment
- [ ] Document the rollback procedure for the on-call owner

---

## Quick reference — what triggers what

| Action | Workflow fired | Result |
|--------|----------------|--------|
| Push to `main` | A (auto-deploy-staging) | staging.nduproject.com updates |
| Workflow A succeeds | **B (staging-notify-and-escalate)** | Opens review Issue @mentioning stakeholders (GitHub emails them) |
| Stakeholder approves `staging-review` env | B (continues) | Comments on Issue @mentioning chimmie (GitHub emails them) |
| Chimmie approves `final-approval` env | B (continues) | Promotion PR opened automatically |
| Owner merges PR → `production` | C (deploy-production) | nduproject.com updates |
| Manual dispatch of C with `DEPLOY` | C (deploy-production) | nduproject.com updates |
| Revert a promotion PR | C fires again | nduproject.com rolls back |
