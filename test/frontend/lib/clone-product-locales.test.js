const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const localesDirectory = path.resolve(__dirname, '../../../config/locales');
const localeFiles = fs.readdirSync(localesDirectory)
  .filter(file => /^app\.admin\..+\.yml$/.test(file) && file !== 'app.admin.zu.yml');

describe('clone product SKU labels', () => {
  test.each(localeFiles)('%s matches the product form', file => {
    const translations = yaml.load(fs.readFileSync(path.join(localesDirectory, file), 'utf8'));
    const store = Object.values(translations)[0].app.admin.store;

    expect(store.product_form.sku).toEqual(expect.any(String));
    expect(store.product_form.sku.length).toBeGreaterThan(0);
    expect(store.clone_product_modal.sku).toBe(store.product_form.sku);
  });
});
