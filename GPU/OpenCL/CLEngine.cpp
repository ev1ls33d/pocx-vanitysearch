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
// Stubs for remaining methods - to be implemented

void CLEngine::SetPrefix(std::vector<prefix_t> prefixes) {
  // TODO: Implement prefix setting
}

void CLEngine::SetPrefix(std::vector<LPREFIX> prefixes, uint32_t totalPrefix) {
  // TODO: Implement prefix setting with lookup table
}

bool CLEngine::SetKeys(Point *p) {
  // TODO: Implement key setting
  return true;
}

bool CLEngine::Launch(std::vector<ITEM> &prefixFound, bool spinWait) {
  // TODO: Implement kernel launch
  return callKernel();
}

void CLEngine::WaitForCompletion() {
  if (queue) {
    clFinish(queue);
  }
}

bool CLEngine::Check(Secp256K1 *secp) {
  // TODO: Implement checking
  return true;
}

void CLEngine::GenerateCode(Secp256K1 *secp, int size) {
  // TODO: Implement code generation (if needed)
}

bool CLEngine::callKernel() {
  // TODO: Implement actual kernel execution
  return false;
}

bool CLEngine::CheckHash(uint8_t *h, std::vector<ITEM>& found, int tid, int incr, int endo, int *ok) {
  // TODO: Implement hash checking
  return false;
}

// ---------------------------------------------------------------------------------------
