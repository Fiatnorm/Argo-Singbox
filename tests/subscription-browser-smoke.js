// Run with playwright-cli run-code --filename=tests/subscription-browser-smoke.js
// against a generated fixture served at the UUID path (not a production account).
async (page) => {
  const root = new URL('.', page.url()).href;
  const results = [];
  for (const language of ['zh', 'en']) {
    for (const [width, height] of [[1366, 768], [1280, 720], [1920, 1080], [375, 812], [360, 640]]) {
      await page.setViewportSize({ width, height });
      await page.goto(root + `index.${language}.html`);
      const bounds = await page.evaluate(() => {
        const files = document.querySelector('.files').getBoundingClientRect();
        return { bottom: files.bottom, right: files.right, width: innerWidth, height: innerHeight,
          pageWidth: document.documentElement.scrollWidth,
          pageHeight: document.documentElement.scrollHeight,
          rows: document.querySelectorAll('.files .row:not(.head)').length,
          lang: document.documentElement.lang,
          autoDate: document.querySelectorAll('.date')[1].textContent.trim() };
      });
      const availableHeight = height - (width <= 600 ? 64 : 0);
      if (bounds.bottom > availableHeight || bounds.right > width || bounds.pageWidth > width || bounds.pageHeight > height || bounds.rows !== 5 || bounds.lang !== language || bounds.autoDate === '—') {
        throw Error(JSON.stringify({ language, width, height, bounds }));
      }
      results.push(`${language} ${width}x${height}`);
    }
    await page.locator('[data-view="status"]').click();
    await page.locator('#status-card.ok').waitFor();
    if (!page.url().includes(`index.${language}.html#status`)) throw Error('language lost during navigation');
    if (await page.locator('.check').count() !== 8) throw Error('missing real checks');
    await page.route('**/raw', route => route.fulfill({ status: 404, body: 'missing' }));
    await page.locator('#recheck').click();
    await page.locator('#status-card.error').waitFor();
    await page.unroute('**/raw');
    await page.locator('#recheck').click();
    await page.locator('#status-card.ok').waitFor();
    await page.locator('[data-view="license"]').click();
    await page.waitForFunction(() => document.querySelector('#license-copy').textContent.includes('GENERAL PUBLIC'));
    const previous = await page.locator('#license-copy').textContent();
    await page.locator('#next').click();
    if ((await page.locator('#license-copy').textContent()) === previous) throw Error('license pagination failed');
    const fit = await page.locator('#license-copy').evaluate(e => e.scrollHeight <= e.clientHeight + 1);
    if (!fit) throw Error('license page requires scrolling');
    await page.locator('[data-view="subscriptions"]').click();
    const downloadEvent = page.waitForEvent('download');
    await page.locator('.file-download[data-file="raw"]').click();
    const download = await downloadEvent;
    if (download.suggestedFilename() !== 'raw.txt') throw Error('download filename mismatch');
    await download.delete();
  }
  return { result: 'SUBSCRIPTION_BROWSER_SMOKE_OK', viewports: results, checks: 'healthy, missing-file, recovery, license paging, raw download' };
}
