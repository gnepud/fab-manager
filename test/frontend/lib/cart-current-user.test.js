import angular from 'angular';

Application.Directives = { directive: jest.fn() };
Application.Controllers = { controller: jest.fn() };
require('../../../app/frontend/src/javascript/directives/cart');
require('../../../app/frontend/src/javascript/controllers/plans');

const cartDefinition = Application.Directives.directive.mock.calls.find(([name]) => name === 'cart')[1];
const plansDefinition = Application.Controllers.controller.mock.calls.find(([name]) => name === 'PlansIndexController')[1];
const invoke = (definition, dependencies) => definition[definition.length - 1](...definition.slice(0, -1).map(name => dependencies[name]));

describe('cart identity after in-page login', () => {
  let rootScope, plansScope, cartScope;

  beforeEach(() => {
    rootScope = angular.injector(['ng']).get('$rootScope');
    rootScope.currentUser = null;
    plansScope = rootScope.$new();
    invoke(plansDefinition, {
      $scope: plansScope,
      $rootScope: rootScope,
      settingsPromise: {},
      subscriptionExplicationsPromise: { setting: { value: '' } },
      AuthService: { isAuthorized: () => false }
    });
    cartScope = plansScope.$new(true);
    cartScope.settings = {};
    cartScope.events = {};
    plansScope.$watch('ctrl.member', user => { cartScope.user = user; });
    invoke(cartDefinition, {
      $rootScope: rootScope,
      Price: { compute: jest.fn() }
    }).link(cartScope);
    rootScope.$digest();
  });

  afterEach(() => rootScope.$destroy());

  test('keeps visitor identity empty before login', () => {
    expect(cartScope.currentUser).toBeNull();
    expect(cartScope.user).toBeNull();
  });

  test('passes the logged-in member as both payment operator and customer without recreating the cart', () => {
    const member = { id: 42, role: 'member' };
    rootScope.$broadcast('devise:new-session', member);
    rootScope.currentUser = member;
    rootScope.$digest();

    expect(cartScope.user).toBe(member);
    expect(cartScope.currentUser).toBe(member);
    expect(cartScope.user.id).toBe(cartScope.currentUser.id);
  });

  test('tracks session replacement without overwriting a selected customer', () => {
    const customer = { id: 13, role: 'member' };
    plansScope.ctrl.member = customer;
    rootScope.currentUser = { id: 7, role: 'admin' };
    rootScope.$digest();

    expect(cartScope.currentUser).toBe(rootScope.currentUser);
    expect(cartScope.user).toBe(customer);

    rootScope.currentUser = null;
    rootScope.$digest();
    expect(cartScope.currentUser).toBeNull();
    expect(cartScope.user).toBe(customer);
  });
});
