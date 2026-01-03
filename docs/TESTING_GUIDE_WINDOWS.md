# OpenCL Integration Testing Guide - Windows Edition

## Overview

This guide provides step-by-step instructions for testing the OpenCL implementation of POCX VanitySearch on Windows systems.

## Prerequisites

### Hardware Requirements
- GPU with OpenCL 1.2+ support
- NVIDIA: GTX 600 series or newer (recommended: RTX 5090)
- AMD: Radeon HD 7000 series or newer
- Intel: HD Graphics 4000 or newer

### Software Requirements

**NVIDIA GPU:**
1. Install [NVIDIA CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
   - Download the Windows installer
   - Includes OpenCL runtime and drivers
   - Reboot after installation

**AMD GPU:**
1. Install [AMD Adrenalin Software](https://www.amd.com/en/support)
   - Includes OpenCL runtime
   - Or install [AMD APP SDK](https://github.com/GPUOpen-LibrariesAndSDKs/OCL-SDK/releases)

**Intel GPU:**
1. Install [Intel Graphics Driver](https://downloadcenter.intel.com/product/80939/Graphics-Drivers)
2. Install [Intel OpenCL SDK](https://software.intel.com/content/www/us/en/develop/tools/opencl-sdk.html)

**Build Tools:**
- Visual Studio 2019 or newer (Community Edition is fine)
- OR MinGW-w64 (if using GCC on Windows)
- Git for Windows

## Build Instructions

### Using PowerShell

```powershell
# Clone repository
git clone https://github.com/ev1ls33d/pocx-vanitysearch.git
cd pocx-vanitysearch

# Checkout OpenCL branch
git checkout copilot/port-cuda-to-opencl

# Build with OpenCL (requires Visual Studio or MinGW)
# If using Visual Studio:
# Open pocx-vanitysearch.sln and build in Release mode

# If using MinGW/MSYS2:
make opencl

# Verify binary
dir VanitySearch.exe
```

## Test Suite

### Test 1: Device Enumeration

**Purpose**: Verify OpenCL initialization and device detection

**Command (PowerShell):**
```powershell
.\VanitySearch.exe -l
```

**Expected Output:**
```
OpenCL Platforms: 1
  Platform 0: NVIDIA CUDA
    Device 0: NVIDIA GeForce RTX 5090 (24GB)
      Type: GPU
      Global Memory: 24.00 GB
      Compute Units: 170
```

**What to Check:**
- ✅ Platform detected
- ✅ Device name correct
- ✅ Memory size accurate
- ✅ No errors displayed

**Troubleshooting:**
- If "No OpenCL platforms found": 
  - Check driver installation with: `clinfo` (install via chocolatey: `choco install clinfo`)
  - Verify GPU is recognized in Device Manager
  - Reinstall CUDA Toolkit/GPU drivers
- If crash: Check Windows Event Viewer for errors

---

### Test 2: Simple Prefix Search (Fast)

**Purpose**: Verify basic address generation and prefix matching

**Command (PowerShell):**
```powershell
.\VanitySearch.exe -opencl -gpu pocx1Test
```

**Expected Behavior:**
- Kernel compiles successfully
- Search starts
- Address found within seconds (3-4 characters is easy)
- Private key and address displayed

**Expected Output:**
```
VanitySearch v1.19
[OpenCL Mode]
GPU: NVIDIA GeForce RTX 5090
Compiling kernels...
Kernels compiled successfully
Search: pocx1Test [Compressed]
Start Fri Jan  3 22:59:27 2026
Base Key: [random hex]
Number of CPU thread: 0
GPU: #0 RTX 5090 (170x128 cores) Grid(256x128)

[12.5 GK/s][GPU 12.5 GK/s][Count 2^25.xxx][Dead 0][00:00:03]
PubAddress: pocx1Testxxxxxxxxxxxxxxxxxxxxx
Priv (WIF): p-compressed-L...
Priv (HEX): xxxxx...
```

**What to Check:**
- ✅ Kernel compilation succeeds
- ✅ Hash rate reasonable (>1 GK/s on modern GPU)
- ✅ Address starts with "pocx1Test"
- ✅ Private key can be imported
- ✅ No memory errors

**Troubleshooting:**
- If kernel compilation fails: 
  - Check that .cl files exist in `GPU\OpenCL\*.cl`
  - Verify OpenCL runtime is installed
  - Check build log for errors
- If no results: May need longer runtime or easier prefix
- If crash: Check Task Manager for GPU usage, may be memory issue

---

### Test 3: Medium Difficulty Prefix

**Purpose**: Test sustained performance and result parsing

**Command (PowerShell):**
```powershell
.\VanitySearch.exe -opencl -gpu pocx1TestAB
```

**Expected Behavior:**
- Should take 1-5 minutes (depends on GPU)
- Continuous hash rate display
- Result found and validated

**What to Check:**
- ✅ Stable hash rate
- ✅ No performance degradation
- ✅ Correct prefix match
- ✅ GPU temperature reasonable (check with GPU-Z or MSI Afterburner)

---

### Test 4: Pattern Matching with Wildcards

**Purpose**: Verify wildcard pattern matching

**Command (PowerShell):**
```powershell
.\VanitySearch.exe -opencl -gpu "pocx1T?st*"
```

**Expected Behavior:**
- Matches addresses like: pocx1Test, pocx1Tast, pocx1Txst...
- Pattern matching kernel used

**What to Check:**
- ✅ Pattern matches correctly
- ✅ Wildcard '?' works (any single char)
- ✅ Wildcard '*' works (any chars)

---

### Test 5: Compressed vs Uncompressed

**Purpose**: Test different key compression modes

**Commands (PowerShell):**
```powershell
# Compressed (default)
.\VanitySearch.exe -opencl -gpu pocx1Test

# Uncompressed
.\VanitySearch.exe -opencl -gpu -u pocx1Test

# Both
.\VanitySearch.exe -opencl -gpu -b pocx1Test
```

**What to Check:**
- ✅ All modes work
- ✅ Address format matches mode
- ✅ Both mode finds 2x results

---

### Test 6: Multi-GPU (if available)

**Purpose**: Test multi-GPU support

**Commands (PowerShell):**
```powershell
# List devices
.\VanitySearch.exe -l

# Use specific GPU
.\VanitySearch.exe -opencl -gpuId 0 pocx1Test

# Use multiple GPUs
.\VanitySearch.exe -opencl -gpuId 0,1 pocx1Test
```

**What to Check:**
- ✅ All GPUs detected
- ✅ Load balanced across GPUs
- ✅ Combined hash rate

---

### Test 7: Performance Comparison (CUDA vs OpenCL)

**Purpose**: Compare OpenCL vs CUDA performance

**Commands (PowerShell):**
```powershell
# CUDA version (if available)
Measure-Command { .\VanitySearch.exe -gpu pocx1TestX }

# OpenCL version
Measure-Command { .\VanitySearch.exe -opencl -gpu pocx1TestX }
```

**Expected:**
- OpenCL: 85-95% of CUDA performance on NVIDIA
- Similar addresses found
- Time difference < 15%

**What to Check:**
- ✅ OpenCL hash rate within expected range
- ✅ Both find same addresses (given same start key)

---

### Test 8: Grid Size Optimization

**Purpose**: Find optimal workgroup configuration

**Commands (PowerShell):**
```powershell
# Test different grid sizes
.\VanitySearch.exe -opencl -gpu -g 256,128 pocx1Test
.\VanitySearch.exe -opencl -gpu -g 512,128 pocx1Test
.\VanitySearch.exe -opencl -gpu -g 1024,128 pocx1Test
.\VanitySearch.exe -opencl -gpu -g 2048,128 pocx1Test
```

**What to Check:**
- ✅ Find optimal grid size for your GPU
- ✅ Larger not always better (memory limits)
- ✅ Note best configuration

---

### Test 9: Long-Running Stability

**Purpose**: Verify stability over time

**Command (PowerShell):**
```powershell
# Run for 10 minutes on difficult prefix
$job = Start-Job -ScriptBlock { .\VanitySearch.exe -opencl -gpu pocx1TestABC }
Wait-Job $job -Timeout 600
Stop-Job $job
Receive-Job $job
```

**What to Check:**
- ✅ No crashes
- ✅ No memory leaks (check Task Manager)
- ✅ Stable hash rate
- ✅ GPU temperature stable

---

### Test 10: Error Handling

**Purpose**: Test error conditions

**Commands (PowerShell):**
```powershell
# Invalid device ID
.\VanitySearch.exe -opencl -gpuId 99 pocx1Test 2>&1

# Invalid prefix
.\VanitySearch.exe -opencl -gpu "invalid!" 2>&1

# Too many threads
.\VanitySearch.exe -opencl -gpu -g 100000,128 pocx1Test 2>&1
```

**What to Check:**
- ✅ Graceful error messages
- ✅ No crashes
- ✅ Clear error descriptions

---

## Validation Tests

### Validate Address Generation

**PowerShell Script:**
```powershell
# Run search and capture result
.\VanitySearch.exe -opencl -gpu pocx1Test | Tee-Object -FilePath result.txt

# Extract address and private key
$address = (Get-Content result.txt | Select-String "PubAddress:").ToString().Split()[1]
$privkey = (Get-Content result.txt | Select-String "Priv \(HEX\):").ToString().Split()[2]

Write-Host "Address: $address"
Write-Host "PrivKey: $privkey"

# Validate with CPU version
.\VanitySearch.exe -check $privkey $address

# Should output: "Valid!"
```

### Cross-Validation with CPU

**Purpose**: Verify GPU results match CPU

**Steps:**
1. Run GPU search: `.\VanitySearch.exe -opencl -gpu -s 12345 pocx1Test`
2. Run CPU search: `.\VanitySearch.exe -t 1 -s 12345 pocx1Test`
3. Compare results - should be identical

---

## Performance Benchmarks

### Hash Rate Measurement (PowerShell)

**Script:**
```powershell
# Run for exactly 60 seconds
$job = Start-Job -ScriptBlock { 
    .\VanitySearch.exe -opencl -gpu -t 0 pocx1TestXXXX 2>&1 
}
Wait-Job $job -Timeout 60
Stop-Job $job
$output = Receive-Job $job

# Extract and calculate average hash rate
$output | Select-String "GK/s" | Select-Object -Last 10 | ForEach-Object {
    $_.ToString() -match '\[([0-9.]+) GK/s\]'
    [double]$matches[1]
} | Measure-Object -Average | Select-Object -ExpandProperty Average
```

---

## Known Issues and Workarounds (Windows-Specific)

### Issue 1: Kernel Compilation Failure

**Symptoms:**
```
CLEngine: Failed to build program: -11
Build log: [errors]
```

**Solutions:**
- Check kernel files exist in `GPU\OpenCL\*.cl`
- Verify OpenCL version: Run `clinfo` to check OpenCL version
- Try running as Administrator
- Check Windows Defender isn't blocking OpenCL runtime

### Issue 2: No OpenCL Platforms Found

**Symptoms:**
```
No OpenCL platforms found
```

**Solutions:**
- Reinstall GPU drivers
- Install CUDA Toolkit (NVIDIA) or AMD APP SDK
- Check Device Manager for GPU issues
- Verify OpenCL DLL exists: `C:\Windows\System32\OpenCL.dll`

### Issue 3: Low Performance

**Symptoms:**
- Hash rate much lower than expected
- GPU utilization low

**Solutions:**
- Disable Windows power saving: Set to "High Performance"
- Close other GPU-intensive applications
- Increase grid size: `-g 1024,128`
- Disable CPU threads: `-t 0`
- Check for thermal throttling in GPU-Z

### Issue 4: Memory Errors

**Symptoms:**
```
CLEngine: Failed to allocate memory
```

**Solutions:**
- Close other applications
- Reduce grid size: `-g 256,128`
- Reduce maxFound: `-m 256`
- Check available GPU memory in Task Manager

### Issue 5: Windows Firewall/Antivirus Blocking

**Symptoms:**
- Random crashes
- OpenCL initialization fails

**Solutions:**
- Add VanitySearch.exe to Windows Defender exclusions
- Temporarily disable antivirus during testing
- Run as Administrator

---

## Automated Test Script

**Run the automated test suite:**

```powershell
# Make sure you're in the project directory
cd pocx-vanitysearch

# Run the test suite
.\test_opencl.ps1
```

The script will:
- Run 14 automated tests
- Generate detailed logs in `test_results\<timestamp>\`
- Display color-coded results
- Exit with code 0 if all tests pass

---

## Windows-Specific Tips

1. **Use PowerShell ISE or Windows Terminal** for better output formatting
2. **Run as Administrator** if you encounter permission issues
3. **Check GPU-Z or HWiNFO** for GPU monitoring during tests
4. **Use Process Explorer** to check for memory leaks
5. **Enable Performance Mode** in Windows power settings
6. **Disable Windows Updates** during long tests

---

## Test Results Template

```markdown
## Test Results (Windows)

**Date:** YYYY-MM-DD
**GPU:** [Model]
**Driver:** [Version]
**OpenCL:** [Version]
**Windows:** [Version]

### Test 1: Device Enumeration
- Status: ✅ PASS / ❌ FAIL
- Notes: 

### Test 2: Simple Prefix
- Status: ✅ PASS / ❌ FAIL
- Time: X seconds
- Hash Rate: X GK/s
- Notes:

### Test 3: Medium Prefix
- Status: ✅ PASS / ❌ FAIL
- Time: X seconds
- Hash Rate: X GK/s
- Notes:

### Test 4: Pattern Matching
- Status: ✅ PASS / ❌ FAIL
- Notes:

### Test 5: Compression Modes
- Compressed: ✅ PASS / ❌ FAIL
- Uncompressed: ✅ PASS / ❌ FAIL
- Both: ✅ PASS / ❌ FAIL

### Test 7: Performance vs CUDA
- CUDA Hash Rate: X GK/s
- OpenCL Hash Rate: X GK/s
- Ratio: X%

### Overall Assessment (Windows)
- [ ] Ready for production
- [ ] Needs bug fixes
- [ ] Needs optimization

**Issues Found:**
1. 
2. 

**Recommendations:**
1. 
2. 
```

---

## Next Steps

After running these tests on Windows:

1. **Document Results**: Fill out the test results template
2. **Report Issues**: Create GitHub issues for any failures
3. **Optimize**: Based on performance results
4. **Benchmark**: Compare with CUDA across different scenarios
5. **Production**: Once all tests pass, ready for production use

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/ev1ls33d/pocx-vanitysearch/issues
- Include test results and logs
- Specify GPU model, driver version, and Windows version
- Include output from `clinfo` command

---

## Quick Reference Commands (PowerShell)

```powershell
# List devices
.\VanitySearch.exe -l

# Simple search
.\VanitySearch.exe -opencl -gpu pocx1Test

# Pattern search
.\VanitySearch.exe -opencl -gpu "pocx1T?st"

# Custom grid
.\VanitySearch.exe -opencl -gpu -g 1024,128 pocx1Test

# Multi-GPU
.\VanitySearch.exe -opencl -gpuId 0,1 pocx1Test

# Run test suite
.\test_opencl.ps1

# Check OpenCL installation
clinfo

# Monitor GPU (requires GPU-Z or similar)
# Download GPU-Z from: https://www.techpowerup.com/gpuz/
```
