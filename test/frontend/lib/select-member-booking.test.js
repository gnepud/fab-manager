Application.Directives = { directive: jest.fn() };
require('../../../app/frontend/src/javascript/directives/selectMember');

const definition = Application.Directives.directive.mock.calls.find(([name]) => name === 'selectMember')[1];

describe('booking member picker', () => {
  let scope, member, directive;

  beforeEach(() => {
    scope = {};
    member = { search: jest.fn() };
    directive = definition[definition.length - 1]({ remove: value => value }, member);
  });

  test('requests the booking filter and retains subscription filtering', () => {
    directive.link(scope, null, { booking: 'true', subscription: 'false' });
    scope.autoCompleteName('Morgan');

    expect(member.search).toHaveBeenCalledWith({ query: 'Morgan', booking: true, subscription: 'false' }, expect.any(Function), expect.any(Function));
    const matches = [{ id: 5, name: 'Morgan' }];
    member.search.mock.calls[0][1](matches);
    expect(scope.matchingMembers).toEqual(matches);
    expect(scope.isLoadingMembers).toBe(false);
  });

  test('does not restrict generic picker searches', () => {
    directive.link(scope, null, {});
    scope.autoCompleteName('Admin');

    expect(member.search.mock.calls[0][0]).toEqual({ query: 'Admin' });
  });

  test('empty queries do not search and empty matches clear the list', () => {
    directive.link(scope, null, { booking: 'true' });
    scope.autoCompleteName('');
    expect(member.search).not.toHaveBeenCalled();
    scope.autoCompleteName('Unknown');
    member.search.mock.calls[0][1]([]);
    expect(scope.matchingMembers).toEqual([]);
    expect(scope.isLoadingMembers).toBe(false);
  });

  test('keeps the existing error handler for failed booking searches', () => {
    const log = jest.spyOn(console, 'error').mockImplementation(() => {});
    directive.link(scope, null, { booking: 'true' });
    scope.autoCompleteName('Morgan');
    const error = { status: 403 };
    member.search.mock.calls[0][2](error);
    expect(log).toHaveBeenCalledWith(error);
    log.mockRestore();
  });

  test.each(['machines/reserve', 'spaces/reserve', 'trainings/reserve', 'events/show', 'plans/index'])('%s opts into booking search', template => {
    const fs = require('fs');
    const path = require('path');
    const content = fs.readFileSync(path.join(__dirname, '../../../app/frontend/templates', `${template}.html`), 'utf8');
    expect(content).toMatch(/<select-member[^>]*booking="true"/);
  });
});
