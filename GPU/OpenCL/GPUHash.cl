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
// SHA256
// ---------------------------------------------------------------------------------

__constant uint K[64] = {
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
};

__constant uint I[8] = {
  0x6a09e667u,
  0xbb67ae85u,
  0x3c6ef372u,
  0xa54ff53au,
  0x510e527fu,
  0x9b05688cu,
  0x1f83d9abu,
  0x5be0cd19u,
};

inline uint rotr32(uint x, uint n) {
  return (x >> n) | (x << (32 - n));
}

inline uint S0(uint x) {
  return rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22);
}

inline uint S1(uint x) {
  return rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25);
}

inline uint s0(uint x) {
  return rotr32(x, 7) ^ rotr32(x, 18) ^ (x >> 3);
}

inline uint s1(uint x) {
  return rotr32(x, 17) ^ rotr32(x, 19) ^ (x >> 10);
}

inline uint maj(uint x, uint y, uint z) {
  return (x & y) ^ (x & z) ^ (y & z);
}

inline uint ch(uint x, uint y, uint z) {
  return (x & y) ^ (~x & z);
}

inline void SHA256Initialize(uint *s) {
  for(int i = 0; i < 8; i++)
    s[i] = I[i];
}

inline void SHA256Transform(uint *s, __private uint *buf) {
  uint W[64];
  uint a, b, c, d, e, f, g, h;
  uint T1, T2;

  // Prepare message schedule
  for(int i = 0; i < 16; i++)
    W[i] = buf[i];
    
  for(int i = 16; i < 64; i++)
    W[i] = s1(W[i-2]) + W[i-7] + s0(W[i-15]) + W[i-16];

  // Initialize working variables
  a = s[0];
  b = s[1];
  c = s[2];
  d = s[3];
  e = s[4];
  f = s[5];
  g = s[6];
  h = s[7];

  // Main loop
  #pragma unroll 8
  for(int i = 0; i < 64; i++) {
    T1 = h + S1(e) + ch(e, f, g) + K[i] + W[i];
    T2 = S0(a) + maj(a, b, c);
    h = g;
    g = f;
    f = e;
    e = d + T1;
    d = c;
    c = b;
    b = a;
    a = T1 + T2;
  }

  // Add working variables to state
  s[0] += a;
  s[1] += b;
  s[2] += c;
  s[3] += d;
  s[4] += e;
  s[5] += f;
  s[6] += g;
  s[7] += h;
}

// ---------------------------------------------------------------------------------
// RIPEMD160
// ---------------------------------------------------------------------------------

__constant uint IV[5] = {
  0x67452301u,
  0xEFCDAB89u,
  0x98BADCFEu,
  0x10325476u,
  0xC3D2E1F0u,
};

inline uint F(uint x, uint y, uint z) {
  return x ^ y ^ z;
}

inline uint G(uint x, uint y, uint z) {
  return (x & y) | (~x & z);
}

inline uint H(uint x, uint y, uint z) {
  return (x | ~y) ^ z;
}

inline uint I_RMD(uint x, uint y, uint z) {
  return (x & z) | (y & ~z);
}

inline uint J(uint x, uint y, uint z) {
  return x ^ (y | ~z);
}

inline uint rol(uint x, uint n) {
  return (x << n) | (x >> (32 - n));
}

inline uint FF(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + F(b, c, d) + x, s) + e;
}

inline uint GG(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + G(b, c, d) + x + 0x5A827999u, s) + e;
}

inline uint HH(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + H(b, c, d) + x + 0x6ED9EBA1u, s) + e;
}

inline uint II(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + I_RMD(b, c, d) + x + 0x8F1BBCDCu, s) + e;
}

inline uint JJ(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + J(b, c, d) + x + 0xA953FD4Eu, s) + e;
}

inline uint FFF(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + F(b, c, d) + x, s) + e;
}

inline uint GGG(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + G(b, c, d) + x + 0x7A6D76E9u, s) + e;
}

inline uint HHH(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + H(b, c, d) + x + 0x6D703EF3u, s) + e;
}

inline uint III(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + I_RMD(b, c, d) + x + 0x5C4DD124u, s) + e;
}

