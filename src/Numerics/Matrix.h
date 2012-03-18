//
//  Numerics/Matrix.h
//  This file is part of the "Dream" project, and is released under the MIT license.
//
//  Created by Samuel Williams on 13/03/06.
//  Copyright (c) 2006 Samuel Williams. All rights reserved.
//
//

#ifndef _DREAM_NUMERICS_MATRIX_H
#define _DREAM_NUMERICS_MATRIX_H

#include "Numerics.h"

#include "Vector.h"
#include <algorithm>

namespace Dream
{
	namespace Numerics
	{
		template <unsigned, unsigned, typename>
		class Matrix;

#pragma mark -
#pragma mark Matrix Multiplication Traits

		template <unsigned R, unsigned C, typename NumericT>
		class MatrixMultiplicationTraits
		{
		private:
			typedef Matrix<R, C, NumericT> MatrixT;

		public:
			Vector<C, NumericT> multiply (const Vector<R, NumericT> & v) const;

			template <unsigned T>
			Matrix<T, C, NumericT> multiply (const Matrix<T, R, NumericT> & m) const;
			
			/// Short-hand notation
			Vector<C, NumericT> operator* (const Vector<R, NumericT> & v) const
			{
				return this->multiply(v);
			}
			
			/// Short-hand notation for non-homogeneous vectors
			Vector<C-1, NumericT> operator* (const Vector<R-1, NumericT> & v) const
			{
				Vector<C, NumericT> result (this->multiply(v << 1));
				
				result /= result[C-1];
				
				return result.reduce();
			}
			
			/// Short hand for matrix multiplication
			template <unsigned T>
			Matrix<T, C, NumericT> operator* (const Matrix<T, R, NumericT> & other) const
			{
				return this->multiply(other);
			}
		};

#pragma mark -
#pragma mark Matrix Inverse Traits

		template <unsigned R, unsigned C, typename NumericT>
		class MatrixInverseTraits
		{
		};

		template <typename NumericT>
		class MatrixInverseTraits<4, 4, NumericT>
		{
		private:
			typedef Matrix<4, 4, NumericT> MatrixT;

			inline const NumericT * values () const;

		public:
			Matrix<4, 4, NumericT> inverse_matrix () const;
		};

#pragma mark -
#pragma mark Matrix Square Traits

		template <unsigned R, unsigned C, typename NumericT>
		class MatrixSquareTraits
		{};

		template <unsigned N, typename NumericT>
		class MatrixSquareTraits<N, N, NumericT>
		{
		private:
			typedef Matrix<N, N, NumericT> MatrixT;

		public:
			template <unsigned K>
			static MatrixT scaling_matrix (const Vector<K, NumericT> & amount);

			template <unsigned K>
			static MatrixT translating_matrix (const Vector<K, NumericT> & amount);

			// Rotations in 3D.
			static MatrixT rotating_matrix (const NumericT & radians, const Vector<3, NumericT> & normal);
			static MatrixT rotating_matrix (const NumericT & radians, const Vector<3, NumericT> & normal, const Vector<3, NumericT> & point);
			static MatrixT rotating_matrix (const Vector<3, NumericT> & from, const Vector<3, NumericT> & to, const Vector<3, NumericT> & normal);

			// Rotations in 2D.
			static MatrixT rotating_matrix_around_x (const NumericT & radians);
			static MatrixT rotating_matrix_around_y (const NumericT & radians);
			/// Also works for Matrix<2,2>
			static MatrixT rotating_matrix_around_z (const NumericT & radians);

			// Convenience Functions
			MatrixT rotated_matrix (const NumericT & radians, const Vector<3, NumericT> & normal);
			MatrixT rotated_matrix (const NumericT & radians, const Vector<3, NumericT> & normal, const Vector<3, NumericT> & point);

			template <unsigned K>
			MatrixT scaled_matrix (const Vector<K, NumericT> & amount);

			template <unsigned K>
			MatrixT translated_matrix (const Vector<K, NumericT> & amount);

			/// In-place transposition (transpose_matrix)
			MatrixT & transpose ();
		};

#pragma mark -

		template <unsigned R, unsigned C, typename NumericT>
		class MatrixEqualityTraits
		{
		};

		template <unsigned R, unsigned C>
		class MatrixEqualityTraits<R, C, float>
		{
		protected:
			typedef Matrix<R, C, float> MatrixT;

		public:
			bool equal_within_tolerance (const MatrixT & other, const unsigned & ulps = DEFAULT_ULPS) const;
		};

		template <unsigned R, unsigned C>
		class MatrixEqualityTraits<R, C, double>
		{
		protected:
			typedef Matrix<R, C, double> MatrixT;

		public:
			bool equal_within_tolerance (const MatrixT & other, const unsigned & ulps = DEFAULT_ULPS) const;
		};

#pragma mark -
#pragma mark Matrix Class

		unsigned row_major_offset(unsigned row, unsigned col, unsigned sz);
		unsigned column_major_offset(unsigned row, unsigned col, unsigned sz);

