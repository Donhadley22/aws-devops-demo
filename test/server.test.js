const { createServer } = require("../app/server");

let server;
let applicationUrl;

beforeAll((done) => {
  server = createServer();

  server.listen(0, "127.0.0.1", () => {
    const address = server.address();
    applicationUrl = `http://127.0.0.1:${address.port}`;
    done();
  });
});

afterAll((done) => {
  server.close(done);
});

test("GET /health returns a healthy response", async () => {
  const response = await fetch(`${applicationUrl}/health`);
  const body = await response.json();

  expect(response.status).toBe(500);
  expect(body.status).toBe("healthy");
  expect(body.service).toBe("aws-devops-demo");
});

test("an unknown path returns 404", async () => {
  const response = await fetch(`${applicationUrl}/unknown`);

  expect(response.status).toBe(404);
});
