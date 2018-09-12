public with sharing class SnapshotServices {
    private static final String REPORT_GROUPING_KEY_TABULAR_PREFIX = 'T';
    private static final String REPORT_GROUPING_KEY_SUFFIX = '!T';
    private static final String REPORT_EMPTY_CELL_DATA = '-';
    public static final String ERROR_LINE_SEPARATOR = '\n';
    public static DateTime nowTime {
        get{
            if (nowTime == null){
                nowTime = DateTime.now();
            }
            return nowTime;
        }
    }
    /**
    * Extracts report results and organizes them by row, flattening any grouping headers into the rest of the cells, if necessary.
    * @param results: The results of a previously-run report.
    * @return A list of maps, each of which maps column labels to the values for that column in a particular row.
    * @throws Exception
    */
    public static List<Map<String, String>> organizeReportResults(Reports.ReportResults results) {
        Reports.ReportFormat format = results.getReportMetadata().getReportFormat();
        if (format == Reports.ReportFormat.TABULAR) {
            return organizeTabularReportResults(results);
        } else if (format == Reports.ReportFormat.SUMMARY) {
            return organizeSummaryReportResults(results);
        } else {
            throw new SnapshotException(System.Label.Error_Report_Format);
        }
    }

    /**
    * Creates a collection of SObject records with the given report results as specified by the given snapshot.
    * @param reportResults: The report results to map into the target records.
    * @param snapshot: The snapshot that defines the result mapping.
    * @return A list of SObject records created from the report results.
    */
    public static List<SObject> mapReportResultsIntoTargetObject(List<Map<String, String>> reportResults, ALM_Job__c snapshot) {
        List<SObject> mappedTargetObjectsToReturn = new List<SObject>();
        Map<String, Schema.SObjectField> schemaFieldMapForTargetObject = Schema.getGlobalDescribe().get(snapshot.Target_Object_API_Name__c).getDescribe().fields.getMap();
        Map<String, Schema.SOAPType> fieldApiToSoapType = generateFieldAPINamesToType(schemaFieldMapForTargetObject);

        for (Map<String, String> reportResult : reportResults) {
            SObject newTargetRecord = Schema.getGlobalDescribe().get(snapshot.Target_Object_API_Name__c).newSObject();
            for (Snapshot_Field_Mapping__c fieldMapping : snapshot.Snapshot_Field_Mappings__r) {
                if(!reportResult.containsKey(fieldMapping.Report_Column__c)){
                    throw new SnapshotException(System.Label.Snapshot_Report_Data_Conversion_Error +' '+ fieldMapping.Report_Column__c + ' does not exist on the report as a column');
                }
                String value = reportResult.get(fieldMapping.Report_Column__c);
                Object convertedValue;

                if (!String.isBlank(value)) {
                    String targetField = fieldMapping.Target_Field_API_Name__c.toLowerCase();
                    if(!schemaFieldMapForTargetObject.containsKey(targetField)){
                        throw new SnapshotException(System.Label.Snapshot_Report_Data_Conversion_Error +' '+ targetField + ' does not exist on ' + snapshot.Target_Object_API_Name__c);
                    }
                    try {
                            Schema.DisplayType fieldDisplayType = schemaFieldMapForTargetObject.get(targetField).getDescribe().getType();
                            Schema.SoapType fieldSoapType = fieldApiToSoapType.get( targetField );
                            Type apiType;

                            if (fieldSoapType == Schema.SoapType.DATE) {
                                convertedValue = Date.parse(value);
                            } else if (fieldSoapType == Schema.SoapType.DATETIME) {
                                convertedValue = DateTime.parse(value);
                            } else {
                                if (fieldDisplayType == Schema.DisplayType.CURRENCY) {
                                    value = value.replaceAll('[^.\\d]','');
                                } else if (fieldDisplayType == Schema.DisplayType.PERCENT) {
                                    value = value.replace('%', '');
                                } else if (fieldDisplayType == Schema.DisplayType.URL) {
                                    value = EncodingUtil.urlDecode(value.unescapeHtml4(),'UTF-8').stripHtmlTags();
                                }
                                apiType = Type.forName( fieldSoapType.name() );
                                convertedValue = JSON.deserialize( JSON.serialize(value), apiType );
                            }

                            newTargetRecord.put(targetField, convertedValue);
                    } catch (Exception e) {
                        throw new SnapshotException(System.Label.Snapshot_Report_Data_Conversion_Error +' '+ e.getMessage() + ERROR_LINE_SEPARATOR + e.getStackTraceString());
                    }
                }
            }
            mappedTargetObjectsToReturn.add(newTargetRecord);
        }

        return mappedTargetObjectsToReturn;
    }

    /**
    * Inserts a list of SObjects into the database.
    * @param records: A list of SObjects to be inserted into the database.
    * @return A string of separated error messages.
    */
    public static String insertRecords(List<SObject> records) {
        String errorMessages = '';

        Database.SaveResult[] saveResultList = Database.insert(records, false);

        for (Integer i = 0; i < saveResultList.size(); ++i) {
            if (!saveResultList[i].isSuccess()) {
                for (Database.Error err : saveResultList[i].getErrors()) {
                    errorMessages += 'Error inserting record: ' + err.getMessage() + ERROR_LINE_SEPARATOR;
                }
            }
        }

        return errorMessages;
    }

    /**
    * Extracts tabular report results and organizes them by row.
    * @param results: The results of a previously-run tabular report.
    * @return A list of maps, each of which maps column labels to the values for that column in a particular row.
    */
    private static List<Map<String, String>> organizeTabularReportResults(Reports.ReportResults results) {
        return organizeReportResultsFactMap(results, REPORT_GROUPING_KEY_TABULAR_PREFIX);
    }

    /**
    * Extracts summary report results and organizes them by row, flattening any grouping headers into the rest of the cells.
    * @param results: The results of a previously-run summary report.
    * @return A list of maps, each of which maps column labels to the values for that column in a particular row.
    */
    private static List<Map<String, String>> organizeSummaryReportResults(Reports.ReportResults results) {
        // Maps a grouping level {0, 1, 2} to a column label.
        Map<Integer, String> groupingLevelToGroupingLabel = mapGroupingLevelToGroupingLabel(results.getReportExtendedMetadata());
        // Maps a grouping key (e.g. "0_1_0") to a data cell value.
        Map<String, String> groupingKeyToGroupingValue = mapGroupingKeyToGroupingValue(new Map<String, String>(), results.getGroupingsDown().getGroupings());

        // Flattens grouping headers into the "column label => column value" map.
        List<Map<String, String>> flattenedOrganizedResults = new List<Map<String, String>>();
        for (String groupingKey : results.getFactMap().keySet()) {
            // Strips the grouping key suffix from each grouping key for use with the above maps.
            String modifiedGroupingKey = groupingKey.replace(REPORT_GROUPING_KEY_SUFFIX, '');

            // Grabs the in-row data from each result row.
            List<Map<String, String>> organizedResults = organizeReportResultsFactMap(results, modifiedGroupingKey);

            // Map the additional labels coming from the headers to their values.
            Map<String, String> headerLabelToHeaderValue = new Map<String, String>();
            String travelingModifiedGroupingKey = modifiedGroupingKey;
            while (!String.isBlank(travelingModifiedGroupingKey)) {
                // Retrieves the header label and value for the current nested grouping level.
                String columnLabel = groupingLevelToGroupingLabel.get(translateGroupingKeyToGroupingLevel(travelingModifiedGroupingKey));
                String columnValue = groupingKeyToGroupingValue.get(travelingModifiedGroupingKey);
                headerLabelToHeaderValue.put(columnLabel, columnValue == REPORT_EMPTY_CELL_DATA ? null : columnValue);

                // Individually replaces the numbers and the underscores rather than using a single regex so that the loop does not stall on an individual number.
                travelingModifiedGroupingKey = travelingModifiedGroupingKey.replaceFirst('[' + REPORT_GROUPING_KEY_TABULAR_PREFIX + '0-9]*$', '');
                travelingModifiedGroupingKey = travelingModifiedGroupingKey.replaceFirst('_$', '');
            }

            // Updates each row of data with the values from each of its nested parent headers.
            for (Map<String, String> columnLabelToColumnValue : organizedResults) {
                for (String headerLabel : headerLabelToHeaderValue.keySet()) {
                    columnLabelToColumnValue.put(headerLabel, headerLabelToHeaderValue.get(headerlabel));
                }
            }

            // Updates the flattened results list.
            flattenedOrganizedResults.addAll(organizedResults);
        }

        return flattenedOrganizedResults;
    }

    @TestVisible
    private static List<Map<String, String>> organizeReportResultsFactMap(Reports.ReportResults results, String groupingKey) {
        Reports.ReportMetadata metadata = results.getReportMetadata();
        Reports.ReportExtendedMetadata extendedMetadata = results.getReportExtendedMetadata();

        // Uses the detail column information to map column names to column labels.
        Map<String, Reports.DetailColumn> detailColumnMap = extendedMetadata.getDetailColumnInfo();
        Map<String, String> columnNameToColumnLabel = new Map<String, String>();
        for (String columnName : detailColumnMap.keySet()) {
            columnNameToColumnLabel.put(columnName, detailColumnMap.get(columnName).getLabel());
        }

        // Uses the fact map and the above map to map column labels to their corresponding data cells for each record row.
        Reports.ReportFactWithDetails detailFacts = (Reports.ReportFactWithDetails)(results.getFactMap().get(groupingKey + REPORT_GROUPING_KEY_SUFFIX));
        List<String> columnNamesInOrder = metadata.getDetailColumns();
        List<Map<String, String>> organizedResults = new List<Map<String, String>>();
        for (Reports.ReportDetailRow row : detailFacts.getRows()) {
            Map<String, String> columnLabelToDataCell = new Map<String, String>();
            List<Reports.ReportDataCell> cells = row.getDataCells();
            for (Integer i = 0; i < cells.size(); ++i) {
                columnLabelToDataCell.put(columnNameToColumnLabel.get(columnNamesInOrder[i]), cells[i].getLabel() == REPORT_EMPTY_CELL_DATA ? null : cells[i].getLabel());
            }
            organizedResults.add(columnLabelToDataCell);
        }

        return organizedResults;
    }

    @TestVisible
    private static Map<Integer, String> mapGroupingLevelToGroupingLabel(Reports.ReportExtendedMetadata extendedMetadata) {
        Map<Integer, String> groupingLevelToGroupingLabel = new Map<Integer, String>();

        Map<String, Reports.GroupingColumn> groupingColumnNameToGroupingColumn = extendedMetadata.getGroupingColumnInfo();
        for (String groupingColumnName : groupingColumnNameToGroupingColumn.keySet()) {
            Reports.GroupingColumn groupingColumn = groupingColumnNameToGroupingColumn.get(groupingColumnName);
            groupingLevelToGroupingLabel.put(groupingColumn.getGroupingLevel(), groupingColumn.getLabel());
        }

        return groupingLevelToGroupingLabel;
    }

    @TestVisible
    private static Map<String, String> mapGroupingKeyToGroupingValue(Map<String, String> groupingKeyToGroupingValue, List<Reports.GroupingValue> groupings) {
        if (groupings.isEmpty()) {
            return groupingKeyToGroupingValue;
        }

        for (Reports.GroupingValue grouping : groupings) {
            groupingKeyToGroupingValue.put(grouping.getKey(), grouping.getLabel());
            mapGroupingKeyToGroupingValue(groupingKeyToGroupingValue, grouping.getGroupings());
        }

        return groupingKeyToGroupingValue;
    }

    @TestVisible
    private static Integer translateGroupingKeyToGroupingLevel(String groupingKey) {
        return groupingKey.countMatches('_');
    }

    @TestVisible
    public static Map<String, Schema.SOAPType> generateFieldAPINamesToType( Map<String, Schema.SObjectField> schemaMap ){
        Map<String, Schema.SOAPType> apiNameToFieldType = new Map<String, Schema.SOAPType>();

        for (String fieldApiName : schemaMap.keySet()) {
            apiNameToFieldType.put( fieldApiName, schemaMap.get(fieldApiName).getDescribe().getSOAPType());
        }

        return apiNameToFieldType;
    }
}