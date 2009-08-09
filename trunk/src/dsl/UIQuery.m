
#import "UIQuery.h"
#import "objc/runtime.h"
#import "UIDescendants.h"
#import "UIChildren.h"
#import "UIParents.h"
#import "WaitUntilIdle.h"
#import "UIRedoer.h"
#import "UIQueryTableViewCell.h"
#import "UIQueryTableView.h"
#import "UIQueryAll.h"
#import "UIFilter.h"

@implementation UIQuery

@synthesize views, className, redoer, timeout;

+(id)withApplicaton {
	return [self withViews:[NSMutableArray arrayWithObject:[UIApplication sharedApplication]] className:NSStringFromClass([UIApplication class])];
}

-(UIQuery *)find {
	return [self descendant];
}

-(UIQuery *)descendant {
	[self wait:.25];
	return [UIQuery withViews:[[UIDescendants withTraversal] collect:views] className:className filter:YES];
}

-(UIQuery *)child {
	[self wait:.25];
	return [UIQuery withViews:[[UIChildren withTraversal] collect:views] className:className filter:YES];
}

-(UIQuery *)parent {
	[self wait:.25];
	return [UIQuery withViews:[[UIParents withTraversal] collect:views] className:className filter:YES];
}

-(UIExpectation *)should {
	return [UIExpectation withQuery:self];
}

-(UIFilter *)with {
	return [UIFilter withQuery:self];
}

+(id)withViews:(NSMutableArray *)views className:(NSString *)className {
	return [UIRedoer withTarget:[[[self alloc] initWithViews:views className:className filter:NO] autorelease]];
}

+(id)withViews:(NSMutableArray *)views className:(NSString *)className filter:(BOOL)filter {
	return [UIRedoer withTarget:[[[self alloc] initWithViews:views className:className filter:filter] autorelease]];
}

-(id)initWithViews:(NSMutableArray *)_views className:(NSString *)_className filter:(BOOL)_filter {
	if (self = [super init]) {
		self.timeout = 10;
		self.views = _views;
		self.className = _className;
		filter = _filter;
	}
	return self;
}

-(NSArray *)collect:(NSArray *)views {
	return [[[[UIDescendants alloc] init] autorelease] collect:views];
}

-(UIQuery *)target {
	return self;
}

-(NSArray *)targetViews {
	return (views.count == 0) ? [NSArray array] : [NSArray arrayWithObject:[views objectAtIndex:0]];
}

-(UIQuery *)timeout:(int)seconds {
	UIQuery *copy = [UIQuery withViews:views className:className];
	copy.timeout = seconds;
	return copy;
}

-(id)templateFilter {
	NSString *viewName = NSStringFromSelector(_cmd);
	return [self view:[NSString stringWithFormat:@"UI%@", [viewName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[viewName substringWithRange:NSMakeRange(0,1)] uppercaseString]]]];
}

-(UIQuery *)index:(int)index {
	if (index >= views.count) {
		NSLog(@"UISPEC WARNING: %@ doesn't exist at index %i", className, index);
	}
	NSArray *resultViews = (index >= views.count) ? [NSArray array] : [NSArray arrayWithObject:[views objectAtIndex:index]];
	return [UIQuery withViews:resultViews className:className];
}

-(UIQuery *)first {
	return [self index:0];
}

-(UIQuery *)last {
	return [self index:views.count - 1];
}

-(UIQuery *)all {
	return [UIQueryAll withViews:views className:className];
}

-(UIQuery *)view:(NSString *)className {
	NSArray *views = filter ? self.views : self.descendant.views;
	NSMutableArray *array = [NSMutableArray array];
	NSDate *start = [NSDate date];
	while ([start timeIntervalSinceNow] > (0 - timeout)) {
		Class class = NSClassFromString(className);
		for (UIView * v in views) {
			if ([v isKindOfClass:class]) {
				[array addObject:v];
			} 
		}
		if (array.count > 0) {
			break;
		}
		self.redo;
	}
	if ([className isEqualToString:@"UITableViewCell"]) {
		return [UIQueryTableViewCell withViews:array className:className];
	} else if ([className isEqualToString:@"UITableView"]) {
		return [UIQueryTableView withViews:array className:className];
	} else {
		return [UIQuery withViews:array className:className];
	}
}

