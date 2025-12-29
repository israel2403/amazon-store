# Repository Governance & Security Guidelines

This document describes how to configure GitHub settings and workflows for this public repository, following security and collaboration best practices.

> **Scope:**  
> - Protect the main branches from accidental or malicious changes.  
> - Enforce code review and automated checks.  
> - Secure access (collaborator permissions, secrets, etc.).  
> - Standardize how contributions are made and approved.

---

## 1. Branch Strategy

1. **Create protected branches**
   - Go to: **Settings → Branches → Branch protection rules → Add rule**.
   - Recommended protected branches:
     - `main` (production-ready code).
     - `develop` (if you use GitFlow style).

2. **Recommended model**
   - `main` → stable, deployable.
   - `develop` → integration of features.
   - `feature/*` branches → for new work.
   - `hotfix/*` branches → for urgent fixes.

3. **Do not commit directly to `main`**
   - All changes must go through Pull Requests (PRs / Merge Requests).
   - Disable direct pushes to protected branches (see next section).

---

## 2. Branch Protection Rules (Main Security Layer)

For each protected branch (e.g., `main`, `develop`):

1. Go to **Settings → Branches → Branch protection rules → Add rule**.
2. In **Branch name pattern**, enter the branch (e.g. `main`).
3. Enable at least:

   - ✅ **Require a pull request before merging**
     - Set **Required approvals**: `1` (or `2` for stricter reviews).
     - Enable **Dismiss stale pull request approvals when new commits are pushed**.
     - (Optional, but recommended) Enable **Require review from Code Owners** once you configure CODEOWNERS.
   - ✅ **Require status checks to pass before merging**
     - Select required checks (e.g. `build`, `test`, `lint`) after GitHub Actions / CI are configured.
     - Enable **Require branches to be up to date before merging** (forces rebase/merge with latest `main` / `develop`).
   - ✅ **Require conversation resolution before merging**
     - Ensures all review comments are addressed.
   - ✅ **Require signed commits** (optional but recommended)
     - Forces GPG or SSH-signed commits to improve auditability.
   - ✅ **Restrict who can push to matching branches**
     - Limit to maintainers / CI only; regular contributors must use PRs.
   - ✅ **Include administrators**
     - Apply rules even to admins (for strict governance).

4. Save the rule and repeat for other critical branches (`develop`, if used).

---

## 3. Pull Request (PR) Workflow Rules

1. **Create a pull request for every change**
   - Source: `feature/*` or `hotfix/*` branch.
   - Target: `develop` or `main` (depending on your flow).

2. **Required conditions before merging**
   - ✅ At least **one approval** from a reviewer.
   - ✅ All **required checks** passed (CI builds, tests, lint, security scans).
   - ✅ All **conversations resolved**.
   - ✅ No direct commit to `main` / `develop` without PR.

3. **Recommended PR standards**
   - Use a **PR template**:
     - Go to `.github/PULL_REQUEST_TEMPLATE.md`.
     - Include sections:
       - Summary
       - Motivation / Context
       - Testing (steps and results)
       - Screenshots (if relevant)
       - Checklist (tests passed, docs updated, breaking changes, etc.).

4. **Enforce linear history (optional)**
   - In **Settings → General → Pull Requests**:
     - Consider enabling **“Allow squash merging”** and/or **“Allow rebase merging”**.
     - Disable unnecessary merge strategies to keep history clean.

---

## 4. CODEOWNERS (Automatic Review Assignment)

1. **Create a CODEOWNERS file**
   - Location (one of):
     - `.github/CODEOWNERS`
     - `docs/CODEOWNERS`
     - `CODEOWNERS` at repository root.
   - Example:

     ```txt
     # Default owners for the entire repo
     *       @your-username

     # Backend code owners
     /src/main/java/     @your-username @backend-reviewer

     # Infrastructure / DevOps configs
     /k8s/               @your-username @devops-reviewer
     /docker/            @your-username @devops-reviewer
     ```

2. **Connect CODEOWNERS to branch protection**
   - In branch protection rules, enable:
     - **Require review from Code Owners**.
   - Now PRs touching those paths will automatically request review and cannot be merged without approval.

---

## 5. GitHub Actions / CI Configuration

1. **Create basic workflows**
   - Add files under `.github/workflows/`, for example:
     - `ci.yml` → build, test, lint on each push / PR.
     - `security.yml` → run SAST / dependency scans.

2. **Typical CI triggers**
   - Run on:
     - `pull_request` for `main` and `develop`.
     - `push` for `main` and `develop` (for verification after merge).

