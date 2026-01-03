# OpenCL Implementation for POCX VanitySearch

## Status: In Progress

This document tracks the OpenCL implementation for cross-platform GPU support.

## Completed Components

### Phase 1: Core OpenCL Kernel Files ✓
- [x] `GPU/OpenCL/GPUMath.cl` - 256-bit arithmetic operations for secp256k1
- [x] `GPU/OpenCL/GPUHash.cl` - SHA-256 and RIPEMD-160 implementations
- [x] `GPU/OpenCL/GPUBase58.cl` - Base58 encoding (optimized for POCX)
- [x] `GPU/OpenCL/GPUWildcard.cl` - Pattern matching
- [ ] `GPU/OpenCL/GPUGroup.cl` - Group operations and constants (pending)
- [ ] `GPU/OpenCL/GPUCompute.cl` - Main computation kernels (pending)

### Phase 2: Host-side OpenCL Engine
- [ ] `GPU/OpenCL/CLEngine.h` - Engine header
- [ ] `GPU/OpenCL/CLEngine.cpp` - Engine implementation
- [ ] Platform/device selection
- [ ] Memory management
- [ ] Kernel compilation

### Phase 3: Build System
- [ ] Update Makefile
- [ ] Create CMakeLists.txt
- [ ] OpenCL SDK detection

### Phase 4: Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] Benchmarks

### Phase 5: Documentation
- [ ] Setup guide
- [ ] Performance tuning
- [ ] Troubleshooting

## Key Features

### POCX-Specific Optimizations
1. **Lowercase Base58**: POCX uses lowercase characters only (33 vs 58 characters)
2. **Version Byte**: POCX uses 0x38 as the version byte
3. **Optimized Prefix Matching**: Reduced character set improves matching speed

### OpenCL Adaptations from CUDA
1. **No inline assembly**: Used OpenCL built-in functions instead
2. **Different memory model**: Explicit `__global`, `__local`, `__constant`, `__private`
3. **Work-items vs threads**: OpenCL work-items map to CUDA threads
4. **Work-groups vs blocks**: OpenCL work-groups map to CUDA blocks

## Architecture

### Kernel Structure
```
GPUMath.cl      - 256-bit integer arithmetic
├── Addition/Subtraction with carry
├── Multiplication (Montgomery)
├── Modular operations
└── Inverse computation

GPUHash.cl      - Cryptographic hashing
├── SHA-256 implementation
├── RIPEMD-160 implementation
└── Combined Hash160

GPUBase58.cl    - Address encoding
├── Standard Base58 (Bitcoin)
├── POCX lowercase Base58
└── Checksum computation

GPUWildcard.cl  - Pattern matching
└── Wildcard support (? and *)

GPUGroup.cl     - Elliptic curve operations
├── Point addition
├── Point doubling
├── Scalar multiplication
└── Precomputed tables

GPUCompute.cl   - Main kernels
├── Key computation
├── Address generation
├── Prefix checking
└── Result collection
```

### Memory Layout
```
Global Memory:
- Input keys (64-bit integers)
- Prefix lookup tables (16-bit and 32-bit)
- Output buffer (found addresses)

Constant Memory:
- Elliptic curve parameters
- Precomputed point tables
- Hash round constants

Local Memory:
- Shared work-group data
- Temporary computation buffers
```

## Performance Considerations

### Optimization Strategies
1. **Coalesced Memory Access**: Align memory access patterns
2. **Local Memory Usage**: Share data within work-groups
3. **Loop Unrolling**: Critical hash computations
4. **Register Optimization**: Minimize register pressure
5. **Async Operations**: Overlap compute and memory transfers

### Expected Performance
- **NVIDIA GPUs**: 90%+ of CUDA performance
- **AMD GPUs**: Competitive performance (vendor-optimized)
- **Intel GPUs**: Lower but functional performance

## Build Requirements

### Linux
```bash
# Install OpenCL development headers
sudo apt-get install opencl-headers ocl-icd-opencl-dev

# Install vendor-specific ICD
# NVIDIA: nvidia-opencl-icd-xxx
# AMD: amd-opencl-icd
# Intel: intel-opencl-icd
```

### Windows
```powershell
# Install NVIDIA CUDA Toolkit (includes OpenCL)
# OR AMD APP SDK
# OR Intel OpenCL SDK
```

## Testing Strategy

### Unit Tests
- Individual kernel functions
- Known test vectors
- Cross-validation with CPU

### Integration Tests
- Full address generation
- Prefix matching
- CUDA vs OpenCL comparison

### Performance Tests
- Hash rate measurement
- Memory bandwidth
- Different workgroup sizes

## Known Limitations

1. **Modular Inverse**: Simplified placeholder implementation
2. **Error Handling**: Basic error reporting
3. **Platform Selection**: Manual device selection
4. **Memory Pool**: No advanced memory management yet

## Next Steps

1. Complete GPUGroup.cl with elliptic curve operations
2. Implement GPUCompute.cl main computation kernels
3. Create CLEngine.cpp host-side implementation
4. Add comprehensive testing
5. Benchmark and optimize
6. Document setup procedures

## References

- OpenCL 1.2 Specification: https://www.khronos.org/registry/OpenCL/
- SECP256K1 Curve: https://en.bitcoin.it/wiki/Secp256k1
- Base58Check Encoding: https://en.bitcoin.it/wiki/Base58Check_encoding
- POCX Specification: https://github.com/PoC-Consortium/bitcoin-pocx
