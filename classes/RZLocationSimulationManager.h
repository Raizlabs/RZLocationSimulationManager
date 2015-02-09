//
//  RZLocationSimulationManager.h
//  Raizlabs
//
//  Created by Adam Howitt on 1/23/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>


@interface RZOffsetLocation : NSObject

- (instancetype)initWithLatitude:(CLLocationDegrees)latitude
                       longitude:(CLLocationDegrees)longitude
                        altitude:(CLLocationDistance)altitude
              horizontalAccuracy:(CLLocationAccuracy)hAccuracy
                verticalAccuracy:(CLLocationAccuracy)vAccuracy
                          course:(CLLocationDirection)course
                           speed:(CLLocationSpeed)speed
                       timestamp:(NSString *)timestamp
               firstLocationDate:(NSDate *)firstLocationDate
                   playBackSpeed:(double)playBackSpeed;

- (CLLocation *)locationOffsetFromStartDate:(NSDate *)startDate;

+ (NSDate *)dateFromTimestamp:(NSString *)timestamp;

@end

@interface RZLocationSimulationManager : CLLocationManager

-(instancetype)initWithPlaybackSpeed:(double)playbackSpeed json:(NSData*)jsonData;
-(void)startSimulator;

@end