3. **Mark checks as required**
   - After first CI run, go to:
     - **Settings → Branches → Branch protection rules → Edit → Require status checks to pass before merging**.
   - Mark the relevant workflows (e.g. `CI`, `Tests`, `Lint`, `Security Scan`) as required.

---

## 6. Security: Secrets, Tokens, Access

1. **Never commit secrets**
   - No passwords, API keys, tokens, or certificates in:
     - Source files
     - YAML/JSON configs
     - Dockerfiles / shell scripts.
   - Use environment variables or GitHub Secrets.

2. **Use GitHub Secrets**
   - Go to **Settings → Secrets and variables → Actions**.
   - Add secrets like:
     - `DOCKERHUB_USERNAME`
     - `DOCKERHUB_TOKEN`
     - `DATABASE_URL` (for tests, if needed).
   - Consume them in workflows via `${{ secrets.SECRET_NAME }}`.

3. **Restrict collaborator permissions**
   - Go to **Settings → Collaborators and teams**:
     - Use **least privilege**:
       - Outside contributors → open PRs via forks.
       - Internal collaborators → use roles (Write, Maintain, Admin) only as needed.

4. **Security features (recommended)**
   - Enable:
     - **Dependabot Alerts** (Security → Configure).
     - **Dependabot Security Updates**.
     - **Code scanning** (GitHub Advanced Security or third-party).
     - **Secret scanning** (public repos usually have some scanning enabled by default).

---

## 7. Repository Management & Documentation

1. **Add a clear README**
   - Include:
     - Project description.
     - Tech stack.
     - How to run locally.
     - How to run tests.
     - Contribution guidelines.

2. **Add a CONTRIBUTING guide**
   - File: `CONTRIBUTING.md`.
   - Specify:
     - Branch naming convention.
     - Coding style.
     - How to open issues and PRs.
     - Expectations for tests and documentation.

3. **Add a LICENSE**
   - Choose a license (MIT, Apache-2.0, etc.).
   - Add it as `LICENSE` in the repo root.

4. **Add an ISSUE TEMPLATE and PR TEMPLATE**
   - Folder: `.github/ISSUE_TEMPLATE/`:
     - `bug_report.md`
     - `feature_request.md`
   - File: `.github/PULL_REQUEST_TEMPLATE.md`.

---

## 8. Additional Hardening (Optional but Recommended)

1. **Require 2FA for contributors**
   - Organization-level setting (if repo is under an org).
   - Enforce **2FA** for all members and outside collaborators.

2. **Limit who can create or approve PRs to `main`**
   - Use teams with clear responsibilities:
     - “Maintainers” (can approve / merge PRs).
     - “Contributors” (can push to feature branches and open PRs).

3. **Use signed-release tags**
   - Create annotated and signed tags for releases.
   - Document release steps and changelog process.

4. **Audit logs (organizations)**
   - If under an organization, periodically review **Audit log** for suspicious activity.

---

## 9. Step-by-Step Checklist

Use this checklist when configuring a new public repo:

1. [ ] Define branch strategy (`main`, `develop`, `feature/*`, `hotfix/*`).
2. [ ] Protect `main` (and `develop`) with branch protection rules:
   - [ ] Require PRs before merging.
   - [ ] Minimum 1 approval.
   - [ ] Require status checks to pass.
   - [ ] Require conversations to be resolved.
   - [ ] Restrict who can push.
   - [ ] (Optional) Require signed commits.
3. [ ] Configure CODEOWNERS and link to branch protection.
4. [ ] Create GitHub Actions workflows under `.github/workflows/`:
   - [ ] CI: build + tests.
   - [ ] Lint & formatting checks.
   - [ ] Security scans (optional).
5. [ ] Mark CI checks as **required** in branch protection.
6. [ ] Configure GitHub Secrets and remove any hard-coded secrets from the repo.
7. [ ] Add core documentation:
   - [ ] `README.md`
   - [ ] `CONTRIBUTING.md`
   - [ ] `LICENSE`
   - [ ] `.github/PULL_REQUEST_TEMPLATE.md`
   - [ ] `.github/ISSUE_TEMPLATE/…`
8. [ ] Review collaborator permissions and enable 2FA requirements (if applicable).
9. [ ] Review settings periodically (at least every few months) to keep rules and workflows up to date.

---

By following these steps, this public repository stays secure, auditable, and maintainable, while encouraging high-quality contributions through a consistent review and CI/CD process.