-(UIQuery *)wait:(double)seconds {
	CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false);
	return [UIQuery withViews:views className:className];
}

-(id)redo {
	//NSLog(@"UIQuery redo");
	if (redoer != nil) {
		//NSLog(@"UIQuery redo redoer = %@", redoer);
		UIRedoer *redone = [redoer redo];
		redoer.target = redone.target;
		self.views = [[redoer play] views];
	}
	//return is provided by uiredoer
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	if ([UIQuery instancesRespondToSelector:aSelector]) {
		return [super methodSignatureForSelector:aSelector];
	}
	
	[self.should exist:[NSString stringWithFormat:@"before you can call %@", NSStringFromSelector(aSelector)]];
	NSString *selector = NSStringFromSelector(aSelector);
	
	for (UIView *target in [self targetViews]) {
		if ([target respondsToSelector:aSelector]) {
			return [target methodSignatureForSelector:aSelector];
		}
	}
	
	//Check if any view responds as a property match
	NSArray *selectors = [selector componentsSeparatedByString:@":"];
	if (selectors.count == 2) {
		return [self.with methodSignatureForSelector:aSelector];
	}
	return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	BOOL isDirect = NO;
	for (UIView *target in [self targetViews]) {
		if ([target respondsToSelector:[anInvocation selector]]) {
			[anInvocation invokeWithTarget:target];
			isDirect = YES;
		}
	}
	
	if (!isDirect) {
		[[[UIRedoer withTarget:self] with] forwardInvocation:anInvocation];
	}
}

- (BOOL)respondsToSelector:(SEL)aSelector {
	if ([UIQuery instancesRespondToSelector:aSelector]) {
		return YES;
	}
	for (UIView *target in [self targetViews]) {
		if ([target respondsToSelector:aSelector]) {
			return YES;
		}
	}
	return [super respondsToSelector:aSelector];
}

-(UIQuery *)flash {
	[self.should exist:@"before you can flash it"];
	for (UIView *view in [self targetViews]) {
		UIColor *tempColor = view.backgroundColor;
		for (int i=0; i<5; i++) {
			view.backgroundColor = [UIColor yellowColor];
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
			view.backgroundColor = [UIColor blueColor];
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
		}
		view.backgroundColor = tempColor;
	}
	return self;
}

-(UIQuery *)show {
	[self.should exist:@"before you can show it"];
	for (UIView *view in [self targetViews]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		NSLog(@"Class = %@", [view class]);
		int i, propertyCount = 0;
		objc_property_t *propertyList = class_copyPropertyList([view class], &propertyCount);
		for (i=0; i<propertyCount; i++) {
			objc_property_t *thisProperty = propertyList + i;
			const char* propertyName = property_getName(*thisProperty);
			const char* propertyAttributes = property_getAttributes(*thisProperty);
			NSString *key = [NSString stringWithFormat:@"%s", propertyName];
			NSString *keyAttributes = [NSString stringWithFormat:@"%s", propertyAttributes];
			
			if ([view respondsToSelector:NSSelectorFromString(key)]) {
				id value = nil;
				if ([keyAttributes rangeOfString:@"T@"].length != 0) {
					value = [view performSelector:NSSelectorFromString(key)];
				} else {
					value = @"Need to get value for this key";
				}
				if (value == nil) {
					value = @"nil";
				}
				[dict setObject:value forKey:key];
			}
		}
		if ([dict allKeys].count > 0) {
			NSLog([dict description]);
		}
	}
	return self;
}

