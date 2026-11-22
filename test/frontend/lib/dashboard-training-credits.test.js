import angular from 'angular';
import fs from 'fs';
import path from 'path';

describe('dashboard training credits', () => {
  let scope;
  let element;

  beforeAll(() => {
    Application.Controllers = angular.module('dashboardTrainingCreditsTest', [])
      .value('$rootElement', angular.element(document.body))
      .filter('translate', () => value => value)
      .filter('trainingReservationsFilter', () => value => value)
      .filter('amDateFormat', () => value => value);
    require('../../../app/frontend/src/javascript/controllers/dashboard');
  });

  afterEach(() => {
    scope.$destroy();
    element.remove();
  });

  function render (usedCredits = [], allowance = 3, eligibleTrainingIds = [1]) {
    const member = {
      profile_attributes: {},
      training_credits: usedCredits.map(trainingId => ({ training_id: trainingId })),
      subscribed_plan: {
        training_credit_nb: allowance,
        training_credits: eligibleTrainingIds.map(trainingId => ({ training_id: trainingId }))
      },
      training_reservations: [],
      trainings: []
    };
    const injector = angular.injector(['ng', 'dashboardTrainingCreditsTest']);
    scope = injector.get('$rootScope').$new();
    injector.get('$templateCache').put('/dashboard/nav.html', '');
    injector.get('$controller')('DashboardController', {
      $scope: scope,
      memberPromise: member,
      trainingsPromise: [
        { id: 1, name: 'Laser training', disabled: false },
        { id: 2, name: 'CNC training', disabled: false },
        { id: 3, name: 'Disabled training', disabled: true }
      ],
      SocialNetworks: [],
      growl: {},
      proofOfIdentityTypesPromise: []
    });
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/dashboard/trainings.html'), 'utf8');
    element = injector.get('$compile')(template)(scope);
    document.body.appendChild(element[0]);
    scope.$digest();
  }

  function bookingButtons () {
    return Array.from(element[0].querySelectorAll('button[ui-sref]')).filter(button => !button.closest('.ng-hide'));
  }

  test('shows an eligible training before any credits have been used', () => {
    render();

    expect(bookingButtons()).toHaveLength(1);
    expect(bookingButtons()[0].parentElement.textContent).toContain('Laser training');
  });

  test.each([1, 2])('keeps the same training bookable after %i previous bookings', usedCredits => {
    render(Array(usedCredits).fill(1));

    expect(bookingButtons()).toHaveLength(1);
    expect(bookingButtons()[0].parentElement.textContent).toContain('Laser training');
  });

  test('hides the credit panel when the total allowance is exhausted', () => {
    render([1, 1, 1]);

    expect(bookingButtons()).toHaveLength(0);
  });

  test('credits used on another training reduce the same shared allowance', () => {
    render([2, 2, 2]);

    expect(bookingButtons()).toHaveLength(0);
  });

  test('all eligible active trainings remain bookable while the shared allowance remains', () => {
    render([2], 3, [1, 2]);

    expect(bookingButtons()).toHaveLength(2);
  });

  test('still hides disabled trainings', () => {
    render([1], 3, [1, 3]);

    expect(bookingButtons()).toHaveLength(1);
    expect(bookingButtons()[0].parentElement.textContent).toContain('Laser training');
  });

  test('a plan with no training credits has no credit booking options', () => {
    render([], 0);

    expect(bookingButtons()).toHaveLength(0);
  });

  test('a plan without eligible trainings has no credit booking options', () => {
    render([], 3, []);

    expect(bookingButtons()).toHaveLength(0);
  });

  test('a member without a subscribed plan has no credit booking options', () => {
    render();
    scope.user.subscribed_plan = null;
    scope.$digest();

    expect(bookingButtons()).toHaveLength(0);
  });
});
