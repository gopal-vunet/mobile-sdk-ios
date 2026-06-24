//
//  VULifecycleSwizzler.m
//  VuTelemetryBootstrap
//
//  Method swizzler for AppDelegate lifecycle timing capture
//

#import "VULifecycleSwizzler.h"
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <assert.h>
#import <objc/runtime.h>

#import "StartupTelemetry.h"

#import "VUObjCLogger.h"

#if __has_include(<UIKit/UIKit.h>)

// Internal setters (defined in StartupTelemetry.m)
extern void vu_set_will_finish_launching_begin_ns(uint64_t ns);
extern void vu_set_will_finish_launching_end_ns(uint64_t ns);
extern void vu_set_did_finish_launching_begin_ns(uint64_t ns);
extern void vu_set_did_finish_launching_end_ns(uint64_t ns);
extern void vu_set_scene_connection_begin_ns(uint64_t ns);
extern void vu_set_scene_connection_end_ns(uint64_t ns);

// Type definitions for the original method implementations
typedef BOOL (*AppDelegateMethodIMP)(id, SEL, UIApplication *, NSDictionary *);
typedef void (*SceneDelegateMethodIMP)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *);

// Finding #9: Per-class storage for AppDelegate original IMPs (instead of single globals)
static NSMutableDictionary<NSString *, NSValue *> *willFinishOriginalIMPs = nil;
static NSMutableDictionary<NSString *, NSValue *> *didFinishOriginalIMPs = nil;

// Finding #26: Per-class storage for scene delegate original implementations (synchronized access)
static NSMutableDictionary<NSString *, NSValue *> *sceneOriginalIMPs = nil;

// Finding #10: Plain C wrapper functions with correct IMP signature
static BOOL vu_willFinishLaunching_wrapper(id self, SEL _cmd, UIApplication *app, NSDictionary *opts) {
    vu_set_will_finish_launching_begin_ns(mach_absolute_time());

    NSString *className = [NSString stringWithUTF8String:class_getName([self class])];
    AppDelegateMethodIMP originalIMP = NULL;
    @synchronized(willFinishOriginalIMPs) {
        NSValue *impValue = willFinishOriginalIMPs[className];
        if (impValue) originalIMP = (AppDelegateMethodIMP)[impValue pointerValue];
    }

    BOOL result = originalIMP ? originalIMP(self, _cmd, app, opts) : YES;

    vu_set_will_finish_launching_end_ns(mach_absolute_time());
#if DEBUG
    VU_LOG("[VULifecycleSwizzler] willFinish captured begin=%llu end=%llu\n",
            vu_get_will_finish_launching_begin_ns(), vu_get_will_finish_launching_end_ns());
#endif
    return result;
}

static BOOL vu_didFinishLaunching_wrapper(id self, SEL _cmd, UIApplication *app, NSDictionary *opts) {
    VU_LOG("[VULifecycleSwizzler] didFinish ENTERED\n");

    vu_set_did_finish_launching_begin_ns(mach_absolute_time());

    NSString *className = [NSString stringWithUTF8String:class_getName([self class])];
    AppDelegateMethodIMP originalIMP = NULL;
    @synchronized(didFinishOriginalIMPs) {
        NSValue *impValue = didFinishOriginalIMPs[className];
        if (impValue) originalIMP = (AppDelegateMethodIMP)[impValue pointerValue];
    }

    BOOL result = originalIMP ? originalIMP(self, _cmd, app, opts) : YES;

    vu_set_did_finish_launching_end_ns(mach_absolute_time());
#if DEBUG
    VU_LOG("[VULifecycleSwizzler] didFinish captured begin=%llu end=%llu\n",
            vu_get_did_finish_launching_begin_ns(), vu_get_did_finish_launching_end_ns());
#endif
    VU_LOG("[VULifecycleSwizzler] didFinish EXITING with result=%d\n", result);
    return result;
}

