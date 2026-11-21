import angular from 'angular';
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';
import i18next from 'i18next';

describe('TagsController update messages', () => {
  let scope;
  let tag;
  let growl;
  let translations;

  beforeAll(async () => {
    Application.Controllers = angular.module('tagsControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/tags');
    const locale = yaml.load(fs.readFileSync(path.resolve(__dirname, '../../../config/locales/app.admin.en.yml'), 'utf8'));
    translations = i18next.createInstance();
    await translations.init({ lng: 'en', resources: { en: { translation: locale.en } } });
  });

  beforeEach(() => {
    scope = {};
    tag = { update: jest.fn() };
    growl = { success: jest.fn(), error: jest.fn() };
    angular.injector(['ng', 'tagsControllerTest']).get('$controller')('TagsController', {
      $scope: scope,
      tagsPromise: [],
      Tag: tag,
      dialogs: {},
      growl,
      _t: key => translations.t(key)
    });
  });

  test('translates the successful update toast using the English locale', () => {
    scope.saveTag({ name: 'Updated tag' }, 1);
    expect(tag.update).toHaveBeenCalledWith({ id: 1 }, { tag: { name: 'Updated tag' } }, expect.any(Function), expect.any(Function));
    tag.update.mock.calls[0][2]({ id: 1 });
    expect(growl.success).toHaveBeenCalledWith('Changes successfully saved.');
  });

  test('translates the failed update toast using the English locale', () => {
    scope.saveTag({ name: '' }, 1);
    tag.update.mock.calls[0][3]();
    expect(growl.error).toHaveBeenCalledWith('An error occurred when saving changes.');
    expect(growl.success).not.toHaveBeenCalled();
  });
});
