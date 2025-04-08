#
# Web Cache
#

class WebCache {
    static [string] $CacheDir = ".";
    static [DateTime] $Expire = (Get-Date 1900/1/1); # likely never expire
    static $PurgeList;
    static [int] $PurgeBeforeDays = 31;
    static $HashFunc;
    static $WebHookPreAccess;
    static [string] $UserAgent;
    static [int] $ThrottlingMilliseconds;
    static [DateTime] $LastCall;
    static [hashtable] $TrottlingMillisecondsPerHost;

    static Init([string]$dir, [DateTime]$exp) {
        [WebCache]::CacheDir = [IO.Path]::GetFullPath($dir)
        [WebCache]::Expire = $exp
        [WebCache]::HashFunc = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider

        [WebCache]::SetUserAgent($null)

        log "WebCache.Init: Expire set to: $([WebCache]::Expire.ToString('yyyy\/MM\/dd HH:mm'))"

        [WebCache]::InitPurgeList()
        [WebCache]::ResetWebHook()
        [WebCache]::InitThrottlingParam()
    }

    static SetWebHook($cb) { [WebCache]::WebHookPreAccess = $cb }
    static ResetWebHook() { [WebCache]::WebHookPreAccess = [WebCache]::Noop }
    static InitThrottlingParam() {
        [WebCache]::LastCall = [DateTime]0
        [WebCache]::ThrottlingMilliseconds = 0
        [WebCache]::TrottlingMillisecondsPerHost = @{}
    }
    static Noop() {}

    #
    # Throttling of accessing web site
    #
    static SetThrottling([int]$ms) {
        [WebCache]::ThrottlingMilliseconds = $ms
        logv "WebCache: Throttling set=$ms"
    }
    static SetThrottling([int]$ms, [string]$hostname) {
        [WebCache]::TrottlingMillisecondsPerHost.$hostname = $ms
        logv "WebCache: Throttling set=$ms for $hostname"
    }
    static Throttling($url) {
        $hn = ([URI]$url).Host
        $ms = [WebCache]::TrottlingMillisecondsPerHost.Contains($hn) ? [WebCache]::TrottlingMillisecondsPerHost.$hn : [WebCache]::ThrottlingMilliseconds
        $wait = $ms - ([DateTime]::Now - [WebCache]::LastCall).TotalMilliSeconds
        if ($wait -gt 0) {
            logv "WebCache: Throttling $wait ms Host:$hn"
            Start-Sleep -Milliseconds $wait
        }
        [WebCache]::LastCall = [DateTime]::Now
    }

    static [string] GetContent([string]$url) { return [WeBCache]::GetContent($url, [WebCache]::Expire) }

    static [string] GetContent([string]$url, [DateTime]$expire) {
        $fp = Join-Path ([WebCache]::CacheDir) ([WebCache]::GetCacheFilename($url))
        if (Test-Path $fp) {
            if (($fd = Get-Item $fp).LastWriteTime -gt $expire) {
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

            [WebCache]::Throttling($url)
            logc "cyan" "WebCache.GetContent: Accesing $url UserAgent: $([WebCache]::UserAgent)"
            $res = Invoke-WebRequest -Uri $url -Method Get -SkipHeaderValidation -UserAgent "$([WebCache]::UserAgent)"
            if ($res.StatusCode -eq 200) {
                $res.Content |Out-File -FilePath $fp -Encoding utf8
                logv "WebCache.GetContent: Cache saved: $fp, $($res.Content.Length)"

                [WebCache]::PurgeCacheFile()

                return $res.Content -join("`n")
            } else {
                logerror "WebCache.GetContent: Web access error $($res.StatusCode)"
            }
        } catch {
            logerror "WebCache.GetContent: Web access failed: $_ (URL=$url, fp=$fp)"
        }
        return $null
    }

    static [string] GetCacheFilename([string]$url) {
        $hashcode = ([WebCache]::HashFunc.ComputeHash([Text.Encoding]::UTF8.GetBytes($url)) |%{ $_.ToString("x2") }) -join('')
        return $url -replace '^[^:]+://','' -replace '/$','' -replace '[\.\/]','_' -replace '\?.*','' -replace '$', "-$hashcode"
    }

    static InitPurgeList() {
        $purgeDate = [DateTime]::Now.AddDays(-[WebCache]::PurgeBeforeDays)
        $files = Get-ChildItem -File -Path ([WebCache]::CacheDir) |? {$_.LastWriteTime -le $purgeDate } |Sort LastWriteTime
        [WebCache]::PurgeList = $files
        log "WebCache: PurgeList created: count=$([WebCache]::PurgeList.Count)"
    }

    static SetUserAgent([string]$ua) {
        [WebCache]::UserAgent = $ua ? $ua :
            "Mozilla/5.0 (Windows NT 10.0; Microsoft Windows 10.0.23456; en-US) AppleWebKit/543.2 (KHTML, like Gecko) Safari/543.2"
        }
    }

    static PurgeCacheFile() {
        logv "WebCache.PurgeCacheFile: Count=$([WebCache]::PurgeList.Count)"
        if ([WebCache]::PurgeList.Count) {
            $f = [WebCache]::PurgeList[0]
            $fp = $f.FullName
            logv "WebCache.PurgeCacheFile: Purging file: $fp"
            Remove-Item -Path $fp -Force -Confirm:$false -ErrorAction SilentlyContinue
            [WebCache]::PurgeList = [WebCache]::PurgeList.Count -eq 1 ? @() : [WebCache]::PurgeList[1..([WebCache]::PurgeList.Count - 1)]
            logv "WebCache: Cache purged: $fp ($($f.LastWriteTime.ToString('yyyy\/M\/d HH:mm')))"
        }
    }
}
