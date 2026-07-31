const http = require("http");

const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 8020);

const server = http.createServer(async (req, res) => {
console.log("Request on server received :  " + req.method + " : " + req.url);

  /**
   * Health check endpoint `/health`
   * 
   * @path {HOST}:{PORT}/health
   * @return status : {200}
   * @return message : text : "If you see this message, your API server is all set , Welcome !"
   */
  if (req.url === "/" && req.method === "GET") {
    // set the status code, and content-type
    res.writeHead(200, { "Content-Type": "application/json" });
    // send the response data as text
    res.end("If you see this message, your API server is all set , Welcome !");
  } 


  /**
   * Health check endpoint `/health`
   * 
   * @path {HOST}:{PORT}/health
   * @return status {200:OK}
   * @return uptime : how long has been server up & running
   * @return timestamp : Time of response from server  
   */
  else if (req.url === "/health" && req.method === "GET") {
    const healthcheck = {
      uptime: process.uptime(),
      message: "OK",
      timestamp: Date.now(),
    };
    res.end(JSON.stringify(healthcheck));
  } 


  /**
   * Endpoint not implemented / invalid endpoint
   * @path {optional} `/`
   * @return {404} - Route is not implemented (Page Not Found)
   */
  else {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({ message: "Route is not implemented" })
    );
  }
});

server.listen(PORT, () => {
  console.log(`server started on: ${HOST} port: ${PORT}`);
});
