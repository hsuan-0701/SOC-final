import struct
import random
#####################################################################
#                          Transform                                #
#####################################################################
def float_to_bits(f):
    bits = struct.unpack(">Q", struct.pack(">d", f))[0]
    return f'{bits:064b}'  

def bits_to_float(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]

def extract_components(bits):
    sign_funct = (bits >> 63) & 1
    exponent_funct = (bits >> 52) & 0x7FF
    mantissa_funct = bits & ((1 << 52) - 1)
    if exponent_funct != 0:
        mantissa_funct |= (1 << 52)  # hidden bit
    return sign_funct, exponent_funct, mantissa_funct

def assemble_float(sign, exponent, mantissa):
    s_funct = sign
    e_funct = exponent
    m_funct = mantissa
    
    if e_funct >= 2047:
        e_funct = 2047
        m_funct = 0
    elif e_funct < 0:
        e_funct = 0
        m_funct = 0
    else:
        m_funct &= ~(1 << 52)
    bits = (s_funct << 63) | (e_funct << 52) | m_funct
    return bits_to_float(bits)

#####################################################################
#                           DATA GENERATE                           #
#####################################################################

def generate_random_sign():
    return random.randint(0, 1)

def generate_random_exp():
    return random.randint(0, 2046)  # avoid Inf/NaN

def generate_random_mantissa():
    return random.randint(0, (1 << 52) - 1)

def ieee754_double_to_hex(sign, exponent, mantissa):
    bits = (sign << 63) | (exponent << 52) | mantissa
    return f"{bits:016X}"

####################################################################
#                           fp_add                                 #
####################################################################
def align_exponents(m1, e1, m2, e2,position_move):
    m1_funct = m1
    m2_funct = m2
    e1_funct = e1
    e2_funct = e2
    # we shift left 52bit before op in hardware
    if e1_funct > e2_funct:
        shift = e1_funct - e2_funct
        m2_funct = 0 if shift >= (53+position_move) else m2_funct >> shift
        return m1_funct, m2_funct, e1_funct
    else:
        shift = e2_funct - e1_funct
        m1_funct = 0 if shift >= (53+position_move) else m1_funct >> shift
        return m1_funct, m2_funct, e2_funct

def fp64_add(ma, mb, ea, eb, sa, sb):
    ma_funct = ma
    mb_funct = mb
    
    ea_funct = ea
    eb_funct = eb
    
    sa_funct = sa
    sb_funct = sb
    ###########################################
    #               Denormal                  #
    ###########################################
    if ea_funct == 2047 :
        return assemble_float( sa_funct , 2047 , 0 )
    if eb_funct == 2047 :
        return assemble_float( sb_funct , 2047 , 0 )
    if ea_funct == 0 and ma_funct == 0:
        return assemble_float(sb_funct, eb_funct, mb_funct)
    if eb_funct == 0 and mb_funct == 0:
        return assemble_float(sa_funct, ea_funct, ma_funct)
    ##########################################
    #               Normal                   #
    ##########################################
    ma_funct <<= 52
    mb_funct <<= 52
    ma_funct, mb_funct, e_funct = align_exponents(ma_funct, ea_funct, mb_funct, eb_funct , position_move=52)
    if sa_funct == sb_funct:
        result_m = ma_funct + mb_funct
        result_s = sa_funct
    else:
        if ma_funct >= mb_funct:
            result_m = ma_funct - mb_funct
            result_s = sa_funct
        else:
            result_m = mb_funct - ma_funct
            result_s = sb_funct
    result_m, result_e = normalize(result_m, e_funct , position_move=52)
    result_m = round_to_nearest_even_with_sticky(result_m)
    result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
    # if result_m_final & (1<<52):
    #     result_m_final = result_m_final & ((1<<52)-1)
    #     result_e_final = result_e_final+1
    # else:
    #     result_m_final = result_m_final & ((1<<52)-1)
    return assemble_float(result_s, result_e_final, result_m_final)

