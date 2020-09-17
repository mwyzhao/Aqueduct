#include <ap_int.h>

void block_sync(
    ap_uint<2> sync_header_in,
    ap_uint<1> test_sh_in,
    ap_uint<1> & block_lock_out,
    ap_uint<1> & slip_out
) {
    #pragma HLS INTERFACE ap_ctrl_none port=return
    #pragma HLS INTERFACE ap_none port=sync_header_in
    #pragma HLS INTERFACE ap_none port=test_sh_in
    #pragma HLS INTERFACE ap_none port=block_lock_out
    #pragma HLS INTERFACE ap_none port=slip_out

    #define LOCK_INIT 0
    #define RESET_CNT 1
    #define TEST_SH   2
    #define TEST_WAIT 3

    static ap_uint<2> state = LOCK_INIT;
    static ap_uint<1> block_lock_reg;
    static ap_uint<1> slip_reg;
    static ap_uint<7> sh_cnt;
    static ap_uint<5> sh_invalid_cnt;
    ap_uint<1> sh_valid;

    sh_valid = sync_header_in[1] ^ sync_header_in[0];

    switch(state){
        case LOCK_INIT: {
            block_lock_reg = 0;
            state = RESET_CNT;
            break;
        }
        case RESET_CNT: {
            sh_cnt = 0;
            sh_invalid_cnt = 0;
            slip_reg = 0;
            state = test_sh_in ? TEST_SH : RESET_CNT;
            break;
        }
        case TEST_SH: {
            sh_cnt += 1;
            sh_invalid_cnt = sh_valid ? sh_invalid_cnt : ap_uint<5>(sh_invalid_cnt + 1);
            if(sh_valid){
                if(sh_cnt[6]){ // sh_cnt == 64
                    block_lock_reg = (sh_invalid_cnt == 0);
                    state = RESET_CNT;
                }
                else{
                    state = test_sh_in ? TEST_SH : TEST_WAIT;
                }
            }
            else{
                if(sh_invalid_cnt[4] || !block_lock_reg){ // sh_invalid_cnt == 16
                    block_lock_reg = 0;
                    slip_reg = 1;
                    state = RESET_CNT;
                }
                else{
                    state = sh_cnt[6] ? RESET_CNT : TEST_SH;
                }
            }
            break;
        }
        case TEST_WAIT: {
            state = test_sh_in ? TEST_SH : TEST_WAIT;
            break;
        }
    }

    block_lock_out = block_lock_reg;
    slip_out = slip_reg;

}
