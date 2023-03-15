//This is our CUDA thread
//d_a is the word list array
//maxidx is the maximum index in the array (if there are more threads than words)
#include <stdint.h>

#define N_PERFECT_MATCH 11
#define N_NICE_MATCH 4
#define N_GOLD_MD5 7
#define N_MD5_OF_DIGITS 32
#define N_MD5_OF_LETTERS 23
#define N_PI_MD5 9
#define N_E_MD5 9

struct md5_digest_t{
    uint8_t data[16];
};

__device__ bool is_perfect_match(char *hash) {
    for (int i = 1; i < 32; ++i) {
        if (hash[i] != hash[0]) {
            return false;
        }
    }
    return true;
}

__device__ bool is_nice_match(char *hash) {
    for (int i = 1; i < N_NICE_MATCH; ++i) {
        if (hash[i] != hash[0]) {
            return false;
        }
    }
    return true;
}

__device__ bool is_gold_md5(char *text, char *hash) {
    for (int i = 0; i < N_GOLD_MD5; ++i) {
        if (text[i] != hash[i]) {
            return false;
        }
    }
    return true;
}

__device__ bool is_pi_md5(char *hash) {
    char pi_str[35];
    for (int i = 0; i < N_PI_MD5; ++i) {
        if (hash[i] != pi_str[i + 2]) {
            return false;
        }
    }
    return true;
}

__device__ bool is_e_md5(char *hash) {
    char e_str[35];
    for (int i = 0; i < N_E_MD5; ++i) {
        if (hash[i] != e_str[i + 2]) {
            return false;
        }
    }
    return true;
}

__device__ size_t check_nice_match(md5_digest_t digest) {
    uint8_t first = digest.data[0];
    if (first >> 4 != first & 0xF) {
        return 0;
    }

    uint8_t expected = first & 0xF;
    for (int i = 1; i < 16; i++) {
        uint8_t byte = digest.data[i];
        if (byte >> 4 != expected) {
            return 2 * i;
        }
        if (byte & 0xF != expected) {
            return 2 * i + 1;
        }
    }

    return 32;
}

__device__ void IncrementBruteGPU(unsigned char* ourBrute, uint charSetLen, uint bruteLength, uint incrementBy)
{
	int i = 0;
	while(incrementBy > 0 && i < bruteLength)
	{
		int add = incrementBy + ourBrute[i];
		ourBrute[i] = add % charSetLen;
		incrementBy = add / charSetLen;
		i++;
	}
}

__device__ void u32_to_4_u8s(uint c1, uint c2, uint c3, uint c4, uint8_t* buffer) {
        buffer[0] = (char)c1 >> 24;
        buffer[1] = (char)c1 >> 16 & 0xFF;
        buffer[2] = (char)c1 >> 8 & 0xFF;
        buffer[3] = (char)c1 & 0xFF;
        buffer[4] = (char)c2 >> 24;
        buffer[5] = (char)c2 >> 16 & 0xFF;
        buffer[6] = (char)c2 >> 8 & 0xFF;
        buffer[7] = (char)c2 & 0xFF;
        buffer[8] = (char)c3 >> 24;
        buffer[9] = (char)c3 >> 16 & 0xFF;
        buffer[10] = (char)c3 >> 8 & 0xFF;
        buffer[11] = (char)c3 & 0xFF;
        buffer[12] = (char)c4 >> 24;
        buffer[13] = (char)c4 >> 16 & 0xFF;
        buffer[14] = (char)c4 >> 8 & 0xFF;
        buffer[15] = (char)c4 & 0xFF;
}

__global__ void crack(uint numThreads, uint charSetLen, uint bruteLength)
{
	//compute our index number
    	uint idx = (blockIdx.x*blockDim.x + threadIdx.x);
	int totalLen = 0;
	int bruteStart = 0;

	unsigned char word[MAX_TOTAL];
	unsigned char ourBrute[MAX_BRUTE_LENGTH];
	int i = 0;

	for(i = 0; i < MAX_BRUTE_LENGTH; i++)
	{
		ourBrute[i] = cudaBrute[i];
	}
	
	IncrementBruteGPU(ourBrute, charSetLen, bruteLength, idx);
	int timer = 0;
	for(timer = 0; timer < MD5_PER_KERNEL; timer++)
	{	
		//Now, substitute the values into the string
		for(i = 0; i < bruteLength; i++)
		{
			word[i+bruteStart] = cudaCharSet[ourBrute[i]];
		}

		uint c1 = 0, c2 = 0, c3 = 0, c4 = 0;
        uint8_t buffer = 0;
		//get the md5 hash of the word
		md5_vfy(word,totalLen, &c1, &c2, &c3, &c4);
        
        //convert md5 thingies into other thingies for easier comparison
        u32_to_4_u8s( c1, c2, c3, c4, &buffer);
        
        struct md5_digest_t digest = {buffer};
        //check nice
        if(check_nice_match(digest) >= N_NICE_MATCH){
            int j;
            for(j=0; j < 32; j++){
                correctPass[j] = j;
            }
            correctPass[totalLen] = 0;
        }
		IncrementBruteGPU(ourBrute, charSetLen, bruteLength, numThreads);
	}
}