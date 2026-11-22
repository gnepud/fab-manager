import angular from 'angular';
import fs from 'fs';
import path from 'path';
import React from 'react';
import { render, cleanup, waitFor, act } from '@testing-library/react';
import 'angular-ui-bootstrap';
import { react2angular } from 'react2angular';
import { Trainings } from '../../../app/frontend/src/javascript/components/trainings/trainings';
import TrainingAPI from '../../../app/frontend/src/javascript/api/training';
import MachineAPI from '../../../app/frontend/src/javascript/api/machine';

jest.mock('../../../app/frontend/src/javascript/api/training');
jest.mock('../../../app/frontend/src/javascript/api/machine');

describe('admin trainings tour', () => {
  let scope;
  let steps;
  let handlers;
  let template;
  let compile;

  beforeAll(() => {
    Application.Controllers = angular.module('trainingsTourTest', ['ui.bootstrap'])
      .filter('translate', () => key => key)
      .component('trainings', react2angular(Trainings, ['onError', 'onSuccess']));
    require('../../../app/frontend/src/javascript/controllers/admin/trainings');
  });

  beforeEach(async () => {
    TrainingAPI.index.mockResolvedValue([]);
    MachineAPI.index.mockResolvedValue([]);
    steps = [];
    handlers = {};
    template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/trainings/index.html'), 'utf8');
    document.body.appendChild(template);
    render(<Trainings onError={jest.fn()} onSuccess={jest.fn()} />, { container: template.querySelector('trainings') });
    await waitFor(() => expect(TrainingAPI.index).toHaveBeenCalled());
    const injector = angular.injector(['ng', 'trainingsTourTest']);
    compile = injector.get('$compile');
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, profile_attributes: { tours: [] } };
    injector.get('$controller')('TrainingsAdminController', {
      $scope: scope,
      $state: {},
      $uibModal: {},
      Training: {},
      trainingsPromise: [],
      machinesPromise: [],
      settingsPromise: { feature_tour_display: 'manual' },
      _t: key => key,
      Member: {},
      uiTourService: {
        getTourByName: () => ({
          createStep: step => steps.push(step),
          on: (event, handler) => { handlers[event] = handler; }
        })
      },
      growl: {},
      dialogs: {},
      $uiRouter: {}
    });
    scope.setupTrainingsTour();
  });

  afterEach(() => {
    cleanup();
    scope.$destroy();
    template.remove();
  });

  test('every step targets an element in the real page template', () => {
    expect(steps.length).toBeGreaterThan(2);
    expect(steps.filter(step => !document.querySelector(step.selector)).map(step => step.selector)).toEqual([]);
  });

  test('tracking activates the monitoring tab', () => {
    handlers.stepChanged(steps.find(step => step.stepId === 'tracking'));
    const monitoringTab = template.querySelector('uib-tab.post-tracking');
    expect(scope.tabs.active).toBe(Number(monitoringTab.getAttribute('index')));
  });

  test('Previous preserves the tour target while remounting and refreshing the trainings list', async () => {
    cleanup();
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/trainings/index.html'), 'utf8');
    await act(async () => {
      compile(template)(scope);
      scope.$digest();
    });
    const filter = steps.find(step => step.stepId === 'filter');
    const target = document.querySelector(filter.selector);
    const originalFilter = document.querySelector('.trainings-monitoring .filter');
    const originalRequests = TrainingAPI.index.mock.calls.length;
    expect(target).not.toBeNull();

    await act(async () => {
      handlers.stepChanged(steps.find(step => step.stepId === 'tracking'));
      scope.$digest();
    });
    expect(scope.tabs.active).toBe(2);
    expect(originalFilter.isConnected).toBe(false);
    expect(target.isConnected).toBe(true);

    await act(async () => {
      handlers.stepChanged(filter);
      scope.$digest();
    });
    expect(scope.tabs.active).toBe(0);
    expect(document.querySelector(filter.selector)).toBe(target);
    expect(target.isConnected).toBe(true);
    expect(target.closest('.tab-pane')).toBe(template.querySelector('.tab-pane.active'));
    expect(document.querySelector('.trainings-monitoring .filter')).not.toBe(originalFilter);
    expect(TrainingAPI.index.mock.calls.length).toBeGreaterThan(originalRequests);
  });
});
