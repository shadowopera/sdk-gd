// Serves a Web export of the tests and runs it in headless Chrome.
// Usage: node scripts/godot-web-test.mjs <build dir> [timeout seconds]
// Prints the console output of the page. Exits with 0 when the test runner reports that at least one test ran and
// all passed, 1 when it reports a failure, and 2 on a timeout.

import { spawn } from 'node:child_process';
import { createReadStream, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';

const [buildDir, timeoutArg] = process.argv.slice(2);
const timeoutMs = (Number(timeoutArg) || 120) * 1000;
const chromePath = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const types = {
    '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
};

// A build with thread support needs SharedArrayBuffer, which the browser enables only for a cross-origin isolated
// page. The headers do not affect a build without thread support.
const server = createServer((req, res) => {
    const path = normalize(join(buildDir, decodeURIComponent(new URL(req.url, 'http://x').pathname)));
    let stat;
    try {
        stat = statSync(path);
    } catch {
        res.writeHead(404).end();
        return;
    }
    if (stat.isDirectory()) {
        res.writeHead(404).end();
        return;
    }
    res.writeHead(200, {
        'Content-Type': types[extname(path)] || 'application/octet-stream',
        'Cache-Control': 'no-store',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    createReadStream(path).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const pageUrl = `http://127.0.0.1:${server.address().port}/index.html`;

const chrome = spawn(chromePath, [
    '--headless=new', '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check',
    `--user-data-dir=${process.env.TMPDIR || '/tmp'}/godot-web-test-chrome-${process.pid}`,
    '--enable-unsafe-swiftshader', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

const wsUrl = await new Promise((resolve, reject) => {
    let buf = '';
    chrome.stderr.on('data', d => {
        buf += d;
        const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
        if (m) resolve(m[1]);
    });
    chrome.on('exit', () => reject(new Error('Chrome exited early:\n' + buf)));
});

let exitCode = 2;
const finish = () => {
    chrome.kill();
    server.close();
    process.exit(exitCode);
};

const ws = new WebSocket(wsUrl);
let nextId = 1;
const pending = new Map();
const send = (method, params = {}, sessionId) => new Promise(resolve => {
    const id = nextId++;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params, sessionId }));
});

ws.onmessage = ev => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
        pending.get(msg.id)(msg.result);
        pending.delete(msg.id);
        return;
    }
    if (msg.method === 'Runtime.consoleAPICalled') {
        const text = msg.params.args.map(a => a.value ?? a.description ?? '').join(' ').trimEnd();
        console.log(text);
        // The summary of tests/test_runner.gd.
        const m = text.match(/^Total: (\d+), passed: (\d+), failed: (\d+)$/m);
        if (m) {
            exitCode = Number(m[1]) > 0 && Number(m[3]) === 0 ? 0 : 1;
            // Let the remaining output arrive.
            setTimeout(finish, 500);
        }
    } else if (msg.method === 'Runtime.exceptionThrown') {
        console.log('[page exception]', msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text);
    }
};

ws.onopen = async () => {
    const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
    await send('Runtime.enable', {}, sessionId);
    await send('Page.navigate', { url: pageUrl }, sessionId);
    setTimeout(() => {
        console.log(`[harness] timeout after ${timeoutMs / 1000}s`);
        finish();
    }, timeoutMs);
};
