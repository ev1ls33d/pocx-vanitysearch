// 256-bit unsigned integer implementation for SECP256K1
// Ported from VanitySearch Int.cpp/Int.h

use std::fmt;
use std::ops::{Add, Sub, Mul};

/// 256-bit unsigned integer (5 x 64-bit limbs for Montgomery operations)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(C)]
pub struct U256 {
    pub limbs: [u64; 5], // Extra limb for Montgomery multiplication
}

impl U256 {
    pub const ZERO: U256 = U256 { limbs: [0; 5] };
    pub const ONE: U256 = U256 { limbs: [1, 0, 0, 0, 0] };
    
    /// SECP256K1 prime: FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
    pub const SECP256K1_P: U256 = U256 {
        limbs: [
            0xFFFFFFFEFFFFFC2F,
            0xFFFFFFFFFFFFFFFF,
            0xFFFFFFFFFFFFFFFF,
            0xFFFFFFFFFFFFFFFF,
            0,
        ],
    };

    /// SECP256K1 order (curve order)
    pub const SECP256K1_ORDER: U256 = U256 {
        limbs: [
            0xBFD25E8CD0364141,
            0xBAAEDCE6AF48A03B,
            0xFFFFFFFFFFFFFFFE,
            0xFFFFFFFFFFFFFFFF,
            0,
        ],
    };

    /// Beta constant for endomorphism optimization
    pub const BETA: U256 = U256 {
        limbs: [
            0x9CF0497512F58995,
            0x6E64479EAC3434E9,
            0x7AE96A2B657C0710,
            0xC1396C28719501EE,
            0,
        ],
    };

    /// Beta^2 constant for endomorphism optimization
    pub const BETA2: U256 = U256 {
        limbs: [
            0x630FB68AED0A766A,
            0x919BB86153CBCB16,
            0x851695D49A83F8EF,
            0x3EC693D68E6AFA40,
            0,
        ],
    };

    pub fn new() -> Self {
        Self::ZERO
    }

    pub fn from_u64(val: u64) -> Self {
        U256 {
            limbs: [val, 0, 0, 0, 0],
        }
    }

    pub fn from_limbs(limbs: [u64; 5]) -> Self {
        U256 { limbs }
    }

    pub fn from_hex(hex: &str) -> Result<Self, &'static str> {
        let hex = hex.trim_start_matches("0x");
        if hex.len() > 64 {
            return Err("Hex string too long for 256-bit integer");
        }

        let mut limbs = [0u64; 5];
        let mut hex_bytes = hex.as_bytes();
        
        // Process from right to left (least significant first)
        for i in 0..4 {
            if hex_bytes.is_empty() {
                break;
            }
            
            let chunk_len = std::cmp::min(16, hex_bytes.len());
            let start = hex_bytes.len() - chunk_len;
            let chunk = &hex_bytes[start..];
            
            limbs[i] = u64::from_str_radix(
                std::str::from_utf8(chunk).map_err(|_| "Invalid UTF-8")?,
                16
            ).map_err(|_| "Invalid hex digit")?;
            
            hex_bytes = &hex_bytes[..start];
        }

