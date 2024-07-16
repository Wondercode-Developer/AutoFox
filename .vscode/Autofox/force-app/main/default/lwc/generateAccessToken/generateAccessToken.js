import { LightningElement, api, track } from 'lwc';
import generateAccessToken from '@salesforce/apex/AutofoxIntegration.generateAccessToken';
import checkMissingFields from '@salesforce/apex/AutofoxIntegration.checkMissingFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class GenerateAccessToken extends LightningElement {
    @api recordId;
    @api objectApiName;
    message = '';
    isLoading = false;
    @track showContinueButton = false;

    connectedCallback() {
        this.isLoading = true;
        if (!this.recordId) {
            this.waitRecordId();
        } else {
            this.callCheckMissingFields();
        }
    }

    waitRecordId() {
        const intervalId = setInterval(() => {
            if (this.recordId) {
                clearInterval(intervalId);
                this.callCheckMissingFields();
            }
        }, 100);
    }

    callCheckMissingFields() {
        checkMissingFields({ recordId: this.recordId })
            .then(result => {
                this.message = result.message;
                this.showContinueButton = false;
            
                if(result.messageType == 'ValidationMessage'){
                    this.showContinueButton = true;
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.message = 'Error: ' + error.body.message;
                this.isLoading = false;
            });
    }

    handleContinue() {
        this.isLoading = true;
        generateAccessToken({ recordId: this.recordId })
            .then(result => {
                if(result.messageType != 'CodeGenerated'){
                    this.message = result.message;
                    this.showToast('Error', result.message, 'error');
                    this.closeQuickActionPanel();
                    this.isLoading = false;
                    return;
                }

                this.message = '';
                this.showToast('Success', result.message, 'success');
                this.closeQuickActionPanel();
                this.isLoading = false;

            })
            .catch(error => {
                this.message = error.body.message;
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleCancel() {
       this.closeQuickActionPanel();
    }

    closeQuickActionPanel(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}