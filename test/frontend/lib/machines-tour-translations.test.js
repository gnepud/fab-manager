import angular from 'angular';
import '@uirouter/angularjs';
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

describe('admin machines tour translations', () => {
  let injector;
  let states;
  let translations;
  let refresh;
  let parts;

  beforeAll(() => {
    require('../../../app/frontend/src/javascript/router');
    Application.Services = angular.module('machinesTourTranslationsTest', [])
      .value('$rootElement', angular.element(document.body));
    require('../../../app/frontend/src/javascript/services/translations');
  });

  beforeEach(() => {
    parts = [];
    refresh = jest.fn(() => Promise.resolve());
    angular.module('machinesTourTranslationDependencies', [])
      .value('$translatePartialLoader', { addPart: part => parts.push(part) })
      .value('$translate', { refresh });
    injector = angular.injector(['ng', 'application.router', 'machinesTourTranslationsTest', 'machinesTourTranslationDependencies']);
    states = injector.get('$state');
    translations = injector.get('Translations');
  });

  test('a direct admin machines load includes every public translation used by its tour', async () => {
    for (const name of ['app', 'app.admin', 'app.admin.machines_list']) {
      const resolve = states.get(name).resolve;
      for (const key of Object.keys(resolve).filter(key => key.endsWith('Translations'))) {
        await injector.invoke(resolve[key]);
      }
    }
    const controller = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/controllers/admin/machines.js'), 'utf8');
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/machines/machines.html'), 'utf8');
    const keys = [...`${controller}\n${template}`.matchAll(/'(app\.public\.tour\.[^']+)'/g)].map(match => match[1]);
    const locale = yaml.load(fs.readFileSync(path.resolve(__dirname, '../../../config/locales/app.public.en.yml'), 'utf8')).en;
    expect(keys.length).toBeGreaterThan(0);
    for (const key of keys) {
      expect(key.split('.').reduce((value, segment) => value[segment], locale)).toEqual(expect.any(String));
    }
    expect(keys.filter(key => !parts.some(part => key.startsWith(`${part}.`)))).toEqual([]);
  });

  test('waits for the tour translations to refresh and propagates loading failures', async () => {
    const resolve = states.get('app.admin.machines_list').resolve.tourTranslations;
    expect(resolve).toBeDefined();
    const pending = Promise.resolve();
    refresh.mockReturnValueOnce(pending);
    expect(injector.invoke(resolve, null, { Translations: translations })).toBe(pending);
    expect(parts).toEqual(['app.public.tour']);
    refresh.mockRejectedValueOnce(new Error('Translation loading failed'));
    await expect(injector.invoke(resolve, null, { Translations: translations })).rejects.toThrow('Translation loading failed');
  });
});
