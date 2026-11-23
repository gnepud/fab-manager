import angular from 'angular';
import '@uirouter/angularjs';
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

const tours = [
  ['app.public.home', 'home.js', 'home.html', 'app.public.tour'],
  ['app.public.machines_list', 'machines.js.erb', 'machines/index.html', 'app.public.tour'],
  ['app.admin.machines_list', 'admin/machines.js', 'admin/machines/machines.html', 'app.public.tour'],
  ['app.public.spaces_list', 'spaces.js.erb', 'spaces/index.html', 'app.public.tour'],
  ['app.admin.trainings', 'admin/trainings.js', 'admin/trainings/index.html', 'app.admin.tour'],
  ['app.admin.calendar', 'admin/calendar.js', 'admin/calendar/calendar.html', 'app.admin.tour'],
  ['app.admin.members', 'admin/members.js', 'admin/members/index.html', 'app.admin.tour'],
  ['app.admin.invoices', 'admin/invoices.js', 'admin/invoices/index.html', 'app.admin.tour'],
  ['app.admin.pricing', 'admin/pricing.js', 'admin/pricing/index.html', 'app.admin.tour'],
  ['app.admin.events', 'admin/events.js', 'admin/events/index.html', 'app.admin.tour'],
  ['app.admin.projects', 'admin/projects.js', 'admin/projects/index.html', 'app.admin.tour'],
  ['app.admin.statistics', 'admin/statistics.js', 'admin/statistics/index.html', 'app.admin.tour'],
  ['app.admin.settings', 'admin/settings.js', 'admin/settings/index.html', 'app.admin.tour'],
  ['app.admin.open_api_clients', 'admin/open_api_clients.js', 'admin/open_api_clients/index.html.erb', 'app.admin.tour']
];

describe('cold-entry tour translations', () => {
  let injector;
  let states;
  let refresh;
  let parts;

  beforeAll(() => {
    require('../../../app/frontend/src/javascript/router');
    Application.Services = angular.module('tourTranslationsTest', [])
      .value('$rootElement', angular.element(document.body));
    require('../../../app/frontend/src/javascript/services/translations');
  });

  beforeEach(() => {
    parts = [];
    refresh = jest.fn(() => Promise.resolve());
    angular.module('tourTranslationDependencies', [])
      .value('$translatePartialLoader', { addPart: part => parts.push(part) })
      .value('$translate', { refresh });
    injector = angular.injector(['ng', 'application.router', 'tourTranslationsTest', 'tourTranslationDependencies']);
    states = injector.get('$state');
  });

  test.each(tours)('%s resolves every namespace used by its tour on cold entry', async (route, controller, template, namespace) => {
    const resolve = states.get(route).resolve.tourTranslations;
    expect(resolve).toBeDefined();
    await injector.invoke(resolve);
    const source = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/controllers', controller), 'utf8') +
      fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates', template), 'utf8');
    const keys = [...source.matchAll(/'(app\.(?:admin|public)\.tour\.[^']+)'/g)].map(match => match[1]);
    expect(keys.length).toBeGreaterThan(0);
    expect([...new Set(keys.map(key => key.split('.').slice(0, 3).join('.')))]).toEqual([namespace]);
    expect(parts).toEqual([namespace]);
    const locale = yaml.load(fs.readFileSync(path.resolve(__dirname, `../../../config/locales/${namespace.slice(0, namespace.lastIndexOf('.'))}.en.yml`), 'utf8')).en;
    for (const key of keys) {
      expect(key.split('.').reduce((value, segment) => value?.[segment], locale)).toEqual(expect.any(String));
    }
  });

  test.each(tours)('%s waits for translations and propagates loading failures', async (route) => {
    const resolve = states.get(route).resolve.tourTranslations;
    expect(resolve).toBeDefined();
    const pending = new Promise(() => {});
    refresh.mockReturnValueOnce(pending);
    expect(injector.invoke(resolve)).toBe(pending);
    refresh.mockRejectedValueOnce(new Error('Translation loading failed'));
    await expect(injector.invoke(resolve)).rejects.toThrow('Translation loading failed');
  });
});
