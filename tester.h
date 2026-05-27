////////////////////////////////////////
// tester.h
////////////////////////////////////////

#ifndef CSE169_TESTER_H
#define CSE169_TESTER_H

#include "core.h"
#include "camera.h"
#include "cube.h"
#include <vector>
#include <time.h>
#include <math.h>

using namespace std;

#define PI 3.14159

inline double RAD(double d) { return (d*M_PI / 180.); }
inline double DEG(double d) { return (d*180. / M_PI); }

////////////////////////////////////////////////////////////////////////////////
struct colorRGB {
	int r;
	int g;
	int b;
};

struct Colors  {
	colorRGB  red; //:0xf25346,
	colorRGB  white; // : 0xd8d0d1,
	colorRGB  brown; // : 0x59332e,
	colorRGB  brownDark; // : 0x23190f,
	colorRGB  pink; // : 0xF5986E,
	colorRGB  yellow; // : 0xf4ce93,
	colorRGB  blue; // : 0x68c3c0,
	colorRGB  darkBlue;
	colorRGB  pureWhite;
	
	//int r, g, b;
};

struct box {
	float px, py, pz, rz, ry, s;
};

struct cloud {
	vector <box> cube;
	float x, y, rz, pz, s, h;
};

struct Position {
	float x;
	float y;
	float z;
};

struct airplanePosition {
	int w, h, d;
	float x;
	float y;
	float z;
	float rz;
	float rx;
	Position a0, a1, a2, a3, a4, a5, a6, a7;
};

struct Ennemy {
  float angle;
  float distance;

  float positionY;
  float positionX;
  float positionZ;
  float rotationX;
  float rotationY;
  float rotationZ;
};

struct Target {
	float angle;
	float distance;

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;
};

struct Building {
	float angle;
	float distance;

	int w, h, d;
	colorRGB c;
	int type; //0 building, 1 wall

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;
	Position b0, b1, b2, b3, b4, b5, b6, b7;
};

struct Missle {
	float velocity;
	float scale;
	float stime;
	float etime;
	float onTime;
	float durationTime;

	float incX, incY, incRZ, incRX;

	int color;

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;

	int targetID;

	float  m[16];
};

struct Coin {
	float angle;
	float distance;

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;
};

struct Particle {
	float angle;
	float distance;
	float scale;
	float stime;
	float etime;
	float onTime;
	float durationTime;

	float incX, incY, incZ, incRZ, incRX;

	int color;

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;
};

struct whiteSphere {
	float angle;
	float distance;
	float scale;
	float stime;
	float etime;
	float onTime;
	float durationTime;

	float incX, incY, incZ, incRZ, incRX;

	Position sp, ep;

	colorRGB c;

	float positionY;
	float positionX;
	float positionZ;
	float rotationX;
	float rotationY;
	float rotationZ;
};

struct Game {
	float speed;
    float initSpeed;
	float baseSpeed;
    float targetBaseSpeed;
    float incrementSpeedByTime;
    float incrementSpeedByLevel;
    int distanceForSpeedUpdate;
    int   speedLastUpdate;

    float   distance;
    int   ratioSpeedDistance;
    float   energy;
    int   ratioSpeedEnergy;

    int   level;
	int   levelLastUpdate;
    int   distanceForLevelUpdate;

	float planeScale;
    int   planeDefaultHeight;
    int   planeAmpHeight;
	int   planeLowHeight;
    int   planeAmpWidth;
    float   planeMoveSensivity;
    float   planeRotXSensivity;
    float   planeRotZSensivity;
    float   planeFallSpeed;
    float   planeMinSpeed;
    float   planeMaxSpeed;
    int   planeSpeed;
    int   planeCollisionDisplacementX;
    int   planeCollisionSpeedX;

    int   planeCollisionDisplacementY;
    int   planeCollisionSpeedY;

    int   seaRadius;
    int   seaLength;

	int   waveLength;
	int   waveHeight;
          
		  ////seaRotationSpeed:0.006,
	int   wavesMinAmp; // 5,
	int   wavesMaxAmp; //20,
	float wavesMinSpeed; //0.001,
	float wavesMaxSpeed; //.003,
	int waveSacle;

	int      cameraFarPos;
	int      cameraNearPos;
	float     cameraSensivity;

	float  coinDistanceTolerance;
	int    coinValue;
	float  coinsSpeed;
	int    coinLastSpawn;
	int    distanceForCoinsSpawn;

    float   ennemyDistanceTolerance;
    int   ennemyValue;
    float   ennemiesSpeed;
    int   ennemyLastSpawn;
    int   distanceForEnnemiesSpawn;

    int   status; // "0 = playing",
         //};
  //fieldLevel.innerHTML = Math.floor(game.level);
};

//Represents a terrain, by storing a set of heights and normals at 2D locations
struct Wave {
	float ang;
	float amp;
	float speed;
};


class Terrain {

private:
	int w; //Width
	int l; //Length
	float** hs; //Heights
	Vector3 ** normals;
	vector<Wave> wave;
	bool computedNormals; //Whether normals is up-to-date

public:

	float angle;
	float amp;
	float speed;
	Game _game;

