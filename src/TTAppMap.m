#import "Three20/TTAppMap.h"
#import "Three20/TTViewController.h"
#import <objc/runtime.h>

///////////////////////////////////////////////////////////////////////////////////////////////////

typedef enum {
  TTURLPatternTypeDefault,
  TTURLPatternTypeSingleton,
  TTURLPatternTypeModal,
} TTURLPatternType;

typedef enum {
  TTURLArgumentTypePointer,
  TTURLArgumentTypeBool,
  TTURLArgumentTypeInteger,
  TTURLArgumentTypeLongLong,
  TTURLArgumentTypeFloat,
  TTURLArgumentTypeDouble,
} TTURLArgumentType;

///////////////////////////////////////////////////////////////////////////////////////////////////

@protocol TTURLPatternText <NSObject>

- (BOOL)match:(NSString*)text;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface TTURLLiteral : NSObject <TTURLPatternText> {
  NSString* _name;
}

@property(nonatomic,copy) NSString* name;

@end

@implementation TTURLLiteral

@synthesize name = _name;

- (id)init {
  if (self = [super init]) {
    _name = nil;
  }
  return self;
}

- (void)dealloc {
  TT_RELEASE_MEMBER(_name);
  [super dealloc];
}

- (BOOL)match:(NSString*)text {
  return [text isEqualToString:_name];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface TTURLWildcard : NSObject <TTURLPatternText> {
  NSString* _name;
  NSInteger _argIndex;
  TTURLArgumentType _argType;
}

@property(nonatomic,copy) NSString* name;
@property(nonatomic) NSInteger argIndex;
@property(nonatomic) TTURLArgumentType argType;

@end

@implementation TTURLWildcard

@synthesize name = _name, argIndex = _argIndex, argType = _argType;

- (id)init {
  if (self = [super init]) {
    _name = nil;
    _argIndex = NSNotFound;
    _argType = TTURLArgumentTypePointer;
  }
  return self;
}

- (void)dealloc {
  TT_RELEASE_MEMBER(_name);
  [super dealloc];
}

- (BOOL)match:(NSString*)text {
  return YES;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface TTURLPattern : NSObject {
  TTURLPatternType _patternType;
  NSURL* _parentURL;
  Class _controllerClass;
  SEL _selector;
  NSString* _scheme;
  NSMutableArray* _path;
  NSMutableDictionary* _query;
  NSInteger _specificity;
  NSInteger _argumentCount;
}

@property(nonatomic,readonly) TTURLPatternType patternType;
@property(nonatomic,copy) NSURL* parentURL;
@property(nonatomic) Class controllerClass;
@property(nonatomic) SEL selector;
@property(nonatomic) NSInteger specificity;
@property(nonatomic) NSInteger argumentCount;

- (id)initWithURL:(NSString*)URL type:(TTURLPatternType)patternType;

- (BOOL)matchURL:(NSURL*)URL;

@end

@implementation TTURLPattern

@synthesize patternType = _patternType, parentURL = _parentURL,
            controllerClass = _controllerClass, selector = _selector,
            specificity = _specificity, argumentCount = _argumentCount;

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

- (id<TTURLPatternText>)parseText:(NSString*)text {
  NSInteger len = text.length;
  if (len && [text characterAtIndex:0] == '(' && [text characterAtIndex:len-1] == ')') {
    NSString* name = [text substringWithRange:NSMakeRange(1, len-2)];
    TTURLWildcard* wildcard = [[[TTURLWildcard alloc] init] autorelease];
    wildcard.name = name;
    ++_specificity;
    return wildcard;
  } else {
    TTURLLiteral* literal = [[[TTURLLiteral alloc] init] autorelease];
    literal.name = text;
    return literal;
  }
}

- (void)parsePathComponent:(NSString*)value {
  id<TTURLPatternText> component = [self parseText:value];
  [_path addObject:component];
}

- (void)parseParameter:(NSString*)name value:(NSString*)value {
  if (!_query) {
    _query = [[NSMutableDictionary alloc] init];
  }
  
  id<TTURLPatternText> component = [self parseText:value];
  [_query setObject:component forKey:name];
}

- (TTURLArgumentType)convertArgumentType:(char*)argType {
  if (strcmp(argType, "c") == 0
      || strcmp(argType, "i") == 0
      || strcmp(argType, "s") == 0
      || strcmp(argType, "l") == 0
      || strcmp(argType, "C") == 0
      || strcmp(argType, "I") == 0
      || strcmp(argType, "S") == 0
      || strcmp(argType, "L") == 0) {
    return TTURLArgumentTypeInteger;
  } else if (strcmp(argType, "q") == 0 || strcmp(argType, "Q") == 0) {
    return TTURLArgumentTypeLongLong;
  } else if (strcmp(argType, "f") == 0) {
    return TTURLArgumentTypeFloat;
  } else if (strcmp(argType, "d") == 0) {
    return TTURLArgumentTypeDouble;
  } else if (strcmp(argType, "B") == 0) {
    return TTURLArgumentTypeBool;
  } else {
    return TTURLArgumentTypePointer;
  }
}

- (void)parseURL:(NSString*)URL {
  NSURL* theURL = [NSURL URLWithString:URL];
    
  _scheme = [theURL.scheme copy];
  if (theURL.host) {
    [self parsePathComponent:theURL.host];
    if (theURL.path) {
      for (NSString* name in theURL.path.pathComponents) {
        if (![name isEqualToString:@"/"]) {
          [self parsePathComponent:name];
        }
      }
    }
  }
  
  if (theURL.query) {
    NSDictionary* query = [theURL.query queryDictionaryUsingEncoding:NSUTF8StringEncoding];
    for (NSString* name in [query keyEnumerator]) {
      NSString* value = [query objectForKey:name];
      [self parseParameter:name value:value];
    }
  }
}

- (NSComparisonResult)compareSpecificity:(TTURLPattern*)pattern2 {
  if (_specificity > pattern2.specificity) {
    return NSOrderedAscending;
  } else if (_specificity < pattern2.specificity) {
    return NSOrderedDescending;
  } else {
    return NSOrderedSame;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithURL:(NSString*)URL type:(TTURLPatternType)patternType {
  if (self = [self init]) {
    _patternType = patternType;
    [self parseURL:URL];
  }
  return self;
}

- (id)init {
  if (self = [super init]) {
    _patternType = TTURLPatternTypeDefault;
    _scheme = nil;
    _path = [[NSMutableArray alloc] init];
    _query = nil;
    _selector = nil;
    _controllerClass = nil;
    _argumentCount = 0;
    _specificity = 0;
  }
  return self;
}

- (void)dealloc {
  TT_RELEASE_MEMBER(_parentURL);
  TT_RELEASE_MEMBER(_scheme);
  TT_RELEASE_MEMBER(_path);
  TT_RELEASE_MEMBER(_query);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

- (void)setSelector:(SEL)selector {
  _selector = selector;
  if (_selector) {
    Method method = class_getInstanceMethod(_controllerClass, _selector);
    if (method) {
      _argumentCount = method_getNumberOfArguments(method)-2;

      // Look up the index and type of each argument in the method
      NSString* selectorName = [NSString stringWithCString:sel_getName(_selector)];
      NSArray* argNames = [selectorName componentsSeparatedByString:@":"];

      for (id<TTURLPatternText> pattern in _path) {
        if ([pattern isKindOfClass:[TTURLWildcard class]]) {
          TTURLWildcard* wildcard = (TTURLWildcard*)pattern;
          wildcard.argIndex = [argNames indexOfObject:wildcard.name];
          if (wildcard.argIndex == NSNotFound) {
            TTWARN(@"Argument %@ not found in @selector(%s)", wildcard.name, sel_getName(_selector));
          } else {
            char argType[256];
            method_getArgumentType(method, wildcard.argIndex+2, argType, 256);
            wildcard.argType = [self convertArgumentType:argType];
          }
        }
      }

      for (id<TTURLPatternText> pattern in [_query objectEnumerator]) {
        if ([pattern isKindOfClass:[TTURLWildcard class]]) {
          TTURLWildcard* wildcard = (TTURLWildcard*)pattern;
          wildcard.argIndex = [argNames indexOfObject:wildcard.name];
          if (wildcard.argIndex == NSNotFound) {
            TTWARN(@"Argument %@ not found in @selector(%s)", wildcard.name, sel_getName(_selector));
          } else {
            char argType[256];
            method_getArgumentType(method, wildcard.argIndex+2, argType, 256);
            wildcard.argType = [self convertArgumentType:argType];
          }
        }
      }
    }
  }
}

- (BOOL)matchURL:(NSURL*)URL {
  if ([_scheme isEqualToString:URL.scheme] && URL.host) {
    NSArray* pathComponents = URL.path.pathComponents;
    NSInteger componentCount = URL.path.length ? pathComponents.count : 1;
    if (componentCount != _path.count) {
      return NO;
    }

    id<TTURLPatternText>hostPattern = [_path objectAtIndex:0];
    if (![hostPattern match:URL.host]) {
      return NO;
    }
    
    for (NSInteger i = 1; i < _path.count; ++i) {
      id<TTURLPatternText>pathPattern = [_path objectAtIndex:i];
      NSString* pathText = [pathComponents objectAtIndex:i];
      if (![pathPattern match:pathText]) {
        return NO;
      }
    }
  }
  return YES;
}

- (BOOL)setArgument:(NSString*)text pattern:(id<TTURLPatternText>)patternText
        forInvocation:(NSInvocation*)invocation {
  if ([patternText isKindOfClass:[TTURLWildcard class]]) {
    TTURLWildcard* wildcard = (TTURLWildcard*)patternText;
    NSInteger index = wildcard.argIndex;
    if (index != NSNotFound) {
      switch (wildcard.argType) {
        case TTURLArgumentTypeInteger: {
          int val = [text intValue];
          [invocation setArgument:&val atIndex:index+2];
          break;
        }
        case TTURLArgumentTypeLongLong: {
          long long val = [text longLongValue];
          [invocation setArgument:&val atIndex:index+2];
          break;
        }
        case TTURLArgumentTypeFloat: {
          float val = [text floatValue];
          [invocation setArgument:&val atIndex:index+2];
          break;
        }
        case TTURLArgumentTypeDouble: {
          double val = [text doubleValue];
          [invocation setArgument:&val atIndex:index+2];
          break;
        }
        case TTURLArgumentTypeBool: {
          BOOL val = [text boolValue];
          [invocation setArgument:&val atIndex:index+2];
          break;
        }
        default: {
          [invocation setArgument:&text atIndex:index+2];
          break;
        }
      }
      return YES;
    }
  }
  return NO;
}

- (void)setArgumentsFromURL:(NSURL*)URL forInvocation:(NSInvocation*)invocation {
  NSInteger remainingArguments = _argumentCount;
  
  NSArray* pathComponents = URL.path.pathComponents;
  for (NSInteger i = 0; i < _path.count; ++i) {
    id<TTURLPatternText> patternText = [_path objectAtIndex:i];
    NSString* text = i == 0 ? URL.host : [pathComponents objectAtIndex:i];
    if ([self setArgument:text pattern:patternText forInvocation:invocation]) {
      --remainingArguments;
    }
  }
  
  NSDictionary* query = [URL.query queryDictionaryUsingEncoding:NSUTF8StringEncoding];
  if (query.count) {
    NSMutableDictionary* unmatched = nil;

    for (NSString* name in [query keyEnumerator]) {
      id<TTURLPatternText> patternText = [_query objectForKey:name];
      NSString* text = [query objectForKey:name];
      if (patternText) {
        if ([self setArgument:text pattern:patternText forInvocation:invocation]) {
          --remainingArguments;
        }
      } else {
        if (!unmatched) {
          unmatched = [NSMutableDictionary dictionary];
        }
        [unmatched setObject:text forKey:name];
      }
    }
    
    if (remainingArguments && unmatched.count) {
      // If there are unmatched arguments, and the method signature has extra arguments,
      // then pass the dictionary of unmatched arguments as the last argument
      [invocation setArgument:&unmatched atIndex:_argumentCount+1];
    }
  }
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTAppMap

@synthesize delegate = _delegate, mainWindow = _mainWindow,
            mainViewController = _mainViewController, persistenceMode = _persistenceMode,
            supportsShakeToReload = _supportsShakeToReload;

///////////////////////////////////////////////////////////////////////////////////////////////////
// class public

+ (TTAppMap*)sharedMap {
  static TTAppMap* sharedMap = nil;
  if (!sharedMap) {
    sharedMap = [[TTAppMap alloc] init];
  }
  return sharedMap;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

- (void)addPattern:(TTURLPattern*)pattern {
  _invalidPatterns = YES;
  
  if (!_patterns) {
    _patterns = [[NSMutableArray alloc] init];
  }
  
  [_patterns addObject:pattern];
}

- (TTURLPattern*)matchPattern:(NSURL*)URL {
  if (_invalidPatterns) {
    [_patterns sortUsingSelector:@selector(compareSpecificity:)];
  }
  
  for (TTURLPattern* pattern in _patterns) {
    if ([pattern matchURL:URL]) {
      return pattern;
    }
  }
  return nil;
}

- (UIViewController*)controllerForURL:(NSURL*)URL withPattern:(TTURLPattern*)pattern {
  if (_singletons) {
    // XXXjoe Normalize the URL first
    NSString* URLString = [URL absoluteString];
    UIViewController* controller = [_singletons objectForKey:URLString];
    if (controller) {
      return controller;
    }
  }

  UIViewController* controller = [[[pattern.controllerClass alloc] init] autorelease];
  if (pattern.selector) {
    NSMethodSignature *sig = [controller methodSignatureForSelector:pattern.selector];
    if (sig) {
      NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
      [invocation setTarget:controller];
      [invocation setSelector:pattern.selector];
      [pattern setArgumentsFromURL:URL forInvocation:invocation];
      [invocation invoke];
    }
  }

  if (pattern.patternType == TTURLPatternTypeSingleton) {
    [self setController:controller forURL:[URL absoluteString]];
  }

  return controller;
}

- (UIViewController*)controllerForURL:(NSURL*)URL pattern:(TTURLPattern**)outPattern {
  TTURLPattern* pattern = [self matchPattern:URL];
  if (pattern) {
    if (outPattern) {
      *outPattern = pattern;
    }
    return [self controllerForURL:URL withPattern:pattern];
  } else {
    return nil;
  }
}

- (UIViewController*)parentControllerForPattern:(TTURLPattern*)pattern {
  UIViewController* parentController = nil;
  if (pattern.parentURL) {
    parentController = [self controllerForURL:pattern.parentURL pattern:nil];
  }
  return parentController ? parentController : self.visibleViewController;
}

- (void)presentModalController:(UIViewController*)controller
        parent:(UIViewController*)parentController animated:(BOOL)animated {
  if ([controller isKindOfClass:[UINavigationController class]]) {
    [parentController presentModalViewController:controller animated:animated];
  } else {
    UINavigationController* navController = [[[UINavigationController alloc] init] autorelease];
    [navController pushViewController:controller animated:NO];
    [parentController presentModalViewController:navController animated:animated];
  }
}

- (void)presentController:(UIViewController*)controller
        parent:(UIViewController*)parentController modal:(BOOL)modal animated:(BOOL)animated {
  if (!_mainWindow) {
    _mainWindow = [[UIWindow alloc] initWithFrame:TTScreenBounds()];
    [_mainWindow makeKeyAndVisible];
  }
  if (!_mainViewController) {
    _mainViewController = [controller retain];
    [_mainWindow addSubview:controller.view];
  } else if (controller.parentViewController) {
    // The controller already exists, so we just need to make it visible
    while (controller) {
      UIViewController* parent = controller.parentViewController;
      [parent bringControllerToFront:controller animated:NO];
      controller = parent;
    }
  } else if (parentController) {
    [self presentController:parentController parent:nil modal:NO animated:NO];
    if (modal) {
      [self presentModalController:controller parent:parentController animated:animated];
    } else {
      [parentController presentController:controller animated:animated];
    }
  }
}

- (void)presentController:(UIViewController*)controller forURL:(NSURL*)URL
        withPattern:(TTURLPattern*)pattern animated:(BOOL)animated {
  UIViewController* parentController = [self parentControllerForPattern:pattern];
  [self presentController:controller parent:parentController
        modal:pattern.patternType == TTURLPatternTypeModal animated:animated];
}

- (UINavigationController*)frontNavigationController {
  if ([_mainViewController isKindOfClass:[UITabBarController class]]) {
    UITabBarController* tabBarController = (UITabBarController*)_mainViewController;
    if (tabBarController.selectedViewController) {
      return (UINavigationController*)tabBarController.selectedViewController;
    } else {
      return (UINavigationController*)[tabBarController.viewControllers objectAtIndex:0];
    }
  } else if ([_mainViewController isKindOfClass:[UINavigationController class]]) {
    return (UINavigationController*)_mainViewController;
  } else {
    return nil;
  }
}

- (UIViewController*)frontViewControllerForController:(UIViewController*)controller {
  if ([controller isKindOfClass:[UITabBarController class]]) {
    UITabBarController* tabBarController = (UITabBarController*)controller;
    if (tabBarController.selectedViewController) {
      controller = tabBarController.selectedViewController;
    } else {
      controller = [tabBarController.viewControllers objectAtIndex:0];
    }
  } else if ([controller isKindOfClass:[UINavigationController class]]) {
    UINavigationController* navController = (UINavigationController*)controller;
    controller = [navController.viewControllers lastObject];
  }
  
  if (controller.modalViewController) {
    return [self frontViewControllerForController:controller.modalViewController];
  } else {
    return controller;
  }
}

- (UIViewController*)frontViewController {
  UINavigationController* navController = self.frontNavigationController;
  if (navController) {
    return [self frontViewControllerForController:navController];
  } else {
    return [self frontViewControllerForController:_mainViewController];
  }
}

- (UIViewController*)loadControllerWithURL:(NSString*)URL display:(BOOL)display
                    animated:(BOOL)animated {
  NSURL* theURL = [NSURL URLWithString:URL];
  TTURLPattern* pattern = nil;
  UIViewController* controller = [self controllerForURL:theURL pattern:&pattern];
  if (controller) {
    controller.appMapURL = URL;
    if (display) {
      [self presentController:controller forURL:theURL withPattern:pattern animated:animated];
    }
  }
  return controller;
}

- (void)persistControllers {
  NSMutableArray* path = [NSMutableArray array];
  [self persistController:_mainViewController path:path];
  
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:path forKey:@"TTAppMapNavigation"];
  [defaults synchronize];
}

- (BOOL)restoreControllersStartingWithURL:(NSString*)startURL {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSArray* path = [defaults objectForKey:@"TTAppMapNavigation"];
  NSInteger pathIndex = 0;
  for (NSDictionary* state in path) {
    NSString* URL = [state objectForKey:@"__appMapURL__"];
    
    if (!_mainViewController && ![URL isEqualToString:startURL]) {
      // If the start URL is not the same as the persisted start URL, then don't restore
      // because the app wants to start with a different URL.
      return NO;
    }
    
    UIViewController* controller = [self loadControllerWithURL:URL display:YES animated:NO];
    controller.frozenState = state;
    
    if (_persistenceMode == TTAppMapPersistenceModeTop && pathIndex++ == 1) {
      break;
    }
  }
  return path.count > 0;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)init {
  if (self = [super init]) {
    _delegate = nil;
    _mainWindow = nil;
    _mainViewController = nil;
    _singletons = nil;
    _patterns = nil;
    _persistenceMode = TTAppMapPersistenceModeNone;
    _supportsShakeToReload = NO;
    _invalidPatterns = NO;
    
    // Swizzle a new dealloc for UIViewController so it notifies us when it's going away.
    // We may need to remove it from our singleton cache, which keeps week references.
    TTSwizzle([UIViewController class], @selector(dealloc), @selector(ttdealloc));
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(applicationWillTerminateNotification:)
                                          name:UIApplicationWillTerminateNotification
                                          object:nil];
  }
  return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                          name:UIApplicationWillTerminateNotification
                                          object:nil];
  _delegate = nil;
  TT_RELEASE_MEMBER(_mainWindow);
  TT_RELEASE_MEMBER(_mainViewController);
  TT_RELEASE_MEMBER(_singletons);
  TT_RELEASE_MEMBER(_patterns);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSNotifications

- (void)applicationWillTerminateNotification:(void*)info {
  if (_persistenceMode) {
    [self persistControllers];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

- (UIViewController*)visibleViewController {
  UINavigationController* navController = self.frontNavigationController;
  if (navController) {
    return navController.visibleViewController;
  } else {
    return [self frontViewControllerForController:_mainViewController];
  }
}

- (UIViewController*)loadURL:(NSString*)URL {
  if (!_mainViewController && _persistenceMode && [self restoreControllersStartingWithURL:URL]) {
    return _mainViewController;
  } else {
    return [self loadControllerWithURL:URL display:YES animated:YES];
  }
}

- (UIViewController*)controllerForURL:(NSString*)URL {
  return [self loadControllerWithURL:URL display:NO animated:NO];
}

- (void)addURL:(NSString*)URL controller:(Class)controller {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeDefault];
  pattern.controllerClass = controller;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL controller:(Class)controller selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeDefault];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL parent:(NSString*)parentURL controller:(Class)controller
        selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeDefault];
  pattern.parentURL = [NSURL URLWithString:parentURL];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL singleton:(Class)controller {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeSingleton];
  pattern.controllerClass = controller;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL singleton:(Class)controller selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeSingleton];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL parent:(NSString*)parentURL singleton:(Class)controller
        selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeSingleton];
  pattern.parentURL = [NSURL URLWithString:parentURL];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL modal:(Class)controller {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeModal];
  pattern.controllerClass = controller;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL modal:(Class)controller selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeModal];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)addURL:(NSString*)URL parent:(NSString*)parentURL modal:(Class)controller
        selector:(SEL)selector {
  TTURLPattern* pattern = [[TTURLPattern alloc] initWithURL:URL type:TTURLPatternTypeModal];
  pattern.parentURL = [NSURL URLWithString:parentURL];
  pattern.controllerClass = controller;
  pattern.selector = selector;
  [self addPattern:pattern];
  [pattern release];
}

- (void)setController:(UIViewController*)controller forURL:(NSString*)URL {
  if (!_singletons) {
    _singletons = TTCreateNonRetainingDictionary();
  }
  // XXXjoe Normalize the URL first
  [_singletons setObject:controller forKey:URL];
}

- (void)removeControllerForURL:(NSString*)URL {
  [_singletons removeObjectForKey:URL];
}

- (void)removePersistedControllers {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:@"TTAppMapNavigation"];
  [defaults synchronize];
}

- (void)persistController:(UIViewController*)controller path:(NSMutableArray*)path {
  NSString* URL = controller.appMapURL;
  if (URL) {
    // Let the controller persists its own arbitrary state
    NSMutableDictionary* state = [NSMutableDictionary dictionaryWithObject:URL  
                                                      forKey:@"__appMapURL__"];
    [controller persistView:state];

    [path addObject:state];
    
    // Prevent controller from being persisted again - necessary because the same
    // modalViewController is often assigned to multiple controllers
    controller.appMapURL = nil;
  }
  [controller persistNavigationPath:path];

  if (controller.modalViewController) {
    [self persistController:controller.modalViewController path:path];
  }
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////
// global

void TTLoadURL(NSString* URL) {
  [[TTAppMap sharedMap] loadURL:URL];
}