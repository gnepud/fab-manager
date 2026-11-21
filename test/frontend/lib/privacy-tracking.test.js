import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('privacy tracking settings', () => {
  const templatePath = path.resolve(__dirname, '../../../app/frontend/templates/admin/settings');
  const update = jest.fn();
  let injector, scope;

  beforeAll(() => {
    Application.Directives = angular.module('privacyTrackingTest', [])
      .value('Setting', { update })
      .value('growl', { success: jest.fn() })
      .value('_t', key => key);
    require('../../../app/frontend/src/javascript/directives/settings/text-setting');
    injector = angular.injector(['ng', 'privacyTrackingTest']);
    injector.get('$templateCache').put('/admin/settings/text.html', fs.readFileSync(path.join(templatePath, 'text.html'), 'utf8'));
  });

  afterEach(() => {
    scope.$destroy();
    update.mockClear();
  });

  function clearSetting (page, name, value) {
    const template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.join(templatePath, page), 'utf8');
    const field = template.querySelector(`text-setting[name="${name}"]`);
    scope = injector.get('$rootScope').$new();
    scope.allSettings = { [name]: value };
    injector.get('$compile')(field)(scope);
    scope.$digest();

    const input = field.querySelector('input');
    expect(input.value).toBe(value);
    input.value = '';
    input.dispatchEvent(new Event('input'));
    return field.querySelector('button');
  }

  test.each([
    ['tracking_id', 'G-TEST123456'],
    ['facebook_app_id', '123456789'],
    ['twitter_analytics', '@example']
  ])('can save an empty %s', (name, value) => {
    const save = clearSetting('privacy.html', name, value);

    expect(save.disabled).toBe(false);
    save.click();
    expect(update).toHaveBeenCalledWith({ name }, { value: '' }, expect.any(Function), expect.any(Function));
  });

  test('still requires a Fab Lab name', () => {
    const save = clearSetting('general.html', 'fablab_name', 'Fab Lab');

    expect(save.disabled).toBe(true);
  });
});

describe('Google Analytics activation', () => {
  test('does not load Google Analytics without a tracking ID', () => {
    const source = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/lib/gtm.js'), 'utf8');
    const referenceScript = document.createElement('script');
    document.head.appendChild(referenceScript);

    try {
      window.eval(source);
      window.GTM.enableAnalytics('');
      expect(document.querySelector('script[src*="googletagmanager.com"]')).toBeNull();
    } finally {
      referenceScript.remove();
      document.querySelector('script[src*="googletagmanager.com"]')?.remove();
      delete window.dataLayer;
      delete window.GTM;
    }
  });
});
