public with sharing class Assembler {
    public static final Integer MANIFEST_CHUNK_SIZE = 1000;

    public transient String documentedComponentsJSON {get; set;}

    public List<AssemblerManifestRecord> manifest { get; set; }
    public List<AssemblerManifestRecord> filteredManifest { get; set; }
    public List<AssemblerManifestRecord> undocumentedComponents { get; set; }
    // List of build components to remove on save
    public List<Build_Component__c> removedBuildComps = new List<Build_Component__c>();

    public List<ProfileManifestRecord> documentedPermissions { get; set; }
    public List<ProfileManifestRecord> undocumentedPermissions { get; set; }
    public List<ProfileManifestRecord> selectedPermissions { get; set; }

    public String selectedComponentIdString { get; set; }

    /*Comma delimited assembler manifest record keys to be removed from the profile permissions*/
    public String pendingRemovals { get; set; }

    public List<SelectOption> instanceFilters { get; set; }
    public List<SelectOption> statusFilters { get; set; }
    public List<SelectOption> typeFilters { get; set; }
    public List<String> selectedInstanceFilters { get; set; }
    public List<String> selectedStatusFilters { get; set; }
    public List<String> selectedTypeFilters { get; set; }
    public List<BacklogFilter> backlogFilters { get; set; }

    private Id releaseId;
    private String previousBuildId;
    private Boolean isRebuild {
        get { return (build != null && (build.Status__c == BuildServices.STATUS_FAILURE || build.Status__c == BuildServices.STATUS_SUCCESS)); }
    }

    public String buildId { get { return build.Id; } }

    public Boolean buildExists {
        get {
            return !String.isBlank( buildId );
        }
    }

    public Integer componentCount {
        get {
            componentCount = manifest.size() + undocumentedComponents.size();
            return componentCount;
        }
        set;
    }

    public Integer selectedProfileCount {
        get {
            selectedProfileCount = (selectedPermissions == null) ? 0 : selectedPermissions.size();
            return selectedProfileCount;
        }
        set;
    }

    public Boolean isInProgress {
        get {
          return build != null && build.Status__c == BuildServices.STATUS_PENDING || build.Status__c == BuildServices.STATUS_IN_PROGRESS;
       }
    }

    public Boolean isCompleted {
        get { return isRebuild; }
    }

    public Boolean isManualUpload {
        get { return build != null && build.Manual_Upload__c; }
    }

    public Boolean isManualPackageParsed {
        get { return (build != null) ? build.Is_Manual_Package_Parsed__c : false; }
    }

    public String parseBuildFailureReason {
        get { return (build != null) ? build.Manual_Package_Parse_Failure_Reason__c : ''; }
    }

    public String manifestInstances {
        get {
            if (isManifestLoaded) {
                Set<String> instances = new Set<String>();

                for(AssemblerManifestRecord manifestRecord : manifest) {
                    if (String.isNotBlank(manifestRecord.instance)) {
                        instances.add(manifestRecord.instance);
                    }
                }

                for(AssemblerManifestRecord manifestRecord : undocumentedComponents) {
                    if (String.isNotBlank(manifestRecord.instance)) {
                        instances.add(manifestRecord.instance);
                    }
                }

                for(ProfileManifestRecord manifestRecord : selectedPermissions) {
                    if (String.isNotBlank(manifestRecord.instance)) {
                        instances.add(manifestRecord.instance);
                    }
                }

                manifestInstances = JSON.serialize(new List<String>(instances));
            }
            return manifestInstances;
        }
        private set;
    }

    public Build__c build { get; private set; }

    public Boolean isManifestLoaded { get; private set;}
    // TRUE if the manifest has become stale by outside editing
    public Boolean isStaleManifest { get; private set; }
    // Date/Time of last stale manifest check
    @TestVisible
    public Datetime staleManifestCheckTime { get; private set; }

    public Assembler(String releaseId) {
        this.isManifestLoaded = false;
        this.isStaleManifest = false;
        this.releaseId = releaseId;
        this.manifest = new List<AssemblerManifestRecord>();
        this.undocumentedComponents = new List<AssemblerManifestRecord>();

        // Do not init build if this is a rebuild since it will get taken
        // care of as part of the rebuild flow
        if(!this.isRebuild) {
            initNewBuild();
        }
        populateFilters();
        selectedInstanceFilters = new List<String>();
        selectedTypeFilters = new List<String>();
        selectedStatusFilters = new List<String>();
    }

    public Assembler(String releaseId, Build__c build) {
        this(releaseId);
        this.build = build;

        // If this is a rebuild then we need to call loadManifest
        // so that we rebuild manifest and clear current build
        if(this.isRebuild) {
            loadManifest();
        }
    }

    public void addUndocumentedComponents() {
       List<ComponentSearchWrapper> selectedComponents;

        try {
            selectedComponents = ComponentSearch.getSelectedComponents(selectedComponentIdString);
        } catch(ALMException ae) {
            ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    ae.getMessage()
                ));
            return;
        }

        for(ComponentSearchWrapper component : selectedComponents) {
            if (component.component.Type__c == 'Profile') {
                addSelectedUndocumentedProfileFromUndocumentedComponent(component.component);
            } else {
                if (undocumentedComponents.isEmpty()) {
                    undocumentedComponents.add(new AssemblerManifestRecord(component) );
                } else {
                    undocumentedComponents.add(0, new AssemblerManifestRecord(component) );
                }
            }
        }
        //regenerate documented components json to ensure transient value is populated when rerendering the profile manifest
        documentedComponentsJSON = generateDocumentedComponentsJSON();
    }

    public void addSelectedUndocumentedProfileFromUndocumentedComponent(Component__c component) {
        ProfileManifestRecord profile = new ProfileManifestRecord(component);
        profile.selected = true;

        if (undocumentedPermissions.isEmpty()) {
            undocumentedPermissions.add(profile);
        } else {
            undocumentedPermissions.add(0, profile);
        }

        if (selectedPermissions.isEmpty()) {
            selectedPermissions.add(profile);
        } else {
            selectedPermissions.add(0, profile);
        }
    }

    public Boolean isManifestChanged(String completedBuildId) {

        if (completedBuildId == null) {
            return false;
        }

        Set<String> existingKeys = new Set<String>();
        Set<String> manifestKeys = new Set<String>();

        for(AssemblerManifestRecord record : AssemblerServices.getManifestByBuildId(completedBuildId)) {
                existingKeys.add(record.getKey() + '|' + record.getBuildComponent().Type__c);
        }

        List<AssemblerManifestRecord> allComponents = new List<AssemblerManifestRecord>();
        allComponents.addAll(undocumentedComponents);
        allComponents.addAll(manifest);
        allComponents.addAll((List<AssemblerManifestRecord>)selectedPermissions);

        for (AssemblerManifestRecord record : allComponents) {
            String key = record.getKey() + '|';
            key += (record.isRemoved) ? AssemblerManifestRecord.REMOVED : record.getBuildComponent().Type__c;
            manifestKeys.add(key);
        }

        for(ProfileManifestRecord profile : documentedPermissions) {
            if (!profile.selected) {
                manifestKeys.add(profile.getKey() + '|' + AssemblerManifestRecord.REMOVED);
            }
        }

        return !existingKeys.equals(manifestKeys);
    }

    public void removeUndocumentedComponents() {
        if ( !String.isBlank(selectedComponentIdString) ) {
            Set<String> selectedComponentIds = new Set<String>(selectedComponentIdString.split(','));
            for (Integer i = undocumentedComponents.size() - 1; i >= 0; i--) {
                if (selectedComponentIds.contains(undocumentedComponents[i].getKey())) {
                    AssemblerManifestRecord manifestRecord = undocumentedComponents.remove(i);
                    Build_Component__c buildComp = manifestRecord.getBuildComponent();
                    if(buildComp.Id != null) {
                        removedBuildComps.add(buildComp);
                    }
                }
            }
        }

        //regenerate documented components json to ensure transient value is populated when rerendering the profile manifest
        documentedComponentsJSON = generateDocumentedComponentsJSON();
    }

    public void removeComponentProfileData() {
        documentedComponentsJSON = generateDocumentedComponentsJSON();

        if (String.isBlank(pendingRemovals)) {
            return;
        }

        List<ProfileManifestRecord> permissionsToUpdate = new List<ProfileManifestRecord>();
        for (ProfileManifestRecord profile : selectedPermissions) {
            if (profile.includeOnlyDocumentedComponents && !profile.includeEntireProfile
                 && String.isNotBlank(profile.selectedPermissions)) {
                permissionsToUpdate.add(profile);
            }
        }

        if (permissionsToUpdate.isEmpty()) {
            pendingRemovals = '';
            return;
        }

        Set<String> assemblerManifestKeysToRemove = new Set<String>(pendingRemovals.split(','));

        List<AssemblerManifestRecord> documentedComponentsToRemove = new List<AssemblerManifestRecord>();
        for (AssemblerManifestRecord manifestRecord : manifest) {
            if (assemblerManifestKeysToRemove.contains(manifestRecord.getKey()) && manifestRecord.isRemoved) {
                documentedComponentsToRemove.add(manifestRecord);
            }
        }

        Map<String, Set<String>> sectionToPermissions = ProfileServices.filterComponents(documentedComponentsToRemove);

        for (ProfileManifestRecord profile : permissionsToUpdate) {
            ProfilePermissions permissionsData = ProfilePermissions.valueOf(profile.selectedPermissions);
            permissionsData.removePermissions(sectionToPermissions);
            profile.selectedPermissions = JSON.serialize(permissionsData);
        }

        pendingRemovals = '';
    }

    /**
    * @throws Exception
    */
    public void saveBuild() {
        upsert build;
    }

    /**
    * Get the build components from the List of AssemblerManifestRecord
    * @param List<AssemblerManifestRecord> manifestRecs
    * @return List<Build_Component__c>
    */
    private static List<Build_Component__c> getBuildComponents(List<AssemblerManifestRecord> manifestRecs) {
        List<Build_Component__c> buildComponents = new List<Build_Component__c>();
        if(manifestRecs != null) {
            for(AssemblerManifestRecord manifestRecord : manifestRecs) {
                buildComponents.add(manifestRecord.getBuildComponent());
            }
        }
        return buildComponents;
    }

    /**
    * Diffs the current build and release and sets isStale property and last check date
    * @throws ALMException
    */
    public void checkManifestIsStale() {
        if (isManualUpload) {
            isStaleManifest = false;
            return;
        }

        String buildToCompare = (buildId == null) ? previousBuildId : buildId;

        if(buildToCompare == null) {
            return;
        }

        isStaleManifest = AssemblerServices.diffBuildAndRelease(buildToCompare, releaseId).size() > 0;
        staleManifestCheckTime = DateTime.now();
    }

    /**
    * Performs a diff and syncs the current manifest with the latest release manifest
    * @throws ALMException
    */
    public void syncManifest() {

        if(buildId == null) {
            saveBuild();
            saveComponents();
        }

        loadManifest();

        List<AssemblerServices.ManifestDiff> diffList = AssemblerServices.diffBuildAndRelease(buildId, releaseId);
        if(diffList.isEmpty()) {
            // Could happen if someone removed any changed components/profiles right before
            // running the sync
            return;
        }

        // Remove any build components whose backlog component lookups are null.
        List<Build_Component__c> buildComponentsWithDeletedBacklogComponents = new List<Build_Component__c>();
        Set<String> documentedKeysToRemove = new Set<String>();
        for (AssemblerManifestRecord record : manifest) {
            Build_Component__c buildComponent = null;
            if (record != null) {
                if (!record.getIsDocumented()) {
                    continue;
                }
                buildComponent = record.getBuildComponent();
            }

            if (buildComponent != null && buildComponent.Backlog_Component__c == null) {
                buildComponentsWithDeletedBacklogComponents.add(buildComponent);
                documentedKeysToRemove.add(record.getDocumentedKey());
            }
        }
        if (!buildComponentsWithDeletedBacklogComponents.isEmpty()) {
            delete buildComponentsWithDeletedBacklogComponents;
        }
        for (Integer i = manifest.size() - 1; i >= 0; --i) {
            if (documentedKeysToRemove.contains(manifest[i].getDocumentedKey())) {
                manifest.remove(i);
            }
        }

        List<AssemblerManifestRecord> totalManifest = getTotalManifest();
        AssemblerServices.ManifestFilterable manifestFilterable = new AssemblerServices.ManifestFilterable(totalManifest);
        Set<Build_Component__c> buildCompsToUpsert = new Set<Build_Component__c>();
        Set<Id> existingRecBacklogCompIds = new Set<Id>();

        for(AssemblerServices.ManifestDiff diff : diffList) {
            AssemblerManifestRecord existingRec = manifestFilterable.findByKey(diff.manifestRecord.getDocumentedKey());

            if(diff.type == AssemblerServices.DiffType.ADDED) {
                if(existingRec == null) {
                    AssemblerManifestRecord undocumentedExistingRec = manifestFilterable.findByKey(diff.manifestRecord.getKey());

                    if (undocumentedExistingRec == null) {
                        // New component documented on release that isn't on the build
                        AssemblerManifestRecord newBuildRecord = diff.manifestRecord.deepClone();
                        Build_Component__c newBuildComp = newBuildRecord.getBuildComponent();
                        newBuildComp.Build__c = buildId;
                        buildCompsToUpsert.add(newBuildComp);
                    } else if(undocumentedExistingRec.getIsUndocumented()) {
                        // Convert undocumented build component into
                        // documented build component
                        Build_Component__c existingBuildComp = undocumentedExistingRec.getBuildComponent();
                        existingBuildComp.Backlog_Component__c = diff.manifestRecord.getBuildComponent().Backlog_Component__c;
                        existingBuildComp.Type__c = AssemblerManifestRecord.DOCUMENTED;
                        buildCompsToUpsert.add(existingBuildComp);
                    }
                }
            } else if (diff.type == AssemblerServices.DiffType.CHANGED) {
                if(existingRec != null) {
                    AssemblerManifestRecord releaseRecord = diff.manifestRecord;

                    existingRec.getBuildComponent().Is_Manual_Deployment__c = releaseRecord.getBuildComponent().Is_Manual_Deployment__c;
                    existingRec.isRemoved = releaseRecord.isRemoved;

                    buildCompsToUpsert.add(existingRec.getBuildComponent());
                }
            } else {
                // Remove the component from the build if it exists
                if(existingRec != null) {
                    Build_Component__c existingRecBuildComponent = existingRec.getBuildComponent();
                    existingRecBacklogCompIds.add(existingRecBuildComponent.Backlog_Component__c);
                }
            }
        }

        //Until we can determine if a profile has changed, we will just overwrite all profile selections
        syncProfilesData(manifestFilterable, buildCompsToUpsert);

        if(!buildCompsToUpsert.isEmpty()) {
            upsert new List<Build_Component__c>(buildCompsToUpsert);
        }
        if(!existingRecBacklogCompIds.isEmpty()) {
            List<Build_Component__c> buildCompsToDelete = [SELECT Id FROM Build_Component__c WHERE (Build__c=:buildId AND Backlog_Component__c IN :existingRecBacklogCompIds)];
            if (!buildCompsToDelete.isEmpty()) {
                delete buildCompsToDelete;
            }
        }

        isStaleManifest = false;
        forceManifestReload();
    }

    private void syncProfilesData(AssemblerServices.ManifestFilterable manifestFilterable, Set<Build_Component__c> buildCompsToUpsert) {
        Set<String> buildCompsToUpsertSet = new Set<String>();

        for (Build_Component__c buildComponent : buildCompsToUpsert) {
            buildCompsToUpsertSet.add(buildComponent.Id);
        }

        for (ProfileManifestRecord updatedProfile : AssemblerServices.getDocumentedProfiles(releaseId)) {
            ProfileManifestRecord existingRec =
                (ProfileManifestRecord)manifestFilterable.findByKey(updatedProfile.getDocumentedKey());
            if (existingRec != null) {
                existingRec.includeOnlyDocumentedComponents = updatedProfile.includeOnlyDocumentedComponents;
                existingRec.includeEntireProfile = updatedProfile.includeEntireProfile;
                existingRec.selectedPermissions = updatedProfile.selectedPermissions;

                Build_Component__c componentToUpdate = existingRec.getBuildComponent();
                if (!buildCompsToUpsertSet.contains(componentToUpdate.Id)) {
                    buildCompsToUpsert.add(componentToUpdate);
                }
            }
        }
    }

    private List<AssemblerManifestRecord> cloneAssemblerManifestList(List<AssemblerManifestRecord> manifestToClone){
        List<AssemblerManifestRecord> clonedManifest = new List<AssemblerManifestRecord>();
        for (AssemblerManifestRecord amr : manifestToClone){
          amr = amr.deepClone();
          amr.getBuildComponent().Build__c = null;
          clonedManifest.add(amr);
        }
        return clonedManifest;
    }

    private List<ProfileManifestRecord> cloneProfileManifestList(List<ProfileManifestRecord> manifestToClone){
        List<ProfileManifestRecord> clonedManifest = new List<ProfileManifestRecord>();
        for (ProfileManifestRecord pmr : manifestToClone){
          pmr = (ProfileManifestRecord) pmr.deepClone();
          pmr.getBuildComponent().Build__c = null;
          clonedManifest.add(pmr);
        }
        return clonedManifest;
    }

    public void cloneManifest(){
        if (!this.isManifestLoaded) {
            this.loadManifest();
        }

        this.build = this.build.clone(false, true);

        this.manifest = cloneAssemblerManifestList(this.manifest);
        this.undocumentedComponents = cloneAssemblerManifestList(this.undocumentedComponents);
        filterManifest();

        this.documentedPermissions = cloneProfileManifestList(this.documentedPermissions);
        this.undocumentedPermissions = cloneProfileManifestList(this.undocumentedPermissions);
        this.selectedPermissions = cloneProfileManifestList(this.selectedPermissions);

        this.removedBuildComps.clear();
    }

    /**
    * @throws DMLException, ALMException
    */
    public void saveComponents() {

        if(buildId == null) {
            throw new ALMException('Cannot save components without a build.');
        }

        List<Build_Component__c> buildComponentsToUpsert = new List<Build_Component__c>();
        resetUnappliedProfileChanges();
        removeComponentProfileData();

        buildComponentsToUpsert.addAll( getBuildComponents(manifest) );
        buildComponentsToUpsert.addAll( getBuildComponents(undocumentedComponents) );
        buildComponentsToUpsert.addAll( getBuildComponents(selectedPermissions) );

        for(AssemblerManifestRecord profile : documentedPermissions) {
            Build_Component__c buildComponent = profile.getBuildComponent();
            if (profile.selected) {
                buildComponent.Type__c = AssemblerManifestRecord.DOCUMENTED;
            } else {
                buildComponent.Type__c = AssemblerManifestRecord.REMOVED;
                buildComponentsToUpsert.add(buildComponent);
            }
        }

        for(AssemblerManifestRecord profile : undocumentedPermissions) {
            if (!profile.selected && profile.getBuildComponent().Id != null) {
                removedBuildComps.add(profile.getBuildComponent());
            }
        }

        if(!buildComponentsToUpsert.isEmpty()) {
            Set<Id> upsertCompIds = new Set<Id>();
            for(Build_Component__c bc : buildComponentsToUpsert) {
                if(bc.Backlog_Component__c != null) {
                    upsertCompIds.add(bc.Backlog_Component__c);
                }
            }
            Map<Id, Backlog_Component__c> currCompStateMap = new Map<Id, Backlog_Component__c> ([
                select Id
                from Backlog_Component__c
                where Id in :upsertCompIds
            ]);

            for(Build_Component__c bc : buildComponentsToUpsert) {
                // Add build ID to any components without it
                // Check since we cannot reparent
                if(bc.Id == null) {
                    bc.Build__c = buildId;
                }

                // If the backlog component has been deleted, clear the lookup
                if(bc.Backlog_Component__c != null && !currCompStateMap.containsKey(bc.Backlog_Component__c)) {
                    bc.Backlog_Component__c = null;
                }
            }

            upsert buildComponentsToUpsert;
        }
        if(!removedBuildComps.isEmpty()) {
            delete removedBuildComps;
            for (Build_Component__c component : removedBuildComps) {
                component.Id = null;
            }
            removedBuildComps.clear();
        }
    }

    public List<AssemblerManifestRecord> getTotalManifest() {
        return getTotalManifest(true);
    }

    /**
    * Combines all manifest lists into a single list
    * @return List<AssemblerManifestRecord>
    */
    public List<AssemblerManifestRecord> getTotalManifest(Boolean includeProfiles) {
        List<AssemblerManifestRecord> totalManifest = new List<AssemblerManifestRecord>();

        totalManifest.addAll(manifest);
        totalManifest.addAll(undocumentedComponents);

        if(includeProfiles) {
            if(selectedPermissions != null) {
                totalManifest.addAll((List<AssemblerManifestRecord>)selectedPermissions);
            }
            if(documentedPermissions != null) {
                for(ProfileManifestRecord pmr : documentedPermissions) {
                    if(!pmr.selected) {
                        totalManifest.add((AssemblerManifestRecord)pmr);
                    }
                }
            }
        }

        return totalManifest;
    }

    public void filterManifest() {
        Map<String, AssemblerManifestRecord> manifestMap = new Map<String, AssemblerManifestRecord>();
        List<String> selectedBacklogFilters = new List<String>();
        for(BacklogFilter filter : backlogFilters) {
            if(filter.isSelected) {
                selectedBacklogFilters.add(filter.id);
            }
        }

        if (!hasSelectedFilters(selectedBacklogFilters)) {
            filteredManifest = manifest.clone();
            return;
        }

        for(AssemblerManifestRecord manifestRecord : manifest) {
            manifestMap.put(manifestRecord.getDocumentedKey(), manifestRecord);
        }

        List<AssemblerManifestRecord> filteredRecords = AssemblerServices.getManifest(releaseId,
            selectedInstanceFilters, selectedTypeFilters, selectedStatusFilters, selectedBacklogFilters);

        filteredManifest = new List<AssemblerManifestRecord>();

        for(AssemblerManifestRecord manifestRecord : filteredRecords) {
            if (manifestMap.containsKey(manifestRecord.getDocumentedKey())) {
                filteredManifest.add(manifestMap.get(manifestRecord.getDocumentedKey()));
            }
        }
    }

    public void loadManifest() {
        if (isManifestLoaded) {
            documentedComponentsJSON = generateDocumentedComponentsJSON();
            return;
        }
        isManifestLoaded = true;

        if ( buildExists ) {

            manifest = AssemblerServices.getManifestByBuildId(buildId);

            undocumentedComponents = new List<AssemblerManifestRecord>();
            selectedPermissions = new List<ProfileManifestRecord>();

            if (isRebuild) {
                rebuildManifest();
            }
            else {
                List<ProfileManifestRecord> savedPermissions = new List<ProfileManifestRecord>();
                for (Integer i = manifest.size() - 1; i >= 0; i--) {
                    AssemblerManifestRecord manifestRecord = manifest[i];
                    if (manifestRecord instanceof ProfileManifestRecord) {
                        ProfileManifestRecord profileRecord = (ProfileManifestRecord)manifestRecord;
                        savedPermissions.add(profileRecord);
                        if (profileRecord.selected) {
                            selectedPermissions.add(profileRecord);
                        }
                        manifest.remove(i);
                    } else if (manifestRecord.getIsUndocumented() ) {
                        undocumentedComponents.add(manifestRecord);
                        manifest.remove(i);
                    } else if ( manifestRecord.getBuildComponent().Type__c == AssemblerManifestRecord.REMOVED ) {
                        manifestRecord.isRemoved = true;
                    }
                }

                loadExistingProfiles(savedPermissions);
            }
        }
        else {
            manifest = AssemblerServices.getManifest(releaseId);
            selectedPermissions = AssemblerServices.getDocumentedProfiles(releaseId);
            for (AssemblerManifestRecord permission : selectedPermissions) {
                permission.selected = true;
            }
            documentedPermissions = selectedPermissions.clone();
            undocumentedPermissions = AssemblerServices.getUndocumentedProfiles(releaseId);
        }

        filteredManifest = manifest.clone();

        documentedComponentsJSON = generateDocumentedComponentsJSON();
    }

    public void updateProfileSelection() {
        selectedPermissions.clear();

        for (ProfileManifestRecord profile : documentedPermissions) {
            if (profile.selected) {
                selectedPermissions.add(profile);
            }
        }
        for (ProfileManifestRecord profile : undocumentedPermissions) {
            if (profile.selected) {
                selectedPermissions.add(profile);
            }
        }
        selectedPermissions.sort();
        //regenerate documented components json to ensure transient value is populated when rerendering the profile manifest
        documentedComponentsJSON = generateDocumentedComponentsJSON();
    }

    public List<List<AssemblerManifestRecord>> getChunkedDocumentedManualComponents() {
        return getChunkedComponents(filteredManifest, false, true);
    }

    public List<List<AssemblerManifestRecord>> getChunkedDocumentedDestructiveManualComponents() {
        return getChunkedComponents(filteredManifest, true, true);
    }

    public List<List<AssemblerManifestRecord>> getChunkedUndocumentedDestructiveComponents() {
        return getChunkedComponents(undocumentedComponents, true, false);
    }

    public List<List<AssemblerManifestRecord>> getChunkedDocumentedDestructiveComponents() {
        return getChunkedComponents(filteredManifest, true, false);
    }

    public List<List<AssemblerManifestRecord>> getChunkedUndocumentedComponents() {
        return getChunkedComponents(undocumentedComponents, false, false);
    }

    public List<List<AssemblerManifestRecord>> getChunkedDocumentedComponents() {
        return getChunkedComponents(filteredManifest, false, false);
    }

    public List<Component__c> retrieveAllAvailableTestClasses() {
        return [SELECT Id, Name, Is_Test_Class__c
                FROM Component__c
                WHERE Is_Test_Class__c=true
                ORDER BY Name ASC];
    }

    private List<List<AssemblerManifestRecord>> getChunkedComponents(List<AssemblerManifestRecord> components, Boolean includeDeleted, Boolean includeDeployManually) {
        List<AssemblerManifestRecord> matchingRecords = new List<AssemblerManifestRecord>();
        if (components != null) {
            for (AssemblerManifestRecord record : components) {
                if (((includeDeleted && record.isDeletion) ||
                    (!includeDeleted && !record.isDeletion)) &&
                    ((includeDeployManually && record.deployManually) ||
                    (!includeDeployManually && !record.deployManually))) {

                    matchingRecords.add(record);
                }
            }
        }

        return chunkList(matchingRecords, MANIFEST_CHUNK_SIZE);
    }

    @TestVisible
    private List<List<AssemblerManifestRecord>> chunkList(List<AssemblerManifestRecord> elements, Integer chunkSize) {
        List<List<AssemblerManifestRecord>> chunks = new List<List<AssemblerManifestRecord>>();

        if (elements != null) {
            Integer fromIndex = 0;
            Integer toIndex = 0;

            while (fromIndex < elements.size()) {
               List<AssemblerManifestRecord> chunk = new List<AssemblerManifestRecord>();

               if (toIndex + chunkSize > elements.size()) {
                   toIndex = elements.size();
               } else {
                   toIndex += chunkSize;
               }
               for(Integer i = fromIndex; i < toIndex; i++) {
                   chunk.add(elements[i]);
               }
               chunks.add( chunk );
               fromIndex += chunkSize;
            }
        }

        return chunks;
    }

    /**
    * Forces the reload of the manifest
    */
    private void forceManifestReload() {
        isManifestLoaded = false;
        loadManifest();
    }

    private void initNewBuild() {
        build = new Build__c(
            Release__c = releaseId,
            Status__c = BuildServices.STATUS_NOT_STARTED,
            Manual_Upload__c = isManualUpload,
            Package_URL__c = (build != null ? build.Package_URL__c : null),
            Source_Repository__c = (build != null ? build.Source_Repository__c : null),
            Source_Repository_Location__c = (build != null ? build.Source_Repository_Location__c : null)
        );
    }

    private String generateDocumentedComponentsJSON() {
        List<AssemblerManifestRecord> documentedComponents = new List<AssemblerManifestRecord>();
        for (AssemblerManifestRecord record : manifest) {
            if (!record.isRemoved) {
                documentedComponents.add(record);
            }
        }

        return JSON.serialize(
            ProfileServices.getPermissionsMap(documentedComponents)
        );
    }

    private void rebuildManifest() {
        previousBuildId = buildId;
        initNewBuild();
        List<AssemblerManifestRecord> oldManifest = manifest.clone();

        manifest = new List<AssemblerManifestRecord>();
        undocumentedComponents = new List<AssemblerManifestRecord>();
        documentedPermissions = new List<ProfileManifestRecord>();
        selectedPermissions = new List<ProfileManifestRecord>();

        for(AssemblerManifestRecord record : oldManifest) {
            AssemblerManifestRecord manifestRecord = record.deepClone();
            if (manifestRecord instanceof ProfileManifestRecord) {
                if (manifestRecord.getIsDocumented()) {
                    documentedPermissions.add((ProfileManifestRecord)manifestRecord);
                }
                if (manifestRecord.selected) {
                    selectedPermissions.add((ProfileManifestRecord)manifestRecord);
                }
            }
            else if ( record.getIsUndocumented() ) {
                undocumentedComponents.add( manifestRecord );
            }
            else if( manifestRecord.getBuildComponent().Type__c == AssemblerManifestRecord.REMOVED ) {
                manifestRecord.isRemoved = true;
                manifest.add( manifestRecord );
            }
            else {
                manifest.add( manifestRecord );
            }
        }

        rebuildProfiles();

        selectedPermissions.sort();
        documentedPermissions.sort();
        undocumentedPermissions.sort();
    }

    private void resetUnappliedProfileChanges() {
        Map<String, ProfileManifestRecord> profileMap = new Map<String, ProfileManifestRecord>();

        for (ProfileManifestRecord profile : selectedPermissions) {
            profileMap.put(profile.profileName, profile);
        }

         for (ProfileManifestRecord profile : documentedPermissions) {
            profile.selected = profileMap.containsKey(profile.profileName);
        }

        for (ProfileManifestRecord profile : undocumentedPermissions) {
            profile.selected = profileMap.containsKey(profile.profileName);
        }
    }

    /**
    * Populate documented and undocumented profiles lists when loading an existing build.
    */
    private void loadExistingProfiles(List<ProfileManifestRecord> savedProfiles) {
        undocumentedPermissions = AssemblerServices.getUndocumentedProfiles(releaseId);
        documentedPermissions   = AssemblerServices.getDocumentedProfiles(releaseId);
        Map<String, ProfileManifestRecord> savedProfilesMap = new Map<String, ProfileManifestRecord>();

        for (ProfileManifestRecord profile : savedProfiles) {
            savedProfilesMap.put(profile.profileName, profile);
        }
        for (Integer i = 0; i < undocumentedPermissions.size(); i++) {
            String profileName = undocumentedPermissions[i].profileName;
            if (savedProfilesMap.containsKey( profileName )) {
                undocumentedPermissions[i] = savedProfilesMap.get( profileName );
            }
        }

        for (Integer i = 0; i < documentedPermissions.size(); i++) {
            String profileName = documentedPermissions[i].profileName;
            if (savedProfilesMap.containsKey( profileName )) {
                documentedPermissions[i] = savedProfilesMap.get( profileName );
            }
        }
    }

    /**
    * Populate undocumented profiles list for a rebuild. This
    * depends on the selectedPermissions already being populated
    */
    private void rebuildProfiles() {
        Map<String, ProfileManifestRecord> selectedMap = new Map<String, ProfileManifestRecord>();
        for (ProfileManifestRecord selectedPermission : selectedPermissions) {
            selectedMap.put(selectedPermission.profileName, selectedPermission);
        }
        Map<String, ProfileManifestRecord> documentedMap = new Map<String, ProfileManifestRecord>();
        for (ProfileManifestRecord documentedPermission : documentedPermissions) {
            documentedMap.put(documentedPermission.profileName, documentedPermission);
        }

        undocumentedPermissions = new List<ProfileManifestRecord>();
        for (ProfileManifestRecord undocumentedProfile : AssemblerServices.getUndocumentedProfiles(releaseId)) {
            undocumentedProfile.selected = selectedMap.containsKey(undocumentedProfile.profileName);
            if (!documentedMap.containsKey(undocumentedProfile.profileName)) {
                undocumentedPermissions.add(undocumentedProfile);
            }
        }

        Map<String, ProfileManifestRecord> undocumentedMap = new Map<String, ProfileManifestRecord>();
        for (ProfileManifestRecord undocumentedPermission : undocumentedPermissions) {
            undocumentedMap.put(undocumentedPermission.profileName, undocumentedPermission);
        }

        for (ProfileManifestRecord manifestRecord : AssemblerServices.getDocumentedProfiles(releaseId)) {
            manifestRecord.selected = selectedMap.containsKey(manifestRecord.profileName);
            if (!documentedMap.containsKey(manifestRecord.profileName) && !undocumentedMap.containsKey(manifestRecord.profileName)) {
                undocumentedPermissions.add(manifestRecord);
            }
        }
    }

    private void populateFilters() {
        backlogFilters = new List<BacklogFilter>();
        instanceFilters = new List<SelectOption>();
        statusFilters = new List<SelectOption>();
        typeFilters = new List<SelectOption>();

        for(Instances__c instance : InstanceServices.getAllInstances()) {
            instanceFilters.add( new SelectOption(instance.Id, instance.Name) );
        }

        for( String cType : AssemblerServices.getComponentTypes() ) {
            typeFilters.add( new SelectOption(cType, cType) );
        }

        statusFilters = AssemblerServices.getBacklogStatusesAsSelectOptions();

        for( Backlog__c backlogItem : AssemblerServices.getRelatedBacklogItems(releaseId) ) {
            backlogFilters.add( new BacklogFilter( backlogItem) );
        }
    }

    private Boolean hasSelectedFilters(List<String> selectedBacklogFilters) {
        return !selectedInstanceFilters.isEmpty()
            || !selectedTypeFilters.isEmpty()
            || !selectedStatusFilters.isEmpty()
            || !selectedBacklogFilters.isEmpty();
    }

    public class BacklogFilter {

        public Boolean isSelected {get; set;}
        public String id {get; private set;}
        public String name {get; private set;}
        public String recordTypeName {get; private set;}

        public BacklogFilter(Backlog__c backlogItem) {
            id = backlogItem.Id;
            isSelected = false;
            name = backlogItem.Name;
            recordTypeName = backlogItem.RecordType.Name;
        }
    }
}
