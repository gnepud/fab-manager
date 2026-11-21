import angular from 'angular';
import fs from 'fs';
import path from 'path';
import 'angular-xeditable';

describe('GroupsController cancellation', () => {
  let scope;
  let compile;
  let groups;

  beforeAll(() => {
    Application.Controllers = angular.module('groupsControllerTest', ['xeditable']);
    Application.Filters = Application.Controllers;
    require('../../../app/frontend/src/javascript/filters/filters');
    require('../../../app/frontend/src/javascript/controllers/admin/groups');
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'groupsControllerTest']);
    scope = injector.get('$rootScope').$new();
    compile = injector.get('$compile');
    groups = [
      { id: 1, name: 'Enabled A' },
      { id: 2, name: 'Disabled B', disabled: true },
      { id: 3, name: 'Enabled C' }
    ];
    injector.get('$controller')('GroupsController', {
      $scope: scope,
      groupsPromise: [...groups],
      Group: {},
      growl: {},
      _t: value => value
    });
  });

  afterEach(() => scope.$destroy());

  function render () {
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/groups/index.html'), 'utf8');
    const element = compile(`<div>${template}</div>`)(scope);
    scope.$digest();
    return element[0];
  }

  test('removes the new filtered row without changing persisted groups', () => {
    const element = render();
    scope.addGroup();
    scope.$digest();
    const rows = element.querySelectorAll('tbody tr');
    expect(rows).toHaveLength(3);
    angular.element(rows[2].querySelector('form button[type="button"]')).triggerHandler('click');
    scope.$digest();
    expect(scope.groups).toEqual(groups);
    expect(scope.groups.every((group, index) => group === groups[index])).toBe(true);
    expect(element.querySelectorAll('tbody tr')).toHaveLength(2);
  });

  test('cancels editing a persisted group without removing it', () => {
    const element = render();
    const row = element.querySelectorAll('tbody tr')[1];
    const rowform = angular.element(row).scope().rowform;
    rowform.$show();
    const cancel = jest.spyOn(rowform, '$cancel');
    angular.element(row.querySelector('form button[type="button"]')).triggerHandler('click');
    expect(cancel).toHaveBeenCalledTimes(1);
    expect(scope.groups).toEqual(groups);
    expect(scope.groups.every((group, index) => group === groups[index])).toBe(true);
  });

  test('renders no rows for an empty group list', () => {
    scope.groups = [];
    expect(render().querySelectorAll('tbody tr')).toHaveLength(0);
  });
});
