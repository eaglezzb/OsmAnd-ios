//
//  OAPoiTypeSelectionViewController.h
//  OsmAnd
//
//  Created by Paul on 2/23/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OACompoundViewController.h"
#import "OAOsmEditingViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EOASelectionType)
{
    CATEGORY_SCREEN = 0,
    POI_TYPE_SCREEN
};

@interface OAPoiTypeSelectionViewController : OACompoundViewController

@property (nonatomic) id<OAOsmEditingDataProtocol> dataProvider;

-(id)initWithType:(EOASelectionType)type;

@end

NS_ASSUME_NONNULL_END
