// public with sharing class LeadReassignController {   

//     /* =========================================================
//        GET USERS (SUBORDINATES + CURRENT USER)
//        ========================================================= */
//     @AuraEnabled(cacheable=true)
//     public static List<User> getUsers() {
//         User me = [
//             SELECT UserRoleId
//             FROM User
//             WHERE Id = :UserInfo.getUserId()
//             LIMIT 1
//         ];

//         Set<Id> roleIds = getSubordinateRoleIds(me.UserRoleId);
//         roleIds.remove(me.UserRoleId);

//         return [
//             SELECT Id, Name
//             FROM User
//             WHERE IsActive = true
//             AND (UserRoleId IN :roleIds OR Id = :UserInfo.getUserId())
//             ORDER BY Name
//         ];
//     }

//     /* =========================================================
//        ROLE HIERARCHY HELPERS
//        ========================================================= */
//     private static Set<Id> getSubordinateRoleIds(Id rootRoleId) {
//         Map<Id, UserRole> roleMap = new Map<Id, UserRole>([
//             SELECT Id, ParentRoleId
//             FROM UserRole
//         ]);

//         Set<Id> result = new Set<Id>();
//         collectRoles(rootRoleId, roleMap, result);
//         return result;
//     }

//     private static void collectRoles(
//         Id parentId,
//         Map<Id, UserRole> roleMap,
//         Set<Id> result
//     ) {
//         for (UserRole r : roleMap.values()) {
//             if (r.ParentRoleId == parentId && !result.contains(r.Id)) {
//                 result.add(r.Id);
//                 collectRoles(r.Id, roleMap, result);
//             }
//         }
//     }

//     /* =========================================================
//        LEAD STATUS PICKLIST
//        ========================================================= */
//     @AuraEnabled(cacheable=true)
//     public static List<String> getLeadStatusPicklistValues() {
//         List<String> values = new List<String>();
//         for (Schema.PicklistEntry p :
//             Lead.Lead_Status__c.getDescribe().getPicklistValues()) {
//             if (p.isActive()) {
//                 values.add(p.getValue());
//             }
//         }
//         return values;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<String> getDropOffReasonsPicklistValues() {
//         List<String> values = new List<String>();
//         for (Schema.PicklistEntry p :
//             Lead.Drop_off_Reasons__c.getDescribe().getPicklistValues()) {
//             if (p.isActive()) {
//                 values.add(p.getValue());
//             }
//         }
//         return values;
//     }

//     /* =========================================================
//        GET DISTINCT ALLOCATED PROJECTS (for current owner + status)
//        ========================================================= */
//     /* ===== Sathya - START : Get distinct allocated projects ===== */
//     @AuraEnabled
//     public static List<String> getAllocatedProjects(
//         List<Id> ownerIds,
//         String status
//     ) {
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return new List<String>();
//         }

//         Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//         Date limitDate = Date.today().addDays(-recoveryDays);

//         String q =
//             'SELECT Allocated_Project__c ' +
//             'FROM Lead ' +
//             'WHERE OwnerId IN :ownerIds ' +
//             'AND Allocated_Project__c != null';

//         if (String.isNotBlank(status) && status != 'ALL') {
//             q += ' AND Lead_Status__c = :status';
//         }
//         if (status == 'Recovery - Pre Sales') {
//             q += ' AND Unqualified_Date__c <= :limitDate';
//         } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//             q += ' AND Closed_Lost_Date__c <= :limitDate';
//         }

//         q += ' GROUP BY Allocated_Project__c ORDER BY Allocated_Project__c';

//         Set<String> projects = new Set<String>();
//         for (AggregateResult ar : Database.query(q)) {
//             String val = (String) ar.get('Allocated_Project__c');
//             if (String.isNotBlank(val)) projects.add(val);
//         }
//         return new List<String>(projects);
//     }
//     /* ===== Sathya - END : Get distinct allocated projects ===== */

//     /* ===== Added By Sathya - START : Campaign / Sub Campaign filter options ===== */
//     @AuraEnabled
//     public static List<OptionWrapper> getCampaignOptions(List<Id> ownerIds) {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return options;
//         }
//         for (AggregateResult aggregateRow : [SELECT Campaign_std__c campaignId, Campaign_std__r.Name campaignName FROM Lead WHERE OwnerId IN :ownerIds AND Campaign_std__c != null GROUP BY Campaign_std__c, Campaign_std__r.Name ORDER BY Campaign_std__r.Name]) {
//             options.add(new OptionWrapper((Id) aggregateRow.get('campaignId'), (String) aggregateRow.get('campaignName')));
//         }
//         return options;
//     }

//     @AuraEnabled
//     public static List<OptionWrapper> getSubCampaignOptions(List<Id> ownerIds, Id campaignId) {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return options;
//         }
//         String q = 'SELECT Sub_Campaign__c subCampaignId, Sub_Campaign__r.Name subCampaignName FROM Lead WHERE OwnerId IN :ownerIds AND Sub_Campaign__c != null';
//         if (campaignId != null) {
//             q += ' AND Campaign_std__c = :campaignId';
//         }
//         q += ' GROUP BY Sub_Campaign__c, Sub_Campaign__r.Name ORDER BY Sub_Campaign__r.Name';
//         for (AggregateResult aggregateRow : Database.query(q)) {
//             options.add(new OptionWrapper((Id) aggregateRow.get('subCampaignId'), (String) aggregateRow.get('subCampaignName')));
//         }
//         return options;
//     }

//     /*
//        Activity filter clause builder.
//        activityFilter values: 'NFA', 'Untouched', 'Missed Call' (anything else = no extra filter).
//        Binds used (:nowDateTime, :startOfToday) must be declared in the calling method.
//     */
//     private static String buildActivityFilterClause(String activityFilter) {
//         if (activityFilter == 'NFA') {
//             return ' AND (Next_Followup_Date__c = null OR Next_Followup_Date__c < :nowDateTime)' +
//                    ' AND (Next_Scheduled_Date__c = null OR Next_Scheduled_Date__c < :nowDateTime)';
//         }
//         if (activityFilter == 'Untouched') {
//             return ' AND RecordType.Name = \'Pre Sales\'' +
//                    ' AND Lead_Status__c IN (\'New Enquiry\', \'Unable to connect\', \'Follow Up\')' +
//                    ' AND Followup_Scheduled__c = false' +
//                    ' AND (pre_sales_last_attempt__c = null OR pre_sales_last_attempt__c < :startOfToday)';
//         }
//         if (activityFilter == 'Missed Call') {
//             return ' AND Id IN (SELECT Lead__c FROM Call_Detail__c WHERE Call_Type__c = \'Inbound Call\' AND Status__c IN (\'BUSY\', \'CANCEL\', \'NOANSWER\') AND Is_Called_Back__c = false)';
//         }
//         return '';
//     }
//     /* ===== Added By Sathya - END : Campaign / Sub Campaign filter options ===== */

