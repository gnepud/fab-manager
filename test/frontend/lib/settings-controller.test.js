import angular from 'angular';
import moment from 'moment';

describe('SettingsController upload errors', () => {
  let scope;
  let growl;

  beforeAll(() => {
    global.moment = moment;
    Application.Controllers = angular.module('settingsControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/settings');
  });

  afterAll(() => { delete global.moment; });

  beforeEach(() => {
    scope = { $watch: jest.fn() };
    growl = { error: jest.fn(), success: jest.fn() };
    angular.injector(['ng', 'settingsControllerTest']).get('$controller')('SettingsController', {
      $scope: scope,
      $rootScope: { summernoteOpts: { toolbar: [[], [], [], [], [], ['insert', []]] } },
      $uibModal: {},
      dialogs: {},
      Setting: {},
      growl,
      settingsPromise: {},
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

  test.each([
    [{ error: 'You have to confirm your email address before continuing.' }, ['You have to confirm your email address before continuing.']],
    [{ attachment: ['cannot be blank', 'must be a PDF'], name: ['is invalid'] }, ['cannot be blank', 'must be a PDF', 'is invalid']],
    [{ error: 'Unauthorized', attachment: ['is invalid'] }, ['Unauthorized', 'is invalid']],
    [{}, []],
    [{ attachment: [] }, []]
  ])('displays whole error messages for %j', (content, messages) => {
    scope.submited(content);

    expect(growl.error.mock.calls).toEqual(messages.map(message => [message]));
    expect(growl.success).not.toHaveBeenCalled();
  });

  test('keeps successful terms uploads working', () => {
    const asset = { name: 'cgu-file', attachment_url: '/terms.pdf' };
    scope.submited({ custom_asset: asset });

    expect(scope.cguFile).toBe(asset);
    expect(scope.methods.cgu).toBe('put');
    expect(scope.actionUrl.cgu).toBe('/api/custom_assets/cgu-file');
    expect(scope.loader.cgu).toBe(false);
    expect(growl.success).toHaveBeenCalledTimes(1);
    expect(growl.error).not.toHaveBeenCalled();
  });
});
