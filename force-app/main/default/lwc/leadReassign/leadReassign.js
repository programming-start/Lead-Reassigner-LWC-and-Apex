// /* ===== Modified by Sathya - START ===== */
// import { LightningElement, track } from 'lwc';
// import getUsers from '@salesforce/apex/LeadReassignController.getUsers';
// import getLeadsByOwner from '@salesforce/apex/LeadReassignController.getLeadsByOwner';
// import reassignLeads from '@salesforce/apex/LeadReassignController.reassignLeads';
// import getLeadStatusPicklistValues from '@salesforce/apex/LeadReassignController.getLeadStatusPicklistValues';
// import getDropOffReasonsPicklistValues from '@salesforce/apex/LeadReassignController.getDropOffReasonsPicklistValues';
// import getAllocatedProjects from '@salesforce/apex/LeadReassignController.getAllocatedProjects';
// /* ===== Added By Sivam V - START : Campaign / Sub Campaign filter imports ===== */
// import getCampaignOptions from '@salesforce/apex/LeadReassignController.getCampaignOptions';
// import getSubCampaignOptions from '@salesforce/apex/LeadReassignController.getSubCampaignOptions';
// /* ===== Added By Sivam V - END : Campaign / Sub Campaign filter imports ===== */

// import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// export default class LeadReassign extends LightningElement {

//     @track userOptions = [];
//     @track leads = [];
//     @track statusOptions = [];
//     @track dropOffOptions = [];
//     @track projectOptions = [];

//     /* ===== Added By Sivam V - START : Campaign / Sub Campaign / Activity filter state ===== */
//     @track campaignOptions = [{ label: 'All', value: 'ALL' }];
//     @track subCampaignOptions = [{ label: 'All', value: 'ALL' }];

//     selectedCampaignId = 'ALL';
//     selectedSubCampaignId = 'ALL';
//     selectedActivityFilter = 'ALL';

//     activityFilterOptions = [
//         { label: 'All', value: 'ALL' },
//         { label: 'NFA (No Future Activity)', value: 'NFA' },
//         { label: 'Untouched', value: 'Untouched' },
//         { label: 'Missed Call', value: 'Missed Call' }
//     ];
//     /* ===== Added By Sivam V - END : Campaign / Sub Campaign / Activity filter state ===== */

//     @track isLoading = false;
//     @track reassignCount = 0;

//     fromUserIds = [];
//     toUserIds = [];
//     selectedLeadIds = [];
//     selectedStatus = 'ALL';
//     dropOffStatus = [];
//     selectedProjects = [];
//     searchKey = '';
//     searchTimeout;
//     pendingCheckboxRestore = false;
//     reassignChunkSize = 5;

//     pageSize = 50;
//     currentPage = 1;
//     totalRecords = 0;
//     totalPages = 1;
//     fromDate;
//     toDate;
//     leadStatus;

//     connectedCallback() {
//         this.loadUsers();
//         this.loadStatusPicklist();
//     }

//     // Restores ticks after the table has actually rendered (replaces the 50 ms setTimeout race)
//     renderedCallback() {
//         if (this.pendingCheckboxRestore) {
//             this.pendingCheckboxRestore = false;
//             this.restoreCheckboxStates();
//         }
//     }

//     get selectedCount() {
//         return this.selectedLeadIds.length;
//     }

//     get pageInfo() {
//         return `Page ${this.currentPage} of ${this.totalPages} (Total: ${this.totalRecords} records)`;
//     }

//     get disablePrev() {
//         return this.currentPage === 1;
//     }

//     get disableNext() {
//         return this.currentPage === this.totalPages;
//     }

//     // ─── LOAD DATA ────────────────────────────────────────────────────────────

//     loadUsers() {
//         getUsers()
//             .then(res => {
//                 this.userOptions = res.map(u => ({
//                     label: u.Name,
//                     value: u.Id
//                 }));
//             })
//             .catch(e => this.showError(e));
//     }

