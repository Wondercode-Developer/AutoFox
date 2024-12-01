public class QuotePDFController {
    public String formattedDate { get; set; }
    public QuoteLineItem mainProduct { get; set; }
    public List<QuoteLineItem> accessoryProducts { get; set; }
    public Quote quoteRecord { get; set; }
    public Contact primaryContact { get; set; }
    public Opportunity opportunityRecord { get; set; }
    public Map<Id, ContentDocument> productImageMap { get; set; }
    public String quoteId { get; set; }
    public User loggedInUser { get; set; }


    public QuotePDFController(ApexPages.StandardController controller) {
        
        this.quoteRecord = (Quote)controller.getRecord();
        quoteId = quoteRecord.id;
        fetchRelatedData();
        formattedDate = formatDate();
    }

    public QuotePDFController(){
        quoteId = ApexPages.currentPage().getParameters().get('RecordId');
        loggedInUser = [SELECT FirstName, LastName, Email, title FROM User WHERE Id = :UserInfo.getUserId()];

        // Ensure the ID is not null before proceeding
        if (quoteId != null) {
            // Fetch related data using the quoteId from the URL
            fetchRelatedData();
            
            // Format the date
            formattedDate = formatDate();
        }
    }

    // Method to fetch the related data: Opportunity, Contact, QuoteLineItems, and Product Images
    public void fetchRelatedData() {
        
        this.quoteRecord = [
        Select Id, QuoteNumber, ExpirationDate, TotalPriceAfterDiscount__c ,Opportunity.Owner.Name, Opportunity.Owner.Email, OpportunityId 
        from Quote 
        Where ID = :quoteId 
        Limit 1
        ];


        // Fetch the QuoteLineItems, categorize them into Main and Accessory
        List<QuoteLineItem> allItems = [SELECT Id, Product2Id, Product2.Family, Product2.Name, Product2.ProductCode, 
                                        Product2.QTE_ProductTitle__c, Product2.QTE_ProductDescription__c, Product2.QTE_ProductShortDescription__c,
                                        Product2.QTE_ProductDimension__c, Quantity, TotalPrice
                                        FROM QuoteLineItem WHERE QuoteId = :quoteRecord.Id Order BY Product2.ProductCode ASC];

        accessoryProducts = new List<QuoteLineItem>();

        for (QuoteLineItem item : allItems) {
            if (item.Product2.Family == 'Main') {
                mainProduct = item;  // Store the main product (only one expected)
            } else if (item.Product2.Family == 'Accessories') {
                accessoryProducts.add(item);  // Add accessory products to the list
            }
        }
        system.debug('accessoryProducts '+accessoryProducts);

        // Fetch product images for the main and accessory products
        fetchProductImages(allItems);

        // Fetch Opportunity and Primary Contact details
        fetchOpportunityAndContact();
    }

    // Method to fetch product images from the related ContentDocument
    public void fetchProductImages(List<QuoteLineItem> allItems) {
        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem item : allItems) {
            productIds.add(item.Product2Id);
        }

        List<ContentDocumentLink> contentDocumentLinks = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId, 
                   ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.FileType
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :productIds
            ORDER BY ContentDocument.CreatedDate DESC
        ];

        productImageMap = new Map<Id, ContentDocument>();
        for (ContentDocumentLink link : contentDocumentLinks) {
            if (!productImageMap.containsKey(link.LinkedEntityId)) {
                productImageMap.put(link.LinkedEntityId, link.ContentDocument);
            }
        }
    }

    // Fetch the related Opportunity and Primary Contact
    public void fetchOpportunityAndContact() {
        // Fetch the Opportunity related to the Quote
        opportunityRecord = [SELECT Id, Name, Account.Name, Payment__c, PricesQuoteText__c, Delivery__c,
                             Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry 
                             FROM Opportunity 
                             WHERE Id = :quoteRecord.OpportunityId LIMIT 1];

        // Fetch the Primary Contact related to the Opportunity
        OpportunityContactRole primaryContactRole = [SELECT Contact.Salutation, Contact.FirstName, Contact.LastName, Contact.Name,
                                                     Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, 
                                                     Contact.MailingPostalCode, Contact.MailingCountry 
                                                     FROM OpportunityContactRole 
                                                     WHERE OpportunityId = :opportunityRecord.Id AND IsPrimary = TRUE LIMIT 1];

        if (primaryContactRole != null) {
            this.primaryContact = primaryContactRole.Contact;
        }
    }

    // Method to format date in "dd. MMMM yyyy" format
    public String formatDate() {
        Date today = Date.today();
        String day = String.valueOf(today.day());
        String month = getMonthName(today.month());
        String year = String.valueOf(today.year());
        return day + '. ' + month + ' ' + year;
    }

    // Method to get month name in German
    public String getMonthName(Integer month) {
        switch on month {
            when 1 { return 'Januar'; }
            when 2 { return 'Februar'; }
            when 3 { return 'März'; }
            when 4 { return 'April'; }
            when 5 { return 'Mai'; }
            when 6 { return 'Juni'; }
            when 7 { return 'Juli'; }
            when 8 { return 'August'; }
            when 9 { return 'September'; }
            when 10 { return 'Oktober'; }
            when 11 { return 'November'; }
            when 12 { return 'Dezember'; }
            when else { return ''; }
        }
    }
    @RemoteAction
    public static String formatCurr(Decimal amount) {
        if (amount == null) {
            return '€ 0,-';
        }
        String formattedAmount = String.format('{0,number,#,###}', new Object[]{amount});
        return '€ ' + formattedAmount + ',-';
    }

