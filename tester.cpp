////////////////////////////////////////
// tester.cpp
////////////////////////////////////////

#include "tester.h"
#include <math.h>
#include <iostream>
#include <fstream>

//#include <GLFW/glfw3.h>

#define WINDOWTITLE	"AVIATOR TO SKY"

#pragma comment(lib, "opengl32.lib")

//inline double RAD(double d) { return (d*M_PI/180.); }
//inline double DEG(double d) { return (d*180./M_PI); }

#define FABS(x) (float(fabs(x)))        /* implement as is fastest on your machine */

/* if USE_EPSILON_TEST is true then we do a check:
         if |dv|<EPSILON then dv=0.0;
   else no check is done (which is less robust)
*/
#define USE_EPSILON_TEST TRUE
#define EPSILON 0.000001

#define PI 3.14159
int   xini = -100,   yini = 0;
int   xmov = 0, ymov = 100;
int nCoins = 20;

ofstream out;

//shadow----------------------------------------------------------------------------------------
#include "../Common/OpenGLSB.h"      // System and OpenGL Stuff

#include <math.h>
#include <stdio.h>

GLfloat factor = 4.0f;                  // for polygon offset

GLint windowWidth = 512;                // window size
GLint windowHeight = 512;

GLint shadowSize = 512;                 // set based on window size
GLuint shadowTextureID;

GLfloat ambientLight[] = { 0.2f, 0.2f, 0.2f, 1.0f };
GLfloat diffuseLight[] = { 0.7f, 0.7f, 0.7f, 1.0f };
GLfloat noLight[] = { 0.0f, 0.0f, 0.0f, 1.0f };
//GLfloat lightPos[] = { 100.0f, 300.0f, 100.0f, 1.0f };

GLfloat lightPos[] = { 1200, 1200, 1200, 1 }; //GLfloat lightpos[] = { 900, 1500, 1500, 1 };

GLfloat cameraPos[] = { 0, 400.0f, 100.0f, 1.0f };

//----------------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char **argv) {

	glutInit(&argc, argv);
	Tester t(argc,argv);

	glutMainLoop();

	//out.close();
	return 0;
}

////////////////////////////////////////////////////////////////////////////////

// These are really HACKS to make glut call member functions instead of static functions
static Tester *TESTER;
static void display()			{TESTER->Draw();}
static void idle()				{TESTER->Update();}
static void resize(int x,int y)	{TESTER->Resize(x,y);}
static void keyboard(unsigned char key,int x,int y)		{TESTER->Keyboard(key,x,y);}
static void mousebutton(int btn,int state,int x,int y)	{TESTER->MouseButton(btn,state,x,y);}
static void mousemotion(int x, int y)					{TESTER->MouseMotion(x,y);}


////////////////////////////////////////////////////////////////////////////////
void Tester::gameInit()
{
	game.speed = 0;
    game.initSpeed = .00035;
	game.baseSpeed = .00035;
    game.targetBaseSpeed = .00035;
	game.incrementSpeedByTime = 0; //.000005;  //.0000025; //중간(이것도 쉬움) //.0000001; //게임 아주 느리게    //.000009; //너무 빠름 
    game.incrementSpeedByLevel = .000003; //.000005;
    game.distanceForSpeedUpdate = 100;
    game.speedLastUpdate = 0;

    game.distance = 0;
    game.ratioSpeedDistance = 50;
	game.energy = 70; //100;
    game.ratioSpeedEnergy = 3;

    game.level = 1;
	game.levelLastUpdate = 0;
    game.distanceForLevelUpdate = 1000;

	game.planeScale = 0.5f;
	game.planeDefaultHeight = 100; //100;
	game.planeAmpHeight = 100; //80; //80;
	game.planeLowHeight = 80;  //mine variable
    game.planeAmpWidth = 75; //100;
    game.planeMoveSensivity = 0.005;
    game.planeRotXSensivity = 0.0008;
    game.planeRotZSensivity = 0.0004;
    game.planeFallSpeed = .001;
    game.planeMinSpeed = 1.2;
    game.planeMaxSpeed = 1.6;
    game.planeSpeed = 0;
    game.planeCollisionDisplacementX = 0;
    game.planeCollisionSpeedX = 0;

    game.planeCollisionDisplacementY = 0;
    game.planeCollisionSpeedY = 0;

	game.seaRadius = 600;
    game.seaLength = 800;
          
	game.waveLength = 20;
	game.waveHeight = 10;
	game.waveSacle = 80;

		  ////seaRotationSpeed:0.006,
	game.wavesMinAmp = 5;
	game.wavesMaxAmp = 20;
	game.wavesMinSpeed = 0.001;
	game.wavesMaxSpeed = 0.003;

	game.cameraFarPos = 700;//500;
	game.cameraNearPos = 100; //150;
	game.cameraSensivity = 0.000001f; //0.002f;

	game.coinDistanceTolerance = 15;
	game.coinValue = 3;
	game.coinsSpeed = .5;
	game.coinLastSpawn =0;
	game.distanceForCoinsSpawn = 200;

    game.ennemyDistanceTolerance = 10; 
    game.ennemyValue = 10;
    game.ennemiesSpeed = .6;
    game.ennemyLastSpawn = 0;
    game.distanceForEnnemiesSpawn = 50;

   game.status = 1; // "1 = playing",
         //};
  //fieldLevel.innerHTML = Math.floor(game.level);
}

////////////////////////////////////////////////////////////////////////////////

Tester::Tester(int argc,char **argv) {
	
	out.open("an.txt"); //debug 용 출력
	
	WinX=1000;
	WinY=700;

	gameInit();
	
	LeftDown=MiddleDown=RightDown=false;
	MouseX=MouseY=0;

	colors.red.r = 242; colors.red.g = 83; colors.red.b = 70;
	colors.white.r = 216; colors.white.g = 208; colors.white.b = 209;
	colors.brown.r = 89; colors.brown.g = 51; colors.brown.b = 46;
	colors.brownDark.r = 35; colors.brownDark.g = 25; colors.brownDark.b = 15;
	colors.pink.r = 245; colors.pink.g = 152; colors.pink.b = 110;
	colors.yellow.r = 244; colors.yellow.g = 206; colors.yellow.b = 147;
	//colors.blue.r = 196; colors.blue.b = 234; colors.blue.b = 247;
	colors.blue.r = 104; colors.blue.g = 195; colors.blue.b = 192;
	colors.darkBlue.r = 0; colors.darkBlue.g = 152; colors.darkBlue.b = 206;
	colors.pureWhite.r = 255; colors.pureWhite.g = 255; colors.pureWhite.b = 255;

	//airplane info-------------------------------------------------------------------
	airplanePos.x = -100; //-100;
	airplanePos.y = game.planeDefaultHeight;
	airplanePos.z = 0;

	//임시 비행기 크기 ------------------------------------------------------
	airplanePos.w = 120 * game.planeScale;
	airplanePos.h = 80 * game.planeScale;
	airplanePos.d = 120 * game.planeScale;

	int w = airplanePos.w; 
	int h = airplanePos.h;
	int d = airplanePos.d;

	//airplanePos.a0.x =  w/2 -50; airplanePos.a0.y = -h/2; airplanePos.a0.z =  d/2;
	//airplanePos.a1.x =  w/2 -50; airplanePos.a1.y = -h/w; airplanePos.a1.z = -d/2;
	//airplanePos.a2.x =  w/2 -50; airplanePos.a2.y =  h/2; airplanePos.a2.z = -d/2;
	//airplanePos.a3.x =  w/2 -50; airplanePos.a3.y =  h/2; airplanePos.a3.z =  d/2;
	//airplanePos.a4.x = -w/2; airplanePos.a4.y = -h/2; airplanePos.a4.z =  d/2;
	//airplanePos.a5.x = -w/2; airplanePos.a5.y = -h/2; airplanePos.a5.z = -d/2;
	//airplanePos.a6.x = -w/2; airplanePos.a6.y =  h/2; airplanePos.a6.z = -d/2;
	//airplanePos.a7.x = -w/2; airplanePos.a7.y =  h/2; airplanePos.a7.z =  d/2;
	//--------------------------------------------------------------------------------

	angleHairs = 0.0f;

	pAngle = 0;
	skyAngle = 0;
	seaAngle = 0;
	
	deltaTime = 0.0f;
	newTime = timeGetTime();
	oldTime = timeGetTime();
	
	//---------------------------------------------------------------------------
	//sky paramter for cloud
		box b;
	cloud c;

	nClouds = 20.0f;
	float stepAngle = PI * 2 / nClouds;	
	
	for(int i=0; i< nClouds; i++){

		int nBlocs = 3 + random() * 1;
		for(int j=0; j< nBlocs; j++){
			b.px = j * 5;
			b.py = random() * 10;
			b.pz = random() * 10;
			b.rz = random() * 360 * 2 ;
			b.ry = random() * 360 * 2 ;
			b.s = 1 + random() * .9;
			c.cube.push_back(b);
		}
		
		float a = stepAngle * i; 
		float h = game.seaRadius/2 + random()*10; 

		c.y = sin(a) * h;
		c.x = cos(a) * h;
		c.rz = (a + PI/2.0f)  * 180/PI;

		c.pz = -100 - random()*100;
		
		c.s = 1 + random()*2;

		clouds.push_back(c);
		c.cube.clear();
	}

	_terrain = _terrain->loadTerrain(game.waveLength, game.waveHeight, game);

	//-----------------------------------------------------------------------------

	// Create the window
	glutInitDisplayMode( GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH );
	glutInitWindowSize( WinX, WinY );
	glutInitWindowPosition( 0, 0 );
	WindowHandle = glutCreateWindow( WINDOWTITLE );
	glutSetWindowTitle( WINDOWTITLE );
	glutSetWindow( WindowHandle );

	// Background color
	//glClearColor( 0., 0., 0., 1. );
	glClearColor( 235.0/255.0, 221.0/255.0, 180.0/255.0, 1. );

	//glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_MULTISAMPLE);
	/*glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);*/

	glEnable(GL_CULL_FACE);		
	GLfloat  specref[] = { 1.0f, 1.0f, 1.0f, 1.0f };
	glMaterialfv(GL_FRONT, GL_SPECULAR, specref);
	glMateriali(GL_FRONT, GL_SHININESS, 100);

	SetupRC();

	// Callbacks
	TESTER=this;
	glutDisplayFunc( display );
	glutIdleFunc( idle );
	glutKeyboardFunc( keyboard );
	glutMouseFunc( mousebutton );
	glutMotionFunc( mousemotion );
	glutPassiveMotionFunc( mousemotion );
	glutReshapeFunc( resize );
	glutTimerFunc( 0, NULL, 0 );

	//shadow 코드 중복------------------------------------
	GLfloat lightToSceneDistance, nearPlane, fieldOfView;
	GLfloat lightModelview[16], lightProjection[16];

	// Save the depth precision for where it's useful
	lightToSceneDistance = sqrt(lightPos[0] * lightPos[0] +
		lightPos[1] * lightPos[1] +
		lightPos[2] * lightPos[2]);
	nearPlane = lightToSceneDistance - 150.0f;
	if (nearPlane < 50.0f)
		nearPlane = 50.0f;
	// Keep the scene filling the depth texture
	fieldOfView = 17000.0f / lightToSceneDistance;
	//----------------------------------------------------


	// Initialize components
	Cam.SetAspect(float(WinX)/float(WinY));
	Cam.FOV = 17000; //50.0f;
	Cam.x = 0;
	Cam.z = -400; // -300;
	Cam.y = -game.planeDefaultHeight;

	/*cameraPos[0] = Cam.x;
	cameraPos[1] = Cam.z;
	cameraPos[2] = Cam.y;
	cameraPos[3] = 1.0f;*/

	Cam.SetAzimuth(90);
	Cam.SetIncline(0);
}

////////////////////////////////////////////////////////////////////////////////

Tester::~Tester() {
	glFinish();
	glutDestroyWindow(WindowHandle);
}


////////////////////////////////////////////////////////////////////////////////

