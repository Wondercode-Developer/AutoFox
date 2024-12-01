public class GenerateDocumentLWCController {

    @AuraEnabled(cacheable=true)
    public static blob getPDFData(String quoteid) {
    

        SBQQ__Quote__c quote = new SBQQ__Quote__c ();
        quote = [select id,SBQQ__Opportunity2__r.PreferredLanguage__c from SBQQ__Quote__c where id=:quoteid];
        String sfdcBaseURL = URL.getOrgDomainURL().toExternalForm();
        
        String language = quote.SBQQ__Opportunity2__r.PreferredLanguage__c != null ? quote.SBQQ__Opportunity2__r.PreferredLanguage__c :'de';
        Blob pdfData = new PageReference('/apex/GenerateQuotePDF?id='+quote.id+'&language='+language).getContentasPDF();
      
        return pdfData;
    }
    
    @AuraEnabled
    public static void savepdf(String quoteid) {
    
    
        SBQQ__Quote__c quote = new SBQQ__Quote__c ();
        quote = [select id,SBQQ__Account__r.Name,SBQQ__Opportunity2__r.PreferredLanguage__c from SBQQ__Quote__c where id=:quoteid];
        String sfdcBaseURL = URL.getOrgDomainURL().toExternalForm();
        
        String language = quote.SBQQ__Opportunity2__r.PreferredLanguage__c != null ? quote.SBQQ__Opportunity2__r.PreferredLanguage__c :'de';
        Blob pdfData = new PageReference('/apex/GenerateQuotePDF?id='+quote.id+'&language='+language).getContent();
        String pdfname = 'Angebot '+ quote.SBQQ__Account__r.Name;
   
   
        List<contentdocumentlink> cdllist = new List<contentdocumentlink> ();
        cdllist = [select id,ContentDocumentid from contentdocumentlink where LinkedEntityId ='a2MbW000000YBM1'];
   
        Set<id> contentdocumentidset = new set<id> ();
        
        for(contentdocumentlink cdl : cdllist) {
            contentdocumentidset.add(cdl.ContentDocumentid);
        }
        
        List<ContentVersion> cvlist = new List<ContentVersion> ();
        cvlist = [select id,versiondata from ContentVersion where contentdocumentid IN:contentdocumentidset AND islatest=true];
        Blob combinedDataAsBlob;
        for(contentversion cv : cvlist) {
            String combinedDataAsHex =  EncodingUtil.convertToHex(cv.versiondata)+EncodingUtil.convertToHex(new PageReference('/apex/GenerateQuotePDF?id='+quote.id+'&language='+language).getContent());
            combinedDataAsBlob = EncodingUtil.convertFromHex(combinedDataAsHex);
            
        }
        
        ContentVersion contentVersion_1 = new ContentVersion(
            Title=pdfname, 
            PathOnClient =pdfname+'.pdf',
            VersionData = pdfdata, 
            origin = 'H'
        );
        insert contentVersion_1;
        
        ContentVersion contentVersion_2 = [SELECT Id, Title, ContentDocumentId 
                        FROM ContentVersion WHERE Id = :contentVersion_1.Id LIMIT 1];
        
        ContentDocumentLink contentlink = new ContentDocumentLink();
        contentlink.LinkedEntityId = quote.id;
        contentlink.contentdocumentid = contentVersion_2.contentdocumentid;
        contentlink.ShareType = 'V';
        insert contentlink;

      
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAllFiles(String quoteid){
        try {
            system.System.debug('getAllFiles');
            SBQQ__Quote__c quote = new SBQQ__Quote__c ();
            quote = [select id,SBQQ__Opportunity2__r.PreferredLanguage__c from SBQQ__Quote__c where id=:quoteid];
            String language = quote.SBQQ__Opportunity2__r.PreferredLanguage__c != null ? quote.SBQQ__Opportunity2__r.PreferredLanguage__c :'de';

            List<String> fileData = new List<String>();

            List<ContentDocumentlink> cdLinks = [select id,ContentDocumentid from contentdocumentlink where LinkedEntityId ='a2MbW000000YBM1'];

            if(cdLinks.isEmpty()) 
                return null;

            
            Contentversion cv = [SELECT id,VersionData FROM contentversion WHERE ContentDocumentId =:cdLinks[0].ContentDocumentId];

            // Create PDF
            PageReference quotePage = Page.GenerateQuotePDF;
            quotePage.getParameters().put('id',quoteid);
            quotePage.getParameters().put('language',language);
            Blob quotePagePDFBlob;
            try {
                quotePagePDFBlob = quotePage.getContentAsPDF();
            }
            catch (Exception e) {
                quotePagePDFBlob = Blob.valueOf(e.getMessage());
            }
            
            fileData.add(EncodingUtil.base64Encode(quotePagePDFBlob));
            fileData.add(EncodingUtil.base64Encode(cv.VersionData));

            return fileData;

            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}