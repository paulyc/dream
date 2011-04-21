/*
 *  CocoaContext.mm
 *  Dream
 *
 *  Created by Samuel Williams on 27/03/07.
 *  Copyright 2007 Samuel Williams. All rights reserved.
 *
 */

// Exclude quickdraw.
#define __INCLUDE_QD__

#include "Application.h"
#include "Context.h"

#include "CocoaContext.h"
#import <Cocoa/Cocoa.h>

#include "Renderer.h"

#import <CoreVideo/CoreVideo.h>
#import <CoreVideo/CVDisplayLink.h>

#import "CocoaContextDelegate.h"

@interface NSAppleMenuController : NSObject
- (void)controlMenu:(NSMenu *)aMenu;
@end

namespace Dream
{
	namespace Client
	{
		namespace Display
		{
			
			void IApplication::start (IApplication::Class * appKlass, PTR(Dictionary) config)
			{
				REF(IApplication) app = appKlass->init(config);
				
				app->run();
			}
			
#pragma mark -
#pragma mark Renderer Subclass
			
			typedef OpenGL20::Renderer MacOSXOpenGLRenderer;
			
#pragma mark -
			
			IMPLEMENT_CLASS(CocoaContext)
			
			struct CocoaContext::CocoaContextImpl {
				CocoaContextImpl () : displayWillRefresh(false), displayRefreshStallCount(0) {}
				
				REF(MacOSXOpenGLRenderer) renderer;
				
				NSWindow * window;
				NSOpenGLView * view;
				NSAutoreleasePool * pool;
				CocoaContextDelegate * delegate;
				
				//display link for managing rendering thread
				CVDisplayLinkRef displayLink;
				bool displayWillRefresh;
				unsigned displayRefreshStallCount;
				
				REF(FrameNotificationSource) notificationSource;
				REF(Events::Loop) loop;
				
				static CVReturn displayLinkCallback (CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, 
													 CVOptionFlags* flagsOut, void* displayLinkContext);
			};
			