void Tester::createMatrix(Vector3 pos, Vector3 axisX, Vector3 axisY, Vector3 axisZ, float* matrix)
{
	matrix[0] = axisX.x; matrix[1] = axisX.y; matrix[2] = axisX.z; matrix[3] = 0;
	matrix[4] = axisY.x; matrix[5] = axisY.y;	matrix[6] = axisY.z; matrix[7] = 0;
	matrix[8] = axisZ.x; matrix[9] = axisZ.y; matrix[10] = axisZ.z; matrix[11] = 0;
	matrix[12] = pos.x; matrix[13] = pos.y; matrix[14] = pos.z;	matrix[15] = 1;
};


void Tester::launchingMissle(){
	for (int i = 0; i < ennemiesInUse.size(); i++) {
		Ennemy ennemy = ennemiesInUse[i];

		float d = sqrt(pow((airplanePos.x - ennemy.positionX), 2) + pow((airplanePos.y - ennemy.positionY), 2) + pow((airplanePos.z - ennemy.positionZ), 2));

		//var d = diffPos.length();
		if (d < 900){
			//printf("find enney \n");

			Missle missle;
			missle.positionX = airplanePos.x - 10.0f;
			missle.positionY = airplanePos.y - 20.0f;
			missle.positionZ = airplanePos.z;
			missle.velocity = 10.0f; //0.5f;
			missle.scale = 0.4f;
			missle.targetID = i;

			misslesInUse.push_back(missle);
		}
	}
}

void Tester::updateMissles(){
	float steptime = 0.25f;
	for (int i = 0; i<misslesInUse.size(); i++){
		Missle missle = misslesInUse[i];

		//bool isHit = false;
		Vector3 mv, ev;
		Vector3 approchVec, pos, oldPos, diffVec;

		//for (int j = 0; j < ennemiesInUse.size(); j++){
			Ennemy ennemy = ennemiesInUse[missle.targetID];   //미사일이 lock한 목표 아이디 
			//printf(" ez = %f \n ", ennemy.rotationZ);

			mv.x = missle.positionX; mv.y = missle.positionY; mv.z = missle.positionZ;
			ev.x = ennemy.positionX; ev.y = ennemy.positionY; ev.z = ennemy.positionZ;

			float d = sqrt(pow((missle.positionX - ennemy.positionX), 2) + pow((missle.positionY - ennemy.positionY), 2) + pow((missle.positionZ - ennemy.positionZ), 2));

			approchVec.Subtract(ev, mv); //미사일에서 적 방향 벡터 구하기
			approchVec.Scale(d*d);  //거리가 가까울수록 속도 증가, 거리에 비례

			approchVec.Normalize();
			approchVec.Scale(7);   // 속도 벡터에 조정 값 적용
			
			oldPos.x = missle.positionX; oldPos.y = missle.positionY; oldPos.z = missle.positionZ;
			
			missle.positionX += approchVec.x; missle.positionY += approchVec.y; missle.positionZ += approchVec.z; //미사일 위치 값 계산
			pos.x = missle.positionX; pos.y = missle.positionY; pos.z = missle.positionZ;
			
			//----------------------------------------------------------------------
			Vector3 g(0.0f, -9.8f, 0.0f);
			Vector3 upVec, axisX, axisY, axisZ;

			approchVec.Normalize();
			axisZ = approchVec;

			approchVec.Subtract(oldPos);   // 신규 속도 벡터와 이전 속도 벡터의 빼기 벡터와
			upVec.Subtract(approchVec, g); //중력 벡터에 직교 벡터 Up 벡터 구함

			axisX.Cross(upVec, axisZ);     //  up 벡터와 Z 벡터의 직교는 X축 벡터
			axisX.Normalize();

			axisY.Cross(axisZ, axisX);     //Z, X 벡터의 직교 벡터 Y축 벡터
			axisY.Normalize();
			createMatrix(pos, axisX, axisY,axisZ, missle.m);  //회전, 이동 행열 구함
			//----------------------------------------------------------------------

			misslesInUse[i] = missle;

			//var d = diffPos.length();
			if (d < game.ennemyDistanceTolerance){
				
				spawnParticles(ennemy, 15, 1, 7);

				ennemiesInUse.erase(ennemiesInUse.begin() + missle.targetID);
				misslesInUse.erase(misslesInUse.begin() + i);

				//isHit = true;

				i--;
				//j--;
			}
	}
}

////////////////////////////////////////////////////////////////////////////////

void Tester::Update() {
	
	//// Update the components in the world
	//Cam.Update();
	////Cube.Update();

	newTime = timeGetTime();
	deltaTime = newTime-oldTime;
	oldTime = newTime;

	//printf(" nt, %d, ot = %d  dt = %d \n", newTime, oldTime, deltaTime);
	
	skyAngle += DEG(game.speed*deltaTime);  //0.005 * 180.0f / PI;
	seaAngle += 0.003 * 180.0f/PI;
	
	if (skyAngle > 360) skyAngle = skyAngle - 360;
	if(seaAngle > 360) seaAngle = seaAngle - 360;

	//game play-------------------------------------------------------------
	if(game.status == 1) {
		
		//구조물 생성
		if ((int)floor(game.distance) % 5 == 0) {
			buildStructures();
		}

		// Add energy coins every 100m;
		if ((int)floor(game.distance) % game.distanceForCoinsSpawn == 0 && (int)floor(game.distance) > game.coinLastSpawn){
			game.coinLastSpawn = (int)floor(game.distance);
			spawnCoins();
		}

		if ((int)floor(game.distance) % game.distanceForSpeedUpdate == 0 && (int)floor(game.distance) > game.speedLastUpdate){
			game.speedLastUpdate = (int)floor(game.distance);
			game.targetBaseSpeed += game.incrementSpeedByTime*deltaTime;
		}
	
		if ((int)floor(game.distance) % game.distanceForEnnemiesSpawn == 0 && (int)floor(game.distance) > game.ennemyLastSpawn){
		  game.ennemyLastSpawn = (int)floor(game.distance);
		  //spawnEnnemies();

		  constructBuilding();

		  //미사일 발사 코드-------------------------------------------------------------------------------------------------
		  //launchingMissle();
		  //----------------------------------------------------------------------------------------------------------------
		}

		if ((int)floor(game.distance)%game.distanceForLevelUpdate == 0 && (int)floor(game.distance) > game.levelLastUpdate){
		  game.levelLastUpdate = floor(game.distance);
		  game.level++;
		 // fieldLevel.innerHTML = floor(game.level);

		  game.targetBaseSpeed = game.initSpeed + game.incrementSpeedByLevel*game.level;
		}

		updatePlane();
		updateDistance();
		updateEnergy();
		updateParticles();

		game.baseSpeed += (game.targetBaseSpeed - game.baseSpeed) * deltaTime * 0.02;
		game.speed = game.baseSpeed * game.planeSpeed;
	}
	else if (game.status == 0) {
		game.speed *= .99f;

		//game.speed -= .09f;

		airplanePos.rz += DEG((PI / 2 - airplanePos.rz)*.0002*deltaTime) ;
		airplanePos.rx += DEG(0.0003*deltaTime);
		game.planeFallSpeed *= 1.05f;
		airplanePos.y -= game.planeFallSpeed*deltaTime;

		particlesInUse.clear();
	}
	//----------------------------------------------------------------------

	_terrain->moveWaves(_terrain, deltaTime, game);

	//#if 0

	//#endif 
	//updateMissles();
	flyMissles();
	rotateCoins();
	rotateEnnemies();
	moveBuildings();
	moveStructures();
	updateWhiteSpheres();

	// Tell glut to re-display the scene
	glutSetWindow(WindowHandle);
	glutPostRedisplay();
}


void Tester::updatePlane(){
	pAngle += DEG(0.3);//25;
	if (pAngle > 360) pAngle = pAngle - 360;

	game.planeSpeed = normalize(mousePos.x, -.5, .5, game.planeMinSpeed, game.planeMaxSpeed);
	//float targetY = normalize(mousePos.y,-.75,.75, 15, 300);
	//float tragetX = normalize(mousePos.x,-.75,.75,-200, 200);
	float targetY = normalize(mousePos.y, -.75, .75, game.planeDefaultHeight - /*game.planeAmpHeight*/ game.planeLowHeight, game.planeDefaultHeight + game.planeAmpHeight);
	float targetZ = normalize(mousePos.x, -.75, .75, -120 /*game.planeLowHeight*/, 120);
	//float targetX = normalize(mousePos.x, -1, 1, -game.planeAmpWidth*.7, -game.planeAmpWidth);

	game.planeCollisionDisplacementX += game.planeCollisionSpeedX;
	targetZ += game.planeCollisionDisplacementX;

	game.planeCollisionDisplacementY += game.planeCollisionSpeedY;
	targetY += game.planeCollisionDisplacementY;

	airplanePos.y += (targetY - airplanePos.y)*deltaTime*game.planeMoveSensivity;
	airplanePos.z += (targetZ - airplanePos.z /*- 150.0f*/)*deltaTime*game.planeMoveSensivity; // 비행기 위치 화면 왼쪽 이동

	//airplanePos.y += (targetY - airplanePos.y) * 0.1;
	airplanePos.rz = (targetY - airplanePos.y)*0.0128 * 180 / PI;
	airplanePos.rx = (targetZ - airplanePos.z)*0.0128 * 180 / PI; //*0.0064 * 180 / PI;

	//Cam.FOV = normalize(mousePos.x, -1, 1, 40, 80);
	//Cam.y += (airplanePos.y - Cam.y) * deltaTime * game.cameraSensivity * 1.5;

	//airplane bounding box update----------------------------------------------------------------------------------------------------------
	airplanePos.a0.x = airplanePos.x + airplanePos.w / 2 - 20; airplanePos.a0.y = airplanePos.y - airplanePos.h / 2; airplanePos.a0.z = airplanePos.z + airplanePos.d / 2;
	airplanePos.a1.x = airplanePos.x + airplanePos.w / 2 - 20; airplanePos.a1.y = airplanePos.y - airplanePos.h / 2; airplanePos.a1.z = airplanePos.z - airplanePos.d / 2;
	airplanePos.a2.x = airplanePos.x + airplanePos.w / 2 - 20; airplanePos.a2.y = airplanePos.y + airplanePos.h / 2; airplanePos.a2.z = airplanePos.z - airplanePos.d / 2;
	airplanePos.a3.x = airplanePos.x + airplanePos.w / 2 - 20; airplanePos.a3.y = airplanePos.y + airplanePos.h / 2; airplanePos.a3.z = airplanePos.z + airplanePos.d / 2;

	airplanePos.a4.x = airplanePos.x - airplanePos.w / 2 - 20; airplanePos.a4.y = airplanePos.y - airplanePos.h / 2; airplanePos.a4.z = airplanePos.z + airplanePos.d / 2;
	airplanePos.a5.x = airplanePos.x - airplanePos.w / 2 - 20; airplanePos.a5.y = airplanePos.y - airplanePos.h / 2; airplanePos.a5.z = airplanePos.z - airplanePos.d / 2;
	airplanePos.a6.x = airplanePos.x - airplanePos.w / 2 - 20; airplanePos.a6.y = airplanePos.y + airplanePos.h / 2; airplanePos.a6.z = airplanePos.z - airplanePos.d / 2;
	airplanePos.a7.x = airplanePos.x - airplanePos.w / 2 - 20; airplanePos.a7.y = airplanePos.y + airplanePos.h / 2; airplanePos.a7.z = airplanePos.z + airplanePos.d / 2;
	//----------------------------------------------------------------------------------------------------------------------------------------

	game.planeCollisionSpeedX += (0 - game.planeCollisionSpeedX)*deltaTime * 0.03;
	game.planeCollisionDisplacementX += (0 - game.planeCollisionDisplacementX)*deltaTime *0.01;
	game.planeCollisionSpeedY += (0 - game.planeCollisionSpeedY)*deltaTime * 0.03;
	game.planeCollisionDisplacementY += (0 - game.planeCollisionDisplacementY)*deltaTime *0.01;
}

void Tester::updateDistance(){
	game.distance += game.speed*deltaTime*game.ratioSpeedDistance;

	//printf("game distance %f \n" , game.distance);
	//fieldDistance.innerHTML = Math.floor(game.distance);
	//var d = 502*(1-(game.distance%game.distanceForLevelUpdate)/game.distanceForLevelUpdate);
	//levelCircle.setAttribute("stroke-dashoffset", d);
}

