// Run with playwright-cli run-code --filename=tests/subscription-browser-smoke.js
// against a generated fixture served at the UUID path (not a production account).
async (page) => {
  const root = new URL('.', page.url()).href;
  const results = [];
  const foreignRequests=[];page.on('request',r=>{if(r.url().includes('www.w3.org'))foreignRequests.push(r.url())});
  for (const language of ['zh', 'en']) {
    for (const [width, height] of [[1366, 768], [1280, 720], [1920, 1080], [820, 900], [375, 812], [360, 640]]) {
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
      const typography=await page.evaluate(()=>({head:getComputedStyle(document.querySelector('.head')).fontSize,file:getComputedStyle(document.querySelector('.file')).fontSize,nav:getComputedStyle(document.querySelector('.nav-item')).fontSize,columns:document.querySelector('.head').children.length,labels:Array.from(document.querySelectorAll('.head [data-i18n]'),e=>e.textContent),icons:Array.from(document.querySelectorAll('.file svg'),e=>e.getBoundingClientRect().left),sizes:Array.from(document.querySelectorAll('[data-bytes]'),e=>[Number(e.dataset.bytes),e.textContent])}));
      if(typography.head!=='14px'||typography.file!=='16px'||typography.nav!=='12px'||typography.columns!==6)throw Error(JSON.stringify(typography));
      if(typography.labels.join(',')!=='File,Format,Modified,Size,Open,Download')throw Error('inconsistent headers');
      if(width>600&&Math.max(...typography.icons)-Math.min(...typography.icons)>1)throw Error('file icons not aligned');
      for(const [bytes,label] of typography.sizes)if(bytes>=1000?!label.endsWith('KB'):!label.endsWith('B'))throw Error('incorrect size unit');
      if(await page.locator('.page-header .chip').textContent()!=='5 formats'||await page.locator('.hero .button').textContent()!=='Open adaptive subscription ↗'||await page.locator('[data-adaptive="adaptive"]').textContent()!=='Adaptive')throw Error('mixed labels not updated');
      const contentWidth=await page.locator('main').evaluate(e=>e.getBoundingClientRect().width);
      if(contentWidth>960.5)throw Error('content exceeds R2Gate view width');
      if(width>900){
        const alignment=await page.evaluate(()=>{const row=document.querySelector('.row:not(.head)');const head=Array.from(document.querySelector('.head').children,e=>e.getBoundingClientRect());const center=e=>e.left+e.width/2;const names=Array.from(document.querySelectorAll('.file'),e=>{const range=document.createRange();range.selectNode(e.lastChild);return center(range.getBoundingClientRect())});const open=row.querySelector('.file-open').getBoundingClientRect();const download=row.querySelector('.file-download').getBoundingClientRect();return{fileCenter:center(head[0]),names,gaps:head.slice(0,4).slice(1).map((e,i)=>center(e)-center(head[i])),actionGap:download.left-open.right}});
        if(alignment.names.some(c=>Math.abs(c-alignment.fileCenter)>1)||Math.max(...alignment.gaps)-Math.min(...alignment.gaps)>1||alignment.actionGap>24||alignment.actionGap<0)throw Error(JSON.stringify(alignment));
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
    if (!(await page.locator('.check.error').textContent()).includes('HTTP 404')) throw Error('missing HTTP error reason');
    await page.unroute('**/raw');
    await page.route('**/sing-box',route=>route.fulfill({status:200,body:'{invalid'}));
    await page.locator('#recheck').click();
    await page.locator('#status-card.error').waitFor();
    if (!(await page.locator('.check.error').textContent()).includes('sing-box')) throw Error('invalid JSON not detected');
    await page.unroute('**/sing-box');
    await page.route('**/raw',route=>route.fulfill({status:200,body:''}));
    await page.locator('#recheck').click();
    await page.locator('#status-card.error').waitFor();
    await page.unroute('**/raw');
    await page.locator('#recheck').click();
    await page.locator('#status-card.ok').waitFor();
    if (await page.locator('.license').getAttribute('href') !== 'https://raw.githubusercontent.com/Fiatnorm/Argo-Singbox/refs/heads/main/LICENSE') throw Error('license redirect mismatch');
    await page.locator('[data-view="subscriptions"]').click();
    if (await page.locator('a.file').count()) throw Error('filename still navigates');
    if (await page.locator('.file-open').count() !== 5) throw Error('missing open buttons');
    const downloadEvent = page.waitForEvent('download');
    await page.locator('.file-download[data-file="raw"]').click();
    const download = await downloadEvent;
    if (download.suggestedFilename() !== 'raw.txt') throw Error('download filename mismatch');
    await download.delete();
  }
  if(foreignRequests.length)throw Error('unexpected external SVG request');
  return { result: 'SUBSCRIPTION_BROWSER_SMOKE_OK', viewports: results, checks: 'healthy, missing-file, recovery, license redirect, raw download' };
}
