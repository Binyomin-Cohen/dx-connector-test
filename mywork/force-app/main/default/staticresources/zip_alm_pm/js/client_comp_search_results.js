(function(global) {
  var init = function($, AlmCommon) {

    var lineFormatFn = function(id, data) {
      for(var property in data) {
        if(typeof data[property] === 'string') {
          data[property] = AlmCommon.htmlDecode(data[property]);
        }
      }

      var row = $('<tr class="' + (data.disabled ? 'disabled' : '') +'" data-is-deleted="' + data.isDeleted + '"></tr>');
      row.data('comp_id', data.id);
      var checkboxId = 'select-cb-' + data.id;
      // Will either be the unsupported class or blank if type is supported
      var unsupportedTypeClass = data.isUnsupportedType ? 'manual-component' : '';

      var $cb = $('<input ' +
                'class="fancy-checkbox add-cmp-cb ' + unsupportedTypeClass + '" ' +
                'type="checkbox" ' +
                (data.disabled ? 'checked disabled' : '') +
                '/>');

      $cb.attr('id', checkboxId);
      $cb.data('comp_id', data.id);

      row.append(
        $('<td></td>')
        .append($cb)
        .append('<label class="checkbox" for="' + checkboxId + '"><span></span></label>')
      );
      row.append('<td>' + data.instance + '</td>');
      row.append('<td class="' + unsupportedTypeClass + '">' + data.name + '</td>');
      row.append('<td>' + data.type + '</td>');
      row.append('<td>' + data.parentComponent + '</td>');
      row.append('<td>' + data.lastModifiedDate + '</td>');
      row.append('<td>' + data.lastModifiedBy + '</td>');

      return row;
    };

    var setupCustomPagingControls = function (start, end, current, first, last) {
      return $('<li />').html(first + ' - ' + last);
    };

    var API = {
      // List of currently selected components
      selectedComponents: [],

      // List of components added to the backlog item
      addedComponents: [],

      datatableOptions: {
        // tableClass doesn't actually work :(
        //tableClass: 'alm-table',
        identify: 'id',
        pagingDivSelector: '.componentPaging',
        pageSize: 10,
        sort: [true, true, true, true, true, true, true],
        // Disabling filters for now since they don't work
        filters: false,
        sortKey : "sortableLastModifiedDate",
        sortDir: "desc",
        filterText: 'Type to filter...',
        data: [],
        lineFormat: lineFormatFn,
        pagingPages: setupCustomPagingControls,
        nextPage: 'Next >',
        prevPage: '< Previous'
      },

      /**
      * Gets the table instance
      */
      getTable: function() {
        return $('#component-search-table');
      },

      /**
      * Returns true if the table is ready to perform ops on
      * @return {boolean}
      */
      tableReady: function() {
        return this.getTable().data('dtable_init');
      },

      /**
      * Shows loader
      */
      loading: function() {
        AlmCommon.blockUI('#comp-search-res-wrapper');
      },

      /**
      * Hides loader
      */
      doneLoading: function() {
        AlmCommon.unblockUI('#comp-search-res-wrapper');
      },

      /**
      * Selects a component if it doesn't already exist
      * @param {string} id
      */
      selectComponent: function(id) {
        if(this.selectedComponents.indexOf(id) < 0) {
          this.selectedComponents.push(id);
        }
      },

      /**
      * Selects an array of component IDs
      * @param [] ids
      */
      selectComponents: function(ids) {
        if(!ids || !ids.length) {
          return;
        }
        ids.forEach(this.selectComponent.bind(this));
      },

      /**
      * Removes a component from selected array based on ID
      * @param {string} id
      */
      deselectComponent: function(id) {
        var idx = this.selectedComponents.indexOf(id);
        if(idx > -1) {
          return this.selectedComponents.splice(idx, 1)[0];
        }
        return null;
      },

      /**
      * Adds a component if it doesn't already exist
      * @param {string} id
      */
      addComponent: function(id) {
        if(this.addedComponents.indexOf(id) < 0) {
          this.addedComponents.push(id);
        }
      },

      /**
      * Adds an array of component IDs
      * @param [] ids
      */
      addComponents: function(ids) {
        if(!ids || !ids.length) {
          return;
        }
        ids.forEach(this.addComponent.bind(this));
      },

      /**
      * Removes a component from added components array based on ID
      * @param {string} id
      */
      removeComponent: function(id) {
        var idx = this.addedComponents.indexOf(id);
        if(idx > -1) {
          this.addedComponents.splice(idx, 1)[0];
          this.toggleRows([id], false);
        }
        return null;
      },

      /**
      * Removes a list of components from the added components array based on the component id or key
      * @param {array} ids
      */
      removeComponents: function(ids) {
        if(!ids || !ids.length) {
          return;
        }
        for (var k = 0; k < ids.length; k++) {
          var idx = this.addedComponents.indexOf(ids[k]);
          if(idx > -1) {
            this.addedComponents.splice(idx, 1);
          }
        }

        this.toggleRows(ids, false);
      },

      /**
      * Adds all currently selected components and disables them from search table
      */
      addAllSelectedComponents: function() {
        if(this.selectedComponents.length === 0) {
          return;
        }

        this.addComponents(this.selectedComponents);
        this.toggleRows(this.selectedComponents, true);
        this.clearSelectedComponents();
      },

      /**
      * Toggles the current rows "disabled" status based on disabled param
      * @param [{string}]
      * @param {bool} disabled
      */
      toggleRows: function(ids, disabled) {
        if(!ids || !ids.length || !this.tableReady()) {
          return;
        }

        disabled = (typeof disabled === 'undefined' ? false : disabled);
        var $table = this.getTable();
        // For some reason the table jumps to the middle page
        // on update so here we store the current page and restore
        // it to that page after update.
        var currPage = $table.datatable('page');

        if ($table.datatable('select').length == 0) {
          return;
        }

        var rowData = [];
        var rows = $table.datatable('select', function(data) {
          return ids.indexOf(data.id) > -1;
        }.bind(this));

        rows.forEach(function(row) {
          row.disabled = disabled;
          rowData.push([row.id, row]);
        });

        $table.datatable('updateAll', rowData);

        $table.datatable('page', currPage);
      },

      /**
      * Clears the selected Array
      */
      clearSelectedComponents: function() {
        this.selectedComponents = [];
      },

      /**
      * Clears all added components
      */
      clearAddedComponents: function() {
        this.addedComponents = [];
      },

      /**
      * Returns a comma delimited string of all selected IDs
      * @return {string}
      */
      getSelectedComponentsString: function() {
        return this.selectedComponents.join(',');
      },

      /**
      * Returns a comma delimited string of all selected IDs
      * @return {string}
      */
      getAddedComponentsString: function() {
        return this.addedComponents.join(',');
      },

      /**
      * Returns number of records in context
      */
      getRecordCount: function() {
        return this.datatableOptions.data.length;
      },

      /**
      * Returns TRUE if there are selected components that are unsupported
      */
      containsUnsupportedSelectedComponents: function() {
        // Query for any non disabled rows that contain selected components with "manual-component" class
        return $(
          '#comp-search-res-wrapper #component-search-table tr:not(.disabled) input.manual-component:checked'
        ).length > 0
      },

      /**
      * Performs search and updates ui with results
      * @param searchParams
      * @param searchParams.name
      * @param searchParams.type
      * @param searchParams.parentComponent
      * @param searchParams.instances
      * @param searchParams.includeDeleted
      * @param searchParams.selectedComps
      * @param searchParams.selectedUsers
      * @param {String} [blockUI] selector of an element to block while searching
      */
      doSearch : function(searchParams, blockUI) {
        if(blockUI !== undefined) {
          AlmCommon.blockUI(blockUI);
        }

        this.getComponents(searchParams, function(err, resultObj) {
          this.renderSearchResults(err, resultObj, blockUI);
        }.bind(this));
      },

      /**
      * Display the search results from the resultObj
      * @param err    an error string
      * @param resultObj  the search results
      */
      renderSearchResults: function(err, resultObj, blockUI) {
        if (err) {
          AlmCommon.showError(err);
          return;
        }

        var locale = $('#user-locale').val().replace('_', '-');
        var formatOptions = {
          format: 'l LT',
          timeZone: $('#user-timezone').val()
        };

        var recordCountText = resultObj.results.length;
        if(resultObj.hasMore) {
          recordCountText += '+';
        }

        // Update number of records
        $('#total-num-records').text(recordCountText);

        // Update page record count
        $('#pagesize-count').text(recordCountText);

        var tableData = resultObj.results.map(function(row) {
          var modifiedDate = row.lastModifiedDate ?
            AlmCommon.formatDateTime(row.lastModifiedDate, locale, formatOptions)
              : 'Not Available';

          var parentComponentRec = AlmCommon.getSObjValue(row.component, 'Parent_Component__r') || {};
          var componentName = (AlmCommon.getSObjValue(row.component, 'Full_Name__c') == '') ? AlmCommon.getSObjValue(row.component, 'Name') : AlmCommon.getSObjValue(row.component, 'Full_Name__c');
          return {
              id: row.key,
              disabled: row.checked,
              instance: row.environment,
              name: componentName,
              type: AlmCommon.getSObjValue(row.component, 'Type__c'),
              parentComponent: AlmCommon.getSObjValue(parentComponentRec, 'Name'),
              lastModifiedDate: modifiedDate,
              sortableLastModifiedDate: row.lastModifiedDate === undefined ? '' : row.lastModifiedDate + '',
              lastModifiedBy: row.lastModifiedBy ? row.lastModifiedBy : 'Not Available',
              isUnsupportedType: row.isUnsupportedType,
              isDeleted: row.isDeleted
          };
        });

        var cb = (blockUI !== undefined) ? AlmCommon.unblockUI.bind(AlmCommon.compdoc, blockUI) : null;

        this.refreshDataTable(
          tableData,
          cb
        );
      },

      getComponents: function(searchParams, cb) {
        cb = cb || function() {};

        //TODO: replace null param with selected users
        Visualforce.remoting.Manager.invokeAction(
          $('#comp-search-res-wrapper').data('bklg-items-remote-action'),
          searchParams.name, searchParams.type, searchParams.parentComponent, searchParams.instances, searchParams.selectedComps, searchParams.selectedUsers,
          function(result, event) {
            if (event.status) {
              cb(null, result);
              this.clearSelectedComponents();
            } else if (event.message) {
              cb(event.message);
            } else {
              cb('An unknown exception occurred in VF Remote call.');
            }
          }.bind(this), {
            escape: true,
            timeout: 120000
          }
        );
      },

      setPageSize: function(size, cb) {
        cb = cb || function() {};
        this.datatableOptions.pageSize = size;
        this.refreshDataTable(null, cb);
      },

      refreshDataTable: function(data, onComplete) {
        var $table = this.getTable();

        if($table.data('dtable_init') === true) {
          $table.datatable('destroy');
          // Add in table class since it is destroyed
          $table.addClass('alm-table');
        }

        this.datatableOptions.data = data || this.datatableOptions.data;
        $table.datatable(this.datatableOptions);

        // Set to true in order for init ops to only
        // occur once
        $table.data('dtable_init', true);

        if(typeof onComplete === 'function') {
          onComplete();
        }
      },

      lineFormatFn : lineFormatFn
    };

    // Init default handlers
    $(function initHandlers() {
      var savedPageSize = $('.selected-page-size').data('page-size');
      API.setPageSize(savedPageSize);
      $('.selected-page-size').val(savedPageSize);

      $('.selected-page-size').change(function() {
        API.loading();
        var pageSize = parseInt($(this).val(), 10);
        API.setPageSize(pageSize, function() {
          API.doneLoading();
        });

        AlmCommon.clearMsgs();

        remoteUpdateUserPreferences(pageSize, function(result, event){
          if (!event.status && event.message) {
            AlmCommon.showError(event.message, {clearPriorMessages : true});
          }
        });

      });

      $('#alm-container').on('click', '#component-search-table .add-cmp-cb', function() {
        if(this.checked) {
          API.selectComponent($(this).data('comp_id'));
        } else {
          API.deselectComponent($(this).data('comp_id'));
        }
      });

      $( "#alm-container" ).on( "click", "#component-search-table .select-all-checkbox", function() {
          // Get all non-disabled checkboxes
          var $cbList = $( "#component-search-table input.add-cmp-cb:not([disabled])");

          if ( $(this).prop( "checked" ) ) {
              $('.add-btn').prop("disabled", false).removeClass('inactive');
              $cbList.each(function() {
                  this.checked = true;
                  API.selectComponent($(this).data('comp_id'));
              });
          }
          else {
              $('.add-btn').prop("disabled", true).addClass('inactive');
              $cbList.each(function() {
                  this.checked = false;
                  API.deselectComponent($(this).data('comp_id'));
              });
          }
      });
    });

    return API;
  };

  if(typeof define !== 'undefined') {
    define(['jquery', 'jquery-datatable', 'js_alm_common'], function($) {
      var AlmCommon = arguments[2];
      var ApiBuilder = arguments[3];
      return init($, AlmCommon);
    });
  } else {
    global.BW = global.BW || {};
    global.BW.ComponentSearch = init(global.jQuery, global.BW.AlmCommon);
  }
})(this);