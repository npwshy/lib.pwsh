#
# stdps
#
Set-StrictMode -Version latest

#
# App startup
#

function __RunApp($app, $logfile, $gen, $appendMode = $false) {
    Remove-Item ($logfile + ".lock") -Force -Confirm:$false -Verbose:1 -ErrorAction Ignore
    RunApp $app $logfile $gen $appendMode
}

function RunApp($app, $logfile, $gen, $appendMode = $false) {
    if (!(Get-Variable -Scope global -Name Args -ErrorAction SilentlyContinue)) {
        $Global:Args = @()
    }
    if ($global:Args.Count -gt 0) {
        throw "Unknown paratemer(s) specified: $($global:Args -join(' '))"
    }

    [Logging]::Init($logfile, $gen, $appendMode)
    $appObject = $app -is [String] ? (Invoke-Expression "$app::New()")
        : $app -is [System.Type] ? $app::New() : $app
    $appObject.Run()
    [Logging]::Closelog()
}


#
#--- Logging
#
class Logging {
    static [string] $LogFile;
    static [string] $LockFile;
    static [string] $DateFormat = 'yyyy\/MM\/dd HH:mm:ss';
    static [string] $Encoding = 'utf-8';
    static $WriteStream;

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

        # These two must not be set in Init() as it overwrites caller's setting
        #[Logging]::Encoding = 'utf-8'
        #[Logging]::DateFormat = 'yyyy\/MM\/dd HH:mm:ss'
        [Logging]::LogFile = [IO.Path]::GetFullPath($fn)
        [Logging]::LockFile = [Logging]::LogFile + '.lock'
        [Logging]::Locklog()


        $msg = ""
        if (-not $appendMode) {
            if ($gen) {
                [Logging]::Rotatelogs([Logging]::LogFile, $gen)
            }
            $msg = "Logging started:"
        } else {
            $msg = "Logging started in append mode:"
        }

        [Logging]::WriteStream = [IO.StreamWriter]::New([Logging]::LogFile, $appendMode, [Text.Encoding]::GetEncoding([Logging]::Encoding))
        [Logging]::WriteStream.AutoFlush = $true
        log "$($global:PSCommandPath) $msg $(Get-Date -Format ([Logging]::DateFormat)) $([Logging]::LogFile)"
    }

    static WriteLog($m) {
        if ([Logging]::LogFile) {
            #Add-Content -Path ([Logging]::LogFile) -Value "$(Get-Date -Format ([Logging]::DateFormat)) $m" -Encoding ([Logging]::Encoding)
            #[IO.File]::AppendAllText([Logging]::LogFile, "$(Get-Date -Format ([Logging]::DateFormat)) $m`n", [Text.Encoding]::GetEncoding([Logging]::Encoding))
            [Logging]::WriteStream.Write("$(Get-Date -Format ([Logging]::DateFormat)) $m`n")
            [Logging]::WriteStream.Flush()
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
        if ([Logging]::LockFile) {
            $lockPID = Get-Content -Path ([Logging]::LockFile) -ErrorAction SilentlyContinue
            if ($lockPID -eq $global:PID) {
                Remove-Item -Force -Path ([Logging]::LockFile)
            }
        }
        if ([Logging]::WriteStream) {
            [Logging]::WriteStream.Close()
            [Logging]::WriteStream = $null
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

#
# rotating file(s)
#
function rotatefile($fn, $gen) {
    [Logging]::Rotatelogs($fn, $gen)
}

#
# Getting value from hashtable
#
function getv($h, $k, $def) { return $h.Contains($k) ? $h.$k : $def }

function getvk2($h, $k1, $k2, $def) { return $h.Contains($k1) ? $h.$k1 : $h.Contains($k2) ? $h.$k2 : $def }


#
# Array Math
#
function addarray([int[]]$a) {
    $s = 0
    $a |%{ $s += $_ }
    $s
}

function addarray([float[]]$a) {
    $s = 0.0
    $a |%{ $s += $_ }
    $s
}
