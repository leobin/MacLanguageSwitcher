//
//  GLSAppDelegate.m
//  LanguageSwitcher
//
//  Created by Tran Nguyen Ngoc Huy on 7/15/14.
//  Copyright (c) 2014 learn. All rights reserved.
//

#import "GLSAppDelegate.h"

@interface GLSAppDelegate ()
@property (weak) IBOutlet NSTextField *CurrentApplicationName;
@property (weak) IBOutlet NSButton *AddButton;
@end
@implementation GLSAppDelegate {
    NSString *previousAppName;
    NSMutableArray *listApplication;
    NSUserDefaults *_userDefaults;
    __weak NSButton *_AddButton;
    __weak NSTextField *_CurrentApplicationName;
    TISInputSourceRef _inputSource;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _userDefaults = [NSUserDefaults standardUserDefaults];
    [_AddButton setTarget:self];
    [_AddButton setAction:@selector(addNewApp)];

    // Insert code here to initialize your application
    // ------------------------------------------------------------
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(observer_NSWorkspaceDidActivateApplicationNotification:)
                                                               name:NSWorkspaceDidActivateApplicationNotification
                                                             object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(distributedObserver_kTISNotifyEnabledKeyboardInputSourcesChanged:)
                                                            name:(NSString*)(kTISNotifyEnabledKeyboardInputSourcesChanged)
                                                          object:nil
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(distributedObserver_kTISNotifySelectedKeyboardInputSourceChanged:)
                                                            name:(NSString*)(kTISNotifySelectedKeyboardInputSourceChanged)
                                                          object:nil
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}

- (void)addNewApp{
    if (![listApplication containsObject:previousAppName]) {
        [listApplication addObject:previousAppName];
        [_userDefaults setObject:previousAppName forKey:@"list_app_vn"];
    }
}

- (void) distributedObserver_kTISNotifyEnabledKeyboardInputSourcesChanged:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
    });
}


// ------------------------------------------------------------
- (void) observer_NSWorkspaceDidActivateApplicationNotification:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* name = [GLSAppDelegate getActiveApplicationName];
        if (name) {
            NSLog(@"%@ \n", name);
//            NSArray *listName = @[@""]
            // We ignore our investigation application.
            if (! [name isEqualToString:@"com.gapt.LanguageSwitcher"]) {
                NSString* inputSourceId= [_userDefaults objectForKey:name];
                if (inputSourceId != nil){
                    [self changeToInputSourceId:inputSourceId];
                } else {
                    [self changeToInputSourceId:@"org.unknown.keylayout.NoSpecialt"];
                }
                @synchronized (self) {
                    previousAppName = name;
                    [_CurrentApplicationName setStringValue:previousAppName];
                }
            }
        }
    });
}

+ (NSString*) getActiveApplicationName
{
    // ----------------------------------------
    NSWorkspace* ws = [NSWorkspace sharedWorkspace];
    if (! ws) return nil;

    NSArray* a = [ws runningApplications];
    if (! a) return nil;

    for (NSRunningApplication* app in a) {
        if (! app) return nil;

        if ([app isActive]) {
            NSString* nsappname = [app bundleIdentifier];

            if (nsappname) {
                return [NSString stringWithString:nsappname];

            } else {
                // We use localizedName instead of bundleIdentifier,
                // because "MacSOUP" doesn't have bundleIdentifier.
                // http://www.haller-berlin.de/macsoup/index.html
                NSString* localizedName = [app localizedName];
                if (localizedName) {
                    return [NSString stringWithFormat:@"org.pqrs.unknownapp.%@", localizedName];
                }
            }
        }
    }

    return nil;
}

- (void) distributedObserver_kTISNotifySelectedKeyboardInputSourceChanged:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _inputSource = TISCopyCurrentKeyboardInputSource();
        NSString* inputSourceId =(__bridge NSString *) TISGetInputSourceProperty(_inputSource, kTISPropertyInputSourceID);
        NSLog(@"%@ \n", inputSourceId);
        [_userDefaults setObject:inputSourceId forKey:previousAppName];
    });
}

-(void)changeToInputSourceId:(NSString *)inputSource{
    @synchronized(self) {

        CFArrayRef list = NULL;
        CFDictionaryRef filter = NULL;
        // ----------------------------------------
        // Making filter
        const void *keys[] = {
//                kTISPropertyInputSourceID,
                kTISPropertyInputSourceCategory,
        };
        const void *values[] = {
//                kCFBooleanTrue,
                kTISCategoryKeyboardInputSource,
        };
        filter = CFDictionaryCreate(NULL, keys, values, sizeof(keys) / sizeof(keys[0]), NULL, NULL);
        if (!filter) goto finish;

        // ----------------------------------------
        // Making list
        list = TISCreateInputSourceList(filter, false);
        if (!list) goto finish;

        for (int i = 0; i < CFArrayGetCount(list); ++i) {
            TISInputSourceRef source = (TISInputSourceRef) (CFArrayGetValueAtIndex(list, i));
            if (!source) continue;

            // ----------------------------------------
            // Skip inappropriate input sources.
            //
            // - com.apple.inputmethod.ironwood (Voice Input)

            NSString *sourceID = (__bridge NSString *) (TISGetInputSourceProperty(source, kTISPropertyInputSourceID));
            if ([sourceID isEqualToString:inputSource]) {
                TISSelectInputSource(source);
            }

        }
        finish:
        if (filter) {
            CFRelease(filter);
        }
        if (list) {
            CFRelease(list);
        }
    }
}

@end
