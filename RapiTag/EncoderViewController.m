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
//  Zebra RFID scanner code from:
//  http://compass.motorolasolutions.com

#import "EncoderViewController.h"
#import <AVFoundation/AVFoundation.h> // Barcode capture tools
#import <RFIDEncoder/EPCEncoder.h>    // To encode EPCs (GS1 compliant)
#import <RFIDEncoder/TCINEncoder.h>   // To encode TCINs (Target internal)
#import <RFIDEncoder/TIAIEncoder.h>   // To encode TIAIs (Non-Retail, Target internal)
#import <RFIDEncoder/Converter.h>     // To convert to binary
#import "RfidSdkFactory.h"            // Zebra reader

@interface EncoderViewController ()<AVCaptureMetadataOutputObjectsDelegate, srfidISdkApiDelegate>
{
    __weak IBOutlet UILabel             *_gtinLbl;
    __weak IBOutlet UILabel             *_tcinLbl;
    __weak IBOutlet UILabel             *_dptLbl;
    __weak IBOutlet UILabel             *_clsLbl;
    __weak IBOutlet UILabel             *_itmLbl;
    __weak IBOutlet UILabel             *_serLbl;
    __weak IBOutlet UILabel             *_tiaiLbl;
    __weak IBOutlet UILabel             *_aidLbl;
    __weak IBOutlet UITextField         *_gtinFld;
    __weak IBOutlet UITextField         *_tcinFld;
    __weak IBOutlet UITextField         *_dptFld;
    __weak IBOutlet UITextField         *_clsFld;
    __weak IBOutlet UITextField         *_itmFld;
    __weak IBOutlet UITextField         *_serFld;
    __weak IBOutlet UITextField         *_tiaiFld;
    __weak IBOutlet UITextField         *_aidFld;
    __weak IBOutlet UIBarButtonItem     *_resetBtn;
    __weak IBOutlet UIBarButtonItem     *_encodeBtn;
    __weak IBOutlet UIImageView         *_successImg;
    __weak IBOutlet UIImageView         *_failImg;
    __weak IBOutlet UISwitch            *_scanScanEncodeSwt;
    __weak IBOutlet UISwitch            *_replaceSwt;
    __weak IBOutlet UISwitch            *_tcinSwt;
    __weak IBOutlet UISwitch            *_tiaiSwt;
    __weak IBOutlet UISegmentedControl  *_tiaiTypeSel;
    __weak IBOutlet UILabel             *_versionLbl;
    
    BOOL                                _barcodeFound;
    BOOL                                _rfidFound;
    BOOL                                _encoding;
    BOOL                                _tagEncoded;
    NSMutableString                     *_oldEPC;
    NSMutableString                     *_newEPC;
    NSMutableString                     *_lastDetectionString;
    UIColor                             *_defaultBackgroundColor;
    
    AVCaptureSession                    *_session;
    AVCaptureDevice                     *_device;
    AVCaptureDeviceInput                *_input;
    AVCaptureMetadataOutput             *_output;
    AVCaptureVideoPreviewLayer          *_prevLayer;
    
    UIView                              *_highlightView;
    UILabel                             *_barcodeLbl;
    UILabel                             *_rfidLbl;
    UILabel                             *_batteryLifeLbl;
    UIProgressView                      *_batteryLifeView;
    
    EPCEncoder                          *_encodeEPC;
    TCINEncoder                         *_encodeTCIN;
    TIAIEncoder                         *_encodeTIAI;
    Converter                           *_convert;
    
    id <srfidISdkApi>                   _rfidSdkApi;
    int                                 _zebraReaderID;
    srfidStartTriggerConfig             *_startTriggerConfig;
    srfidStopTriggerConfig              *_stopTriggerConfig;
    srfidReportConfig                   *_reportConfig;
    srfidAccessConfig                   *_accessConfig;
    srfidDynamicPowerConfig             *_dpoConfig;            // Only for writing tags
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
    _encodeEPC = [EPCEncoder alloc];
    _encodeTCIN = [TCINEncoder alloc];
    _encodeTIAI = [TIAIEncoder alloc];
    _convert = [Converter alloc];
    _oldEPC = [[NSMutableString alloc] init];
    _newEPC = [[NSMutableString alloc] init];
    _lastDetectionString = [[NSMutableString alloc] init];
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _defaultBackgroundColor = UIColorFromRGB(0x000000);
    
