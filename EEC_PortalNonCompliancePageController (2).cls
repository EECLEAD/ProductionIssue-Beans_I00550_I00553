/**
* EEC_PortalNonCompliancePageController
* 
* @description This is conroller for portal page EEC_PortalNonCompliancePage and also for 
* EEC_GenerateProviderNonComplianceHistory page that is used to create a pdf version of the correction
* plan submitted by the provider. 
* Providers will see all the non-compliances grouped by related visit/investigation on this page. They 
* can add their correction plan, supporting documents etc and submit.
* @devNotes Currently using without sharing to avoid insufficient access error which is probably due
* to some update on a related record. This needs to be further evaluated and removed. [Qamar - 081817]
* @author Incapsulate Team
* @date 2017
*/

global without sharing class EEC_PortalNonCompliancePageController {
 
   public List<Inspection_Item__c> visititems {get;set; }
   public List<Inspection__c> relatedVisits {get; set;}
   public List<Inspection_Item__c> investigationvVisitItems {get;set; } 
   public List<Non_Compliant__c>  noncompitems {get;set; } 
   public Set<String> allVisits = new Set<String>();
   public Set<String> allInvestigationVisits = new Set<String>(); 
   public Set<String> allInvestigation = new Set<String>();
   public List<InspectionListWrapper> iiWrapperList {get;set;}
   public List<ComplainceListWrapper> ncWrapperList {get;set;}
   public Map<Id,InspectionListWrapper> iiMap {get; set;} 
    
   public List<InspectionListWrapper> iiVisitWrapperList {get;set;}
   public List<InspectionListWrapper> iiInvWrapperList {get;set;} 

   public List<Case> incidentInjuryCase {get;set;}
   public Set<String> allCNVisits = new Set<String>();   
   public List<Inspection__c> visititemsC {get;set;}   
   public List<InsInvListReportWrapper>  reportVisitWrapperList {get;set;} 
   public List<InsInvListReportWrapper> reportInvestigationWrapperList {get;set;}  
   public List<visitCNCListReportWrapper> reportvistCWrapperList {get;set;}
   public List<visitCNCListReportWrapper> viCNAllWrapperList {get;set;}  
   public Set<String> allCVisits = new Set<String>();
   Public Map<String, List<visitCNCListReportWrapper>> allVisitCNCItems {get;set;} 
   Public List<CaseIncidentInjuryListWrapper> cseIncidentInjuryList {get;set;}
   
   Public Map<String,List<InspectionListWrapper>> allInvNonComplianceItems {get; set;}
   Private Map<String,Id> allInvIds = new Map<String,Id>();
   Public Map<String,List<InspectionListWrapper>> allVisitNonComplianceItems {get; set;}
   public Integer valcount {get;set; }
   public ID accountid {get; private set;}
   public Id invId {get; private set;}
   public Account provider {get; private set;}
   public String memberId {get;set;}
   public String mode {get;set;} 
   public boolean saveForLater {get; set;}
   private String id { get; set; } 
   private List<boolean> viewTypes = new List<boolean>();
    
    
   EmailTemplate template34 = [SELECT Body, Subject FROM EmailTemplate WHERE DeveloperName = 'X34_Alert_to_licensor_that_corrective_actions_have_been_submitted'];
       
   public EEC_PortalNonCompliancePageController() {  
       memberId = ApexPages.currentPage().getParameters().get('member');
       mode = ApexPages.currentPage().getParameters().get('mode');
       String view = ApexPages.currentPage().getParameters().get('view');
       System.debug('view-->' + view);
       viewTypes.add(True);
       if(String.isNotBlank(view)){
           viewTypes.add(False);
       } 
       if(String.isNotBlank(memberId)){
           accountid = memberId;
           //memberId = EEC_Util.encryptGetParam(EncodingUtil.urlDecode(memberId, 'UTF-8'));
       }
       else{
           List<Account> tempAccount = [SELECT Id 
                                        FROM Account 
                                        WHERE ID in 
                                        (SELECT Accountid 
                                         FROM User WHERE id = :Userinfo.getUserId()) LIMIT 1];
           
           if (tempAccount != null && tempAccount.size() == 1) {
             accountid = tempAccount.get(0).Id;    
           }
       }
       if(String.isBlank(accountid)){
           accountid = ApexPages.currentPage().getParameters().get('accountid');
       }

       if(String.isnotBlank(accountid))
       {
           provider = [SELECT Id, Owner.Email,Name, Provider_Number__c,Owner.Out_of_Office__c,Owner.ManagerId,
                       Provider_Full_Address__c, Last_Issue_Date__c, Renewal_date__c,Owner.Manager.Email,
                       Licensor_Full_Name__c
                       FROM Account WHERE Id = :accountId];
           getitems();
       }                 
   }
   
   public pageReference generatePDF(){
        PageReference pagePdf = ApexPages.currentPage();
        pagePdf.getParameters().put('view','all');
        if(String.isNotBlank(mode)){
            return savePDF();
        }
       else
           return null;
   } 
   
   public pageReference savePDF(){
        PageReference pagePdf = ApexPages.currentPage();
        Blob pdfPageBlob;
        pagePdf.getParameters().put('mode','');
        pdfPageBlob = Test.isRunningTest() ? Blob.valueOf('UNIT.TEST') : pagePdf.getContentAsPDF();
             
        Attachment a = new Attachment();
        a.Body = pdfPageBlob;
        a.ParentID = provider.Id;
        a.Name = 'Program Transaction History - ' + provider.Name + '.pdf';
        insert a;
                 
        return new PageReference('/' + provider.Id);
    } 
    
   public PageReference returnProvider() {
    PageReference pPage = page.EEC_PortalProviderPage;
    if(memberId != null)  
       pPage.getParameters().put('member',memberId);
    return pPage;
  }
    
   public void getitems(){    
         
        iiWrapperList = new List<InspectionListWrapper>();
        Map<Id,Map<String,String>> iregulationMap = new Map<Id,Map<String,String>>();
        Map<String,String> jiMap;
        //Changes starts here
        Map<Id,Map<String,String>> iRegulationVNMap = new Map<Id,Map<String,String>>();
        Map<Id,Map<String,String>> iRegulationVCMap = new Map<Id,Map<String,String>>();
        Map<String,String> jiVNMap;
        Map<String,String> jiVCMap;
        //Changes ends here
        iiMap = new Map<Id,InspectionListWrapper>();
               
     
        visititems = [SELECT Id,Recordtype.Name,Observations__c,Corrective_Action_EEC_Feedback__c, 
                      Standard_Inspection_Item__c,Associated_regulation__c,
                      Associated_regulation__r.name, Associated_regulation__r.Regulation_Number__c, Inspection_No__c,Inspection_No__r.Visit_Tool_Used__r.Name,Inspection_No__r.RecordType.Name, 
                      Inspection_No__r.Name,Inspection_No__r.Date_Of_Visit__c,Correction_Plan__c,Inspection_No__r.Status__c, 
                      Date_Implemented__c, Inspection_No__r.Investigation__c,Description_of_inspection__c, 
                      Inspection_No__r.Investigation__r.Name, Inspection_No__r.Investigation__r.Closed_Date__c,Inspection_No__r.Investigation__r.Investigation_Status__c
                      FROM Inspection_Item__c 
                      WHERE Inspection_No__r.Provider_No__c = :accountId
                      AND Inspection_Result__c = 'Non-Compliant'
                      AND To_Review_on_Portal__c IN: viewTypes 
                      LIMIT 1000];
                      
    //Changes starts here
        visititemsC = [SELECT Id, Name, Type_of_Visit__c, Status__c, Date_of_Visit__c, Visit_Tool_Used__c, Number_of_non_compliant_items__c, RecordType.DeveloperName
                       FROM Inspection__c 
                       WHERE Provider_No__c = :accountId AND
                             Number_of_non_compliant_items__c = 0         AND
                             RecordType.DeveloperName != 'Investigation_Visits' AND
                             RecordType.DeveloperName != 'Investigation_Visits_with_Non_Compliance'
                       LIMIT 9000];
        system.debug('Compliant Visits : ' + visititemsC);
        
        cseIncidentInjuryList = new List<CaseIncidentInjuryListWrapper>();
        incidentInjuryCase = [SELECT CaseNumber, Origin, Status, ClosedDate, CreatedDate, Note_To_User__c, RecordType.DeveloperName, HasInvestigation__c, Investigation__c, Investigation__r.Investigation_Status__c
                        FROM Case
                        WHERE AccountId = :accountId AND
                             (RecordType.DeveloperName = 'Incident' OR RecordType.DeveloperName = 'SGLSA_Injury') AND
                              HasInvestigation__c = TRUE AND
                              Investigation__r.Investigation_Status__c = 'Closed'
                        ORDER BY CreatedDate DESC];
        system.debug('Incident : ' + incidentInjuryCase);
        for(Case c :incidentInjuryCase){
            cseIncidentInjuryList.add(new CaseIncidentInjuryListWrapper(c));
        }      
    //Changes ends here                   
                      
           //Getting list of all visits that may need staus update once visit items are reviewed. Qamar (LEAD-4678)
           Set<id> relatedVisitIdSet = new Set<Id>();
           for(Inspection_Item__c ii : visititems){
              relatedVisitIdSet.add(ii.Inspection_No__c);
           }
           relatedVisits = [SELECT ID, Status__c FROM Inspection__c WHERE Id IN :relatedVisitIdSet];



           Set<Id> siSet = new Set<Id>(); 
           System.debug('viewTypes-->' + viewTypes);
           System.debug('visititems-->' + visititems);    
           if(visititems != null && visititems.size() > 0){
               
                for(Inspection_Item__c ii : visititems){
                    if(ii.RecordType.Name == 'Standard Visit Item'){
                        siSet.add(ii.Standard_Inspection_Item__c);
                        invId = ii.Inspection_No__r.Investigation__c;
                    }
                }
           
               for(Junction_InspReg__c jir : [SELECT Id,Regulation__c,Standard_Inspection_Item__c,
                                              Regulation__r.name, Regulation__r.Regulation_Number__c 
                                              FROM Junction_InspReg__c 
                                              WHERE Standard_Inspection_Item__c in :siSet]){
                  if(iregulationMap.containsKey(jir.Standard_Inspection_Item__c)){
                     iregulationMap.get(jir.Standard_Inspection_Item__c).put(jir.Regulation__r.Regulation_Number__c+',', jir.Regulation__c);

                  }
                  else{
                     jiMap = new Map<String,String>();
                     jiMap.put(jir.Regulation__r.Regulation_Number__c+',', jir.Regulation__c);
                     iregulationMap.put(jir.Standard_Inspection_Item__c,jiMap);
                
                  }
               }
               Integer rowIndex = 0; 
               
               System.debug('visititems-->' + visititems);
               iiVisitWrapperList = new List<InspectionListWrapper>();
               investigationvVisitItems = new List<Inspection_Item__c>();
         
               for(Inspection_Item__c ii : visititems){ 
                   if(!allVisits.contains(ii.Inspection_No__r.Name) && ii.Inspection_No__r.Investigation__c == null)
                       iiVisitWrapperList.add(new InspectionListWrapper(rowIndex,ii,iregulationMap));

                   if(ii.Inspection_No__r.Investigation__c != null){
                       investigationvVisitItems.add(ii);
                       allInvestigationVisits.add(ii.Inspection_No__r.Investigation__r.Name);
                   }
                   allVisits.add(ii.Inspection_No__r.Name); 
                   iiWrapperList.add(new InspectionListWrapper(rowIndex,ii,iregulationMap));  
                   iiMap.put(ii.Id, new InspectionListWrapper(rowIndex,ii,iregulationMap));
                   rowIndex = rowIndex + 1;
               }
           }
                                              
             
        ncWrapperList = new List<ComplainceListWrapper>();
        iiInvWrapperList = new List<InspectionListWrapper>();
        reportInvestigationWrapperList  = new List<InsInvListReportWrapper>();
        Integer rowIndex = 0; 
        Integer rowNIdx  = 0;       
        noncompitems = [SELECT Id,Name,Recordtype.Name,Observations__c,Investigation__c,
                        Corrective_Action_EEC_Feedback__c,Investigation__r.Investigation_Type__c,
                        Investigation__r.name,Correction_Plan__c,Date_Implemented__c,
                        Investigation__r.Closed_Date__c, Investigation__r.Investigation_Status__c 
                        FROM Non_Compliant__c 
                        WHERE Investigation__r.Provider_No__c = :accountId 
                        AND To_Review_on_Portal__c IN: viewTypes LIMIT 200 ];
       
           Set<Id> ncSet = new Set<Id>();
           if(noncompitems != null && noncompitems.size() > 0){
                
               for(Non_Compliant__c nc : noncompitems){
                    ncSet.add(nc.id);
                    invId = nc.Investigation__r.Id;
               }
               Map<String,String> ncMap; 
               Map<Id,Map<String,Id>> ncregulationMap = new Map<Id,Map<String,String>>();
               
               for(Non_Compliant_Item_Regulation__c ncr : [SELECT Id,Non_Compliant_Item__c,
                                                           Regulation__c,Regulation__r.name, Regulation__r.Regulation_Number__c 
                                                           FROM Non_Compliant_Item_Regulation__c 
                                                           WHERE Non_Compliant_Item__c in :ncSet]){
                  if(ncregulationMap.containsKey(ncr.Non_Compliant_Item__c)){
                     ncregulationMap.get(ncr.Non_Compliant_Item__c).put(ncr.Regulation__r.Regulation_Number__c+',', ncr.Regulation__c);

                  }
                  else{
                     ncMap = new Map<String,String>();
                     ncMap.put(ncr.Regulation__r.Regulation_Number__c+',', ncr.Regulation__c);
                     ncregulationMap.put(ncr.Non_Compliant_Item__c,ncMap);
                
                  }
               }
               for(Non_Compliant__c nc : noncompitems){  
                   if(!allInvestigation.contains(nc.Investigation__r.name)){
                       iiInvWrapperList.add(new InspectionListWrapper(rowIndex,nc,ncregulationMap));
                       if((nc.Investigation__r.Investigation_Status__c  == 'Closed'  || nc.Investigation__r.Investigation_Status__c  == 'Closed (Legacy Investigation)' || nc.Investigation__r.Investigation_Status__c  == 'Report Sent to Provider, Awaiting feedback' || nc.Investigation__r.Investigation_Status__c  == 'Feedback received, to review') && nc.Investigation__r.Closed_Date__c != null){
                            reportInvestigationWrapperList.add(new InsInvListReportWrapper(rowNIdx,nc,ncregulationMap,'investigation','Non-Compliant'));
                            system.debug('===> reportInvestigationWrapperList : ' + reportInvestigationWrapperList);
                            rowNIdx = rowNIdx + 1;
                        }                      
                    }
                   allInvestigation.add(nc.Investigation__r.name);
                   
                   iiWrapperList.add(new InspectionListWrapper(rowIndex,nc,ncregulationMap));
                   iiMap.put(nc.Id, new InspectionListWrapper(rowIndex,nc,ncregulationMap));                   
                   rowIndex = rowIndex + 1;
               }
       }
       System.debug('iiWrapperList-->' + iiWrapperList);
       System.debug('iiVisitWrapperList-->' + iiVisitWrapperList);
       if(investigationvVisitItems != null && investigationvVisitItems.size() > 0){
               for(Inspection_Item__c ii : investigationvVisitItems){
                   if(!allInvestigation.contains(ii.Inspection_No__r.Investigation__r.Name)){
                       iiInvWrapperList.add(new InspectionListWrapper(rowIndex,ii,iregulationMap));
                       if((ii.Inspection_No__r.Status__c  == 'Closed' || ii.Inspection_No__r.Status__c  == 'Closed (Legacy Investigation)' || ii.Inspection_No__r.Status__c  == 'Report Sent to Provider, Awaiting feedback' || ii.Inspection_No__r.Status__c  == 'Feedback received, to review') && ii.Inspection_No__r.Investigation__r.Closed_Date__c != null){
                            reportInvestigationWrapperList.add(new InsInvListReportWrapper(rowNIdx,ii,iregulationMap,'investigation','Non-Compliant'));
                            system.debug('===> reportInvestigationWrapperList : ' + reportInvestigationWrapperList);
                            rowNIdx = rowNIdx + 1;  
                        }                      
                    }
                   allInvestigation.add(ii.Inspection_No__r.Investigation__r.Name);

                   rowIndex = rowIndex + 1; 
               }
        }      
       //Changes starts here
       System.debug('==> reportVisitWrapperList : ' + reportVisitWrapperList);
       if(reportVisitWrapperList != null && reportVisitWrapperList.size() > 0){
          system.debug('Before Sorting reportVisitWrapperList : ' + reportVisitWrapperList);
          reportVisitWrapperList.sort();
          system.debug('After Sorting reportVisitWrapperList : ' + reportVisitWrapperList);
       }

       allVisitCNCItems = new Map<String, List<visitCNCListReportWrapper>>();
       for(String name : allCNVisits){
           List<visitCNCListReportWrapper> visitCNWList = new List<visitCNCListReportWrapper>();
           for(visitCNCListReportWrapper iCNWL :viCNAllWrapperList){
               if(iCNWL.visitname == name){
                   visitCNWList.add(iCNWL);
               }
           }
           allVisitCNCItems.put(name,visitCNWList);
       }
       
       system.debug('reportInvestigationWrapperList : ' + reportInvestigationWrapperList);
       if(reportInvestigationWrapperList != null && reportInvestigationWrapperList.size() > 0){
          system.debug('Before Sorting reportInvestigationWrapperList : ' + reportInvestigationWrapperList);
          reportInvestigationWrapperList.sort();
          system.debug('After Sorting reportInvestigationWrapperList : ' + reportInvestigationWrapperList);
       }      
       //Changes ends here     
       allInvNonComplianceItems = new Map<String, List<InspectionListWrapper>>();
       allVisitNonComplianceItems = new Map<String, List<InspectionListWrapper>>();
       for(String name : allInvestigation){
           Id invId;
           List<InspectionListWrapper> wrapperList = new List<InspectionListWrapper>();
           for(InspectionListWrapper ilw : iiWrapperList){
               if(ilw.name == name || ilw.inspItem.Inspection_No__r.Investigation__r.Name == name){
                    wrapperList.add(ilw);
               }
               invId = ilw.inspItem.Inspection_No__r.Investigation__c; 
           }
           allInvNonComplianceItems.put(name,wrapperList);
           allInvIds.put(name, invId);
       }
       System.debug('allInvNonComplianceItems-->' + allInvNonComplianceItems);
       System.debug('allVisits-->' + allVisits);
       for(String name : allVisits){
           List<InspectionListWrapper> wrapperList = new List<InspectionListWrapper>();
           for(InspectionListWrapper ilw : iiWrapperList){
               if(ilw.visitname == name){
                    wrapperList.add(ilw);
               }
           }
           allVisitNonComplianceItems.put(name,wrapperList);
       }    
       
       System.debug('allVisitNonComplianceItems-->' + allVisitNonComplianceItems);
       if((visititems == null && visititems.size() == 0) && (noncompitems == null && noncompitems.size() == 0)){
           ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Current, there is no non-compliance that requires your feedback.'));           
       }
  }

  public class InspectionListWrapper{
       
    public Id Id {get;set;}
    public String visitname {get;set;}
    public Integer rowIndex { get; set; }
    public String Type {get; private set;}
    public Map<String,String> regulationMap {get; set;}
    public String dateofvisit {get;set;}
    public String closedDate {get;set;}  
    public String implementdate {get;set;}
    public String observations {get;set;}
    public String correctionPlan {get;set;}
    public Inspection_Item__c inspItem {get;set;}
    public String name {get;set;}  
    public String InvestType {get; private set;}
    public Non_Compliant__c compItem {get;set;}
    public String ncFeedback {get; set;}  
    public String viFeedback {get; set;}
    public String invId {get;set;}
    public String inspDescription {get; set;}
    public String inspStatus {get; set;}
    public String inspToolUser {get; set;}
    public String inspType {get; set;}
    public String invStatus {get; set;}  
    
    public InspectionListWrapper (Integer rowIndex, Inspection_Item__c insp,Map<Id, Map<String,String>> iRegMap) {
         System.debug('********ID-- ' + insp.Id);
         this.Id = insp.Id;
         this.rowIndex = rowIndex;
         this.Type = insp.RecordType.Name;
         this.regulationMap = null;
         if(this.Type == 'Standard Visit Item' && insp.Standard_Inspection_Item__c != null){
              this.regulationMap = iRegMap.get(insp.Standard_Inspection_Item__c);
         }
         else{
              this.regulationMap = new Map<String,String>();
              if(insp.Associated_regulation__c != null){
                this.regulationMap.put(insp.Associated_regulation__r.Regulation_Number__c,insp.Associated_regulation__c);
              }
            }
            System.debug('********regulationMap-- '+this.regulationMap);
            this.visitname = insp.Inspection_No__r.Name;
            this.name = insp.Inspection_No__r.Investigation__r.Name;
            this.invId = insp.Inspection_No__r.Investigation__c;
            this.implementdate = insp.Date_Implemented__c != null ? insp.Date_Implemented__c.format() : String.valueOf(insp.Date_Implemented__c);
            this.dateofvisit = insp.Inspection_No__r.Date_Of_Visit__c != null ? insp.Inspection_No__r.Date_Of_Visit__c.format() : String.valueOf(insp.Inspection_No__r.Date_Of_Visit__c);
            this.closedDate = insp.Inspection_No__r.Investigation__r.Closed_Date__c != null ? insp.Inspection_No__r.Investigation__r.Closed_Date__c .format() : String.valueOf(insp.Inspection_No__r.Investigation__r.Closed_Date__c);
            this.observations = insp.observations__c;
            this.correctionPlan = insp.correction_plan__c;
            this.inspItem = insp;
            this.viFeedback = insp.Corrective_Action_EEC_Feedback__c;
            this.inspDescription = insp.Description_of_inspection__c;
            this.inspStatus = insp.Inspection_No__r.Status__c;
            this.inspToolUser = insp.Inspection_No__r.Visit_Tool_Used__r.Name;
            this.inspType = insp.Inspection_No__r.RecordType.Name;
            this.invStatus = insp.Inspection_No__r.Investigation__r.Investigation_Status__c;
      }
       
      public InspectionListWrapper (Integer rowIndex, Non_Compliant__c ncomp,Map<Id, Map<String,String>> nRegMap) {
         this.Id = ncomp.Id;
         this.rowIndex = rowIndex;
         this.Type = ncomp.RecordType.Name;
         this.InvestType = ncomp.Investigation__r.Investigation_Type__c;
         this.regulationMap = null;
         if(ncomp.Name != null){
              this.regulationMap = nRegMap.get(ncomp.id);
         }
            System.debug('********Non Complaince regulationMap-- '+this.regulationMap);
            this.name = ncomp.Investigation__r.name;
            this.implementdate = ncomp.Date_Implemented__c != null ? ncomp.Date_Implemented__c.format() : String.valueOf(ncomp.Date_Implemented__c);
            this.observations = ncomp.observations__c;
            this.closedDate = ncomp.Investigation__r.Closed_Date__c != null ? ncomp.Investigation__r.Closed_Date__c.format() : String.valueOf(ncomp.Investigation__r.Closed_Date__c);
            this.correctionPlan = ncomp.correction_plan__c;
            this.compItem = ncomp;
            this.ncFeedback = ncomp.Corrective_Action_EEC_Feedback__c;
            this.invStatus = ncomp.Investigation__r.Investigation_Status__c;
            this.invId = ncomp.Investigation__c;
        }
    }
    
   //Changes starts here
   global class InsInvListReportWrapper implements Comparable{
       
    public Id Id {get;set;}
    public String visitname {get;set;}
    public Integer rowIndex { get; set; }
    public String Type {get; private set;}
    public Map<String,String> regulationMap {get; set;}
    public String dateofvisit {get;set;}
    public String closedDate {get;set;}  
    public String implementdate {get;set;}
    public String observations {get;set;}
    public String correctionPlan {get;set;}
    public Inspection_Item__c inspItem {get;set;}
    public String name {get;set;}  
    public String InvestType {get; private set;}
    public Non_Compliant__c compItem {get;set;}
    public String ncFeedback {get; set;}  
    public String viFeedback {get; set;}
    public String invId {get;set;}
    public String inspDescription {get; set;}
    public String inspStatus {get; set;}
    public String inspToolUser {get; set;}
    public String inspType {get; set;}
    public String invStatus {get; set;}
    public String iiType {get; set;}
    public String visitResult {get; set;}
    
    public InsInvListReportWrapper (Integer rowIndex, Inspection_Item__c insp,Map<Id, Map<String,String>> iRegMap, String striiType, String strVisitResult) {
         this.Id = insp.Id;
         this.rowIndex = rowIndex;
         this.Type = insp.RecordType.Name;
         this.regulationMap = null;
         if(this.Type == 'Standard Visit Item' && insp.Standard_Inspection_Item__c != null){
              this.regulationMap = iRegMap.get(insp.Standard_Inspection_Item__c);
         }
         else{
              this.regulationMap = new Map<String,String>();
              if(insp.Associated_regulation__c != null){
                this.regulationMap.put(insp.Associated_regulation__r.Regulation_Number__c,insp.Associated_regulation__c);
              }
            }
            this.visitname = insp.Inspection_No__r.Name;
            this.name = insp.Inspection_No__r.Investigation__r.Name;
            this.invId = insp.Inspection_No__r.Investigation__c;
            this.implementdate = insp.Date_Implemented__c != null ? insp.Date_Implemented__c.format() : String.valueOf(insp.Date_Implemented__c);
            this.dateofvisit = insp.Inspection_No__r.Date_Of_Visit__c != null ? insp.Inspection_No__r.Date_Of_Visit__c.format() : String.valueOf(insp.Inspection_No__r.Date_Of_Visit__c);
            this.closedDate = insp.Inspection_No__r.Investigation__r.Closed_Date__c != null ? insp.Inspection_No__r.Investigation__r.Closed_Date__c .format() : String.valueOf(insp.Inspection_No__r.Investigation__r.Closed_Date__c);
            this.observations = insp.observations__c;
            this.correctionPlan = insp.correction_plan__c;
            this.inspItem = insp;
            this.viFeedback = insp.Corrective_Action_EEC_Feedback__c;
            this.inspDescription = insp.Description_of_inspection__c;
            this.inspStatus = insp.Inspection_No__r.Status__c;
            this.inspToolUser = insp.Inspection_No__r.Visit_Tool_Used__r.Name;
            this.inspType = insp.Inspection_No__r.RecordType.Name;
            this.invStatus = insp.Inspection_No__r.Investigation__r.Investigation_Status__c;
            this.iiType = striiType;
            this.visitResult = strVisitResult;
      }
       
      public InsInvListReportWrapper (Integer rowIndex, Non_Compliant__c ncomp, Map<Id, Map<String,String>> nRegMap, String striiType, String strVisitResult) {
         this.Id = ncomp.Id;
         this.rowIndex = rowIndex;
         this.Type = ncomp.RecordType.Name;
         this.InvestType = ncomp.Investigation__r.Investigation_Type__c;
         this.regulationMap = null;
         if(ncomp.Name != null){
              this.regulationMap = nRegMap.get(ncomp.id);
         }
            this.name = ncomp.Investigation__r.name;
            this.implementdate = ncomp.Date_Implemented__c != null ? ncomp.Date_Implemented__c.format() : String.valueOf(ncomp.Date_Implemented__c);
            this.observations = ncomp.observations__c;
            this.closedDate = ncomp.Investigation__r.Closed_Date__c != null ? ncomp.Investigation__r.Closed_Date__c.format() : String.valueOf(ncomp.Investigation__r.Closed_Date__c);
            this.correctionPlan = ncomp.correction_plan__c;
            this.compItem = ncomp;
            this.ncFeedback = ncomp.Corrective_Action_EEC_Feedback__c;
            this.invStatus = ncomp.Investigation__r.Investigation_Status__c;
            this.invId = ncomp.Investigation__c;
            this.iiType = striiType;
            this.visitResult = strVisitResult;
        }
        
      global Integer compareTo(Object compareTo) {
            InsInvListReportWrapper InspInvWrapper = (InsInvListReportWrapper)compareTo;
            
            system.debug('===> iiType : ' + iiType);
            if(iiType == 'inspection'){
                system.debug('Inspection ==>');
                system.debug('#######> This.dateofvisit : ' + this.dateofvisit);
                system.debug('===> this.dateofvisit : ' + this.dateofvisit);
                system.debug('===> InspInvWrapper.dateofvisit : ' + InspInvWrapper.dateofvisit);
                if(this.dateofvisit != null && this.dateofvisit != ''){
                    if(date.parse(this.dateofvisit) > date.parse(InspInvWrapper.dateofvisit)){ 
                        system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                        system.debug('===> date.parse(InspInvWrapper.dateofvisit) : ' + date.parse(InspInvWrapper.dateofvisit));    
                        system.debug('Return -1');
                        return -1;
                    } else {
                        if(date.parse(this.dateofvisit) < date.parse(InspInvWrapper.dateofvisit)){    
                            system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                            system.debug('===> date.parse(InspInvWrapper.dateofvisit : ' + date.parse(InspInvWrapper.dateofvisit)); 
                            system.debug('Return +1');                      
                            return 1;                           
                        } else {   
                            system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                            system.debug('===> date.parse(InspInvWrapper.dateofvisit) : ' + date.parse(InspInvWrapper.dateofvisit));    
                            system.debug('Return 0');                           
                            return 0;
                        }
                    }
                } else {     
                            system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                            system.debug('===> date.parse(InspInvWrapper.dateofvisit) : ' + date.parse(InspInvWrapper.dateofvisit));    
                            system.debug('Return +00');                 
                    return 0;
                }
            } else {
                system.debug('Investigation ==>');
                system.debug('++++++> This.closedDate : ' + this.closedDate);
                system.debug('===> InspInvWrapper.closedDate : ' + InspInvWrapper.closedDate);              
                if(this.closedDate != null && this.closedDate != ''){
                    if(date.parse(this.closedDate) > date.parse(InspInvWrapper.closedDate)){  
                            system.debug('===> date.parse(this.closedDate) : ' + date.parse(this.closedDate));
                            system.debug('===> date.parse(InspInvWrapper.closedDate) : ' + date.parse(InspInvWrapper.closedDate));  
                            system.debug('Return -1');                  
                        return -1;                      
                    } else {
                        if(date.parse(this.closedDate) < date.parse(InspInvWrapper.closedDate)){   
                            system.debug('===> date.parse(this.closedDate) : ' + date.parse(this.closedDate));
                            system.debug('===> date.parse(InspInvWrapper.closedDate) : ' + date.parse(InspInvWrapper.closedDate));  
                            system.debug('Return +1');                      
                            return 1;
                            
                        } else {    
                            system.debug('===> date.parse(this.closedDate) : ' + date.parse(this.closedDate));
                            system.debug('===> date.parse(InspInvWrapper.closedDate) : ' + date.parse(InspInvWrapper.closedDate));  
                            system.debug('Return 0');                       
                            return 0;
                        }
                    }
                } else {    system.debug('===> date.parse(this.closedDate) : ' + date.parse(this.closedDate));
                            system.debug('===> date.parse(InspInvWrapper.closedDate) : ' + date.parse(InspInvWrapper.closedDate));  
                            system.debug('Return 000');
                
                    return 0;
                }
            }
      }
    }

    global class visitCNCListReportWrapper implements Comparable{
       
        public Id Id {get;set;}
        public String visitname {get;set;}
        public Integer rowIndex { get; set; }
        public String Type {get; private set;}
        public String dateofvisit {get;set;}
        public Inspection_Item__c inspItem {get;set;}
        public String name {get;set;}  
        public String inspStatus {get; set;}
        public String inspToolUser {get; set;}
        public String inspType {get; set;}
        public String inspDescription {get; set;} 
 
        public String observations {get;set;}
        public String correctionPlan {get;set;}     
        public String implementdate {get;set;}      
        public Map<String,String> regulationMap {get; set;}  
    
        public visitCNCListReportWrapper (Integer rowIndex, Inspection_Item__c insp, Map<Id, Map<String,String>> iCRegMap) {
    
            this.Id = insp.Id;
            this.visitname = insp.Inspection_No__r.Name;        
            this.rowIndex = rowIndex;
            this.Type = insp.RecordType.Name;
            this.dateofvisit = insp.Inspection_No__r.Date_Of_Visit__c != null ? insp.Inspection_No__r.Date_Of_Visit__c.format() : String.valueOf(insp.Inspection_No__r.Date_Of_Visit__c);
            this.inspItem = insp;
            this.name = insp.Inspection_No__r.Investigation__r.Name;
            this.inspStatus = insp.Inspection_No__r.Status__c;
            this.inspToolUser = insp.Inspection_No__r.Visit_Tool_Used__r.Name;
            this.inspType = insp.Inspection_No__r.RecordType.Name;    
            this.inspDescription = insp.Description_of_inspection__c; 
            this.observations = insp.observations__c; 
            this.correctionPlan = insp.correction_plan__c;
            this.implementdate = insp.Date_Implemented__c != null ? insp.Date_Implemented__c.format() : String.valueOf(insp.Date_Implemented__c);       
 
            if(this.Type == 'Standard Visit Item' && insp.Standard_Inspection_Item__c != null){
                this.regulationMap = iCRegMap.get(insp.Standard_Inspection_Item__c);
            } else {
                this.regulationMap = new Map<String,String>();
                if(insp.Associated_regulation__c != null){
                    this.regulationMap.put(insp.Associated_regulation__r.Regulation_Number__c,insp.Associated_regulation__c);
                }
            }       
        }
        
        global Integer compareTo(Object compareTo) {

            visitCNCListReportWrapper visitCWrapper = (visitCNCListReportWrapper)compareTo;

            if(this.dateofvisit != null && this.dateofvisit != ''){
                if(date.parse(this.dateofvisit) > date.parse(visitCWrapper.dateofvisit)){ 
                    system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                    system.debug('===> date.parse(visitCWrapper.dateofvisit) : ' + date.parse(visitCWrapper.dateofvisit));    
                    system.debug('Return -1');
                    return -1;
                } else {
                    if(date.parse(this.dateofvisit) < date.parse(visitCWrapper.dateofvisit)){    
                        system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                        system.debug('===> date.parse(visitCWrapper.dateofvisit : ' + date.parse(visitCWrapper.dateofvisit)); 
                        system.debug('Return +1');                      
                        return 1;                           
                    } else {   
                        system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                        system.debug('===> date.parse(visitCWrapper.dateofvisit) : ' + date.parse(visitCWrapper.dateofvisit));    
                        system.debug('Return 0');                           
                        return 0;
                    }
                }
            } else {     
                system.debug('===> date.parse(this.dateofvisit) : ' + date.parse(this.dateofvisit));
                system.debug('===> date.parse(visitCWrapper.dateofvisit) : ' + date.parse(visitCWrapper.dateofvisit));    
                system.debug('Return +00');                 
                return 0;
            }
        }
    }

    public class CaseIncidentInjuryListWrapper{
       
        public string caseNumber {get;set;}
        public String caseOrigin {get;set;}
        public String caseStatus {get; set;}
        public String formattedClosedDate {get; set;}
        public String formattedCreatedDate {get; set;}
        public String noteToUser {get; set;}
        public String caseType {get; set;}        
        
        public CaseIncidentInjuryListWrapper(Case caseRecords) {
            this.caseNumber             = caseRecords.CaseNumber;
            this.caseOrigin             = caseRecords.Origin;
            this.caseStatus             = caseRecords.Status;
            this.formattedClosedDate    = caseRecords.ClosedDate != null ? caseRecords.ClosedDate.format() : String.valueOf(caseRecords.ClosedDate);
            this.formattedCreatedDate   = caseRecords.CreatedDate != null ? caseRecords.CreatedDate.format() : String.valueOf(caseRecords.CreatedDate);
            this.noteToUser             = caseRecords.Note_To_User__c;
            this.caseType               = caseRecords.RecordType.DeveloperName;
        }
    }  
    //Changes ends here

    public class ComplainceListWrapper{
       
    public Id Id {get;set;}
    public String name {get;set;}
    public Integer rowIndex { get; set;}
    public String Type {get; private set;}
    public String InvestType {get; private set;}
    public Map<String,String> regulationMap {get; set;}
    public String   implementdate {get;set;}
    public String observations {get;set;}
    public String correctionPlan {get;set;}
    public Non_Compliant__c compItem {get;set;}
    
    
    public ComplainceListWrapper(Integer rowIndex, Non_Compliant__c ncomp,Map<Id, Map<String,String>> nRegMap) {
         this.Id = ncomp.Id;
         this.rowIndex = rowIndex;
         this.Type = ncomp.RecordType.Name;
         this.InvestType = ncomp.Investigation__r.Investigation_Type__c;
         this.regulationMap = null;
         if(ncomp.Name != null){
              this.regulationMap = nRegMap.get(ncomp.id);
         }
            System.debug('********Non Complaince regulationMap-- '+this.regulationMap);
            this.name = ncomp.Investigation__r.name;
            this.implementdate = ncomp.Date_Implemented__c != null ? ncomp.Date_Implemented__c.format() : String.valueOf(ncomp.Date_Implemented__c);
            this.observations = ncomp.observations__c;
            this.correctionPlan = ncomp.correction_plan__c;
            this.compItem = ncomp;
        }
    }
    
    private void saveInspectionItems(){
    List<Inspection_Item__c> updateiiList = new List<Inspection_Item__c>();
    List<Non_Compliant__c>   updatencList = new List<Non_Compliant__c>();
    //numberItemsNonSelected = 0;
    Integer iiCount = 0;
    Integer ncCount = 0;
    if(iiWrapperList != null){
      Set<Id> iiWarpperIdSet = new Set<Id>();
      for(InspectionListWrapper ilw : iiWrapperList){
        iiWarpperIdSet.add(ilw.Id);
      }
      Map<Id, Inspection_Item__c> oldItemMap = new Map<Id, Inspection_Item__c>([SELECT ID, Correction_Plan__c 
                            , Save_for_Later__c
                            FROM Inspection_Item__c 
                            WHERE Id IN :iiWarpperIdSet]);
      Map<Id, Non_Compliant__c> oldNonCompMap = new Map<Id, Non_Compliant__c>([SELECT ID
                            , Correction_Plan__c
                            , Save_for_Later__c
                            FROM Non_Compliant__c
                            WHERE Id IN :iiWarpperIdSet]);
      Inspection_Item__c iItem;
      for(InspectionListWrapper ilw : iiWrapperList){
          if(ilw.inspItem != null){ 
              iItem = new Inspection_Item__c();
              iItem.Id = ilw.Id;
              Inspection_Item__c oldItem = oldItemMap.get(ilw.Id);
              if (saveForlater) {
                if ( (String.isBlank(ilw.correctionPlan) && String.isNotBlank(oldItem.Correction_Plan__c))
                      || ilw.correctionPlan <> oldItem.Correction_Plan__c){
                  iItem.Save_for_Later__c = true;
                }
              } else {
                iItem.Save_for_Later__c = false;
                if ( (String.isNotBlank(ilw.correctionPlan) 
                    && String.isBlank(oldItem.Correction_Plan__c))
                    || ilw.correctionPlan <> oldItem.Correction_Plan__c 
                    || oldItem.Save_for_Later__c){
                  iItem.Correction_Plan_Status__c ='Provider Submitted, EEC to Review';
                }
              }
 
              iItem.correction_plan__c = ilw.correctionPlan;
              iItem.Date_Implemented__c = (!String.isBlank(ilw.implementdate) ? Date.parse(ilw.implementdate) : null);
                  
              if(String.isNotBlank(iItem.correction_plan__c)){
                iiCount ++;
              }
              //if(iItem.Date_Implemented__c != null && iItem.Correction_Plan__c != '')
              updateiiList.add(iItem);
          } else if(ilw.compItem != null){
              Non_Compliant__c cItem ;
              cItem = new Non_Compliant__c();
              cItem.Id = ilw.Id;
              Non_Compliant__c oldItem = oldNonCompMap.get(ilw.Id);
              if (saveForlater) {
                if ( (String.isBlank(ilw.correctionPlan) && String.isNotBlank(oldItem.Correction_Plan__c))
                      || ilw.correctionPlan <> oldItem.Correction_Plan__c){
                  cItem.Save_for_Later__c = true;
                }
              } else {
                cItem.Save_for_Later__c = false;
                if ( (String.isNotBlank(ilw.correctionPlan) 
                    && String.isBlank(oldItem.Correction_Plan__c))
                    || ilw.correctionPlan <> oldItem.Correction_Plan__c 
                    || oldItem.Save_for_Later__c){
                  cItem.Correction_Plan_Status__c ='Provider Submitted, EEC to Review';
                }
              }
 
              cItem.correction_plan__c = ilw.correctionPlan;
              cItem.Date_Implemented__c = (!String.isBlank(ilw.implementdate) ? Date.parse(ilw.implementdate) : null);
              
              if(String.isNotBlank(cItem.correction_plan__c)){
                ncCount ++;
              }
              //if(cItem.Date_Implemented__c != null && cItem.Correction_Plan__c != '')
              updatencList.add(cItem);
          }
        }
     }
      if(updatencList.size() > 0){
          update updatencList;
      }
        
      if(updateiiList.size() > 0){
          update updateiiList;
          System.debug('---------> relatedVisitsList: ' + relatedVisits);
          for(Inspection__c visit : relatedVisits){
            if(visit.Status__c != 'Report Sent to Provider, Awaiting feedback'){
              System.debug('-------> Visits: ' + visit);
            } else {
              List<Inspection_Item__c> iiList = [SELECT ID, Inspection_Result__c, To_Review_on_Portal__c, Date_Implemented__c
                                            FROM Inspection_Item__c 
                                            WHERE Inspection_No__c = :visit.Id AND Inspection_Result__c = 'Non-Compliant'
                                              AND To_Review_on_Portal__c = true];
              Integer ncToReviewOnPortal = 0;
              Integer ncDateImplementedNull = 0;
              for(Inspection_Item__c ii : iiList){
                if(ii.To_Review_on_Portal__c = true){
                  ncToReviewOnPortal++;
                }
                if(ii.Date_Implemented__c == null){
                  ncDateImplementedNull++;
                }
              }
              if(ncToReviewOnPortal == 0 && ncDateImplementedNull == 0){
                visit.Status__c = 'Feedback received, to review';
                visit.Validation_Rule_ByPass__c = True ; 
                Update visit;
              }
            }
            
          }
      }
      
      Set<String> totalInvs = allInvestigation;  
      Set<String> totalVisits = allVisits;  
      System.debug('allInvestigationVisits--->' + allInvestigationVisits);  
      System.debug('allInvestigation--->' + allInvestigation);   
      Map<String,Id> cloneAllInvIds = allInvIds;
      getitems();
      List<Investigation__c> invUpdates = new List<Investigation__c>();  
      Boolean emailSent = false;  
      for(String name : totalInvs){
          System.debug('totalInvs--->' + totalInvs);
          if(allInvNonComplianceItems.get(name).isEmpty()){
              if(cloneAllInvIds.get(name) != null){
                  Investigation__c inv = new Investigation__c();
                  inv.Id = cloneAllInvIds.get(name);
                  inv.Corrective_Actions_Submitted_Date__c = System.Today();
                  invUpdates.add(inv);
              }
              Id recordid = [SELECT Id FROM Investigation__c WHERE Name =: name limit 1].Id;
              sendEmail(recordid,'inv'); 
              emailSent = true;
          }
      }
      for(String name : totalVisits){
        System.debug('totalVisits--->' + totalVisits);
        System.debug('allVisitNonComplianceItems--->' + allVisitNonComplianceItems);
        if(allVisitNonComplianceItems.get(name).isEmpty() && !emailSent){
            Id recordid = [SELECT Id FROM Inspection__c WHERE Name =: name limit 1].Id;
            sendEmail(recordid,'visit');
        }
      }
      if(invUpdates.size() > 0)
          update invUpdates;
    }
    
    public PageReference ReturnToProvider(){
        saveForLater = true;
        saveInspectionItems();
        return returnProvider();
    } 
 
    public PageReference saveNoSubmit(){
        saveForLater = true;
        saveInspectionItems();
        if(memberId != null){
          ApexPages.currentPage().getParameters().put('member',memberId);
        } 
        PageReference page = ApexPages.currentPage();
        page.setRedirect(true);
        return page;
    } 
  
    public PageReference Save(){
        saveForLater = false;
        saveInspectionItems();
        if(memberId != null){
          ApexPages.currentPage().getParameters().put('member',memberId);
        } 
        PageReference page = ApexPages.currentPage();
        page.setRedirect(true);
        return page;
    }
  
    public PageReference Cancel(){
        return null;
    }
  
    private void sendEmail(Id recordId, string visitORinv){
        EEC_Config__c baseURL = EEC_Config__c.getOrgDefaults();
        EEC_EmailUtil email = new EEC_EmailUtil();   
        OrgWideEmailAddress owa = [SELECT id, Address FROM OrgWideEmailAddress WHERE DisplayName  = 'EEC LEAD Alert'];  
        email.toAddresses = new List<String>();
        email.toAddresses.add(provider.Owner.Email);
        if(provider.Owner.Out_Of_Office__c && provider.Owner.ManagerId != null)
            email.toAddresses.add(provider.Owner.Manager.Email);
        email.saveAsActivity = false;
        email.orgWideEmailId = owa.Id; 
        if(visitORInv == 'inv'){
            email.plainTextBody = template34.Body.replace('{!Inspection__c.Provider_No__c}', provider.Name)
                                                 .replace('{!Investigation__c.Provider_No__c}','')
                                                 .replace('{!Investigation__c.Link}', baseURL.Salesforce_Base_URL__c  + '/' + recordId)
                                                 .replace('{!Inspection__c.Link}', '');
        }
        else{
            email.plainTextBody = template34.Body.replace('{!Inspection__c.Provider_No__c}', provider.Name)
                                                 .replace('{!Investigation__c.Provider_No__c}','')
                                                 .replace('{!Inspection__c.Link}', baseURL.Salesforce_Base_URL__c  + '/' + recordId)
                                                 .replace('{!Investigation__c.Link}', '');
        }
        email.subject = template34.Subject;  
        email.whatId = provider.Id;
        email.sendEmail();       
 
    }
  
}