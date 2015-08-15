//
//  EPCEncoder.m
//  EPCEncoder
//
//  Created by Tim.Milne on 4/27/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This object takes Target's Department, Class, Item and a Serial Number
//  and encodes it in GS1's GID format, or a GTIN and encodes it in GS1's SGTIN format.
//  Output available in binary, hex, and URI formats
//

#import "EPCEncoder.h"

// NSString
@import Foundation;

// Convert
#import "Converter.h"

@implementation EPCEncoder {
    Converter *_convert;
}

// Encode with DPCI
- (void)withDpt:(NSString *)dpt
        cls:(NSString *)cls
        itm:(NSString *)itm
        ser:(NSString *)ser {
    
    // Have we done this?
    if (_convert == nil) _convert = [Converter alloc];
    
    // Set the inputs
    [self setDpt:dpt];
    [self setCls:cls];
    [self setItm:itm];
    [self setSer:ser];
    [self setGtin:@""];
    [self setSgtin_bin:@""];
    [self setSgtin_hex:@""];
    [self setSgtin_uri:@""];
    
    // Make sure the inputs are not too long (especially the Serial Number)
    if ([_dpt length] > 3) {
        _dpt = [_dpt substringToIndex:3];
    }
    if ([_cls length] > 2) {
        _cls = [_cls substringToIndex:2];
    }
    if ([_itm length] > 4) {
        _itm = [_itm substringToIndex:4];
    }
    if ([_ser length] > 10) {
        _ser = [_ser substringToIndex:10];
    }
    
    // GID - e.g. urn:epc:tag:gid-96:4928100.85702.12345
    //            3504B3264014EC6000003039
    //
    // Here is how to pack the GID-96 into the EPC
    // 8 bits are the header: 00110101 or 0x35 (GID-96)
    // No Filter
    // No Partition
    // 28 bits are the manager number: 00 + 49 + Department + Class (8 digits)
    // 24 bits are the item number (object class): 000 + Item + Check Digit (7 digits)
    // 36 bits are the serial number (guaranteed 10 digits)
    // = 96 bits
    NSString *dpt_cls_dec = [NSString stringWithFormat:@"049%@%@",_dpt,_cls];
    NSString *dpt_cls_bin = [_convert Dec2Bin:(dpt_cls_dec)];
    for (int i=(int)[dpt_cls_bin length]; i<(int)28; i++) {
        dpt_cls_bin = [NSString stringWithFormat:@"0%@", dpt_cls_bin];
    }
    NSString *upc = [NSString stringWithFormat:@"49%@%@%@",_dpt,_cls,_itm];
    NSString *chkdgt = [self calculateCheckDigit:upc];
    NSString *itm_chk_dec = [NSString stringWithFormat:@"00%@%@",_itm,chkdgt];
    NSString *itm_chk_bin = [_convert Dec2Bin:(itm_chk_dec)];
    for (int i=(int)[itm_chk_bin length]; i<(int)24; i++) {
        itm_chk_bin = [NSString stringWithFormat:@"0%@", itm_chk_bin];
    }
    NSString *ser_bin = [_convert Dec2Bin:(_ser)];
    for (int i=(int)[ser_bin length]; i<(int)36; i++) {
        ser_bin = [NSString stringWithFormat:@"0%@", ser_bin];
    }
    
    [self setGid_bin:[NSString stringWithFormat:@"%@%@%@%@",GID_Bin_Prefix,dpt_cls_bin,itm_chk_bin,ser_bin]];
    [self setGid_hex:[_convert Bin2Hex:(_gid_bin)]];
    [self setGid_uri:[NSString stringWithFormat:@"%@%@.%@.%@",GID_URI_Prefix,dpt_cls_dec,itm_chk_dec,_ser]];
    
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    //    NSString *GID_Hex_Ken_str = @"3504B3264014EC6000003039";
    //    NSString *GID_Bin_Ken_str = [self Hex2Bin:GID_Hex_Ken_str];
}

