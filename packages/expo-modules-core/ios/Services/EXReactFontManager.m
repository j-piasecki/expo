// Copyright 2018-present 650 Industries. All rights reserved.

#import <objc/runtime.h>
#import <React/RCTFont.h>

#import <ExpoModulesCore/EXDefines.h>
#import <ExpoModulesCore/EXReactFontManager.h>
#import <ExpoModulesCore/EXFontProcessorInterface.h>
#import <ExpoModulesCore/EXFontManagerInterface.h>
#import <ExpoModulesCore/EXAppLifecycleService.h>

static dispatch_once_t initializeCurrentFontProcessorsOnce;

static NSPointerArray *currentFontProcessors;

@implementation RCTFont (EXReactFontManager)

+ (UIFont *)EXUpdateFont:(UIFont *)uiFont
              withFamily:(NSString *)family
                    size:(NSNumber *)size
                  weight:(NSString *)weight
                   style:(NSString *)style
                 variant:(NSArray<NSDictionary *> *)variant
         scaleMultiplier:(CGFloat)scaleMultiplier
{
  UIFont *font;
  // Here, we extend a broken React Native function that has thread saftey issues,
  // if the app is reloaded multiple times, it has increased potential of crashing due to:
  // `Thread 163: "*** Collection <NSConcretePointerArray: 0x600003088000> was mutated while being enumerated."`
  // https://github.com/facebook/react-native/blob/1ecd98adc7b18504600fc7e9d56c7b4c9a090abd/Libraries/Text/RCTTextAttributes.m#L195
  // For now, we'll skip over the array's enumerator, and use a for-in loop.
  for (int i = 0; i < currentFontProcessors.count; i++) {
    id<EXFontProcessorInterface> fontProcessor = [currentFontProcessors pointerAtIndex:i];
    font = [fontProcessor updateFont:uiFont withFamily:family size:size weight:weight style:style variant:variant scaleMultiplier:scaleMultiplier];
    if (font) {
      return font;
    }
  }

  return [self EXUpdateFont:uiFont withFamily:family size:size weight:weight style:style variant:variant scaleMultiplier:scaleMultiplier];
}

@end

/**
 * This class is responsible for allowing other modules to register as font processors in React Native.
 *
 * A font processor is an object conforming to EXFontProcessorInterface and is capable of
 * providing an instance of UIFont for given (family, size, weight, style, variant, scaleMultiplier).
 *
 * To be able to hook into React Native's way of processing fonts we:
 *  - add a new class method to RCTFont, `EXUpdateFont:withFamily:size:weight:style:variant:scaleMultiplier`
 *    with EXReactFontManager category.
 *  - add a new static variable `currentFontProcessors` holding an array of... font processors. This variable
 *    is shared between the RCTFont's category and EXReactFontManager class.
 *  - when EXReactFontManager is initialized, we exchange implementations of RCTFont.updateFont...
 *    and RCTFont.EXUpdateFont... After the class initialized, which happens only once, calling `RCTFont updateFont`
 *    calls in fact implementation we've defined up here and calling `RCTFont EXUpdateFont` falls back
 *    to the default implementation. (This is why we call `[self EXUpdateFont]` at the end of that function,
 *    though it seems like an endless loop, in fact we dispatch to another implementation.)
 *  - When some module adds a font processor using EXFontManagerInterface, EXReactFontManager adds a weak pointer to it
 *    to currentFontProcessors array.
 *  - Implementation logic of `RCTFont.EXUpdateFont` uses current value of currentFontProcessors when processing arguments.
 */

@interface EXReactFontManager ()

@property (nonatomic, strong) NSMutableSet *fontProcessors;

@end

@implementation EXReactFontManager

EX_REGISTER_MODULE();

- (instancetype)init
{
  if (self = [super init]) {
    _fontProcessors = [NSMutableSet set];
  }
  return self;
}

+ (const NSArray<Protocol *> *)exportedInterfaces
{
  return @[@protocol(EXFontManagerInterface)];
}

+ (void)initialize
{
  dispatch_once(&initializeCurrentFontProcessorsOnce, ^{
    currentFontProcessors = [NSPointerArray weakObjectsPointerArray];
  });

  Class rtcClass = [RCTFont class];
  SEL rtcUpdate = @selector(updateFont:withFamily:size:weight:style:variant:scaleMultiplier:);
  SEL exUpdate = @selector(EXUpdateFont:withFamily:size:weight:style:variant:scaleMultiplier:);
  
  method_exchangeImplementations(class_getClassMethod(rtcClass, rtcUpdate),
                                 class_getClassMethod(rtcClass, exUpdate));
}

# pragma mark - EXFontManager

- (void)addFontProcessor:(id<EXFontProcessorInterface>)processor
{
  [_fontProcessors addObject:processor];
  [currentFontProcessors compact];
  [currentFontProcessors addPointer:(__bridge void * _Nullable)(processor)];
}

@end
