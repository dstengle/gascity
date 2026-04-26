# Personal build workflow

This documents how `dstengle/gascity` maintains a personal patched build
on top of upstream `gastownhall/gascity`.

## What this is

`personal/main` is a branch in this fork that tracks upstream `main` with a
small set of patches applied on top — fixes that are pending upstream review
or personal experiments. Two GitHub Actions workflows keep it alive:

- **`personal-sync.yml`** — runs daily (and on demand) to rebase
  `personal/main` onto the latest upstream `main`.
- **`personal-build.yml`** — runs on every push to `personal/main` and
  produces downloadable `gc` binaries for Linux and macOS (amd64 + arm64).

## Current patches

These commits sit on top of upstream `main`. Keep this list current whenever
you add or drop a patch.

| Commit | Branch | Description |
|--------|--------|-------------|
| `faaf24ef` | `fix/session-reconciler-no-op-writes` | fix: skip clearWakeFailures write when values already cleared |
| `e2f14b61` | `fix/dolt-state-missing-recovery` | fix: recover dolt-state.json from stale or missing provider state |
| `2287dc4e` | `fix/gc-init-issue-prefix` | fix: ensure gc init sets issue_prefix in beads database |
| `ff907482` | `fix/darwin-cross-compile` | fix: cast stat.Dev/Ino to uint64 for darwin cross-compilation |

## Day-to-day operations

### Getting a binary

1. Go to **Actions → Build personal gc binaries** in this repo.
2. Download the artifact for your platform from the latest run.

Or trigger a build manually: **Actions → Build personal gc binaries → Run workflow**.

### Adding a new patch

Every patch lives on its own branch first — never commit directly to
`personal/main`.

```bash
# 1. Create a branch off upstream main
git fetch upstream main
git checkout -b fix/my-description upstream/main

# 2. Make your change and commit
git add ...
git commit -m "fix: description"
git push origin fix/my-description

# 3. Cherry-pick onto personal/main
git checkout personal/main
git cherry-pick <commit-sha>

# 4. Update the patches table in PERSONAL_BUILD.md, then push
git add .github/PERSONAL_BUILD.md
git commit --amend --no-edit   # fold into the cherry-pick
git push --force-with-lease origin personal/main
```

### Dropping a patch (merged upstream or no longer needed)

After the daily sync rebases the branch, verify the patch is gone:

```bash
git fetch origin personal/main
git log --oneline upstream/main..origin/personal/main
```

If the commit no longer appears (upstream absorbed it), remove its row from
the table above and push.

### Handling a sync conflict

The daily sync fails if `git rebase` hits a conflict. GitHub will send an
email from the Actions failure. To fix it:

```bash
git fetch upstream main
git checkout personal/main
git rebase upstream/main
# resolve conflicts, then:
git rebase --continue
git push --force-with-lease origin personal/main
```

Re-run the sync workflow after pushing to confirm it passes clean.

### Rebasing a patch branch before opening a PR

When contributing a patch upstream, make sure its branch is rebased on
upstream `main` (not `personal/main`):

```bash
git fetch upstream main
git checkout fix/my-patch
git rebase upstream/main
git push --force-with-lease origin fix/my-patch
```

## How the rebase sync works

`personal-sync.yml` does:

```
git fetch upstream main
git rebase upstream/main
git push --force-with-lease origin personal/main
```

Force-with-lease is safe here because only the workflow writes to this
branch. If a human pushes while the workflow is mid-run, the push will
fail rather than overwrite — that's the correct behaviour.
