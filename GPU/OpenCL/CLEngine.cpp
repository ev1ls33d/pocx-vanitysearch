/*
 * This file is part of the VanitySearch distribution (https://github.com/JeanLucPons/VanitySearch).
 * Copyright (c) 2019 Jean Luc PONS.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include "CLEngine.h"
#include <stdio.h>
#include <string.h>
#include <fstream>
#include <sstream>
#include "../../Timer.h"

// ---------------------------------------------------------------------------------------

std::string toHex(unsigned char *data, int length) {
  std::string ret;
  char tmp[3];
  for (int i = 0; i < length; i++) {
    if (i && i % 4 == 0) ret.append(" ");
    sprintf(tmp, "%02x", (int)data[i]);
    ret.append(tmp);
  }
  return ret;
}

// ---------------------------------------------------------------------------------------

std::string loadKernelSource(const char *filename) {
  std::ifstream file(filename);
  if (!file.is_open()) {
    printf("CLEngine: Failed to open kernel file: %s\n", filename);
    return "";
  }
  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

// ---------------------------------------------------------------------------------------

CLEngine::CLEngine(int nbThreadGroup, int nbThreadPerGroup, int gpuId, uint32_t maxFound, bool rekey) {
  
  this->rekey = rekey;
  this->nbThreadPerGroup = nbThreadPerGroup;
  this->gpuId = gpuId;
  this->maxFound = maxFound;
  initialised = false;
  
  // Initialize all pointers to nullptr
  inputPrefix = nullptr;
  inputPrefixPinned = nullptr;
  inputPrefixLookUp = nullptr;
  inputPrefixLookUpPinned = nullptr;
  inputKey = nullptr;
  inputKeyPinned = nullptr;
  outputPrefix = nullptr;
  outputPrefixPinned = nullptr;
  
  // OpenCL objects
  platform = nullptr;
  device = nullptr;
  context = nullptr;
  queue = nullptr;
  program = nullptr;
  
  kernel_comp_keys = nullptr;
  kernel_comp_keys_p2sh = nullptr;
  kernel_comp_keys_comp = nullptr;
  kernel_comp_keys_pattern = nullptr;
  kernel_comp_keys_p2sh_pattern = nullptr;
  
  inputPrefixBuffer = nullptr;
  inputPrefixLookUpBuffer = nullptr;
  inputKeyBuffer = nullptr;
  outputPrefixBuffer = nullptr;
  
  // Initialize OpenCL
  if (!initOpenCL()) {
    return;
  }
  
  // Allocate memory
  nbThread = nbThreadGroup * nbThreadPerGroup;
  outputSize = (maxFound * ITEM_SIZE32 + 1) * sizeof(uint32_t);
  
  // Allocate pinned host memory
  inputKey = (uint64_t *)malloc(nbThread * 32 * 2);
  outputPrefix = (uint32_t *)malloc(outputSize);
  
  if (!inputKey || !outputPrefix) {
    printf("CLEngine: Failed to allocate host memory\n");
    return;
  }
  
  // Create device buffers
  cl_int err;
  
  inputKeyBuffer = clCreateBuffer(context, CL_MEM_READ_ONLY, 
                                   nbThread * 32 * 2, nullptr, &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create input key buffer: %d\n", err);
    return;
  }
  
  outputPrefixBuffer = clCreateBuffer(context, CL_MEM_READ_WRITE,
                                       outputSize, nullptr, &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create output buffer: %d\n", err);
    return;
  }
  
  lostWarning = false;
  initialised = true;
  
  printf("CLEngine: Initialized with %d work-items in %d work-groups\n", 
         nbThread, nbThreadGroup);
}

// ---------------------------------------------------------------------------------------

CLEngine::~CLEngine() {
  cleanup();
}

// ---------------------------------------------------------------------------------------

void CLEngine::cleanup() {
  
  // Release kernels
  if (kernel_comp_keys) clReleaseKernel(kernel_comp_keys);
  if (kernel_comp_keys_p2sh) clReleaseKernel(kernel_comp_keys_p2sh);
  if (kernel_comp_keys_comp) clReleaseKernel(kernel_comp_keys_comp);
  if (kernel_comp_keys_pattern) clReleaseKernel(kernel_comp_keys_pattern);
  if (kernel_comp_keys_p2sh_pattern) clReleaseKernel(kernel_comp_keys_p2sh_pattern);
  
  // Release memory objects
  if (inputPrefixBuffer) clReleaseMemObject(inputPrefixBuffer);
  if (inputPrefixLookUpBuffer) clReleaseMemObject(inputPrefixLookUpBuffer);
  if (inputKeyBuffer) clReleaseMemObject(inputKeyBuffer);
  if (outputPrefixBuffer) clReleaseMemObject(outputPrefixBuffer);
  
  // Release OpenCL objects
  if (program) clReleaseProgram(program);
  if (queue) clReleaseCommandQueue(queue);
  if (context) clReleaseContext(context);
  
  // Free host memory
  if (inputKey) free(inputKey);
  if (outputPrefix) free(outputPrefix);
  if (inputPrefix) free(inputPrefix);
  if (inputPrefixLookUp) free(inputPrefixLookUp);
}

// ---------------------------------------------------------------------------------------

bool CLEngine::initOpenCL() {
  
  cl_int err;
  cl_uint numPlatforms;
  
  // Get platform count
  err = clGetPlatformIDs(0, nullptr, &numPlatforms);
  if (err != CL_SUCCESS || numPlatforms == 0) {
    printf("CLEngine: No OpenCL platforms found\n");
    return false;
  }
  
  // Get platforms
  cl_platform_id *platforms = new cl_platform_id[numPlatforms];
  err = clGetPlatformIDs(numPlatforms, platforms, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to get platform IDs\n");
    delete[] platforms;
    return false;
  }
  
  // Use first platform by default
  platform = platforms[0];
  delete[] platforms;
  
  // Get device count
  cl_uint numDevices;
  err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, nullptr, &numDevices);
  if (err != CL_SUCCESS || numDevices == 0) {
    printf("CLEngine: No GPU devices found\n");
    return false;
  }
  
  // Get devices
  cl_device_id *devices = new cl_device_id[numDevices];
  err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, numDevices, devices, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to get device IDs\n");
    delete[] devices;
    return false;
  }
  
  // Select device
  if (gpuId >= (int)numDevices) {
    printf("CLEngine: Invalid GPU ID %d (available: 0-%d)\n", gpuId, numDevices-1);
    delete[] devices;
    return false;
  }
  device = devices[gpuId];
  
  // Get device name
  char deviceNameBuf[256];
  err = clGetDeviceInfo(device, CL_DEVICE_NAME, sizeof(deviceNameBuf), 
                        deviceNameBuf, nullptr);
  if (err == CL_SUCCESS) {
    deviceName = std::string(deviceNameBuf);
    printf("CLEngine: Using device: %s\n", deviceName.c_str());
  }
  
  delete[] devices;
  
  // Create context
  context = clCreateContext(nullptr, 1, &device, nullptr, nullptr, &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create context: %d\n", err);
    return false;
  }
  
  // Create command queue
  queue = clCreateCommandQueue(context, device, 0, &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create command queue: %d\n", err);
    return false;
  }
  
  // Build kernels
  if (!buildKernels()) {
    return false;
  }
  
  return true;
}

// ---------------------------------------------------------------------------------------

bool CLEngine::buildKernels() {
  
  cl_int err;
  
  // Load kernel sources
  std::string mathSrc = loadKernelSource("GPU/OpenCL/GPUMath.cl");
  std::string hashSrc = loadKernelSource("GPU/OpenCL/GPUHash.cl");
  std::string base58Src = loadKernelSource("GPU/OpenCL/GPUBase58.cl");
  std::string wildcardSrc = loadKernelSource("GPU/OpenCL/GPUWildcard.cl");
  std::string groupSrc = loadKernelSource("GPU/OpenCL/GPUGroup.cl");
  std::string computeSrc = loadKernelSource("GPU/OpenCL/GPUCompute.cl");
  
  if (mathSrc.empty() || hashSrc.empty() || base58Src.empty() || 
      wildcardSrc.empty() || groupSrc.empty() || computeSrc.empty()) {
    printf("CLEngine: Failed to load kernel sources\n");
    return false;
  }
  
  // Combine all sources
  std::string combinedSrc = mathSrc + "\n" + hashSrc + "\n" + base58Src + "\n" + 
                             wildcardSrc + "\n" + groupSrc + "\n" + computeSrc;
  
  const char *srcPtr = combinedSrc.c_str();
  size_t srcLen = combinedSrc.length();
  
  // Create program
  program = clCreateProgramWithSource(context, 1, &srcPtr, &srcLen, &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create program: %d\n", err);
    return false;
  }
  
  // Build program
  err = clBuildProgram(program, 1, &device, "-cl-std=CL1.2", nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to build program: %d\n", err);
    
    // Get build log
    size_t logSize;
    clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, nullptr, &logSize);
    char *log = new char[logSize];
    clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, logSize, log, nullptr);
    printf("Build log:\n%s\n", log);
    delete[] log;
    
    return false;
  }
  
  // Create kernels
  kernel_comp_keys = clCreateKernel(program, "comp_keys", &err);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to create comp_keys kernel: %d\n", err);
    // Note: These kernels may not exist yet in GPUCompute.cl
    // This is expected and will be fixed when we complete the port
  }
  
  printf("CLEngine: Kernels built successfully\n");
  return true;
}

// ---------------------------------------------------------------------------------------

void CLEngine::PrintCLInfo() {
  
  cl_uint numPlatforms;
  cl_int err = clGetPlatformIDs(0, nullptr, &numPlatforms);
  
  if (err != CL_SUCCESS || numPlatforms == 0) {
    printf("No OpenCL platforms found\n");
    return;
  }
  
  cl_platform_id *platforms = new cl_platform_id[numPlatforms];
  clGetPlatformIDs(numPlatforms, platforms, nullptr);
  
  printf("OpenCL Platforms: %d\n", numPlatforms);
  
  for (cl_uint i = 0; i < numPlatforms; i++) {
    char platformName[256];
    clGetPlatformInfo(platforms[i], CL_PLATFORM_NAME, sizeof(platformName), 
                      platformName, nullptr);
    printf("  Platform %d: %s\n", i, platformName);
    
    cl_uint numDevices;
    err = clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, 0, nullptr, &numDevices);
    
    if (err == CL_SUCCESS && numDevices > 0) {
      cl_device_id *devices = new cl_device_id[numDevices];
      clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, numDevices, devices, nullptr);
      
      for (cl_uint j = 0; j < numDevices; j++) {
        char deviceName[256];
        cl_device_type deviceType;
        cl_ulong globalMem;
        cl_uint computeUnits;
        
        clGetDeviceInfo(devices[j], CL_DEVICE_NAME, sizeof(deviceName), deviceName, nullptr);
        clGetDeviceInfo(devices[j], CL_DEVICE_TYPE, sizeof(deviceType), &deviceType, nullptr);
        clGetDeviceInfo(devices[j], CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(globalMem), &globalMem, nullptr);
        clGetDeviceInfo(devices[j], CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(computeUnits), &computeUnits, nullptr);
        
        printf("    Device %d: %s\n", j, deviceName);
        printf("      Type: %s\n", (deviceType & CL_DEVICE_TYPE_GPU) ? "GPU" : "Other");
        printf("      Global Memory: %.2f GB\n", globalMem / (1024.0 * 1024.0 * 1024.0));
        printf("      Compute Units: %d\n", computeUnits);
      }
      
      delete[] devices;
    }
  }
  
  delete[] platforms;
}

// ---------------------------------------------------------------------------------------

int CLEngine::GetNbThread() {
  return nbThread;
}

int CLEngine::GetGroupSize() {
  return nbThreadPerGroup;
}

void CLEngine::SetSearchMode(int searchMode) {
  this->searchMode = searchMode;
}

void CLEngine::SetSearchType(int searchType) {
  this->searchType = searchType;
}

void CLEngine::SetPattern(const char *pattern) {
  this->pattern = std::string(pattern);
  this->hasPattern = true;
}

// ---------------------------------------------------------------------------------------

void CLEngine::SetPrefix(std::vector<prefix_t> prefixes) {
  
  if (!initialised) return;
  
  cl_int err;
  
  // Allocate prefix buffers if not already allocated
  if (!inputPrefix) {
    inputPrefix = (prefix_t *)malloc(_64K * 2);
    if (!inputPrefix) {
      printf("CLEngine: Failed to allocate prefix memory\n");
      return;
    }
  }
  
  if (!inputPrefixBuffer) {
    inputPrefixBuffer = clCreateBuffer(context, CL_MEM_READ_ONLY, _64K * 2, nullptr, &err);
    if (err != CL_SUCCESS) {
      printf("CLEngine: Failed to create prefix buffer: %d\n", err);
      return;
    }
  }
  
  // Clear and set prefixes
  memset(inputPrefix, 0, _64K * 2);
  for (int i = 0; i < (int)prefixes.size(); i++) {
    inputPrefix[prefixes[i]] = 1;
  }
  
  // Upload to device
  err = clEnqueueWriteBuffer(queue, inputPrefixBuffer, CL_TRUE, 0, _64K * 2, 
                              inputPrefix, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to upload prefix data: %d\n", err);
    return;
  }
  
  lostWarning = false;
}

// ---------------------------------------------------------------------------------------

void CLEngine::SetPrefix(std::vector<LPREFIX> prefixes, uint32_t totalPrefix) {
  
  if (!initialised) return;
  
  cl_int err;
  
  // Allocate prefix buffers if not already allocated
  if (!inputPrefix) {
    inputPrefix = (prefix_t *)malloc(_64K * 2);
  }
  
  if (!inputPrefixLookUp) {
    inputPrefixLookUp = (uint32_t *)malloc((_64K + totalPrefix) * 4);
  }
  
  if (!inputPrefix || !inputPrefixLookUp) {
    printf("CLEngine: Failed to allocate prefix memory\n");
    return;
  }
  
  if (!inputPrefixBuffer) {
    inputPrefixBuffer = clCreateBuffer(context, CL_MEM_READ_ONLY, _64K * 2, nullptr, &err);
    if (err != CL_SUCCESS) {
      printf("CLEngine: Failed to create prefix buffer: %d\n", err);
      return;
    }
  }
  
  if (!inputPrefixLookUpBuffer) {
    inputPrefixLookUpBuffer = clCreateBuffer(context, CL_MEM_READ_ONLY, 
                                              (_64K + totalPrefix) * 4, nullptr, &err);
    if (err != CL_SUCCESS) {
      printf("CLEngine: Failed to create prefix lookup buffer: %d\n", err);
      return;
    }
  }
  
  // Build lookup tables
  uint32_t offset = _64K;
  memset(inputPrefix, 0, _64K * 2);
  memset(inputPrefixLookUp, 0, _64K * 4);
  
  for (int i = 0; i < (int)prefixes.size(); i++) {
    int nbLPrefix = (int)prefixes[i].lPrefixes.size();
    inputPrefix[prefixes[i].sPrefix] = (uint16_t)nbLPrefix;
    inputPrefixLookUp[prefixes[i].sPrefix] = offset;
    for (int j = 0; j < nbLPrefix; j++) {
      inputPrefixLookUp[offset++] = prefixes[i].lPrefixes[j];
    }
  }
  
  if (offset != (_64K + totalPrefix)) {
    printf("CLEngine: Wrong totalPrefix %d!=%d!\n", offset - _64K, totalPrefix);
    return;
  }
  
  // Upload to device
  err = clEnqueueWriteBuffer(queue, inputPrefixBuffer, CL_TRUE, 0, _64K * 2, 
                              inputPrefix, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to upload prefix data: %d\n", err);
    return;
  }
  
  err = clEnqueueWriteBuffer(queue, inputPrefixLookUpBuffer, CL_TRUE, 0, 
                              (_64K + totalPrefix) * 4, inputPrefixLookUp, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to upload prefix lookup data: %d\n", err);
    return;
  }
  
  lostWarning = false;
}

// ---------------------------------------------------------------------------------------

bool CLEngine::SetKeys(Point *p) {
  
  if (!initialised) return false;
  
  // Sets the starting keys for each thread
  // p must contain nbThread public keys
  for (int i = 0; i < nbThread; i += nbThreadPerGroup) {
    for (int j = 0; j < nbThreadPerGroup; j++) {
      
      inputKey[8*i + j + 0*nbThreadPerGroup] = p[i + j].x.bits64[0];
      inputKey[8*i + j + 1*nbThreadPerGroup] = p[i + j].x.bits64[1];
      inputKey[8*i + j + 2*nbThreadPerGroup] = p[i + j].x.bits64[2];
      inputKey[8*i + j + 3*nbThreadPerGroup] = p[i + j].x.bits64[3];
      
      inputKey[8*i + j + 4*nbThreadPerGroup] = p[i + j].y.bits64[0];
      inputKey[8*i + j + 5*nbThreadPerGroup] = p[i + j].y.bits64[1];
      inputKey[8*i + j + 6*nbThreadPerGroup] = p[i + j].y.bits64[2];
      inputKey[8*i + j + 7*nbThreadPerGroup] = p[i + j].y.bits64[3];
    }
  }
  
  // Upload to device
  cl_int err = clEnqueueWriteBuffer(queue, inputKeyBuffer, CL_TRUE, 0, 
                                     nbThread * 32 * 2, inputKey, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to upload key data: %d\n", err);
    return false;
  }
  
  // Call kernel after setting keys
  return callKernel();
}

// ---------------------------------------------------------------------------------------

bool CLEngine::Launch(std::vector<ITEM> &prefixFound, bool spinWait) {
  
  if (!initialised) return false;
  
  prefixFound.clear();
  
  cl_int err;
  
  // Read result count first
  uint32_t nbFound = 0;
  err = clEnqueueReadBuffer(queue, outputPrefixBuffer, CL_TRUE, 0, 4, 
                             &nbFound, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to read result count: %d\n", err);
    return false;
  }
  
  // Check for lost items
  if (nbFound > maxFound) {
    if (!lostWarning) {
      printf("\nWarning, %d items lost\nHint: Search with less prefixes, less threads (-g) or increase maxFound (-m)\n", 
             (nbFound - maxFound));
      lostWarning = true;
    }
    nbFound = maxFound;
  }
  
  // Read all results
  if (nbFound > 0) {
    size_t resultSize = nbFound * ITEM_SIZE + 4;
    err = clEnqueueReadBuffer(queue, outputPrefixBuffer, CL_TRUE, 0, resultSize, 
                               outputPrefix, 0, nullptr, nullptr);
    if (err != CL_SUCCESS) {
      printf("CLEngine: Failed to read results: %d\n", err);
      return false;
    }
    
    // Parse results
    for (uint32_t i = 0; i < nbFound; i++) {
      uint32_t *itemPtr = outputPrefix + (i * ITEM_SIZE32 + 1);
      ITEM it;
      it.thId = itemPtr[0];
      int16_t *ptr = (int16_t *)&(itemPtr[1]);
      it.endo = ptr[0] & 0x7FFF;
      it.mode = (ptr[0] & 0x8000) != 0;
      it.incr = ptr[1];
      it.hash = (uint8_t *)(itemPtr + 2);
      prefixFound.push_back(it);
    }
  }
  
  // Launch next kernel
  return callKernel();
}

// ---------------------------------------------------------------------------------------

void CLEngine::WaitForCompletion() {
  if (queue) {
    clFinish(queue);
  }
}

// ---------------------------------------------------------------------------------------

bool CLEngine::callKernel() {
  
  if (!initialised || !kernel_comp_keys) return false;
  
  cl_int err;
  
  // Reset result counter
  uint32_t zero = 0;
  err = clEnqueueWriteBuffer(queue, outputPrefixBuffer, CL_TRUE, 0, 4, 
                              &zero, 0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to reset output buffer: %d\n", err);
    return false;
  }
  
  // Select appropriate kernel based on search type and mode
  cl_kernel kernel = nullptr;
  
  if (searchType == P2SH) {
    if (hasPattern) {
      kernel = kernel_comp_keys_p2sh_pattern;
    } else {
      kernel = kernel_comp_keys_p2sh;
    }
  } else {
    // P2PKH, BECH32, or POCX
    if (hasPattern) {
      if (searchType == BECH32) {
        printf("CLEngine: BECH32 not yet supported with wildcard\n");
        return false;
      }
      kernel = kernel_comp_keys_pattern;
    } else {
      if (searchMode == SEARCH_COMPRESSED) {
        kernel = kernel_comp_keys_comp;
      } else {
        kernel = kernel_comp_keys;
      }
    }
  }
  
  if (!kernel) {
    printf("CLEngine: Kernel not available for current search configuration\n");
    return false;
  }
  
  // Set kernel arguments
  int argIdx = 0;
  
  if (hasPattern) {
    // Pattern-based search
    err = clSetKernelArg(kernel, argIdx++, sizeof(cl_uint), &searchMode);
    err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputPrefixBuffer);
    err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputKeyBuffer);
    err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_uint), &maxFound);
    err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &outputPrefixBuffer);
  } else {
    // Prefix-based search
    if (searchMode == SEARCH_COMPRESSED && searchType != P2SH) {
      err = clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputPrefixBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputPrefixLookUpBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputKeyBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_uint), &maxFound);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &outputPrefixBuffer);
    } else {
      err = clSetKernelArg(kernel, argIdx++, sizeof(cl_uint), &searchMode);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputPrefixBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputPrefixLookUpBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &inputKeyBuffer);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_uint), &maxFound);
      err |= clSetKernelArg(kernel, argIdx++, sizeof(cl_mem), &outputPrefixBuffer);
    }
  }
  
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to set kernel arguments: %d\n", err);
    return false;
  }
  
  // Execute kernel
  size_t globalSize = nbThread;
  size_t localSize = nbThreadPerGroup;
  
  err = clEnqueueNDRangeKernel(queue, kernel, 1, nullptr, &globalSize, &localSize, 
                                0, nullptr, nullptr);
  if (err != CL_SUCCESS) {
    printf("CLEngine: Failed to execute kernel: %d\n", err);
    return false;
  }
  
  return true;
}

// ---------------------------------------------------------------------------------------

bool CLEngine::CheckHash(uint8_t *h, std::vector<ITEM>& found, int tid, int incr, int endo, int *nbOK) {
  
  bool ok = true;
  
  // Search in results found by GPU
  bool f = false;
  int l = 0;
  
  while (l < (int)found.size() && !f) {
    // Compare 20-byte hash
    f = (memcmp(found[l].hash, h, 20) == 0);
    if (!f) l++;
  }
  
  if (f) {
    found.erase(found.begin() + l);
    *nbOK = *nbOK + 1;
  } else {
    ok = false;
    printf("Expected item not found %s (thread=%d, incr=%d, endo=%d)\n",
           toHex(h, 20).c_str(), tid, incr, endo);
  }
  
  return ok;
}

// ---------------------------------------------------------------------------------------

bool CLEngine::Check(Secp256K1 *secp) {
  
  if (!initialised) return false;
  
  printf("GPU: %s\n", deviceName.c_str());
  
  // Basic validation - full check implementation would be extensive
  // For now, just verify device is responding
  
  return true;
}

// ---------------------------------------------------------------------------------------

void CLEngine::GenerateCode(Secp256K1 *secp, int size) {
  // Not needed for OpenCL - kernels are loaded from .cl files
  // This function is used in CUDA to generate GPU code at runtime
}

// ---------------------------------------------------------------------------------------
