//
//  OAPOIParser.m
//  OsmAnd
//
//  Created by Alexey Kulish on 18/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAPOIParser.h"
#import "OAPOIType.h"
#import "OAPOICategory.h"
#import "OAPOIFilter.h"

// called from libxml functions
@interface OAPOIParser (LibXMLParserMethods)

- (void)elementFound:(const xmlChar *)localname prefix:(const xmlChar *)prefix
                 uri:(const xmlChar *)URI namespaceCount:(int)namespaceCount
          namespaces:(const xmlChar **)namespaces attributeCount:(int)attributeCount
defaultAttributeCount:(int)defaultAttributeCount attributes:(xmlSAX2Attributes *)attributes;
- (void)endElement:(const xmlChar *)localname prefix:(const xmlChar *)prefix uri:(const xmlChar *)URI;
- (void)charactersFound:(const xmlChar *)characters length:(int)length;
- (void)parsingError:(const char *)msg, ...;
- (void)endDocument;


@end

// Forward reference. The structure is defined in full at the end of the file.
static xmlSAXHandler simpleSAXHandlerStruct;


@implementation OAPOIParser {
    
    NSMutableArray<OAPOIType *> *_pTypes;
    NSMutableArray<OAPOICategory *> *_pCategories;
    NSMutableArray<OAPOIFilter *> *_pFilters;
    
    xmlParserCtxtPtr _xmlParserContext;
    
    BOOL _done;

    OAPOIType *_currentPOIType;
    OAPOICategory *_currentPOICategory;
    OAPOIFilter *_currentPOIFilter;
    NSMutableString *_propertyValue;
    NSOperationQueue *_retrieverQueue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _retrieverQueue = [[NSOperationQueue alloc] init];
        _retrieverQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (void)getPOITypesSync:(NSString*)fileName {
    
    _pTypes = [NSMutableArray array];
    _pCategories = [NSMutableArray array];
    _pFilters = [NSMutableArray array];

    self.fileName = fileName;
    [self parseForData];
}

- (void)getPOITypesAsync:(NSString*)fileName {
    
    _pTypes = [NSMutableArray array];
    _pCategories = [NSMutableArray array];
    _pFilters = [NSMutableArray array];

    self.fileName = fileName;
    
    // make an operation so we can push it into the queue
    SEL method = @selector(parseForData);
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self
                                                                     selector:method
                                                                       object:nil];
    [_retrieverQueue addOperation:op];
}

- (BOOL)parseWithLibXML2Parser
{
    BOOL success = NO;
    self.error = NO;
    
    _xmlParserContext = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, (__bridge void *)(self), NULL, 0, NULL);
    
    NSData *poiData = [NSData dataWithContentsOfFile:self.fileName];
    xmlParseChunk(_xmlParserContext, (const char *)[poiData bytes], (int)[poiData length], 0);
    xmlParseChunk(_xmlParserContext, NULL, 0, 1);
    _done = YES;
    
    if (self.error)
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(encounteredError:)])
        {
            [self.delegate encounteredError:nil];
        }
    }
    else
    {
        self.poiTypes = _pTypes;
        self.poiCategories = _pCategories;
        self.poiFilters = _pFilters;
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(parserFinished)])
        {
            [(id)[self delegate] performSelectorOnMainThread:@selector(parserFinished)
                                                  withObject:nil
                                               waitUntilDone:NO];
        }
        
        success = YES;
    }
    return success;
}


- (BOOL)parseForData
{
    BOOL success = NO;
    
    @autoreleasepool
    {
        success = [self parseWithLibXML2Parser];
        return success;
    }
}

/*
 
 <poi_category name="shop" default_tag="shop">
   <poi_filter name="shop_food">
     <poi_type name="bakery" tag="shop" value="bakery"></poi_type>
 
 */

#pragma mark Parsing Function Callback Methods

static const char *kPoiCategoryElementName = "poi_category";
static NSUInteger kPoiCategoryElementNameLength = 13;
static const char *kPoiFilterElementName = "poi_filter";
static NSUInteger kPoiFilterElementNameLength = 11;
static const char *kPoiTypeElementName = "poi_type";
static NSUInteger kPoiTypeElementNameLength = 9;
static const char *kPoiReferenceElementName = "poi_reference";
static NSUInteger kPoiReferenceElementNameLength = 14;
static const char *kPoiAdditionalElementName = "poi_additional";
static NSUInteger kPoiAdditionalElementNameLength = 15;

