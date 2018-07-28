//
//  OATTSCommandPlayerImpl.m
//  OsmAnd
//
//  Created by Paul on 7/10/18.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "OATTSCommandPlayerImpl.h"
#import "OACommandBuilder.h"
#import "OAVoiceRouter.h"

@implementation OATTSCommandPlayerImpl {
    AVSpeechSynthesizer *synthesizer;
    OAVoiceRouter *vrt;
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        synthesizer = [[AVSpeechSynthesizer alloc] init];
    }
    return self;
}

- (instancetype) initWithVoiceRouter:(OAVoiceRouter *) voiceRouter
{
    self = [super init];
    if (self)
    {
        synthesizer = [[AVSpeechSynthesizer alloc] init];
        vrt = voiceRouter;
    }
    return self;
}

- (void)playCommands:(OACommandBuilder *)builder
{
    if ([vrt isMute]) {
        return;
    }
    NSMutableString *toSpeak = [[NSMutableString alloc] init];
    NSArray<NSString *> *uterrances = [builder getUtterances];
    for (NSString *utterance in uterrances) {
        [toSpeak appendString:utterance];
    }
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:toSpeak];
//    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"hu-HU"];
    [utterance setRate:0.5f];
    [synthesizer speakUtterance:utterance];
}

@end