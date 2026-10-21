// /**
//  * Author     : Sivam V
//  * Class Name : LeadReassignController
//  * Purpose    : Apex controller for the Lead Reassigner screen (leadReassign LWC).
//  *              Lets a Team Leader see the leads of the users below them, filter those leads
//  *              and move them evenly to one or more users. Recovery leads also get the field
//  *              changes their new owner's profile needs. Leads that fail to save are returned
//  *              with the reason, and every reassignment run is logged to Apex_Log__c
//  *              (Request_Type__c = 'LeadReassignController'). When a run completes, its report
//  *              is emailed to the MIS Sales and Pre-Sales TL users, the Salesforce Admin user
//  *              and the fixed report addresses (sivam.v@adissia.com).
//  * Date       : 15/10/2026
//  */
// public without sharing class LeadReassignController {

//     private static final Id RECOVERY_RECORD_TYPE_ID  = '012IS000000c3OBYAY';
//     private static final Id PRE_SALES_RECORD_TYPE_ID = '012IS000000c1dOYAQ';
//     private static final Id SVC_RECORD_TYPE_ID       = '012fu000001AprtAAC';

//     private static final String  REASSIGN_LOG_REQUEST_TYPE = 'LeadReassignController';
//     private static final Integer LOG_TEXT_LIMIT            = 32768;
//     private static final String  LOG_TIME_FORMAT           = 'dd/MM/yyyy hh:mm:ss a';
//     private static final String  LOG_TIME_ZONE             = 'Asia/Kolkata';

//     private static final Set<String> REPORT_RECIPIENT_PROFILE_NAMES    = new Set<String>{ 'MIS Sales', 'Pre-Sales TL', 'CRE Head' };
//     private static final String      REPORT_DEFAULT_RECIPIENT_USER_NAME = '';
//     private static final Set<String> REPORT_FIXED_RECIPIENT_EMAILS      = new Set<String>{ }; // 'sivam.v@adissia.com'
//     private static final String      REPORT_EMAIL_SUBJECT               = 'Lead Reassignment Report';
// /**
//      * Returns the active users the logged-in user can move leads between:
//      * every user in a role below the logged-in user's role, plus the logged-in user.
//      * @return active users, sorted by name
//      */
//     @AuraEnabled(cacheable=true)
//     public static List<User> getUsers() {
//         Id currentUserId = UserInfo.getUserId();
//         User currentUser = [SELECT UserRoleId FROM User WHERE Id = :currentUserId LIMIT 1];

//         Set<Id> subordinateRoleIds = getSubordinateRoleIds(currentUser.UserRoleId);
//         subordinateRoleIds.remove(currentUser.UserRoleId);

//         return [SELECT Id, Name FROM User WHERE IsActive = true AND (UserRoleId IN :subordinateRoleIds OR Id = :currentUserId) ORDER BY Name];
//     }
    

//     /**
//      * Collects every role below the given role, at any depth.
//      * @param parentRoleId role to start from
//      * @return Ids of all roles under that role
//      */
//     private static Set<Id> getSubordinateRoleIds(Id parentRoleId) {
//         Map<Id, UserRole> userRoleById = new Map<Id, UserRole>([SELECT Id, ParentRoleId FROM UserRole]);

//         Set<Id> subordinateRoleIds = new Set<Id>();
//         collectChildRoleIds(parentRoleId, userRoleById, subordinateRoleIds);
//         return subordinateRoleIds;
//     }

//     /**
//      * Adds the direct child roles of a role to the collected set, then does the same for each child.
//      * @param parentRoleId       role whose child roles are collected
//      * @param userRoleById       all roles in the org, by Id
//      * @param subordinateRoleIds role Ids collected so far (filled in by this method)
//      */
//     private static void collectChildRoleIds(Id parentRoleId, Map<Id, UserRole> userRoleById, Set<Id> subordinateRoleIds) {
//         for (UserRole userRole : userRoleById.values()) {
//             if (userRole.ParentRoleId == parentRoleId && !subordinateRoleIds.contains(userRole.Id)) {
//                 subordinateRoleIds.add(userRole.Id);
//                 collectChildRoleIds(userRole.Id, userRoleById, subordinateRoleIds);
//             }
//         }
//     }

//     /**
//      * Returns the active values of the Lead Status picklist, for the Lead Status filter.
//      * @return active Lead Status values
//      */
//     @AuraEnabled(cacheable=true)
//     public static List<String> getLeadStatusPicklistValues() {
//         return getActivePicklistValues(Lead.Lead_Status__c.getDescribe().getPicklistValues());
//     }

//     /**
//      * Returns the active values of the Drop Off Reasons picklist, for the Drop Off Reasons filter.
//      * @return active Drop Off Reasons values
//      */
//     @AuraEnabled(cacheable=true)
//     public static List<String> getDropOffReasonsPicklistValues() {
//         return getActivePicklistValues(Lead.Drop_off_Reasons__c.getDescribe().getPicklistValues());
//     }

