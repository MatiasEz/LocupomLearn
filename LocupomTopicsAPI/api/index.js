const { route } = require("../server");

module.exports = (req, res) => {
  Promise.resolve(route(req, res)).catch((error) => {
    if (!res.headersSent) {
      res.statusCode = 500;
      res.setHeader("Content-Type", "application/json; charset=utf-8");
    }

    res.end(JSON.stringify({
      error: error.message || "Unexpected server error"
    }));
  });
};