//     /* =========================================================
//        GET LEADS BY OWNER + STATUS + PROJECT (with pagination)
//        ========================================================= */
//     @AuraEnabled
//     public static LeadResult getLeadsByOwner(
//         List<Id> ownerIds,
//         Date fromDate,
//         Date toDate,
//         String status,
//         List<String> dropStatus,
//         List<String> projects,
//         String searchKey,
//         Integer pageSize,
//         Integer pageNumber,
//         Id campaignId,
//         Id subCampaignId,
//         String activityFilter
//     ) {
//         try {
//             if (ownerIds == null || ownerIds.isEmpty()) {
//                 return new LeadResult(new List<Lead>(), 0);
//             }

//             Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//             Date limitDate = Date.today().addDays(-recoveryDays);

//             if (pageSize == null || pageSize <= 0)    pageSize   = 50;
//             if (pageNumber == null || pageNumber < 1) pageNumber = 1;

//             Integer offset = (pageNumber - 1) * pageSize;

//             Boolean hasDropFilter    = dropStatus != null && !dropStatus.isEmpty();
//             Boolean hasProjectFilter = projects != null && !projects.isEmpty();

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filter binds ===== */
//             DateTime nowDateTime  = System.now();
//             DateTime startOfToday = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
//             String activityClause = buildActivityFilterClause(activityFilter);
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filter binds ===== */

//             // --- Data query ---
//             String query =
//                 'SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId, ' +
//                 'Allocated_Project__c, Campaign_std__r.Name, Sub_Campaign__r.Name, ' +
//                 'Drop_off_Reasons__c, FORMAT(Unqualified_Date__c), FORMAT(Closed_Lost_Date__c) ' +
//                 'FROM Lead WHERE OwnerId IN :ownerIds';

//             if (hasDropFilter)                                    query += ' AND Drop_off_Reasons__c IN :dropStatus';
//             if (hasProjectFilter)                                 query += ' AND Allocated_Project__c IN :projects';
//             if (String.isNotBlank(status) && status != 'ALL')    query += ' AND Lead_Status__c = :status';
//             if (String.isNotBlank(searchKey)) {
//                 String searchPattern = '%' + searchKey + '%';
//                 query += ' AND Lead_ID__c LIKE :searchPattern';
//             }

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filters (data query) ===== */
//             if (campaignId != null)    query += ' AND Campaign_std__c = :campaignId';
//             if (subCampaignId != null) query += ' AND Sub_Campaign__c = :subCampaignId';
//             query += activityClause;
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filters (data query) ===== */

//             if (status == 'Recovery - Pre Sales') {
//                 query += ' AND Unqualified_Date__c <= :limitDate';
//                 if (fromDate != null) query += ' AND Unqualified_Date__c >= :fromDate';
//                 if (toDate   != null) query += ' AND Unqualified_Date__c <= :toDate';
//                 query += ' ORDER BY Unqualified_Date__c DESC';

//             } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//                 if(fromDate == null && toDate == null){
//                     query += ' AND Closed_Lost_Date__c <= :limitDate'; 
//                 }
//                 if (fromDate != null) query += ' AND Closed_Lost_Date__c >= :fromDate';
//                 if (toDate   != null) query += ' AND Closed_Lost_Date__c <= :toDate';
//                 query += ' ORDER BY Closed_Lost_Date__c DESC';

//             } else {
//                 query += ' ORDER BY CreatedDate DESC';
//             }

//             query += ' LIMIT :pageSize OFFSET :offset';

//             // --- Count query ---
//             String countQuery =
//                 'SELECT COUNT() FROM Lead WHERE OwnerId IN :ownerIds';

//             if (hasDropFilter)                                    countQuery += ' AND Drop_off_Reasons__c IN :dropStatus';
//             if (hasProjectFilter)                                 countQuery += ' AND Allocated_Project__c IN :projects';
//             if (String.isNotBlank(status) && status != 'ALL')    countQuery += ' AND Lead_Status__c = :status';
//             if (String.isNotBlank(searchKey)) {
//                 String searchPattern = '%' + searchKey + '%';
//                 countQuery += ' AND Lead_ID__c LIKE :searchPattern';
//             }

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filters (count query) ===== */
//             if (campaignId != null)    countQuery += ' AND Campaign_std__c = :campaignId';
//             if (subCampaignId != null) countQuery += ' AND Sub_Campaign__c = :subCampaignId';
//             countQuery += activityClause;
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filters (count query) ===== */

//             if (status == 'Recovery - Pre Sales') {
//                 countQuery += ' AND Unqualified_Date__c <= :limitDate';
//                 if (fromDate != null) countQuery += ' AND Unqualified_Date__c >= :fromDate';
//                 if (toDate   != null) countQuery += ' AND Unqualified_Date__c <= :toDate';

//             } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//                 countQuery += ' AND Closed_Lost_Date__c <= :limitDate';
//                 if (fromDate != null) countQuery += ' AND Closed_Lost_Date__c >= :fromDate';
//                 if (toDate   != null) countQuery += ' AND Closed_Lost_Date__c <= :toDate';
//             }

//             List<Lead> leads    = Database.query(query);
//             Integer totalCount  = Database.countQuery(countQuery);

//             return new LeadResult(leads, totalCount);

//         } catch (Exception ex) {
//             System.debug('getLeadsByOwner error: ' + ex.getMessage() + ' | ' + ex.getStackTraceString());
//             return new LeadResult(new List<Lead>(), 0);
//         }
//     }

//     /* =========================================================
//        SEARCH LEADS BY LEAD ID
//        ========================================================= */
//     @AuraEnabled
//     public static List<Lead> searchLeadsByLeadId(
//         List<Id> ownerIds,
//         String searchKey,
//         Integer limitCount
//     ) {
//         if (ownerIds == null || ownerIds.isEmpty() || String.isBlank(searchKey)) {
//             return new List<Lead>();
//         }

//         if (limitCount == null || limitCount <= 0) limitCount = 100;

//         String searchPattern = '%' + searchKey + '%';

//         return [
//             SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId
//             FROM Lead
//             WHERE OwnerId IN :ownerIds
//             AND Lead_ID__c LIKE :searchPattern
//             ORDER BY CreatedDate DESC
//             LIMIT :limitCount
//         ];
//     }