//     /**
//      * Keeps only the active entries of a picklist.
//      * @param picklistEntries all entries of the picklist
//      * @return values of the active entries, in picklist order
//      */
//     private static List<String> getActivePicklistValues(List<Schema.PicklistEntry> picklistEntries) {
//         List<String> activePicklistValues = new List<String>();
//         for (Schema.PicklistEntry picklistEntry : picklistEntries) {
//             if (picklistEntry.isActive()) {
//                 activePicklistValues.add(picklistEntry.getValue());
//             }
//         }
//         return activePicklistValues;
//     }

//     /**
//      * Returns the distinct Allocated Project values on the selected users' leads,
//      * for the Allocated Projects filter. For a Recovery status, only leads that have been in
//      * recovery for at least the days in the Recovery_Reassign_Days label are counted.
//      * @param ownerIds users whose leads are checked (the From Users)
//      * @param status   selected Lead Status, or 'ALL'
//      * @return allocated project values, sorted
//      */
//     @AuraEnabled
//     public static List<String> getAllocatedProjects(List<Id> ownerIds, String status) {
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return new List<String>();
//         }

//         Integer recoveryReassignDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//         Date recoveryCutoffDate = Date.today().addDays(-recoveryReassignDays);

//         String allocatedProjectQuery = 'SELECT Allocated_Project__c FROM Lead WHERE OwnerId IN :ownerIds AND Allocated_Project__c != null';
//         if (String.isNotBlank(status) && status != 'ALL') allocatedProjectQuery += ' AND Lead_Status__c = :status';

//         if (status == 'Recovery - Pre Sales') {
//             allocatedProjectQuery += ' AND Unqualified_Date__c <= :recoveryCutoffDate';
//         } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//             allocatedProjectQuery += ' AND Closed_Lost_Date__c <= :recoveryCutoffDate';
//         }
//         allocatedProjectQuery += ' GROUP BY Allocated_Project__c ORDER BY Allocated_Project__c';

//         Set<String> allocatedProjects = new Set<String>();
//         for (AggregateResult projectResult : Database.query(allocatedProjectQuery)) {
//             String allocatedProject = (String) projectResult.get('Allocated_Project__c');
//             if (String.isNotBlank(allocatedProject)) allocatedProjects.add(allocatedProject);
//         }
//         return new List<String>(allocatedProjects);
//     }

//     /**
//      * Returns one page of the selected users' leads, with all the screen's filters applied,
//      * plus the total number of matching leads for the page count.
//      * For a Recovery status, only leads that have been in recovery for at least the days in the
//      * Recovery_Reassign_Days label are shown, and the Recovery From / To dates filter on the
//      * Unqualified Date (Recovery - Pre Sales) or the Closed Lost Date (Recovery - Sales / SVC).
//      * @param ownerIds   users whose leads are listed (the From Users)
//      * @param fromDate   Recovery From Date, or null
//      * @param toDate     Recovery To Date, or null
//      * @param status     selected Lead Status, or 'ALL'
//      * @param dropStatus selected Drop Off Reasons, or empty
//      * @param projects   selected Allocated Projects, or empty
//      * @param searchKey  part of a Lead ID to search for, or blank
//      * @param pageSize   leads per page (50 when not given)
//      * @param pageNumber page to return, starting at 1
//      * @return the leads on the page and the total number of matching leads
//      */
//     @AuraEnabled
//     public static LeadResult getLeadsByOwner(List<Id> ownerIds, Date fromDate, Date toDate, String status, List<String> dropStatus, List<String> projects, String searchKey, Integer pageSize, Integer pageNumber) {
//         try {
//             if (ownerIds == null || ownerIds.isEmpty()) {
//                 return new LeadResult(new List<Lead>(), 0);
//             }

//             Integer recoveryReassignDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//             Date recoveryCutoffDate = Date.today().addDays(-recoveryReassignDays);

//             if (pageSize == null || pageSize <= 0) pageSize = 50;
//             if (pageNumber == null || pageNumber < 1) pageNumber = 1;
//             Integer recordOffset = (pageNumber - 1) * pageSize;

//             Boolean hasDropOffReasonFilter = dropStatus != null && !dropStatus.isEmpty();
//             Boolean hasProjectFilter = projects != null && !projects.isEmpty();
//             String leadIdSearchPattern = '%' + searchKey + '%';

//             // Filters shared by the lead list and the lead count
//             String leadFilterClause = ' WHERE OwnerId IN :ownerIds';
//             if (hasDropOffReasonFilter) leadFilterClause += ' AND Drop_off_Reasons__c IN :dropStatus';
//             if (hasProjectFilter) leadFilterClause += ' AND Allocated_Project__c IN :projects';
//             if (String.isNotBlank(status) && status != 'ALL') leadFilterClause += ' AND Lead_Status__c = :status';
//             if (String.isNotBlank(searchKey)) leadFilterClause += ' AND Lead_ID__c LIKE :leadIdSearchPattern';

//             String leadQuery = 'SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId, Allocated_Project__c, Drop_off_Reasons__c, FORMAT(Unqualified_Date__c), FORMAT(Closed_Lost_Date__c) FROM Lead' + leadFilterClause;
//             String leadCountQuery = 'SELECT COUNT() FROM Lead' + leadFilterClause;

