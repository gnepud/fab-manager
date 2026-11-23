import { execFileSync } from 'child_process';
import path from 'path';

describe('mobile Bootstrap tab CSS contract (not a layout test)', () => {
  let css;
  let mobile;

  beforeAll(() => {
    css = execFileSync(process.execPath, ['-e', `
      const path = require('node:path');
      const { pathToFileURL } = require('node:url');
      const sass = require('sass');
      process.stdout.write(sass.compileString('@import "bootstrap_and_overrides"; @import "app.nav";', {
        loadPaths: [path.resolve('app/frontend/src/stylesheets')],
        importers: [{
          findFileUrl: url => url.startsWith('~') ? pathToFileURL(path.resolve('node_modules', url.slice(1))) : null
        }],
        logger: sass.Logger.silent
      }).css);
    `], { cwd: path.resolve(__dirname, '../../..'), encoding: 'utf8' });
    mobile = css.match(/@media \(max-width: 767px\) \{\n  \.nav\.nav-tabs \{[\s\S]*?\n\}/)?.[0];
  });

  test('emits phone-only wrapping, shrinkable tabs, and breakable labels', () => {
    expect(mobile).toBeDefined();
    expect(mobile).toMatch(/\.nav\.nav-tabs \{\s*flex-wrap: wrap;/);
    expect(mobile).toMatch(/\.nav\.nav-tabs > li \{\s*flex: 1 1 12rem;\s*min-width: 0;/);
    expect(mobile).toMatch(/\.nav\.nav-tabs > li a \{\s*white-space: normal;\s*overflow-wrap: anywhere;/);
  });

  test('keeps the desktop flex rules unchanged', () => {
    const row = css.match(/^\.nav\.nav-tabs \{([^}]+)\}/m)?.[1];
    const tab = css.match(/^\.nav\.nav-tabs > li \{([^}]+)\}/m)?.[1];
    expect(row).toMatch(/display: flex;/);
    expect(row).not.toMatch(/flex-wrap:/);
    expect(tab).toMatch(/flex: 1;\s*width: auto;/);
  });

  test('does not override existing active-tab styling', () => {
    expect(css).toContain('.nav-tabs > li.active > a');
    expect(mobile).toBeDefined();
    expect(mobile).not.toMatch(/\b(?:background|border|color)[\w-]*\s*:/);
  });
});
