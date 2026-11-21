Application.Controllers = { controller: jest.fn() };
require('../../../app/frontend/src/javascript/controllers/admin/members');

const definition = Application.Controllers.controller.mock.calls.find(([name]) => name === 'EditMemberController')[1];

describe('admin member subscription changes', () => {
  let scope, member, growl, plan;

  beforeEach(() => {
    scope = {};
    member = { get: jest.fn() };
    growl = { success: jest.fn(), error: jest.fn() };
    plan = { query: jest.fn() };
    const dependencies = {
      $scope: scope,
      $transition$: { params: () => ({ id: 1 }) },
      Member: member,
      Plan: plan,
      Training: { query: () => ({ $promise: Promise.resolve([]) }) },
      Group: { query: onSuccess => onSuccess([]) },
      CSRF: { setMetaTags: jest.fn() },
      memberPromise: {
        id: 1,
        subscription: { id: 2, expired_at: '2026-01-01' },
        subscribed_plan: { id: 4 },
        invoices: [{ id: 1 }],
        profile_attributes: { first_name: 'Unsaved edit' }
      },
      settingsPromise: {},
      SupportingDocumentType: { query: (_params, onSuccess) => onSuccess([]) },
      growl,
      _t: key => key
    };
    definition[definition.length - 1](...definition.slice(0, -1).map(name => dependencies[name]));
  });

  test.each(['onExtendSuccess', 'onSubscribeSuccess', 'onCancelSuccess'])('%s refreshes subscription and invoices without losing profile edits', callback => {
    const subscription = { id: 3, expired_at: '2027-01-01' };
    const plan = { id: 5 };
    const invoices = [{ id: 2 }, { id: 1 }];
    member.get.mockImplementation((_params, success) => success({ subscription, subscribed_plan: plan, invoices }));

    scope[callback]('Success');

    expect(member.get).toHaveBeenCalledWith({ id: 1 }, expect.any(Function), expect.any(Function));
    expect(scope.subscription).toBe(subscription);
    expect(scope.user.subscription).toBe(subscription);
    expect(scope.user.subscribed_plan).toBe(plan);
    expect(scope.user.invoices).toBe(invoices);
    expect(scope.user.profile_attributes.first_name).toBe('Unsaved edit');
  });

  test('clears the subscription when the API omits canceled subscription fields', () => {
    member.get.mockImplementation((_params, success) => success({ invoices: [] }));

    scope.onCancelSuccess('Canceled');

    expect(scope.subscription).toBeNull();
    expect(scope.user.subscription).toBeNull();
    expect(scope.user.subscribed_plan).toBeNull();
    expect(scope.user.invoices).toEqual([]);
  });

  test('treats a canceled subscription without subscribed plan as no subscription and loads plans', () => {
    member.get.mockImplementation((_params, success) => success({ subscription: { id: 3, canceled_at: '2026-11-21' }, invoices: [] }));
    plan.query.mockImplementation((_params, success) => success([{ base_name: 'Monthly', interval: 'month' }]));

    scope.onCancelSuccess('Canceled');

    expect(scope.subscription).toBeNull();
    expect(plan.query).toHaveBeenCalled();
    expect(scope.plans[0].nameToDisplay).toBe('Monthly - month');
  });

  test('reports a failed refresh without replacing member data', () => {
    const error = { status: 500 };
    const log = jest.spyOn(console, 'error').mockImplementation(() => {});
    member.get.mockImplementation((_params, _success, failure) => failure(error));

    scope.onExtendSuccess('Renewed');

    expect(growl.error).toHaveBeenCalledWith('app.public.common.unexpected_error_occurred');
    expect(log).toHaveBeenCalledWith(error);
    expect(scope.subscription.id).toBe(2);
    expect(scope.user.invoices).toEqual([{ id: 1 }]);
    log.mockRestore();
  });
});
