import { test, expect } from '@playwright/test';
import assert from 'node:assert';
import { once } from 'node:events';
import { createServer } from 'node:http';

import { clearEnv, restoreEnv } from '../../__tests__/export/export-side-effects';
import { getRouterE2ERoot } from '../../__tests__/utils';
import { createExpoServe, executeExpoAsync } from '../../utils/expo';
import { pageCollectErrors } from '../page';

declare global {
  interface Window {
    safeAreaServerNodes: Map<string, Element>;
  }
}

const projectRoot = getRouterE2ERoot();
const outputDir = 'dist-safe-area-streaming';
test.describe.configure({ mode: 'serial' });
const expoServe = createExpoServe({ cwd: projectRoot, env: { NODE_ENV: 'production' } });
let earlyBootstrapUrl: string;

// Exercise hydration before the response ends. Production's deferred script normally waits for EOF.
// This fixture must have one startup script; changing the order of multiple scripts would be unsafe.
const earlyBootstrapServer = createServer(async (request, response) => {
  try {
    const upstream = await fetch(new URL(request.url!, expoServe.url));
    response.statusCode = upstream.status;
    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    response.setHeader('content-type', contentType);
    assert(upstream.body);
    let shellFlushed = !contentType.includes('text/html');
    let shell = Buffer.alloc(0);
    for await (const chunk of upstream.body) {
      if (shellFlushed) {
        response.write(chunk);
        continue;
      }
      shell = Buffer.concat([shell, chunk]);
      const html = shell.toString();
      // Network chunks can split tags. Expo's hydration flag follows the startup script.
      if (!html.includes('globalThis.__EXPO_ROUTER_HYDRATE__=true;</script>')) continue;
      assert.equal([...html.matchAll(/<script\b[^>]*\bsrc=/g)].length, 1);
      assert(html.includes('<script defer="" src='));
      response.write(html.replace('<script defer="" src=', '<script async="" src='));
      shellFlushed = true;
    }
    assert(shellFlushed, 'Expected Expo hydration flag in the streamed shell');
    response.end();
  } catch (error) {
    response.destroy(error instanceof Error ? error : new Error(String(error)));
  }
});

test.beforeAll(async () => {
  clearEnv();
  await executeExpoAsync(projectRoot, ['export', '-p', 'web', '--output-dir', outputDir], {
    env: {
      NODE_ENV: 'production',
      EXPO_USE_STATIC: 'server',
      E2E_ROUTER_SRC: 'safe-area-streaming',
      E2E_ROUTER_ASYNC: 'false',
    },
  });
  await expoServe.startAsync([outputDir]);
  earlyBootstrapServer.listen(0, '127.0.0.1');
  await once(earlyBootstrapServer, 'listening');
  const address = earlyBootstrapServer.address();
  assert(address && typeof address !== 'string');
  earlyBootstrapUrl = `http://127.0.0.1:${address.port}`;
});

test.afterAll(async () => {
  if (earlyBootstrapServer.listening) {
    earlyBootstrapServer.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      earlyBootstrapServer.close((error) => (error ? reject(error) : resolve()))
    );
  }
  await expoServe.stopAsync();
  restoreEnv();
});

for (const path of ['/', '/stack']) {
  test(`retains streamed nodes during early hydration and resize: ${path}`, async ({ page }) => {
    const errors = pageCollectErrors(page);
    await page.addInitScript(() => {
      window.safeAreaServerNodes = new Map();
      new MutationObserver((records) => {
        for (const record of records) {
          for (const node of record.addedNodes) {
            if (!(node instanceof Element)) continue;
            const elements = [node, ...node.querySelectorAll('#shell, #first, #second')];
            for (const element of elements) {
              if (['shell', 'first', 'second'].includes(element.id)) {
                if (!window.safeAreaServerNodes.has(element.id)) {
                  window.safeAreaServerNodes.set(element.id, element);
                }
              }
            }
          }
        }
      }).observe(document, { childList: true, subtree: true });
    });

    await page.goto(new URL(path, earlyBootstrapUrl).href, { waitUntil: 'commit' });
    await page.waitForFunction(() => document.documentElement.dataset.safeAreaHydrated === 'true');
    await expect(page.locator('#first-fallback')).toBeVisible();
    await expect(page.locator('#second-fallback')).toBeVisible();
    await page.evaluate(() => document.querySelector<HTMLButtonElement>('#shell')!.click());
    await expect(page.locator('#shell')).toHaveAttribute('data-clicked', 'true');
    await page.setViewportSize({ width: 900, height: 700 });

    await expect(page.locator('#root #first')).toBeVisible({ timeout: 15000 });
    await expect(page.locator('#root #second')).toBeVisible({ timeout: 15000 });
    await page.waitForLoadState('load');
    for (const id of ['shell', 'first', 'second']) {
      expect(
        await page.evaluate((id) => {
          const node = window.safeAreaServerNodes.get(id);
          return node?.isConnected && node === document.querySelector(`#root #${id}`);
        }, id)
      ).toBe(true);
    }
    expect(errors.all).toEqual([]);
  });
}
