import angular from 'angular';
import moment from 'moment';

describe('public registration navigation settings', () => {
  let rootScope, adminScope, headerScope, navScope, controller;

  beforeAll(() => {
    global.moment = moment;
    Application.Controllers = angular.module('registrationSettingsTest', []);
    require('../../../app/frontend/src/javascript/controllers/header');
    require('../../../app/frontend/src/javascript/controllers/main_nav');
    require('../../../app/frontend/src/javascript/controllers/admin/settings');
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'registrationSettingsTest']);
    rootScope = injector.get('$rootScope');
    controller = injector.get('$controller');
    rootScope.settings = { publicRegistrations: true, familyAccount: true };
    rootScope.modules = {};
    rootScope.summernoteOpts = { toolbar: [[], [], [], [], [], ['insert', []]] };
    headerScope = rootScope.$new();
    navScope = rootScope.$new();
    const parentSettings = { public_registrations: 'true' };
    controller('HeaderController', {
      $scope: headerScope,
      $transitions: { onStart: jest.fn() },
      $state: { current: { name: 'app.admin.settings' } },
      settingsPromise: parentSettings,
      SupportingDocumentType: {},
      AuthService: {}
    });
    controller('MainNavController', { $scope: navScope, settingsPromise: parentSettings });
    adminScope = rootScope.$new();
    controller('SettingsController', {
      $scope: adminScope,
      $filter: jest.fn(),
      $uibModal: {},
      dialogs: {},
      Setting: {},
      growl: { success: jest.fn(), error: jest.fn() },
      settingsPromise: { public_registrations: 'true' },
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
      uiTourService: {},
      ReservationContext: {}
    });
  });

  test('successful saves disable and re-enable existing navigation without reloading', () => {
    expect(headerScope.registrationEnabled()).toBe(true);
    expect(navScope.registrationEnabled()).toBe(true);

    adminScope.onSuccess('Saved', 'public_registrations', 'false');
    rootScope.$digest();
    expect(headerScope.registrationEnabled()).toBe(false);
    expect(navScope.registrationEnabled()).toBe(false);
    expect(rootScope.settings.familyAccount).toBe(true);

    adminScope.onSuccess('Saved', 'public_registrations', 'true');
    rootScope.$digest();
    expect(headerScope.registrationEnabled()).toBe(true);
    expect(navScope.registrationEnabled()).toBe(true);
  });

  test('missing setting does not enable registration', () => {
    delete rootScope.settings.publicRegistrations;
    expect(headerScope.registrationEnabled()).toBeFalsy();
    expect(navScope.registrationEnabled()).toBeFalsy();
  });

  test('errors and unrelated success callbacks do not change registration visibility', () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    adminScope.onError('Save failed');
    adminScope.onSuccess('Saved', 'confirmation_required', 'false');
    adminScope.onSuccess('Saved');
    rootScope.$digest();
    expect(headerScope.registrationEnabled()).toBe(true);
    expect(navScope.registrationEnabled()).toBe(true);
    console.error.mockRestore();
  });
});