####################################################################
#                           fp  mul                                #
####################################################################

def fp64_mul(ma, mb, ea, eb, sa, sb):
    ###########################################
    #               Denormal                  #
    ###########################################    
    if ma == 0 and ea == 0 :
        return assemble_float(0, 0, 0)
    if mb == 0 and eb == 0 :
        return assemble_float(0, 0, 0)
    if ea == 2047 :
        return assemble_float(sa^sb , 2047 ,0)
    if eb == 2047 :
        return assemble_float(sa^sb , 2047 ,0)
    ##########################################
    #               Normal                   #
    ##########################################
    result_m = ma * mb
    if sa == sb :
        result_s = 0
    else :
        result_s = 1
    e = ea + eb - 1023

    result_m, result_e = normalize(result_m, e , position_move=52)

    result_m = round_to_nearest_even_with_sticky(result_m)
    result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
    # if result_m_final & (1<<52):
    #     result_m_final = result_m_final & ((1<<52)-1)
    #     result_e_final = result_e_final+1
    # else:
    #     result_m_final = result_m_final & ((1<<52)-1)
    return assemble_float(result_s, result_e_final, result_m_final)

##########################################################################
#                    Rounding and normalization                          #
##########################################################################

def round_to_nearest_even_with_sticky(m, lsb_position=52): #in hardware LSB is at [52]
    m_funct   = m
    guard     = (m_funct >> (lsb_position-1)) & 1
    round_bit = (m_funct >> (lsb_position-2)) & 1

    sticky_mask = (1 << (lsb_position - 2)) - 1
    sticky = (m_funct & sticky_mask) != 0
    lsb = (m_funct >> (lsb_position)) & 1
    # print("stick :",sticky)
    if guard and (round_bit or sticky or lsb):
        m_funct += (1 << (lsb_position))  # 往 lsb 進位
    return m_funct >> (lsb_position)  # 去除 GRS bits

def normalize(m, e , position_move):
    m_funct = m
    e_funct = e
    while m_funct >= (1 << (53 + position_move)):
        m_funct >>= 1
        e_funct += 1
    while m_funct and m_funct < (1 << (52 + position_move)):
        if e_funct == 0:
            return m_funct ,e_funct
        else :
            m_funct <<= 1
            e_funct -= 1 
    return m_funct, e_funct
##########################################################################
#                           Complex mul                                  #                             
##########################################################################

