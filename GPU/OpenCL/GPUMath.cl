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
// 256(+64) bits integer OpenCL library for SECPK1
// ---------------------------------------------------------------------------------

// We need 1 extra block for ModInv
#define NBBLOCK 5
#define BIFULLSIZE 40

// SECPK1 endomorphism constants
__constant ulong _beta[4] = { 0xC1396C28719501EEUL,0x9CF0497512F58995UL,0x6E64479EAC3434E9UL,0x7AE96A2B657C0710UL };
__constant ulong _beta2[4] = { 0x3EC693D68E6AFA40UL,0x630FB68AED0A766AUL,0x919BB86153CBCB16UL,0x851695D49A83F8EFUL };

#define HSIZE (GRP_SIZE / 2 - 1)

// 64bits lsb negative inverse of P (mod 2^64)
#define MM64 0xD838091DD2253531UL
// ---------------------------------------------------------------------------------------

#define _IsPositive(x) (((long)(x[4]))>=0L)
#define _IsNegative(x) (((long)(x[4]))<0L)
#define _IsEqual(a,b)  ((a[4] == b[4]) && (a[3] == b[3]) && (a[2] == b[2]) && (a[1] == b[1]) && (a[0] == b[0]))
#define _IsZero(a)     ((a[4] | a[3] | a[2] | a[1] | a[0]) == 0UL)
#define _IsOne(a)      ((a[4] == 0UL) && (a[3] == 0UL) && (a[2] == 0UL) && (a[1] == 0UL) && (a[0] == 1UL))

#define IDX get_local_id(0)

// OpenCL doesn't have inline assembly, so we use built-in functions
#define __sright128(a,b,n) ((a)>>(n))|((b)<<(64-(n)))
#define __sleft128(a,b,n) ((b)<<(n))|((a)>>(64-(n)))

// ---------------------------------------------------------------------------------------
// Add/Sub with carry using OpenCL built-ins

inline void uaddo(ulong *c, ulong a, ulong b, ulong *carry) {
  *c = a + b;
  *carry = (*c < a) ? 1 : 0;
}

inline void uaddc(ulong *c, ulong a, ulong b, ulong *carry) {
  ulong prev_carry = *carry;
  *c = a + b + prev_carry;
  *carry = (*c < a || (*c == a && prev_carry)) ? 1 : 0;
}

inline void usubo(ulong *c, ulong a, ulong b, ulong *borrow) {
  *c = a - b;
  *borrow = (*c > a) ? 1 : 0;
}

inline void usubc(ulong *c, ulong a, ulong b, ulong *borrow) {
  ulong prev_borrow = *borrow;
  ulong temp = a - b;
  *c = temp - prev_borrow;
  *borrow = (temp > a || *c > temp) ? 1 : 0;
}

// ---------------------------------------------------------------------------------------

#define AddP(r) { \
  ulong carry = 0; \
  uaddo(&r[0], r[0], 0xFFFFFFFEFFFFFC2FUL, &carry); \
  uaddc(&r[1], r[1], 0xFFFFFFFFFFFFFFFFUL, &carry); \
  uaddc(&r[2], r[2], 0xFFFFFFFFFFFFFFFFUL, &carry); \
  uaddc(&r[3], r[3], 0xFFFFFFFFFFFFFFFFUL, &carry); \
  uaddc(&r[4], r[4], 0UL, &carry); }

// ---------------------------------------------------------------------------------------

#define SubP(r) { \
  ulong borrow = 0; \
  usubo(&r[0], r[0], 0xFFFFFFFEFFFFFC2FUL, &borrow); \
  usubc(&r[1], r[1], 0xFFFFFFFFFFFFFFFFUL, &borrow); \
  usubc(&r[2], r[2], 0xFFFFFFFFFFFFFFFFUL, &borrow); \
  usubc(&r[3], r[3], 0xFFFFFFFFFFFFFFFFUL, &borrow); \
  usubc(&r[4], r[4], 0UL, &borrow); }

// ---------------------------------------------------------------------------------------

inline void Sub2(ulong *r, __global const ulong *a, __global const ulong *b) {
  ulong borrow = 0;
  usubo(&r[0], a[0], b[0], &borrow);
  usubc(&r[1], a[1], b[1], &borrow);
  usubc(&r[2], a[2], b[2], &borrow);
  usubc(&r[3], a[3], b[3], &borrow);
  usubc(&r[4], a[4], b[4], &borrow);
}

// ---------------------------------------------------------------------------------------

inline void Sub1(ulong *r, __global const ulong *a) {
  ulong borrow = 0;
  usubo(&r[0], r[0], a[0], &borrow);
  usubc(&r[1], r[1], a[1], &borrow);
  usubc(&r[2], r[2], a[2], &borrow);
  usubc(&r[3], r[3], a[3], &borrow);
  usubc(&r[4], r[4], a[4], &borrow);
}

// ---------------------------------------------------------------------------------------

inline void Add2(ulong *r, __global const ulong *a, __global const ulong *b) {
  ulong carry = 0;
  uaddo(&r[0], a[0], b[0], &carry);
  uaddc(&r[1], a[1], b[1], &carry);
  uaddc(&r[2], a[2], b[2], &carry);
  uaddc(&r[3], a[3], b[3], &carry);
  uaddc(&r[4], a[4], b[4], &carry);
}

