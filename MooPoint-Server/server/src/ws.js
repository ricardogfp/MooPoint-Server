const WebSocket = require('ws');

function createWsServer({ server, logger, sessionParser }) {
  const wss = new WebSocket.Server({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname !== '/ws') {
      socket.destroy();
      return;
    }

    const adminUser = process.env.ADMIN_USERNAME;
    const adminPass = process.env.ADMIN_PASSWORD;
    const authEnabled = !!(adminUser && adminPass);

    if (!authEnabled) {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req);
      });
      return;
    }

    if (typeof sessionParser !== 'function') {
      socket.destroy();
      return;
    }

    sessionParser(req, {}, () => {
      if (!req.session?.user?.username) {
        socket.destroy();
        return;
      }
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req);
      });
    });
  });

  wss.on('connection', (ws) => {
    ws.on('error', (err) => {
      logger.error('WS client error', { err });
    });
  });

  function broadcast(obj) {
    const msg = JSON.stringify(obj);
    for (const client of wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(msg);
      }
    }
  }

  return { wss, broadcast };
}

module.exports = { createWsServer };