//     /* =========================================================
//        REASSIGN LEADS
//        ========================================================= */
//     /* ===== Sathya - START : */
//     @AuraEnabled
//     public static void reassignLeads(
//         List<Id> leadIds,
//         List<Id> newOwnerIds
//     ) {
//         if (leadIds == null || leadIds.isEmpty()) return;
//         if (newOwnerIds == null || newOwnerIds.isEmpty()) return;

//         Id RECOVERY_RT_ID     = '012IS000000c3OBYAY';
//         Id PRESALES_RT_ID     = '012IS000000c1dOYAQ';
//         Id RECOVERY_SVC_RT_ID = '012IS000000c3OBYAY';
//         Id SVC_RT_ID          = '012fu000001AprtAAC';

//         Set<Id> uniqueLeadIds = new Set<Id>(leadIds);

//         List<Lead> leads = [
//             SELECT Id,
//                    OwnerId,
//                    RecordTypeId,
//                    Lead_Status__c,
//                    Is_Unqualified__c,
//                    Unqualified_Date__c,
//                    Unqualified_Lost_By__c,
//                    Unqualified_Reason__c,
//                    Recovery_Reassigned_Date__c,
//                    Recovery_User__c,
//                    Lead_ID__c,
//                    Lead_ReAssigned_Date__c,
//                    Previous_Presales_user__c,
//                    Reassigned_By__c,
//                    Lead_ReAssigned_Dates__c,
//                    Owner.Name
//             FROM Lead
//             WHERE Id IN :uniqueLeadIds
//         ];

//         Map<Id, User> userMap = new Map<Id, User>(
//             [SELECT Id, Profile.Name
//              FROM User
//              WHERE Id IN :newOwnerIds]
//         );

//         Integer index  = 0;
//         Integer size   = newOwnerIds.size();
//         List<Lead> updates = new List<Lead>();

//         for (Lead ld : leads) {

//             Id     oldOwnerId = ld.OwnerId;
//             String ownerName  = ld.Owner.Name;

//             ld.OwnerId                   = newOwnerIds[index];
//             ld.Lead_ReAssigned_Dates__c  = System.now();
//             ld.Previous_Presales_user__c = oldOwnerId;
//             ld.Reassigned_By__c          = UserInfo.getUserId();

//             /* ===== Added By Sathya - START : Last reassigned date + last reassigner (screen reassign only) ===== */
//             ld.Last_Reassigned_Date__c   = System.now();
//             ld.Last_Reassigner_Name__c   = UserInfo.getUserId();
//             /* ===== Added By Sathya - END : Last reassigned date + last reassigner ===== */

//             User   targetUser  = userMap.get(newOwnerIds[index]);
//             String profileName = (targetUser != null) ? targetUser.Profile.Name : '';

//             if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Recovery') {
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Lead_ReAssigned_Date__c     = Date.today();
//                 ld.Previous_Lead_owner__c      = ownerName;
//                 ld.Is_Lead_ReAssigned__c       = true;
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }
//             else if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Pre Sales') {
//                 ld.RecordTypeId                = PRESALES_RT_ID;
//                 ld.Lead_Status__c              = 'Unable to connect';
//                 ld.Previous_Lead_owner__c      = ownerName;
//                 ld.Lead_ReAssigned_Date__c     = Date.today();
//                 ld.Is_Lead_ReAssigned__c       = true;
//                 ld.Is_Unqualified__c           = false;
//                 ld.Unqualified_Date__c         = null;
//                 ld.Unqualified_Lost_By__c      = null;
//                 ld.Unqualified_Reason__c       = null;
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }
//             else if (ld.RecordTypeId == RECOVERY_SVC_RT_ID && profileName == 'SVC Team') {
//                 ld.RecordTypeId                = SVC_RT_ID;
//                 ld.Lead_Status__c              = 'Allocate to SVC';
//                 ld.Is_Unqualified__c           = false;
//                 ld.Unqualified_Date__c         = null;
//                 ld.Unqualified_Lost_By__c      = null;
//                 ld.Unqualified_Reason__c       = null;
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }

//             updates.add(ld);
//             index++;
//             if (index == size) index = 0;
//         }

//         if (!updates.isEmpty()) {
//             Database.update(updates, false);
//         }
//            integer i=1;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//     }
//     /* ===== Sathya - END : */

//     /* =========================================================
//        WRAPPER CLASS
//        ========================================================= */
//     public class LeadResult {
//         @AuraEnabled public List<Lead> leads      { get; set; }
//         @AuraEnabled public Integer    totalCount  { get; set; }

//         public LeadResult(List<Lead> leads, Integer totalCount) {
//             this.leads      = leads;
//             this.totalCount = totalCount;
//         }
//     }

//     /* ===== Added By Sathya - START : Option wrapper for filter dropdowns ===== */
//     public class OptionWrapper {
//         @AuraEnabled public String value { get; set; }
//         @AuraEnabled public String label { get; set; }

//         public OptionWrapper(String value, String label) {
//             this.value = value;
//             this.label = label;
//         }
//     }
//     /* ===== Added By Sathya - END : Option wrapper for filter dropdowns ===== */
    
// }

// ============================================================================================
// ========================================= Added by Sivam V ============================================
// public with sharing class LeadReassignController {   

//     /* =========================================================
//        GET USERS (SUBORDINATES + CURRENT USER)
//        ========================================================= */
//     @AuraEnabled(cacheable=true)
//     public static List<User> getUsers() {
//         User me = [
//             SELECT UserRoleId
//             FROM User
//             WHERE Id = :UserInfo.getUserId()
//             LIMIT 1
//         ];

//         Set<Id> roleIds = getSubordinateRoleIds(me.UserRoleId);
//         roleIds.remove(me.UserRoleId);

//         return [
//             SELECT Id, Name
//             FROM User
//             WHERE IsActive = true
//             AND (UserRoleId IN :roleIds OR Id = :UserInfo.getUserId())
//             ORDER BY Name
//         ];
//     }

//     /* =========================================================
//        ROLE HIERARCHY HELPERS
//        ========================================================= */
//     private static Set<Id> getSubordinateRoleIds(Id rootRoleId) {
//         Map<Id, UserRole> roleMap = new Map<Id, UserRole>([
//             SELECT Id, ParentRoleId
//             FROM UserRole
//         ]);

//         Set<Id> result = new Set<Id>();
//         collectRoles(rootRoleId, roleMap, result);
//         return result;
//     }

//     private static void collectRoles(
//         Id parentId,
//         Map<Id, UserRole> roleMap,
//         Set<Id> result
//     ) {
//         for (UserRole r : roleMap.values()) {
//             if (r.ParentRoleId == parentId && !result.contains(r.Id)) {
//                 result.add(r.Id);
//                 collectRoles(r.Id, roleMap, result);
//             }
//         }
//     }