// Encode with GTIN
- (void)withGTIN:(NSString *)gtin
        ser:(NSString *)ser
        partBin:(NSString *)partBin{
    
    // Have we done this?
    if (_convert == nil) _convert = [Converter alloc];
    
    // Set the inputs
    [self setDpt:@""];
    [self setCls:@""];
    [self setItm:@""];
    [self setSer:ser];
    [self setGtin:gtin];
    [self setGid_bin:@""];
    [self setGid_hex:@""];
    [self setGid_uri:@""];
    
    int mgrBinLen   = 0;
    int mgrDecLen   = 0;
    int itmBinLen   = 0;
    int itmDecLen   = 0;
    
    // GS1 Tag Data Standard partition values for SGTIN
    if ([partBin isEqualToString:@"000"]) {
        mgrBinLen   = 40;
        mgrDecLen   = 12;
        itmBinLen   = 4;
        itmDecLen   = 1;
    }
    else if ([partBin isEqualToString:@"001"]) {
        mgrBinLen   = 37;
        mgrDecLen   = 11;
        itmBinLen   = 7;
        itmDecLen   = 2;
    }
    else if ([partBin isEqualToString:@"010"]) {
        mgrBinLen   = 34;
        mgrDecLen   = 10;
        itmBinLen   = 10;
        itmDecLen   = 3;
    }
    else if ([partBin isEqualToString:@"011"]) {
        mgrBinLen   = 30;
        mgrDecLen   = 9;
        itmBinLen   = 14;
        itmDecLen   = 4;
    }
    else if ([partBin isEqualToString:@"100"]) {
        mgrBinLen   = 27;
        mgrDecLen   = 8;
        itmBinLen   = 17;
        itmDecLen   = 5;
    }
    else if ([partBin isEqualToString:@"101"]) {
        mgrBinLen   = 24;
        mgrDecLen   = 7;
        itmBinLen   = 20;
        itmDecLen   = 6;
    }
    else if ([partBin isEqualToString:@"110"]) {
        mgrBinLen   = 20;
        mgrDecLen   = 6;
        itmBinLen   = 24;
        itmDecLen   = 7;
    }
    
    // Make sure the inputs are not too long (especially the Serial Number)
    if ([_gtin length] > 14) {
        _gtin = [_gtin substringToIndex:14];
    }
    while ([_gtin length] < 14) {
        _gtin = [NSString stringWithFormat:@"0%@", _gtin];
    }
    if ([_ser length] > 11) {
        // SGTIN serial number max = 11
        _ser = [_ser substringToIndex:11];
    }
    
    // SGTIN - e.g. urn:epc:tag:sgtin-96:1.0043935.046062.12345
    //              303402AE7C2CFB8000003039
    //
    // A UPC 12 can be promoted to an EAN14 by right shifting and adding two zeros to the front.
    // One of these zeroes is an indicator digit, which is '0' for items, and this will be moved
    // to the front of the item reference.  The other is the country code, and can be omitted
    // for US and Canada, as those country codes are '0'.
    //
    // Here is how to pack the SGTIN-96 into the EPC
    // 8 bits are the header: 00110000 or 0x30 (SGTIN-96)
    // 3 bits are the Filter: 001 (1 POS Item)
    // 3 bits are the Partition: See above (from the scanned RFID tag)
    // 20-40 bits are the manager number: 0 + digits 3-x of gtin
    // 24-4 bits are the 0 prefixed Item: 0 + digits x-13 of gtin (NO CHECK DIGIT)
    // 38 bits are the serial number (guaranteed 11 digits)
    // = 96 bits
    NSString *mgrDec = [NSString stringWithFormat:@"0%@", [_gtin substringWithRange:NSMakeRange(2,(mgrDecLen-1))]];
    NSString *mgrBin = [_convert Dec2Bin:(mgrDec)];
    for (int i=(int)[mgrBin length]; i<(int)mgrBinLen; i++) {
        mgrBin = [NSString stringWithFormat:@"0%@", mgrBin];
    }
    
    // Drop the check digit!!
    NSString *itmDec = [NSString stringWithFormat:@"0%@", [_gtin substringWithRange:NSMakeRange((2+(mgrDecLen-1)),itmDecLen-1)]];
    NSString *itmBin = [_convert Dec2Bin:(itmDec)];
    for (int i=(int)[itmBin length]; i<(int)itmBinLen; i++) {
        itmBin = [NSString stringWithFormat:@"0%@", itmBin];
    }
    NSString *serBin = [_convert Dec2Bin:(_ser)];
    for (int i=(int)[serBin length]; i<(int)38; i++) {
        serBin = [NSString stringWithFormat:@"0%@", serBin];
    }
    [self setSgtin_bin:[NSString stringWithFormat:@"%@001%@%@%@%@",SGTIN_Bin_Prefix,partBin,mgrBin,itmBin,serBin]];
    [self setSgtin_hex:[_convert Bin2Hex:(_sgtin_bin)]];
    [self setSgtin_uri:[NSString stringWithFormat:@"%@%@.%@.%@",SGTIN_URI_Prefix,mgrDec,itmDec,_ser]];
    
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    //    NSString *SGTIN_Hex_Ken_str = @"303402AE7C2CFB8000003039";
    //    NSString *SGTIN_Bin_Ken_str = [self Hex2Bin:SGTIN_Hex_Ken_str];
}

// Quick Check Digit calculator
- (NSString *)calculateCheckDigit:(NSString *)upc {
    int sumOdd = 0;
    int sumEven = 0;
    NSRange range = {0, 1};
    
    for (; range.location < [upc length]; range.location++) {
        sumOdd += [[upc substringWithRange:range] integerValue];
        range.location++;
        if (range.location < [upc length]){
            sumEven += [[upc substringWithRange:range] integerValue];
        }
    }
    
    return [NSString stringWithFormat:@"%d",((10 - ((3*sumOdd + sumEven)%10))%10)];
}

@end
