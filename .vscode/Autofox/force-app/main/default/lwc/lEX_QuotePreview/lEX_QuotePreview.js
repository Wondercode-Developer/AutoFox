import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import attach from "@salesforce/label/c.AttachToRecord";


// Apex methods
import attachPdfToQuote from '@salesforce/apex/QuotePDFController.attachPdfToQuote';
//import attachAndSendEmail from '@salesforce/apex/QuotePDFController.attachAndSendEmail';

export default class LEX_QuotePreview extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track height;
    @track width;

    label = {
        attach
    };
    connectedCallback() {
        // Dynamically calculate iframe height and width based on screen size
        this.height = `${window.innerHeight * 0.85}px`; // 85% of the viewport height
        this.width = '100%'; // Full width
    }

    get pageUrl() {
        return '/apex/QuotePDF?RecordId=' + this.recordId;
    }

    handleAttach() {
        console.log('Attach button clicked');
        console.log('Record ID: ', this.recordId);
        this.isLoading = true;
        attachPdfToQuote({ quoteId: this.recordId })
            .then(result => {
                console.log('Attach result: ', result);
                this.showToast('Success!', result, 'success');
                return refreshApex(this.record);
            })
            .catch(error => {
                console.error('Attach error: ', error);
                let errorMessage = 'An unexpected error occurred';
                // Check if the error has a message property
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.message) {
                    errorMessage = error.message;
                }
                this.showToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.closeModal();
            });
    }

    handleSend() {
        console.log('Send button clicked');
        this.isLoading = true;
        attachAndSendEmail({ quoteId: this.recordId })
            .then(result => {
                console.log('Send result: ', result);
                this.showToast('Success!', result, 'success');
                return refreshApex(this.record);
            })
            .catch(error => {
                console.error('Send error: ', error);
                let errorMessage = 'An unexpected error occurred';
                // Check if the error has a message property
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.message) {
                    errorMessage = error.message;
                }
                this.showToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.closeModal();
            });
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(toastEvent);
    }

  

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
