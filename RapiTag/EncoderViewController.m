//
//  EncoderViewController.m
//  RapiTag
//
//  Created by Tim.Milne on 5/11/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  Barcode scanner code from:
//  http://www.infragistics.com/community/blogs/torrey-betts/archive/2013/10/10/scanning-barcodes-with-ios-7-objective-c.aspx
//
//  uGrokit RFID scanner code from:
//  http://dev.ugrokit.com/ios.html
//
//  Zebra RFID scanner code from:
//  http://compass.motorolasolutions.com

#import "EncoderViewController.h"
#import <AVFoundation/AVFoundation.h> // Barcode capture tools
#import <EPCEncoder/EPCEncoder.h>     // To encode the scanned barcode for comparison
#import <EPCEncoder/Converter.h>      // To convert to binary for comparison
#import "Ugi.h"                       // uGrokit goodies
#import "RfidSdkFactory.h"            // Zebra reader

@interface EncoderViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate, srfidISdkApiDelegate>
{
    __weak IBOutlet UILabel         *_dptLbl;
    __weak IBOutlet UILabel         *_clsLbl;
    __weak IBOutlet UILabel         *_itmLbl;
    __weak IBOutlet UILabel         *_serLbl;
    __weak IBOutlet UILabel         *_gtinLbl;
    __weak IBOutlet UITextField     *_dptFld;
    __weak IBOutlet UITextField     *_clsFld;
    __weak IBOutlet UITextField     *_itmFld;
    __weak IBOutlet UITextField     *_serFld;
    __weak IBOutlet UITextField     *_gtinFld;
    __weak IBOutlet UIBarButtonItem *_resetBtn;
    __weak IBOutlet UIBarButtonItem *_encodeBtn;
    __weak IBOutlet UIImageView     *_successImg;
    __weak IBOutlet UIImageView     *_failImg;
    __weak IBOutlet UISwitch        *_replaceSwt;
    
    BOOL                        _barcodeFound;
    BOOL                        _rfidFound;
    BOOL                        _encoding;
    BOOL                        _tagEncoded;
    NSMutableString             *_oldEPC;
    NSMutableString             *_newEPC;
    UIColor                     *_defaultBackgroundColor;
    
    AVCaptureSession            *_session;
    AVCaptureDevice             *_device;
    AVCaptureDeviceInput        *_input;
    AVCaptureMetadataOutput     *_output;
    AVCaptureVideoPreviewLayer  *_prevLayer;
    
    UIView                      *_highlightView;
    UILabel                     *_barcodeLbl;
    UILabel                     *_rfidLbl;
    UILabel                     *_batteryLifeLbl;
    UIProgressView              *_batteryLifeView;
    
    EPCEncoder                  *_encode;
    Converter                   *_convert;
    
    BOOL                        _ugiReaderConnected;
    UgiRfidConfiguration        *_ugiConfig;
    
    BOOL                        _zebraReaderConnected;
    id <srfidISdkApi>           _rfidSdkApi;
    int                         _readerID;
    srfidStartTriggerConfig     *_startTriggerConfig;
    srfidStopTriggerConfig      *_stopTriggerConfig;
    srfidReportConfig           *_reportConfig;
    srfidAccessConfig           *_accessConfig;
    srfidDynamicPowerConfig     *_dpoConfig;            // Only for writing tags
}
@end

@implementation EncoderViewController

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // Initialize variables
    _encode = [EPCEncoder alloc];
    _convert = [Converter alloc];
    _oldEPC = [[NSMutableString alloc] init];
    _newEPC = [[NSMutableString alloc] init];
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _defaultBackgroundColor = UIColorFromRGB(0x000000);
    
    // Set scanner configuration used in startInventory
    _ugiConfig = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_ugiConfig setVolume:.2];
    
    // Set the label background colors
    _dptLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _clsLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _itmLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _serLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _gtinLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
// TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
// the settings programatically, so I've continued with that here...
    
    // Barcode highlight view
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];
    
    // Barcode label view
    _barcodeLbl = [[UILabel alloc] init];
    _barcodeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 120, self.view.bounds.size.width, 40);
    _barcodeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _barcodeLbl.textColor = [UIColor whiteColor];
    _barcodeLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_barcodeLbl];
    
    // RFID label view
    _rfidLbl = [[UILabel alloc] init];
    _rfidLbl.frame = CGRectMake(0, self.view.bounds.size.height - 80, self.view.bounds.size.width, 40);
    _rfidLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _rfidLbl.textColor = [UIColor whiteColor];
    _rfidLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_rfidLbl];
    
    // Battery life label
    _batteryLifeLbl = [[UILabel alloc] init];
    _batteryLifeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _batteryLifeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeLbl.textColor = [UIColor whiteColor];
    _batteryLifeLbl.textAlignment = NSTextAlignmentCenter;
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view addSubview:_batteryLifeLbl];
    
    // Battery life view
    _batteryLifeView = [[UIProgressView alloc] init];
    _batteryLifeView.frame = CGRectMake(0, self.view.bounds.size.height - 8, self.view.bounds.size.width, 40);
    _batteryLifeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view addSubview:_batteryLifeView];
    
    // Initialize the bar code scanner session, device, input, output, and preview layer
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@\n", error);
    }
    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];
    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];
    
    // Register with the default NotificationCenter for RFID reads
    // TPM there was a typo in the online documentation fixed here
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStateChanged:)
                                                 name:[Ugi singleton].NOTIFICAION_NAME_CONNECTION_STATE_CHANGED
                                               object:nil];
    
    // Pop the subviews to the front of the preview view
    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_barcodeLbl];
    [self.view bringSubviewToFront:_rfidLbl];
    [self.view bringSubviewToFront:_batteryLifeLbl];
    [self.view bringSubviewToFront:_batteryLifeView];
    [self.view bringSubviewToFront:_successImg];
    [self.view bringSubviewToFront:_failImg];
    
    // Reset initializes all the variables and colors and pops the remaining views
    [self reset:_resetBtn];
    
    // Update the encoder
    [self updateAll];
    
    // Start scanning for barcodes
    [_session startRunning];
    
    // Set Zebra scanner configurations used in srfidStartRapidRead
    _zebraReaderConnected = FALSE;
    _readerID = -1;
    [self zebraInitializeRfidSdkWithAppSettings];
}

