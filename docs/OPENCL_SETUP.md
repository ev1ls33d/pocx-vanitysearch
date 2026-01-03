# OpenCL Setup Guide for POCX VanitySearch

## Overview

This guide helps you set up OpenCL support for VanitySearch-PoCX on different platforms and GPU vendors.

## System Requirements

### Minimum Requirements
- OpenCL 1.2 compatible GPU
- 2GB GPU memory (recommended 4GB+)
- OpenCL SDK/Runtime for your GPU vendor

### Supported GPUs
- **NVIDIA**: GeForce GTX 600 series and newer
- **AMD**: Radeon HD 7000 series and newer
- **Intel**: HD Graphics 4000 and newer (lower performance)

## Linux Installation

### Ubuntu/Debian

#### 1. Install OpenCL Development Headers
```bash
sudo apt-get update
sudo apt-get install opencl-headers ocl-icd-opencl-dev clinfo
```

#### 2. Install Vendor-Specific Runtime

**For NVIDIA GPUs:**
```bash
# Install NVIDIA drivers (if not already installed)
sudo ubuntu-drivers autoinstall

# Install NVIDIA OpenCL ICD
sudo apt-get install nvidia-opencl-icd-xxx  # Replace xxx with your driver version

# Verify installation
clinfo
```

**For AMD GPUs:**
```bash
# Install AMD drivers
sudo apt-get install mesa-opencl-icd

# OR install AMD ROCm for better performance
# Follow: https://rocmdocs.amd.com/en/latest/Installation_Guide/Installation-Guide.html

# Verify installation
clinfo
```

**For Intel GPUs:**
```bash
# Install Intel OpenCL runtime
sudo apt-get install intel-opencl-icd

# Verify installation
clinfo
```

#### 3. Verify OpenCL Installation
```bash
# List available OpenCL platforms and devices
clinfo

# You should see your GPU listed
```

#### 4. Build VanitySearch with OpenCL
```bash
cd pocx-vanitysearch

# Build with OpenCL support
make opencl

# Or build with both CUDA and OpenCL
make all
```

### Fedora/RHEL/CentOS

```bash
# Install development tools
sudo dnf install opencl-headers ocl-icd-devel

# Install vendor runtime (NVIDIA example)
sudo dnf install xorg-x11-drv-nvidia-cuda

# Build
make opencl
```

### Arch Linux

```bash
# Install OpenCL headers
sudo pacman -S opencl-headers ocl-icd

# Install vendor runtime
# NVIDIA:
sudo pacman -S opencl-nvidia

# AMD:
sudo pacman -S opencl-mesa

# Intel:
sudo pacman -S intel-compute-runtime

# Build
make opencl
```

## Windows Installation

### Method 1: NVIDIA CUDA Toolkit (NVIDIA GPUs)