	Terrain(int w2, int l2, Game game) {
		w = w2;
		l = l2;

		hs = new float*[l];
		for (int i = 0; i < l; i++) {
			hs[i] = new float[w];
		}

		normals = new Vector3*[l];
		for (int i = 0; i < l; i++) {
			normals[i] = new Vector3[w];
		}

		computedNormals = false;
		_game = game;
		
		int vi = 0;
		for (int y = 0; y < l; y++) {
			for (int x = 0; x < w; x++) {
				Wave twave;
				twave.ang = random() * PI * 2;
				twave.amp = game.wavesMinAmp + random() * (game.wavesMaxAmp - game.wavesMinAmp);
				twave.speed = game.wavesMinSpeed + random() * (game.wavesMaxSpeed - game.wavesMinSpeed);
				wave.push_back(twave);
			}
		}
	}

	~Terrain() {
		for (int i = 0; i < l; i++) {
			delete[] hs[i];
		}
		delete[] hs;

		for (int i = 0; i < l; i++) {
			delete[] normals[i];
		}
		delete[] normals;
	}

	int width() {
		return w;
	}

	int length() {
		return l;
	}

	//Sets the height at (x, z) to y
	void setHeight(int x, int z, float y) {
		hs[z][x] = y;
		computedNormals = false;
	}

	//Returns the height at (x, z)
	float getHeight(int x, int z) {
		return hs[z][x];
	}

	float random(){
		return (float)rand() / (RAND_MAX + 1);
	}

	//Computes the normals, if they haven't been computed yet
	void computeNormals() {
		//if (computedNormals) {
		//	return;
		//}

		//Compute the rough version of the normals
		Vector3** normals2 = new Vector3*[l];
		for (int i = 0; i < l; i++) {
			normals2[i] = new Vector3[w];
		}

		for (int z = 0; z < l; z++) {
			for (int x = 0; x < w; x++) {
				Vector3 sum(0.0f, 0.0f, 0.0f);

				Vector3 out;
				if (z > 0) {
					out = Vector3(0.0f, hs[z - 1][x] - hs[z][x], -1.0f);
				}
				Vector3 in;
				if (z < l - 1) {
					in = Vector3(0.0f, hs[z + 1][x] - hs[z][x], 1.0f);
				}
				Vector3 left;
				if (x > 0) {
					left = Vector3(-1.0f, hs[z][x - 1] - hs[z][x], 0.0f);
				}
				Vector3 right;
				if (x < w - 1) {
					right = Vector3(1.0f, hs[z][x + 1] - hs[z][x], 0.0f);
				}

				if (x > 0 && z > 0) {
					out.Cross(out, left);
					out.Normalize();
					sum.Add(out); 
				}
				if (x > 0 && z < l - 1) {
					left.Cross(left, in);
					left.Normalize();
					sum.Add(left);
				}
				if (x < w - 1 && z < l - 1) {
					in.Cross(in, right);
					in.Normalize();
					sum.Add(in);
				}
				if (x < w - 1 && z > 0) {
					right.Cross(right, out);
					right.Normalize();
					sum.Add(right);
				}

				normals2[z][x] = sum;
			}
		}

		//Smooth out the normals
		const float FALLOUT_RATIO = 0.5f;
		for (int z = 0; z < l; z++) {
			for (int x = 0; x < w; x++) {
				Vector3 sum = normals2[z][x];

				if (x > 0) {
					normals2[z][x - 1].Scale(FALLOUT_RATIO);
					sum.Add(normals2[z][x - 1]);
				}
				if (x < w - 1) {
					normals2[z][x + 1].Scale(FALLOUT_RATIO);
					sum.Add(normals2[z][x + 1]);
				}
				if (z > 0) {
					normals2[z - 1][x].Scale(FALLOUT_RATIO);
					sum.Add(normals2[z - 1][x]);
				}
				if (z < l - 1) {
					normals2[z + 1][x].Scale(FALLOUT_RATIO);
					sum.Add(normals2[z + 1][x]);
				}

				if (sum.Mag() == 0) {
					sum = Vector3(0.0f, 1.0f, 0.0f);
				}
				normals[z][x] = sum;
			}
		}

		for (int i = 0; i < l; i++) {
			delete[] normals2[i];
		}
		delete[] normals2;

		computedNormals = true;
	}

	//Returns the normal at (x, z)
	Vector3 getNormal(int x, int z) {
		//if (!computedNormals) {
		//	computeNormals();
		//}
		return normals[z][x];
	}

	Terrain* moveWaves(Terrain* t, float dtime , Game rtGame) {
			int vi = 0;
			//Terrain* t = new Terrain(w, l);
			for (int y = 0; y < l; y++) {
				for (int x = 0; x < w; x++) {
					Wave twave = wave[vi];
					float h = getHeight(x, y);
					h = cos(twave.ang) * twave.amp * 0.03; //h += cos(twave.ang) * twave.amp * 0.0005f;
					twave.ang += twave.speed * dtime;
					t->setHeight(x, y, h);

					wave[vi] = twave;
					vi++;
					//------------------------------------------------------------
					//독특한 파도 움직임-
					//float h = getHeight(x, y);
					//h = cos(angle + (x + y) / 2.0f) * amp;
					//angle += rtGame.speed * dtime * 0.25f; //0.00003 * dtime;
					//t->setHeight(x, y, h);
					//------------------------------------------------------------

					//float h = getHeight(x, y);
					//h += .95 + sin(angle + (x + y) / 3.0f); // *0.25f; //cos(angle) * amp;
					//angle += rtGame.speed * dtime * 70; //0.00003 * dtime;
					//t->setHeight(x, y, h);
				}
			}

			//delete image;
			t->computeNormals();
			return t;
	}