/*!
 * @discussion Adjust the preview layer on orientation changes
 */
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    switch ((int)orientation) {
        case UIInterfaceOrientationPortrait:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            break;
    }
}

/*!
 * @discussion Press reset button to reset the interface and reader and begin reading.
 * @param sender The ID of the sender object (not used)
 */
- (IBAction)reset:(id)sender {
    // TPM - uncomment this to test a NewRelic crash
    //    [NewRelic crashNow:@"Crashed on Reset"];
    
    // Reset all controls and variables
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _encodeBtn.enabled = FALSE;
    _encoding = FALSE;
    [_oldEPC setString:@""];
    [_newEPC setString:@""];
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    _dptFld.text = @"";
    _clsFld.text = @"";
    _itmFld.text = @"";
    _serFld.text = @"1";
    _gtinFld.text = @"";
    
    _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.text = @"RFID: (connecting to reader)";
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.text = @"RFID Battery Life";
    _batteryLifeView.progress = 0.;
    
    // Bring the input views to the front
    [self.view bringSubviewToFront:_dptLbl];
    [self.view bringSubviewToFront:_clsLbl];
    [self.view bringSubviewToFront:_itmLbl];
    [self.view bringSubviewToFront:_serLbl];
    [self.view bringSubviewToFront:_gtinLbl];
    [self.view bringSubviewToFront:_dptFld];
    [self.view bringSubviewToFront:_clsFld];
    [self.view bringSubviewToFront:_itmFld];
    [self.view bringSubviewToFront:_serFld];
    [self.view bringSubviewToFront:_gtinFld];
    
    // Hide the result images (treat these different for landscape mode)
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
// TPM - This logic assumes that once you've read a tag with one type of reader, you won't switch
// to another.  If you change readers, restart the app.  The first reader to scan a tag sets the
// reader flags for that session.  Until then, all protocols are attempted until a tag is found.
    
    // If no connection open, open it now and start scanning for RFID tags
    // Before we know what reader, we try all, so test the negative
    
    // uGrokit Reader
    if (!_zebraReaderConnected) {
        [[Ugi singleton].activeInventory stopInventory];
        [[Ugi singleton] closeConnection];
        [[Ugi singleton] openConnection];  // Does a lot of things, including check battery life, and start an inventory
    }
    
    // Zebra Reader
    if (!_ugiReaderConnected) {
        [_rfidSdkApi srfidStopRapidRead:_readerID aStatusMessage:nil];
        [_rfidSdkApi srfidTerminateCommunicationSession:_readerID];
        _readerID = -1;
        [self zebraRapidRead];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Zebra RFID Reader
#pragma mark - Zebra Reader Support

/*!
 * @discussion Initialize the Zebra reader and start a rapid read.
 */
- (void)zebraInitializeRfidSdkWithAppSettings
{
    _rfidSdkApi = [srfidSdkFactory createRfidSdkApiInstance];
    [_rfidSdkApi srfidSetDelegate:self];
    
    int notifications_mask = SRFID_EVENT_READER_APPEARANCE |
    SRFID_EVENT_READER_DISAPPEARANCE | // Not really needed
    SRFID_EVENT_SESSION_ESTABLISHMENT |
    SRFID_EVENT_SESSION_TERMINATION; // Not really needed
    [_rfidSdkApi srfidSetOperationalMode:SRFID_OPMODE_MFI];
    [_rfidSdkApi srfidSubsribeForEvents:notifications_mask];
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_READ | SRFID_EVENT_MASK_STATUS)]; // Event mask not needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_PROXIMITY)]; // Not really needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_TRIGGER)]; // Not really needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_BATTERY)];
    [_rfidSdkApi srfidEnableAvailableReadersDetection:YES];
    [_rfidSdkApi srfidEnableAutomaticSessionReestablishment:YES];
    
    _startTriggerConfig = [[srfidStartTriggerConfig alloc] init];
    _stopTriggerConfig  = [[srfidStopTriggerConfig alloc] init];
    _reportConfig       = [[srfidReportConfig alloc] init];
    _accessConfig       = [[srfidAccessConfig alloc] init];
    _dpoConfig          = [[srfidDynamicPowerConfig alloc] init]; // Only for writing tags
    
    // Configure start and stop triggers parameters to start and stop actual
    // operation immediately on a corresponding response
    [_startTriggerConfig setStartOnHandheldTrigger:NO];
    [_startTriggerConfig setStartDelay:0];
    [_startTriggerConfig setRepeatMonitoring:NO];
    [_stopTriggerConfig setStopOnHandheldTrigger:NO];
    [_stopTriggerConfig setStopOnTimeout:NO];
    [_stopTriggerConfig setStopOnTagCount:YES];
    [_stopTriggerConfig setStopOnInventoryCount:YES];
    [_stopTriggerConfig setStopTagCount:1];
    [_stopTriggerConfig setStopOnAccessCount:NO];
    
    // Configure report parameters to report RSSI, Channel Index, Phase and PC fields
    [_reportConfig setIncPC:YES];
    [_reportConfig setIncPhase:YES];
    [_reportConfig setIncChannelIndex:YES];
    [_reportConfig setIncRSSI:YES];
    [_reportConfig setIncTagSeenCount:NO];
    [_reportConfig setIncFirstSeenTime:NO];
    [_reportConfig setIncLastSeenTime:NO];
    
    // Configure access parameters to perform the operation with 12.0 dbm antenna
    // power level without application of pre-filters for close proximity
    [_accessConfig setPower:120];
    [_accessConfig setDoSelect:NO];
    
    // Configure dynamic power options (must be off for writing)
    [_dpoConfig setDynamicPowerOptimizationEnabled:FALSE];
    
    // See if a reader is already connected and try and read a tag
    [self zebraRapidRead];
}