        Ok(U256 { limbs })
    }

    pub fn to_hex(&self) -> String {
        format!(
            "{:016x}{:016x}{:016x}{:016x}",
            self.limbs[3], self.limbs[2], self.limbs[1], self.limbs[0]
        )
    }

    pub fn is_zero(&self) -> bool {
        self.limbs.iter().all(|&x| x == 0)
    }

    pub fn is_one(&self) -> bool {
        self.limbs[0] == 1 && self.limbs[1..].iter().all(|&x| x == 0)
    }

    pub fn is_even(&self) -> bool {
        (self.limbs[0] & 1) == 0
    }

    pub fn is_odd(&self) -> bool {
        (self.limbs[0] & 1) == 1
    }

    /// Add with carry
    pub fn adc(&mut self, other: &U256) -> u64 {
        let mut carry = 0u64;
        for i in 0..5 {
            let (sum, c1) = self.limbs[i].overflowing_add(other.limbs[i]);
            let (sum, c2) = sum.overflowing_add(carry);
            self.limbs[i] = sum;
            carry = (c1 as u64) + (c2 as u64);
        }
        carry
    }

    /// Subtract with borrow
    pub fn sbb(&mut self, other: &U256) -> u64 {
        let mut borrow = 0u64;
        for i in 0..5 {
            let (diff, b1) = self.limbs[i].overflowing_sub(other.limbs[i]);
            let (diff, b2) = diff.overflowing_sub(borrow);
            self.limbs[i] = diff;
            borrow = (b1 as u64) + (b2 as u64);
        }
        borrow
    }

    /// Modular addition: (self + other) mod P
    pub fn mod_add(&self, other: &U256, modulus: &U256) -> U256 {
        let mut result = *self;
        result.adc(other);
        
        // Subtract modulus if result >= modulus
        let mut temp = result;
        let borrow = temp.sbb(modulus);
        if borrow == 0 {
            result = temp;
        }
        result
    }

    /// Modular subtraction: (self - other) mod P
    pub fn mod_sub(&self, other: &U256, modulus: &U256) -> U256 {
        let mut result = *self;
        let borrow = result.sbb(other);
        
        // Add modulus if we borrowed
        if borrow != 0 {
            result.adc(modulus);
        }
        result
    }

    /// Modular negation: -self mod P
    pub fn mod_neg(&self, modulus: &U256) -> U256 {
        if self.is_zero() {
            return *self;
        }
        modulus.mod_sub(self, modulus)
    }

    /// Left shift by n bits
    pub fn shl(&self, n: u32) -> U256 {
        if n == 0 {
            return *self;
        }
        if n >= 320 {
            return U256::ZERO;
        }

        let mut result = U256::ZERO;
        let limb_shift = (n / 64) as usize;
        let bit_shift = n % 64;

        if bit_shift == 0 {
            for i in limb_shift..5 {
                result.limbs[i] = self.limbs[i - limb_shift];
            }
        } else {
            let carry_shift = 64 - bit_shift;
            for i in limb_shift..5 {
                result.limbs[i] = self.limbs[i - limb_shift] << bit_shift;
                if i > limb_shift {
                    result.limbs[i] |= self.limbs[i - limb_shift - 1] >> carry_shift;
                }
            }
        }
        result
    }

    /// Right shift by n bits
    pub fn shr(&self, n: u32) -> U256 {
        if n == 0 {
            return *self;
        }
        if n >= 320 {
            return U256::ZERO;
        }

        let mut result = U256::ZERO;
        let limb_shift = (n / 64) as usize;
        let bit_shift = n % 64;

        if bit_shift == 0 {
            for i in 0..(5 - limb_shift) {
                result.limbs[i] = self.limbs[i + limb_shift];
            }
        } else {
            let carry_shift = 64 - bit_shift;
            for i in 0..(5 - limb_shift) {
                result.limbs[i] = self.limbs[i + limb_shift] >> bit_shift;
                if i + limb_shift + 1 < 5 {
                    result.limbs[i] |= self.limbs[i + limb_shift + 1] << carry_shift;
                }
            }
        }
        result
    }

    /// Compare: returns -1 if self < other, 0 if equal, 1 if self > other
    pub fn cmp(&self, other: &U256) -> i32 {
        for i in (0..5).rev() {
            if self.limbs[i] < other.limbs[i] {
                return -1;
            }
            if self.limbs[i] > other.limbs[i] {
                return 1;
            }
        }
        0
    }
}

impl fmt::Display for U256 {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "0x{}", self.to_hex())
    }
}

impl Add for U256 {
    type Output = U256;

    fn add(self, other: U256) -> U256 {
        let mut result = self;
        result.adc(&other);
        result
    }
}

impl Sub for U256 {
    type Output = U256;

    fn sub(self, other: U256) -> U256 {
        let mut result = self;
        result.sbb(&other);
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zero_one() {
        assert!(U256::ZERO.is_zero());
        assert!(U256::ONE.is_one());
        assert!(!U256::ONE.is_zero());
    }

    #[test]
    fn test_from_u64() {
        let val = U256::from_u64(42);
        assert_eq!(val.limbs[0], 42);
        assert_eq!(val.limbs[1], 0);
    }

    #[test]
    fn test_add() {
        let a = U256::from_u64(100);
        let b = U256::from_u64(200);
        let c = a + b;
        assert_eq!(c.limbs[0], 300);
    }

    #[test]
    fn test_sub() {
        let a = U256::from_u64(300);
        let b = U256::from_u64(100);
        let c = a - b;
        assert_eq!(c.limbs[0], 200);
    }

    #[test]
    fn test_hex_conversion() {
        let hex = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F";
        let val = U256::from_hex(hex).unwrap();
        assert_eq!(val, U256::SECP256K1_P);
    }
}