//     loadStatusPicklist() {
//         getLeadStatusPicklistValues()
//             .then(res => {
//                 this.statusOptions = [
//                     { label: 'All', value: 'ALL' },
//                     ...res.map(v => ({ label: v, value: v }))
//                 ];
//             })
//             .catch(e => this.showError(e));

//         getDropOffReasonsPicklistValues()
//             .then(res => {
//                 this.dropOffOptions = [
//                     { label: 'All', value: 'ALL' },
//                     ...res.map(v => ({ label: v, value: v }))
//                 ];
//             })
//             .catch(e => this.showError(e));
//     }

//     loadProjects() {
//         if (!this.fromUserIds.length) {
//             this.projectOptions = [];
//             return;
//         }
//         getAllocatedProjects({
//             ownerIds: this.fromUserIds,
//             status: this.selectedStatus
//         })
//         .then(res => {
//             this.projectOptions = res.map(v => ({ label: v, value: v }));
//         })
//         .catch(e => this.showError(e));
//     }

//     /* ===== Added By Sivam V - START : Campaign / Sub Campaign option loaders ===== */
//     get campaignIdForApex() {
//         return this.selectedCampaignId === 'ALL' ? null : this.selectedCampaignId;
//     }

//     get subCampaignIdForApex() {
//         return this.selectedSubCampaignId === 'ALL' ? null : this.selectedSubCampaignId;
//     }

//     get activityFilterForApex() {
//         return this.selectedActivityFilter === 'ALL' ? null : this.selectedActivityFilter;
//     }

//     loadCampaigns() {
//         if (!this.fromUserIds.length) {
//             this.campaignOptions = [{ label: 'All', value: 'ALL' }];
//             return;
//         }
//         getCampaignOptions({ ownerIds: this.fromUserIds })
//             .then(res => {
//                 this.campaignOptions = [
//                     { label: 'All', value: 'ALL' },
//                     ...res.map(option => ({ label: option.label, value: option.value }))
//                 ];
//             })
//             .catch(e => this.showError(e));
//     }

//     loadSubCampaigns() {
//         if (!this.fromUserIds.length) {
//             this.subCampaignOptions = [{ label: 'All', value: 'ALL' }];
//             return;
//         }
//         getSubCampaignOptions({
//             ownerIds: this.fromUserIds,
//             campaignId: this.campaignIdForApex
//         })
//         .then(res => {
//             this.subCampaignOptions = [
//                 { label: 'All', value: 'ALL' },
//                 ...res.map(option => ({ label: option.label, value: option.value }))
//             ];
//         })
//         .catch(e => this.showError(e));
//     }
//     /* ===== Added By Sivam V - END : Campaign / Sub Campaign option loaders ===== */

//     // ─── FILTER / SEARCH HANDLERS ─────────────────────────────────────────────

//     handleFromUserChange(event) {
//         this.fromUserIds = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.selectedProjects = [];
//         this.loadProjects();
//         /* ===== Added By Sivam V - START : reset campaign filters on owner change ===== */
//         this.selectedCampaignId = 'ALL';
//         this.selectedSubCampaignId = 'ALL';
//         this.loadCampaigns();
//         this.loadSubCampaigns();
//         /* ===== Added By Sivam V - END : reset campaign filters on owner change ===== */
//         this.refreshLeads();
//     }

//     handleToUserChange(event) {
//         this.toUserIds = event.detail.value;
//     }

//     handleStatusChange(event) {
//         this.selectedStatus = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.selectedProjects = [];
//         this.loadProjects();
//         this.refreshLeads();
//     }

//     handleDropOffChange(event) {
//         this.dropOffStatus = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.refreshLeads();
//     }

//     handleProjectChange(event) {
//         this.selectedProjects = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.refreshLeads();
//     }

//     /* ===== Added By Sivam V - START : Campaign / Sub Campaign / Activity filter handlers ===== */
//     handleCampaignChange(event) {
//         this.selectedCampaignId = event.detail.value;
//         this.selectedSubCampaignId = 'ALL';
//         this.loadSubCampaigns();
//         this.clearSelection();
//         this.currentPage = 1;
//         this.refreshLeads();
//     }

//     handleSubCampaignChange(event) {
//         this.selectedSubCampaignId = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.refreshLeads();
//     }

