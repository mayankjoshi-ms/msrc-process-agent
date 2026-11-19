---
name: msrc-process-agent
description: Self-sufficient end-to-end MSRC process agent for USO security fixes across all supported platforms (undocked and docked). Handles IcM intake, code porting, containment metadata, bug field management, PR creation, build, validation, and duplicate verification.
version: 2026.11.19.3
---

# MSRC Process Agent

Use this skill when the user says `msrc-process-agent`, asks to backport an MSRC fix, port a security fix to downlevel branches, ship an MSRC across platforms, create MSRC PRs for multiple platforms, manage MSRC task group bugs, or close/duplicate MSRC platform bugs.

This skill is **self-sufficient**. It does not depend on any preloaded skill. It may delegate to available repo-level skills (`uso-vm-testing`, `uus-change-tracker`, `dosvc-coding`) when they are present, but functions fully without them.

---

## 1. Core Principles

1. **Never assume** — if unsure about anything, confirm with the user. Never silently pick a default.
2. **Never skip steps** — every step must execute or be explicitly flagged as blocked/skipped with a reason.
3. **All bug writes require approval** — dry run → user reviews → user approves → execute. No exceptions.
4. **Triple-consistency** — branch version == containment Release field == bug Release field. Flag any mismatch.
5. **Clean screen UX** — show only a rotating progress spinner and a random tech joke. No "Thinking...", "Thought for X sec", raw shell commands, or verbose tool output.
6. **Surgical changes** — make focused, minimal code changes. Do not refactor unrelated code.
7. **Verify before declaring done** — build must pass, fix must be validated on a VM using full repro.
8. **PR format is mandatory** — ALL PR titles and descriptions MUST follow §19 format. No exceptions. No custom sections, no HTML. This is non-negotiable when this skill is loaded.
9. **PRs must be complete on creation** — A PR is NEVER created without ALL of the following, even if it's a draft:
   - ✅ Title in `[<branch>] <description> (MSRC <ID>)` format
   - ✅ Full Markdown description with all 3 sections (Why/What/How)
   - ✅ IcM link in the description (`https://portal.microsofticm.com/imp/v5/incidents/details/<ID>/summary`)
   - ✅ Platform bug linked to the PR (`az repos pr work-item add`)
   If ANY of these cannot be completed, do NOT create the PR — flag the blocker to the user instead.
   - ⛔ Do NOT add reviewers — the user will add reviewers manually.

---

## 1b. Version Check

**Loaded version**: read from `version:` in the YAML front matter above (e.g., `2026.11.17.1`).

### When to check

Run a version preflight **before any bulk write operation** — filling multiple bug templates, closing multiple bugs, creating multiple PRs, or any batch that modifies ≥ 2 ADO work items.

### How to check

```
1. Read the skill file on disk:
   Path: C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md
   Extract the `version:` line from the YAML front matter.

2. Compare disk version to loaded version (from this document's front matter).

3. If versions DIFFER:
   ⚠️ STOP — tell the user:
   "Skill has been updated (loaded: <old>, disk: <new>). Please reload the skill
    before proceeding — say 'load msrc-process-agent' to get the latest version."
   Do NOT proceed with the bulk write.

4. If versions MATCH:
   ✅ Proceed normally.
```

### Version format

`YYYY.MM.DD.N` — date of last update + revision number (N starts at 1, increments for same-day updates).

### Updating the version

**Every time the skill file is edited**, the `version:` field in the front matter MUST be bumped:
- Same day as previous version → increment N (e.g., `2026.11.17.1` → `2026.11.17.2`)
- Different day → reset to `<today>.1` (e.g., `2026.11.18.1`)

This is part of the sync protocol (alongside git commit + push + copy to runtime dir).

---

## 2. UX Requirements

### What to show
```
⠋ Building orchestrator (x64 debug)...
   💡 Why do programmers prefer dark mode? Because light attracts bugs.
```

- A rotating spinner character (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏) with a short status message.
- A random tech joke from the joke pool below each status line.
- Clean progress updates when a phase starts or completes.
- Final summary tables with clear formatting.

### What to NEVER show
- "Thinking...", "Thought", "Thought for 1 sec", "Processing...", or any meta-reasoning output.
- Raw shell commands, PowerShell scripts, or `az boards` calls.
- Failed command attempts or retry noise.
- Internal tool call details or JSON blobs.
- Verbose build/test output (summarize pass/fail only).

### Tech Joke Pool
```
"Why do programmers prefer dark mode? Because light attracts bugs."
"There are only 10 types of people — those who understand binary and those who don't."
"A SQL query walks into a bar, sees two tables, and asks... 'Can I JOIN you?'"
"!false — it's funny because it's true."
"Why do Java developers wear glasses? Because they can't C#."
"What's a programmer's favorite hangout place? Foo Bar."
"Algorithm: a word used by programmers when they don't want to explain what they did."
"It works on my machine. — Every developer, ever."
"To understand recursion, you must first understand recursion."
"The best thing about a boolean is that even if you're wrong, you're only off by a bit."
"A programmer's wife tells him: 'Go to the store and buy a loaf of bread. If they have eggs, buy a dozen.' He comes home with 12 loaves."
"Debugging: being the detective in a crime movie where you're also the murderer."
"99 little bugs in the code, 99 little bugs. Take one down, patch it around... 127 little bugs in the code."
"I would tell you a UDP joke, but you might not get it."
"TCP joke: Would you like to hear a TCP joke? Yes, I'd like to hear a TCP joke. OK, I'll tell you a TCP joke. OK, I'll hear a TCP joke. ... Are you ready to hear a TCP joke? Yes..."
```

Rotate through these randomly. Never repeat the same joke consecutively.

---

## 3. Dependencies

### Must-Have (hard block if missing)

| Dependency | Check Command | Setup Instructions |
|---|---|---|
| **git CLI** | `git --version` | Install Git for Windows from https://git-scm.com |
| **az CLI + devops extension** | `az version` and `az extension show --name azure-devops` | Install: https://aka.ms/install-az-cli then `az extension add --name azure-devops` and `az login` |
| **VPN** (for IcM only) | Test connectivity to `portal.microsofticm.com` | Connect to Microsoft corporate VPN before IcM operations |

### Must-Have for IcM Work

| Dependency | Check | Workaround if missing |
|---|---|---|
| **icm-mcp MCP server** | Check if `icm-mcp-get_incident_details_by_id` tool is available | Ask user to provide IcM details manually (severity, MSRC ID, assessment status, task group ID) |

### Optional (fall back gracefully)

| Dependency | Used For | Fallback |
|---|---|---|
| **Bluebird MCP** | Code search, navigation | Use `grep`/`glob`/`view` directly |
| **uso-vm-testing skill** | Deploy binaries to test VM | Ask user to deploy manually and provide results |
| **uus-change-tracker skill** | Track CI builds | Ask user to check CI manually |
| **containment-copilot MCP** | Containment metadata generation | Generate containment manually using known patterns |
| **Build tools** (dazzle.ps1, MSBuild) | Building code | Prompt user with build instructions |

### Startup Dependency Check

On skill activation, check all must-have dependencies. For each:
- **Present** → ✅ silently continue
- **Missing** → 🛑 hard block with exact setup instructions, then stop

For optional dependencies:
- **Present** → ✅ silently use
- **Missing** → silently fall back, no warning unless the user requests a feature that needs it

### VPN Check

Before ANY IcM call, verify VPN connectivity:
```
Test-NetConnection portal.microsofticm.com -Port 443 -InformationLevel Quiet
```
If VPN is down, tell the user: "⚠️ VPN connection required for IcM access. Please connect to corporate VPN and retry."

---

## 4. Platform Support Matrix

### Main OS Platforms

| Platform | ADO Product | Repo | Branch Pattern | Status |
|---|---|---|---|---|
| **Main** | OS | uus | `main` | ✅ Supported |
| **GE** | Windows (Ge) | uus | `release/v15/XXXXb_ge` or `release/v15/XXXXb_gebr` | ✅ Supported — check remote branch |
| **GE-LT** | Windows (Ge) LT | uus | `release/v15/XXXXb_lt` | ✅ Supported |
| **NI** | Windows 11 22H2 | uus | `release/v14/XXXXb_ni` | ✅ Supported |
| **BR** | Windows (Br) | uus | `release/v15/XXXXb_br` or covered by `*_gebr` | ✅ Supported — check remote branch |
| **FE** | Windows Server 2022 | os.2020 | `official/fe_release_svc_XXXXb` | ✅ Supported (docked) |
| **VB** | Windows 10 2004 | os.2020 | `official/vb_release_svc_XXXXb` | ✅ Supported (docked) |
| GE Hotpatch | Windows (Ge) Hotpatch | — | — | ❓ Unknown — ask user |
| GE-LT Hotpatch | Windows (Ge) LT Hotpatch | — | — | ❓ Unknown — ask user |
| Server 2022 Hotpatch | Windows Server 2022 Hotpatch | — | — | ❓ Unknown — ask user |
| Windows 8.1 | — | — | — | ❌ Not supported |
| Windows 10 1607 | — | — | — | ❌ Not supported |
| Windows 10 1809 | — | — | — | ❌ Not supported |
| Windows Server 2012 | — | — | — | ❌ Not supported |

### SafeOS DU Platforms

| Platform | ADO Product | Status |
|---|---|---|
| **GE** SafeOS | Windows (Ge) | ✅ Supported |
| **GE-LT** SafeOS | Windows (Ge) LT | ✅ Supported |
| **NI** SafeOS | Windows 11 22H2 | ✅ Supported |
| **BR** SafeOS | Windows (Br) | ✅ Supported |
| **FE** SafeOS | Windows Server 2022 | ✅ Supported |
| **VB** SafeOS | Windows 10 2004 | ✅ Supported |
| Win 10 1607 SafeOS | — | ❌ Not supported |
| Win 10 1809 SafeOS | — | ❌ Not supported |

**Notes:**
- No SafeOS DU for Main.
- For ❌ platforms, skip them silently and note as "not applicable for USO".
- For ❓ platforms, ask user before proceeding.
- Unsupported platform bugs should be closed as **Won't Fix** (with user approval).

---

## 5. Containment Format Reference

### Undocked (Main, GE, GE-LT, NI, BR) — `.featurestaging` XML

- **File**: `src/common/featurestaging-UndockedUpdateStack-MSRC.featurestaging`
- All MSRC features in ONE shared file.
- Include header: `"FeatureStaging-UndockedUpdateStack-MSRC.h"`

> **`{{alias}}`** in templates below = the user's ADO alias, resolved from `git config user.email` (strip `@microsoft.com`). See §6 for the extraction command. The email in containment files MUST be `<alias>@microsoft.com`.

**Main branch** entry:
```xml
<feature>
  <className>Feature_MSRCXXXXXX</className>
  <id>MSRCXXXXXX</id>
  <name>Feature_MSRCXXXXXX</name>
  <description>MSRC XXXXXX fix</description>
  <stage>AlwaysDisabled</stage>
  <enabledByDefaultBranchTokens>
    <branchToken>main</branchToken>
    <branchToken>user/.*</branchToken>
    <branchToken>feature/.*</branchToken>
    <branchToken>pull/.*</branchToken>
  </enabledByDefaultBranchTokens>
  <email>{{alias}}@microsoft.com</email>
  <changeTime>OnReboot</changeTime>
</feature>
```

> **⚠️ `<changeTime>` accepts ONLY `OnRead`, `OnReload`, or `OnReboot`** (schema-enforced regex `\s*(OnRead|OnReload|OnReboot)\s*`). Do NOT use timestamps — builds will fail with schema validation errors. All existing entries use `OnReboot`.

**Downlevel branch** entry (GE, GE-LT, NI, BR):
```xml
<feature>
  <className>Feature_MSRCXXXXXX</className>
  <id>MSRCXXXXXX</id>
  <name>Feature_MSRCXXXXXX</name>
  <description>MSRC XXXXXX fix</description>
  <stage>EnabledByDefault</stage>
  <!-- NO enabledByDefaultBranchTokens for downlevel -->
  <email>{{alias}}@microsoft.com</email>
  <changeTime>OnReboot</changeTime>
</feature>
```

**Critical rules:**
- Main = `AlwaysDisabled` + branch tokens
- Downlevel = `EnabledByDefault`, NO branch tokens
- Bug ID in the `<id>` field must be the real ADO bug ID for that platform (NOT a placeholder)

### Docked (FE, VB) — JSON

