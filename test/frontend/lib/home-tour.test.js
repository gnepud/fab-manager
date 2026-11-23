import angular from 'angular';
import 'angular-ui-tour';
import fs from 'fs';
import path from 'path';
import { waitFor } from '@testing-library/react';

describe('Home tour after login without a reload', () => {
  let injector;
  let root;
  let scope;
  let template;
  let tour;
  let settings;
  let modal;

  beforeAll(() => {
    const module = angular.module('homeTourTest', ['bm.uiTour'])
      .value('$rootElement', angular.element(document.body))
      .filter('translate', () => key => key)
      .config(['TourConfigProvider', function (TourConfigProvider) {
        TourConfigProvider.set('scrollIntoView', false);
      }]);
    Application.Controllers = module;
    Application.Services = module;
    require('../../../app/frontend/src/javascript/services/session');
    require('../../../app/frontend/src/javascript/services/auth');
    require('../../../app/frontend/src/javascript/services/help');
    require('../../../app/frontend/src/javascript/controllers/home');
  });

  const publishUser = user => {
    if (user) injector.get('Session').create(user);
    else injector.get('Session').destroy();
    root.currentUser = user;
    root.$digest();
  };

  beforeEach(() => {
    modal = { open: jest.fn() };
    angular.module('homeTourDependencies', [])
      .value('$uibModal', modal)
      .value('$state', { current: { name: 'app.public.home' } });
    injector = angular.injector(['ng', 'homeTourDependencies', 'homeTourTest']);
    const $q = injector.get('$q');
    modal.open.mockImplementation(() => {
      const result = $q.defer();
      return {
        opened: $q.resolve(true),
        result: result.promise,
        close: jest.fn(value => result.resolve(value))
      };
    });
    root = injector.get('$rootScope');
    root.modules = { spaces: false };
    publishUser({ id: 1, role: 'member', profile_attributes: { tours: [] } });
    scope = root.$new();
    settings = { home_content: '<div></div>', feature_tour_display: 'once' };
    injector.get('$controller')('HomeController', {
      $scope: scope,
      $transition$: { params: () => ({}) },
      $translatePartialLoader: {},
      settingsPromise: settings,
      Member: { completeTour: jest.fn((_params, _body, callback) => callback({ tours: ['welcome'] })) },
      _t: key => key
    });
    injector.get('$templateCache').put('/shared/tour-step-template.html', fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/shared/tour-step-template.html'), 'utf8'));
    template = angular.element(fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/home.html'), 'utf8'));
    document.body.appendChild(template[0]);
    injector.get('$compile')(template)(scope);
    root.$digest();
    scope.setupHomeTour();
    tour = injector.get('uiTourService').getTourByName('welcome');
    publishUser(null);
  });

  afterEach(async () => {
    await tour.end();
    scope.$destroy();
    template.remove();
    document.querySelectorAll('.ui-tour-popup').forEach(popup => popup.remove());
  });

  const login = (role, tours = []) => publishUser({ id: 2, role, profile_attributes: { tours } });

  const expectWelcomePopup = async () => {
    await waitFor(() => expect(tour.getCurrentStep()?.stepId).toBe('welcome'));
    await waitFor(() => expect(tour.getCurrentStep().popup[0].style.visibility).toBe('visible'));
    expect(tour.getStatus()).toBe(tour.Status.ON);
  };

  const chooseTourFromHelp = () => {
    injector.get('Help')(new KeyboardEvent('keydown', { key: 'F1', cancelable: true }));
    expect(modal.open).toHaveBeenCalledTimes(1);
    const options = modal.open.mock.calls[0][0];
    const modalScope = {};
    injector.invoke(options.controller, null, {
      $scope: modalScope,
      $uibModalInstance: modal.open.mock.results[0].value,
      tourName: options.resolve.tourName()
    });
    modalScope.onTour();
  };

  test.each(['admin', 'manager'])('registers and auto-starts Welcome for a new %s after logout', async role => {
    expect(tour.hasStep('welcome')).toBe(false);
    login(role);
    expect(tour.hasStep('welcome')).toBe(true);
    expect(tour.hasStep('version')).toBe(role === 'admin');
    await expectWelcomePopup();
  });

  test('a manager can start the registered tour through F1 in manual mode', async () => {
    settings.feature_tour_display = 'manual';
    login('manager');
    expect(tour.hasStep('welcome')).toBe(true);
    expect(tour.getStatus()).toBe(tour.Status.OFF);
    chooseTourFromHelp();
    await expectWelcomePopup();
  });

  test('completed Welcome history prevents auto-start but still permits F1 for a manager', async () => {
    login('manager', ['welcome']);
    expect(tour.hasStep('welcome')).toBe(true);
    expect(tour.getStatus()).toBe(tour.Status.OFF);
    chooseTourFromHelp();
    await expectWelcomePopup();
  });

  test.each(['member', null])('does not register or start Welcome for %s', role => {
    if (role) login(role);
    expect(tour.hasStep('welcome')).toBe(false);
    expect(tour.getStatus()).toBe(tour.Status.OFF);
    expect(document.querySelector('.ui-tour-popup')).toBeNull();
  });
});
