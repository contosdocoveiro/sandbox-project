# Versioning and releases

The version lives in two places and both must always agree:

- `version.txt` — used by CI and release naming
- `project.godot` → `application/config/version` — available in-game via `ProjectSettings.get_setting("application/config/version")`

The PR workflow fails if they drift.

## One-time repository setup

Create the release labels once (Settings → Labels, or with an account that can write to the repo):

```bash
gh label create major --color B60205 --description "Major version bump"
gh label create minor --color FBCA04 --description "Minor version bump"
gh label create patch --color 0E8A16 --description "Patch version bump (default)"
gh label create skip-release --color 6A737D --description "Merge without a release"
```

Only `major` and `minor` are strictly required; an unlabeled PR falls back to a patch bump.
The `main` branch must also allow `github-actions[bot]` to push the version commit. If you add
branch protection, grant that bot push access (or switch to a personal access token).


## Release labels

Every PR merged into `main` produces a release, driven by one label on the PR:

| Label | Result |
| --- | --- |
| `major` | `1.2.3` → `2.0.0` |
| `minor` | `1.2.3` → `1.3.0` |
| `patch` | `1.2.3` → `1.2.4` (default) |
| `skip-release` | No tag, no release |

### First release

No `v*` tags exist yet, so the first merge publishes `v0.1.0` exactly as written in `version.txt`
instead of bumping it. Every merge after that bumps normally.

## What happens when a PR is merged into `main`

1. The workflow reads the labels of the merged PR.
2. It bumps `version.txt` and `project.godot`, commits as `github-actions[bot]`
   (`chore(release): vX.Y.Z [skip ci]`) and pushes the commit with an annotated `vX.Y.Z` tag.
3. It exports the Windows build with Godot 4.7.2, packaging `teste.exe` into
   `sandbox-project-vX.Y.Z-windows-x86_64.zip`.
4. It creates the GitHub Release (with generated notes) and attaches the zip.

Pull requests get a preview build instead: the **PR Build** workflow exports the same preset and
uploads a zip as a workflow artifact for 14 days. It does not publish anything.

## Where the version bump can fail

The release job pushes a commit to `main`. If `main` has branch protection that blocks
`github-actions[bot]`, the push fails and no tag is created. Either allow the bot to push or switch
to a tag-only flow (`version.txt` updated by the PR author instead).

Reruns after a partial failure: if `vX.Y.Z` already exists, the job refuses to move the tag and
stops, so the release never silently overwrites a previous version.

## Builds

- Engine pin: `4.7.2-stable` (`GODOT_VERSION` in both workflows and the default in
  `.github/actions/setup-godot/action.yml`). Update those together when upgrading Godot.
- Export preset: `Windows Desktop` in `export_presets.cfg`, single embedded `.pck`, x86_64.
- CI does a headless import first and fails on `SCRIPT ERROR` lines, then exports the release build.

## Manual build

On Windows, with Godot 4.7.2 and export templates installed:

```powershell
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" "build/windows/teste.exe"
```

The exe is self-contained (PCK embedded), so it can be zipped and shared as-is.
