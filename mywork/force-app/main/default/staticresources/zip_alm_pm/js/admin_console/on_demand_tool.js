(function() {
  var init = function($, ApiBuilder, AlmCommon, Analytics) {
    'use strict';

    var STATUS_ON_HOLD = 'On Hold';
    var STATUS_SCHEDULED = 'Scheduled';
    var STATUS_QUEUED = 'Queued';
    var STATUS_RUNNING = 'Running';

    // Instance ID in context
    var currentInstanceId;
    // Boolean indicating whether to show errors or make them silent
    var showApexErrors = true;
    // Poll timeout duration for SCAN which gets progressively increased
    var scanPollTimeoutDuration = 0;
    // Poll timeout duration for BUTR which gets progressively increased
    var butrPollTimeoutDuration = 0;
    // Amount to increase the timeout each request
    var POLL_TIMEOUT_INCREASE_AMT = 10000;
    // Maximum poll timeout
    var POLL_TIMEOUT_MAX = 60000;
    // Timeout ID for status polling for SCAN
    var statusScanPollTimeout = -1;
    // Timeout ID for status polling for BUTR
    var statusButrPollTimeout = -1;

    /**
    * Call this only after initial page load to add onload handlers
    */
    function addOnloadHandlers() {
      $('#alm-container').on('click', '[id$="scanDetailsContainer"] .on-demand-container.scheduled > button', function(){
        requestJobInstanceStatus(AlmCommon.JOB_TYPE.SCAN);
      });
      $('#alm-container').on('click', '[id$="butr-details-container"] .on-demand-container.scheduled > button', function(){
        requestJobInstanceStatus(AlmCommon.JOB_TYPE.BUTR);
      });
    }

    /**
    * Calls the action function to kickoff job, either Scan or Butr, and change the status to pending.
    * The action function will call createOnDemand*Request and then call the polling methods after completion.
    */
    function requestJobInstanceStatus(jobType) {
      if (jobType === AlmCommon.JOB_TYPE.SCAN) {
        afScanInstance();
      } else if (jobType === AlmCommon.JOB_TYPE.BUTR) {
        afButrInstance();
      } else {
        return;
      }

      updateJobButtonByStatus(jobType, STATUS_QUEUED);
      updateJobMenuStatus(jobType, STATUS_QUEUED);
    }

    function onRequestInstanceScanComplete() {
      startPolling(currentInstanceId, AlmCommon.JOB_TYPE.SCAN);
    }

    function onRequestInstanceButrComplete() {
      Analytics.trackEvent('Automated Testing', 'Run Now Automated Testing');
      startPolling(currentInstanceId, AlmCommon.JOB_TYPE.BUTR);
    }

    function setCurrentInstanceId(id) {
      currentInstanceId = id;
    }

    /**
    * Starts polling for instance status
    * @param {string} instanceId - The ID of the instance
    * @param {boolean} showErrors - Set to false if errors should be silent
    */
    function startPolling(instanceId, jobType, showErrors) {
      if(!instanceId) {
        return;
      }
      currentInstanceId = instanceId;
      showApexErrors = typeof showErrors === 'undefined' ? true : !!showErrors;

      if (jobType === AlmCommon.JOB_TYPE.SCAN) {
        afPollScanJob();
      } else if (jobType === AlmCommon.JOB_TYPE.BUTR) {
        remoteGetButrJobStatus(currentInstanceId, pollButrJobStatus);
      }
    }

    /**
    * Cancels the next poll operation
    */
    function cancelPolling(jobType) {
      if (jobType === AlmCommon.JOB_TYPE.SCAN) {
        clearTimeout(statusScanPollTimeout);
      } else if (jobType === AlmCommon.JOB_TYPE.BUTR) {
        clearTimeout(statusButrPollTimeout);
      }
    }

    function pollScanJobStatus() {
      var status = $('[id$="scanDetailsContainer"] [id$="jobStatus"]').val();

      updateJobButtonByStatus(AlmCommon.JOB_TYPE.SCAN, status);
      updateJobMenuStatus(AlmCommon.JOB_TYPE.SCAN, status);

      if(status !== STATUS_SCHEDULED) {
        // Check to see if we should increase the timeout this run
        if(scanPollTimeoutDuration < POLL_TIMEOUT_MAX) {
          scanPollTimeoutDuration += POLL_TIMEOUT_INCREASE_AMT;
        }

        statusScanPollTimeout = setTimeout(function() {
          if ($('[id$="scanDetailsContainer"] .is-tool-activated').prop('checked')) {
            afPollScanJob();
          }
        }, scanPollTimeoutDuration);
      }
    }

    function pollButrJobStatus(status, evt) {
      if(!evt.status) {
        if(showApexErrors) {
          AlmCommon.showError(evt.message);
        }
        return;
      }

      updateJobButtonByStatus(AlmCommon.JOB_TYPE.BUTR, status);
      updateJobMenuStatus(AlmCommon.JOB_TYPE.BUTR, status);
      if(status !== STATUS_SCHEDULED) {
        // Check to see if we should increase the timeout this run
        if(butrPollTimeoutDuration < POLL_TIMEOUT_MAX) {
          butrPollTimeoutDuration += POLL_TIMEOUT_INCREASE_AMT;
        }

        statusButrPollTimeout = setTimeout(function() {
          remoteGetButrJobStatus(currentInstanceId, pollButrJobStatus);
        }, butrPollTimeoutDuration);
      } else {
        afGetButrResults();
      }
    }

    function updateJobButtonByStatus(jobType, status) {

      var onDemandJobCont;

      if (jobType === AlmCommon.JOB_TYPE.BUTR) {
        onDemandJobCont = $('[id$="butr-details-container"] .on-demand-container');
      } else if (jobType === AlmCommon.JOB_TYPE.SCAN) {
        onDemandJobCont = $('[id$="scanDetailsContainer"] .on-demand-container');
      } else {
        return;
      }

      onDemandJobCont.removeClass('queued running');

      if (status === STATUS_QUEUED || status === STATUS_RUNNING) {
        onDemandJobCont.removeClass('scheduled');
      }

      onDemandJobCont.addClass(status.toLowerCase());

      if (status === STATUS_ON_HOLD) {
        onDemandJobCont.addClass('scheduled');
      }
    }

    function updateJobMenuStatus(jobType, status) {

      var $statusSection;

      if (jobType === AlmCommon.JOB_TYPE.BUTR) {
        $statusSection = $('[id$="butr-details-container"] .status-section');
      } else if (jobType === AlmCommon.JOB_TYPE.SCAN) {
        $statusSection = $('[id$="scanDetailsContainer"] .status-section');
      } else {
          return;
      }

      $statusSection.find('input').val(status);
      $statusSection.find('.status-output').text(status);

      if (status.toLowerCase().match(/queued|running/)) {
        $statusSection.addClass('disabled');
      } else {
        $statusSection.removeClass('disabled');
      }
    }

    return new ApiBuilder({
      pure: {
        addOnloadHandlers: addOnloadHandlers,
        setCurrentInstanceId : setCurrentInstanceId,
        startPolling: startPolling,
        pollScanJobStatus: pollScanJobStatus,
        onRequestInstanceScanComplete: onRequestInstanceScanComplete,
        onRequestInstanceButrComplete: onRequestInstanceButrComplete,
        cancelPolling: cancelPolling
      },
      testOnly: {
        STATUS_RUNNING : STATUS_RUNNING,
        POLL_TIMEOUT_MAX : POLL_TIMEOUT_MAX,
        pollButrJobStatus : pollButrJobStatus,
        updateJobMenuStatus: updateJobMenuStatus,
        updateJobButtonByStatus : updateJobButtonByStatus
      }
    }).getApi();
  };

  define(['jquery', 'api_builder', 'js_alm_common', 'try!analytics'], function($, ApiBuilder, AlmCommon, Analytics) {
    var API = init($, ApiBuilder, AlmCommon, Analytics);
    window.BW = window.BW || {};
    window.BW.onDemandScan = API;
    return API;
  });
})();