def cmul(a0_bits , b0_bits , a1_bits , b1_bits ):
    #####################################################################
    #  a0_bits = float_to_bits(a0_val) => bit form of real part com_A   #
    #  b0_bits = float_to_bits(b0_val) => bit form of img  part com_A   #
    #  a1_bits = float_to_bits(a1_val) => bit form of real part com_B   #
    #  b1_bits = float_to_bits(b1_val) => bit form of img  part com_B   #
    #                                                                   #
    #  TO DO com_A * com_B  as following :                              #
    #                                                                   #      
    #       y_re = a_re * (b_re - b_im) + b_im * (a_re - a_im)          #
    #       y_im = a_im * (b_re + b_im) + b_im * (a_re - a_im)          #
    #                                                                   #
    #####################################################################       
    # extract imformation to do fP_add fucntion
    sA_re, eA_re, mA_re = extract_components(int(a0_bits, 2)) #real part of com_A
    sA_im, eA_im, mA_im = extract_components(int(b0_bits, 2)) #img  part of com_A
    
    sB_re, eB_re, mB_re = extract_components(int(a1_bits, 2)) #real part of com_B
    sB_im, eB_im, mB_im = extract_components(int(b1_bits, 2)) #img  part of com_B
    ####################################  fp_add stage ####################################################
    Bre_sub_Bim_val = fp64_add(mB_im , mB_re, eB_im , eB_re, (1-sB_im) , sB_re)  # B_re - B_im
    Bre_add_Bim_val = fp64_add(mB_im , mB_re, eB_im , eB_re, sB_im     , sB_re)  # B_re + B_im
    Are_sub_Aim_val = fp64_add(mA_im , mA_re, eA_im , eA_re, (1-sA_im) , sA_re ) # A_re - A_im
    # Transform to bit format
    Bre_sub_Bim_bits  = float_to_bits( Bre_sub_Bim_val )
    Bre_add_Bim_bits  = float_to_bits( Bre_add_Bim_val )
    Are_sub_Aim_bits  = float_to_bits( Are_sub_Aim_val )
    # extrac_component
    s_Bre_sub_Bim, e_Bre_sub_Bim, m_Bre_sub_Bim = extract_components(int(Bre_sub_Bim_bits, 2))
    s_Bre_add_Bim, e_Bre_add_Bim, m_Bre_add_Bim = extract_components(int(Bre_add_Bim_bits, 2))
    s_Are_sub_Aim, e_Are_sub_Aim, m_Are_sub_Aim = extract_components(int(Are_sub_Aim_bits, 2))
    ####################################  mul stage  #######################################################
    y_re_0_val  = fp64_mul(mA_re, m_Bre_sub_Bim , eA_re, e_Bre_sub_Bim, sA_re,  s_Bre_sub_Bim) # y_re_0 = a_re * (b_re - b_im)
    y_re_1_val  = fp64_mul(m_Are_sub_Aim , mB_im, e_Are_sub_Aim, eB_im, s_Are_sub_Aim, sB_im)  # y_re_1 = b_im * (a_re - a_im)
        
    y_im_0_val  = fp64_mul(mA_im , m_Bre_add_Bim, eA_im, e_Bre_add_Bim, sA_im, s_Bre_add_Bim)  # y_im_0 = a_im * (b_re + b_im)
    y_im_1_val  = fp64_mul(m_Are_sub_Aim, mB_im, e_Are_sub_Aim, eB_im, s_Are_sub_Aim, sB_im)   # y_im_1 = b_im * (a_re - a_im)
    # Transform to bit format
    y_re_0_bits = float_to_bits( y_re_0_val )
    y_re_1_bits = float_to_bits( y_re_1_val )
    y_im_0_bits = float_to_bits( y_im_0_val )
    y_im_1_bits = float_to_bits( y_im_1_val )
    # extrac_component
    s_y_re_0 , e_y_re_0 , m_y_re_0 = extract_components(int(y_re_0_bits, 2))
    s_y_re_1 , e_y_re_1 , m_y_re_1 = extract_components(int(y_re_1_bits, 2))
        
    s_y_im_0 , e_y_im_0 , m_y_im_0 = extract_components(int(y_im_0_bits, 2))
    s_y_im_1 , e_y_im_1 , m_y_im_1 = extract_components(int(y_im_1_bits, 2))
    ##################################### fadd stage #####################################################
    y_re_val = fp64_add(m_y_re_1 , m_y_re_0, e_y_re_1 , e_y_re_0, s_y_re_1 ,  s_y_re_0)
    y_im_val = fp64_add(m_y_im_1 , m_y_im_0, e_y_im_1 , e_y_im_0, s_y_im_1 ,  s_y_im_0)
    return y_re_val , y_im_val

##########################################################################
#                       16 bit Integer mul pattern                       #
##########################################################################
int_pattern_num = 80000
with  open("int_A.dat", "w") as int_A, open("int_B.dat", "w") as int_B ,open("golden_int.dat", "w") as int_g ,open("int_A_check.dat", "w") as int_A_check, open("int_B_check.dat", "w") as int_B_check ,open("golden_int_check.dat", "w") as int_g_check :
    chunk_A = chunk_B = chunk_G = 0   # 暫存 128-bit
    idx_in_chunk = 0                  # 0‥7
    line_cnt = 0
    for i in range(int_pattern_num):
        A = random.randint(0, 65535)  # 16-bit A
        B = random.randint(0, 65535)  # 16-bit B
        result = A*B
        int_A_check.write(f"{A}\n")
        int_B_check.write(f"{B}\n")
        int_g_check.write(f"{result}\n")

        shift = idx_in_chunk * 16
        chunk_A |= A << shift
        chunk_B |= B << shift
        chunk_G |= result << (shift*2)
        idx_in_chunk += 1
   
        if idx_in_chunk == 8:         # 滿 8 筆 → 輸出一行
            int_A.write(f"{chunk_A:032X}\n")
            int_B.write(f"{chunk_B:032X}\n")
            int_g.write(f"{chunk_G:064X}\n")
            chunk_A = chunk_B = chunk_G = 0
            idx_in_chunk = 0
            line_cnt += 1
    

    int_pattern_num = int_pattern_num / 8
    print(f"{int_pattern_num} of int mul pattern generated !")
    
