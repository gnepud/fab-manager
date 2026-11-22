import angular from 'angular';
import fs from 'fs';
import path from 'path';
import moment from 'moment';

describe('admin settings tour tab placement', () => {
  let scope;
  let steps;
  let handlers;
  let template;

  beforeAll(() => {
    global.moment = moment;
    Application.Controllers = angular.module('settingsTourTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/settings');
  });

  afterAll(() => { delete global.moment; });

  beforeEach(() => {
    steps = [];
    handlers = {};
    template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/settings/index.html'), 'utf8');
    document.body.appendChild(template);
    const injector = angular.injector(['ng', 'settingsTourTest']);
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, profile_attributes: { tours: [] } };
    injector.get('$controller')('SettingsController', {
      $scope: scope,
      $rootScope: { summernoteOpts: { toolbar: [[], [], [], [], [], ['insert', []]] } },
      $uibModal: {},
      dialogs: {},
      Setting: {},
      growl: {},
      settingsPromise: {
        feature_tour_display: 'manual',
        booking_window_start: '2000-01-01T08:00:00.000Z',
        booking_window_end: '2000-01-01T15:00:00.000Z'
      },
      privacyDraftsPromise: { setting: { history: [] } },
      cgvFile: {},
      cguFile: {},
      logoFile: {},
      logoBlackFile: {},
      faviconFile: {},
      profileImageFile: {},
      reservationContextsPromise: [],
      reservationContextApplicableOnValuesPromise: [],
      CSRF: { setMetaTags: jest.fn() },
      _t: key => key,
      Member: {},
      uiTourService: {
        getTourByName: () => ({
          createStep: step => steps.push(step),
          on: (event, handler) => { handlers[event] = handler; }
        })
      },
      ReservationContext: {}
    });
    scope.setupSettingsTour();
  });

  afterEach(() => {
    scope.$destroy();
    template.remove();
  });

  test('Reservations is the rightmost justified tab, immediately after Privacy and About', () => {
    const tabset = template.querySelector('uib-tabset');
    const tabs = Array.from(tabset.querySelectorAll('uib-tab'));
    expect(tabset.getAttribute('justified')).toBe('true');
    expect(tabs.slice(-3).map(tab => tab.className)).toEqual(['about-page-tab', 'privacy-page-tab', 'reservations-page-tab']);
  });

  test.each(['general', 'about', 'privacy', 'reservations'])('%s targets the real tab and activates its pane', name => {
    const step = steps.find(step => step.stepId === name);
    const tab = template.querySelector(step.selector);
    expect(tab.tagName).toBe('UIB-TAB');
    handlers.stepChanged(step);
    expect(scope.tabs.active).toBe(Number(tab.getAttribute('index')));
  });

  test.each([
    ['general', 'bottom'],
    ['about', 'bottom'],
    ['privacy', 'bottom'],
    ['reservations', 'bottom-right']
  ])('%s uses %s alignment without a manual offset', (name, placement) => {
    const step = steps.find(step => step.stepId === name);
    expect(step.placement).toBe(placement);
    expect(step.popupClass).toBeUndefined();
  });
});
