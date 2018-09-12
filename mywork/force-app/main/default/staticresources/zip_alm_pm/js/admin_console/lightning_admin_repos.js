(function(global) {
  var init = function ($, AlmCommon, ComboBox, ApiBuilder, moment) {
    "use strict";

    var repoPage = {
      almContainer : '#version-control-container',
      mainContent : '#main-content',
      repoPanel : 'span[id$="schedule-panel"]',
      syncDetailsContainer : 'div[id$="sync-details-container"]',
      emailInput : '.email-input',
      interval : '.interval',
      isToolActivated : '.is-tool-activated',
      isToolDeactivationPending : '.onoffswitch-container + input',
      accordionHandle : '.simple-accordion-handle'
    }

    var vcSyncConfigProperties = {
      label : 'Sync Scheduler',
      className : AlmCommon.JOB_TYPE.SYNC,
      container : repoPage.syncDetailsContainer,
      previousToolState: getHasActiveJob(repoPage.syncDetailsContainer)
    };
    
    var toolConfigPropertiesGetters = {};
    toolConfigPropertiesGetters[AlmCommon.JOB_TYPE.SYNC] = function() { return vcSyncConfigProperties; }


    //on document ready
    $(function() {
        $.blockUI.defaults.css = {};
        addEventHandlers();
        loadState();
    });

    function addEventHandlers() {
      AlmCommon.addBeforeUnloadEventListener();
      $(repoPage.almContainer).on("keyup", repoPage.emailInput, setUnsavedChanges);
      $(repoPage.almContainer).on('click', '.alm-modal .cancel-btn', unblockAlmContainer);
      wireToolConfig(vcSyncConfigProperties);
    }

    function setUnsavedChanges() {
      AlmCommon.setHasUnsavedChanges(true);
      setButtonStates();
    }

    function resetUnsavedChanges() {
      AlmCommon.setHasUnsavedChanges(false);
      setButtonStates();
    }

    function unblockAlmContainer() {
      AlmCommon.unblockUI(repoPage.almContainer);
    }

    function setHasActiveJob(container, hasActiveJob) {
      $(container + ' ' + repoPage.isToolActivated).prop('checked', hasActiveJob).trigger('change');
    }

    function getHasActiveJob(container) {
      return $(container + ' ' + repoPage.isToolActivated).prop('checked');
    }

    function getId() {
      return AlmCommon.getUrlParameter('id');
    }

    function getUserTimezone() {
      return $('#user-timezone').val();
    }

    // Set state of Save button based on hasUnsavedChanges
    function setButtonStates() {
      var $saveButton = $('.save-btn');

      if (AlmCommon.getHasUnsavedChanges()) {
        $saveButton.removeClass('inactive').prop('disabled', false);
      } else {
        $saveButton.addClass('inactive').prop('disabled', true);
      }
    }
    
    function loadState() {
      var repoId = AlmCommon.getUrlParameter('id');

      if (repoId) {
        finishRepoLoad();
      }
    }

    function finishRepoLoad() {
      loadRepoUI();
    }

    function finishRepoSave() {
      if (!AlmCommon.hasSaveErrors()) {
        AlmCommon.setHasUnsavedChanges(false);
      }

      finishRepoLoad();
    }

    function loadRepoUI() {
      var selectedRepoId = getId();
      if (selectedRepoId === undefined) {
        AlmCommon.unblockUI(repoPage.mainContent);
        return;
      }
      generateScheduleTimeOptions($(repoPage.syncDetailsContainer + ' .start-time, ' + repoPage.syncDetailsContainer + ' .end-time'));
      enableToolSelectMenus(repoPage.syncDetailsContainer);
      setButtonStates();
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
    
      setSelectedOptionsBasedOnHiddenInputs($select);
    }
    
    function setSelectedOptionsBasedOnHiddenInputs($select) {
      $select.each(function() {
        var inputValue = $(this).siblings('input').val();
        if (inputValue) {
          $(this).val(inputValue);
        }
      });
    }

    function wireToolConfig(toolConfigProperties) {
      
      $(repoPage.almContainer).on('click', toolConfigProperties.container + ' ' + repoPage.accordionHandle, function() {
        $(repoPage.repoPanel).hasClass(toolConfigProperties.className + '-open')
          ? closeAccordion(toolConfigProperties)
          : activateTool(toolConfigProperties);
      });

      $(repoPage.almContainer).on('click', toolConfigProperties.container + ' .onoffswitch-container', function(e) {
        e.preventDefault();
        toggleTool(toolConfigProperties);
      });

      $(repoPage.almContainer).on('click', function(e) {
        toggleStatusFlyout(e, toolConfigProperties.container);
      });

      $(repoPage.almContainer).on('click', toolConfigProperties.container + ' .status-section .flyout-menu li', function() {
        setToolStatus(toolConfigProperties.container, this);
      });

      $(repoPage.almContainer).on('click', toolConfigProperties.container + ' .clickable-tile', toolDaySelectClickHandler);
      
      $(repoPage.almContainer).on('click', '.' + toolConfigProperties.className + '-deactivation-modal .continue-btn', function() {
        deactivateTool(toolConfigProperties);
        unblockAlmContainer();
      });
      
      AlmCommon.enableShiftSelect({
        container : repoPage.almContainer,
        selector : toolConfigProperties.container + ' .clickable-tile',
        callback : toolDaySelect
      });
      

    }

    function openAccordion(toolConfigProperties) {
      if ($(repoPage.repoPanel).hasClass(toolConfigProperties.className + '-open')) {
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
          $(repoPage.repoPanel).addClass(toolConfigProperties.className + '-open');
        }
      });
      
    }

    function closeAccordion(toolConfigProperties) {
      if (!$(repoPage.repoPanel).hasClass(toolConfigProperties.className + '-open')) {
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
          $(repoPage.repoPanel).removeClass(toolConfigProperties.className + '-open');
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

      $(toolConfigProperties.container + ' ' + repoPage.isToolDeactivationPending).val(false);
      setHasActiveJob(toolConfigProperties.container, true);
      
      //In lightning components, when jobs are rerendered, these dropdown menus are emptied.
      var $selects = $(repoPage.syncDetailsContainer + ' .start-time, ' + repoPage.syncDetailsContainer + ' .end-time');
      if(!$selects.html()) {
        generateScheduleTimeOptions($(repoPage.syncDetailsContainer + ' .start-time, ' + repoPage.syncDetailsContainer + ' .end-time'));
      }
      
      enableToolSelectMenus(toolConfigProperties.container);

      setUnsavedChanges();
    }

    function confirmDeactivateTool(toolConfigProperties) {
      if (!getHasActiveJob(toolConfigProperties.container) || $(toolConfigProperties.container + ' ' + repoPage.isToolDeactivationPending).val() === 'true') {
        return;
      }

      var message = "Are you sure you want to turn off " + toolConfigProperties.label + "? Any existing jobs scheduled will be deleted.";
      var warningCard = templates['sprint_warning'].render({
        'message' : message,
        'mainClass' : 'alm-modal ' + toolConfigProperties.className + '-deactivation-modal'
      });
      AlmCommon.displayModal({
        content: warningCard,
        container: repoPage.almContainer,
        width: '30%'
      });

      $('.alm-warning').parent().css({left: '0', top: '0'});
      $('.sp-card-wrap-error').show();
    }

    function deactivateTool(toolConfigProperties) {
      if (!getHasActiveJob(toolConfigProperties.container)) {
        return;
      }

      closeAccordion(toolConfigProperties);

      $(toolConfigProperties.container + ' ' + repoPage.isToolDeactivationPending).val(true);
      setHasActiveJob(toolConfigProperties.container, false);

      setUnsavedChanges();
    }

    function enableToolSelectMenus(toolContainer) {
      $(toolContainer + ' ' +  repoPage.interval).val($(toolContainer + ' ' +  repoPage.interval).siblings('input').val());
      $(toolContainer + ' ' +  repoPage.interval).almSelectMenu({
        change: selectMenuChange,
        width: '100%'
      });

      $(toolContainer + ' .start-time, ' + toolContainer + ' .end-time').almSelectMenu({
        change: selectMenuChange,
        width: '100%'
      });
    }

    function selectMenuChange() {
      selectSiblingInput.call(this);
      setUnsavedChanges();
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

    // Clears and hides the error message panel.
    function clearErrorMsg() {
      AlmCommon.clearMsgs();
    }
    var api = {
          pure: {
            finishRepoSave : finishRepoSave,
            loadRepoUI : loadRepoUI,
            setUnsavedChanges : setUnsavedChanges,
            resetUnsavedChanges : resetUnsavedChanges,
            addEventHandlers : addEventHandlers
          },
          testOnly: {
            finishRepoLoad : finishRepoLoad,
            setUnsavedChanges : setUnsavedChanges,
            repoPage : repoPage,
            toolDaySelectClickHandler: toolDaySelectClickHandler,
            setHasActiveJob: setHasActiveJob,
            setToolStatus: setToolStatus,
            setButtonStates: setButtonStates,
            vcSyncConfigProperties : vcSyncConfigProperties,
            toggleStatusFlyout: toggleStatusFlyout,
            activateTool : activateTool,
            deactivateTool : deactivateTool,
            unblockAlmContainer : unblockAlmContainer,
            toolConfigPropertiesGetters : toolConfigPropertiesGetters
          }
        };
    if (ApiBuilder !== undefined) {
      // TODO: We need to remove this define module name after
      // we have everything running on AMD and no scripts are loaded inline
      return new ApiBuilder(api).getApi();
    } else {
      return $.extend(api.pure, api.testOnly);
    }
  };
  if (typeof define !== 'undefined') {
    define(
        [
          'jquery',
          'js_alm_common',
          'combobox',
          'api_builder',
          //'admin_console/on_demand_tool',
          'alm_selectmenu',
          "moment",
          'external/moment/moment-timezone',
          //"oauth",
          'external/jquery.sticky-kit'
          //'common/request-manager'
          ], function() {
          
          var $ = arguments[0];
          var AlmCommon = arguments[1];
          var ComboBox = arguments[2];
          var ApiBuilder = arguments[3];
          //var OnDemandTool = arguments[4];
          var moment = arguments[5];
          //var oauth = arguments[7];
          //var RequestManager = arguments[8];
          
          var API = init($, AlmCommon, ComboBox, ApiBuilder, moment);
          
          global.BW = global.BW || {};
          global.BW.adminRepos = API;
          
          return global.BW.adminRepos;
        });
  }else {
    global.BW = global.BW || {};
    global.BW.adminRepos = init(global.jQuery, global.BW.AlmCommon, global.BW.ComboBox, global.BW.ApiBuilder, global.moment);
  }
})(this);