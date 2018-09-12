(function() {

  var init = function($, Assembler, SlingshotUtils, RequestManager, AlmCommon, Analytics) {

    function hideActionButtonOverlay() {
      $('#action-button-overlay')
        .hide()
        .removeClass('really-important-btn important-btn')
        .children('.content')
        .removeClass('validating deploying can-cancel');
      setIsCancelInProgress(false);
    }

    function enableCancelDeploy() {
      $('#action-button-overlay .content').addClass('can-cancel');
    }

    function hideCancelDeploy() {
      $('#action-button-overlay .content').removeClass('can-cancel');
    }

    function showCancelWarning() {
      if ($('#slingshot-card-body').hasClass('manifest-open')) {
        Assembler.toggleManifest();
      }

      var warningCard = templates["sprint_warning"].render({
          continueButtonClass: 'confirm-cancel',
          cancelButtonClass: 'close-cancel',
          message : "Are you sure you want to cancel this process?"
        });

      // Update the content
      $('#action-button-overlay .content').addClass('confirm-cancel');

      SlingshotUtils.blockSlingshotCard('.ss-record-wrap');
      var warningCont = $('<div id="cancel-deploy-warning"/>').append(warningCard);
      $('.ss-record-wrap').append(warningCont);
      $('.sp-card-wrap-error').show();
    }

    function removeCancelWarning() {
      $('#action-button-overlay .content').removeClass('confirm-cancel');
      SlingshotUtils.unblockSlingshotCard('.ss-record-wrap');
      $('.ss-record-wrap #cancel-deploy-warning').remove();
    }

    function updateActionText() {
      var args = {
          deploymentText: BW.utils.stages.CANCELING,
          deploymentTextCssClass: 'canceled',
          deploymentImageCssClass: 'canceled',
          showFailText: false,
          progressLabelText: ''
      };

      SlingshotUtils.setActionTextAndImage(args);
    }

    function cancelDeployment() {
      Analytics.trackEvent('slingshot', 'cancel', 'slingshot - cancel');
      updateActionText();
      // Show action image within status circle since it's hidden by other flows
      $('#selected-action-img').show();
      RequestManager.invokeFunction(afCancelDeployment);
      removeCancelWarning();
      setIsCancelInProgress(true);
      hideCancelDeploy();
      SlingshotUtils.updateRadialProgressColor(SlingshotUtils.colors.CANCEL);
    }

    function setIsCancelInProgress(inProg) {
      if(inProg) {
        $('#action-button-overlay .content').addClass('cancel-in-progress');
      } else {
        $('#action-button-overlay .content').removeClass('cancel-in-progress');
      }
    }

    function isCancelInProgress() {
      return $('#action-button-overlay .content').hasClass('cancel-in-progress');
    }

    return {
      hideActionButtonOverlay: hideActionButtonOverlay,
      hideCancelDeploy: hideCancelDeploy,
      enableCancelDeploy: enableCancelDeploy,
      showCancelWarning: showCancelWarning,
      removeCancelWarning: removeCancelWarning,
      setIsCancelInProgress: setIsCancelInProgress,
      isCancelInProgress: isCancelInProgress,
      cancelDeployment: cancelDeployment,
      updateActionText: updateActionText
    };
  };

  define(['jquery', 'slingshot/utils', 'common/request-manager', 'slingshot/assembler2', 'js_alm_common', 'try!analytics'], function(jQuery, SlingshotUtils, RequestManager, Assembler, AlmCommon, Analytics) {
    return init(jQuery, Assembler, SlingshotUtils, RequestManager, AlmCommon, Analytics);
  });

})();