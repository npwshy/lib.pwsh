#
# Web Cache
#

class WebCache {
    static [string] $CacheDir = ".";
    static [DateTime] $Expire = (Get-Date 1900/1/1); # likely never expire
    static [string[]] $PurgeList;
    static $HashFunc;
    static $WebHookPreAccess;

    static Init([string]$dir, [DateTime]$exp) {
        [WebCache]::CacheDir = [IO.Path]::GetFullPath($dir)
        [WebCache]::Expire = $exp
        [WebCache]::HashFunc = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider

        log "WebCache.Init: Expire set to: $([WebCache]::Expire.ToString('yyyy\/MM\/dd HH:mm'))"

        [WebCache]::InitPurgeList()
        [WebCache]::ResetWebHook()
    }

    static SetWebHook($cb) { [WebCache]::WebHookPreAccess = $cb }
    static ResetWebHook() { [WebCache]::WebHookPreAccess = [WebCache]::Noop }
    static Noop() {}

    static [string] GetContent([string]$url) {
        $fp = Join-Path ([WebCache]::CacheDir) ([WebCache]::GetCacheFilename($url))
        if (Test-Path $fp) {
            if (($fd = Get-Item $fp).LastWriteTime -gt [WebCache]::Expire) {
                logv "WebCache.GetContent: Loading from cache: $url, $fp [LWT: $($fd.LastWriteTime.ToString('yyyyMMdd.HHmm'))]"
                return (Get-Content $fp) -join("`n")
            } else {
                logv "WebCache.GetContent: Cache file exists but old: $url, $fp, $($fd.LastWriteTime.ToString('yyyyMMdd.HHmm'))"
            }
        } else {
            logv "WebCache.GetContent: Cache does not exist: $url, $fp"
        }

        try {
            # call webhook
            ([WebCache]::WebHookPreAccess).Invoke()

            logc "cyan" "WebCache.GetContent: Accesing $url"
            $res = Invoke-WebRequest -Uri $url -Method Get
            if ($res.StatusCode -eq 200) {
                $res.Content |Out-File -FilePath $fp -Encoding utf8
                logv "WebCache.GetContent: Cache saved: $fp, $($res.Content.Length)"

                [WebCache]::PurgeCacheFile()

                return $res.Content -join("`n")
            } else {
                logerror "WebCache.GetContent: Web access error $($res.StatusCode)"
            }
        } catch {
            logerror "WebCache.GetContent: Web access failed: $_"
        }
        return $null
    }

    static [string] GetCacheFilename([string]$url) {
        $hashcode = ([WebCache]::HashFunc.ComputeHash([Text.Encoding]::UTF8.GetBytes($url)) |%{ $_.ToString("x2") }) -join('')
        return $url -replace '^[^:]+://','' -replace '/$','' -replace '[\.\/]','_' -replace '\?.*','' -replace '$', "-$hashcode"
    }

    static InitPurgeList() {
        $purgeDate = [DateTime]::Now.AddDays(-31)
        $files = Get-ChildItem -File -Path ([WebCache]::CacheDir) |? {$_.LastWriteTime -le $purgeDate } |Sort LastWriteTime
        [WebCache]::PurgeList = $files.FullName
        log "WebCache: PurgeList created: count=$([WebCache]::PurgeList.Count)"
    }

    static PurgeCacheFile() {
        if ([WebCache]::PurgeList.Count) {
            $f = [WebCache]::PurgeList[0]
            Remove-Item -Path $f -Force -Confirm:$false -ErrorAction SilentlyContinue
            [WebCache]::PurgeList = [WebCache]::PurgeList -ne $f
            logv "WebCache: Cache purged: $f"
        }
    }
}