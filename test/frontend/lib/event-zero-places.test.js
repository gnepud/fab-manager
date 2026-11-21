import angular from 'angular';
import moment from 'moment';
import fs from 'fs';
import path from 'path';
import lodash from 'lodash';

describe('event reservation places', () => {
  let scope;

  beforeAll(() => {
    Application.Controllers = angular.module('eventZeroPlacesTest', []);
    const source = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/javascript/controllers/events.js.erb'), 'utf8')
      .replace(/<%=.*?%>/g, '');
    // eslint-disable-next-line no-new-func
    new Function('Application', 'angular', 'moment', '_', source)(Application, angular, moment, lodash);
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'eventZeroPlacesTest']);
    scope = injector.get('$rootScope').$new();
    injector.get('$controller')('ShowEventController', {
      $scope: scope,
      $state: {},
      $rootScope: {},
      Event: {},
      $uibModal: {},
      Member: {},
      Reservation: {},
      Price: {},
      CustomAsset: {},
      SlotsReservation: {},
      eventPromise: {
        id: 1,
        nb_free_places: 12,
        event_type: 'family',
        amount: 0,
        end_date: '2027-01-04',
        end_time: '16:00',
        event_price_categories_attributes: [{ id: 2 }]
      },
      growl: {},
      _t: key => key,
      Wallet: {},
      AuthService: {},
      helpers: {},
      dialogs: {},
      priceCategoriesPromise: [],
      settingsPromise: {},
      LocalPayment: {},
      Child: {}
    });
    scope.computeEventAmount = jest.fn();
  });

  afterEach(() => scope.$destroy());

  test.each(['normal', '2'])('counts only selected %s tickets after selecting one then zero', (priceType) => {
    const selectPlaces = count => {
      if (priceType === 'normal') scope.reserve.nbReservePlaces = count;
      else scope.reserve.tickets[priceType] = count;
      scope.changeNbPlaces(priceType);
    };

    selectPlaces(1);
    expect(scope.reserve.totalSeats).toBe(1);
    expect(scope.reservationIsValid()).toBe(false);
    scope.reserve.bookingUsers[priceType][0].booked = { id: 1, type: 'User' };
    expect(scope.reservationIsValid()).toBe(true);

    selectPlaces(0);
    expect(scope.reserve.totalSeats).toBe(0);
    expect(scope.reservationIsValid()).toBe(false);
  });

  test.each(['family', 'nominative', 'standard'])('rejects an empty %s reservation', (eventType) => {
    scope.event.event_type = eventType;
    expect(scope.reservationIsValid()).toBe(false);
  });
});
