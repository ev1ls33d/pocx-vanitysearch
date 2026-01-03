# OpenCL Quick Test Reference

## Quick Start (RTX 5090)

### 1. Build
```bash
cd pocx-vanitysearch
make opencl
```

### 2. Verify Setup
```bash
./VanitySearch -l
# Should show: NVIDIA GeForce RTX 5090
```

### 3. First Test (Should complete in seconds)
```bash
./VanitySearch -opencl -gpu pocx1Test
```

### 4. Run Full Test Suite
```bash
./test_opencl.sh
```

---

## Command Quick Reference

| Purpose | Command |
|---------|---------|
| List devices | `./VanitySearch -l` |
| Simple search | `./VanitySearch -opencl -gpu pocx1Test` |
| Pattern search | `./VanitySearch -opencl -gpu "pocx1T?st"` |
| Compressed only | `./VanitySearch -opencl -gpu pocx1Test` |
| Uncompressed | `./VanitySearch -opencl -gpu -u pocx1Test` |
| Both modes | `./VanitySearch -opencl -gpu -b pocx1Test` |
| Specific GPU | `./VanitySearch -opencl -gpuId 0 pocx1Test` |
| Custom grid | `./VanitySearch -opencl -gpu -g 1024,128 pocx1Test` |
| No CPU threads | `./VanitySearch -opencl -gpu -t 0 pocx1Test` |

---

## Expected Performance (RTX 5090)

| Metric | Expected Value |
|--------|----------------|
| Hash Rate | 15-20 GK/s |
| vs CUDA | 85-95% |
| 3-char prefix | < 10 seconds |
| 4-char prefix | < 2 minutes |
| 5-char prefix | 5-15 minutes |

---

## Troubleshooting Quick Fixes

| Issue | Solution |
|-------|----------|
| "No OpenCL platforms" | Install CUDA Toolkit |
| Kernel compile error | Check `GPU/OpenCL/*.cl` files exist |
| Low hash rate | Try `-g 1024,128` or `-g 2048,128` |
| Crash on start | Reduce grid: `-g 256,128` |
| No results | Try easier prefix: `pocx1T` |

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

---

## Filing Bug Reports

If tests fail, include:
1. Output of `./VanitySearch -l`
2. Output of `clinfo`
3. Full error message
4. Test log from `test_results/` directory
5. GPU model and driver version

---

## Next Steps After Testing

1. ✅ All tests pass → Ready for production
2. ⚠️ Some tests fail → File GitHub issue with logs
3. 🚀 Want more speed → Tune grid size (`-g` parameter)
4. 📊 Benchmark → Compare with CUDA version

---

See `docs/TESTING_GUIDE.md` for comprehensive testing documentation.
