//
//  TempiAudioManager.m
//  TempiAudioManager
//
//  Created by Simon Mitchell on 19/07/2018.
//

#import <AVFoundation/AVFoundation.h>
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import "TempiAudioManager.h"
#import "RNTempiFFT-Swift.h"

NSString *const AudioAnalysisEvent = @"analysisAvailable";

@interface TempiAudioManager ()

@property (nonatomic, strong) TempiAudioInput *audioInput;

@property (nonatomic, strong) NSDate *previousProgressUpdateTime;

@property (nonatomic, assign) NSTimeInterval progressUpdateInterval;

@property (nonatomic, assign) float sampleRate;

@property (nonatomic, strong) NSDictionary *fourierParameters;

@end

@implementation TempiAudioManager

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return true;
}

- (void)sendProgressUpdate:(float)timestamp frames:(NSInteger)frames samples:(NSArray<NSNumber *> * _Nonnull) samples {
    
    if (self.previousProgressUpdateTime == nil || [self.previousProgressUpdateTime timeIntervalSinceNow] * -1 >= self.progressUpdateInterval) {
        
        NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
        body[@"currentTime"] = [NSNumber numberWithFloat:timestamp];
        
        TempiFFT *fft = [[TempiFFT alloc] initWithSize:frames sampleRate: self.sampleRate];
        fft.windowType = TempiFFTWindowTypeHanning;
        [fft fftForward:samples];
        
        // Interpoloate the FFT data so there's the number of bands we require!
        float minFrequency = 0.0;
        float maxFrequency = fft.nyquistFrequency;
        NSInteger numberOfBands = (NSInteger)[UIScreen mainScreen].bounds.size.width * [UIScreen mainScreen].scale;
        
        if (self.fourierParameters) {
            
            if (self.fourierParameters[@"MinFrequency"] && [self.fourierParameters[@"MinFrequency"] isKindOfClass:[NSNumber class]]) {
                minFrequency = [self.fourierParameters[@"MinFrequency"] floatValue];
            }
            
            if (self.fourierParameters[@"MaxFrequency"] && [self.fourierParameters[@"MaxFrequency"] isKindOfClass:[NSNumber class]]) {
                maxFrequency = [self.fourierParameters[@"MaxFrequency"] floatValue];
            }
            
            if (self.fourierParameters[@"Bands"] && [self.fourierParameters[@"Bands"] isKindOfClass:[NSNumber class]]) {
                numberOfBands = [self.fourierParameters[@"Bands"] integerValue];
            }
        }
        
        [fft calculateLinearBandsWithMinFrequency:minFrequency maxFrequency:maxFrequency numberOfBands:numberOfBands];
        
        body[@"fft"] = @{
            @"frequencies": fft.bandFrequencies ? : @[],
            @"magnitudes": fft.bandMagnitudes ? : @[]
        };
    
        [self.bridge.eventDispatcher sendAppEventWithName:AudioAnalysisEvent body:body];
        self.previousProgressUpdateTime = [NSDate date];
    }
}

RCT_EXPORT_METHOD(requestAuthorization:(RCTPromiseResolveBlock)resolve
                  rejecter:(__unused RCTPromiseRejectBlock)reject)
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if(granted) {
            resolve(@YES);
        } else {
            resolve(@NO);
        }
    }];
}

RCT_EXPORT_METHOD(startAnalysingWithSampleRate:(float)sampleRate channels:(nonnull NSNumber *)channels fourierParameters:(NSDictionary *)fourierParameters)
{
    self.previousProgressUpdateTime = nil;
    self.sampleRate = sampleRate;
    self.fourierParameters = fourierParameters;
    
    __weak typeof(self) welf = self;
    
    self.audioInput = [[TempiAudioInput alloc] initWithAudioInputCallback:^(double timestamp, NSInteger frames, NSArray<NSNumber *> * _Nonnull samples) {
        
        if (!welf) {
            return;
        }
        
        [welf sendProgressUpdate:timestamp frames:frames samples:samples];
        
    } sampleRate:sampleRate numberOfChannels:[channels intValue]];
    
    [self.audioInput startRecording];
}

RCT_EXPORT_METHOD(stopAnalysing)
{
    [self.audioInput stopAnalysing];
}

- (instancetype)init
{
    if (self = [super init]) {
        self.progressUpdateInterval = 0.25;
    }
    
    return self;
}

@end