- **File**: `onecore/base/wil/containment/security/Feature_MSRCXXXXXX.json`
- One file PER MSRC containment key.
- Include header: `<featurestaging-servicing-security.h>` (consolidated)

```json
{
  "owner": "{{alias}}@microsoft.com",
  "team": "USO-Update Session Orchestrator",
  "MSRCCaseId": "XXXXXX",
  "className": "Feature_MSRCXXXXXX",
  "BugId": 12345678,
  "Binary": ["usosvcimpl.dll", "MoUsoCoreWorker.exe"],
  "Description": "MSRC XXXXXX fix description",
  "Release": "RELXXXX",
  "Notes": []
}
```

**Critical rules:**
- `Release` must match the target branch version (e.g., branch `2610b` → `REL2610`)
- `BugId` must be the real ADO bug ID for that platform (number, not string)
- Source paths use `onecore/enduser/WindowsUpdate/muse/orchestrator/...`

### Containment Entry Validation Checklist (MANDATORY)

> **⚠️ Before committing ANY containment entry, verify EVERY field below. The MSRC-156290 session omitted `<changeTime>` and caused a build failure. This checklist prevents that.**

**XML (undocked) — every `<feature>` block MUST have ALL of these:**

| # | Field | Required Value | Common Mistake |
|---|---|---|---|
| 1 | `<className>` | `Feature_MSRCXXXXXX` | Wrong MSRC ID |
| 2 | `<id>` | `MSRCXXXXXX` | Using placeholder instead of real ID |
| 3 | `<name>` | `Feature_MSRCXXXXXX` | Mismatch with className |
| 4 | `<description>` | Non-empty | Left blank |
| 5 | `<stage>` | `AlwaysDisabled` (main) or `EnabledByDefault` (downlevel) | Swapped main/downlevel |
| 6 | `<enabledByDefaultBranchTokens>` | Present for main, **ABSENT** for downlevel | Added to downlevel |
| 7 | `<email>` | `{{alias}}@microsoft.com` | Hardcoded wrong alias |
| 8 | `<changeTime>` | `OnReboot` | **⛔ OMITTED — most common error** |

**JSON (docked) — every `.json` file MUST have ALL of these:**

| # | Field | Required Value | Common Mistake |
|---|---|---|---|
| 1 | `owner` | `{{alias}}@microsoft.com` | Hardcoded wrong alias |
| 2 | `className` | `Feature_MSRCXXXXXX` | Wrong MSRC ID |
| 3 | `BugId` | Real ADO bug ID (number) | String or placeholder |
| 4 | `Binary` | Array of affected DLLs | Empty array |
| 5 | `Release` | `RELXXXX` matching branch | Wrong release code |

**Self-check procedure — run mentally before every `git add`:**
```
For each <feature> block I just wrote:
  ☐ className, id, name all use the correct MSRC ID
  ☐ stage is correct for this branch type (main vs downlevel)
  ☐ branch tokens present for main, absent for downlevel
  ☐ email uses {{alias}} (resolved), not hardcoded
  ☐ <changeTime>OnReboot</changeTime> is PRESENT (not omitted!)
  ☐ No extra whitespace or typos in tag names
```

---

## 6. Branch & Reviewer Mapping

### Topic Branch Naming

**Format:**
```
user/<alias>/msrc-<MSRC-ID>-<short-description>
```

**Rules:**
- `<alias>` — your ADO alias, extracted from git config email (see below)
- `<MSRC-ID>` — numeric MSRC case ID (e.g., `170271`)
- `<short-description>` — 2-4 lowercase words separated by hyphens describing the fix. Keep it brief but meaningful.
- All lowercase, no spaces, no special characters except hyphens

**How to get the alias:**
```powershell
# Extract alias from git user.email (e.g., "mayajoshi@microsoft.com" → "mayajoshi")
$alias = (git config user.email) -replace '@.*$', ''
```
If `git config user.email` is empty or not set, fall back to:
```powershell
$alias = $env:USERNAME
```

**Examples:**
```
user/mayajoshi/msrc-170271-authz-check
user/mayajoshi/msrc-163522-wil-use-after-free
user/mayajoshi/msrc-120495-junction-info-disclosure
user/mayajoshi/msrc-131462-null-deref-fix
```

**Same branch name across all platform repos** — when porting to GE, LT, NI etc., use the **same branch name** in every repo:
```
E:\uus       → user/mayajoshi/msrc-170271-authz-check
E:\uus-ge    → user/mayajoshi/msrc-170271-authz-check
E:\uus-lt    → user/mayajoshi/msrc-170271-authz-check
E:\uus-ni    → user/mayajoshi/msrc-170271-authz-check
```

### Reviewer Groups

**Undocked (Main, GE, GE-LT, NI, BR):**
| Reviewer | Required? |
|---|---|
| `[TEAM FOUNDATION]\UUS Containment Champs` | ✅ Required (all) |
| `[OS]\USO-Update Session Orchestrator` | ✅ Required (all) |
| `[TEAM FOUNDATION]\UUS Pull Requests` | ✅ Required (all) |
| `[TEAM FOUNDATION]\UUS CD Approvals` | ✅ Required (downlevel only — NOT main) |
| Leonardo Stabile Prates | Optional |
| Rahul Varanasi | Optional |
| Disha Patel | Optional |
| Santosh Kumar Patil | Optional |
| WSD UP IDC LT | Optional |
| IDC_XIS_USO_WU | Optional |

**Docked (FE, VB):**
| Reviewer | Required? |
|---|---|
| `[OS]\MSRC Servicing Containment Champs` | ✅ Required |
| `[OS]\USO-Update Session Orchestrator` | ✅ Required |
| Leonardo Stabile Prates | Optional |
| Rahul Varanasi | Optional |
| Disha Patel | Optional |
| Santosh Kumar Patil | Optional |
| WSD UP IDC LT | Optional |
| IDC_XIS_USO_WU | Optional |

---

## 7. ADO Bug Field Requirements

### Required Fields for MSRC Bugs

| Field | ADO API Name | Value |
|---|---|---|
| Release | `Microsoft.VSTS.Common.Release` | Downlevel: `YYYY.MM B`; Main: current codename |
| How Found | `Microsoft.VSTS.CMMI.HowFound` | `Security: MSRC` |
| Binary Filename | `OSG.Loc.BinaryFilename` | Affected binaries (e.g., `usosvcimpl.dll`) |
| LOC Impact | `OSG.LocImpact` | `No` |
| Regression | `Microsoft.VSTS.Common.Regression` | `No` |
| Update Type | `OSG.UpdateType` | `Cumulative` (downlevel only) |
| Tags | `System.Tags` | Must include: `ComplianceProtocolClean`, `KIR_Opt_In` |
| Repro Steps | `Microsoft.VSTS.TCM.ReproSteps` | Security Bug Case Approval Template (HTML) |
| Product | `OSG.Product` | Platform-specific product name (see platform matrix) |
| Product Family | `OSG.ProductFamily` | `Windows` (Main) or `Windows Servicing` (downlevel) |

### Security Bug Case Approval Template Sections
The ReproSteps field MUST use the **"Servicing - Security Bug Case Approval Template"** HTML table format. Do NOT use plain HTML headings (`<h2>`, `<h3>`) — the content must be inside a 2-column HTML table.

**⚠️ CRITICAL FORMATTING RULES (learned from reference bug 62575488, confirmed working in bug 64861567 Rev 15):**
1. **Never** use `<h2>`, `<h3>`, `<ul>/<li>` tags — ADO renders them inconsistently
2. Use `<div>` tags for each paragraph/line of content inside right `<td>` cells
3. Use `<br>` inside `<div>` for line breaks between paragraphs: `<div><br></div>`
4. Use literal `•` character (U+2022) for bullet points, each in its own `<div>`
5. Use `&nbsp;` around inline code identifiers (e.g., `&nbsp;FunctionName()&nbsp;`)
6. Use `<b>` for bold text and sub-headings within a section
7. Use numbered steps (1, 2, 3...) in `<div>` tags for attack scenario repro steps
8. The ENS section header must be **"ENS-Specific Sec Questions"** (not "ENS-Specific")
9. Wrap ALL label text in `<p>` with Aptos font: `<p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">`

**⚠️ CRITICAL CSS RULES (these exact styles are required — ADO drops rows with wrong borders):**

| Cell type | CSS style |
|-----------|-----------|
| **Header row** (template title) | `border:1pt solid windowtext;background:gray;padding:0cm;` |
| **Version row** | `border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;` |
| **Section separator** (Case Details) | Same as version row + `background:rgb(221, 221, 221);` |
| **Section separator** (Comms, ENS) | Same as version row + `background:rgb(204, 204, 204);` |
| **Label cell** (left `<td>`, internal rows) | `border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;` |
| **Content cell** (right `<td>`, internal rows) | `border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;` |

**Required table structure (exact CSS — do NOT simplify to `border:1pt solid windowtext`):**

```html
<table width="100%" style="border-collapse:collapse;">
  <thead>
    <tr><td colspan=2 style="border:1pt solid windowtext;background:gray;padding:0cm;">
      <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
        <b><span style="color:black;">Servicing - Security Bug Case Approval Template</span></b>
      </p>
    </td></tr>
    <tr><td colspan=2 style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
      <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">Version 2022.1.04</p>
    </td></tr>
  </thead>
  <tbody>
    <!-- Case Details separator -->
    <tr><td colspan=2 style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;background:rgb(221, 221, 221);padding:0cm;">
      <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
        <b><span style="color:black;">Case Details</span></b>
      </p>
    </td></tr>

    <!-- Label + Content row pattern -->
    <tr>
      <td style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;"><b>Attack Scenario</b></p>
      </td>
      <td style="border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;">
        <div>Content using div tags...</div>
        <div><br></div>
        <div>• Bullet point using literal • character</div>
      </td>
    </tr>

    <!-- Fix Description, Validation, Variant Analysis follow same pattern -->

    <!-- Changes Outside Component Area (3-column sub-table per official template) -->
    <tr>
      <td style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;"><b>Changes Outside Component Area</b></p>
      </td>
      <td style="border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
          If there are dependencies or impact to other components, please list them here:
        </p>
        <table style="border-collapse:collapse;"><tbody>
          <tr>
            <td style="border:1pt solid windowtext;padding:0cm;">
              <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">Component Area</p>
            </td>
            <td style="border-width:1pt 1pt 1pt medium;border-style:solid solid solid none;border-color:windowtext windowtext windowtext currentcolor;padding:0cm;">
              <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">Component Duo/Lead Signoff</p>
            </td>
            <td style="border-width:1pt 1pt 1pt medium;border-style:solid solid solid none;border-color:windowtext windowtext windowtext currentcolor;padding:0cm;">
              <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">Nature of changes in this component</p>
            </td>
          </tr>
          <!-- Data rows use same border pattern as main table internal rows -->
        </tbody></table>
      </td>
    </tr>

    <!-- Regression -->
    <tr>
      <td style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
          <b>Regression: &quot;Affected By&quot; Bug and Rationale</b>
        </p>
      </td>
      <td style="border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">No</p>
      </td>
    </tr>

    <!-- Comms separator -->
    <tr><td colspan=2 style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;background:rgb(204, 204, 204);padding:0cm;">
      <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
        <b><span style="color:black;">Comms</span></b>
      </p>
    </td></tr>

    <!-- Release notes -->
    <tr>
      <td style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
          <b>Release notes (if Rel Note field == Yes)</b>
        </p>
      </td>
      <td style="border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;"></td>
    </tr>

    <!-- ENS separator -->
    <tr><td colspan=2 style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;background:rgb(204, 204, 204);padding:0cm;">
      <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">
        <b><span style="color:black;">ENS-Specific Sec Questions</span></b>
      </p>
    </td></tr>

    <!-- ENS fields (Cloud Critical?, Hot Patchable, Localization, Dependencies, Protocol Changes, Is Test Guidance filled out in TrackIt) -->
    <tr>
      <td style="border-width:medium 1pt 1pt;border-style:none solid solid;border-color:currentcolor windowtext windowtext;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;"><b>Cloud Critical?</b></p>
      </td>
      <td style="border-width:medium 1pt 1pt medium;border-style:none solid solid none;border-color:currentcolor windowtext windowtext currentcolor;padding:0cm;">
        <p style="margin:0cm 0cm 8pt;font-size:11pt;font-family:Aptos, sans-serif;">No</p>
      </td>
    </tr>
    <!-- Repeat for each ENS field -->
  </tbody>
</table>
```

