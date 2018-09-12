/*
 * jQuery UI custom select menu for ALM
 *
 * Depends:
 *   - jQuery UI Selectmenu widget
 *
*/
(function() {
    var init = function($) {
        /**
         * Defines a placeholder option
         * */
        $.widget('custom.almSelectMenu', $.ui.selectmenu, {
          _drawButton: function() {
            this._super();

            var selected = this.element.val(),
              placeholder = this.options.placeholder,
              isRequired = this.options.isRequired;

            this.button.addClass('alm-selectmenu');
            this.buttonText = $('span.ui-selectmenu-text');
            
            if (isRequired === true) {
              this.button.addClass('required');
            }

            if (!selected && placeholder) {
              this.buttonText
               .text(placeholder)
               .addClass('placeholder');
            } else {
              this.buttonText.removeClass('placeholder');
            }
          },

          _renderMenu: function( ul, items ) {
            this._super(ul, items);
            ul.addClass('alm-menu-display');
          }

          // TODO: Move setSiblingInputOnChange into this file?
          // setSiblingInputOnChange: function() {
          //   this.change = function(event, ui) {
          //     var value = $(this).val();
          //     $(this).siblings('input').val(value);
          //   }
          // }

        });
    };

    if(typeof define !== 'undefined') {
        define(['jquery', 'jquery-ui'], function(jQuery) {
            init(jQuery);
        });
    } else {
        init(window.jQuery);
    }
})();
