import angular from 'angular';
import lodash from 'lodash';

describe('account deletion errors', () => {
  let scope;
  let growl;
  let resource;
  let auth;

  beforeAll(() => {
    global._ = lodash;
    Application.Controllers = angular.module('accountDeletionTest', []);
    require('../../../app/frontend/src/javascript/controllers/members');
    require('../../../app/frontend/src/javascript/controllers/admin/members');
  });

  afterAll(() => { delete global._; });

  beforeEach(() => {
    scope = { currentUser: { id: 2 } };
    growl = { error: jest.fn(), success: jest.fn() };
    resource = { delete: jest.fn(), remove: jest.fn() };
    auth = { logout: jest.fn().mockResolvedValue() };
    angular.injector(['ng', 'accountDeletionTest']).get('$controller')('EditProfileController', {
      $scope: scope,
      $rootScope: {},
      $state: { go: jest.fn() },
      $window: {},
      $sce: { trustAsHtml: text => text },
      $cookies: { get: jest.fn() },
      $injector: {},
      Member: resource,
      Auth: auth,
      Session: {},
      activeProviderPromise: { providable_type: 'DatabaseProvider', mapping: [] },
      settingsPromise: {},
      growl,
      dialogs: { confirm: (_options, confirm) => confirm() },
      CSRF: { setMetaTags: jest.fn() },
      memberPromise: { id: 2 },
      groups: [],
      _t: key => key,
      proofOfIdentityTypesPromise: [],
      SupportingDocumentType: {}
    });
  });

  const message = 'Impossible de supprimer ce compte : il possède des réservations à venir ou un abonnement actif.';

  test('self deletion displays the server explanation and does not log out on refusal', () => {
    resource.remove.mockImplementation((_params, _success, error) => error({ data: [message] }));
    scope.deleteUser({ id: 2 });
    expect(growl.error).toHaveBeenCalledWith(message);
    expect(auth.logout).not.toHaveBeenCalled();
  });

  test.each([undefined, [], '<html>Server failure</html>'])('self deletion retains its readable fallback for %j', data => {
    resource.remove.mockImplementation((_params, _success, error) => error({ data }));
    scope.deleteUser({ id: 2 });
    expect(growl.error).toHaveBeenCalledWith('app.logged.dashboard.settings.an_error_occured_preventing_your_account_from_being_deleted');
  });

  test.each(['deleteMember', 'destroyAdmin', 'destroyPartner', 'destroyManager'])('%s displays the server explanation and retains the list', method => {
    angular.injector(['ng', 'accountDeletionTest']).get('$controller')('AdminMembersController', {
      $scope: scope,
      $sce: { trustAsHtml: text => text },
      $uibModal: {},
      membersPromise: [{ id: 2 }],
      adminsPromise: { admins: [{ id: 2 }] },
      partnersPromise: [{ id: 2 }],
      managersPromise: [{ id: 2 }],
      growl,
      Admin: resource,
      AuthService: {},
      dialogs: { confirm: (_options, confirm) => confirm() },
      _t: key => key,
      Member: resource,
      Export: {},
      User: resource,
      uiTourService: {},
      settingsPromise: {},
      $location: { search: () => ({}) }
    });
    resource.delete.mockImplementation((_params, _success, error) => error({ data: [message] }));
    if (method === 'deleteMember') scope[method](2);
    else scope[method]([{ id: 2 }], { id: 2 });
    expect(growl.error).toHaveBeenCalledWith(message);
    expect(scope.members).toEqual([{ id: 2 }]);
  });
});