##########################################################################
#               double precision complex mul pattern                     #
##########################################################################
with open("complex_A.dat", "w") as ca_in, open("complex_B.dat", "w") as cb_in , open("golden_complex.dat", "w") as cg_in , open("com_A_float.dat", "w") as fa_in, open("com_B_float.dat", "w") as fb_in , open("golden_com_float.dat", "w") as fg_in :
    for i in range(10000):
        ###############################
        #   Generate complex num A    #
        ###############################
        a0_sign = generate_random_sign()
        b0_sign = generate_random_sign()

        a0_exp =  generate_random_exp()
        b0_exp = generate_random_exp()
        
        a0_frac = generate_random_mantissa()
        b0_frac = generate_random_mantissa()

        a0_val = assemble_float(a0_sign, a0_exp, a0_frac) # a0 = real part of com_A 
        b0_val = assemble_float(b0_sign, b0_exp, b0_frac) # b0 = img  part of com_A

        a0_bits = float_to_bits(a0_val)  # bit form of real part com_A
        b0_bits = float_to_bits(b0_val)  # bit form of img  part com_A  
        
        A_re   = int(a0_bits, 2) << 64  
        A_im   = int(b0_bits, 2)
        
        COM_A_bits  = A_re | A_im         
        ###############################
        #   Generate complex num B    #
        ###############################
        a1_sign = generate_random_sign()
        b1_sign = generate_random_sign()

        a1_exp =  generate_random_exp()
        b1_exp = generate_random_exp()
        
        a1_frac = generate_random_mantissa()
        b1_frac = generate_random_mantissa()

        a1_val = assemble_float(a1_sign, a1_exp, a1_frac)   # a1 = real part of com_B
        b1_val = assemble_float(b1_sign, b1_exp, b1_frac)   # b1 = img  part of com_B

        a1_bits = float_to_bits(a1_val) # bit form of real part com_B
        b1_bits = float_to_bits(b1_val) # bit form of img  part com_B

        B_re   = int(a1_bits, 2) << 64 
        B_im   = int(b1_bits, 2)

        COM_B_bits  = B_re | B_im 

        ###################################################
        #      write hex type of IEEE754 for testbench    #
        ###################################################
        ca_in.write(f"{COM_A_bits:032X}\n")
        cb_in.write(f"{COM_B_bits:032X}\n")

        ##############################################
        #       wirte visible type for debugging     #
        ##############################################
        fa_in.write(f"{a0_val:.16e}   +  j * {b0_val:.16e}\n")
        fb_in.write(f"{a1_val:.16e}   +  j * {b1_val:.16e}\n")
    
        ##############################################
        #               complex mul op               #
        ##############################################
        result_re_val , result_im_val = cmul(a0_bits , b0_bits , a1_bits , b1_bits )
        fg_in.write(f"{result_re_val:.16e}  +  j * {result_im_val:.16e} \n")
        
        result_re_bits = float_to_bits(result_re_val)
        result_im_bits = float_to_bits(result_im_val)
        
        result_re      = int(result_re_bits, 2) << 64 
        result_im      = int(result_im_bits, 2)
        result         = result_re | result_im
        
        cg_in.write(f"{result:032X}\n")
print(f"10000 of complex mul pattern generated !")                