static void vu_sceneWillConnect_wrapper(id self, SEL _cmd, UIScene *scene,
                                         UISceneSession *session,
                                         UISceneConnectionOptions *connectionOptions) {
    NSString *className = [NSString stringWithUTF8String:class_getName([self class])];
    SceneDelegateMethodIMP originalIMP = NULL;
    // Finding #26: Synchronized access to sceneOriginalIMPs
    @synchronized(sceneOriginalIMPs) {
        NSValue *impValue = sceneOriginalIMPs[className];
        if (impValue) originalIMP = (SceneDelegateMethodIMP)[impValue pointerValue];
    }

    if (vu_get_scene_connection_begin_ns() == 0) {
        vu_set_scene_connection_begin_ns(mach_absolute_time());
        if (originalIMP) {
            originalIMP(self, @selector(scene:willConnectToSession:options:), scene, session, connectionOptions);
        }
        vu_set_scene_connection_end_ns(mach_absolute_time());
        VU_LOG("[VULifecycleSwizzler] scene:willConnect captured begin=%llu end=%llu\n",
                vu_get_scene_connection_begin_ns(), vu_get_scene_connection_end_ns());
    } else {
        if (originalIMP) {
            originalIMP(self, @selector(scene:willConnectToSession:options:), scene, session, connectionOptions);
        }
    }
}

@implementation VULifecycleSwizzler

// Finding #25: Install scene swizzle on a specific class rather than scanning all ObjC classes
+ (void)installSceneSwizzlesOnAllSceneDelegates {
    if (@available(iOS 13.0, *)) {
        Protocol *sceneDelegateProtocol = @protocol(UIWindowSceneDelegate);
        int classCount = objc_getClassList(NULL, 0);
        if (classCount <= 0) {
            VU_LOG("[VULifecycleSwizzler] installSceneSwizzles: no classes found\n");
            return;
        }

        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * (size_t)classCount);
        if (classes == NULL) {
            return;
        }

        int swizzledCount = 0;
        classCount = objc_getClassList(classes, classCount);
        for (int i = 0; i < classCount; i++) {
            Class cls = classes[i];
            if (cls != Nil && class_conformsToProtocol(cls, sceneDelegateProtocol)) {
                VU_LOG("[VULifecycleSwizzler] Found scene delegate class: %s\n", class_getName(cls));
                [self installSceneConnectionOn:cls];
                swizzledCount++;
            }
        }

        if (swizzledCount == 0) {
            VU_LOG("[VULifecycleSwizzler] No explicit UIWindowSceneDelegate conformers found, checking common names...\n");
            NSArray *commonNames = @[@"SceneDelegate", @"UIWindowSceneDelegate"];
            for (NSString *className in commonNames) {
                Class cls = NSClassFromString(className);
                if (cls != Nil) {
                    VU_LOG("[VULifecycleSwizzler] Found by name: %s\n", class_getName(cls));
                    [self installSceneConnectionOn:cls];
                    swizzledCount++;
                }
            }
        }

        if (swizzledCount > 0) {
            VU_LOG("[VULifecycleSwizzler] Swizzled %d scene delegate class(es)\n", swizzledCount);
        }

        free(classes);
    }
}

+ (void)installOn:(Class)delegateClass {
    static NSMutableSet<NSString *> *installedClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        installedClasses = [NSMutableSet new];
        // Finding #9: Initialize per-class IMP dictionaries
        willFinishOriginalIMPs = [NSMutableDictionary new];
        didFinishOriginalIMPs = [NSMutableDictionary new];
    });

    NSString *classKey = [NSString stringWithFormat:@"%p", delegateClass];
    @synchronized(installedClasses) {
        if ([installedClasses containsObject:classKey]) {
            return;
        }
        [installedClasses addObject:classKey];
    }

    [self installWillFinishLaunchingOn:delegateClass];
    [self installDidFinishLaunchingOn:delegateClass];
    [self installSceneSwizzlesOnAllSceneDelegates];

    VU_LOG("[VULifecycleSwizzler] Installed on %s\n", class_getName(delegateClass));
}

// MARK: - willFinishLaunching Swizzle

