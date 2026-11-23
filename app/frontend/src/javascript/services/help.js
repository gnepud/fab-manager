'use strict';

Application.Services.factory('Help', ['$rootScope', '$uibModal', '$state', 'AuthService', 'uiTourService',
  function ($rootScope, $uibModal, $state, AuthService, uiTourService) {
    const TOURS = {
      'app.public.home': 'welcome',
      'app.public.machines_list': 'machines',
      'app.public.spaces_list': 'spaces',
      'app.admin.machines_list': 'machines',
      'app.admin.trainings': 'trainings',
      'app.admin.calendar': 'calendar',
      'app.admin.members': 'members',
      'app.admin.invoices': 'invoices',
      'app.admin.pricing': 'pricing',
      'app.admin.events': 'events',
      'app.admin.projects': 'projects',
      'app.admin.statistics': 'statistics',
      'app.admin.settings': 'settings',
      'app.admin.open_api_clients': 'open-api'
    };

    return function (e) {
      if (!AuthService.isAuthorized(['admin', 'manager'])) return;

      if (e.key === 'F1') {
        e.preventDefault();
        // retrieve the tour name, based on the current location
        const tourName = TOURS[$state.current.name];
        const tour = tourName === undefined ? undefined : uiTourService.getTourByName(tourName);

        // if no tour, just open the guide
        if (!tour) {
          return window.open('http://guide-fr.fab.mn', '_blank');
        }

        if (tour.getStatus() === tour.Status.ON) return;

        const modal = $uibModal.open({
          animation: true,
          templateUrl: '/shared/help_modal.html',
          resolve: {
            tourName: function () { return tourName; }
          },
          controller: ['$scope', '$uibModalInstance', 'uiTourService', 'tourName', function ($scope, $uibModalInstance, uiTourService, tourName) {
          // start the tour and hide the modal
            $scope.onTour = function () {
              const tour = uiTourService.getTourByName(tourName);
              if (tour && tour.getStatus() !== tour.Status.ON) { tour.start(); }

              $uibModalInstance.close('tour');
            };

            // open the user's guide and hide the modal
            $scope.onGuide = function () {
              $uibModalInstance.close('guide');
            };
          }]
        });

        const closeForActiveTour = () => { modal.close('tour-active'); };
        const removeTourListener = () => { tour.off('started', closeForActiveTour); };
        modal.opened.then(() => {
          if (tour.getStatus() === tour.Status.ON) {
            closeForActiveTour();
          } else {
            tour.on('started', closeForActiveTour);
          }
        }, angular.noop);
        modal.result.then(removeTourListener, removeTourListener);
      }
    };
  }]);
