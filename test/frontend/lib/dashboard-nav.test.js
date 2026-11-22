import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('dashboard navigation', () => {
  let rootScope;
  let scope;
  let element;

  beforeEach(() => {
    const injector = angular.injector(['ng']);
    rootScope = injector.get('$rootScope');
    scope = rootScope.$new();
    scope.isAuthorized = () => false;
    rootScope.modules = {};
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/dashboard/nav.html'), 'utf8');
    element = injector.get('$compile')(template)(scope);
  });

  afterEach(() => {
    scope.$destroy();
    element.remove();
  });

  test.each([false, true, undefined])('shows orders only when the store module is enabled (%s)', (store) => {
    rootScope.modules.store = store;
    rootScope.$digest();

    expect(element[0].querySelector('[ui-sref="app.logged.dashboard.orders"]') !== null).toBe(store === true);
    expect(element[0].querySelector('[ui-sref="app.logged.dashboard.profile"]')).not.toBeNull();
  });
});
