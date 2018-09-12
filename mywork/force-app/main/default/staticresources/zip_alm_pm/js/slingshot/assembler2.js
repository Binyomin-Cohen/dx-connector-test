(function() {
  var init = function ($, AlmCommon, ComponentSearch, ComboBox, ApiBuilder, SlingshotUtils, RequestManager, Analytics) {
      "use strict";

      var PARSE_PACKAGE_POLL_TIMEOUT = 30000;
      var PARSE_PACKAGE_POLL_INTERVAL = 3000;

      var assemblerPage = {
        applyProfilesBtn: 'input[id$="apply-profiles-btn"]',
        buildLabelContainer: '.wrap-container-labels.build',
        pendingRemovals : 'input[id$="pending-removals"]',
        profileSelectAll: '#profile-select-all'
      };

      var tableSorts = {
          buildErrorsTable : {},
          deploymentErrorsTable : {},
          manifestTable : {}
      };

      var pollBuildTimeout;

      function getPollBuildTimeout() {
        return pollBuildTimeout;
      }

      $(function () {
        addEventHandlers();
      });

      function addEventHandlers() {

        $("#alm-container").on("click", ".manifest-tab", toggleManifest);

        wireProfileEdit();
        wireManifestEdit();
        wireManifestFilter();
      }

      function addPendingRemoval(key) {
        if (!key) {
          return;
        }

        var componentId = key.split('|').pop();

        //only add the element if there are no others duplicates on the page that are not removed
        if ($('#manifest-components').find('tr[data-key$="' + componentId + '"]').not('.disabled').length === 0) {
          var $pendingRemovalsEl = $(assemblerPage.pendingRemovals);
          var pendingRemovals = ($pendingRemovalsEl.val()) ? $pendingRemovalsEl.val().split(',') : [];
          pendingRemovals.push(key);
          $pendingRemovalsEl
            .val(pendingRemovals.join(','))
            .data('has-pending-removals', true);
        }
      }

      function addSavedComponents() {
        ComponentSearch.clearAddedComponents();

        var savedComponents = [];

        $('.manifest-detail tbody tr').each(function() {
          var key = $(this).data('key');
          savedComponents.push(key);
        });

        if(savedComponents.length > 0) {
          ComponentSearch.addComponents(savedComponents);
        }
      }

      function componentSearch() {
        var $parent = $('.page-block-content-component-search');
        var searchParams = {};

        searchParams.name = $("#component-name").val() || null;
        searchParams.type = $("#component-type").val() || null;
        searchParams.parentComponent = $("#parent-name").val() || null;
        searchParams.selectedComps = ComponentSearch.getAddedComponentsString();
        searchParams.instances = $("#instance-search-filter").val() || null;
        searchParams.selectedUsers = null;

        // Determine the proper element to block depending on whether the table has results loaded in or not.
        var blockElement = ($('#search-panel .alm-table tbody tr').length) ? '#comp-search-res-wrapper' : '.search-results > div';
        ComponentSearch.doSearch(searchParams, blockElement);
      }

      function displayBuildErrorResult(numberOfErrors, webAssemblerError){
        if (numberOfErrors === 0 && webAssemblerError !==  undefined) {
          BW.slingshot.showProgressResultAndImage({
            type: "build",
            resultText: "N/A",
            result: "not-applicable"
          });
        } else {
          var errorMessage = (numberOfErrors === 1) ? numberOfErrors + " Error" : numberOfErrors + " Errors";
          BW.slingshot.showProgressResultAndImage({
            type : "build",
            resultText : errorMessage,
            result: "fail"
          });
        }
      }

      function setTableSort($table, additionalOptions) {
        var defaultOptions = {
          cssAsc: 'asc',
          cssDesc: 'desc',
          cssNone: 'unsorted',
          emptyTo: 'bottom'
        };
        var options = $.extend(defaultOptions, additionalOptions);
        $table.trigger("destroy").tablesorter(options);

        applyTableHandlers($table);
      }

      function enableTableSort() {
        var options = {
          headers: {
            0: {
              sorter: false
            }
          }
        };

        setTableSort($('#component-search-table'), options);
        setTableSort($('#manifest-components .manifest-detail table.alm-table'), $.extend(options, getTableSorts().manifestTable));
        setTableSort($('.simple-accordion-errors table.alm-table'), {});
      }

      function getBuildId() {
        return $('[id$=hidden-input-wrapper]').data('build-id');
      }

      function constructBuildStatusMessage(buildModel) {
        if (buildModel) {
          if (buildModel.buildStage === SlingshotUtils.stages.PACKAGING) {
            return '<span class="progress-data">' + SlingshotUtils.stages.PACKAGING + '</span>';
          } else if (buildModel.buildStage === SlingshotUtils.stages.RETRIEVING) {
            var msg = SlingshotUtils.stages.RETRIEVING;

            if (buildModel.componentsRetrieved && buildModel.componentsTotal) {
              msg += ' <span class="progress-data">';
              msg += buildModel.componentsRetrieved + ' / ' + buildModel.componentsTotal +'</span>';
            }

            msg += " components"

            return msg;
          } else if (buildModel.buildStage === SlingshotUtils.stages.CREATING_BACKUP) {
            return '<span class="progress-data">' + SlingshotUtils.statuses.CREATING_BACKUP + '</span>';
          }


          return "";
        }
      }

      function drawRadialBuildProgress(buildModel) {
        var numComplete = 0,
        progressColor = BW.slingshot.getActionColor(),
        $buildLabelContainer = $(assemblerPage.buildLabelContainer),
        oldProgressVal = $buildLabelContainer.data('comps-retrieved');

        if (buildModel) {
          if (buildModel.buildStatus === "Success" || buildModel.buildStatus === "Failed") {
            numComplete = 100;
          } else if (buildModel.buildStage === SlingshotUtils.stages.RETRIEVING) {
            if (!buildModel.componentsTotal) {
              numComplete = 10;
            } else {
              numComplete = 10 + (buildModel.componentsRetrieved / buildModel.componentsTotal) * 80;
            }
          } else if (buildModel.buildStage === SlingshotUtils.stages.PACKAGING) {
            if (!oldProgressVal || oldProgressVal < 90) {
              numComplete = 90;
            } else if (oldProgressVal < 99) {
              numComplete = oldProgressVal + 1;
            } 
          } else if (buildModel.buildStage === SlingshotUtils.stages.CREATING_BACKUP) {
            if (!oldProgressVal) {
              numComplete = 25;
            } else if (oldProgressVal < 90) {
              numComplete = oldProgressVal + 5;
            }
          }
        }
        if (oldProgressVal && oldProgressVal > numComplete) {
          //ignore any polling requests that show backwards progress
          return;
        }

        BW.slingshot.drawRadialProgress(1500, SlingshotUtils.colors.PENDING, progressColor, false, oldProgressVal, 100);
        $('.component-progress').data('radial-progress').animate(numComplete / 100);
        $buildLabelContainer.data('comps-retrieved', numComplete);
      }

      function finishAddUndocumented() {
        AlmCommon.unblockUI('#manifest-edit-details');
        updateComponentCount();
        finishManifestLoad(true);
        BW.slingshot.setSavedStatus(true);

        // Manually set accordion container's size when manifest details overflow the container
        var manifestDetails = $('.manifest-detail').first(),
            manifestContainer = $('#manifest-components').first(),
            accordionBody = $('#manifest-edit-pane').closest('.simple-accordion-body');
        if (manifestDetails.height() > manifestContainer.height()) {
          accordionBody.height(manifestDetails.height());
        }
      }

      /**
       * Resets the manifest pane.
       * @param {Boolean} isFiltering   - set to true when finished filtering the manifest
       */
      function finishManifestLoad(isFiltering) {
        forceManifestTabRerender(); // bug fix for MS browsers (Item-04302) after adding undoc'd comps
        enableTableSort();
        AlmCommon.unblockUI( '#manifest-body' );
        $('#manifest-body').tooltip();

        if (!isFiltering) {
          initializeComboboxes();
          addSavedComponents();
          BW.slingshot.finishDeploymentErrorsLoad();
        }

        if (BW.slingshot.buildIsManualUpload()) {
          $('.profile-permissions .profile-tile').prop('disabled', true);
        }

        initializeApplyProfilesButton();
      }

      function forceManifestTabRerender() {
        var $elem = $('.manifest-tab');
        $elem.css('display', 'none').height(); // .height() forces a redraw of the element
        $elem.css('display', 'block');
      }

      function initializeComboboxes() {
        ComboBox.init({
          inputSelector : '#instance-search-filter',
          parentContainer : '#search-form',
          appendTo : "#search-form",
          isMultiSelect : false
        });
        initFilter( "#instance-filter" );
        initFilter( "#status-filter" );
        initFilter( "#type-filter" );
      }

      function finishApplyProfiles() {
        initializeApplyProfilesButton();
      }

      function initializeApplyProfilesButton() {
        $(assemblerPage.applyProfilesBtn).addClass('inactive').prop('disabled', true);
      }

      function onStartAssemblerComplete() {
        startPolling();

        var buildId = getBuildId();
        if(!buildId) { return; }
        getUpdatedDeployment(buildId, function(deploymentAttemptModel, event) {
          if(event.status) {
            BW.slingshot.setStartTimeText(deploymentAttemptModel);
          } else if(event.message) {
            AlmCommon.clearMsgs();
            AlmCommon.showError(event.message);
          }
        });
      }

      function pollBuildStatus() {
        var buildId = getBuildId();

        if (!buildId) { return; }

        checkBuildStatus(buildId, function (buildModel, event) {
          if (event.status) {
            var args = {
                deploymentText: SlingshotUtils.stages.BUILDING,
                deploymentTextCssClass: 'pending',
                deploymentImageCssClass: 'pending',
                showFailText: false,
                progressLabelText: ''
            };
            var buildStatus = buildModel.buildStatus;
            var webAssemblerStatus = buildModel.webAssemblerFailureMessage;

            if (buildStatus === "Pending") {
              args.deploymentText = SlingshotUtils.stages.PENDING;
            } else {
              $("img[id$=selected-action-img]").hide();
            }

            SlingshotUtils.setStatusDetail(constructBuildStatusMessage(buildModel));

            BW.slingshot.setActionTextAndImage(args);
            BW.slingshot.showProgressTypeAndImage("build", "in-progress");

            drawRadialBuildProgress(buildModel);

            if ( buildStatus === "Success" ) {
              BW.slingshot.showProgressResultAndImage({
                type : "build",
                resultText : "Success",
                result: "pass"
              });

              BW.slingshot.kickoffDeployer();
            } else if (buildStatus === "Failed") {
              getBuildErrors(buildId, function(numberOfErrors, event) {
                forceManifestTabRerender(); // bug fix for MS browsers (Item-04302)
                displayBuildErrorResult(numberOfErrors, webAssemblerStatus);

                if (webAssemblerStatus === undefined) {
                  $("#slingshot-card-body").addClass('has-errors');
                }

                BW.slingshot.kickoffDeployer();
              });
            } else {
              pollBuildTimeout = window.setTimeout( pollBuildStatus, SlingshotUtils.constants.FIVE_SECONDS);
            }
          } else if (event.message){
            AlmCommon.clearMsgs();
            AlmCommon.showError( event.message);
          }
        });
      }

      function profileSelectHandler($items, isChecked) {
        if (isChecked) {
          $items.addClass('selected');
        } else {
          $items.removeClass('selected');
        }
        $items.find('input').val(isChecked);

        var $allProfiles = $("#profile-edit-details .profile-tile");

        if ($allProfiles.length == $allProfiles.filter('.selected').length) {
          $(assemblerPage.profileSelectAll).prop( "checked", true );
        } else {
          $(assemblerPage.profileSelectAll).prop( "checked", false );
        }
      }

      function startPolling() {
        $(assemblerPage.buildLabelContainer).data('comps-retrieved', 0);
        pollBuildStatus();
      }

      function toggleAddComponentsTray() {
        var $handle = $( '#manifest-edit-handle'),
        $tray =  $('#manifest-edit-pane'),
        handlePosition = '97%',
        options = {
          expandParent : true
        };

        BW.slingshot.closeOtherOpenTrays('manifest-edit-pane');

        // Set the 'original-height' attribute to stop unnecessary jQuery height animations
        var manifestDetails = $('.manifest-detail').first(),
            accordionBody = $('#manifest-edit-pane').closest('.simple-accordion-body');
        accordionBody.data('original-height', manifestDetails.height());

        AlmCommon.toggleSlidingTray( $tray, $handle, handlePosition, options);
      }

      /**
       * Toggles a component in the manifest between the added or removed state
       */
      function toggleComponent() {
        var $this = $(this),
            $row = $this.closest('tr'),
            isUndocumented = $row.hasClass('undocumented-component'),
            $closestSelect = $this.closest('.select'),
            $isRemovedInput = $closestSelect.find('input[id$=documented-select]'), // ends with documented..
            $savedIsRemovedInput = $closestSelect.find('input[id$=saved-isRemoved-value]'); 

        if ($row.hasClass('disabled')) {
          $this.removeClass('add');
          $this.attr('title',  $this.data('remove-title'));
          $isRemovedInput.val(false);
          $row.removeClass('disabled');
          $(assemblerPage.pendingRemovals).data('has-pending-removals', true);
        } else if (isUndocumented) {
          removeUndocumentedComponents( $row );
        } else {
          $this.addClass('add');
          $this.attr('title',  $this.data('add-title'));
          $isRemovedInput.val(true);
          $row.addClass('disabled');
          addPendingRemoval($row.data('key'));
        }
        $row.toggleClass('changed-is-removed', ($savedIsRemovedInput.val() !== $isRemovedInput.val()));
        BW.slingshot.setSavedStatus(true);
      }

      function removeUndocumentedComponents($rows) {
        var rowKeys = '';
        $rows.each(function() {
          var $row = $(this),
              rowKey = $row.data('key'),
              isUndocumented = $row.hasClass('undocumented-component');

          if (isUndocumented) {
            rowKeys = rowKeys + ((rowKeys) ? "," : "") + rowKey;
          }
        });

        RequestManager.invokeFunction(afRemoveUndocumentedComponents, rowKeys, {
          callback : function() {
            finishUndocumentedComponentsRemoval($rows);
            ComponentSearch.removeComponents(rowKeys.split(','));
          }
        });
      }

      function finishUndocumentedComponentsRemoval($rows) {
        $rows.remove();
        updateComponentCount();
        enableTableSort();
        BW.slingshot.setSavedStatus(true);
        AlmCommon.unblockUI( '#manifest-body' );
      }

      function toggleFilterManifestTray() {
        var $handle = $( '#manifest-filter-handle'),
        $tray =  $('#manifest-filter-pane'),
        handlePosition = '284px',
        options = {
          expandParent : true
        };

        BW.slingshot.closeOtherOpenTrays('manifest-filter-pane');
        AlmCommon.toggleSlidingTray( $tray, $handle, handlePosition, options);
      }

      function toggleManifest() {
        BW.slingshot.collapseDeploymentErrorTables(true);
        var $manifestTab = $('.manifest-tab');
        $manifestTab.toggleClass('expanded');
        $('#slingshot-card-body').toggleClass('manifest-open');
        if ($('[id$=manifest-tab-loaded]').data('is-loaded') !== true) {
          startParsePackageUpdatePolling(function() {
            RequestManager.invokeFunction(afLoadManifest, null, { 
              callback : function parsePackageCompleteCallback() {
                finishManifestLoad();
                displayParseBuildError();
              }
            });
          });
          AlmCommon.blockUI( '#manifest-body' );
        } else {
          enableTableSort();
          addSavedComponents();
        }
      }

      function toggleProfileEdit() {
        var $handle = $('#profile-edit-handle'),
         $tray =  $("#profile-edit-pane"),
         handlePosition = '97%',
         options = {
           expandParent : true,
           parentEl : $('#profile-panel'),
           parentMinHeight : $('#profile-edit-pane').height(),
           onCompleteHandler : function(tray, trayHandle, handlePostion) {
            var scrollOffset = 10;
            if (trayHandle.hasClass('close')) {
               $('html, body').animate({
                 scrollTop: $('.profile-manifest').offset().top - scrollOffset
               });
             }
             $('#profile-edit-pane .tray-title').show();
           },
           onStartHandler : function(tray, trayHandle, handlePostion) {
             if (trayHandle.hasClass('is_stuck')) {
               $('#profile-edit-pane .tray-title').hide("slide", {
                 direction: "left",
                 queue: false
               });
             }
           }
         };

        BW.slingshot.closeOtherOpenTrays('profile-edit-pane');
        AlmCommon.toggleSlidingTray( $tray, $handle, handlePosition, options);

        if (!$handle.hasClass('is_stuck')) {
          $('#profile-edit-pane .tray-title').stick_in_parent();
          //until we can figure out the z-index issue, this enables us to hide the handle
          $handle.stick_in_parent();
        }
      }

      function addAllComponents() {
        var $removedComponents = $(".manifest-detail tr").not('.deleted-bc').find("td.select img.add");
        $removedComponents.each(toggleComponent);
        $("#manifest-select-all").removeClass("add");
        $('[id$=manifest-component-toggle]').data('manifest-component-toggle', '');
      }

      function removeAllComponents() {
        var $undocumentedComponents = $(".manifest-detail").find("tr.undocumented-component");
        var $addedComponents = $(".manifest-detail")
            .find('tr').not('.undocumented-component, .deleted-bc')
            .find('td.select img').not('.add');

        removeUndocumentedComponents($undocumentedComponents);
        $addedComponents.each(toggleComponent);
        $("#manifest-select-all").addClass("add");
        $('[id$=manifest-component-toggle]').data('manifest-component-toggle', 'add');
      }

      function confirmRemoveAll() {
        var message = "You are about to make changes to all of the components in the manifest.";

        var removeAllModal = templates['confirmation_modal'].render({
          'id' : 'manifest-remove-all-modal',
          'message' : message
        });
        AlmCommon.displayModal({
          content: removeAllModal,
          container: '#alm-container',
          width: '30%'
        });

        $('#manifest-remove-all-modal').parent().css({left: '0', top: '0'});
        $('#manifest-remove-all-modal').show();
      }

      function wireManifestEdit() {
        $("#alm-container").on("click", "td.select img", toggleComponent);
        $("#alm-container").on("click", "#manifest-select-all a.add-all", addAllComponents);
        $("#alm-container").on("click", "#manifest-select-all a.remove-all", confirmRemoveAll);
        $("#alm-container").on("click", "#manifest-remove-all-modal .confirm-button", function() {
          AlmCommon.unblockUI( '#alm-container' );
          AlmCommon.blockUI( '#manifest-body' );
          removeAllComponents();
        });
        $("#alm-container").on("click", "#manifest-remove-all-modal .cancel-button", function() {
          AlmCommon.unblockUI('#alm-container');
        });
        $("#alm-container").on("click", "#manifest-edit-handle", toggleAddComponentsTray);
        $("#alm-container").on("click", ".search-btn", componentSearch);

        $("#alm-container").on( "keypress", "#search-form input", function(evt) {
          AlmCommon.performActionOnEnter( $(this), evt, function() {
              componentSearch();
              evt.preventDefault();
          });
        });

        var addComponents = function() {
          AlmCommon.blockUI('#manifest-edit-details');
          RequestManager.invokeFunction(
            afAddUndocumentedComponents,
            ComponentSearch.getSelectedComponentsString(),
            {
              objectsToShow: ['#manifest-message-spinner-container'],
              objectsToHide: ['.manifest-tab .error'],
              callback: finishAddUndocumented
            }
          );

          ComponentSearch.addAllSelectedComponents();
          // uncheck select all if it was checked
          $('.select-all-checkbox').prop('checked', false);

          // Disable me
          $(this).prop('disabled', true).addClass('inactive');
          Analytics.trackEvent('Slingshot', 'Document Components', 'Slingshot - Edit Undocumented Components');
        }
        $( "#alm-container" ).on( "click", "#search-panel .add-btn", addComponents);
        $("#search-panel .add-btn").prop('disabled', true);

        $( "#alm-container" ).on( "click", '#search-panel input[type="checkbox"]', function toggleApplyBtn() {
          var checkedRows = $( this ).closest('.alm-table').find( 'input:checked' ).length;
          var $applyBtn = $('#search-panel').find('.disableable-btn');

          if ( checkedRows > 0 ) {
            $applyBtn
                .prop("disabled", false)
                .removeClass('inactive');
          }
          else {
            $applyBtn
              .prop("disabled", true)
              .addClass('inactive');
          }
        });
      }

      function updateComponentCount() {
        $('#manifest-components .component-count').text($('[id$=hidden-input-wrapper]').data('component-count'));
      }

      function invokeFilterManifest() {
        RequestManager.invokeFunction(
          afFilterManifest,
          null,
          {
            callback: function() {
              finishManifestLoad(true);
            }
          }
        );
      }

      function wireManifestFilter() {
        $("#alm-container").on("click", "#manifest-filter-handle", toggleFilterManifestTray);

        $('#alm-container').on('click', '.backlog-menu input[type="checkbox"]', function() {
          invokeFilterManifest();
          AlmCommon.blockUI( '.manifest-detail' );
        });

        $('#alm-container').on('click', '#clear-filters', function() {
          $('.combobox-selection').empty();
          $('.alm-combobox .filter-values option').filter(':selected').prop("selected",false);
          $('.backlog-menu input:checked').prop( 'checked', false);

           invokeFilterManifest();
           AlmCommon.blockUI( '.manifest-detail' );
           ComboBox.setSource( $("#instance-filter") );
           ComboBox.setSource( $("#status-filter") );
           ComboBox.setSource( $("#type-filter") );
        });

        $('#alm-container').on('click', 'a.remove-filter', function() {
          ComboBox.removeSelectedOption($(this), function callback($input) {
            invokeFilterManifest();
            ComboBox.setSource($input);
            AlmCommon.blockUI( '.manifest-detail' );
          });
        });
      }

      /**
       * @param {string} selector for the input field to initialize
       */
      function initFilter( inputSelector ) {

        ComboBox.init({
          inputSelector : inputSelector,
          parentContainer : '.page-block-panel-section-body',
          appendTo : "#manifest-filter-pane",
          selectAction : function() {
            Analytics.trackEvent('Slingshot', 'Apply Filter');

            invokeFilterManifest();
            AlmCommon.blockUI( '.manifest-detail' );
          }
        });
      }

      function wireProfileEdit() {
        $( "#alm-container" ).on( "click", "#profile-edit-handle, " + assemblerPage.applyProfilesBtn + ", #profile-edit-handle-inner", toggleProfileEdit);
        $( "#alm-container" ).on( "click", assemblerPage.applyProfilesBtn, function() {
          Analytics.trackEvent('Slingshot', 'Document Profile', 'Slingshot - Profiles Modified');

          BW.slingshot.setSavedStatus(true);
        });
        $( "#alm-container" ).on( "click", "#profile-panel .profile-permissions .profile-tile", function() {
          BW.slingshot.closeOtherOpenTrays();
        });

        $( "#alm-container" ).on( "click", "#profile-edit-details .profile-tile", function(event) {
          $(assemblerPage.applyProfilesBtn).removeClass('inactive').prop('disabled', false);

          var $tile = $(this),
           isChecked = !$tile.hasClass('selected');

          //let shift click handler deal with this.
          if(event.shiftKey) {
            return;
          }

          profileSelectHandler($tile, isChecked );

          event.preventDefault();
        });

        AlmCommon.enableShiftSelect({
          container : "#alm-container",
          selector : '#profile-edit-details .profile-tile',
          callback : profileSelectHandler
        });

        $( "#alm-container" ).on( "click", assemblerPage.profileSelectAll, function() {
          var $profileTiles = $("#profile-edit-details .profile-tile");
          $(assemblerPage.applyProfilesBtn).removeClass('inactive').prop('disabled', false);

          if ( $(this).prop( "checked" ) ) {
            $profileTiles.addClass('selected');
            $profileTiles.find('input').val( true );
          }
          else {
            $profileTiles.removeClass('selected');
            $profileTiles.find('input').val( false );
          }
        });

        $( window ).on( "keydown", function(event) {
          if ($('#profile-edit-handle').hasClass("close")) {
            AlmCommon.performActionOnSelectAll($(this), event, function() {
              var $profileTiles = $("#profile-edit-details .profile-tile");
              $profileTiles.addClass('selected');
              $profileTiles.find('input').val( true );
              $(assemblerPage.profileSelectAll).prop( "checked", true );
            });
          }
        });
      }

      function getTableSorts() {
          return tableSorts;
      }

      function applyTableHandlers($table) {
        $table.on('click', 'th.tablesorter-header', function() {
          var col = $(this).data('column');
          var sortType = ( $(this).hasClass('desc') || $(this).hasClass('unsorted') ) ? 0 : 1;
          tableSorts.manifestTable = {
              sortList: [[col, sortType]]
          };
        });
      }

      /**
       * Start polling for the build package parsing to be completed
       * @param {function} callback to excecute once the package has finished being parsed
       */
      function startParsePackageUpdatePolling(callback) {
        if (BW.slingshot.buildIsManualUpload() && !getIsBuildPackageParsed()) {
          pollParsePackageUpdate(getBuildId(), PARSE_PACKAGE_POLL_TIMEOUT, callback);
        } else if (typeof callback === 'function') {
          callback();
        }
      }

      function pollParsePackageUpdate(buildId, timeout, callback) {
        if (buildId !== getBuildId()) {
          return;
        }

        remotePollParsePackageUpdate(buildId, function(response) {
          var hiddenInputWrapper = $('[id$=hidden-input-wrapper]');
          if (response) {
            hiddenInputWrapper.data('is-manual-package-parsed', response.isPackageParsed);
            hiddenInputWrapper.data('parse-build-failure-reason', response.failureReason);
          }

          if (getIsBuildPackageParsed() || timeout < PARSE_PACKAGE_POLL_INTERVAL) {
            if (typeof callback === 'function') {
              callback();
            }
          } else {
            window.setTimeout(function() {
              pollParsePackageUpdate(buildId, timeout - PARSE_PACKAGE_POLL_INTERVAL, callback);
            }, PARSE_PACKAGE_POLL_INTERVAL);
          }
        });
      }

      function displayParseBuildError() {
        if (getParseBuildFailureReason()) {
          $('[id$="manifest-page-messages"').empty();
          AlmCommon.addWarningMessage(
            "Unable to parse the package.xml from the manually uploaded package.  Please check your package and try again.",
            { messagePanel: '[id$="manifest-page-messages"]'}
          );
        }
      }

      function getParseBuildFailureReason() {
        return $('[id$=hidden-input-wrapper]').data('parse-build-failure-reason');
      }

      function getIsBuildPackageParsed() {
        return $('[id$=hidden-input-wrapper]').data('is-manual-package-parsed');
      }

      return new ApiBuilder({
        pure: {
          displayBuildErrorResult : displayBuildErrorResult,
          displayParseBuildError : displayParseBuildError,
          finishAddUndocumented : finishAddUndocumented,
          finishApplyProfiles : finishApplyProfiles,
          finishManifestLoad : finishManifestLoad,
          getBuildId : getBuildId,
          getPollBuildTimeout: getPollBuildTimeout,
          getTableSorts : getTableSorts,
          initializeComboboxes : initializeComboboxes,
          onStartAssemblerComplete : onStartAssemblerComplete,
          setTableSort : setTableSort,
          startParsePackageUpdatePolling: startParsePackageUpdatePolling,
          startPolling : startPolling,
          toggleAddComponentsTray : toggleAddComponentsTray,
          toggleFilterManifestTray : toggleFilterManifestTray,
          toggleManifest : toggleManifest,
          toggleProfileEdit : toggleProfileEdit,
          updateComponentCount : updateComponentCount
        },
        testOnly: {
          addAllComponents : addAllComponents,
          addPendingRemoval : addPendingRemoval,
          constructBuildStatusMessage : constructBuildStatusMessage,
          drawRadialBuildProgress : drawRadialBuildProgress,
          finishUndocumentedComponentsRemoval : finishUndocumentedComponentsRemoval,
          initializeApplyProfilesButton : initializeApplyProfilesButton,
          invokeFilterManifest : invokeFilterManifest,
          page: assemblerPage,
          pollBuildStatus : pollBuildStatus,
          removeAllComponents : removeAllComponents,
          resetPollBuildTimeout : function() { pollBuildTimeout = null; },
          wireManifestEdit : wireManifestEdit,
          wireProfileEdit : wireProfileEdit,
          PARSE_PACKAGE_POLL_INTERVAL : PARSE_PACKAGE_POLL_INTERVAL,
          PARSE_PACKAGE_POLL_TIMEOUT : PARSE_PACKAGE_POLL_TIMEOUT
        }
      }).getApi();
  };

  define([
    'jquery',
    'js_alm_common',
    'client_comp_search_results',
    'jquery-tablesorter',
    'combobox',
    'api_builder',
    'slingshot/utils',
    'common/request-manager',
    'try!analytics'
  ], function() {
    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    var ComponentSearch = arguments[2];
    var ComboBox = arguments[4];
    var ApiBuilder = arguments[5];
    var SlingshotUtils = arguments[6];
    var RequestManager = arguments[7];
    var Analytics = arguments[8];

    var API = init(jQuery, AlmCommon, ComponentSearch, ComboBox, ApiBuilder, SlingshotUtils, RequestManager, Analytics);
    window.BW = window.BW || {};
    window.BW.assembler = API;
    return API;
  });
})();