//             if (status == 'Recovery - Pre Sales') {
//                 String unqualifiedDateClause = ' AND Unqualified_Date__c <= :recoveryCutoffDate';
//                 if (fromDate != null) unqualifiedDateClause += ' AND Unqualified_Date__c >= :fromDate';
//                 if (toDate != null) unqualifiedDateClause += ' AND Unqualified_Date__c <= :toDate';

//                 leadQuery += unqualifiedDateClause + ' ORDER BY Unqualified_Date__c DESC';
//                 leadCountQuery += unqualifiedDateClause;
//             } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//                 String closedLostDateRangeClause = '';
//                 if (fromDate != null) closedLostDateRangeClause += ' AND Closed_Lost_Date__c >= :fromDate';
//                 if (toDate != null) closedLostDateRangeClause += ' AND Closed_Lost_Date__c <= :toDate';

//                 // The lead list applies the recovery cut-off only when no date range is given; the count always applies it
//                 String listRecoveryCutoffClause = (fromDate == null && toDate == null) ? ' AND Closed_Lost_Date__c <= :recoveryCutoffDate' : '';
//                 leadQuery += listRecoveryCutoffClause + closedLostDateRangeClause + ' ORDER BY Closed_Lost_Date__c DESC';
//                 leadCountQuery += ' AND Closed_Lost_Date__c <= :recoveryCutoffDate' + closedLostDateRangeClause;
//             } else {
//                 leadQuery += ' ORDER BY CreatedDate DESC';
//             }
//             leadQuery += ' LIMIT :pageSize OFFSET :recordOffset';

//             List<Lead> matchingLeads = Database.query(leadQuery);
//             Integer totalLeadCount = Database.countQuery(leadCountQuery);
//             return new LeadResult(matchingLeads, totalLeadCount);
//         } catch (Exception caughtException) {
//             System.debug('getLeadsByOwner error: ' + caughtException.getMessage() + ' | ' + caughtException.getStackTraceString());
//             return new LeadResult(new List<Lead>(), 0);
//         }
//     }

//     /**
//      * Finds the selected users' leads whose Lead ID contains the search text.
//      * @param ownerIds   users whose leads are searched
//      * @param searchKey  part of a Lead ID
//      * @param limitCount maximum number of leads to return (100 when not given)
//      * @return matching leads, newest first
//      */
//     @AuraEnabled
//     public static List<Lead> searchLeadsByLeadId(List<Id> ownerIds, String searchKey, Integer limitCount) {
//         if (ownerIds == null || ownerIds.isEmpty() || String.isBlank(searchKey)) {
//             return new List<Lead>();
//         }
//         if (limitCount == null || limitCount <= 0) limitCount = 100;

//         String leadIdSearchPattern = '%' + searchKey + '%';
//         return [SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId FROM Lead WHERE OwnerId IN :ownerIds AND Lead_ID__c LIKE :leadIdSearchPattern ORDER BY CreatedDate DESC LIMIT :limitCount];
//     }

//     /**
//      * Reassigns the given leads round robin across the given users, in the order the leads are
//      * received: lead 1 to user 1, lead 2 to user 2, and back to user 1 after the last user.
//      * The screen uses reassignLeadsWithOwnerMap; this method is kept for callers that send
//      * a plain list of users.
//      * @param leadIds     leads to reassign
//      * @param newOwnerIds users to share the leads between
//      */
//     @AuraEnabled
//     public static void reassignLeads(List<Id> leadIds, List<Id> newOwnerIds) {
//         if (leadIds == null || leadIds.isEmpty() || newOwnerIds == null || newOwnerIds.isEmpty()) {
//             return;
//         }

//         Map<Id, Id> newOwnerIdByLeadId = new Map<Id, Id>();
//         for (Id leadId : leadIds) {
//             if (!newOwnerIdByLeadId.containsKey(leadId)) {
//                 Integer ownerPosition = Math.mod(newOwnerIdByLeadId.size(), newOwnerIds.size());
//                 newOwnerIdByLeadId.put(leadId, newOwnerIds[ownerPosition]);
//             }
//         }
//         applyReassignment(newOwnerIdByLeadId);
//     }

//     /**
//      * Reassigns each lead to the owner the screen chose for it. The screen decides every
//      * lead's owner before it sends the leads in batches, so the split stays even for any
//      * number of users.
//      * @param leadOwnerMap new owner Id for each lead Id, for one batch
//      * @return one message per lead that failed to save, as "Lead ID: reason"
//      */
//     @AuraEnabled
//     public static List<String> reassignLeadsWithOwnerMap(Map<String, String> leadOwnerMap) {
//         if (leadOwnerMap == null || leadOwnerMap.isEmpty()) {
//             return new List<String>();
//         }

//         Map<Id, Id> newOwnerIdByLeadId = new Map<Id, Id>();
//         for (String leadId : leadOwnerMap.keySet()) {
//             String newOwnerId = leadOwnerMap.get(leadId);
//             if (String.isNotBlank(leadId) && String.isNotBlank(newOwnerId)) {
//                 newOwnerIdByLeadId.put(Id.valueOf(leadId), Id.valueOf(newOwnerId));
//             }
//         }
//         return applyReassignment(newOwnerIdByLeadId);
//     }

