(function(global) {
  var init = function($, ApiBuilder, AlmCommon, ComboBox) {

    function init() {
      initTypeBox();
      initLastModifiedByFilter();
      initComboboxBehavior();
      AlmCommon.enableTwistyPageBlockPanelSections();
    }

    /**
     * Adds common behavior for all comboboxes on the page
     */
    function initComboboxBehavior() {
      $("#alm-container").on("keyup", ".ui-autocomplete-input", function() {
        // Set a data attribute on the input field as the user types
        // This is so that we can keep showing what they have typed
        // when the user mouses over the matching entries
        setTypeInputDataAttribute($(this));
      });

      $("#alm-container").on("keydown", ".ui-autocomplete-input", function(event) {
        restoreTypeInputOnArrowNavigation(event, $(this));
      });

      $("#alm-container").on( "mouseover", ".ui-menu-item", function() {
        // Display what the user has typed by reading in the data attribute
        $("#ctype").val($("#ctype").data("typed-value"));
        $("#last-modified-by").val($("#last-modified-by").data("typed-value"));
      });

      $("#alm-container").on("focus", ".ui-autocomplete-input", function() {
        $(this).select();
      });

      $("#alm-container").on("click", ".search-btn", function collapseOpenMultiselects() {
        $('#search-container')
          .find('.page-block-panel-section.expanded .section-title')
          .trigger('click');
      })
    }

    function initLastModifiedByFilter() {
      ComboBox.init({
        inputSelector : "#last-modified-by",
        parentContainer : '#last-modified-by-section .page-block-panel-section-body',
        appendTo : '#last-modified-by-section .page-block-panel-section-body',
        isMultiSelect : true,
        selectAction : function() {
          setFilterAppliedState();
          setTypeInputDataAttribute($("#last-modified-by"));
        }
      });

      $('#alm-container').on('click', 'a.remove-filter', function() {
        ComboBox.removeSelectedOption($(this), function callback($input) {
          setFilterAppliedState()
        });
      });

      $('#last-modified-by-section').on('click', '.section-close-btn', function() {
        ComboBox.clearFilterSelections( $("#last-modified-by-section").find('.combobox-selection') );
        setFilterAppliedState();
      });

      $(window).on("resize", function() {
        resetLastModifiedWidth();
      });
    }

    function setFilterAppliedState() {
      var $section = $("#last-modified-by-section"),
       $header = $section.find('.page-block-panel-section-header'),
       $title = $header.find('.section-title span'),
       selectedCount = $section.find('ul.combobox-selection li').length;

      if (selectedCount) {
        var plural = selectedCount > 1 ? 's' : '';
        $title.text(selectedCount + ' value' + plural);
        $header.addClass('filter-applied');
      } else {
        $title.text($title.data('title'));
        $header.removeClass('filter-applied');
      }
    }

    function resetLastModifiedWidth() {
      //set the width since the section is positioned absolutely and needs a dynamic width
      var $section = $("#last-modified-by-section");
      var width = $section.find('.alm-settings-label').width();
      $section.find('.page-block-panel-section').css("width", width);
    }

    /**
     * Initializes the type input box.
     */
     function initTypeBox() {
       ComboBox.init({
         inputSelector : "#ctype",
         parentContainer : '#search-container',
         appendTo : '#search-container',
         isMultiSelect : false,
         selectAction : function() {
           setTypeInputDataAttribute($("#ctype"));
         }
       });
     }

     /**
     * Preserve the type input when the user navigates through the auto-complete results with the up/down arrow keys.
     * @param event - An event captured by an event handler.
     */
     function restoreTypeInputOnArrowNavigation(event, $target) {
       AlmCommon.performActionOnArrowKeyPress({
         $el: $target,
         evt: event,
         keys: [
           AlmCommon.KEYSTRING_ARROWUP,
           AlmCommon.KEYSTRING_ARROWDOWN
         ],
         callback: function() {
           $target.val($target.data('typed-value'));
         }
       });
     }

     function setTypeInputDataAttribute($el) {
       $el.data("typed-value", $el.val());
     }

    return new ApiBuilder({
      pure: {
        init: init
      },
      testOnly: {
        initTypeBox : initTypeBox
      }
    }).getApi();
  };
  if (typeof define === "function") {
    define([
      'jquery',
      'api_builder',
      'js_alm_common',
      'combobox',
    ], function($, ApiBuilder, AlmCommon, ComboBox) {
      var API = init($, ApiBuilder, AlmCommon, ComboBox);
      return API;
    });
  }
  else{
    var BW = BW || {};
    var API = init(global.jQuery, global.BW.ApiBuilder, global.BW.AlmCommon, global.BW.ComboBox);
    global.BW.filter = API;
  }
})(this);
