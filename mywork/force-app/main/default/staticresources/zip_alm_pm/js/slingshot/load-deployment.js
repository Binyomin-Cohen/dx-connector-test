(function() {

  var init = function($, AlmCommon, Utils, ApiBuilder, Analytics) {

    function loadDeploymentsForRelease(releaseId) {
      if(!remoteGetDeployments) {
        throw new Error('This method requires a remote action function: remoteGetDeployments()');
      }
      remoteGetDeployments(releaseId, loadDeploymentsTemplate)
    }

    function loadDeploymentsTemplate(err, deployments) {

      if(!deployments) {
        AlmCommon.clearMsgs();
        AlmCommon.showError("An error occurred. Please try again or contact your administrator.", {
          messagePanel: '#slingshot-card-errors'
        });
        var $tray = $('#load-deployment-pane');
        AlmCommon.toggleSlidingTray( $tray, $('#load-deployment-handle') );
        $tray.data('deployments-init', false);

        return;
      }

      // Clear out existing list to be reloaded
      $('#saved-deployment-list').empty();

      deployments.forEach(function(deployment) {
        deployment.rowClass = getRowClass(deployment);
        deployment.testCoverageClass = '';
        if(deployment.isValidation || deployment.isDeploy) {
          var totalCodeCoverage = AlmCommon.getSObjValue(deployment.deploymentAttempt.record, 'Total_Code_Coverage__c', 0);
          deployment.testCoverageClass = totalCodeCoverage >= 75 ? 'passing' : 'failing';
        }

        deployment.deploymentStatus = getDeploymentStatus(deployment);

        deployment.buildErrorText = getErrorText('build', deployment);
        deployment.compErrorText = getErrorText('component', deployment);
        deployment.testErrorText = getErrorText('tests', deployment);

        deployment.record.Name = AlmCommon.htmlDecode(deployment.record.Name);
        deployment.sourceInstanceName = AlmCommon.htmlDecode(deployment.sourceInstanceName);
        deployment.targetInstanceName = AlmCommon.htmlDecode(deployment.targetInstanceName);

        var item = $( templates["slingshot_saved_deployment_item"].render(deployment));
        var $item = $(item);
        $item.data('deployment', deployment);
        $('#saved-deployment-list').append( $item );
      });

      //reset parent height
      var parent = $('#load-deployment-pane').parent();
      if ($('#saved-deployment-list').outerHeight() > parent.outerHeight()) {
        window.setTimeout(function() {
          parent.data('original-height', parent.height());
          //need to re-retrieve parent for this to work
          $('#load-deployment-pane').parent().height( $('#load-deployment-pane').outerHeight() );
        },
        400);
      }

      AlmCommon.unblockUI('#load-deployment-pane');
    }

    function getRowClass(deployment) {
      var rowClasses = [];
      var statusClass;
      if (deployment.deploymentAttempt && deployment.deploymentAttempt.status === Utils.stages.CANCELED) {
        statusClass = Utils.stages.CANCELED;
      } else if (deployment.isInProgress) {
        statusClass = Utils.stages.IN_PROGRESS;
      } else if (deployment.isSuccess) {
        statusClass = Utils.stages.SUCCESS;
      } else {
        statusClass = Utils.stages.FAILURE;
      }

      if(deployment.isValidation) {
        rowClasses.push('validation');
        rowClasses.push(statusClass);
      } else if(deployment.isDeploy) {
        rowClasses.push('deployment');
        rowClasses.push(statusClass);
      }

      if(deployment.isManualUpload) {
        rowClasses.push('manual-upload');
      }

      return rowClasses.join(' ');
    }

    function getDeploymentStatus(deployment) {
      var status = '';
      if (deployment.isInProgress) {
        status += Utils.statuses.IN_PROGRESS;
      }
      else {
        if (deployment.isValidation) {
          status += Utils.statuses.VALIDATION;
        } else if (deployment.isDeploy) {
          status += Utils.statuses.DEPLOYMENT;
        }
        if (deployment.deploymentAttempt && deployment.deploymentAttempt.status === Utils.stages.CANCELED) {
          status += ' ' + Utils.statuses.CANCELED;
        } else {
          status += deployment.isSuccess ? ' ' + Utils.statuses.SUCCESSFUL : ' ' + Utils.statuses.FAILED;
        }
      }
      return status;
    }

    function downloadFlyoutHandler(e) {
      var $target = $(e.target);
      if ($target.is('.dl-build-opener img')) {
        $("#load-deployment-pane").find(".flyout-menu").hide();
        $target.closest('.details-right-col').find('.flyout-menu').show();
        e.stopPropagation();
      }
    }

    function buildPackageDownloadHandler(e) {
      Analytics.trackEvent('Slingshot', 'Download Build Package');
    }

    function targetBackupDownloadHandler(e) {
      Analytics.trackEvent('Slingshot', 'Download Target Backup');
    }

    function getErrorText(type, deployment) {
      // No deployment attempt so there will be no errors
      if(!deployment.deploymentAttempt) {
        return '';
      }

      var numberComponentsErrors = AlmCommon.getSObjValue(deployment.deploymentAttempt.record, 'Number_Components_Errors__c', 0);
      var numberTestErrors = AlmCommon.getSObjValue(deployment.deploymentAttempt.record, 'Number_Test_Errors__c', 0);
      switch(type) {
        case 'build':
          return (deployment.totalBuildErrors === 1 ? 'Error' : 'Errors');
        case 'component':
          if(numberComponentsErrors === 1) {
            return 'Error';
          } else {
            return 'Errors';
          }
        case 'tests':
          if(numberTestErrors === 1) {
            return 'Error';
          } else {
            return 'Errors';
          }
      }
    };

    return new ApiBuilder({
      pure: {
        loadDeploymentsForRelease: loadDeploymentsForRelease,
        downloadFlyoutHandler: downloadFlyoutHandler,
        buildPackageDownloadHandler: buildPackageDownloadHandler,
        targetBackupDownloadHandler: targetBackupDownloadHandler
      },
      testOnly: {
        getRowClass : getRowClass,
        getDeploymentStatus : getDeploymentStatus
      }
    }).getApi();
  };

  define(['jquery', 'js_alm_common', 'slingshot/utils', 'api_builder', 'try!analytics'], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    var Utils = arguments[2];
    var ApiBuilder = arguments[3];
    var Analytics = arguments[4];

    return init(jQuery, AlmCommon, Utils, ApiBuilder, Analytics);
  });
})();