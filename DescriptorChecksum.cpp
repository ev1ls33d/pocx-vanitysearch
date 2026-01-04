/*
 * Bitcoin Core descriptor checksum implementation
 * Based on Bitcoin Core's descriptor checksum algorithm
 * https://github.com/bitcoin/bitcoin/blob/master/src/script/descriptor.cpp
 */

#include "DescriptorChecksum.h"
#include <string>

// Character set for descriptor checksums
static const char* CHECKSUM_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

// Generator coefficients for the checksum polynomial
static const uint64_t CHECKSUM_GENERATOR[] = {
    0xf5dee51989, 0xa9fdca3312, 0x1bab10e32d, 0x3706b1677a, 0x644d626ffd
};

// PolyMod computes the polynomial modulus for descriptor checksums
static uint64_t DescriptorPolyMod(uint64_t c, int val) {
    uint8_t c0 = c >> 35;
    c = ((c & 0x7ffffffff) << 5) ^ val;
    if (c0 & 1)  c ^= CHECKSUM_GENERATOR[0];
    if (c0 & 2)  c ^= CHECKSUM_GENERATOR[1];
    if (c0 & 4)  c ^= CHECKSUM_GENERATOR[2];
    if (c0 & 8)  c ^= CHECKSUM_GENERATOR[3];
    if (c0 & 16) c ^= CHECKSUM_GENERATOR[4];
    return c;
}

// Calculate the descriptor checksum for a given descriptor string
std::string DescriptorChecksum(const std::string& descriptor) {
    const std::string INPUT_CHARSET =
        "0123456789()[],'/*abcdefgh@:$%{}"
        "IJKLMNOPQRSTUVWXYZ&+-.;<=>?!^_|~"
        "ijklmnopqrstuvwxyzABCDEFGH`#\"\\ ";

    uint64_t c = 1;
    int cls = 0;
    int clscount = 0;

    for (unsigned char ch : descriptor) {
        auto pos = INPUT_CHARSET.find(ch);
        if (pos == std::string::npos) {
            return "";
        }
        c = DescriptorPolyMod(c, pos & 31);
        cls = cls * 3 + (pos >> 5);
        if (++clscount == 3) {
            c = DescriptorPolyMod(c, cls);
            cls = 0;
            clscount = 0;
        }
    }

    if (clscount > 0) {
        c = DescriptorPolyMod(c, cls);
    }

    // Shift further to determine the checksum
    for (int j = 0; j < 8; ++j) {
        c = DescriptorPolyMod(c, 0);
    }
    c ^= 1;

    // Convert the checksum to characters
    std::string ret(8, ' ');
    for (int j = 0; j < 8; ++j) {
        ret[j] = CHECKSUM_CHARSET[(c >> (5 * (7 - j))) & 31];
    }

    return ret;
}