- (UIQuery *)touch {
	[self.should exist:@"before you can touch it"];
	
	for (UIView *view in [self targetViews]) {
		UITouch *touch = [[UITouch alloc] initInView:view];
		UIEvent *eventDown = [[NSClassFromString(@"UITouchesEvent") alloc] initWithTouch:touch];
		NSSet *touches = [[NSMutableSet alloc] initWithObjects:&touch count:1];
		
		[touch.view touchesBegan:touches withEvent:eventDown];
		
		UIEvent *eventUp = [[NSClassFromString(@"UITouchesEvent") alloc] initWithTouch:touch];
		[touch setPhase:UITouchPhaseEnded];
		
		[touch.view touchesEnded:touches withEvent:eventDown];
		
		[eventDown release];
		[eventUp release];
		[touches release];
		[touch release];
		[self wait:.25];
	}
	return [UIQuery withViews:views className:className];
}

-(NSString *)description {
	return [views description];
}

-(void)logRange:(NSString *)prefix range:(NSRange)range {
	NSLog(@"%@ location = %d, length = %d", prefix, range.location, range.length);
}

-(void)dealloc {
	self.views = nil;
	self.className = nil;
	self.redoer = nil;
	[super dealloc];
}

@end


@implementation UITouch (UIQuery)
//
// initInView:phase:
//
// Creats a UITouch, centered on the specified view, in the view's window.
// Sets the phase as specified.
//
- (id)initInView:(UIView *)view
{
	self = [super init];
	if (self != nil)
	{
		CGRect frameInWindow;
		if ([view isKindOfClass:[UIWindow class]])
		{
			frameInWindow = view.frame;
		}
		else
		{
			frameInWindow =
			[view.window convertRect:view.frame fromView:view.superview];
		}
		
		_tapCount = 1;
		_locationInWindow =
		CGPointMake(
					frameInWindow.origin.x + 0.5 * frameInWindow.size.width,
					frameInWindow.origin.y + 0.5 * frameInWindow.size.height);
		_previousLocationInWindow = _locationInWindow;
		
		UIView *target = [view.window hitTest:_locationInWindow withEvent:nil];
		
		_window = [view.window retain];
		_view = [target retain];
		_phase = UITouchPhaseBegan;
		_touchFlags._firstTouchForView = 1;
		_touchFlags._isTap = 1;
		_timestamp = [NSDate timeIntervalSinceReferenceDate];
	}
	return self;
}

//
// setPhase:
//
// Setter to allow access to the _phase member.
//
- (void)setPhase:(UITouchPhase)phase
{
	_phase = phase;
	_timestamp = [NSDate timeIntervalSinceReferenceDate];
}

//
// setPhase:
//
// Setter to allow access to the _locationInWindow member.
//
- (void)setLocationInWindow:(CGPoint)location
{
	_previousLocationInWindow = _locationInWindow;
	_locationInWindow = location;
	_timestamp = [NSDate timeIntervalSinceReferenceDate];
}

@end