void Tester::updateEnergy(){
	game.energy -=  game.speed*deltaTime*game.ratioSpeedEnergy;
	game.energy = max(0, game.energy);

	//float ed = (game.speed)*deltaTime*game.ratioSpeedEnergy;

	//printf("ge = %f \n", game.energy);
	//energyBar.style.right = (100 - game.energy) + "%";
	//energyBar.style.backgroundColor = (game.energy<50) ? "#f25346" : "#68c3c0";

	/*if (game.energy<30){
		energyBar.style.animationName = "blinking";
	}
	else{
		energyBar.style.animationName = "none";
	}*/

	if (game.energy <1){
		//game.status = 0; //game over
	}
}

void Tester::updateParticles() {
	
	//update 파티클 애니메이션 파라마터--------------
	for (int i = 0; i < particlesInUse.size(); i++) {
		particlesInUse[i].onTime += STEP_TIME;

		particlesInUse[i].positionZ += particlesInUse[i].incZ;
		particlesInUse[i].positionY += particlesInUse[i].incY;
		particlesInUse[i].positionX -= game.speed*deltaTime*game.ennemiesSpeed * 5000;

		particlesInUse[i].scale -= 0.1f;

		particlesInUse[i].rotationX += particlesInUse[i].incRX;
		particlesInUse[i].rotationZ += particlesInUse[i].incRZ;

		if (particlesInUse[i].onTime > particlesInUse[i].durationTime) {
			particlesInUse.erase(particlesInUse.begin() + i);
			i--;
		}
	}
}

void Tester::updateWhiteSpheres() {
	for (int i = 0; i < whteSpheresInUse.size(); i++) {
		whteSpheresInUse[i].onTime += STEP_TIME;

		//whteSpheresInUse[i].positionZ += particlesInUse[i].incZ;
		//whteSpheresInUse[i].positionY += particlesInUse[i].incY;
		whteSpheresInUse[i].positionX -= game.speed*deltaTime*game.ennemiesSpeed * 5000;

		whteSpheresInUse[i].scale += 0.2f;

		//whteSpheresInUse[i].rotationX += particlesInUse[i].incRX;
		//whteSpheresInUse[i].rotationZ += particlesInUse[i].incRZ;

		if (whteSpheresInUse[i].onTime > whteSpheresInUse[i].durationTime) {
			whteSpheresInUse.erase(whteSpheresInUse.begin() + i);
			i--;
		}
	}
}