**Multi-MSRC handling (learned from reference bug 62575488 with MSRCs 120495, 128733, 131096, 137811):**
- In **Attack Scenario**: give each MSRC its own bold sub-heading with vuln type:
  `<div><b>MSRC-128733 (EoP — Arbitrary File Delete):</b></div>` followed by numbered repro steps
- In **Fix Description**: label each fix separately:
  `<div><b>Fix 1 — RedirectionGuard (MSRC-120495, 128733, 131096)</b></div>`
  `<div><b>Fix 2 — Remove StateRepository (MSRC-137811)</b></div>`
- In **Validation**: list each MSRC's confirmation:
  `<div>• MSRC-128733: race no longer deletes marker files</div>`

**Content guidelines per section:**
- **Attack Scenario**: Describe vulnerability, affected code paths, numbered repro steps, privilege boundary crossed, CWE, and severity
- **Fix Description**: What was changed, containment feature names and states, files modified
- **Validation / Regression Risk**: Regression risk rationale first, then before/after bullet-point lists, then per-MSRC validation results
- **Variant Analysis**: Whether similar patterns exist in other code paths (or "No additional variants identified")
- **Changes Outside Component Area**: 3-column template table (Component Area | Duo/Lead Signoff | Nature of changes)
- **Regression: "Affected By" Bug**: Usually "No"
- **ENS-Specific Sec Questions**: Default to "No" unless explicitly known otherwise

---

## 8. Bug Modification Policy

### Golden Rule
**ALL writes to ANY bug field require explicit user approval via the `ask_user` tool with a dry run preview.**

> **⚠️ A user's chat message requesting a change (e.g., "close those bugs") is the REQUEST, NOT the approval. You MUST still show a dry run and collect approval via `ask_user` before executing. MSRC-181704 violated this by treating "hotpatch bugs too, close them" as implicit approval and going straight to ADO API calls.**

> **⚠️ If the user declines or cancels the `ask_user` form and then asks again (even with a broader or narrower scope), you MUST present a NEW `ask_user` approval form for the updated scope. Never carry forward a cancelled approval.**

### Workflow for ANY Bug Write
```
1. User explicitly asks for a bug field change (this is the REQUEST)
2. Skill shows dry run table with all proposed changes
3. Skill calls `ask_user` tool with approval form (this is the APPROVAL gate)
   - The `ask_user` form MUST list every bug ID and the exact field changes
   - Include a "Make no changes" option
4. User approves via `ask_user` → skill executes the change
5. User declines/cancels `ask_user` → skill does NOTHING
6. User asks again (same or different scope) → go back to step 2 (new dry run + new ask_user)
```

**❌ WRONG (what MSRC-181704 did):**
```
User: "close those bugs"
Skill: *immediately calls ADO API to close bugs*
```

**✅ CORRECT:**
```
User: "close those bugs"
Skill: "Here's what would change:" → dry run table → ask_user approval form
User: approves via ask_user
Skill: executes the changes
```

### Triage Field
- **Only** allowed value: `Consider by Triad Shiproom`
- No other triage state is ever set by this skill.
- Only when user explicitly asks.
- Dry run + approval required.

### Resolve → Fixed
All three conditions must be met:
1. Bug's triage field shows shiproom approval (`Approved by Triad Shiproom` or `Approved by Central Shiproom`)
2. PR for that platform is merged
3. User explicitly asks to resolve

Then: State = `Resolved`, Resolved Reason = `Fixed`

### Resolve → Duplicate
- Only for confirmed duplicate MSRC bugs (after duplicate verification — see §12)
- User explicitly asks
- Resolved Reason = `Duplicate`
- **Required fields** (REST API PATCH only — `az boards` CLI does NOT support this):
  1. `System.State` = `Resolved`
  2. `Microsoft.VSTS.Common.ResolvedReason` = `Duplicate`
  3. `Microsoft.VSTS.Common.DuplicateIDParent` = `<duplicate-of-bug-id>` (integer)
- All three fields must be set in a **single** `PATCH` call with `application/json-patch+json`
- For bulk duplicate resolution, use §8a parallel writes

### Close → Won't Fix
- Only for unsupported platforms (see platform matrix §4)
- User explicitly asks
- Resolved Reason = `Won't Fix`

### Things This Skill NEVER Does on Its Own
- Never initiates any bug write without being asked
- Never approves or rejects a bug
- Never changes triage to anything other than "Consider by Triad Shiproom"
- Never resolves without shiproom approval + PR merge + user request

---

## 8a. ADO Bulk Operations (Performance-Optimized)

When operating on multiple bugs (task group children, bulk resolution, etc.), use these optimized patterns instead of sequential `az boards` CLI calls.

### Batch Fetch (17x faster than sequential)

Use the batch REST API to fetch all bugs in a single HTTP call:

```powershell
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$body = @{
    ids = @(64852948, 64852946, 64852949)  # all child bug IDs
    fields = @("System.Id", "System.Title", "System.State", "OSG.Product",
               "Microsoft.VSTS.Common.ResolvedReason", "Microsoft.VSTS.Common.Release")
} | ConvertTo-Json -Depth 3
$bugs = Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/wit/workitemsbatch?api-version=7.1" `
    -Method Post -Body $body -ContentType "application/json" `
    -Headers @{ Authorization = "Bearer $token" }
```

**Benchmarked**: 22 bugs in **0.4s** (17ms/bug) vs 6.7s sequential (304ms/bug).

### Parallel Writes (55x faster than sequential)

No batch update API exists — use PowerShell runspace pools for concurrent writes:

```powershell
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
$runspacePool.Open()
$jobs = @()

foreach ($entry in $updateMap.GetEnumerator()) {
    $ps = [powershell]::Create().AddScript({
        param($bugId, $patchBody, $tkn)
        Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/wit/workitems/${bugId}?api-version=7.1" `
            -Method Patch -Body $patchBody -ContentType "application/json-patch+json" `
            -Headers @{ Authorization = "Bearer $tkn" }
    }).AddArgument($entry.Key).AddArgument($entry.Value).AddArgument($token)
    $ps.RunspacePool = $runspacePool
    $jobs += @{ Pipe=$ps; Handle=$ps.BeginInvoke() }
}

$results = foreach ($job in $jobs) { $job.Pipe.EndInvoke($job.Handle); $job.Pipe.Dispose() }
$runspacePool.Close()
```

**Benchmarked**: 22 bugs in **1.2s** (54ms/bug) vs ~66s sequential (~3s/bug).

### Duplicate Resolution Patch Body

The exact JSON Patch body for resolving as Duplicate (field name is **`Microsoft.VSTS.Common.DuplicateIDParent`** — NOT `DuplicateID` or `DuplicateId`):

```json
[
  { "op": "add", "path": "/fields/System.State", "value": "Resolved" },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Common.ResolvedReason", "value": "Duplicate" },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Common.DuplicateIDParent", "value": 64422004 }
]
```

> ⚠️ **`az boards work-item update --reason Duplicate` does NOT work** — "Duplicate" is not a valid `--reason` value.
> ⚠️ **`az boards work-item update --fields`** does NOT recognize `DuplicateIDParent` — only REST API works.

### Recommended Workflow for Bulk Operations

```
1. Batch-fetch all child bugs from BOTH task groups (2 HTTP calls)
2. Match bugs by OSG.Product field across task groups
3. Present dry run table to user (§8 Golden Rule still applies)
4. User approves → parallel-write all updates (runspace pool, 10 threads)
5. Report results: success/fail count + per-bug status
```

**Expected total time for 22-bug duplicate resolution: ~2 seconds** (vs ~2.5 minutes sequential).

---

## 8b. Fill Servicing Template Workflow

This is the step-by-step procedure for populating the **Servicing - Security Bug Case Approval Template** in a bug's ReproSteps field. It applies whether the user says "fill the bug template", "fill servicing template", "populate repro steps", or any equivalent phrasing.

### Entry Point

User provides a bug ID (or bug URL) and says "fill servicing template" (or equivalent).

### Step 1: Read the Bug

```
ADO API → GET work item by ID
Extract:
  - System.Title → MSRC ID (parse [MSRC XXXXXX] from title)
  - System.State, OSG.Product, Microsoft.VSTS.Common.Release
  - Current Microsoft.VSTS.TCM.ReproSteps → check if already populated
  - All linked work items → find linked PRs (type: "Pull Request")
```

If ReproSteps already has the template filled, **warn the user** and ask whether to overwrite or skip.

### Step 2: Determine Data Sources

**Decision tree:**

```
Has linked PR(s)?
  ├─ YES → Go to Step 3A (PR-driven)
  └─ NO
       └─ Ask user: "No PR is linked to this bug. Please either:
            1. Link a PR first and re-run, or
            2. Provide the fix details manually (what changed, files, containment feature)"
          → If user links PR → Go to Step 3A
          → If user provides details → Go to Step 3B (manual)
```

### Step 3A: PR-Driven Data Gathering

When a linked PR exists, extract fix information from it:

```
1. Read PR title, description, and diff (ADO REST API)
2. From PR description:
   - "Why" section → Attack Scenario context
   - "What" section → Fix Description details
   - "How was the change tested?" → Validation details
   - IcM link → IcM incident ID
3. From PR diff:
   - Files changed → Binary Filename, Changes Outside Component Area
   - Functions modified → Fix Description specifics
4. If PR description is empty or missing Why/What/How sections:
   - Ask user: "The PR description is empty or incomplete.
     Please add the Why/What/How sections to the PR description,
     or provide the fix details here."
   - Wait for user response before continuing.
```

### Step 3B: Manual Data Gathering (No PR)

When no PR is linked and user chooses to provide details manually:

```
Ask user for each missing piece:
1. "What is the vulnerability? (attack scenario, CWE, severity)"
2. "What was the fix? (code changes, containment feature name)"
3. "What files/binaries were changed?"
4. "How was it validated? (before/after behavior)"
5. "Any variant analysis done?"
```

### Step 4: Cross-Verify with IcM

Regardless of PR or manual path, **always** try to enrich from IcM:

```
1. Extract MSRC ID from bug title
2. Query IcM (icm-mcp) for the incident:
   - icm-mcp-search_incidents with title containing MSRC ID
   - Read incident summary → vulnerability type, CWE, severity, researcher info
3. Cross-verify: PR description attack scenario should align with IcM summary
4. If IcM data contradicts PR data → flag discrepancy to user
5. If IcM MCP is unavailable → continue with PR/manual data only, note it
```

### Step 5: Gather Containment Metadata

```
1. Query containment MCP for feature details:
   - containment-copilot-coco-mcp-get_containment_basic_information
   - Feature name, state, release vehicle
2. If containment MCP is unavailable:
   - Check PR description for containment feature mentions
   - Ask user if not found anywhere
```

### Step 6: Build the Template HTML

Using the data gathered, build the full HTML table per §7:

| Template Section | Data Source (priority order) |
|---|---|
| **Attack Scenario** | 1) IcM incident summary 2) PR "Why" section 3) User-provided |
| **Fix Description** | 1) PR diff + "What" section 2) Containment metadata 3) User-provided |
| **Validation / Regression Risk** | 1) PR "How tested" section 2) User-provided 3) Default: "Validated by building and running unit tests" |
| **Variant Analysis** | 1) PR description 2) User-provided 3) Default: "No additional variants identified" |
| **Changes Outside Component Area** | 1) PR diff (file/component list) 2) User-provided 3) Default: "None" |
| **Regression** | Default: "No" (override only if user says otherwise) |
| **Release notes** | Default: empty (unless Rel Note field == Yes) |
| **ENS fields** | Default: all "No" (unless user specifies otherwise) |

**For multi-MSRC bugs**: follow the multi-MSRC formatting rules in §7:
- Separate sub-headings per MSRC in Attack Scenario
- Labeled fixes in Fix Description
- Per-MSRC validation results

### Field Defaults During Template Fill

When filling the servicing template, the skill sets **only** these fields unless the user explicitly requests otherwise:

| Field | Action | Default |
|---|---|---|
| Repro Steps | ✅ Set | Full HTML template |
| Binary Filename | ✅ Set | From PR diff |
| LOC Impact | ✅ Set | `No` |
| Tags | ✅ Append | `ComplianceProtocolClean; KIR_Opt_In` |
| **Triage** | ⛔ **NEVER change** | Leave as-is unless user explicitly says "set triage" |
| **State** | ⛔ **NEVER change** | Leave as-is |
| **Resolved Reason** | ⛔ **NEVER change** | Leave as-is |

