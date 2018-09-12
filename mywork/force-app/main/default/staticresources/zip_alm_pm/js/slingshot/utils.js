(function() {
  var init = function($, AlmCommon) {

    var colors =  {
      CANCEL : "#FF9210",
      DEPLOY : "#009DDC",
      PENDING : "#909090",
      VALIDATE : "#9DC042",
      FAIL : "#F67675"
    },
    stages = {
      BUILDING : "building",
      CANCELED : "canceled",
      CANCELING : "canceling",
      CREATING_BACKUP : "backing-up",
      COMPONENTS : "components",
      FAILURE : "failure",
      IN_PROGRESS : "in-progress",
      PENDING : "pending",
      PACKAGING : "packaging",
      RETRIEVING : "retrieving",
      SUCCESS : "success",
      UNIT_TESTS : "unit tests"
    },
    statuses = {
      CANCELED : "Canceled",
      CREATING_BACKUP : "Creating target backup",
      DEPLOYMENT : "Deployment",
      FAILED : "Failed",
      IN_PROGRESS : "In Progress",
      SUCCESSFUL : "Successful",
      VALIDATION : "Validation"
    },
    constants = {
      FIVE_SECONDS : 5000,
      ASSEMBLE_PROGRESS_SPEED : 2500
    };

    function blockSlingshotCard(container, warningCard, centerY) {

      var msg = warningCard || "";

      var options = {
          message: msg,
          css: { border: 'none', background: 'none'}
      };

      if (centerY === false) {
        options.centerY = false;
        options.css.top = "155px";
      }

      $(container).block(options);
      $('.blockOverlay').css({ cursor: 'default', borderRadius: '3px' });
      setDroppableOption("disabled", true);
    }

    function unblockSlingshotCard(container) {
      AlmCommon.unblockUI(container);
      setDroppableOption("disabled", false);
    }

    function setDroppableOption(prop, val) {
      var $source = $('#slingshot-card-body #source-selection');
      var $target = $('#slingshot-card-body #target-selection');

      if($source.data('droppable')) {
        $source.droppable("option", prop, val);
      }
      if($target.data('droppable')) {
        $target.droppable("option", prop, val);
      }
    }

    /**
     * Sets the deployment status and image within the progress circle during the deployment process
     * @param args Object
     * @param args.deploymentText The current state of the deployment, i.e. Pending, Assembling, etc
     * @param args.deploymentTextCssClass The name of the CSS class to apply to the deploymentText param
     * @param args.deploymentImageCssClass The name of the CSS class to apply to the image
     * @param args.showFailText Boolean to indicate if the word FAIL should appear.
     * @param args.progressLabelText The text to display when deployment is deploying components or running apex tests. i.e. 3 /100 Unit Tests
     */
    function setActionTextAndImage(args) {
      $(".deployment-progress-text").removeClass().addClass("deployment-progress-text").addClass(args.deploymentTextCssClass);

      $(".progress-circle").toggleClass("building", args.deploymentText === stages.BUILDING);

      if (args.deploymentText === stages.CANCELED) {
        $(".deployment-canceled-text").html(args.progressLabelText.toUpperCase());
      } else {
        $(".deployment-canceled-text").text("");
        $(".deployment-progress-text").text(args.progressLabelText.toUpperCase());
      }

      $(".deployment-text").removeClass().addClass("deployment-text").addClass(args.deploymentTextCssClass);
      $(".deployment-text").text(args.deploymentText.toUpperCase());
      $("img[id$=selected-action-img]").removeClass().addClass(args.deploymentImageCssClass);

      if (args.showFailText) {
        $(".deployment-fail-text").text("FAIL");
      } else {
        $(".deployment-fail-text").text("");
      }
    }

    function setStatusDetail(statusMessageHTML) {
      $("#deployment-status-detail").html(statusMessageHTML);
    }

    /**
     * Updates the color of the progress without changing the state
     */
    function updateRadialProgressColor(color) {
      var circle = $('.component-progress').data('radial-progress');
      circle.animate(
        circle.value(), {
        from: {color: color},
        to: {color: color},
      });
    }


    return {
      blockSlingshotCard: blockSlingshotCard,
      stages: stages,
      statuses: statuses,
      colors: colors,
      constants: constants,
      setDroppableOption: setDroppableOption,
      setActionTextAndImage: setActionTextAndImage,
      setStatusDetail: setStatusDetail,
      unblockSlingshotCard: unblockSlingshotCard,
      updateRadialProgressColor: updateRadialProgressColor
    }
  };

  define(['jquery', 'js_alm_common'], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    return init(jQuery, AlmCommon);
  });

})();
