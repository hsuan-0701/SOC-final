import random
import struct

#################################################################################################################
#                                               Rounding                                                        #
#################################################################################################################
def round_to_nearest_even_with_sticky(m, lsb_position=52): # LSB is at bit[52]
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

def normalize(m, e ):
    while m >= (1 << (53)):
        m >>= 1
        e += 1
    while m and m < (1 << (52)):
        if e== 0 or e < 0 :
            return m ,e
        else:
            m <<= 1
            e -= 1
    return m, e

#########################################################################################################
#                               Generate pattern and  write into .txt                                   #
#########################################################################################################

pattern_num = 50000

with open("frac_i.dat", "w") as frac_i, open("exp_i.dat", "w") as exp_i, open("golden_frac.dat", "w") as fg,open("golden_exp.dat", "w") as eg , open("inf_case.dat" , "w") as inf_i:
            
    for i in range(pattern_num):
        frac_in = random.randint(0, 81129638414606681695789005144063)  # 106-bit frac
        exp_in  = random.randint(-1023, 3071)  # 13-bit exp
        inf_in  = random.randint(0,1)        # infinite case

        zero_case = 0
        #####################################
        #   check whether frac is all zero  #
        #####################################
        if(frac_in ==0):
            zero_case = 1
        
        ###############################################################################
        #   Check whether frac[105] is one  & modify the position and exponent value  #
        ###############################################################################
        if(frac_in >= (1<<105)): 
            frac_in = frac_in - (1<<105)
            exp_in = exp_in + 1
        if(exp_in < 0):
            zero_case = 1

        frac_rounded = round_to_nearest_even_with_sticky(frac_in)
        # after first time rounding , the floating point locate between bit[52:51]
    
        frac_norm , exp_norm = normalize(frac_rounded , exp_in)
        # denormal (inifinte num 、 zero number)

        #############################################################
        #      If final result of exp > 2047 resturn inf number     #
        #############################################################
        if exp_norm == 2047 or exp_norm > 2047 : 
            frac_norm = 1<<52
            exp_norm  = 2047
        #############################################################
        #      If final result of exp < 0 , resturn zero  number    #
        #############################################################
        if frac_norm == 0 or exp_norm <0  :  
            frac_norm = 0
            exp_norm = 0
        ##############################################################################
        #      If input has infinte num  and other is not zero ,return infinite num  #
        ##############################################################################
        if inf_in == 1 and zero_case == 0 :
            frac_norm = 1 <<52
            exp_norm  = 2047
        ##########################################################
        #        Check hidden bit is zero or one                 #
        ##########################################################
        if exp_norm == 0 :
            frac_norm = frac_norm
        else : 
            frac_norm = frac_norm - (1<<52)
        print(zero_case)

        frac_i.write(f"{frac_in}\n")
        exp_i.write(f"{exp_in}\n")
        inf_i.write(f"{inf_in}\n")
        fg.write(f"{frac_norm}\n")
        eg.write(f"{exp_norm}\n")
print(f"{pattern_num} of pattern generated !")