### Batch Template Fill (Multiple Bugs)

When filling templates for multiple bugs (e.g., all active bugs in a task group):

```
1. Batch-fetch ALL bug IDs in a single call (§8a batch fetch)
2. Group bugs by linked PR — bugs sharing a PR get the same template content
3. Read each unique PR's description + diff ONCE (not per-bug)
4. Build template HTML per unique MSRC+platform combination
5. Parallel-write all bugs via runspace pool (§8a parallel writes)
```

This avoids reading the same PR N times for N bugs linked to it.

### Step 7: Dry Run Preview

**§8 Golden Rule applies — no writes without approval.**

```
Show the user:
┌─────────────────────────────────────────────┐
│ 📝 Proposed ReproSteps Update (DRY RUN)     │
│                                              │
│ Bug: <bug-id>                                │
│ Field: Microsoft.VSTS.TCM.ReproSteps         │
│                                              │
│ Template sections filled:                    │
│  ✅ Attack Scenario (from PR + IcM)          │
│  ✅ Fix Description (from PR diff)           │
│  ✅ Validation (from PR description)         │
│  ✅ Variant Analysis (default: none)         │
│  ✅ Changes Outside Component (from PR diff) │
│  ✅ Regression (No)                          │
│  ✅ ENS fields (all No)                      │
│                                              │
│ [Show full HTML preview? y/n]                │
│ [Apply this change? y/n]                     │
└─────────────────────────────────────────────┘
```

If user asks to see the full preview, render a readable summary of each section's content (not raw HTML).

### Step 8: Apply

```
1. User approves → PATCH bug with the HTML via ADO REST API
2. Confirm: "✅ Bug <id> ReproSteps updated with servicing template"
3. If PATCH fails → show error, do NOT retry without user consent
```

### Quick Reference: What Can Be Auto-Filled vs What Needs User Input

| Section | PR Linked | No PR |
|---|---|---|
| Attack Scenario | ✅ Auto (PR + IcM) | ⚠️ IcM only, may need user |
| Fix Description | ✅ Auto (PR diff) | ❌ User must provide |
| Validation | ✅ Auto (PR desc) | ❌ User must provide |
| Variant Analysis | ⚠️ Default "none" | ⚠️ Default "none" |
| Changes Outside | ✅ Auto (PR diff) | ❌ User must provide |
| Regression | ✅ Default "No" | ✅ Default "No" |
| ENS fields | ✅ Default "No" | ✅ Default "No" |

### Edge Cases

1. **Multiple PRs linked**: Use the main/first PR; if PRs target different MSRCs, merge data from all and use multi-MSRC formatting.
2. **PR has empty description**: Ask user to fill the PR description first (preferred) or provide details manually.
3. **IcM MCP unavailable**: Continue with PR data only; note in dry run that IcM cross-verification was skipped.
4. **Bug already has template**: Warn user and ask to overwrite or skip — never silently overwrite.
5. **MSRC ID not in bug title**: Ask user for the MSRC case ID.

---

## 9. Release Targeting

### Determining the Target Release Code (XXXX)

The release code (e.g., `2701b`) determines which branches to target. **Never guess or assume the release code — always derive it from authoritative sources.**

**Priority order for determining the release code:**

1. **Bug's Release field** (most reliable) — Query any child bug from the task group:
   ```
   Microsoft.VSTS.Common.Release → e.g., "2027.01 B" → release code = 2701
   ```
   Format: `YYYY.MM B` → extract year (last 2 digits) + month (2 digits) → `YYMMb`
   - `2027.01 B` → `2701b`
   - `2026.10 B` → `2610b`
   - `2027.03 B` → `2703b`

2. **IcM ResolveBy date** — Calculate from the `MsrcCaseDetails.ResolveBy` date:
   ```
   ResolveBy: "2027-01-12" → January 2027 → 1B → release code = 2701
   ```

3. **Task group's Iteration Path** — The iteration may contain the release:
   ```
   System.IterationPath → e.g., "OS\2701" → release code = 2701
   ```

4. **User-provided** — If the user explicitly says "targeting 1B" or "targeting 2701b".

**Implementation:**
```powershell
# After fetching task group children (§20), read the Release field from any child bug:
$releaseField = $bugs.value[0].fields.'Microsoft.VSTS.Common.Release'
# e.g., "2027.01 B"

# Parse to release code:
if ($releaseField -match '(\d{4})\.(\d{2})\s*B') {
    $year = $Matches[1].Substring(2)  # "27"
    $month = $Matches[2]              # "01"
    $releaseCode = "${year}${month}b"  # "2701b"
}
```

**Once the release code is determined**, use it for ALL branch lookups:
- `release/v15/${releaseCode}_ge*` / `release/v15/${releaseCode}_br*` (GEBR detection)
- `release/v15/${releaseCode}_lt` (GE-LT)
- `release/v14/${releaseCode}_ni` (NI)
- `official/fe_release_svc_${releaseCode}` (FE, docked)
- `official/vb_release_svc_${releaseCode}` (VB, docked)

**⚠️ If the release code from the bug differs from what the IcM or user says, flag a mismatch and ask the user to confirm.**

### Target Branch Resolution (MANDATORY)

> **⚠️ NEVER pick a target branch by scanning all remote branches and guessing. ALWAYS resolve the branch from the release code derived from the bug/IcM.**

**Step-by-step procedure for each platform:**

```powershell
# 1. Derive release code from the bug Release field (see above)
#    e.g., "2027.01 B" → releaseCode = "2701b"

# 2. Query remote branches matching that release code for the target platform
#    Use git ls-remote — this is the ONLY way to find the correct branch.

# GE/BR: check for combined GEBR or separate branches
$geBranches = git ls-remote --heads origin "release/v15/${releaseCode}_ge*" "release/v15/${releaseCode}_br*"
# Example output:
#   refs/heads/release/v15/2701b_gebr        → combined GEBR
#   refs/heads/release/v15/2610b_ge           → separate GE
#   refs/heads/release/v15/2610b_br           → separate BR
#   refs/heads/release/v15/2612b_ge_hotpatch  → hotpatch (ignore for Main OS/SafeOS)

# LT
$ltBranch = git ls-remote --heads origin "release/v15/${releaseCode}_lt"

# NI
$niBranch = git ls-remote --heads origin "release/v14/${releaseCode}_ni"

# FE (docked)
$feBranch = git ls-remote --heads origin "official/fe_release_svc_${releaseCode}"

# VB (docked)
$vbBranch = git ls-remote --heads origin "official/vb_release_svc_${releaseCode}"
```

**Branch selection rules:**
1. **Use ONLY branches that match the derived release code** — if the code is `2701b`, do NOT use `2610b_ge` even if it exists
2. If `*_gebr` exists for that release code → use it (combined GE+BR)
3. If `*_ge` and `*_br` exist separately → create separate PRs
4. If `*_ge_hotpatch` exists → ignore for Main OS / SafeOS DU bugs (hotpatch is separate)
5. If NO branch matches the release code → **STOP and ask the user**; do not fall back to other release codes

**Common mistake to avoid:**
```
❌ WRONG: Search all remote branches with `git branch -r` and pick the first one that
   has "ge" in the name (this is how MSRC-156290 picked 2610b_ge instead of 2701b_gebr)
✅ RIGHT: Derive release code from bug → query remote for exact match → use that branch
```

### IcM Assessment Validation

Before targeting a release, check the IcM assessment status:

```
IcM → MsrcCaseDetails custom field → Severity, SecurityImpact, ReactPhase
```

| IcM Severity | SecurityImpact | ReactPhase | Assessment Status |
|---|---|---|---|
| 3 (default) | null | "New" | ❌ NOT assessed — flag warning |
| 2.5 or 25 | non-null | varies | ✅ Assessed — Important |
| Other | non-null | varies | ✅ Assessed — check severity text |

### Release Naming Convention

MSRC releases follow the **monthly B-release** cadence named `1B` through `12B`:

| Release | Month | Patch Tuesday |
|---|---|---|
| 1B | January | 2nd Tuesday of January |
| 2B | February | 2nd Tuesday of February |
| … | … | … |
| 10B | October | 2nd Tuesday of October |
| 11B | November | 2nd Tuesday of November |
| 12B | December | 2nd Tuesday of December |

### Code Checkin Deadline

**The fix must be checked in 1 month before the target release.**

| Target Release | Code Checkin Deadline |
|---|---|
| 1B (January) | 12B (December, prior year) |
| 2B (February) | 1B (January) |
| 3B (March) | 2B (February) |
| … | … |
| 10B (October) | 9B (September) |
| 11B (November) | 10B (October) |
| 12B (December) | 11B (November) |

When the user provides or the IcM specifies a target release (e.g., "targeting 10B"), always:
1. Calculate the checkin deadline (target − 1 month).
2. Show the user: "Target: **10B** (October) → Code must be checked in by **9B** (September) timeline."
3. If the current date is past the checkin deadline, flag a warning that the deadline may have passed.

### Coldpatch vs Hotpatch Months

**Coldpatch months: 1B, 4B, 7B, 10B** (January, April, July, October).

In coldpatch months, hotpatch updates are NOT shipped. Therefore:
- **Hotpatch bugs (GE Hotpatch, GE-LT Hotpatch, Server 2022 Hotpatch) can be closed** when the target release is a coldpatch month.
- Close reason: **Won't Fix** — "Not applicable: {XB} is a coldpatch month; hotpatch not shipped."

All other months (2B, 3B, 5B, 6B, 8B, 9B, 11B, 12B) are **hotpatch months** — hotpatch bugs remain applicable and must be fixed (if the platform is supported).

### Bug Disposition Decision Tree

Given a target release (e.g., 10B), determine each bug's action:

```
For each bug in the task group:
  1. Is the platform supported? (see §4)
     NO  → Close as Won't Fix ("Not supported for USO")
     YES → continue

  2. Is it a hotpatch bug AND target is a coldpatch month (1B/4B/7B/10B)?
     YES → Close as Won't Fix ("Coldpatch month — hotpatch not shipped")
     NO  → continue

  3. Is the platform status ❓ Unknown? (GE Hotpatch, GE-LT Hotpatch, Server 2022 Hotpatch)
     YES → Ask user before proceeding
     NO  → Fix required
```

**Example: MSRC targeting 10B (coldpatch month)**

| Bug Type | Platform | Action | Reason |
|---|---|---|---|
| Main OS | Main | ✅ Fix | Supported |
| Main OS | GE | ✅ Fix | Supported |
| Main OS | GE-LT | ✅ Fix | Supported |
| Main OS | NI | ✅ Fix | Supported |
| Main OS | BR | ✅ Fix | Supported |
| Main OS | FE | ✅ Fix | Supported (docked) |
| Main OS | VB | ✅ Fix | Supported (docked, last) |
| Main OS | Win 10 1809 | ❌ Close | Not supported |
| Main OS | Win 10 1607 | ❌ Close | Not supported |
| Main OS | Win 8.1 | ❌ Close | Not supported |
| Main OS | Server 2012 | ❌ Close | Not supported |
| SafeOS DU | GE | ✅ Fix | Supported |
| SafeOS DU | GE-LT | ✅ Fix | Supported |
| SafeOS DU | NI | ✅ Fix | Supported |
| SafeOS DU | BR | ✅ Fix | Supported |
| SafeOS DU | FE | ✅ Fix | Supported (docked) |
| SafeOS DU | VB | ✅ Fix | Supported (docked) |
| SafeOS DU | Unsupported | ❌ Close | Not supported |
| Hotpatch | GE | ❌ Close | **10B = coldpatch month** |
| Hotpatch | GE-LT | ❌ Close | **10B = coldpatch month** |
| Hotpatch | Server 2022 | ❌ Close | **10B = coldpatch month** |

**Summary for 10B:** Fix 13 bugs (7 Main OS + 6 SafeOS DU), Close all hotpatch + unsupported.

### Release Rules

| Assessment Result | Required Release | Notes |
|---|---|---|
| **Important** (sev 2.5/25) | **B release** | Mandatory — no exceptions |
| **Moderate** | **D release** allowed | Can also go in B if preferred |
| **Not assessed** (sev 3) | ⚠️ Flag to user | Do NOT proceed without assessment confirmation |

### Triple-Consistency Check

Before committing containment metadata, verify:
```
Branch version == Containment Release field == Bug Release field
```

