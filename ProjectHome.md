UISpec is a Behavior Driven Development framework for the iPhone that provides a full automated testing solution that drives the actual iPhone UI.  It is modeled after the very popular [RSpec](http://rspec.info/) for Ruby.

To make finding specific views in the iPhone UI easy, UISpec includes a very powerful view traversal DSL called UIQuery.  Not only can you easily traverse the view heirarchy, you can also interact with the views you find.

If you have any questions or issues please post them in the [UISpec Group](http://groups.google.com/group/uispec).

### [Installation](http://code.google.com/p/uispec/wiki/Installation) ###

### [Documentation](http://code.google.com/p/uispec/wiki/Documentation) ###


---


### Recent News! ###
Simple scripting language support added to UISpec called [UIScript](http://code.google.com/p/uispec/wiki/Documentation#UIScript).  It allows you to send a string as a script and have it run dynamically.  Here is an example of using UIScript to automate a login screen on the iphone:

```
$(@"textField with placeholder:'Username' setText:'bkuser'");
$(@"textField with placeholder:'Password' setText:'bkpassword'");
$(@"navigationButton label with text:'Login' touch");
```

This really open up the possibility of using UISpec from other languages like Ruby or Java, or even the ability to have an interactive console that drives the iphone ui.  Check it out [here](http://code.google.com/p/uispec/wiki/Documentation#UIScript).


---


### Demo ###
<a href='http://www.youtube.com/watch?feature=player_embedded&v=-kWYatRKnYo' target='_blank'><img src='http://img.youtube.com/vi/-kWYatRKnYo/0.jpg' width='425' height=344 /></a>
Thanks Patrick Hüsler for the video!

Included in the distribution is the UISpecDemo XCode project that shows UISpec running against the Employee Admin application from the [Objective-C port of PureMVC](http://puremvc.org/content/view/121/1/).  The Spec is defined in DescribeEmployeeAdmin.m and contains 5 examples.

To run the demo:

  * Checkout/export UISpec from the repository using subversion, explained [here](http://code.google.com/p/uispec/source/checkout).
  * From within the folder you did a checkout/export, go to the directory xcode/UISpecDemo and open the file UISpecDemo.xcodeproj
  * Once XCode has loaded the project, set the Active SDK to Simulator 3.0
  * Then click "Build and Go".
  * If you get a build error the first time, just do a Build -> Clean All Targets, and then click "Build and Go" again, this should fix the build errors from now on.

And if you have any issues please post them in the [UISpec Group](http://groups.google.com/group/uispec).


---


### Example Spec ###
The following is just a taste of what's possible with UISpec:

```
#import "DescribeEmployeeAdmin.h"
#import "SpecHelper.h"

@implementation DescribeEmployeeAdmin

-(void)before {
	//login as default admin before each example
	[SpecHelper loginAsAdmin];
}

-(void)after {
	//logout after each example
	[SpecHelper logout];
}

-(void)itShouldHaveDefaultUsers {
	//Check that all default users are in list
	[[app.tableView.label text:@"Larry Stooge"] should].exist;
	[[app.tableView.label text:@"Curly Stooge"] should].exist;
	[[app.tableView.label text:@"Moe Stooge"] should].exist;
}

-(void)itShouldAddAUser {
	//Click the + button
	[app.navigationButton touch];
	
	//Set the form fields.
        //Also ".with" is optional so we here we can show the different syntax
	[[app.textField.with placeholder:@"First Name"] setText:@"Brian"];
	[[app.textField.with placeholder:@"Last Name"] setText:@"Knorr"];
	[[app.textField.with placeholder:@"Email"] setText:@"b@g.com"];
	[[app.textField placeholder:@"Username"] setText:@"bkuser"];
	[[app.textField placeholder:@"Password"] setText:@"test"];
	[[app.textField placeholder:@"Confirm"] setText:@"test"];
	
	//Click the Save button
	[[app.navigationButton.label text:@"Save"] touch];
	
	//Make sure the error alert view doesn't appear
	[app timeout:1].alertView.should.not.exist;
	
	//User list should now have a new entry
	[[app.tableView.label text:@"Brian Knorr"] should].exist;
}

@end
```