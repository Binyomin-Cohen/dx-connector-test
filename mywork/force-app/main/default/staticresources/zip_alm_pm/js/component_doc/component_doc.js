
(function (global) {
  "use strict";
  var init = function ($, AlmCommon, ComponentSearch, ApiBuilder, Profiles, /*DatePicker,*/ Filters) {

    $(function() {
      init();
    });

    function init() {
      $('.banner-wrap').stick_in_parent( {
        parent: $('#alm-container'),
        bottoming : false
      });

      $('.multiselect').multiselect();
      $( "#search-form" ).on( "keypress", "input", function(evt) {
        AlmCommon.performActionOnEnter( $(this), evt, function() {
          componentSearch();
        });
      });

      $('.search-btn').click(componentSearch);

      $( "#alm-container" ).on( "click", ".save-btn", function() {
        blockUI();
        AlmCommon.setHasUnsavedChanges(false);
      });

      $( "#component-search-table" ).on( "click", ".add-cmp-cb", function() {
        var checkedRows = $( "#component-search-table input.add-cmp-cb:checked:not([disabled])" ).length;

        if ( checkedRows > 0 ) {
          $('.add-btn').prop("disabled", false).removeClass('inactive');
        }
        else {
          $('.add-btn').prop("disabled", true).addClass('inactive');
        }
      });

      $( "#alm-container" ).on( "click", ".selected-checkbox", function() {
        var checkedRows = $( ".saved-panel input.selected-checkbox:checked" ).length;

        if ( checkedRows > 0 ) {
          $('.delete-btn').prop("disabled", false).removeClass('inactive');
        }
        else {
          $('.delete-btn').prop("disabled", true).addClass('inactive');
        }
      });

      $( "#alm-container" ).on( "click", ".sort-action", function() {
        blockUI( "div[id$='search-results-panel']" );
        sortComponents($(this).data('sort-col'));
      });

      $( "#alm-container" ).on( "click", "#selectAllCheckboxDelete", function() {
        if ( $(this).prop( "checked" ) ) {
          $( ".saved-panel input.selected-checkbox").prop( "checked", true );
        }
        else {
          $( ".saved-panel input.selected-checkbox").prop( "checked", false );
          $('.delete-btn').prop("disabled", true).addClass('inactive');
        }
      });

      $( "#alm-container" ).on( "click", ".component-note", editNotes);


      $( document ).on( "click", ".cancel-btn", function() {
        if (AlmCommon.getHasUnsavedChanges()) {
          displayModal( $("#cancel-modal") );
        } else {
          cancel();
        }
      });

      $( document ).on( "click", ".delete-btn", function() {
        AlmCommon.setHasUnsavedChanges(true);
        blockUI();

        // Clear all selected components
        $(this).siblings('.saved-panel').find('.selected-checkbox').each(function() {
          if(this.checked) {
            ComponentSearch.removeComponent($(this).data('comp_id'));
          }
        });
      });

      $( document ).on( "click", "#notes-modal .apply", function() {
        var noteValue = $('#note-value').val(),
         noteDisplay = truncate(noteValue),
         noteId = $('#note-name').data('currentRowId'),
         noteCell = $(AlmCommon.escapeId('#' + noteId));

        AlmCommon.setHasUnsavedChanges(true);
        noteCell.find("[id$='component-note-value']").val(noteValue);
        noteCell.find("[id$='component-note-display-input']").val( noteDisplay );
        noteCell.find("[id$='component-note-display']")
        .text( noteDisplay )
        .attr('data-original-title', noteValue);
        $.unblockUI();
      });

      $( document ).on( "click", "#cancel-modal .close-no-save-btn", function(e) {
        AlmCommon.setHasUnsavedChanges(false);
        cancel();
      });

      $( document ).on( "click", "#cancel-modal .continue-btn", function(e) {
        $.unblockUI();
      });

      $( document ).on( "click", "#notes-modal .close-modal-btn", $.unblockUI );

      $.blockUI.defaults.overlayCSS.opacity = .5;
      initTooltips();
      Profiles.init();

      AlmCommon.addBeforeUnloadEventListener();

      var runTimesInput = $('input[name$=runTimes]');
      var runTimes = !AlmCommon.isNullOrUndefined(runTimesInput[0]) ? JSON.parse(runTimesInput.val()) : {};
      $('.dropdown-menu a').each(function () {
        var $labelElement = $(this).find('.checkbox');

        // Add a div before the label tag
        $labelElement.before("<div class='border-padding'>");

        // Add the label tag as a child of the div we just created
        $(this).find('.border-padding').append($labelElement);

        var instanceName = $labelElement.text().trim();
        var date = runTimes[instanceName] || 'NEVER';
        $(this).append('<span>last <span class="tool-name">SCAN</span>: <span class="date">'+date+'</span></span>');
      });

      $('#banner-sub-menu .action.search').click(function() {
        //call animate on both html and body to work cross browser
        $('html, body').animate({
          scrollTop: $('#alm-container').offset().top - 1
        });
      });

      var addComponents = function() {
        // Check to see if any components have been checked
        if(ComponentSearch.selectedComponents.length === 0 || !validate()) {
          return;
        }

        AlmCommon.setHasUnsavedChanges(true);
        blockUI('[id$=search-results-panel]');
        addSelectedComponents(ComponentSearch.getSelectedComponentsString());
        ComponentSearch.addAllSelectedComponents();
        // uncheck select all if it was checked
        $('.select-all-checkbox').prop('checked', false);

        // Disable me
        $(this).prop('disabled', true).addClass('inactive');
      }
      $('.add-btn').click(addComponents);

      Filters.init();


      var pageInit = function() {
        var existing = $('#init-selected-comps').val();
        if(existing != 'null' && !AlmCommon.isNullOrUndefined(existing)) {
          ComponentSearch.addComponents(existing.split(','));
        }
        ComponentSearch.doSearch({
          name: null,
          type: null,
          parentComponent: null,
          instances: null,
          includeDeleted: false,
          selectedComps: ComponentSearch.getAddedComponentsString(),
          selectedUsers: null
        },
        '[id$=search-results-panel]'
        );
      };
      $(document).ready(pageInit);
    }



    //performSearch();
    function componentSearch(blockUI) {
      var $parent = $('.page-block-content-component-search');
      var searchParams = {};

      searchParams.name = $parent.find('.name').val() || null;
      searchParams.type = $parent.find('.ctype').val() || null;
      searchParams.parentComponent = $parent.find('.parent-name').val() || null;
      searchParams.selectedComps = ComponentSearch.getAddedComponentsString();
      searchParams.selectedUsers = $("#last-modified-by-section")
        .find('.combobox-selection li')
        .map(function() {
          return $(this).data('val');
         })
         .toArray();

      // Check for any selected instances
      var selectedInstances = [];

      $('.dropdown-menu li').each(function () {
        if ($(this).hasClass('active')) {
          selectedInstances.push($(this).find('.checkbox').text().trim());
        }
      });

      searchParams.instances = selectedInstances.length > 0 ? selectedInstances.join(',') : null;

      ComponentSearch.doSearch(searchParams, '[id$=search-results-panel]');
    };

    function editNotes() {
        var row = $(this).closest('tr');
        var componentName = row.find('.component-name span').text();

        var currentNoteId = row.find('.component-note').prop('id');
        $('#note-value').val( row.find("[id$='component-note-value']").val() );
        $('#note-name').text( componentName ).data('currentRowId', currentNoteId);
        displayModal( $("#notes-modal"), '60%' );
    }

    function displayModal($modalContent, modalWidth) {
        $.blockUI({ message: $modalContent,
            css: { cursor: 'auto',
                width: modalWidth,
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

    function initTooltips() {
      $('.added-components td span').tooltip();
    }

    function performSearch() {
        var $input = $('input[name$=selectedInstances]');
        var selectedInstances = [];
        $('.dropdown-menu li').each(function () {
            if ($(this).hasClass('active')) {
                selectedInstances.push($(this).find('.checkbox').text().trim());
            }
        });
        $input.val(selectedInstances.join());

        search();
        blockUI( "div[id$='search-results-panel']" );
    }

    function validate() {
        if (ComponentSearch.containsUnsupportedSelectedComponents()) {
            var message = 'At least one component selected is a manual deployment.\nPlease be sure to add any additional information in the Notes field that is relevant.\n\n';
            message += 'Click OK to add the components as is or click Cancel to go back and add additional notes.';

            var result = confirm(message);
            return result;
        } else {
            return true;
        }
    }

    function truncate(s) {
        return (s && s.length > 26) ? s.substring(0, 26) +  "..." : s;
    }

    function blockUI( selector ) {
        var options = {
            message: "<div id='block-ui'><img src='/s.gif' /></div>",
            css: { border: 'none', background: 'none' }
        };
        if(selector) {
            $(selector).block( options );
        }
        else {
            $.blockUI( options );
        }
    }

    function unblockUI( selector ) {
        if(selector) {
            $(selector).unblock();
        }
        else {
            $.unblockUI();
        }
    }

    return new ApiBuilder({
      pure: {
        validate : validate,
        blockUI : blockUI,
        initTooltips : initTooltips,
        unblockUI : unblockUI
      },
      testOnly: {
      }
    }).getApi();
  }; // end init


  if (typeof define === "function" && define.amd) {
    define([
     'jquery',
     'jquery-ui',
     'jquery-blockUI',
     'js_alm_common',
     'client_comp_search_results',
     'external/bootstrap.min',
     'external/bootstrap_multiselect',
     'api_builder',
     'component_doc/profiles',
  //   'component_doc/date_picker',
     'external/jquery.sticky-kit',
     'component_doc/filter'
    ], function() {
      var jQuery = arguments[0];
      var AlmCommon = arguments[3];
      var ComponentSearch = arguments[4];
      var ApiBuilder = arguments[7];
      var Profiles = arguments[8];
  //    var DatePicker = arguments[9];
      var Filters = arguments[10];
      var API = init(jQuery, AlmCommon, ComponentSearch, ApiBuilder, Profiles, /*DatePicker,*/ Filters);
      window.BW = window.BW || {};
      window.BW.compdoc = API;

      return API;
    });
  } else {
    var api = init(global.jQuery, global.BW.AlmCommon, global.ComponentSearch, global.BW.ApiBuilder, global.Profiles, /*DatePicker,*/ global.Filters);

    global.BW.compdoc = api;
  }
})(this);