# OpenCL Quick Test Reference (Windows/PowerShell)

## Quick Start (RTX 5090 on Windows)

### 1. Build
```powershell
cd pocx-vanitysearch
# If using Visual Studio: Build in Release mode
# If using MinGW: make opencl
```

### 2. Verify Setup
```powershell
.\VanitySearch.exe -l
# Should show: NVIDIA GeForce RTX 5090
```

### 3. First Test (Should complete in seconds)
```powershell
.\VanitySearch.exe -opencl -gpu pocx1Test
```

### 4. Run Full Test Suite
```powershell
.\test_opencl.ps1
```

---

## Command Quick Reference (PowerShell)

| Purpose | Command |
|---------|---------|
| List devices | `.\VanitySearch.exe -l` |
| Simple search | `.\VanitySearch.exe -opencl -gpu pocx1Test` |
| Pattern search | `.\VanitySearch.exe -opencl -gpu "pocx1T?st"` |
| Compressed only | `.\VanitySearch.exe -opencl -gpu pocx1Test` |
| Uncompressed | `.\VanitySearch.exe -opencl -gpu -u pocx1Test` |
| Both modes | `.\VanitySearch.exe -opencl -gpu -b pocx1Test` |
| Specific GPU | `.\VanitySearch.exe -opencl -gpuId 0 pocx1Test` |
| Custom grid | `.\VanitySearch.exe -opencl -gpu -g 1024,128 pocx1Test` |
| No CPU threads | `.\VanitySearch.exe -opencl -gpu -t 0 pocx1Test` |

---

## PowerShell-Specific Commands

### Run with timeout
```powershell
$job = Start-Job { .\VanitySearch.exe -opencl -gpu pocx1Test }
Wait-Job $job -Timeout 60
Stop-Job $job
Receive-Job $job
```

### Capture output to file
```powershell
.\VanitySearch.exe -opencl -gpu pocx1Test | Tee-Object -FilePath output.txt
```

### Measure execution time
```powershell
Measure-Command { .\VanitySearch.exe -opencl -gpu pocx1Test }
```

### Check if OpenCL is available
```powershell
Get-Command clinfo -ErrorAction SilentlyContinue
if ($?) { clinfo } else { Write-Host "clinfo not found - install OpenCL" }
```

---

## Expected Performance (RTX 5090 on Windows)

| Metric | Expected Value |
|--------|----------------|
| Hash Rate | 15-20 GK/s |
| vs CUDA | 85-95% |
| 3-char prefix | < 10 seconds |
| 4-char prefix | < 2 minutes |
| 5-char prefix | 5-15 minutes |

---

## Troubleshooting Quick Fixes (Windows)

| Issue | Solution |
|-------|----------|
| "No OpenCL platforms" | Install CUDA Toolkit or AMD drivers |
| Kernel compile error | Run as Administrator |
| Low hash rate | Set Windows to "High Performance" power mode |
| Crash on start | Add to Windows Defender exclusions |
| No results | Try easier prefix: `pocx1T` |
| DLL not found | Install Visual C++ Redistributable |

---

## Windows-Specific Checks

### Check OpenCL DLL
```powershell
Test-Path "C:\Windows\System32\OpenCL.dll"
# Should return True
```

### Check GPU in Device Manager
```powershell
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion
```

### Check GPU Memory Usage
```powershell
# Use Task Manager > Performance > GPU
# Or install GPU-Z: https://www.techpowerup.com/gpuz/
```

### Monitor GPU Temperature
```powershell
# Use MSI Afterburner or HWiNFO64
# Download: https://www.msi.com/Landing/afterburner
```

---

## Installation Prerequisites

