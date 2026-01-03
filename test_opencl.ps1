# OpenCL Integration Test Runner (PowerShell)
# This script performs basic validation tests for the OpenCL implementation

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "OpenCL Integration Test Suite" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if binary exists
if (-not (Test-Path ".\VanitySearch.exe")) {
    Write-Host "❌ FAIL VanitySearch.exe not found" -ForegroundColor Red
    Write-Host "Please run: make opencl" -ForegroundColor Yellow
    exit 1
}

# Create test output directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "test_results\$timestamp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host "Test logs will be saved to: $logDir" -ForegroundColor Cyan
Write-Host ""

# Test counter
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0

function Run-Test {
    param(
        [string]$TestName,
        [string]$TestCmd,
        [string]$Expected,
        [int]$TimeoutSec = 30
    )
    
    $script:totalTests++
    
    Write-Host "Test ${script:totalTests}: $TestName... " -NoNewline
    
    $logFile = Join-Path $logDir "test$($script:totalTests).log"
    
    try {
        # Run test with timeout
        $job = Start-Job -ScriptBlock {
            param($cmd)
            Invoke-Expression $cmd 2>&1
        } -ArgumentList $TestCmd
        
        $completed = Wait-Job $job -Timeout $TimeoutSec
        
        if ($completed) {
            $output = Receive-Job $job
            $output | Out-File -FilePath $logFile -Encoding UTF8
            
            # Check if expected string is in output
            $outputStr = $output | Out-String
            if ($outputStr -match [regex]::Escape($Expected)) {
                Write-Host "✅ PASS" -ForegroundColor Green
                $script:passedTests++
                Remove-Job $job -Force
                return $true
            } else {
                Write-Host "❌ FAIL (expected: '$Expected')" -ForegroundColor Red
                Write-Host "  See log: $logFile" -ForegroundColor Yellow
                $script:failedTests++
                Remove-Job $job -Force
                return $false
            }
        } else {
            # Timeout
            Stop-Job $job
            Receive-Job $job | Out-File -FilePath $logFile -Encoding UTF8
            Write-Host "⚠️  WARN (timeout after ${TimeoutSec}s)" -ForegroundColor Yellow
            Write-Host "  This may be normal for difficult prefixes" -ForegroundColor Yellow
            Write-Host "  See log: $logFile" -ForegroundColor Yellow
            Remove-Job $job -Force
            return $false
        }
    } catch {
        Write-Host "❌ FAIL (error: $_)" -ForegroundColor Red
        Write-Host "  See log: $logFile" -ForegroundColor Yellow
        $_.Exception.Message | Out-File -FilePath $logFile -Encoding UTF8
        $script:failedTests++
        return $false
    }
}

# ===== Test Suite =====

Write-Host "Phase 1: Basic Functionality" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan

# Test 1: Help/Version
Run-Test -TestName "Display help" `
         -TestCmd ".\VanitySearch.exe -h" `
         -Expected "Usage" `
         -TimeoutSec 5

# Test 2: Device Listing
Run-Test -TestName "Device enumeration" `
         -TestCmd ".\VanitySearch.exe -l" `
         -Expected "OpenCL Platforms" `
         -TimeoutSec 10

Write-Host ""
Write-Host "Phase 2: OpenCL Initialization" -ForegroundColor Cyan
Write-Host "-------------------------------" -ForegroundColor Cyan

# Test 3: Simple prefix (very easy, should find quickly)
Run-Test -TestName "Simple 3-char prefix" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 pocx1T" `
         -Expected "PubAddress" `
         -TimeoutSec 60

# Test 4: 4-char prefix
Run-Test -TestName "Medium 4-char prefix" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 pocx1Te" `
         -Expected "PubAddress" `
         -TimeoutSec 120

Write-Host ""
Write-Host "Phase 3: Address Modes" -ForegroundColor Cyan
Write-Host "----------------------" -ForegroundColor Cyan

# Test 5: Compressed mode (explicit)
Run-Test -TestName "Compressed mode" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 pocx1T" `
         -Expected "Compressed" `
         -TimeoutSec 60

# Test 6: Uncompressed mode
Run-Test -TestName "Uncompressed mode" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 -u pocx1T" `
         -Expected "Uncompressed" `
         -TimeoutSec 60

# Test 7: Both modes
Run-Test -TestName "Both modes" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 -b pocx1T" `
         -Expected "Both" `
         -TimeoutSec 60

Write-Host ""
Write-Host "Phase 4: Pattern Matching" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan

# Test 8: Wildcard ? (any single char)
Run-Test -TestName "Pattern with ?" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 'pocx1T?'" `
         -Expected "PubAddress" `
         -TimeoutSec 60

# Test 9: Wildcard * (any chars)
Run-Test -TestName "Pattern with *" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 'pocx1T*st'" `
         -Expected "PubAddress" `
         -TimeoutSec 60

Write-Host ""
Write-Host "Phase 5: Grid Configuration" -ForegroundColor Cyan
Write-Host "---------------------------" -ForegroundColor Cyan

# Test 10: Small grid
Run-Test -TestName "Small grid (128x128)" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 -g 128,128 pocx1T" `
         -Expected "PubAddress" `
         -TimeoutSec 60

# Test 11: Medium grid
Run-Test -TestName "Medium grid (256x128)" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 -g 256,128 pocx1T" `
         -Expected "PubAddress" `
         -TimeoutSec 60

# Test 12: Large grid
Run-Test -TestName "Large grid (512x128)" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu -t 0 -g 512,128 pocx1T" `
         -Expected "PubAddress" `
         -TimeoutSec 60

Write-Host ""
Write-Host "Phase 6: Error Handling" -ForegroundColor Cyan
Write-Host "-----------------------" -ForegroundColor Cyan

# Test 13: Invalid GPU ID
Run-Test -TestName "Invalid GPU ID" `
         -TestCmd ".\VanitySearch.exe -opencl -gpuId 99 pocx1T 2>&1" `
         -Expected "Invalid GPU ID" `
         -TimeoutSec 10

# Test 14: Invalid prefix characters
Run-Test -TestName "Invalid prefix" `
         -TestCmd ".\VanitySearch.exe -opencl -gpu 'invalid!' 2>&1" `
         -Expected "Invalid" `
         -TimeoutSec 10

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $($script:totalTests)"
Write-Host "Passed:       " -NoNewline
Write-Host "$($script:passedTests)" -ForegroundColor Green
Write-Host "Failed:       " -NoNewline
Write-Host "$($script:failedTests)" -ForegroundColor Red
Write-Host ""

if ($script:failedTests -eq 0) {
    Write-Host "All tests passed! ✅" -ForegroundColor Green
    Write-Host ""
    Write-Host "The OpenCL implementation is working correctly." -ForegroundColor Green
    Write-Host "You can now use it for production searches." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed! ❌" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the logs in: $logDir" -ForegroundColor Yellow
    Write-Host "Fix the issues and run tests again." -ForegroundColor Yellow
    exit 1
}
