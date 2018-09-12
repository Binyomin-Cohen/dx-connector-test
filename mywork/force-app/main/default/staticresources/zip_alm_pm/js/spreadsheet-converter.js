(function() {

  var init = function($, ApiBuilder, XLSX) {

    var ACCEPTED_FILE_EXTS = ['xls', 'xlsx', 'csv'];
    var EXCEL_TYPES = ['xls', 'xlsx'];
    var BLANK_ROW_SKIP_THRESHOLD = 5;
    var handlers = {
      onInvalidExtension: function() {},
      onFinish: function() {}
    };

    function process(fileNameExt, options, uploadData, handlers) {
      if (! $.isEmptyObject(handlers) ) {
        this.handlers = handlers;
      }
      if (! $.isEmptyObject(options) ) {
        BLANK_ROW_SKIP_THRESHOLD = options.BLANK_ROW_SKIP_THRESHOLD;
      }

      if (!fileHasValidExtension(fileNameExt)) {
        handlers.onInvalidExtension(fileNameExt);
      } else {
        convertUploadDataToArray(uploadData, fileNameExt, function(errors, arr) {
          prepArrayForImport(arr, function(errors, arr) {
            handlers.onFinish(errors, arr);
          });
        });
      }
    };

    function convertUploadDataToArray(uploadData, fileNameExt, fn) {
      convertArrayBufferToString(uploadData, function(errors, str) {
        if (fileIsExcelType(fileNameExt)) {
          convertBinaryStringExcelTypeToCsv(str, function(errors, csv) {
            if (errors) {
              console.log('errors encountered while converting binary string!', errors);
            } else {
              $.csv.toArrays(csv, function(errors, arr) {
                fn(null, arr);
              });
            }
          });
        } else if (fileNameExt === 'csv') {
          fn(null, $.csv.toArrays(str));
        } else {
          fn('invalid extension', uploadData);
        }
      });
    };

    function convertArrayBufferToString(buffer, fn) {
      var dataArray = new Uint8Array(buffer),
          bufferConvertedToString = '';
      for(var i = 0; i < dataArray.length; i++) {
        bufferConvertedToString += String.fromCharCode(dataArray[i]);
      }
      fn(null, bufferConvertedToString);
    };

    function prepArrayForImport (arr, fn) {
      removeEmptyTrailingRows(arr, function(errors, arr) {
        removeColumnsWithEmptyHeaders(arr, function(errors, arr) {
          fn(errors, arr);
        });
      });
    };

    function convertBinaryStringExcelTypeToCsv (bstr, fn) {
      try {
        var workbook = XLSX.read(bstr, {type:"binary"});
        var firstSheet = workbook.Sheets[workbook.SheetNames[0]];
        var csv = XLSX.utils.sheet_to_csv(firstSheet) ;
        fn(null, csv);
      } catch(e) {
        fn('error parsing to XLSX', csv);
      }
    };

    function removeColumnsWithEmptyHeaders(arr, fn) {
      var trimmedHeaders,
          emptyHeaderCellIndexes;

      try {
        trimmedHeaders = arr[0].map(function(e){return e.trim();});
        arr[0] = trimmedHeaders;
        emptyHeaderCellIndexes = getEmptyCellIndexes(trimmedHeaders);

        if (emptyHeaderCellIndexes.length > 0) {
          arr = removeColumnsAtIndexes(arr, emptyHeaderCellIndexes);
        }
        fn(null, arr);
      } catch(e) {
        fn('error parsing header', arr);
      }
    };

    function removeEmptyTrailingRows(arr, fn) {
      var firstEmptyRowToRemove = 0,
          blankRowCounter = 0;

      for (var i = 0; i < arr.length; i++) {
        if (rowIsEmpty(arr[i])) {
          blankRowCounter += 1;
        } else {
          firstEmptyRowToRemove = i + 1;
          blankRowCounter = 0;
        }
        if (blankRowCounter >= BLANK_ROW_SKIP_THRESHOLD) {break;}
      }
      arr = arr.slice(0, firstEmptyRowToRemove);
      fn(null, arr);
    };

    function fileIsExcelType(filenameExt){
      return $.inArray(filenameExt, EXCEL_TYPES) > -1;
    };

    function fileHasValidExtension(filenameExt){
      return $.inArray(filenameExt, ACCEPTED_FILE_EXTS) > -1;
    };

    function getEmptyCellIndexes(row) {
      return row.reduce(function(indexes, cellValue, cellIndex) {
        if (cellValue === '') {
          indexes.push(cellIndex);
        }
        return indexes;
      }, []);
    };

    function rowIsEmpty(row) {
      for(var i = 0; i < row.length; i++) {
        if (row[i] !== '') {
          return false;
        }
      }
      return true;
    };

    function removeColumnsAtIndexes(csv, indexesToRemove) {
      // sort indexesToremove descending
      indexesToRemove.sort(function(a, b){return b-a;});

      for(var rowIndex = 0; rowIndex < csv.length; rowIndex++) {
        for(var i = 0; i < indexesToRemove.length; i++) {
          csv[rowIndex].splice(indexesToRemove[i], 1);
        }
      }
      return csv;
    };

    return new ApiBuilder({
      pure: {
        process : process
      },
      testOnly: {
      }
    }).getApi();

  };

  define(['jquery', 'api_builder', 'xlsx'], function() {
    var jQuery = arguments[0];
    var ApiBuilder = arguments[1];
    var XLSX = arguments[2];

    return init(jQuery, ApiBuilder, XLSX);
  });
})();
