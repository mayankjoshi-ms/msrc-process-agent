# USO MSRC Infrastructure

Use this skill for MSRC fix infrastructure: VM-to-repo mapping, credentials, build commands, binary deployment, testing methodology, and workflow optimizations. This is the operational reference for executing MSRC fixes across all USO/UUS platforms.

---

## Platform → VM → Repo Mapping

### Undocked Platforms (UUS repo)

| Platform | VM Name | Repo Folder | ADO Repo | Branch Pattern | UUS Version Series | Binary Path on VM |
|---|---|---|---|---|---|---|
| **Main** | — (no VM) | `E:\uus` | `uus` | `main` | latest | — |
| **GE** | `GE` | `E:\uus-ge`¹ | `uus` | `release/v15/XXXXb_gebr` | v15xx | `C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe` |
| **GE-LT** | `LT` | `E:\uus-lt` | `uus` | `release/v15/XXXXb_lt` | v1506 | `C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe` |
| **NI** | `NI` | `E:\uus-ni` | `uus` | `release/v14/XXXXb_ni` | v1407 | `C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe` |
| **BR** | `BR` | `E:\uus-br` | `uus` | `release/v15/XXXXb_br` | v15xx | `C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe` |

¹ GE and GE-LT share the same target branch pattern `release/v15/XXXXb_gebr` for GE, but `E:\uus-ge` is the working repo for GE-specific branches.

### Docked Platforms (os.2020 repo)

| Platform | VM Name | Repo Folder | ADO Repo | Branch Pattern | Binary |
|---|---|---|---|---|---|
| **FE** | `FE` | `F:\fe\src` | `os.2020` | `official/fe_release_svc_XXXXb` | `usosvcimpl.dll` / `MoUsoCoreWorker.exe` |
| **VB** | `VB` | `F:\vb\src` | `os.2020` | `official/vb_release_svc_XXXXb` | `usosvcimpl.dll` / `MoUsoCoreWorker.exe` |

### Other VMs

| VM Name | Purpose | Notes |
|---|---|---|
| **AB** | Unknown / spare | Available but unmapped |

---

## VM Checkpoint Policy

> ⚠️ **Always restore VMs to the `Fresh-VM` Hyper-V checkpoint before starting a new MSRC case.**

Each VM has a `Fresh-VM` checkpoint in Hyper-V — a clean state with the original OS binary, no test artifacts, and pending Windows Updates available (needed for PoC). Before any new MSRC work:

```powershell
# From the host — restore VM to clean state
Restore-VMSnapshot -VMName "<VMName>" -Name "Fresh-VM" -Confirm:$false
Start-VM -VMName "<VMName>"
```

This ensures:
- Original vulnerable binary is present (not a previously fixed version)
- No leftover tools, dumps, or configs from prior MSRCs
- Pending updates are available for PoC to work
- Clean event logs for crash detection

---

## Build & Test Sequencing

> ⚠️ **Never build or test multiple platforms in parallel — it crashes the system.** Always do one platform at a time: build → deploy → test → next platform.

---

## VM Credentials

### Admin Accounts

| VM Type | VMs | Username | Password |
|---|---|---|---|
| **Clients** (desktop OS) | GE, NI, BR, VB | `mj` | `123` |
| **Servers** (server OS) | LT, FE | `Administrator` | `Pass@123#` |

### Local Account

| Username | Password | Notes |
|---|---|---|
| `test` | *(none)* | Local non-admin user, all VMs |

### Connection Template

```powershell
# Connect to a VM via PowerShell Direct (Hyper-V VMBus — no network needed)
$cred = New-Object PSCredential("<username>", (ConvertTo-SecureString "<password>" -AsPlainText -Force))
$s = New-PSSession -VMName "<VMName>" -Credential $cred -ErrorAction Stop

Invoke-Command -Session $s -ScriptBlock {
    # Your commands here
}

Remove-PSSession $s
```

> ⚠️ Sessions do NOT persist across PowerShell calls — recreate `$cred` and `New-PSSession` each time.

---

## Tools on VMs

### Required Tools for MSRC Testing

