//
//  RZLocationSimulationManager.m
//  Raizlabs
//
//  Created by Adam Howitt on 1/23/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZLocationManager.h"
#import <CoreLocation/CoreLocation.h>

static const NSDateFormatter* df;

@interface RZOffsetLocation ()

@property (assign, nonatomic) CLLocationCoordinate2D coordinate;
@property (assign, nonatomic) CLLocationDistance altitude;
@property (assign, nonatomic) CLLocationAccuracy horizontalAccuracy;
@property (assign, nonatomic) CLLocationAccuracy verticalAccuracy;
@property (assign, nonatomic) CLLocationDirection course;
@property (assign, nonatomic) CLLocationSpeed speed;
@property (assign, nonatomic) NSTimeInterval timeSinceRouteBegan;
@property (copy, nonatomic) NSDate *timestamp;

@end

@implementation RZOffsetLocation

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

{
    self = [super init];
    if ( self != nil ) {
        self.coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        self.altitude = altitude;
        self.horizontalAccuracy = hAccuracy;
        self.verticalAccuracy = vAccuracy;
        self.course = course;
        self.speed = speed;
        self.timestamp = [self.class dateFromTimestamp:timestamp];
        self.timeSinceRouteBegan = [self.timestamp timeIntervalSinceDate:firstLocationDate]/playBackSpeed;
    }
    return self;
}

- (CLLocation *)locationOffsetFromStartDate:(NSDate *)startDate
{
    NSDate *locationTimeStamp = [startDate dateByAddingTimeInterval:self.timeSinceRouteBegan];

    return [[CLLocation alloc] initWithCoordinate:self.coordinate
                                         altitude:self.altitude
                               horizontalAccuracy:self.horizontalAccuracy
                                 verticalAccuracy:self.verticalAccuracy
                                           course:self.course
                                            speed:self.speed
                                        timestamp:locationTimeStamp];
}

+ (NSDate *)dateFromTimestamp:(NSString *)timestamp
{
    if ( df == nil ) {
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    }
    return [df dateFromString:timestamp];
}

+ (NSString *)dateToTimestamp:(NSDate *)date
{
    if ( df == nil ) {
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    }
    return [df stringFromDate:date];
}
@end


@interface RZLocationSimulationManager ()

@property (strong, nonatomic) NSArray *locationArray;
@property (strong, nonatomic) NSTimer *dispatchTimer;
@property (strong, nonatomic) CLLocation *nextLocation;
@property (assign, nonatomic) NSInteger currentPointIndex;
@property (assign, nonatomic) BOOL isUpdating;
@property (strong, nonatomic) NSDate *startDate;
@property (assign, nonatomic) NSTimeInterval startOffset;
@property (assign, nonatomic) double playbackSpeed;

@end


@implementation RZLocationSimulationManager

-(instancetype)initWithPlaybackSpeed:(double)playbackSpeed json:(NSData*)jsonData
{
    self = [super init];
    if ( self != nil ) {
        self.currentPointIndex = 0;
        self.isUpdating = NO;
        self.playbackSpeed = ( playbackSpeed > 0 ? playbackSpeed : 1 );
        [self loadJSON:jsonData];
    }
    return self;
}

- (void)dealloc
{
}

- (void)startUpdatingLocation
{
    self.startDate = [NSDate date];
    self.isUpdating = YES;
    if ( self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)] ) {

        self.nextLocation = [self locationAtIndex:self.currentPointIndex++];
        self.startOffset = [self.startDate timeIntervalSinceDate:self.nextLocation.timestamp];
    }
}

- (void)startSimulator {

    self.currentPointIndex = 0;
    self.nextLocation = self.locationArray[ 0 ];
    [self dispatchLocation];
}

- (void)stopUpdatingLocation
{
    self.isUpdating = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dispatchLocation) object:nil];
}

- (CLLocation *)locationAtIndex:(NSInteger)index
{
    RZOffsetLocation *currentLocation = self.locationArray[index];
    return [currentLocation locationOffsetFromStartDate:self.startDate];
}


- (void)loadJSON:(NSData *)jsonData
{
    NSError *error;
    id parsedJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    if ( error ) {
        NSLog(@"%@ %@ got error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
        return;
    }

    NSMutableArray *locations = [NSMutableArray array];
    NSDate *firstLocationTimeStamp = [RZOffsetLocation dateFromTimestamp:[(NSArray *)parsedJSON firstObject][@"timestamp"]];
    NSDate *oldstamp = firstLocationTimeStamp;

    for (NSDictionary *location in (NSArray *)parsedJSON) {
        NSString *timestamp = location[@"timestamp"] ?: [RZOffsetLocation dateToTimestamp:[oldstamp dateByAddingTimeInterval:1]];
        oldstamp = [RZOffsetLocation dateFromTimestamp:timestamp];

        RZOffsetLocation *offsetLocation = [[RZOffsetLocation alloc] initWithLatitude:[location[@"latitude"] doubleValue]
                                                                              longitude:[location[@"longitude"] doubleValue]
                                                                               altitude:[location[@"altitude"]   doubleValue]
                                                                     horizontalAccuracy:[location[@"horizontalAccuracy"] doubleValue]
                                                                       verticalAccuracy:[location[@"verticalAccuracy"] doubleValue]
                                                                                 course:[location[@"direction"] doubleValue]
                                                                                  speed:[location[@"metersPerSecond"] doubleValue]
                                                                              timestamp:timestamp
                                                                      firstLocationDate:firstLocationTimeStamp
                                                                          playBackSpeed:self.playbackSpeed];
        [locations addObject:offsetLocation];
    }

    self.locationArray = locations;
}

- (void)dispatchLocation
{
    if ( self.isUpdating ) {
        NSDate *lastLocationDate = self.nextLocation.timestamp;

        [self.delegate locationManager:self didUpdateLocations:@[self.nextLocation]];

        if ( self.currentPointIndex < self.locationArray.count ) {
            self.nextLocation = [self locationAtIndex:self.currentPointIndex++];
            NSTimeInterval timeToNextPoint = 1.0f; // [self.nextLocation.timestamp timeIntervalSinceDate:lastLocationDate]/self.playbackSpeed;

            [self performSelector:@selector(dispatchLocation) withObject:nil afterDelay:timeToNextPoint inModes:@[NSRunLoopCommonModes]];
        }
        else {
            NSLog(@"Out of GPS tracks...");
        }
    }
}

- (CLLocation *)location {
    return self.nextLocation;
}


@end