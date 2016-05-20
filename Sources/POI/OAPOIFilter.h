//
//  OAPOIFilter.h
//  OsmAnd
//
//  Created by Alexey Kulish on 29/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAPOIBaseType.h"
#import "OAPOICategory.h"

@class OAPOIType;

@interface OAPOIFilter : OAPOIBaseType

@property (nonatomic) OAPOICategory *category;
@property (nonatomic) NSArray<OAPOIType *> *poiTypes;

- (instancetype)initWithName:(NSString *)name category:(OAPOICategory *)category;

- (void)addPoiType:(OAPOIType *)poiType;

@end