			// This is the renderer output callback function
			CVReturn CocoaContext::CocoaContextImpl::displayLinkCallback (CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, 
																		  CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
			{
				CocoaContext::CocoaContextImpl * ctx = (CocoaContext::CocoaContextImpl*)displayLinkContext;
				
				if (ctx->displayWillRefresh == true) {
					ctx->displayRefreshStallCount += 1;
					
					if (ctx->displayRefreshStallCount % 500 == 100)
						std::cerr << __func__ << ": Pipeline stalled (" << ctx->displayRefreshStallCount << ")..." << std::endl;
				} else {
					// Only warn when stall is large
					if (ctx->displayRefreshStallCount > 5)
						std::cerr << __func__ << ": Display stalled for " << ctx->displayRefreshStallCount << " frame(s)" << std::endl;
					
					ctx->displayRefreshStallCount = 0;
					ctx->displayWillRefresh = true;
				}
				
				TimeT time = (TimeT)(outputTime->hostTime) / (TimeT)CVGetHostClockFrequency();			
				ensure(ctx->notificationSource);
				ctx->notificationSource->frameCallback(ctx->loop.get(), time);
				
				return 0;
			}
			
			CocoaContext::Class::Class() : IContext::Class(25)
			{
			
			}
			
			REF(IContext) CocoaContext::Class::init (PTR(Dictionary) config)
			{
				return new CocoaContext(config);
			}
			
			NSString * getApplicationName ()
			{
				NSDictionary * dict;
				NSString * appName = 0;

				/* Determine the application name */
				dict = (NSDictionary *)CFBundleGetInfoDictionary(CFBundleGetMainBundle());
				if (dict)
					appName = [dict objectForKey:@"CFBundleName"];
				
				if (![appName length])
					appName = [[NSProcessInfo processInfo] processName];

				return appName;
			}

			void createApplicationMenus ()
			{
				NSString *appName;
				NSString *title;
				NSMenu *appleMenu;
				NSMenu *windowMenu;
				NSMenuItem *menuItem;
				
				/* Create the main menu bar */
				[NSApp setMainMenu:[[NSMenu alloc] init]];

				/* Create the application menu */
				appName = getApplicationName();
				appleMenu = [[NSMenu alloc] initWithTitle:@""];
				
				/* Add menu items */
				title = [@"About " stringByAppendingString:appName];
				[appleMenu addItemWithTitle:title action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

				[appleMenu addItem:[NSMenuItem separatorItem]];

				title = [@"Hide " stringByAppendingString:appName];
				[appleMenu addItemWithTitle:title action:@selector(hide:) keyEquivalent:@/*"h"*/""];

				menuItem = (NSMenuItem *)[appleMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@/*"h"*/""];
				[menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask|NSCommandKeyMask)];

				[appleMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

				[appleMenu addItem:[NSMenuItem separatorItem]];

				title = [@"Quit " stringByAppendingString:appName];
				[appleMenu addItemWithTitle:title action:@selector(terminate:) keyEquivalent:@/*"q"*/""];
				
				/* Put menu into the menubar */
				menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
				[menuItem setSubmenu:appleMenu];
				[[NSApp mainMenu] addItem:menuItem];
				[menuItem release];

				/* Tell the application object that this is now the application menu */
				[NSApp setAppleMenu:appleMenu];
				[appleMenu release];

				/* Create the window menu */
				windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
				
				/* "Minimize" item */
				menuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@/*"m"*/""];
				[windowMenu addItem:menuItem];
				[menuItem release];
				
				/* Put menu into the menubar */
				menuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
				[menuItem setSubmenu:windowMenu];
				[[NSApp mainMenu] addItem:menuItem];
				[menuItem release];
				
				/* Tell the application object that this is now the window menu */
				[NSApp setWindowsMenu:windowMenu];
				[windowMenu release];
			}

			void transformToForegroundApplication ()
			{
				ProcessSerialNumber psn;
				
				if (!GetCurrentProcess(&psn)) {
					TransformProcessType(&psn, kProcessTransformToForegroundApplication);
					SetFrontProcess(&psn);
				}
			}
			
			void CocoaContext::setTitle (String title) {
				NSString * windowTitle = [[NSString alloc] initWithBytes:title.data() length:title.length() encoding:NSUTF8StringEncoding];
				
				[m_impl->window setTitle:windowTitle];

				[windowTitle release];
			}
			
			void CocoaContext::show () {
				[m_impl->window makeKeyAndOrderFront:nil];
			}
			
			void CocoaContext::hide () {
				
			}
			
			void CocoaContext::setFrameSync (bool vsync) {
				GLint swapInt = vsync ? 1 : 0;
				
				std::cerr << "VSync = " << vsync << std::endl;
				
				[[m_impl->view openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
			}
			
			CocoaContext::CocoaContext (PTR(Dictionary) config) {
				m_impl = new CocoaContextImpl;
				m_impl->pool = [[NSAutoreleasePool alloc] init];

				[NSApplication sharedApplication];
				
				NSWindow * configWindow = NULL;
				if (config->get("CocoaContext.Window", configWindow)) {
					m_impl->window = configWindow;
				} else {
					transformToForegroundApplication();
					
					if ([NSApp mainMenu] == nil)
						createApplicationMenus();
				
					NSRect windowSize = NSMakeRect(50, 50, 1024, 768);
					unsigned windowStyle = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;

					m_impl->window = [[NSWindow alloc] initWithContentRect:windowSize styleMask:windowStyle backing:NSBackingStoreBuffered defer:YES];
					[m_impl->window setAcceptsMouseMovedEvents:YES];
					
					m_impl->delegate = [CocoaContextDelegate new];
					
					if ([NSApp delegate] == nil) {
						[NSApp setDelegate:m_impl->delegate];
					}
					
					[m_impl->window setDelegate:m_impl->delegate];
					
					[NSApp finishLaunching];
				}
				
				NSOpenGLView * graphicsView = NULL;
				if (config->get("CocoaContext.View", graphicsView)) {
					m_impl->view = graphicsView;
				} else {
					NSOpenGLPixelFormatAttribute attribs[] = {
						NSOpenGLPFAWindow,
						NSOpenGLPFADoubleBuffer,	// double buffered
						NSOpenGLPFAAccelerated,
						NSOpenGLPFANoRecovery,
						/* Anti-aliasing */
						//NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)3, /* 3 looks awsome */
						//NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)4,
						/* --- --- --- */
						NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)24,
						NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute)32,
						(NSOpenGLPixelFormatAttribute)nil
					};

					NSOpenGLPixelFormat * pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
					
					graphicsView = [[[NSOpenGLView alloc] initWithFrame:[[m_impl->window contentView] frame] pixelFormat:pf] autorelease];
					m_impl->view = graphicsView;
					
					[graphicsView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];				

					//[[m_impl->window contentView] addSubview:graphicsView];
					[m_impl->window setContentView:graphicsView];
				}
				
				// ***** SETUP CVDisplayLink *****
				// Synchronize buffer swaps with vertical refresh rate
				setFrameSync(true);
				
				// Create a display link capable of being used with all active displays
				CVDisplayLinkCreateWithActiveCGDisplays(&m_impl->displayLink);
				
				// Set the renderer output callback function
				CVDisplayLinkSetOutputCallback(m_impl->displayLink, &CocoaContextImpl::displayLinkCallback, m_impl);
				
				// Set the display link for the current renderer
				CGLContextObj cglContext = (CGLContextObj)[[graphicsView openGLContext] CGLContextObj];
				CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[graphicsView pixelFormat] CGLPixelFormatObj];
				CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(m_impl->displayLink, cglContext, cglPixelFormat);
				
				// OpenGL Defaults:
				glEnable(GL_DEPTH_TEST);
				
				// Tight alignment
				glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
				glPixelStorei(GL_PACK_ALIGNMENT, 1);
				
				//glPolygonOffset (1.0f, 1.0f);
				
				m_impl->renderer = new MacOSXOpenGLRenderer();
				
				std::cerr << "OpenGL Context Initialized..." << std::endl;
				std::cerr << "OpenGL Vendor: " << glGetString(GL_VENDOR) << std::endl;
				std::cerr << "OpenGL Renderer: " << glGetString(GL_RENDERER) << " " << glGetString(GL_VERSION) << std::endl;
			}
			
