import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('member import route authorization', () => {
  let states;
  let injector;
  let session;
  let onStart;
  let modal;
  let state;

  beforeAll(() => {
    states = {};
    const stateProvider = {
      state: jest.fn((name, state) => {
        states[name] = state;
        return stateProvider;
      })
    };
    const module = jest.spyOn(angular, 'module').mockReturnValue({
      config: definition => definition[definition.length - 1](stateProvider, { otherwise: jest.fn() }, { hashPrefix: jest.fn() })
    });
    require('../../../app/frontend/src/javascript/router');
    module.mockRestore();
    session = {};
    Application.Controllers = Application.Services = angular.module('membersImportRouteTest', [])
      .value('Session', session)
      .value('$rootElement', angular.element('<div></div>'))
      .filter('translate', () => value => value);
    require('../../../app/frontend/src/javascript/services/auth');
    require('../../../app/frontend/src/javascript/controllers/application');
    injector = angular.injector(['ng', 'membersImportRouteTest']);
  });

  beforeEach(() => {
    modal = { open: jest.fn(() => ({ result: new Promise(() => {}) })) };
    state = { go: jest.fn() };
    injector.get('$controller')('ApplicationController', {
      $rootScope: {},
      $scope: {},
      $transitions: { onStart: (criteria, callback) => { onStart = callback; } },
      $locale: { NUMBER_FORMATS: { CURRENCY_SYM: '$' } },
      Auth: { login: () => new Promise(() => {}) },
      $uibModal: modal,
      $state: state,
      growl: {},
      Notification: {},
      Setting: { query: jest.fn() },
      _t: jest.fn(),
      Version: {},
      Help: jest.fn(),
      $cookies: {}
    });
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe.each(['app.admin.members_import', 'app.admin.members_import_result'])('%s', name => {
    test.each(['manager', 'member'])('cancels the transition for a signed-in %s without redirecting or opening login', role => {
      session.currentUser = { id: 2, role };

      expect(onStart({ $to: () => states[name], params: () => ({ id: '1' }) })).toBe(false);
      expect(state.go).not.toHaveBeenCalled();
      expect(modal.open).not.toHaveBeenCalled();
    });

    test('allows an administrator', () => {
      session.currentUser = { id: 1, role: 'admin' };

      expect(onStart({ $to: () => states[name], params: () => ({ id: '1' }) })).toBeUndefined();
      expect(modal.open).not.toHaveBeenCalled();
    });

    test('asks unauthenticated visitors to log in rather than entering the state', () => {
      session.currentUser = null;

      expect(onStart({ $to: () => ({ ...states[name], name }), params: () => ({ id: '1' }) })).toBe(false);
      expect(modal.open).toHaveBeenCalledTimes(1);
    });
  });

  test.each(['admin', 'manager', 'member'])('only shows the import button to administrators, not other roles (%s)', role => {
    session.currentUser = { id: 2, role };
    const scope = injector.get('$rootScope').$new();
    scope.isAuthorized = injector.get('AuthService').isAuthorized;
    injector.get('$templateCache').put('/admin/members/users.html', '<div></div>');
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/index.html'), 'utf8');
    const element = injector.get('$compile')('<div>' + template + '</div>')(scope);
    scope.$digest();

    const actions = element[0].querySelector('.import-members').closest('section');
    expect(actions.classList.contains('ng-hide')).toBe(role !== 'admin');
    scope.$destroy();
    element.remove();
  });
});