| Tool | Expected Path | Purpose |
|---|---|---|
| **CDB** (debugger) | `C:\tools\cdb\cdb.exe` | Register poisoning, breakpoints, crash dumps |
| **PoC binary** | `C:\temp\UsoApproveWorkMapRaceNative.exe` | Race condition PoC for MSRC 155686 |
| **sfpcopy** | Host: `C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\sfpcopy.exe` | Copy/replace system-protected binaries |
| **VC runtimes** | `C:\Windows\System32\vcruntime140.dll` / `vcruntime140d.dll` | Required for debug binaries |

### Deploying Tools to a VM

```powershell
# Copy file from host to VM
$s = New-PSSession -VMName "<VMName>" -Credential $cred
Copy-Item -ToSession $s -Path "<host-path>" -Destination "<vm-path>"
Remove-PSSession $s
```

### Deploying Fixed Binaries

```powershell
$s = New-PSSession -VMName "<VMName>" -Credential $cred

# 1. Stop the service
Invoke-Command -Session $s { Stop-Service usosvc -Force; Start-Sleep 3 }

# 2. Backup original
Invoke-Command -Session $s { Copy-Item "C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe" "C:\temp\MoUsoCoreWorker.exe.ORIG" }

# 3. Copy sfpcopy and new binary
Copy-Item -ToSession $s -Path "C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\sfpcopy.exe" -Destination "C:\temp\sfpcopy.exe"
Copy-Item -ToSession $s -Path "<repo>\Output\Bin\Orchestrator\<Config>\x64\MoUsoCoreWorker.exe" -Destination "C:\temp\MoUsoCoreWorker.exe.FIXED"

# 4. Replace using sfpcopy
Invoke-Command -Session $s { & C:\temp\sfpcopy.exe "C:\temp\MoUsoCoreWorker.exe.FIXED" "C:\Windows\uus\packages\preview\AMD64\MoUsoCoreWorker.exe" }

# 5. RESTART the VM (mandatory — ensures clean service load with new binary)
Remove-PSSession $s
Restart-VM -Name "<VMName>" -Force -Wait
# Wait for VM to boot, then reconnect
Start-Sleep 30
$s = New-PSSession -VMName "<VMName>" -Credential $cred -ErrorAction Stop
```

> ⚠️ **Always restart the VM after deploying a fixed binary.** Simply restarting the service is not sufficient — the OS may cache the old binary or hold file locks. A full VM restart guarantees the new binary is loaded cleanly.

### Verify Feature Staging Key Is Enabled

After restart, before running any tests, **confirm the MSRC fix containment is active**:

```powershell
Invoke-Command -Session $s -ScriptBlock {
    # Check if the feature staging key is enabled
    # Undocked: check OneSettings / feature staging registry
    $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Update\FeatureStaging"
    if (Test-Path $key) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue | Format-List
    }

    # Also check via WIL feature staging (runtime check)
    # The binary itself logs feature state on startup — check usosvc log:
    $log = Get-Content "$env:ProgramData\USOShared\Logs\System\MoUsoCoreWorker*.etl" -ErrorAction SilentlyContinue
    # Or check event log for feature staging state
    Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WindowsUpdateClient/Operational'; StartTime=(Get-Date).AddMinutes(-5)} -MaxEvents 10 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match "MSRC|Feature" } | Select-Object TimeCreated, Message
}
```

> If the containment feature is **not enabled**, the fix code path will NOT execute and the vulnerability remains exploitable. The test results would be meaningless. Always verify before testing.

---

## Build Outputs by Platform

> ⚠️ **Always build in RELEASE mode (`-amd64fre`).** Debug builds are larger, may crash on VMs due to version mismatch with runtime DLLs, and do not represent what ships to customers. Use release for all testing and validation.