//     /**
//      * Moves each lead to its new owner and stamps who reassigned it and when. Recovery leads
//      * also get the changes their new owner's profile needs (see applyRecoveryLeadRules).
//      * Saves with partial success, so one lead that fails does not stop the others.
//      * @param newOwnerIdByLeadId new owner Id for each lead Id
//      * @return one message per lead that failed to save, as "Lead ID: reason"
//      */
//     private static List<String> applyReassignment(Map<Id, Id> newOwnerIdByLeadId) {
//         List<String> failureMessages = new List<String>();
//         if (newOwnerIdByLeadId == null || newOwnerIdByLeadId.isEmpty()) {
//             return failureMessages;
//         }

//         Set<Id> leadIds = newOwnerIdByLeadId.keySet();
//         Set<Id> newOwnerIds = new Set<Id>(newOwnerIdByLeadId.values());
//         Id currentUserId = UserInfo.getUserId();

//         List<Lead> leadsToReassign = [SELECT Id, OwnerId, RecordTypeId, Lead_Status__c, Is_Unqualified__c, Unqualified_Date__c, Unqualified_Lost_By__c, Unqualified_Reason__c, Recovery_Reassigned_Date__c, Recovery_User__c, Lead_ID__c, Lead_ReAssigned_Date__c, Previous_Presales_user__c, Reassigned_By__c, Lead_ReAssigned_Dates__c, Owner.Name FROM Lead WHERE Id IN :leadIds];
//         Map<Id, User> newOwnerById = new Map<Id, User>([SELECT Id, Profile.Name FROM User WHERE Id IN :newOwnerIds]);

//         for (Lead leadToReassign : leadsToReassign) {
//             Id newOwnerId = newOwnerIdByLeadId.get(leadToReassign.Id);
//             String previousOwnerName = leadToReassign.Owner.Name;
//             User newOwner = newOwnerById.get(newOwnerId);
//             String newOwnerProfileName = (newOwner != null) ? newOwner.Profile.Name : '';

//             leadToReassign.Previous_Presales_user__c = leadToReassign.OwnerId;
//             leadToReassign.OwnerId                   = newOwnerId;
//             leadToReassign.Lead_ReAssigned_Dates__c  = System.now();
//             leadToReassign.Reassigned_By__c          = currentUserId;
//             leadToReassign.Last_Reassigned_Date__c   = System.now();
//             leadToReassign.Last_Reassigner_Name__c   = currentUserId;

//             applyRecoveryLeadRules(leadToReassign, newOwnerProfileName, previousOwnerName);
//         }

//         if (!leadsToReassign.isEmpty()) {
//             List<Database.SaveResult> saveResults = Database.update(leadsToReassign, false);
//             for (Integer resultIndex = 0; resultIndex < saveResults.size(); resultIndex++) {
//                 if (!saveResults[resultIndex].isSuccess()) {
//                     List<Database.Error> saveErrors = saveResults[resultIndex].getErrors();
//                     String errorMessage = saveErrors.isEmpty() ? 'Unknown error' : saveErrors[0].getMessage();
//                     failureMessages.add(leadsToReassign[resultIndex].Lead_ID__c + ': ' + errorMessage);
//                 }
//             }
//         }
//         return failureMessages;
//     }

//     /**
//      * Extra changes for a lead on the Recovery record type, based on its new owner's profile:
//      *   Recovery  - stays a Recovery lead; the reassignment and push details are stamped.
//      *   Pre Sales - becomes a Pre Sales lead in "Unable to connect"; unqualified details are cleared.
//      *   SVC Team  - becomes an SVC lead in "Allocate to SVC"; unqualified details are cleared.
//      * Leads on any other record type, or moved to any other profile, only change owner.
//      * @param leadToReassign      lead being reassigned (changed in place)
//      * @param newOwnerProfileName profile name of the new owner
//      * @param previousOwnerName   name of the owner before this reassignment
//      */
//     private static void applyRecoveryLeadRules(Lead leadToReassign, String newOwnerProfileName, String previousOwnerName) {
//         if (leadToReassign.RecordTypeId != RECOVERY_RECORD_TYPE_ID) {
//             return;
//         }

//         if (newOwnerProfileName == 'Recovery') {
//             leadToReassign.Lead_ReAssigned_Date__c = Date.today();
//             leadToReassign.Previous_Lead_owner__c  = previousOwnerName;
//             leadToReassign.Is_Lead_ReAssigned__c   = true;
//             stampRecoveryPush(leadToReassign);
//         } else if (newOwnerProfileName == 'Pre Sales') {
//             leadToReassign.RecordTypeId            = PRE_SALES_RECORD_TYPE_ID;
//             leadToReassign.Lead_Status__c          = 'Unable to connect';
//             leadToReassign.Lead_ReAssigned_Date__c = Date.today();
//             leadToReassign.Previous_Lead_owner__c  = previousOwnerName;
//             leadToReassign.Is_Lead_ReAssigned__c   = true;
//             clearUnqualifiedDetails(leadToReassign);
//             stampRecoveryPush(leadToReassign);
//         } else if (newOwnerProfileName == 'SVC Team') {
//             leadToReassign.RecordTypeId   = SVC_RECORD_TYPE_ID;
//             leadToReassign.Lead_Status__c = 'Allocate to SVC';
//             clearUnqualifiedDetails(leadToReassign);
//             stampRecoveryPush(leadToReassign);
//         }
//     }

