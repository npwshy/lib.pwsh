#
# HTML Generator --- base class of HTML Generator
#
using module .\AppEnv.psm1

Set-StrictMode -Version latest

class HTMLGenParams {
    [string] $OutPath;
    [string] $Title;
}

class HTMLGenerator {
    [HTMLGenParams] $Param;
    [string[]] $Code;

    Generate([HTMLGenParams]$p) {
        if (-not $p.OutPath) { throw "$($this.GetType().Name).Generate: No OutPath set in parameter." }

        $this.Param = $p
        $this.Code = @()
        $this.Init()

        $this.OpenHTML()
        $this.AddHead()
        $this.AddBody()
        $this.CloseHTML()

        $txt = $this.Code -join("`n")
        $txt = $this.PostProcess($txt)

        $txt |Out-File -FilePath $this.Param.OutPath -Encoding utf8
        log "$($this.GetType().Name).Generate: HTML code saved: $($this.Param.OutPath)"
    }

    OpenHTML() {
        $this.Code += ,@"
<!DOCTYPE html>
<html lang="ja">
"@
    }

    CloseHTML() {
        $this.Code += ,@"
</html>
"@
    }

    AddHead() {
        $this.Code += ,'<head>'
        $this.Code += ,'<meta charset="UTF-8">'
        if ($this.Param.Title) {
            $this.Code += ,"<title>$($this.Param.Title)</title>"
        }
        $this.AddHeadContent()
        $this.Code += ,'<style>'
        $this.AddHeadStyle()
        $this.Code += ,'</style>'
        $this.Code += ,'<script>'
        $this.AddHeadScript()
        $this.Code += ,'</script>'
        $this.Code += ,'</head>'
    }

    AddBody() {
        $this.Code += ,'<body>'
        $this.AddBodyContent()
        $this.Code += ,'<script>'
        $this.AddBodyScript()
        $this.Code += ,'</script>'
        $this.Code += ,'</body>'
    }


    #
    # Subclass implementation is expected to override following functions as needed.
    #
    Init() {} # sub class may want to initialize something

    AddHeadContent() { $this.AddContentByTemplate('HeadContent', $this.GetHeadTemplateName) }
    [string]GetHeadTemplateName() { return 'HTML.Template.Head' }

    AddHeadStyle() { $this.AddContentByTemplate('HeadStyle', $this.GetHeadStyleTemplateName) }
    [string]GetHeadStyleTemplateName() { return 'HTML.Template.CSS' }

    AddHeadScript() { $this.AddContentByTemplate('HeadScript', $this.GetHeadScriptTemplateName) }
    [string]GetHeadScriptTemplateName() { return 'HTML.Template.HeadJS' }

    AddBodyContent() { $this.AddContentByTemplate('BodyContent', $this.GetBodyTemplateName) }
    [string]GetBodyTemplateName() { return 'HTML.Template.Body' }

    AddBodyScript() { $this.AddContentByTemplate('BodyScrypt', $this.GetBodyScriptTemplateName) }
    [string]GetBodyScriptTemplateName() { return 'HTML.Template.BodyJS' }

    AddContentByTemplate($name, $method) {
        if ($tag = $method.Invoke()) {
            if (-not ($fp = [AppEnv]::Get($tag, $null))) {
                log "$($this.GetType().Name).$($name): No template defined. Skipping: $tag"
                return
            }
            if (-not (Test-Path $fp)) {
                log "$($this.GetType().Name).$($name): Template file not found. Skipping: $fp"
                return
            }
            log "$($this.GetType().Name).$($name): Adding $fp"
            $this.Code += Get-Content $fp
        }
    }

    [string] PostProcess($txt) { return $txt }
}