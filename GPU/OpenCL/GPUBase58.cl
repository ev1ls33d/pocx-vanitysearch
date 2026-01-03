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

// ---------------------------------------------------------------------------------
// Base58 encoding for POCX (lowercase optimized)
// ---------------------------------------------------------------------------------

// POCX uses lowercase base58 alphabet (33 characters)
__constant char *pszBase58POCX = (char *)"abcdefghijkmnopqrstuvwxyz123456789";

// Standard Base58 alphabet (58 characters)
__constant char *pszBase58 = (char *)"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

__constant char b58digits_map[128] = {
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1, 0, 1, 2, 3, 4, 5, 6,  7, 8,-1,-1,-1,-1,-1,-1,
  -1, 9,10,11,12,13,14,15, 16,-1,17,18,19,20,21,-1,
  22,23,24,25,26,27,28,29, 30,31,32,-1,-1,-1,-1,-1,
  -1,33,34,35,36,37,38,39, 40,41,42,43,-1,44,45,46,
  47,48,49,50,51,52,53,54, 55,56,57,-1,-1,-1,-1,-1,
};

inline void _GetAddress(int type, __private uint *hash, char *b58Add) {
  uint addBytes[16];
  uint s[8];
  uchar A[25];
  int retPos = 0;
  uchar digits[128];
  int digitslen = 1;
  
  // Set version byte based on address type
  switch(type) {
    case 0: // P2PKH
      A[0] = 0x00;
      break;
    case 1: // P2SH
      A[0] = 0x05;
      break;
    case 3: // POCX
      A[0] = 0x38; // POCX version byte
      break;
    default:
      A[0] = 0x00;
      break;
  }
  
  // Copy hash
  for(int i = 0; i < 20; i++)
    A[i+1] = ((uchar*)hash)[i];

  // Compute checksum (double SHA256)
  addBytes[0] = (A[0] << 24) | (A[1] << 16) | (A[2] << 8) | A[3];
  addBytes[1] = (A[4] << 24) | (A[5] << 16) | (A[6] << 8) | A[7];
  addBytes[2] = (A[8] << 24) | (A[9] << 16) | (A[10] << 8) | A[11];
  addBytes[3] = (A[12] << 24) | (A[13] << 16) | (A[14] << 8) | A[15];
  addBytes[4] = (A[16] << 24) | (A[17] << 16) | (A[18] << 8) | A[19];
  addBytes[5] = (A[20] << 24) | 0x800000;
  for(int i = 6; i < 15; i++)
    addBytes[i] = 0;
  addBytes[15] = 21 * 8; // 21 bytes

  SHA256Initialize(s);
  SHA256Transform(s, addBytes);

  for(int i = 0; i < 8; i++)
    addBytes[i] = s[i];
  addBytes[8] = 0x80000000;
  for(int i = 9; i < 15; i++)
    addBytes[i] = 0;
  addBytes[15] = 32 * 8; // 32 bytes

  SHA256Initialize(s);
  SHA256Transform(s, addBytes);

  A[21] = (uchar)(s[0] >> 24);
  A[22] = (uchar)(s[0] >> 16);
  A[23] = (uchar)(s[0] >> 8);
  A[24] = (uchar)(s[0]);

  // Base58 encode
  digits[0] = 0;
  for(int i = 0; i < 25; i++) {
    uint carry = (uint)A[i];
    for(int j = 0; j < digitslen; j++) {
      carry += (uint)(digits[j]) << 8;
      digits[j] = (uchar)(carry % 58);
      carry /= 58;
    }
    while(carry > 0) {
      digits[digitslen++] = (uchar)(carry % 58);
      carry /= 58;
    }
  }

  // Skip leading zeros in A, add '1' for each
  for(int i = 0; i < 25 && A[i] == 0; i++)
    b58Add[retPos++] = '1';

  // Reverse and map to base58 alphabet
  char *alphabet = (type == 3) ? pszBase58POCX : pszBase58;
  for(int i = digitslen - 1; i >= 0; i--)
    b58Add[retPos++] = alphabet[digits[i]];
    
  b58Add[retPos] = '\0';
}