//     /**
//      * Stamps when a Recovery lead was reassigned and pushed, and by whom.
//      * @param leadToReassign lead being reassigned (changed in place)
//      */
//     private static void stampRecoveryPush(Lead leadToReassign) {
//         leadToReassign.Recovery_Reassigned_Date__c = Date.today();
//         leadToReassign.Pushed_On__c                = System.now();
//         leadToReassign.Pushed_By__c                = UserInfo.getUserId();
//     }

//     /**
//      * Clears the unqualified details of a Recovery lead that goes back into the Pre Sales or SVC flow.
//      * @param leadToReassign lead being reassigned (changed in place)
//      */
//     private static void clearUnqualifiedDetails(Lead leadToReassign) {
//         leadToReassign.Is_Unqualified__c      = false;
//         leadToReassign.Unqualified_Date__c    = null;
//         leadToReassign.Unqualified_Lost_By__c = null;
//         leadToReassign.Unqualified_Reason__c  = null;
//     }

//     /**
//      * Creates the Apex_Log__c record for a reassignment run, before the first batch is sent.
//      * The log stays IN PROGRESS until completeReassignmentLog runs, so a log left IN PROGRESS
//      * means the page was closed before the run finished.
//      * @param requestJson run details from the screen: From / To users, filters and lead counts
//      * @return Id of the new log record
//      */
//     @AuraEnabled
//     public static Id startReassignmentLog(String requestJson) {
//         Apex_Log__c reassignmentLog = new Apex_Log__c();
//         reassignmentLog.Request_Type__c = REASSIGN_LOG_REQUEST_TYPE;
//         reassignmentLog.Status__c       = 'IN PROGRESS';

//         try {
//             ReassignRequestWrapper runRequest = String.isBlank(requestJson) ? new ReassignRequestWrapper() : (ReassignRequestWrapper) JSON.deserialize(requestJson, ReassignRequestWrapper.class);
//             runRequest.reassignedBy   = UserInfo.getName();
//             runRequest.reassignedById = UserInfo.getUserId();
//             runRequest.startedAt      = System.now().format(LOG_TIME_FORMAT, LOG_TIME_ZONE);
//             reassignmentLog.Request__c = limitLogText(JSON.serializePretty(runRequest));
//         } catch (Exception caughtException) {
//             reassignmentLog.Request__c       = limitLogText(requestJson);
//             reassignmentLog.Error_Message__c = limitLogText('Request could not be read: ' + caughtException.getMessage());
//         }

//         new ReassignmentLogWriter().saveLog(reassignmentLog);
//         return reassignmentLog.Id;
//     }

//     /**
//      * Completes the run log once the last batch has finished. The result is read back from
//      * the leads themselves (not taken from the screen): how many were reassigned, how many
//      * failed, how many stayed with the same owner, and how many each owner received.
//      * Status becomes SUCCESS, PARTIAL (some leads failed) or FAIL (no lead was reassigned).
//      * The run report is then emailed to the report recipients; an email problem is noted in
//      * the response and never changes the log status.
//      * @param logId           Id returned by startReassignmentLog
//      * @param leadIds         every lead sent for reassignment in this run
//      * @param failureMessages failed leads with their reason, as returned by the batches
//      */
//     @AuraEnabled
//     public static void completeReassignmentLog(Id logId, List<Id> leadIds, List<String> failureMessages) {
//         if (logId == null) {
//             return;
//         }

//         ReassignmentLogWriter logWriter = new ReassignmentLogWriter();
//         Apex_Log__c reassignmentLog = logWriter.getLog(logId);
//         if (reassignmentLog == null) {
//             return;
//         }

//         List<String> failedLeadMessages = (failureMessages == null) ? new List<String>() : failureMessages;
//         Set<Id> sentLeadIds = (leadIds == null) ? new Set<Id>() : new Set<Id>(leadIds);

//         try {
//             Map<String, Integer> leadCountByOwnerName = new Map<String, Integer>();
//             Integer reassignedLeadCount = 0;
//             Integer sameOwnerLeadCount = 0;

//             for (Lead reassignedLead : logWriter.getReassignedLeads(sentLeadIds, reassignmentLog.CreatedDate, UserInfo.getUserId())) {
//                 reassignedLeadCount++;
//                 String ownerName = (reassignedLead.Owner != null) ? reassignedLead.Owner.Name : String.valueOf(reassignedLead.OwnerId);
//                 Integer ownerLeadCount = leadCountByOwnerName.containsKey(ownerName) ? leadCountByOwnerName.get(ownerName) : 0;
//                 leadCountByOwnerName.put(ownerName, ownerLeadCount + 1);
//                 if (String.valueOf(reassignedLead.OwnerId) == reassignedLead.Previous_Presales_user__c) sameOwnerLeadCount++;
//             }

