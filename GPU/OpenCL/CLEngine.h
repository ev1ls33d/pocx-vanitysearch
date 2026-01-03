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

#ifndef CLENGINEH
#define CLENGINEH

#include <vector>
#include <string>
#include "../../SECP256k1.h"

#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#define SEARCH_COMPRESSED 0
#define SEARCH_UNCOMPRESSED 1
#define SEARCH_BOTH 2

// Address types
#define P2PKH 0
#define P2SH 1
#define BECH32 2
#define POCX 3

typedef uint16_t prefix_t;
typedef uint32_t prefixl_t;

typedef struct {
  uint32_t thId;
  int16_t  incr;
  int16_t  endo;
  uint8_t  *hash;
  bool mode;
} ITEM;

// Second level lookup
typedef struct {
  prefix_t sPrefix;
  std::vector<prefixl_t> lPrefixes;
} LPREFIX;

class CLEngine {

public:

  CLEngine(int nbThreadGroup, int nbThreadPerGroup, int gpuId, uint32_t maxFound, bool rekey);
  ~CLEngine();
  
  void WaitForCompletion();
  void SetPrefix(std::vector<prefix_t> prefixes);
  void SetPrefix(std::vector<LPREFIX> prefixes, uint32_t totalPrefix);
  bool SetKeys(Point *p);
  void SetSearchMode(int searchMode);
  void SetSearchType(int searchType);
  void SetPattern(const char *pattern);
  bool Launch(std::vector<ITEM> &prefixFound, bool spinWait = false);
  int GetNbThread();
  int GetGroupSize();
  bool Check(Secp256K1 *secp);
  std::string deviceName;

  static void PrintCLInfo();
  static void GenerateCode(Secp256K1 *secp, int size);

private:

  bool callKernel();
  bool CheckHash(uint8_t *h, std::vector<ITEM>& found, int tid, int incr, int endo, int *ok);
  bool initOpenCL();
  bool buildKernels();
  void cleanup();

  // OpenCL objects
  cl_platform_id platform;
  cl_device_id device;
  cl_context context;
  cl_command_queue queue;
  cl_program program;
  cl_kernel kernel_comp_keys;
  cl_kernel kernel_comp_keys_p2sh;
  cl_kernel kernel_comp_keys_comp;
  cl_kernel kernel_comp_keys_pattern;
  cl_kernel kernel_comp_keys_p2sh_pattern;

  // Memory buffers
  cl_mem inputPrefixBuffer;
  cl_mem inputPrefixLookUpBuffer;
  cl_mem inputKeyBuffer;
  cl_mem outputPrefixBuffer;

  // Host memory
  prefix_t *inputPrefix;
  prefix_t *inputPrefixPinned;
  uint32_t *inputPrefixLookUp;
  uint32_t *inputPrefixLookUpPinned;
  uint64_t *inputKey;
  uint64_t *inputKeyPinned;
  uint32_t *outputPrefix;
  uint32_t *outputPrefixPinned;

  // Configuration
  int nbThread;
  int nbThreadPerGroup;
  int gpuId;
  bool initialised;
  uint32_t searchMode;
  uint32_t searchType;
  bool littleEndian;
  bool lostWarning;
  bool rekey;
  uint32_t maxFound;
  uint32_t outputSize;
  std::string pattern;
  bool hasPattern;
};

#endif // CLENGINEH
