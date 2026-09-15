const http = require("node:http");

function requestHandler(request, response) {
  if (request.url === "/health" && request.method === "GET") {
    response.writeHead(200, {
      "Content-Type": "application/json",
    });

    response.end(
      JSON.stringify({
        status: "healthy",
        service: "aws-devops-demo",
      })
    );

    return;
  }

  response.writeHead(404, {
    "Content-Type": "application/json",
  });

  response.end(
    JSON.stringify({
      error: "Not found",
    })
  );
}

function createServer() {
  return http.createServer(requestHandler);
}

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);

  createServer().listen(port, () => {
    console.log(`Application listening on port ${port}`);
  });
}

module.exports = { createServer };