/*!
 * @discussion Kick off a Zebra Rapid Read.
 */
- (void)zebraRapidRead
{
    if (_readerID < 0) {
        // Get an available reader (must connect with bluetooth settings outside of app)
        NSMutableArray *readers = [[NSMutableArray alloc] init];
        [_rfidSdkApi srfidGetAvailableReadersList:&readers];
        
        for (srfidReaderInfo *reader in readers)
        {
            SRFID_RESULT result = [_rfidSdkApi srfidEstablishCommunicationSession:[reader getReaderID]];
            if (result == SRFID_RESULT_SUCCESS) {
                break;
            }
        }
    }
    else {
        [_rfidSdkApi srfidRequestBatteryStatus:_readerID];
        _zebraReaderConnected = TRUE;
        
        NSString *error_response = nil;
        
        do {
            // Set start trigger parameters
            SRFID_RESULT result = [_rfidSdkApi srfidSetStartTriggerConfiguration:_readerID
                                                              aStartTriggeConfig:_startTriggerConfig
                                                                  aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                // Start trigger configuration applied
                NSLog(@"Zebra Start trigger configuration has been set\n");
            } else {
                NSLog(@"Zebra Failed to set start trigger parameters\n");
                break;
            }
            
            // Set stop trigger parameters
            result = [_rfidSdkApi srfidSetStopTriggerConfiguration:_readerID
                                                 aStopTriggeConfig:_stopTriggerConfig
                                                    aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                // Stop trigger configuration applied
                NSLog(@"Zebra Stop trigger configuration has been set\n");
            } else {
                NSLog(@"Zebra Failed to set stop trigger parameters\n");
                break;
            }
            
            // Set dynamice power options parameters (must be off for writing tags)
            result  = [_rfidSdkApi srfidSetDpoConfiguration:_readerID
                                          aDpoConfiguration:_dpoConfig
                                             aStatusMessage:&error_response];
            
            if (SRFID_RESULT_SUCCESS == result ) {
                // Dynamic power options configuration applied
                NSLog(@"Zebra dynamic power options configuration has been set\n");
            } else {
                NSLog(@"Zebra Failed to set dynamic power options parameters\n");
                break;
            }
            
            // Start and stop triggers and DPO have been configured
            error_response = nil;
            
            // Request performing of rapid read operation
            result = [_rfidSdkApi srfidStartRapidRead:_readerID
                                        aReportConfig:_reportConfig
                                        aAccessConfig:_accessConfig
                                       aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                NSLog(@"Zebra Request succeeded\n");
                
                _rfidLbl.text = @"RFID: (scanning for tags)";
                _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
                
                // Stop an operation after 1 minute
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 *
                                                                          NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [_rfidSdkApi srfidStopRapidRead:_readerID aStatusMessage:nil];
                });
            }
            else if (SRFID_RESULT_RESPONSE_ERROR == result) {
                NSLog(@"Zebra Error response from RFID reader: %@\n", error_response);
            }
            else {
                NSLog(@"Zebra Request failed\n");
            }
        } while (0);
    }
}

// Barcode scanner
#pragma mark - Barcode Scanner Delegates

