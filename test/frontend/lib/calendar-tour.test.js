import angular from 'angular';
import moment from 'moment';
import $ from 'jquery';

describe('admin calendar tour', () => {
  let scope;
  let steps;

  beforeAll(() => {
    Application.Controllers = angular.module('calendarTourTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/calendar');
    global.$ = $;
    global._ = { groupBy: jest.fn(() => ({})), forIn: jest.fn() };
  });

  afterAll(() => {
    delete global.$;
    delete global._;
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'calendarTourTest']);
    scope = injector.get('$rootScope').$new();
    steps = [];
    injector.get('$controller')('AdminCalendarController', {
      $scope: scope,
      $state: {},
      $uibModal: {},
      moment,
      AuthService: { isAuthorized: () => true },
      Availability: {},
      SlotsReservation: {},
      Setting: {},
      Export: {},
      growl: {},
      dialogs: {},
      bookingWindowStart: { setting: { value: '2000-01-01T08:00:00' } },
      bookingWindowEnd: { setting: { value: '2000-01-01T18:00:00' } },
      machinesPromise: [],
      plansPromise: [],
      groupsPromise: [],
      settingsPromise: { feature_tour_display: 'manual', slot_duration: '60' },
      _t: key => key,
      uiCalendarConfig: {},
      CalendarConfig: config => config,
      Member: {},
      uiTourService: { getTourByName: () => ({ createStep: step => steps.push(step), on: jest.fn() }) },
      trainingsPromise: [],
      spacesPromise: [],
      machineCategoriesPromise: [],
      $aside: {}
    });
    scope.setupCalendarTour();
  });

  afterEach(() => scope.$destroy());

  test('places the full-width agenda tooltip above the calendar, not outside its right edge', () => {
    expect(steps.find(step => step.stepId === 'agenda')).toMatchObject({
      selector: '.admin-calendar .fc-view-container',
      placement: 'top'
    });
  });
});
