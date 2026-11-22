import angular from 'angular';
import 'angular-ui-tour';
import fs from 'fs';
import path from 'path';
import * as sass from 'sass';
import { waitFor } from '@testing-library/react';

describe('application-wide tour viewport constraints', () => {
  let injector;
  let style;
  let popup;
  let target;
  let tether;

  beforeAll(() => {
    const configurations = [];
    const application = {
      config: definition => { configurations.push(definition); return application; },
      run: () => application,
      constant: () => application
    };
    const module = angular.module;
    const registration = jest.spyOn(angular, 'module').mockImplementation((...args) => args[0] === 'application' ? application : module(...args));
    require('../../../app/frontend/src/javascript/app');
    registration.mockRestore();

    angular.module('tourViewportTest', ['bm.uiTour'])
      .value('$rootElement', angular.element(document.body))
      .config(['$injector', '$provide', 'TourConfigProvider', function ($injector, $provide, TourConfigProvider) {
        const noop = () => {};
        for (const configuration of configurations) {
          $injector.invoke(configuration, null, {
            $provide,
            TourConfigProvider,
            $httpProvider: {},
            AuthProvider: {},
            growlProvider: { globalTimeToLive: noop },
            unsavedWarningsConfigProvider: {},
            uibDatepickerPopupConfig: {},
            $translateProvider: {
              useLoader: noop,
              useLoaderCache: noop,
              useSanitizeValueStrategy: noop,
              useMessageFormatInterpolation: noop,
              preferredLanguage: noop
            },
            $sceDelegateProvider: { resourceUrlWhitelist: noop }
          });
        }
        TourConfigProvider.set('scrollIntoView', false);
      }]);
    style = document.createElement('style');
    style.textContent = sass.compileString(fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/src/stylesheets/modules/tour.scss'), 'utf8')).css;
    document.head.appendChild(style);
    Object.defineProperty(document.documentElement, 'clientWidth', { configurable: true, value: 1280 });
    Object.defineProperty(document.documentElement, 'clientHeight', { configurable: true, value: 841 });
    window.innerWidth = 1280;
    window.innerHeight = 841;
  });

  beforeEach(() => {
    injector = angular.injector(['ng', 'tourViewportTest']);
    popup = document.createElement('div');
    popup.className = 'ui-tour-popup popover';
    target = document.createElement('button');
    target.className = 'viewport-target';
    document.body.append(target, popup);
  });

  afterEach(() => {
    if (tether) tether.destroy();
    tether = null;
    target?.remove();
    popup?.remove();
    jest.restoreAllMocks();
  });

  afterAll(() => { style?.remove(); });

  const rect = (left, top, width, height) => ({ left, top, width, height, right: left + width, bottom: top + height });

  test.each([
    ['settings Reservations', 1080, 190, 160, 'top center', 'bottom center', 'shift-left-50'],
    ['members Authentication', 1008.75, 190, 240, 'top center', 'bottom center', 'shift-left-50'],
    ['statistics export', 1069, 190, 40, 'top center', 'bottom center', ''],
    ['projects reports, centered', 1102, 100, 80, 'top center', 'bottom center', 'shift-left-40'],
    ['projects reports, right aligned near the left edge', 50, 100, 80, 'top right', 'bottom right', ''],
    ['left edge', 0, 100, 40, 'top center', 'bottom center', 'shift-right-40'],
    ['top edge', 600, 0, 40, 'bottom center', 'top center', ''],
    ['bottom edge', 600, 810, 40, 'top center', 'bottom center', ''],
    ['already on screen', 600, 100, 40, 'top center', 'bottom center', '']
  ])('keeps a popup inside 1280x841: %s', (_name, left, top, width, attachment, targetAttachment, popupClass) => {
    popup.classList.add(...popupClass.split(' ').filter(Boolean));
    jest.spyOn(target, 'getBoundingClientRect').mockReturnValue(rect(left, top, width, 30));
    jest.spyOn(popup, 'getBoundingClientRect').mockReturnValue(rect(0, 0, 414, 200));
    const Tether = injector.get('Tether');
    tether = new Tether({ element: popup, target, attachment, targetAttachment, optimizations: { gpu: false } });
    const x = parseFloat(popup.style.left) + (parseFloat(getComputedStyle(popup).marginLeft) || 0);
    const y = parseFloat(popup.style.top) + (parseFloat(getComputedStyle(popup).marginTop) || 0);
    expect(x).toBeGreaterThanOrEqual(0);
    expect(x + 414).toBeLessThanOrEqual(1280);
    expect(y).toBeGreaterThanOrEqual(0);
    expect(y + 200).toBeLessThanOrEqual(841);
  });

  const arrowFixture = (placement, bounds) => {
    const horizontal = ['top', 'bottom'].includes(placement);
    popup.classList.add(placement);
    const arrow = document.createElement('div');
    arrow.className = 'arrow';
    popup.appendChild(arrow);
    Object.defineProperties(popup, {
      clientLeft: { value: 1 },
      clientTop: { value: 1 },
      clientWidth: { value: 412 },
      clientHeight: { value: 198 }
    });
    jest.spyOn(target, 'getBoundingClientRect').mockImplementation(() => bounds);
    jest.spyOn(popup, 'getBoundingClientRect').mockImplementation(() => rect(parseFloat(popup.style.left) || 0, parseFloat(popup.style.top) || 0, 414, 200));
    jest.spyOn(arrow, 'getBoundingClientRect').mockReturnValue(rect(0, 0, horizontal ? 22 : 11, horizontal ? 11 : 22));
    const positions = {
      bottom: ['top center', 'bottom center'],
      top: ['bottom center', 'top center'],
      left: ['middle right', 'middle left'],
      right: ['middle left', 'middle right']
    };
    const [attachment, targetAttachment] = positions[placement];
    const Tether = injector.get('Tether');
    tether = new Tether({ element: popup, target, attachment, targetAttachment, optimizations: { gpu: false } });
    return {
      arrow,
      centre: () => {
        const offset = parseFloat(arrow.style[horizontal ? 'left' : 'top']);
        const origin = horizontal ? popup.getBoundingClientRect().left + popup.clientLeft : popup.getBoundingClientRect().top + popup.clientTop;
        return origin + (Number.isFinite(offset) ? offset : (horizontal ? popup.clientWidth : popup.clientHeight) / 2);
      }
    };
  };

  test.each([
    ['bottom', rect(1122.5, 190, 40, 30), 1142.5],
    ['top', rect(1122.5, 400, 40, 30), 1142.5],
    ['left', rect(600, 800, 40, 30), 815],
    ['right', rect(600, 800, 40, 30), 815]
  ])('the pinned %s popup arrow points at the target centre', (placement, bounds, expected) => {
    const { centre } = arrowFixture(placement, bounds);
    expect(popup.classList.contains('tether-pinned')).toBe(true);
    expect(centre()).toBeCloseTo(expected);
  });

  test.each([
    ['bottom', rect(-80, 190, 40, 30), 12],
    ['bottom', rect(1400, 190, 40, 30), 1268],
    ['right', rect(600, -80, 40, 30), 12],
    ['right', rect(600, 900, 40, 30), 829]
  ])('clamps the %s arrow inside the box for target %j', (placement, bounds, expected) => {
    const { centre } = arrowFixture(placement, bounds);
    expect(centre()).toBeCloseTo(expected);
  });

  test('updates the arrow when the target moves but the pinned box stays still, then resets when unpinned', async () => {
    const bounds = rect(1122.5, 190, 40, 30);
    const { arrow, centre } = arrowFixture('bottom', bounds);
    expect(centre()).toBeCloseTo(1142.5);
    const left = popup.style.left;
    Object.assign(bounds, rect(1150, 190, 40, 30));
    tether.position();
    await Promise.resolve();
    expect(popup.style.left).toBe(left);
    expect(centre()).toBeCloseTo(1170);
    Object.assign(bounds, rect(600, 190, 40, 30));
    tether.position();
    await Promise.resolve();
    expect(popup.classList.contains('tether-pinned')).toBe(false);
    for (const side of ['left', 'right', 'top', 'bottom']) expect(arrow.style[side]).toBe('');
    expect(centre()).toBeCloseTo(620);
  });

  test('real tour popups use body attachment and the constrained Tether', async () => {
    const scope = injector.get('$rootScope').$new();
    const element = angular.element('<div ui-tour="viewport"></div>');
    document.body.appendChild(element[0]);
    element[0].appendChild(target);
    injector.get('$compile')(element)(scope);
    scope.$digest();
    const tour = injector.get('uiTourService').getTourByName('viewport');
    const step = tour.createStep({ selector: '.viewport-target', stepId: 'target', content: 'Tour content', placement: 'bottom' });
    try {
      await tour.start();
      expect(injector.get('TourConfig').get('appendToBody')).toBe(true);
      expect(step.popup[0].parentNode).toBe(document.body);
      await waitFor(() => expect(step.tether).toBeDefined());
      expect(step.tether.options.constraints).toContainEqual({ to: 'window', pin: true });
    } finally {
      await tour.end();
      if (step.tether) step.tether.destroy();
      if (step.popup) step.popup.remove();
      scope.$destroy();
      element.remove();
    }
  });
});
