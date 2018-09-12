/**
 * ALM Combobox
 *
 * Depends
 *   - depends on almautocomplete
 */
(function(global) {
  var init = function ($) {
    "use strict";

    /**
    * Initialize a combobox
    * @param {object} configuration
    * @param {string} configuration.inputSelector - selector for the input field to initialize
    * @param {string} configuration.parentContainer- selector for the parent container for the combobox
    * @param {string} configuration.appendTo - selector for the element to append the comboxbox to
    * @param {Boolean} configuration.isMultiSelect (optional) - indicates if this combobox supports multiple item selection. Defaults to true.
    * @param {function} configuration.selectAction - action to invoke upon selection
    * @param {function} configuration.lookupAction - action to invoke upon source lookup. Function should accept inputSelector, isMultiSelect, responseCallback
    *
    * @return the jquery wrapped input for the combobox
    */
    function init( configuration ) {

      var inputSelector = configuration.inputSelector ? configuration.inputSelector : undefined,
          parentContainer = configuration.parentContainer ? configuration.parentContainer : undefined,
          appendTo = configuration.appendTo ? configuration.appendTo : undefined,
          isMultiSelect = configuration.isMultiSelect !== undefined ? configuration.isMultiSelect : true,
          selectAction = configuration.selectAction ? configuration.selectAction : undefined,
          lookupAction = configuration.lookupAction ? configuration.lookupAction : undefined;

      var $input = $( inputSelector ),
       $comboBox = $input.closest('.alm-combobox'),
       isRemoteSource = Object.prototype.toString.call(lookupAction) == "[object Function]";

      // Autocomplete ComboBox
      $input.almautocomplete({
        minLength: 0,
        select: function( event, ui ) {
          if (isMultiSelect) {
            $(this).val('');
            addSelection(  $(this).closest( parentContainer ), ui.item.label, ui.item.value );
          } else {
            $(this).val( ui.item.label );
          };
          setTypeInputDataAttribute($input, ui.item.label);
          if ( selectAction !== undefined) {
            selectAction(ui.item.value);
          }
          if (!isRemoteSource) {
            setSource($input, isMultiSelect);
          }
          event.preventDefault();
        },

        appendTo: appendTo,

        focus: function( event, ui ) {
          event.preventDefault();
        }
      })
      .on('focus',function() {
        // Fix jQuery memory leak: https://bugs.jqueryui.com/ticket/10050
        var $input = $(this);
        $input.data().customAlmautocomplete.menu.bindings = $()
        $input.almautocomplete( "search", $(this).val() );
      });

      if (isRemoteSource){
        setRemoteSource($input, isMultiSelect, lookupAction);
      } else {
        setSource($input, isMultiSelect);
      }

      function applyUserInput(event) {
        var currentUserInput = $input.val(),
           currentSelected = $input.closest('.alm-combobox').parent().find('.combobox-selection li').map(
               function(index,elem){return "" + $(elem).data('val')}
           ).toArray();

        if ( !currentUserInput ||
             currentUserInput == $input.data('previous-input') ||
             currentSelected.indexOf(currentUserInput) != -1)
        {
            return;
        }

        $input.data('previous-input', currentUserInput);
        if (isMultiSelect) {
              addSelection($input.closest(parentContainer), currentUserInput, currentUserInput);
              $input.val('');
        } else {
              $(this).val(currentUserInput);
        }
        if (selectAction !== undefined) {
              selectAction();
        }

        if (event && event.preventDefault) {
          event.preventDefault();
        }

        $input.focus();
      }

      if ($input.data('is-userinput') || $input.data('is-reference')){
        $comboBox.find('.apply-input').on('click', applyUserInput);
        $input.on('keypress', function(e){
          BW.AlmCommon.performActionOnEnter($input, e, applyUserInput);
        });
      }

      enableExpander($comboBox.find('.expander'), $input);
      return $input;
    }

    function enableExpander($expanderEl, $inputEl) {
      $expanderEl.off('click').on('click', function() {
        $inputEl.almautocomplete( "search", "" );
        $inputEl.focus();
      });
    }

    function disableExpander($expanderEl){
      $expanderEl.off('click');
    }

    function initComboboxBehavior($input, $inputAppendToContainer) {
      $input.on("keyup", function() {
        // Set a data attribute on the input field as the user types
        // This is so that we can keep showing what they have typed
        // when the user mouses over the matching entries
        setTypeInputDataAttribute($input);
      });

      $input.on("keydown", function(event) {
        restoreTypeInputOnArrowNavigation(event, $input);
      });

      $inputAppendToContainer.on( "mouseover", ".ui-menu-item", function(event) {
        // Display what the user has typed by reading in the data attribute
        $input.val($input.data("typed-value"));
      });

      $input.on("focus", function() {
        $input.select();
      });

    }

    /**
     * Preserve the type input when the user navigates through the auto-complete results with the up/down arrow keys.
     * @param event - An event captured by an event handler.
     */
     function restoreTypeInputOnArrowNavigation(event, $target) {
       BW.AlmCommon.performActionOnArrowKeyPress({
         $el: $target,
         evt: event,
         keys: [
           BW.AlmCommon.KEYSTRING_ARROWUP,
           BW.AlmCommon.KEYSTRING_ARROWDOWN
         ],
         callback: function() {
           $target.val($target.data('typed-value'));
         }
       });
     }

     function setTypeInputDataAttribute($el, valueToUse) {
       valueToUse = valueToUse || $el.val();
       $el.data("typed-value", valueToUse);
     }

    function addSelection( $filterPanel, label, value ) {
      var filterTemplate = '<li data-val="$2">$1<a class="remove-filter"><img src="/s.gif"></img></a></li>';
      var filter = filterTemplate.replace('$1', label).replace('$2',value);
      $filterPanel.find('ul.combobox-selection').append( filter );
      $filterPanel.find('select option[value="'+ value +'"]').prop("selected",true);
    }

    /**
     * Clears all selected items for multi select containers
     * @param $container        the combobox selection container
     */
    function clearFilterSelections($container) {
      if (!$container) {
        $container = $('.combobox-selection');
      }
      $container.empty();
      var $containerCombobox = $container.siblings('.alm-combobox');
      $containerCombobox
        .find('.filter-values option')
        .filter(':selected')
        .prop("selected", false);
      var $input = $containerCombobox.children('.ui-autocomplete-input');
      $input.data('previous-input', '');
    }

    /**
     * Set the source for the combobox based on the input selector
     * @param {String}    Selector for the input field to turn into a combobox. The source will be pulled from the closest
     *                  select option list
     * @param {Boolean} isMultiSelect (optional) - indicates if this combobox supports multiple item selection. Defaults to true.
     * @param {Function} sourceCallback - function to call on source lookup
     */
    function setRemoteSource(inputSelector, isMultiSelect, sourceCallback) {
        inputSelector.almautocomplete( "option", "minLength", 3);
        inputSelector.almautocomplete( "option", "source", function( request, response, url ){
            sourceCallback(inputSelector, isMultiSelect, response);
       });
    }

    /**
     * Set the source for the combobox based on the input selector
     * @param {String}    Selector for the input field to turn into a combobox. The source will be pulled from the closest
     *                  select option list
     * @param {Boolean} isMultiSelect (optional) - indicates if this combobox supports multiple item selection. Defaults to true.
     */
    function setSource(inputSelector, isMultiSelect) {
      inputSelector.almautocomplete( "option", "source", function( request, response, url ) {
          var $input = $( inputSelector ),
           $comboBox = $input.closest('.alm-combobox'),
           sourceValues = [],
           options = $comboBox.find( '.filter-values option');

          isMultiSelect = (isMultiSelect === undefined) ? true : isMultiSelect;

          if (isMultiSelect) {
            options = options.not(':selected');
          }
          options.filter(function(index, elem ){ return $(elem).text().toLowerCase().indexOf(request.term.toLowerCase()) != -1; }).each(function() {
            sourceValues.push( {label : $(this).text(), value :$(this).val()});
          });
          response(sourceValues);
      });
    }

    /**
     * Event handler to remove the selected option
     * @param {JQuery} the element that was clicked for removal
     * @param {Function}[callback] callback function
     * @param {JQuery} callback.$input  the autocomplete input element
     */
    function removeSelectedOption($target, callback) {
      var $tag = $target.closest('li'),
        value = $tag.data('val'),
        $filterPanel = $tag.closest('.page-block-panel-section-body'),
        $input = $filterPanel.find('.ui-autocomplete-input');
      $input.data('previous-input', '');
      $tag.remove();
      $filterPanel.find('select option[value="'+ value +'"]').prop("selected", false);

      callback($input);
    }

    var api = {
      init : init,
      initComboboxBehavior : initComboboxBehavior,
      clearFilterSelections: clearFilterSelections,
      removeSelectedOption : removeSelectedOption,
      enableExpander : enableExpander,
      disableExpander : disableExpander,
      setSource : setSource
    };

    return api;
   }; // End init()

   if(typeof define !== 'undefined') {
    define(['jquery', 'alm_autocomplete'], function(jQuery) {
      return init(jQuery);
    });
   } else {
    global.BW = global.BW || {};
    global.BW.ComboBox = init(global.jQuery);
   }
})(this);