static const char *kNameAttributeName = "name";
static NSUInteger kNameAttributeNameLength = 5;
static const char *kDefaultTagAttributeName = "default_tag";
static NSUInteger kDefaultTagAttributeNameLength = 12;
static const char *kTagAttributeName = "tag";
static NSUInteger kTagAttributeNameLength = 4;
static const char *kValueAttributeName = "value";
static NSUInteger kValueAttributeNameLength = 6;
static const char *kTopAttributeName = "top";
static NSUInteger kTopAttributeNameLength = 4;
static const char *kMapAttributeName = "map";
static NSUInteger kMapAttributeNameLength = 4;
static const char *kOrderAttributeName = "order";
static NSUInteger kOrderAttributeNameLength = 6;


- (void)elementFound:(const xmlChar *)localname prefix:(const xmlChar *)prefix
                 uri:(const xmlChar *)URI namespaceCount:(int)namespaceCount
          namespaces:(const xmlChar **)namespaces attributeCount:(int)attributeCount
defaultAttributeCount:(int)defaultAttributeCount attributes:(xmlSAX2Attributes *)attributes
{
    if (0 == strncmp((const char *)localname, kPoiCategoryElementName, kPoiCategoryElementNameLength))
    {
        NSString *name = nil;
        NSString *tag = nil;
        BOOL top = NO;
        
        for(int i = 0; i < attributeCount; i++)
        {
            if (0 == strncmp((const char*)attributes[i].localname, kNameAttributeName,
                            kNameAttributeNameLength))
            {
                int length = (int) (attributes[i].end - attributes[i].value);
                name = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            }
            else if (0 == strncmp((const char*)attributes[i].localname, kDefaultTagAttributeName,
                                   kDefaultTagAttributeNameLength))
            {
                int length = (int) (attributes[i].end - attributes[i].value);
                tag = [[NSString alloc] initWithBytes:attributes[i].value
                                                               length:length
                                                             encoding:NSUTF8StringEncoding];
            }
            else if (0 == strncmp((const char*)attributes[i].localname, kTopAttributeName,
                                  kTopAttributeNameLength))
            {
                int length = (int) (attributes[i].end - attributes[i].value);
                NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                           length:length
                                                         encoding:NSUTF8StringEncoding];
                
                top = [[value lowercaseString] isEqualToString:@"true"];
            }
        }

        _currentPOICategory = [[OAPOICategory alloc] initWithName:name];
        _currentPOICategory.tag = tag;
        _currentPOICategory.top = top;
        
        if (![_pCategories containsObject:_currentPOICategory])
        {
            [_pCategories addObject:_currentPOICategory];
        }
    }
    else if (0 == strncmp((const char *)localname, kPoiFilterElementName, kPoiFilterElementNameLength))
    {
        NSString *name = nil;
        BOOL top = NO;

        for(int i = 0; i < attributeCount; i++)
        {
            if (0 == strncmp((const char*)attributes[i].localname, kNameAttributeName,
                            kNameAttributeNameLength))
            {
                int length = (int) (attributes[i].end - attributes[i].value);
                name = [[NSString alloc] initWithBytes:attributes[i].value
                                                               length:length
                                                             encoding:NSUTF8StringEncoding];
            }
            else if (0 == strncmp((const char*)attributes[i].localname, kTopAttributeName,
                                  kTopAttributeNameLength))
            {
                int length = (int) (attributes[i].end - attributes[i].value);
                NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                           length:length
                                                         encoding:NSUTF8StringEncoding];
                
                top = [[value lowercaseString] isEqualToString:@"true"];
            }
        }
        
        _currentPOIFilter = [[OAPOIFilter alloc] initWithName:name category:_currentPOICategory];
        _currentPOIFilter.top = top;
        if (_currentPOICategory)
        {
            [_currentPOICategory addPoiFilter:_currentPOIFilter];
        }

        if (![_pFilters containsObject:_currentPOIFilter])
        {
            [_pFilters addObject:_currentPOIFilter];
        }
    }
    else if (0 == strncmp((const char *)localname, kPoiTypeElementName, kPoiTypeElementNameLength) ||
             0 == strncmp((const char *)localname, kPoiReferenceElementName, kPoiReferenceElementNameLength))
    {
        _currentPOIType = [self parsePoiType:localname attributeCount:attributeCount attributes:attributes];
    }
    else if (0 == strncmp((const char *)localname, kPoiAdditionalElementName, kPoiAdditionalElementNameLength))
    {
        [self parsePoiAdditional:localname attributeCount:attributeCount attributes:attributes];
    }
}