/*!
 * @discussion Check for a valid scanned barcode, only proceed if a valid barcode found.  Check for ready to encode.
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                              AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        if (detectionString != nil)
        {
            // Assume false until verified
            _barcodeFound = FALSE;
            
            // New input data
            _successImg.hidden = TRUE;
            _failImg.hidden = TRUE;
            
            // Grab the barcode
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            NSString *barcode;
            barcode = detectionString;
            
            // Quick length checks, chop to 12 for now (remove leading zeros)
            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            
            // Owned brand, encode DPCI in a GID
            if (barcode.length == 12 && [[barcode substringToIndex:2] isEqualToString:@"49"]) {
                NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
                NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
                NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
                NSString *ser = ([_serFld.text length])?[_serFld text]:@"0";
                
                // If this is a replacement tag, check the commissioning authority
                if (_replaceSwt.on == TRUE) {
                    for (int i=(int)[ser length]; i<10; i++) {
                        ser = [NSString stringWithFormat:@"0%@", ser];
                    }
                    
                    // Make sure it starts with 01, 02, 03, 04
                    if (!([[ser substringToIndex:2] isEqualToString:@"01"] ||
                          [[ser substringToIndex:2] isEqualToString:@"02"] ||
                          [[ser substringToIndex:2] isEqualToString:@"03"] ||
                          [[ser substringToIndex:2] isEqualToString:@"04"])) {
                        ser = [NSString stringWithFormat:@"01%@", [ser substringFromIndex:2]];
                    }
                    [_serFld setText:ser];
                }
                
                [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                
                // Set the interface
                [_dptFld setText:dpt];
                [_itmFld setText:itm];
                [_clsFld setText:cls];
                [_gtinFld setText:@""];
                
                // Show DPCI
                [self.view bringSubviewToFront:_dptLbl];
                [self.view bringSubviewToFront:_clsLbl];
                [self.view bringSubviewToFront:_itmLbl];
                [self.view bringSubviewToFront:_dptFld];
                [self.view bringSubviewToFront:_clsFld];
                [self.view bringSubviewToFront:_itmFld];
                
                // Hide GTIN
                [self.view sendSubviewToBack:_gtinLbl];
                [self.view sendSubviewToBack:_gtinFld];
                
                _barcodeFound = TRUE;
            }
            
            // For replacement tags, encode any National brand GTINs in our custom GID format
            else if (_replaceSwt.on == TRUE && ((barcode.length == 12) || (barcode.length == 14))) {
                // Take the gtin and encode a reference
                NSString *gtin = barcode;
                NSString *ser  = ([_serFld.text length])?[_serFld text]:@"0";
                
                // This is a replacement tag, check the commissioning authority
                // GID serial numbers are 10 digits long
                for (int i=(int)[ser length]; i<10; i++) {
                    ser = [NSString stringWithFormat:@"0%@", ser];
                }
                
                // Make sure it starts with 01, 02, 03, 04
                if (!([[ser substringToIndex:2] isEqualToString:@"01"] ||
                      [[ser substringToIndex:2] isEqualToString:@"02"] ||
                      [[ser substringToIndex:2] isEqualToString:@"03"] ||
                      [[ser substringToIndex:2] isEqualToString:@"04"])) {
                    ser = [NSString stringWithFormat:@"01%@", [ser substringFromIndex:2]];
                }
                [_serFld setText:ser];
                
                [_encode gidWithGTIN:gtin ser:ser];
                    
                // Set the interface
                [_gtinFld setText:barcode];
                [_dptFld setText:@""];
                [_clsFld setText:@""];
                [_itmFld setText:@""];
                
                // Show GTIN
                [self.view bringSubviewToFront:_gtinLbl];
                [self.view bringSubviewToFront:_gtinFld];
                
                // Hide DPCI
                [self.view sendSubviewToBack:_dptLbl];
                [self.view sendSubviewToBack:_clsLbl];
                [self.view sendSubviewToBack:_itmLbl];
                [self.view sendSubviewToBack:_dptFld];
                [self.view sendSubviewToBack:_clsFld];
                [self.view sendSubviewToBack:_itmFld];
                
                _barcodeFound = TRUE;
            }
            
            // National brand, encode GTIN in an SGTIN
            else if ((barcode.length == 12) || (barcode.length == 14)) {
                // Take the gtin and encode a reference
                NSString *gtin = barcode;
                NSString *ser  = ([_serFld.text length])?[_serFld text]:@"0";
                
                [_encode withGTIN:gtin ser:ser partBin:@"101"];
                
                // Set the interface
                [_gtinFld setText:barcode];
                [_dptFld setText:@""];
                [_clsFld setText:@""];
                [_itmFld setText:@""];
                
                // Show GTIN
                [self.view bringSubviewToFront:_gtinLbl];
                [self.view bringSubviewToFront:_gtinFld];
                
                // Hide DPCI
                [self.view sendSubviewToBack:_dptLbl];
                [self.view sendSubviewToBack:_clsLbl];
                [self.view sendSubviewToBack:_itmLbl];
                [self.view sendSubviewToBack:_dptFld];
                [self.view sendSubviewToBack:_clsFld];
                [self.view sendSubviewToBack:_itmFld];
                
                _barcodeFound = TRUE;
            }
            
            // Unsupported barcode
            else {
                
                _barcodeLbl.text = @"Barcode: unsupported barcode";
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
                _barcodeFound = FALSE;
            }
        }
        
        // Still scanning for barcodes
        else {
            _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
            _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
            _barcodeFound = FALSE;
        }
    }
    
    _highlightView.frame = highlightViewRect;
    
    // Check to see if ready to encode
    [self readyToEncode];
}

// Text field delegates
#pragma mark - Text Fields

/*!
 * @discussion Delegate to dimiss keyboard after return.
 * Set the delegate of any input text field to the ViewController class
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

/*!
 * @discussion Update the interface - All the edit fields point here, after you end the edit and hit return.
 */