// ---------------------------------------------------------------------------------------

inline void Add1(ulong *r, __global const ulong *a) {
  ulong carry = 0;
  uaddo(&r[0], r[0], a[0], &carry);
  uaddc(&r[1], r[1], a[1], &carry);
  uaddc(&r[2], r[2], a[2], &carry);
  uaddc(&r[3], r[3], a[3], &carry);
  uaddc(&r[4], r[4], a[4], &carry);
}

// ---------------------------------------------------------------------------------------
// Modular Multiplication using Montgomery multiplication
// ---------------------------------------------------------------------------------------

inline void _ModMult(ulong *r, __global const ulong *a, __constant const ulong *b) {
  
  ulong t[NBBLOCK];
  ulong c,h,carry;
  int i,j;

  // Initialize
  for(i=0;i<NBBLOCK;i++) t[i] = 0;

  for(i=0;i<4;i++) {

    c = 0;
    for(j=0;j<4;j++) {
      // t[j] += a[i]*b[j] + c
      ulong hi = mul_hi(a[i], b[j]);
      ulong lo = a[i] * b[j];
      uaddo(&t[j], t[j], lo, &carry);
      uaddc(&t[j], t[j], c, &carry);
      c = hi + carry;
    }
    t[4] = c;

    // Reduction step
    ulong m = t[0] * MM64;
    
    // Add m*P to t
    c = 0;
    ulong lo = m * 0xFFFFFFFEFFFFFC2FUL;
    uaddo(&h, t[0], lo, &carry);
    c = mul_hi(m, 0xFFFFFFFEFFFFFC2FUL) + carry;
    
    for(j=1;j<4;j++) {
      lo = m * 0xFFFFFFFFFFFFFFFFUL;
      uaddo(&t[j-1], t[j], lo, &carry);
      uaddc(&t[j-1], t[j-1], c, &carry);
      c = mul_hi(m, 0xFFFFFFFFFFFFFFFFUL) + carry;
    }
    
    uaddo(&t[3], t[4], c, &carry);
    t[4] = carry;
  }

  // Copy result
  for(i=0;i<4;i++) r[i] = t[i];
  r[4] = t[4];

  // Final reduction if needed
  if(_IsNegative(r) || 
     (r[4] == 0 && (r[3] > 0xFFFFFFFFFFFFFFFFUL || 
                    (r[3] == 0xFFFFFFFFFFFFFFFFUL && 
                     (r[2] > 0xFFFFFFFFFFFFFFFFUL ||
                      (r[2] == 0xFFFFFFFFFFFFFFFFUL && 
                       (r[1] > 0xFFFFFFFFFFFFFFFFUL ||
                        (r[1] == 0xFFFFFFFFFFFFFFFFUL && r[0] >= 0xFFFFFFFEFFFFFC2FUL)))))))) {
    SubP(r);
  }
}

// ---------------------------------------------------------------------------------------
// Modular Inverse using Extended Euclidean Algorithm
// ---------------------------------------------------------------------------------------

inline void _ModInv(ulong *r, __global const ulong *a) {
  // Simplified modular inverse - full implementation would be much longer
  // For now, placeholder - full implementation needed for production
  for(int i=0;i<5;i++) r[i] = a[i];
}

// ---------------------------------------------------------------------------------------
// Modular Square
// ---------------------------------------------------------------------------------------

inline void _ModSqr(ulong *rp, __global const ulong *a) {
  _ModMult(rp, a, (__constant ulong*)a);
}

// ---------------------------------------------------------------------------------------
// Modular Addition
// ---------------------------------------------------------------------------------------

inline void _ModAdd(ulong *r, __global const ulong *a, __global const ulong *b) {
  Add2(r, a, b);
  if(_IsNegative(r)) {
    AddP(r);
  } else {
    if(r[4] || r[3] > 0xFFFFFFFFFFFFFFFFUL || 
       (r[3] == 0xFFFFFFFFFFFFFFFFUL && 
        (r[2] > 0xFFFFFFFFFFFFFFFFUL ||
         (r[2] == 0xFFFFFFFFFFFFFFFFUL && 
          (r[1] > 0xFFFFFFFFFFFFFFFFUL ||
           (r[1] == 0xFFFFFFFFFFFFFFFFUL && r[0] >= 0xFFFFFFFEFFFFFC2FUL)))))) {
      SubP(r);
    }
  }
}

// ---------------------------------------------------------------------------------------
// Modular Subtraction
// ---------------------------------------------------------------------------------------

inline void _ModSub(ulong *r, __global const ulong *a, __global const ulong *b) {
  Sub2(r, a, b);
  if(_IsNegative(r)) {
    AddP(r);
  }
}

// ---------------------------------------------------------------------------------------
// Modular Negation
// ---------------------------------------------------------------------------------------

inline void _ModNeg(ulong *r, __global const ulong *a) {
  ulong zero[5] = {0,0,0,0,0};
  _ModSub(r, (__global ulong*)zero, a);
}
