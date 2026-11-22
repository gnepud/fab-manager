import angular from 'angular';

describe('ApplicationController', () => {
  let scope;
  let rootScope;
  let onStart;
  let state;
  let modal;
  let resolveLogin;
  let rejectLogin;
  let auth;

  beforeAll(() => {
    Application.Controllers = angular.module('applicationControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/application');
  });

  beforeEach(() => {
    scope = {};
    rootScope = {};
    state = { go: jest.fn() };
    auth = { login: () => new Promise(() => {}), register: jest.fn() };
    modal = {
      open: jest.fn(() => ({
        result: new Promise((resolve, reject) => {
          resolveLogin = resolve;
          rejectLogin = reject;
        })
      }))
    };
    const injector = angular.injector(['ng', 'applicationControllerTest']);
    injector.get('$controller')('ApplicationController', {
      $rootScope: rootScope,
      $scope: scope,
      $transitions: { onStart: (criteria, callback) => { onStart = callback; } },
      $locale: { NUMBER_FORMATS: { CURRENCY_SYM: '$' } },
      Session: {},
      AuthService: { isAuthorized: () => false, isAuthenticated: () => false },
      Auth: auth,
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
    scope.setCurrentUser = jest.fn();
    global.GTM = { trackLogin: jest.fn() };
  });

  afterEach(() => {
    jest.restoreAllMocks();
    delete global.GTM;
  });

  test('uses the configured EUR symbol for legacy coupons even with an English Angular locale', () => {
    expect(rootScope.currencySymbol).toBe('€');
  });

  test.each([
    [{ base: ['Password is too weak: minimum 12 characters'] }, ['Password is too weak: minimum 12 characters']],
    [{ password: ['is invalid'] }, ['password: is invalid']],
    [{ base: [] }, []]
  ])('signup displays base errors without an attribute prefix', async (errors, expected) => {
    scope.signup();
    const definition = modal.open.mock.calls[0][0].controller;
    const signupScope = {};
    const dependencies = {
      $scope: signupScope,
      Group: { query: jest.fn() },
      CustomAsset: { get: jest.fn() },
      settingsPromise: {},
      profileCustomFieldsPromise: []
    };
    definition[definition.length - 1](...definition.slice(0, -1).map(name => dependencies[name]));
    auth.register.mockRejectedValue({ data: { errors } });
    await signupScope.ok();
    expect(signupScope.alerts.map(alert => alert.msg)).toEqual(expected);
  });

  test.each([
    ['app.logged.space_reserve', { id: '42' }],
    ['app.logged.trainings_reserve', { id: '17' }],
    ['app.logged.dashboard', {}]
  ])('resumes %s with destination parameter values', async (name, params) => {
    const transition = {
      $to: () => ({ name, data: { authorizedRoles: ['member'] }, params: { id: { id: 'id' } } }),
      params: () => params
    };

    expect(onStart(transition)).toBe(false);
    resolveLogin({ id: 1 });
    await new Promise(resolve => setTimeout(resolve, 0));

    expect(state.go).toHaveBeenCalledWith(name, params);
  });

  test('does not redirect when login is cancelled', async () => {
    onStart({
      $to: () => ({ name: 'app.logged.space_reserve', data: { authorizedRoles: ['member'] } }),
      params: () => ({ id: '42' })
    });
    rejectLogin('cancel');
    await new Promise(resolve => setTimeout(resolve, 0));

    expect(state.go).not.toHaveBeenCalled();
  });
});
