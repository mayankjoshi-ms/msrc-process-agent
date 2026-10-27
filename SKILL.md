---
name: msrc-process-agent
description: Self-sufficient end-to-end MSRC process agent for USO security fixes across all supported platforms (undocked and docked). Handles IcM intake, code porting, containment metadata, bug field management, PR creation, build, validation, and duplicate verification.
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
   - ✅ Reviewers assigned
   If ANY of these cannot be completed, do NOT create the PR — flag the blocker to the user instead.

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
| **GE** | Windows (Ge) | uus | `release/v15/XXXXb_ge` | ✅ Supported |
| **GE-LT** | Windows (Ge) LT | uus | `release/v15/XXXXb_lt` | ✅ Supported |
| **NI** | Windows 11 22H2 | uus | `release/v14/XXXXb_ni` | ✅ Supported |
| **BR** | Windows (Br) | uus | `release/v15/XXXXb_br` | ✅ Supported |
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
  <email>mayajoshi@microsoft.com</email>
  <changeTime>YYYY-MM-DDTHH:MM:SS.0000000-XX:XX</changeTime>
</feature>
```

**Downlevel branch** entry (GE, GE-LT, NI, BR):
```xml
<feature>
  <className>Feature_MSRCXXXXXX</className>
  <id>MSRCXXXXXX</id>
  <name>Feature_MSRCXXXXXX</name>
  <description>MSRC XXXXXX fix</description>
  <stage>EnabledByDefault</stage>
  <!-- NO enabledByDefaultBranchTokens for downlevel -->
  <email>mayajoshi@microsoft.com</email>
  <changeTime>YYYY-MM-DDTHH:MM:SS.0000000-XX:XX</changeTime>
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
  "owner": "mayajoshi@microsoft.com",
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

---

## 6. Branch & Reviewer Mapping

### Topic Branch Naming

```
user/<alias>/msrc-<MSRC-ID>-<short-description>
```

Examples:
```
user/<alias>/msrc-<MSRC-ID>-<short-description>
user/<alias>/msrc-<MSRC-ID>-<short-description>
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
The ReproSteps field contains an HTML template with these sections:
- Attack Scenario
- Fix Description
- Validation/Regression Risk
- Variant Analysis
- Changes Outside Component Area (component table)
- Regression: "Affected By" Bug and Rationale
- Comms: Release notes
- ENS-Specific: Cloud Critical (No), Hot Patchable (No), Localization (No), Dependencies (No), Protocol Changes

---

## 8. Bug Modification Policy

### Golden Rule
**ALL writes to ANY bug field require explicit user approval with a dry run preview.**

### Workflow for ANY Bug Write
```
1. User explicitly asks for a bug field change
2. Skill shows dry run:
   ┌─────────────────────────────────────────────┐
   │ 📝 Proposed Bug Changes (DRY RUN)           │
   │                                              │
   │ Bug: <bug-id>                                │
   │ Field: Triage                                │
   │ Current: "New"                               │
   │ Proposed: "Consider by Triad Shiproom"       │
   │                                              │
   │ Apply this change? [y/n]                     │
   └─────────────────────────────────────────────┘
3. User approves → skill executes the change
4. User declines → skill does nothing
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

## 9. Release Targeting

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
2. For each child bug:
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

**Default config**: `-amd64chk` (x64 debug) for testing.

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
If the `uus-change-tracker` skill is available, use it to track CI builds.
If the `/orchestrator-build-and-test` skill is available, use it for build workflow.

---

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

**3b. Apply Fix**
1. Cherry-pick or manually port the fix from the primary branch
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

**3e. Stage & Review**
1. Stage only intended files (never auto-commit)
2. Show diff to user
3. Let user review before committing

### Phase 4: Build
1. Build each platform repo (§11)
2. Report pass/fail summary only
3. If build fails, show errors and ask user how to proceed

### Phase 5: Validation
1. Deploy to test VM (delegate to `uso-vm-testing` if available, else ask user)
2. Run full repro scenario against fixed binary
3. Verify no crash/vulnerability — not just code path existence
4. Report results

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
3. **Bug ID** — the correct platform bug to link
4. **Reviewers** — from §6 reviewer mapping
5. **IcM ID** — for the IcM link in the description

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

