//
//  Application.h
//  Dream
//
//  Created by Samuel Williams on 14/09/11.
//  Copyright 2011 Orion Transfer Ltd. All rights reserved.
//

#ifndef _DREAM_CLIENT_DISPLAY_UIKIT_APPLICATION_H
#define _DREAM_CLIENT_DISPLAY_UIKIT_APPLICATION_H

#include "../Application.h"

namespace Dream {
	namespace Client {
		namespace Display {
			namespace UIKit {
			
				class Application : public Object, implements IApplication {
					protected:
						REF(IApplicationDelegate) m_applicationDelegate;
						
					public:
						Application(PTR(IApplicationDelegate) delegate);
						virtual ~Application ();
						
						void run();
						
						virtual REF(IContext) createContext (REF(Dictionary) config);
						
						virtual IApplicationDelegate * delegate () const;
				};
			}
		}
	}
}

#endif
