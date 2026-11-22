import angular from 'angular';
import moment from 'moment';
import $ from 'jquery';
import 'fullcalendar';
import fs from 'fs';
import path from 'path';

describe('admin calendar tour', () => {
  let scope;
  let steps;
  let template;

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
    template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/calendar/calendar.html'), 'utf8');
    document.body.appendChild(template);
    $(template.querySelector('[ui-calendar]')).fullCalendar({ defaultView: 'agendaWeek', height: 'auto' });
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

  afterEach(() => {
    $(template.querySelector('[ui-calendar]')).fullCalendar('destroy');
    template.remove();
    scope.$destroy();
  });

  test('anchors the agenda tooltip below the compact calendar toolbar, outside calendar-local styles', () => {
    const agenda = steps.find(step => step.stepId === 'agenda');
    expect(agenda).toMatchObject({
      selector: '.admin-calendar .fc-toolbar',
      placement: 'bottom',
      appendToBody: true
    });
    const target = template.querySelector(agenda.selector);
    expect(target).not.toBeNull();
    expect(target.querySelector('.fc-view-container')).toBeNull();
    expect(target.querySelector('.fc-today-button')).not.toBeNull();
  });
});
