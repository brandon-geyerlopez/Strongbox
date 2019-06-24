//
//  OTPToken+Generation.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPToken+Generation.h"
#import "OTPToken+Persistence.h"
#import <CommonCrypto/CommonHMAC.h>


static NSUInteger kPinModTable[] = {
    0,
    10,
    100,
    1000,
    10000,
    100000,
    1000000,
    10000000,
    100000000,
};


@implementation OTPToken (Generation)

+ (NSSet *)keyPathsForValuesAffectingPassword
{
    return [NSSet setWithArray:@[@"secret",
                                 @"algorithm",
                                 @"digits",
                                 @"counter"]];
}

- (NSString *)password
{
    if (self.type == OTPTokenTypeTimer) {
        uint64_t newCounter = (uint64_t)([NSDate date].timeIntervalSince1970 / self.period);
        if (self.counter != newCounter) {
            self.counter = newCounter;
        }
    }

    return [self generatePasswordForCounter:self.counter];
}

- (void)updatePassword
{
    if (self.type == OTPTokenTypeCounter) {
        self.counter++;
        if (self.isInKeychain)
            [self saveToKeychain];
    } else if (self.type == OTPTokenTypeTimer) {
        self.counter = (uint64_t)([NSDate date].timeIntervalSince1970 / self.period);
    }
}


#pragma mark - Generator

CCHmacAlgorithm hashAlgorithmForAlgorithm(OTPAlgorithm algorithm)
{
    switch (algorithm) {
        case OTPAlgorithmSHA1:
            return kCCHmacAlgSHA1;
        case OTPAlgorithmSHA256:
            return kCCHmacAlgSHA256;
        case OTPAlgorithmSHA512:
            return kCCHmacAlgSHA512;
        case OTPAlgorithmSteam:
            return kCCHmacAlgSHA1;
    }
    return kCCHmacAlgSHA1;
}

NSUInteger digestLengthForAlgorithm(CCHmacAlgorithm algorithm)
{
    switch (algorithm) {
        case kCCHmacAlgSHA1:
            return CC_SHA1_DIGEST_LENGTH;
        case kCCHmacAlgSHA256:
            return CC_SHA256_DIGEST_LENGTH;
        case kCCHmacAlgSHA512:
            return CC_SHA512_DIGEST_LENGTH;
    }
    return 0;
}

- (NSString *)generatePasswordForCounter:(uint64_t)counter {
    counter = NSSwapHostLongLongToBig(counter);
    
    if(self.algorithm == OTPAlgorithmSteam) {
        return [self generateSteamTotp:counter];
    }
    else {
        return [self generateRFC6238Totp:counter];
    }
}

- (NSString*)generateSteamTotp:(uint64_t)counter {
//    NSLog(@"Generating Steam Totp");
    
    NSUInteger length = digestLengthForAlgorithm(kCCHmacAlgSHA1);
    NSMutableData *hash = [NSMutableData dataWithLength:length];
    CCHmac(kCCHmacAlgSHA1, self.secret.bytes, self.secret.length, &counter, sizeof(counter), hash.mutableBytes);
    uint8_t *hmac = hash.mutableBytes;

    int offset = (hmac[hash.length - 1] & 0xf);
    
    //NSLog(@"offset = %d, length = %lu", offset, (unsigned long)length);
    
    uint32_t a = ((hmac[offset] & 0x7f) << 24);
    uint32_t b = ((hmac[offset + 1] & 0xff) << 16);
    uint32_t c = ((hmac[offset + 2] & 0xff) << 8);
    uint32_t d = (hmac[offset + 3] & 0xff);
    
    int binary = a | b | c | d;
    
    NSArray<NSString*>* alphabet = @[@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"B",@"C",@"D",@"F",@"G",
                                     @"H",@"J",@"K",@"M",@"N",@"P",@"Q",@"R",@"T",@"V",@"W",@"X",@"Y"];

    uint32_t dp = pow(alphabet.count, self.digits);
    uint64_t pw = binary % dp;
    
    NSMutableArray<NSString*>* resArray = [@[@"2",@"2",@"2",@"2",@"2"] mutableCopy];

    int i=0;
    while(pw > 0 && i < 5) {
        resArray[i++] = alphabet[pw % alphabet.count];
        pw /= alphabet.count;
    }
    
    return [resArray componentsJoinedByString:@""];
}

- (NSString*)generateRFC6238Totp:(uint64_t)counter {
//    NSLog(@"Generating RFC6238 Totp");
    
    // Generate an HMAC value from the key and counter
    CCHmacAlgorithm algorithm = hashAlgorithmForAlgorithm(self.algorithm);
    NSMutableData *hash = [NSMutableData dataWithLength:digestLengthForAlgorithm(algorithm)];
    CCHmac(algorithm, self.secret.bytes, self.secret.length, &counter, sizeof(counter), hash.mutableBytes);

    // Use the last 4 bits of the hash as an offset (0 <= offset <= 15)
    const char *ptr = hash.bytes;
    unsigned char offset = ptr[hash.length-1] & 0x0f;

    // Take 4 bytes from the hash, starting at the given offset
    const void *truncatedHashPtr = &ptr[offset];
    unsigned int truncatedHash = *(unsigned int *)truncatedHashPtr;

    // Ensure the four bytes taken from the hash match the current endian format
    truncatedHash = NSSwapBigIntToHost(truncatedHash);
    // Discard the most significant bit
    truncatedHash &= 0x7fffffff;

    unsigned long pinValue = truncatedHash % kPinModTable[self.digits];

    return [NSString stringWithFormat:@"%0*ld", (int)self.digits, pinValue];
}

@end