void Tester::flyMissles(){
	float steptime = 0.25f;
	for (int i = 0; i<misslesInUse.size(); i++){
		Missle missle = misslesInUse[i];

		missle.velocity += 1.9f;

		missle.positionX += missle.velocity * steptime + 0.5 * 5 * steptime * steptime;
		//missle.positionY = airplanePos.y;
		//missle.positionZ = airplanePos.z;
		//missle.positionY = airplanePos.y;

		misslesInUse[i] = missle;

		//cout << " target size "  <<targetsInUse.size() << endl;

		for (int j = 0; j < targetsInUse.size(); j++){

			Target target = targetsInUse[j];
			//printf(" ez = %f \n ", ennemy.rotationZ);

			////var globalEnnemyPosition =  ennemy.mesh.localToWorld(new THREE.Vector3());
			//float diffPos = airplane.mesh.position.clone().sub(ennemy.mesh.position.clone());
			float diffPosZ = missle.positionZ - target.positionZ;
			float diffPosY = missle.positionY - target.positionY;

			//float d = diffPosX * diffPosX + diffPosY * diffPosY;

			float d = sqrt(pow((missle.positionX - target.positionX), 2) + pow((missle.positionY - target.positionY), 2) + pow((missle.positionZ - target.positionZ), 2));

			//out << "mx = " << missle.positionX << " my = " << missle.positionY << " mz = " << missle.positionZ << endl;
			//out << "tx = " << target.positionX << " ty = " << target.positionY << " tz = " << target.positionZ << endl;
			//out << " d = " << d << endl;

			//var d = diffPos.length();
			if (d < game.ennemyDistanceTolerance + 10){

				spawnParticles(target, 15, 1, 7);

				targetsInUse.erase(targetsInUse.begin() + j);
				j--;

				misslesInUse.erase(misslesInUse.begin() + i);
				i--;

				//out << endl << "hit " << endl;
				//out << "mx = " << missle.positionX << " my = " << missle.positionY << " mz = " << missle.positionZ << endl;
				//out << "tx = " << target.positionX << " ty = " << target.positionY << " tz = " << target.positionZ << endl;
				//out << " d = " << d << endl;
			}
			//out << endl;
		}

		if (missle.positionX > 15000) {
			misslesInUse.erase(misslesInUse.begin() + i);
			i--;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

void Tester::addEnergy(){
	game.energy += game.coinValue;
	game.energy = min(game.energy, 100);
}

void Tester::removeEnergy(){
	game.energy -= game.ennemyValue;
	game.energy = max(0, game.energy);
}

////////////////////////////////////////////////////////////////////////////////

void Tester::Reset() {
	
	Cam.SetAspect(float(WinX)/float(WinY));
	Cam.Reset();
	
	//Cube.Reset();
}

float Tester::random(){
	return (float)rand() / (RAND_MAX + 1);
}

float Tester::normalize(float v,float vmin,float vmax, float tmin, float tmax)
{
	float nv = max(min(v,vmax), vmin);
	float dv = vmax-vmin;
	float pc = (nv-vmin)/dv;
	float dt = tmax-tmin;
	float tv = tmin + (pc*dt);

	//printf("tv %f \n" , tv);
	
	return tv;
}

Vector3 Tester::getTriNoraml(Position b0, Position b1, Position b2){

	Vector3 va, vb, vc;
	va.x = b0.x; va.y = b0.y; va.z = b0.z;
	vb.x = b1.x; vb.y = b1.y; vb.z = b1.z;
	vc.x = b2.x; vc.y = b2.y; vc.z = b2.z;

	Vector3 dir, sbv1, sbv2;
	sbv1.Subtract(va, vb); sbv2.Subtract(va, vc);

	//printf("s1x = %f, s1y = %f, s1z = %f \n", sbv1.x, sbv1.y, sbv1.z);
	//printf("s2x = %f, s2y = %f, s2z = %f \n", sbv2.x, sbv2.y, sbv2.z);

	dir.Cross(sbv1, sbv2);

	//printf("dx = %f, dy = %f, dz = %f \n", dir.x, dir.y, dir.z);

	dir.Normalize();;

	//printf("nx = %f, ny = %f, nz = %f \n", dir.x, dir.y, dir.z);

	return dir;
}

void Tester::tBoxGeometry(float w, float h, float d, colorRGB c, float alpha){

	glColor4f(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, alpha);
	//Top front
	glNormal3f(0.0f, 0.0f, 1.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, d / 2.0f);
	glEnd();

	//back front
	glNormal3f(0.0f, 0.0f, -1.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, -d / 2.0f);
	glEnd();

	//side right
	glNormal3f(1.0f, 0.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, d / 2.0f);
	glEnd();

	//side left
	glNormal3f(-1.0f, 0.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, -d / 2.0f);
	glEnd();

	//top 
	glNormal3f(0.0f, 1.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(w / 2.0f, h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f, d / 2.0f);
	glEnd();

	//bottom 
	glNormal3f(0.0f, -1.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(-w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, d / 2.0f);
	glEnd();
}

void Tester::BoxGeometry(float w, float h, float d, colorRGB c){
	
	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	//glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, d / 2.0f);
	//glVertex3f(-w / 2.0f, h / 2.0f, d / 2.0f);
	glEnd();

	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	glVertex3f(-w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, h / 2.0f, -d / 2.0f);
	glEnd();

	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	glVertex3f(w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f, -d / 2.0f);
	glEnd();

	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(w / 2.0f, -h / 2.0f,  d / 2.0f);
	glEnd();
	
	
	glColor4f(c.r/255.0f, c.g/255.0f, c.b/255.0f, 1.0f);
	//Top front
	glNormal3f(0.0f, 0.0f, 1.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f( w / 2.0f, -h / 2.0f, d / 2.0f); 
	glVertex3f( w / 2.0f,  h / 2.0f, d / 2.0f); 
	glVertex3f(-w / 2.0f,  h / 2.0f, d / 2.0f);
	glEnd();

	
	//back front
	glNormal3f(0.0f, 0.0f, -1.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f( w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f( -w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f( -w / 2.0f,  h / 2.0f, -d / 2.0f);
	glVertex3f( w / 2.0f,  h / 2.0f, -d / 2.0f);
	glEnd();

	//side right
	glNormal3f(1.0f, 0.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f( w / 2.0f, -h / 2.0f,  d / 2.0f);
	glVertex3f( w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f( w / 2.0f,  h / 2.0f, -d / 2.0f);
	glVertex3f( w / 2.0f,  h / 2.0f,  d / 2.0f);
	glEnd();

	//side left
	glNormal3f(-1.0f, 0.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f,  -h / 2.0f,  d / 2.0f);
	glVertex3f(-w / 2.0f,  h / 2.0f,  d / 2.0f);
	glVertex3f(-w / 2.0f,  h / 2.0f, -d / 2.0f);
	glEnd();

	//top 
	glNormal3f(0.0f, 1.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f( w / 2.0f, h / 2.0f,  d / 2.0f);
	glVertex3f( w / 2.0f, h / 2.0f, -d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f,  -d / 2.0f);
	glVertex3f(-w / 2.0f, h / 2.0f,  d / 2.0f);
	glEnd();

	//bottom 
	glNormal3f(0.0f, -1.0f, 0.0f);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(-w / 2.0f, -h / 2.0f, d / 2.0f);
	glVertex3f(-w / 2.0f, -h / 2.0f, -d / 2.0f);
	glVertex3f( w / 2.0f, -h / 2.0f,  -d / 2.0f);
	glVertex3f( w / 2.0f, -h / 2.0f,  d / 2.0f);
	glEnd();
}

void Tester::cBoxGeometry(float w, float h, float d, colorRGB c){

	Position b0; b0.x = w / 2.0f; b0.y = h / 2.0f; b0.z = -d / 2.0f;
	Position b1; b1.x = w / 2.0f; b1.y = h / 2.0f; b1.z =  d / 2.0f;
	Position b2; b2.x = w / 2.0f; b2.y = -h / 2.0f; b2.z = d / 2.0f;
	Position b3; b3.x = w / 2.0f; b3.y = -h / 2.0f; b3.z = -d / 2.0f;

	Position b4; b4.x = -w / 2.0f; b4.y =  h / 2.0f; b4.z = -d / 2.0f;
	Position b5; b5.x = -w / 2.0f; b5.y =  h / 2.0f; b5.z =  d / 2.0f;
	Position b6; b6.x = -w / 2.0f; b6.y = -h / 2.0f; b6.z =  d / 2.0f;
	Position b7; b7.x = -w / 2.0f; b7.y = -h / 2.0f; b7.z = -d / 2.0f;

	b4.y -= 10; b4.z += 20;
	b5.y -= 10; b5.z -= 20;
	b6.y += 30; b6.z -= 20;
	b7.y += 30; b7.z += 20;


	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	glVertex3f(b2.x, b2.y, b2.z);
	glVertex3f(b6.x, b6.y, b6.z);
	glEnd();

	glColor3f(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f);

	Vector3 dir;
	
	//Top front
	dir = getTriNoraml(b1, b5, b6);
	
	glNormal3f(dir.x, dir.y, dir.z);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b1.x, b1.y, b1.z);
	glVertex3f(b5.x, b5.y, b5.z);
	glVertex3f(b6.x, b6.y, b6.z);
	glVertex3f(b2.x, b2.y, b2.z);
	glEnd();

	//back front
	dir = getTriNoraml(b0, b3, b7);

	glNormal3f(dir.x, dir.y, dir.z);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b0.x, b0.y, b0.z);
	glVertex3f(b3.x, b3.y, b3.z);
	glVertex3f(b7.x, b7.y, b7.z);
	glVertex3f(b4.x, b4.y, b4.z);
	glEnd();

	//side right
	dir = getTriNoraml(b0, b1, b2);

	//printf("dx = %f, dy = %f, dz = %f \n", dir.x, dir.y, dir.z);

	glNormal3f(dir.x, dir.y, dir.z);
	//glNormal3f(1, 0, 0);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b0.x, b0.y, b0.z);
	glVertex3f(b1.x, b1.y, b1.z);
	glVertex3f(b2.x, b2.y, b2.z);
	glVertex3f(b3.x, b3.y, b3.z);
	glEnd();

	//back left
	dir = getTriNoraml(b4, b7, b6);

	glNormal3f(dir.x, dir.y, dir.z);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b4.x, b4.y, b4.z);
	glVertex3f(b7.x, b7.y, b7.z);
	glVertex3f(b6.x, b6.y, b6.z);
	glVertex3f(b5.x, b5.y, b5.z);
	glEnd();

	//top 
	dir = getTriNoraml(b0, b4, b5);

	glNormal3f(dir.x, dir.y, dir.z);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b0.x, b0.y, b0.z);
	glVertex3f(b4.x, b4.y, b4.z);
	glVertex3f(b5.x, b5.y, b5.z);
	glVertex3f(b1.x, b1.y, b1.z);
	glEnd();

	//bottom
	dir = getTriNoraml(b2, b6, b7);

	glNormal3f(dir.x, dir.y, dir.z);
	glBegin(GL_POLYGON); // Draw A Quad
	//glColor3i(c.r, c.g, c.b);
	glVertex3f(b2.x, b2.y, b2.z);
	glVertex3f(b6.x, b6.y, b6.z);
	glVertex3f(b7.x, b7.y, b7.z);
	glVertex3f(b3.x, b3.y, b3.z);
	glEnd();

	glLineWidth(2.0);
	glBegin(GL_LINES); // Draw A Quad
	glColor3f(0.2, 0.2, 0.2);
	glVertex3f(b0.x, b0.y, b0.z);
	glVertex3f(b4.x, b4.y, b4.z);
	glEnd();

}

void Tester::pilot(){

	// body
	glPushMatrix();
	glTranslatef(2.0f, -12.0f, 0.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(15, 15, 15, colors.brown);
	glPopMatrix();

	// face
	glPushMatrix();
	//glTranslatef(2.0f, -12.0f, 0.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(10, 10, 10, colors.pink);
	glPopMatrix();

	// hair
	glPushMatrix();
	glTranslatef(-5, 5, 0);
		for (int i = 0; i < 12; i++) {
			float col = floor(i % 3);
			float row = floor(float(i) / 3.0f);
			int startPosZ = -4;
			int startPosX = -4;
			float px = startPosX + row * 4;
			float pz = startPosZ + col * 4;
		
			glPushMatrix();
			glTranslatef(px, 2, pz);
			//glColor3f(0.7, 0.7, 0.7);
			float hs = .95 + cos(angleHairs + i / 3) * 0.25f;
			glScalef(1, hs, 1);
			BoxGeometry(4, 4, 4, colors.brownDark);
			glPopMatrix();
		}
	
		angleHairs += game.speed * deltaTime * 40;

		// hair sideR
		//glPushMatrix();
		//glTranslatef(-5, 5, 0);
			glPushMatrix();
			glTranslatef(-6.0f, 0.0f, 0.0f); 
				glPushMatrix();
				//glTranslatef(-6.0f, 0.0f, 0.0f);
				//glColor3f(0.7, 0.7, 0.7);
				glTranslatef(8.0f, -2.0f, 6.0f);
				BoxGeometry(12, 4, 2, colors.brown);
				glPopMatrix();

				// hair sideL
				glPushMatrix();
				//glTranslatef(-6.0f, 0.0f, 0.0f);
				//glColor3f(0.7, 0.7, 0.7);
				glTranslatef(8.0f, -2.0f, -6.0f);
				BoxGeometry(12, 4, 2, colors.brown);
				glPopMatrix();
			glPopMatrix();

			// hair back
			glPushMatrix();
			glTranslatef(-1.0f, -4.0f, 0.0f);
			//glColor3f(0.7, 0.7, 0.7);
			//glTranslatef(2.0f, 8.0f, 10.0f);
			BoxGeometry(2, 8, 10, colors.brown);
			glPopMatrix();

		glPopMatrix();
	//glPopMatrix();

	// glass R
	glPushMatrix();
	glTranslatef(6.0f, 0.0f, 3.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(5, 5, 5, colors.brown);
	glPopMatrix();

	// glass L
	glPushMatrix();
	glTranslatef(6.0f, 0.0f, -3.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(5, 5, 5, colors.brown);
	glPopMatrix();

	// glass A
	glPushMatrix();
	//glTranslatef(0.0f, 0.0f, -6.0f); 

	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(11, 1, 11, colors.brown);
	glPopMatrix();

	// ear L
	glPushMatrix();
	glTranslatef(0.0f, 0.0f, -6.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(2, 3, 2, colors.pink);
	glPopMatrix();

	// ear R
	glPushMatrix();
	glTranslatef(0.0f, 0.0f, 6.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(2, 3, 2, colors.pink);
	glPopMatrix();

}

void Tester::AirPlane(){

	////glLoadIdentity();
	//glColor3f(1.0f, 0.0f, 0.0f);
	//glutSolidCube(20);

	////glLoadIdentity();
	//glTranslatef(20,0,0);
	//glColor3f(1.0f, 1.0f, 1.0f);
	//glutSolidCube(20);

	////glLoadIdentity();
	//glTranslatef(12.5,0,0);
	//glColor3f(0.0f, 1.0f, 0.0f);
	//glutSolidCube(5);

	////glLoadIdentity();
	//glTranslatef(2.5,0,0);
	//glRotatef(pAngle, 1, 0, 0);
	//glColor3f(1.0f, 0.5f, 0.0f);
	//glScalef(1,50,5);
	//glutSolidCube(1);

	// Cockpit
	glPushMatrix();
	glTranslatef(0.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	cBoxGeometry(80, 50, 50, colors.red);
	glPopMatrix();

	// Engine
	glPushMatrix();
	glTranslatef(50.0f, 0.0f, 0.0f);
	//glColor3f(0.7, 0.7, 0.7);
	BoxGeometry(20, 50, 50, colors.white);
	glPopMatrix();

	// Tail Plane
	glPushMatrix();
	glTranslatef(-40.0f, 20.0f, 0.0f);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(15, 20, 5, colors.white);
	glPopMatrix();

	// Wings
	glPushMatrix();
	glTranslatef(0.0f, 15.0f, 0.0f);
	BoxGeometry(30, 5, 120, colors.white);
	glPopMatrix();

	// Wind Shield
	glPushMatrix();
	glTranslatef(5.0f, 27.0f, 0.0f);
	tBoxGeometry(3, 15, 20, colors.blue, 0.7f);
	glPopMatrix();

	// propeller object
	glPushMatrix();
	glTranslatef(60.0f,0.0f, 0.0f);	
	glRotatef(pAngle, 1, 0, 0);
		// propeller geometry
		glPushMatrix();
		BoxGeometry(20, 10, 10, colors.brown);
		glPopMatrix();

		// blade1
		glPushMatrix();
		glTranslatef(8.0f, 0.0f, 0.0f);
		//glRotatef(pAngle, 1, 0, 0);
		BoxGeometry(1, 80, 10, colors.brownDark);
		glPopMatrix();

		// blade2
		glPushMatrix();
		glTranslatef(8.0f, 0.0f, 0.0f);
		glRotatef(90, 1, 0, 0);
		BoxGeometry(1, 80, 10, colors.brownDark);
		glPopMatrix();
	glPopMatrix();
	
	glPushMatrix();
		glTranslatef(-10, 27,0);
		pilot();
	glPopMatrix();

	// wheel Protec R Geom
	glPushMatrix();
	glTranslatef(25.0f, -20.0f, 25.0f);
	BoxGeometry(30, 15, 10, colors.red);

	//createCylinder(0, 0, 0, 15, 5);
	glPopMatrix();

	// wheel Tire R Geom
	glPushMatrix();
	glTranslatef(25.0f, -28.0f, 25.0f);
	BoxGeometry(24, 24, 4, colors.brownDark);
		// wheel Axis R Geom
		//glPushMatrix();
		//glTranslatef(25.0f, -28.0f, -25.0f);
		BoxGeometry(10, 10, 6, colors.brown);
		//glPopMatrix();
	glPopMatrix();

	// wheel Tire L Geom
	glPushMatrix();
	glTranslatef(25.0f, -28.0f, -25.0f);
	BoxGeometry(24, 24, 4, colors.brownDark);
	// wheel Axis R Geom
	//glPushMatrix();
	//glTranslatef(25.0f, -28.0f, -25.0f);
	BoxGeometry(10, 10, 6, colors.brown);
	//glPopMatrix();
	glPopMatrix();

	// wheel Tire B Geom
	glPushMatrix();
	glTranslatef(-35.0f, -5.0f, 0.0f);
	glScalef(.5, .5, .5);
	BoxGeometry(24, 24, 4, colors.brownDark);
	// wheel Axis R Geom
	//glPushMatrix();
	//glTranslatef(25.0f, -28.0f, -25.0f);
	BoxGeometry(10, 10, 6, colors.brown);
	//glPopMatrix();
	glPopMatrix();

	// wheel Protec L Geom
	glPushMatrix();
	glTranslatef(25.0f, -20.0f, -25.0f);
	BoxGeometry(30, 15, 10, colors.red);
	glPopMatrix();

	//suspension
	glPushMatrix();
	glTranslatef(0.0f, 10.0f, 0.0f);
	glTranslatef(-32.5f, -5.0f, 0.0f);
	glRotatef(-DEG(0.3f), 0, 0, 1);
	BoxGeometry(4, 20, 4, colors.red);
	glPopMatrix();
}

void Tester::Cloud(){
	
	glColor3f(1.0f, 1.0f, 1.0f);
	
}

void Tester::createCylinder(GLfloat centerx, GLfloat centery, GLfloat centerz, GLfloat radius, GLfloat h)
{
    /* function createCyliner()
    원기둥의 중심 x,y,z좌표, 반지름, 높이를 받아 원기둥을 생성하는 함수(+z방향으로 원에서 늘어남)
    centerx : 원기둥 원의 중심 x좌표
    centery : 원기둥 원의 중심 y좌표
    centerz : 원기둥 원의 중심 z좌표
    radius : 원기둥의 반지름
    h : 원기둥의 높이
    */
    GLfloat x, y, angle;
 
	glColor4f(colors.blue.r/255.0f, colors.blue.g/255.0f, colors.blue.b/255.0f, 0.8f);
    glBegin(GL_TRIANGLE_FAN);           //원기둥의 윗면
    //glNormal3f(0.0f, 0.0f, 1.0f);
    //glColor4f(0.5, 0.5, 0.5, 0.8f);
    glVertex3f(centerx, centery, centerz);
	float cylineDivision = 10.0f;
 
    for(angle = 0.0f; angle < (2.0f*PI); angle += (PI/cylineDivision))
    {
        x = centerx + radius*sin(angle);
        y = centery + radius*cos(angle);
        glNormal3f(0.0f, 0.0f, -1.0f);
        glVertex3f(x, y, centerz);
    }
    glEnd();
 
    glBegin(GL_QUAD_STRIP);            //원기둥의 옆면
	//glColor4f(0.5, 0.5, 0.5, 0.8f);
    for(angle = 0.0f; angle < (2.0f*PI); angle += (PI/cylineDivision))
    {
		x = centerx + radius*sin(angle);
        y = centery + radius*cos(angle);
        glNormal3f(sin(angle), cos(angle), 0.0f);
        glVertex3f(x, y, centerz);
        glVertex3f(x, y, centerz + h);
    }
    glEnd();
 
    glBegin(GL_TRIANGLE_FAN);           //원기둥의 밑면
	//glColor4f(0.5, 0.5, 0.5, 0.8f);
    glVertex3f(centerx, centery, centerz + h);
    for(angle = (2.0f*PI); angle > 0.0f; angle -= (PI/cylineDivision))
    {
        x = centerx + radius*sin(angle);
        y = centery + radius*cos(angle);
        glNormal3f(0.0f, 0.0f, 1.0f);
        glVertex3f(x, y, centerz + h);
    }
    glEnd();
}


void Tester::createEnnemies() {
	for (int i=0; i<10; i++){
		Ennemy ennemy;
		/*ennemy.angle = 0.0f;
		ennemy.distance = 0.0f;
		ennemy.positionX = 0.0f;
		ennemy.positionY = 0.0f;
		ennemy.rotationX = 0.0f;
		ennemy.rotationY = 0.0f;
		ennemy.rotationZ = 0.0f;*/
		ennemiesPool.push_back(ennemy);
	}
}

void Tester::createMissles() {
	for (int i = 0; i<5; i++){
		Missle missle;
		misslesPool.push_back(missle);
	}
}

void Tester::spawnEnnemies(){
	int nEnnemies = game.level;

	for (int i=0; i<nEnnemies; i++){
		Ennemy ennemy;
		//if (ennemiesPool.size()) {
		//  ennemy = ennemiesPool[i];
		//}else{
		  ////ennemy = new Ennemy();
		//}

		ennemy.angle = - (i*0.1);
		ennemy.distance = game.seaRadius + game.planeDefaultHeight + (-1 + random() * 2) * (game.planeAmpHeight-20);
		ennemy.positionY = -game.seaRadius + sin(ennemy.angle) * ennemy.distance;
		ennemy.positionX = cos(ennemy.angle)*ennemy.distance;
		ennemy.positionZ = 0;

		//printf("**********  ex = %f, ey = %f \n", ennemy.positionX, ennemy.positionY);
		ennemiesInUse.push_back(ennemy);
	}
}


//좌우 길게 늘어선 건물
void Tester::constructBuilding(){
	
	int nBuildings = game.level;

	//for (int i = 0; i<nBuildings; i++){
		
		//left buildings
		Building building;
		
		building.w = 1200;
		building.d = 100;
		building.h = 300 + random() * 200;
		building.c = colors.blue;
		
		building.positionX = 4000;
		building.positionY = building.h / 2;
		building.positionZ = -200;// +random() * 300;
		building.type = 0;
		buildingsInUse.push_back(building);

		//right buildings
		building.w = 1200;
		building.d = 100;
		building.h = 300 + random() * 200;
		building.c = colors.blue;

		building.positionX = 4000;
		building.positionY = building.h/2;
		building.positionZ = 200; //building.positionZ = -300 + random() * 300;
		building.type = 0;
		buildingsInUse.push_back(building);
	//}
	
		//wall-----------------------------------------------
		building.positionX = 4000;
		
		building.w = 200 + random() * 700; //50;
		building.h = 90 + random() * 70;//50;
		building.d = 110 + random() * 110;//400;
		
		building.positionY = random() * 150 + building.h / 2; //비행기 비행 고도와 맞출것
		building.positionZ = -100 + random() * 200;
		building.c = colors.darkBlue;
		building.type = 1;
		buildingsInUse.push_back(building);

		//타켓 임시 생성 독립 함수로 만들어야 됨
		Target target;
		target.positionX = building.positionX - building.w / 2 - 30;
		target.positionY = building.positionY;
		target.positionZ = building.positionZ;

		targetsInUse.push_back(target);
}

//외곽지대 저층 건물 형상 구현
void Tester::buildStructures() {

	int nStructures = 1 + floor(random() * 5);

	for (int i = 0; i < nStructures; i++) {
		Building building;
		building.positionX = 4000;
		building.positionY = 0;
		building.positionZ = -1000 + random() * 650;  //building.positionZ = -1000 + random() * 850;
		building.h = 30 + random() * 50;
		building.w = 30 + random() * 50;
		building.d = 30 + random() * 50;
		building.c = colors.white;

		structuresInUse.push_back(building);
	}

	for (int i = 0; i < nStructures; i++) {
		Building building;
		building.positionX = 4000;
		building.positionY = 0;
		building.positionZ = 350 + random() * 1000; //building.positionZ = 150 + random() * 1000;
		building.h = 30 + random() * 50;
		building.w = 30 + random() * 50;
		building.d = 30 + random() * 50;
		building.c = colors.white;

		structuresInUse.push_back(building);
	}

	Building building;
	building.positionX = 4000;
	building.positionY = 0;
	building.positionZ = 0;
	building.h = 1;
	building.w = 30;
	building.d = 10;
	building.c = colors.pink;

	structuresInUse.push_back(building);

}


void Tester::moveBuildings(){

	for (int i = 0; i< buildingsInUse.size(); i++){
		Building building = buildingsInUse[i];
		building.positionX -= game.speed*deltaTime*game.ennemiesSpeed * 5000;
		//building.positionY = //building.h / 2;

		//building bounding box
		building.b0.x = building.positionX + building.w / 2; building.b0.y = building.positionY - building.h / 2; building.b0.z = building.positionZ + building.d / 2;
		building.b1.x = building.positionX + building.w / 2; building.b1.y = building.positionY - building.h / 2; building.b1.z = building.positionZ - building.d / 2;
		building.b2.x = building.positionX + building.w / 2; building.b2.y = building.positionY + building.h / 2; building.b2.z = building.positionZ - building.d / 2;
		building.b3.x = building.positionX + building.w / 2; building.b3.y = building.positionY + building.h / 2; building.b3.z = building.positionZ + building.d / 2;

		building.b4.x = building.positionX - building.w / 2; building.b4.y = building.positionY - building.h / 2; building.b4.z = building.positionZ + building.d / 2;
		building.b5.x = building.positionX - building.w / 2; building.b5.y = building.positionY - building.h / 2; building.b5.z = building.positionZ - building.d / 2;
		building.b6.x = building.positionX - building.w / 2; building.b6.y = building.positionY + building.h / 2; building.b6.z = building.positionZ - building.d / 2;
		building.b7.x = building.positionX - building.w / 2; building.b7.y = building.positionY + building.h / 2; building.b7.z = building.positionZ + building.d / 2;

		buildingsInUse[i] = building;

		float diffPosX = airplanePos.x - building.positionX;
		float diffPosY = airplanePos.y - building.positionY;

		float d = sqrt(pow((airplanePos.x - building.positionX), 2) + pow((airplanePos.y - building.positionY), 2) + pow((airplanePos.z - building.positionZ), 2));

		if (building.b4.y < airplanePos.a0.y && airplanePos.a0.y < building.b7.y ||
			building.b4.y < airplanePos.a3.y && airplanePos.a3.y < building.b7.y ||
			building.b4.y < airplanePos.a1.y && airplanePos.a1.y < building.b7.y ||
			building.b4.y < airplanePos.a2.y && airplanePos.a2.y < building.b7.y) {
			if (building.b5.z < airplanePos.a0.z && airplanePos.a0.z < building.b7.z ||
				building.b5.z < airplanePos.a3.z && airplanePos.a3.z < building.b7.z ||
				building.b5.z < airplanePos.a1.z && airplanePos.a1.z < building.b7.z ||
				building.b5.z < airplanePos.a2.z && airplanePos.a2.z < building.b7.z) {
					if (sqrt(diffPosX * diffPosX) < game.ennemyDistanceTolerance) {

						//buildingsInUse.erase(buildingsInUse.begin() + i);

						game.planeCollisionSpeedX = 100 * diffPosX / d;
						game.planeCollisionSpeedY = 100 * diffPosY / d;
					}
			}
		}

		for (int j = 0; j < misslesInUse.size(); j++) {
			Missle missle = misslesInUse[j];
			
			diffPosX = missle.positionX - (building.b5.x);

			float d = sqrt(pow((missle.positionX - building.positionX), 2) + pow((missle.positionY - building.positionY), 2) + pow((missle.positionZ - building.positionZ), 2));

			if (building.b4.y < missle.positionY && missle.positionY < building.b7.y ) {
				if (building.b5.z < missle.positionZ && missle.positionZ < building.b7.z) {
					if (sqrt(diffPosX * diffPosX) < game.ennemyDistanceTolerance + 10) {

						cout << " b hit " << endl;

						missle.positionX = building.b5.x; // 빌딩 벽 면으로 위치 이동
						//spawnParticles(missle, 15, 1, 20);
						Position pos;
						pos.x = missle.positionX; pos.y = missle.positionY; pos.z = missle.positionZ;
						makeWhiteSpheres(pos);

						misslesInUse.erase(misslesInUse.begin() + j);
						j--;
					}
				}
			}
		}
		

		if (building.positionX < -1000) {
			buildingsInUse.erase(buildingsInUse.begin() + i);
			i--;
		}
	}


	//임시 타겟 이동------------------------------------------------------
	for (int i = 0; i < targetsInUse.size(); i++){
		Target target = targetsInUse[i];
		target.positionX -= game.speed*deltaTime*game.ennemiesSpeed * 5000;

		targetsInUse[i] = target;

		if (target.positionX < -1000) {
			targetsInUse.erase(targetsInUse.begin() + i);
			i--;
		}
	}
}

void Tester::moveStructures(){

	float min = 1000000.0f;
	for (int i = 0; i< structuresInUse.size(); i++){
		Building building = structuresInUse[i];
		building.positionX -= game.speed*deltaTime*game.ennemiesSpeed * 5000;
		//building.positionY = //building.h / 2;

		structuresInUse[i] = building;

		if (building.positionX < -1000) {
			structuresInUse.erase(structuresInUse.begin() + i);
			i--;
		}
	}
}

void Tester::rotateEnnemies() {

	float min = 1000000.0f;
	for (int i=0; i<ennemiesInUse.size(); i++){
		Ennemy ennemy = ennemiesInUse[i];
		ennemy.angle += game.speed*deltaTime*game.ennemiesSpeed;

		if (ennemy.angle > PI*2) ennemy.angle -= PI*2;

		ennemy.positionY = -game.seaRadius + sin(ennemy.angle)*ennemy.distance;
		ennemy.positionX = cos(ennemy.angle)*ennemy.distance;
		ennemy.positionZ = 0;

		ennemy.rotationZ += random()*.1 * 180.0f / PI;
		ennemy.rotationY += random()*.1 * 180.0f / PI;

		ennemiesInUse[i] = ennemy;

		//printf(" ez = %f \n ", ennemy.rotationZ);

		////var globalEnnemyPosition =  ennemy.mesh.localToWorld(new THREE.Vector3());
		//float diffPos = airplane.mesh.position.clone().sub(ennemy.mesh.position.clone());
		float diffPosX = airplanePos.x - ennemy.positionX;
		float diffPosY = airplanePos.y - ennemy.positionY;

		//float d = diffPosX * diffPosX + diffPosY * diffPosY;

		float d = sqrt(pow((airplanePos.x - ennemy.positionX),2) + pow((airplanePos.y - ennemy.positionY),2) + pow((airplanePos.z - ennemy.positionZ),2));
		
		//var d = diffPos.length();
		if (d < game.ennemyDistanceTolerance ){

			//printf("collision %f \n", d);
			//particlesHolder.spawnParticles(ennemy.mesh.position.clone(), 15, Colors.red, 3);
			spawnParticles(ennemy, 15, 1, 9);

			//ennemiesPool.unshift(this.ennemiesInUse.splice(i,1)[0]);
			//this.mesh.remove(ennemy.mesh);

			ennemiesInUse.erase(ennemiesInUse.begin() + i);
							
			game.planeCollisionSpeedX = 100 * diffPosX / d;
			game.planeCollisionSpeedY = 100 * diffPosY / d;
			//ambientLight.intensity = 2;

			removeEnergy();
			i--;
		}else if (ennemy.angle > PI){
			//ennemiesPool.unshift(this.ennemiesInUse.splice(i,1)[0]);
			//this.mesh.remove(ennemy.mesh);

			ennemiesInUse.erase(ennemiesInUse.begin() + i);
			i--;
		}
  }

}

//void Tester::createCoins() {
//	for (int i = 0; i < nCoins; i++) {
//		Coin coin;
//		coinsPool.push_back(coin);
//	}
//}

void Tester::spawnCoins() {
	int nCoins = 1 + floor(random() * 10);
	float d = game.seaRadius + game.planeDefaultHeight + (-1 + random() * 2) * (game.planeAmpHeight - 20);
	float amplitude = 10 + round(random() * 10);
	for (int i = 0; i<nCoins; i++){
		Coin coin;
		//if (coinsPool.size()) {
		//	coin = coinsPool[i];
		//}
		//else{
		//	//coin = new Coin();
		//}
				
		coin.angle = -(i*0.02);
		coin.distance = d + cos(i*.5)*amplitude;
		coin.positionY = -game.seaRadius + sin(coin.angle)*coin.distance;
		coin.positionX = cos(coin.angle)*coin.distance;
		coin.positionZ = 0;

		coinsInUse.push_back(coin);
	}
}

void Tester::rotateCoins() {
	for (int i = 0; i<coinsInUse.size(); i++){
		Coin coin = coinsInUse[i];
		//if (coin.exploding) continue;
		coin.angle += game.speed*deltaTime*game.coinsSpeed;
		if (coin.angle > PI * 2) coin.angle -= PI * 2;
		coin.positionY = -game.seaRadius + sin(coin.angle)*coin.distance;
		coin.positionX = cos(coin.angle)*coin.distance;
		coin.rotationZ += random()*.1 * 180.0f/PI;
		coin.rotationY += random()*.1 * 180.0f/PI;

		coinsInUse[i] = coin;

		//var globalCoinPosition =  coin.mesh.localToWorld(new THREE.Vector3());
		//var diffPos = airplane.mesh.position.clone().sub(coin.mesh.position.clone());
		//var d = diffPos.length();
		
		float d = sqrt(pow((airplanePos.x - coin.positionX), 2) + pow((airplanePos.y - coin.positionY), 2) + pow((airplanePos.z - coin.positionZ), 2));

		if (d < game.coinDistanceTolerance){
			//this.coinsPool.unshift(this.coinsInUse.splice(i, 1)[0]);
			//this.mesh.remove(coin.mesh);
			//printf("get coin \n");
			coinsInUse.erase(coinsInUse.begin() + i);
			
			Ennemy ennemy;
			ennemy.positionX = coin.positionX;
			ennemy.positionY = coin.positionY;

			spawnParticles(ennemy, 5, 2, 3);
			addEnergy();
			i--;
		}
		else if (coin.angle > PI){
			coinsInUse.erase(coinsInUse.begin() + i);
			//this.mesh.remove(coin.mesh);
			i--;
		}
	}
}

//void Tester::createParticles(){
//	for (int i = 0; i<10; i++){
//		Particle particle;
//		particlesPool.push_back(particle);
//	}
//	//particlesHolder = new ParticlesHolder();
//	////ennemiesHolder.mesh.position.y = -game.seaRadius;
//	//scene.add(particlesHolder.mesh)
//}

void Tester::explode(Position pos, int color, int scale) {
	//var _this = this;
	//var _p = this.mesh.parent;
	//this.mesh.material.color = new THREE.Color(color);
	//this.mesh.material.needsUpdate = true;
	///this.mesh.scale.set(scale, scale, scale);
	float targetX = pos.x; //+ (-1 + random() * 2) * 50;
	float targetY = pos.y; //+ (-1 + random() * 2) * 50;
	float targetZ = pos.z;
	float speed = .6 + random()*.2;
	
	Particle pe;
	//pe.rotationX = max(speed, );
	
	pe.rotationX = 0; //random() * 12;
	pe.rotationZ = 0; //random() * 12;
	pe.positionX = targetX;
	pe.positionY = targetY;
	pe.positionZ = targetZ;

	pe.color = color;

	pe.incZ = (-1 + random() * 2);
	pe.incY = (-1 + random() * 2);
	//pe.incX = (-1 + random() * 2);

	pe.incRZ = random() * 12;;
	pe.incRX = random() * 12;;

	pe.onTime = 0.0f;
	pe.durationTime = 0.3f; //random() + 1;

	pe.scale = scale;

	pe.stime = timeGetTime();

	particlesInUse.push_back(pe);
	
	/*TweenMax.to(this.mesh.rotation, speed, { x:Math.random() * 12, y : Math.random() * 12 });
	TweenMax.to(this.mesh.scale, speed, { x:.1, y : .1, z : .1 });
	TweenMax.to(this.mesh.position, speed, { x:targetX, y : targetY, delay : Math.random() *.1, ease : Power2.easeOut, onComplete : function(){
		if (_p) _p.remove(_this.mesh);
		_this.mesh.scale.set(1, 1, 1);
		particlesPool.unshift(_this);
	} });*/
}

void Tester::spawnParticles(Ennemy e, int density, int color, int scale){

	int nPArticles = density;
	for (int i = 0; i<nPArticles; i++){
		Particle particle;
		//if (particlesPool.size()) {
		//	particle = particlesPool[i];
		//}
		//else{
		//	//particle = new Particle();
		//}
		//this.mesh.add(particle.mesh);
		//particle.mesh.visible = true;
		//var _this = this;
		
		particle.positionY = e.positionY;
		particle.positionX = e.positionX;

		Position pos;
		pos.x = e.positionX; pos.y = e.positionY; pos.z = e.positionZ;
		explode(pos, color, scale);
	}

}

void Tester::spawnParticles(Target t, int density, int color, int scale){

	int nPArticles = density;
	for (int i = 0; i<nPArticles; i++){
		Particle particle;
		//if (particlesPool.size()) {
		//	particle = particlesPool[i];
		//}
		//else{
		//	//particle = new Particle();
		//}
		//this.mesh.add(particle.mesh);
		//particle.mesh.visible = true;
		//var _this = this;

		particle.positionY = t.positionY;
		particle.positionX = t.positionX;

		Position pos;
		pos.x = t.positionX; pos.y = t.positionY; pos.z = t.positionZ;
		explode(pos, color, scale);
	}

}

void Tester::spawnParticles(Missle m, int density, int color, int scale){

	int nPArticles = density;
	for (int i = 0; i<nPArticles; i++){
		Particle particle;
		//if (particlesPool.size()) {
		//	particle = particlesPool[i];
		//}
		//else{
		//	//particle = new Particle();
		//}
		//this.mesh.add(particle.mesh);
		//particle.mesh.visible = true;
		//var _this = this;

		particle.positionY = m.positionY;
		particle.positionX = m.positionX;

		Position pos;
		pos.x = m.positionX; pos.y = m.positionY; pos.z = m.positionZ;
		explode(pos, color, scale);
	}

}

void Tester::makeWhiteSpheres(Position pos){

	int numSpheres = 7 + random() * 20;

	for (int i = 0; i < numSpheres; i++) {
		float targetX = pos.x; //+ (-1 + random() * 2) * 50;
		float targetY = pos.y; //+ (-1 + random() * 2) * 50;
		float targetZ = pos.z;
		float speed = .6 + random()*.2;

		whiteSphere ws;
		//pe.rotationX = max(speed, );

		ws.positionX = targetX -15 + random() * 25;
		ws.positionY = targetY -15 + random() * 25;
		ws.positionZ = targetZ -15 + random() * 25;

		if (i % 5 == 0) ws.c = colors.brownDark;
		else ws.c = colors.pureWhite;

		//targetX = pos.x -5 + random() * 10;
		//targetX = pos.y -5 + random() * 10;
		//targetX = pos.z -5 + random() * 10;

		ws.sp.x = 0; ws.sp.y = 0; ws.sp.z = 0;

		targetX =  - 5 + random() * 10;
		targetY =  - 5 + random() * 10;
		targetZ =  - 5 + random() * 10;

		ws.ep.x = targetX; ws.ep.y = targetY; ws.ep.z = targetZ;

		ws.onTime = 0.0f;
		ws.durationTime = 0.9f; //random() + 1;

		ws.scale = 2 + random() * 3;

		ws.stime = timeGetTime();

		whteSpheresInUse.push_back(ws);
	}
}

void Tester::drawMissle(){

	// head
	glPushMatrix();
	glTranslatef(0.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(20, 5, 5, colors.red);
	glPopMatrix();

	// head2
	glPushMatrix();
	glTranslatef(-15.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(10, 10, 10, colors.darkBlue);
	glPopMatrix();

	// head2
	glPushMatrix();
	glTranslatef(-20.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(10, 20, 20, colors.white);
	glPopMatrix();

	// body
	glPushMatrix();
	glTranslatef(-50.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(50, 20, 20, colors.red);
	glPopMatrix();

	// wing
	glPushMatrix();
	glTranslatef(-70.0f, 0.0f, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(5, 2, 35, colors.white);
	glPopMatrix();

	// wing2
	glPushMatrix();
	glTranslatef(-70.0f, 0.0f, 0);
	glRotatef(270, 1, 0, 0);
	//glColor3f(0.7, 0, 0);
	BoxGeometry(5, 2, 35, colors.white);
	glPopMatrix();
}

void Tester::guideLines(Building building){

	Vector3 a3(airplanePos.a3.x, airplanePos.a3.y, airplanePos.a3.z);
	Vector3 a7(airplanePos.a7.x, airplanePos.a7.y, airplanePos.a7.z);

	Vector3 b4(building.b4.x, building.b4.y, building.b4.z);
	Vector3 b5(building.b5.x, building.b5.y, building.b5.z);
	Vector3 b6(building.b6.x, building.b6.y, building.b6.z);
	Vector3 b7(building.b7.x, building.b7.y, building.b7.z);

	Vector3 v;
	v.Subtract(a3, a7);

	Vector3 line;

	float t = 200;
	v.Scale(t);
	line.Add(a3, v);

	glLineWidth(1.0);
	glBegin(GL_LINES);
	glVertex3f(airplanePos.a7.x, airplanePos.a7.y, airplanePos.a7.z);
	glVertex3f(line.x, line.y, line.z);
	glEnd();
	//-------------------------------------------------------------------------------

	//평면과 직선의 교차-------------------------------------------------------------
	Vector3 N, bFace, P, P1, P2, P3, PP3, Na, Nb, P31, P21, Pt;
	//P = b4;
	P1 = a7;
	P2 = a3;

	Pt.Add(b4, b7);
	Pt.Scale(0.5);
	P3 = b7;

	P31.Subtract(P3, P1); P21.Subtract(P2, P1);

	Na.Subtract(b7, b4); Nb.Subtract(b5, b4);

	N.Cross(Na, Nb); N.Mag();

	float u, ub, uu;
	ub = N.Dot(P21);
	uu = N.Dot(P31);

	u = uu / ub;
	if (ub != 0.0f) {
		//printf("ub = %f \n", u);
	}

	Vector3 lfLine;
	P21.Scale(u);
	lfLine.Add(P1, P21);

	//glPointSize(20);

	GLfloat y, z, angle;

	if (building.b4.y < lfLine.y && lfLine.y < building.b7.y &&
		building.b5.z < lfLine.z && lfLine.z < building.b7.z) {

		int circleDivision = 20;
		int radius = 15;
		
		glLineWidth(2.0);
		glColor3f(1,1,1);
		glBegin(GL_LINE_LOOP); //glBegin(GL_POINTS);
		for (int i = 0; i< circleDivision; i++){
			float angle = PI * 2 * float(i) / float(circleDivision);
			y = lfLine.y + radius*sinf(angle);
			z = lfLine.z + radius*cosf(angle);
			//glNormal3f(0.0f, 0.0f, -1.0f);
			glVertex3f(lfLine.x, y ,z);
		}
		glEnd();
		
	/*	Target target;
		target.positionX = lfLine.x;
		target.positionY = lfLine.y;
		target.positionZ = lfLine.z;
		
		targetsInUse.push_back(target);*/
		
		//glVertex3f(b7.x, b7.y, b7.z);
		//glVertex3f(lfLine.x, lfLine.y, lfLine.z);
		//glEnd();
		//glPopMatrix();
	}
}

////////////////////////////////////////////////////////////////////////////////

//shadow---------------------------------------------------------------------------------------
// Called to draw scene objects
void Tester::DrawModels(void)
{
	// Draw plane that the objects rest on
	glColor3f(0.0f, 0.0f, 0.90f); // Blue
	glNormal3f(0.0f, 1.0f, 0.0f);
	glBegin(GL_QUADS);
	glVertex3f(-100.0f, -25.0f, -100.0f);
	glVertex3f(-100.0f, -25.0f, 100.0f);
	glVertex3f(100.0f, -25.0f, 100.0f);
	glVertex3f(100.0f, -25.0f, -100.0f);
	glEnd();

	// Draw red cube
	glPushMatrix();
	glRotatef(45.0f, 1.0f, 1.0f, 0.0f);
	glColor3f(1.0f, 0.0f, 0.0f);
	glutSolidCube(48.0f);
	glPopMatrix();
}

// Called to regenerate the shadow map
void Tester::RegenerateShadowMap(void)
{
	GLfloat lightToSceneDistance, nearPlane, fieldOfView;
	GLfloat lightModelview[16], lightProjection[16];

	// Save the depth precision for where it's useful
	lightToSceneDistance = sqrt(lightPos[0] * lightPos[0] + lightPos[1] * lightPos[1] + lightPos[2] * lightPos[2]);
	nearPlane = lightToSceneDistance - 150.0f;
	if (nearPlane < 50.0f)
		nearPlane = 50.0f;
	// Keep the scene filling the depth texture
	fieldOfView = 17000.0f / lightToSceneDistance;

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(fieldOfView, 1.0f, nearPlane, nearPlane + 300.0f);
	glGetFloatv(GL_PROJECTION_MATRIX, lightProjection);
	//// Switch to light's point of view
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	gluLookAt(lightPos[0], lightPos[1], lightPos[2], 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f);
	glGetFloatv(GL_MODELVIEW_MATRIX, lightModelview);
	glViewport(0, 0, shadowSize, shadowSize);

	// Clear the window with current clearing color
	glClear(GL_DEPTH_BUFFER_BIT);

	// All we care about here is resulting depth values
	glShadeModel(GL_FLAT);
	glDisable(GL_LIGHTING);
	glDisable(GL_COLOR_MATERIAL);
	glDisable(GL_NORMALIZE);
	glColorMask(0, 0, 0, 0);

	// Overcome imprecision
	glEnable(GL_POLYGON_OFFSET_FILL);

	// Draw objects in the scene
	DrawModels();
	AirPlane();

	// Copy depth values into depth texture
	glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, 0, 0, shadowSize, shadowSize, 0);

	// Restore normal drawing state
	glShadeModel(GL_SMOOTH);
	glEnable(GL_LIGHTING);
	glEnable(GL_COLOR_MATERIAL);
	glEnable(GL_NORMALIZE);
	glColorMask(1, 1, 1, 1);
	glDisable(GL_POLYGON_OFFSET_FILL);

	// Set up texture matrix for shadow map projection
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glTranslatef(0.5f, 0.5f, 0.5f);
	glScalef(0.5f, 0.5f, 0.5f);
	glMultMatrixf(lightProjection);
	glMultMatrixf(lightModelview);
}

// Called to draw scene
void Tester::RenderScene(void)
{
	// Track camera angle
	//glMatrixMode(GL_PROJECTION);
	//glLoadIdentity();
	//gluPerspective(45.0f, 1.0f, 1.0f, 1000.0f);
	//glMatrixMode(GL_MODELVIEW);
	//glLoadIdentity();
	//gluLookAt(cameraPos[0], cameraPos[1], cameraPos[2], 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f);
	//glViewport(0, 0, windowWidth, windowHeight);

	// Track light position
	glLightfv(GL_LIGHT0, GL_POSITION, lightPos);

	// Clear the window with current clearing color
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	GLfloat sPlane[4] = { 1.0f, 0.0f, 0.0f, 0.0f };
	GLfloat tPlane[4] = { 0.0f, 1.0f, 0.0f, 0.0f };
	GLfloat rPlane[4] = { 0.0f, 0.0f, 1.0f, 0.0f };
	GLfloat qPlane[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

	GLfloat lowAmbient[4] = { 0.1f, 0.1f, 0.1f, 1.0f };
	GLfloat lowDiffuse[4] = { 0.35f, 0.35f, 0.35f, 1.0f };

	// Because there is no support for an "ambient"
	// shadow compare fail value, we'll have to
	// draw an ambient pass first...
	glLightfv(GL_LIGHT0, GL_AMBIENT, lowAmbient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, lowDiffuse);

	// Draw objects in the scene
	DrawModels();
	AirPlane();

	// Enable alpha test so that shadowed fragments are discarded
	glAlphaFunc(GL_GREATER, 0.9f);
	glEnable(GL_ALPHA_TEST);


	glLightfv(GL_LIGHT0, GL_AMBIENT, ambientLight);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, diffuseLight);

	// Set up shadow comparison
	glEnable(GL_TEXTURE_2D);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_R_TO_TEXTURE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	// Set up the eye plane for projecting the shadow map on the scene
	glEnable(GL_TEXTURE_GEN_S);
	glEnable(GL_TEXTURE_GEN_T);
	glEnable(GL_TEXTURE_GEN_R);
	glEnable(GL_TEXTURE_GEN_Q);
	glTexGenfv(GL_S, GL_EYE_PLANE, sPlane);
	glTexGenfv(GL_T, GL_EYE_PLANE, tPlane);
	glTexGenfv(GL_R, GL_EYE_PLANE, rPlane);
	glTexGenfv(GL_Q, GL_EYE_PLANE, qPlane);

	// Draw objects in the scene
	DrawModels();

	glDisable(GL_ALPHA_TEST);
	glDisable(GL_TEXTURE_2D);
	glDisable(GL_TEXTURE_GEN_S);
	glDisable(GL_TEXTURE_GEN_T);
	glDisable(GL_TEXTURE_GEN_R);
	glDisable(GL_TEXTURE_GEN_Q);

	//glutSwapBuffers();
}

// This function does any needed initialization on the rendering
// context. 
void Tester::SetupRC()
{
	// Black background
	glClearColor(1.0f, 1.0f, 1.0f, 1.0f);

	// Hidden surface removal
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	glPolygonOffset(factor, 0.0f);

	// Set up some lighting state that never changes
	glShadeModel(GL_SMOOTH);
	glEnable(GL_LIGHTING);
	glEnable(GL_COLOR_MATERIAL);
	glEnable(GL_NORMALIZE);
	glEnable(GL_LIGHT0);

	// Set up some texture state that never changes
	glGenTextures(1, &shadowTextureID);
	glBindTexture(GL_TEXTURE_2D, shadowTextureID);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D, GL_DEPTH_TEXTURE_MODE, GL_INTENSITY);

	glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
	glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
	glTexGeni(GL_R, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
	glTexGeni(GL_Q, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);

	//RegenerateShadowMap();
}
//---------------------------------------------------------------------------------------

void Tester::Draw() {
	// Begin drawing scene
	glViewport(0, 0, WinX, WinY);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); //투명 가능

	//glEnable(GL_POLYGON_SMOOTH);
	//glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);

	//glfwWindowHint(GLFW_SAMPLES, 4);
	//glEnable(GLUT_MULTISAMPLE);

	 //for the light---------------------
    glEnable(GL_DEPTH_TEST);
	glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
	glEnable(GL_NORMALIZE);
	glShadeModel(GL_SMOOTH);

	GLfloat lightpos[] = { 1200, 1200, 1200, 1 }; //GLfloat lightpos[] = { 900, 1500, 1500, 1 };

    glLightfv(GL_LIGHT0, GL_POSITION, lightpos);
	GLfloat ambient[4] = { 0.5, 0.5, 0.5, 0.5f };  //GLfloat ambient[4] = { 220 / 255.0f, 136 / 255.0f, 116 / 255.0f, 0.5f };
    glLightfv(GL_LIGHT0,GL_AMBIENT,ambient);

	GLfloat diffuse[] = { 1, 1, 1, 1.0 };

    glLightfv(GL_LIGHT0,GL_DIFFUSE,diffuse);
    GLfloat spec[] = { 1.0, 1.0, 1.0, 1.0 };
    //glLightfv(GL_LIGHT0,GL_SPECULAR,spec);

    glEnable(GL_COLOR_MATERIAL);
    glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);
	//-----------------------------------------

	Cam.Draw();

	//glPushMatrix();
	//RenderScene();
	//glPopMatrix();

	//glLineWidth(2.0);
	//glBegin(GL_LINES); // Draw A Quad
	//glColor3i(0.3, 0.3, 0.3);
	//glVertex3f(0, 0, 0);
	//glVertex3f(airplanePos.x, airplanePos.y, airplanePos.z);
	////glVertex3f(w / 2.0f, h / 2.0f, d / 2.0f);
	////glVertex3f(-w / 2.0f, h / 2.0f, d / 2.0f);
	//glEnd();

	//glNormal3f(1.0f,0.0f, 0.0f);
	//glColor3f(colors.red.r/255.0f, colors.red.b/255.0f, colors.red.g/255.0f);
	//glBegin(GL_POLYGON);/* f1: front */
	//  glVertex3f(0.0f,0.0f, 0.0f);
	//  glVertex3f(0.0f,0.0f, 100.0f);
	//  glVertex3f(0.0f,100.0f, 100.0f);
	//  glVertex3f(0.0f,100.0f, 0.0f);
	//glEnd();

	/*glBegin(GL_POINTS);
	for(int r = 1; r < 100; ++r)
	{
		glVertex2i(2, r * random());
	}
	glEnd();*/

	//BoxGeometry(100, 150, 200, colors.red);

	//glPushMatrix();
	//	glRotatef(-50, 0,1,0);
	//	glRotatef(-10, 0,0,1);

	//사면쳋 그리기-------------------------
	//glPushMatrix();
	//	glScalef(1,1,2);
	//	test();
	//glPopMatrix();
	//--------------------------------------

	//glPointSize(10);
	//	glBegin(GL_POINTS);
	//		glVertex3f(-63.4951, 177.22, 0);
	//	glEnd();

	//glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH | GLUT_MULTISAMPLE);
	//glEnable(GLUT_MULTISAMPLE);
	
	// Draw components
	//Cam.Draw();		// Sets up projection & viewing matrices

	//Draw Airplane----------------------------------------------------
	//임시 비행기 크기 ------------------------------------------------------
	glPushMatrix();
	glBegin(GL_LINES);
	glVertex3f(airplanePos.a0.x, airplanePos.a0.y, airplanePos.a0.z);
	glVertex3f(airplanePos.a1.x, airplanePos.a1.y, airplanePos.a1.z);
	glEnd();

	//printf("abx = %f  aby = %f \n", airplanePos.a0.x, airplanePos.y);

	glBegin(GL_LINES);
	glVertex3f(airplanePos.a6.x, airplanePos.a6.y, airplanePos.a6.z);
	glVertex3f(airplanePos.a7.x, airplanePos.a7.y, airplanePos.a7.z);
	glEnd();
	glPopMatrix();

	glPushMatrix(); 
	glTranslatef(airplanePos.x -25.0f, airplanePos.y, airplanePos.z); // 비행기 중심으로 비행기 동체 이동(비행기동체길이/2 = 16.25)  //glTranslatef(airplanePos.x, airplanePos.y, 0);
	glScalef(game.planeScale, game.planeScale, game.planeScale); // scale translate 보다 먼저 오면 좌표 값이 정상좌표보다 커짐.
		glRotatef(airplanePos.rz, 0,0,1);
		glRotatef(airplanePos.rx, 1,0,0);
			AirPlane();
			//RenderScene();
	glPopMatrix();
	//-----------------------------------------------------------------

	//Draw buildings----------------------------------------------------
	BoxGeometry(9000, 1, 9000, colors.white); //land

	for (int i = 0; i<buildingsInUse.size(); i++) {
		Building building = buildingsInUse[i];

		//임시 라인-----------------------------------------------
		glColor3f(1,0,0);
		glLineWidth(3);
		glBegin(GL_LINES);
		glVertex3f(building.b6.x, building.b6.y, building.b6.z);
		glVertex3f(building.b7.x, building.b7.y, building.b7.z);
		glVertex3f(building.b4.x, building.b4.y, building.b4.z);
		glVertex3f(building.b5.x, building.b5.y, building.b5.z);
		glEnd();
		//---------------------------------------------------------

		guideLines(building);
		
		glPushMatrix();
			glTranslatef(building.positionX, building.positionY, building.positionZ);
			//glColor3f(0.3f, 0.3f, 0.3f);
			if (building.type == 0) BoxGeometry(building.w, building.h, building.d, building.c);
			if (building.type == 1) tBoxGeometry(building.w, building.h, building.d, building.c, 0.7f);

			//glScalef(50, 50, 50);
			//glutSolidIcosahedron();
		glPopMatrix();
	}

	//Draw structures----------------------------------------------------
	for (int i = 0; i<structuresInUse.size(); i++) {
		Building building = structuresInUse[i];
		glPushMatrix();
		glTranslatef(building.positionX, building.positionY + building.h / 2, building.positionZ);
		//glColor3f(0.3f, 0.3f, 0.3f);
		BoxGeometry(building.w, building.h, building.d, building.c);
		glPopMatrix();
	}

	//Darw Clouds------------------------------------------------------
	/*glPushMatrix();
		glTranslatef(0,-100,0);
		glRotatef(skyAngle, 0,0,1);   //clouds rotation
		for(int i=0; i< clouds.size(); i++){
			cloud tc = clouds[i];
			glPushMatrix();
				glTranslatef(tc.x, tc.y, tc.pz);
				
				glRotatef(tc.rz , 0,0,1);
				glScalef(tc.s, tc.s, tc.s);
				for(int j=0; j<tc.cube.size(); j++){
					glPushMatrix();
					box tb = tc.cube[j];
					tb.rz += DEG(random()*.005*(j + 1));
					tb.ry += DEG(random()*.002*(j + 1));
					tc.cube[j] = tb;  //갱신된 값을 벡터에 다시 할당해야 변수 값이 업데이트됨
					glTranslatef(tb.px, tb.py, tb.pz);
					glRotatef(tb.rz, 0,0,1);
					glRotatef(tb.ry, 0,1,0);
					glScalef(tb.s,tb.s,tb.s);
					glColor3f(colors.white.r / 255.0f, colors.white.g / 255.0f, colors.white.b / 255.0f);
				
					glutSolidCube(5);
				
					glPopMatrix();
				}
				clouds[i] = tc;  //갱신된 값을 벡터에 다시 할당해야 변수 값이 업데이트됨
			glPopMatrix();
		}  
	glPopMatrix(); */
	//-----------------------------------------------------------------

	//draw sea---------------------------------------------------------
	/*glPushMatrix();
	glTranslatef(0, -game.seaRadius, -game.seaLength/2.0f);
	glRotatef(seaAngle, 0,0,1);
	createCylinder(0, 0, 0, game.seaRadius, game.seaLength);
	glPopMatrix();*/
	//-----------------------------------------------------------------

	//Wave terrain -------------------------------------------------------------------
	/* //glFrontFace(GL_CCW);
	glColor4f(colors.blue.r / 255.0f, colors.blue.g / 255.0f, colors.blue.b / 255.0f, 0.5f); //glColor4f(0.3f, 0.9f, 0.0f, 0.3f);
	for (int z = 0; z < _terrain->length() - 1; z++) {
		//Makes OpenGL draw a triangle at every three consecutive vertices
		glPushMatrix();
		glTranslatef(-game.waveLength * game.waveSacle / 2, -100, -game.waveHeight * game.waveSacle / 2);
		glScalef(game.waveSacle, game.waveSacle, game.waveSacle);

		glBegin(GL_TRIANGLE_STRIP);
		for (int x = 0; x < _terrain->width(); x++) {
			Vector3 normal = _terrain->getNormal(x, z);
			glNormal3f(normal[0], normal[1], normal[2]);
			glVertex3f(x, _terrain->getHeight(x, z), z);
			normal = _terrain->getNormal(x, z + 1);
			glNormal3f(normal[0], normal[1], normal[2]);
			glVertex3f(x, _terrain->getHeight(x, z + 1), z + 1);
		}
		glEnd();
		glPopMatrix();
	}*/
	//-------------------------------------------------------------------


	//draw coins-----------------------------------------------------
	/*for (int i = 0; i<coinsInUse.size(); i++) {
		Coin coin = coinsInUse[i];
		glPushMatrix();
		glTranslatef(coin.positionX, coin.positionY, coin.positionZ);
		glRotatef(coin.rotationZ, 0,0,1);
		glRotatef(coin.rotationY, 0,1,0);
		glColor3f(0.0f, 153 / 255.0, 153.0f/255.0f);
		glScalef(8,8,8);
		glutSolidTetrahedron();
		glPopMatrix();
	}*/

	//draw enemies-----------------------------------------------------
	for(int i=0; i<ennemiesInUse.size(); i++) {
	   	Ennemy ennemy = ennemiesInUse[i];
		glPushMatrix();
		glTranslatef(ennemy.positionX, ennemy.positionY, ennemy.positionZ);
		
		//ennemy.rotationZ += DEG(random()*.1);
		//ennemy.rotationY += DEG(random()*.1);

		glRotatef(ennemy.rotationZ, 0,0,1);
		glRotatef(ennemy.rotationY, 0,1,0);

		//ennemiesInUse[i] = ennemy;

		//glColor3f(160 / 255.0, 0.2f , 0.2f);
		glColor3f(colors.red.r / 255.0, colors.red.g/255.0f, colors.red.b/255.0f);

		//glColor3f(colors.red.r, colors.red.g, colors.red.b);
		//glutSolidSphere(10.0f, 20, 15);
		//glutSolidCube(20.0f);
		glScalef(15, 15, 15);
		glutSolidIcosahedron();
		glPopMatrix();
	}

	//draw target-----------------------------------------------------
	for (int i = 0; i< targetsInUse.size(); i++) {
		Target target = targetsInUse[i];
		glPushMatrix();
		glTranslatef(target.positionX, target.positionY, target.positionZ);

		glColor3f(colors.red.r / 255.0, colors.red.g / 255.0f, colors.red.b / 255.0f);
		glScalef(15, 15, 15);
		glutSolidIcosahedron();
		glPopMatrix();
	}

	//draw Particles-----------------------------------------------------
	newTime = timeGetTime();
	for (int i = 0; i< particlesInUse.size(); i++) {
		
		Particle particle = particlesInUse[i];

		//printf("nt = %d, pt = %d // %d \n", newTime, particle.stime, newTime - particle.stime);

		if ((newTime - particle.stime) > 50) {

			glPushMatrix();
			glTranslatef(particle.positionX, particle.positionY, particle.positionZ);
			glRotatef(particle.rotationZ, 0,0,1);
			glRotatef(particle.rotationX, 1,0,0);
			if (particle.color == 1) glColor3f(colors.red.r / 255.0, colors.red.g / 255.0f, colors.red.b / 255.0f);
			if (particle.color == 2) glColor3f(0.0f, 153 / 255.0, 153.0f / 255.0f);
			glScalef(particle.scale, particle.scale, particle.scale);
			glutSolidTetrahedron();
			glPopMatrix();
		}
	}
	
	//draw white spheres-----------------------------------------------------
	newTime = timeGetTime();
	for (int i = 0; i< whteSpheresInUse.size(); i++) {

		whiteSphere ws = whteSpheresInUse[i];

		//printf("nt = %d, pt = %d // %d \n", newTime, particle.stime, newTime - particle.stime);

		//if ((newTime - ws.stime) > 70) {

			glPushMatrix();
			glTranslatef(ws.positionX, ws.positionY, ws.positionZ);
			//glRotatef(particle.rotationZ, 0, 0, 1);
			//glRotatef(particle.rotationX, 1, 0, 0);
			//if (particle.color == 1) glColor3f(colors.red.r / 255.0, colors.red.g / 255.0f, colors.red.b / 255.0f);
			//if (particle.color == 2) 
			glColor3ub (ws.c.r, ws.c.g, ws.c.b );
			//glScalef(ws.scale, ws.scale, ws.scale);
			glutSolidSphere(ws.scale, 30, 10);

			Vector3 nVec(ws.ep.x - ws.sp.x, ws.ep.y - ws.sp.y, ws.ep.z - ws.sp.z);
			nVec.Mag();

			glBegin(GL_LINES);
				glVertex3f(ws.sp.x, ws.sp.y, ws.sp.y);
				glVertex3f(nVec.x * ws.scale * 0.35, nVec.y * ws.scale * 0.35, nVec.z * ws.scale * 0.35);
			glEnd();

			glPopMatrix();
		//}
	}

	//draw missle----------------------------------------------------------
	for (int i = 0; i < misslesInUse.size(); i++) {
		Missle missle = misslesInUse[i];

		glPushMatrix();
			//glMultMatrixf(missle.m);
			glTranslatef(missle.positionX, missle.positionY, missle.positionZ);
			//glRotatef(-90, 0,1,0);
			glScalef(missle.scale, missle.scale, missle.scale);
				drawMissle();
		glPopMatrix();
	}
	
	//RenderScene();

	// Finish drawing scene
	//glFinish();
	glutSwapBuffers();
}

////////////////////////////////////////////////////////////////////////////////

void Tester::Quit() {
	glFinish();
	glutDestroyWindow(WindowHandle);
	exit(0);

	out.close();//debug 용 출력
}

////////////////////////////////////////////////////////////////////////////////

void Tester::Resize(int x,int y) {
	WinX = x;
	WinY = y;
	//Cam.SetAspect(float(WinX)/float(WinY));
}

////////////////////////////////////////////////////////////////////////////////

void Tester::Keyboard(int key,int x,int y) {

	switch(key) {
		case 0x1b:		// Escape
			Quit();
			break;
		case 'r':
			Reset();
			break;
	}
}

////////////////////////////////////////////////////////////////////////////////

void Tester::MouseButton(int btn,int state,int x,int y) {

	//airplanePos.x = x;
	//airplanePos.y = WinY - y;
	//y = WinY - y;

	//xmov = x - WinX/2;
	//ymov = y - WinY/2;

	//printf("ax = %f,  ay = %f  \n" ,xmov, ymov);

	if(btn==GLUT_LEFT_BUTTON) {
		LeftDown = (state==GLUT_DOWN);
	}
	else if(btn==GLUT_MIDDLE_BUTTON) {
		MiddleDown = (state==GLUT_DOWN);
	}
	else if(btn==GLUT_RIGHT_BUTTON) {
		RightDown = (state == GLUT_UP);
		
		//missile fire---------------------------------------
		if (RightDown){
			Missle missle;

			missle.positionX = airplanePos.a3.x;
			missle.positionY = airplanePos.a3.y;
			missle.positionZ = airplanePos.a3.z;
			missle.velocity = 10.0f; //0.5f;
			missle.scale = 0.4f;

			misslesInUse.push_back(missle);
			
		////launchingMissle();
		}
		//---------------------------------------------------
	}

	//xini = x;
    //yini = y;

	//printf("ax = %f,  ay = %f  \n" ,xini, yini);
}

////////////////////////////////////////////////////////////////////////////////

void Tester::MouseMotion(int nx,int ny) 
{
	float tx = -1.0f + (float(nx) / float(WinX))*2.0f;
	float ty =  1.0f - (float(ny) / float(WinY))*2.0f;

	//printf("mpx = %f,  mpy = %f  \n" ,tx, ty);

	mousePos.x = tx;
	mousePos.y = ty;
	

	xmov /= WinX;
	ymov = (WinY - ny)/WinY;

	xini = nx;
	yini = ny;
	
	//printf("mpx = %d,  mpy = %d  \n" ,mousePos.x, mousePos.y);
	
	// Move camera
	// NOTE: this should really be part of Camera::Update()
	float rate=1.0f;
	int dx = nx - MouseX;
	int dy = -(ny - MouseY);

	MouseX = nx;
	MouseY = ny;

	//printf("%f,  %f  \n" ,mousePos.x, mousePos.y);
	
	if(LeftDown) {
		//const float rate=1.0f;
		Cam.SetAzimuth(Cam.GetAzimuth()+dx*rate);
		Cam.SetIncline(Cam.GetIncline()-dy*rate);

		//printf("Az = %f, In = %f  \n", Cam.GetAzimuth() + dx*rate, Cam.GetIncline() - dy*rate);
	}
	if(RightDown) {
		rate=0.01f;
		Cam.SetDistance(Cam.GetDistance()*(1.0f-dx*rate));
	}
}

////////////////////////////////////////////////////////////////////////////////
