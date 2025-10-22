({
	fetchData: function (component) {
  		debugger;
        var spinner = component.find("loader");
        $A.util.toggleClass(spinner, "slds-hide");
        // var spinner = component.find("loader");
        var action = component.get("c.getOppList");
        var sunshineCenter = component.get("v.selectedSunshineValue");
        // alert(OppId);
        action.setParams({
            SunshineCenter: sunshineCenter
        });
        action.setCallback(this, function(response) {
            var state = response.getState();

            if (state === "SUCCESS") {
                debugger;
                var data = response.getReturnValue();
			   component.set("v.data", data);
               
              $A.util.toggleClass(spinner, "slds-hide");
                return;

            }
            this.showErrors(component, response.getError());

        });
        $A.enqueueAction(action);
    },

    isNetPromoterButtonEnabled: function (component) {
        debugger;
      var spinner = component.find("loader");
    //  $A.util.toggleClass(spinner, "slds-hide");
      // var spinner = component.find("loader");
      var action = component.get("c.isNetPromoterButtonEnabled");
      var sunshineCenter = component.get("v.selectedSunshineValue");
      // alert(OppId);
      action.setParams({
        centerName: sunshineCenter
      });
      action.setCallback(this, function(response) {
          var state = response.getState();

          if (state === "SUCCESS") {
              debugger;
              var nps = response.getReturnValue();
             component.set("v.showNPSButton", nps);
             
          //  $A.util.toggleClass(spinner, "slds-hide");
              return;

          }
          this.showErrors(component, response.getError());

      });
      $A.enqueueAction(action);
  },
    
    
     loadSunshineCenter: function (component) {
        var opts = [
            { value: "Monarch Shores", label: "Monarch Shores" },
            { value: "Chapters Capistrano", label: "Chapters Capistrano" },
            { value: "Shore Light", label: "Shore Light" },
            { value: "Willowsprings Recovery", label: "Willowsprings Recovery" },
            { value: "Mountain Springs Recovery", label: "Mountain Springs Recovery" },
            { value: "Mountain Springs MH", label: "Mountain Springs MH" },
            { value: "Lincoln Recovery", label: "Lincoln Recovery" },
            { value: "Lincoln MH", label: "Lincoln MH" },
            { value: "Wood Violet Recovery", label: "Wood Violet Recovery" },
            { value: "Wood Violet MH", label: "Wood Violet MH" }

            
        ];
        component.set("v.SunshineCenteroptions", opts);
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
    }
)