- (IBAction)update:(id)sender {
    // New input data
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    [self updateAll];
}

/*!
 * @discussion Update all elements for any input change.  Check input and check ready to encode.
 */
- (void)updateAll {
    NSString *dpt  = [_dptFld text];
    NSString *cls  = [_clsFld text];
    NSString *itm  = [_itmFld text];
    NSString *ser  = [_serFld text];
    NSString *gtin = [_gtinFld text];
    
    // Make sure the inputs are not too long (especially the Serial Number)
    if ([dpt length] > 3) {
        dpt = [dpt substringToIndex:3];
        [_dptFld setText:dpt];
    }
    if ([cls length] > 2) {
        cls = [cls substringToIndex:2];
        [_clsFld setText:cls];
    }
    if ([itm length] > 4) {
        itm = [itm substringToIndex:4];
        [_itmFld setText:itm];
    }
    if ([ser length] > 10) {
        // GID serial number max = 10
        ser = [ser substringToIndex:10];
        [_serFld setText:ser];
    }
    if ([gtin length] > 14) {
        gtin = [gtin substringToIndex:14];
        [_gtinFld setText:gtin];
    }
    
    if ([dpt length] > 0 && [cls length] > 0 && [itm length] > 0 && [ser length] > 0) {
        // If this is a replacement tag, check the commissioning authority
        if (_replaceSwt.on == TRUE) {
            for (int i=(int)[ser length]; i<10; i++) {
                ser = [NSString stringWithFormat:@"0%@", ser];
            }
            
            // Make sure it starts with 01, 02, 03, 04
            if (!([[ser substringToIndex:2] isEqualToString:@"01"] ||
                  [[ser substringToIndex:2] isEqualToString:@"02"] ||
                  [[ser substringToIndex:2] isEqualToString:@"03"] ||
                  [[ser substringToIndex:2] isEqualToString:@"04"])) {
                ser = [NSString stringWithFormat:@"01%@", [ser substringFromIndex:2]];
            }
            [_serFld setText:ser];
        }
        
        // Update the EPCEncoder object
        [_encode withDpt:dpt cls:cls itm:itm ser:ser];
        
        if ([dpt length] == 3 && [cls length] == 2 && [itm length] == 4) {
            // Build the barcode
            NSString *barcode = [NSString stringWithFormat:@"49%@%@%@",dpt,cls,itm];
            NSString *chkdgt = [_encode calculateCheckDigit:barcode];
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@%@", barcode, chkdgt];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
            
            // Hide GTIN
            [self.view sendSubviewToBack:_gtinLbl];
            [self.view sendSubviewToBack:_gtinFld];
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid DPCI)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
        }
    }
    
    // For replacement tags, encode any National brand GTINs in our custom GID format
    else if (_replaceSwt.on == TRUE && ([ser length] > 0 && [gtin length] > 0)) {
        
        // This is a replacement tag, check the commissioning authority
        // GID serial numbers are 10 digits long
        for (int i=(int)[ser length]; i<10; i++) {
            ser = [NSString stringWithFormat:@"0%@", ser];
        }
        
        // Make sure it starts with 01, 02, 03, 04
        if (!([[ser substringToIndex:2] isEqualToString:@"01"] ||
              [[ser substringToIndex:2] isEqualToString:@"02"] ||
              [[ser substringToIndex:2] isEqualToString:@"03"] ||
              [[ser substringToIndex:2] isEqualToString:@"04"])) {
            ser = [NSString stringWithFormat:@"01%@", [ser substringFromIndex:2]];
        }
        [_serFld setText:ser];
        
        // Update the EPCEncoder object
        [_encode gidWithGTIN:gtin ser:ser];
        
        if ([gtin length] == 14 || [gtin length] == 12) {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", gtin];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
            
            // Hide DPCI
            [self.view sendSubviewToBack:_dptLbl];
            [self.view sendSubviewToBack:_clsLbl];
            [self.view sendSubviewToBack:_itmLbl];
            [self.view sendSubviewToBack:_dptFld];
            [self.view sendSubviewToBack:_clsFld];
            [self.view sendSubviewToBack:_itmFld];
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid GTIN)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
        }
        
        _barcodeFound = TRUE;
    }
    else if ([ser length] > 0 && [gtin length] > 0) {
        // Update the EPCEncoder object
        [_encode withGTIN:gtin ser:ser partBin:@"101"];
        
        if ([gtin length] == 14 || [gtin length] == 12) {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", gtin];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
            
            // Hide DPCI
            [self.view sendSubviewToBack:_dptLbl];
            [self.view sendSubviewToBack:_clsLbl];
            [self.view sendSubviewToBack:_itmLbl];
            [self.view sendSubviewToBack:_dptFld];
            [self.view sendSubviewToBack:_clsFld];
            [self.view sendSubviewToBack:_itmFld];
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid GTIN)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
        }
    }
    else {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
        _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _barcodeFound = FALSE;
    }
    
    // Set the background color
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    // Check to see if ready to encode
    [self readyToEncode];
}