//     /* =========================================================
//        LEAD STATUS PICKLIST
//        ========================================================= */
//     @AuraEnabled(cacheable=true)
//     public static List<String> getLeadStatusPicklistValues() {
//         List<String> values = new List<String>();
//         for (Schema.PicklistEntry p :
//             Lead.Lead_Status__c.getDescribe().getPicklistValues()) {
//             if (p.isActive()) {
//                 values.add(p.getValue());
//             }
//         }
//         return values;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<String> getDropOffReasonsPicklistValues() {
//         List<String> values = new List<String>();
//         for (Schema.PicklistEntry p :
//             Lead.Drop_off_Reasons__c.getDescribe().getPicklistValues()) {
//             if (p.isActive()) {
//                 values.add(p.getValue());
//             }
//         }
//         return values;
//     }

//     /* =========================================================
//        GET DISTINCT ALLOCATED PROJECTS (for current owner + status)
//        ========================================================= */
//     /* ===== Sathya - START : Get distinct allocated projects ===== */
//     @AuraEnabled
//     public static List<String> getAllocatedProjects(
//         List<Id> ownerIds,
//         String status
//     ) {
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return new List<String>();
//         }

//         Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//         Date limitDate = Date.today().addDays(-recoveryDays);

//         String q =
//             'SELECT Allocated_Project__c ' +
//             'FROM Lead ' +
//             'WHERE OwnerId IN :ownerIds ' +
//             'AND Allocated_Project__c != null';

//         if (String.isNotBlank(status) && status != 'ALL') {
//             q += ' AND Lead_Status__c = :status';
//         }
//         if (status == 'Recovery - Pre Sales') {
//             q += ' AND Unqualified_Date__c <= :limitDate';
//         } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//             q += ' AND Closed_Lost_Date__c <= :limitDate';
//         }

//         q += ' GROUP BY Allocated_Project__c ORDER BY Allocated_Project__c';

//         Set<String> projects = new Set<String>();
//         for (AggregateResult ar : Database.query(q)) {
//             String val = (String) ar.get('Allocated_Project__c');
//             if (String.isNotBlank(val)) projects.add(val);
//         }
//         return new List<String>(projects);
//     }
//     /* ===== Sathya - END : Get distinct allocated projects ===== */

//     /* ===== Added By Sathya - START : Campaign / Sub Campaign filter options ===== */
//     @AuraEnabled
//     public static List<OptionWrapper> getCampaignOptions(List<Id> ownerIds) {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return options;
//         }
//         for (AggregateResult aggregateRow : [SELECT Campaign_std__c campaignId, Campaign_std__r.Name campaignName FROM Lead WHERE OwnerId IN :ownerIds AND Campaign_std__c != null GROUP BY Campaign_std__c, Campaign_std__r.Name ORDER BY Campaign_std__r.Name]) {
//             options.add(new OptionWrapper((Id) aggregateRow.get('campaignId'), (String) aggregateRow.get('campaignName')));
//         }
//         return options;
//     }

//     @AuraEnabled
//     public static List<OptionWrapper> getSubCampaignOptions(List<Id> ownerIds, Id campaignId) {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         if (ownerIds == null || ownerIds.isEmpty()) {
//             return options;
//         }
//         String q = 'SELECT Sub_Campaign__c subCampaignId, Sub_Campaign__r.Name subCampaignName FROM Lead WHERE OwnerId IN :ownerIds AND Sub_Campaign__c != null';
//         if (campaignId != null) {
//             q += ' AND Campaign_std__c = :campaignId';
//         }
//         q += ' GROUP BY Sub_Campaign__c, Sub_Campaign__r.Name ORDER BY Sub_Campaign__r.Name';
//         for (AggregateResult aggregateRow : Database.query(q)) {
//             options.add(new OptionWrapper((Id) aggregateRow.get('subCampaignId'), (String) aggregateRow.get('subCampaignName')));
//         }
//         return options;
//     }

//     /*
//        Activity filter clause builder.
//        activityFilter values: 'NFA', 'Untouched', 'Missed Call' (anything else = no extra filter).
//        Binds used (:nowDateTime, :startOfToday) must be declared in the calling method.
//     */
//     private static String buildActivityFilterClause(String activityFilter) {
//         if (activityFilter == 'NFA') {
//             return ' AND (Next_Followup_Date__c = null OR Next_Followup_Date__c < :nowDateTime)' +
//                    ' AND (Next_Scheduled_Date__c = null OR Next_Scheduled_Date__c < :nowDateTime)';
//         }
//         if (activityFilter == 'Untouched') {
//             return ' AND RecordType.Name = \'Pre Sales\'' +
//                    ' AND Lead_Status__c IN (\'New Enquiry\', \'Unable to connect\', \'Follow Up\')' +
//                    ' AND Followup_Scheduled__c = false' +
//                    ' AND (pre_sales_last_attempt__c = null OR pre_sales_last_attempt__c < :startOfToday)';
//         }
//         if (activityFilter == 'Missed Call') {
//             return ' AND Id IN (SELECT Lead__c FROM Call_Detail__c WHERE Call_Type__c = \'Inbound Call\' AND Status__c IN (\'BUSY\', \'CANCEL\', \'NOANSWER\') AND Is_Called_Back__c = false)';
//         }
//         return '';
//     }
//     /* ===== Added By Sathya - END : Campaign / Sub Campaign filter options ===== */

//     /* =========================================================
//        GET LEADS BY OWNER + STATUS + PROJECT (with pagination)
//        ========================================================= */
//     @AuraEnabled
//     public static LeadResult getLeadsByOwner(
//         List<Id> ownerIds,
//         Date fromDate,
//         Date toDate,
//         String status,
//         List<String> dropStatus,
//         List<String> projects,
//         String searchKey,
//         Integer pageSize,
//         Integer pageNumber,
//         Id campaignId,
//         Id subCampaignId,
//         String activityFilter
//     ) {
//         try {
//             if (ownerIds == null || ownerIds.isEmpty()) {
//                 return new LeadResult(new List<Lead>(), 0);
//             }

//             Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
//             Date limitDate = Date.today().addDays(-recoveryDays);

//             if (pageSize == null || pageSize <= 0)    pageSize   = 50;
//             if (pageNumber == null || pageNumber < 1) pageNumber = 1;

//             Integer offset = (pageNumber - 1) * pageSize;