- (void)endElement:(const xmlChar *)localname prefix:(const xmlChar *)prefix uri:(const xmlChar *)URI
{
    if(0 == strncmp((const char *)localname, kPoiFilterElementName, kPoiFilterElementNameLength)) {
        _currentPOIFilter = nil;
        
    } else if(0 == strncmp((const char *)localname, kPoiCategoryElementName, kPoiCategoryElementNameLength)) {
        _currentPOICategory = nil;

    } else if(0 == strncmp((const char *)localname, kPoiTypeElementName, kPoiTypeElementNameLength)) {
        _currentPOIType = nil;
    
    }
}

- (void)charactersFound:(const xmlChar *)characters length:(int)length
{
}

- (void)parsingError:(const char *)msg, ... {
    self.error = YES;
    _done = YES;
}

-(void)endDocument {

}

- (void) dealloc {
    
    xmlFreeParserCtxt(_xmlParserContext);
    _xmlParserContext = NULL;
    
    self.delegate = nil;
    self.fileName = nil;
    self.poiTypes = nil;
    self.poiCategories = nil;
}

- (OAPOIType *)parsePoiType:(const xmlChar *)localname attributeCount:(int)attributeCount
                 attributes:(xmlSAX2Attributes *)attributes
{
    NSString *name = nil;
    NSString *tag = nil;
    NSString *value = nil;
    int order = 0;
    BOOL mapOnly = NO;
    BOOL reference = NO;
    
    for(int i = 0; i < attributeCount; i++)
    {
        if (0 == strncmp((const char*)attributes[i].localname, kNameAttributeName,
                         kNameAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            name = [[NSString alloc] initWithBytes:attributes[i].value
                                                      length:length
                                                    encoding:NSUTF8StringEncoding];
            if (0 == strncmp((const char *)localname, kPoiReferenceElementName, kPoiReferenceElementNameLength))
                reference = YES;
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kTagAttributeName,
                              kTagAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            tag = [[NSString alloc] initWithBytes:attributes[i].value
                                                     length:length
                                                   encoding:NSUTF8StringEncoding];
            
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kValueAttributeName,
                              kValueAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kMapAttributeName,
                              kMapAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            mapOnly = [[value lowercaseString] isEqualToString:@"true"];
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kOrderAttributeName,
                              kOrderAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            order = [value intValue];
        }
    }
    
    OAPOIType *poiType = [[OAPOIType alloc] initWithName:name category:_currentPOICategory];
    poiType.filter = _currentPOIFilter;
    poiType.tag = tag ? tag : _currentPOICategory.tag;
    poiType.value = value;
    poiType.reference = reference;
    poiType.mapOnly = mapOnly;
    poiType.order = order;

    [_pTypes addObject:poiType];
    
    // Category
    if (_currentPOICategory)
    {
        [_currentPOICategory addPoiType:poiType];
    }
    
    // Filter
    if (_currentPOIFilter)
    {
        [_currentPOIFilter addPoiType:poiType];
    }
    
    return poiType;
}

- (OAPOIType *)parsePoiAdditional:(const xmlChar *)localname attributeCount:(int)attributeCount
                 attributes:(xmlSAX2Attributes *)attributes
{
    if (!_currentPOICategory)
    {
        OAPOICategory *c = [[OAPOICategory alloc] initWithName:@"Other"];
        if ([_pCategories containsObject:c])
        {
            _currentPOICategory = _pCategories[[_pCategories indexOfObject:c]];
        }
        else
        {
            _currentPOICategory = c;
            [_pCategories addObject:_currentPOICategory];
        }        
    }
    
    NSString *name = nil;
    NSString *tag = nil;
    NSString *value = nil;
    int order = 0;
    BOOL mapOnly = NO;
    BOOL reference = NO;
    
    for(int i = 0; i < attributeCount; i++)
    {
        if (0 == strncmp((const char*)attributes[i].localname, kNameAttributeName,
                         kNameAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            name = [[NSString alloc] initWithBytes:attributes[i].value
                                                      length:length
                                                    encoding:NSUTF8StringEncoding];

            if (0 == strncmp((const char *)localname, kPoiReferenceElementName, kPoiReferenceElementNameLength))
                reference = YES;
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kTagAttributeName,
                              kTagAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            tag = [[NSString alloc] initWithBytes:attributes[i].value
                                                     length:length
                                                   encoding:NSUTF8StringEncoding];
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kValueAttributeName,
                              kValueAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kMapAttributeName,
                              kMapAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            mapOnly = [[value lowercaseString] isEqualToString:@"true"];
        }
        else if (0 == strncmp((const char*)attributes[i].localname, kOrderAttributeName,
                              kOrderAttributeNameLength))
        {
            int length = (int) (attributes[i].end - attributes[i].value);
            NSString *value = [[NSString alloc] initWithBytes:attributes[i].value
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            order = [value intValue];
        }
    }
    
    OAPOIType *poiType = [[OAPOIType alloc] initWithName:name category:_currentPOICategory];
    poiType.filter = _currentPOIFilter;
    poiType.tag = _currentPOICategory.tag;
    poiType.tag = tag ? tag : _currentPOICategory.tag;
    poiType.value = value;
    poiType.reference = reference;
    poiType.mapOnly = mapOnly;
    poiType.order = order;
    [poiType setAdditional:_currentPOIType ? _currentPOIType : (_currentPOIFilter ? _currentPOIFilter : _currentPOICategory)];
    
    if (_currentPOIType)
    {
        [_currentPOIType addPoiAdditional:poiType];
    }
    else if (_currentPOIFilter)
    {
        [_currentPOIFilter addPoiAdditional:poiType];
    }
    else if (_currentPOICategory)
    {
        [_currentPOICategory addPoiAdditional:poiType];
    }
    
    return poiType;
}

@end


#pragma mark SAX Parsing Callbacks

static void startElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix,
                            const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces,
                            int nb_attributes, int nb_defaulted, const xmlChar **attributes) {
    [((__bridge OAPOIParser *)ctx) elementFound:localname prefix:prefix uri:URI
                               namespaceCount:nb_namespaces namespaces:namespaces
                               attributeCount:nb_attributes defaultAttributeCount:nb_defaulted
                                   attributes:(xmlSAX2Attributes*)attributes];
}

static void	endElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix,
                          const xmlChar *URI) {
    [((__bridge OAPOIParser *)ctx) endElement:localname prefix:prefix uri:URI];
}

static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    [((__bridge OAPOIParser *)ctx) charactersFound:ch length:len];
}

