// Photographs /og into public/cleen-og.png (1200×630, drawn at 2×).
//   npx next build && npx next start -p 3490 &
//   CHROME=/path/to/chrome-headless-shell node scripts/og.mjs
import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
import { setTimeout as wait } from "node:timers/promises";

const chrome = process.env.CHROME;
if (!chrome) throw new Error("Set CHROME to a Chrome or chrome-headless-shell binary.");
const url = process.env.OG_URL ?? "http://127.0.0.1:3490/og";
const port = 9334;
const browser = spawn(chrome, ["--headless", `--remote-debugging-port=${port}`, "--hide-scrollbars", `--user-data-dir=/tmp/cleen-og-${process.pid}`, "about:blank"], { stdio: "ignore" });

try {
  let targets;
  for (let attempt = 0; attempt < 50 && !targets; attempt++) {
    await wait(100);
    targets = await fetch(`http://127.0.0.1:${port}/json`).then((r) => r.json()).catch(() => undefined);
  }
  const socket = new WebSocket(targets.find((t) => t.type === "page").webSocketDebuggerUrl);
  await new Promise((resolve) => (socket.onopen = resolve));
  let id = 0;
  const pending = new Map();
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    pending.get(message.id)?.(message.result);
    pending.delete(message.id);
  };
  const send = (method, params = {}) => new Promise((resolve) => {
    pending.set(++id, resolve);
    socket.send(JSON.stringify({ id, method, params }));
  });
  await send("Emulation.setDeviceMetricsOverride", { width: 1200, height: 630, deviceScaleFactor: 2, mobile: false });
  await send("Page.navigate", { url });
  // The replica measures itself and lays out after the first paint.
  await wait(2500);
  const shot = await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width: 1200, height: 630, scale: 1 } });
  writeFileSync(new URL("../public/cleen-og.png", import.meta.url), Buffer.from(shot.data, "base64"));
  socket.close();
} finally {
  browser.kill();
}
