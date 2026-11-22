import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('members authentication providers', () => {
  let states;

  beforeAll(() => {
    states = {};
    const stateProvider = {
      state: jest.fn((name, state) => {
        states[name] = state;
        return stateProvider;
      })
    };
    const module = jest.spyOn(angular, 'module').mockReturnValue({
      config: definition => definition[definition.length - 1](stateProvider, { otherwise: jest.fn() }, { hashPrefix: jest.fn() })
    });
    require('../../../app/frontend/src/javascript/router');
    module.mockRestore();
    angular.module('membersAuthProvidersTest', [])
      .value('$rootElement', angular.element('<div></div>'))
      .filter('translate', () => value => value);
  });

  test.each([{ role: 'manager' }, { role: 'member' }, null])('does not fetch providers for %j', currentUser => {
    const provider = { query: jest.fn() };
    const resolve = states['app.admin.members'].resolve.authProvidersPromise;

    expect(resolve.slice(0, -1)).toEqual(['AuthProvider', 'currentUser']);
    expect(resolve[resolve.length - 1](provider, currentUser)).toEqual([]);
    expect(provider.query).not.toHaveBeenCalled();
  });

  test('fetches providers for administrators', () => {
    const promise = Promise.resolve([{ name: 'FabManager' }]);
    const provider = { query: jest.fn(() => ({ $promise: promise })) };
    const resolve = states['app.admin.members'].resolve.authProvidersPromise;

    expect(resolve[resolve.length - 1](provider, { role: 'admin' })).toBe(promise);
    expect(provider.query).toHaveBeenCalledTimes(1);
  });

  test.each(['admin', 'manager'])('gates the Authentication tab for %s', role => {
    const injector = angular.injector(['ng', 'membersAuthProvidersTest']);
    const scope = injector.get('$rootScope').$new();
    scope.isAuthorized = allowedRole => allowedRole === role;
    injector.get('$templateCache').put('/admin/members/users.html', '<div class="member-list"></div>');
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/index.html'), 'utf8');
    const element = injector.get('$compile')('<div>' + template + '</div>')(scope);
    scope.$digest();

    expect(element[0].querySelector('.sso-tab') !== null).toBe(role === 'admin');
    expect(element[0].querySelector('.member-list')).not.toBeNull();
    scope.$destroy();
    element.remove();
  });
});
