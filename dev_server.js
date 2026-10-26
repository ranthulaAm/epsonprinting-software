const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const PREVIEW_DIR = path.join(__dirname, 'web_preview');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

// Connected live-reload clients (SSE)
const clients = new Set();

// Injected live-reload client script
const LIVE_RELOAD_SCRIPT = `
<!-- [Live-Reload Dev Server Injected] -->
<script>
  (function() {
    const es = new EventSource('/livereload-events');
    es.onmessage = function(e) {
      if (e.data === 'reload') {
        console.log('[Dev Server] File changed. Live reloading...');
        window.location.reload();
      }
    };
    es.onerror = function() {
      // Reconnect automatically if dev server restarts
      setTimeout(() => new EventSource('/livereload-events'), 1500);
    };
  })();
</script>
`;

const server = http.createServer((req, res) => {
  // SSE Live-Reload Endpoint
  if (req.url === '/livereload-events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });
    res.write('data: connected\n\n');
    clients.add(res);

    req.on('close', () => {
      clients.delete(res);
    });
    return;
  }

  // Clean request path
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/' || reqPath === '') {
    reqPath = '/index.html';
  }

  const filePath = path.join(PREVIEW_DIR, reqPath);

  // Security check: ensure path is within preview dir
  if (!filePath.startsWith(PREVIEW_DIR)) {
    res.writeHead(403);
    res.end('403 Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (readErr, content) => {
      if (readErr) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('500 Internal Server Error');
        return;
      }

      // Inject live reload script into HTML
      if (ext === '.html') {
        let html = content.toString('utf-8');
        if (html.includes('</body>')) {
          html = html.replace('</body>', LIVE_RELOAD_SCRIPT + '</body>');
        } else {
          html += LIVE_RELOAD_SCRIPT;
        }
        res.writeHead(200, {
          'Content-Type': contentType,
          'Cache-Control': 'no-cache, no-store, must-revalidate'
        });
        res.end(html);
        return;
      }

      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-cache, no-store, must-revalidate'
      });
      res.end(content);
    });
  });
});

// Broadcast reload to all active browser tabs
let reloadDebounceTimer = null;
function triggerReload(changedFile) {
  clearTimeout(reloadDebounceTimer);
  reloadDebounceTimer = setTimeout(() => {
    const relativeName = path.relative(__dirname, changedFile);
    console.log(`\x1b[36m[DEV WATCHER]\x1b[0m Change detected in \x1b[33m${relativeName}\x1b[0m -> Reloading ${clients.size} browser tab(s)...`);
    for (const client of clients) {
      client.write('data: reload\n\n');
    }
  }, 100);
}

// Watch web_preview directory recursively
function setupWatchers() {
  if (fs.existsSync(PREVIEW_DIR)) {
    fs.watch(PREVIEW_DIR, { recursive: true }, (eventType, filename) => {
      if (filename) {
        triggerReload(path.join(PREVIEW_DIR, filename));
      }
    });
  }
}

server.listen(PORT, () => {
  console.log(`\n\x1b[32m✔ Live Auto-Reload Dev Server active at:\x1b[0m`);
  console.log(`  ➜ Local:   \x1b[36mhttp://localhost:${PORT}/\x1b[0m`);
  console.log(`  ➜ Watching: \x1b[33mweb_preview/\x1b[0m for changes (auto-reloading on save)\n`);
  setupWatchers();
});