1. Download and install [NVIDIA CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
   - The CUDA Toolkit includes OpenCL support
   - Version 11.0 or newer recommended

2. Set environment variables:
   ```powershell
   setx CUDA_PATH "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0"
   setx OPENCL_INCLUDE "%CUDA_PATH%\include"
   setx OPENCL_LIB "%CUDA_PATH%\lib\x64"
   ```

3. Build using Visual Studio:
   - Open `VanitySearch.sln`
   - Select `Release_OpenCL` configuration
   - Build Solution

### Method 2: AMD APP SDK (AMD GPUs)

1. Download [AMD APP SDK](https://github.com/GPUOpen-LibrariesAndSDKs/OCL-SDK/releases)
2. Install to default location
3. Environment variables should be set automatically
4. Build using Visual Studio with `Release_OpenCL` configuration

### Method 3: Intel OpenCL SDK (Intel GPUs)

1. Download [Intel OpenCL SDK](https://software.intel.com/content/www/us/en/develop/tools/opencl-sdk.html)
2. Install SDK
3. Configure project paths in Visual Studio
4. Build with `Release_OpenCL` configuration

## macOS Installation

```bash
# macOS includes OpenCL by default (deprecated but still functional)
# No additional installation needed

# Install development tools
xcode-select --install

# Build
make opencl
```

**Note**: Apple has deprecated OpenCL in favor of Metal. OpenCL still works but may have limited performance improvements.

## Verification

### Test OpenCL Installation

```bash
# Check available devices
./VanitySearchCL -l

# Expected output:
# OpenCL Platforms:
#   Platform 0: NVIDIA CUDA
#     Device 0: GeForce RTX 3080 (8GB)
#   Platform 1: Intel(R) OpenCL
#     Device 0: Intel(R) UHD Graphics 630
```

### Run a Quick Test

```bash
# Test with simple prefix (should be instant)
./VanitySearchCL -opencl -gpu pocx1Test

# Monitor performance
./VanitySearchCL -opencl -gpu -t 0 pocx1Test
# -t 0 disables CPU threads to measure pure GPU performance
```

## Performance Tuning

### Workgroup Size Optimization

```bash
# Try different grid sizes
./VanitySearchCL -opencl -gpu -g 256,128 pocx1Test
./VanitySearchCL -opencl -gpu -g 512,128 pocx1Test
./VanitySearchCL -opencl -gpu -g 1024,128 pocx1Test

# Find optimal for your GPU
```

### Multi-GPU Configuration

```bash
# List GPUs
./VanitySearchCL -l

# Use specific GPU
./VanitySearchCL -opencl -gpuId 0 pocx1Test

# Use multiple GPUs
./VanitySearchCL -opencl -gpuId 0,1 pocx1Test
```

### Memory Optimization

```bash
# Adjust maximum found addresses
./VanitySearchCL -opencl -gpu -m 1024 pocx1Test

# Default is 256, increase for better throughput
```

## Troubleshooting

### "No OpenCL platforms found"

**Linux:**
```bash
# Check if ICD loader can find your vendor
ls -la /etc/OpenCL/vendors/

# Should show .icd files for installed vendors
# If empty, reinstall vendor runtime
```

**Windows:**
- Reinstall GPU drivers
- Verify CUDA Toolkit or AMD APP SDK installation
- Check system PATH includes OpenCL DLLs

### "Kernel compilation failed"

```bash
# Enable verbose output
./VanitySearchCL -opencl -gpu -v pocx1Test

# Check kernel compilation errors
# Usually caused by:
# - Outdated OpenCL version
# - Missing kernel files
# - Syntax errors in .cl files
```

### Low Performance

1. **Check GPU utilization:**
   ```bash
   # NVIDIA:
   nvidia-smi -l 1
   
   # AMD:
   radeontop
   
   # Should show high GPU usage (>90%)
   ```

2. **Optimize workgroup size:**
   - Try different `-g` values
   - Larger values usually better for high-end GPUs

3. **Disable CPU threads:**
   ```bash
   ./VanitySearchCL -opencl -gpu -t 0 pocx1Test
   # Prevents CPU/GPU contention
   ```

4. **Check thermal throttling:**
   - Monitor GPU temperature
   - Ensure adequate cooling

### "Out of memory" errors

```bash
# Reduce batch size
./VanitySearchCL -opencl -gpu -g 256,64 pocx1Test

# Or reduce max found
./VanitySearchCL -opencl -gpu -m 64 pocx1Test
```

## Platform-Specific Notes

### NVIDIA
- Best performance with CUDA Toolkit
- Supports both CUDA and OpenCL simultaneously
- RTX series: Excellent OpenCL performance

### AMD
- Use ROCm for best performance
- Open-source drivers may have limited OpenCL support
- Use proprietary AMDGPU-PRO for full functionality

### Intel
- Integrated GPUs have lower performance (expected)
- Useful for testing without dedicated GPU
- Newer Xe graphics show improved performance

## Advanced Configuration

### Environment Variables

```bash
# Force specific OpenCL platform
export OCL_PLATFORM=0

# Enable OpenCL debugging
export AMD_OCL_BUILD_OPTIONS_APPEND="-g"
export CUDA_LAUNCH_BLOCKING=1

# Increase kernel timeout (NVIDIA)
# Edit /etc/X11/xorg.conf:
# Option "Interactive" "0"
```

### Build Options

```bash
# Debug build for troubleshooting
make opencl DEBUG=1

# Specify OpenCL include path
make opencl OPENCL_INCLUDE=/opt/opencl/include

# Specify OpenCL library path
make opencl OPENCL_LIB=/opt/opencl/lib
```

## Getting Help

### Check GPU Support
```bash
clinfo | grep "Device Name"
clinfo | grep "OpenCL C Version"
```

### Collect Debug Information
```bash
./VanitySearchCL -opencl -gpu -v pocx1Test > debug.log 2>&1
```

### Report Issues
Include in bug reports:
- `clinfo` output
- GPU model and driver version
- OS and version
- Debug log
- Command line used

## Performance Expectations

### Hash Rates (approximate)

| GPU Model | Hash Rate | Notes |
|-----------|-----------|-------|
| RTX 4090 | ~12-15 GK/s | Excellent |
| RTX 3080 | ~8-10 GK/s | Very Good |
| RTX 2080 Ti | ~6-8 GK/s | Good |
| AMD RX 6800 | ~7-9 GK/s | Good |
| AMD RX 5700 | ~5-7 GK/s | Good |
| Intel UHD 630 | ~0.5-1 GK/s | Basic |

*GK/s = Giga Keys per second*

## Next Steps

1. Verify installation with `clinfo`
2. Build VanitySearch with OpenCL
3. Test with simple prefix
4. Optimize workgroup size
5. Start searching for your vanity address!

## Additional Resources

- [OpenCL Programming Guide](https://www.khronos.org/opencl/)
- [NVIDIA OpenCL Best Practices](https://developer.nvidia.com/opencl)
- [AMD OpenCL Programming Guide](https://www.amd.com/en/technologies/opencl)
- [Intel OpenCL Documentation](https://software.intel.com/content/www/us/en/develop/documentation/opencl-fpga-sdk-programming-guide/)