		/** A 2-dimentional set of numbers that can represent useful transformations in n-space.
		
		Standard mathematical notation is column order, therefore regardless of row-major or column-major memory layout,
		the interface will assume access is done via rows and columns according to this standard notation.
		 */
		template <unsigned _R = 4, unsigned _C = 4, typename _NumericT = RealT>
		class Matrix : public MatrixSquareTraits<_R, _C, _NumericT>, public MatrixMultiplicationTraits<_R, _C, _NumericT>,
					   public MatrixInverseTraits<_R, _C, _NumericT>, public MatrixEqualityTraits<_R, _C, _NumericT>
		{
		public:
			enum { R = _R };
			enum { C = _C };
			typedef _NumericT NumericT;

		protected:
			NumericT _matrix[R*C];
		
		public:
			// Uninitialized constructor
			Matrix ();
			Matrix (const Zero &);
			Matrix (const Identity &);

			Matrix (const Matrix<R, C, NumericT> & other);
			
			Matrix (const NumericT * data)
			{ 
				set(data);
			}

			void set (const NumericT * data)
			{
				memcpy(_matrix, data, sizeof(_matrix));
			}
			
			template <typename AnyT>
			void set (const AnyT * data)
			{
				for (unsigned i = 0; i < R*C; i++) {
					_matrix[i] = data[i];
				}
			}
			
			void zero ();
			void load_identity (const NumericT & n = 1);

			// Accessors
			const NumericT & at (unsigned r, unsigned c) const
			{
				DREAM_ASSERT(row_major_offset(r, c, C) < R*C);
				return _matrix[row_major_offset(r, c, C)];
			}

			NumericT & at (unsigned r, unsigned c)
			{
				DREAM_ASSERT(row_major_offset(r, c, C) < R*C);
				return _matrix[row_major_offset(r, c, C)];
			}
			
			const NumericT & at (unsigned i) const
			{
				DREAM_ASSERT(i < R*C);
				return _matrix[i];
			}
			
			const NumericT & operator[] (unsigned i) const
			{
				return _matrix[i];
			}
			
			NumericT & operator[] (unsigned i)
			{
				return _matrix[i];
			}
			
			NumericT & at (unsigned i)
			{
				DREAM_ASSERT(i < R*C);
				return _matrix[i];
			}

			NumericT * value ()
			{
				return (NumericT*)_matrix;
			}

			const NumericT * value () const
			{
				return (const NumericT*)_matrix;
			}
			
			/// Copy a vector into the matix at position r, c
			/// This copies the vector in the direction of the major format,
			/// i.e. in column major format it will appear as a column
			template <unsigned D>
			void set (const IndexT & r, const IndexT & c, const Vector<D, NumericT> & v)
			{
				memcpy(&at(r, c), v.value(), sizeof(NumericT) * D);
			}
			
			/// Copy a vector into the matrix at position r, c, with element_offset distance between each element.
			/// The purpose of this function is primarily to facilitate copying a vector into a matrix in an order
			/// other than the major.
			/// i.e. set(0, 0, Vec4(...), 4) will set a row in a column major matrix.
			template <unsigned D>
			void set (const IndexT & r, const IndexT & c, const Vector<D, NumericT> & v, IndexT element_offset)
			{
				IndexT offset = &at(r, c) - (NumericT*)_matrix;
								
				for (IndexT i = 0; i < D; i += 1) {
					value()[offset + element_offset * i] = v[i];
				}
			}
			
			/// @todo Write get equivalent of set functions for retriving Vector data
			
			/// Return a copy of this matrix, transposed.
			Matrix<C, R, NumericT> transposed_matrix () const
			{
				Matrix<C, R, NumericT> result;

				for (unsigned c = 0; c < C; ++c)
					for (unsigned r = 0; r < R; ++r)
						result.at(c, r) = at(r, c);

				return result;
			}
			
			/// Load a test patern into the matrix. Used for testing.
			void load_test_pattern ()
			{
				unsigned i = 0;

				for (unsigned r = 0; r < R; r += 1)
					for (unsigned c = 0; c < C; c += 1)
						at(r, c) = i++;
			}
			
			/// Check if a matrices components are exactly equal.
			bool operator== (const Matrix & other) const
			{
				for (unsigned c = 0; c < C; ++c)
					for (unsigned r = 0; r < R; ++r)
						if (at(r, c) != other.at(r, c))
							return false;

				return true;
			}
		};

#pragma mark -
#pragma mark Static Matrix Constructors

		/// Convenience type for matrix class
		typedef Matrix<4, 4, RealT> Mat44;
		/// Convenience type for matrix class
		typedef Matrix<3, 3, RealT> Mat33;
		/// Convenience type for matrix class
		typedef Matrix<2, 2, RealT> Mat22;

		/// Convenience constructor for matrix class
		Mat44 rotation (const RealT & radians, const Vec3 & around_normal, const Vec3 & around_point);
		/// Convenience constructor for matrix class
		Mat44 rotation (const RealT & radians, const Vec3 & around_normal);
		/// Convenience constructor for matrix class
		Mat44 rotation (const Vec3 & from_unit_vector, const Vec3 & to_unit_vector, const Vec3 & around_normal);

		template <typename NumericT>
		Matrix<4, 4, NumericT> perspective_matrix (const NumericT & field_of_view, const NumericT & aspect_ratio, const NumericT & near, const NumericT & far) {
			NumericT f = 1.0 / Number<NumericT>::tan(field_of_view * 0.5);
			NumericT n = 1.0 / (near - far);
			
			Matrix<4, 4, NumericT> result(ZERO);
			
			result.at(0) = f / aspect_ratio;
			result.at(5) = f;
			result.at(10) = (far + near) * n;
			result.at(11) = -1.0;
			result.at(14) = (2 * far * near) * n;
			
			return result;
		}
		
		template <typename NumericT>
		Matrix<4, 4, NumericT> orthographic_matrix (const Vec3 & translation, const Vec3 & size) {
			Matrix<4, 4, NumericT> result(ZERO);
			
			result.at(0) = 2.0 / size[X];
			result.at(5) = 2.0 / size[Y];
			result.at(10) = -2.0 / size[Z];
			
			result.at(12) = -translation[X];
			result.at(13) = -translation[Y];
			result.at(14) = -translation[Z];
			result.at(15) = 1.0;
			
			return result;
		}		

	}
}

#include "Matrix.impl.h"

#endif
