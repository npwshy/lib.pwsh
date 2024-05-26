#
# stdps
#
Set-StrictMode -Version latest

#
# App startup
#
function RunApp($app, $logfile, $gen, $appendMode = $false) {
    if ($global:Args.Count -gt 0) {
        throw Unknown paratemers specified: $($global:Args -join(' '))
    }

    [Logging]::Init($logfile, $gen, $appendMode)
    $app.Run()
    [Logging]::Closelog()
}


#
#--- Logging
#
class Logging {
    static [string] $LogFile;
    static [string] $LockFile;
    static [string] $DateFormat;
    static [string] $Encoding;

    static [bool] $VerboseLogging = $false;

    static Init([string]$fn, [int]$gen) {
        [Logging]::Init($fn, $gen, $false)
    }

    static Init([string]$fn, [int]$gen, [bool]$appendMode) {
        if (-not $fn) {
            [Logging]::LogFile = $null
            Write-Host "Logging.Init: Logging is disabled as no filename specified."
            return;
        }

        [Logging]::Encoding = 'utf8'
        [Logging]::DateFormat = 'yyyy\/MM\/dd HH:mm:ss'
        [Logging]::LogFile = [IO.Path]::GetFullPath($fn)
        [Logging]::LockFile = [Logging]::LogFile + '.lock'
        [Logging]::Locklog()


        if (-not $appendMode) {
            if ($gen) {
                [Logging]::Rotatelogs([Logging]::LogFile, $gen)
            }
            Set-Content -Path ([Logging]::LogFile) -Value $null -Encoding ([Logging]::Encoding)
            log "Logging started: $(Get-Date -Format ([Logging]::DateFormat)) $([Logging]::LogFile)"
        } else {
            log "Logging started in append mode: $(Get-Date -Format ([Logging]::DateFormat)) $([Logging]::LogFile)"
        }
    }

    static WriteLog($m) {
        if ([Logging]::LogFile) {
            Add-Content -Path ([Logging]::LogFile) -Value "$(Get-Date -Format ([Logging]::DateFormat)) $m" -Encoding ([Logging]::Encoding)
        }
    }

    static Locklog() {
        if (-not [Logging]::LockFile) { throw "Logging.locklog LogFile not defined" }

        try {
            $global:PID |Out-File -FilePath ([Logging]::LockFile) -NoClobber
        } catch {
            $lockPID = [int](Get-Content -Path ([Logging]::LockFile))
            if ($proc = Get-Process -Id $lockPID -ErrorAction SilentlyContinue) {
                throw "Lockfile exists and the process is running (PID=$lockPID, Name=$($proc.ProcessName))"
            }

            Write-Host "Lockfile exists but no process exists: (LockPID=$lockPID)"
            $global:PID |Out-File -FilePath ([Logging]::LockFile) # -NoClobber -- allow overwrting the lockfile
        }
    }

    static Closelog() {
        $lockPID = Get-Content -Path ([Logging]::LockFile) -ErrorAction SilentlyContinue
        if ($lockPID -eq $global:PID) {
            Remove-Item -Force -Path ([Logging]::LockFile)
        }
        [Logging]::LogFile = $null
    }

    static Rotatelogs($f, $n) {
        $rf = [Logging]::GetRotateLogFilename($f, $n)
        Remove-Item -Path $rf -Force -Confirm:$false -ErrorAction SilentlyContinue
        ($n-1) .. 0 |%{
            $rfpre = [Logging]::GetRotateLogFilename($f, $_);
            Move-Item -Path $rfpre -Destination $rf -Force -Confirm:$false -ErrorAction SilentlyContinue;
            $rf = $rfpre
        }
        Move-Item -Path $f -Destination $rf -Force -Confirm:$false -ErrorAction SilentlyContinue
    }

    static [string] GetRotateLogFilename($f, $n) {
        $ext = Split-Path -Extension $f
        return $f -replace "$ext$","-$n$ext"
    }

}

function log([string]$txt) {
    Write-Host $txt
    [Logging]::WriteLog($txt)
}

function logv([string]$txt) {
    if ([Logging]::VerboseLogging) { Write-Host $txt }
    [Logging]::WriteLog($txt)
}

function logc([string]$color, [string]$txt) {
    Write-Host -ForegroundColor $color $txt
    [Logging]::WriteLog($txt)
}

function logerror([string]$txt) {
    logc "red" $txt
}
