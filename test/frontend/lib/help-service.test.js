import angular from 'angular';
import 'angular-ui-tour';

describe('Help service', () => {
  let help;
  let modal;
  let state;
  let authorized;
  let openGuide;
  let tours;
  let modalOpened;
  let modalResult;
  let instance;
  let openApiTour;

  beforeAll(() => {
    Application.Services = angular.module('helpServiceTest', ['bm.uiTour'])
      .value('$rootElement', angular.element(document.body));
    require('../../../app/frontend/src/javascript/services/help');
  });

  beforeEach(() => {
    modal = { open: jest.fn() };
    state = { current: { name: 'app.admin.machines_list' } };
    authorized = { isAuthorized: jest.fn(() => true) };
    tours = { getTourByName: jest.fn(() => ({ start: jest.fn(), getStatus: () => 0, Status: { ON: 1 } })) };
    const tourInjector = angular.injector(['ng', 'helpServiceTest']);
    openApiTour = tourInjector.get('uiTourService').createDetachedTour('open-api');
    openApiTour.createStep({ selector: 'body', orphan: true });
    jest.spyOn(openApiTour, 'showStep').mockResolvedValue();
    angular.module('helpServiceDependencies', [])
      .value('$uibModal', modal)
      .value('$state', state)
      .value('uiTourService', tours)
      .value('AuthService', authorized);
    const injector = angular.injector(['ng', 'helpServiceTest', 'helpServiceDependencies']);
    help = injector.get('Help');
    const $q = injector.get('$q');
    modalOpened = $q.defer();
    modalResult = $q.defer();
    instance = {
      opened: modalOpened.promise,
      result: modalResult.promise,
      close: jest.fn(reason => modalResult.resolve(reason))
    };
    modal.open.mockReturnValue(instance);
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
    const tour = { start: jest.fn(), getStatus: () => 0, Status: { ON: 1 } };
    const tours = { getTourByName: jest.fn(() => tour) };
    options.controller[options.controller.length - 1](scope, instance, tours, options.resolve.tourName());
    scope.onTour();
    expect(tours.getTourByName).toHaveBeenCalledWith('machines');
    expect(tour.start).toHaveBeenCalledTimes(1);
    expect(instance.close).toHaveBeenCalledWith('tour');
  });

  test('does not open Help while the Open API tour is already active', async () => {
    state.current.name = 'app.admin.open_api_clients';
    tours.getTourByName.mockReturnValue(openApiTour);
    await openApiTour.start();

    const event = new KeyboardEvent('keydown', { key: 'F1', cancelable: true });
    help(event);

    expect(event.defaultPrevented).toBe(true);
    expect(modal.open).not.toHaveBeenCalled();
    expect(openGuide).not.toHaveBeenCalled();
  });

  test.each([true, false])('closes Help when the Open API tour auto-starts (modal ready: %s)', async modalReady => {
    state.current.name = 'app.admin.open_api_clients';
    tours.getTourByName.mockReturnValue(openApiTour);

    help(new KeyboardEvent('keydown', { key: 'F1' }));
    expect(modal.open).toHaveBeenCalledTimes(1);
    if (modalReady) {
      modalOpened.resolve();
      await modalOpened.promise;
    }

    await openApiTour.start();
    if (!modalReady) modalOpened.resolve();
    await modalOpened.promise;

    expect(instance.close).toHaveBeenCalledTimes(1);
    expect(openApiTour.showStep).toHaveBeenCalledTimes(1);
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

  test.each(['Settings', 'Machine Categories'])('opens the guide when the machines tour is unregistered on the %s tab', () => {
    tours.getTourByName.mockReturnValue(undefined);
    help(new KeyboardEvent('keydown', { key: 'F1' }));
    expect(tours.getTourByName).toHaveBeenCalledWith('machines');
    expect(modal.open).not.toHaveBeenCalled();
    expect(openGuide).toHaveBeenCalledWith('http://guide-fr.fab.mn', '_blank');
  });
});
