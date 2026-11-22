import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('admin members tour tab placement', () => {
  let scope;
  let steps;
  let handlers;
  let template;

  beforeAll(() => {
    Application.Controllers = angular.module('membersTourTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/members');
  });

  beforeEach(() => {
    steps = [];
    handlers = {};
    template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/index.html'), 'utf8');
    const usersTab = template.querySelector('uib-tab[index="0"]');
    usersTab.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/users.html'), 'utf8');
    document.body.appendChild(template);
    const injector = angular.injector(['ng', 'membersTourTest']);
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, role: 'admin', profile_attributes: { tours: [] } };
    injector.get('$controller')('AdminMembersController', {
      $scope: scope,
      $sce: {},
      $uibModal: {},
      membersPromise: [],
      adminsPromise: { admins: [] },
      partnersPromise: [],
      managersPromise: [],
      growl: {},
      Admin: {},
      AuthService: { isAuthorized: role => role === 'admin' },
      dialogs: {},
      _t: key => key,
      Member: {},
      Export: {},
      User: {},
      uiTourService: {
        getTourByName: () => ({
          createStep: step => steps.push(step),
          on: (event, handler) => { handlers[event] = handler; }
        })
      },
      settingsPromise: { feature_tour_display: 'manual' },
      $location: { search: () => ({}) }
    });
    scope.setupMembersTour();
  });

  afterEach(() => {
    scope.$destroy();
    template.remove();
  });

  test('Authentication is the last top-level justified tab, after Groups and Tags', () => {
    const tabset = template.querySelector('uib-tabset');
    const tabs = Array.from(tabset.children);
    expect(tabset.getAttribute('justified')).toBe('true');
    expect(tabs.slice(-3).map(tab => tab.className)).toEqual(['groups-tab', 'labels-tab', 'sso-tab']);
  });

  test.each(['groups', 'labels', 'sso'])('%s targets the real tab and activates its pane', name => {
    const step = steps.find(step => step.stepId === name);
    const tab = template.querySelector(step.selector);
    expect(tab.tagName).toBe('UIB-TAB');
    handlers.stepChanged(step);
    expect(scope.tabs.active).toBe(Number(tab.getAttribute('index')));
  });

  test('the admins step targets the interior Administrators subtab under Users', () => {
    const step = steps.find(step => step.stepId === 'admins');
    const tab = template.querySelector(step.selector);
    const tabset = tab.closest('uib-tabset');
    expect(tabset.getAttribute('active')).toBe('tabs.sub');
    expect(Array.from(tabset.children).indexOf(tab)).toBe(1);
    handlers.stepChanged(step);
    expect(scope.tabs.active).toBe(Number(tabset.closest('uib-tab').getAttribute('index')));
    expect(scope.tabs.sub).toBe(Number(tab.getAttribute('index')));
  });

  test.each([
    ['admins', 'bottom'],
    ['groups', 'bottom'],
    ['labels', 'bottom'],
    ['sso', 'bottom-right']
  ])('%s uses %s alignment without a manual offset', (name, placement) => {
    const step = steps.find(step => step.stepId === name);
    expect(step.placement).toBe(placement);
    expect(step.popupClass).toBeUndefined();
  });
});
