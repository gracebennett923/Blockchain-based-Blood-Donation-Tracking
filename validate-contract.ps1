# Basic Contract Validation Script
Write-Host "=== Contract Syntax Validation ===" -ForegroundColor Green

$contractPath = "contracts\blood-donation-tracker.clar" 
if (Test-Path $contractPath) {
    Write-Host "Contract file found" -ForegroundColor Green
    
    $content = Get-Content $contractPath -Raw
    
    # Basic syntax checks
    $openParens = ($content.ToCharArray() | Where-Object {$_ -eq "("}).Count
    $closeParens = ($content.ToCharArray() | Where-Object {$_ -eq ")"}).Count
    
    if ($openParens -eq $closeParens) {
        Write-Host "? Parentheses are balanced ($openParens pairs)" -ForegroundColor Green
    } else {
        Write-Host "? Parentheses not balanced: $openParens open, $closeParens close" -ForegroundColor Red
        exit 1
    }
    
    # Check for required elements
    $required = @("define-constant", "define-map", "define-public", "define-read-only")
    foreach ($req in $required) {
        if ($content -match $req) {
            Write-Host "? Found $req constructs" -ForegroundColor Green
        } else {
            Write-Host "? Missing $req constructs" -ForegroundColor Red
        }
    }
    
    Write-Host "=== Contract validation completed ===" -ForegroundColor Green
} else {
    Write-Host "? Contract file not found!" -ForegroundColor Red
    exit 1
}