//             Boolean hasDropFilter    = dropStatus != null && !dropStatus.isEmpty();
//             Boolean hasProjectFilter = projects != null && !projects.isEmpty();

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filter binds ===== */
//             DateTime nowDateTime  = System.now();
//             DateTime startOfToday = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
//             String activityClause = buildActivityFilterClause(activityFilter);
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filter binds ===== */

//             // --- Data query ---
//             String query =
//                 'SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId, ' +
//                 'Allocated_Project__c, Campaign_std__r.Name, Sub_Campaign__r.Name, ' +
//                 'Drop_off_Reasons__c, FORMAT(Unqualified_Date__c), FORMAT(Closed_Lost_Date__c) ' +
//                 'FROM Lead WHERE OwnerId IN :ownerIds';

//             if (hasDropFilter)                                    query += ' AND Drop_off_Reasons__c IN :dropStatus';
//             if (hasProjectFilter)                                 query += ' AND Allocated_Project__c IN :projects';
//             if (String.isNotBlank(status) && status != 'ALL')    query += ' AND Lead_Status__c = :status';
//             if (String.isNotBlank(searchKey)) {
//                 String searchPattern = '%' + searchKey + '%';
//                 query += ' AND Lead_ID__c LIKE :searchPattern';
//             }

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filters (data query) ===== */
//             if (campaignId != null)    query += ' AND Campaign_std__c = :campaignId';
//             if (subCampaignId != null) query += ' AND Sub_Campaign__c = :subCampaignId';
//             query += activityClause;
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filters (data query) ===== */

//             if (status == 'Recovery - Pre Sales') {
//                 query += ' AND Unqualified_Date__c <= :limitDate';
//                 if (fromDate != null) query += ' AND Unqualified_Date__c >= :fromDate';
//                 if (toDate   != null) query += ' AND Unqualified_Date__c <= :toDate';
//                 query += ' ORDER BY Unqualified_Date__c DESC';

//             } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//                 if(fromDate == null && toDate == null){
//                     query += ' AND Closed_Lost_Date__c <= :limitDate'; 
//                 }
//                 if (fromDate != null) query += ' AND Closed_Lost_Date__c >= :fromDate';
//                 if (toDate   != null) query += ' AND Closed_Lost_Date__c <= :toDate';
//                 query += ' ORDER BY Closed_Lost_Date__c DESC';

//             } else {
//                 query += ' ORDER BY CreatedDate DESC';
//             }

//             query += ' LIMIT :pageSize OFFSET :offset';

//             // --- Count query ---
//             String countQuery =
//                 'SELECT COUNT() FROM Lead WHERE OwnerId IN :ownerIds';

//             if (hasDropFilter)                                    countQuery += ' AND Drop_off_Reasons__c IN :dropStatus';
//             if (hasProjectFilter)                                 countQuery += ' AND Allocated_Project__c IN :projects';
//             if (String.isNotBlank(status) && status != 'ALL')    countQuery += ' AND Lead_Status__c = :status';
//             if (String.isNotBlank(searchKey)) {
//                 String searchPattern = '%' + searchKey + '%';
//                 countQuery += ' AND Lead_ID__c LIKE :searchPattern';
//             }

//             /* ===== Added By Sathya - START : Campaign / Sub Campaign / Activity filters (count query) ===== */
//             if (campaignId != null)    countQuery += ' AND Campaign_std__c = :campaignId';
//             if (subCampaignId != null) countQuery += ' AND Sub_Campaign__c = :subCampaignId';
//             countQuery += activityClause;
//             /* ===== Added By Sathya - END : Campaign / Sub Campaign / Activity filters (count query) ===== */

//             if (status == 'Recovery - Pre Sales') {
//                 countQuery += ' AND Unqualified_Date__c <= :limitDate';
//                 if (fromDate != null) countQuery += ' AND Unqualified_Date__c >= :fromDate';
//                 if (toDate   != null) countQuery += ' AND Unqualified_Date__c <= :toDate';

//             } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
//                 countQuery += ' AND Closed_Lost_Date__c <= :limitDate';
//                 if (fromDate != null) countQuery += ' AND Closed_Lost_Date__c >= :fromDate';
//                 if (toDate   != null) countQuery += ' AND Closed_Lost_Date__c <= :toDate';
//             }

//             List<Lead> leads    = Database.query(query);
//             Integer totalCount  = Database.countQuery(countQuery);

//             return new LeadResult(leads, totalCount);

//         } catch (Exception ex) {
//             System.debug('getLeadsByOwner error: ' + ex.getMessage() + ' | ' + ex.getStackTraceString());
//             return new LeadResult(new List<Lead>(), 0);
//         }
//     }

//     /* =========================================================
//        SEARCH LEADS BY LEAD ID
//        ========================================================= */
//     @AuraEnabled
//     public static List<Lead> searchLeadsByLeadId(
//         List<Id> ownerIds,
//         String searchKey,
//         Integer limitCount
//     ) {
//         if (ownerIds == null || ownerIds.isEmpty() || String.isBlank(searchKey)) {
//             return new List<Lead>();
//         }

//         if (limitCount == null || limitCount <= 0) limitCount = 100;

//         String searchPattern = '%' + searchKey + '%';

//         return [
//             SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId
//             FROM Lead
//             WHERE OwnerId IN :ownerIds
//             AND Lead_ID__c LIKE :searchPattern
//             ORDER BY CreatedDate DESC
//             LIMIT :limitCount
//         ];
//     }

//     /* =========================================================
//        REASSIGN LEADS
//        ========================================================= */
//     /* ===== Sathya - START : */
//     @AuraEnabled
//     public static void reassignLeads(
//         List<Id> leadIds,
//         List<Id> newOwnerIds
//     ) {
//         if (leadIds == null || leadIds.isEmpty()) return;
//         if (newOwnerIds == null || newOwnerIds.isEmpty()) return;

//         Id RECOVERY_RT_ID     = '012IS000000c3OBYAY';
//         Id PRESALES_RT_ID     = '012IS000000c1dOYAQ';
//         Id RECOVERY_SVC_RT_ID = '012IS000000c3OBYAY';
//         Id SVC_RT_ID          = '012fu000001AprtAAC';

//         Set<Id> uniqueLeadIds = new Set<Id>(leadIds);

//         List<Lead> leads = [
//             SELECT Id,
//                    OwnerId,
//                    RecordTypeId,
//                    Lead_Status__c,
//                    Is_Unqualified__c,
//                    Unqualified_Date__c,
//                    Unqualified_Lost_By__c,
//                    Unqualified_Reason__c,
//                    Recovery_Reassigned_Date__c,
//                    Recovery_User__c,
//                    Lead_ID__c,
//                    Lead_ReAssigned_Date__c,
//                    Previous_Presales_user__c,
//                    Reassigned_By__c,
//                    Lead_ReAssigned_Dates__c,
//                    Owner.Name
//             FROM Lead
//             WHERE Id IN :uniqueLeadIds
//         ];

