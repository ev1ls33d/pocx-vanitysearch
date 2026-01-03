# OpenCL Implementation for POCX VanitySearch

## Overview

This is the OpenCL implementation enabling cross-platform GPU support for POCX VanitySearch. Unlike CUDA (NVIDIA-only), OpenCL runs on NVIDIA, AMD, and Intel GPUs.

## Quick Start

### Installation

**Linux (Ubuntu/Debian):**
```bash
# Install OpenCL
sudo apt-get install opencl-headers ocl-icd-opencl-dev

# Install vendor runtime (choose one)
sudo apt-get install nvidia-opencl-icd  # NVIDIA
sudo apt-get install mesa-opencl-icd    # AMD
sudo apt-get install intel-opencl-icd   # Intel

# Build
make opencl
```

**Windows:**
- Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads) (includes OpenCL)
- OR install AMD APP SDK / Intel OpenCL SDK
- Build with Visual Studio (Release_OpenCL configuration)

### Usage

```bash
# List available OpenCL devices
./VanitySearchCL -l

# Search with OpenCL
./VanitySearchCL -opencl -gpu pocx1Test

# Use specific GPU
./VanitySearchCL -opencl -gpuId 0 pocx1Test

# Optimize grid size
./VanitySearchCL -opencl -gpu -g 512,128 pocx1Test
```

## Features

### Implemented ✅
- **256-bit Arithmetic**: Full secp256k1 math operations
- **SHA-256**: Optimized cryptographic hashing
- **RIPEMD-160**: Bitcoin-compatible address hashing
- **Base58 Encoding**: Standard and POCX lowercase variants
- **Pattern Matching**: Wildcard support (? and *)
- **POCX Optimizations**: Lowercase character set

### In Progress 🚧
- **Elliptic Curve Operations**: Point arithmetic and tables
- **Main Compute Kernels**: Address generation pipeline
- **Host Engine**: OpenCL device management

### Planned 📋
- **Build System**: Makefile and CMake integration
- **Testing Suite**: Unit, integration, and performance tests
- **Benchmarks**: Performance comparisons across vendors

## Performance

### Expected Hash Rates

| GPU | OpenCL | CUDA | Ratio |
|-----|--------|------|-------|
| RTX 4090 | ~12-14 GK/s | ~15 GK/s | 90-93% |
| RTX 3080 | ~8-9 GK/s | ~10 GK/s | 80-90% |
| AMD RX 6800 | ~7-9 GK/s | N/A | - |
| Intel UHD 630 | ~0.5-1 GK/s | N/A | - |

*Performance varies based on workgroup size optimization*

## Architecture

### Kernel Files

```
GPU/OpenCL/
├── GPUMath.cl      # 256-bit integer arithmetic
├── GPUHash.cl      # SHA-256 & RIPEMD-160
├── GPUBase58.cl    # Base58 address encoding
├── GPUWildcard.cl  # Pattern matching
├── GPUGroup.cl     # Elliptic curve tables (pending)
├── GPUCompute.cl   # Main kernels (pending)
└── CLEngine.cpp/.h # Host-side management (pending)
```

### Key Differences from CUDA

| Feature | CUDA | OpenCL |
|---------|------|--------|
| Inline ASM | PTX assembly | None (built-ins) |
| Memory | `__device__`, `__shared__` | `__global`, `__local`, `__constant` |
| Threads | Thread blocks | Work-groups and work-items |
| Compilation | NVCC compile-time | Runtime kernel compilation |

## POCX Optimizations

### Lowercase Base58
POCX addresses use only lowercase characters:
- **Standard**: 58 characters (a-z, A-Z, 0-9 minus ambiguous)
- **POCX**: 33 characters (a-z, 1-9)
- **Benefit**: Faster encoding, simpler prefix matching

### Version Byte
- **Bitcoin P2PKH**: 0x00 → addresses start with '1'
- **POCX**: 0x38 → addresses start with 'p'

### Example Addresses
```
Bitcoin: 1BitcoinEatersAddressDontSendf59kuE
POCX:    pocx1TestABC123def456ghi789jkl012
```

## Documentation

### Guides
- **[OPENCL_SETUP.md](OPENCL_SETUP.md)**: Installation and configuration
- **[OPENCL_IMPLEMENTATION.md](OPENCL_IMPLEMENTATION.md)**: Architecture details
- **[IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)**: Current progress

### API Documentation
See `CLEngine.h` for the OpenCL engine API, which mirrors `GPUEngine.h`:

