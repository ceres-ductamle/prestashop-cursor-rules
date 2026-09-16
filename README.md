# Cursor AI rules — canonical folder

This folder is the single source of truth for Cursor AI rules that apply to
every PrestaShop module and PrestaShop-adjacent repo living under
`C:\Users\Windows 10\projects\prestashop\`.

## How it works

1. Edit the `.mdc` files in this folder.
2. Run the sync (see **Common commands** — use **cmd** or **PowerShell**).
3. The script copies (not symlinks) each `.mdc` file into every matching
   repo's `.cursor\rules\` folder. Each repo carries its own copy so the
   rules travel through `git` and work for teammates.

Rules are scoped by the `globs:` / `alwaysApply:` fields inside each `.mdc`
file. A repo that never matches the glob (e.g. a PrestaShop core source dir
with no `translations/*.php`) sees the rule as a no-op.

## Rules shipped today

All rules use the **`module-{topic}.mdc`** prefix (`alwaysApply: true` where noted).

| File | What it enforces |
|---|---|
| `module-changelog.mdc` | Diff vs `origin/master` before editing `CHANGELOG.txt` |
| `module-optimize.mdc` | Branch diff review; consolidate, dedupe, remove dead code |
| `module-ignore-vendor.mdc` | Never edit, commit, or search `vendor/` |
| `module-php.mdc` | PHP 7.4 → 8.x syntax and runtime |
| `module-prestashop.mdc` | PS 1.7 → 9.x API, `version_compare`, templates |
| `module-header-license.mdc` | Feed.biz / OSL stub license headers |
| `module-security.mdc` | Tokens on cron/AJAX; module controllers; uploads |
| `module-paths.mdc` | `_PS_*` constants; cache / `var/modules` writable dirs |
| `module-input.mdc` | `Validate` + BO form success/error feedback |
| `module-sql.mdc` | SQL injection; `bqSQL`/`pSQL`; Db helpers; schema DDL |
| `module-logging.mdc` | Module logger; no `var_dump` / `dd` |
| `module-translations.mdc` | md5 keys; EN/FR/ES parity; `l()` usage |
| `module-upgrade.mdc` | `upgrade-<version>.php`; no auto version bump |
| `module-documentation.mdc` | Scan `documentation/` / `document/` before API or third-party work |
| `module-ignore-seller-partner.mdc` | Amazon only: never customize `classes/seller_partner/`; build overwrites it |

### How module rules fit together

```
module-documentation (read local API specs) — before external API work
module-input → module-security → module-sql → Db / API
module-paths (file locations) — independent
module-php + module-prestashop (language / platform) — all PHP edits
```

Each concern has one file. Cross-references only — no duplicated content.

**Project-specific rules** (e.g. Octopia proxy, one marketplace's cite format) belong in that repo's own `.cursor/rules/` — not in this canonical folder. The sync script only copies rules from `_cursor-rules`; it does not delete extra `.mdc` files that exist only in a single repo.

## Per-rule overrides

Most canonical rules go to **all** target repos. Use `$ExcludeByRule` / `$IncludeByRule` in `sync-rules.ps1` only when a rule must be scoped to specific repos.

Current repo-scoped rule:

- `module-ignore-seller-partner.mdc` -> `Prestashop-Amazon`, `Prestashop-SAAS-Module`

Retired filenames are listed in `$ObsoleteRules`.

## Common commands

Run from **`_cursor-rules`** (where the sync scripts live), **or** from the
parent `prestashop\` folder via the wrapper (see Troubleshooting).

### Command Prompt (cmd)

In **cmd**, `.\sync-rules.ps1` opens **Notepad** — cmd cannot execute `.ps1` files.
Use the `.cmd` launcher (calls **PowerShell 7 / pwsh**):

```bat
cd C:\Users\Windows 10\projects\prestashop\_cursor-rules

sync-rules.cmd
sync-rules.cmd -DryRun
sync-rules.cmd -Target Prestashop-Cdiscount
```

From `prestashop\`: `sync-cursor-rules.cmd`

### PowerShell

```powershell
cd C:\Users\Windows 10\projects\prestashop\_cursor-rules

.\sync-rules.ps1 -DryRun
.\sync-rules.ps1
.\sync-rules.ps1 -Target Prestashop-Cdiscount
.\sync-rules.ps1 -Target Prestashop-Cdiscount, PrestaShop-Cdiscount-Modern
```

From `prestashop\`:

```powershell
.\sync-cursor-rules.ps1
.\sync-cursor-rules.ps1 -Target Prestashop-Cdiscount
```

## Troubleshooting

### `.\sync-rules.ps1` opens Notepad (or does nothing)

You are in **Command Prompt (cmd)**, not PowerShell. Cmd cannot run `.ps1` files;
Windows opens them in Notepad.

Use:

```bat
sync-rules.cmd
```

Do **not** use plain `powershell -File` if your default Windows PowerShell is 2.x
(the script needs `Get-FileHash`, available in PowerShell 7+). The `.cmd` file
uses `pwsh` when installed.

Manual run with PowerShell 7:

```bat
pwsh -NoProfile -ExecutionPolicy Bypass -File sync-rules.ps1
```

### `.\sync-rules.ps1` is not recognized

You are not in `_cursor-rules`. Either:

```powershell
cd C:\Users\Windows 10\projects\prestashop\_cursor-rules
.\sync-rules.ps1
```

or use the parent wrapper:

```powershell
cd C:\Users\Windows 10\projects\prestashop
.\sync-cursor-rules.ps1
```

Full path always works:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Windows 10\projects\prestashop\_cursor-rules\sync-rules.ps1"
```

### Script is disabled (execution policy)

Use `sync-cursor-rules.cmd` or add `-ExecutionPolicy Bypass` to the `powershell -File` command (see above). Signing is not required for local scripts with `RemoteSigned` if you run from `_cursor-rules` with `.\sync-rules.ps1` in PowerShell 7+ / Windows PowerShell from that folder.

## Adding a new rule

1. Add `module-<topic>.mdc` in this folder.
2. YAML frontmatter: `description`, `globs` or `alwaysApply`.
3. Run `.\sync-rules.ps1`.

## Removing / renaming a rule

1. Delete or rename the `.mdc` in this folder.
2. Add the old filename to `$ObsoleteRules` in `sync-rules.ps1` so sync removes it from all repos.
3. Re-run `.\sync-rules.ps1`.
