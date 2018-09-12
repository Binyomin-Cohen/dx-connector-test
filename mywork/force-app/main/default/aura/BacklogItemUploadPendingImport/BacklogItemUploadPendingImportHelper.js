({
  populateObjectToPendingRecordCount : function( component, helper ) {
    var reqConfigData = component.get("v.mappingConfigData.requiredMappingConfigurations");
    var configData = component.get("v.mappingConfigData.mappingConfigurations");
    var objectApiName = component.get("v.mappingConfigData.backlogItemObjectApiName");
    var objectLabelPlural = component.get("v.mappingConfigData.backlogItemObjectLabelPlural");
    var objectToPendingRecordCount = component.get("v.objectToPendingRecordCount");
    var emptyObjectBlocks = component.get("v.emptyBlocks");
    var step = component.get("v.step");
    var numberOfBacklogItemsToUpload = component.get("v.parsedUploadFile.rows.length");

    if( step == 2 )
    {
      objectToPendingRecordCount = [];
      objectToPendingRecordCount.push({objectName: objectLabelPlural, apiName:objectApiName, count:numberOfBacklogItemsToUpload});

      this.aggregateObjectCountsForRequiredAndNonRequiredData( reqConfigData, configData, objectToPendingRecordCount );
      component.set("v.objectToPendingRecordCount", objectToPendingRecordCount);

      var step;
      var count = 4 - ( objectToPendingRecordCount.length % 4 );
      if( count > 0 ){
        for (step = 0; step < count; step++) {
          emptyObjectBlocks.push('&nbsp;');
        }
        component.set("v.emptyBlocks", emptyObjectBlocks);
      }
    }
  },
  aggregateObjectCounts : function( configData, apiNameToCount ){
    var mappingIndex;
    for (mappingIndex in configData){
      var mapping = configData[mappingIndex];

      if (mapping.isLookup && !mapping.lookupDetail.hasLookupError && mapping.lookupDetail.createNewRelatedRecords){
        var countToModify = apiNameToCount[ mapping.lookupDetail.lookupTargetObjectName ]
        || {objectName: mapping.lookupDetail.lookupTargetObjectLabel + ' Records',
          apiName:mapping.lookupDetail.lookupTargetObjectName,
          count:0};

          countToModify.count += mapping.lookupDetail.newRelatedRecords.length;
          apiNameToCount[ mapping.lookupDetail.lookupTargetObjectName ] = countToModify;
      }
    }
  },
  aggregateObjectCountsForRequiredAndNonRequiredData : function( reqConfigData, configData, objectToPendingRecordCount ){
    var apiNameToCount = [];
    this.aggregateObjectCounts( reqConfigData, apiNameToCount );
    this.aggregateObjectCounts( configData, apiNameToCount );
    for( var key in apiNameToCount )
    {
      var currentCount = apiNameToCount[key];
      if( currentCount.count > 0 ){
        objectToPendingRecordCount.push(currentCount);
      }
    }
  }
})