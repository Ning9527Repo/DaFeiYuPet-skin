#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetBalance.h"
#import "../Sources/MowangDaFeiYuPetBalance.h"
static int failures;
static void check(BOOL ok) { if(!ok) failures++; }
int main(void) {
    @autoreleasepool {
        check([mowang_dafeiyupet_balanceText(@{@"code":@YES,@"data":@{@"object":@"token_usage",@"user_quota":@{@"total_available":@123}}},YES,@"智纽") containsString:@"123"]);
        check([mowang_dafeiyupet_balanceText(@{@"code":@YES,@"data":@{@"object":@"token_usage",@"total_available":@999}},YES,@"智纽") length]==0);
        check([mowang_dafeiyupet_balanceText(@{@"mode":@"normal",@"balance":@12.5,@"currency":@"USD"},NO,@"晚晚舟") containsString:@"12.5"]);
        check([mowang_dafeiyupet_balanceText(@{@"mode":@"normal",@"remaining":@12.5},NO,@"晚晚舟") length]==0);
        check([mowang_dafeiyupet_balanceText(@{@"mode":@"quota_limited",@"quota":@{@"remaining":@88}},NO,@"晚晚舟") containsString:@"Key 剩余配额"]);
        check([mowang_dafeiyupet_balanceText(@{@"code":@NO},YES,@"智纽") length]==0);
    }
    return failures;
}