// Encode
#pragma mark - Encode

/*!
 * @discussion Check for ready to encode - Enable the encode button if all input ready.
 */
- (void)readyToEncode {
    // If we have a valid barcode and an RFID tag read, we are ready to encode so enable the encode button
    _encodeBtn.enabled = (_barcodeFound && _rfidFound);
}

/*!
 * @discussion Encode handler - Prepare to encode.
 * @param sender The ID of the sender object (not used)
 */
- (IBAction)encode:(id)sender {
    _encoding = TRUE;
    
    // New encoding attempt
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;

    NSString *ser  = [_serFld text];
    NSString *gtin = [_gtinFld text];
    
    [self beginEncode:([ser length] > 0 && [gtin length] > 0 && _replaceSwt.on == FALSE)?[_encode sgtin_hex]:[_encode gid_hex]];
}

/*!
 * @discussion Begin the encoding process.
 * @param hex The new tag number to encode (hex)
 */
- (void)beginEncode:(NSString *)hex {
    [_newEPC setString:hex];
    
    if ([_oldEPC length] == 0) {
        // The only way we got here is after a successful tag read, otherwise the encode button wouldn't be active
        // so this code block really should never be hit, and we should know which reader...
        if (_ugiReaderConnected) {
            // No reader, no encoding
            if (![[Ugi singleton] isAnythingPluggedIntoAudioJack]) return;
            if (![[Ugi singleton] inOpenConnection]) return;
        
            // Start scanning for RFID tags - when a tag is found, the inventoryTagFound delegate will be called
            [[Ugi singleton] startInventory:self withConfiguration:_ugiConfig];
        }
        else if (_zebraReaderConnected) {
            [self zebraRapidRead];
        }
    }
    else {
        [self endEncode:_oldEPC];
    }
}

/*!
 * @discussion End the encoding process.
 * @param hex The Old EPC (will be replaced)
 */
