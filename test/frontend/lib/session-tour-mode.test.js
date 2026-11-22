import angular from 'angular';
import '@uirouter/angularjs';

describe('current user tour history', () => {
  let scope;
  let rootScope;
  let session;
  let injector;
  let auth;

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
    session = { create: jest.fn(), destroy: jest.fn() };
    auth = { login: () => new Promise(() => {}), logout: jest.fn().mockResolvedValue() };
    injector.get('$controller')('ApplicationController', {
      $rootScope: rootScope,
      $scope: scope,
      $transitions: { onStart: jest.fn() },
      $locale: { NUMBER_FORMATS: { CURRENCY_SYM: '$' } },
      Session: session,
      AuthService: {},
      Auth: auth,
      $uibModal: {},
      $state: { go: jest.fn() },
      growl: {},
      Notification: {},
      Setting: { query: jest.fn() },
      _t: key => key,
      Version: { get: jest.fn() },
      Help: jest.fn(),
      $cookies: { remove: jest.fn() }
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

  test.each([[[]], [['settings']]])('starts a new user with empty history after logout with completed tours: %j', async tours => {
    scope.setCurrentUser({ id: 1, role: 'admin', profile_attributes: { tours: [] } });
    Fablab.sessionTours.push(...tours);
    expect(rootScope.currentUser.profile_attributes.tours).toEqual(tours);

    await scope.logout({ preventDefault: jest.fn() });
    expect(rootScope.currentUser).toBeNull();
    scope.setCurrentUser({ id: 2, role: 'admin', profile_attributes: { tours: ['welcome', 'settings'] } });

    expect(Fablab.sessionTours).toEqual([]);
    expect(rootScope.currentUser.id).toBe(2);
    expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
  });

  test('preserves the current user and session history when logout fails', async () => {
    const user = { id: 1, role: 'admin', profile_attributes: { tours: [] } };
    scope.setCurrentUser(user);
    Fablab.sessionTours.push('settings');
    const error = new Error('Logout failed');
    auth.logout.mockRejectedValueOnce(error);
    jest.spyOn(console, 'error').mockImplementation(() => {});

    await scope.logout({ preventDefault: jest.fn() });

    expect(rootScope.currentUser).toBe(user);
    expect(Fablab.sessionTours).toEqual(['settings']);
    expect(session.destroy).not.toHaveBeenCalled();
    expect(console.error).toHaveBeenCalledWith(`An error occurred logging out: ${error}`);
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
