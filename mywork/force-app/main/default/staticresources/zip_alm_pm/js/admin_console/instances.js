(function() {
  var init = function ($, AlmCommon, ComboBox, ApiBuilder, OnDemandTool, moment, OAuth, RequestManager, Analytics) {
    "use strict";

    var INSTANCE_NAME_MIN_LENGTH = 1;
    var INSTANCE_NAME_MAX_LENGTH = 40;
    var INSTANCE_ADD_TYPE_SELECT_MENU_WIDTH = 200;
    var INSTANCE_LENGTH_ERROR_MESSAGE = "Instance name must be at least " + INSTANCE_NAME_MIN_LENGTH + " and at most " + INSTANCE_NAME_MAX_LENGTH + " characters.";
    var INSTANCE_SPECIAL_CHARS_ERROR_MESSAGE = "Instance names must be alphanumerics only.";

    var instanceAddPage = {
      container : '#instance-add',
      buttonContainer : '#instance-add-btn-container',
      button : '#instance-add-btn',
      isInstanceDeleted : 'input[id$=is-deleted-instance-value]',
      nameContainer : '#instance-add-name-container',
      nameInput : 'input[id$=instance-add-name-input]',
      nameButton : '#instance-add-name-btn',
      typeContainer : '#instance-add-type-container',
      typeSelect : '#instance-add-type-select',
      typeSelectMenu : '#instance-add-type-select-button',
      typeFilter : 'input[id$=instance-add-types-filter]',
      typeButton : '#instance-add-type-btn',
      visible : 'visible',
      errorPanel : '#instance-add-error-panel',
      errorPanelMessages : '#instance-add-error-panel > .error-text > .errorM3',
    }

    var instancePage = {
      almContainer : '#alm-container',
      mainContent : '#main-content',
      instanceForm : 'form[id$="instanceForm"]',
      instancePanel : 'span[id$="instance-panel"]',
      instanceOverviewPanel : 'span[id$="instance-overview-panel"]',
      instanceNameColumn : '#instance-name-col',
      scanDetailsContainer : 'div[id$="scanDetailsContainer"]',
      butrDetailsContainer : 'div[id$="butr-details-container"]',
      scanResultsOverviewContainer : '#scan-results-overview-container',
      scanResultsOverview : 'span[id$="scan-results-overview"]',
      scanResultsOverviewBlockContainer : '#scan-results-overview-block-container',
      scanResultsOverviewBlock: '.scan-results-overview-block',
      detailsPanel : 'div[id$="instance-details-panel"]',
      detailsHeaderPanel : '#instance-detail-header-panel',
      instanceDeleteButton : '#instance-delete-btn',
      errorContainer : '#instance-error',
      errorPanel : '#instance-error-panel',
      errorPanelMessages : '#instance-error-panel > .error-text > .errorM3',
      homeLink : '#instances-home-link',
      pageMessages : 'span[id$="instance-msgs"] .message',
      nameContainer : '#instance-name',
      nameContainerText : '#instance-name-text',
      renameWrapper : '#instance-rename',
      oauthContainer : '#oauth-container',
      isToolActivated : '.is-tool-activated',
      isToolDeactivationPending : '.onoffswitch-container + input',
      hiddenIsRenamePending : 'input[id$="is-instance-rename-pending"]',
      hiddenIsRenameLocked : 'input[id$="is-instance-rename-locked"]',
      renameContainer : "#instance-rename-container",
      renameInput : 'input[id$="instance-rename-input"]',
      renameApplyBtn : '#instance-rename-apply-btn',
      typeFilter : 'input[id$="instance-details-types-filter"]',
      customDomain : 'input[id$="custom-domain-input"]',
      emailInput : '.email-input',
      onDemandScanBtn : '[id$="scanDetailsContainer"] .on-demand-container .on-demand-btn',
      onDemandButrBtn : '[id$="butr-details-container"] .on-demand-container .on-demand-btn',
      accordionHandle : '.simple-accordion-handle',
      interval : '.interval',
      detailsOpen : 'details-open'
    }

    var scanConfigProperties = {
      label : 'SCAN',
      className : AlmCommon.JOB_TYPE.SCAN,
      container : instancePage.scanDetailsContainer,
      previousToolState: getHasActiveJob(instancePage.scanDetailsContainer),
      hasUnsavedChanges : false,
    };
    var butrConfigProperties = {
      label : 'Automated Testing',
      className : AlmCommon.JOB_TYPE.BUTR,
      container : instancePage.butrDetailsContainer,
      previousToolState: getHasActiveJob(instancePage.butrDetailsContainer),
      hasUnsavedChanges : false,
    };
    var toolConfigPropertiesGetters = {};
    toolConfigPropertiesGetters[AlmCommon.JOB_TYPE.SCAN] = function() { return scanConfigProperties; }
    toolConfigPropertiesGetters[AlmCommon.JOB_TYPE.BUTR] = function() { return butrConfigProperties; }

    var isOAuthPolling = false;

    //on document ready
    $(function() {
      $.blockUI.defaults.css = {};
      addEventHandlers();
      loadState();
      doWindowResize();
      RequestManager.invokeFunction(afExpirePageState);
    });

    function addEventHandlers() {
      $(window).on("resize", doWindowResize);
      AlmCommon.addBeforeUnloadEventListener();

      $(instancePage.almContainer).on("click", ".ui-autocomplete", setUnsavedChanges);
      $(instancePage.almContainer).on('keypress', '.custom-domain-input', function() { setUnsavedChanges([AlmCommon.JOB_TYPE.SCAN, AlmCommon.JOB_TYPE.BUTR]); });
      $(instancePage.almContainer).on('input', instancePage.scanDetailsContainer + ' ' + instancePage.emailInput, function() { setUnsavedChanges([AlmCommon.JOB_TYPE.SCAN]); });
      $(instancePage.almContainer).on('input', instancePage.butrDetailsContainer + ' ' + instancePage.emailInput, function() { setUnsavedChanges([AlmCommon.JOB_TYPE.BUTR]); });

      $(instancePage.almContainer).on("click", ".save-btn", updateInstance);

      // Transition from the new instance button to the new instance name entry field on click.
      $(instancePage.almContainer).on('click', instanceAddPage.button, clickInstanceAddBtn);

      // Perform a check on the validity of the chosen new instance name and store it if it's valid.
      $(instancePage.almContainer).on('click', instanceAddPage.nameButton, clickInstanceAddNameBtn);
      $(instancePage.almContainer).on('keypress', instanceAddPage.nameInput, keypressInstanceAddNameInput);

      // Perform a check on the validity of the chosen new instance type and store it if it's valid.
      $(instancePage.almContainer).on('click', instanceAddPage.typeButton, clickInstanceAddTypeBtn);

      $(instancePage.almContainer).on('click', instancePage.instanceDeleteButton, clickInstanceDeleteBtn);

      $(instancePage.almContainer).on('click', '.alm-modal .cancel-btn', unblockAlmContainer);

      $(instancePage.almContainer).on('click', instancePage.renameApplyBtn, applyRenameInstance);
      $(instancePage.almContainer).on('keypress', instancePage.renameInput, keypressRenameInstance);

      $(instancePage.almContainer).on('click', instancePage.nameContainer, setInstanceRenameMode);

      $(instancePage.almContainer).on('click', '.alm-modal-unarchive-modal .continue-btn', unDeleteInstance);

      $(instancePage.almContainer).on('click', '.alm-modal-unarchive-modal .cancel-btn', cancelUndelete);

      $(instancePage.almContainer).on("click", ".page-messages .message .cancel-btn", function() {
        AlmCommon.closePageMessage($(this).parents().closest('.message'), "[id$='custom-messages']", ".message");
        doWindowResize();
      });

      $(instancePage.almContainer).on("click", ".instance-name-text", function(event) {
        handleClickNavigation(event, $(this).attr('href'));
      });

      $(instancePage.almContainer).on("click", ".home-link", function(event) {
        handleClickNavigation(event, $(this).attr('href'));
      });

      // Determine if area outside of the instance-adding container was clicked.
      $(document).click(clickInstanceInputOutside);

      OnDemandTool.addOnloadHandlers();

      OAuth.init({
        pageStateConfig : {
          saveAction : afSavePageState,
          expireAction : afExpirePageState
        },
        afterPromptChangeAuthorizedCredentials : function() {
          setButtonStates();
        },
        afterCancelChangeAuthorizedCredentials : function() {
          setButtonStates();
        },
        beforeAuthorizeInstance : function() {
          isOAuthPolling = true;
          setButtonStates();
        },
        handleFinishPolling: function() {
          getAuthStatus(getId());
          afUpdateAuthMessages();
        }
      });

      wireToolConfig(scanConfigProperties);
      wireToolConfig(butrConfigProperties);
    }
    function handleClickNavigation(event, targetUrl){
      event.preventDefault();
      var targetUrlString = String(targetUrl);
      AlmCommon.navigateTo(targetUrlString);
    }

    function doWindowResize() {
      var MAIN_CONTENT_PAGE_OFFSET = 132;

      AlmCommon.windowResize(instancePage.mainContent, '', MAIN_CONTENT_PAGE_OFFSET, 0);

      if (!$(instancePage.instancePanel).hasClass(instancePage.detailsOpen)) {
        var MINIMUM_SUPPORTED_VIEWPORT_HEIGHT = 800;
        var SCAN_RESULTS_OVERVIEW_CONTAINER_OFFSET = 58;
        var INSTANCE_NAME_COLUMN_OFFSET = 50;
        var PAGE_MESSAGE_PADDING_OFFSET = 5;

        // Adjust the SCAN results block.
        var pageMessageContainerOffset =
          $(instancePage.errorContainer).height() +
          ($(instancePage.pageMessages).length > 0 ? PAGE_MESSAGE_PADDING_OFFSET : 0);
        var minHeight =
          $(window).height() - AlmCommon.SFDC_CONTAINER_HEIGHT - MAIN_CONTENT_PAGE_OFFSET -
          SCAN_RESULTS_OVERVIEW_CONTAINER_OFFSET - pageMessageContainerOffset;
        $(instancePage.scanResultsOverviewContainer).css({ 'min-height' : minHeight });
        $(instancePage.scanResultsOverviewContainer).height(
          $(instancePage.instanceNameColumn).height() - INSTANCE_NAME_COLUMN_OFFSET
        );

        // Adjust the spinner.
        var halfOfFullHeight =
          ($(instancePage.scanResultsOverviewContainer).height() / 2) -
          ($(instancePage.scanResultsOverviewBlock).height() / 2);
        var halfOfVisibleHeight =
          ((MINIMUM_SUPPORTED_VIEWPORT_HEIGHT - AlmCommon.getProperty($(instancePage.scanResultsOverviewContainer).offset(), "top")) / 2) -
          ($(instancePage.scanResultsOverviewBlock).height() / 2);
        $(instancePage.scanResultsOverviewBlock).css({
          'top' : Math.min(halfOfFullHeight, halfOfVisibleHeight)
        });
      }
    }

    function cancelUndelete() {
      $(instanceAddPage.isInstanceDeleted).val('false');
      AlmCommon.unblockUI(instancePage.almContainer);
      clickInstanceAddBtn();
    }

    function setInstanceRenameMode() {
      $(instancePage.renameInput).val($(instancePage.nameContainerText).text().trim());
      transitionElement(instancePage.nameContainer, instancePage.renameContainer);
    }

    function keypressRenameInstance(event) {
      AlmCommon.performActionOnEnter($(this), event, applyRenameInstance);
    }

    function applyRenameInstance() {
        var currentInstanceName = $(instancePage.nameContainerText).text().trim(),
          newInstanceName = $(instancePage.renameInput).val().trim();
        function nameValidationSuccessful() {
          $(instancePage.hiddenIsRenamePending).val(true);
          setUnsavedChanges();
          $(instancePage.nameContainerText).text(newInstanceName);
          unSetInstanceRenameMode();
        }
        function nameValidationFailure(instanceNameLengthFail, specialCharsFail) {
          AlmCommon.clearMsgs();
          if(instanceNameLengthFail === true) {
            AlmCommon.addErrorMessage(INSTANCE_LENGTH_ERROR_MESSAGE, {showCloseButton:true});
          }
          if(specialCharsFail === true) {
            AlmCommon.addErrorMessage(INSTANCE_SPECIAL_CHARS_ERROR_MESSAGE, {showCloseButton:true});
          }
        }
        if (currentInstanceName !== newInstanceName) {
          instanceCheckName(instancePage.renameInput, nameValidationSuccessful, nameValidationFailure);
        } else {
          unSetInstanceRenameMode();
        }
    }

    function setUnsavedChanges(jobTypes) {
      if (!AlmCommon.isNullOrUndefined(jobTypes)) {
        for (var i = 0; i < jobTypes.length; ++i) {
          var toolConfigPropertiesGetter = toolConfigPropertiesGetters[jobTypes[i]];
          if (!AlmCommon.isNullOrUndefined(toolConfigPropertiesGetter)) {
            toolConfigPropertiesGetter().hasUnsavedChanges = true;
          }
        }
      }

      AlmCommon.setHasUnsavedChanges(true);
      $(instancePage.oauthContainer).addClass('disabled');
      setButtonStates();
    }

    function resetUnsavedChanges() {
      AlmCommon.setHasUnsavedChanges(false);
      $(instancePage.oauthContainer).removeClass('disabled');
      setButtonStates();
    }

    function unblockAlmContainer() {
      AlmCommon.unblockUI(instancePage.almContainer);
    }

    function unDeleteInstance() {
      afUnDeleteInstance();
    }

    function setHasActiveJob(container, hasActiveJob) {
      $(container + ' ' + instancePage.isToolActivated).prop('checked', hasActiveJob).trigger('change');
    }

    function getHasActiveJob(container) {
      return $(container + ' ' + instancePage.isToolActivated).prop('checked');
    }

    function getId() {
      return $(instancePage.detailsPanel).data('id');
    }

    function getCurrentInstanceName() {
      return $(instancePage.nameContainerText).text();
    }

    function getCurrentInstanceRename() {
      return $(instancePage.renameInput).val();
    }

    function setCurrentInstanceRename(name) {
      return $(instancePage.renameInput).val(name);
    }

    function getCurrentInstanceType() {
      return $('[id$=instance-details-types-filter]').val();
    }

    function setCurrentInstanceType(type) {
      $('#active-instance-select').val(type);
      selectMenuChange.call($('#active-instance-select'));
    }

    function getCurrentInstanceCustomDomain() {
      return $(instancePage.customDomain).val();
    }

    function setCurrentInstanceCustomDomain(domain) {
      $(instancePage.customDomain).val(domain);
    }

    function getUserTimezone() {
      return $('#user-timezone').val();
    }

    function restoreCurrentInstanceRename(name) {
      setInstanceRenameMode();
      setCurrentInstanceRename(name);
    }

    function loadState() {
      var instanceId = AlmCommon.getUrlParameter('id');
      var pollOAuthId = AlmCommon.getUrlParameter('pollOAuthId');

      if (instanceId) {
        window.history.pushState('', '', 'AdminInstanceManagement?id=' + instanceId);
        finishInstanceLoad();
      } else {
        blockScanResults();
        RequestManager.invokeFunction(afGetAllScanResults);
      }

      if (pollOAuthId) {
        OAuth.initPollOAuthUpdate(pollOAuthId, null, null);
      }
    }

    function updateInstance() {
      clearErrorMsg();

      var custDomain = getCurrentInstanceCustomDomain();

      if(custDomain && custDomain.length > 199) {
        displayErrorMsg("Custom domain URLs must less be less than 200 characters.");
        return;
      }

      var instanceType = getCurrentInstanceType();

      if ($.inArray(instanceType, getValidInstanceTypes()) == -1) {
        displayErrorMsg("Please select a valid instance type.");
        return;
      }

      if ($(instancePage.hiddenIsRenamePending).val() === 'true') {
        confirmInstanceRename();
        return;
      }
      var selectedInstanceId = getId();

      if(getHasActiveJob(butrConfigProperties.container) === true) {
          remoteCheckRemoteSiteSettingExists(selectedInstanceId, checkInstanceAccess);
      } else {
        performSave();
      }
    }

    function performSave() {
      AlmCommon.blockUI(instancePage.mainContent);
      save();
    }

    function save() {
      var isButrActivated =
              ( $("#instance-details-panel-body").find('input[id$="is-butr-activated"]').val() === 'true' ),
          currentAutomatedTestingSwitch =
              $('[id$="butr-details-container"] ' + instancePage.isToolActivated).prop('checked');

      if ( !isButrActivated && currentAutomatedTestingSwitch ) {
        Analytics.trackEvent('Automated Testing', 'Turn On Automated Testing');
      } else if ( isButrActivated && !currentAutomatedTestingSwitch ) {
        Analytics.trackEvent('Automated Testing', 'Turn Off Automated Testing');
      }
      OAuth.setPageStateTriggers(false);

      afUpdateInstance();
    }

    function deleteInstance() {
      unblockAlmContainer();
      afDeleteInstance();
    }

    function blockScanResults() {
      $(instancePage.scanResultsOverviewContainer).show().block({
        message: $(instancePage.scanResultsOverviewBlockContainer),
        blockMsgClass: 'scan-results-overview-block',
        centerX: false,
        centerY: false
      });
    }

    function getValidInstanceTypes() {
      return $("#active-instance-select option").map(function() {
        return $(this).val();
      });
    }

    function restoreErrorPanels() {
      $(instancePage.instanceForm).prepend($(instancePage.errorContainer));
    }

    function finishInstanceLoad() {
      loadInstanceUI();

      var selectedInstanceId = getId();

      if (getHasActiveJob(instancePage.scanDetailsContainer)) {
        OnDemandTool.startPolling(selectedInstanceId, scanConfigProperties.className);
      }

      if (getHasActiveJob(instancePage.butrDetailsContainer)) {
        OnDemandTool.startPolling(selectedInstanceId, butrConfigProperties.className);
      }
    }

    function checkInstanceAccess(status, evt) {
      if(!evt.status) {
        displayErrorMsg(evt.message);
        return;
      }
      if (!AlmCommon.isNullOrUndefined(status)) {
        warnNoRemoteSiteSetting(butrConfigProperties, status);
      } else {
        performSave();
      }
    }

    function finishInstanceSave() {
      if (!AlmCommon.hasSaveErrors() && $('[id$="was-instance-save-triggered"]').val() === "true") {
        AlmCommon.setHasUnsavedChanges(false);

        for (var key in toolConfigPropertiesGetters) {
          toolConfigPropertiesGetters[key]().hasUnsavedChanges = false;
        }

        $('[id$="was-instance-save-triggered"]').val("false");
      }

      finishInstanceLoad();
      scanConfigProperties.previousToolState = getHasActiveJob(scanConfigProperties.container);
      butrConfigProperties.previousToolState = getHasActiveJob(butrConfigProperties.container);

      $(instancePage.oauthContainer).removeClass('disabled');
    }

    function finishGetAllScanResults() {
      $(instancePage.scanResultsOverviewContainer).unblock();

      RequestManager.completeFunction();
    }

    function finishAddNewInstance() {
      var isInstanceDeleted = $(instanceAddPage.isInstanceDeleted).val();
      if(isInstanceDeleted === 'true') {
        confirmUnArchiveInstance();
      } else {
        instanceAddReset();
      }
      $(instancePage.scanResultsOverviewContainer).unblock();
    }

    function finishInstanceUndelete() {
      AlmCommon.unblockUI(instancePage.almContainer);
      loadState();
      instanceAddReset();
    }

    function finishInstanceDelete() {
      var vfPageName = $("#namespace").val() + 'AdminInstanceManagement';
      AlmCommon.navigateTo('/apex/'+ vfPageName);
    }

    function finishExpirePageState() {
      RequestManager.completeFunction();
    }

    function getAuthStatus(selectedInstanceId) {
      OAuth.getAuthStatus({
        selectedInstanceId : selectedInstanceId,
        oauthContainer : instancePage.oauthContainer,
        successCallback : function(authInfo) {
          var preferredUser = (authInfo === null) ? "" : authInfo.preferred_username;

          $(instancePage.oauthContainer)
           .attr('title', preferredUser)
           .find('.authorized-user').text(preferredUser);
        },
        errorCallback : displayErrorMsg,
        onComplete : function() {
          isOAuthPolling = false;
          setButtonStates();

          AlmCommon.unblockUI(instancePage.mainContent);
        }
      });
    }

    function loadInstanceUI() {
      var selectedInstanceId = getId();
      if (selectedInstanceId === undefined) {
        AlmCommon.unblockUI(instancePage.mainContent);

        return;
      }

      $(instancePage.detailsHeaderPanel).prepend($(instancePage.errorContainer));
      $(instancePage.errorPanel + ' .message').remove();

      getAuthStatus(selectedInstanceId);

      initializeActiveInstanceTypeSelect();

      OnDemandTool.setCurrentInstanceId(selectedInstanceId);

      generateScheduleTimeOptions($(instancePage.scanDetailsContainer + ' .start-time, ' + instancePage.scanDetailsContainer + ' .end-time'));
      generateScheduleTimeOptions($(instancePage.butrDetailsContainer + ' .start-time, ' + instancePage.butrDetailsContainer + ' .end-time'));

      enableToolSelectMenus(instancePage.scanDetailsContainer);
      enableToolSelectMenus(instancePage.butrDetailsContainer);

      $(instancePage.detailsHeaderPanel).stick_in_parent({
        parent: $(instancePage.detailsPanel),
        bottoming : false
      });

      if ($(instancePage.hiddenIsRenameLocked).val() === "true") {
        $(instancePage.almContainer).off('click', instancePage.nameContainer, setInstanceRenameMode);
        $(instancePage.detailsPanel).addClass('renaming');

        var newName = $(instancePage.detailsPanel).data('name');
        var options = {
          messagePanel: instancePage.errorPanel
        };
        AlmCommon.addInfoMessage("Currently in the process of updating all references to the new name \"" + newName + "\"", options);
        $(instancePage.errorPanel).find('.message').last().append('<span id="instance-rename-message-spinner" class="pull-right"></span>');
      } else {
        $(instancePage.almContainer).on('click', instancePage.nameContainer, setInstanceRenameMode);
        $(instancePage.detailsPanel).removeClass('renaming');
      }

      if ($('input[id$="is-page-restored"]').val() === 'true') {
        setUnsavedChanges();
      }
      if ($('input[id$="is-scan-restored"]').val() === 'true') {
        openAccordion(scanConfigProperties);
      }
      if ($('input[id$="is-butr-restored"]').val() === 'true') {
        openAccordion(butrConfigProperties);
      }

      setButtonStates();
    }

    function initializeActiveInstanceTypeSelect() {
      $('#active-instance-select')
        .val(getCurrentInstanceType())
        .almSelectMenu({
          change: onActiveInstanceTypeSelectChange,
          isRequired : true,
          placeholder: 'Instance Type',
          width: '100%'
        });
    }

    function onActiveInstanceTypeSelectChange() {
      selectMenuChange.call(this, [AlmCommon.JOB_TYPE.SCAN, AlmCommon.JOB_TYPE.BUTR]);
    }

    /**
     * Generates the options for the time select list with values from 12am - 11:30pm
     * @param   {String|Element|jQuery} $select - the <select> element(s) to populate the options
     *            on. The selected value will be set on the select if there is a sibling input field
     */
    function generateScheduleTimeOptions($select) {
      var dayPart = ['am', 'pm'],
       html = '',
       i, j,
       timezone = getUserTimezone();

      moment.tz.setDefault(timezone);

      for (i = 0; i < 2; i++) {
        html += '<option value="'+ moment({h:12 * i, m:0 }) +'">12:00 ' + dayPart[i] + '</option>';
        html += '<option value="'+ moment({h:12 * i, m:30 }) +'">12:30 ' + dayPart[i] + '</option>';

        for (j = 1; j < 12; j++) {
          html += '<option value="' + moment({h:12 * i + j, m:0 }) + '">' + j + ':00 ' + dayPart[i] + '</option>';
          html += '<option value="' + moment({h:12 * i + j, m:30 }) +'">' + j + ':30 ' + dayPart[i] + '</option>';
        }
      }

      $select.html(html);
      $select.each(function() {
        $(this).val($(this).siblings('input').val());
      });
    }

    function instanceAddInitializeSelect() {
      if($(instanceAddPage.typeContainer + ' .alm-selectmenu').length !== 0) {
        $(instanceAddPage.typeSelect).almSelectMenu('destroy');
      }

      $(instanceAddPage.typeSelect)
        .val("")
        .almSelectMenu({
          change: changeInstanceAddTypeSelect,
          isRequired : true,
          placeholder: 'Instance Type',
          appendTo: instanceAddPage.typeContainer,
          width: INSTANCE_ADD_TYPE_SELECT_MENU_WIDTH
        });
    }

    function clickInstanceAddBtn(event) {
      instanceAddClearErrorMsg();
      instanceAddShowName();
    }

    function clickInstanceAddNameBtn(event) {
      function nameValidationSuccessful() {
        instanceAddClearErrorMsg();
        instanceAddShowType();
      }
      function nameValidationFailure(instanceNameLengthFail, specialCharsFail) {
        if(instanceNameLengthFail === true) {
          instanceAddDisplayErrorMsg(INSTANCE_LENGTH_ERROR_MESSAGE);
        }
        if(specialCharsFail === true) {
          instanceAddDisplayErrorMsg(INSTANCE_SPECIAL_CHARS_ERROR_MESSAGE);
        }
      }
      instanceCheckName(instanceAddPage.nameInput, nameValidationSuccessful, nameValidationFailure);
    }

    function keypressInstanceAddNameInput(event) {
      AlmCommon.performActionOnEnter($(this), event, clickInstanceAddNameBtn);
    }

    function clickInstanceAddTypeBtn(event) {
      instanceAddCheckType();
    }

    function changeInstanceAddTypeSelect() {
      selectSiblingInput.call(this);
      $(this).siblings('span' + instanceAddPage.typeSelectMenu).addClass('selected');

      if($(instanceAddPage.typeSelect).val() !== "") {
        $(instanceAddPage.typeButton).addClass(instanceAddPage.visible);
      }
    }

    function clickInstanceInputOutside(event) {
      var isInstanceDeleted = $(instanceAddPage.isInstanceDeleted).val();
      if (AlmCommon.eventOccursOutsideElements(event, [instanceAddPage.container])
          && !$(event.target).hasClass('ui-menu-item')
          && !$(event.target).hasClass('ui-menu-item-wrapper')
          && !$(event.target).hasClass('cancel-btn')
          && isInstanceDeleted === 'false') {
            instanceAddReset();
      }
      if (AlmCommon.eventOccursOutsideElements(event, [instancePage.renameWrapper])
          && !$(event.target).hasClass('ui-menu-item')
          && !$(event.target).hasClass('ui-menu-item-wrapper')) {
            unSetInstanceRenameMode();
      }
    }

    function clickInstanceDeleteBtn() {
      $(instancePage.almContainer)
        .off('click', '#delete-modal .continue-btn')
        .on('click', '#delete-modal .continue-btn', deleteInstance);

      var message = "Are you sure you want to delete <b>" + $(instancePage.detailsPanel).data('name') + "</b>?<br />Any existing jobs scheduled will be deleted.";
      $('#delete-modal #modal-text').html(message);

      AlmCommon.displayModal({
        content: $('#delete-modal'),
        container: instancePage.almContainer,
        width: '305px'
      });
    }

    function confirmInstanceRename() {
      $('#rename-modal .continue-btn')
        .off('click')
        .on('click', function() {
          unblockAlmContainer();
          save();
        });

      $('#rename-modal .cancel-btn')
        .off('click')
        .on('click', function() {
         AlmCommon.unblockUI();
         instanceRenameReset();
      });

      AlmCommon.displayModal({
        content: $('#rename-modal'),
        container: "#alm-container",
        width: '30%'
      });
    }

    // Transition from the new instance state to the instance-naming state.
    function instanceAddShowName() {
      transitionElement(instanceAddPage.buttonContainer, instanceAddPage.nameContainer, function() {
        $(instanceAddPage.nameInput).focus();
      });
    }

    // Transition from the instance-naming state to the type-choosing state.
    function instanceAddShowType() {
      transitionElement(instanceAddPage.nameContainer, instanceAddPage.typeContainer, function() {
        instanceAddInitializeSelect();
        $(instanceAddPage.typeSelectMenu).focus();
      });
    }

    // Validation of a user-entered instance name, displaying an error message if it's invalid.
    function instanceCheckName(inputSelector, onSuccess, onFailure) {
      if (!inputSelector) return;
      var instanceName = $(inputSelector).val();
      var instanceNameLength = instanceName.length;
      var specialCharsFail = /[^A-Za-z0-9-_ ]/gi.test(instanceName);
      var instanceNameLengthFail = (instanceNameLength < INSTANCE_NAME_MIN_LENGTH || INSTANCE_NAME_MAX_LENGTH < instanceNameLength);

      // Name passed length validation.
      if((INSTANCE_NAME_MIN_LENGTH <= instanceNameLength)
          && (instanceNameLength <= INSTANCE_NAME_MAX_LENGTH)
          && (specialCharsFail === false)) {
        if (typeof onSuccess === 'function') {
          onSuccess();
        }
      }
      // Name failed length validation.
      else {
        if (typeof onFailure === 'function') {
          onFailure(instanceNameLengthFail, specialCharsFail);
        }
      }
    }

    // Validation of a user-entered instance type, displaying an error message if it's invalid.
    function instanceAddCheckType() {
      var instanceType = $(instanceAddPage.typeFilter).val();
      var validInstanceTypes = $(instanceAddPage.typeSelect + ' option').map(function() { return $(this).val(); });

      if($.inArray(instanceType, validInstanceTypes) === -1) {
        instanceAddDisplayErrorMsg("Instance type must be valid.");
      } else {
        instanceAddClearErrorMsg();
        instanceAddSubmitInstance();
      }
    }

    // Final submission attempt for new instance. Server-side validation should be performed on the input data.
    function instanceAddSubmitInstance() {
      blockScanResults();
      afAddNewInstance();
    }

    // Reset the instance-adding process to the beginning, clearing all user-entered data.
    function instanceAddReset() {
      $(instanceAddPage.nameContainer).hide('slide', { direction: "left" });
      $(instanceAddPage.typeContainer).hide('slide', { direction: "left" });
      $(instanceAddPage.buttonContainer).show('slide', {
        direction: "left",
        queue: false
      });

      $(instanceAddPage.nameInput).val("");
      $(instanceAddPage.typeSelect).val("");
      $(instanceAddPage.typeButton).removeClass(instanceAddPage.visible);
      instanceAddClearErrorMsg();
    }

    // Hide the instance rename input container and show the current instance name container.
    function unSetInstanceRenameMode() {
      $(instancePage.renameContainer).hide('slide', { direction: "left" });
      $(instancePage.nameContainer).show('slide', { direction: "left" });

      // TODO: Uncommenting the code below breaks renaming. Write a regression test for this?
      // if ($(instancePage.nameContainer).data('original-name')) {
      //   $(instancePage.renameInput).val($(instancePage.nameContainer).data('original-name').trim());
      // }
    }

    // Reset the instance-rename process to the beginning, clearing all user-entered data.
    function instanceRenameReset() {
      if ($(instancePage.nameContainer).data('original-name')) {
        $(instancePage.renameInput).val($(instancePage.nameContainer).data('original-name').trim());
        $(instancePage.nameContainerText).text($(instancePage.nameContainer).data('original-name').trim());
      }
      $(instancePage.hiddenIsRenamePending).val(false);
      resetUnsavedChanges();
    }

    // Slide-transition from one given element to another.
    function transitionElement(fromElement, toElement, completeFunction) {
      $(fromElement).hide('slide', { direction : "left" });
      $(toElement).show('slide', {
        direction : "left",
        queue : false,
        complete: function() {
          if(typeof completeFunction === 'function')
          {
            completeFunction();
          }
        }
      });
    }

    function wireToolConfig(toolConfigProperties) {
      $(instancePage.almContainer).on('click', toolConfigProperties.container + ' ' + instancePage.accordionHandle, function() {
        $(instancePage.instancePanel).hasClass(toolConfigProperties.className + '-open')
          ? closeAccordion(toolConfigProperties)
          : activateTool(toolConfigProperties);
      });

      $(instancePage.almContainer).on('click', toolConfigProperties.container + ' .onoffswitch-container', function(e) {
        e.preventDefault();

        toggleTool(toolConfigProperties);
      });

      $(instancePage.almContainer).on('click', function(e) {
        toggleStatusFlyout(e, toolConfigProperties.container);
      });

      $(instancePage.almContainer).on('click', toolConfigProperties.container + ' .status-section .flyout-menu li', function() {
        setToolStatus(toolConfigProperties.container, this);
      });

      $(instancePage.almContainer).on('click', toolConfigProperties.container + ' .clickable-tile', toolDaySelectClickHandler);

      $(instancePage.almContainer).on('click', '.' + toolConfigProperties.className + '-deactivation-modal .continue-btn', function() {
        deactivateTool(toolConfigProperties);
        unblockAlmContainer();
      });

      $(instancePage.almContainer).on('click', '.' + toolConfigProperties.className + '-activation-modal .continue-btn', function() {
        unblockAlmContainer();
        performSave();
      });

      AlmCommon.enableShiftSelect({
        container : instancePage.almContainer,
        selector : toolConfigProperties.container + ' .clickable-tile',
        callback : toolDaySelect
      });

      $('.time-control-container').focusout(function() {
        // Why does this close all almSelectMenu objects on the page, rather than just the scan interval menu?
        $(toolConfigProperties.container + ' ' + instancePage.interval).almSelectMenu('close');
      });
    }

    function openAccordion(toolConfigProperties) {
      if ($(instancePage.instancePanel).hasClass(toolConfigProperties.className + '-open')) {
        return;
      }

      AlmCommon.blockUI(toolConfigProperties.container);

      $(toolConfigProperties.container)
      .find('.simple-accordion-body')
      .show('slide', {
        direction: 'up',
        queue: false,
        complete: function() {
          AlmCommon.unblockUI(toolConfigProperties.container);
          $(instancePage.instancePanel).addClass(toolConfigProperties.className + '-open');
        }
      });
    }

    function closeAccordion(toolConfigProperties) {
      if (!$(instancePage.instancePanel).hasClass(toolConfigProperties.className + '-open')) {
        return;
      }

      AlmCommon.blockUI(toolConfigProperties.container);

      $(toolConfigProperties.container)
      .find('.simple-accordion-body')
      .hide('slide', {
        direction: 'up',
        queue: false,
        complete: function() {
          AlmCommon.unblockUI(toolConfigProperties.container);
          $(instancePage.instancePanel).removeClass(toolConfigProperties.className + '-open');
        }
      });
    }

    function toggleTool(toolConfigProperties) {
      getHasActiveJob(toolConfigProperties.container)
        ? confirmDeactivateTool(toolConfigProperties)
        : activateTool(toolConfigProperties);
    }

    function activateTool(toolConfigProperties) {
      openAccordion(toolConfigProperties);

      if (getHasActiveJob(toolConfigProperties.container)) {
        return;
      }

      $(toolConfigProperties.container + ' ' + instancePage.isToolDeactivationPending).val(false);
      setHasActiveJob(toolConfigProperties.container, true);

      enableToolSelectMenus(toolConfigProperties.container);

      doWindowResize();
      setUnsavedChanges();
    }

    function confirmDeactivateTool(toolConfigProperties) {
      if (!getHasActiveJob(toolConfigProperties.container) || $(toolConfigProperties.container + ' ' + instancePage.isToolDeactivationPending).val() === 'true') {
        return;
      }

      var message = "Are you sure you want to turn off " + toolConfigProperties.label + "? Any existing jobs scheduled will be deleted.";
      var warningCard = templates['sprint_warning'].render({
        'message' : message,
        'mainClass' : 'alm-modal ' + toolConfigProperties.className + '-deactivation-modal'
      });
      AlmCommon.displayModal({
        content: warningCard,
        container: instancePage.almContainer,
        width: '30%'
      });

      $('.alm-warning').parent().css({left: '0', top: '0'});
      $('.sp-card-wrap-error').show();
    }

    function confirmUnArchiveInstance() {
      var message = 'The instance name provided has been previously used.'
                    +' Click "Yes" to unarchive the existing instance record.'
                    +' Click "No" to go back and provide a different instance name.';
      var warningCard = templates['sprint_warning'].render({
        'message' : message,
        'mainClass' : 'alm-modal-unarchive-modal'
      });
      AlmCommon.displayModal({
        content: warningCard,
        container: instancePage.almContainer,
        width: '30%',
      });

      $('.alm-warning').parent().css({left: '0', top: '0'});
      $('.sp-card-wrap-error').css({height:'200px'});
      $('.sp-card-wrap-error').show();
    }

    function warnNoRemoteSiteSetting(toolConfigProperties, messageFromCallout) {
      var instanceUrl = messageFromCallout === "Not Authorized" ? "" :"["+ messageFromCallout +"],";

      var messagePart1 = "In order for "
        + toolConfigProperties.label
        + " jobs to run, the domain of the instance ";

      var messagePart2 = " must be added to the Remote Site Settings of the ";
      var underlineEnding = "Salesforce org where Sightline is installed.";

      var warningCard = templates['remote_site_setting_warning'].render({
        'messagePart1' : messagePart1,
        'url' : instanceUrl,
        'messagePart2' : messagePart2,
        'underlineEnding' : underlineEnding,
        'mainClass' : 'alm-modal ' + toolConfigProperties.className + '-activation-modal'
      });
      AlmCommon.displayModal({
        content: warningCard,
        container: instancePage.almContainer,
        width: '450px'
      });

      $('.alm-warning').parent().css({left: '0', top: '0'});
      $('.sp-card-wrap-error').css({height: '230px', width: 'auto'}).show();
    }

    function deactivateTool(toolConfigProperties) {
      if (!getHasActiveJob(toolConfigProperties.container)) {
        return;
      }

      closeAccordion(toolConfigProperties);

      $(toolConfigProperties.container + ' ' + instancePage.isToolDeactivationPending).val(true);
      setHasActiveJob(toolConfigProperties.container, false);

      doWindowResize();
      setUnsavedChanges();
    }

    function enableToolSelectMenus(toolContainer) {
      $(toolContainer + ' ' +  instancePage.interval).val($(toolContainer + ' ' +  instancePage.interval).siblings('input').val());
      $(toolContainer + ' ' +  instancePage.interval).almSelectMenu({
        change: selectMenuChange,
        width: '100%'
      });

      $(toolContainer + ' .start-time, ' + toolContainer + ' .end-time').almSelectMenu({
        change: selectMenuChange,
        width: '100%'
      });
    }

    function selectMenuChange(jobTypes) {
      selectSiblingInput.call(this);
      setUnsavedChanges(jobTypes);
    }

    function selectSiblingInput(event, ui) {
      var value = $(this).val();
      $(this).siblings('input').val(value).trigger('input');
      if (typeof $(this).almSelectMenu() !== "undefined") {
        $(this).almSelectMenu('refresh');
      }
    }

    function setToolStatus(toolContainer, targetElement) {
      var newValue = $(targetElement).find('span').text();
      $(toolContainer + ' .status-output').text(newValue);
      $(toolContainer + ' .status-section input').val(newValue);

      AlmCommon.setHasUnsavedChanges(true);
      setButtonStates();
    }

    function toolDaySelectClickHandler(event) {
      setUnsavedChanges();

      var $tile = $(this),
       isChecked = !$tile.hasClass('selected');

      // Let shift click handler deal with this.
      if (event.shiftKey) {
        return;
      }

      toolDaySelect($tile, isChecked);
    }

    /**
     * Event handler for selecting days of the week in the scan schedule
     */
    function toolDaySelect($items, isChecked) {

      AlmCommon.setHasUnsavedChanges(true);
      if (isChecked) {
        $items.addClass('selected');
      } else {
        $items.removeClass('selected');
      }
      $items.find('input').val(isChecked);
    }

    function toggleStatusFlyout(event, toolContainer) {
      var $statusSection = $(toolContainer + ' .status-section');

      if ($statusSection.hasClass('disabled')) {
        return;
      }

      var $menu = $statusSection.find('.flyout-menu');
      if ($(event.target).is(toolContainer + ' .menu-opener')) {
        var selectedVal = $statusSection.find('input').val();

        $menu.find('li')
          .removeClass('selected')
          .filter(":contains('"+ selectedVal +"')")
          .addClass('selected');
        $menu.show();
      } else {
        $menu.hide();
      }
    }

    // Display an error message to an error panel.
    function displayErrorMsg(msg, opts) {
      clearErrorMsg();

      var options = opts !== undefined ? opts : {
        messagePanel: instancePage.errorPanel,
        standardTemplate: true
      };

      AlmCommon.showError(msg, options);

      if ($(instancePage.detailsPanel) !== undefined) {
        styleErrorMessages();
      }
    }

    function instanceAddDisplayErrorMsg(msg) {
      instanceAddClearErrorMsg();
      var errorMsg = $(templates["error"].render({
        "message" : msg
      }));

      $(instanceAddPage.errorPanel + ' .error-text').append(errorMsg);
      $(instanceAddPage.errorPanel).show();
      $(instancePage.almContainer)[0].scrollIntoView();

      if ($(instancePage.detailsPanel) !== undefined) {
        styleErrorMessages();
      }
    }

    function instanceAddClearErrorMsg() {
      $(instanceAddPage.errorPanel + ' .error-text').empty();
    }

    function styleErrorMessages() {
      $(instancePage.errorContainer + ' .message').removeClass('first-message');
      $(instancePage.errorContainer + ' .message:not(:empty)').first().addClass('first-message');
    }

    // Set state of Save and Run Now buttons based on hasUnsavedChanges
    function setButtonStates() {
      var $scanButton = $(instancePage.onDemandScanBtn);
      var $butrButton = $(instancePage.onDemandButrBtn);
      var $saveButton = $('.save-btn');
      var tooltip = "Save changes to enable";

      $scanButton.removeClass('inactive').prop('disabled', false).removeAttr('title');
      $butrButton.removeClass('inactive').prop('disabled', false).removeAttr('title');
      $saveButton.addClass('inactive').prop('disabled', true);

      if (isOAuthPolling ||
          $(instancePage.hiddenIsRenameLocked).val() === "true" ||
          $(instancePage.oauthContainer).hasClass('prompting')) {
        $scanButton.addClass('inactive').prop('disabled', true);
      }

      if (isOAuthPolling ||
          $(instancePage.oauthContainer).hasClass('prompting')) {
        $butrButton.addClass('inactive').prop('disabled', true);
      }

      if (AlmCommon.getHasUnsavedChanges()) {
        $saveButton.removeClass('inactive').prop('disabled', false);

        if (getHasActiveJob(scanConfigProperties.container) != scanConfigProperties.previousToolState ||
            scanConfigProperties.hasUnsavedChanges) {
          $scanButton.addClass('inactive').prop('disabled', true).attr('title', tooltip);
        }

        if (getHasActiveJob(butrConfigProperties.container) != butrConfigProperties.previousToolState ||
            butrConfigProperties.hasUnsavedChanges) {
          $butrButton.addClass('inactive').prop('disabled', true).attr('title', tooltip);
        }
      }
    }

    // Clears and hides the error message panel.
    function clearErrorMsg() {
      AlmCommon.clearMsgs();
    }

    return new ApiBuilder({
      pure: {
        finishGetAllScanResults : finishGetAllScanResults,
        finishInstanceSave : finishInstanceSave,
        finishAddNewInstance : finishAddNewInstance,
        finishInstanceDelete : finishInstanceDelete,
        finishInstanceUndelete : finishInstanceUndelete,
        finishExpirePageState : finishExpirePageState,
        restoreErrorPanels : restoreErrorPanels,
        scanConfigProperties : scanConfigProperties,
        butrConfigProperties : butrConfigProperties,
        loadInstanceUI : loadInstanceUI
      },
      testOnly: {
        finishInstanceLoad : finishInstanceLoad,
        setUnsavedChanges : setUnsavedChanges,
        getCurrentInstanceType : getCurrentInstanceType,
        getValidInstanceTypes : getValidInstanceTypes,
        clickInstanceAddBtn : clickInstanceAddBtn,
        clickInstanceAddNameBtn : clickInstanceAddNameBtn,
        clickInstanceAddTypeBtn : clickInstanceAddTypeBtn,
        clickInstanceDeleteBtn: clickInstanceDeleteBtn,
        changeInstanceAddTypeSelect : changeInstanceAddTypeSelect,
        cancelUndelete : cancelUndelete,
        instanceAddClearErrorMsg : instanceAddClearErrorMsg,
        instancePage : instancePage,
        instanceAddPage : instanceAddPage,
        updateInstance : updateInstance,
        toolDaySelectClickHandler: toolDaySelectClickHandler,
        setHasActiveJob: setHasActiveJob,
        setToolStatus: setToolStatus,
        toggleStatusFlyout: toggleStatusFlyout,
        setButtonStates : setButtonStates,
        clearErrorMsg : clearErrorMsg,
        confirmUnArchiveInstance : confirmUnArchiveInstance,
        activateTool : activateTool,
        deactivateTool : deactivateTool,
        unblockAlmContainer : unblockAlmContainer,
        unDeleteInstance : unDeleteInstance,
        addEventHandlers : addEventHandlers,
        onActiveInstanceTypeSelectChange : onActiveInstanceTypeSelectChange,
        toolConfigPropertiesGetters : toolConfigPropertiesGetters
      }
    }).getApi();
  };

  define(
    [
     'jquery',
     'js_alm_common',
     'combobox',
     'api_builder',
     'admin_console/on_demand_tool',
     'alm_selectmenu',
     "moment",
     'external/moment/moment-timezone',
     "oauth",
     'external/jquery.sticky-kit',
     'common/request-manager',
     'try!analytics'
    ], function() {

    var $ = arguments[0];
    var AlmCommon = arguments[1];
    var ComboBox = arguments[2];
    var ApiBuilder = arguments[3];
    var OnDemandTool = arguments[4];
    var moment = arguments[6];
    var oauth = arguments[8];
    var RequestManager = arguments[10];
    var Analytics = arguments[11];

    var API = init($, AlmCommon, ComboBox, ApiBuilder, OnDemandTool, moment, oauth, RequestManager, Analytics);

    window.BW = window.BW || {};
    window.BW.adminInstances = API;

    return API
  });

})();