-(void)endEncode:(NSString *)hex {
    [_oldEPC setString:hex];
    
    if ([_newEPC length] == 0) return;
    
    // Assume failure (many ways to fail)
    _tagEncoded = FALSE;
    
    // Encode it with the new number
    // uGrokit Reader
    if (_ugiReaderConnected) {
        
        // Set the programming inputs
        UgiEpc *oldEpc = [UgiEpc epcFromString:_oldEPC];
        UgiEpc *newEpc = [UgiEpc epcFromString:_newEPC];
        
        [[Ugi singleton].activeInventory programTag:oldEpc
                                              toEpc:newEpc
                                       withPassword:UGI_NO_PASSWORD
                                      whenCompleted:^(UgiTag *tag, UgiTagAccessReturnValues result) {
                                          if (result == UGI_TAG_ACCESS_OK) {
                                              // Tag programmed successfully
                                              NSLog(@"Tag programmed successfully\n");
                                              [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
                                              _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _newEPC];
                                              _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                                              
                                              // Increment the serial number for another run and update
                                              NSInteger serInt = [[_serFld text] intValue];
                                              [_serFld setText:[NSString stringWithFormat:@"%d", (int)(++serInt)]];
                                              [self updateAll];
                                              _successImg.hidden = FALSE;
                                              _tagEncoded = TRUE;
                                          }
                                          else {
                                              // Tag programming was unsuccessful
                                              NSLog(@"Tag programming UNSUCCESSFUL\n");
                                              [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
                                              _failImg.hidden = FALSE;
                                          }
                                          // Stop the RFID reader
                                          [[Ugi singleton].activeInventory stopInventory];
                                          
                                          // Update the battery life
                                          UgiBatteryInfo batteryInfo;
                                          if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
                                              _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
                                              _batteryLifeLbl.backgroundColor =
                                              (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
                                              (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
                                                                                  UIColorFromRGB(0xCC0000);
                                              _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
                                          }
                                      }];
    }
    
    // Zebra reader
    if (_zebraReaderConnected) {
        // Allocate object for storing results of access operation
        srfidTagData *access_result = [[srfidTagData alloc] init];
        
        // An object for storage of error response received from RFID reader
        NSString *error_response = nil;
        
        // Write _newEPC to the EPC memory bank of a tag specified by _oldEPC
        SRFID_RESULT result = [_rfidSdkApi srfidWriteTag:_readerID
                                                  aTagID:_oldEPC
                                          aAccessTagData:&access_result
                                             aMemoryBank:SRFID_MEMORYBANK_EPC
                                                 aOffset:2                      // Not sure where 2 came from....
                                                   aData:_newEPC
                                               aPassword:0x00
                                           aDoBlockWrite:NO
                                          aStatusMessage:&error_response];
        
        if (SRFID_RESULT_SUCCESS == result) {
            // Check result code of access operation
            if (NO == [access_result getOperationSucceed]) {
                NSLog(@"Tag programming UNSUCCESSFUL with error: %@\n", [access_result getOperationStatus]);
                [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
                _failImg.hidden = FALSE;
            }
            else {
                NSLog(@"Tag programmed successfully\n");
                [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
                _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _newEPC];
                _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                
                // Increment the serial number for another run and update
                NSInteger serInt = [[_serFld text] intValue];
                [_serFld setText:[NSString stringWithFormat:@"%d", (int)(++serInt)]];
                [self updateAll];
                _successImg.hidden = FALSE;
                _tagEncoded = TRUE;
            }
        }
        else if (SRFID_RESULT_RESPONSE_ERROR == result) {
            NSLog(@"Tag programming UNSUCCESSFUL with error response from RFID reader: %@\n", error_response);
            [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
            _failImg.hidden = FALSE;
        }
        else if (SRFID_RESULT_RESPONSE_TIMEOUT == result) {
            NSLog(@"Tag programming UNSUCCESSFUL: Timeout occurred\n");
            [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
            _failImg.hidden = FALSE;
        }
        else {
            NSLog(@"Tag programming UNSUCCESSFUL: Request failed\n");
            [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
            _failImg.hidden = FALSE;
        }
    }
    
    // If our work is done
    if (_tagEncoded) [_oldEPC setString:@""];
}

// uGrokit RFID Reader
#pragma mark - uGrokit Delegates

/*!
 * @discussion New tag found with uGrokit reader.
 * Display the tag, stop the reader and check if ready to encode.
 * @param tag The RFID tag
 * @param detailedPerReadData The detailed data about the RFID tag
 */
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // Tag was found for the first time
    
    // New input data
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    // Set the old EPC
    [_oldEPC setString:[tag.epc toString]];

    // Get the RFID tag
    _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _oldEPC];
    _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
       
    // After the first read, we know which reader
    _rfidFound = TRUE;
    if (!_ugiReaderConnected) {
        [_rfidSdkApi srfidStopRapidRead:_readerID aStatusMessage:nil];
        [_rfidSdkApi srfidTerminateCommunicationSession:_readerID];
    }
    _ugiReaderConnected = TRUE;
    _zebraReaderConnected = FALSE;
    
    if (_encoding) {
        [self endEncode:_oldEPC];
        _encoding = FALSE;
    }
    else {
        _rfidFound = TRUE;
        
        // Check to see if ready to encode
        [self readyToEncode];
    }
    
    // Log the read tag
    NSLog(@"\nRFID tag read: %@\n", _oldEPC);
}

/*!
 * @discussion State changed with uGrokit reader - Adjust to the new state.
 * Listen for one of the following:
 *    UGI_CONNECTION_STATE_NOT_CONNECTED -          Nothing connected to audio port
 *    UGI_CONNECTION_STATE_CONNECTING -             Something connected to audio port, trying to connect
 *    UGI_CONNECTION_STATE_INCOMPATIBLE_READER -    Connected to an reader with incompatible firmware
 *    UGI_CONNECTION_STATE_CONNECTED -              Connected to reader
 * @param notification The notification info
 */
- (void)connectionStateChanged:(NSNotification *) notification {
    NSNumber *n = notification.object;
    UgiConnectionStates connectionState = n.intValue;
    if (connectionState == UGI_CONNECTION_STATE_CONNECTED) {
        // Update the battery life with a new connection before starting an inventory
        UgiBatteryInfo batteryInfo;
        if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
            _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
            _batteryLifeLbl.backgroundColor =
            (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
            (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
                                                UIColorFromRGB(0xCC0000);
            
            _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
        }
        
        // Start scanning for RFID tags - when a tag is found, the inventoryTagFound delegate will be called
        _rfidLbl.text = @"RFID: (scanning for tags)";
        [[Ugi singleton] startInventory:self withConfiguration:_ugiConfig];
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_CONNECTING) {
        _rfidLbl.text = @"RFID: (connecting to reader)";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC9900);
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_INCOMPATIBLE_READER) {
        // With no reader, just ignore the RFID reads
        _rfidLbl.text = @"RFID: (no compatible reader)";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _batteryLifeView.progress = 0.;
        _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeLbl.text = @"RFID Battery Life";
        _rfidFound = FALSE;
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_NOT_CONNECTED ) {
        // Reader not connected, just ignore the RFID reads
        _rfidLbl.text = @"RFID: (reader not connected)";
        _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeView.progress = 0.;
        _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeLbl.text = @"RFID Battery Life";
        _rfidFound = FALSE;
        return;
    }
}

// Zebra RFID Reader
#pragma mark - Zebra Delegates

/*!
 * @discussion Zebra reader appeared - Adjust to the new state.
 * @param availableReader Reader info about the newly appeared reader
 */
- (void)srfidEventReaderAppeared:(srfidReaderInfo*)availableReader
{
    NSLog(@"Zebra Reader Appeared - Name: %@", [availableReader getReaderName]);
    
    [_rfidSdkApi srfidEstablishCommunicationSession:[availableReader getReaderID]];
}

/*!
 * @discussion Zebra reader communication established - Start reading
 * @param activeReader Reader info for the active reader
 */
- (void)srfidEventCommunicationSessionEstablished:(srfidReaderInfo*)activeReader
{
    NSLog(@"Zebra Communication Established - Name: %@", [activeReader getReaderName]);
    
    // Set the volume
    NSString *statusMessage = nil;
    [_rfidSdkApi srfidSetBeeperConfig:[activeReader getReaderID] aBeeperConfig:SRFID_BEEPERCONFIG_LOW aStatusMessage:&statusMessage];
    
    // Set the reader
    _readerID = [activeReader getReaderID];
    
    // Establish ASCII connection
    if ([_rfidSdkApi srfidEstablishAsciiConnection:_readerID aPassword:nil] == SRFID_RESULT_SUCCESS)
    {
        // Success, now read tags
        [self zebraRapidRead];
    }
    else
    {
        // Error, alert
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"Zebra Error"
                              message:@"Failed to establish connection with Zebra RFID reader"
                              delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           [alert show];
                       });
        
        // Terminate sesssion
        [_rfidSdkApi srfidTerminateCommunicationSession:_readerID];
        _readerID = -1;
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _rfidLbl.text = @"RFID: Zebra connection failed";
    }
}

/*!
 * @discussion New tag found with Zebra reader
 * Display the tag, stop the reader, disable the other readers, and check for a match.
 * @param readerID The ID of the reader
 * @param aTagData The data in the RFID tag
 */
- (void)srfidEventReadNotify:(int)readerID aTagData:(srfidTagData*)tagData
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       // tag was found for the first time

                       // Stop the RFID reader
                       [_rfidSdkApi srfidStopRapidRead:readerID aStatusMessage:nil];
                       
                       // New input data
                       _successImg.hidden = TRUE;
                       _failImg.hidden = TRUE;
                       
                       // Set the old EPC
                       [_oldEPC setString:[tagData getTagId]];
                       
                       // Get the RFID tag
                       _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _oldEPC];
                       _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                       
                       // After the first read, we know which reader
                       _rfidFound = TRUE;
                       if (!_zebraReaderConnected) {
                           [[Ugi singleton].activeInventory stopInventory];
                           [[Ugi singleton] closeConnection];
                       }
                       _ugiReaderConnected = FALSE;
                       _zebraReaderConnected = TRUE;
                       
                       if (_encoding) {
                           [self endEncode:_oldEPC];
                           _encoding = FALSE;
                       }
                       else {
                           _rfidFound = TRUE;
                           
                           // Check to see if ready to encode
                           [self readyToEncode];
                       }
                       
                       // Log the read tag
                       NSLog(@"\nRFID tag read: %@\n", _oldEPC);
                   });
}