# Step 4: Add reviewers
az repos pr reviewer add --id <PR_ID> --reviewers <alias1> <alias2> --org "https://dev.azure.com/microsoft"
```

**Post-creation verification (mandatory):**
- Confirm title matches §19 format
- Confirm description has all 3 sections and IcM link
- Confirm bug is linked (`az repos pr work-item list --id <PR_ID>`)
- Confirm reviewers are assigned

If any verification fails, fix it immediately before reporting PR as created.
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

This skill is maintained at 2 locations + 1 symlink. **Every update** edits the primary and pushes to GitHub:

| # | Role | Location | Sync Method |
|---|---|---|---|
| 1 | **Primary** | `D:\skill\SKILL.md` | Edit here first |
| 2 | **GitHub** | `github.com/mayankjoshi-ms/msrc-process-agent` | `git add . && git commit -m "<change summary>" && git push` from `D:\skill` |
| 3 | **Copilot runtime** | `C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md` | **Symlink → `D:\skill\SKILL.md`** (auto-synced, no copy needed) |

### Update Sequence (mandatory)
```
1. Edit D:\skill\SKILL.md
2. cd D:\skill && git add . && git commit -m "<summary>" && git push
3. Verify symlink still resolves: (Get-Item "C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md").Target
```

**Never** update only one location. If the symlink is broken, recreate it:
```
New-Item -ItemType SymbolicLink -Path "C:\Users\mayajoshi\.copilot\skills\msrc-process-agent\SKILL.md" -Target "D:\skill\SKILL.md" -Force
```

If any sync step fails, flag it to the user immediately.

---

## 19. PR Title and Description Format

> **⚠️ MANDATORY — When this skill is loaded, this format is the ONLY acceptable PR format.**
> Do NOT generate any other format. Do NOT use HTML. Do NOT invent custom sections.
> Any PR created or updated by this skill MUST follow §19 exactly. No exceptions.

**All PRs must use Markdown format.** ADO PR descriptions support full Markdown rendering — use `##` headings, `**bold**`, `` `code` ``, `|` tables, and `- ` lists. Do NOT use raw HTML tags.

### PR Title Format

```
[<branch>] <short fix description> (MSRC <ID>)
```

| Platform | Example Title |
|---|---|
| Main | `[main] Fix arbitrary memory increment via WIL ProcessLocalStorageData::Acquire (MSRC 163522)` |
| GE | `[GE] Fix arbitrary memory increment via WIL ProcessLocalStorageData::Acquire (MSRC 163522)` |
| GE-LT | `[GE-LT] Fix arbitrary memory increment via WIL ProcessLocalStorageData::Acquire (MSRC 163522)` |
| NI | `[NI] Fix arbitrary memory increment via WIL ProcessLocalStorageData::Acquire (MSRC 163522)` |

Rules:
- Branch name in `[]` brackets at the start — use the short platform name (main, GE, GE-LT, NI, BR, FE, VB)
- Fix description should be concise (one line)
- MSRC ID(s) in parentheses at the end
- For non-MSRC PRs, use `(Bug <ID>)` instead of `(MSRC <ID>)`

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
| MSRC / Scenario | Result |
|---|---|
| <scenario> | <vulnerable result> |

**After fix:**
| MSRC / Scenario | Result |
|---|---|
| <scenario> | <mitigated result> |

<Mention unit tests, regression analysis, VM validation, etc.>
```

### Description Rules
- **Markdown only** — no raw HTML (`<h2>`, `<table>`, `<ul>`, `<b>`, etc.). ADO renders Markdown natively.
- Section headings must be exactly: `## Why is this change being made?`, `## What is being changed?`, `## How was the change tested?`
- Do NOT invent custom sections like "Attack Scenario", "Fix Description", "Variant Analysis", "References", etc.
- Before/after tables are required when repro was performed.
- Files changed list is required in the "What" section.
- Containment feature key and state must be mentioned if applicable.
- MSRC ID and IcM reference go in the "Why" section, not in a separate "References" section.
