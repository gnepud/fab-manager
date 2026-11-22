import angular from 'angular';

describe('Help service', () => {
  let help;
  let modal;
  let state;
  let authorized;
  let openGuide;

  beforeAll(() => {
    Application.Services = angular.module('helpServiceTest', []);
    require('../../../app/frontend/src/javascript/services/help');
  });

  beforeEach(() => {
    modal = { open: jest.fn() };
    state = { current: { name: 'app.admin.machines_list' } };
    authorized = { isAuthorized: jest.fn(() => true) };
    angular.module('helpServiceDependencies', [])
      .value('$uibModal', modal)
      .value('$state', state)
      .value('AuthService', authorized);
    help = angular.injector(['ng', 'helpServiceDependencies', 'helpServiceTest']).get('Help');
    openGuide = jest.spyOn(window, 'open').mockImplementation(() => {});
  });

  afterEach(() => jest.restoreAllMocks());

  test('offers the machines tour to authorized users', () => {
    const event = new KeyboardEvent('keydown', { key: 'F1', cancelable: true });
    help(event);
    expect(event.defaultPrevented).toBe(true);
    expect(modal.open).toHaveBeenCalledTimes(1);
    expect(openGuide).not.toHaveBeenCalled();
    const options = modal.open.mock.calls[0][0];
    expect(options.templateUrl).toBe('/shared/help_modal.html');
    expect(options.resolve.tourName()).toBe('machines');
    const scope = {};
    const instance = { close: jest.fn() };
    const tour = { start: jest.fn() };
    const tours = { getTourByName: jest.fn(() => tour) };
    options.controller[options.controller.length - 1](scope, instance, tours, options.resolve.tourName());
    scope.onTour();
    expect(tours.getTourByName).toHaveBeenCalledWith('machines');
    expect(tour.start).toHaveBeenCalledTimes(1);
    expect(instance.close).toHaveBeenCalledWith('tour');
  });

  test('ignores unauthorized users', () => {
    authorized.isAuthorized.mockReturnValue(false);
    help(new KeyboardEvent('keydown', { key: 'F1' }));
    expect(modal.open).not.toHaveBeenCalled();
    expect(openGuide).not.toHaveBeenCalled();
  });

  test('ignores other keys', () => {
    help(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(modal.open).not.toHaveBeenCalled();
    expect(openGuide).not.toHaveBeenCalled();
  });

  test('opens the guide on pages without a tour', () => {
    state.current.name = 'app.admin.machines_edit';
    help(new KeyboardEvent('keydown', { key: 'F1' }));
    expect(modal.open).not.toHaveBeenCalled();
    expect(openGuide).toHaveBeenCalledWith('http://guide-fr.fab.mn', '_blank');
  });
});