Example:
- Branch: `release/v15/2610b_ge` → version = `2610`
- Containment: `<Release>REL2610</Release>` or `"Release": "REL2610"` ✅
- Bug: `Release = YYYY.MM B` (which maps to `XXXX`) ✅

If ANY mismatch → flag to user with details, do not proceed.

---

## 10. IcM Data Flow

```
IcM ID
  → icm-mcp: get_incident_details_by_id
    → Title, Severity, State, OwningTeam
    → MsrcCaseDetails (custom field JSON):
        Severity, SecurityImpact, ReactPhase, DaysInAssessment, ResolveBy
    → Summary HTML
        → Task Group ADO ID (linked in summary)
          → az boards work-item show <task-group-id>
            → Child bugs (Hierarchy-Forward relations)
              → Per-platform bug details
    → Hyperlink to IcM
```

### Extracting Task Group from IcM
1. Get incident details
2. Parse the summary/discussion for the ADO task group link
3. Extract work item ID from URL
4. Query child bugs via `az boards work-item show` relations

### Per-Platform Bug Discovery
From the task group:
1. Get all `System.LinkTypes.Hierarchy-Forward` relations
2. **Batch-fetch** all child bugs in a single call (see §8a — do NOT fetch sequentially)
3. For each child bug:
   - Read `OSG.Product` field → determine platform
   - Check title for `[SafeOS DU]` → determine Main OS vs SafeOS
   - Check for `ArtifactLink` relations with `PullRequest` → PR linked?
   - Read State, Release, ResolvedReason

---

## 11. Build Process

### Undocked (Main, GE, GE-LT, NI, BR)

Both commands MUST run in the **same shell session** (dazzle sets env vars):

```powershell
# In a single shell:
. <repo-root>\build\dazzle.ps1 -amd64chk
cd <repo-root>\src\orchestrator
bcz    # clean build
# OR
bz     # incremental build
# OR
bzf    # fast build (no packaging, no test metadata)
```

**Available build aliases** (from `build/cue.pub`):
| Command | Purpose |
|---|---|
| `bz` | Incremental build |
| `bcz` | Clean + build |
| `bzm` | Build with minimal verbosity |
| `bczm` | Clean + build with minimal verbosity |
| `bzf` | Fast build (skip packaging/test metadata) |
| `bczf` | Clean + fast build |

**Default config**: `-amd64chk` (x64 debug) for testing. Use `-amd64fre` (x64 release) for VM deployment binaries.

### Build Dependency Order

Some projects have implicit build dependencies that must be satisfied first:

| Project | Required Dependency | When |
|---|---|---|
| `CoreWorkerWinrtApi` | `casablanca2.8.0.vcxproj` | Release config (`-amd64fre`) — the casablanca REST SDK lib is not pre-built for Release |

If a build fails with `LNK1181: cannot open input file '<lib>.lib'`, check whether the missing lib has a `.vcxproj` in the repo and build it first:
```powershell
# Example: build casablanca before the main project
. <repo-root>\build\dazzle.ps1 -amd64fre
cd <repo-root>\src\orchestrator
bz src\orchestrator\common\casablanca2.8.0\casablanca2.8.0.vcxproj
bz   # now build the main project
```

**Each repo has its own dazzle.ps1:**
- `E:\uus\build\dazzle.ps1` (main)
- `E:\uus-ge\build\dazzle.ps1` (GE)
- `E:\uus-lt\build\dazzle.ps1` (GE-LT)
- `E:\uus-ni\build\dazzle.ps1` (NI)
- Downlevel repos follow same pattern

### Docked (FE, VB)
Different build system — **ask user** for build instructions for docked platforms.

### Repo Skill Delegation
If the `uso-vm-testing` skill is available, delegate VM deployment to it.

### Sequential Build — One Repo at a Time

**⚠️ NEVER build multiple repos in parallel.** Each `dazzle.ps1 + bz/bcz` spawns a full MSBuild process that consumes significant CPU and memory. Running 2+ builds simultaneously will freeze the system.

**Rules:**
1. Build repos **one at a time**, sequentially — wait for each build to fully complete before starting the next.
2. **Close the previous dazzle shell** before opening a new one for the next repo — dazzle sets env vars that conflict across repos.
3. Follow this order (most critical first):
   ```
   main → GE → LT → NI → BR → (docked if applicable)
   ```
4. After each build completes, record pass/fail before moving to the next.

**Example — building 3 platform repos:**
```powershell
# 1. Build main — wait for completion
cd E:\uus; . .\build\dazzle.ps1 -amd64chk; cd src\orchestrator; bz
# ✅ main done — close this shell

# 2. Build GE — new shell, wait for completion
cd E:\uus-ge; . .\build\dazzle.ps1 -amd64chk; cd src\orchestrator; bz
# ✅ GE done — close this shell

# 3. Build LT — new shell, wait for completion
cd E:\uus-lt; . .\build\dazzle.ps1 -amd64chk; cd src\orchestrator; bz
# ✅ LT done
```

**Do NOT do this:**
```powershell
# ❌ WRONG — parallel builds will freeze the system
Start-Job { cd E:\uus; ... bz }
Start-Job { cd E:\uus-ge; ... bz }   # System freezes
Start-Job { cd E:\uus-lt; ... bz }   # System unresponsive
```
If the `uus-change-tracker` skill is available, use it to track CI builds.
If the `/orchestrator-build-and-test` skill is available, use it for build workflow.

---

## 11b. Branch Safety — Multi-MSRC Concurrency

When working on multiple MSRCs simultaneously, each MSRC uses its own topic branch. Since multiple sessions may share the same repo directory, branch conflicts are inevitable if both MSRCs use the same repo checkout.

### The Problem

```
Session A (MSRC-123)              Session B (MSRC-456)
────────────────────              ────────────────────
E:\uus-ge on msrc-123 ✅
editing files...
                                  E:\uus-ge checkout msrc-456 ← CONFLICT!
                                  Session A's work is now on wrong branch 💥
```

### Solution: Git Worktrees

When 2+ MSRCs need the **same repo** concurrently, use **git worktrees**. Each worktree is an independent working directory with its own branch, sharing the same `.git` database — no duplication, no conflicts.

**Directory convention:** `<repo>-msrc-<ID>`

```powershell
# From the main repo checkout, create a worktree for the second MSRC
cd E:\uus-ge
git worktree add E:\uus-ge-msrc-456 -b user/mayajoshi/msrc-456-description official/main

# Now you have:
#   E:\uus-ge            → working on msrc-123 (original checkout)
#   E:\uus-ge-msrc-456   → working on msrc-456 (worktree, independent branch)
```

**Worktree commands:**
```powershell
# List all worktrees for a repo
git -C E:\uus-ge worktree list

# Create worktree from existing remote branch
git -C E:\uus-ge worktree add E:\uus-ge-msrc-456 user/mayajoshi/msrc-456-description

# Create worktree with new branch from upstream
git -C E:\uus-ge worktree add E:\uus-ge-msrc-456 -b user/mayajoshi/msrc-456-description official/main

# Remove worktree after MSRC is done
git -C E:\uus-ge worktree remove E:\uus-ge-msrc-456
```

**Building in a worktree** — works exactly like a normal repo checkout:
```powershell
cd E:\uus-ge-msrc-456
. .\build\dazzle.ps1 -amd64chk
cd src\orchestrator
bz
```

### Decision: When to Use Worktrees vs Branch Switching

| Situation | Action |
|---|---|
| 1 MSRC per repo | Normal branch checkout — no worktree needed |
| 2+ MSRCs in same repo, **both actively being worked on** | **Use worktrees** — one worktree per MSRC |
| 2+ MSRCs in same repo, one is done/PR merged | Stay on single checkout — just switch branches |
| Session starts and repo is on a different MSRC's branch | Check if other MSRC is active (uncommitted changes?) — if yes → worktree; if no → switch |

### Session Start: Repo State Check

At the start of every session, for each repo the MSRC needs:

```
1. Check current branch:
   $current = git -C "<repo>" branch --show-current

2. Check if dirty:
   $dirty = git -C "<repo>" status --porcelain

3. Decision:
   If $current matches expected MSRC branch AND clean → ✅ proceed
   If $current matches expected MSRC branch AND dirty → ask: commit, stash, or continue
   If $current is a DIFFERENT MSRC branch AND clean → switch to expected branch
   If $current is a DIFFERENT MSRC branch AND dirty → ⚠️ another MSRC has active work here
      → Ask user: "E:\uus-ge has uncommitted changes for MSRC-123.
         Create a worktree at E:\uus-ge-msrc-456 for your MSRC instead?"
```

### Branch Preflight Check (MANDATORY)

Even with worktrees, **always verify the branch before every git write operation** (commit, push, cherry-pick):

```powershell
$current = git -C "<repo-path>" branch --show-current
$expected = "user/<alias>/msrc-<ID>-<description>"
if ($current -ne $expected) {
    # ⚠️ STOP — wrong branch! Show mismatch and ask user.
}
```

### Worktree Cleanup

After an MSRC is fully closed (all PRs merged, bugs resolved):
```powershell
# Remove the worktree
git -C E:\uus-ge worktree remove E:\uus-ge-msrc-456

# Delete the topic branch if merged
git -C E:\uus-ge branch -d user/mayajoshi/msrc-456-description
```

### Phase 3 Integration

In Phase 3 (§13), step **3a. Branch Setup** must include worktree awareness:

```
3a. Branch Setup (updated)
1. Confirm repo path with user
2. Check current branch and dirty state
3. If repo is on a different MSRC's branch with uncommitted changes:
   → Offer to create a worktree for this MSRC
4. If clean wrong branch → ask: switch or worktree?
5. If correct branch → check clean/dirty, proceed
6. Fetch latest from upstream
7. Create topic branch: user/<alias>/msrc-<ID>-<description>
8. Record expected branch per repo for this session's preflight checks
```

## 12. Duplicate Verification

When the user says "X is a duplicate of Y":

### Step 1: Fetch Both IcMs
- Get incident details for both MSRC IDs via `icm-mcp`
- If IcM details unavailable (VPN down, icm-mcp missing), ask user to provide IcM IDs manually

### Step 2: Compare Side-by-Side

| Aspect | MSRC-X | MSRC-Y |
|---|---|---|
| Vulnerability class | ? | ? |
| Attack vector | ? | ? |
| Affected binary | ? | ? |
| Affected code path | ? | ? |
| Impact/scope | ? | ? |
| Additional notes | ? | ? |

### Step 3: Flag Differences
```
⚠️ Potential differences found between MSRC-X and MSRC-Y:

| Aspect           | MSRC-X                   | MSRC-Y                   |
|------------------|--------------------------|--------------------------|
| Attack vector    | Junction + state repo    | Junction + COM reparse   |
| Impact           | Arbitrary file read      | Info disclosure          |

These may NOT be true duplicates. Proceed anyway? [y/n]
```

### Step 4: User Confirms
Only after explicit user confirmation → proceed with duplicate resolution (still requires dry run + approval per §8).

### Task Group Duplication
When asked to duplicate one task group with another:
1. Resolve IcMs linked to BOTH task groups
2. Cross-compare IcM details (not just titles)
3. Confirm truly duplicate in ALL aspects
4. If IcM details unavailable → ask user for IcM IDs

**Example of NOT a duplicate:**
Example of a NOT-duplicate scenario: Two MSRCs may target the same binary with similar attack surfaces (e.g., junction traversal), but if one has an additional attack vector (e.g., state repository access) that the other does not, they are distinct vulnerabilities and NOT duplicates.

---

## 13. End-to-End Backporting Workflow

### Phase 0: Bootstrap
1. Run dependency checks (§3)
2. Hard block on missing must-haves
3. Confirm user's working repos and branches

### Phase 1: IcM Intake & Assessment
1. Fetch IcM details (VPN check first)
2. Validate assessment status (§9)
3. Extract MSRC ID, severity, task group link
4. Flag if assessment incomplete

### Phase 2: Task Group Discovery
1. Fetch task group work item
2. Enumerate all child bugs
3. Classify each: platform, Main OS vs SafeOS DU, PR status, state
4. Present summary table to user
5. Identify which platforms need work

### Phase 3: Code Porting (per platform)

For each supported platform that needs a fix:

**3a. Branch Setup**
1. Confirm repo path with user
2. Check repo is clean (no uncommitted changes)
3. Fetch latest from upstream
4. Create topic branch: `user/<alias>/msrc-<ID>-<description>`