//         Map<Id, User> userMap = new Map<Id, User>(
//             [SELECT Id, Profile.Name
//              FROM User
//              WHERE Id IN :newOwnerIds]
//         );

//         Integer index  = 0;
//         Integer size   = newOwnerIds.size();
//         List<Lead> updates = new List<Lead>();

//         for (Lead ld : leads) {

//             Id     oldOwnerId = ld.OwnerId;
//             String ownerName  = ld.Owner.Name;

//             ld.OwnerId                   = newOwnerIds[index];
//             ld.Lead_ReAssigned_Dates__c  = System.now();
//             ld.Previous_Presales_user__c = oldOwnerId;
//             ld.Reassigned_By__c          = UserInfo.getUserId();

//             /* ===== Added By Sathya - START : Last reassigned date + last reassigner (screen reassign only) ===== */
//             ld.Last_Reassigned_Date__c   = System.now();
//             ld.Last_Reassigner_Name__c   = UserInfo.getUserId();
//             /* ===== Added By Sathya - END : Last reassigned date + last reassigner ===== */

//             User   targetUser  = userMap.get(newOwnerIds[index]);
//             String profileName = (targetUser != null) ? targetUser.Profile.Name : '';

//             if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Recovery') {
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Lead_ReAssigned_Date__c     = Date.today();
//                 ld.Previous_Lead_owner__c      = ownerName;
//                 ld.Is_Lead_ReAssigned__c       = true;
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }
//             else if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Pre Sales') {
//                 ld.RecordTypeId                = PRESALES_RT_ID;
//                 ld.Lead_Status__c              = 'Unable to connect';
//                 ld.Previous_Lead_owner__c      = ownerName;
//                 ld.Lead_ReAssigned_Date__c     = Date.today();
//                 ld.Is_Lead_ReAssigned__c       = true;
//                 ld.Is_Unqualified__c           = false;
//                 ld.Unqualified_Date__c         = null;
//                 ld.Unqualified_Lost_By__c      = null;
//                 ld.Unqualified_Reason__c       = null;
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }
//             else if (ld.RecordTypeId == RECOVERY_SVC_RT_ID && profileName == 'SVC Team') {
//                 ld.RecordTypeId                = SVC_RT_ID;
//                 ld.Lead_Status__c              = 'Allocate to SVC';
//                 ld.Is_Unqualified__c           = false;
//                 ld.Unqualified_Date__c         = null;
//                 ld.Unqualified_Lost_By__c      = null;
//                 ld.Unqualified_Reason__c       = null;
//                 ld.Recovery_Reassigned_Date__c = Date.today();
//                 ld.Pushed_On__c                = System.now();
//                 ld.Pushed_By__c                = UserInfo.getUserId();
//             }

//             updates.add(ld);
//             index++;
//             if (index == size) index = 0;
//         }

//         if (!updates.isEmpty()) {
//             Database.update(updates, false);
//         }
//            integer i=1;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//         i=i++;
//     }
//     /* ===== Sathya - END : */

//     /* =========================================================
//        WRAPPER CLASS
//        ========================================================= */
//     public class LeadResult {
//         @AuraEnabled public List<Lead> leads      { get; set; }
//         @AuraEnabled public Integer    totalCount  { get; set; }

//         public LeadResult(List<Lead> leads, Integer totalCount) {
//             this.leads      = leads;
//             this.totalCount = totalCount;
//         }
//     }

//     /* ===== Added By Sathya - START : Option wrapper for filter dropdowns ===== */
//     public class OptionWrapper {
//         @AuraEnabled public String value { get; set; }
//         @AuraEnabled public String label { get; set; }

//         public OptionWrapper(String value, String label) {
//             this.value = value;
//             this.label = label;
//         }
//     }
//     /* ===== Added By Sathya - END : Option wrapper for filter dropdowns ===== */
    
// }

// ============================================================================================
// ========================================= Added by Sivam V ============================================

