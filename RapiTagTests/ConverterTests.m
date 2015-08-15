//
//  ConverterTests.m
//  ValiTag
//
//  Created by Tim.Milne on 8/14/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "Converter.h"

@interface ConverterTests : XCTestCase
{
    Converter *_convert;
    NSString *_dec;
    NSString *_hex;
    NSString *_bin;
    NSString *_decTest;
    NSString *_hexTest;
    NSString *_binTest;
}
@end

@implementation ConverterTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    if (_convert == nil) _convert = [Converter alloc];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDec2Bin{
    // Only works with numbers up to 64 bits...
    _dec = @"3472316652601920064";
    _bin = [_convert Dec2Bin:_dec];
    _binTest = @"0011000000110000001001011001100100110010000000101100101001000000";
    XCTAssertEqualObjects(_bin, _binTest, @"Dec2Bin: Test 1 Failed");
    
    _dec = @"3472316652602285696";
    _bin = [_convert Dec2Bin:_dec];
    _binTest = @"0011000000110000001001011001100100110010000010000101111010000000";
    XCTAssertEqualObjects(_bin, _binTest, @"Dec2Bin: Test 2 Failed");
}
- (void)testBin2Dec{
    // Only works with numbers up to 64 bits...
    _bin = @"0011000000110000001001011001100100110010000000101100101001000000";
    _dec = [_convert Bin2Dec:_bin];
    _decTest = @"3472316652601920064";
    XCTAssertEqualObjects(_dec, _decTest, @"Bin2Dec: Test 1 Failed");
    
    _bin = @"0011000000110000001001011001100100110010000010000101111010000000";
    _dec = [_convert Bin2Dec:_bin];
    _decTest = @"3472316652602285696";
    XCTAssertEqualObjects(_dec, _decTest, @"Bin2Dec: Test 2 Failed");
}
- (void)testDec2Hex{
    // Only works with numbers up to 64 bits...
    _dec = @"3472316652601920064";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"303025993202CA40";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 1 Failed");
    
    _dec = @"3472316652602285696";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"3030259932085E80";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 2 Failed");
    
    _dec = @"4393546062";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"105E0314E";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 3 Failed");
    
    _dec = @"439354606";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"1A3004EE";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 4 Failed");
    
    _dec = @"43935460";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"29E66E4";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 5 Failed");
    
    _dec = @"4393546";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"430A4A";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 6 Failed");
    
    _dec = @"439354";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"6B43A";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 7 Failed");
    
    _dec = @"43935";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"AB9F";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 8 Failed");
    
    _dec = @"4393";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"1129";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 9 Failed");
    
    _dec = @"12345";
    _hex = [_convert Dec2Hex:_dec];
    _hexTest = @"3039";
    XCTAssertEqualObjects(_hex, _hexTest, @"Dec2Hex: Test 10 Failed");
}
- (void)testHex2Dec{
    // Only works with numbers up to 64 bits...
    _hex = @"303025993202CA40";
    _dec = [_convert Hex2Dec:_hex];
    _decTest = @"3472316652601920064";
    XCTAssertEqualObjects(_dec, _decTest, @"Hex2Dec: Test 1 Failed");
    
    _hex = @"3030259932085E80";
    _dec = [_convert Hex2Dec:_hex];
    _decTest = @"3472316652602285696";
    XCTAssertEqualObjects(_dec, _decTest, @"Hex2Dec: Test 2 Failed");
}
- (void)testHex2Bin{
    _hex = @"303025993202CA4000003039";
    _bin = [_convert Hex2Bin:_hex];
    _binTest = @"001100000011000000100101100110010011001000000010110010100100000000000000000000000011000000111001";
    XCTAssertEqualObjects(_bin, _binTest, @"Hex2Bin: Test 1 Failed");
    
    _hex = @"3030259932085E8000003039";
    _bin = [_convert Hex2Bin:_hex];
    _binTest = @"001100000011000000100101100110010011001000001000010111101000000000000000000000000011000000111001";
    XCTAssertEqualObjects(_bin, _binTest, @"Hex2Bin: Test 2 Failed");
}
- (void)testBin2Hex{
    _bin = @"001100000011000000100101100110010011001000000010110010100100000000000000000000000011000000111001";
    _hex = [_convert Bin2Hex:_bin];
    _hexTest = @"303025993202CA4000003039";
    XCTAssertEqualObjects(_hex, _hexTest, @"Bin2Hex: Test 1 Failed");
    
    _bin = @"001100000011000000100101100110010011001000001000010111101000000000000000000000000011000000111001";
    _hex = [_convert Bin2Hex:_bin];
    _hexTest = @"3030259932085E8000003039";
    XCTAssertEqualObjects(_hex, _hexTest, @"Bin2Hex: Test 2 Failed");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