**3a-bis. Per-Platform Vulnerability Surface Analysis (MANDATORY)**

Before applying any fix, analyze which vulnerable sites actually exist on the target platform. Do NOT assume all platforms have the same code paths — platforms diverge over time (functions renamed, refactored, or removed).

For each vulnerable site identified in the primary fix (e.g., main):
1. **Check if the function exists** on this platform (`Select-String` or `grep` for the function name)
2. **Check if it's already protected** (does it already have the required lock/guard?)
3. **Check if the code was refactored** (renamed function, logic merged into another function, etc.)
4. **Check if vulnerable members exist** (e.g., `m_updatesToBeReverted`, `m_currentUpdateBeingReverted` may not exist on all platforms)
5. **Document findings** — these go into the PR's vulnerability table (§19)

Present findings to user before proceeding:
```
Platform: GE
| Site | Function | Exists? | Already Protected? | Action |
|---|---|---|---|---|
| Site 1 — Approve | UpdateManager::Approve | ✅ Yes | ✅ shared_lock at line X | Skip — already safe |
| Site 2 — EvaluateIpuMode | UpdateManager::EvaluateIpuMode | ✅ Yes | ❌ shared_lock insufficient | Fix required |
| Site 3 — EvaluateReverts | UpdateManager::EvaluateReverts | ❌ No | N/A | Skip — refactored away |
```

**Rules:**
- A site that doesn't exist = no fix needed, but MUST be documented in the PR vulnerability table
- A site that's already protected = no fix needed, document as "Already protected" with the line number
- A site that exists but is refactored = check if the equivalent code is protected; document either way
- **Never blindly port all fix sites** — only fix what's actually vulnerable on each platform

**3b. Apply Fix**
1. Cherry-pick or manually port the fix from the primary branch — **only for sites identified as needing a fix in 3a-bis**
2. Adapt code paths if needed (docked vs undocked differences)
3. Follow coding standards from AGENTS.md and copilot-instructions.md

**3c. Containment Metadata**
1. Add/update containment entry (XML for undocked, JSON for docked)
2. Use correct stage (`AlwaysDisabled` + tokens for main, `EnabledByDefault` for downlevel)
3. Use real bug ID (never placeholder)
4. Run triple-consistency check (§9)

**3d. Include Header**
- Undocked: `#include "FeatureStaging-UndockedUpdateStack-MSRC.h"`
- Docked: `#include <featurestaging-servicing-security.h>`

**3e. Code Porting Verification (MANDATORY)**

After applying the fix, verify that ALL functional code changes from the primary branch are present in the port. Containment and include differences are expected — but the actual fix logic must be identical.

**Verification steps:**

1. **Identify the primary fix diff** — get the list of files and code hunks changed in the primary branch fix (usually `main`). Exclude containment files (`.featurestaging`, `.xml`, `.json` containment entries) and include headers.

2. **For each code file changed in the primary fix:**
   - Confirm the same file exists in the downlevel repo
   - If the file path differs (docked vs undocked), identify the equivalent file
   - Compare the functional code change (the actual fix lines) — they must match or have an equivalent adaptation

3. **Diff comparison command:**
   ```powershell
   # Get the primary fix diff (code files only, exclude containment)
   cd <primary_repo>
   git diff HEAD~1 HEAD -- '*.cpp' '*.h' ':!*featurestaging*' ':!*containment*'

   # Get the downlevel port diff
   cd <downlevel_repo>
   git diff HEAD~1 HEAD -- '*.cpp' '*.h' ':!*featurestaging*' ':!*containment*'

   # Compare: every functional hunk in primary must have a match in downlevel
   ```

4. **Present a porting completeness table:**

   | File | Primary Fix | Downlevel Port | Status |
   |---|---|---|---|
   | `src/path/file.cpp` | +5/-2 lines | +5/-2 lines | ✅ Match |
   | `src/path/other.cpp` | +3/-1 lines | — | ❌ **MISSING** |

5. **Flag any discrepancies:**
   - ❌ **MISSING file** — file changed in primary but not in port
   - ❌ **MISSING hunk** — some code changes present in primary but absent in port
   - ⚠️ **ADAPTED** — code change is logically equivalent but syntactically different (e.g., different API names in docked vs undocked) — explain why
   - ✅ **MATCH** — identical functional change

6. **Expected differences (do NOT flag as missing):**
   - Containment metadata format (XML vs JSON)
   - Include headers (`FeatureStaging-UndockedUpdateStack-MSRC.h` vs `featurestaging-servicing-security.h`)
   - Feature gate macro names (undocked vs docked naming)
   - File paths that differ between repos but contain the same logic

7. **Block if incomplete:** If any file or hunk is ❌ MISSING, do NOT proceed to Stage & Review. Ask the user whether to port the missing changes or skip with justification.

**3f. Stage & Review**
1. Stage only intended files (never auto-commit)
2. Show diff to user
3. Let user review before committing

### Phase 4: Build
1. Build each platform repo (§11)
2. Report pass/fail summary only
3. If build fails, show errors and ask user how to proceed

### Phase 4a: Cross-Platform Porting Summary (after all platforms are ported)

After all supported platforms have been ported and built, present a **final cross-platform porting summary** to confirm nothing was missed across the entire MSRC.

```
╔══════════════════════════════════════════════════════════════╗
║              MSRC <ID> — Cross-Platform Porting Summary     ║
╠══════════════════════════════════════════════════════════════╣

Code files changed in primary fix (main):
  - src/path/file1.cpp  (+12/-3)
  - src/path/file2.cpp  (+5/-1)

Porting status per platform:
┌──────────┬──────────────────┬──────────────────┬────────┐
│ Platform │ file1.cpp        │ file2.cpp        │ Status │
├──────────┼──────────────────┼──────────────────┼────────┤
│ GE       │ ✅ Match         │ ✅ Match         │ ✅ OK  │
│ GE-LT    │ ✅ Match         │ ✅ Match         │ ✅ OK  │
│ NI       │ ✅ Match         │ ⚠️ Adapted       │ ✅ OK  │
│ BR       │ ✅ Match         │ ❌ MISSING       │ ❌     │
│ FE       │ ✅ Match (docked)│ ✅ Match (docked)│ ✅ OK  │
│ VB       │ ✅ Match (docked)│ ✅ Match (docked)│ ✅ OK  │
└──────────┴──────────────────┴──────────────────┴────────┘

Containment: Verified separately per platform (§9 triple-check)

Overall: ❌ BR is missing file2.cpp port — BLOCK until resolved
╚══════════════════════════════════════════════════════════════╝
```

**Rules:**
- If ANY platform shows ❌, do NOT proceed to PR creation for that platform
- ⚠️ ADAPTED entries must have a written justification (shown to user)
- This table goes in the session status report (§17) and is referenced in PR descriptions

### Phase 5: Validation
1. Deploy fixed binary to test VM using **sfpcopy** (see §21)
2. Enable the containment feature key using **StagingTool** (see §21)
3. **Reboot the VM** (required after StagingTool enables the key)
4. Run full repro scenario against fixed binary
5. Verify no crash/vulnerability — not just code path existence
6. Report results

### Phase 6: Commit & Push
1. Commit with format: `[MSRC XXXXXX] : <Bug title>`
2. Include fix summary in commit body
3. Push only when user approves
4. Never force-push without explicit permission

### Phase 7: PR Creation (ATOMIC — all steps mandatory, even for drafts)

> **⚠️ A PR is NEVER "half created". All steps below execute as one unit. If any step fails, roll back and flag the blocker.**

**Before creating the PR, prepare ALL of the following:**

1. **Title** — `[<branch>] <short fix description> (MSRC <ID>)` (§19)
2. **Description** — Full Markdown with all 3 sections (§19):
   - `## Why is this change being made?` — must include IcM link and MSRC ID
   - `## What is being changed?` — must list files changed
   - `## How was the change tested?` — must include before/after tables if repro was done
3. **Bug ID** — auto-discovered from IcM → task group → child bugs (§20). Do NOT ask user.
4. **IcM ID** — for the IcM link in the description (extract from chat context or MSRC case)

> ⛔ **Do NOT add reviewers.** The user will add reviewers manually after PR creation.

**Execution sequence:**

```powershell
# Step 1: Create PR with title (az CLI sets title correctly)
az repos pr create --repository <repo> --source-branch <branch> --target-branch <target> --title "<title>" --org "https://dev.azure.com/microsoft" --project "OS" --draft

# Step 2: Set full description via REST API (az CLI truncates multi-line descriptions)
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$body = @{ description = $description } | ConvertTo-Json -Depth 5 -Compress
Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/git/repositories/<repo>/pullrequests/<id>?api-version=7.1" -Method Patch -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" }

# Step 3: Link platform bug
az repos pr work-item add --id <PR_ID> --work-items <BUG_ID> --org "https://dev.azure.com/microsoft"

# Do NOT add reviewers — user handles this manually
```

**Post-creation verification (mandatory):**
- Confirm title matches §19 format
- Confirm description has all 3 sections and IcM link
- Confirm bug is linked (`az repos pr work-item list --id <PR_ID>`)
- **Check build status** (Phase 7a) and report it alongside the PR confirmation

If any verification fails, fix it immediately before reporting PR as created.

**Every PR confirmation message MUST include build status:**
```
✅ PR #12345 created — build: ⏳ pending (takes ~4-5 hours)
```
Never report a PR without its build state. This is not optional.

### Phase 7a: PR Build Monitoring (MANDATORY — not optional)

> **⚠️ This is NOT a "nice to have". Every PR creation MUST trigger an immediate build status check. Every status update the user asks for MUST include build state. MSRC-156290 failed because build status was never checked.**

**Mandatory actions:**

1. **Immediately after creating each PR** — query build status and include it in the PR confirmation message
2. **When user asks "what's the status"** — re-check ALL open PR builds and report current state
3. **Before closing/resolving any bug** — verify its linked PR build has passed. If build is still pending or failed, do NOT close the bug.
4. **When summarizing work done** — always list each PR with its current build state

**How to check build status:**
```powershell
# Get PR build status via Azure DevOps REST API
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$statuses = Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/git/repositories/<repo>/pullrequests/<PR_ID>/statuses?api-version=7.1" `
  -Headers @{ Authorization = "******" }