//     handleActivityFilterChange(event) {
//         this.selectedActivityFilter = event.detail.value;
//         this.clearSelection();
//         this.currentPage = 1;
//         this.refreshLeads();
//     }
//     /* ===== Added By Sivam V - END : Campaign / Sub Campaign / Activity filter handlers ===== */

//     handleSearchKeyChange(event) {
//         this.searchKey = event.target.value;
//         this.clearSelection();
//         this.currentPage = 1;

//         clearTimeout(this.searchTimeout);
//         // eslint-disable-next-line @lwc/lwc/no-async-operation
//         this.searchTimeout = setTimeout(() => {
//             this.refreshLeads();
//         }, 500);
//     }

//     clearSelection() {
//         this.selectedLeadIds = [];
//         this.setReassignCount(0);
//     }

//     // ─── REASSIGN COUNT INPUT ─────────────────────────────────────────────────

//     // Keeps the property and the visible input in sync at all times
//     setReassignCount(value) {
//         this.reassignCount = value;
//         const countInput = this.template.querySelector('lightning-input[data-count-input]');
//         if (countInput && Number(countInput.value) !== value) {
//             countInput.value = value;
//         }
//     }

//     handleReassignCountChange(event) {
//         const raw = event.target.value;
//         this.reassignCount = raw === '' ? 0 : Number(raw);
//     }

//     handleReassignCountBlur(event) {
//         const value = Number(event.target.value);
//         const max = this.selectedLeadIds.length;

//         if (!value || value < 1 || value > max) {
//             this.setReassignCount(max);
//         } else {
//             this.setReassignCount(value);
//         }
//     }

//     // ─── LEADS TABLE ──────────────────────────────────────────────────────────

//     refreshLeads() {
//         if (!this.fromUserIds.length) {
//             this.leads = [];
//             this.totalRecords = 0;
//             this.totalPages = 0;
//             return;
//         }

//         this.isLoading = true;

//         getLeadsByOwner({
//             ownerIds: this.fromUserIds,
//             fromDate: this.fromDate,
//             toDate: this.toDate,
//             status: this.selectedStatus,
//             dropStatus: this.dropOffStatus,
//             projects: this.selectedProjects,
//             searchKey: this.searchKey,
//             pageSize: this.pageSize,
//             pageNumber: this.currentPage,
//             /* ===== Added By Sivam V - START : Campaign / Sub Campaign / Activity filter params ===== */
//             campaignId: this.campaignIdForApex,
//             subCampaignId: this.subCampaignIdForApex,
//             activityFilter: this.activityFilterForApex
//             /* ===== Added By Sivam V - END : Campaign / Sub Campaign / Activity filter params ===== */
//         })
//         .then(result => {

//             if (
//                 result.leads &&
//                 result.leads.length > 0 &&
//                 (
//                     result.leads[0].Lead_Status__c === 'Recovery - Pre Sales' ||
//                     result.leads[0].Lead_Status__c === 'Recovery - SVC' ||
//                     result.leads[0].Lead_Status__c === 'Recovery - Sales'
//                 )
//             ) {
//                 this.leadStatus = result.leads[0].Lead_Status__c;
//             }

//             this.leads = (result.leads || []).map(lead => {
//                 let recoveryDate = null;

//                 if (lead.Lead_Status__c === 'Recovery - Pre Sales') {
//                     recoveryDate = lead.Unqualified_Date__c;
//                 }
//                 else if (
//                     lead.Lead_Status__c === 'Recovery - SVC' ||
//                     lead.Lead_Status__c === 'Recovery - Sales'
//                 ) {
//                     recoveryDate = lead.Closed_Lost_Date__c;
//                 }
//                 return {
//                     ...lead,
//                     RecoveryDate: recoveryDate,
//                     /* ===== Added By Sivam V - START : Campaign display columns ===== */
//                     CampaignName: lead.Campaign_std__r ? lead.Campaign_std__r.Name : '',
//                     SubCampaignName: lead.Sub_Campaign__r ? lead.Sub_Campaign__r.Name : ''
//                     /* ===== Added By Sivam V - END : Campaign display columns ===== */
//                 };
//             });

