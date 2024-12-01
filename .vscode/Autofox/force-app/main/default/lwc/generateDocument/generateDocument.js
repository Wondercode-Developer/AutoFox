import { LightningElement, wire, track } from 'lwc';
import getPDFData from '@salesforce/apex/GenerateDocumentLWCController.getPDFData';
import savepdf from '@salesforce/apex/GenerateDocumentLWCController.savepdf';
import getAllFiles from '@salesforce/apex/GenerateDocumentLWCController.getAllFiles';
import pdflibResource from '@salesforce/resourceUrl/PDFLIB';
import { loadScript } from 'lightning/platformResourceLoader';

export default class GenerateDocument extends LightningElement {
    @track recordId;
    @track height = '900px';
    @track referrerPolicy = 'no-referrer';
    @track sandbox = '';    
    //@track url = 'https://flowitag--fabiodev--c.sandbox.vf.force.com/apex/GenerateQuotePDF?id=a1xbW0000004bvR&language=en_US';
    @track width = '90%';
    @track pdfdata;
    @track fileUrl;
    pdfLibInitialized = false;
    docData = [];
    /*	@wire (getPDFData,{quoteid: 'a1xbW0000004bvR'})
	wiredPDFData({data, error}){
       
		if(data) {
           
			this.pdfdata =data;
            this.template.querySelector('pdfFrame').contentWindow.postMessage(this.pdfData, window.location.origin);
			this.error = undefined;
		}else {
           
            console.log(error);
			this.pdfdata =undefined;
			this.error = error;
		}
	}*/
    @wire(getAllFiles, { quoteid: 'a1xbW0000004bvR' })
    wiredPDFData({ data, error }) {
        if (data) {
            console.log('inside');
            this.pdfdata = JSON.parse(JSON.stringify(data));
            this.docData = this.pdfdata; 
            if (this.docData != null && this.pdfLibInitialized) {
                this.createPdf();
            }
        } else {
            console.error('Error in getting PDF data: ', error);
        }
    }

    connectedCallback() {
        if (!this.pdfLibInitialized) {
            loadScript(this, pdflibResource)
                .then(() => {
                    this.pdfLibInitialized = true;
                    console.log('PDFLib initialized');
                    if (this.docData.length > 0) {
                        this.createPdf(); 
                    }
                })
                .catch(error => {
                    console.error('Failed to load PDFLib', error);
                });
        }
    }

    async createPdf() {
        try {
            if (!window.PDFLib) {
                console.error('PDFLib is not loaded');
                return;
            }
    
            // Create a new PDF document
            const pdfDoc = await window.PDFLib.PDFDocument.create();
            console.log('Created new PDF Document', pdfDoc);
            
            if (this.docData.length < 1) return; 
    
            const quotePageBytes = Uint8Array.from(atob(this.docData[0]), (c) => c.charCodeAt(0));
            const quotePdfDoc = await window.PDFLib.PDFDocument.load(quotePageBytes);
            const quotePages = await pdfDoc.copyPages(quotePdfDoc, quotePdfDoc.getPageIndices());
    
    
            quotePages.forEach((page) => {
                pdfDoc.addPage(page);
            });
    
      
            const contentVersionBytes = Uint8Array.from(atob(this.docData[1]), (c) => c.charCodeAt(0));
            const contentVersionPdfDoc = await window.PDFLib.PDFDocument.load(contentVersionBytes);
            const contentVersionPages = await pdfDoc.copyPages(contentVersionPdfDoc, contentVersionPdfDoc.getPageIndices());
    
            console.log(`ContentVersion PDF has ${contentVersionPages.length} page(s)`);
    
            contentVersionPages.forEach((page) => {
                pdfDoc.addPage(page);
            });
    
            const pdfBytes = await pdfDoc.save();
            this.saveByteArray('Generated PDF', pdfBytes);
    
        } catch (error) {
            console.error('Error generating PDF:', error);
        }
    }
    
    saveByteArray(pdfName, byte) {
        var blob = new Blob([byte], { type: 'application/pdf' });
        this.fileUrl = window.URL.createObjectURL(blob);
    
        let reader = new FileReader();
        reader.readAsDataURL(blob);
        reader.onload = function () {
            this.base64pdf = reader.result; 
        }.bind(this);
    }
    

    handlesave(event) {
        savepdf({ quoteid: 'a1xbW0000004bvR' })
            .then(result => {
                alert('111');

            })
            .catch(error => {
                this.error = error;
            });
    }
}
