#include <ap_int.h>

#define TAP1    38
#define TAP2    57

// implements G(x) = 1 + x^39 + x^58
void scrambler64(
    ap_uint<1> mode_in,   // mode_in == 0 => scrambler
                          // mode_in == 1 => descrambler
    ap_uint<64> data_in,
    ap_uint<64>& data_out
){
    #pragma HLS INTERFACE ap_ctrl_none port=return
    #pragma HLS INTERFACE ap_none port=data_in
    #pragma HLS INTERFACE ap_none port=data_out

    static ap_uint<64> state_reg = "0xaaaaaaaaaaaaaaaa";
    ap_uint<1> tap1_xor_tap2;
    ap_uint<1> result;

    // the theory here is that hls unrolls it in a way
    // that makes sense because I can't think of any
    for(int i = 0; i < 64; i++){
        #pragma HLS unroll
        tap1_xor_tap2 = state_reg[TAP1] ^ state_reg[TAP2];  // x^39 + x^58
        result = tap1_xor_tap2 ^ data_in[i];                // 1 + x^39 + x^58
        data_out[i] = result;
        for(int j = TAP2; j > 0 ; j--){ // shift
            #pragma HLS unroll
            state_reg[j] = state_reg[j-1];
        }
        state_reg[0] = mode_in ? data_in[i] : result;
    }
}