/*!
 * @discussion Set the battery life of the Zebra reader.
 * @warning This delegate is called at random intervals (Stochastic baby!), or can be prompted by the SDK
 */
- (void)srfidEventBatteryNotity:(int)readerID aBatteryEvent:(srfidBatteryEvent*)batteryEvent
{
    // Thread is unknown
    NSLog(@"\nbatteryEvent: level = [%d] charging = [%d] cause = (%@)\n", [batteryEvent getPowerLevel], [batteryEvent getIsCharging], [batteryEvent getEventCause]);
    
    int battery = [batteryEvent getPowerLevel];
    
    if(battery > 100) battery = 100;
    else if(battery < 0) battery = 0;
    
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       _batteryLifeView.progress = battery/100.;
                       _batteryLifeLbl.backgroundColor =
                       (battery > 20)?UIColorFromRGB(0xA4CD39):
                       (battery > 5 )?UIColorFromRGB(0xCC9900):
                       UIColorFromRGB(0xCC0000);
                       
                       _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%\n", battery];
                   });
}

/**
 None of these are really needed
 */
- (void)srfidEventReaderDisappeared:(int)readerID
{
    NSLog(@"Zebra Reader Disappeared - ID: %d\n", readerID);
}
- (void)srfidEventCommunicationSessionTerminated:(int)readerID
{
    NSLog(@"Zebra Reader Session Terminated - ID: %d\n", readerID);
}
- (void)srfidEventStatusNotify:(int)readerID aEvent:(SRFID_EVENT_STATUS)event aNotification:(id)notificationData
{
    NSLog(@"Zebra Reader - Event status notify: %d\n", event);
}
- (void)srfidEventProximityNotify:(int)readerID aProximityPercent:(int)proximityPercent
{
    NSLog(@"Zebra Reader - Event proximity nofity percent: %d\n", proximityPercent);
}
- (void)srfidEventTriggerNotify:(int)readerID aTriggerEvent:(SRFID_TRIGGEREVENT)triggerEvent
{
    NSLog(@"Zebra Reader - Event trigger notify: %@\n", ((triggerEvent == SRFID_TRIGGEREVENT_PRESSED)?@"Pressed":@"Released"));
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
