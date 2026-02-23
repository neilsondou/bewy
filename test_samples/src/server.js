const express = require('express');
const cors = require('cors');

class ApiServer {
  constructor(port = 3000) {
    this.app = express();
    this.port = port;
    this.routes = new Map();
    this.middleware();
  }

  middleware() {
    this.app.use(cors());
    this.app.use(express.json());
    this.app.use((req, res, next) => {
      console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
      next();
    });
  }

  get(path, handler) {
    this.routes.set(`GET:${path}`, handler);
    this.app.get(path, async (req, res) => {
      try {
        const result = await handler(req);
        res.json({ success: true, data: result });
      } catch (err) {
        res.status(500).json({ success: false, error: err.message });
      }
    });
  }

  post(path, handler) {
    this.routes.set(`POST:${path}`, handler);
    this.app.post(path, async (req, res) => {
      try {
        const result = await handler(req);
        res.status(201).json({ success: true, data: result });
      } catch (err) {
        res.status(400).json({ success: false, error: err.message });
      }
    });
  }

  start() {
    return new Promise((resolve) => {
      this.server = this.app.listen(this.port, () => {
        console.log(`Server running on port ${this.port}`);
        resolve(this.server);
      });
    });
  }
}

// Usage
const api = new ApiServer(8080);
const items = [];

api.get('/items', () => items);
api.post('/items', (req) => {
  const { name, value } = req.body;
  if (!name) throw new Error('Name is required');
  const item = { id: items.length + 1, name, value, createdAt: new Date() };
  items.push(item);
  return item;
});

api.start();