```cpp
// Initialize OpenCL engine
CLEngine engine(gridSize, blockSize, gpuId, maxFound, rekey);

// Set search parameters
engine.SetSearchType(POCX);
engine.SetSearchMode(SEARCH_COMPRESSED);
engine.SetPrefix(prefixes);

// Execute search
std::vector<ITEM> results;
engine.Launch(results);
```

## Build System

### Make Targets (Planned)
```bash
make all          # Build both CUDA and OpenCL
make cuda         # Build CUDA version only
make opencl       # Build OpenCL version only
make clean        # Clean build artifacts
make tests        # Build and run tests
```

### Build Options
```bash
# Custom OpenCL path
make opencl OPENCL_INCLUDE=/opt/opencl/include OPENCL_LIB=/opt/opencl/lib

# Debug build
make opencl DEBUG=1

# Specific GPU architecture
make opencl GPU_ARCH=gfx906  # AMD RDNA
```

## Testing

### Test Suite (Planned)
```bash
# Run all tests
make test

# Run specific tests
./tests/test_opencl_kernels
./tests/test_address_generation
./tests/benchmark_opencl
```

### Test Coverage
- **Unit Tests**: Individual kernel functions
- **Integration Tests**: Full address generation
- **Benchmarks**: Performance measurement
- **Validation**: Cross-check with CPU/CUDA

## Troubleshooting

### Common Issues

**"No OpenCL platforms found"**
```bash
# Check ICD loaders
ls /etc/OpenCL/vendors/  # Linux
# Should show vendor .icd files
```

**"Kernel compilation failed"**
```bash
# Enable verbose mode
./VanitySearchCL -opencl -v -gpu pocx1Test
# Check compiler errors in output
```

**Low performance**
```bash
# Try different grid sizes
./VanitySearchCL -opencl -gpu -g 256,128 pocx1Test
./VanitySearchCL -opencl -gpu -g 512,128 pocx1Test
./VanitySearchCL -opencl -gpu -g 1024,128 pocx1Test
```

### Debug Information
```bash
# Get device information
clinfo

# Check OpenCL version
clinfo | grep "OpenCL C Version"

# List capabilities
clinfo | grep -A 5 "Device Name"
```

## Contributing

### Development Setup
```bash
# Clone repository
git clone https://github.com/ev1ls33d/pocx-vanitysearch.git
cd pocx-vanitysearch

# Install dependencies
sudo apt-get install opencl-headers ocl-icd-opencl-dev

# Build and test
make opencl
./VanitySearchCL -opencl -gpu pocx1Test
```

### Code Style
- Follow existing CUDA kernel style
- Use OpenCL C 1.2 standard
- Document all public functions
- Add test vectors for new features

### Testing Guidelines
1. Test on multiple GPU vendors (NVIDIA, AMD, Intel)
2. Verify results against CPU implementation
3. Compare with CUDA results (if available)
4. Run memory leak tests (valgrind)
5. Benchmark performance

## Roadmap

### Phase 1: Core Implementation (Current)
- [x] Mathematical operations (GPUMath.cl)
- [x] Hash functions (GPUHash.cl)
- [x] Base58 encoding (GPUBase58.cl)
- [x] Pattern matching (GPUWildcard.cl)
- [ ] Elliptic curve operations (GPUGroup.cl)
- [ ] Main kernels (GPUCompute.cl)

### Phase 2: Integration
- [ ] Host-side engine (CLEngine.cpp)
- [ ] Build system updates
- [ ] Basic testing

### Phase 3: Optimization
- [ ] Performance tuning
- [ ] Multi-GPU support
- [ ] Platform-specific optimizations

### Phase 4: Release
- [ ] Comprehensive testing
- [ ] Documentation finalization
- [ ] Release candidate
- [ ] Community feedback

## License

GPLv3 - Same as VanitySearch

## Credits

- **Original VanitySearch**: Jean Luc PONS
- **POCX Fork**: ev1ls33d
- **OpenCL Port**: Community contribution

## Links

- **Main Repository**: https://github.com/ev1ls33d/pocx-vanitysearch
- **Original VanitySearch**: https://github.com/JeanLucPons/VanitySearch
- **POCX Project**: https://github.com/PoC-Consortium/bitcoin-pocx
- **OpenCL Specification**: https://www.khronos.org/opencl/

## Support

### Issues
Report bugs and issues on GitHub: https://github.com/ev1ls33d/pocx-vanitysearch/issues

### Discussion
Join the discussion on BitcoinTalk or POCX forums

### Community
- Bitcoin cryptography community
- POCX development team
- OpenCL developers

---

**Status**: Work in Progress (35% complete)

**Last Updated**: 2026-01-03

**Target Release**: Q1 2026
