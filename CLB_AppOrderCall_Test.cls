/********************************************************************************************************************
* NAME        : CLB_AppOrderCall_Test
* DESCRIPTION : Test class for CLB_AppOrderCall

* @AUTHOR : Divya JC
* @DATE : 04/06/2020
*
* MODIFICATION LOG:
* DEVELOPER                   DATE                             DESCRIPTION
* ------------------------------------------------------------------------------------------------------------------               
* ********************************************************************************************************************/
@isTest
public class CLB_AppOrderCall_Test {
    /********************************************************************************************
METHOD NAME    : TestDataSetup
DESCRIPTION    : Sets up the test data to be used in the methods below
RETURN TYPE    : void
PARAMETER      : None
*********************************************************************************************/  
    @testSetup 
    static void setup() {
        User cityEmployeeUser = CLB_TestDataGenerator.createCLBEmployeeUser(true,'CityEmployee','User','cityEmployeeUser@test.com');
        system.runAs(cityEmployeeUser){
            case cse = CLB_TestDataGenerator.createCase(FALSE,'New','GPC',33.7829822,-118.1969889,'West Anaheim Street', 'Long Beach CA', 'CA','US','90813','Graffiti');
            Case cse1=CLB_TestDataGenerator.createCase(TRUE,'New','GPC',33.7829822,-118.1969889,'West Anaheim Street', 'Long Beach CA', 'CA','US','90813','News Rack');
            Contact con=CLB_TestDataGenerator.createContact(TRUE,'Test','Contact','contact@test.com','0987654321');
            cse.contactid=con.id;
            insert cse;
            Blob b = Blob.valueOf('Test Data');
            Attachment attachment = new Attachment();
            attachment.ParentId = cse.id;
            attachment.Name = 'Test Attachment for Parent';
            attachment.Body = b;
            insert attachment;
        }      
    }
    /********************************************************************************************
METHOD NAME    : testPostAppOrderCallout
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod  void testPostAppOrderCallout() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='Graffiti' limit 1];
        system.runAs(cityEmployeeUser){
            test.startTest();
            // Set mock callout class 
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            Boolean isSuccess;
            String JSONContent;
            JSONParser parser;
            Object obj=CLB_AppOrderCall.appOrderHttpPost(cse.id);
            system.debug(obj);
            Object obj1=CLB_AppOrderCall.appOrderHttpPost(cse.id);
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
            
            Test.stopTest();
        } 
    }
    /********************************************************************************************
METHOD NAME    : testPostAppOrderNotGraffiti
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod void testPostAppOrderNotGraffiti() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='News Rack'];
        system.runAs(cityEmployeeUser){
            test.startTest();
            // Set mock callout class 
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            Boolean isSuccess;
            String JSONContent;
            JSONParser parser;
            Object obj=CLB_AppOrderCall.appOrderHttpPost(cse.id);
            system.debug(obj);
            Object obj1=CLB_AppOrderCall.appOrderHttpPost(cse.id);
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
            Test.stopTest();
        }
    }
    /********************************************************************************************
METHOD NAME    : testPostAppOrderNotEligible
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod void testPostAppOrderNotEligible() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='Graffiti' limit 1];
        Id devRecordTypeId =Schema.SObjectType.Case.getRecordTypeInfosByName().get('Generic').getRecordTypeId();
        cse.RecordTypeId=devRecordTypeId; 
        update cse;
        system.runAs(cityEmployeeUser){
            test.startTest();
            // Set mock callout class 
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            Boolean isSuccess;
            String JSONContent;
            JSONParser parser;
            Object obj=CLB_AppOrderCall.appOrderHttpPost(cse.id);
            system.debug(obj);
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
            Test.stopTest();
        }
    }
    
    /********************************************************************************************
METHOD NAME    : testPostAppOrderDuplicate
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod void testPostAppOrderDuplicate() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='Graffiti' limit 1];
        cse.status='Closed';
        cse.Closure_Reason__c='Closed';
        update cse;
        test.startTest();
        // Set mock callout class 
        system.runAs(cityEmployeeUser){
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.appOrderHttpPost(cse.id);
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
            String gpcRecordTypeId = [Select Id from RecordType WHERE DeveloperName = 'GPC' AND sObjectType='External_Work_Order__c' LIMIT 1].Id;
            External_Work_Order__c wo=new External_Work_Order__c(Name='CW-12345',Ext_Work_Order_Status__c='Open');
            if(gpcRecordTypeId != null && !String.isBlank(gpcRecordTypeId)){
                wo.RecordTypeId = gpcRecordTypeId;
            }
            insert wo;
            Case_Work_Order_Junction__c junc= new Case_Work_Order_Junction__c(External_Work_Order__c=wo.id,case__c=cse.id);
            insert junc;
            List<Case_Work_Order_Junction__c> workOrderJunctionLst = [Select Case__c,Case__r.Status from Case_Work_Order_Junction__c];
            system.debug(workOrderJunctionLst);
            List<String> workOrderId=new List<String>();
            workOrderId.add(wo.id);
            CLB_AppOrderCall.appOrderHttpPost(cse.id);
            CLB_AppOrderCall.closeCaseStatus(workOrderId);
            Case cseResult=[Select id,Status from Case where id=:cse.id];
            System.assertEquals('In Progress', cseResult.Status);
            Test.stopTest();
        }
    }
    /********************************************************************************************
METHOD NAME    : testPostAppOrder
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod void testPostAppOrder() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='Graffiti' limit 1];
        test.startTest();
        // Set mock callout class 
        //Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
        System.runAs(cityEmployeeUser){
            CLB_AppOrderCall.appOrderHttpPost(cse.id);
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
        }
        Test.stopTest();
        
    }
    /********************************************************************************************
METHOD NAME    : testPostAppOrderException
DESCRIPTION    : Post app order throught test mock callout
RETURN TYPE    : void
*********************************************************************************************/ 
    static testmethod void testPostAppOrderException() {
        User cityEmployeeUser=[Select id from user where email='cityEmployeeUser@test.com'];
        system.debug(cityEmployeeUser);
        Case cse=[Select  Id,recordtype.DeveloperName,Status,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where type='Graffiti' limit 1];
        // Set mock callout class 
        system.runAs(cityEmployeeUser){
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.appOrderHttpPost(''); 
            String caseJson=JSON.serialize(cse);
            Test.setMock(HttpCalloutMock.class, new CLB_HttpCalloutMock()); 
            CLB_AppOrderCall.httpCalloutToAppOrder(caseJson);
        }
    }
}