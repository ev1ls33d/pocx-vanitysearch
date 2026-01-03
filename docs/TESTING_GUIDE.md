# OpenCL Integration Testing Guide

## Overview

This guide provides step-by-step instructions for testing the OpenCL implementation of POCX VanitySearch.

## Prerequisites

### Hardware Requirements
- GPU with OpenCL 1.2+ support
- NVIDIA: GTX 600 series or newer
- AMD: Radeon HD 7000 series or newer
- Intel: HD Graphics 4000 or newer

### Software Requirements

**Linux:**
```bash
# OpenCL headers and ICD loader
sudo apt-get install opencl-headers ocl-icd-opencl-dev clinfo

# NVIDIA GPU
sudo apt-get install nvidia-opencl-icd

# AMD GPU
sudo apt-get install mesa-opencl-icd
# OR for better performance:
# Install ROCm: https://rocmdocs.amd.com/

# Intel GPU
sudo apt-get install intel-opencl-icd
```

**Windows:**
- NVIDIA: Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
- AMD: Install [AMD APP SDK](https://github.com/GPUOpen-LibrariesAndSDKs/OCL-SDK/releases)
- Intel: Install [Intel OpenCL SDK](https://software.intel.com/content/www/us/en/develop/tools/opencl-sdk.html)

## Build Instructions

```bash
# Clone repository
git clone https://github.com/ev1ls33d/pocx-vanitysearch.git
cd pocx-vanitysearch

# Checkout OpenCL branch
git checkout copilot/port-cuda-to-opencl

# Build with OpenCL
make opencl

# Verify binary
ls -lh VanitySearch
```

## Test Suite

### Test 1: Device Enumeration

**Purpose**: Verify OpenCL initialization and device detection

**Command:**
```bash
./VanitySearch -l
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
- If "No OpenCL platforms found": Check driver installation
- If crash: Check OpenCL ICD loader with `clinfo`

---

### Test 2: Simple Prefix Search (Fast)

**Purpose**: Verify basic address generation and prefix matching

**Command:**
```bash
./VanitySearch -opencl -gpu pocx1Test
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
Start Tue Jan  3 22:52:35 2026
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
- If kernel compilation fails: Check build log in code
- If no results: May need longer runtime or easier prefix
- If crash: Check memory allocation

---

### Test 3: Medium Difficulty Prefix

**Purpose**: Test sustained performance and result parsing

**Command:**
```bash
./VanitySearch -opencl -gpu pocx1TestAB
```

**Expected Behavior:**
- Should take 1-5 minutes (depends on GPU)
- Continuous hash rate display
- Result found and validated

**What to Check:**
- ✅ Stable hash rate
- ✅ No performance degradation
- ✅ Correct prefix match
- ✅ GPU temperature reasonable

---

### Test 4: Pattern Matching with Wildcards

**Purpose**: Verify wildcard pattern matching

**Command:**
```bash
./VanitySearch -opencl -gpu "pocx1T?st*"
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

**Commands:**
```bash
# Compressed (default)
./VanitySearch -opencl -gpu pocx1Test

# Uncompressed
./VanitySearch -opencl -gpu -u pocx1Test

# Both
./VanitySearch -opencl -gpu -b pocx1Test
```

**What to Check:**
- ✅ All modes work
- ✅ Address format matches mode
- ✅ Both mode finds 2x results

---

### Test 6: Multi-GPU (if available)

**Purpose**: Test multi-GPU support

**Command:**
```bash
# List devices
./VanitySearch -l

# Use specific GPU
./VanitySearch -opencl -gpuId 0 pocx1Test

# Use multiple GPUs
./VanitySearch -opencl -gpuId 0,1 pocx1Test
```

**What to Check:**
- ✅ All GPUs detected
- ✅ Load balanced across GPUs
- ✅ Combined hash rate

---

### Test 7: Performance Comparison (CUDA vs OpenCL)

**Purpose**: Compare OpenCL vs CUDA performance

**Commands:**
```bash
# CUDA version (if available)
time ./VanitySearch -gpu pocx1TestX

# OpenCL version
time ./VanitySearch -opencl -gpu pocx1TestX
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

**Commands:**
```bash
# Test different grid sizes
./VanitySearch -opencl -gpu -g 256,128 pocx1Test
./VanitySearch -opencl -gpu -g 512,128 pocx1Test
./VanitySearch -opencl -gpu -g 1024,128 pocx1Test
./VanitySearch -opencl -gpu -g 2048,128 pocx1Test
```

**What to Check:**
- ✅ Find optimal grid size for your GPU
- ✅ Larger not always better (memory limits)
- ✅ Note best configuration

---

### Test 9: Long-Running Stability

**Purpose**: Verify stability over time

**Command:**
```bash
# Run for 10 minutes on difficult prefix
timeout 600 ./VanitySearch -opencl -gpu pocx1TestABC
```

**What to Check:**
- ✅ No crashes
- ✅ No memory leaks
- ✅ Stable hash rate
- ✅ GPU temperature stable

---

### Test 10: Error Handling

**Purpose**: Test error conditions

**Commands:**
```bash
# Invalid device ID
./VanitySearch -opencl -gpuId 99 pocx1Test

# Invalid prefix
./VanitySearch -opencl -gpu "invalid!"

# Too many threads
./VanitySearch -opencl -gpu -g 100000,128 pocx1Test
```

**What to Check:**
- ✅ Graceful error messages
- ✅ No crashes
- ✅ Clear error descriptions

---

## Validation Tests

### Validate Address Generation

**Script:**
```bash
#!/bin/bash
# Run search and capture result
./VanitySearch -opencl -gpu pocx1Test > result.txt

# Extract address and private key
ADDRESS=$(grep "PubAddress:" result.txt | awk '{print $2}')
PRIVKEY=$(grep "Priv (HEX):" result.txt | awk '{print $3}')

echo "Address: $ADDRESS"
echo "PrivKey: $PRIVKEY"

# Validate with CPU version
./VanitySearch -check $PRIVKEY $ADDRESS

# Should output: "Valid!"
```

### Cross-Validation with CPU

**Purpose**: Verify GPU results match CPU

**Steps:**
1. Run GPU search: `./VanitySearch -opencl -gpu -s 12345 pocx1Test`
2. Run CPU search: `./VanitySearch -t 1 -s 12345 pocx1Test`
3. Compare results - should be identical

---

## Performance Benchmarks

### Hash Rate Measurement

**Command:**
```bash
# Run for exactly 60 seconds
timeout 60 ./VanitySearch -opencl -gpu -t 0 pocx1TestXXXX 2>&1 | tee benchmark.log

# Extract average hash rate
grep "GK/s" benchmark.log | tail -10 | awk '{print $1}' | sed 's/\[//' | awk '{sum+=$1; n++} END {print "Average:", sum/n, "GK/s"}'
```

### Memory Bandwidth Test

**Purpose**: Check memory transfer efficiency

**Look for:**
- Time spent in kernel vs. memory transfer
- Should be >90% in kernel execution

---

## Known Issues and Workarounds

### Issue 1: Kernel Compilation Failure

**Symptoms:**
```
CLEngine: Failed to build program: -11
Build log: [errors]
```

**Solutions:**
- Check kernel files exist in `GPU/OpenCL/*.cl`
- Verify OpenCL version compatibility
- Check build log for syntax errors

### Issue 2: No Results Found

**Symptoms:**
- Search runs but never finds anything
- Hash rate looks good

**Solutions:**
- Try easier prefix (3-4 chars)
- Check prefix format (lowercase for POCX)
- Verify kernel is actually running

### Issue 3: Low Performance

**Symptoms:**
- Hash rate much lower than expected
- GPU utilization low

**Solutions:**
- Increase grid size: `-g 1024,128`
- Disable CPU threads: `-t 0`
- Check for thermal throttling
- Try different workgroup sizes

### Issue 4: Memory Errors

**Symptoms:**
```
CLEngine: Failed to allocate memory
```

**Solutions:**
- Reduce grid size
- Reduce maxFound: `-m 256`
- Check available GPU memory

---

## Test Results Template

```markdown
## Test Results

**Date:** YYYY-MM-DD
**GPU:** [Model]
**Driver:** [Version]
**OpenCL:** [Version]

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

### Overall Assessment
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

## Automated Test Script

Save as `test_opencl.sh`:

```bash
#!/bin/bash

echo "==================================="
echo "OpenCL Integration Test Suite"
echo "==================================="
echo ""

# Test 1: Device enumeration
echo "Test 1: Device Enumeration"
./VanitySearch -l > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 2: Simple search
echo "Test 2: Simple Prefix Search"
timeout 30 ./VanitySearch -opencl -gpu pocx1T > /tmp/test2.log 2>&1
if grep -q "PubAddress:" /tmp/test2.log; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    cat /tmp/test2.log
    exit 1
fi

# Test 3: Pattern matching
echo "Test 3: Pattern Matching"
timeout 30 ./VanitySearch -opencl -gpu "pocx1T?" > /tmp/test3.log 2>&1
if grep -q "PubAddress:" /tmp/test3.log; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 4: Compressed mode
echo "Test 4: Compressed Mode"
timeout 30 ./VanitySearch -opencl -gpu pocx1T > /tmp/test4.log 2>&1
if grep -q "Compressed" /tmp/test4.log; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo ""
echo "==================================="
echo "All tests passed! ✅"
echo "==================================="
```

Make executable: `chmod +x test_opencl.sh`

---

## Next Steps

After running these tests:

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
- Specify GPU model and driver version