inline uint JJJ(uint a, uint b, uint c, uint d, uint e, uint x, uint s) {
  return rol(a + J(b, c, d) + x + 0x50A28BE6u, s) + e;
}

inline void RIPEMD160Transform(uint *digest, __private uint *X) {
  uint a, b, c, d, e;
  uint aa, bb, cc, dd, ee;

  a = aa = digest[0];
  b = bb = digest[1];
  c = cc = digest[2];
  d = dd = digest[3];
  e = ee = digest[4];

  // Round 1
  a = FF(a, b, c, d, e, X[0], 11); c = rol(c, 10);
  e = FF(e, a, b, c, d, X[1], 14); b = rol(b, 10);
  d = FF(d, e, a, b, c, X[2], 15); a = rol(a, 10);
  c = FF(c, d, e, a, b, X[3], 12); e = rol(e, 10);
  b = FF(b, c, d, e, a, X[4], 5);  d = rol(d, 10);
  a = FF(a, b, c, d, e, X[5], 8);  c = rol(c, 10);
  e = FF(e, a, b, c, d, X[6], 7);  b = rol(b, 10);
  d = FF(d, e, a, b, c, X[7], 9);  a = rol(a, 10);
  c = FF(c, d, e, a, b, X[8], 11); e = rol(e, 10);
  b = FF(b, c, d, e, a, X[9], 13); d = rol(d, 10);
  a = FF(a, b, c, d, e, X[10], 14); c = rol(c, 10);
  e = FF(e, a, b, c, d, X[11], 15); b = rol(b, 10);
  d = FF(d, e, a, b, c, X[12], 6);  a = rol(a, 10);
  c = FF(c, d, e, a, b, X[13], 7);  e = rol(e, 10);
  b = FF(b, c, d, e, a, X[14], 9);  d = rol(d, 10);
  a = FF(a, b, c, d, e, X[15], 8);  c = rol(c, 10);

  // Round 2
  e = GG(e, a, b, c, d, X[7], 7);   b = rol(b, 10);
  d = GG(d, e, a, b, c, X[4], 6);   a = rol(a, 10);
  c = GG(c, d, e, a, b, X[13], 8);  e = rol(e, 10);
  b = GG(b, c, d, e, a, X[1], 13);  d = rol(d, 10);
  a = GG(a, b, c, d, e, X[10], 11); c = rol(c, 10);
  e = GG(e, a, b, c, d, X[6], 9);   b = rol(b, 10);
  d = GG(d, e, a, b, c, X[15], 7);  a = rol(a, 10);
  c = GG(c, d, e, a, b, X[3], 15);  e = rol(e, 10);
  b = GG(b, c, d, e, a, X[12], 7);  d = rol(d, 10);
  a = GG(a, b, c, d, e, X[0], 12);  c = rol(c, 10);
  e = GG(e, a, b, c, d, X[9], 15);  b = rol(b, 10);
  d = GG(d, e, a, b, c, X[5], 9);   a = rol(a, 10);
  c = GG(c, d, e, a, b, X[2], 11);  e = rol(e, 10);
  b = GG(b, c, d, e, a, X[14], 7);  d = rol(d, 10);
  a = GG(a, b, c, d, e, X[11], 13); c = rol(c, 10);
  e = GG(e, a, b, c, d, X[8], 12);  b = rol(b, 10);

  // Round 3
  d = HH(d, e, a, b, c, X[3], 11);  a = rol(a, 10);
  c = HH(c, d, e, a, b, X[10], 13); e = rol(e, 10);
  b = HH(b, c, d, e, a, X[14], 6);  d = rol(d, 10);
  a = HH(a, b, c, d, e, X[4], 7);   c = rol(c, 10);
  e = HH(e, a, b, c, d, X[9], 14);  b = rol(b, 10);
  d = HH(d, e, a, b, c, X[15], 9);  a = rol(a, 10);
  c = HH(c, d, e, a, b, X[8], 13);  e = rol(e, 10);
  b = HH(b, c, d, e, a, X[1], 15);  d = rol(d, 10);
  a = HH(a, b, c, d, e, X[2], 14);  c = rol(c, 10);
  e = HH(e, a, b, c, d, X[7], 8);   b = rol(b, 10);
  d = HH(d, e, a, b, c, X[0], 13);  a = rol(a, 10);
  c = HH(c, d, e, a, b, X[6], 6);   e = rol(e, 10);
  b = HH(b, c, d, e, a, X[13], 5);  d = rol(d, 10);
  a = HH(a, b, c, d, e, X[11], 12); c = rol(c, 10);
  e = HH(e, a, b, c, d, X[5], 7);   b = rol(b, 10);
  d = HH(d, e, a, b, c, X[12], 5);  a = rol(a, 10);

  // Round 4
  c = II(c, d, e, a, b, X[1], 11);  e = rol(e, 10);
  b = II(b, c, d, e, a, X[9], 12);  d = rol(d, 10);
  a = II(a, b, c, d, e, X[11], 14); c = rol(c, 10);
  e = II(e, a, b, c, d, X[10], 15); b = rol(b, 10);
  d = II(d, e, a, b, c, X[0], 14);  a = rol(a, 10);
  c = II(c, d, e, a, b, X[8], 15);  e = rol(e, 10);
  b = II(b, c, d, e, a, X[12], 9);  d = rol(d, 10);
  a = II(a, b, c, d, e, X[4], 8);   c = rol(c, 10);
  e = II(e, a, b, c, d, X[13], 9);  b = rol(b, 10);
  d = II(d, e, a, b, c, X[3], 14);  a = rol(a, 10);
  c = II(c, d, e, a, b, X[7], 5);   e = rol(e, 10);
  b = II(b, c, d, e, a, X[15], 6);  d = rol(d, 10);
  a = II(a, b, c, d, e, X[14], 8);  c = rol(c, 10);
  e = II(e, a, b, c, d, X[5], 6);   b = rol(b, 10);
  d = II(d, e, a, b, c, X[6], 5);   a = rol(a, 10);
  c = II(c, d, e, a, b, X[2], 12);  e = rol(e, 10);

  // Round 5
  b = JJ(b, c, d, e, a, X[4], 9);   d = rol(d, 10);
  a = JJ(a, b, c, d, e, X[0], 15);  c = rol(c, 10);
  e = JJ(e, a, b, c, d, X[5], 5);   b = rol(b, 10);
  d = JJ(d, e, a, b, c, X[9], 11);  a = rol(a, 10);
  c = JJ(c, d, e, a, b, X[7], 6);   e = rol(e, 10);
  b = JJ(b, c, d, e, a, X[12], 8);  d = rol(d, 10);
  a = JJ(a, b, c, d, e, X[2], 13);  c = rol(c, 10);
  e = JJ(e, a, b, c, d, X[10], 12); b = rol(b, 10);
  d = JJ(d, e, a, b, c, X[14], 5);  a = rol(a, 10);
  c = JJ(c, d, e, a, b, X[1], 12);  e = rol(e, 10);
  b = JJ(b, c, d, e, a, X[3], 13);  d = rol(d, 10);
  a = JJ(a, b, c, d, e, X[8], 14);  c = rol(c, 10);
  e = JJ(e, a, b, c, d, X[11], 11); b = rol(b, 10);
  d = JJ(d, e, a, b, c, X[6], 8);   a = rol(a, 10);
  c = JJ(c, d, e, a, b, X[15], 5);  e = rol(e, 10);
  b = JJ(b, c, d, e, a, X[13], 6);  d = rol(d, 10);

  // Parallel rounds
  aa = JJJ(aa, bb, cc, dd, ee, X[5], 8);   cc = rol(cc, 10);
  ee = JJJ(ee, aa, bb, cc, dd, X[14], 9);  bb = rol(bb, 10);
  dd = JJJ(dd, ee, aa, bb, cc, X[7], 9);   aa = rol(aa, 10);
  cc = JJJ(cc, dd, ee, aa, bb, X[0], 11);  ee = rol(ee, 10);
  bb = JJJ(bb, cc, dd, ee, aa, X[9], 13);  dd = rol(dd, 10);
  aa = JJJ(aa, bb, cc, dd, ee, X[2], 15);  cc = rol(cc, 10);
  ee = JJJ(ee, aa, bb, cc, dd, X[11], 15); bb = rol(bb, 10);
  dd = JJJ(dd, ee, aa, bb, cc, X[4], 5);   aa = rol(aa, 10);
  cc = JJJ(cc, dd, ee, aa, bb, X[13], 7);  ee = rol(ee, 10);
  bb = JJJ(bb, cc, dd, ee, aa, X[6], 7);   dd = rol(dd, 10);
  aa = JJJ(aa, bb, cc, dd, ee, X[15], 8);  cc = rol(cc, 10);
  ee = JJJ(ee, aa, bb, cc, dd, X[8], 11);  bb = rol(bb, 10);
  dd = JJJ(dd, ee, aa, bb, cc, X[1], 14);  aa = rol(aa, 10);
  cc = JJJ(cc, dd, ee, aa, bb, X[10], 14); ee = rol(ee, 10);
  bb = JJJ(bb, cc, dd, ee, aa, X[3], 12);  dd = rol(dd, 10);
  aa = JJJ(aa, bb, cc, dd, ee, X[12], 6);  cc = rol(cc, 10);

  ee = III(ee, aa, bb, cc, dd, X[6], 9);   bb = rol(bb, 10);
  dd = III(dd, ee, aa, bb, cc, X[11], 13); aa = rol(aa, 10);
  cc = III(cc, dd, ee, aa, bb, X[3], 15);  ee = rol(ee, 10);
  bb = III(bb, cc, dd, ee, aa, X[7], 7);   dd = rol(dd, 10);
  aa = III(aa, bb, cc, dd, ee, X[0], 12);  cc = rol(cc, 10);
  ee = III(ee, aa, bb, cc, dd, X[13], 8);  bb = rol(bb, 10);
  dd = III(dd, ee, aa, bb, cc, X[5], 9);   aa = rol(aa, 10);
  cc = III(cc, dd, ee, aa, bb, X[10], 11); ee = rol(ee, 10);
  bb = III(bb, cc, dd, ee, aa, X[14], 7);  dd = rol(dd, 10);
  aa = III(aa, bb, cc, dd, ee, X[15], 7);  cc = rol(cc, 10);
  ee = III(ee, aa, bb, cc, dd, X[8], 12);  bb = rol(bb, 10);
  dd = III(dd, ee, aa, bb, cc, X[12], 7);  aa = rol(aa, 10);
  cc = III(cc, dd, ee, aa, bb, X[4], 6);   ee = rol(ee, 10);
  bb = III(bb, cc, dd, ee, aa, X[9], 15);  dd = rol(dd, 10);
  aa = III(aa, bb, cc, dd, ee, X[1], 13);  cc = rol(cc, 10);
  ee = III(ee, aa, bb, cc, dd, X[2], 11);  bb = rol(bb, 10);

  dd = HHH(dd, ee, aa, bb, cc, X[15], 9);  aa = rol(aa, 10);
  cc = HHH(cc, dd, ee, aa, bb, X[5], 7);   ee = rol(ee, 10);
  bb = HHH(bb, cc, dd, ee, aa, X[1], 15);  dd = rol(dd, 10);
  aa = HHH(aa, bb, cc, dd, ee, X[3], 11);  cc = rol(cc, 10);
  ee = HHH(ee, aa, bb, cc, dd, X[7], 8);   bb = rol(bb, 10);
  dd = HHH(dd, ee, aa, bb, cc, X[14], 6);  aa = rol(aa, 10);
  cc = HHH(cc, dd, ee, aa, bb, X[6], 6);   ee = rol(ee, 10);
  bb = HHH(bb, cc, dd, ee, aa, X[9], 14);  dd = rol(dd, 10);
  aa = HHH(aa, bb, cc, dd, ee, X[11], 12); cc = rol(cc, 10);
  ee = HHH(ee, aa, bb, cc, dd, X[8], 13);  bb = rol(bb, 10);
  dd = HHH(dd, ee, aa, bb, cc, X[12], 5);  aa = rol(aa, 10);
  cc = HHH(cc, dd, ee, aa, bb, X[2], 14);  ee = rol(ee, 10);
  bb = HHH(bb, cc, dd, ee, aa, X[10], 13); dd = rol(dd, 10);
  aa = HHH(aa, bb, cc, dd, ee, X[0], 13);  cc = rol(cc, 10);
  ee = HHH(ee, aa, bb, cc, dd, X[4], 7);   bb = rol(bb, 10);
  dd = HHH(dd, ee, aa, bb, cc, X[13], 5);  aa = rol(aa, 10);

  cc = GGG(cc, dd, ee, aa, bb, X[8], 15);  ee = rol(ee, 10);
  bb = GGG(bb, cc, dd, ee, aa, X[6], 5);   dd = rol(dd, 10);
  aa = GGG(aa, bb, cc, dd, ee, X[4], 8);   cc = rol(cc, 10);
  ee = GGG(ee, aa, bb, cc, dd, X[1], 11);  bb = rol(bb, 10);
  dd = GGG(dd, ee, aa, bb, cc, X[3], 14);  aa = rol(aa, 10);
  cc = GGG(cc, dd, ee, aa, bb, X[11], 14); ee = rol(ee, 10);
  bb = GGG(bb, cc, dd, ee, aa, X[15], 6);  dd = rol(dd, 10);
  aa = GGG(aa, bb, cc, dd, ee, X[0], 14);  cc = rol(cc, 10);
  ee = GGG(ee, aa, bb, cc, dd, X[5], 6);   bb = rol(bb, 10);
  dd = GGG(dd, ee, aa, bb, cc, X[12], 9);  aa = rol(aa, 10);
  cc = GGG(cc, dd, ee, aa, bb, X[2], 12);  ee = rol(ee, 10);
  bb = GGG(bb, cc, dd, ee, aa, X[13], 9);  dd = rol(dd, 10);
  aa = GGG(aa, bb, cc, dd, ee, X[9], 12);  cc = rol(cc, 10);
  ee = GGG(ee, aa, bb, cc, dd, X[7], 5);   bb = rol(bb, 10);
  dd = GGG(dd, ee, aa, bb, cc, X[10], 15); aa = rol(aa, 10);
  cc = GGG(cc, dd, ee, aa, bb, X[14], 8);  ee = rol(ee, 10);

  bb = FFF(bb, cc, dd, ee, aa, X[12], 8);  dd = rol(dd, 10);
  aa = FFF(aa, bb, cc, dd, ee, X[15], 5);  cc = rol(cc, 10);
  ee = FFF(ee, aa, bb, cc, dd, X[10], 12); bb = rol(bb, 10);
  dd = FFF(dd, ee, aa, bb, cc, X[4], 9);   aa = rol(aa, 10);
  cc = FFF(cc, dd, ee, aa, bb, X[1], 12);  ee = rol(ee, 10);
  bb = FFF(bb, cc, dd, ee, aa, X[5], 5);   dd = rol(dd, 10);
  aa = FFF(aa, bb, cc, dd, ee, X[8], 14);  cc = rol(cc, 10);
  ee = FFF(ee, aa, bb, cc, dd, X[7], 6);   bb = rol(bb, 10);
  dd = FFF(dd, ee, aa, bb, cc, X[6], 8);   aa = rol(aa, 10);
  cc = FFF(cc, dd, ee, aa, bb, X[2], 13);  ee = rol(ee, 10);
  bb = FFF(bb, cc, dd, ee, aa, X[13], 6);  dd = rol(dd, 10);
  aa = FFF(aa, bb, cc, dd, ee, X[14], 5);  cc = rol(cc, 10);
  ee = FFF(ee, aa, bb, cc, dd, X[0], 15);  bb = rol(bb, 10);
  dd = FFF(dd, ee, aa, bb, cc, X[3], 13);  aa = rol(aa, 10);
  cc = FFF(cc, dd, ee, aa, bb, X[9], 11);  ee = rol(ee, 10);
  bb = FFF(bb, cc, dd, ee, aa, X[11], 11); dd = rol(dd, 10);

  // Final addition
  dd += c + digest[1];
  digest[1] = digest[2] + d + ee;
  digest[2] = digest[3] + e + aa;
  digest[3] = digest[4] + a + bb;
  digest[4] = digest[0] + b + cc;
  digest[0] = dd;
}