    // Set the label background colors
    _gtinLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _tcinLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _dptLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _clsLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _itmLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _serLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _tiaiLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _aidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
// TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
// the settings programatically, so I've continued with that here...
    
    // Barcode highlight view
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor redColor].CGColor;
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
    _batteryLifeView.frame = CGRectMake(0, self.view.bounds.size.height - 35, self.view.bounds.size.width, 40);
    _batteryLifeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeView.progressTintColor = [UIColor whiteColor];
    _batteryLifeView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view addSubview:_batteryLifeView];
    
    // Version label
    _versionLbl.text = [NSString stringWithFormat:@"Version: %@",
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
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
    _zebraReaderID = -1;
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
 * @param sender The ID of the sender object
 */
- (IBAction)reset:(id)sender {
    // Reset all controls and variables
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _encodeBtn.enabled = FALSE;
    _encoding = FALSE;
    [_oldEPC setString:@""];
    [_newEPC setString:@""];
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    _gtinFld.text = @"";
    _tcinFld.text = @"";
    _dptFld.text = @"";
    _clsFld.text = @"";
    _itmFld.text = @"";
    _aidFld.text = @"";
    
    _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.text = @"RFID Battery Life";
    _batteryLifeView.progress = 0.;
    
    // Set up controls depending on mode - start by hiding everything
    [self.view sendSubviewToBack:_gtinLbl];
    [self.view sendSubviewToBack:_gtinFld];
    [self.view sendSubviewToBack:_tcinLbl];
    [self.view sendSubviewToBack:_tcinFld];
    [self.view sendSubviewToBack:_dptLbl];
    [self.view sendSubviewToBack:_dptFld];
    [self.view sendSubviewToBack:_clsLbl];
    [self.view sendSubviewToBack:_clsFld];
    [self.view sendSubviewToBack:_itmLbl];
    [self.view sendSubviewToBack:_itmFld];
    [self.view sendSubviewToBack:_serLbl];
    [self.view sendSubviewToBack:_serFld];
    [self.view sendSubviewToBack:_tiaiLbl];
    [self.view sendSubviewToBack:_tiaiFld];
    [self.view sendSubviewToBack:_aidLbl];
    [self.view sendSubviewToBack:_aidFld];
    [self.view sendSubviewToBack:_tiaiTypeSel];
    
    // By defaiult, enable the serial field
    [_serFld setEnabled:true];
    [_serFld setUserInteractionEnabled:true];
    
    // TCIN
    if (((sender == _tcinSwt) ||
         (sender == _scanScanEncodeSwt) ||
         (sender == _resetBtn)) &&
         _tcinSwt.on) {
        
        // Bring the TCIN input views to the front
        [self.view bringSubviewToFront:_tcinLbl];
        [self.view bringSubviewToFront:_tcinFld];
        [self.view bringSubviewToFront:_serLbl];
        [self.view bringSubviewToFront:_serFld];
        
        // Disable the serial field (auto generated)
        [_serFld setEnabled:false];
        [_serFld setUserInteractionEnabled:false];
        
        // Toggle mutually exclusive states
        [_replaceSwt setOn:false];
        [_tiaiSwt setOn:false];
    }
    // TIAI
    else if (((sender == _tiaiSwt) ||
              (sender == _scanScanEncodeSwt) ||
              (sender == _resetBtn)) &&
             _tiaiSwt.on) {
        
        // Bring the TIAI input views to the front
        [self.view bringSubviewToFront:_tiaiLbl];
        [self.view bringSubviewToFront:_tiaiFld];
        [self.view bringSubviewToFront:_aidLbl];
        [self.view bringSubviewToFront:_aidFld];
        [self.view bringSubviewToFront:_tiaiTypeSel];
        
        // Toggle mutually exclusive states
        [_replaceSwt setOn:false];
        [_tcinSwt setOn:false];
    }
    // Everything else
    else {
        
        // Bring the default input views to the front
        [self.view bringSubviewToFront:_gtinLbl];
        [self.view bringSubviewToFront:_gtinFld];
        [self.view bringSubviewToFront:_dptLbl];
        [self.view bringSubviewToFront:_dptFld];
        [self.view bringSubviewToFront:_clsLbl];
        [self.view bringSubviewToFront:_clsFld];
        [self.view bringSubviewToFront:_itmLbl];
        [self.view bringSubviewToFront:_itmFld];
        [self.view bringSubviewToFront:_serLbl];
        [self.view bringSubviewToFront:_serFld];
        
        // Toggle mutually exclusive states
        [_tcinSwt setOn:false];
        [_tcinSwt setOn:false];
    }
    
    // Hide the result images (treat these different for landscape mode)
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    // If scanScanEncode is enabled, reset these differently
    if (_scanScanEncodeSwt.on == TRUE) {
        // DON'T reset these controls and variables
//        _tagEncoded = FALSE;                  // Set only in endEncode
//        [_lastDetectionString setString:@""]; // Read a barcode only once in captureOutput - must read a different barcode each time
//        _serFld.text = @"1";                  // Incremented after successful tag write
//        _tiaiFld.text = @"";                  // Reuse the Asset Ref
        
        // Scanning for labels
        _rfidLbl.text = @"RFID: (scanning for labels)";
        
        // We don't read tags in scan scan encode mode
        
        // Update the battery life
        if (_zebraReaderID > 0) {
            [_rfidSdkApi srfidRequestBatteryStatus:_zebraReaderID];
        }
    }
    
    // Regular reset, scan for a tag
    else {
        // Reset these additional controls and variables
        _tagEncoded = FALSE;
        [_lastDetectionString setString:@""];
        _serFld.text = (_tcinSwt.on)?@"":@"1";
        _tiaiFld.text = @"";
        
        // Scanning for tags
        _rfidLbl.text = @"RFID: (connecting to reader)";
        
        // If no connection open, open it now and start scanning for RFID tags
        [_rfidSdkApi srfidStopRapidRead:_zebraReaderID aStatusMessage:nil];
        [_rfidSdkApi srfidTerminateCommunicationSession:_zebraReaderID];
        _zebraReaderID = -1;
        [self zebraRapidRead];
        
        // Asking for RFID scans triggers battery life updates, so no need to do that here
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
    if (_zebraReaderID < 0) {
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
    else if (_scanScanEncodeSwt.on == TRUE) {
        [_rfidSdkApi srfidRequestBatteryStatus:_zebraReaderID];
        
        // Don't read RFID tags in scan scan encode mode, set the label and scan for barcode labels
        _rfidLbl.text = @"RFID: (scanning for labels)";
        _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    }
    else {
        [_rfidSdkApi srfidRequestBatteryStatus:_zebraReaderID];
        
        NSString *error_response = nil;
        
        do {
            // Set start trigger parameters
            SRFID_RESULT result = [_rfidSdkApi srfidSetStartTriggerConfiguration:_zebraReaderID
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
            result = [_rfidSdkApi srfidSetStopTriggerConfiguration:_zebraReaderID
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
            result  = [_rfidSdkApi srfidSetDpoConfiguration:_zebraReaderID
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
            result = [_rfidSdkApi srfidStartRapidRead:_zebraReaderID
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
                    [self->_rfidSdkApi srfidStopRapidRead:self->_zebraReaderID aStatusMessage:nil];
                });
            }
            else if (SRFID_RESULT_RESPONSE_ERROR == result) {
                NSLog(@"Zebra Error response from RFID reader: %@\n", error_response);
            }
            else {
                NSLog(@"Zebra Request failed\n");
            }
        } while (0); // Only do this once, but break on any errors (Objective-C GO TO :)
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
    NSString *type;
    
// TPM don't check all barcode types, but these are the ones iOS supports.
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode,
//                              AVMetadataObjectTypeCode39Code,
//                              AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code,
                              AVMetadataObjectTypeEAN8Code,
//                              AVMetadataObjectTypeCode93Code,
                              AVMetadataObjectTypeCode128Code, // Alphanumeric
//                              AVMetadataObjectTypePDF417Code,
//                              AVMetadataObjectTypeQRCode,
                              AVMetadataObjectTypeAztecCode,    // Session config options
//                              AVMetadataObjectTypeInterleaved2of5Code,
//                              AVMetadataObjectTypeITF14Code,
                              AVMetadataObjectTypeDataMatrixCode // Avery and Checkpoint tags
                              ];
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        // Update before returning
        _highlightView.frame = highlightViewRect;
        
        if (detectionString != nil) {
            // Don't keep processing the same barcode
            if ([_lastDetectionString isEqualToString:detectionString]) return;
            [_lastDetectionString setString:detectionString];
            
            // Check for a session configuration barcode
            if (type == AVMetadataObjectTypeAztecCode){
                [self configureSettings:detectionString];
                return;
            }
            
            // New input data
            _successImg.hidden = TRUE;
            _failImg.hidden = TRUE;
            
            // Scan scan barcodes (might not need to check for length)
            if ((type == AVMetadataObjectTypeDataMatrixCode && detectionString.length == 24) ||
                (type == AVMetadataObjectTypeCode128Code    && detectionString.length == 17) ){
                
                // New input data
                
                // Set the old EPC
                [_oldEPC setString:detectionString];
                
                // Get the RFID tag
                _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _oldEPC];
                _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                _rfidFound = TRUE;
                
                // With a Data Matrix barcode scan, stop the RFID reader
                [_rfidSdkApi srfidStopRapidRead:_zebraReaderID aStatusMessage:nil];
                
                // Log the read barcode
                NSLog(@"\nData Matrix label read: %@\n", _oldEPC);
            }
            
            // TCIN
            else if (_tcinSwt.on) {
                // Assume false until verified
                _barcodeFound = FALSE;
                
                // The barcode is the TCIN
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                NSString *tcin;
                tcin = detectionString;
                
                NSString *ser = [_serFld text];
                
                _barcodeFound = [self updateTCIN:tcin withSer:ser];
                
                // Log the read barcode
                NSLog(@"\nBar code read: %@\n", tcin);
            }
            
            // TIAI
            else if (_tiaiSwt.on) {
                // Assume false until verified
                _barcodeFound = FALSE;
                
                NSString *tiai = [_tiaiFld text];
                
                // The barcode is the Asset ID
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                NSString *aid;
                aid = detectionString;
                
                _barcodeFound = [self updateTIAI:tiai withAID:aid];
                
                // Log the read barcode
                NSLog(@"\nBar code read: %@\n", aid);
            }
            
            // All the rest are UPC or EAN barcodes
            else {
                // Assume false until verified
                _barcodeFound = FALSE;
                
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
                    
                    [_encodeEPC withDpt:dpt cls:cls itm:itm ser:ser];
                    
                    // Set the interface
                    [_dptFld setText:dpt];
                    [_itmFld setText:itm];
                    [_clsFld setText:cls];
                    [_gtinFld setText:@""];
                    
                    // Show DPCI
                    [self.view bringSubviewToFront:_dptLbl];
                    [self.view bringSubviewToFront:_dptFld];
                    [self.view bringSubviewToFront:_clsLbl];
                    [self.view bringSubviewToFront:_clsFld];
                    [self.view bringSubviewToFront:_itmLbl];
                    [self.view bringSubviewToFront:_itmFld];
                    
                    // Hide the rest
                    [self.view sendSubviewToBack:_gtinLbl];
                    [self.view sendSubviewToBack:_gtinFld];
                    
                    _barcodeFound = TRUE;
                    
                    // Log the read barcode
                    NSLog(@"\nBar code read: %@\n", barcode);
                }
                
                // For replacement tags, encode any National brand GTINs in our custom GID format
                else if (_replaceSwt.on && ((barcode.length == 12) || (barcode.length == 14))) {
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
                    
                    [_encodeEPC gidWithGTIN:gtin ser:ser];
                    
                    // Set the interface
                    [_gtinFld setText:barcode];
                    [_dptFld setText:@""];
                    [_clsFld setText:@""];
                    [_itmFld setText:@""];
                    
                    // Show GTIN
                    [self.view bringSubviewToFront:_gtinLbl];
                    [self.view bringSubviewToFront:_gtinFld];
                    
                    // Hide the rest
                    [self.view sendSubviewToBack:_dptLbl];
                    [self.view sendSubviewToBack:_dptFld];
                    [self.view sendSubviewToBack:_clsLbl];
                    [self.view sendSubviewToBack:_clsFld];
                    [self.view sendSubviewToBack:_itmLbl];
                    [self.view sendSubviewToBack:_itmFld];
                    
                    _barcodeFound = TRUE;
                    
                    // Log the read barcode
                    NSLog(@"\nBar code read: %@\n", barcode);
                }
                
                // National brand, encode GTIN in an SGTIN
                else if ((barcode.length == 12) || (barcode.length == 14)) {
                    // Take the gtin and encode a reference
                    NSString *gtin = barcode;
                    NSString *ser  = ([_serFld.text length])?[_serFld text]:@"0";
                    
                    [_encodeEPC withGTIN:gtin ser:ser partBin:@"101"];
                    
                    // Set the interface
                    [_gtinFld setText:barcode];
                    [_dptFld setText:@""];
                    [_clsFld setText:@""];
                    [_itmFld setText:@""];
                    
                    // Show GTIN
                    [self.view bringSubviewToFront:_gtinLbl];
                    [self.view bringSubviewToFront:_gtinFld];
                    
                    // Hide the rest
                    [self.view sendSubviewToBack:_dptLbl];
                    [self.view sendSubviewToBack:_dptFld];
                    [self.view sendSubviewToBack:_clsLbl];
                    [self.view sendSubviewToBack:_clsFld];
                    [self.view sendSubviewToBack:_itmLbl];
                    [self.view sendSubviewToBack:_itmFld];
                    
                    _barcodeFound = TRUE;
                    
                    // Log the read barcode
                    NSLog(@"\nBar code read: %@\n", barcode);
                }
                
                // Unsupported barcode
                else {
                    
                    _barcodeLbl.text = @"Barcode: unsupported barcode";
                    _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
                    _barcodeFound = FALSE;
                    
                    // Log the unsupported barcode
                    NSLog(@"\nUnsupported barcode: %@\n", barcode);
                }
            }
        }
        
        // Still scanning for barcodes
        else {
            _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
            _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
            _barcodeFound = FALSE;
        }
    }
    
    // This clears the scan rectangle if empty
    _highlightView.frame = highlightViewRect;
    
    // Check to see if ready to encode
    [self readyToEncode];
}

- (void)configureSettings:(NSString *)detectionString {
    // Parse the settings
    NSArray *settings = [detectionString componentsSeparatedByString:@"|"];
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    for( int i=0; i<[settings count]; i+=2){
        dictionary[[settings objectAtIndex:i]] = [settings objectAtIndex:i+1];
    }
    
    // Set ScanScan toggle before the rest
    _scanScanEncodeSwt.on = ([[dictionary valueForKey:@"SCANSCAN"] isEqualToString:@"ON"]);
    
    // MODE|DEFAULT|SCANSCAN|ON or OFF
    if ([[dictionary valueForKey:@"MODE"] isEqualToString:@"DEFAULT"]) {
        _replaceSwt.on = false;
        _tcinSwt.on = false;
        _tiaiSwt.on = false;
        [self reset:_replaceSwt];
    }
    
    // MODE|REPLACE|SCANSCAN|ON or OFF
    if ([[dictionary valueForKey:@"MODE"] isEqualToString:@"REPLACE"]) {
        _replaceSwt.on = true;
        [self reset:_replaceSwt];
    }
    
    // MODE|TCIN|SCANSCAN|ON or OFF
    if ([[dictionary valueForKey:@"MODE"] isEqualToString:@"TCIN"]) {
        _tcinSwt.on = true;
        [self reset:_tcinSwt];
    }
    
    // MODE|TIAI|ASSETREF|5|TYPE|DEC or CHAR or HEX|SCANSCAN|ON or OFF
    if ([[dictionary valueForKey:@"MODE"] isEqualToString:@"TIAI"]) {
        _tiaiSwt.on = true;
        if ([[dictionary valueForKey:@"TYPE"] isEqualToString:@"DEC"]) {
            [_tiaiTypeSel setSelectedSegmentIndex:0];
        }
        else if ([[dictionary valueForKey:@"TYPE"] isEqualToString:@"CHAR"]) {
            [_tiaiTypeSel setSelectedSegmentIndex:1];
        }
        else if ([[dictionary valueForKey:@"TYPE"] isEqualToString:@"HEX"]) {
            [_tiaiTypeSel setSelectedSegmentIndex:2];
        }
        [self reset:_tiaiSwt];
        _tiaiFld.text = [dictionary valueForKey:@"ASSETREF"];
    }
    
    NSLog (@"Configuration Settings Set: %@", detectionString);
}

- (BOOL)isNumericOnly:(NSString *)toCheck {
    NSScanner* scan = [NSScanner scannerWithString:toCheck];
    int val;
    return [scan scanInt:&val] && [scan isAtEnd];
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
 * @discussion Called when UISegmentedControl _tiaiTypeSel selection changed to update controls
 */
- (IBAction)typeSelValueChanged:(id)sender {
    [self updateAll];
}

/*!
 * @discussion Update the interface - All the edit fields point here, after you end the edit and hit return.
 */
- (IBAction)update:(id)sender {
    // Mutually exclusive options
    if (sender == _replaceSwt && _replaceSwt.on && (_tcinSwt.on || _tiaiSwt.on)) {
        [_tcinSwt setOn:false];
        [_tiaiSwt setOn:false];
        [self.view sendSubviewToBack:_tiaiTypeSel];
        [self reset:_replaceSwt];
    }
    
    // New input data
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    [self updateAll];
}

/*!
 * @discussion Update all elements for any input change.  Check input and check ready to encode.
 */
- (void)updateAll {
    
    // TCIN encoding
    if (_tcinSwt.on) {
        NSString *tcin = [_tcinFld text];
        NSString *ser  = [_serFld text];
        
        [self updateTCIN:tcin withSer:ser];
    }
    // TIAI Encoding
    else if (_tiaiSwt.on) {
        NSString *tiai = [_tiaiFld text];
        NSString *aid  = [_aidFld text];
        
        [self updateTIAI:tiai withAID:aid];
    }
    // EPC Encodings (SGTIN, GID (DPCI)
    else {
        NSString *gtin = [_gtinFld text];
        NSString *dpt  = [_dptFld text];
        NSString *cls  = [_clsFld text];
        NSString *itm  = [_itmFld text];
        NSString *ser  = [_serFld text];
        
        // Make sure the inputs are not too long (especially the Serial Number)
        if ([gtin length] > 14) {
            gtin = [gtin substringToIndex:14];
            [_gtinFld setText:gtin];
        }
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
        // GTIN in SGTIN
        if ([ser length] > 0 && [gtin length] > 0) {
            // Update the EPCEncoder object
            [_encodeEPC withGTIN:gtin ser:ser partBin:@"101"];
            
            if ([gtin length] == 14 || [gtin length] == 12) {
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", gtin];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                _barcodeFound = TRUE;
                
                // Hide DPCI
                [self.view sendSubviewToBack:_dptLbl];
                [self.view sendSubviewToBack:_dptFld];
                [self.view sendSubviewToBack:_clsLbl];
                [self.view sendSubviewToBack:_clsFld];
                [self.view sendSubviewToBack:_itmLbl];
                [self.view sendSubviewToBack:_itmFld];
            }
            else {
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid GTIN)"];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
                _barcodeFound = FALSE;
            }
        }
        // DPCI in GID
        else if ([dpt length] > 0 && [cls length] > 0 && [itm length] > 0 && [ser length] > 0) {
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
            [_encodeEPC withDpt:dpt cls:cls itm:itm ser:ser];
            
            if ([dpt length] == 3 && [cls length] == 2 && [itm length] == 4) {
                // Build the barcode
                NSString *barcode = [NSString stringWithFormat:@"49%@%@%@",dpt,cls,itm];
                NSString *chkdgt = [_encodeEPC calculateCheckDigit:barcode];
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
            [_encodeEPC gidWithGTIN:gtin ser:ser];
            
            if ([gtin length] == 14 || [gtin length] == 12) {
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", gtin];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                _barcodeFound = TRUE;
                
                // Hide DPCI
                [self.view sendSubviewToBack:_dptLbl];
                [self.view sendSubviewToBack:_dptFld];
                [self.view sendSubviewToBack:_clsLbl];
                [self.view sendSubviewToBack:_clsFld];
                [self.view sendSubviewToBack:_itmLbl];
                [self.view sendSubviewToBack:_itmFld];
            }
            else {
                _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid GTIN)"];
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
                _barcodeFound = FALSE;
            }
            
            _barcodeFound = TRUE;
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
            _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
            _barcodeFound = FALSE;
        }
    }
    
    // Set the background color
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    // Check to see if ready to encode
    if (_scanScanEncodeSwt.on == FALSE) [self readyToEncode];
}

- (BOOL)updateTCIN:(NSString *)tcin withSer:(NSString *)ser {
  
    // Make sure the inputs are not too long
    if ([tcin length] > 10) tcin = [tcin substringToIndex:10];
    
    [_tcinFld setText:tcin];
    
    if ([tcin length] > 0) {
        // Update the TCINEncoder object (randomly generate ser)
        [_encodeTCIN withTCIN:tcin];
        
        if ([tcin length] > 0 && [self isNumericOnly:tcin]) {
            // Update with the random serial number
            [_serFld setText:[_encodeTCIN ser]];
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", tcin];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid TCIN)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
            [_tcinFld setText:@""];
        }
    }
    else {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
        _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _barcodeFound = FALSE;
    }
    
    return _barcodeFound;
}

- (BOOL)updateTIAI:(NSString *)tiai withAID:(NSString *)aid {

    // Make sure the inputs are numeric only
    if ([tiai length] == 0 || ![self isNumericOnly:tiai]) tiai = @"5";
    
    // Make sure the inputs are not too long (especially the Asset ID)
    if ([tiai length] > 3) tiai = [tiai substringToIndex:3];
    
    // Set the type selector segment index
    BOOL isNumeric = [self isNumericOnly:aid];
    NSInteger type = _tiaiTypeSel.selectedSegmentIndex;
    if (([aid length] > 0) && !isNumeric && type == 0) {
        [_tiaiTypeSel setSelectedSegmentIndex:1];
        [_tiaiTypeSel setEnabled:false forSegmentAtIndex:0];
    }
    else {
        [_tiaiTypeSel setEnabled:true forSegmentAtIndex:0];
    }
    
    // TIAI aid number max = 21, varchar max = 12, hex max = 18
    int maxLength = (isNumeric && type == 0)?21:(type == 1)?12:18;
    if ([aid length] > maxLength) aid = [aid substringToIndex:maxLength];
    
    [_tiaiFld setText:tiai];
    [_aidFld setText:aid];
    
    if (([tiai length] > 0) && ([aid length] > 0))  {
        // Update the TCINEncoder object
        (isNumeric && type == 0)?
            [_encodeTIAI withAssetRef:tiai assetIDDec:aid]:(type == 1)?
            [_encodeTIAI withAssetRef:tiai assetIDChar:aid]:
            [_encodeTIAI withAssetRef:tiai assetIDHex:aid];
        
        if ([aid length] > 0) {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", aid];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid asset ID)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
            [_aidFld setText:@""];
        }
    }
    else {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
        _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _barcodeFound = FALSE;
    }
    
    return _barcodeFound;
}

// Encode
#pragma mark - Encode

/*!
 * @discussion Check for ready to encode - Enable the encode button if all input ready.
 */
- (void)readyToEncode {
    // If we have a valid barcode, an RFID tag, and a reader is connected, we are ready to encode
    BOOL conditionsMet = (_barcodeFound && _rfidFound && ([_oldEPC length] > 0));
    
    // If scanScanEncode is enabled, automatically encode the tag now
    if (_scanScanEncodeSwt.on == TRUE && conditionsMet) {
        [self encode:_scanScanEncodeSwt];
        
        if (_tagEncoded) {
            [self reset:_scanScanEncodeSwt];
            
            // Adjust the result images after reset
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                               self->_successImg.hidden = !(self->_tagEncoded);
                               self->_failImg.hidden = self->_tagEncoded;
                           });
        }
    }
    
    // Otherwise, enable or disable the manual encode button based on the conditions
    else {
        _encodeBtn.enabled = conditionsMet;
    }
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

    NSString *hex;
    if (_tcinSwt.on) {
        hex = [_encodeTCIN tcin_hex];
    }
    else if (_tiaiSwt.on) {
        hex = [_encodeTIAI tiai_hex];
    }
    else {
        NSString *ser  = [_serFld text];
        NSString *gtin = [_gtinFld text];
        
        hex =([ser length] > 0 && [gtin length] > 0 && _replaceSwt.on == FALSE)?[_encodeEPC sgtin_hex]:[_encodeEPC gid_hex];
    }

    [self beginEncode:hex];
}

