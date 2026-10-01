<#
Shared helpers for this repo's patch scripts.

WHY THIS EXISTS
---------------
On some Windows setups an elevated process still cannot MODIFY or DELETE an
existing file under Program Files, while creating a NEW file in the very same
folder works fine. That asymmetry is the signature of a filtering layer
intercepting the write - an overlay/union file system, a container sandbox, or
a security product's file protection. Raising the integrity level does not
help, because the filter sits below the token check. Patching browser\omni.ja
in place then fails with "access denied" no matter what.

A process started by the Task Scheduler under the SYSTEM account is NOT a child
of the calling session, so it escapes that layer entirely. That is the escape
hatch these helpers automate.

CHILD-SCRIPT CONTRACT
---------------------
Any script driven by Invoke-SystemTask must accept:

    -AsSystem             marks "this process is the SYSTEM copy"
    -UserProfile <path>   user profile root; the child rebuilds APPDATA,
                          LOCALAPPDATA, TEMP and TMP from it, because as SYSTEM
                          those would otherwise resolve to the system profile
    -LogFile <path>       transcript path; a SYSTEM session has no console, so
                          the caller can only read back a file
#>

function Test-WritableFile {
    # Opens the file for read/write WITHOUT touching its contents and closes it.
    # $false means a filter driver or ACL denies writes to this existing file.
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        $fs.Close()
        return $true
    } catch {
        return $false
    }
}

function Initialize-SystemSession {
    # Call once, right at the top of a script that may be re-executed as SYSTEM.
    # Restores the invoking user's environment and starts a transcript so the
    # parent process can read back what happened.
    param(
        [switch]$AsSystem,
        [string]$UserProfile = '',
        [string]$LogFile = ''
    )
    if (-not $AsSystem) { return }

    if ($UserProfile -and (Test-Path $UserProfile)) {
        $env:USERPROFILE  = $UserProfile
        $env:APPDATA      = Join-Path $UserProfile 'AppData\Roaming'
        $env:LOCALAPPDATA = Join-Path $UserProfile 'AppData\Local'
        $env:TEMP         = Join-Path $UserProfile 'AppData\Local\Temp'
        $env:TMP          = $env:TEMP
    }

    if ($LogFile) {
        try { Start-Transcript -Path $LogFile -Force | Out-Null } catch { }
    }
}

function Complete-SystemSession {
    # Flushes the transcript. Safe (and a no-op) outside SYSTEM mode.
    param(
        [switch]$AsSystem,
        [string]$LogFile = ''
    )
    if ($AsSystem -and $LogFile) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}

function Invoke-SystemTask {
    # Registers a one-shot scheduled task that runs $ScriptPath as SYSTEM with
    # the child-script contract above, waits for it, echoes its transcript, and
    # always removes the task again.
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$ScriptArgs = @(),
        [string]$TaskName = 'FirefoxPatchAsSystem',
        [int]$TimeoutMinutes = 15,
        [string]$LogFile = ''
    )

    if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }

    if (-not $LogFile) {
        $LogFile = Join-Path $env:TEMP ('firefox-patch-system-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
    }
    if (Test-Path $LogFile) { Remove-Item $LogFile -Force -ErrorAction SilentlyContinue }

    # The Task Scheduler takes ONE command line string, so anything containing a
    # space (e.g. "C:\Program Files\Mozilla Firefox") has to be quoted here.
    $extra = @()
    foreach ($a in $ScriptArgs) {
        if ($a -match '\s') { $extra += ('"' + $a + '"') } else { $extra += $a }
    }
    $argParts = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"' + $ScriptPath + '"')
        '-AsSystem'
        '-UserProfile', ('"' + $env:USERPROFILE + '"')
        '-LogFile', ('"' + $LogFile + '"')
    ) + $extra
    $argString = $argParts -join ' '

    Write-Host ''
    Write-Host 'Writes to the Firefox install directory were refused in this session.'
    Write-Host 'Re-running the same script as SYSTEM through a scheduled task, which'
    Write-Host 'bypasses overlay sandboxes and file-protection filter drivers.'
    Write-Host ''
    Write-Host "  task : $TaskName"
    Write-Host "  log  : $LogFile"
    Write-Host '  note : the profile menu is unavailable in SYSTEM mode, so the'
    Write-Host '         recommended (install-default) profile is used'
    Write-Host ''

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes)

    $state = ''
    $result = -1
    try {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName

        $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
        do {
            Start-Sleep -Seconds 2
            $state = (Get-ScheduledTask -TaskName $TaskName).State
        } while ($state -eq 'Running' -and (Get-Date) -lt $deadline)
        Start-Sleep -Seconds 1

        $result = (Get-ScheduledTaskInfo -TaskName $TaskName).LastTaskResult
    } finally {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-Host '--- begin output of the SYSTEM session ---'
    if (Test-Path $LogFile) {
        Get-Content $LogFile | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host '(the SYSTEM session produced no log file)'
    }
    Write-Host '--- end output of the SYSTEM session ---'
    Write-Host ''

    if ($state -eq 'Running') { throw "The SYSTEM task '$TaskName' did not finish within $TimeoutMinutes minutes." }
    if ($result -ne 0) { throw "The SYSTEM task failed (LastTaskResult = $result). See its output above." }
    return $true
}

function Resolve-SystemFallback {
    # Decides whether the caller should hand its work to a SYSTEM task.
    # Returns $true when the work HAS ALREADY been done by the SYSTEM copy, so
    # the caller should simply return; $false when the caller should carry on
    # in this process.
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$TargetFile,
        [string[]]$ScriptArgs = @(),
        [string]$TaskName = 'FirefoxPatchAsSystem',
        [switch]$AsSystem,
        [switch]$Force,
        [switch]$Disabled
    )

    if ($AsSystem) {
        if (-not (Test-WritableFile -Path $TargetFile)) {
            throw "Cannot open $TargetFile for writing even when running as SYSTEM. Something is blocking writes below the token level."
        }
        return $false
    }

    if (-not $Force -and (Test-WritableFile -Path $TargetFile)) { return $false }

    if ($Disabled) {
        throw ("Cannot open $TargetFile for writing (access denied). This normally means an overlay file system, a container sandbox or a security product is blocking writes to the install directory - elevation does not help. Re-run without -NoSystemFallback to let the script retry itself as SYSTEM.")
    }

    Invoke-SystemTask -ScriptPath $ScriptPath -ScriptArgs $ScriptArgs -TaskName $TaskName | Out-Null
    Write-Host 'Done. Start Firefox and open the AI chatbot sidebar (Ctrl+Alt+X).'
    return $true
}
