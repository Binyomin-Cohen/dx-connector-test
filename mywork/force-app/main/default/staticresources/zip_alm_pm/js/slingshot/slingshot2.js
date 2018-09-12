(function() {
  "use strict";
  var init = function ($, BW, AlmCommon, ProgressBar, RequestManager, OAuth, ApiBuilder, Analytics, ComboBox) {

    // We need to remove the slds-scope class from #bodyTable because it is getting set with apex:slds
    var $header = $('#bodyTable .noSidebarCell, body');
    $header.removeClass('slds-scope');

    var slingshotPage = {
      almInstanceAuthMessage : '.message[data-message-id="validateAuth"]',
      pendingRemovals : 'input[id$="pending-removals"]',
      availableTests : 'input[id$="available-tests-classes"]',
      specifiedTests : 'input[id$="specified-tests-classes"]',
      selectionTargetInstanceId : 'input[id$="tgt-instance-id"]'
    };

    var TEN_SECONDS = 10000;
    var DEPLOY_ACTION = 'deploy';
    var VALIDATE_ACTION = 'validate';
    var RUN_SPECIFIED_TESTS = 'RunSpecifiedTests';

    var isNewSave = true;

    var pollDeploymentTimeout;

    $(function () {
      if (!hasPermissions()) {
        displayModal( $("#no-access-modal") );
      }

      AlmCommon.addIEConditionalCSS('ie-only-css', $('#alm-container').data('ie-only-css'));

      RequestManager.invokeFunction(afValidateAuth, null, { callback: finishValidateAuth });
      addEventHandlers();
      enableAvailableSourcesDrag();
      loadState();
      toggleDeployBtn();
      drawRadialProgress(TEN_SECONDS, BW.utils.colors.PENDING, BW.utils.colors.PENDING, false);
      initConfirmSlider();
      initStaleManifestAlertHandlers();
      initProfiles();
      BW.assembler.initializeComboboxes();
      OAuth.init( {
        authorizeInstance : function() {
          var message = "Please save your deployment before continuing. All unsaved changes will be lost. Do you want to continue?";
          var $authModal = $('#auth-modal');
          $authModal.find('#modal-text').html(message);
          $authModal.data('oauth-container-id', $(this).parents('.oauth-container').prop('id'));

          if (AlmCommon.getHasUnsavedChanges()) {
            AlmCommon.displayModal({
              content: $authModal,
              container: '#alm-container'
            });
          } else {
            enterOAuthFlow();
          }
        },
        pageStateConfig : {
          expireAction : afExpirePageState
        },
        afterAuthorizeInstance: finishAuthPolling
      });
      afExpirePageState();
    });

    /**
     * Deployment attempt progress
     * @constructor
     */
    function DeploymentAttemptProgress(deploymentAttemptModel) {
      this.numberComponentsTotal = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Components_Total__c', 0);
      this.numberComponentsDeployed = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Components_Deployed__c', 0);
      this.numberTestsCompleted = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Tests_Completed__c', 0);
      this.numberTestsTotal = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Tests_Total__c', 0);

      this.componentProgressVal = this.numberComponentsTotal ? this.numberComponentsDeployed / this.numberComponentsTotal : 0;
      this.apexProgressVal = this.numberTestsTotal ? this.numberTestsCompleted / this.numberTestsTotal : 0;
    }

    function getCurrentDeploymentModel() {
      return $("#load-deployment-pane")
        .find("[data-deployment-id='" + getCurrentSavedDeploymentId() + "']")
        .data('deployment');
    }

    function getCurrentSavedDeploymentName() {
      return $('[id$=hidden-input-wrapper]').data('existing-deployment-name');
    }

    function getCurrentSavedDeploymentId() {
      return $('[id$=hidden-input-wrapper]').data('existing-deployment-id');
    }

    function isDeploymentInProgress() {
      return $('input[id$=validate-deploy-in-progress]').val() === 'true';
    }

    function setIsDeploymentInProgress(inProgress){
      $('input[id$=validate-deploy-in-progress]').val(inProgress);
    }

    function getReleaseId() {
      return $('input[id$=release-id]').val();
    }

    function isSaveAsDeployment(){
      return $('#deploy-input-wrapper').children('input').data('is-saveas');
    }

    function setSaveAsDeployment(value){
      $('#deploy-input-wrapper').children('input').data('is-saveas', value);
    }

    function addEventHandlers() {
      AlmCommon.addBeforeUnloadEventListener();

      stickyExpandElem("#changed-deployment-alert", "#slingshot-card-errors");

      $("#alm-container").on("click", ".validate-btn", function() {
        showDeploymentForm(VALIDATE_ACTION);
      });

      $("#alm-container").on("click", ".deploy-btn", function() {
        showDeploymentForm(DEPLOY_ACTION);
      });

      $("#alm-container").on("click", ".validate-confirm-button", function(e) {
        createBuildRecord(VALIDATE_ACTION);
        e.preventDefault();
      });

      $("#alm-container").on("click", "#save-deployment-option", deploymentSaveOptionClick);
      $("#alm-container").on("click", "#saveas-deployment-option", deploymentSaveAsOptionClick);

      $("#alm-container").on("click", ".deploy-confirm-button", function(e) {

        var instance = $('#target-selection .instance-name').text();
        $('.instance-name-confirm').text(instance);
        $('.confirm-panel').show("slide", {
          direction: "right"
        });

        e.preventDefault();
      });

      $("#alm-container").on("click", ".cancel", function() {
        closeDeploymentForm();
      });

      $("#alm-container").on("click", ".deployment-reset", displayWarning);

      $("#alm-container").on("click", '#quickdeploy-options input[id$="is-quickdeploy"]', quickDeployClick);
      $("#alm-container").on("click", '.test-options .fancy-radio', testOptionClick);

      $( "#alm-container" ).on( "click", ".reset-manifest-modal .warning-buttons .continue-btn", resetSlingshot);

      $( "#alm-container" ).on( "click", ".reset-manifest-modal .warning-buttons .cancel-btn", removeWarning);

      $("#alm-container").on("click", "#load-deployment-handle", toggleLoadDeploymentTray);

      $('#load-deployment-pane').tooltip();
      $('.deployment-form-options img.info-icon').tooltip({
          options: {
              classes: {
                  "ui-tooltip": "ui-corner-all ui-widget-shadow"
              }
          }
      });

      $("#alm-container").on("click", "#load-deployment-pane .upload-build", BW.manualUpload.toggleManualUploadForm);
      $("#alm-container").on("click", "#load-deployment-pane #exit-manual-upload", BW.manualUpload.toggleManualUploadForm);

      $("#alm-container").on("click", "#manifest-legend", toggleManifestLegend);

      $("#alm-container").on("click", ".deployment-form-tests-buttons .finish-selection", function(e) {
        selectTestClasses();
        e.preventDefault();
      });
      $("#alm-container").on("click", ".deployment-form-tests-buttons .cancel-selection", function(e) {
        cancelTestSelection();
        e.preventDefault();
      });

      $("#alm-container").on("click", ".slds-dueling-list__column .move-to-selected", function(e) {
        var $selectedTests = $("#available-tests-column .slds-listbox__option[aria-selected=true]");
        if ($selectedTests.length === 0) {
          return;
        }

        var specifiedTests = $(slingshotPage.specifiedTests).val() || '';
        var availableTests = $(slingshotPage.availableTests).val() || '';
        var splitAvailableTests = availableTests.split(',');

        $selectedTests.each(function() {
          var selectedTestName = $(this).text().trim();
          var selectedIndex = splitAvailableTests.indexOf(selectedTestName);
          if (selectedIndex > -1) {
            splitAvailableTests.splice(selectedIndex, 1);
          }
          specifiedTests += ((specifiedTests) ? ',' : '') + selectedTestName;
        });

        $(slingshotPage.specifiedTests).val(specifiedTests);
        $(slingshotPage.availableTests).val(splitAvailableTests.join(','));

        renderDuelingLists();
        e.preventDefault();
      });
      $("#alm-container").on("click", ".slds-dueling-list__column .move-from-selected", function(e) {
        var $selectedTests = $("#specified-tests-column .slds-listbox__option[aria-selected=true]");
        if ($selectedTests.length === 0) {
          return;
        }

        var specifiedTests = $(slingshotPage.specifiedTests).val() || '';
        var availableTests = $(slingshotPage.availableTests).val() || '';
        var splitSpecifiedTests = specifiedTests.split(',');
        $selectedTests.each(function() {
          var selectedTestName = $(this).text().trim();
          var selectedIndex = splitSpecifiedTests.indexOf(selectedTestName);
          if (selectedIndex > -1) {
            splitSpecifiedTests.splice(selectedIndex, 1);
          }
          availableTests += ((availableTests) ? ',' : '') + selectedTestName;
        });

        $(slingshotPage.specifiedTests).val(splitSpecifiedTests.join(','));
        $(slingshotPage.availableTests).val(availableTests);

        renderDuelingLists();
        e.preventDefault();
      });

      $("#alm-container").on("click", ".slds-listbox .slds-listbox__item", function(e) {
        var $testClass = $(this).find('.slds-listbox__option');
        $testClass.attr('aria-selected', ($testClass.attr('aria-selected') === "true") ? "false" : "true");
        e.preventDefault();
      });

      $("#specified-tests-info").on("click", ".edit-selected-tests", function(e) {
        if ($('.deployment-form').find('input[id$="test-level"]').val() === 'RunSpecifiedTests') {
          toggleSpecifiedTestsSection(true);
        } else {
          var $runSpecifiedTestsButton = $("#test-level-radio-3");
          $runSpecifiedTestsButton.prop('checked', true);
          testOptionClick();
        }
      });

      AlmCommon.enableSimpleAccordions();
      AlmCommon.enableTwistyPageBlockPanelSections();


      $( '#alm-container' ).on( 'keypress', '#deploy-input-wrapper > input', function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, function() {
          saveDeployment();
          resetDeploymentListState();
        });
      });

      $('#alm-container').on('click', '#deploy-input-wrapper button.save-btn', function(e) {
        e.preventDefault();
        saveDeployment();
        resetDeploymentListState();
      });

      $(document.body).click(function closeFlyouts(e) {
        var $target = $(e.target);
        // Only force save if the user didn't click on a descendent
        // of the deploy-input-wrapper
        if($target.parents('#deploy-input-wrapper').length === 0) {
          toggleSaveMenu(true);
          toggleSave(true);
        }

        if (!$target.is('.dl-build-opener img')) {
          $("#load-deployment-pane").find(".flyout-menu").hide();
        }
      });

      $('#alm-container').on('click', '.deployment-item', loadDeployment);

      $('#alm-container').on('click',".dl-build-opener img", BW.loadDeployments.downloadFlyoutHandler);
      $('#alm-container').on('click', '#build-package-download-button', BW.loadDeployments.buildPackageDownloadHandler);
      $('#alm-container').on('click', '#target-backup-download-button', BW.loadDeployments.targetBackupDownloadHandler);

      // Prevent download package link from closing deployments pane
      $('#alm-container').on('click', '.deployment-item .flyout-menu a, .deployment-item .flyout-menu li', function(e) {
          $("#load-deployment-pane").find(".flyout-menu").hide();
          e.stopPropagation();
          if (!$(e.target).attr('href')) {
            e.preventDefault();
          }
      });

      $('#alm-container').on('click', '#sync-manifest-link', syncManifest);

      $('#alm-container').on('click', '#cancel-deployment a', BW.cancel.showCancelWarning);
      $('#alm-container').on('click', '#cancel-deploy-warning button.confirm-cancel', BW.cancel.cancelDeployment);
      $('#alm-container').on('click', '#cancel-deploy-warning button.close-cancel', BW.cancel.removeCancelWarning);

      $('#alm-container').on('click', '.message .cancel-btn', function() {
        var message = $(this).closest('.message');
        message.remove();
        RequestManager.invokeFunction(afRemovePageMessage, message.data('message-id'));
      });

      $('#alm-container').on('click', '#auth-modal .continue-btn', function() {
        enterOAuthFlow();
        AlmCommon.unblockUI('#alm-container');
      });
      $('#alm-container').on('click', '#auth-modal .cancel-btn', function() {
        AlmCommon.unblockUI('#alm-container');
      });

      $('#alm-container').on('change', '#branch-search', function() {
        selectRepoLocation($("#branch-search").val());
      });

      $('#alm-container').on('click', '.update-build-package', function(e) {
        e.stopPropagation();
        var deploymentId = $(this).closest('.deployment-item').attr('data-deployment-id');
        BW.manualUpload.toggleManualUploadForm('show', deploymentId );
      });

      $('#alm-container').on('click', '#edit-deployment-name-icon', function(e) {
        e.stopPropagation();
        toggleSave();
      });
      

      updateSaveHandlers();
      // Manual upload
      BW.manualUpload.setupFileHandlers();
    }

    function enterOAuthFlow() {
      afSavePageState();
      var oAuthContainer = $('#auth-modal').data('oauth-container-id');
      OAuth.authorizeInstance.call($('#' + oAuthContainer));
    }

    function syncManifest() {
      AlmCommon.blockUI('#manifest-body');
      RequestManager.invokeFunction(afSyncManifest, null, { callback: BW.assembler.finishManifestLoad });
    }

    function initProfiles() {
      BW.profiles.init({
        parentEventContainer : "#profile-panel-list",
        useMultiInstanceTemplate: true,
        getDefaultInstances : function() {
          return $("#profile-panel-list").data("default-instances");
        },
        profilePreload : function(instanceName, profileKey, finishProfileLoadCallback) {

          var profileCallback = function() {
            var $profileTile = $('#profile-panel').find('div[data-key$="' + profileKey + '"]');
            finishProfileLoadCallback(instanceName, $profileTile);
          }

          if ($(slingshotPage.pendingRemovals).data('has-pending-removals') === true) {
            RequestManager.invokeFunction(afRemoveComponentProfileData, null, {
              callback: profileCallback
            });
          } else {
            profileCallback();
          }
        }
      });

      $('#profile-apply-btn').on('click', function() {
        Analytics.trackEvent('Slingshot', 'Document Profile', 'Slingshot - Edit Profile Settings');

        setSavedStatus(true);
      });
    }

    function initStaleManifestAlertHandlers() {
      stickyExpandElem('#stale-manifest-alert', '#slingshot-card-errors');
      addStickyAlert();
    }

    function addStickyAlert() {
      $('#slingshot-card .manifest-alert-panel').stick_in_parent();
    }

    /**
    * Will expand the element within the sticky element container based
    * on it's position and available space
    * @param {string} selector - The selector for the sticky element
    * @param {string} toggleOnAnim - (Optional) A selector for an element to toggle when other elements are expanded
    */
    function stickyExpandElem(selector, toggleOnAnim) {

      $('#alm-container').on('click', selector, function() {
        var $this = $(this);
        var rightPad = parseInt($this.parent().css('right'), 10);
        var parentWidth = $this.parents('#slingshot-card').outerWidth();
        // Our width should be the parent width with 95px of space on the left
        var css = {
          width: (parentWidth - rightPad - 120) + 'px'
        };

        if ($this.hasClass("open")) {
          return;
        }

        if(toggleOnAnim && $(toggleOnAnim).css('display') !== 'none') {
          $(toggleOnAnim)
            .hide()
            .addClass('toggled-on-animation');
        }

        var openPanels = $(".manifest-alert-panel").find(".open");
        if (openPanels.length) {
          openPanels.find('.close-icon').trigger("click");
        }

        $this.animate(css, {
          complete: function() {
            $this.addClass('open');
          }
        });
      });

      $('#alm-container').on('click', selector + " .close-icon", function closeStickyEl(e) {
        e.stopPropagation();
        var $this = $(this).closest(selector);
        $this.removeClass('open');
        var css = {
          width: '30px'
        };

        $this.animate(css, {
          complete: function() {
            if(toggleOnAnim && $(toggleOnAnim).hasClass('toggled-on-animation')) {
              $(toggleOnAnim)
                .show()
                .removeClass('toggled-on-animation');
            }
          }
        });
      });
    }

    function collapseDeploymentErrorTables(closeAll) {
      if (closeAll) {
        $('.simple-accordion-errors .simple-accordion').removeClass('expanded');
      } else {
        var accordionToClose = $("#manifest-body").data("current-deployment-metric");
        $("#errors-"+accordionToClose).removeClass('expanded');
      }
    }

    /**
    * Toggles or force closes the save form
    * @param {bool} forceSaveClose - True if forme should be force closed
    */
    function toggleSave(forceSaveClose) {
      var action = forceSaveClose !== true ? 'toggle' : 'hide';

      if(action === 'hide' && !$('#deploy-input-wrapper').is(':visible')) {
        return;
      }

      var $deployInputWrapper = $('#deploy-input-wrapper');

      if($deployInputWrapper.hasClass('in-slide')) {
        return;
      };

      switch(action) {
        case 'toggle':
          $('#deploy-name-wrapper').toggle();
          $deployInputWrapper.addClass('in-slide');
          $deployInputWrapper.toggle('slide', {
            direction : "left",
            queue : false,
            complete: function() {
              $('#deploy-input-wrapper > input').focus();
              $(this).removeClass('in-slide');
            }
          });
          break;
        case 'hide':
          var $currentSavedNameEl = $('.deployment-name-static .name');
          if ($currentSavedNameEl.data('name') === '') {
            $deployInputWrapper.children('input').val('');
          }
          else {
            $('#deploy-name-input').val($currentSavedNameEl.text());
          }
          setSaveAsDeployment(false);
          $deployInputWrapper.addClass('in-slide');
          $deployInputWrapper.toggle('slide', {
            direction : "left",
            queue : false,
            complete: function() {
              $('#deploy-name-wrapper').show();
              $(this).removeClass('in-slide');
            }
          });
          break;
      }

    }

    function deploymentSaveOptionClick(event){
      if (!$('#save-deployment-link').hasClass('deploy-save-inactive')) {
        saveDeployment({ toggleSaveForm: false });
      }
    }
    function deploymentSaveAsOptionClick(event){
      var $deployInputWrapper = $('#deploy-input-wrapper');
      setSaveAsDeployment(true);
      toggleSave();
    }

    function onDeployNameClick(e) {
      e.stopPropagation();
      toggleSave();
    }

    function toggleSaveMenu(forceClose){
      if (!$('#save-deployment-link').hasClass('deploy-save-inactive')){
        var $menu = $('#deploy-name-wrapper .flyout-menu');
        if ($menu.is(':visible') || forceClose) {
          $menu.hide();
        } else {
          $menu.show();
        }
      }
    }

    function toggleQuickDeployState(isEnabled) {
      $("div.progress-circle").toggleClass('quick-deploy', isEnabled);
    }

    function onSaveLinkClicked(event) {
      event.stopPropagation();
      toggleSaveMenu();
    }

    function updateSaveHandlers() {
      var deploySaved = getCurrentSavedDeploymentId() !== '';
      isNewSave = !deploySaved;

      // Make sure to unbind any functions before rebinding as this function can be called many times.
      // If you don't do this, it will attach multiple handlers and duplicate actions.
      if(!deploySaved) {
        $('#alm-container').off('click', '#deploy-name-wrapper', onDeployNameClick);
        $('#alm-container').off('click', '#save-deployment-link', onSaveLinkClicked);
        $('#alm-container').on('click', '#deploy-name-wrapper', onDeployNameClick);

      } else {
        // Unbind existing form handler if it exists
        $('#alm-container').off('click', '#deploy-name-wrapper', onDeployNameClick);
        // Enable save link
        $('#alm-container').off('click', '#save-deployment-link', onSaveLinkClicked);
        $('#alm-container').on('click', '#save-deployment-link', onSaveLinkClicked);
      }
    }

    function clearSaveHandlers() {
      $('#alm-container').off('click', '#deploy-name-wrapper', onDeployNameClick);
      $('#alm-container').off('click', '#save-deployment-link', onSaveLinkClicked);

    }

    function hasCompletedBuild() {
      return !!getCompletedBuildId();
    }
    function getCompletedBuildId() {
      return $('[id$=hidden-input-wrapper]').data('completed-build-id');
    }

    function isBuildInProgress() {
      return $('[id$=hidden-input-wrapper]').data('build-is-in-progress') === true;
    }

    //TODO: no longer used anywhere - consider removing
    function isBuildComplete() {
      return $('[id$=hidden-input-wrapper]').data('build-is-completed') === true;
    }

    function hasSaveErrors() {
      return $('[id$=hidden-input-wrapper]').data('has-save-errors') === true;
    }

    function buildIsManualUpload() {
      return $('[id$=slingshot-detail]').hasClass('manual-upload');
    }

    function isQuickDeployChecked() {
      return $(".deployment-form").find('input[id$="is-quickdeploy"]').prop("checked");
    }

    function hasPermissions() {
      return $('[id$=hidden-input-wrapper]').data('has-permissions') === true;
    }

    function isAuthValid() {
      return $('[id$="hidden-input-wrapper"]').data('is-auth-valid');
    }

    function displayModal($modalContent) {
      $(document).on("click", "#ok-button", function() {
        location.href='/'+getReleaseId();
      });

      $.blockUI({ message: $modalContent,
          css: { cursor: 'auto',
              width:  '63%',
              top: '0',
              left:  '0',
              bottom:  '0',
              right:  '0',
              border: 'none',
              background: 'none',
              position: 'fixed',
              height: '78%',
              margin: 'auto',
              overflow: 'auto'
          }
      });
      $('.blockOverlay').css({ cursor: 'auto' });
    }

    function invokeSaveDeployment(func, dataBundle, startAssembler) {
      AlmCommon.blockUI( '#manifest-body' );
      RequestManager.invokeFunction(
        func,
        JSON.stringify(dataBundle),
        {
          objectsToShow: ['#deploy-save-message-spinner-container'],
          classesToAdd: {
            '.deployment-name-static': ['message-spinner-active']
          },
          callback: function() {
            onSaveDeploymentComplete(startAssembler);
          },
          debounce: true
        }
      );
    }

    /**
    * Validate the deployment name, determines whether action is "save" or "save as", and saves the deployment.
    * @param options - Options for saving a deployment.
    *        options.toggleSaveForm - Whether or not to force the save form closed.
    *        options.startAssembler - Whether or not assembler should be started after saving.
    */
    function saveDeployment(options) {
      options = options || {};

      AlmCommon.clearMsgs();

      // Update static label
      var deployName = $('#deploy-name-input').val();
      if(!validateDeployName()) {
        if (isSaveAsDeployment()){
          $('#deploy-name-input').val($('.deployment-name-static .name').text());
          setSaveAsDeployment(false);
        }
        return;
      }
      $('.deployment-name-static .name')
        .text(deployName)
        .attr('title', deployName)
        .data('name', deployName);

      if(options.toggleSaveForm !== false) {
        toggleSave();
      }

      var dataBundle = {
        deployName: deployName,
        //deploymentId: $('input[id$=existing-deployment-id]').val() || null,
        buildId: BW.assembler.getBuildId() || null,
        sourceInstanceId: $('input[id$=src-instance-id]').val() || null,
        targetInstanceId: $('input[id$=tgt-instance-id]').val() || null
      };

      // Clear handlers until save is complete
      clearSaveHandlers();
      var $deployInputWrapper = $('#deploy-input-wrapper');
      if (isSaveAsDeployment() === true) {
        invokeSaveDeployment(afSaveAsDeployment, dataBundle);
      }
      else {
        invokeSaveDeployment(afSaveDeployment, dataBundle, options.startAssembler);
      }
    }

    function getActionType() {
      return $('#alm-container').data('action-type');
    }

    /**
     * @returns {String}  the hex value for the current action (validate or deploy)
     */
    function getActionColor(actionType) {
      actionType = actionType || getActionType();
      if (BW.cancel.isCancelInProgress()) {
        return BW.utils.colors.CANCEL;
      }
      return (actionType === VALIDATE_ACTION || actionType === 'validation') ? BW.utils.colors.VALIDATE : BW.utils.colors.DEPLOY;
    }

    function setActionType(actionType) {
      $('#alm-container').data('action-type', actionType);
    }

    function onSaveDeploymentComplete(startAssembler) {
      BW.assembler.finishManifestLoad();
      BW.assembler.updateComponentCount();

      var manifestComponentToggle = $('[id$=manifest-component-toggle]').data('manifest-component-toggle');
      if ( manifestComponentToggle === "add" ) {
          $("#manifest-select-all").addClass(manifestComponentToggle);
      }

      updateSaveHandlers();
      addStickyAlert();
      setSaveAsDeployment(false);

      if (hasSaveErrors()) {
        // Get the message from the page and move it to the custom one
        var rawText = AlmCommon.getErrorMessageText();
        var text = "";
        $.each(rawText.split("\n"), function() {
          text += AlmCommon.trimDuplicateTextPrefix(this) + "\n";
        });
        AlmCommon.clearMsgs();
        AlmCommon.showError(text, {
          messagePanel: '#slingshot-card-errors'
        });
        var currentSavedDeploymentName = getCurrentSavedDeploymentName();
        $('#deploy-name-input').val(currentSavedDeploymentName);
        $('.deployment-name-static .name').text(currentSavedDeploymentName)
                                          .attr('title', currentSavedDeploymentName);
        return;
      }

      if(!isNewSave) {
        setSavedStatus(false);

        if(startAssembler === true) {
          saveDisabled(true);
          toggleButtonState(true);

          setCurrentDeploymentMetric("build");

          RequestManager.invokeFunction(
            afStartAssembler,
            getActionType() === VALIDATE_ACTION,
            {
              callback: BW.assembler.onStartAssemblerComplete,
              debounce: true
            }
          );
          resetProgressMetrics();
          displayDeploymentId({isBuilding : true});
          setIsChangedWarning(false);
        }
      }
    }

    function resetDeploymentListState() {
      $('#load-deployment-pane').data('deployments-init', false);
    }

    /**
     * Add or removes the deployment is changed warning
     * @param {Boolean} - true if the warning should be hidden
     */
    function setIsChangedWarning(isChanged) {
      var alertEl = $('#changed-deployment-alert');
      (isChanged === true) ? alertEl.addClass('is-changed') : alertEl.removeClass('is-changed');
    }

    function setSavedStatus(unsaved) {
      AlmCommon.setHasUnsavedChanges(unsaved);
      checkSaveStatus();
      if (unsaved === true && hasCompletedBuild() ) {
        setIsChangedWarning(true);
      }
    }

    /**
    * Toggles the active/inactive classes on the save link based on the isDisabled param
    */
    function saveDisabled(isDisabled) {
      if(isDisabled) {
        $('#save-deployment-link')
          .removeClass('deploy-save-active')
          .addClass('deploy-save-inactive');
      } else {
        $('#save-deployment-link')
          .removeClass('deploy-save-inactive')
          .addClass('deploy-save-active');
      }
    }

    /**
    * Checks for unsaved changes and shows unsaved status
    * if there are any changes waiting to be saved
    */
    function checkSaveStatus() {
      $('#deployment-unsaved').css({
        visibility: (AlmCommon.getHasUnsavedChanges() ? 'visible' : 'hidden')
      });
    }

    function finishValidateAuth() {
      AlmCommon.animateScrollToElement($(slingshotPage.almInstanceAuthMessage));
    }

    function showDeploymentForm(buttonToShow) {
      if (!isAuthValid()) {
        AlmCommon.animateScrollToElement($(slingshotPage.almInstanceAuthMessage));

        return;
      }

      if ($('#slingshot-card-body').hasClass('manifest-open')) {
        BW.assembler.toggleManifest();
      }

      $(".deployment-form").animate({right: "0px"}, {
        complete: function() {
          $(".deployment-form").show("slide", {
            direction: "right"
          });

          var isValidation = buttonToShow === VALIDATE_ACTION;
          initDeploymentOptions(!isValidation);

          if (isValidation) {
            $(".validate-confirm-button").show();
            $(".deploy-confirm-button").hide();
          } else {
            $(".deploy-confirm-button").show();
            $(".validate-confirm-button").hide();
          }

          BW.utils.blockSlingshotCard('#ss-container');
        }
      });

      toggleSpecifiedTestsSection(false);
    }

    function closeDeploymentForm() {
      $(".deployment-form").animate({right: "0px"}, {
        complete: function() {
          $(".deployment-form").hide("slide", {
            direction: "right"
          });

          closeConfirmPanel();

          BW.utils.unblockSlingshotCard('#ss-container');
        }
      });

      $(".validate-btn").show();
      $(".deploy-btn").show();

      $('#specified-tests-info').data('rendered', false);
      cancelTestSelection();
    }

    function initDeploymentOptions(isDeployment) {

      var $deploymentForm = $(".deployment-form"),
        $testOptions = $deploymentForm.find('.test-options .fancy-radio, .test-options'),
        $rebuildPackage = $deploymentForm.find('input[id$="rebuild-package-from-source"]'),
        $quickDeploy = $deploymentForm.find('input[id$="is-quickdeploy"]'),
        isDeployment = isDeployment || $(".deploy-confirm-button").is(':visible');

        $().add($quickDeploy)
          .add($rebuildPackage)
          .add($testOptions)
          .prop("checked", false)
          .prop("disabled", false)
          .removeClass("disabled");

      var deploymentModel = getCurrentDeploymentModel() || {},
        completedBuildRecord = AlmCommon.getSObjValue(deploymentModel.record, 'Completed_Build__r') || {},
        packageUrl = AlmCommon.getSObjValue(completedBuildRecord, 'Package_URL__c'),
        hasChangedDeploymentAlert = $('#changed-deployment-alert').is(':visible');

      if (buildIsManualUpload()) {
        $rebuildPackage
        .prop("disabled", true)
        .addClass('disabled');
      } else if (!hasCompletedBuild() || hasChangedDeploymentAlert || packageUrl === undefined || !packageUrl.trim()) {
        // If there is no pre-existing package to source from, we must build the package from the source instance.
        $rebuildPackage
          .prop('checked', true)
          .prop("disabled", true)
          .addClass('disabled');
      } else {
        // If there is a pre-existing package to source from, provide the user with an option.
        // Determine whether the checkbox should default as checked or not based on whether the user is validating or deploying.
        $rebuildPackage.prop('checked', !isDeployment).removeClass('disabled');
      }

      if (deploymentModel && deploymentModel.isQuickDeployEligible === true && !hasChangedDeploymentAlert && isDeployment) {
        $quickDeploy
          .prop("disabled", false)
          .removeClass("disabled");
      } else {
        $quickDeploy
          .prop("disabled", true)
          .addClass("disabled");
      }

      $("#quickdeploy-options").toggle(isDeployment);
      
      handleBackupTargetCheckBox();

      initTestOptionsForm(deploymentModel, $deploymentForm);
   }

   function handleBackupTargetCheckBox() {
    var $backupTarget = $(".deployment-form").find('input[id$=back-up-target]');
    if (isQuickDeployChecked()) {
      $backupTarget.prop("checked", false)
      .prop("disabled", true)
      .addClass('disabled');
    } else {
      $backupTarget.prop("disabled", false)
      .removeClass("disabled")
      .prop("checked", true);
    }
   }

   function initTestOptionsForm(deploymentModel, $deploymentForm) {
     var testLevel, specifiedTests;

     if (deploymentModel.deploymentAttempt) {
       testLevel = AlmCommon.getSObjValue(deploymentModel.deploymentAttempt.record, 'Test_Level__c'),
       specifiedTests = AlmCommon.getSObjValue(deploymentModel.deploymentAttempt.record, 'Specified_Tests__c');
     } else {
       $("#test-level-radio-0").prop('checked', true);
     }

     if (testLevel) {
       $deploymentForm.find('input[name=test-level-radio][value=' + testLevel + ']').prop('checked', true);
       setSpecifedTests(testLevel === RUN_SPECIFIED_TESTS ? specifiedTests : '');
     }

     testOptionClick();
     selectTestClasses();
   }

   function setSpecifedTests(specifiedTests) {
     $(slingshotPage.specifiedTests).val(specifiedTests);
   }

   function getInstanceType(instanceId) {
     var $targetCard = findInstanceCard(instanceId);
     return $targetCard.data("type");
   }

    function drawRadialProgress(duration, defaultColor, animationColor, doAnimation, numComplete, total) {
      $('.component-progress').empty();

      try {
        var circle = new ProgressBar.Circle('.component-progress', {
          color: defaultColor,
          trailColor: defaultColor,
          trailWidth: 6,
          strokeWidth: 6,
          duration: duration,
          from: {color: animationColor},
          to: {color: animationColor},
          // Set default step function for all animate calls
          step: function(state, circle) {
              circle.path.setAttribute('stroke', state.color);
          }
        });


        if (numComplete) {
          circle.set(numComplete / total);
        }

        if (doAnimation) {
          circle.animate(1.0);
        }

        $('.component-progress').data('radial-progress', circle);
      } catch(e) {
        AlmCommon.showError(e.message);
      }
    }

    function enableAvailableSourcesDrag() {
      $( ".instance-list .instance-card, .instance-list .repo-card").draggable({
        revert: "invalid",
        refreshPositions: false,
        containment: ".alm-container-body",
        helper : "clone",
        cursor: "move",
        opacity: .7,
        zIndex: 100,
        start: function(event, ui) {
          $(this).hide();
          $(this).after('<div class="drag-src-placeholder"/>');
        },
        stop: function(event, ui) {
          $(".instance-list").find(".drag-src-placeholder").remove();
          $(this).show();
        }
      });

      var srcDropOpts = {
        accept: ".instance-card, .repo-card",
        hoverClass: "drag-hover",
        classes: {
          "ui-droppable-active": "active-droppable-area"
        },
        drop: function( event, ui ) {
          var $targetArea = $(this),
           $selectedSource = ui.draggable;

          $targetArea.find('input[id$=src-repo-location]').val('');
          $targetArea.find('input[id$=src-repo-id]').val('');

          if ($selectedSource.hasClass('repo-card')) {
            selectRepo($selectedSource, $targetArea);
          } else {
            selectInstance($selectedSource, $targetArea);
          }
        }
      };

      var targetDropOpts = {
        accept: ".instance-card",
        hoverClass: "drag-hover",
        classes: {
          "ui-droppable-active": "active-droppable-area"
        },
        drop: function( event, ui ) {
          var $targetArea = $(this),
          $selectedInstance = ui.draggable;

          selectInstance($selectedInstance, $targetArea);
        }
      };

      if(!buildIsManualUpload()) {
        $('#slingshot-card-body #source-selection').droppable(srcDropOpts);
      }

      $('#slingshot-card-body #target-selection').droppable(targetDropOpts);
      initBranchCombobox();
    }

    function initBranchCombobox() {
      ComboBox.init({
        inputSelector : "#branch-search",
        parentContainer : '#source-selection',
        appendTo : "#source-selection",
        isMultiSelect : false,
        selectAction : selectRepoLocation
      });
    }

    function selectRepoLocation(selectedLocation) {
      var isValidLocation = $("#branch-search").data("branches").indexOf(selectedLocation) > -1;
      $('#source-selection').find('input[id$=src-repo-location]').val(isValidLocation ? selectedLocation : '');
      $('#branch-search').closest('.alm-combobox').toggleClass('invalid-location', !isValidLocation && selectedLocation.length > 0);
      toggleDeployBtn();
    }

    function loadSelectedInstances() {
      var savedSourceId = $('input[id$=src-instance-id]').val() || null;
      var savedRepoSourceId = $('input[id$=src-repo-id]').val() || null;
      var savedTargetId = $('input[id$=tgt-instance-id]').val() || null;

      $('#instance-panel .panel-tile').removeClass('selected');

      if (savedSourceId) {
        var instance = findInstanceCard( savedSourceId );
        var $selection = $('#source-selection');
        (instance.length > 0) ?
            selectInstance( instance, $selection, {unsaved: false} ) :
            displayDeletedInstancePlaceholder( savedSourceId, $selection );
      }

      if (savedRepoSourceId) {
        var $repo = findInstanceCard( savedRepoSourceId );
        selectRepo($repo, $('#source-selection'), false);
      }

      if(savedTargetId) {
        var instance = findInstanceCard( savedTargetId );
        var $selection = $('#target-selection');
        (instance.length > 0) ?
            selectInstance( instance, $selection, {unsaved: false} ) :
            displayDeletedInstancePlaceholder( savedTargetId, $selection );
      }
    }

    function findInstanceCard(instanceId) {
      return $('#instance-panel').find('div[data-id=' + instanceId + ']');
    }


    function loadState() {
      loadSelectedInstances();

      var pollOAuthId = AlmCommon.getUrlParameter('pollOAuthId');
      if (pollOAuthId) {
        window.history.pushState('', '', 'Slingshot2' + AlmCommon.removeUrlParameter('pollOAuthId'));

        var $oAuthInput = $('.oauth-container input[value="' + pollOAuthId + '"]');
        if ($oAuthInput.length) {
          OAuth.initPollOAuthUpdate(pollOAuthId, $oAuthInput.parents('.oauth-container'), null);
        }
      }
    }

    function displayDeletedInstancePlaceholder(id, $card) {
      remoteGetInstance(id, function(instanceObject, event) {
        if (event.status) {
          $card.data('selected-id', instanceObject.Id)
              .addClass('oauth-container disabled unauthorized selected')
              .attr('title', "The instance has been deleted. Please select a new one.")
              .find('.unauthorized-icon').show();
          $card.find('.instance-name')
              .text(instanceObject.Name)
              .attr('title', "");
          $card.find('.instance-user-name')
              .text("No user authorized")
              .attr('title', "");
        } else if (event.message){
          AlmCommon.showError(event.message);
        }
      });
    }

    function selectInstance($instanceCard, $targetArea, options) {
      options = options || {};
      var priorSelectedId = $targetArea.data('selected-id'),
       selectedInstanceId = $instanceCard.data('id'),
       selectedInstanceName = $instanceCard.data('name');

      findInstanceCard( priorSelectedId ).removeClass('selected');

      $targetArea.data('selected-id', selectedInstanceId);
      $targetArea.find('.instance-name').text(selectedInstanceName).attr('title', selectedInstanceName);
      $targetArea.addClass('selected');

      $targetArea.find('input[id$=instance-id]').val(selectedInstanceId);
      $targetArea.data('instance-id', selectedInstanceId);
      $targetArea.removeClass('authorized unauthorized disabled repo-source');
      $targetArea.attr('title', '');

      $instanceCard.addClass('selected');

      // Set unsaved to true unless options override it
      if(options.unsaved !== false) {
        setSavedStatus(true);
      }

      $targetArea.addClass('oauth-container');
      $targetArea.find('.instance-user-name').text("Checking authorization...");

      OAuth.getAuthStatus({
        selectedInstanceId : selectedInstanceId,
        oauthContainer : '#' + $targetArea[0].id,
        successCallback : function(authInfo, event) {
          if (authInfo && authInfo.isAuthorized) {
            $targetArea.find('.instance-user-name')
             .text(authInfo.preferred_username)
             .attr('title', authInfo.preferred_username);
          } else {
            $targetArea.find('.instance-user-name')
             .text("No user authorized")
             .attr('title', "No user authorized");
          }

          toggleDeployBtn();
        },
        errorCallback : function(message) {
          AlmCommon.showError(message);
        }
      });
    }

    function selectRepo($repoCard, $targetArea, setTheSavedStatus) {
      var priorSelectedId = $targetArea.data('selected-id'),
       selectedId = $repoCard.data('id'),
       selectedRepoName = $repoCard.data('name'),
       $branchSearch = $("#branch-search"),
       $sourceBranchValues = $("#source-selection .repo-info .filter-values");

      findInstanceCard( priorSelectedId ).removeClass('selected');

      $targetArea.data('selected-id', selectedId);
      $targetArea.find('.repo-name').text(selectedRepoName).attr('title', selectedRepoName);
      
      $targetArea.addClass('selected repo-source');

      $targetArea.find('input[id$=instance-id]').val('');
      $targetArea.find('input[id$=src-repo-id]').val(selectedId);
      //when loading an existing repo selection, copy the branch into the search field
      $branchSearch.val( $targetArea.find('input[id$=src-repo-location]').val() );
      
      
      $targetArea.data('instance-id', '');
      $targetArea.removeClass('authorized unauthorized disabled oauth-container');
      $targetArea.attr('title', '');

      $repoCard.addClass('selected');

      $branchSearch.removeData("branches");
      $sourceBranchValues.empty();
      remoteRetrieveBranches(selectedId, function(branches, event) {
        if (event.status) {
          AlmCommon.clearMsgs();
          $sourceBranchValues.html(
            branches.map(function(branch) {
              return "<option>" + branch + "</option>"
            }).join()
          );
          $branchSearch.data("branches", branches);
          ComboBox.setSource( $branchSearch, false );
        } else if (event.message){
          AlmCommon.showError(event.message);
        }
      });
      if(setTheSavedStatus !== false) {
        setSavedStatus(true);
      }
      toggleDeployBtn();
    }

    function finishAuthPolling(selectedInstanceId, $oAuthContainer) {
      OAuth.getAuthStatus(generateOAuthConfig($oAuthContainer, selectedInstanceId));

      var $otherOAuthCard = ($oAuthContainer.prop('id').indexOf('source') > -1) ?
                            $('#target-selection') : $('#source-selection');
      if ($otherOAuthCard.hasClass('selected') && ( $otherOAuthCard.data('selected-id') === selectedInstanceId )) {
        OAuth.getAuthStatus(generateOAuthConfig($otherOAuthCard, selectedInstanceId));
      }
    }

    function generateOAuthConfig($oAuthContainer, instanceId) {
      return {
        selectedInstanceId : instanceId,
        oauthContainer : '#' + $oAuthContainer.prop('id'),
        successCallback : function(authInfo, event) {
          if ( $oAuthContainer.data('selected-id') !== instanceId ) {
            return;
          }

          if (authInfo && authInfo.isAuthorized) {
            $oAuthContainer.find('.instance-user-name')
              .text(authInfo.preferred_username)
              .attr('title', authInfo.preferred_username);
          } else {
            $oAuthContainer.find('.instance-user-name')
              .text('No user authorized')
              .attr('title', 'No user authorized');
          }

          OAuth.cancelChangeAuthorizedCredentials($oAuthContainer);
          toggleDeployBtn();
        },
        errorCallback : function(message) {
          AlmCommon.showError(message);
        }
      }
    }

    function toggleDeployBtn() {
      var sourceInstance = $('#source-selection');
      var targetInstance = $('#target-selection');
      var validateButton = $('.validate-btn');
      var deployButton = $('.deploy-btn');

      var isRepoSelectionValid = sourceInstance.hasClass('repo-source') && sourceInstance.find('input[id$=src-repo-location]').val();

      if ((sourceInstance.hasClass('authorized') || buildIsManualUpload() || isRepoSelectionValid) &&
          targetInstance.hasClass('authorized'))
      {
        validateButton.removeClass('inactive-validate').addClass('really-important-btn');
        deployButton.removeClass('inactive-deploy').addClass('important-btn');

        if (!isDeploymentInProgress()) {
          toggleButtonState(false);
        }
      } else {
        validateButton.removeClass('really-important-btn').addClass('inactive-validate');
        deployButton.removeClass('important-btn').addClass('inactive-deploy');

        toggleButtonState(true);
      }
    }

    function toggleButtonState(isDisabled) {
      var validateButton = $('.validate-btn');
      var deployButton = $('.deploy-btn');

      validateButton.prop('disabled', isDisabled);
      deployButton.prop('disabled', isDisabled);
    }

    function readyForBuild() {
      return validateDeployName();
    }

    function trackValidationsOrDeployments(repoId, repoBranch, eventType) {
      if (repoId && repoBranch) {
        Analytics.trackEvent('Slingshot', eventType, 'Slingshot - Repository Branch '+ eventType);
      } else if (buildIsManualUpload()) {
        Analytics.trackEvent('Slingshot', eventType, 'Slingshot - Uploaded Package '+ eventType);
      } else {
        Analytics.trackEvent('Slingshot', eventType, 'Slingshot - Instance '+ eventType);
      }
    }

    function createBuildRecord(actionType) {
      var repoId = $("#source-selection").find('input[id$=src-repo-id]').val(),
          repoBranch = $("#source-selection").find('input[id$=src-repo-location]').val(),
          instanceId = $("#source-selection").find('input[id$=src-instance-id]').val(),
          testLevel = $("#ss-container .deployment-form").find('input[id$=test-level]').val();

      if (actionType === VALIDATE_ACTION) {
        closeDeploymentForm();
        trackValidationsOrDeployments(repoId, repoBranch, 'Validate');
      } else {
        trackValidationsOrDeployments(repoId, repoBranch, 'Deploy');
        if ($('#quickdeploy-options input[id$="is-quickdeploy"]').prop('checked')) {
          Analytics.trackEvent('Slingshot', 'Quick Deploy');
        }
      }

      if (testLevel === "RunSpecifiedTests") {
        Analytics.trackEvent('Slingshot', 'Run Specified Test Classes');
      }

      if(!readyForBuild()) {
        return;
      }

      $('#slingshot-card-body').removeClass('has-errors');
      resetDeploymentListState();
      var args = {
          deploymentText: BW.utils.stages.PENDING,
          deploymentTextCssClass: 'pending',
          deploymentImageCssClass: 'pending',
          showFailText: false,
          progressLabelText: ''
      };

      BW.utils.setActionTextAndImage(args);
      setIsDeploymentInProgress(true);
      setActionType(actionType);
      saveDeployment({ toggleSaveForm: false, startAssembler: true });
      showActionButtonOverlay(actionType);
      disableReset(true);
      toggleQuickDeployState(false);
    }

    function kickoffDeployer() {
      window.setTimeout(function delayFinishBuild() {

        //reset component progress
        $('.wrap-container-labels.components').data('comps-deployed', 0);
        $('.wrap-container-labels.apex').data('tests-run', 0);

        drawRadialProgress(BW.utils.constants.ASSEMBLE_PROGRESS_SPEED, BW.utils.colors.PENDING, BW.utils.colors.PENDING, false);
        RequestManager.invokeFunction(afFinishBuild, null, { callback: function() {
            finishDeploymentErrorsLoad();
            pollDeploymentStatus();
          }
        });
      }, 3000);
    }

    function loadDeploymentResults(deployment) {
      if (deployment && deployment.deploymentAttempt) {
        var attempt = deployment.deploymentAttempt;

        if (!attempt.isNotStarted) {
          if ( (deployment.buildStatus === "Failed") || (deployment.totalBuildErrors > 0) ) {
            BW.assembler.displayBuildErrorResult(deployment.totalBuildErrors, attempt.assembleRequestError);
          } else {
            showProgressResultAndImage({
              type : "build",
              resultText :"Success",
              result: "pass"
            });
          }

          if (deployment.isSuccess === false && attempt.assembleRequestError === undefined) {
            $("#slingshot-card-body").addClass('has-errors');
          }
          if (!attempt.inProgress) {
            displayDeploymentResults(attempt);
          }
          displayDeploymentId({attemptModel: attempt});
        }

        setStartTimeText(attempt);
        setEndTimeText(attempt);
      } else {
        drawRadialProgress(TEN_SECONDS, BW.utils.colors.PENDING, BW.utils.colors.PENDING, false);
      }
    }

    function pollDeploymentStatus() {
      var buildId = getCompletedBuildId();

      if (!buildId) { return; }

      // Only enable cancel icon if the deployment
      // has not already initiated a cancel
      if(!BW.cancel.isCancelInProgress()) {
        BW.cancel.enableCancelDeploy();
      }

      getUpdatedDeployment(buildId, function(deploymentAttemptModel, event) {
        if (event.status) {
          var progress = new DeploymentAttemptProgress(deploymentAttemptModel);

          var $componentLabelContainer = $('.wrap-container-labels.components');
          var $apexLabelContainer = $('.wrap-container-labels.apex');

          var progressColor = getActionColor(deploymentAttemptModel.deploymentType);

          var currentMetricInProgress = (progress.numberTestsTotal < 1 ? "components" : "apex");
          if (currentMetricInProgress === "components") {
            drawRadialProgress(1500, BW.utils.colors.PENDING, progressColor, false, $componentLabelContainer.data('comps-deployed') , progress.numberComponentsTotal);
            $componentLabelContainer.data('comps-deployed', progress.numberComponentsDeployed);

            $('.component-progress').data('radial-progress').animate(progress.componentProgressVal);
          } else {
            drawRadialProgress(1500, BW.utils.colors.PENDING, progressColor, false, $apexLabelContainer.data('tests-run') , progress.numberTestsTotal);
            $apexLabelContainer.data('tests-run', progress.numberTestsCompleted);

            $('.component-progress').data('radial-progress').animate(progress.apexProgressVal);
          }

          displayDeploymentId({attemptModel : deploymentAttemptModel});

          if (deploymentAttemptModel.inProgress) {
            $("img[id$=selected-action-img]").hide();

            displayProgressResults(deploymentAttemptModel, progress.numberTestsTotal, progress.apexProgressVal);

            setEndTimeText(deploymentAttemptModel);
          }

          if (['succeeded', 'failed', 'canceled'].indexOf(deploymentAttemptModel.status) > -1) {
            //Reset validate/deploy state
            setIsDeploymentInProgress(false);
            displayDeploymentResults(deploymentAttemptModel);
            setEndTimeText(deploymentAttemptModel);

            RequestManager.invokeFunction(
              afFinishDeployment,
              getCurrentSavedDeploymentId(),
              {
                callback: BW.assembler.finishManifestLoad
              }
            );
            //re-load the deployments list to get any update deployment model information
            BW.loadDeployments.loadDeploymentsForRelease( getReleaseId() );
            saveDisabled(false);
            disableReset(false);
            BW.cancel.hideActionButtonOverlay();
          } else {
            if(BW.cancel.isCancelInProgress()) {
              BW.cancel.updateActionText();
            }
            pollDeploymentTimeout = window.setTimeout( pollDeploymentStatus, BW.utils.constants.FIVE_SECONDS );
          }

          if (deploymentAttemptModel.hasComponentErrors ||
              deploymentAttemptModel.hasTestErrors ||
              deploymentAttemptModel.hasCodeCoverageErrors) {
            $("#slingshot-card-body").addClass('has-errors');
          }

        } else if (event.message){
          AlmCommon.clearMsgs();
          AlmCommon.showError( event.message);
        }
      });
    }

    function finishDeploymentErrorsLoad() {
      collapseDeploymentErrorTables();

      $('.simple-accordion-errors table.alm-table').trigger("destroy").tablesorter({
        cssAsc: 'asc',
        cssDesc: 'desc',
        cssNone: 'unsorted',
        emptyTo: 'bottom'
      });
      addStickyAlert();
    }

    function displayProgressResults(deploymentAttemptModel, componentProgressVal, apexProgressVal) {
        // If component progress is less than one, then it means the components are being deployed.
        // Components are finished once the component progress value is equal to one
        if (componentProgressVal < 1) {
          setCurrentDeploymentMetric("components");

          updateComponentProgress(deploymentAttemptModel);
        } else if (apexProgressVal < 1) {
          setCurrentDeploymentMetric("apex");

          // Same as components but for unit tests
          // If the unit tests are in progress, we want to display the results for components
          // And update the apex progress result
          displayComponentProgressResult(deploymentAttemptModel);

          RequestManager.invokeFunction(afGetDeploymentErrors, null, { callback: finishDeploymentErrorsLoad });

          updateApexProgress(deploymentAttemptModel);
        }
    }

    function setCurrentDeploymentMetric(currentItem) {
      $("#manifest-body").data("current-deployment-metric", currentItem);
    }

    function closeOtherOpenTrays(paneIdOpen) {
      // When new pane is added, add the ID and toggle handler here
      var allPanels = [
        {id: 'manifest-edit-pane', toggle: BW.assembler.toggleAddComponentsTray},
        {id: 'manifest-filter-pane', toggle: BW.assembler.toggleFilterManifestTray},
        {id: 'profile-edit-pane', toggle: BW.assembler.toggleProfileEdit},
        {id: 'load-deployment-pane', toggle: toggleLoadDeploymentTray}
      ];

      var panelsToClose = allPanels.filter(function(panelOpts) {return panelOpts.id !== paneIdOpen});
      panelsToClose.forEach(function(p){
        // Look for the handle class which should be a sibling
        var $handle = $('#' + p.id).prevAll("[class*='handle']").first();
        if ($handle.hasClass('close')) {
          p.toggle();
        }
      });

      closeManifestLegend();
    }

    function initConfirmSlider() {
      $( "#slider" ).slider({
        value: 0,
        min: 0,
        max: 1000,
        step: 1,
        range: 'min',
        animate:"fast",
        slide: function( event, ui ) {
          var $slider = $('.slider-container');
          $slider.find('.ui-slider-legend').remove();

          if (ui.value > 200 && ui.value < 985) {
            $slider.removeClass('confirm-end');
            $slider.addClass('confirming');
            $slider.append('<div class="ui-slider-legend">Almost There</div>');

            $('.ui-slider-legend').position({
              of: '.ui-slider-handle',
              within: $slider,
              at: "center bottom+15",
              my: "center bottom",
              collision: "none"
            });
          } else if (ui.value >= 985){
            $slider.removeClass('confirming');
            $slider.addClass('confirm-end');
          } else {
            $slider.removeClass('confirming confirm-end');
          }
        },
        stop: function(event, ui) {
          var $slider = $('.slider-container');
          $slider.removeClass('confirming confirm-end');
          if (ui.value < 985) {
            $slider.find('.ui-slider-legend').remove();
            $(this).slider('value', 0);
          } else {
            $slider.closest('.confirm-panel').addClass('confirmed');
            $(this).slider( 'disable' );
            createBuildRecord(DEPLOY_ACTION);
            AlmCommon.toggleSave();
            window.setTimeout(function() {
              closeDeploymentForm();
              $('.confirm-panel').hide("slide", {
                direction: "right",
                complete: function() {
                  resetConfirmSlider();
                }
              });
            }, 3500)
          }
        }
      });

      $("#cancel-confirm").on("click", closeConfirmPanel);
    }

    function closeConfirmPanel(e) {
      $('.confirm-panel').hide();

      if (e !== undefined) {
        e.preventDefault();
      }
    }

    function resetConfirmSlider() {
      var $slider = $( "#slider" );
      $slider.slider( 'enable' );
      $slider.slider('value', 0);
      $slider.closest('.confirm-panel').removeClass('confirmed');
    }

    function toggleLoadDeploymentTray() {
      var $handle = $( '#load-deployment-handle'),
      $tray =  $('#load-deployment-pane'),
      handlePosition = '95.1%',
      options = {
        expandParent : true
      };

      closeOtherOpenTrays('load-deployment-pane');
      closeDeploymentForm();
      AlmCommon.toggleSlidingTray( $tray, $handle, handlePosition, options);

      if($('#load-deployment-pane').data('deployments-init') !== true) {
        AlmCommon.blockUI('#load-deployment-pane');
        $('#load-deployment-pane').data('deployments-init', true);
        BW.loadDeployments.loadDeploymentsForRelease( getReleaseId() );
      }
    }

    function updateComponentProgress(deploymentAttemptModel) {
      showProgressResultAndImage({
        type : "components",
        result : "in-progress",
        resultText : ""
      });

      var numberComponentsTotal = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Components_Total__c', 0);
      var numberComponentsDeployed = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Components_Deployed__c', 0);

      if (numberComponentsTotal  === 0) {
        var args = {
            deploymentText: BW.utils.stages.PENDING,
            deploymentTextCssClass: 'pending',
            deploymentImageCssClass: 'pending',
            showFailText: false,
            progressLabelText: ''
        };

        BW.utils.setActionTextAndImage(args);
        $("img[id$=selected-action-img]").show();
      } else {
        $("img[id$=selected-action-img]").hide();
        var progress = numberComponentsDeployed + " / " + numberComponentsTotal ;

        var args = {
            deploymentText: BW.utils.stages.COMPONENTS,
            deploymentTextCssClass: 'pending',
            deploymentImageCssClass: 'pending',
            showFailText: false,
            progressLabelText: progress
        };
        BW.utils.setActionTextAndImage(args);
      }


      showProgressTypeAndImage("components", "in-progress");
    }

    function updateApexProgress(deploymentAttemptModel) {
      var numberTestsCompleted = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Tests_Completed__c', 0);
      var numberTestsTotal = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Tests_Total__c', 0);

      showProgressResultAndImage({
        type : "apex",
        result : "in-progress",
        resultText : ""
      });

      var progress = numberTestsCompleted + " / " + numberTestsTotal;

      var args = {
          deploymentText: BW.utils.stages.UNIT_TESTS,
          deploymentTextCssClass: 'pending',
          deploymentImageCssClass: 'pending',
          showFailText: false,
          progressLabelText: progress
      };

      BW.utils.setActionTextAndImage(args);

      showProgressTypeAndImage("apex", "in-progress");
    }


    /**
     * @param {DeploymentModel.Attempt} the deployment attempt model
     * @param {DeploymentAttemptProgress} - optional reference to the progress details
     */
    function displayDeploymentResults(deploymentAttemptModel, progress) {
      var deploymentType = deploymentAttemptModel.deploymentType,
      deploymentStatus = deploymentAttemptModel.status,
      progress = progress || new DeploymentAttemptProgress(deploymentAttemptModel),
      canceledText,
      totalProcessed,
      totalComponents;

      if (deploymentStatus === 'succeeded') {
        var args = {
            deploymentText: (deploymentType === "validation" ? "validated" : "deployed"),
            deploymentTextCssClass: deploymentType,
            deploymentImageCssClass: deploymentType + "-pass",
            showFailText: false,
            progressLabelText: ''
        };

        BW.utils.setActionTextAndImage(args);

        if (deploymentAttemptModel.isQuickDeploy === true) {
          toggleQuickDeployState(true);
          $('.quick-deploy .hover-help').tooltip();
        }

        var progressColor = getActionColor(deploymentType);
        drawRadialProgress(BW.utils.constants.ASSEMBLE_PROGRESS_SPEED, progressColor, progressColor, false);

      } else if (deploymentStatus === 'failed') {
        drawRadialProgress(BW.utils.constants.ASSEMBLE_PROGRESS_SPEED, BW.utils.colors.FAIL, BW.utils.colors.FAIL, false);

        var args = {
            deploymentText: deploymentType+":",
            deploymentTextCssClass: deploymentType,
            deploymentImageCssClass: "fail",
            showFailText: true,
            progressLabelText: ''
        };

        BW.utils.setActionTextAndImage(args);
      } else if(deploymentStatus === 'canceled') {

        if (deploymentAttemptModel.componentResult === 'canceled') {
          totalProcessed = progress.numberComponentsDeployed;
          totalComponents = progress.numberComponentsTotal;
          canceledText = totalProcessed + " / " + totalComponents + "<br/>Components";
        } else {
          totalProcessed = progress.numberTestsCompleted;
          totalComponents = progress.numberTestsTotal;
          canceledText = totalProcessed + " / " + totalComponents + "<br/>Unit Tests";
        }

        drawRadialProgress(BW.utils.constants.ASSEMBLE_PROGRESS_SPEED, BW.utils.colors.PENDING, BW.utils.colors.CANCEL, false, totalProcessed, totalComponents);

        var args = {
            deploymentText: BW.utils.stages.CANCELED,
            deploymentTextCssClass: "canceled",
            deploymentImageCssClass: "canceled",
            showFailText: false,
            progressLabelText: canceledText
        };

        BW.utils.setActionTextAndImage(args);
      }

      displayComponentProgressResult(deploymentAttemptModel)

      displayCodeCovergeResult(deploymentAttemptModel);

      displayApexProgressResult(deploymentAttemptModel);

      $("img[id$=selected-action-img]").show();

      toggleButtonState(false);

      if (deploymentAttemptModel.assembleRequestError !== undefined) {
        AlmCommon.showError(deploymentAttemptModel.assembleRequestError, {
          clearPriorMessages: true,
          messagePanel: '#slingshot-card-errors'
        });
      }
    }

    function displayComponentProgressResult(deploymentAttemptModel) {
      var componentErrors = deploymentAttemptModel.numberComponentsErrors;
      var componentResult = deploymentAttemptModel.componentResult;
      var progress = new DeploymentAttemptProgress(deploymentAttemptModel);
      var resultCssClass = componentResult;

      var componentResultMessage;
      var componentTypeLabel;

      if (componentResult === deploymentAttemptModel.NOT_APPLICABLE) {
        componentResultMessage = deploymentAttemptModel.NOT_APPLICABLE;
        componentResult = 'not-applicable';
      } else if (componentResult === deploymentAttemptModel.RESULT_PASS) {
        componentResultMessage = progress.numberComponentsTotal;
      } else if (componentResult === deploymentAttemptModel.RESULT_FAIL) {
        componentResultMessage = (componentErrors === 1) ? componentErrors + " Error" : componentErrors + " Errors";
        componentTypeLabel = progress.numberComponentsTotal;
      } else if (componentResult === deploymentAttemptModel.RESULT_CANCELED){
        componentResultMessage = (componentErrors === 0) ? progress.numberComponentsDeployed : componentErrors + " Errors";
        componentTypeLabel = progress.numberComponentsTotal;
        resultCssClass = (componentErrors === 0) ? deploymentAttemptModel.RESULT_CANCELED : deploymentAttemptModel.RESULT_FAIL;
      }

      showProgressResultAndImage({
        type : "components",
        resultText : componentResultMessage,
        result: componentResult,
        resultCss: resultCssClass,
        itemCount: componentTypeLabel
      });
    }

    function displayCodeCovergeResult(deploymentAttemptModel) {
      var codeCoverage = deploymentAttemptModel.codeCoverage;
      var codeCoverageResult;

      if (codeCoverage === deploymentAttemptModel.NOT_APPLICABLE) {
        codeCoverageResult = "not-applicable";
      } else if (isNaN(codeCoverage)) {
        return;
      } else {
        codeCoverage = Number(codeCoverage);

        if (deploymentAttemptModel.hasCodeCoverageErrors) {
            codeCoverageResult = deploymentAttemptModel.RESULT_FAIL;
        } else {
            codeCoverageResult = (codeCoverage >= 75) ? deploymentAttemptModel.RESULT_PASS : deploymentAttemptModel.RESULT_FAIL;
        }

        codeCoverage += "%";
      }

      showProgressResultAndImage({
        type : "coverage",
        resultText : codeCoverage,
        result: codeCoverageResult
      });
    }

    function displayApexProgressResult(deploymentAttemptModel) {
      var totalTests = deploymentAttemptModel.apexTestsTotal;
      var testErrors = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Test_Errors__c', 0);
      var apexResult = deploymentAttemptModel.apexResult;
      var resultCssClass = apexResult;

      var apexResultMessage = totalTests;
      var totalTestCount;

      if (isNaN(totalTests)) {
        apexResultMessage = deploymentAttemptModel.NOT_APPLICABLE;
        apexResult = 'not-applicable';
        resultCssClass = '';
      } else if (deploymentAttemptModel.componentResult === deploymentAttemptModel.RESULT_CANCELED) {
        apexResultMessage = deploymentAttemptModel.NOT_APPLICABLE;
      } else if (totalTests === deploymentAttemptModel.NOT_RAN) {
        apexResult = "in-progress";
      } else if (apexResult === deploymentAttemptModel.RESULT_FAIL) {
        apexResultMessage = (testErrors === 1) ? testErrors + " Error" : testErrors + " Errors";
        totalTestCount = totalTests;
      } else if (apexResult === deploymentAttemptModel.RESULT_CANCELED) {
        var testsCompleted = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'Number_Tests_Completed__c', 0);
        apexResultMessage = (testErrors === 0) ? testsCompleted : testErrors + " Errors";
        resultCssClass = (testErrors === 0) ? deploymentAttemptModel.RESULT_CANCELED : deploymentAttemptModel.RESULT_FAIL;
        totalTestCount = totalTests;
      }

      showProgressResultAndImage({
        type : "apex",
        resultText : apexResultMessage,
        result: apexResult,
        resultCss: resultCssClass,
        itemCount: totalTestCount
      });
    }

    function resetSlingshot() {
      AlmCommon.setHasUnsavedChanges(false);

      removeWarning();
      RequestManager.invokeFunction(afLoadDeployment, '', { callback: onLoadDeploymentComplete });
    }


    function displayWarning(warningMsg) {
      if (!$('.deployment-reset').hasClass('disabled')) {

          // If Tray is open, close it.
          var $handle = $('#load-deployment-handle');
          if ($handle.hasClass("close")) {
              //Close the deployment tray, but wait until the animiation finished to show prompt
              toggleLoadDeploymentTray();
              setTimeout(resetManifestPrompt, 1000);
          } else {
              resetManifestPrompt();
          }
      }
    }

    function resetManifestPrompt() {
        // Force modal to be on top of any open confirmation panel and deployment form
        $(".ss-record-wrap").children(".blockOverlay").css('z-index', 1011);

        $('.deployment-reset').toggleClass('disabled');

        $('.confirm-panel').hide();

        closeDeploymentForm();

        var warningCard = templates["sprint_warning"].render({
          "message" : "Are you sure you want to reset the manifest and start a new deployment with only documented components?",
          "mainClass" : "reset-manifest-modal"
        });

        BW.utils.blockSlingshotCard('#slingshot-card-body', warningCard, false);
        $('.sp-card-wrap-error').show();
    }


    function removeWarning() {
      BW.utils.unblockSlingshotCard('#slingshot-card-body');

      $('.deployment-reset').toggleClass('disabled');
    }

    /**
     * Disable the reset link for the slingshot card
     */
    function disableReset(disable) {
      if (disable === true) {
        $('.deployment-reset').addClass('disabled');
      } else {
        $('.deployment-reset').removeClass('disabled');
      }

    }

    /**
    * Displays the overlay for the validate/deploy buttons
    * @param {string} type - VALIDATE_ACTION or DEPLOY_ACTION
    */
    function showActionButtonOverlay(type) {
      var overlay = $('#action-button-overlay');
      if(type === VALIDATE_ACTION) {
        overlay
          .addClass('really-important-btn')
          .children('.content')
          .addClass('validating');
      } else {
        overlay
          .addClass('important-btn')
          .children('.content')
          .addClass('deploying');
      }

      overlay.show();
    }

    /**
     * Displays the progress type and the vertical bar image
     *
     * @param type The current progress to display. Values are: build, components, coverage, apex
     * @param status The name of the CSS class to apply to the vertical bar image
     */
    function showProgressTypeAndImage(type, status) {
      switch(type) {
        case 'build':
          $('.wrap-container-labels.build .progress-type').show();
          $('.wrap-container-image.build img').removeClass().addClass("build").addClass(status).show();
          break;
        case 'components':
          $('.wrap-container-labels.components .progress-type').show();
          $('.wrap-container-image.components img').addClass("components").addClass(status).show();
          break;
        case 'coverage':
          $('.wrap-container-labels.coverage .progress-type').show();
          $('.wrap-container-image.coverage img').addClass("coverage").addClass(status).show();
          break;
        case 'apex':
          $('.wrap-container-labels.apex .progress-type').show();
          $('.wrap-container-image.apex img').addClass("apex").addClass(status).show();
          break;
      }
    }

    /**
     * Show the progress result text and corresponding vertical bar image.  This is the progress result that are
     * in the 4 corners of the deployment card
     *
     * @param args  {Object}  argument object
     * @param args.type The type of progress to show.  Choices are build, components, coverage, apex
     * @param args.resultText The result to display for the given progress.  Ex: Success, 50 Errors, etc.
     * @param args.result The name of the CSS class to apply to the result image'
     * @param args.resultCss The name of the CSS class to apply to the resultText parameter
     * @param args.itemCount optional- The # of items if applicable, e.g. the number of tests or components
     */
    function showProgressResultAndImage(args) {
      args = args || {};
      var resultCss = args.resultCss || args.result;

      var $section, typeText;

      switch(args.type) {
        case 'build':
          $section = $(".wrap-container-end-columns.build");
          typeText = "Build";
          break;
        case 'components':
          $section = $(".wrap-container-end-columns.components");
          typeText = args.itemCount === undefined ? "Components" : args.itemCount + " Components";
          break;
        case 'coverage':
          $section = $(".wrap-container-end-columns.coverage");
          typeText = "Code Coverage";
          break;
        case 'apex':
          $section = $(".wrap-container-end-columns.apex");
          typeText = args.itemCount === undefined ? "Unit Tests" : args.itemCount + " Unit Tests";
          break;
      }

      $section.find('.progress-result').text(args.resultText);
      $section.find('.progress-result').removeClass("fail pass").addClass(resultCss).show();
      $section.find('.progress-type').text(typeText).show();

      $section.find('.wrap-container-image img').removeClass().addClass(args.type).addClass(args.result).show();
    }


    /**
     * Hide all progress result values for the deployment and reset the progress circle to it's default state
     */
    function resetProgressMetrics() {
      $('.wrap-container-labels.build .progress-result').hide();
      $('.wrap-container-labels.build .progress-type').hide();
      $('.wrap-container-image.build img').hide()

      $('.wrap-container-labels.components .progress-result').hide();
      $('.wrap-container-labels.components .progress-type').hide();
      $('.wrap-container-image.components img').hide();

      $('.wrap-container-labels.coverage .progress-result').hide();
      $('.wrap-container-labels.coverage .progress-type').hide();
      $('.wrap-container-image.coverage img').hide();

      $('.wrap-container-labels.apex .progress-result').hide();
      $('.wrap-container-labels.apex .progress-type').hide();
      $('.wrap-container-image.apex img').removeClass().hide();

      setStartTimeText({startTime:''});
      setEndTimeText({endTime:''});

      drawRadialProgress(BW.utils.constants.ASSEMBLE_PROGRESS_SPEED, BW.utils.colors.PENDING, BW.utils.colors.PENDING, false);
    }

    /**
     * Display the deployment id on the deployment results section
     * @param options
     *        options.attemptModel  - the DeploymentModel.Attempt
     *        options.isBuilding  - boolean indicating if a build is in progress
     */
    function displayDeploymentId(options) {
      var options = options || {};
      var attemptModel = options.attemptModel;
      var idText = 'N/A';

      if (isBuildInProgress() || options.isBuilding) {
        idText = 'Pending';
      } else if (attemptModel && attemptModel.sfDeploymentId) {
        idText = attemptModel.sfDeploymentId;
      }

      $('#sf-deployment-id-container span').text(idText);
    }

    /**
     * Sets Start Time for the current deployment
     *
     * @param deploymentAttemptModel The current deploymentAttemptModel object for the deployment
     */
    function setStartTimeText(deploymentAttemptModel) {
      var message = "Start Time: " + deploymentAttemptModel.startTime;
      $('.time-started').text(message);
    }

    /**
     * Sets either the Finish Time or the state detail text for the current deployment
     *
     * @param deploymentAttemptModel The current deploymentAttemptModel object for the deployment
     */
    function setEndTimeText(deploymentAttemptModel) {
      var message;
      var stateDetail = AlmCommon.getSObjValue(deploymentAttemptModel.record, 'State_Detail__c');

      if (deploymentAttemptModel.inProgress) {
        $(".time-finished").removeClass().addClass("state-detail");
        message = stateDetail;
        $('.state-detail').text(message);
      } else {
        $(".state-detail").removeClass().addClass("time-finished");
        if (deploymentAttemptModel.endTime !== undefined) {
          message = "Finish Time: " + deploymentAttemptModel.endTime;
          $('.time-finished').text(message);
        }
      }
    }

    function loadDeployment(e) {
      if (e) {
        var $target = $(e.target);
        if ($target.is('.flyout-menu li')) {
          return;
        }
      }

      Analytics.trackEvent('Slingshot', 'Load Saved Deployment');

      AlmCommon.setHasUnsavedChanges(false);
      setIsDeploymentInProgress(false);
      disableReset(false);
      RequestManager.invokeFunction(
        afLoadDeployment,
        $(this).data('deployment-id'),
        {
          objectsToShow: ['#deploy-load-message-spinner-container'],
          classesToAdd: {
            '.deployment-name-static': ['message-spinner-active']
          },
          callback: onLoadDeploymentComplete
        }
      );
      toggleLoadDeploymentTray();
    }

    function onLoadDeploymentComplete() {
      $('#slingshot-card-body').removeClass('manifest-open has-errors');

      loadSelectedInstances();
      updateSaveHandlers();

      window.clearTimeout(pollDeploymentTimeout);
      window.clearTimeout(BW.assembler.getPollBuildTimeout());

      var deployment = getCurrentDeploymentModel();
      var deploymentAttempt = (deployment) ? deployment.deploymentAttempt : null;

      loadDeploymentResults(deployment);

      enableAvailableSourcesDrag();
      initConfirmSlider();

      checkSaveStatus();

      toggleDeployBtn();
      addStickyAlert();

      var getDeploymentType = function(depAttempt) {
        return depAttempt.deploymentType === 'validation' ? 'validate' : 'deploy';
      };

      if (deploymentAttempt) {
        if (deploymentAttempt.isPending || deploymentAttempt.inProgress) {
          setIsDeploymentInProgress(true);
          pollDeploymentStatus();
          saveDisabled(true);
          toggleButtonState(true);
          disableReset(true);
          showActionButtonOverlay(getDeploymentType(deploymentAttempt));
        } else if (isBuildInProgress()) {
          setIsDeploymentInProgress(true);
          var isValidation = AlmCommon.getSObjValue(deploymentAttempt.record, 'Is_Validation__c');
          setActionType(isValidation === true ? VALIDATE_ACTION : DEPLOY_ACTION);
          BW.assembler.startPolling();
          saveDisabled(true);
          toggleButtonState(true);
          disableReset(true);
          showActionButtonOverlay(getDeploymentType(deploymentAttempt));
        }
      }

      setSpecifedTests('');
    }

    function quickDeployClick(event) {
      var isChecked = $(this).prop("checked");

      var deployOptions = $('.deployment-form')
        .find('input[id$="rebuild-package-from-source"], .test-options .fancy-radio, .test-options');

      if (isChecked === true) {
        deployOptions
          .prop("disabled", true)
          .addClass("disabled")
          .prop("checked", false);
      } else {
        deployOptions
          .prop("disabled", false)
          .removeClass("disabled");

        initDeploymentOptions();
      }
      handleBackupTargetCheckBox();
    }

    function testOptionClick() {
      var $deployForm = $('.deployment-form'),
        testOptionVal = $deployForm.find('[name="test-level-radio"]:checked').val();
      var $testLevelInput = $deployForm.find('input[id$="test-level"]');
      if (testOptionVal !== $testLevelInput.val()) {
        $testLevelInput.val(testOptionVal);
        toggleSpecifiedTestsSection(testOptionVal === RUN_SPECIFIED_TESTS);
      }
    }

    function validateDeployName() {
      if(!$('#deploy-name-input').val()) {
        toggleSave();
        AlmCommon.showError('Deployment name cannot be blank.', {
          clearPriorMessages: true,
          messagePanel: '#slingshot-card-errors'
        });
        return false;
      }

      return true;
    }

    function toggleManifestLegend(event) {
      var isLegendOpen = $('#manifest-legend').hasClass('open');

      if (!isLegendOpen) {
        openManifestLegend();
      } else if (event && $(event.target).is('#manifest-legend-header-close')) {
        closeManifestLegend();
      }
    }

    function openManifestLegend() {
      $('#manifest-legend').addClass('open');
    }

    function closeManifestLegend() {
      $('#manifest-legend').removeClass('open');
    }

    function selectTestClasses() {
      var availableTests = $(slingshotPage.availableTests).val();
      var specifiedTests = $(slingshotPage.specifiedTests).val();

      $('#available-tests-column').data('previous-test-values', availableTests);
      $('#specified-tests-column').data('previous-test-values', specifiedTests);

      $('#specified-tests-info')
        .toggle(specifiedTests !== "")
        .find('.selected-tests-count')
        .text((specifiedTests) ? specifiedTests.split(',').length + ' Tests Selected | ' : '');

      toggleSpecifiedTestsSection(false);
      if(!specifiedTests) {
        resetTestOptionToDefault()
      }
    }

    function cancelTestSelection() {
      toggleSpecifiedTestsSection(false);
      resetDefaultTests();

      if(!$(slingshotPage.specifiedTests).val() &&
          ($('.deployment-form').find('input[id$="test-level"]').val() === 'RunSpecifiedTests')) {
        resetTestOptionToDefault();
      }
    }

    function resetTestOptionToDefault() {
      var $defaultRadioButton = $("#test-level-radio-0");
      $defaultRadioButton.prop('checked', true);
      testOptionClick();
    }

    function resetDefaultTests() {
      $(slingshotPage.availableTests).val($('#available-tests-column').data('previous-test-values'));
      $(slingshotPage.specifiedTests).val($('#specified-tests-column').data('previous-test-values'));
    }

    function toggleSpecifiedTestsSection(isOpen) {
      $('#ss-container')
          .find('.deployment-form-tests-list, .deployment-form-tests-buttons')
          .toggle(isOpen);

      var $testOptions = $('.deployment-form-options.test-options');
      var $infoEditButton = $('#specified-tests-info .edit-selected-tests');
      if (isOpen) {
        $testOptions.addClass('borderless-left');
        $infoEditButton.addClass('inactive-edit');
        var $specifiedTestButton = $('#specified-tests-info');
        if (!$specifiedTestButton.data('rendered')) {
          $('.deployment-form-tests-list').addClass('hidden-lists');
          BW.assembler.startParsePackageUpdatePolling(loadApexTestClasses);
        } else {
          resetDefaultTests();
          renderDuelingLists();
        }
      } else {
        $infoEditButton.removeClass('inactive-edit');
        $testOptions.removeClass('borderless-left');
      }
    }

    function loadApexTestClasses() {
      RequestManager.invokeFunction (
        afLoadAvailableTestClasses,
        null,
        {
          callback: function() {
            BW.assembler.displayParseBuildError();
            renderDuelingLists();
            $('#available-tests-column').data('previous-test-values', $(slingshotPage.availableTests).val());
            $('#specified-tests-column').data('previous-test-values', $(slingshotPage.specifiedTests).val());
            $('.deployment-form-tests-list').removeClass('hidden-lists');
          }
        }
      );
      $('#specified-tests-info').data('rendered', true);
    }

    function renderDuelingLists() {
      var delimitedAvailableTests = $(slingshotPage.availableTests).val(),
          delimitedSpecifiedTests = $(slingshotPage.specifiedTests).val(),
          $availableTestColumn = $('#available-tests-column'),
          $specifiedTestColumn = $('#specified-tests-column'),
          availableTestClassItem = {"dueling_list_item_row" : templates["dueling_list_item_row"]},
          specifiedTestClassItem = {"dueling_list_item_row" : templates["dueling_list_item_row"]};

      var availableTests = (delimitedAvailableTests) ? delimitedAvailableTests.split(',').sort() : "";
      var specifiedTests = (delimitedSpecifiedTests) ? delimitedSpecifiedTests.split(',').sort() : "";

      var availableTestsTemplate = templates["dueling_list_column"].render({
        "items" : availableTests,
        "title" : "Available Tests (" + availableTests.length+ ")"
      }, availableTestClassItem);

      var specifiedTestsTemplate = templates["dueling_list_column"].render({
        "items" : specifiedTests,
        "title" : "Selected Tests (" + specifiedTests.length+ ")"
      }, specifiedTestClassItem);

      $availableTestColumn.html(availableTestsTemplate);
      $specifiedTestColumn.html(specifiedTestsTemplate);
    }

    return new ApiBuilder({
      pure: {
        buildIsManualUpload : buildIsManualUpload,
        collapseDeploymentErrorTables: collapseDeploymentErrorTables,
        closeOtherOpenTrays : closeOtherOpenTrays,
        drawRadialProgress : drawRadialProgress,
        finishDeploymentErrorsLoad : finishDeploymentErrorsLoad,
        finishValidateAuth : finishValidateAuth,
        getActionColor: getActionColor,
        kickoffDeployer : kickoffDeployer,
        loadDeploymentComplete: onLoadDeploymentComplete,
        toggleDeployBtn : toggleDeployBtn,
        pollDeploymentStatus : pollDeploymentStatus,
        saveDeploymentComplete: onSaveDeploymentComplete,
        saveDisabled : saveDisabled,
        setActionTextAndImage : BW.utils.setActionTextAndImage,
        setStartTimeText : setStartTimeText,
        setSavedStatus : setSavedStatus,
        showProgressResultAndImage : showProgressResultAndImage,
        showProgressTypeAndImage : showProgressTypeAndImage
      },
      testOnly: {
        buildIsManualUpload : buildIsManualUpload,
        createBuildRecord : createBuildRecord,
        toggleLoadDeploymentTray: toggleLoadDeploymentTray,
        loadDeployment : loadDeployment,
        loadDeploymentResults: loadDeploymentResults,
        saveDeployment : saveDeployment,
        setSaveAsDeployment : setSaveAsDeployment,
        isSaveAsDeployment : isSaveAsDeployment,
        deploymentSaveAsOptionClick : deploymentSaveAsOptionClick,
        deploymentSaveOptionClick : deploymentSaveOptionClick,
        displayApexProgressResult : displayApexProgressResult,
        displayComponentProgressResult : displayComponentProgressResult,
        addEventHandlers : addEventHandlers,
        updateSaveHandlers : updateSaveHandlers,
        initDeploymentOptions : initDeploymentOptions,
        getActionType : getActionType,
        getActionColor : getActionColor,
        collapseDeploymentErrorTables : collapseDeploymentErrorTables,
        closeDeploymentForm : closeDeploymentForm,
        loadState : loadState,
        loadSelectedInstances: loadSelectedInstances,
        selectInstance : selectInstance,
        selectRepo : selectRepo,
        setEndTimeText: setEndTimeText,
        setToggleSaveFunct : function(funct) { toggleSave = funct; },
        showDeploymentForm : showDeploymentForm,
        stickyExpandElem : stickyExpandElem,
        testOptionClick : testOptionClick,
        toggleSpecifiedTestsSection : toggleSpecifiedTestsSection,
        toggleManifestLegend : toggleManifestLegend,
        selectRepoLocation : selectRepoLocation
      }
    }).getApi();
  }; // End init()

  define([
    'jquery',
    'jquery-ui',
    'external/jquery.sticky-kit',
    'js_alm_common',
    'slingshot/assembler2',
    'progressbar.min',
    'slingshot/utils',
    'slingshot/cancel',
    'slingshot/manual-upload',
    'slingshot/load-deployment',
    'common/request-manager',
    'common/profiles',
    'oauth',
    'api_builder',
    'try!analytics',
    'combobox',
  ], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[3];
    var Assembler = arguments[4];
    var ProgressBar = arguments[5];
    var RequestManager = arguments[10];
    var OAuth = arguments[12];
    // Create "shim" for old BW namespace
    var BW = window.BW || {};
    BW.AlmCommon = AlmCommon;
    BW.assembler = Assembler;
    BW.requestManager = RequestManager;
    BW.OAuth = OAuth;
    BW.utils = arguments[6]
    BW.cancel = arguments[7];
    BW.manualUpload = arguments[8];
    BW.loadDeployments = arguments[9];
    BW.profiles = arguments[11];

    var ApiBuilder = arguments[13];
    var Analytics = arguments[14];
    var ComboBox = arguments[15];

    var API = init(jQuery, BW, AlmCommon, ProgressBar, RequestManager, OAuth, ApiBuilder, Analytics, ComboBox);
    window.BW = BW;
    window.BW.slingshot = API;

    return API;
  });
})();