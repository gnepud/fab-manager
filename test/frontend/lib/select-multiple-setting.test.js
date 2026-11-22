import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('CAO file type settings', () => {
  let scope;
  let element;
  const update = jest.fn((_params, _data, onSuccess) => onSuccess());

  beforeAll(() => {
    Application.Directives = angular.module('selectMultipleSettingTest', [])
      .value('Setting', { update })
      .value('growl', { success: jest.fn() })
      .value('_t', key => key)
      .factory('$uibModal', ['$q', $q => ({ open: () => ({ result: $q.resolve('stl') }) })]);
    require('../../../app/frontend/src/javascript/directives/settings/select-multiple-setting');
  });

  beforeEach(() => update.mockClear());

  afterEach(() => {
    scope.$destroy();
    element.remove();
  });

  function render (name, value) {
    const injector = angular.injector(['ng', 'selectMultipleSettingTest']);
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/settings/select-multiple.html'), 'utf8');
    injector.get('$templateCache').put('/admin/settings/select-multiple.html', template);

    scope = injector.get('$rootScope').$new();
    scope.settings = { [name]: value };
    element = injector.get('$compile')(`<select-multiple-setting name="${name}" settings="settings"></select-multiple-setting>`)(scope);
    document.body.appendChild(element[0]);
    scope.$digest();

    const select = element[0].querySelector('select');
    const [remove, add, save] = element[0].querySelectorAll('button');
    return { select, remove, add, save };
  }

  test.each([
    ['allowed_cad_extensions', 'pdf stl', 'stl'],
    ['allowed_cad_mime_types', 'application/pdf model/stl', 'model/stl'],
    ['allowed_cad_extensions', 'pdf', '']
  ])('saves removal from %s (%s) without a selected row', (name, value, remaining) => {
    const { select, remove, save } = render(name, value);
    select.options[0].selected = true;
    select.dispatchEvent(new Event('change'));
    remove.click();

    expect(select.selectedOptions).toHaveLength(0);
    expect(update).not.toHaveBeenCalled();
    save.click();

    expect(update).toHaveBeenCalledWith({ name }, { value: remaining }, expect.any(Function), expect.any(Function));
    expect(scope.settings[name]).toBe(remaining);
    expect(save.disabled).toBe(true);
  });

  test('saves a newly added extension without a selected row', () => {
    const name = 'allowed_cad_extensions';
    const { select, add, save } = render(name, 'pdf');
    add.click();

    expect(select.selectedOptions).toHaveLength(0);
    save.click();

    expect(scope.settings[name]).toBe('pdf stl');
  });
});
