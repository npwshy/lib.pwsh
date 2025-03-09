#
# ComparableStruct
#
class ComparableStruct : System.IComparable {
    ComparableStruct() {}

    ComparableStruct($o) {
        $oProp = $o -is [hashtable] ? $o.Keys :  ($o |Get-Member -MemberType NoteProperty,Property |% { $_.Name })
        $this.GetType().GetProperties().Name |? { $_ -in $oProp } |% { $this.$_ = $o.$_ }
    }

    [object] GetIdentifier() { return $this.GetHashCode() }
    [bool] Equals($o) { return $this.GetIdentifier() -eq ($o -as $this.GetType()).GetIdentifier() }
    [int] CompareTo($o) { return ($__ti = $this.GetIdentifier()) -eq ($__oi = ($o -as $this.GetType()).GetIdentifier()) ? 0 : $__ti -gt $__oi ? 1 : -1 }
    [string] ToString() { return "$($this.GetType().Name)$($this |ConvertTo-Json -Compress)" }
}