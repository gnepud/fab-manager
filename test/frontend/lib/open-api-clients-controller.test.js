import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('OpenAPIClientsController deletion', () => {
  let scope;
  let compile;
  let api;
  let confirm;

  beforeAll(() => {
    Application.Controllers = angular.module('openAPIClientsControllerTest', [])
      .filter('translate', () => value => value)
      .filter('amDateFormat', () => value => value);
    require('../../../app/frontend/src/javascript/controllers/admin/open_api_clients');
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'openAPIClientsControllerTest']);
    scope = injector.get('$rootScope').$new();
    compile = injector.get('$compile');
    api = { delete: jest.fn() };
    confirm = jest.fn((options, callback) => callback());
    injector.get('$controller')('OpenAPIClientsController', {
      $scope: scope,
      clientsPromise: [{ id: 1, name: 'Zeta', calls_count: 0 }, { id: 2, name: 'Alpha', calls_count: 0 }],
      settingsPromise: {},
      growl: { success: jest.fn() },
      OpenAPIClient: api,
      dialogs: { confirm },
      _t: value => value,
      Member: {},
      uiTourService: {}
    });
  });

  afterEach(() => scope.$destroy());

  function renderRows () {
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/open_api_clients/index.html.erb'), 'utf8');
    const table = compile(template.match(/<table[\s\S]*?<\/table>/)[0])(scope);
    scope.$digest();
    return table;
  }

  test('deletes Alpha from the first name-sorted template row, leaving Zeta', () => {
    scope.setOrder('name');
    const table = renderRows();
    expect(table[0].querySelector('tbody tr td').textContent).toBe('Alpha');
    angular.element(table[0].querySelector('tbody .btn-danger')).triggerHandler('click');
    expect(api.delete).toHaveBeenCalledWith({ id: 2 }, expect.any(Function));
    api.delete.mock.calls[0][1]();
    scope.$digest();
    expect(scope.clients.map(client => client.name)).toEqual(['Zeta']);
    expect(table[0].querySelectorAll('tbody tr')).toHaveLength(1);
    expect(table[0].querySelector('tbody tr td').textContent).toBe('Zeta');
  });

  test('renders no delete actions for an empty list', () => {
    scope.clients = [];
    expect(renderRows()[0].querySelectorAll('tbody .btn-danger')).toHaveLength(0);
    expect(api.delete).not.toHaveBeenCalled();
  });

  test('keeps the list unchanged when deletion does not succeed', () => {
    scope.setOrder('name');
    const table = renderRows();
    angular.element(table[0].querySelector('tbody .btn-danger')).triggerHandler('click');
    expect(scope.clients.map(client => client.name)).toEqual(['Zeta', 'Alpha']);
  });

  test('does not delete when confirmation is cancelled', () => {
    confirm.mockImplementation(() => {});
    const table = renderRows();
    angular.element(table[0].querySelector('tbody .btn-danger')).triggerHandler('click');
    expect(api.delete).not.toHaveBeenCalled();
    expect(scope.clients).toHaveLength(2);
  });
});
