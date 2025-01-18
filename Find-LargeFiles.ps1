clear
Get-childItem -Path ../MWP-CWF_bu/ -Recurse |Where-Object{
    (Test-Path -Path $_ -PathType Leaf) -and ($_.Size/1MB -gt 100)
} |ForEach-Object{
    $_.FullName + ':' + ($_.Size).tostring('0')
}