| Platform | Build Command | Output Binary |
|---|---|---|
| **Main** | `E:\uus\build\dazzle.ps1 -amd64fre; cd src\orchestrator; bz` | `E:\uus\Output\Bin\Orchestrator\Release\x64\MoUsoCoreWorker.exe` |
| **GE** | `E:\uus-ge\build\dazzle.ps1 -amd64fre; cd src\orchestrator; bz` | `E:\uus-ge\Output\Bin\Orchestrator\Release\x64\MoUsoCoreWorker.exe` |
| **GE-LT** | `E:\uus-lt\build\dazzle.ps1 -amd64fre; cd src\orchestrator; bz` | `E:\uus-lt\Output\Bin\Orchestrator\Release\x64\MoUsoCoreWorker.exe` |
| **NI** | `E:\uus-ni\build\dazzle.ps1 -amd64fre; cd src\orchestrator; bz` | `E:\uus-ni\Output\Bin\Orchestrator\Release\x64\MoUsoCoreWorker.exe` |
| **BR** | `E:\uus-br\build\dazzle.ps1 -amd64fre; cd src\orchestrator; bz` | `E:\uus-br\Output\Bin\Orchestrator\Release\x64\MoUsoCoreWorker.exe` |

---

## Network Requirements

| VM | Network Needed? | Setup Command | Notes |
|---|---|---|---|
| **All VMs** | ✅ Yes (for PoC) | `Connect-VMNetworkAdapter -VMName "<VM>" -SwitchName "Default Switch"` | PoC requires internet for PrimeScan (~120s) |

If a VM has APIPA address (169.254.x.x), it's disconnected. Run the connect command from the **host**.

---

## Key RVAs by Platform (MSRC 155686)

| Platform | UUS Version | Approve RVA | Notes |
|---|---|---|---|
| **NI** | v1407.2606.10012.0 | `0x851FC` | Confirmed via CDB crash |
| **LT** | v1506.2606.8022.0 | `0x85FBB` | Matches researcher's windbg_repro.txt |
| **GE** | v15xx | Site 1 already fixed | Only Site 2 (EvaluateIpuMode) needed fix |

---

## Topic Branch Naming

```
user/<alias>/msrc-<MSRC-ID>-<XXXXb>_<platform>
```

Examples:
- `user/mayajoshi/msrc-155686-2701b_ge`
- `user/mayajoshi/msrc-155686-2701b_lt`
- `user/mayajoshi/msrc-155686-2701b_ni`
- `user/mayajoshi/msrc-155686-2610b_br`
- `user/mayajoshi/msrc-155686-fe-2701b` (docked — slightly different pattern)

---

## Quick Reference: Full MSRC Workflow per Platform

> **Checkpoint after every major step.** Use the session checkpoint mechanism to save progress so work can be resumed if interrupted.

### Step-by-step with checkpoints:

```
1. BRANCH SETUP
   - cd <repo-folder>
   - git fetch origin && git checkout -b user/<alias>/msrc-<ID>-<branch> origin/<target-branch>
   → 📌 Checkpoint: "Branch created for <platform>"

2. APPLY FIX + CONTAINMENT
   - Port the code fix and containment metadata
   - Verify porting completeness (all files, all hunks)
   → 📌 Checkpoint: "Fix applied to <platform>"

3. BUILD
   - . build\dazzle.ps1 -amd64chk; cd src\orchestrator; bz
   - Confirm build success (zero errors)
   → 📌 Checkpoint: "Build succeeded for <platform>"

4. BEFORE-FIX TEST (with ORIGINAL vulnerable binary)
   - Deploy tools (CDB, PoC) to VM if not already present
   - Ensure VM has network connectivity
   - Run attacker's PoC / CDB register poisoning → expect crash
   → 📌 Checkpoint: "Before-fix crash confirmed on <platform>"

5. DEPLOY FIXED BINARY
   - Backup original binary
   - Copy fixed binary via sfpcopy
   - **RESTART the VM** (mandatory)
   - Reconnect and verify feature staging key is enabled
   → 📌 Checkpoint: "Fixed binary deployed to <platform>"

6. AFTER-FIX TEST (with FIXED binary)
   - Run the SAME attacker PoC / CDB test → expect NO crash
   - Stress test: multiple runs, high thread count
   - Save all evidence (CDB logs, PoC output, event logs)
   → 📌 Checkpoint: "After-fix validation passed on <platform>"

7. COMMIT & PUSH
   - Commit with format: [MSRC XXXXXX] : <Bug title>
   - Push to remote
   → 📌 Checkpoint: "Committed and pushed for <platform>"

8. CREATE PR
   - Follow §19 format from msrc-process-agent skill
   - Link platform bugs (Main OS + SafeOS DU)
   → 📌 Checkpoint: "PR created for <platform>"
```

