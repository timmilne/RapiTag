//
//  EPCEncoder.m
//  EPCEncoder
//
//  Created by Tim.Milne on 4/27/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This object takes Target's Department, Class, Item and a Serial Number
//  and encodes it in GS1's SGTIN, GIAI, and GID formats.  Output available
//  in binary, hex, and URI formats
//

#import "EPCEncoder.h"

// NSString
@import Foundation;

// Convert
#import "EPCConverter.h"

// Global values
static NSString *SGTIN_URI_Prefix = @"urn:epc:tag:sgtin-96:1.";
static NSString *SGTIN_Bin_Prefix = @"00110000";
static NSString *GIAI_URI_Prefix  = @"urn:epc:tag:giai-96:0.";
static NSString *GIAI_Bin_Prefix  = @"00110100";
static NSString *GID_URI_Prefix   = @"urn:epc:tag:gid-96:";
static NSString *GID_Bin_Prefix   = @"00110101";

@implementation EPCEncoder {
    EPCConverter *_convert;
}

// Encode with inputs
- (void)withDpt:(NSString *)dpt
        cls:(NSString *)cls
        itm:(NSString *)itm
        ser:(NSString *)ser {
    
    // Have we done this?
    if (_convert == nil) _convert = [EPCConverter alloc];
    
    // Set the inputs
    [self setDpt:dpt];
    [self setCls:cls];
    [self setItm:itm];
    [self setSer:ser];
    
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
        // SGTIN serial number max = 11
        // GIAI serial number max = 18
        // GID serial number max = 10
        // Shorten to the least common denominator for now
        _ser = [_ser substringToIndex:10];
    }
    
    
    // SGTIN - e.g. urn:epc:tag:sgtin-96:1.04928100.08570.12345
    //              3030259932085E8000003039
    //
    // A UPC 12 can be promoted to an EAN14 by right shifting and adding to zeros to the front.
    // One of these zeroes is an indicator digit, which is '0' for items, and this will be moved
    // to the front of the item reference.  The other is the country code, and can be omitted
    // for US and Canada, as those country codes are '0'.
    //
    // Here is how to pack the SGTIN-96 into the EPC
    // 8 bits are the header: 00110000 or 0x30 (SGTIN-96)
    // 3 bits are the Filter: 001 (1 POS Item)
    // 3 bits are the Partition: 100 (4, so 8 digits for manager, 5 for item)
    // 27 bits are the manager number: 049 + Department + Class (8 digits)
    // 17 bits are the 0 prefixed Item: 0 + Item (5 digits, no check digit)
    // 38 bits are the serial number (guaranteed 11 digits)
    // = 96 bits
    NSString *dpt_cls_dec = [NSString stringWithFormat:@"049%@%@",_dpt,_cls];
    NSString *dpt_cls_bin = [_convert Dec2Bin:(dpt_cls_dec)];
    for (int i=(int)[dpt_cls_bin length]; i<(int)27; i++) {
        dpt_cls_bin = [NSString stringWithFormat:@"0%@", dpt_cls_bin];
    }
    NSString *itm_dec = [NSString stringWithFormat:@"0%@",_itm];
    NSString *itm_bin = [_convert Dec2Bin:(itm_dec)];
    for (int i=(int)[itm_bin length]; i<(int)17; i++) {
        itm_bin = [NSString stringWithFormat:@"0%@", itm_bin];
    }
    NSString *ser_bin = [_convert Dec2Bin:(_ser)];
    for (int i=(int)[ser_bin length]; i<(int)38; i++) {
        ser_bin = [NSString stringWithFormat:@"0%@", ser_bin];
    }
    [self setSgtin_bin:[NSString stringWithFormat:@"%@001100%@%@%@",SGTIN_Bin_Prefix,dpt_cls_bin,itm_bin,ser_bin]];
    [self setSgtin_hex:[_convert Bin2Hex:(_sgtin_bin)]];
    [self setSgtin_uri:[NSString stringWithFormat:@"%@%@.%@.%@",SGTIN_URI_Prefix,dpt_cls_dec,itm_dec,_ser]];
    
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    //    NSString *SGTIN_Hex_Ken_str = @"3030259932085E8000003039";
    //    NSString *GSTIN_Bin_Ken_str = [self Hex2Bin:SGTIN_Hex_Ken_str];
   
    
    // GIAI - e.g. urn:epc:tag:giai-96:0.49281008570.12345
    //             34056F2C1077400000003039
    //
    // Here is how to pack the GIAI-96 into the EPC
    // 8 bits are the header: 00110100 or 0x34 (GIAI-96)
    // 3 bits are the Filter: 000 (All Others)
    // 3 bits are the Partition: 001 (1)
    // 37 bits are the manager number: 49 + Department + Class + Item (11 digits)
    // 45 bits are the serial number (guaranteed 14 digits)
    // = 96 bits
    NSString *dpt_cls_itm_dec = [NSString stringWithFormat:@"49%@%@%@",_dpt,_cls,_itm];
    NSString *dpt_cls_itm_bin = [_convert Dec2Bin:(dpt_cls_itm_dec)];
    for (int i=(int)[dpt_cls_itm_bin length]; i<(int)37; i++) {
        dpt_cls_itm_bin = [NSString stringWithFormat:@"0%@", dpt_cls_itm_bin];
    }
    ser_bin = [_convert Dec2Bin:(_ser)];
    for (int i=(int)[ser_bin length]; i<(int)45; i++) {
        ser_bin = [NSString stringWithFormat:@"0%@", ser_bin];
    }
    [self setGiai_bin:[NSString stringWithFormat:@"%@000001%@%@",GIAI_Bin_Prefix,dpt_cls_itm_bin,ser_bin]];
    [self setGiai_hex:[_convert Bin2Hex:(_giai_bin)]];
    [self setGiai_uri:[NSString stringWithFormat:@"%@%@.%@",GIAI_URI_Prefix,dpt_cls_itm_dec,_ser]];
    
    // Check with http://www.kentraub.net/tools/tagxlate/EPCEncoderDecoder.html
    //    NSString *GIAI_Hex_Ken_str = @"34056F2C1077400000003039";
    //    NSString *GIAI_Bin_Ken_str = [self Hex2Bin:GIAI_Hex_Ken_str];
    
    
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
    dpt_cls_dec = [NSString stringWithFormat:@"049%@%@",_dpt,_cls];
    dpt_cls_bin = [_convert Dec2Bin:(dpt_cls_dec)];
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
    ser_bin = [_convert Dec2Bin:(_ser)];
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
