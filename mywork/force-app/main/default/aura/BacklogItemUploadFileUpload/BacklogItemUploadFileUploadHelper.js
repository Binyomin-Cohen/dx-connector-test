({
  init : function(component, event, helper) {
    helper.toggleManualUploadForm('show');

    // TODO: extract to component
    this.ACCEPTED_FILE_EXTS = ['.xls', '.xlsx', '.csv'];
    this.MAX_FILE_SIZE = 1024 * 1024 * 25; //25Mb
  },

  /**
   * Resets the file input after an unsuccessful upload
   * This is to preserve "onchange" listeners if user tries
   * to upload the same file multiple times
   */
  resetManualPackageInput : function() {
    var $input = $('#manual-upload-form .file-input');
    $input.val('');
  },

  showUploadMessage : function(self, type, msg) {
    self.fireAddPageMessageEvent(type, msg);
    self.resetManualPackageInput();
  },

  fileDragHover : function(component, event) {
    event.preventDefault();
    event.stopPropagation();
    if (event.type == "dragover") {
      $('.upload-drag-helper').addClass("drag-hover");
    } else {
      $('.upload-drag-helper').removeClass("drag-hover");
    }
  },

  fileDropHandler : function(component, event, helper) {
    //TODO: investigate drop on input button
    var file;
    if (event.dataTransfer) {
      file = event.dataTransfer.files[0];
    } else {
      file = component.find("file").getElement().files[0];
    }

    helper.fileDragHover(component, event);
    helper.startFileUpload(this, file, component, helper);
  },

  toggleManualUploadForm : function (stateOverride) {
    if(stateOverride !== 'show') {
      $('#manual-upload-form').hide();
    } else {
      $('#manual-upload-form').show();
    }
  },

  fileSizeIsValid : function (file){
    return (file.size && file.size <= this.MAX_FILE_SIZE);
  },

  fileHasValidExtension : function(filenameExt){
    return $.inArray(filenameExt, this.ACCEPTED_FILE_EXTS) > -1;
  },

  getEmptyCellIndexes : function(row) {
    return row.reduce(function(indexes, cellValue, cellIndex) {
      if (cellValue === '') {
        indexes.push(cellIndex);
      }
      return indexes;
    }, []);
  },

  rowIsEmpty : function (row) {
    for(var i = 0; i < row.length; i++) {
      if (row[i] !== '') {
        return false;
      }
    }
    return true;
  },

  removeColumnsAtIndexes : function(csv, indexesToRemove) {
    // sort indexesToremove descending
    indexesToRemove.sort(function(a, b){return b-a;});

    for(var rowIndex = 0; rowIndex < csv.length; rowIndex++) {
      for(var i = 0; i < indexesToRemove.length; i++) {
        csv[rowIndex].splice(indexesToRemove[i], 1);
      }
    }
    return csv;
  },

  handleCsvUpload : function (self, component, filename, csv) {
    var headers,
        parsedUploadFile,
        emptyHeaderCellIndexes = [],
        numRowsToKeep = 0,
        blankRowCounter = 0,
        blankRowSkipThreshold = 5;
    try {
      csv = $.csv.toArrays(csv);

      // Remove empty rows
      for (var i = 0; i < csv.length; i++) {
        if (self.rowIsEmpty(csv[i])) {
          blankRowCounter += 1;
        } else {
          numRowsToKeep = i + 1;
          blankRowCounter = 0;
        }
        if (blankRowCounter >= blankRowSkipThreshold) {break;}
      }
      csv = csv.slice(0, numRowsToKeep);

      headers = csv[0].map(function(e){return e.trim();});
      emptyHeaderCellIndexes = self.getEmptyCellIndexes(headers);

      // Remove columns with empty header cells
      if (emptyHeaderCellIndexes.length > 0) {
        csv = self.removeColumnsAtIndexes(csv, emptyHeaderCellIndexes);
        headers = csv[0].map(function(e){return e.trim();});
      }

      csv.shift();
      parsedUploadFile = {
        headers: headers,
        rows: csv,
        filename: filename
      };
    } catch(e) {
      self.showUploadMessage(self, "error", e.message);
      return;
    }

    if (!parsedUploadFile.headers || parsedUploadFile.headers.length === 0) {
      self.showUploadMessage(self, "error", "An error occurred while parsing the file header");
      return;
    } else if (!parsedUploadFile.rows || parsedUploadFile.rows.length === 0) {
      self.showUploadMessage(self, "error", "An error occurred while parsing the file");
      return;
    }

    component.set('v.parsedUploadFile', parsedUploadFile);
    self.requestNextPage(component);
  },

  convertBinaryStringExcelTypeToCsv : function (self, component, filename, bstr, cb) {
    try {
      var workbook = XLSX.read(bstr, {type:"binary"});
      var firstSheet = workbook.Sheets[workbook.SheetNames[0]];
      var csv = XLSX.utils.sheet_to_csv(firstSheet) ;
      cb(self, component, filename, csv);
    } catch(e) {
      self.showUploadMessage(self, "error", 'An error occurred while parsing the file');
    }
  },

  requestNextPage: function(component) {
    var step = component.get("v.step");
    step++;
    component.set("v.step", step);
  },

  arrayBufferToString: function( buffer ) {
    var dataArray = new Uint8Array(buffer);

    var bufferConvertedToString = '';
    for(var i = 0; i < dataArray.length; i++) {
      bufferConvertedToString += String.fromCharCode(dataArray[i]);
    }

    return bufferConvertedToString;
  },

  startFileUpload : function (self, file, component, helper) {
    if (!file) {
      return;
    }

    var fileName = file.name,
        fileNameExt = fileName.substr(fileName.lastIndexOf('.'));

    self.clearMessages();

    if (!this.fileHasValidExtension(fileNameExt)) {
      self.showUploadMessage(self, "error", 'Invalid file type. File must be of type .csv, .xls, .xlsx');
      return;
    } else if (!this.fileSizeIsValid(file)) {
      self.showUploadMessage(self, "error", 'Maximum file size is 25Mb');
      return;
    }

    var reader = new FileReader();

    reader.onloadend = $A.getCallback(function () {
      var bstr = self.arrayBufferToString(reader.result);

      if (fileNameExt === '.xlsx' || fileNameExt === '.xls') {
        self.convertBinaryStringExcelTypeToCsv(self, component, fileName, bstr, $A.getCallback(self.handleCsvUpload));
      } else if (fileNameExt === '.csv') {
        self.handleCsvUpload(self, component, fileName, bstr);
      }
      self.resetManualPackageInput();
    });

    reader.onerror = $A.getCallback(function(event) {
      self.clearMessages();
      self.showUploadMessage(self, "error", "Error reading file! Code " + event.target.error.code);
    });

    reader.readAsArrayBuffer(file);
  },

  fireAddPageMessageEvent : function(type, message) {
    var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");
    pageMessageAddEvent.setParams({
      "type": type,
      "message": message
    });
    pageMessageAddEvent.fire();
  },

  clearMessages : function() {
    var clearMsgsEvt = $A.get("e.c:pageMessagesClear");
    clearMsgsEvt.fire();
  }
});
