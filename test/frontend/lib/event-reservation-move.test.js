import angular from 'angular';
import moment from 'moment';
import fs from 'fs';
import path from 'path';

describe('event reservation move modal', () => {
  let scope;
  let modalScope;
  let reservationApi;
  let instance;

  beforeEach(() => {
    const controllers = {};
    const source = fs.readFileSync(path.resolve('app/frontend/src/javascript/controllers/events.js.erb'), 'utf8')
      .replace(/<%=[\s\S]*?%>/g, '');
    // The controller contains server-rendered month names, unused by this modal.
    new Function('Application', 'angular', 'moment', source)({
      Controllers: { controller: (name, definition) => { controllers[name] = definition; } }
    }, angular, moment);
    const injector = angular.injector(['ng']);
    scope = injector.get('$rootScope').$new();
    modalScope = scope.$new();
    reservationApi = { update: jest.fn() };
    instance = { close: jest.fn(), dismiss: jest.fn() };
    const reservation = { id: 1, total_booked_seats: 2, slots_reservations_attributes: [{ id: 3, slot_id: 4 }] };
    const event = {
      end_date: '2027-01-10', end_time: '16:00',
      nb_free_places: 4, event_price_categories_attributes: [],
      recurrence_events: [{ id: 2, slot_id: 5, nb_free_places: 6 }]
    };
    const modal = { open: jest.fn(options => {
      injector.invoke(options.controller, null, {
        $scope: modalScope, $uibModalInstance: instance, event, reservation, Reservation: reservationApi
      });
      return { result: { finally: () => ({ then: jest.fn() }) } };
    }) };
    const definition = controllers.ShowEventController;
    const locals = Object.fromEntries(definition.slice(0, -1).map(name => [name, {}]));
    Object.assign(locals, { $scope: scope, $uibModal: modal, eventPromise: event, settingsPromise: {} });
    injector.invoke(definition, null, locals);
    scope.reservations = [reservation];
    scope.modifyReservation(reservation);
  });

  test('submits the destination slot and closes on success', () => {
    modalScope.ok();
    const [params, payload, success] = reservationApi.update.mock.calls[0];
    expect(params).toEqual({ id: 1 });
    expect(payload.reservation.slots_reservations_attributes[0]).toEqual({ id: 3, slot_id: 5 });
    success({ id: 1 });
    expect(instance.close).toHaveBeenCalledWith({ id: 1 });
  });

  test('shows only validation response data and allows retry', () => {
    modalScope.ok();
    reservationApi.update.mock.calls[0][3]({
      data: { 'tickets.booked': ['must be greater than 0'] }, status: 422, config: { url: '/api/reservations/1' }
    });
    expect(modalScope.alerts).toEqual([{ msg: 'tickets.booked: must be greater than 0', type: 'danger' }]);
    expect(modalScope.attempting).toBe(false);
    expect(instance.close).not.toHaveBeenCalled();
  });

  test('handles an empty validation response', () => {
    modalScope.ok();
    reservationApi.update.mock.calls[0][3]({ data: {}, status: 422 });
    expect(modalScope.alerts).toEqual([]);
    expect(modalScope.attempting).toBe(false);
  });
});
