//
//  EPCConverter.m
//
//  Created by Tim.Milne on 4/27/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This object converts betweem Decimal, Hex and Binary
//  All inputs and outputs are NSStrings
//

#import "EPCConverter.h"

// NSString
@import Foundation;

@implementation EPCConverter {
    NSDictionary *_dictBin2Hex;
    NSDictionary *_dictHex2Bin;
}
- (void)initDictionaries {
    if (_dictBin2Hex == nil) {
        _dictBin2Hex = [[NSDictionary alloc] initWithObjectsAndKeys:
                        @"0",@"0000",
                        @"1",@"0001",
                        @"2",@"0010",
                        @"3",@"0011",
                        @"4",@"0100",
                        @"5",@"0101",
                        @"6",@"0110",
                        @"7",@"0111",
                        @"8",@"1000",
                        @"9",@"1001",
                        @"A",@"1010",
                        @"B",@"1011",
                        @"C",@"1100",
                        @"D",@"1101",
                        @"E",@"1110",
                        @"F",@"1111", nil];
    }
    if (_dictHex2Bin == nil) {
        _dictHex2Bin = [[NSDictionary alloc] initWithObjectsAndKeys:
                        @"0000",@"0",
                        @"0001",@"1",
                        @"0010",@"2",
                        @"0011",@"3",
                        @"0100",@"4",
                        @"0101",@"5",
                        @"0110",@"6",
                        @"0111",@"7",
                        @"1000",@"8",
                        @"1001",@"9",
                        @"1010",@"A",
                        @"1011",@"B",
                        @"1100",@"C",
                        @"1101",@"D",
                        @"1110",@"E",
                        @"1111",@"F", nil];
    }
}

- (NSString *)Dec2Bin:(NSString *)dec {
    return [self Hex2Bin:([self Dec2Hex:(dec)])];
}

- (NSString *)Bin2Dec:(NSString *)bin {
    return [self Hex2Dec:([self Bin2Hex:(bin)])];
}

- (NSString *)Dec2Hex:(NSString *)dec {
    // TPM: This did not work with a number longer than 32 bits...
    // So switched to a 64 bit long - watch out if you go longer than that...
    return [NSString stringWithFormat:@"%llX",[dec longLongValue]];
}

- (NSString *)Hex2Dec:(NSString *)hex {
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    // TPM: This did not work with a number longer than 32 bits...
    // So switched to a 64 bit long - watch out if you go longer than that...
    unsigned long long tmpDec;
    [scanner scanHexLongLong:&tmpDec];
    return [NSString stringWithFormat:@"%lld",tmpDec];
}

- (NSString *)Bin2Hex:(NSString *)bin {
    NSString *hex = @"";
    NSString *paddedBin = bin;
    
    if (_dictBin2Hex == nil) [self initDictionaries];
    
    // Pad to 4 bit bytes
    while((paddedBin.length % 4) != 0) paddedBin = [NSString stringWithFormat:@"0%@", paddedBin];
    
    for (int i = 0;i < [paddedBin length]; i+=4)
    {
        NSString *binKey = [paddedBin substringWithRange: NSMakeRange(i, 4)];
        hex = [NSString stringWithFormat:@"%@%@",hex,[_dictBin2Hex valueForKey:binKey]];
    }
    return hex;
}

- (NSString *)Hex2Bin:(NSString *)hex {
    NSString *bin = @"";
    
    if (_dictHex2Bin == nil) [self initDictionaries];
    
    for (int i = 0;i < [hex length]; i++)
    {
        NSString *hexKey = [hex substringWithRange: NSMakeRange(i, 1)];
        bin = [NSString stringWithFormat:@"%@%@",bin,[_dictHex2Bin valueForKey:hexKey]];
    }
    return bin;
}

@end
