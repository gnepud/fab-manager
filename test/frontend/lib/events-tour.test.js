import angular from 'angular';
import 'angular-ui-bootstrap';
import fs from 'fs';
import path from 'path';

describe('admin events tour tabs', () => {
  let scope;
  let steps;
  let handlers;
  let template;
  let source;

  beforeAll(() => {
    Application.Controllers = angular.module('eventsTourTest', ['ui.bootstrap'])
      .value('$rootElement', angular.element(document.body))
      .filter('translate', () => key => key)
      .filter('amDateFormat', () => value => value);
    require('../../../app/frontend/src/javascript/controllers/admin/events');
  });

  beforeEach(() => {
    steps = [];
    handlers = {};
    const injector = angular.injector(['ng', 'eventsTourTest']);
    source = document.createElement('div');
    source.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/events/index.html'), 'utf8');
    for (const include of source.querySelectorAll('ng-include')) {
      const url = include.getAttribute('src').slice(1, -1);
      const content = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates', url.slice(1)), 'utf8');
      include.innerHTML = content;
      injector.get('$templateCache').put(url, content);
    }
    template = source.cloneNode(true);
    document.body.appendChild(template);
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, role: 'admin', profile_attributes: { tours: [] } };
    scope.isAuthorized = role => Array.isArray(role) ? role.includes(scope.currentUser.role) : role === scope.currentUser.role;
    injector.get('$controller')('AdminEventsController', {
      $scope: scope,
      $state: {},
      dialogs: {},
      $uibModal: {},
      growl: {},
      AuthService: { isAuthorized: scope.isAuthorized },
      Event: { query: (_params, callback) => callback([]) },
      Category: {},
      EventTheme: {},
      AgeRange: {},
      PriceCategory: {},
      eventsPromise: [],
      categoriesPromise: [],
      themesPromise: [],
      ageRangesPromise: [],
      priceCategoriesPromise: [],
      _t: key => key,
      Member: {},
      uiTourService: {
        getTourByName: () => ({
          createStep: step => steps.push(step),
          on: (event, handler) => { handlers[event] = handler; }
        })
      },
      settingsPromise: { feature_tour_display: 'manual' },
      $uiRouter: {}
    });
    injector.get('$compile')(template)(scope);
    scope.$digest();
    scope.setupEventsTour();
  });

  afterEach(() => {
    scope.$destroy();
    template.remove();
  });

  test('every step targets an element in the real templates, including an empty events list', () => {
    expect(steps.map(step => step.stepId)).toEqual(['welcome', 'list', 'filter', 'categories', 'themes', 'ages', 'prices', 'conclusion']);
    expect(steps.filter(step => !document.querySelector(step.selector)).map(step => step.selector)).toEqual([]);
    expect(template.querySelectorAll('.events-list tbody tr')).toHaveLength(0);
  });

  test.each(['list', 'filter', 'categories', 'themes', 'ages', 'prices'])('%s activates the tab owning its target', name => {
    const step = steps.find(step => step.stepId === name);
    const tab = source.querySelector(step.selector).closest('uib-tab');
    handlers.stepChanged(step);
    scope.$digest();
    expect(scope.tabs.active).toBe(Number(tab.getAttribute('index')));
    const target = template.querySelector(step.selector);
    expect((target.closest('.tab-pane') || target).classList.contains('active')).toBe(true);
  });

  test('Previous from prices to themes restores the Filters pane without replacing the target', () => {
    const themes = steps.find(step => step.stepId === 'themes');
    const target = template.querySelector(themes.selector);
    handlers.stepChanged(steps.find(step => step.stepId === 'prices'));
    scope.$digest();
    expect(scope.tabs.active).toBe(Number(source.querySelector('.prices-tab').getAttribute('index')));
    handlers.stepChanged(themes);
    scope.$digest();
    expect(target.closest('.tab-pane')).toBe(template.querySelector('.tab-pane.active'));
    expect(template.querySelector(themes.selector)).toBe(target);
  });

  test('managers only receive monitoring steps and their targets remain present without admin tabs', () => {
    scope.currentUser.role = 'manager';
    steps.length = 0;
    scope.$digest();
    scope.setupEventsTour();
    expect(steps.map(step => step.stepId)).toEqual(['welcome', 'list', 'filter', 'conclusion']);
    expect(steps.filter(step => !document.querySelector(step.selector))).toEqual([]);
    expect(template.querySelector('.nav-tabs')).toBeNull();
  });
});
