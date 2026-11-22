import angular from 'angular';
import '@uirouter/angularjs';

describe('current user tour history', () => {
  let scope;
  let rootScope;
  let session;
  let injector;

  beforeAll(() => {
    Application.Controllers = angular.module('sessionTourModeTest', [])
      .value('$rootElement', angular.element(document.body));
    require('../../../app/frontend/src/javascript/router');
    require('../../../app/frontend/src/javascript/controllers/application');
    angular.isUndefinedOrNull = value => angular.isUndefined(value) || value === null;
  });

  afterAll(() => { delete angular.isUndefinedOrNull; });

  beforeEach(() => {
    Fablab.sessionTours = [];
    Fablab.sessionTourMode = true;
    injector = angular.injector(['ng', 'sessionTourModeTest', 'application.router']);
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

  describe.each(['app.admin', 'app.logged'])('%s route entry', name => {
    const enter = async (user) => {
      const state = injector.get('$state').get(name);
      const currentUser = await injector.invoke(state.resolve.currentUser, null, {
        Auth: { currentUser: () => Promise.resolve(user) }
      });
      injector.invoke(state.onEnter, null, { currentUser, $rootScope: rootScope });
    };

    test.each([[[]], [['calendar']]])('publishes session history instead of database history: %j', async (tours) => {
      Fablab.sessionTours = tours;
      await enter({ id: 1, role: 'admin', profile_attributes: { tours: ['welcome', 'machines', 'settings'] } });
      expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
      expect(rootScope.currentUser.profile_attributes.tours).not.toContain('settings');
    });

    test('preserves database history outside session mode', async () => {
      Fablab.sessionTourMode = false;
      const tours = ['settings'];
      await enter({ id: 1, role: 'admin', profile_attributes: { tours } });
      expect(rootScope.currentUser.profile_attributes.tours).toBe(tours);
    });

    test('accepts an absent user', async () => {
      await enter(null);
      expect(rootScope.currentUser).toBeNull();
    });
  });
});
