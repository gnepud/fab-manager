import angular from 'angular';

describe('current user tour history', () => {
  let scope;
  let rootScope;
  let session;

  beforeAll(() => {
    Application.Controllers = angular.module('sessionTourModeTest', []);
    require('../../../app/frontend/src/javascript/controllers/application');
    angular.isUndefinedOrNull = value => angular.isUndefined(value) || value === null;
  });

  afterAll(() => { delete angular.isUndefinedOrNull; });

  beforeEach(() => {
    Fablab.sessionTours = [];
    Fablab.sessionTourMode = true;
    const injector = angular.injector(['ng', 'sessionTourModeTest']);
    scope = injector.get('$rootScope').$new();
    rootScope = { checkNotificationsIsInit: true };
    session = { create: jest.fn() };
    injector.get('$controller')('ApplicationController', {
      $rootScope: rootScope,
      $scope: scope,
      $transitions: { onStart: jest.fn() },
      $locale: { NUMBER_FORMATS: { CURRENCY_SYM: '$' } },
      Session: session,
      AuthService: {},
      Auth: { login: () => new Promise(() => {}) },
      $uibModal: {},
      $state: {},
      growl: {},
      Notification: {},
      Setting: { query: jest.fn() },
      _t: key => key,
      Version: { get: jest.fn() },
      Help: jest.fn(),
      $cookies: {}
    });
  });

  afterEach(() => {
    scope.$destroy();
    delete Fablab.sessionTourMode;
    Fablab.sessionTours = [];
    jest.restoreAllMocks();
  });

  test('ignores persisted once-mode history on a fresh session-mode load', () => {
    const user = { id: 1, role: 'admin', profile_attributes: { tours: ['welcome', 'trainings'] } };
    scope.setCurrentUser(user);
    expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
    expect(rootScope.currentUser.profile_attributes.tours).toEqual([]);
    expect(session.create).toHaveBeenCalledWith(user);
  });

  test('keeps this application session history when the user is set again', () => {
    Fablab.sessionTours.push('calendar');
    scope.setCurrentUser({ id: 1, role: 'admin', profile_attributes: { tours: ['welcome'] } });
    expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
    expect(rootScope.currentUser.profile_attributes.tours).toEqual(['calendar']);
  });

  test.each([[['welcome']], [[]]])('preserves database history outside session mode: %j', tours => {
    Fablab.sessionTourMode = false;
    const user = { id: 1, role: 'admin', profile_attributes: { tours } };
    scope.setCurrentUser(user);
    expect(rootScope.currentUser.profile_attributes.tours).toBe(tours);
  });

  test('ignores an absent user', () => {
    scope.setCurrentUser(null);
    expect(session.create).not.toHaveBeenCalled();
  });
});