//             ReassignResponseWrapper runResult = new ReassignResponseWrapper();
//             runResult.completedAt        = System.now().format(LOG_TIME_FORMAT, LOG_TIME_ZONE);
//             runResult.leadsSent          = sentLeadIds.size();
//             runResult.leadsReassigned    = reassignedLeadCount;
//             runResult.leadsFailed        = sentLeadIds.size() - reassignedLeadCount;
//             runResult.leadsKeptSameOwner = sameOwnerLeadCount;
//             runResult.splitByOwner       = leadCountByOwnerName;

//             if (reassignedLeadCount == 0 && (!sentLeadIds.isEmpty() || !failedLeadMessages.isEmpty())) {
//                 reassignmentLog.Status__c = 'FAIL';
//             } else if (runResult.leadsFailed > 0 || !failedLeadMessages.isEmpty()) {
//                 reassignmentLog.Status__c = 'PARTIAL';
//             } else {
//                 reassignmentLog.Status__c = 'SUCCESS';
//             }

//             if (!failedLeadMessages.isEmpty()) {
//                 String earlierErrorMessage = String.isBlank(reassignmentLog.Error_Message__c) ? '' : reassignmentLog.Error_Message__c + '\n';
//                 reassignmentLog.Error_Message__c = limitLogText(earlierErrorMessage + String.join(failedLeadMessages, '\n'));
//             }

//             // A run that sent nothing and failed nothing has no report to email
//             if (!sentLeadIds.isEmpty() || !failedLeadMessages.isEmpty()) {
//                 sendReassignmentReport(reassignmentLog, readRunRequest(reassignmentLog.Request__c), runResult, failedLeadMessages);
//             }
//             reassignmentLog.Response__c = limitLogText(JSON.serializePretty(runResult));
//         } catch (Exception caughtException) {
//             reassignmentLog.Response__c      = limitLogText(caughtException.getStackTraceString());
//             reassignmentLog.Status__c        = 'FAIL';
//             reassignmentLog.Error_Message__c = limitLogText(caughtException.getMessage() + (failedLeadMessages.isEmpty() ? '' : '\n' + String.join(failedLeadMessages, '\n')));
//         }

//         logWriter.saveLog(reassignmentLog);
//     }

//     /**
//      * Cuts log text to the size the Apex_Log__c long text fields can hold.
//      * @param logText text to save
//      * @return the text, cut to 32,768 characters when longer
//      */
//     private static String limitLogText(String logText) {
//         if (logText == null) return null;
//         return (logText.length() > LOG_TEXT_LIMIT) ? logText.left(LOG_TEXT_LIMIT) : logText;
//     }

//     /**
//      * Reads the run details saved by startReassignmentLog back from the log.
//      * @param requestJson Apex_Log__c.Request__c of the run
//      * @return the run details, or empty details when the text cannot be read
//      */
//     private static ReassignRequestWrapper readRunRequest(String requestJson) {
//         try {
//             if (String.isNotBlank(requestJson)) {
//                 return (ReassignRequestWrapper) JSON.deserialize(requestJson, ReassignRequestWrapper.class);
//             }
//         } catch (Exception caughtException) {
//             System.debug('readRunRequest error: ' + caughtException.getMessage());
//         }
//         return new ReassignRequestWrapper();
//     }

//     /**
//      * Emails the run report to the report recipients (see getReportRecipientEmails).
//      * The addresses the report went to, or the reason it could not be sent, are noted in the
//      * run result so they appear in Apex_Log__c.Response__c. This method never throws.
//      * @param reassignmentLog    the run's log, with its final status
//      * @param runRequest         run details: From / To users and filters
//      * @param runResult          run result: lead counts and the split by owner (updated in place)
//      * @param failedLeadMessages failed leads with their reason
//      */
//     private static void sendReassignmentReport(Apex_Log__c reassignmentLog, ReassignRequestWrapper runRequest, ReassignResponseWrapper runResult, List<String> failedLeadMessages) {
//         try {
//             List<String> recipientEmails = getReportRecipientEmails();
//             if (recipientEmails.isEmpty()) {
//                 runResult.reportEmailError = 'No active user found for the report recipient profiles';
//                 return;
//             }

//             Messaging.SingleEmailMessage reportEmail = new Messaging.SingleEmailMessage();
//             reportEmail.setToAddresses(recipientEmails);
//             reportEmail.setSubject(REPORT_EMAIL_SUBJECT + ' - ' + reassignmentLog.Status__c + ' - ' + runResult.leadsReassigned + ' of ' + runResult.leadsSent + ' leads reassigned by ' + UserInfo.getName());
//             reportEmail.setHtmlBody(buildReportHtml(reassignmentLog, runRequest, runResult, failedLeadMessages));
//             reportEmail.setSaveAsActivity(false);

//             List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ reportEmail }, false);
//             if (sendResults[0].isSuccess()) {
//                 runResult.reportEmailedTo = recipientEmails;
//             } else {
//                 runResult.reportEmailError = sendResults[0].getErrors().isEmpty() ? 'Email could not be sent' : sendResults[0].getErrors()[0].getMessage();
//             }
//         } catch (Exception caughtException) {
//             runResult.reportEmailError = caughtException.getMessage();
//         }
//     }

