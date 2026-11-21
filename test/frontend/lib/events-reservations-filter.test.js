import angular from 'angular';

describe('eventsReservationsFilter', () => {
  let filter;
  const upcoming = { start_at: '2030-01-02T10:00:00Z', end_at: '2030-01-02T12:00:00Z', canceled_at: null };
  const previous = { start_at: '2029-12-30T10:00:00Z', end_at: '2029-12-30T12:00:00Z', canceled_at: null };

  beforeAll(() => {
    Application.Filters = angular.module('eventsReservationsFilterTest', []);
    require('../../../app/frontend/src/javascript/filters/filters');
    filter = angular.injector(['ng', 'eventsReservationsFilterTest']).get('$filter')('eventsReservationsFilter');
  });

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2030-01-01T12:00:00Z'));
  });

  afterEach(() => jest.useRealTimers());

  test.each(['future', 'future_asc'])('%s excludes cancelled bookings without hiding active bookings', (scope) => {
    const cancelled = { ...upcoming, canceled_at: '2030-01-01T10:00:00Z' };
    expect(filter([previous, cancelled, upcoming], scope)).toEqual([upcoming]);
    expect(filter([cancelled], scope)).toEqual([]);
  });

  test('keeps cancelled bookings in dated history', () => {
    const cancelled = { ...previous, canceled_at: '2029-12-29T10:00:00Z' };
    expect(filter([upcoming, previous, cancelled], 'passed')).toEqual([previous, cancelled]);
  });

  test('preserves ascending ordering and availability dates', () => {
    const later = { availability: { start_at: '2030-01-03T10:00:00Z', end_at: '2030-01-03T12:00:00Z' } };
    expect(filter([later, upcoming], 'future_asc')).toEqual([upcoming, later]);
  });

  test('handles empty or unavailable data and unknown scopes', () => {
    expect(filter([], 'future')).toEqual([]);
    expect(filter(undefined, 'future')).toBeUndefined();
    expect(filter(null, 'future')).toBeNull();
    expect(filter([upcoming], 'unknown')).toEqual([]);
    expect(filter([upcoming], '')).toEqual([upcoming]);
  });
});