---

## Regression Analysis (Mandatory)

> ⚠️ **Always run regression analysis before creating a PR.** Every MSRC fix must be reviewed for unintended side effects.

### What regression analysis covers:

1. **Lock scope impact** — does the new lock (shared_lock, unique_lock) introduce deadlocks, priority inversions, or performance regressions? Check all callers of the modified function.

2. **Code path completeness** — does the fix cover ALL vulnerable entry points? Cross-reference the researcher's report with the actual code to ensure no variant is missed.

3. **Feature staging gate** — is the fix properly gated behind `Feature_MSRCXXXXXX::IsEnabled()`? If the feature is disabled, does the original code path still work correctly (no behavior change)?

4. **Cross-platform consistency** — is the fix logically identical across all platforms? Account for expected differences (refactored code, different APIs) but flag any missing hunks.

5. **Service stability** — after deploying the fix, does the service start, run scans, and shut down cleanly? Check event logs for new errors introduced by the fix.

### When to run:

- **After applying the fix** (before build) — code-level review of the change
- **After successful after-fix test** — confirm no new errors in event logs, no service instability
- **Before creating the PR** — final check that the fix is complete and safe

### How to invoke:

If the `regression-reviewer-agent` skill is available, delegate to it with the diff. Otherwise, manually review:

```powershell
# Generate the diff for review
cd <repo-folder>
git diff origin/<target-branch>..HEAD -- '*.cpp' '*.h' ':!*featurestaging*'
```

Inspect every changed line for:
- Removed error handling or return paths
- Changed lock ordering that could deadlock
- Missing else-branch in feature gate (old behavior must be preserved when feature is off)
- Accidental changes to unrelated code

---

## Testing Philosophy: Attack-Based Validation

> ⚠️ **Tests MUST replicate what the attacker does, not just exercise code paths.**

### Principles

1. **Use the researcher's PoC** — the actual exploit binary or technique from the MSRC submission. If the researcher provided a PoC, that IS the test. Do not substitute with a simpler or "equivalent" test.

2. **Reproduce the exact attack scenario** — same race conditions, same thread counts, same COM calls. The goal is to trigger the vulnerability, not to verify code coverage.

3. **Before-fix MUST crash** — if the before-fix test doesn't crash, the test is not valid. The vulnerability must be proven exploitable before the fix can be validated. If before-fix doesn't crash, escalate technique (register poisoning via CDB, page heap, higher thread count, longer duration).

4. **After-fix MUST survive the same attack** — run the identical PoC with identical parameters against the fixed binary. Zero crashes across multiple stress runs = fix validated.

5. **Never declare "fix works" based on**:
   - Code path inspection / disassembly alone
   - A test that doesn't match the attack vector
   - A single short run (use stress: high threads, long duration, multiple runs)
   - The absence of a PoC (ask the user or researcher for one)

### Debugger: Use WinDbg/CDB When the Attacker Did

Use the same tools the attacker/researcher used. If the researcher's PoC or repro steps involve WinDbg or CDB (e.g., register poisoning, breakpoints, page heap), replicate their exact technique. Do NOT substitute with a different debugger or skip the debugger step.

If the researcher reproduced without a debugger (e.g., standalone PoC binary that crashes on its own), run the PoC the same way — no debugger needed.

**Rule: Match the attacker's methodology exactly.**

```
1. Identify the vulnerable instruction (RVA from researcher or disassembly)
2. Set CDB breakpoint at that RVA
3. When hit, poison the register used for memory access (e.g., rdx=dead0000dead0000)
4. Continue execution → if UAF exists, the poisoned pointer causes immediate AV
5. Before-fix: AV proves the vulnerability
6. After-fix: breakpoint never hit (guarded by lock/feature flag) = fix works
```

