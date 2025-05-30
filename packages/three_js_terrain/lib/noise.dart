import 'dart:math' as math; 

class Grad{
  double x;
  double y;
  double z;
  Grad(this.x, this.y, this.z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  double dot2(double x, double y) {
    return this.x*x + this.y*y;
  }

  double dot3(x, y, z) {
    return this.x*x + this.y*y + this.z*z;
  }
}

class Noise{
  static List<Grad> grad3 = [
    new Grad(1,1,0),new Grad(-1,1,0),new Grad(1,-1,0),new Grad(-1,-1,0),
    new Grad(1,0,1),new Grad(-1,0,1),new Grad(1,0,-1),new Grad(-1,0,-1),
    new Grad(0,1,1),new Grad(0,-1,1),new Grad(0,1,-1),new Grad(0,-1,-1),
  ];

  static List<int> p = [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,
      30,69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,
      252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,
      168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,
      60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,65,25,63,161,
      1,216,80,73,209,76,132,187,208,89,18,169,200,196,135,130,116,188,159,
      86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,
      118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,
      170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,
      22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,
      251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
      107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,
      150,254,138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,
      61,156,180];

  static List<int> perm = List.filled(512,0);
  static late List<Grad> gradP = List.filled(512,new Grad(0,0,0));

  Noise(){
    seed(math.Random().nextInt(10));
  }

  // This isn't a very good seeding function, but it works okay. It supports
  // 2^16 different seed values. Write your own if you need more seeds.
  static void seed(num seed) {
    if (seed > 0 && seed < 1) {
      // Scale the seed out
      seed *= 65536;
    }

    int newSeed = seed.floor();
    if (seed < 256) {
      newSeed |= newSeed << 8;
    }

    for (int i = 0; i < 256; i++) {
      int v;
      if (i & 1 != 0) {
          v = p[i] ^ (newSeed & 255);
      }
      else {
          v = p[i] ^ ((newSeed>>8) & 255);
      }

      perm[i] = perm[i + 256] = v;
      gradP[i] = gradP[i + 256] = grad3[v % 12];
    }
  }

  // Skewing and unskewing factors for 2 and 3 dimensions
  static double F2 = 0.5*(math.sqrt(3)-1),
      G2 = (3-math.sqrt(3))/6,
      F3 = 1/3,
      G3 = 1/6;

  // 2D simplex noise
  static double simplex(num xin,num yin) {
    double n0, n1, n2; // Noise contributions from the three corners
    // Skew the input space to determine which simplex cell we're in
    double s = (xin+yin)*F2; // Hairy factor for 2D
    int i = (xin+s).floor();
    int j = (yin+s).floor();
    double t = (i+j)*G2;
    double x0 = xin-i+t; // The x,y distances from the cell origin, unskewed
    double y0 = yin-j+t;
    // For the 2D case, the simplex shape is an equilateral triangle.
    // Determine which simplex we are in.
    int i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
    if (x0 > y0) { // Lower triangle, XY order: (0,0)->(1,0)->(1,1)
      i1 = 1; j1 = 0;
    }
    else { // Upper triangle, YX order: (0,0)->(0,1)->(1,1)
      i1 = 0; j1 = 1;
    }
    // A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
    // a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
    // c = (3-sqrt(3))/6
    double x1 = x0 - i1 + G2; // Offsets for middle corner in (x,y) unskewed coords
    double y1 = y0 - j1 + G2;
    double x2 = x0 - 1 + 2 * G2; // Offsets for last corner in (x,y) unskewed coords
    double y2 = y0 - 1 + 2 * G2;
    // Work out the hashed gradient indices of the three simplex corners
    i &= 255;
    j &= 255;
    Grad gi0 = gradP[i+perm[j]];
    Grad gi1 = gradP[i+i1+perm[j+j1]];
    Grad gi2 = gradP[i+1+perm[j+1]];
    // Calculate the contribution from the three corners
    double t0 = 0.5 - x0*x0-y0*y0;
    if (t0 < 0) {
        n0 = 0;
    }
    else {
        t0 *= t0;
        n0 = t0 * t0 * gi0.dot2(x0, y0); // (x,y) of grad3 used for 2D gradient
    }
    double t1 = 0.5 - x1*x1-y1*y1;
    if (t1 < 0) {
      n1 = 0;
    }
    else {
      t1 *= t1;
      n1 = t1 * t1 * gi1.dot2(x1, y1);
    }
    double t2 = 0.5 - x2*x2-y2*y2;
    if (t2 < 0) {
      n2 = 0;
    }
    else {
      t2 *= t2;
      n2 = t2 * t2 * gi2.dot2(x2, y2);
    }
    // Add contributions from each corner to get the final noise value.
    // The result is scaled to return values in the interval [-1,1].
    return 70 * (n0 + n1 + n2);
  }

  // ##### Perlin noise stuff

  static double fade(double t) {
    return t*t*t*(t*(t*6-15)+10);
  }

  static double lerp(double a, double b, double t) {
    return (1-t)*a + t*b;
  }

  // 2D Perlin Noise
  static double perlin(double x, double y) {
    // Find unit grid cell containing point
    int X = x.floor(),
      Y = y.floor();

    // Get relative xy coordinates of point within that cell
    x = x - X;
    y = y - Y;
    // Wrap the integer cells at 255 (smaller integer period can be introduced here)
    X = X & 255;
    Y = Y & 255;

    // Calculate noise contributions from each of the four corners
    double n00 = gradP[X+perm[Y]].dot2(x, y);
    double n01 = gradP[X+perm[Y+1]].dot2(x, y-1);
    double n10 = gradP[X+1+perm[Y]].dot2(x-1, y);
    double n11 = gradP[X+1+perm[Y+1]].dot2(x-1, y-1);

    // Compute the fade curve value for x
    double u = fade(x);

    // Interpolate the four results
    return lerp(
        lerp(n00, n10, u),
        lerp(n01, n11, u),
        fade(y)
    );
  }
}