			CocoaContext::~CocoaContext () {
				CVDisplayLinkStop(m_impl->displayLink);
				CVDisplayLinkRelease(m_impl->displayLink);
				
				[m_impl->window release];
				[m_impl->pool release];
				
				delete m_impl;
			}
			
			unsigned buttonFromEvent (NSEvent * theEvent)
			{
				NSEventType t = [theEvent type];
								
				if (t == NSLeftMouseDown || t == NSLeftMouseUp || t == NSLeftMouseDragged) {
					if ([theEvent modifierFlags] & NSControlKeyMask)
						return MouseRightButton;
					
					return MouseLeftButton;
				}
				
				if (t == NSRightMouseDown || t == NSRightMouseUp || t == NSRightMouseDragged)
					return MouseRightButton;
				
				return [theEvent buttonNumber];
			}
			
			bool handleMouseEvent (NSEvent * theEvent, unsigned button, IInputHandler * handler)
			{
				Vec3 position, movement;
				
				if ([theEvent type] != NSScrollWheel)
				{
					//NSPoint curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
					NSPoint curPoint = [theEvent locationInWindow];
					
					position[X] = curPoint.x;
					position[Y] = curPoint.y;
					position[Z] = 0;
				}
				
				movement[X] = [theEvent deltaX];
				movement[Y] = [theEvent deltaY];
				movement[Z] = [theEvent deltaZ];
				
				StateT state;
				NSEventType t = [theEvent type];
				
				if (t == NSLeftMouseDown || t == NSRightMouseDown || t == NSOtherMouseDown)
					state = Pressed;
				else if (t == NSLeftMouseDragged || t == NSRightMouseDragged || t == NSOtherMouseDragged)
					state = Dragged;
				else
					state = Released;
							
				Key key(DefaultMouse, button);
				MotionInput ipt(key, state, position, movement);
				
				return handler->process(ipt);
			}
			
