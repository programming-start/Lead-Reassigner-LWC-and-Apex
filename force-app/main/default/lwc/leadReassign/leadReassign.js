/**
 * Author         : Sivam V
 * Component Name : leadReassign
 * Apex Class     : LeadReassignController
 * Purpose        : Lead Reassigner screen for Team Leaders. Filters the selected users'
 *                  leads, splits the chosen leads evenly across all selected To Users,
 *                  sends them to Apex in batches of 5, shows failed leads in the toast and
 *                  writes one Apex_Log__c record per run (started when the run begins,
 *                  completed when it ends).
 * Date           : 15/10/2026
 */
import { LightningElement, track } from 'lwc';
import getUsers from '@salesforce/apex/LeadReassignController.getUsers';
import getLeadsByOwner from '@salesforce/apex/LeadReassignController.getLeadsByOwner';
import reassignLeadsWithOwnerMap from '@salesforce/apex/LeadReassignController.reassignLeadsWithOwnerMap';
import getLeadStatusPicklistValues from '@salesforce/apex/LeadReassignController.getLeadStatusPicklistValues';
import getDropOffReasonsPicklistValues from '@salesforce/apex/LeadReassignController.getDropOffReasonsPicklistValues';
import getAllocatedProjects from '@salesforce/apex/LeadReassignController.getAllocatedProjects';
import startReassignmentLog from '@salesforce/apex/LeadReassignController.startReassignmentLog';
import completeReassignmentLog from '@salesforce/apex/LeadReassignController.completeReassignmentLog';

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
    reassignLogId = null;
    reassignLogLeadIds = [];

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

        // Decide every lead's owner once, across all selected users: lead 1 -> user 1, lead 2 -> user 2,
        // and back to user 1 after the last user, so the split stays even for any number of users
        const ownerIdByLeadId = {};
        leadIdsToReassign.forEach((leadId, leadPosition) => {
            ownerIdByLeadId[leadId] = this.toUserIds[leadPosition % this.toUserIds.length];
        });

        // Send in chunks so each Apex call runs in its own transaction with fresh governor limits
        const chunks = [];
        for (let start = 0; start < leadIdsToReassign.length; start += this.reassignChunkSize) {
            // Each batch carries its fixed lead -> owner pairs
            const chunkLeadOwnerMap = {};
            leadIdsToReassign.slice(start, start + this.reassignChunkSize).forEach(leadId => {
                chunkLeadOwnerMap[leadId] = ownerIdByLeadId[leadId];
            });
            chunks.push(chunkLeadOwnerMap);
        }

        this.isLoading = true;

        // Start the run log, then reassign. If the log cannot be created, the run still goes ahead.
        this.reassignLogId = null;
        this.reassignLogLeadIds = [...leadIdsToReassign];

        startReassignmentLog({
            requestJson: JSON.stringify(this.buildReassignLogRequest(leadIdsToReassign.length))
        })
        .then(logId => {
            this.reassignLogId = logId;
        })
        .catch(() => {
            this.reassignLogId = null;
        })
        .finally(() => {
            this.processReassignChunks(chunks, 0, 0, []);
        });
    }

    // Run details saved in Apex_Log__c.Request__c
    buildReassignLogRequest(leadsToReassignCount) {
        const userNameById = {};
        this.userOptions.forEach(userOption => {
            userNameById[userOption.value] = userOption.label;
        });

        return {
            fromUsers: this.fromUserIds.map(userId => userNameById[userId] || userId),
            toUsers: this.toUserIds.map(userId => userNameById[userId] || userId),
            filters: {
                leadStatus: this.selectedStatus,
                dropOffReasons: this.dropOffStatus || [],
                allocatedProjects: this.selectedProjects || [],
                searchKey: this.searchKey || '',
                recoveryFromDate: this.fromDate || null,
                recoveryToDate: this.toDate || null
            },
            leadsSelected: this.selectedLeadIds.length,
            leadsToReassign: leadsToReassignCount,
            batchSize: this.reassignChunkSize
        };
    }

    processReassignChunks(chunks, chunkIndex, successCount, failureMessages) {
        if (chunkIndex >= chunks.length) {
            this.finishReassign(successCount, failureMessages);
            return;
        }

        const chunk = chunks[chunkIndex];
        const chunkSize = Object.keys(chunk).length;

        reassignLeadsWithOwnerMap({
            leadOwnerMap: chunk
        })
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
                `${successCount} reassigned, ${failureMessages.length} failed. First failure: ${failureMessages[0]}`,
                'warning',
                'sticky'
            );
        } else {
            this.toast('Success', `${successCount} leads reassigned successfully`, 'success');
        }

        // Complete the run log with the result
        if (this.reassignLogId) {
            completeReassignmentLog({
                logId: this.reassignLogId,
                leadIds: this.reassignLogLeadIds,
                failureMessages: failureMessages
            })
            .catch(() => {
                // The reassignment is already done; a log failure must not show as a reassign error
            });
        }
        this.reassignLogId = null;
        this.reassignLogLeadIds = [];

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