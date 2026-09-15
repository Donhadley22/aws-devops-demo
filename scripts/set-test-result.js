const fs = require("node:fs");
const path = require("node:path");

const state = process.argv[2];
if (!new Set(["pass", "fail"]).has(state)) {
  console.error("Usage: node scripts/set-test-result.js <pass|fail>");
  process.exit(2);
}

const testPath = path.resolve(__dirname, "..", "test", "server.test.js");
const source = fs.readFileSync(testPath, "utf8");
const matcher = /expect\(response\.status\)\.toBe\((?:200|500)\);/g;
const matches = source.match(matcher) || [];

if (matches.length !== 1) {
  console.error(
    `Expected exactly one switchable health-status assertion; found ${matches.length}.`
  );
  process.exit(1);
}

const expectedStatus = state === "pass" ? 200 : 500;
const replacement = `expect(response.status).toBe(${expectedStatus});`;

if (matches[0] === replacement) {
  console.log(`Health test is already in the ${state} state.`);
  process.exit(0);
}

fs.writeFileSync(testPath, source.replace(matcher, replacement), "utf8");
console.log(`Health test set to ${state}; expected HTTP ${expectedStatus}.`);
