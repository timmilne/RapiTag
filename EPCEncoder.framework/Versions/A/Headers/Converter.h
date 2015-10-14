//
//  Converter.h
//
//  Created by Tim.Milne on 4/27/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This object converts betweem Decimal, Hex and Binary
//  All inputs and outputs are NSStrings
//

#import <Foundation/Foundation.h>

@interface Converter : NSObject

- (NSString *)Dec2Bin:(NSString *)dec;
- (NSString *)Bin2Dec:(NSString *)bin;
- (NSString *)Dec2Hex:(NSString *)dec;
- (NSString *)Hex2Dec:(NSString *)hex;
- (NSString *)Hex2Bin:(NSString *)hex;
- (NSString *)Bin2Hex:(NSString *)bin;

@end
