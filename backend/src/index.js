const express = require('express');

const PORT = process.env.PORT || 8080;
const app = express();

// Middleware for logging
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Hello endpoint with pod info
app.get('/api/hello', (req, res) => {
  res.json({
    message: 'Hello from Backend!',
    hostname: process.env.HOSTNAME || require('os').hostname(),
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend listening on port ${PORT}`);
});