	//Loads a terrain from a heightmap.  The heights of the terrain range from
	//-height / 2 to height / 2.
	Terrain* loadTerrain(int width, int height, Game game) {
		//Image* image = loadBMP(filename);

		Terrain* t = new Terrain(width, height, game);
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x++) {
				//unsigned char color = (unsigned char)image->pixels[3 * (y * image->width + x)];
				float h = random() * 2;
				t->setHeight(x, y, h);
			}
		}

		//delete image;
		t->computeNormals();
		return t;
	}

};

class Tester {
public:
	Tester(int argc,char **argv);
	~Tester();

	int WinX, WinY;

	const float STEP_TIME = 0.01f;

	//=============================================================================================
	//member variable------------------------
	Colors colors;
	/*Colors white;
	Colors brown;
	Colors brownDark;
	Colors pink;
	Colors yellow;
	Colors blue;*/
		
	float pAngle;
	int nClouds;
	float skyAngle;
	float seaAngle;
	Position mousePos;
	airplanePosition airplanePos;
	float angleHairs;

	int deltaTime;
	int newTime;
	int oldTime;

	Terrain* _terrain;

	vector<cloud> clouds;
	vector<Ennemy> ennemiesPool;
	vector<Ennemy> ennemiesInUse;

	vector<Building> buildingsInUse;
	vector<Building> structuresInUse;

	vector<Coin> coinsPool;
	vector<Coin> coinsInUse;

	vector<Particle> particlesPool;
	vector<Particle> particlesInUse;

	vector<whiteSphere> whteSpheresInUse;

	vector<Missle> misslesPool;
	vector<Missle> misslesInUse;

	vector<Target> targetsInUse;

	Game game;
	void gameInit();

	//Ennemy ennemy;
	Coin coin;
	
	//help funciton---------------
	float random();
	float normalize(float v,float vmin,float vmax, float tmin, float tmax);
	void tBoxGeometry(float width, float height, float dapth, colorRGB c, float alpha);
	void BoxGeometry(float width, float height, float dapth, colorRGB c);
	void cBoxGeometry(float width, float height, float dapth, colorRGB c);
	Vector3 getTriNoraml(Position v1, Position v2, Position v3);
	void Tester::createMatrix(Vector3 pos, Vector3 axisX, Vector3 axisY, Vector3 axisZ, float* matrix);

	//plane game funtion--------------
	void AirPlane();
	void pilot();
	
	void createEnnemies();
	void spawnEnnemies();
	void rotateEnnemies();
	
	void constructBuilding();
	void moveBuildings();
	void guideLines(Building building);

	void buildStructures();
	void moveStructures();

	void createCoins();
	void spawnCoins();
	void rotateCoins();

	void createMissles();

	void spawnParticles(Ennemy ennemy, int density, int color, int scale);
	void spawnParticles(Target target, int density, int color, int scale);
	void spawnParticles(Missle missle, int density, int color, int scale);
	void makeWhiteSpheres(Position p);

	void createParticles();
	void explode(Position pos, int color , int scale);
	//int drawScene(); //int drawScene(float x, float y, float z);
	//void spawnParticles;

	void updatePlane();
	void updateDistance();
	void updateEnergy();
	void updateParticles();
	void updateWhiteSpheres();
	
	void addEnergy();
	void removeEnergy();

	void test();
	void Cloud();
	void createCylinder(GLfloat centerx, GLfloat centery, GLfloat centerz, GLfloat radius, GLfloat h);
	
	//Weaphon
	void drawMissle();
	void launchingMissle();
	void flyMissles();
	void updateMissles();

	//shadow---------------------------------------------------------------
	void DrawModels(void);
	void RegenerateShadowMap(void);
	void RenderScene();
	void SetupRC();
	//---------------------------------------------------------------------
	
	//================================================================================================

	void Update();
	void Reset();
	void Draw();

	void Quit();

	// Event handlers
	void Resize(int x,int y);
	void Keyboard(int key,int x,int y);
	void MouseButton(int btn,int state,int x,int y);
	void MouseMotion(int x,int y);

private:
	// Window management
	int WindowHandle;
	

	// Input
	bool LeftDown,MiddleDown,RightDown;
	int MouseX,MouseY;

	// Components
	Camera Cam;
	SpinningCube Cube;
};

////////////////////////////////////////////////////////////////////////////////

/*
The 'Tester' is a simple top level application class. It creates and manages a
window with the GLUT extension to OpenGL and it maintains a simple 3D scene
including a camera and some other components.
*/

#endif
