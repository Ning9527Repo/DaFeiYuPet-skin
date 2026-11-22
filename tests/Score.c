#include "../Sources/MowangDaFeiYuPetScore.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    assert(mowang_dafeiyupet_clickScore(400,462)==4);
    assert(mowang_dafeiyupet_clickScore(800,231)==16);
    assert(mowang_dafeiyupet_clickScore(400,180)==10);
    assert(mowang_dafeiyupet_clickScore(1,10000)==1);
    assert(mowang_dafeiyupet_clickScore(0,180)==0);
    assert(mowang_dafeiyupet_clickScore(400,0)==0);
    assert(mowang_dafeiyupet_clickScore(NAN,180)==0);
    assert(mowang_dafeiyupet_clickScore(INFINITY,180)==0);
    assert(mowang_dafeiyupet_clickScore(400,NAN)==0);
    assert(mowang_dafeiyupet_flyingScore(0,800,0,180)==0);
    assert(mowang_dafeiyupet_flyingScore(1,399.99,0,180)==0);
    assert(mowang_dafeiyupet_flyingScore(1,240,320,462)==4);
    assert(mowang_dafeiyupet_flyingScore(1,-240,-320,462)==4);
    assert(mowang_dafeiyupet_flyingScore(1,INFINITY,0,180)==0);
    assert(mowang_dafeiyupet_clickScore(1e300,1e-300)==1000000);
    puts("Score: threshold, vector speed, size scaling and invalid inputs passed");
    return 0;
}
