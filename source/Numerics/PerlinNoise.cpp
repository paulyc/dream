//
//  Numerics/PerlinNoise.cpp
//  This file is part of the "Dream" project, and is released under the MIT license.
//
//  Created by Samuel Williams on 13/05/06.
//  Copyright (c) 2006 Samuel Williams. All rights reserved.
//
//

#include "PerlinNoise.h"

#include <random>
#include "Interpolate.h"

namespace Dream {
	namespace Numerics {
		PerlinNoise::PerlinNoise(unsigned seed) {
			std::mt19937 rng(seed);

			std::uniform_int_distribution<int> byte_distribution(0, 256);
			auto r256 = std::bind(byte_distribution, rng);

			std::uniform_real_distribution<RealT> real_distribution(0.0, 1.0);
			auto r01 = std::bind(real_distribution, rng);

			for (IndexT i = 0; i < 256; ++i) _indicies[i] = i;

			/* Mix it up! */
			for (IndexT i = 0; i < 256; ++i) {
				IndexT w = r256() % 256;
				/* Swap */
				register unsigned char c;
				c = _indicies[w];
				_indicies[w] = _indicies[i];
				_indicies[i] = c;
			}

			for (IndexT i = 0; i < 256; ++i) _table[i] = (RealT)r01();
		}

		RealT PerlinNoise::sample(const Vec3 &v) const {
			Vec3 t (v);
			Vec3 o (v);

			RealT d[8];
			o.floor();

			/* Get noise at 8 lattice points */
			for (IndexT lz = 0; lz < 2; ++lz) {
				d[0 + lz*4] = lattice_noise((IndexT)o[X], (IndexT)o[Y], (IndexT)o[Z] + lz);
				d[1 + lz*4] = lattice_noise((IndexT)o[X], (IndexT)o[Y] + 1, (IndexT)o[Z] + lz);
				d[2 + lz*4] = lattice_noise((IndexT)o[X] + 1, (IndexT)o[Y] + 1, (IndexT)o[Z] + lz);
				d[3 + lz*4] = lattice_noise((IndexT)o[X] + 1, (IndexT)o[Y], (IndexT)o[Z] + lz);
			}

			RealT x0, x1, x2, x3, y0, y1;
			t.frac();

			x0 = linear_interpolate(t[X], d[0], d[3]);
			x1 = linear_interpolate(t[X], d[1], d[2]);
			x2 = linear_interpolate(t[X], d[4], d[7]);
			x3 = linear_interpolate(t[X], d[5], d[6]);

			y0 = linear_interpolate(t[Y], x0, x1);
			y1 = linear_interpolate(t[Y], x2, x3);

			RealT result = linear_interpolate(t[Z], y0, y1);

			return result;
		}

		RealT PerlinNoise::lattice_noise(IndexT i, IndexT j, IndexT k) const {
		#define P(x) _indicies[(x) & 255]
			//std::cout << i << " " << j << " " << k << " = " << _table[P(i + P(j + P(k)))] << std::endl;
			return _table[P(i + P(j + P(k)))];

		#undef P
		}

		/* Noise should scale between 0.0...1,0 */
		RealT PerlinNoise::turbulence (const Vec3 &at) const {
			RealT v = 0;
			v += sample(at, 1.0/32.0, 1.0/2.0);
			v += sample(at, 1.0/16.0, 1.0/4.0);
			v += sample(at, 1.0/8.0,  1.0/8.0);
			v += sample(at, 1.0/4.0,  1.0/16.0);
			v += sample(at, 1.0/2.0,  (1.0/16.0) * 0.75);
			v += sample(at, 1.0/1.0,  (1.0/16.0) * 0.25);

			return v;
		}

		//RealT PerlinNoise::clouds (const Vec3 &v) const {
		//	return (noise(v) * noise(v*.5) * noise(v*.25) * noise(v*.5*.25));
		//}

		RealT PerlinNoise::marble (const RealT &strength, const Vec3 &v) const {
			RealT t = turbulence(v);

			return t;
		}
	}
}