static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    va_list argList;
    va_start(argList, msg);
    [((__bridge OAPOIParser *)ctx) parsingError:msg, argList];
}

static void endDocumentSAX(void *ctx) {
    [((__bridge OAPOIParser *)ctx) endDocument];
}

static xmlSAXHandler simpleSAXHandlerStruct = {
    NULL,                       /* internalSubset */
    NULL,                       /* isStandalone   */
    NULL,                       /* hasInternalSubset */
    NULL,                       /* hasExternalSubset */
    NULL,                       /* resolveEntity */
    NULL,                       /* getEntity */
    NULL,                       /* entityDecl */
    NULL,                       /* notationDecl */
    NULL,                       /* attributeDecl */
    NULL,                       /* elementDecl */
    NULL,                       /* unparsedEntityDecl */
    NULL,                       /* setDocumentLocator */
    NULL,                       /* startDocument */
    endDocumentSAX,             /* endDocument */
    NULL,                       /* startElement*/
    NULL,                       /* endElement */
    NULL,                       /* reference */
    charactersFoundSAX,         /* characters */
    NULL,                       /* ignorableWhitespace */
    NULL,                       /* processingInstruction */
    NULL,                       /* comment */
    NULL,                       /* warning */
    errorEncounteredSAX,        /* error */
    NULL,                       /* fatalError //: unused error() get all the errors */
    NULL,                       /* getParameterEntity */
    NULL,                       /* cdataBlock */
    NULL,                       /* externalSubset */
    XML_SAX2_MAGIC,             // initialized? not sure what it means just do it
    NULL,                       // private
    startElementSAX,            /* startElementNs */
    endElementSAX,              /* endElementNs */
    NULL,                       /* serror */
};

