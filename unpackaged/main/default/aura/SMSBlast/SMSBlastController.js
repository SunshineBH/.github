({
    init: function(component, event, helper) {
       var spinner = component.find("loader");
        $A.util.toggleClass(spinner, "slds-hide");
        var stepTwo = component.find("stepTwo");
        $A.util.toggleClass(stepTwo, 'slds-hide');
       component.set("v.progressIndicatorFlag","step1");

        var fetchData = {
            opportunityName: "company.companyName",
            phone: "phone.phoneNumber"
        };



        component.set('v.columns', [

            {
                label: 'Opportunity name',
                fieldName: 'OppName',
                sortable:true,
                type: 'text'
                
            },
            {
                label: 'Phone',
                fieldName: 'OppPhoneNumber',
                type: 'text'
            }

        ]);
		helper.loadSunshineCenter(component);
        helper.fetchData(component);
        helper.isNetPromoterButtonEnabled(component);
        
    },
    loadData: function(component, event, helper) {
        debugger;
        helper.fetchData(component);
         helper.isNetPromoterButtonEnabled(component);
        
    },
    goToStepTwo: function(component, event) {
        debugger;
        // component.set('v.readOnlyView',true);
        var stepOne = component.find("stepOne");
        $A.util.toggleClass(stepOne, 'slds-hide');
        var stepTwo = component.find("stepTwo");
        $A.util.toggleClass(stepTwo, 'slds-hide');
        component.set("v.progressIndicatorFlag","step2");


    },
    goBackToStepOne: function(component, event) {
        //  component.set("v.readOnlyView",false);
        var stepOne = component.find("stepOne");
        $A.util.toggleClass(stepOne, 'slds-hide');
        var stepTwo = component.find("stepTwo");
        $A.util.toggleClass(stepTwo, 'slds-hide');
        component.set("v.progressIndicatorFlag","step1");


    },
    goBackAfterSuccess: function(component) {
        //  component.set("v.readOnlyView",false);
        var stepOne = component.find("stepOne");
        $A.util.toggleClass(stepOne, 'slds-hide');
        var stepTwo = component.find("stepTwo");
        $A.util.toggleClass(stepTwo, 'slds-hide');
        component.set("v.progressIndicatorFlag","step1");


    },
    addSelectedRow: function(component, event) {
        var selectedRows = event.getParam('selectedRows');
        // alert(selectedRows.length);
        //var selectedRecipients = component.get('v.SelectedRecipients');
        // selectedRecipients.push(selectedRows);
        component.set('v.SelectedRecipients', selectedRows);
        component.set('v.selectedRowsCount', selectedRows.length);
        //component.set('v.SelectedRecipients',selectedRows);
        debugger;
    },
    sendNetPromoterSMS: function(component){
        debugger;
        var spinner = component.find("loader");
        $A.util.toggleClass(spinner, "slds-hide");
        var action = component.get("c.SendNetPromoterSurveySMS");
        var recipientList = component.get('v.SelectedRecipients');
        var empID = component.get("v.empID");
        if (recipientList.length == 0 ) {
            debugger;
         
            component.find('notifLib').showToast({
                "title": "Error",
                "variant": "error",
                "message": 'Please select a client'
            });
            $A.util.toggleClass(spinner, "slds-hide");
            return;
        }
        action.setParams({
            recipientList: JSON.stringify(recipientList),
            empId: empID
        });
        action.setCallback(this, function(response) {
            var state = response.getState();

            if (state === "SUCCESS") {
                debugger;
                var data = response.getReturnValue();
                component.find('notifLib').showToast({
                    "title": "Success!",
                    "variant": "success",
                    "message": 'Sucessfull'
                });
                //Reset the component
                component.set('v.textMsg','');
                component.set('v.SelectedRecipients', null );
                component.set('v.SelectedRecipientsDT', null );
                  component.set('v.showNPSButton', false );
                
            //    helper.isNetPromoterButtonEnabled(component);
        
                var stepOne = component.find("stepOne");
                $A.util.toggleClass(stepOne, 'slds-hide');
                var stepOne = component.find("stepOne");
                $A.util.toggleClass(stepOne, 'slds-hide');
                var spinner = component.find("loader");
               $A.util.toggleClass(spinner, "slds-hide");
            }
else
            this.showErrors(component, response.getError());

        });
        $A.enqueueAction(action);

    },
    sendSMS: function(component) {
        debugger;
        var spinner = component.find("loader");
        $A.util.toggleClass(spinner, "slds-hide");
        var action = component.get("c.SendSMS");
        var text = component.get('v.textMsg');
        var recipientList = component.get('v.SelectedRecipients');
        // alert(OppId);
        action.setParams({
            text: text,
            recipientList: JSON.stringify(recipientList)
        });
        action.setCallback(this, function(response) {
            var state = response.getState();

            if (state === "SUCCESS") {
                debugger;
                var data = response.getReturnValue();
                component.find('notifLib').showToast({
                    "title": "Success!",
                    "variant": "success",
                    "message": 'Sucessfull'
                });
                //Reset the component
                component.set('v.textMsg','');
                component.set('v.SelectedRecipients', null );
                component.set('v.SelectedRecipientsDT', null );
                var stepOne = component.find("stepOne");
                $A.util.toggleClass(stepOne, 'slds-hide');
                var stepTwo = component.find("stepTwo");
                $A.util.toggleClass(stepTwo, 'slds-hide');
                component.set("v.progressIndicatorFlag","step1");
                var spinner = component.find("loader");
                $A.util.toggleClass(spinner, "slds-hide");
            }
else
            this.showErrors(component, response.getError());

        });
        $A.enqueueAction(action);
    },

    handleRemove: function(component, event) {
        debugger;
        var leftRecipients = [];
        var leftRecipientsDt = [];
        var selectedRemoveId = event.getSource().get('v.name');
        var selectedRecipients = component.get('v.SelectedRecipients');

        for (var item in selectedRecipients) {
            if (selectedRecipients[item].OppID != selectedRemoveId) {
                leftRecipients.push(selectedRecipients[item]);
                leftRecipientsDt.push(selectedRecipients[item].OppID);
            }
        }
        component.set('v.SelectedRecipients', leftRecipients);
        component.set('v.selectedRowsCount', leftRecipients.length);
        component.set('v.SelectedRecipientsDT', leftRecipientsDt);

        if (leftRecipients == 0) {
    
            var stepTwo = component.find("stepTwo");
            if(!$A.util.hasClass(stepTwo, 'slds-hide')){
            component.set("v.progressIndicatorFlag","step1");
            $A.util.toggleClass(stepTwo, 'slds-hide');
            var stepOne = component.find("stepOne");
            $A.util.toggleClass(stepOne, 'slds-hide');
                
            }

        }

    },
    showErrors: function(component, errors) {
        if (errors) {
            var spinner = component.find("loader");
            $A.util.toggleClass(spinner, "slds-hide");
            if (errors[0] && errors[0].message) {
                component.find('notifLib').showToast({
                    "title": "Error!",
                    "variant": "error",
                    "message": errors[0].message
                });
            }
        }

    }
})