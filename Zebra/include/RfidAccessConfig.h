/******************************************************************************
 *
 *       Copyright Zebra Technologies, Inc. 2014 - 2015
 *
 *       The copyright notice above does not evidence any
 *       actual or intended publication of such source code.
 *       The code contains Zebra Technologies
 *       Confidential Proprietary Information.
 *
 *
 *  Description:  RfidAccessConfig.h
 *
 *  Notes:
 *
 ******************************************************************************/

#import <Foundation/Foundation.h>

@interface srfidAccessConfig : NSObject
{
    BOOL m_DoSelect;
    BOOL m_EnableSummaryNotify;
    short m_Power;
}

- (BOOL)getDoSelect;
- (void)setDoSelect:(BOOL)val;
- (BOOL)getEnableSummaryNotify;
- (void)setEnableSummaryNotify:(BOOL)val;
- (short)getPower;
- (void)setPower:(short)val;

@end
