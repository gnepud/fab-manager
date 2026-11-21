import angular from 'angular';
import moment from 'moment';
import fs from 'fs';
import path from 'path';
import lodash from 'lodash';

describe('event booking overlap warning', () => {
  let scope, modal, member;

  beforeAll(() => {
    Application.Controllers = angular.module('eventOverlapTest', []);
    const source = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/controllers/events.js.erb'), 'utf8')
      .replace(/<%=.*?%>/g, '');
    new Function('Application', 'angular', 'moment', '_', source)(Application, angular, moment, lodash);
    moment.suppressDeprecationWarnings = true;
  });

  afterAll(() => { moment.suppressDeprecationWarnings = false; });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'eventOverlapTest']);
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, role: 'member' };
    scope.isAuthenticated = () => true;
    member = { machine_reservations: [], training_reservations: [], space_reservations: [], events_reservations: [] };
    modal = { open: jest.fn(() => ({ result: { then: jest.fn() } })) };
    injector.get('$controller')('ShowEventController', {
      $scope: scope, $state: {}, $rootScope: {}, Event: {}, $uibModal: modal,
      Member: { get: (params, success) => success(member) },
      Reservation: { query: () => ({ $promise: new Promise(() => {}) }) },
      Price: {}, CustomAsset: {}, SlotsReservation: {},
      eventPromise: {
        id: 42, nb_total_places: 5, nb_free_places: 5, event_type: 'standard',
        start_date: '2027-12-04', end_date: '2027-12-04', start_time: '10:30', end_time: '11:30',
        availability: { start_at: '2027-12-04T10:30:00+01:00', end_at: '2027-12-04T11:30:00+01:00' },
        event_price_categories_attributes: []
      },
      growl: {}, _t: key => key, Wallet: {}, AuthService: { isAuthorized: () => false },
      helpers: {}, dialogs: {}, priceCategoriesPromise: [], settingsPromise: {}, LocalPayment: {}, Child: {}
    });
  });

  afterEach(() => scope.$destroy());

  function reservation (start, end) {
    return { reservable_type: 'Machine', start_at: `2027-12-04T${start}:00+01:00`, end_at: `2027-12-04T${end}:00+01:00` };
  }

  test.each([['10:00', '11:00'], ['10:30', '11:30']])('warns for reservation %s–%s', (start, end) => {
    const booking = reservation(start, end);
    member.machine_reservations = [booking];
    scope.reserveEvent();
    expect(modal.open).toHaveBeenCalledTimes(1);
    const options = modal.open.mock.calls[0][0];
    expect(options.controller).toBe('ReserveSlotSameTimeController');
    expect(options.resolve.sameTimeReservations()).toEqual([booking]);
    expect(scope.reserve.toReserve).toBe(false);
  });

  test.each([['09:00', '10:30'], ['11:30', '12:30']])('does not warn for adjacent reservation %s–%s', (start, end) => {
    member.machine_reservations = [reservation(start, end)];
    scope.reserveEvent();
    expect(modal.open).not.toHaveBeenCalled();
    expect(scope.reserve.toReserve).toBe(true);
  });

  test.each([
    ['09:00', '11:00', true],
    ['09:00', '12:00', true],
    ['10:00', '12:00', true],
    ['11:00', '12:00', false]
  ])('checks event %s–%s against reservation 10:00–11:00', (start, end, overlaps) => {
    scope.event.availability.start_at = `2027-12-04T${start}:00+01:00`;
    scope.event.availability.end_at = `2027-12-04T${end}:00+01:00`;
    member.machine_reservations = [reservation('10:00', '11:00')];
    scope.reserveEvent();
    expect(modal.open).toHaveBeenCalledTimes(overlaps ? 1 : 0);
    expect(scope.reserve.toReserve).toBe(!overlaps);
  });

  test('allows booking without existing reservations', () => {
    scope.reserveEvent();
    expect(modal.open).not.toHaveBeenCalled();
    expect(scope.reserve.toReserve).toBe(true);
  });

  test('ignores a reservation for this same event', () => {
    member.events_reservations = [{ ...reservation('10:30', '11:30'), reservable_type: 'Event', reservable: { id: 42 } }];
    scope.reserveEvent();
    expect(modal.open).not.toHaveBeenCalled();
    expect(scope.reserve.toReserve).toBe(true);
  });
});
