import angular from 'angular';
import moment from 'moment';

describe('SettingsController upload errors', () => {
  let scope;
  let growl;
  let setting;

  beforeAll(() => {
    global.moment = moment;
    Application.Controllers = angular.module('settingsControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/settings');
  });

  afterAll(() => { delete global.moment; });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'settingsControllerTest']);
    scope = injector.get('$rootScope').$new();
    setting = { update: jest.fn() };
    growl = { error: jest.fn(), success: jest.fn() };
    angular.injector(['ng', 'settingsControllerTest']).get('$controller')('SettingsController', {
      $scope: scope,
      $rootScope: { summernoteOpts: { toolbar: [[], [], [], [], [], ['insert', []]] } },
      $uibModal: {},
      dialogs: {},
      Setting: setting,
      growl,
      settingsPromise: { booking_window_start: '2000-01-01T08:00:00.000Z', booking_window_end: '2000-01-01T15:00:00.000Z' },
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
    scope.$digest();
  });

  test.each(['15:00', '16:00'])('reverts opening at %s before saving', time => {
    const previous = scope.windowStart.value;
    scope.windowStart.value = new Date(`2000-01-01T${time}:00`);
    scope.$digest();
    expect(scope.windowStart.value).toBe(previous);
    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith('app.admin.settings.invalid_booking_window');
    scope.save(scope.windowStart);
    expect(setting.update.mock.calls[0][1].value).toBe(previous);
  });

  test('accepts opening before closing', () => {
    const value = new Date('2000-01-01T09:00:00');
    scope.windowStart.value = value;
    scope.$digest();
    expect(scope.windowStart.value).toBe(value);
    expect(growl.error).not.toHaveBeenCalled();
    scope.save(scope.windowStart);
    expect(setting.update.mock.calls[0][1].value).toBe(value.toISOString());
  });

  test.each(['07:00', '08:00'])('rejects closing at %s with an error', time => {
    const previous = scope.windowEnd.value;
    scope.windowEnd.value = new Date(`2000-01-01T${time}:00`);
    scope.$digest();
    expect(scope.windowEnd.value).toBe(previous);
    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith('app.admin.settings.invalid_booking_window');
  });

  test('does not show an error on initialization or unchanged values', () => {
    scope.$digest();
    expect(growl.error).not.toHaveBeenCalled();
  });

  test('accepts closing after opening without an error', () => {
    const value = new Date('2000-01-01T14:00:00');
    scope.windowEnd.value = value;
    scope.$digest();
    expect(scope.windowEnd.value).toBe(value);
    expect(growl.error).not.toHaveBeenCalled();
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
