---
name: ldap-info-leak-review
description: Review the repository for leaked sensitive information — secrets (passwords, API keys, tokens, private keys), and real-world identifiers (domains, emails, hostnames, IPs) that should be placeholders. Use when the user asks to check/review/scan for info leaks, secret leaks, exposed credentials, or before sharing/publishing a repo.
---

# Info Leak Review

Find sensitive information that is committed (or about to be committed) to the repository. Report findings; only fix when the user asks.

## Principles

- **Git is the source of truth for exposure.** A secret only leaks if it is *tracked* (`git ls-files`) or in *history* (`git log --all`). A value sitting in a gitignored `.env` is not a repo leak — but flag it if a tracked file reuses the same value.
- **Reason, don't pattern-match blindly.** The greps below are starting points to surface candidates. Judge each hit: is it a real value, a placeholder (`changeme`, `your-token`, `example.com`, `<domain>`, `${VAR}`), or a templated reference? Don't report placeholders as leaks.
- **Don't hardcode what counts as "real."** Infer the project's own placeholder convention from its files (e.g. it uses `example.com` / `<domain>`), then flag anything that deviates — a real domain, a personal email, a specific public IP.
- **Be conservative about false positives, exhaustive about real ones.** When unsure, present it as "verify this" rather than asserting a leak.

## Procedure

### 1. Establish scope
```bash
git ls-files                        # everything tracked (what can leak now)
git status --porcelain              # staged/modified not yet committed
```
Limit to the path the user named, if any.

### 2. Confirm ignore hygiene
Check that sensitive file types are gitignored AND not already tracked:
```bash
cat .gitignore
git ls-files | grep -iE '\.(env|pem|key|crt|csr|p12|pfx|keystore|mdb)$|(^|/)\.env$|credentials|secrets'
```
Anything matching that is *tracked* is a finding. A gitignore rule does **not** retroactively untrack a file.

### 3. Scan history for ever-committed secret files
A file deleted/ignored today may still be in history:
```bash
git log --all --pretty=format: --name-only | sort -u \
  | grep -iE '\.(env|pem|key|crt|csr|p12|pfx)$|credentials|secret'
```

### 4. Scan tracked content for secrets
Run on tracked files (use `git grep`, which respects tracking). Skip docs/examples in the first pass, then check them separately since they often carry real values by mistake.
```bash
git grep -nIE '(pass(word|wd)?|secret|api[_-]?key|token|bind(_|)credential|private[_-]?key|access[_-]?key)\s*[:=]' \
  -- ':!*.md' ':!*.example'
```
Discard hits that resolve to env vars / templates (`${VAR}`, `process.env`, `getenv`, `{{PLACEHOLDER}}`) or obvious placeholders.

### 5. Scan for real-world identifiers that should be placeholders
Surface candidates, then compare against the project's placeholder convention:
```bash
# Domains/hostnames (two-label and deeper) — then exclude the project's own placeholder domains.
# Expect false positives from file names / version strings (package.json, app.module.ts); discard by judgment.
git grep -nIE '\b([a-z0-9-]+\.)+[a-z]{2,}\b'
# Emails — exclude example.com / noreply / test addresses
git grep -nIE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# Public IPs (ignore private ranges 10./192.168./172.16-31./127.)
git grep -nIE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'
```
Also check Dockerfile `LABEL maintainer`, README architecture diagrams, and config comments — common places a real domain or email slips in.

### 6. Cross-check examples vs. real config
If a tracked `*.env.example` exists alongside a gitignored real `.env`, compare them.
```bash
git grep -nIE 'PASSWORD|SECRET|TOKEN' -- '*.env.example'
```
Identical secret values *can* mean the example is publishing a live credential — but judge intent before reporting. Reuse may be deliberate. When unsure, ask rather than assert a leak.

## Reporting

Group findings by severity:
- **Leak (tracked or in history):** secrets or real credentials reachable from the repo.
- **Identifier exposure:** real domains/emails/IPs that should be placeholders.
- **Hygiene risk:** example files reusing live values; near-misses worth verifying.

For each: file:line, what it is, and why it matters. Note when something is only in *history* (working-tree fix alone won't purge it — mention `git filter-repo` / rotation).

Do not modify files unless the user asks. When fixing, match the project's existing placeholder style rather than inventing a new one.
