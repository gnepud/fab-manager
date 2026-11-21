import angular from 'angular';
import moment from 'moment';
import fs from 'fs';
import path from 'path';
import lodash from 'lodash';

describe('event reservation errors', () => {
  let scope, controller, modal, payment, reservation, growl, modalInstance;
  const fallback = 'app.shared.card_payment_modal.unexpected_error';

  beforeAll(() => {
    Application.Controllers = angular.module('eventBookingErrorsTest', []);
    const source = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/controllers/events.js.erb'), 'utf8')
      .replace(/<%=.*?%>/g, '');
    new Function('Application', 'angular', 'moment', '_', source)(Application, angular, moment, lodash);
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'eventBookingErrorsTest']);
    controller = injector.get('$controller');
    scope = injector.get('$rootScope').$new();
    scope.currentUser = { id: 1, role: 'admin' };
    modal = { open: jest.fn(() => ({ result: { finally: () => ({ then: jest.fn() }) } })) };
    payment = { confirm: jest.fn() };
    modalInstance = { close: jest.fn() };
    reservation = { query: () => ({ $promise: new Promise(() => {}) }), update: jest.fn() };
    growl = { error: jest.fn() };
    controller('ShowEventController', {
      $scope: scope, $state: {}, $rootScope: { currentUser: scope.currentUser },
      Event: {}, $uibModal: modal, Member: {}, Reservation: reservation,
      Price: {}, CustomAsset: {}, SlotsReservation: {},
      eventPromise: {
        id: 1, nb_free_places: 2, event_type: 'standard',
        end_date: '2027-01-04', end_time: '23:59',
        event_price_categories_attributes: [], availability: { slot_id: 2 },
        recurrence_events: []
      },
      growl, _t: key => key,
      Wallet: { getWalletByUser: (params, success) => success({ amount: 0 }) },
      AuthService: { isAuthorized: roles => Array.isArray(roles) },
      helpers: { getAmountToPay: () => 10 }, dialogs: {},
      priceCategoriesPromise: [], settingsPromise: {}, LocalPayment: payment, Child: {}
    });
    scope.ctrl.member = { id: 2 };
  });

  afterEach(() => scope.$destroy());

  function openPaymentModal () {
    scope.payEvent();
    const options = modal.open.mock.calls[0][0];
    const modalScope = scope.$new();
    controller(options.controller, {
      $scope: modalScope, $uibModalInstance: modalInstance, $state: {},
      reservation: {}, price: { price: 10 }, Auth: {}, LocalPayment: payment,
      wallet: { amount: 0 }, helpers: { getAmountToPay: () => 10 },
      $filter: () => value => value, coupon: null, cartItems: {}, event: scope.event
    });
    return modalScope;
  }

  test.each([
    [{ slot: ['Le créneau est déjà entièrement réservé', 'Le créneau est déjà entièrement réservé'], base: ['Réessayez plus tard'] }, 'Le créneau est déjà entièrement réservé; Réessayez plus tard'],
    [{ error: 'Booking refused' }, 'Booking refused'],
    [['Booking refused', 'Booking refused'], 'Booking refused'],
    ['Booking refused', 'Booking refused'],
    [undefined, fallback],
    [null, fallback],
    [{}, fallback],
    [{ slot: [] }, fallback],
    [{ slot: [null, 42, {}, '  '] }, fallback]
  ])('shows one readable payment alert for %j', (data, message) => {
    const modalScope = openPaymentModal();
    modalScope.ok();
    const error = payment.confirm.mock.calls[0][2];
    error({ data, status: 422, config: { method: 'POST', transformRequest: function serializeRequest () {} }, headers: () => ({}) });

    expect(modalScope.alerts).toEqual([{ msg: message, type: 'danger' }]);
    expect(modalScope.attempting).toBe(false);
  });

  test('closes the payment dialog on success without alerts', () => {
    const modalScope = openPaymentModal();
    modalScope.ok();
    payment.confirm.mock.calls[0][1]({ id: 5 });
    expect(modalInstance.close).toHaveBeenCalledWith({ id: 5 });
    expect(modalScope.alerts).toBeUndefined();
  });

  test('uses the same readable message for a free booking refusal', () => {
    scope.validReserveEvent();
    payment.confirm.mock.calls[0][2]({ data: { slot: ['Booking refused', 'Booking refused'] } });
    expect(growl.error).toHaveBeenCalledWith('Booking refused');
    expect(scope.attempting).toBe(false);
  });

  test('does not expose HTTP configuration when moving an event reservation fails', () => {
    const booking = { id: 5, slots_reservations_attributes: [{ slot_id: 2 }] };
    scope.modifyReservation(booking);
    const options = modal.open.mock.calls[0][0];
    const modalScope = scope.$new();
    controller(options.controller, {
      $scope: modalScope, $uibModalInstance: {}, event: scope.event,
      reservation: booking, Reservation: reservation
    });
    scope.event.recurrence_events = [{ id: 1, slot_id: 3 }];
    modalScope.reservation.reservable_id = 1;
    modalScope.ok();
    reservation.update.mock.calls[0][3]({ data: { slot: ['Booking refused'] }, config: { method: 'PUT' } });
    expect(modalScope.alerts).toEqual([{ msg: 'Booking refused', type: 'danger' }]);
    expect(modalScope.attempting).toBe(false);
  });
});
