Application.Controllers = { controller: jest.fn() };
require('../../../app/frontend/src/javascript/controllers/admin/members');

describe.each([
  ['NewAdminController', 'saveAdmin', 'app.admin.admins_new.failed_to_create_admin'],
  ['NewManagerController', 'saveManager', 'app.admin.manager_new.failed_to_create_manager']
])('%s server errors', (controller, save, translationKey) => {
  let scope, resource, growl, translate;

  beforeEach(() => {
    scope = {};
    resource = { save: jest.fn() };
    growl = { error: jest.fn() };
    translate = jest.fn(() => 'Création impossible :');
    const dependencies = {
      $scope: scope,
      Admin: resource,
      User: resource,
      settingsPromise: {},
      groupsPromise: [],
      growl,
      _t: translate
    };
    const definition = Application.Controllers.controller.mock.calls.find(([name]) => name === controller)[1];
    definition[definition.length - 1](...definition.slice(0, -1).map(name => dependencies[name]));
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test.each([
    [['Email n’est pas disponible'], ' Email n’est pas disponible'],
    [['Email n’est pas disponible', 'Pseudonyme est invalide'], ' Email n’est pas disponible Pseudonyme est invalide'],
    ['Une erreur est survenue', ' Une erreur est survenue'],
    [[], ''],
    [undefined, ''],
    [{ status: 500 }, '']
  ])('shows one readable toast for %j', (data, detail) => {
    scope[save]();
    resource.save.mock.calls[0][3]({ data });

    expect(translate).toHaveBeenCalledWith(translationKey);
    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith('Création impossible :' + detail);
  });
});
