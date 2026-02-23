function Get-Greeting {
    param(
        [string]$Name
    )  # missing closing brace for function

Write-Host "Hello, $undefinedVariable"

$items = @(1, 2, 3
# missing closing paren

if ($true {  # missing closing paren
    Write-Host "test"
}
