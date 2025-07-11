import random
import struct

#################################################################################################################
#                                               Rounding                                                        #
#################################################################################################################
def round_to_nearest_even_with_sticky(m, lsb_position): # LSB is at bit[52]
    # In hardware we have 106 bit input with floating point between bit[104:103] 
    guard     = (m >> (lsb_position-1)) & 1
    round_bit = (m >> (lsb_position-2)) & 1

    sticky_mask = (1 << (lsb_position - 2)) - 1
    sticky = (m & sticky_mask) != 0
    lsb = (m >> (lsb_position)) & 1
    # print("stick :",sticky)
    if guard and (round_bit or sticky or lsb):
        m += (1 << (lsb_position))  # 往 lsb 進位
    return m >> (lsb_position)  # 去除 GRS bits

def normalize_rounder(m, e , position_move ):
    while m >= (1 << (53 + position_move)):
        m >>= 1
        e += 1
    while m and (m < (1 << (52 + position_move))):
        m <<= 1
        e -= 1
    return m, e

def overflow_detect(m, e , position_move):
    m_funct = m
    e_funct = e
    lsb_posit = position_move
    if (m_funct >= (1<< (53 + position_move))):
        e_funct += 1
        lsb_posit += 1  
    return m_funct, e_funct , lsb_posit
#########################################################################################################
#                               Generate pattern and  write into .txt                                   #
#########################################################################################################

pattern_num = 50000

with open("frac_i.dat", "w") as frac_i, open("exp_i.dat", "w") as exp_i, open("golden_frac.dat", "w") as fg,open("golden_exp.dat", "w") as eg , open("inf_case.dat" , "w") as inf_i:
            
    for i in range(pattern_num):
        frac_in = random.randint(0, ((1<<106)-1))  # 106-bit frac
        exp_in  = random.randint(-1023, 2046)  # 13-bit exp
        inf_in  = random.randint(0,1)        # infinite case

        frac_i.write(f"{frac_in}\n")
        exp_i.write(f"{exp_in}\n")
        inf_i.write(f"{inf_in}\n")
        zero_case = 0
        if frac_in == 0 :
            zero_case = 1
        ###############################################################################
        #   Check whether frac[105] is one  & modify the position and exponent value  #
        ###############################################################################
        result_m, result_e , lsb_posi = overflow_detect(frac_in , exp_in , position_move=52)
        frac_rounded = round_to_nearest_even_with_sticky(result_m , lsb_position = lsb_posi)
        # after first time rounding , the floating point locate between bit[52:51]
        if (frac_rounded != 0) :
            frac_norm , exp_norm = normalize_rounder(frac_rounded , result_e , position_move = 0)
        else :
            frac_norm = 0
            exp_norm = -5000
        # denormal (inifinte num 、 zero number)
        exp_less = 0
        if exp_norm <= 0 :
            exp_less = 0 - exp_norm
            exp_norm = 0
            frac_norm >>= (exp_less + 1)    
 
        #############################################################
        #      If final result of exp > 2047 resturn inf number     #
        #############################################################
        if exp_norm == 2047 or exp_norm > 2047 : 
            frac_norm = 0
            exp_norm  = 2047
 
        ##############################################################################
        #      If input has infinte num  and other is not zero ,return infinite num  #
        ##############################################################################
        if inf_in == 1  and zero_case == 0:
            frac_norm = 0
            exp_norm  = 2047
        ##########################################################
        #                       hidden bit                       #
        ##########################################################
        frac_norm = frac_norm & ((1<<52)-1)


        
        fg.write(f"{frac_norm}\n")
        eg.write(f"{exp_norm}\n")
print(f"{pattern_num} of fmul_rounder pattern generated !")