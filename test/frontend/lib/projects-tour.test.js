import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('admin projects tour', () => {
  let scope;
  let steps;
  let handlers;
  let template;

  beforeAll(() => {
    Application.Controllers = angular.module('projectsTourTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/projects');
  });

  beforeEach(() => {
    steps = [];
    handlers = {};
    template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/projects/index.html'), 'utf8');
    document.body.appendChild(template);
    const injector = angular.injector(['ng', 'projectsTourTest']);
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, profile_attributes: { tours: [] } };
    injector.get('$controller')('AdminProjectsController', {
      $scope: scope,
      $state: {},
      Component: {},
      Licence: {},
      Theme: {},
      ProjectCategory: {},
      componentsPromise: [],
      licencesPromise: [],
      themesPromise: [],
      projectCategoriesPromise: [],
      _t: key => key,
      Member: {},
      uiTourService: {
        getTourByName: () => ({
          createStep: step => steps.push(step),
          on: (event, handler) => { handlers[event] = handler; }
        })
      },
      settingsPromise: { feature_tour_display: 'manual' },
      growl: {},
      dialogs: {},
      DoDoc: {},
      doDocsPromise: []
    });
    scope.setupProjectElementsTour();
  });

  afterEach(() => {
    scope.$destroy();
    template.remove();
  });

  test('every step targets an element in the real page template', () => {
    expect(steps.map(step => step.stepId)).toEqual(['welcome', 'abuses', 'settings', 'conclusion']);
    expect(steps.filter(step => !document.querySelector(step.selector)).map(step => step.selector)).toEqual([]);
  });

  test('the settings step activates the settings tab', () => {
    handlers.stepChanged(steps.find(step => step.stepId === 'settings'));
    expect(scope.tabs.active).toBe(Number(template.querySelector('uib-tab.settings-tab').getAttribute('index')));
  });

  test('the rightmost settings tab uses a right-aligned popover without a manual offset', () => {
    const settings = steps.find(step => step.stepId === 'settings');
    expect(settings.placement).toBe('bottom-right');
    expect(settings.popupClass).toBeUndefined();
  });
});
