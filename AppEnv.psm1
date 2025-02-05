#
# AppEnv
#

class AppEnv {
    static [hashtable] $p = @{};
    static Init($fp) {
        logv "AppEnv: Init with $fp"
        $jd = Get-Content ([IO.Path]::GetFullPath($fp)) |ConvertFrom-Json -Depth 10 -AsHashtable
        foreach ($k in $jd.Keys |? { $_ -match '^[A-Za-z]' }) {
            if ($global:PSBoundParameters.count -eq 0 -or -not $global:PSBoundParameters.Keys.Contains($k)) {
                <#
                # Param $k is not set in command line
                # scope must be globa as scope=script will add vars in this script
                #>
                [AppEnv]::Set($k, $jd.$k)
            } else {
                logv "AppEnv: setting overridden by commandline param: $k"
            }
        }
        [AppEnv]::setLastModified($fp)
    }

    static setLastModified([string]$fp) {
        $keyLM = 'LastModified'
        if (-not [AppEnv]::p.Contains($keyLM)) { return }
        if ([AppEnv]::p.$keyLM -notmatch '%%%AutoUpdate%%%') { return }

        $file = Split-Path -Leaf $fp
        $lm = (Get-Item $fp).LastWriteTime
        foreach ($fdesc in [AppEnv]::getLastModifiedFiles()) {
            if ($fdesc.LastWriteTime -gt $lm) {
                $lm = $fdesc.LastWriteTime
                $file = $fdesc.Name
            }
        }
        [AppEnv]::Set($keyLM, "$($lm.ToString('yyyy\/M\/d HH:mm:ss')) ($($file))")
    }

    static [object] getLastModifiedFiles() {
        $keyLMF = 'LastModifiedFiles'
        $keyLMM = 'LastModifiedFilesMatches'
        $rc = @()
        if ([AppEnv]::p.Contains($keyLMF)) {
            $files= @(Get-ChildItem ([AppEnv]::p.$keyLMF -split(',') |% { $_.Trim() }))
            logv "AppEnv: LastModifiedFiles += $($files.Name -join(','))"
            $rc += $files
         }
         if ([AppEnv]::p.Contains($keyLMM)) {
            $files = @(Get-ChildItem -File |? { $_ -match [AppEnv]::p.$keyLMM })
            logv "AppEnv: LastModifiedFiles += $($files.Name -join(','))"
            $rc += $files
         }
         return $rc
    }

    static Set($k, $v) {
        if ($v) {
            [AppEnv]::p.$k = $v
            $vn = $k -replace '\.','_'
            Set-Variable -Name $vn -Scope global -Value $v
        }
    }

    static [Object] Get($k) {
        if ([AppEnv]::p.Contains($k)) { return [AppEnv]::p.$k }
        throw "ERROR! No data in AppEnv key:$k"
    }

    static [Object] Get($k, $def) {
        return [AppEnv]::p.Contains($k) ? [AppEnv]::p.$k : $def
    }
}