//     /**
//      * Returns the email addresses the run report is sent to: every active user on the
//      * MIS Sales and Pre-Sales TL profiles, the Salesforce Admin user, and the fixed report
//      * addresses that always receive it.
//      * @return recipient email addresses, without duplicates
//      */
//     private static List<String> getReportRecipientEmails() {
//         Set<String> recipientEmails = new Set<String>(REPORT_FIXED_RECIPIENT_EMAILS);
//         for (User recipient : [SELECT Email FROM User WHERE IsActive = true AND (Profile.Name IN :REPORT_RECIPIENT_PROFILE_NAMES OR Name = :REPORT_DEFAULT_RECIPIENT_USER_NAME)]) {
//             if (String.isNotBlank(recipient.Email)) recipientEmails.add(recipient.Email.toLowerCase());
//         }
//         return new List<String>(recipientEmails);
//     }

//     /**
//      * Builds the HTML body of the run report: run summary, filters, From / To users,
//      * leads received per user, failed leads with their reason, and a link to the log record.
//      * @param reassignmentLog    the run's log, with its final status
//      * @param runRequest         run details: From / To users and filters
//      * @param runResult          run result: lead counts and the split by owner
//      * @param failedLeadMessages failed leads with their reason
//      * @return the report as HTML
//      */
//     private static String buildReportHtml(Apex_Log__c reassignmentLog, ReassignRequestWrapper runRequest, ReassignResponseWrapper runResult, List<String> failedLeadMessages) {
//         ReassignFilterWrapper filters = (runRequest.filters == null) ? new ReassignFilterWrapper() : runRequest.filters;
//         List<String> fromUsers = (runRequest.fromUsers == null) ? new List<String>() : runRequest.fromUsers;
//         List<String> toUsers   = (runRequest.toUsers == null) ? new List<String>() : runRequest.toUsers;
//         String logUrl = URL.getOrgDomainUrl().toExternalForm() + '/' + reassignmentLog.Id;

//         String reportHtml = '<div style="font-family:Arial,sans-serif;font-size:13px;color:#222222">';
//         reportHtml += '<h2 style="margin:0 0 10px 0">' + REPORT_EMAIL_SUBJECT + '</h2>';

//         reportHtml += '<table cellpadding="5" cellspacing="0" style="border-collapse:collapse">';
//         reportHtml += buildReportRow('Status', reassignmentLog.Status__c);
//         reportHtml += buildReportRow('Reassigned By', UserInfo.getName());
//         reportHtml += buildReportRow('Started At', runRequest.startedAt);
//         reportHtml += buildReportRow('Completed At', runResult.completedAt);
//         reportHtml += buildReportRow('Lead Status Filter', filters.leadStatus);
//         reportHtml += buildReportRow('Drop Off Reasons', joinReportValues(filters.dropOffReasons));
//         reportHtml += buildReportRow('Allocated Projects', joinReportValues(filters.allocatedProjects));
//         reportHtml += buildReportRow('Lead ID Search', filters.searchKey);
//         reportHtml += buildReportRow('Recovery From Date', filters.recoveryFromDate);
//         reportHtml += buildReportRow('Recovery To Date', filters.recoveryToDate);
//         reportHtml += buildReportRow('Leads Sent', String.valueOf(runResult.leadsSent));
//         reportHtml += buildReportRow('Leads Reassigned', String.valueOf(runResult.leadsReassigned));
//         reportHtml += buildReportRow('Leads Failed', String.valueOf(runResult.leadsFailed));
//         reportHtml += buildReportRow('Leads Kept Same Owner', String.valueOf(runResult.leadsKeptSameOwner));
//         reportHtml += '</table>';

//         reportHtml += '<h3 style="margin:16px 0 4px 0">From Users (' + fromUsers.size() + ')</h3><p style="margin:0">' + formatReportValue(joinReportValues(fromUsers)) + '</p>';
//         reportHtml += '<h3 style="margin:16px 0 4px 0">To Users (' + toUsers.size() + ')</h3><p style="margin:0">' + formatReportValue(joinReportValues(toUsers)) + '</p>';

//         List<String> ownerNames = new List<String>(runResult.splitByOwner.keySet());
//         ownerNames.sort();
//         reportHtml += '<h3 style="margin:16px 0 4px 0">Leads Received Per User (' + ownerNames.size() + ')</h3>';
//         if (ownerNames.isEmpty()) {
//             reportHtml += '<p style="margin:0">-</p>';
//         } else {
//             reportHtml += '<table cellpadding="5" cellspacing="0" style="border-collapse:collapse"><tr><th style="border:1px solid #cccccc;text-align:left">User</th><th style="border:1px solid #cccccc;text-align:right">Leads</th></tr>';
//             for (String ownerName : ownerNames) {
//                 reportHtml += '<tr><td style="border:1px solid #cccccc">' + ownerName.escapeHtml4() + '</td><td style="border:1px solid #cccccc;text-align:right">' + runResult.splitByOwner.get(ownerName) + '</td></tr>';
//             }
//             reportHtml += '</table>';
//         }

