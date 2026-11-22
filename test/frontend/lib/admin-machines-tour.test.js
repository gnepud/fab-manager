import angular from 'angular';
import 'angular-ui-tour';
import fs from 'fs';
import path from 'path';
import React from 'react';
import { cleanup, render, waitFor } from '@testing-library/react';
import { MachineCard } from '../../../app/frontend/src/javascript/components/machines/machine-card';
import SettingAPI from '../../../app/frontend/src/javascript/api/setting';

jest.mock('../../../app/frontend/src/javascript/api/setting');
jest.mock('../../../app/frontend/src/javascript/components/prepaid-packs/propose-packs-modal', () => ({ ProposePacksModal: () => null }));

describe('admin machines tour targets', () => {
  let scope;
  let template;
  let tour;

  beforeAll(() => {
    Application.Controllers = angular.module('adminMachinesTourTest', ['bm.uiTour'])
      .value('$rootElement', angular.element(document.body))
      .filter('translate', () => key => key)
      .config(['TourConfigProvider', function (TourConfigProvider) {
        TourConfigProvider.set('scrollIntoView', false);
      }]);
    require('../../../app/frontend/src/javascript/controllers/admin/machines');
  });

  beforeEach(() => {
    SettingAPI.get.mockResolvedValue({ value: 'true' });
    const injector = angular.injector(['ng', 'adminMachinesTourTest']);
    injector.get('$templateCache').put('/shared/tour-step-template.html', fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/shared/tour-step-template.html'), 'utf8'));
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, role: 'admin', profile_attributes: { tours: [] } };
    scope.isAuthorized = role => Array.isArray(role) ? role.includes(scope.currentUser.role) : scope.currentUser.role === role;
    const tours = injector.get('uiTourService');
    injector.get('$controller')('AdminMachinesController', {
      $scope: scope,
      CSRF: { setMetaTags: jest.fn() },
      growl: {},
      $state: {},
      _t: key => key,
      AuthService: { isAuthorized: scope.isAuthorized },
      settingsPromise: { feature_tour_display: 'manual' },
      Member: { completeTour: jest.fn((_params, _body, callback) => callback({ tours: ['machines'] })) },
      uiTourService: tours,
      machinesPromise: [{ id: 1, disabled: true, reservable: true }],
      helpers: {},
      $uiRouter: {}
    });
    template = angular.element(fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/machines/machines.html'), 'utf8'));
    document.body.appendChild(template[0]);
    injector.get('$compile')(template)(scope);
    scope.$digest();
    scope.setupMachinesTour();
    tour = tours.getTourByName('machines');
  });

  afterEach(() => {
    cleanup();
    scope.$destroy();
    template.remove();
    document.querySelectorAll('.ui-tour-popup').forEach(popup => popup.remove());
  });

  const showMachines = machines => {
    const view = render(<div className="machines-list">{machines.map(machine => (
      <MachineCard key={machine.id} machine={machine} user={scope.currentUser}
        onError={jest.fn()} onSuccess={jest.fn()} onShowMachine={jest.fn()}
        onReserveMachine={jest.fn()} onLoginRequested={jest.fn()} onEnrollRequested={jest.fn()}
        canProposePacks={false} />
    ))}</div>, { container: template[0].querySelector('machines-list') });
    scope.$digest();
    return view;
  };

  test.each([
    ['empty or still loading list', []],
    ['non-reservable active machine', [{ id: 2, disabled: false, reservable: false }]],
    ['disabled machine', [{ id: 3, disabled: true, reservable: true }]]
  ])('does not register a reserve step for: %s', (_name, machines) => {
    showMachines(machines);
    expect(template[0].querySelector('.reserve-button')).toBeNull();
    expect(tour.hasStep('reserve')).toBe(false);
  });

  test('adds the reserve step after a bookable machine is rendered, and removes it when filters hide it', () => {
    expect(tour.hasStep('reserve')).toBe(false);
    showMachines([{ id: 4, disabled: false, reservable: true }]);
    expect(template[0].querySelector('.reserve-button')).not.toBeNull();
    expect(tour.hasStep('reserve')).toBe(true);
    cleanup();
    showMachines([{ id: 5, disabled: false, reservable: false }]);
    expect(tour.hasStep('reserve')).toBe(false);
  });

  test('only registers the view step when a card is rendered and the user is an admin', () => {
    expect(tour.hasStep('view')).toBe(false);
    showMachines([{ id: 2, disabled: false, reservable: false }]);
    expect(tour.hasStep('view')).toBe(true);
    scope.currentUser.role = 'manager';
    scope.$digest();
    expect(tour.hasStep('view')).toBe(false);
  });

  test('the directive keeps its element writable so selector-based steps can replace it', () => {
    for (const element of template[0].querySelectorAll('[tour-step]')) {
      const step = angular.element(element).scope().tourStep;
      expect(Object.getOwnPropertyDescriptor(step, 'element').writable).toBe(true);
    }
  });

  test.each([
    ['empty list', [], ['welcome', 'conclusion']],
    ['bookable machine', [{ id: 4, disabled: false, reservable: true }], ['welcome', 'view', 'reserve', 'conclusion']]
  ])('navigates only the available steps for: %s', async (_name, machines, expectedSteps) => {
    showMachines(machines);
    await tour.start();
    expect(tour.getCurrentStep().stepId).toBe(expectedSteps[0]);
    await waitFor(() => expect(tour.getCurrentStep().popup[0].style.visibility).toBe('visible'));
    for (const step of expectedSteps.slice(1)) {
      await tour.next();
      expect(tour.getCurrentStep().stepId).toBe(step);
      expect(tour.getCurrentStep().element[0]).toBe(document.querySelector(tour.getCurrentStep().selector));
      await waitFor(() => expect(tour.getCurrentStep().popup[0].style.visibility).toBe('visible'));
    }
    await tour.end();
  });
});
