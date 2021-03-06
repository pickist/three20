//
// Copyright 2009-2010 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// See: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/905-A-Unit-Test_Result_Macro_Reference/unit-test_results.html#//apple_ref/doc/uid/TP40007959-CH21-SW2
// for unit test macros.

// See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

#import <SenTestingKit/SenTestingKit.h>

#import "Three20/Three20.h"

/**
 * Unit tests for the Core XML parser. These tests are a part of the comprehensive test suite
 * for the Core functionality of the library.
 */
@interface CoreXMLTests : SenTestCase
@end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation CoreXMLTests


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testXMLParser {
  NSBundle* testBundle = [NSBundle bundleWithIdentifier:@"com.facebook.three20.UnitTests"];
  STAssertTrue(nil != testBundle, @"Unable to find the bundle %@", [NSBundle allBundles]);

  NSString* xmlDataPath = [[testBundle bundlePath]
    stringByAppendingPathComponent:@"testcase.xml"];
  NSData* xmlData = [[NSData alloc] initWithContentsOfFile:xmlDataPath];

  STAssertTrue(nil != xmlData, @"Unable to find the xml test file in %@", xmlDataPath);

  TTXMLParser* parser = [[TTXMLParser alloc] initWithData:xmlData];
  [parser parse];
  STAssertTrue([parser.rootObject isKindOfClass:[NSDictionary class]],
               @"Root object should be an NSDictionary");

  NSDictionary* rootObject = parser.rootObject;
  STAssertTrue([[rootObject nameForXMLNode] isEqualToString:@"issues"],
               @"Root object name should be 'issues'");
  STAssertTrue([[rootObject typeForXMLNode] isEqualToString:@"array"],
               @"Root object type should be 'array'");
  STAssertTrue([[rootObject objectForXMLNode] isKindOfClass:[NSArray class]],
               @"Root object type should be 'array'");

  NSArray* issues = [rootObject objectForXMLNode];
  STAssertEquals((NSUInteger)50, [issues count], @"There should be 50 issues in the array");

  TT_RELEASE_SAFELY(parser);
}


@end
