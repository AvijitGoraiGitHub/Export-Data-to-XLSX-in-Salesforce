import { LightningElement, wire, track } from 'lwc';

// Import Apex methods
import getAccounts from '@salesforce/apex/ExportToXLSX.getAccounts';
import generateXlsx from '@salesforce/apex/ExportToXLSX.generateXlsx';

export default class ExportToXLSX extends LightningElement {

    // Reactive properties
    @track accounts = [];     // Holds Account data
    @track isLoading = false; // Controls spinner UI
    @track error;             // Stores error if any

    // Define datatable columns
    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'State', fieldName: 'BillingState' },
        { label: 'City', fieldName: 'BillingCity' },
        { label: 'Country', fieldName: 'BillingCountry' },
        { label: 'Phone', fieldName: 'Phone' },
        { label: 'Type', fieldName: 'Type' }
    ];

    /**
     * Fetch Accounts using @wire (reactive + cacheable)
     */
    @wire(getAccounts)
    wiredAccounts({ error, data }) {

        if (data) {
            this.accounts = data;   // Assign data to UI
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.accounts = [];
            console.error(error);
        }
    }

    /**
     * Handle Download Button Click
     */
    async handleDownload() {

        // Prevent export if no data
        if (!this.accounts || this.accounts.length === 0) {
            alert('No data to export');
            return;
        }

        this.isLoading = true;

        try {
            // Call Apex to generate XLSX
            const base64 = await generateXlsx({
                accounts: this.accounts
            });

            // Convert Base64 → downloadable file
            this.downloadFile(base64, 'Accounts.xlsx');

        } catch (err) {
            console.error('Download error:', err);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Convert Base64 → Blob → Trigger Download
     */
    downloadFile(base64, fileName) {

        // Decode Base64 string into binary string
        const byteCharacters = atob(base64);

        // Convert binary string → byte array
        const byteNumbers = new Array(byteCharacters.length);

        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }

        // Create typed array
        const byteArray = new Uint8Array(byteNumbers);

        // Create Blob (file object)
        const blob = new Blob([byteArray], {
            type: 'application/octet-stream'
        });

        // Create temporary download link
        const url = URL.createObjectURL(blob);

        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;

        // Trigger download
        document.body.appendChild(link);
        link.click();

        // Cleanup
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
}