# Check the latest iteration's build status
$statuses.value | Select-Object context, state, description | Format-Table
```

**Status values:**
| State | Meaning | Action |
|---|---|---|
| `succeeded` | ✅ Build passed | Proceed — PR is ready for review |
| `pending` | ⏳ Build in progress | Wait and re-check after 10-15 minutes |
| `failed` | ❌ Build failed | Investigate — see below |
| `notSet` | No build triggered | Check if PR policies are configured |
| `notApplicable` | Build skipped | Check PR target branch policies |

**When build fails:**
1. Get the build log URL from the status `targetUrl` field
2. Report the failure to the user with the log link:
   ```
   ❌ PR #12345 build FAILED
   Build: <build_url>
   Error: <brief summary if parseable>
   ```
3. If the error is in files this MSRC changed → investigate and suggest a fix
4. If the error is a pre-existing/infrastructure issue → flag to user, do not attempt to fix
5. After pushing a fix, re-check build status

**Monitoring cadence:**
- Check build status **immediately after PR creation** (will likely be `pending`)
- If `pending`, inform user: "PR #XXXX created ✅ — build is running (takes 4-5 hours)"
- **Do NOT block on build** — builds take 4-5 hours. Continue creating other platform PRs, filling bug templates, and doing other work in parallel.
- When reporting PR status, always include current build state:
  ```
  ✅ PR #12345 created — build: ⏳ pending
  ✅ PR #12346 created — build: ✅ succeeded
  ✅ PR #12347 created — build: ❌ failed (see <url>)
  ```
- **Must check build status before closing/resolving bugs** — a bug cannot be closed if its PR build is failing.
- Periodically check all open PR builds when user asks for a status update.

### Phase 8: Bug Updates (only when asked)
1. Set triage to "Consider by Triad Shiproom" (if asked, with approval)
2. After shiproom + PR merge → resolve as Fixed (if asked, with approval)
3. Close unsupported platforms as Won't Fix (if asked, with approval)

---

## 14. Code Change Standards

Follow the repository's coding standards:
- **C++20** features, Microsoft C++ Core Guidelines
- **WIL** for error handling (`THROW_IF_FAILED`, `RETURN_HR_IF`, `CATCH_LOG`)
- **WRL** (not ATL) for COM
- **RAII** for all resource management
- **std::chrono** for time operations
- **MoStack isolation**: no direct Win32 API dependencies — use SystemInterface
- **Feature containment**: wrap fix in `if (Feature_MSRCXXXXXX::IsEnabled()) { ... } else { ... }`
- **No compound conditions with IsEnabled()** — NEVER combine `Feature_MSRCXXXXXX::IsEnabled()` with other checks using `&&` or `||` in the same `if`. Always nest them:
  ```cpp
  // ❌ WRONG — compound condition, will be flagged by containment review
  if (Feature_MSRC170271::IsEnabled() && !::Windows::Trust::IsSystemOrAdmin())

  // ✅ CORRECT — nested conditions
  if (Feature_MSRC170271::IsEnabled())
  {
      if (!::Windows::Trust::IsSystemOrAdmin())
      {
          return E_ACCESSDENIED;
      }
  }
  ```
  **Reason**: The containment analysis tool needs to clearly identify the feature gate boundary. Compound conditions make it ambiguous which logic is gated.

### MSRC Fix Comment Pattern
```cpp
//
// MSRC XXXXXX: <brief description of what the guard prevents>
//
```

Only comment where behavior is non-obvious. Do not over-comment.

---

## 15. Platform-to-Product Mapping (for ADO queries)

| Platform | `OSG.Product` | `OSG.ProductFamily` |
|---|---|---|
| Main | `OS` | `Windows` |
| GE | `Windows (Ge)` | `Windows Servicing` |
| GE-LT | `Windows (Ge) LT` | `Windows Servicing` |
| NI | `Windows 11 22H2` | `Windows Servicing` |
| BR | `Windows (Br)` | `Windows Servicing` |
| FE | `Windows Server 2022` | `Windows Servicing` |
| VB | `Windows 10 2004` | `Windows Servicing` |
| GE Hotpatch | `Windows (Ge) Hotpatch` | `Windows Servicing` |
| GE-LT Hotpatch | `Windows (Ge) LT Hotpatch` | `Windows Servicing` |
| Server 2022 Hotpatch | `Windows Server 2022 Hotpatch` | `Windows Servicing` |

---

## 16. Stop and Ask Conditions

Stop and ask the user when:
- Any required dependency is missing
- IcM assessment is incomplete (sev 3 / no SecurityImpact)
- A platform's support status is ❓ Unknown
- Triple-consistency check fails
- Multiple reasonable approaches exist for a code change
- Duplicate verification finds differences between MSRCs
- Any bug field write is needed (dry run + approval)
- Build fails
- Validation fails or is inconclusive
- Repo has uncommitted changes
- Branch cannot be found or created
- Docked platform build instructions are needed
- Any ambiguity in user's request

---

## 17. Output Format

### Phase Completion
```
✅ Phase 3 Complete: Code ported to GE
   Branch: user/<alias>/msrc-<MSRC-ID>-<description>
   Files changed: 2
   Containment: Feature_MSRC<ID> (EnabledByDefault)
```

### Platform Summary Table
```
| Platform | Type    | Bug ID       | State    | PR  | Fix Status |
|----------|---------|--------------|----------|-----|------------|
| Main     | Main OS | <main-bug>   | Resolved | #XX | ✅ Done    |
| GE       | Main OS | <ge-bug>     | Active   | —   | 🔧 In Progress |
| NI       | Main OS | <ni-bug>     | Active   | —   | ⏳ Pending |
| BR       | Main OS | <br-bug>     | Active   | —   | ⏳ Pending |
| FE       | Main OS | <fe-bug>     | Active   | —   | ⏳ Pending |
| VB       | Main OS | <vb-bug>     | Active   | —   | ⏳ Pending |
| Win 8.1  | Main OS | <unsup-bug>  | Closed   | —   | ❌ Not supported |
```

### Final Report
```
MSRC Backporting Status: <Complete|InProgress|Blocked>
MSRC ID: XXXXXX
IcM: 31000000XXXXXX
Task Group: XXXXXXXX

Platforms:
  ✅ Main — PR #XXXX merged
  ✅ GE — PR #XXXX merged
  🔧 NI — PR #XXXX under review
  ⏳ BR — pending
  ❌ Win 8.1 — not supported (closed)

Blocked:
  - <reason if any>

Next action:
  - <what needs to happen next>
```

---

## 18. Skill Self-Update Protocol

This skill is maintained at 3 locations. **Every update** edits the primary, pushes to GitHub, and copies to Copilot runtime:

| # | Role | Location | Sync Method |
|---|---|---|---|
| 1 | **Primary** | `D:\skill\SKILL.md` | Edit here first |
| 2 | **GitHub** | `github.com/mayankjoshi-ms/msrc-process-agent` | `git add . && git commit -m "<change summary>" && git push` from `D:\skill` |
| 3 | **Copilot runtime** | `C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md` | **File copy** from primary (symlinks do NOT work — Copilot reports size=0 and fails to discover the skill) |

### Update Sequence (mandatory)
```
1. Edit D:\skill\SKILL.md
2. cd D:\skill && git add . && git commit -m "<summary>" && git push
3. Copy-Item "D:\skill\SKILL.md" "C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md" -Force
4. Verify hashes match
```

> **⚠️ Do NOT use symlinks for the Copilot runtime copy.** Copilot's skill discovery cannot follow symlinks (reports size=0, skill not listed).

**Never** update only one location. If any sync step fails, flag it to the user immediately.

---

## 19. PR Title and Description Format

> **⚠️ MANDATORY — When this skill is loaded, this format is the ONLY acceptable PR format.**
> Do NOT generate any other format. Do NOT use HTML. Do NOT invent custom sections.
> Any PR created or updated by this skill MUST follow §19 exactly. No exceptions.

**All PRs must use Markdown format.** ADO PR descriptions support full Markdown rendering — use `##` headings, `**bold**`, `` `code` ``, `|` tables, and `- ` lists. Do NOT use raw HTML tags.

### PR Title Format

```
[<platform>][MSRC <ID>] <short fix description>
```

For multiple MSRCs:
```
[<platform>][MSRC <ID1>,<ID2>,<ID3>] <brief description of each fix>
```

