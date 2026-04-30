# Personal build workflow

`personal/main` carries a curated set of patches on top of upstream
`gastownhall/gascity`. This document describes how the system is wired
and how to operate it.

## Branches

- **`personal-config`** (default branch on this fork) — source of truth.
  Holds:
  - `.github/personal-patches.toml` — declarative manifest of patches
  - `.github/workflows/personal-sync.yml` — the workflow that rebuilds
    `personal/main` and produces the rolling release
  - `.github/PERSONAL_BUILD.md` — this document
- **`personal/main`** — pure build output. Never hand-edited. Force-pushed
  by the sync workflow on every run. Structure: `upstream/main` + one
  merge commit per `[[patches]]` entry, in manifest order.
- **`fix/*`, `chore/*` patch branches** — each holds one logical change.
  Branched off `upstream/main` (some are stacked on each other). The
  manifest references them by name.
- **`main`** — fork mirror of `upstream/main`. Kept up to date but is
  not the default branch.

## Adding or changing a patch

1. Create the branch off `upstream/main`:

   ```sh
   git fetch upstream main
   git checkout -b fix/my-patch upstream/main
   # ... commit your changes ...
   git push origin fix/my-patch
   ```

2. Add an entry to `.github/personal-patches.toml` on `personal-config`:

   ```toml
   [[patches]]
   name = "my-patch"
   branch = "fix/my-patch"
   description = "one-line summary, used in the merge commit message"
   # upstream_pr = "https://github.com/gastownhall/gascity/pull/NNNN"  # optional
   ```

3. Push `personal-config`. The push triggers the sync workflow, which
   rebuilds `personal/main` and republishes the rolling release.

## Removing a patch

Delete its `[[patches]]` block in `.github/personal-patches.toml` and
push. Next sync rebuild will not include it.

## Triggering a rebuild manually

```sh
gh workflow run "Sync personal/main from upstream"
# or with dry-run preview:
gh workflow run "Sync personal/main from upstream" -f dry_run=true
```

The default branch is `personal-config`, so `gh workflow run` finds the
workflow without `--ref`. Check the run's step summary for the patch
table (`OK` / `WARN` / `CONFLICT` per patch).

## Dropping a patch absorbed upstream

The sync workflow detects when a patch's branch has an empty diff
against its merge-base (i.e. upstream merged the same change). It
prints a `WARN` entry in the run summary saying "branch absorbed by
upstream — drop from manifest." When you see that:

1. Verify upstream actually has the equivalent commit.
2. Delete the `[[patches]]` block in the manifest.
3. Push `personal-config`.

The patch branch itself can stay or be deleted — the manifest is the
only authority.

## Sync conflicts

If a patch branch conflicts with another patch's merge into
`personal/main`, the sync workflow logs `CONFLICT` for that patch and
exits non-zero. To fix:

- Rebase the patch branch onto a base that already includes the
  conflicting change (often `upstream/main` is enough; sometimes
  `fix/<dep>` if your patch genuinely depends on another), OR
- Edit the patch branch to remove the conflicting hunk.

Force-push the branch and re-run sync.

## Workflow internals

`personal-sync.yml` runs as two jobs:

- **`rebuild`** — checks out `personal-config`, fetches `upstream/main`,
  reads the manifest, stages a fresh branch `personal-main-staging` from
  `upstream/main`, merges each manifest entry with `--no-ff`, and
  force-pushes onto `personal/main`. Produces a step-summary table.
- **`build`** — `needs: rebuild`, checks out the rebuilt `personal/main`,
  cross-compiles four binaries (`linux`/`darwin` × `amd64`/`arm64`),
  publishes the rolling `personal-latest` GitHub Release, and dispatches
  to `dstengle/devcontainer-python-node-claude` via the
  `DEVCONTAINER_DISPATCH_TOKEN` secret to rebuild the dev image.

`dry_run=true` runs `rebuild` but skips both the push and the entire
`build` job — useful for previewing what a manifest change will produce
before pushing.

## Installing the binary

```sh
curl -fsSL https://raw.githubusercontent.com/dstengle/gascity/personal-config/scripts/install.sh | sh
```

Detects OS/arch, downloads from `personal-latest`, installs to
`/usr/local/bin/gc`. Override with `GC_INSTALL_DIR` or pin with
`GC_VERSION`.
