// Run with playwright-cli run-code --filename=tests/subscription-browser-smoke.js
// against a generated fixture served at the UUID path (not a production account).
async (page) => {
  const root = new URL('.', page.url()).href;
  const results = [];
  const foreignRequests=[];page.on('request',r=>{if(r.url().includes('www.w3.org'))foreignRequests.push(r.url())});
  for (const language of ['zh', 'en']) {
    for (const [width, height] of [[1366, 768], [1280, 720], [1920, 1080], [820, 900], [375, 812], [360, 640]]) {
      for(const theme of ['light','dark']){
      await page.setViewportSize({ width, height });
      await page.goto(root + `index.${language}.html`);
      if(await page.evaluate(()=>document.documentElement.dataset.theme||'light')!==theme)await page.locator('#theme-toggle').click();
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
      if(typography.head!=='14px'||typography.file!=='16px'||typography.nav!=='12px'||typography.columns!==7)throw Error(JSON.stringify(typography));
      if(typography.labels.join(',')!=='File,Format,Modified,Size,Copy,Open,Download')throw Error('inconsistent headers');
      if(width>600&&Math.max(...typography.icons)-Math.min(...typography.icons)>1)throw Error('file icons not aligned');
      for(const [bytes,label] of typography.sizes)if(bytes>=1000?!label.endsWith('KB'):!label.endsWith('B'))throw Error('incorrect size unit');
      if(await page.locator('.page-header .chip').textContent()!=='5 formats'||await page.locator('.hero .button').textContent()!=='Open adaptive subscription ↗'||await page.locator('[data-adaptive="adaptive"]').textContent()!=='Adaptive')throw Error('mixed labels not updated');
      const contentWidth=await page.locator('main').evaluate(e=>e.getBoundingClientRect().width);
      if(contentWidth>1120.5)throw Error('content exceeds R2Gate view width');
      if(width>1100){
        const alignment=await page.evaluate(()=>{const row=document.querySelector('.row:not(.head)');const head=Array.from(document.querySelector('.head').children,e=>e.getBoundingClientRect());const center=e=>e.left+e.width/2;const names=Array.from(document.querySelectorAll('.file'),e=>{const range=document.createRange();range.selectNode(e.lastChild);return (e.querySelector(".file-icon").getBoundingClientRect().left+range.getBoundingClientRect().right)/2});const open=row.querySelector('.file-open').getBoundingClientRect();const download=row.querySelector('.file-download').getBoundingClientRect();return{fileCenter:center(head[0]),names,gaps:head.slice(0,4).slice(1).map((e,i)=>center(e)-center(head[i])-(i===0?14:0)),actionGap:download.left-open.right}});
        if(Math.abs(alignment.names.reduce((a,b)=>a+b,0)/alignment.names.length-alignment.fileCenter)>5||Math.max(...alignment.gaps)-Math.min(...alignment.gaps)>1||alignment.actionGap>24||alignment.actionGap<0)throw Error(JSON.stringify(alignment));
      }
      if(width>600){
        const row=page.locator('.row:not(.head)').first();
        await row.hover();
        await page.waitForTimeout(200);
        const slot=await row.evaluate(e=>{const file=e.querySelector('.file');const box=e.querySelector('.file-icon');const cell=file.parentElement.getBoundingClientRect();const group=file.getBoundingClientRect();return{background:getComputedStyle(box).backgroundColor,rowBackground:getComputedStyle(e).backgroundColor,gap:getComputedStyle(file).columnGap,centerOffset:Math.abs(group.left+group.width/2-cell.left-cell.width/2)}});
        if(slot.background===slot.rowBackground||slot.gap!=='8px'||slot.centerOffset>1)throw Error(JSON.stringify(slot));
      }
      const actions=await page.locator('.row:not(.head)').first().locator('.download').evaluateAll(items=>items.map(e=>{const r=e.getBoundingClientRect();return [r.width,r.height]}));
      if(actions.length!==3||actions.some(a=>Math.abs(a[0]-actions[0][0])>1||Math.abs(a[1]-actions[0][1])>1))throw Error('action sizes differ: '+JSON.stringify(actions));
      if(await page.locator('#theme-toggle').getAttribute('aria-pressed')!==String(theme==='dark'))throw Error('theme control state mismatch');
      results.push(`${language} ${theme} ${width}x${height}`);
      }

    }
    await page.setViewportSize({width:1366,height:768});
    await page.reload();
    await page.context().grantPermissions(['clipboard-read','clipboard-write']);
    await page.locator('.file-copy[data-file="raw"]').click();
    if(await page.evaluate(()=>navigator.clipboard.readText())!==root+'raw')throw Error('actual clipboard copy mismatch');
    if(await page.evaluate(()=>document.documentElement.dataset.theme)!=='dark')throw Error('theme not persisted');
    await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>window.copiedLink=text}}));
    for(const name of ['raw','auto','base64','clash','sing-box']){
      await page.locator(`.file-copy[data-file="${name}"]`).click();
      await page.waitForFunction(expected=>window.copiedLink===expected,root+name);
      if(await page.locator('#copy-feedback').textContent()!==`Copied · ${name}`)throw Error('copy feedback mismatch');
    }
    await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw Error('Denied')}}}));
    await page.locator('.file-copy').first().click();
    await page.locator('#copy-feedback.error').waitFor();
    if(await page.locator('#copy-feedback').textContent()!=='Copy failed')throw Error('clipboard rejection not reported');
    await page.evaluate(()=>{Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined});document.execCommand=()=>{window.fallbackLink=document.querySelector('textarea').value;return true}});
    await page.locator('.file-copy').first().click();
    if(await page.evaluate(()=>window.fallbackLink)!==root+'raw')throw Error('fallback copied wrong URL');
    await page.evaluate(()=>document.execCommand=()=>false);
    await page.locator('.file-copy').first().click();
    await page.locator('#copy-feedback.error').waitFor();
    if(await page.locator('textarea').count())throw Error('fallback textarea leaked');
    await page.reload();
    await page.locator('[data-view="status"]').click();
    await page.locator('#status-card.ok').waitFor();
    if(await page.evaluate(()=>getComputedStyle(document.documentElement).colorScheme)!=='dark')throw Error('Status theme differs');
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