| Scenario | Example Title |
|---|---|
| Single MSRC (main) | `[main][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| Single MSRC (GE) | `[GE][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| Single MSRC (LT) | `[LT][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| Combined GEBR | `[GE/BR][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| Separate BR | `[BR][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| Docked (FE) | `[FE][MSRC 170271] Fix UOP provider Register/Unregister authorization bypass` |
| 2 MSRCs | `[NI][MSRC 155686,170271] Fix Approve/EvaluateIpuMode UAF race and UOP auth bypass` |
| 3+ MSRCs | `[GE][MSRC 155686,163522,170271] Fix Approve UAF race, WIL token escalation, and UOP auth bypass` |

Rules:
- Platform name in first `[]` — use the short platform name (main, GE, LT, NI, BR, FE, VB)
- MSRC ID(s) in second `[]` — format: `MSRC <ID>` or `MSRC <ID1>,<ID2>` for multiple
- Fix description follows — concise, one line
- **For multiple MSRCs:** each MSRC gets a short `<function/component> <vulnerability>` mention, joined with commas/and. Never use generic text like "Fix multiple security vulnerabilities".
- For non-MSRC PRs, use `[<platform>][Bug <ID>]` instead of `[<platform>][MSRC <ID>]`

### PR Description Template

```markdown
## Why is this change being made?

<Describe the bug/vulnerability/problem. For MSRC PRs include:>
- <MSRC ID(s) and vulnerability class (EoP, RCE, Info Disclosure, Tampering, etc.)>
- <Root cause: what the attacker can do and why>
- <Which entry points / code paths are affected>
- **IcM link (REQUIRED):** `[<IcM ID>](https://portal.microsofticm.com/imp/v5/incidents/details/<IcM ID>/summary)` | MSRC Case: <ID> | Bug: <Bug ID>

## What is being changed?

<Describe the fix — what was added/modified and why.>

<List the approach: new guards, API changes, containment, etc.>

**Files changed:**
- `src/path/to/file.cpp` — <brief description of change>
- `src/path/to/file.featurestaging` — <containment metadata>

<If containment is used, mention the feature key and its default state.>

## How was the change tested?

<Describe how the fix was validated.>

**Before fix:**
- <scenario> - <vulnerable result>

**After fix:**
- <scenario> - <mitigated result>

<Mention unit tests, regression analysis, VM validation, etc.>
```

### Description Rules
- **Markdown only** — no raw HTML (`<h2>`, `<table>`, `<ul>`, `<b>`, etc.). ADO renders Markdown natively.
- **4000-character hard limit** — ADO rejects PR descriptions over 4000 characters. Write concisely. If approaching the limit, trim the "How was the change tested?" section first (keep the before/after lists, cut prose).
- Section headings must be exactly: `## Why is this change being made?`, `## What is being changed?`, `## How was the change tested?`
- Do NOT invent custom sections like "Attack Scenario", "Fix Description", "Variant Analysis", "References", etc.
- Before/after bullet-point lists are required when repro was performed.
- Files changed list is required in the "What" section.
- Containment feature key and state must be mentioned if applicable.
- MSRC ID and IcM reference go in the "Why" section, not in a separate "References" section.

### Vulnerable Sites and Fix Status Table (REQUIRED for all MSRC PRs)

Every MSRC PR description MUST include a **"Vulnerable sites and fix status"** table in the "Why" section, immediately after the IcM link line. This table documents each known vulnerable site from the primary fix and its status **on this specific platform**.

**Template (add after the IcM link line in "Why"):**
```markdown
### Vulnerable sites and fix status

| Site | Function | Status on <PLATFORM> |
|---|---|---|
| Site 1 — <Name> | `ClassName::Function` — <brief desc> | <status> |
| Site 2 — <Name> | `ClassName::Function` — <brief desc> | <status> |
| Site 3 — <Name> | N/A | <status> |
```

**Status values (use exactly one per site):**
| Status | When to use |
|---|---|
| `Fixed in this PR (<brief how>)` | Site is vulnerable and this PR fixes it |
| `Already protected (<lock type> at line X)` | Site exists but already has adequate protection |
| `Code refactored away on <PLATFORM> (no <function>, <member1>, or <member2>)` | Function and related members don't exist |
| `Does not exist on docked (<PLATFORM>)` | Code path not present on docked platforms |

**Rules:**
- The table must list ALL sites from the primary fix — even those that don't need a fix on this platform
- Each platform's table is DIFFERENT — do NOT copy from main or another platform
- Use findings from §13 Phase 3 step 3a-bis (per-platform vulnerability analysis)
- If a site was refactored into another function that IS protected, explain briefly (e.g., "revert logic in `EvaluateAsyncWorkQueue` already protected by `shared_lock`")
- Reference the main PR at the end of the description for cross-platform traceability

---

## 20. Automatic Bug Discovery from IcM

When creating a PR, the skill must **automatically** find the correct platform bug to link. Do NOT ask the user for the bug ID if an IcM ID or MSRC ID is available in the chat context.

### Discovery Chain

```
IcM ID (from chat context or user)
  → Fetch IcM details (icm-mcp-get_incident_details_by_id)
  → Extract MSRC case number from MsrcCaseDetails custom field: CaseNumber
  → Extract task group ID from IcM summary HTML:
      Regex: /workitems\/edit\/(\d+)/  or  "Link to ADO Task Group.*?(\d+)"
  → Fetch task group from ADO REST API
  → Get child bugs via relations (System.LinkTypes.Hierarchy-Forward)
  → Batch-fetch all child bugs (§8a)
  → **Derive release code from bug Release field** (see §9 — "Determining the Target Release Code")
      e.g., "2027.01 B" → releaseCode = "2701b"
  → Use releaseCode for ALL branch lookups (not user-assumed or IcM-assumed)
  → For each child bug, fetch OSG.Product field
  → Match platform to current PR's target branch
  → Link the matching bug to the PR
```

### Platform-to-Branch Matching

| PR Branch Pattern | Platform Match (OSG.Product) |
|---|---|
| `main` | `OS` (Family: `Windows`) |
| `*_gebr` | `Windows (Ge)` **+ `Windows (Br)`** (combined — 4 bugs) |
| `*_ge` | `Windows (Ge)` only (separate — 2 bugs) |
| `*_lt` | `Windows (Ge) LT` |
| `*_ni` | `Windows 11 22H2` |
| `*_br` | `Windows (Br)` only (separate — 2 bugs) |
| `*fe_release*` | `Windows Server 2022` |
| `*vb_release*` | `Windows 10 2004` |

### Combined GEBR Branch Detection

> **⚠️ GE and BR may have separate branches OR a combined `gebr` branch. Always check the remote first — never assume.**

**Detection logic:**
```powershell
# Check what remote branches exist for the target release
git ls-remote --heads origin "release/v15/XXXXb_ge*" "release/v15/XXXXb_br*"

# If *_gebr exists → combined branch, one GE PR covers both GE and BR
# If *_ge and *_br exist separately → separate branches, create separate PRs
# If only *_ge exists (no *_br, no *_gebr) → ask user
```

**If combined (`*_gebr`):**
- Create ONE PR targeting the `gebr` branch
- Link **4 bugs** to this PR: GE Main OS + GE SafeOS DU + BR Main OS + BR SafeOS DU
- The PR title uses `[GE/BR]`: `[GE/BR] <fix description> (MSRC <ID>)`
- No separate code port or PR needed for BR

**If separate (`*_ge` + `*_br`):**
- Create separate PRs for GE and BR as normal
- GE PR gets 2 bugs (GE Main OS + GE SafeOS DU)
- BR PR gets 2 bugs (BR Main OS + BR SafeOS DU)

### Link BOTH Main OS and SafeOS DU Bugs

> **⚠️ Most platforms have TWO bugs: one Main OS and one SafeOS DU. Link ALL matching bugs to the PR.**

### SafeOS DU Bug Existence by Platform

| Platform | OSG.Product | Has Main OS Bug? | Has SafeOS DU Bug? | Linked to PR |
|---|---|---|---|---|
| **Main** | OS | ✅ | ❌ Never | Main PR (1 bug) |
| **GE** | Windows (Ge) | ✅ | ✅ | GE or GEBR PR (check remote) |
| **GE-LT** | Windows (Ge) LT | ✅ | ✅ | LT PR |
| **NI** | Windows 11 22H2 | ✅ | ✅ | NI PR |
| **BR** | Windows (Br) | ✅ | ✅ | BR PR or GEBR PR (check remote) |
| **FE** | Windows Server 2022 | ✅ | ✅ | FE PR |
| **VB** | Windows 10 2004 | ✅ | ✅ | VB PR |
| Win 10 1809 | Windows 10 1809 | ✅ | ✅ | (unsupported — close) |
| Win 10 1607 | Windows 10 1607 | ✅ | ✅ | (unsupported — close) |
| Win 8.1 | Windows 8.1 | ✅ | ❌ Never | (unsupported — close) |
| Server 2012 | Windows Server 2012 | ✅ | ❌ Never | (unsupported — close) |
| GE Hotpatch | Windows (Ge) Hotpatch | ✅ | ❌ Never | (coldpatch close or fix) |
| GE-LT Hotpatch | Windows (Ge) LT Hotpatch | ✅ | ❌ Never | (coldpatch close or fix) |
| Server 2022 Hotpatch | Windows Server 2022 Hotpatch | ✅ | ❌ Never | (coldpatch close or fix) |

**Rules:**
- SafeOS DU bugs exist for **GE through Win 10 1607** (inclusive). They do NOT exist for Main, Win 8.1, Server 2012, or any Hotpatch platform.
- **GEBR:** If the target branch is `*_gebr`, the GE PR gets **4 bugs**. If GE and BR are separate branches, each gets its own 2 bugs.

When linking bugs to a PR:
1. Find ALL child bugs matching the platform's `OSG.Product`
2. **Check the target branch name:** If it contains both `ge` and `br` (i.e., `*_gebr`), match BOTH `Windows (Ge)` AND `Windows (Br)` → expect **4 bugs**. Link ALL 4.
3. If the target branch is `*_ge` only (no `br`), match only `Windows (Ge)` → expect **2 bugs**. Create a separate BR PR with its own 2 bugs.
4. For other platforms GE-LT–Win 10 1607: expect 2 matches (Main OS + SafeOS DU). **Link BOTH.**
5. For Main, Win 8.1, Server 2012, Hotpatch: expect 1 match (Main OS only). Link it.
6. If a SafeOS DU bug is expected but not found, flag it to the user — do not silently skip.

```powershell
# For GEBR PR (4 bugs: GE + BR, each with Main OS + SafeOS DU):
az repos pr work-item add --id <PR_ID> --work-items <ge_main_bug> <ge_safeos_bug> <br_main_bug> <br_safeos_bug> --org "https://dev.azure.com/microsoft"

# For platforms with SafeOS DU (GE-LT through Win 10 1607):
az repos pr work-item add --id <PR_ID> --work-items <main_os_bug_id> <safeos_du_bug_id> --org "https://dev.azure.com/microsoft"

# For Main / Win 8.1 / Server 2012 / Hotpatch (no SafeOS DU):
az repos pr work-item add --id <PR_ID> --work-items <main_os_bug_id> --org "https://dev.azure.com/microsoft"
```

### Implementation

```powershell
# Step 1: Get IcM details
$icm = icm-mcp-get_incident_details_by_id -incidentId <IcM_ID>

# Step 2: Extract MSRC case number
$msrcDetails = ($icm.customFields | Where-Object { $_.Name -eq "MsrcCaseDetails" }).StringValue | ConvertFrom-Json
$msrcId = $msrcDetails.CaseNumber

# Step 3: Extract task group ID from summary
$taskGroupId = [regex]::Match($icm.summary, 'workitems/edit/(\d+)').Groups[1].Value

# Step 4: Fetch task group children
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$tg = Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/wit/workitems/${taskGroupId}?`$expand=relations&api-version=7.1" -Headers @{ Authorization = "Bearer $token" }
$childIds = $tg.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Forward" } | ForEach-Object { $_.url -replace '.*/(\d+)$','$1' }

# Step 5: Find ALL matching platform bugs (Main OS + SafeOS DU)
$matchedBugs = @()
foreach ($id in $childIds) {
    $bug = Invoke-RestMethod -Uri "https://dev.azure.com/microsoft/OS/_apis/wit/workitems/${id}?api-version=7.1" -Headers @{ Authorization = "Bearer $token" }
    $product = $bug.fields.'OSG.Product'
    if ($product -eq $targetProduct) {
        $matchedBugs += $id
    }
}
# $matchedBugs should contain 2 IDs: Main OS bug + SafeOS DU bug

# Step 6: Link ALL matched bugs to PR (both Main OS and SafeOS DU)
$bugList = $matchedBugs -join ' '
az repos pr work-item add --id <PR_ID> --work-items $bugList --org "https://dev.azure.com/microsoft"
```

### Fallback

If the IcM summary does not contain a task group link:
1. Search ADO work items: `az boards query --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.Title] CONTAINS 'MSRC <case_number>' AND [System.WorkItemType] = 'Task Group'" --org "https://dev.azure.com/microsoft" --project "OS"`
2. If multiple task groups found, show them to the user and ask which one.
3. If none found, ask the user for the task group ID.

### Context Awareness

The skill must **proactively** read the IcM ID from:
1. Chat context (user mentioned it earlier in the session)
2. IcM link in the current PR description being edited
3. Branch name if it contains an MSRC ID (e.g., `user/mayajoshi/msrc-163522-fix`)
4. Commit messages in the PR

Do NOT ask "what bug should I link?" if the IcM/MSRC context is available. Find it automatically.

---

## 21. VM Deployment & Feature Enablement Tools

### VM Version Preflight Check

**Before deploying ANY binary to a VM**, verify that the built binary's branch matches the VM's OS version. Deploying a binary from the wrong branch causes interface mismatches and silent failures.

```powershell
# ON THE VM: Get the UUS version currently installed
$uusVer = (Get-Item "C:\Program Files\Windows Update Stack\*\MoUsoCoreWorker.exe").VersionInfo.FileVersion
Write-Host "VM UUS version: $uusVer"

# Compare against your build output version
# Main (v1500.x) ≠ GE (v1511.x) ≠ LT (v1451.x) ≠ NI (v1401.x)
```

| VM Type | Expected UUS Major Version | Build From Branch |
|---|---|---|
| AB (Canary/Dev) | v1511.x or v1500.x | GE (`*_gebr`/`*_ge`) or main |
| GE release | v1511.x | GE branch |
| LT release | v1451.x | LT branch |
| NI release | v1401.x | NI branch |

**If the versions don't match** → build from the correct branch first. Do NOT proceed with sfpcopy.

### Binary Replacement: sfpcopy

Use **sfpcopy** to replace protected system binaries on the test VM. It handles SFC/WFP bypass automatically.

**Tool locations (checked in order):**
1. `C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\sfpcopy.exe` (local)
2. `\\ntqfedev\public\mayajoshi\Tools\sfpcopy.exe` (network share — **requires VPN**)

```powershell
# Check which path is available
$sfpcopy = "C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\sfpcopy.exe"
if (-not (Test-Path $sfpcopy)) {
    $sfpcopy = "\\ntqfedev\public\mayajoshi\Tools\sfpcopy.exe"
    Write-Warning "Using network share — VPN must be connected"
}

# Replace a binary on the VM (run ON the VM as admin)
& $sfpcopy "<path\to\fixed\binary.dll>" "<target\system\path\binary.dll>"
# Example:
& $sfpcopy "C:\temp\usosvcimpl.dll" "C:\Windows\System32\usosvcimpl.dll"
```

### Feature Key Enablement: StagingTool

Use **StagingTool** to enable the containment feature key on the test VM so the fix code path is active.

**Tool locations (checked in order):**
1. `C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\StagingTool.exe` (local)
2. `\\ntqfedev\public\mayajoshi\Tools\StagingTool.exe` (network share — **requires VPN**)

```powershell
# Check which path is available
$stagingTool = "C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\StagingTool.exe"
if (-not (Test-Path $stagingTool)) {
    $stagingTool = "\\ntqfedev\public\mayajoshi\Tools\StagingTool.exe"
    Write-Warning "Using network share — VPN must be connected"
}

# Enable a feature key on the VM (run ON the VM as admin)
& $stagingTool /enable <FeatureId>
# Example:
& $stagingTool /enable 64500171   # Feature_MSRC170271
```

**⚠️ REBOOT REQUIRED:** After enabling a feature key with StagingTool, the VM **must be rebooted** for the change to take effect. Do NOT run validation until after reboot.

### Full Validation Deployment Sequence

```
1. Copy fixed binary to VM (e.g., via shared folder or \\ntqfedev share)
2. sfpcopy — replace the system binary
3. StagingTool /enable <FeatureId> — enable the containment key
4. Reboot the VM
5. Verify the new binary version: (Get-Item <path>).VersionInfo.FileVersion
6. Run repro scenario — confirm fix blocks the attack
7. Run regression scenario — confirm normal operation still works
```

### VM Checkpoints

Create a Hyper-V checkpoint at **every major milestone** during VM testing. This lets you roll back to any known-good state without re-deploying from scratch.

**Naming convention:** `MSRC-<ID>-<milestone>`

| When | Checkpoint Name | Purpose |
|---|---|---|
| After VM version preflight passes | `MSRC-<ID>-baseline` | Clean state before any changes |
| After enabling page heap / gflags | `MSRC-<ID>-pageheap-enabled` | Roll back if page heap causes issues |
| After successful repro (vuln confirmed) | `MSRC-<ID>-repro-done` | Reuse for re-validation without re-setup |
| After sfpcopy + StagingTool + reboot | `MSRC-<ID>-fix-deployed` | Roll back if fix causes regression |
| After fix validated (repro blocked) | `MSRC-<ID>-fixed` | Proof point — keep for auditor review |

**Commands:**

```powershell
# Create checkpoint (run on HOST, not inside the VM)
Checkpoint-VM -Name "<VMName>" -SnapshotName "MSRC-170271-baseline"

# List checkpoints
Get-VMSnapshot -VMName "<VMName>"

# Restore to a checkpoint
Restore-VMSnapshot -VMName "<VMName>" -Name "MSRC-170271-repro-done" -Confirm:$false
Start-VM -Name "<VMName>"
```

**Rules:**
- Always create checkpoints from the **host machine**, not from inside the VM.
- Use the exact naming convention — no freeform names.
- The `baseline` checkpoint is **mandatory** before any binary replacement.
- The `repro-done` checkpoint is **mandatory** before deploying the fix — this is your rollback point.
- Delete old checkpoints after the MSRC case is fully closed to save disk space:
  ```powershell
  Remove-VMSnapshot -VMName "<VMName>" -Name "MSRC-170271-*"
  ```
