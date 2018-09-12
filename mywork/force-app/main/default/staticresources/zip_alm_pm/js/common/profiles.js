(function(global) {
  var init = function($, ApiBuilder, AlmCommon, ComponentSearch, templates, Analytics) {
    /**map of profile templates by instance name*/
    var LOADED_PROFILE_TEMPLATES = {};
    var config = {};
    var hasUnsavedPermissionChanges = false;
    var SCROLL_ANCHOR_OFFSET = 70,
        PROFILE_NAME_INSTANCE_DELIMETER = '~|~',
        SCROLL_ANCHOR_OFFSET_BOUNDARY_BUFFER = 10;

    /**
    * @param    options - optional configuration arguments
    * @param    options.useMultiInstanceTemplate - boolean that controls if the ProfileTemplate should be
    *           retrieved for multiple instances. Defaults to false
    * @param    options.getDefaultInstances     - {function} optionally specify a callback function to return an
    *                                           array of instances to be use for the profile template
    * @param    options.profilePreload          - {function} optionally specify a callback function to load
    *                                           additional data before loading the profile modal
    * @param    options.parentEventContainer - {String} optionally specify a parent to be used when adding event handlers
    */
    function init(options) {
      config = $.extend({
        getDefaultInstances: function(){ return []},
        useMultiInstanceTemplate: false,
        includeProfilePermissionsFromSourceOnly: false,
        parentEventContainer : ""
      }, options);

      AlmCommon.enableSimpleAccordions('#permissions-modal');
      AlmCommon.enableTwistyPageBlockPanelSections('#permissions-modal');

      addEventHandlers();
    }

    function addEventHandlers() {
      if( !config.inLightning ){
        $("#alm-container").on("click", config.parentEventContainer + " .profile-tile", function() {
          displayProfilePermissions( $(this) );
        });
        $("#profile-apply-btn").on("click", applyPermissions);
      }

      $(document).on( "click", "#select-all-permissions", function() {
        setHasUnsavedChanges(true);
        selectAllPermissions($(this).prop("checked"));
        checkDocumentedDeselection($('.permissions-option.documented input'));
      });

      $(document).on( "change", "#permissions-modal .permission", function(event) {
        setHasUnsavedChanges(true);
        handlePermissionsSelect.call(this);
      });

      AlmCommon.enableShiftSelect({
        container : "#permissions-modal",
        parent: ".permissions-option",
        selector : ".permissions-option label"
      });

      $('#permissions-modal').on('click', '#onoffswitch-container', toggleSwitch);
      $('#permissions-modal').on('click', 'img.info-icon', function(event){event.stopPropagation();});

      $( document ).on( "click", ".profile-section-all", function() {
        var $profileSection = $(this).closest('.profile-section');
        setHasUnsavedChanges(true);
        $profileSection
          .find('input.permission, .profile-section-all')
          .prop("checked", $(this).prop( "checked" ) );
        handlePermissionsSelect.call($(this));
        checkDocumentedDeselection($profileSection.find('input.permission'));
      });

      $( document ).on("click", "#permissions-modal .close-modal-btn", promptCloseProfilePermissions);

      $( document ).on( "click", "#cancel-profile-modal .close-no-save-btn", closeProfilePermissions);

      $( document ).on( "click", "#cancel-profile-modal .continue-btn", function() {
        AlmCommon.unblockUI("#permissions-modal");
      });

      $('body').scrollspy( {
        target: '.nav-container',
        offset: SCROLL_ANCHOR_OFFSET }
      );

      $( document ).on( "click", "#permissions-modal .nav-tile", handleNavClick);
    }

    function applyPermissions() {
      setHasUnsavedChanges(false);
      AlmCommon.setHasUnsavedChanges(true);

      var profileKey = $("#permissions-modal").data('selected-profile-key'),
        $profileTile = $('.profile-permissions').find('div[data-key="' + profileKey + '"]'),
        $permissionsStorage = $profileTile.find('input[id$="selected-permissions"]'),
        data = getSelectedData();

      $permissionsStorage.val( JSON.stringify(data.selectedPermissions) );
      getIncludeOnlyDocumentedInputEl($profileTile).val(data.autoIncludePermissions);
      getIncludeEntireProfileEl($profileTile).val(data.includeEntireProfile);

      closeProfilePermissions();

      //TODO: for now rely on the configuration. In the future we should rely on the URL
      var application = (config.useMultiInstanceTemplate) ? 'slingshot' : 'compdoc';
      Analytics.trackEvent(application, 'applyPermissionChanges', 'profiles - apply');
    }

    function getSelectedData() {
      var includeEntireProfile = $("#select-all-permissions").prop("checked"),
        profileKey = $("#permissions-modal").data('selected-profile-key'),
        $profileTile = $('.profile-permissions').find('div[data-key="' + profileKey + '"]'),
        selectedPermissions = {
          name : $profileTile.find('.name').text(),
          instances : $profileTile.data('instances'),
          sections : []
        };

      if (includeEntireProfile !== true) {
        $('#permissions-detail .simple-accordion').each(function() {
          var sectionApiName = $(this).data('section-api-name');
          if (sectionApiName !== undefined){
            var section = {
              apiName: sectionApiName,
              permissions : []
            };
            $(this).find('input:checked').each(function() {
              var permissionApiName = $(this).data('api-name');
              if (permissionApiName !== undefined){
                section.permissions.push( AlmCommon.htmlUnescape(permissionApiName) );
              }
            });

            if (section.permissions.length > 0) {
              selectedPermissions.sections.push(section);
            }
          }
        });
      }

      return  {
        autoIncludePermissions : $("#auto-include-permissions").prop("checked"),
        backlogComponentId : $profileTile.data('id'),
        includeEntireProfile : includeEntireProfile,
        selectedPermissions : selectedPermissions
      };
    }

    function promptCloseProfilePermissions() {
      if(hasUnsavedPermissionChanges) {
        AlmCommon.displayModal({
          container: $('#permissions-modal'),
          content: $("#cancel-profile-modal"),
          width: '30%'
        });
        $('#cancel-profile-modal').parent().css({ top: '86px' });
      } else {
        closeProfilePermissions();
      }
    }

    function closeProfilePermissions() {
      setHasUnsavedChanges(false);
      AlmCommon.unblockUI();
      //cleanup modal
      $('#permissions-modal-body').empty();
    }

    function displayProfilePermissions($profileTile) {
      $.blockUI({
        message: $("#permissions-modal"),
        css: {
            cursor: 'default',
            width: '100%',
            top: '0',
            left:  '0',
            bottom:  '0',
            right:  '0',
            border: 'none',
            background: 'none',
            position: 'absolute',
            height: '100%',
            display: 'table'
        },
        onOverlayClick: function() {
          // This check prevents the handler from double-firing.
          if ($('#cancel-profile-modal').is(':hidden')) {
            promptCloseProfilePermissions();
          }
        }
      });

      // This ensures that clicking out of the modal to close doesn't fail if the permission modal itself is sitting on top of the overlay.
      $('#permissions-modal').parent().on('click', function(event) {
        if (event.target == this) {
          promptCloseProfilePermissions();
        }
      });

      var instanceName = $profileTile.find('.instance').text(),
        profileName = $profileTile.find('.name').text();
      AlmCommon.blockUI('#permissions-modal');

      if (config.useMultiInstanceTemplate) {
        var storedProfileData = getProfileData($profileTile);
        if (storedProfileData && storedProfileData.instances) {
          instanceName = storedProfileData.instances;
        }

        if (!instanceName || !instanceName.length) {
          instanceName = config.getDefaultInstances();
        }

        if (!instanceName || !instanceName.length) {
          AlmCommon.clearMsgs()
          AlmCommon.showError("Profiles cannot be edited without components in the manifest.");
          AlmCommon.unblockUI();
          return;
        }
      }

      $("#permissions-modal")
        .data('instance-name', instanceName)
        .data('selected-profile-key', $profileTile.data('key'))
        .find('.permissions-banner .profile-name').text(profileName);

      if (config.profilePreload && typeof config.profilePreload === 'function') {
        config.profilePreload(instanceName, $profileTile.data('key'), finishDisplayProfilePermissions);
      } else {
        finishDisplayProfilePermissions(instanceName, $profileTile);
      }
    }

    function finishDisplayProfilePermissions(instanceName, $profileTile) {
      $profileTile.data('instances', [].concat(instanceName));

      if (LOADED_PROFILE_TEMPLATES[instanceName]) {
        loadProfileModal($profileTile, LOADED_PROFILE_TEMPLATES[instanceName]);
      } else {
        remoteGetProfileTemplate(instanceName, function(profileTemplate, event) {
          if (event.status) {
            LOADED_PROFILE_TEMPLATES[instanceName] = profileTemplate;
            loadProfileModal($profileTile, profileTemplate);
          } else if (event.message){
            AlmCommon.showError(event.message);
            AlmCommon.unblockUI();
          }
        });
      }
    }

    function handleNavClick(event) {
      var $selectedNavTile = $(this),
        target = $selectedNavTile.find('a').attr('href');

      var bodyTop = $('body').scrollTop();
      var htmlTop = $('html').scrollTop();

      $('html, body').animate({
        scrollTop: calculateTargetScrollOffset( $(target).offset().top )
      }, function() {
        //fall back for FF scroll animation not working in lightning
        if (bodyTop === $('body').scrollTop()
          && htmlTop === $('html').scrollTop()) {
          $(target).get(0).scrollIntoView();
        }
      });

      event.preventDefault();
    }

    function calculateTargetScrollOffset( targetTopLocation ){
      return targetTopLocation - ( SCROLL_ANCHOR_OFFSET - SCROLL_ANCHOR_OFFSET_BOUNDARY_BUFFER );
    }

    function getIncludeOnlyDocumentedInputEl($profileTile) {
      return $profileTile.find("input[id$='include-only-documented-components']");
    }

    function getIncludeEntireProfileEl($profileTile) {
      return $profileTile.find("input[id$='include-entire-profile']");
    }

    function loadProfileModal($profileTile, profileTemplate) {

      var prp = {"permissions_row" : templates["permissions_row"]};

      var transformApiNameToId = function(permission) {
          permission.htmlId = permission.apiName.replace(/[ ]/g, "__");
      };

      //add a sectionApiName to each property to this can be referenced from the profile row partial without name conflicts
      profileTemplate.sections.forEach(function(section) {
        section.sectionApiName = section.apiName;
        //add an htmlId to each permission so it can be transformed into a valid html id
        section.permissions.forEach(transformApiNameToId);
        section.standardPermissions.forEach(transformApiNameToId);
        section.customPermissions.forEach(transformApiNameToId);
      });

      var simpleAccordionPartial = templates["profile_body"].render( profileTemplate, prp);
      $("#permissions-modal-body").html(simpleAccordionPartial);
      $("#auto-include-permissions").prop("checked", getIncludeOnlyDocumentedInputEl($profileTile).val() === 'true');

      loadProfileData($profileTile);

      populateSelectAllCheckbox();

      setHasUnsavedChanges(false);
      window.scrollTo(window.scrollX, 0);
      AlmCommon.unblockUI("#permissions-modal");

      $('.permissions-banner').stick_in_parent({
        parent: $('#permissions-modal')
      });
      $('#permissions-modal-body .nav-container').stick_in_parent({
        parent: $('#permissions-modal'),
        offset_top: $('.permissions-banner').height()
      });

      $("#permissions-modal .nav-tile").first().addClass('active');
    }

    function loadProfileData($profileTile) {

      var storedProfileData = getProfileData($profileTile);

      initDocumentedPermissionOptions( getIncludeOnlyDocumentedInputEl($profileTile).val() == 'true');

      if (storedProfileData && storedProfileData.sections) {
        storedProfileData.sections.forEach(function(section) {
          var $sectionEl =  $('#permissions-detail').find('div.simple-accordion[data-section-api-name="' + section.apiName + '"]');
          for (var i = 0; i < section.permissions.length; i++) {
            var permissionApiName = AlmCommon.htmlEscape(section.permissions[i]);
            $sectionEl.find('input[data-api-name="' + permissionApiName + '"]').prop('checked', true);
          }
          if (section.permissions.length) {
            recalculateSectionSelectAll($sectionEl);
          }
        });
      }

      recalculateSelectedPermissionsCount();

      if (getIncludeEntireProfileEl($profileTile).val() == 'true') {
        selectAllPermissions(true);
        $('#select-all-permissions').prop("checked", true);
      }
    }

    function getProfileData($profileTile) {
      var profileDataString = $profileTile.find("input[id$='selected-permissions']").val(),
        storedProfileData;

      if (profileDataString) {
         try {
           storedProfileData = JSON.parse( profileDataString );
         } catch (syntaxErr) {
           //invalid data format
           return;
         }
       }
      return storedProfileData;
    }

    function initDocumentedPermissionOptions(selectCheckBoxes) {
      var documentedProfileData = JSON.parse($('.saved-panel').attr('data-documented-components')),
          currentProfileInstanceName = $('#permissions-modal').data('instance-name');

      for(var apiName in documentedProfileData) {
        if (documentedProfileData.hasOwnProperty(apiName)) {
          var $section =  $('#permissions-detail').find('div.simple-accordion[data-section-api-name="' + apiName + '"]');
          documentedProfileData[apiName].forEach(function(permissionApiNameAndInstance) {
            var permissionArgList = permissionApiNameAndInstance.split(PROFILE_NAME_INSTANCE_DELIMETER),
                permissionApiName = permissionArgList[0],
                permissionApiInstance = permissionArgList[1];

            // Replace any double quotes with the HTML safe encoded value
            var escapedPermissionApiName = AlmCommon.htmlEscape(permissionApiName);

            if ((config.includeProfilePermissionsFromSourceOnly && permissionApiInstance === currentProfileInstanceName) ||
                 config.includeProfilePermissionsFromSourceOnly === false){
              var $checkbox = $section.find('input[data-api-name="' + escapedPermissionApiName + '"]');
              if (selectCheckBoxes === true) {
                $checkbox.prop('checked', true)
              }
              $checkbox.closest('div').addClass('documented');
            }
          });
          recalculateSectionSelectAll($section);
        }
      }
    }

    function handlePermissionsSelect() {
      var $section = $(this).parents('.profile-section').first(),
        $permissions = $section.find('input.permission');

      checkDocumentedDeselection($(this));

      var checkedPermissions = $permissions.filter(':checked').length;

      var profileSectionAll = $section.find('.profile-section-all').first();

      var isProfileSectionAllChecked = ($permissions.length > 0) ?
        checkedPermissions === $permissions.length :
        !profileSectionAll.prop('checked');
      profileSectionAll.prop('checked', isProfileSectionAllChecked);

      if ($section.hasClass('page-block-panel-section')) {
        handlePermissionsSelect.call($section);
      }
      populateSelectAllCheckbox();
      updateSelectedPermissionsInSectionCount($section);
    }

    function recalculateSectionSelectAll($sectionEl) {
      handlePermissionsSelect.call($sectionEl.find('input.permission:first'));
      //force calculation of select all checkbox in custom subsection
      handlePermissionsSelect.call($sectionEl.find('.select-all-subsection input').last());
    }

    function recalculateSelectedPermissionsCount() {
      $('#permissions-detail').find('div.simple-accordion').each(function() {
        updateSelectedPermissionsInSectionCount($(this));
      });
    }

    function updateSelectedPermissionsInSectionCount($section) {
      var sectionName = $section.data('section-id');
      var $countEl = $('.nav-container').find('li[data-section="' + sectionName + '"] .selection-count');
      var numSelected = $section.find('input.permission:checked').length;

      if (numSelected > 0) {
        $countEl.find('span').text(numSelected);
        $countEl.show();
      } else {
        $countEl.hide();
      }

      $section.find('.page-block-panel-section').each(function() {
        var $subSection = $(this);
        if ($subSection.find('input.permission:checked').length) {
          $subSection.addClass('selected');
        } else {
          $subSection.removeClass('selected');
        }
      });
    }

    /**
     * Checks for any documented components being unchecked. If any are found, then the
     * documented switch will be turned off.
     * @param $elements  - a collection of jQuery wrapped elements
     */
    function checkDocumentedDeselection($elements) {
      if ($('#auto-include-permissions').prop('checked') !== true) {
        return;
      }

      $elements.each(function() {
        if ($(this).prop('checked') === false
              && $(this).closest('.permissions-option').hasClass('documented')) {
          toggleSwitch();
          return false;
        }
      });
    }

    /**
     * populates all permissions checkboxes
     * @param isChecked   {Boolean} The value to set all permissions to
     */
    function selectAllPermissions(isChecked) {
      $("#permissions-detail").find("input.permission, input.profile-section-all")
      .prop("checked", isChecked);
      recalculateSelectedPermissionsCount();
    }

    function populateSelectAllCheckbox() {
      var $allPermissions = $('#permissions-detail').find('input.permission'),
        checkedPermissions = $allPermissions.filter(':checked').length;
      $('#select-all-permissions').prop("checked", checkedPermissions === $allPermissions.length);
    }

    function setHasUnsavedChanges(hasUnsavedChanges) {
      hasUnsavedPermissionChanges = hasUnsavedChanges;
      if (hasUnsavedChanges) {
        $('#profile-apply-btn').removeClass('inactive').prop('disabled', false);
      } else {
        $('#profile-apply-btn').addClass('inactive').prop('disabled', true);
      }
    }

    function toggleSwitch() {
      setHasUnsavedChanges(true);

      var autoIncludePermissions = $("#auto-include-permissions");

      autoIncludePermissions.prop('checked', !autoIncludePermissions.prop('checked'));

      if (autoIncludePermissions.prop('checked') === true) {
        initDocumentedPermissionOptions(true);
        recalculateSelectedPermissionsCount();
      }
    }

    return new ApiBuilder({
      pure: {
        hasUnsavedPermissionChanges: hasUnsavedPermissionChanges,
        init: init,
        config: config,
        closeProfilePermissions : closeProfilePermissions,
        getSelectedData : getSelectedData,
        promptCloseProfilePermissions: promptCloseProfilePermissions,
        LOADED_PROFILE_TEMPLATES: LOADED_PROFILE_TEMPLATES,
        loadProfileModal: loadProfileModal
      },
      testOnly: {
        addEventHandlers : addEventHandlers,
        applyPermissions : applyPermissions,
        displayProfilePermissions : displayProfilePermissions,
        getIncludeOnlyDocumentedInputEl : getIncludeOnlyDocumentedInputEl,
        getIncludeEntireProfileEl : getIncludeEntireProfileEl,
        loadProfileModal : loadProfileModal,
        populateSelectAllCheckbox: populateSelectAllCheckbox,
        setLoadedProfileTemplates : function(instance, template) {
          LOADED_PROFILE_TEMPLATES[instance] = template;
        },
        calculateTargetScrollOffset: calculateTargetScrollOffset
      }
    }).getApi();
  };

  if (typeof define === "function") {
    define([
      'jquery',
      'api_builder',
      'js_alm_common',
      'client_comp_search_results',
      'try!analytics',
      'external/jquery.sticky-kit',
      'external/bootstrap.min'
    ], function($, ApiBuilder, AlmCommon, ComponentSearch, Analytics) {
      var API = init($, ApiBuilder, AlmCommon, ComponentSearch, global.templates, Analytics);
      return API;
    });
  } else {
    var API = init(global.jQuery, global.BW.ApiBuilder, global.BW.AlmCommon, global.ComponentSearch, global.templates, global.BW.Analytics);
    global.BW = global.BW || {};
    global.BW.ProfilesCommon = API;
    return API;
  }
})(this);
