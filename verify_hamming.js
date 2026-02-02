// Standalone verification for hammingDistance logical
// Copy pasted from the implementation in Filter.coffee

// Implementation under test
function hammingDistance(h1, h2) {
    if (h1.length !== h2.length) return 64;
    let dist = 0;
    for (let i = 0; i < h1.length; i++) {
        const v1 = parseInt(h1[i], 16);
        const v2 = parseInt(h2[i], 16);
        let x = v1 ^ v2;
        while (x) {
            if (x & 1) dist++;
            x >>= 1;
        }
    }
    return dist;
}

// Tests
console.log("Running Hamming Distance Tests...");

const tests = [
    { h1: "0000", h2: "0000", expected: 0, desc: "Identical" },
    { h1: "0000", h2: "0001", expected: 1, desc: "1 bit diff (last bit)" },
    { h1: "ffff", h2: "0000", expected: 16, desc: "Max diff (4 chars * 4 bits)" },
    { h1: "8000", h2: "0000", expected: 1, desc: "1 bit diff (first bit)" },
    { h1: "f", h2: "7", expected: 1, desc: "1111 vs 0111" }
];

let failed = 0;
for (const t of tests) {
    const res = hammingDistance(t.h1, t.h2);
    if (res !== t.expected) {
        console.error(`FAILED: ${t.desc}. Expected ${t.expected}, got ${res}`);
        failed++;
    } else {
        console.log(`PASS: ${t.desc}`);
    }
}

if (failed === 0) {
    console.log("All tests passed!");
    process.exit(0);
} else {
    console.error(`${failed} tests failed.`);
    process.exit(1);
}