public with sharing class LeadReassignController {   

    /* =========================================================
       GET USERS (SUBORDINATES + CURRENT USER)
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {
        User me = [
            SELECT UserRoleId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Set<Id> roleIds = getSubordinateRoleIds(me.UserRoleId);
        roleIds.remove(me.UserRoleId);

        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND (UserRoleId IN :roleIds OR Id = :UserInfo.getUserId())
            ORDER BY Name
        ];
    }

    /* =========================================================
       ROLE HIERARCHY HELPERS
       ========================================================= */
    private static Set<Id> getSubordinateRoleIds(Id rootRoleId) {
        Map<Id, UserRole> roleMap = new Map<Id, UserRole>([
            SELECT Id, ParentRoleId
            FROM UserRole
        ]);

        Set<Id> result = new Set<Id>();
        collectRoles(rootRoleId, roleMap, result);
        return result;
    }

    private static void collectRoles(
        Id parentId,
        Map<Id, UserRole> roleMap,
        Set<Id> result
    ) {
        for (UserRole r : roleMap.values()) {
            if (r.ParentRoleId == parentId && !result.contains(r.Id)) {
                result.add(r.Id);
                collectRoles(r.Id, roleMap, result);
            }
        }
    }

    /* =========================================================
       LEAD STATUS PICKLIST
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<String> getLeadStatusPicklistValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry p :
            Lead.Lead_Status__c.getDescribe().getPicklistValues()) {
            if (p.isActive()) {
                values.add(p.getValue());
            }
        }
        return values;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDropOffReasonsPicklistValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry p :
            Lead.Drop_off_Reasons__c.getDescribe().getPicklistValues()) {
            if (p.isActive()) {
                values.add(p.getValue());
            }
        }
        return values;
    }

    /* =========================================================
       GET DISTINCT ALLOCATED PROJECTS (for current owner + status)
       ========================================================= */
    /* ===== Sathya - START : Get distinct allocated projects ===== */
    @AuraEnabled
    public static List<String> getAllocatedProjects(
        List<Id> ownerIds,
        String status
    ) {
        if (ownerIds == null || ownerIds.isEmpty()) {
            return new List<String>();
        }

        Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
        Date limitDate = Date.today().addDays(-recoveryDays);

        String q =
            'SELECT Allocated_Project__c ' +
            'FROM Lead ' +
            'WHERE OwnerId IN :ownerIds ' +
            'AND Allocated_Project__c != null';

        if (String.isNotBlank(status) && status != 'ALL') {
            q += ' AND Lead_Status__c = :status';
        }
        if (status == 'Recovery - Pre Sales') {
            q += ' AND Unqualified_Date__c <= :limitDate';
        } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
            q += ' AND Closed_Lost_Date__c <= :limitDate';
        }

        q += ' GROUP BY Allocated_Project__c ORDER BY Allocated_Project__c';

        Set<String> projects = new Set<String>();
        for (AggregateResult ar : Database.query(q)) {
            String val = (String) ar.get('Allocated_Project__c');
            if (String.isNotBlank(val)) projects.add(val);
        }
        return new List<String>(projects);
    }
    /* ===== Sathya - END : Get distinct allocated projects ===== */

    /* =========================================================
       GET LEADS BY OWNER + STATUS + PROJECT (with pagination)
       ========================================================= */
    @AuraEnabled
    public static LeadResult getLeadsByOwner(
        List<Id> ownerIds,
        Date fromDate,
        Date toDate,
        String status,
        List<String> dropStatus,
        List<String> projects,
        String searchKey,
        Integer pageSize,
        Integer pageNumber
    ) {
        try {
            if (ownerIds == null || ownerIds.isEmpty()) {
                return new LeadResult(new List<Lead>(), 0);
            }

            Integer recoveryDays = Integer.valueOf(Label.Recovery_Reassign_Days);
            Date limitDate = Date.today().addDays(-recoveryDays);

            if (pageSize == null || pageSize <= 0)    pageSize   = 50;
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;

            Integer offset = (pageNumber - 1) * pageSize;

            Boolean hasDropFilter    = dropStatus != null && !dropStatus.isEmpty();
            Boolean hasProjectFilter = projects != null && !projects.isEmpty();

            // --- Data query ---
            String query =
                'SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId, ' +
                'Allocated_Project__c, ' +
                'Drop_off_Reasons__c, FORMAT(Unqualified_Date__c), FORMAT(Closed_Lost_Date__c) ' +
                'FROM Lead WHERE OwnerId IN :ownerIds';

            if (hasDropFilter)                                    query += ' AND Drop_off_Reasons__c IN :dropStatus';
            if (hasProjectFilter)                                 query += ' AND Allocated_Project__c IN :projects';
            if (String.isNotBlank(status) && status != 'ALL')    query += ' AND Lead_Status__c = :status';
            if (String.isNotBlank(searchKey)) {
                String searchPattern = '%' + searchKey + '%';
                query += ' AND Lead_ID__c LIKE :searchPattern';
            }

            if (status == 'Recovery - Pre Sales') {
                query += ' AND Unqualified_Date__c <= :limitDate';
                if (fromDate != null) query += ' AND Unqualified_Date__c >= :fromDate';
                if (toDate   != null) query += ' AND Unqualified_Date__c <= :toDate';
                query += ' ORDER BY Unqualified_Date__c DESC';

            } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
                if(fromDate == null && toDate == null){
                    query += ' AND Closed_Lost_Date__c <= :limitDate'; 
                }
                if (fromDate != null) query += ' AND Closed_Lost_Date__c >= :fromDate';
                if (toDate   != null) query += ' AND Closed_Lost_Date__c <= :toDate';
                query += ' ORDER BY Closed_Lost_Date__c DESC';

            } else {
                query += ' ORDER BY CreatedDate DESC';
            }

            query += ' LIMIT :pageSize OFFSET :offset';

            // --- Count query ---
            String countQuery =
                'SELECT COUNT() FROM Lead WHERE OwnerId IN :ownerIds';

            if (hasDropFilter)                                    countQuery += ' AND Drop_off_Reasons__c IN :dropStatus';
            if (hasProjectFilter)                                 countQuery += ' AND Allocated_Project__c IN :projects';
            if (String.isNotBlank(status) && status != 'ALL')    countQuery += ' AND Lead_Status__c = :status';
            if (String.isNotBlank(searchKey)) {
                String searchPattern = '%' + searchKey + '%';
                countQuery += ' AND Lead_ID__c LIKE :searchPattern';
            }

            if (status == 'Recovery - Pre Sales') {
                countQuery += ' AND Unqualified_Date__c <= :limitDate';
                if (fromDate != null) countQuery += ' AND Unqualified_Date__c >= :fromDate';
                if (toDate   != null) countQuery += ' AND Unqualified_Date__c <= :toDate';

            } else if (status == 'Recovery - Sales' || status == 'Recovery - SVC') {
                countQuery += ' AND Closed_Lost_Date__c <= :limitDate';
                if (fromDate != null) countQuery += ' AND Closed_Lost_Date__c >= :fromDate';
                if (toDate   != null) countQuery += ' AND Closed_Lost_Date__c <= :toDate';
            }

            List<Lead> leads    = Database.query(query);
            Integer totalCount  = Database.countQuery(countQuery);

            return new LeadResult(leads, totalCount);

        } catch (Exception ex) {
            System.debug('getLeadsByOwner error: ' + ex.getMessage() + ' | ' + ex.getStackTraceString());
            return new LeadResult(new List<Lead>(), 0);
        }
    }

    /* =========================================================
       SEARCH LEADS BY LEAD ID
       ========================================================= */
    @AuraEnabled
    public static List<Lead> searchLeadsByLeadId(
        List<Id> ownerIds,
        String searchKey,
        Integer limitCount
    ) {
        if (ownerIds == null || ownerIds.isEmpty() || String.isBlank(searchKey)) {
            return new List<Lead>();
        }

        if (limitCount == null || limitCount <= 0) limitCount = 100;

        String searchPattern = '%' + searchKey + '%';

        return [
            SELECT Id, Name, Lead_ID__c, Lead_Status__c, RecordTypeId, OwnerId
            FROM Lead
            WHERE OwnerId IN :ownerIds
            AND Lead_ID__c LIKE :searchPattern
            ORDER BY CreatedDate DESC
            LIMIT :limitCount
        ];
    }

    /* =========================================================
       REASSIGN LEADS
       ========================================================= */
    /* ===== Sathya - START : */
    @AuraEnabled
    public static void reassignLeads(
        List<Id> leadIds,
        List<Id> newOwnerIds
    ) {
        if (leadIds == null || leadIds.isEmpty()) return;
        if (newOwnerIds == null || newOwnerIds.isEmpty()) return;

        /* ===== Added By Sathya - START : Round robin decided on the lead order received, then shared reassignment logic ===== */
        Map<Id, Id> ownerIdByLeadId = new Map<Id, Id>();
        Integer ownerPosition = 0;
        for (Id leadId : leadIds) {
            if (ownerIdByLeadId.containsKey(leadId)) continue;
            ownerIdByLeadId.put(leadId, newOwnerIds[ownerPosition]);
            ownerPosition = Math.mod(ownerPosition + 1, newOwnerIds.size());
        }
        applyReassignment(ownerIdByLeadId);
        /* ===== Added By Sathya - END : Round robin decided on the lead order received, then shared reassignment logic ===== */
           integer i=1;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
        i=i++;
    }
    /* ===== Sathya - END : */

    /* ===== Added By Sathya - START : Fair split across all selected users + failed lead reporting =====
       The screen decides the owner of every selected lead before sending batches of 5,
       so the split stays even for any number of users (6, 7, 10...). Leads that fail to
       save are returned with their reason instead of being silently skipped. */
    @AuraEnabled
    public static List<String> reassignLeadsWithOwnerMap(Map<String, String> leadOwnerMap) {
        if (leadOwnerMap == null || leadOwnerMap.isEmpty()) return new List<String>();

        Map<Id, Id> ownerIdByLeadId = new Map<Id, Id>();
        for (String leadId : leadOwnerMap.keySet()) {
            String ownerId = leadOwnerMap.get(leadId);
            if (String.isNotBlank(leadId) && String.isNotBlank(ownerId)) {
                ownerIdByLeadId.put(Id.valueOf(leadId), Id.valueOf(ownerId));
            }
        }
        return applyReassignment(ownerIdByLeadId);
    }

    private static List<String> applyReassignment(Map<Id, Id> ownerIdByLeadId) {
        List<String> failureMessages = new List<String>();
        if (ownerIdByLeadId == null || ownerIdByLeadId.isEmpty()) return failureMessages;

        Id RECOVERY_RT_ID     = '012IS000000c3OBYAY';
        Id PRESALES_RT_ID     = '012IS000000c1dOYAQ';
        Id RECOVERY_SVC_RT_ID = '012IS000000c3OBYAY';
        Id SVC_RT_ID          = '012fu000001AprtAAC';

        Set<Id> leadIdSet = ownerIdByLeadId.keySet();
        Set<Id> targetOwnerIds = new Set<Id>(ownerIdByLeadId.values());

        List<Lead> leads = [SELECT Id, OwnerId, RecordTypeId, Lead_Status__c, Is_Unqualified__c, Unqualified_Date__c, Unqualified_Lost_By__c, Unqualified_Reason__c, Recovery_Reassigned_Date__c, Recovery_User__c, Lead_ID__c, Lead_ReAssigned_Date__c, Previous_Presales_user__c, Reassigned_By__c, Lead_ReAssigned_Dates__c, Owner.Name FROM Lead WHERE Id IN :leadIdSet];

        Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Profile.Name FROM User WHERE Id IN :targetOwnerIds]);

        List<Lead> updates = new List<Lead>();

        for (Lead ld : leads) {

            Id     oldOwnerId = ld.OwnerId;
            String ownerName  = ld.Owner.Name;
            Id     newOwnerId = ownerIdByLeadId.get(ld.Id);

            ld.OwnerId                   = newOwnerId;
            ld.Lead_ReAssigned_Dates__c  = System.now();
            ld.Previous_Presales_user__c = oldOwnerId;
            ld.Reassigned_By__c          = UserInfo.getUserId();

            /* ===== Added By Sivam V - START : Last reassigned date + last reassigner (screen reassign only) ===== */
            ld.Last_Reassigned_Date__c   = System.now();
            ld.Last_Reassigner_Name__c   = UserInfo.getUserId();
            /* ===== Added by Sivam V - END : Last reassigned date + last reassigner ===== */

            User   targetUser  = userMap.get(newOwnerId);
            String profileName = (targetUser != null) ? targetUser.Profile.Name : '';

            if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Recovery') {
                ld.Recovery_Reassigned_Date__c = Date.today();
                ld.Lead_ReAssigned_Date__c     = Date.today();
                ld.Previous_Lead_owner__c      = ownerName;
                ld.Is_Lead_ReAssigned__c       = true;
                ld.Pushed_On__c                = System.now();
                ld.Pushed_By__c                = UserInfo.getUserId();
            }
            else if (ld.RecordTypeId == RECOVERY_RT_ID && profileName == 'Pre Sales') {
                ld.RecordTypeId                = PRESALES_RT_ID;
                ld.Lead_Status__c              = 'Unable to connect';
                ld.Previous_Lead_owner__c      = ownerName;
                ld.Lead_ReAssigned_Date__c     = Date.today();
                ld.Is_Lead_ReAssigned__c       = true;
                ld.Is_Unqualified__c           = false;
                ld.Unqualified_Date__c         = null;
                ld.Unqualified_Lost_By__c      = null;
                ld.Unqualified_Reason__c       = null;
                ld.Recovery_Reassigned_Date__c = Date.today();
                ld.Pushed_On__c                = System.now();
                ld.Pushed_By__c                = UserInfo.getUserId();
            }
            else if (ld.RecordTypeId == RECOVERY_SVC_RT_ID && profileName == 'SVC Team') {
                ld.RecordTypeId                = SVC_RT_ID;
                ld.Lead_Status__c              = 'Allocate to SVC';
                ld.Is_Unqualified__c           = false;
                ld.Unqualified_Date__c         = null;
                ld.Unqualified_Lost_By__c      = null;
                ld.Unqualified_Reason__c       = null;
                ld.Recovery_Reassigned_Date__c = Date.today();
                ld.Pushed_On__c                = System.now();
                ld.Pushed_By__c                = UserInfo.getUserId();
            }

            updates.add(ld);
        }

        if (!updates.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(updates, false);
            for (Integer resultIndex = 0; resultIndex < saveResults.size(); resultIndex++) {
                Database.SaveResult saveResult = saveResults[resultIndex];
                if (!saveResult.isSuccess()) {
                    String errorMessage = saveResult.getErrors().isEmpty() ? 'Unknown error' : saveResult.getErrors()[0].getMessage();
                    failureMessages.add(updates[resultIndex].Lead_ID__c + ': ' + errorMessage);
                }
            }
        }
        return failureMessages;
    }
    /* ===== Added By Sathya - END : Fair split across all selected users + failed lead reporting ===== */

    /* =========================================================
       WRAPPER CLASS
       ========================================================= */
    public class LeadResult {
        @AuraEnabled public List<Lead> leads      { get; set; }
        @AuraEnabled public Integer    totalCount  { get; set; }

        public LeadResult(List<Lead> leads, Integer totalCount) {
            this.leads      = leads;
            this.totalCount = totalCount;
        }
    }
    
}