			ResolutionT CocoaContext::resolution ()
			{
				NSSize size = [m_impl->view frame].size;
				
				return ResolutionT(size.width, size.height);
			}
			
			void CocoaContext::flipBuffers ()
			{
				//if (m_impl->displayWillRefresh != true)
				//	std::cerr << __func__ << ": Frame will not be displayed!" << std::endl;
				
				m_impl->displayWillRefresh = false;
				
				[[m_impl->view openGLContext] flushBuffer];
			}
			
			void CocoaContext::processPendingEvents (IInputHandler * handler)
			{
				CocoaContextDelegate * delegate = m_impl->delegate;
				[delegate setInputHandler:handler];
			
				while (true) {
					NSEvent * e = [[NSApplication sharedApplication] nextEventMatchingMask:NSAnyEventMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];					
					if (e == NULL) return;
					
					bool consumed = false;
				
					NSView * v = [m_impl->view hitTest:[e locationInWindow]];
				
					if ([e type] == NSKeyDown) {
						Key key(DefaultKeyboard, [[e characters] characterAtIndex:0]);
						ButtonInput ipt(key, Pressed);
						
						// If the key is processed, don't pass it on.
						if (handler->process(ipt))
							continue;
						
						consumed = true;
					} else if ([e type] == NSKeyUp) {
						Key key(DefaultKeyboard, [[e characters] characterAtIndex:0]);
						ButtonInput ipt(key, Released);
						
						// If the key is processed, don't pass it on.
						if (handler->process(ipt))
							continue;
						
						consumed = true;
					} else if (v) {
						switch ([e type]) {
							case NSLeftMouseDown:
							case NSLeftMouseUp:
							case NSLeftMouseDragged:
							case NSRightMouseDown:
							case NSRightMouseUp:
							case NSRightMouseDragged:
							case NSOtherMouseDown:
							case NSOtherMouseUp:
							case NSOtherMouseDragged:
								if (handleMouseEvent(e, buttonFromEvent(e), handler)) continue;
								consumed = true;
								break;
							case NSScrollWheel:
								if (handleMouseEvent(e, MouseScroll, handler)) continue;
								consumed = true;
								break;
							case NSMouseMoved:
								if (handleMouseEvent(e, NullButton, handler)) continue;
								consumed = true;
								break;
							case NSMouseEntered:
								if (handleMouseEvent(e, MouseEntered, handler)) continue;
								consumed = true;
								break;
							case NSMouseExited:
								if (handleMouseEvent(e, MouseExited, handler)) continue;
								consumed = true;
								break;
						}
					}
					
					// Event Debugging
					//if (!consumed)
					//	NSLog(@"Event Not Consumed: %@", e);
					
					[NSApp sendEvent:e];
				}
				
				[delegate setInputHandler:nil];
			}
		
			void CocoaContext::scheduleFrameNotificationCallback (REF(Events::Loop) loop, FrameCallbackT callback)
			{
				// We stop the display link initially,
				CVDisplayLinkStop(m_impl->displayLink);
				
				if (callback) {
					// Setup the notification source
					if (!m_impl->notificationSource)
						m_impl->notificationSource = new FrameNotificationSource(callback);
					else
						m_impl->notificationSource->setCallback(callback);
				
					m_impl->loop = loop;
					m_impl->displayWillRefresh = false;
					
					// Start the display link
					CVDisplayLinkStart(m_impl->displayLink);
				}					
			}
			
			REF(MacOSXOpenGLRenderer) CocoaContext::renderer ()
			{
				return m_impl->renderer;
			}

		}
	}
}