//             this.totalRecords = result.totalCount || 0;
//             this.totalPages = Math.ceil(this.totalRecords / this.pageSize) || 1;
//             this.pendingCheckboxRestore = true;
//             this.isLoading = false;
//         })
//         .catch(e => {
//             this.showError(e);
//             this.isLoading = false;
//         });
//     }

//     restoreCheckboxStates() {
//         const checkboxes = this.template.querySelectorAll('lightning-input[data-id]');
//         let allChecked = checkboxes.length > 0;

//         checkboxes.forEach(cb => {
//             const isSelected = this.selectedLeadIds.includes(cb.dataset.id);
//             cb.checked = isSelected;
//             if (!isSelected) allChecked = false;
//         });

//         const selectAllCb = this.template.querySelector('lightning-input[data-select-all]');
//         if (selectAllCb) {
//             selectAllCb.checked = allChecked;
//         }

//         this.setReassignCount(this.selectedLeadIds.length);
//     }

//     // ─── CHECKBOX HANDLERS ────────────────────────────────────────────────────

//     handleCheckboxChange(event) {
//         const id = event.target.dataset.id;

//         if (event.target.checked) {
//             if (!this.selectedLeadIds.includes(id)) {
//                 this.selectedLeadIds = [...this.selectedLeadIds, id];
//             }
//         } else {
//             this.selectedLeadIds = this.selectedLeadIds.filter(l => l !== id);
//         }

//         this.setReassignCount(this.selectedLeadIds.length);
//         this.syncSelectAllCheckbox();
//     }

//     handleSelectAll(event) {
//         const checked = event.target.checked;

//         const currentPageIds = [];
//         this.template.querySelectorAll('lightning-input[data-id]')
//             .forEach(cb => {
//                 currentPageIds.push(cb.dataset.id);
//                 cb.checked = checked;
//             });

//         if (checked) {
//             this.selectedLeadIds = [...new Set([...this.selectedLeadIds, ...currentPageIds])];
//         } else {
//             this.selectedLeadIds = this.selectedLeadIds.filter(
//                 id => !currentPageIds.includes(id)
//             );
//         }

//         this.setReassignCount(this.selectedLeadIds.length);
//     }

//     syncSelectAllCheckbox() {
//         const checkboxes = this.template.querySelectorAll('lightning-input[data-id]');
//         let allChecked = checkboxes.length > 0;

//         checkboxes.forEach(cb => {
//             if (!this.selectedLeadIds.includes(cb.dataset.id)) {
//                 allChecked = false;
//             }
//         });

//         const selectAllCb = this.template.querySelector('lightning-input[data-select-all]');
//         if (selectAllCb) selectAllCb.checked = allChecked;
//     }

//     // ─── PAGINATION ───────────────────────────────────────────────────────────

//     handlePrev() {
//         if (this.currentPage > 1) {
//             this.currentPage--;
//             this.refreshLeads();
//         }
//     }

//     handleNext() {
//         if (this.currentPage < this.totalPages) {
//             this.currentPage++;
//             this.refreshLeads();
//         }
//     }

//     // ─── REASSIGN ─────────────────────────────────────────────────────────────

//     handleReassign() {
//         if (!this.toUserIds.length) {
//             this.toast('Error', 'Select target users', 'error');
//             return;
//         }

//         if (!this.selectedLeadIds.length) {
//             this.toast('Error', 'Select at least one lead', 'error');
//             return;
//         }

//         let countToReassign = Number(this.reassignCount);
//         if (!countToReassign || countToReassign < 1 || countToReassign > this.selectedLeadIds.length) {
//             countToReassign = this.selectedLeadIds.length;
//         }
//         this.setReassignCount(countToReassign);

//         const leadIdsToReassign = this.selectedLeadIds.slice(0, countToReassign);

//         // Send in chunks so each Apex call runs in its own transaction with fresh governor limits
//         const chunks = [];
//         for (let start = 0; start < leadIdsToReassign.length; start += this.reassignChunkSize) {
//             chunks.push(leadIdsToReassign.slice(start, start + this.reassignChunkSize));
//         }

