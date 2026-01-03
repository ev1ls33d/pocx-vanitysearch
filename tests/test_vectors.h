/*
 * Test vectors for OpenCL kernel validation
 */

#ifndef TEST_VECTORS_H
#define TEST_VECTORS_H

#include <stdint.h>

// SHA-256 Test Vectors (from NIST)
struct SHA256TestVector {
    const char *input;
    const char *expected_hex;
};

const SHA256TestVector sha256_vectors[] = {
    {
        "",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    {
        "abc",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    },
    {
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
    }
};

// RIPEMD-160 Test Vectors
struct RIPEMD160TestVector {
    const char *input;
    const char *expected_hex;
};

const RIPEMD160TestVector ripemd160_vectors[] = {
    {
        "",
        "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    },
    {
        "abc",
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    },
    {
        "message digest",
        "5d0689ef49d2fae572b881b123a85ffa21595f36"
    }
};

// Base58 Test Vectors
struct Base58TestVector {
    const uint8_t input[25];
    int input_len;
    const char *expected;
};

const Base58TestVector base58_vectors[] = {
    {
        {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
        21,
        "1111111111111111111114oLvT2"
    },
    {
        {0x00, 0x62, 0xe9, 0x07, 0xb1, 0x5c, 0xbf, 0x27, 0xd5, 0x42,
         0x53, 0x99, 0xeb, 0xf6, 0xf0, 0xfb, 0x50, 0xeb, 0xb8, 0x8f, 0x18},
        21,
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    }
};

// secp256k1 Test Points
struct Secp256k1TestPoint {
    const char *private_key_hex;
    const char *public_key_x_hex;
    const char *public_key_y_hex;
    const char *compressed_hex;
};

const Secp256k1TestPoint secp256k1_vectors[] = {
    {
        "0000000000000000000000000000000000000000000000000000000000000001",
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8",
        "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    },
    {
        "0000000000000000000000000000000000000000000000000000000000000002",
        "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
        "1ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a",
        "02c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5"
    }
};

// POCX Address Test Vectors
struct POCXAddressTestVector {
    const char *private_key_hex;
    const char *expected_address;
};

const POCXAddressTestVector pocx_vectors[] = {
    // Add POCX-specific test vectors here
    // Format: private key -> expected POCX address
    {
        "0000000000000000000000000000000000000000000000000000000000000001",
        "pocx..." // Placeholder - actual address to be computed
    }
};

// Hash160 Test Vectors (for full address generation)
struct Hash160TestVector {
    const uint8_t pubkey[65]; // Uncompressed public key
    const char *expected_hash160_hex;
    const char *expected_address_p2pkh;
};

// Arithmetic Test Vectors (256-bit operations)
struct ArithmeticTestVector {
    const char *a_hex;
    const char *b_hex;
    const char *expected_sum_hex;
    const char *expected_product_hex;
};

const ArithmeticTestVector arithmetic_vectors[] = {
    {
        "0000000000000000000000000000000000000000000000000000000000000001",
        "0000000000000000000000000000000000000000000000000000000000000001",
        "0000000000000000000000000000000000000000000000000000000000000002",
        "0000000000000000000000000000000000000000000000000000000000000001"
    },
    {
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F", // secp256k1 P
        "0000000000000000000000000000000000000000000000000000000000000001",
        "0000000000000000000000000000000000000000000000000000000000000000", // Wraps to 0
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"
    }
};

#endif // TEST_VECTORS_H