// ---------------------------------------------------------------------------------
// Combined Hash160 (RIPEMD160(SHA256(data)))
// ---------------------------------------------------------------------------------

inline void _GetHash160(__global ulong *x, __global ulong *y, uchar *h) {
  uint sha[8];
  uint rip[5];
  uint buf[16];
  
  // Prepare input for SHA256 (uncompressed public key)
  buf[0] = 0x04000000 | ((uint)(x[3] >> 40));
  buf[1] = (uint)(x[3] << 24) | (uint)(x[2] >> 40);
  buf[2] = (uint)(x[2] << 24) | (uint)(x[1] >> 40);
  buf[3] = (uint)(x[1] << 24) | (uint)(x[0] >> 40);
  buf[4] = (uint)(x[0] << 24) | (uint)(y[3] >> 40);
  buf[5] = (uint)(y[3] << 24) | (uint)(y[2] >> 40);
  buf[6] = (uint)(y[2] << 24) | (uint)(y[1] >> 40);
  buf[7] = (uint)(y[1] << 24) | (uint)(y[0] >> 40);
  buf[8] = (uint)(y[0] << 24) | 0x00800000;
  buf[9] = 0;
  buf[10] = 0;
  buf[11] = 0;
  buf[12] = 0;
  buf[13] = 0;
  buf[14] = 0;
  buf[15] = 65 * 8; // 65 bytes

  SHA256Initialize(sha);
  SHA256Transform(sha, buf);

  // Prepare for RIPEMD160
  for(int i = 0; i < 8; i++)
    buf[i] = sha[i];
  buf[8] = 0x80000000;
  for(int i = 9; i < 14; i++)
    buf[i] = 0;
  buf[14] = 32 * 8; // 32 bytes
  buf[15] = 0;

  rip[0] = IV[0];
  rip[1] = IV[1];
  rip[2] = IV[2];
  rip[3] = IV[3];
  rip[4] = IV[4];
  
  RIPEMD160Transform(rip, buf);

  // Output as bytes (little endian)
  for(int i = 0; i < 5; i++) {
    h[i*4+0] = (uchar)(rip[i]);
    h[i*4+1] = (uchar)(rip[i] >> 8);
    h[i*4+2] = (uchar)(rip[i] >> 16);
    h[i*4+3] = (uchar)(rip[i] >> 24);
  }
}

