Application.Controllers = { controller: jest.fn() };
require('../../../app/frontend/src/javascript/controllers/admin/members');

const definition = Application.Controllers.controller.mock.calls.find(([name]) => name === 'EditMemberController')[1];

describe('manager member edit authorization', () => {
  test.each(['admin', 'manager'])('refuses another %s before initializing the form', role => {
    const scope = { currentUser: { id: 5, role: 'manager' } };
    const dependencies = {
      $scope: scope,
      $transition$: { params: () => ({ id: 1 }) },
      memberPromise: { id: 1, role, can_update: false }
    };

    definition[definition.length - 1](...definition.slice(0, -1).map(name => dependencies[name]));

    expect(scope.canEditMember).toBe(false);
    expect(scope.password).toBeUndefined();
  });
});