### What a valid test report looks like

```
BEFORE FIX (original binary):
  - Binary: MoUsoCoreWorker.exe v1407.2606.10012.0 (original, 5,247,984 bytes)
  - Attack: PoC 60 threads, 180s, CDB bp at +0x851FC, rdx poisoned
  - Result: c0000005 Access Violation at MoUsoCoreWorker+0x851FC
  - Evidence: crash dump saved, call stack captured

AFTER FIX (fixed binary):
  - Binary: MoUsoCoreWorker.exe (fixed, 5,267,456 bytes)
  - Feature staging: Feature_MSRC155686 = EnabledByDefault (verified)
  - VM restarted: Yes
  - Attack: SAME PoC, SAME params, CDB bp at +0x851FC
  - Result: 0 breakpoint hits, 0 crashes, process survived full stress test
  - Evidence: CDB log shows 0 AV, 0 BP hits; event log clean
```

---

## Lessons Learned (Cross-MSRC)

Hard-won lessons from MSRC-155686, MSRC-156290, and MSRC-170271. Apply these proactively on every future case.

### Debugger & VM Environment

#### 1. CET (Shadow Stack) blocks debugger RIP/RSP tricks
Modern VMs have CET enabled. Researcher techniques like `eq @rsp <addr>` or `r rip=<func>` trigger shadow stack violations, NOT the intended behavior. **Before starting any debugger repro that manipulates RIP/RSP:**

```cmd
:: Check if CET is enabled
bcdedit /enum {current} | findstr "usermodecet"

:: Disable CET if needed (requires reboot)
bcdedit /set {current} usermodecet off
shutdown /r /t 0
```

> Only disable CET when the researcher's repro requires RIP/RSP manipulation. If the PoC is a standalone binary, CET doesn't matter.

#### 2. Page heap doesn't survive service restart
When UsoSvc crashes and restarts, the new process does NOT have page heap enabled. You must:
1. Re-run `gflags /p /enable <binary> /full` after each crash
2. Restart the service: `net stop usosvc & net start usosvc`
3. Re-attach the debugger to the new PID

#### 3. RVAs differ per build — always translate
Researcher RVAs are for THEIR build. Your VM has a different build → different RVAs. Always:
```
0:000> x UsoSvcImpl!<FunctionName>
```
Then compute: `RVA = symbol_address - module_base`

#### 4. Symbol server needs internet on VM
CDB/WinDbg can't download PDBs if the VM has no internet. Either:
- Connect VM to `Default Switch` (gives internet via NAT)
- Or pre-copy the matching PDB from the host to `C:\symbols` on the VM

```powershell
# From host — give VM internet
Connect-VMNetworkAdapter -VMName "<VM>" -SwitchName "Default Switch"
```

### PoC & Repro Scripts

#### 5. ASCII-only in generated scripts — no Unicode
PowerShell 5.1 on VMs cannot handle em-dashes (`—`), box-drawing chars, or other non-ASCII without a UTF-8 BOM. **All generated PoC/repro scripts must use ASCII only:**
- Replace `—` with `--`
- Replace `│├└` with `|+-`
- Replace `✅❌⚠️` with `[OK][FAIL][WARN]`

#### 6. Study the researcher's working PoC FIRST
Before writing a custom repro script, **always read the researcher's exact PoC code** to understand:
- What validation checks their setup passes
- What exact sequence of API calls they use
- What tools/dependencies they assume

Building a repro from scratch and hitting validation errors one-by-one (hash mismatch, BOM in JSON, malformed catalog, etc.) wastes hours. The researcher already solved these problems.

#### 7. Reuse existing `test` user — don't create users
All VMs have a local standard user `test` (no password). PoC scripts should accept `-UserName test` and reuse it. Never try to create a new user — it adds complexity and may conflict with existing accounts.

### Build & Deploy

