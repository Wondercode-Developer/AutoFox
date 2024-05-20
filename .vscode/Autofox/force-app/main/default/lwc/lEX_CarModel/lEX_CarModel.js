import { LightningElement, track, wire } from 'lwc';
import getCarModelRecords from '@salesforce/apex/CarModelController.getCarModelRecords';
import autofoxLogo from '@salesforce/resourceUrl/TestLogo';


export default class LEX_CarModel extends LightningElement {

    autofoxLogoUrl = autofoxLogo;
    @track carModels;

    @wire(getCarModelRecords)
    wiredCarModels({ error, data }) {
        if (data) {
            this.carModels = data;
        } else if (error) {
            console.error('Error fetching car model records: ', error);
        }
    }
}