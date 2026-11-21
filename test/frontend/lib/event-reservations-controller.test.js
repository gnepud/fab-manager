import angular from 'angular';
import _ from 'lodash';

describe('ShowEventReservationsController', () => {
  let scope;

  beforeAll(() => {
    global._ = _;
    Application.Controllers = angular.module('eventReservationsControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/events');
  });

  beforeEach(() => {
    scope = {};
    angular.injector(['ng', 'eventReservationsControllerTest']).get('$controller')('ShowEventReservationsController', {
      $scope: scope,
      eventPromise: { amount: 10, event_price_categories_attributes: [{ id: 2, amount: 5 }] },
      reservationsPromise: [],
      dialogs: {},
      SlotsReservation: {},
      growl: {},
      _t: jest.fn(),
      Price: {},
      Wallet: {},
      $uibModal: {},
      Event: {}
    });
  });

  test.each([
    ['standard seats without named attendees', 2, [], [], 20],
    ['category seats without named attendees', 0, [{ booked: 2, event_price_category: { id: 2 } }], [], 10],
    ['mixed seats', 1, [{ booked: 2, event_price_category: { id: 2 } }], [], 20],
    ['named attendees without double counting', 1, [{ booked: 1, event_price_category: { id: 2 } }], [{ event_price_category_id: null }, { event_price_category_id: 2 }], 15],
    ['empty reservation', 0, [], [], 0],
    ['unknown price category', 1, [{ booked: 1, event_price_category: { id: 99 } }], [], 10]
  ])('calculates %s', (name, places, tickets, users, expected) => {
    expect(scope.reservationAmount({
      nb_reserve_places: places,
      tickets_attributes: tickets,
      booking_users_attributes: users
    })).toBe(expected);
  });

  test('keeps a free event free', () => {
    scope.event.amount = 0;
    expect(scope.reservationAmount({ nb_reserve_places: 1, tickets_attributes: [], booking_users_attributes: [] })).toBe(0);
  });
});