// Attach the PDF to the Quote
@AuraEnabled
public static String attachPdfToQuote(Id quoteId) {
    Blob pdfBlob = generatePDF(quoteId);

    // Attach PDF as ContentVersion to Quote
    ContentVersion contentVersion = new ContentVersion();
    contentVersion.Title = 'Quote PDF';
    contentVersion.PathOnClient = 'Quote.pdf';
    contentVersion.VersionData = pdfBlob;
    contentVersion.FirstPublishLocationId = quoteId;
    insert contentVersion;

    return 'PDF attached to the quote successfully.';
}

// Attach the PDF to the Quote and send it via email
@AuraEnabled
public static String attachAndSendEmail(Id quoteId) {
    Blob pdfBlob = generatePDF(quoteId);

    // Attach PDF as ContentVersion to Quote
    ContentVersion contentVersion = new ContentVersion();
    contentVersion.Title = 'Quote PDF';
    contentVersion.PathOnClient = 'Quote.pdf';
    contentVersion.VersionData = pdfBlob;
    contentVersion.FirstPublishLocationId = quoteId;
    insert contentVersion;

    // Send the email to the primary contact
    sendEmailWithAttachment(quoteId, pdfBlob);

    return 'PDF attached to the quote and sent via email.';
}

// Method to generate the PDF for the Quote
public static Blob generatePDF(Id quoteId) {
    PageReference pdfPage = Page.QuotePDF; // Replace with your Visualforce PDF page
    pdfPage.getParameters().put('RecordId', quoteId);
    return pdfPage.getContentAsPDF();
}

// Send an email to the primary contact with the PDF attached
public static void sendEmailWithAttachment(Id quoteId, Blob pdfBlob) {
        Id primaryContactId;
        Quote quoteRecord = [SELECT OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1];
        
        Opportunity opportunityRecord1 = [SELECT Id, Name, Account.Name, 
                             Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry 
                             FROM Opportunity 
                             WHERE Id = :quoteRecord.OpportunityId LIMIT 1];

        // Fetch the Primary Contact related to the Opportunity
        OpportunityContactRole primaryContactRole1 = [SELECT Contact.Salutation, Contact.FirstName, Contact.LastName, Contact.Name,
                                                     Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, 
                                                     Contact.MailingPostalCode, Contact.MailingCountry 
                                                     FROM OpportunityContactRole 
                                                     WHERE OpportunityId = :opportunityRecord1.Id AND IsPrimary = TRUE LIMIT 1];

        if (primaryContactRole1 != null) {
            primaryContactId = primaryContactRole1.ContactId;
        }
        
    if (primaryContactId != null ) {
        // Create email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(primaryContactId); // Use the primary contact ID
        email.setTemplateId([SELECT Id FROM EmailTemplate WHERE DeveloperName = 'QuoteEmailTemplate' LIMIT 1].Id); // Select email template

        // Attach PDF
        Messaging.EmailFileAttachment pdfAttachment = new Messaging.EmailFileAttachment();
        pdfAttachment.setFileName('Quote.pdf');
        pdfAttachment.setBody(pdfBlob);
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { pdfAttachment });

        // Send email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    } else {
        throw new AuraHandledException('No primary contact or email found for the account.');
    }
}


}