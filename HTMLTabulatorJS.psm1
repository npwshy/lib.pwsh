#
# Tabulator JS
#
using module .\AppEnv.psm1

class TabulatorColumn {
    [string] $Field;
    [string] $Value;
    [bool] $ToQuote;

    TabulatorColumn() {}
    TabulatorColumn($f, $q) {
        $this.Field = $f
        $this.ToQuote = $q
    }
    TabulatorColumn($f, $v, $q) {
        $this.Field = $f
        $this.Value = $v
        $this.ToQuote = $q
    }

    [string] ToString() {
        $q = $this.ToQuote ? '"' : ''
        return "$($this.Field):$q$($this.Value)$q"
    }
}

class TabulatorRow {
    [TabulatorColumn[]] $Cols;
    [TabulatorRow[]] $Children;

    TabulatorRow() {
        $this.Cols = @()
        $this.Children = @()
    }

    [string] ToString() {
        $r = "{"
        $r += ($this.Cols |%{ $_.ToString() }) -join(',')
        if ($this.Children) {
            $r += ",_children:[`n"
            $r += ($this.Children |%{ $_.ToString() }) -join(",`n")
            $r += "]`n"
        }
        $r += "}"
        return $r
    }
}

class TabulatorJS {
    static [int] $Id = 0
    $BodyScripts = @()

    [string] Table([string]$type, [TabulatorRow[]]$param) {
        $htmltext = (Get-Content ([AppEnv]::Get("Tabulator.$type.HTML"))) -join("`n")
        $htmltext = $htmltext -replace '___ID___',([TabulatorJS]::Id)

        $bodyjs = (Get-Content ([AppEnv]::Get("Tabulator.$type.JS"))) -join("`n")
        $bodyjs = $bodyjs -replace '___ID___',([TabulatorJS]::Id)
        $bodyjs = $bodyjs -replace '___DATA___',(($param |%{ $_.ToString() }) -join(",`n"))

        $this.BodyScripts += ,$bodyjs

        [TabulatorJS]::Id ++

        return $htmltext
    }

    [string] GetBodyScript() {
        return $this.BodyScripts -join("`n")
    }

}