//         reportHtml += '<h3 style="margin:16px 0 4px 0">Failed Leads (' + runResult.leadsFailed + ')</h3>';
//         if (failedLeadMessages.isEmpty()) {
//             reportHtml += '<p style="margin:0">' + ((runResult.leadsFailed > 0) ? runResult.leadsFailed + ' lead(s) were not reassigned and no reason was returned' : 'None') + '</p>';
//         } else {
//             reportHtml += '<ul style="margin:0">';
//             for (String failedLeadMessage : failedLeadMessages) {
//                 reportHtml += '<li>' + failedLeadMessage.escapeHtml4() + '</li>';
//             }
//             reportHtml += '</ul>';
//         }

//         reportHtml += '<p style="margin:16px 0 0 0">Log record: <a href="' + logUrl + '">' + reassignmentLog.Name + '</a></p>';
//         reportHtml += '</div>';
//         return reportHtml;
//     }

//     /**
//      * Builds one label / value row of the report summary table.
//      * @param label row label
//      * @param value row value; blank values are shown as "-"
//      * @return the row as HTML
//      */
//     private static String buildReportRow(String label, String value) {
//         return '<tr><td style="border:1px solid #cccccc;font-weight:bold">' + label + '</td><td style="border:1px solid #cccccc">' + formatReportValue(value) + '</td></tr>';
//     }

//     /**
//      * Makes a value safe to show in the report.
//      * @param value value to show
//      * @return the value escaped for HTML, or "-" when blank
//      */
//     private static String formatReportValue(String value) {
//         return String.isBlank(value) ? '-' : value.escapeHtml4();
//     }

//     /**
//      * Joins a list of values for the report.
//      * @param values values to join
//      * @return the values separated by commas, or blank when there are none
//      */
//     private static String joinReportValues(List<String> values) {
//         return (values == null || values.isEmpty()) ? '' : String.join(values, ', ');
//     }

//     /**
//      * Reads and saves the reassignment log without sharing, so the log can always be saved and
//      * the read-back sees every reassigned lead, even leads now owned by users outside the
//      * Team Leader's own view.
//      */
//     private without sharing class ReassignmentLogWriter {

//         /**
//          * Returns the log record, or null when it no longer exists.
//          * @param logId Id of the log record
//          * @return the log record with its name, created date, saved run details and any earlier error message
//          */
//         public Apex_Log__c getLog(Id logId) {
//             List<Apex_Log__c> reassignmentLogs = [SELECT Id, Name, CreatedDate, Request__c, Error_Message__c FROM Apex_Log__c WHERE Id = :logId LIMIT 1];
//             return reassignmentLogs.isEmpty() ? null : reassignmentLogs[0];
//         }

//         /**
//          * Returns the leads from this run that the current user reassigned after the log was created.
//          * @param sentLeadIds    leads sent for reassignment in this run
//          * @param runStartedAt   when the run's log was created
//          * @param reassignedById the Team Leader who ran the reassignment
//          * @return the reassigned leads with their current owner and previous owner
//          */
//         public List<Lead> getReassignedLeads(Set<Id> sentLeadIds, DateTime runStartedAt, Id reassignedById) {
//             if (sentLeadIds == null || sentLeadIds.isEmpty()) return new List<Lead>();
//             return [SELECT Id, OwnerId, Owner.Name, Previous_Presales_user__c FROM Lead WHERE Id IN :sentLeadIds AND Last_Reassigned_Date__c >= :runStartedAt AND Last_Reassigner_Name__c = :reassignedById];
//         }

//         /**
//          * Inserts a new log record or updates an existing one.
//          * @param reassignmentLog log record to save
//          */
//         public void saveLog(Apex_Log__c reassignmentLog) {
//             upsert reassignmentLog;
//         }
//     }

//     /**
//      * One page of leads for the screen, with the total number of matching leads.
//      */
//     public class LeadResult {
//         @AuraEnabled public List<Lead> leads      { get; set; }
//         @AuraEnabled public Integer    totalCount { get; set; }

//         /**
//          * @param leads      leads on the page
//          * @param totalCount total number of matching leads
//          */
//         public LeadResult(List<Lead> leads, Integer totalCount) {
//             this.leads      = leads;
//             this.totalCount = totalCount;
//         }
//     }

//     /**
//      * Run details saved in Apex_Log__c.Request__c.
//      */
//     public class ReassignRequestWrapper {
//         public String       reassignedBy;
//         public String       reassignedById;
//         public String       startedAt;
//         public List<String> fromUsers;
//         public List<String> toUsers;
//         public ReassignFilterWrapper filters;
//         public Integer      leadsSelected;
//         public Integer      leadsToReassign;
//         public Integer      batchSize;
//     }

//     /**
//      * Filters the Team Leader used on the screen for the run.
//      */
//     public class ReassignFilterWrapper {
//         public String       leadStatus;
//         public List<String> dropOffReasons;
//         public List<String> allocatedProjects;
//         public String       searchKey;
//         public String       recoveryFromDate;
//         public String       recoveryToDate;
//     }

//     /**
//      * Run result saved in Apex_Log__c.Response__c, including where the report email went.
//      */
//     public class ReassignResponseWrapper {
//         public String               completedAt;
//         public Integer              leadsSent;
//         public Integer              leadsReassigned;
//         public Integer              leadsFailed;
//         public Integer              leadsKeptSameOwner;
//         public Map<String, Integer> splitByOwner;
//         public List<String>         reportEmailedTo;
//         public String               reportEmailError;
//     }
// }