//         this.isLoading = true;
//         this.processReassignChunks(chunks, 0, 0, []);
//     }

//     processReassignChunks(chunks, chunkIndex, successCount, failureMessages) {
//         if (chunkIndex >= chunks.length) {
//             this.finishReassign(successCount, failureMessages);
//             return;
//         }

//         const chunk = chunks[chunkIndex];

//         reassignLeads({
//             leadIds: chunk,
//             newOwnerIds: this.toUserIds
//         })
//         .then(chunkFailures => {
//             // Works with both the current void Apex and the List<String> version
//             const failedInChunk = chunkFailures ? chunkFailures.length : 0;
//             this.processReassignChunks(
//                 chunks,
//                 chunkIndex + 1,
//                 successCount + chunk.length - failedInChunk,
//                 [...failureMessages, ...(chunkFailures || [])]
//             );
//         })
//         .catch(e => {
//             const errorMessage = e?.body?.message || e?.message || 'Unknown error';
//             this.processReassignChunks(
//                 chunks,
//                 chunkIndex + 1,
//                 successCount,
//                 [...failureMessages, `Batch ${chunkIndex + 1} (${chunk.length} leads): ${errorMessage}`]
//             );
//         });
//     }

//     finishReassign(successCount, failureMessages) {
//         if (failureMessages.length > 0) {
//             this.toast(
//                 'Partially Completed',
//                 `${successCount} reassigned. Failed: ${failureMessages[0]}`,
//                 'warning',
//                 'sticky'
//             );
//         } else {
//             this.toast('Success', `${successCount} leads reassigned successfully`, 'success');
//         }
//         this.clearSelection();
//         this.refreshLeads();
//     }

//     // ─── HELPERS ──────────────────────────────────────────────────────────────

//     showError(error) {
//         this.toast('Error', error?.body?.message || error?.message || 'An error occurred', 'error');
//     }

//     toast(title, message, variant, mode = 'dismissible') {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
//     }

//     handleFromDateChange(event) {
//         this.fromDate = event.target.value;
//         this.currentPage = 1;
//         this.refreshLeads();
//     }

//     handleToDateChange(event) {
//         this.toDate = event.target.value;
//         this.currentPage = 1;
//         this.refreshLeads();
//     }
// }

// /* ===== Modified by Sathya - END ===== */

// ===================================================================================================================================
// ===================================================================================================================================

