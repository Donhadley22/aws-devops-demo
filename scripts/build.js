const fs = require("node:fs");
const path = require("node:path");

const rootDirectory = path.resolve(__dirname, "..");
const outputDirectory = path.join(rootDirectory, "dist");
const outputAppDirectory = path.join(outputDirectory, "app");

fs.rmSync(outputDirectory, {
  recursive: true,
  force: true,
});

fs.mkdirSync(outputAppDirectory, {
  recursive: true,
});

fs.copyFileSync(
  path.join(rootDirectory, "app", "server.js"),
  path.join(outputAppDirectory, "server.js")
);

fs.copyFileSync(
  path.join(rootDirectory, "package.json"),
  path.join(outputDirectory, "package.json")
);

fs.copyFileSync(
  path.join(rootDirectory, "package-lock.json"),
  path.join(outputDirectory, "package-lock.json")
);

console.log("Application artifact created in the dist directory.");
