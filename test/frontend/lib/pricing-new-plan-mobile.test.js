import { execFileSync } from 'child_process';
import fs from 'fs';
import path from 'path';

describe('New plan phone button CSS contract (not a layout test)', () => {
  let css;
  let mobile;

  beforeAll(() => {
    css = execFileSync(process.execPath, ['-e', `
      const path = require('node:path');
      const { pathToFileURL } = require('node:url');
      const sass = require('sass');
      process.stdout.write(sass.compileString('@import "bootstrap_and_overrides"; @import "app.buttons"; @import "modules/base/fab-button";', {
        loadPaths: [path.resolve('app/frontend/src/stylesheets')],
        importers: [{
          findFileUrl: url => url.startsWith('~') ? pathToFileURL(path.resolve('node_modules', url.slice(1))) : null
        }],
        logger: sass.Logger.silent
      }).css);
    `], { cwd: path.resolve(__dirname, '../../..'), encoding: 'utf8' });
    mobile = css.match(/@media \(max-width: 767px\) \{\n  \.fab-button\.new-plan-button \{[\s\S]*?\n\}/)?.[0];
  });

  test('bounds and wraps only the New plan button on phones', () => {
    expect(mobile).toBeDefined();
    expect(mobile).toMatch(/max-width: 100%;/);
    expect(mobile).toMatch(/white-space: normal;/);
    expect(mobile).toMatch(/margin-bottom: 1rem;/);
    expect(mobile).toMatch(/\.fab-button\.new-plan-button > span \{\s*min-width: 0;\s*overflow-wrap: break-word;/);
    expect(css).not.toMatch(/^\.fab-button\.new-plan-button\b/m);
  });

  test('keeps the shared button nowrap rule and the existing template hook', () => {
    expect(css.match(/^\.fab-button \{([^}]+)\}/m)?.[1]).toMatch(/white-space: nowrap;/);
    const template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/pricing/subscriptions.html'), 'utf8');
    const button = template.querySelector('button.fab-button.new-plan-button');
    expect(button.getAttribute('ui-sref')).toBe('app.admin.plans.new');
    expect(button.querySelector('span[translate]')).not.toBeNull();
    expect(button.querySelector('i.fa-plus')).not.toBeNull();
  });
});
