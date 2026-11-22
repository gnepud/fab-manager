import angular from 'angular';
import 'angular-ui-tour';
import fs from 'fs';
import path from 'path';
import { waitFor } from '@testing-library/react';

describe('Welcome tour visibility', () => {
  let injector;
  let scope;
  let template;
  let tour;
  let modal;
  let mobile;
  let zeroTargets;

  const readTemplate = name => fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates', name), 'utf8');
  const menuSteps = ['home', 'calendar', 'machines', 'spaces', 'trainings', 'events', 'projects', 'plans', 'admin'];
  const desktopSteps = ['welcome', ...menuSteps, 'about', 'notifications', 'profile', 'news', 'customize', 'version', 'conclusion'];

  beforeAll(() => {
    const module = angular.module('homeMobileTourTest', ['bm.uiTour'])
      .value('$rootElement', angular.element(document.body))
      .filter('translate', () => key => key)
      .config(['TourConfigProvider', function (TourConfigProvider) {
        TourConfigProvider.set('scrollIntoView', false);
      }]);
    Application.Controllers = module;
    Application.Services = module;
    Application.Directives = module;
    require('../../../app/frontend/src/javascript/controllers/home');
    require('../../../app/frontend/src/javascript/controllers/main_nav');
    require('../../../app/frontend/src/javascript/directives/compile');
    require('../../../app/frontend/src/javascript/services/help');
  });

  beforeEach(() => {
    mobile = true;
    zeroTargets = new Set();
    jest.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(function () {
      const hidden = zeroTargets.has(this) || (mobile && this.closest('.hidden-xs, .app-generator'));
      const width = hidden ? 0 : 120;
      const height = hidden ? 0 : 30;
      return { x: 20, y: 100, left: 20, top: 100, width, height, right: 20 + width, bottom: 100 + height };
    });
    modal = { open: jest.fn() };
    const authorized = roles => (Array.isArray(roles) ? roles : [roles]).includes('admin');
    angular.module('homeMobileTourDependencies', [])
      .value('$uibModal', modal)
      .value('$state', { current: { name: 'app.public.home' } })
      .value('AuthService', { isAuthorized: authorized });
    injector = angular.injector(['ng', 'homeMobileTourDependencies', 'homeMobileTourTest']);
    scope = injector.get('$rootScope').$new();
    scope.$root.modules = { publicAgenda: true, machines: true, trainings: true, spaces: true, plans: true };
    scope.currentUser = { id: 1, role: 'admin', profile_attributes: { tours: [] } };
    scope.settings = { publicRegistrations: false };
    scope.isAuthorized = authorized;
    scope.isAuthenticated = () => true;
    const settings = { home_content: '<div id="news"></div>', home_blogpost: true, feature_tour_display: 'manual' };
    injector.get('$controller')('MainNavController', { $scope: scope, settingsPromise: settings });
    injector.get('$controller')('HomeController', {
      $scope: scope,
      $transition$: { params: () => ({}) },
      $translatePartialLoader: {},
      settingsPromise: settings,
      Member: { completeTour: jest.fn((_params, _body, callback) => callback({ tours: ['welcome'] })) },
      _t: key => key
    });
    injector.get('$templateCache').put('/shared/tour-step-template.html', readTemplate('shared/tour-step-template.html'));
    template = angular.element('<div></div>');
    template.html('<header class="navbar header">' + readTemplate('shared/header.html.erb').replace(/<%[\s\S]*?%>/g, '') + '</header>' +
      readTemplate('shared/leftnav.html') + readTemplate('home.html') +
      '<div class="app-generator"><span class="app-version">Version</span></div>');
    document.body.appendChild(template[0]);
    injector.get('$compile')(template)(scope);
    scope.$digest();
    tour = injector.get('uiTourService').getTourByName('welcome');
  });

  afterEach(async () => {
    await tour.end();
    scope.$destroy();
    template.remove();
    document.querySelectorAll('.ui-tour-popup').forEach(popup => popup.remove());
    jest.restoreAllMocks();
  });

  const registerSteps = () => {
    jest.useFakeTimers();
    try {
      scope.setupHomeTour();
      jest.advanceTimersByTime(1000);
    } finally {
      jest.useRealTimers();
    }
  };

  const expectPopup = async id => {
    await waitFor(() => expect(tour.getCurrentStep()?.stepId).toBe(id));
    await waitFor(() => expect(tour.getCurrentStep().popup[0].style.visibility).toBe('visible'));
    expect(tour.getCurrentStep().popup[0].isConnected).toBe(true);
    expect(tour.getCurrentStep().popup[0].querySelector('[ng-click="tour.end()"]')).not.toBeNull();
  };

  const startFromHelp = async () => {
    injector.get('Help')(new KeyboardEvent('keydown', { key: 'F1', cancelable: true }));
    const options = modal.open.mock.calls[0][0];
    const modalScope = {};
    injector.invoke(options.controller, null, {
      $scope: modalScope,
      $uibModalInstance: { close: jest.fn() },
      tourName: options.resolve.tourName()
    });
    modalScope.onTour();
    await expectPopup('welcome');
  };

  const next = async id => {
    tour.getCurrentStep().popup[0].querySelector('[ng-click="tour.next()"]').click();
    await expectPopup(id);
  };

  test('closed mobile navigation skips hidden menu/header/footer targets and Next reaches visible Home content', async () => {
    registerSteps();
    for (const id of [...menuSteps, 'about', 'notifications', 'profile', 'version']) expect(tour.hasStep(id)).toBe(false);
    await startFromHelp();
    for (const id of ['news', 'customize', 'conclusion']) await next(id);
  });

  test('desktop retains every visible step in its original order and Next remains usable', async () => {
    mobile = false;
    registerSteps();
    for (const id of desktopSteps) expect(tour.hasStep(id)).toBe(true);
    await startFromHelp();
    for (const id of desktopSteps.slice(1)) await next(id);
  });

  test('missing targets leave the orphan steps navigable even when no content is available', async () => {
    template[0].querySelectorAll('.nav-primary, .navbar.header, .app-generator, news').forEach(node => node.remove());
    registerSteps();
    for (const id of desktopSteps.filter(id => !['welcome', 'customize', 'conclusion'].includes(id))) expect(tour.hasStep(id)).toBe(false);
    await startFromHelp();
    await next('customize');
    await next('conclusion');
  });

  test('a visibility-hidden target is skipped even when it has nonzero dimensions', () => {
    mobile = false;
    template[0].querySelector('.nav-primary li.home-link').style.visibility = 'hidden';
    registerSteps();
    expect(tour.hasStep('home')).toBe(false);
    expect(tour.hasStep('calendar')).toBe(true);
  });

  test('a zero-size target is skipped without dropping other desktop steps', () => {
    mobile = false;
    zeroTargets.add(template[0].querySelector('.nav-primary li.reserve-machine-link'));
    registerSteps();
    expect(tour.hasStep('machines')).toBe(false);
    expect(tour.hasStep('home')).toBe(true);
  });
});