/* ===== Modified by Sathya - START ===== */
import { LightningElement, track } from 'lwc';
import getUsers from '@salesforce/apex/LeadReassignController.getUsers';
import getLeadsByOwner from '@salesforce/apex/LeadReassignController.getLeadsByOwner';
/* ===== Added By Sathya - START : Fair split Apex method ===== */
import reassignLeadsWithOwnerMap from '@salesforce/apex/LeadReassignController.reassignLeadsWithOwnerMap';
/* ===== Added By Sathya - END : Fair split Apex method ===== */
import getLeadStatusPicklistValues from '@salesforce/apex/LeadReassignController.getLeadStatusPicklistValues';
import getDropOffReasonsPicklistValues from '@salesforce/apex/LeadReassignController.getDropOffReasonsPicklistValues';
import getAllocatedProjects from '@salesforce/apex/LeadReassignController.getAllocatedProjects';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadReassign extends LightningElement {

    @track userOptions = [];
    @track leads = [];
    @track statusOptions = [];
    @track dropOffOptions = [];
    @track projectOptions = [];

    @track isLoading = false;
    @track reassignCount = 0;

    fromUserIds = [];
    toUserIds = [];
    selectedLeadIds = [];
    selectedStatus = 'ALL';
    dropOffStatus = [];
    selectedProjects = [];
    searchKey = '';
    searchTimeout;
    pendingCheckboxRestore = false;
    reassignChunkSize = 5;

    pageSize = 50;
    currentPage = 1;
    totalRecords = 0;
    totalPages = 1;
    fromDate;
    toDate;
    leadStatus;

    connectedCallback() {
        this.loadUsers();
        this.loadStatusPicklist();
    }

    // Restores ticks after the table has actually rendered (replaces the 50 ms setTimeout race)
    renderedCallback() {
        if (this.pendingCheckboxRestore) {
            this.pendingCheckboxRestore = false;
            this.restoreCheckboxStates();
        }
    }

    get selectedCount() {
        return this.selectedLeadIds.length;
    }

    get pageInfo() {
        return `Page ${this.currentPage} of ${this.totalPages} (Total: ${this.totalRecords} records)`;
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage === this.totalPages;
    }

    // ─── LOAD DATA ────────────────────────────────────────────────────────────

    loadUsers() {
        getUsers()
            .then(res => {
                this.userOptions = res.map(u => ({
                    label: u.Name,
                    value: u.Id
                }));
            })
            .catch(e => this.showError(e));
    }

    loadStatusPicklist() {
        getLeadStatusPicklistValues()
            .then(res => {
                this.statusOptions = [
                    { label: 'All', value: 'ALL' },
                    ...res.map(v => ({ label: v, value: v }))
                ];
            })
            .catch(e => this.showError(e));

        getDropOffReasonsPicklistValues()
            .then(res => {
                this.dropOffOptions = [
                    { label: 'All', value: 'ALL' },
                    ...res.map(v => ({ label: v, value: v }))
                ];
            })
            .catch(e => this.showError(e));
    }

    loadProjects() {
        if (!this.fromUserIds.length) {
            this.projectOptions = [];
            return;
        }
        getAllocatedProjects({
            ownerIds: this.fromUserIds,
            status: this.selectedStatus
        })
        .then(res => {
            this.projectOptions = res.map(v => ({ label: v, value: v }));
        })
        .catch(e => this.showError(e));
    }

    // ─── FILTER / SEARCH HANDLERS ─────────────────────────────────────────────

    handleFromUserChange(event) {
        this.fromUserIds = event.detail.value;
        this.clearSelection();
        this.currentPage = 1;
        this.selectedProjects = [];
        this.loadProjects();
        this.refreshLeads();
    }

    handleToUserChange(event) {
        this.toUserIds = event.detail.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.clearSelection();
        this.currentPage = 1;
        this.selectedProjects = [];
        this.loadProjects();
        this.refreshLeads();
    }

    handleDropOffChange(event) {
        this.dropOffStatus = event.detail.value;
        this.clearSelection();
        this.currentPage = 1;
        this.refreshLeads();
    }

    handleProjectChange(event) {
        this.selectedProjects = event.detail.value;
        this.clearSelection();
        this.currentPage = 1;
        this.refreshLeads();
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
        this.clearSelection();
        this.currentPage = 1;

        clearTimeout(this.searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimeout = setTimeout(() => {
            this.refreshLeads();
        }, 500);
    }

    clearSelection() {
        this.selectedLeadIds = [];
        this.setReassignCount(0);
    }

    // ─── REASSIGN COUNT INPUT ─────────────────────────────────────────────────

    // Keeps the property and the visible input in sync at all times
    setReassignCount(value) {
        this.reassignCount = value;
        const countInput = this.template.querySelector('lightning-input[data-count-input]');
        if (countInput && Number(countInput.value) !== value) {
            countInput.value = value;
        }
    }

    handleReassignCountChange(event) {
        const raw = event.target.value;
        this.reassignCount = raw === '' ? 0 : Number(raw);
    }

    handleReassignCountBlur(event) {
        const value = Number(event.target.value);
        const max = this.selectedLeadIds.length;

        if (!value || value < 1 || value > max) {
            this.setReassignCount(max);
        } else {
            this.setReassignCount(value);
        }
    }

    // ─── LEADS TABLE ──────────────────────────────────────────────────────────

    refreshLeads() {
        if (!this.fromUserIds.length) {
            this.leads = [];
            this.totalRecords = 0;
            this.totalPages = 0;
            return;
        }

        this.isLoading = true;

        getLeadsByOwner({
            ownerIds: this.fromUserIds,
            fromDate: this.fromDate,
            toDate: this.toDate,
            status: this.selectedStatus,
            dropStatus: this.dropOffStatus,
            projects: this.selectedProjects,
            searchKey: this.searchKey,
            pageSize: this.pageSize,
            pageNumber: this.currentPage
        })
        .then(result => {

            if (
                result.leads &&
                result.leads.length > 0 &&
                (
                    result.leads[0].Lead_Status__c === 'Recovery - Pre Sales' ||
                    result.leads[0].Lead_Status__c === 'Recovery - SVC' ||
                    result.leads[0].Lead_Status__c === 'Recovery - Sales'
                )
            ) {
                this.leadStatus = result.leads[0].Lead_Status__c;
            }

            this.leads = (result.leads || []).map(lead => {
                let recoveryDate = null;

                if (lead.Lead_Status__c === 'Recovery - Pre Sales') {
                    recoveryDate = lead.Unqualified_Date__c;
                }
                else if (
                    lead.Lead_Status__c === 'Recovery - SVC' ||
                    lead.Lead_Status__c === 'Recovery - Sales'
                ) {
                    recoveryDate = lead.Closed_Lost_Date__c;
                }
                return {
                    ...lead,
                    RecoveryDate: recoveryDate
                };
            });

            this.totalRecords = result.totalCount || 0;
            this.totalPages = Math.ceil(this.totalRecords / this.pageSize) || 1;
            this.pendingCheckboxRestore = true;
            this.isLoading = false;
        })
        .catch(e => {
            this.showError(e);
            this.isLoading = false;
        });
    }

    restoreCheckboxStates() {
        const checkboxes = this.template.querySelectorAll('lightning-input[data-id]');
        let allChecked = checkboxes.length > 0;

        checkboxes.forEach(cb => {
            const isSelected = this.selectedLeadIds.includes(cb.dataset.id);
            cb.checked = isSelected;
            if (!isSelected) allChecked = false;
        });

        const selectAllCb = this.template.querySelector('lightning-input[data-select-all]');
        if (selectAllCb) {
            selectAllCb.checked = allChecked;
        }

        this.setReassignCount(this.selectedLeadIds.length);
    }

    // ─── CHECKBOX HANDLERS ────────────────────────────────────────────────────

    handleCheckboxChange(event) {
        const id = event.target.dataset.id;

        if (event.target.checked) {
            if (!this.selectedLeadIds.includes(id)) {
                this.selectedLeadIds = [...this.selectedLeadIds, id];
            }
        } else {
            this.selectedLeadIds = this.selectedLeadIds.filter(l => l !== id);
        }

        this.setReassignCount(this.selectedLeadIds.length);
        this.syncSelectAllCheckbox();
    }

    handleSelectAll(event) {
        const checked = event.target.checked;

        const currentPageIds = [];
        this.template.querySelectorAll('lightning-input[data-id]')
            .forEach(cb => {
                currentPageIds.push(cb.dataset.id);
                cb.checked = checked;
            });

        if (checked) {
            this.selectedLeadIds = [...new Set([...this.selectedLeadIds, ...currentPageIds])];
        } else {
            this.selectedLeadIds = this.selectedLeadIds.filter(
                id => !currentPageIds.includes(id)
            );
        }

        this.setReassignCount(this.selectedLeadIds.length);
    }

    syncSelectAllCheckbox() {
        const checkboxes = this.template.querySelectorAll('lightning-input[data-id]');
        let allChecked = checkboxes.length > 0;

        checkboxes.forEach(cb => {
            if (!this.selectedLeadIds.includes(cb.dataset.id)) {
                allChecked = false;
            }
        });

        const selectAllCb = this.template.querySelector('lightning-input[data-select-all]');
        if (selectAllCb) selectAllCb.checked = allChecked;
    }

    // ─── PAGINATION ───────────────────────────────────────────────────────────

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.refreshLeads();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.refreshLeads();
        }
    }

    // ─── REASSIGN ─────────────────────────────────────────────────────────────

    handleReassign() {
        if (!this.toUserIds.length) {
            this.toast('Error', 'Select target users', 'error');
            return;
        }

        if (!this.selectedLeadIds.length) {
            this.toast('Error', 'Select at least one lead', 'error');
            return;
        }

        let countToReassign = Number(this.reassignCount);
        if (!countToReassign || countToReassign < 1 || countToReassign > this.selectedLeadIds.length) {
            countToReassign = this.selectedLeadIds.length;
        }
        this.setReassignCount(countToReassign);

        const leadIdsToReassign = this.selectedLeadIds.slice(0, countToReassign);

        /* ===== Added By Sathya - START : Decide every lead's owner once, across all selected users =====
           Lead 1 -> user 1, lead 2 -> user 2, ... lead N+1 -> user 1 again, so the split stays even
           for any number of users. Batching below only groups these fixed pairs. */
        const ownerIdByLeadId = {};
        leadIdsToReassign.forEach((leadId, leadPosition) => {
            ownerIdByLeadId[leadId] = this.toUserIds[leadPosition % this.toUserIds.length];
        });
        /* ===== Added By Sathya - END : Decide every lead's owner once, across all selected users ===== */

        // Send in chunks so each Apex call runs in its own transaction with fresh governor limits
        const chunks = [];
        for (let start = 0; start < leadIdsToReassign.length; start += this.reassignChunkSize) {
            /* ===== Added By Sathya - START : Each batch carries its fixed lead -> owner pairs ===== */
            const chunkLeadOwnerMap = {};
            leadIdsToReassign.slice(start, start + this.reassignChunkSize).forEach(leadId => {
                chunkLeadOwnerMap[leadId] = ownerIdByLeadId[leadId];
            });
            chunks.push(chunkLeadOwnerMap);
            /* ===== Added By Sathya - END : Each batch carries its fixed lead -> owner pairs ===== */
        }

        this.isLoading = true;
        this.processReassignChunks(chunks, 0, 0, []);
    }

    processReassignChunks(chunks, chunkIndex, successCount, failureMessages) {
        if (chunkIndex >= chunks.length) {
            this.finishReassign(successCount, failureMessages);
            return;
        }

        const chunk = chunks[chunkIndex];
        /* ===== Added By Sathya - START : Send fixed lead -> owner pairs for this batch ===== */
        const chunkSize = Object.keys(chunk).length;

        reassignLeadsWithOwnerMap({
            leadOwnerMap: chunk
        })
        /* ===== Added By Sathya - END : Send fixed lead -> owner pairs for this batch ===== */
        .then(chunkFailures => {
            // Works with both the current void Apex and the List<String> version
            const failedInChunk = chunkFailures ? chunkFailures.length : 0;
            this.processReassignChunks(
                chunks,
                chunkIndex + 1,
                successCount + chunkSize - failedInChunk,
                [...failureMessages, ...(chunkFailures || [])]
            );
        })
        .catch(e => {
            const errorMessage = e?.body?.message || e?.message || 'Unknown error';
            this.processReassignChunks(
                chunks,
                chunkIndex + 1,
                successCount,
                [...failureMessages, `Batch ${chunkIndex + 1} (${chunkSize} leads): ${errorMessage}`]
            );
        });
    }

    finishReassign(successCount, failureMessages) {
        if (failureMessages.length > 0) {
            this.toast(
                'Partially Completed',
                /* ===== Added By Sathya - START : Show how many leads failed ===== */
                `${successCount} reassigned, ${failureMessages.length} failed. First failure: ${failureMessages[0]}`,
                /* ===== Added By Sathya - END : Show how many leads failed ===== */
                'warning',
                'sticky'
            );
        } else {
            this.toast('Success', `${successCount} leads reassigned successfully`, 'success');
        }
        this.clearSelection();
        this.refreshLeads();
    }

    // ─── HELPERS ──────────────────────────────────────────────────────────────

    showError(error) {
        this.toast('Error', error?.body?.message || error?.message || 'An error occurred', 'error');
    }

    toast(title, message, variant, mode = 'dismissible') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.currentPage = 1;
        this.refreshLeads();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.currentPage = 1;
        this.refreshLeads();
    }
}

/* ===== Modified by Sathya - END ===== */