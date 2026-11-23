const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const sass = require('sass');

const css = sass.compileString('@import "bootstrap_and_overrides"; @import "app.nav";', {
  loadPaths: [path.resolve(__dirname, '../../../app/frontend/src/stylesheets')],
  importers: [{
    findFileUrl: url => url.startsWith('~') ? pathToFileURL(path.resolve(__dirname, '../../../node_modules', url.slice(1))) : null
  }],
  logger: sass.Logger.silent
}).css;
const mobile = css.match(/@media \(max-width: 767px\) \{\n  \.nav\.nav-tabs \{[\s\S]*?\n\}/)?.[0];

assert.ok(mobile, 'phone-only tab rules must be emitted');
assert.match(mobile, /\.nav\.nav-tabs \{\s*flex-wrap: wrap;/);
assert.match(mobile, /\.nav\.nav-tabs > li \{\s*flex: 1 1 12rem;\s*min-width: 0;/);
assert.match(mobile, /\.nav\.nav-tabs > li a \{\s*white-space: normal;\s*overflow-wrap: anywhere;/);
console.log('PASS: phone-only wrapping, shrinkable tabs, and breakable labels');

const row = css.match(/^\.nav\.nav-tabs \{([^}]+)\}/m)?.[1];
const tab = css.match(/^\.nav\.nav-tabs > li \{([^}]+)\}/m)?.[1];
assert.match(row, /display: flex;/);
assert.doesNotMatch(row, /flex-wrap:/);
assert.match(tab, /flex: 1;\s*width: auto;/);
console.log('PASS: desktop flex rules unchanged');

assert.ok(css.includes('.nav-tabs > li.active > a'));
assert.doesNotMatch(mobile, /\b(?:background|border|color)[\w-]*\s*:/);
console.log('PASS: existing active-tab styling is not overridden');