### NVIDIA GPU (Recommended for RTX 5090)
1. Download [NVIDIA CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
2. Run installer (includes OpenCL)
3. Reboot
4. Verify: `clinfo`

### AMD GPU
1. Download [AMD Adrenalin Software](https://www.amd.com/en/support)
2. Install drivers
3. Verify: `clinfo`

### Intel GPU
1. Download [Intel Graphics Driver](https://downloadcenter.intel.com/product/80939/Graphics-Drivers)
2. Install OpenCL SDK
3. Verify: `clinfo`

---

## Test Checklist

- [ ] Device enumeration works (`-l`)
- [ ] Simple prefix finds address (`pocx1T`)
- [ ] Pattern matching works (`pocx1T?st`)
- [ ] Hash rate > 10 GK/s
- [ ] No crashes or errors
- [ ] Compressed mode works
- [ ] Both modes work
- [ ] Results validate correctly
- [ ] No Windows Defender blocks
- [ ] GPU temperature stable

---

## Performance Optimization (Windows)

1. **Set Power Plan to High Performance**
   ```powershell
   powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
   ```

2. **Disable Windows Game Mode**
   - Settings > Gaming > Game Mode > Off

3. **Close Background Apps**
   ```powershell
   # Check GPU usage
   Get-Process | Where-Object {$_.Name -like "*gpu*"}
   ```

4. **Increase Virtual Memory**
   - System Properties > Advanced > Performance Settings > Advanced > Virtual Memory

5. **Update GPU Drivers**
   ```powershell
   # For NVIDIA (via GeForce Experience)
   # Or download manually from nvidia.com
   ```

---

## Filing Bug Reports

If tests fail on Windows, include:
1. Output of `.\VanitySearch.exe -l`
2. Output of `clinfo`
3. Full error message
4. Test log from `test_results\` directory
5. GPU model and driver version
6. Windows version: `winver`
7. PowerShell version: `$PSVersionTable.PSVersion`

---

## Build from Source (Windows)

### Using Visual Studio
```powershell
# Open VanitySearch.sln in Visual Studio
# Set to Release configuration
# Build > Build Solution
# Output: Release\VanitySearch.exe
```

### Using MinGW/MSYS2
```powershell
# Install MSYS2 from https://www.msys2.org/
# Open MSYS2 MinGW 64-bit terminal
pacman -S mingw-w64-x86_64-gcc make
cd /c/Users/YourName/pocx-vanitysearch
make opencl
```

---

## Next Steps After Testing

1. ✅ All tests pass → Ready for production
2. ⚠️ Some tests fail → File GitHub issue with logs
3. 🚀 Want more speed → Tune grid size (`-g` parameter)
4. 📊 Benchmark → Compare with CUDA version
5. 🔧 Optimize → Adjust Windows power settings

---

## Quick Links

- **Full Testing Guide**: `docs\TESTING_GUIDE_WINDOWS.md`
- **Linux/Bash Version**: `docs\TESTING_GUIDE.md`
- **OpenCL Setup**: `docs\OPENCL_SETUP.md`
- **Implementation Details**: `docs\OPENCL_IMPLEMENTATION.md`

---

## Example Session (PowerShell)

```powershell
# Navigate to project
cd C:\Users\YourName\pocx-vanitysearch

# List devices
PS> .\VanitySearch.exe -l
OpenCL Platforms: 1
  Platform 0: NVIDIA CUDA
    Device 0: NVIDIA GeForce RTX 5090 (24GB)

# Run simple test
PS> .\VanitySearch.exe -opencl -gpu pocx1T
VanitySearch v1.19
[OpenCL Mode]
GPU: NVIDIA GeForce RTX 5090
[15.2 GK/s][GPU 15.2 GK/s][Count 2^24][00:00:02]
PubAddress: pocx1Txxxxxxxxxxxxxxxxxxx
Priv (WIF): p-compressed-L...

# Run full test suite
PS> .\test_opencl.ps1
Test 1: Display help... ✅ PASS
Test 2: Device enumeration... ✅ PASS
Test 3: Simple 3-char prefix... ✅ PASS
...
All tests passed! ✅
```

---

See `docs\TESTING_GUIDE_WINDOWS.md` for comprehensive Windows testing documentation.