inline void _GetHash160Comp(__global ulong *x, uchar isOdd, uchar *h) {
  uint sha[8];
  uint rip[5];
  uint buf[16];
  
  // Prepare input for SHA256 (compressed public key)
  buf[0] = (isOdd ? 0x03000000 : 0x02000000) | ((uint)(x[3] >> 40));
  buf[1] = (uint)(x[3] << 24) | (uint)(x[2] >> 40);
  buf[2] = (uint)(x[2] << 24) | (uint)(x[1] >> 40);
  buf[3] = (uint)(x[1] << 24) | (uint)(x[0] >> 40);
  buf[4] = (uint)(x[0] << 24) | 0x00800000;
  for(int i = 5; i < 15; i++)
    buf[i] = 0;
  buf[15] = 33 * 8; // 33 bytes

  SHA256Initialize(sha);
  SHA256Transform(sha, buf);

  // Prepare for RIPEMD160
  for(int i = 0; i < 8; i++)
    buf[i] = sha[i];
  buf[8] = 0x80000000;
  for(int i = 9; i < 14; i++)
    buf[i] = 0;
  buf[14] = 32 * 8; // 32 bytes
  buf[15] = 0;

  rip[0] = IV[0];
  rip[1] = IV[1];
  rip[2] = IV[2];
  rip[3] = IV[3];
  rip[4] = IV[4];
  
  RIPEMD160Transform(rip, buf);

  // Output as bytes (little endian)
  for(int i = 0; i < 5; i++) {
    h[i*4+0] = (uchar)(rip[i]);
    h[i*4+1] = (uchar)(rip[i] >> 8);
    h[i*4+2] = (uchar)(rip[i] >> 16);
    h[i*4+3] = (uchar)(rip[i] >> 24);
  }
}