#### 8. Build on the MATCHING branch for the target VM
WinRT APIs have a two-component architecture (e.g., `Windows.Management.Update.dll` in System32 + `MoUsoCoreWorker.exe` in UUS). These must be interface-compatible. **A main-branch binary deployed to a GE-build VM will cause interface mismatch errors.** Always:
- Identify the VM's OS build/branch
- Build from the corresponding repo branch
- Never cross-deploy between branches

#### 9. Use `sfpcopy` for protected system files
Normal file copy fails on `C:\Windows\UUS\` and similar protected directories. Use:
```
C:\temp\sfpcopy.exe "<source>" "<destination>"
```
Tool location on host: `C:\Users\mayajoshi\OneDrive - Microsoft\Desktop\Tools\sfpcopy.exe`

Pre-stage it to `C:\temp\sfpcopy.exe` on every VM at the start of an MSRC case.

### Code & PR

#### 10. Separate containment checks — no compound conditions
Reviewers reject compound `if` statements that mix containment and fix logic:
```cpp
// ❌ BAD — compound condition
if (Feature_MSRC170271::IsEnabled() && !IsSystemOrAdmin())

// ✅ GOOD — separated
if (Feature_MSRC170271::IsEnabled())
{
    if (!IsSystemOrAdmin())
    {
        // fix logic
    }
}
```

#### 11. Check feature gates before porting to downlevel
Some vulnerable code only exists on platforms where a feature gate is enabled (e.g., `Feature_UOvNext` gates WinRT provider code). **Before porting a fix to a platform:**
1. Check if the vulnerable code path exists on that platform's branch
2. Check if the controlling feature gate is enabled on that platform
3. If the code doesn't exist or the gate is disabled → platform is NOT vulnerable → close bug as Won't Fix

This saved work on MSRC-170271: NI, FE, VB were confirmed not vulnerable because `Feature_UOvNext` wasn't enabled.

### Workflow Optimizations

#### 12. Pre-flight checklist before ANY VM testing

Run this checklist before wasting time on a failed test:

```
□ VM restored from Fresh-VM checkpoint (for new MSRC)
□ VM has network connectivity (not 169.254.x.x / APIPA)
□ VC++ runtimes present (vcruntime140.dll for release builds)
□ CDB/debugger tools present at C:\tools\cdb\ (if needed)
□ sfpcopy present at C:\temp\sfpcopy.exe
□ PoC files deployed to C:\temp\ or C:\poc\
□ Correct binary backed up (C:\temp\*.ORIG)
□ Fixed binary built from MATCHING branch (not main on GE VM!)
□ Feature staging key verified as enabled (after deploy + restart)
□ CET disabled (if researcher used RIP/RSP manipulation)
□ Page heap enabled (if needed): gflags /p /enable <binary> /full
□ Symbols accessible (internet or pre-copied PDBs)
```

#### 13. CDB-via-remoting working template

The only reliable pattern for running CDB through PowerShell Direct:

```powershell
# On the VM — wrap CDB in cmd.exe, redirect all output to file
Invoke-Command -Session $s -ScriptBlock {
    & cmd.exe /c 'C:\tools\cdb\cdb.exe -p <PID> -cf C:\temp\script.txt > C:\temp\cdb_log.txt 2>&1'
}

# Then retrieve the log
Copy-Item -FromSession $s -Path "C:\temp\cdb_log.txt" -Destination "<host-path>"
```

> ⚠️ Do NOT try: `Start-Process cdb.exe`, direct pipe, or `Invoke-Expression`. They all fail or hang in PS remoting.

#### 14. Crash detection — never rely on process-alive check

A process that stops may have exited normally (idle timeout), not crashed. Reliable crash detection:

```powershell
# 1. Check Windows Error Reporting (most reliable)
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-10)} |
    Where-Object { $_.Message -match "MoUsoCoreWorker|UsoSvc" }

# 2. Check for crash dumps
Get-ChildItem "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" -Recurse -Filter "*.dmp"

# 3. If using CDB — search log for Access Violation
Select-String -Path "C:\temp\cdb_log.txt" -Pattern "Access violation|UNEXPECTED HIT|Breakpoint 0 hit"
# Do NOT match "dead0000" — it appears in the breakpoint SETUP echo, not just actual hits
```