UIQuery * $(NSString *script, ...) {
	va_list args;
	va_start(args, script);
	script = [[[NSString alloc] initWithFormat:script arguments:args] autorelease];
	va_end(args);
	
	//float test;
	//	[[NSScanner scannerWithString:@"45.73"] scanFloat:(float *)&test];
	//	NSLog(@"((((((( test = %f", test);
	
	//NSLog(@"script = %@, length = %d", script, script.length);
	UIQuery *result = [UIQuery withApplicaton];
	NSRange nextSearchRange = NSMakeRange(0, script.length);
	NSRange nextSpaceRange = [script rangeOfString:@" " options:NSLiteralSearch range:nextSearchRange];	
	
	NSRange checkForSet = [script rangeOfString:@":" options:NSLiteralSearch range:nextSearchRange];
	if (checkForSet.length != 0 && checkForSet.location < nextSpaceRange.location) {
		NSRange openQuote = [script rangeOfString:@"'" options:NSLiteralSearch range:nextSearchRange];
		nextSearchRange = NSMakeRange(openQuote.location + openQuote.length, script.length - openQuote.location - openQuote.length);
		NSRange closeQuote = [script rangeOfString:@"'" options:NSLiteralSearch range:nextSearchRange];
		nextSearchRange = NSMakeRange(closeQuote.location + closeQuote.length, script.length - closeQuote.location - closeQuote.length);
		nextSpaceRange = [script rangeOfString:@" " options:NSLiteralSearch range:nextSearchRange];
	}
	
	if (nextSpaceRange.length == 0) {
		nextSpaceRange =  NSMakeRange(script.length, 0);
	}
	NSRange nextCommandRange = NSMakeRange(nextSearchRange.location, nextSpaceRange.location);
	while (YES) {
		NSString *command = [script substringWithRange:nextCommandRange];
		
		//NSLog(@"command = %@", command);
		if (![command isEqualToString:@""]) {
			NSRange whereIsSet = [command rangeOfString:@":"];
			if (whereIsSet.length != 0) {
				NSArray *selectors = [command componentsSeparatedByString:@":"];
				NSString *selector = [NSString stringWithFormat:@"%@:", [selectors objectAtIndex:0]];
				NSString *arg = [selectors objectAtIndex:1];
				BOOL isString = [arg rangeOfString:@"'"].length != 0;
				arg = [arg stringByReplacingOccurrencesOfString:@"'" withString:@""];
				id argValue = nil;
				if (isString) {
					argValue = arg;
				} else if ([arg isEqualToString:@"YES"] || [arg isEqualToString:@"NO"]) {
					argValue = [arg isEqualToString:@"YES"];
				} else {
					argValue = [arg intValue];
				}
				result = [result performSelector:NSSelectorFromString(selector) withObject:argValue];
			} else {
				result = [result performSelector:NSSelectorFromString(command)];
			}
		}
		//NSLog(@"result = %@", [result target]);
		if (nextSpaceRange.location == script.length) {
			break;
		}
		nextSearchRange = NSMakeRange(nextSpaceRange.location + nextSpaceRange.length, script.length - nextSpaceRange.location - nextSpaceRange.length);
		nextSpaceRange = [script rangeOfString:@" " options:NSLiteralSearch range:nextSearchRange];
		
		NSRange checkForSet = [script rangeOfString:@":" options:NSLiteralSearch range:nextSearchRange];
		if (checkForSet.length != 0 && checkForSet.location < nextSpaceRange.location) {
			NSRange openQuote = [script rangeOfString:@"'" options:NSLiteralSearch range:nextSearchRange];
			//[self logRange:@"openQuote" range:openQuote];
			nextSearchRange = NSMakeRange(openQuote.location + openQuote.length, script.length - openQuote.location - openQuote.length);
			//[self logRange:@"nextSearchRange" range:nextSearchRange];
			NSRange closeQuote = [script rangeOfString:@"'" options:NSLiteralSearch range:nextSearchRange];
			//[self logRange:@"closeQuote" range:closeQuote];
			nextSearchRange = NSMakeRange(closeQuote.location + closeQuote.length, script.length - closeQuote.location - closeQuote.length);
			//[self logRange:@"nextSearchRange" range:nextSearchRange];
			nextSpaceRange = [script rangeOfString:@" " options:NSLiteralSearch range:nextSearchRange];
			//[self logRange:@"nextSpaceRange" range:nextSpaceRange];
		}
		
		if (nextSpaceRange.length == 0) {
			nextSpaceRange =  NSMakeRange(script.length, 0);
		}
		nextCommandRange = NSMakeRange(nextCommandRange.location + nextCommandRange.length + 1, nextSpaceRange.location - nextCommandRange.location - nextCommandRange.length - 1);
		//[self logRange:@"nextCommandRange" range:nextCommandRange];
	}
	return result;
}

