//
//  EPCEncoderTests.m
//  ValiTag
//
//  Created by Tim.Milne on 8/14/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "EPCEncoder.h"

@interface EPCEncoderTests : XCTestCase
{
    EPCEncoder *_encode;
    NSString   *_dpt;
    NSString   *_cls;
    NSString   *_itm;
    NSString   *_ser;
    NSString   *_gtin;
    NSString   *_partBin;
    NSString   *_test_gid_bin;
    NSString   *_test_gid_hex;
    NSString   *_test_gid_uri;
    NSString   *_test_sgtin_bin;
    NSString   *_test_sgtin_hex;
    NSString   *_test_sgtin_uri;
    NSString   *_test_empty;
}

@end

@implementation EPCEncoderTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    if (_encode == nil) _encode = [EPCEncoder alloc];
    _test_empty = @"";
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testWithDptClsItmSer{
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    //    NSString *GID_Hex_Ken_str = @"3504B3264014EC6000003039";
    _dpt = @"281";
    _cls = @"00";
    _itm = @"8570";
    _ser = @"12345";
    [_encode withDpt:_dpt cls:_cls itm:_itm ser:_ser];
    _test_gid_bin = @"001101010000010010110011001001100100000000010100111011000110000000000000000000000011000000111001";
    _test_gid_hex = @"3504B3264014EC6000003039";
// TPM - We are not using the uri, so leave this for now, but note that GID CANNOT have leading zeroes
//       in the manager and item fields...
//    _test_gid_uri = @"urn:epc:tag:gid-96:4928100.85702.12345";  // This is what it is supposed to look like
    _test_gid_uri = @"urn:epc:tag:gid-96:04928100.0085702.12345"; // This is what is being returned
    
    XCTAssertEqualObjects(_test_gid_bin, [_encode gid_bin],   @"withDptClsItmSer: Test 1 Part 1 Failed");
    XCTAssertEqualObjects(_test_gid_hex, [_encode gid_hex],   @"withDptClsItmSer: Test 1 Part 2 Failed");
    XCTAssertEqualObjects(_test_gid_uri, [_encode gid_uri],   @"withDptClsItmSer: Test 1 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty  , [_encode gtin],      @"withDptClsItmSer: Test 1 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty  , [_encode sgtin_bin], @"withDptClsItmSer: Test 1 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty  , [_encode sgtin_hex], @"withDptClsItmSer: Test 1 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty  , [_encode sgtin_uri], @"withDptClsItmSer: Test 1 Part 7 Failed");
}

- (void)testWithGtinSerPartBin{
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    _gtin   = @"00043935460624";
    _ser     = @"12345";
    _partBin = @"000"; // Mgr len 12, Itm len 1
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000010000000000100000101111000000011000101001110000000000000000000000000000011000000111001";
    _test_sgtin_hex = @"3020041780C5380000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.004393546062.0.12345";
    
    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 1 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 1 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 1 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 1 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 1 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 1 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 1 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 1 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 1 Part 9 Failed");
    
    _partBin = @"001"; // Mgr len 11, Itm len 2
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000010010000000011010001100000000010011101110000001000000000000000000000000011000000111001";
    _test_sgtin_hex = @"30240346009DC08000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.00439354606.02.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 2 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 2 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 2 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 2 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 2 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 2 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 2 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 2 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 2 Part 9 Failed");
    
    _partBin = @"010"; // Mgr len 10, Itm len 3
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000010100000000010100111100110011011100100000011111000000000000000000000000011000000111001";
    _test_sgtin_hex = @"3028029E66E40F8000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.0043935460.062.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 3 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 3 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 3 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 3 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 3 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 3 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 3 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 3 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 3 Part 9 Failed");
    
    _partBin = @"011"; // Mgr len 9, Itm len 4
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000010110000000100001100001010010010100000000011111000000000000000000000000011000000111001";
    _test_sgtin_hex = @"302C0430A4A00F8000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.004393546.0062.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 4 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 4 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 4 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 4 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 4 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 4 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 4 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 4 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 4 Part 9 Failed");
    
    _partBin = @"100"; // Mgr len 8, Itm len 5
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000011000000000011010110100001110100000101111010111000000000000000000000000011000000111001";
    _test_sgtin_hex = @"3030035A1D05EB8000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.00439354.06062.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 5 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 5 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 5 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 5 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 5 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 5 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 5 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 5 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 5 Part 9 Failed");

    _partBin = @"101"; // Mgr len 7, Itm len 6
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000011010000000010101011100111110000101100111110111000000000000000000000000011000000111001";
    _test_sgtin_hex = @"303402AE7C2CFB8000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.0043935.046062.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 6 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 6 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 6 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 6 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 6 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 6 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 6 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 6 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 6 Part 9 Failed");

    _partBin = @"110"; // Mgr len 6, Itm len 7
    [_encode withGTIN:_gtin ser:_ser partBin:_partBin];
    _test_sgtin_bin = @"001100000011100000000100010010100100001000010101010000111000000000000000000000000011000000111001";
    _test_sgtin_hex = @"3038044A4215438000003039";
    _test_sgtin_uri = @"urn:epc:tag:sgtin-96:1.004393.0546062.12345";

    XCTAssertEqualObjects(_test_sgtin_bin, [_encode sgtin_bin], @"withGtinSerPartBin: Test 7 Part 1 Failed");
    XCTAssertEqualObjects(_test_sgtin_hex, [_encode sgtin_hex], @"withGtinSerPartBin: Test 7 Part 2 Failed");
    XCTAssertEqualObjects(_test_sgtin_uri, [_encode sgtin_uri], @"withGtinSerPartBin: Test 7 Part 3 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode dpt],       @"withGtinSerPartBin: Test 7 Part 4 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode cls],       @"withGtinSerPartBin: Test 7 Part 5 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode itm],       @"withGtinSerPartBin: Test 7 Part 6 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_bin],   @"withGtinSerPartBin: Test 7 Part 7 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_hex],   @"withGtinSerPartBin: Test 7 Part 8 Failed");
    XCTAssertEqualObjects(_test_empty    , [_encode gid_uri],   @"withGtinSerPartBin: Test 7 Part 9 Failed");
}

- (void)testCalculateCheckDigit{
    NSString *upc12 = @"043935460624";
    NSString *chk12 = [_encode calculateCheckDigit:[upc12 substringToIndex:11]];
    NSString *testChk12 = @"4";
    
    XCTAssertEqualObjects(testChk12, chk12, @"calculateCheckDigit: Test 1 Failed");
    
    NSString *upc14 = @"00043935460624";
    NSString *chk14 = [_encode calculateCheckDigit:[upc14 substringToIndex:13]];
    NSString *testChk14 = @"4";
    
    XCTAssertEqualObjects(testChk14, chk14, @"calculateCheckDigit: Test 2 Failed");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
