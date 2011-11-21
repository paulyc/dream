/*
 *  Assertion.h
 *  This file is part of the "Dream" project, and is licensed under the GNU GPLv3.
 *
 *  Created by Samuel Williams on 26/10/08.
 *  Copyright 2008 Samuel Williams. All rights reserved.
 *
 */

#ifndef _DREAM_ASSERTION_H
#define _DREAM_ASSERTION_H

#include <string>
#include <exception>

/// Similar to assert, however will throw an AssertionError on failure.
#define ensure(e) ::Dream::AssertionError::assertHandler(e, #e, __FILE__, __LINE__)

/// Similar to ensure, but works statically, e.g. on consts, template arguments, etc.
#define static_ensure(e) ::Dream::StaticAssertion<(e) != 0>::failed()

namespace Dream
{
	/**
	 An exception class that indicates a failed assertion.

	 Use the ensure() macro in your code:

	 @code
	 ensure(myCondition)
	 @endcode
	 */
	class AssertionError : public std::exception
	{
		const char * m_expression;
		const char * m_file;
		unsigned m_line;

		std::string m_what;
	public:
		AssertionError (const char * expression, const char * file, unsigned line) throw ();
		virtual ~AssertionError () throw ();

		/// A descriptive string relating to the assertion that failed.
		virtual const char * what () const throw ();

		/// The ensure() macro calls this function to handle throwing the actual exception.
		static void assertHandler (bool condition, const char * expression, const char * file, unsigned line);
	};
	
	/// Simple static assertion implementation
	template <bool>
	class StaticAssertion {
	public:
		static void failed() {}
	};
	
	template<>
	class StaticAssertion<false> {
	};	
}

#endif