+ (void)installWillFinishLaunchingOn:(Class)delegateClass {
    SEL originalSel = @selector(application:willFinishLaunchingWithOptions:);

    Method origMethod = class_getInstanceMethod(delegateClass, originalSel);

    VU_LOG("[VULifecycleSwizzler] installWillFinishLaunching on %s: origMethod=%s\n",
            class_getName(delegateClass), origMethod ? "found" : "NOT FOUND");

    if (origMethod) {
        AppDelegateMethodIMP origIMP = (AppDelegateMethodIMP)method_getImplementation(origMethod);
        NSString *className = [NSString stringWithUTF8String:class_getName(delegateClass)];
        @synchronized(willFinishOriginalIMPs) {
            willFinishOriginalIMPs[className] = [NSValue valueWithPointer:(const void *)origIMP];
        }

        // Guard against superclass poisoning: if delegateClass doesn't directly
        // implement this method, class_getInstanceMethod returns the superclass Method.
        // class_addMethod adds it on delegateClass only; if it already exists, it fails
        // and we can safely replace on the direct class.
        BOOL added = class_addMethod(delegateClass, originalSel,
                                     (IMP)vu_willFinishLaunching_wrapper,
                                     method_getTypeEncoding(origMethod));
        if (!added) {
            method_setImplementation(origMethod, (IMP)vu_willFinishLaunching_wrapper);
        }
        VU_LOG("[VULifecycleSwizzler] willFinishLaunching swizzle INSTALLED (added=%d)\n", added);
    } else {
        VU_LOG("[VULifecycleSwizzler] %s does not implement willFinishLaunchingWithOptions\n",
                class_getName(delegateClass));
    }
}

// MARK: - didFinishLaunching Swizzle

+ (void)installDidFinishLaunchingOn:(Class)delegateClass {
    SEL originalSel = @selector(application:didFinishLaunchingWithOptions:);

    Method origMethod = class_getInstanceMethod(delegateClass, originalSel);

    VU_LOG("[VULifecycleSwizzler] installDidFinishLaunching on %s: origMethod=%s\n",
            class_getName(delegateClass), origMethod ? "found" : "NOT FOUND");

    if (origMethod) {
        AppDelegateMethodIMP origIMP = (AppDelegateMethodIMP)method_getImplementation(origMethod);
        NSString *className = [NSString stringWithUTF8String:class_getName(delegateClass)];
        @synchronized(didFinishOriginalIMPs) {
            didFinishOriginalIMPs[className] = [NSValue valueWithPointer:(const void *)origIMP];
        }

        BOOL added = class_addMethod(delegateClass, originalSel,
                                     (IMP)vu_didFinishLaunching_wrapper,
                                     method_getTypeEncoding(origMethod));
        if (!added) {
            method_setImplementation(origMethod, (IMP)vu_didFinishLaunching_wrapper);
        }
        VU_LOG("[VULifecycleSwizzler] didFinishLaunching swizzle INSTALLED (added=%d)\n", added);
    } else {
        VU_LOG("[VULifecycleSwizzler] %s does not implement didFinishLaunchingWithOptions\n",
                class_getName(delegateClass));
    }
}

// MARK: - scene:willConnectToSession:options: Swizzle (iOS 13+)

+ (void)installSceneConnectionOn:(Class)delegateClass {
    if (@available(iOS 13.0, *)) {
        SEL originalSel = @selector(scene:willConnectToSession:options:);

        Method origMethod = class_getInstanceMethod(delegateClass, originalSel);

        if (origMethod) {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                sceneOriginalIMPs = [NSMutableDictionary new];
            });

            SceneDelegateMethodIMP originalIMP = (SceneDelegateMethodIMP)method_getImplementation(origMethod);
            NSString *className = [NSString stringWithUTF8String:class_getName(delegateClass)];
            // Finding #26: Synchronized access
            @synchronized(sceneOriginalIMPs) {
                sceneOriginalIMPs[className] = [NSValue valueWithPointer:(const void *)originalIMP];
            }
            VU_LOG("[VULifecycleSwizzler] Saved original_sceneWillConnect IMP for %s: %p\n",
                    class_getName(delegateClass), originalIMP);

            BOOL added = class_addMethod(delegateClass, originalSel,
                                         (IMP)vu_sceneWillConnect_wrapper,
                                         method_getTypeEncoding(origMethod));
            if (!added) {
                method_setImplementation(origMethod, (IMP)vu_sceneWillConnect_wrapper);
            }
            VU_LOG("[VULifecycleSwizzler] Installed scene:willConnectToSession on %s (added=%d)\n",
                    class_getName(delegateClass), added);
        } else {
            VU_LOG("[VULifecycleSwizzler] Scene delegate %s does not implement scene:willConnectToSession\n",
                    class_getName(delegateClass));
        }
    }
}

@end
#endif