/*!
 * @discussion Begin the encoding process.
 * @param hex The new tag number to encode (hex)
 */
- (void)beginEncode:(NSString *)hex {
    [_newEPC setString:hex];
    
    if ([_oldEPC length] == 0) {
        // The only way we got here is after a successful tag read, otherwise the encode button wouldn't be active
        // so this code block really should never be hit.
        [self zebraRapidRead];
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
    
    // Test tag reset: check for one of the special reset barcodes, if found, encode with the reset value
    if ([[_gtinFld text] isEqual:@"999999999924"]){
        [_newEPC setString:@"30304035A880C840003676C8"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999931"]){
        [_newEPC setString:@"30304035A880C840003676C9"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999948"]){
        [_newEPC setString:@"E28011606000020610B7E232"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999955"]){
        [_newEPC setString:@"E28011606000020610B85282"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999962"]){
        [_newEPC setString:@"3BF0000000271471148F0E9C"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999979"]){
        [_newEPC setString:@"3BF0000000271471148F0E9D"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999986"]){
        [_newEPC setString:@"3BF0000000271471148F0E9E"];
    }
    else if ([[_gtinFld text] isEqual:@"999999999993"]){
        [_newEPC setString:@"3BF0000000271471148F0E9F"];
    }
    
    // Assume failure (many ways to fail)
    _tagEncoded = FALSE;
    
    // Allocate object for storing results of access operation
    srfidTagData *access_result = [[srfidTagData alloc] init];
    
    // An object for storage of error response received from RFID reader
    NSString *error_response = nil;
    
    // Write _newEPC to the EPC memory bank of a tag specified by _oldEPC
    SRFID_RESULT result = [_rfidSdkApi srfidWriteTag:_zebraReaderID
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
            long long serLong = [[_serFld text] longLongValue];
            [_serFld setText:[NSString stringWithFormat:@"%lld", (++serLong)]];
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
    
    // If our work is done
    if (_tagEncoded) [_oldEPC setString:@""];
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
    
    // Set the reader
    _zebraReaderID = [activeReader getReaderID];
    
    // Establish ASCII connection
    if ([_rfidSdkApi srfidEstablishAsciiConnection:_zebraReaderID aPassword:nil] == SRFID_RESULT_SUCCESS)
    {
        // Set the volume
        NSString *statusMessage = nil;
        [_rfidSdkApi srfidSetBeeperConfig:_zebraReaderID
                            aBeeperConfig:SRFID_BEEPERCONFIG_LOW
                           aStatusMessage:&statusMessage];
        
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
        [_rfidSdkApi srfidTerminateCommunicationSession:_zebraReaderID];
        _zebraReaderID = -1;
        _rfidLbl.text = @"RFID: Zebra connection failed";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
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
                       [self->_rfidSdkApi srfidStopRapidRead:readerID aStatusMessage:nil];
                       
                       // New input data
                       self->_successImg.hidden = TRUE;
                       self->_failImg.hidden = TRUE;
                       
                       // Set the old EPC
                       [self->_oldEPC setString:[tagData getTagId]];
                       
                       // Get the RFID tag
                       self->_rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", self->_oldEPC];
                       self->_rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                       
                       // We've found a tag
                       self->_rfidFound = TRUE;
                       
                       if (self->_encoding) {
                           [self endEncode:self->_oldEPC];
                           self->_encoding = FALSE;
                       }
                       else {
                           self->_rfidFound = TRUE;
                           
                           // Check to see if ready to encode
                           [self readyToEncode];
                       }
                       
                       // Log the read tag
                       NSLog(@"\nRFID tag read: %@\n", self->_oldEPC);
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
                       self->_batteryLifeView.progress = battery/100.;
                       self->_batteryLifeLbl.backgroundColor =
                       (battery > 20)?UIColorFromRGB(0xA4CD39):
                       (battery > 5 )?UIColorFromRGB(0xCC9900):
                       UIColorFromRGB(0xCC0000);
                       
                       self->_batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%\n", battery];
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
