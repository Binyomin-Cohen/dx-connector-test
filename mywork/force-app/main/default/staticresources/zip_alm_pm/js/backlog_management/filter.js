(function() {
  "use strict";
  var init = function($, AlmCommon, ApiBuilder, ComboBox, BacklogUtils, Analytics) {

    function initFilters() {
      AlmCommon.enableTwistyPageBlockPanelSections();

      getFilterInputs().each(function() {
        if ($(this).data('is-picklist') || $(this).data('is-userinput')) {
          ComboBox.init({
            inputSelector: '#'+$(this).attr('id'),
            parentContainer : '.page-block-panel-section-body',
            appendTo : '#backlog-filter-panel',
            selectAction : filterByCriteria
          });
        } else if ($(this).data('is-reference')) {
          ComboBox.init({
            inputSelector: '#'+$(this).attr('id'),
            parentContainer : '.page-block-panel-section-body',
            appendTo : '#backlog-filter-panel',
            selectAction : filterByCriteria,
            lookupAction : lookupReferenceResults
          });
        }
      });

      var slidingTrayOptions = {
        onCompleteHandler : function (tray, trayHandle, handlePosition) {
          var $handle = $(trayHandle);
          if ($handle.hasClass("close")){
            var newWidth = $('#alm-table-panel').width() - 282;
            $('#alm-table-panel, #backlog-table thead.is_stuck').width( newWidth );
          }
        },
        onStartHandler : function(tray, trayHandle, handlePosition){
          var $handle = $(trayHandle);
          if ($handle.hasClass("close")){
            var newWidth = $('#alm-table-panel').width() + 282;
            $('#alm-table-panel, #backlog-table thead.is_stuck').width( newWidth );
          }
        }
      }

      $('#filter-pane-handle').click( function() {
        AlmCommon.toggleSlidingTray("#filter-panel-container", '#filter-pane-handle', "282px", slidingTrayOptions);
      });

      $('#alm-container').on('click', 'a.remove-filter', function() {
        ComboBox.removeSelectedOption($(this), function callback($input) {
          if ($input.data('is-userinput')) {
            $input.data('previous-input', '');
          }
          filterByCriteria();
        });
      });

      $('#alm-container').on('click', "#filtered-items-only", filterByCriteria);

      $('#alm-container').on('click', '#clear-filters', function() {
        $('#filtered-items-only').prop( 'checked', true);
        clearFilterSelections();
      });

      $('#backlog-filter-panel .page-block-panel-section-header').on('click', '.section-close-btn', function() {
          var fieldComboboxContainer = $(this).parents('.page-block-panel-section-header').siblings('.page-block-panel-section-body').find('.combobox-selection');
          clearFilterSelections(fieldComboboxContainer);
      });

    }

    function getFilterInputs(){
      return $("#backlog-filter-panel .page-block-panel-body [id$='-filter']");
    }

    function getCurrentSelectedValues(inputSelector){
      return inputSelector.closest('.alm-combobox').parent().find('.combobox-selection li').map(
              function(index,elem){ return ("" + $(elem).data('val')).toLowerCase() }
      ).toArray();
    }

    function filterByCriteria() {
      Analytics.trackEvent('Backlog', 'Backlog Filter Added');
      var filters = {},
          fuzzyFilters = [];
      var hideNonMatching = $("#filtered-items-only").prop('checked');

      // Create a collection of arrays containing individual filter values for each filter section.
      getFilterInputs().each(function() {
        if ($(this).data('fieldname')) {
          var filterSelections = getCurrentSelectedValues($(this));
          if (filterSelections.length) {
            filters[ $(this).data('fieldname') ] = filterSelections;
            if ($(this).data('is-userinput') || $(this).data('is-reference')){
              fuzzyFilters.push( $(this).data('fieldname') );
            }
          }
        }
      });
      if (!Object.keys(filters).length) {
        // If there are no filters present, remove all matches, show all items, and make the items sortable.
        $('.alm-table tr.prioritized, .alm-table tr.unprioritized').removeClass('filter-match').show();

        if (Number($('#permission-level').val()) === AlmCommon.PERMISSION_LEVEL.FULL) {
          $('#prioritized-section').sortable('enable');
        }
      } else {
        // There are filters present.
        // Determine whether or not the list should be sortable.
        if (hideNonMatching) {
          $('#prioritized-section').sortable('disable');
        } else if (Number($('#permission-level').val()) === AlmCommon.PERMISSION_LEVEL.FULL) {
          $('#prioritized-section').sortable('enable');
        }

        // Check each backlog item to determine whether or not it's a match and if it should be shown.
        $('.alm-table tr.prioritized, .alm-table tr.unprioritized').each(function() {
          var $row = $(this);

          $row.removeClass('filter-match');

          // Check each filter against the current row.
          $.each(filters, function(fieldName) {
            var fieldValue = ("" + $row.find('td.' + fieldName).data('fieldvalue')).toLowerCase();
            if ($.inArray(fieldName, fuzzyFilters) !== -1){
                var fuzzyMatches = $(filters[fieldName]).filter(
                   function(index, userInputValue){
                       return fieldValue.indexOf(userInputValue) !== -1
                   }
                ).toArray();
                if (fuzzyMatches.length > 0){
                  $row.addClass('filter-match');
                }
            } else if ($.inArray(fieldName, fuzzyFilters) === -1 && $.inArray(fieldValue, filters[fieldName]) > -1) {
              $row.addClass('filter-match');
            }
          });

          if (hideNonMatching) {
            $row.hasClass('filter-match') ? $row.show() : $row.hide();
          } else {
            $row.show();
          }
        });
      }

      $('#backlog-table thead th').add('#backlog-filter-panel .page-block-panel-section-header')
      .each(function(index, filterHeader){
        var fieldname = $(filterHeader).data('fieldname') ? $(filterHeader).data('fieldname') : $(filterHeader).data('info');
        if (fieldname){
          if (filters.hasOwnProperty(fieldname)){
            $(filterHeader).addClass('filter-applied');
          } else {
            $(filterHeader).removeClass('filter-applied');
          }
        }
      });

      var firstMatch = $('.alm-table tr.filter-match').first();
      if(firstMatch.length) {
        firstMatch[0].scrollIntoView(false);
      }
      if ($('#filter-pane-handle').hasClass('filter-pane-handle-stuck')){
        $('#filter-panel-container').removeClass('filter-pane-container-stuck');
        $(document.body).trigger("sticky_kit:recalc");
      }
      if (!$('.banner-wrap').hasClass('is_stuck')){
        $('#saving-container').removeClass('saving-container-stuck');
      }
      BacklogUtils.doWindowResize();
    }

    function lookupReferenceResults(inputSelector, isMultiSelect, responseCallback){
      var query = inputSelector.val(),
          fieldname = inputSelector.data('fieldname');
      remoteGetReferenceResults(fieldname, query, function(result, event){
        if (event.status) {
          if (result.length) {
            var currentSelected = getCurrentSelectedValues(inputSelector);
            if (currentSelected.length && !isMultiSelect) {
              responseCallback([]);
            } else {
              responseCallback($.map( result, function(item) { return { label: item, value: item }; })
                                .filter(function(elem, index){ return currentSelected.indexOf(elem.value.toLowerCase()) == -1; }));
            }
            return;
          }
        } else if (event.message){
          AlmCommon.showError( event.message);
        }
        responseCallback([]);
      });
    }

    function clearFilterSelections(container) {
      ComboBox.clearFilterSelections(container);
      getFilterInputs().each(function(){
        var $userinput = $(this);
        if ($userinput.data('is-userinput')){
            $userinput.data('previous-input', '');
        }
      });
      filterByCriteria();
    }

    return new ApiBuilder({
      pure : {
        initFilters : initFilters,
        getCurrentSelectedValues : getCurrentSelectedValues,
        filterByCriteria : filterByCriteria,
        clearFilterSelections : clearFilterSelections,
        getFilterInputs : getFilterInputs
      },
      testOnly : {
        resetFilterByCriteria: function(funct) {
          filterByCriteria = funct;
        }
      }
    }).getApi();

  };

  define([
    'jquery',
    'js_alm_common',
    'combobox',
    'api_builder',
    'backlog_management/utils',
    'try!analytics'
  ], function() {

    var jQuery = arguments[0];
    var AlmCommon = arguments[1];
    var ComboBox = arguments[2];
    var ApiBuilder = arguments[3];
    var BacklogUtils = arguments[4];
    var Analytics = arguments[5];

    return init(jQuery, AlmCommon, ApiBuilder, ComboBox, BacklogUtils, Analytics);
  });
})();