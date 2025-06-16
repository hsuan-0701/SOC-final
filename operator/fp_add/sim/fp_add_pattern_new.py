import struct
import random

def bits_to_float(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]

def float_to_bits(f):
    bits = struct.unpack(">Q", struct.pack(">d", f))[0]
    return f'{bits:064b}'

def encode_IEEE754 (s , e , m ):
    m_funct = m & ( (1<<52) -1 )
    bits = (s << 63) | (e << 52) | m_funct 
    return bits

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

def extract_components(bits):
    sign_funct = (bits >> 63) & 1
    exponent_funct = (bits >> 52) & 0x7FF
    mantissa_funct = bits & ((1 << 52) - 1)
    if exponent_funct != 0:
        mantissa_funct |= (1 << 52)  # hidden bit
    return sign_funct, exponent_funct, mantissa_funct

##########################################################################
#             Rounding 、 normalization 、 alignment                      #
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
    if m_funct ==0 :
        return 0 , 0
    while m_funct >= (1 << (53 + position_move)):
        m_funct >>= 1
        e_funct += 1
    while m_funct and (m_funct < (1 << (52 + position_move))):
        if e_funct == 0:
            return m_funct ,e_funct
        else :
            m_funct <<= 1
            e_funct -= 1 
    return m_funct, e_funct

def align_exponents(m1, e1, m2, e2,position_move):
    m1_funct = m1
    m2_funct = m2
    e1_funct = e1
    e2_funct = e2
    # we shift left 52bit before op in hardware
    if e1_funct > e2_funct:
        shift = e1_funct - e2_funct
        if shift >= (53 + position_move) :
            m2_funct =  0 
        else : m2_funct >>= shift
        return m1_funct, m2_funct, e1_funct
    else:
        shift = e2_funct - e1_funct
        if shift >= (53 + position_move) :
            m1_funct = 0 
        else : m1_funct >>= shift
        return m1_funct, m2_funct, e2_funct

####################################################################
#                        add operation (fp)                         #
####################################################################
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
    # NaN case
    if ea_funct == 2047 and ( (ma_funct & ((1<<52) -1)) != 0 ):
        return 0 , 2047 , 1
    if eb_funct == 2047 and ( (mb_funct & ((1<<52) -1)) != 0 ):
        return 0 , 2047 , 1
    # double inf case
    if ea_funct == 2047 and eb_funct == 2047:
        if(sa_funct != sb_funct):
            return 0 , 2047 , 1
        else :
            return sa_funct , 2047 , 0
    # single inf case
    if ea_funct == 2047 :
        return sa_funct , 2047 , 0
    if eb_funct == 2047 :
        return sb_funct , 2047 , 0
    ##########################################
    #               Normal                   #
    ##########################################
    ma_funct <<= 52
    mb_funct <<= 52
    # while subnormal case , bias must be  1022 , so we shift 1 bits of mantissa to modify
    if ea_funct == 0 :
        ma_funct <<= 1
    if eb_funct == 0 :
        mb_funct <<= 1
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
    result_m = round_to_nearest_even_with_sticky(result_m , lsb_position=52)
    result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
    # Zero case or inf case  
    if result_e_final  >= 2047 :
        return result_s , 2047 , 0
    elif result_e_final < 0  :
        return 0 , 0 , 0
    elif result_e_final == 0 and result_m_final == 0 :
        return 0 , 0 , 0
    # modify subnormal case while exp == 0 , bias must become 1022 , so we shift mantissa 1 bit
    elif result_e_final == 0 and result_m_final != 0 :
        return result_s , result_e_final , (result_m_final >> 1)
    else :
        return result_s, result_e_final, result_m_final
    
# def fp64_add(ma, mb, ea, eb, sa, sb):
#     ma_funct = ma
#     mb_funct = mb
    
#     ea_funct = ea
#     eb_funct = eb
    
#     sa_funct = sa
#     sb_funct = sb
#     ###########################################
#     #               Denormal                  #
#     ###########################################
#     # NaN case
#     if ea_funct == 2047 and ( (ma_funct & ((1<<52) -1)) != 0 ):
#         return 0 , 2047 , 1
#     if eb_funct == 2047 and ( (mb_funct & ((1<<52) -1)) != 0 ):
#         return 0 , 2047 , 1
#     # double inf case
#     if ea_funct == 2047 and eb_funct == 2047:
#         if(sa_funct != sb_funct):
#             return 0 , 2047 , 1
#         else :
#             return sa_funct , 2047 , 0
#     # single inf case
#     if ea_funct == 2047 :
#         return sa_funct , 2047 , 0
#     if eb_funct == 2047 :
#         return sb_funct , 2047 , 0
#     ##########################################
#     #               Normal                   #
#     ##########################################
#     ma_funct <<= 52
#     mb_funct <<= 52
#     ma_funct, mb_funct, e_funct = align_exponents(ma_funct, ea_funct, mb_funct, eb_funct , position_move=52)
#     if sa_funct == sb_funct:
#         result_m = ma_funct + mb_funct
#         result_s = sa_funct
#     else:
#         if ma_funct >= mb_funct:
#             result_m = ma_funct - mb_funct
#             result_s = sa_funct
#         else:
#             result_m = mb_funct - ma_funct
#             result_s = sb_funct
    
#     result_m, result_e = normalize(result_m, e_funct , position_move=52)
#     result_m = round_to_nearest_even_with_sticky(result_m , lsb_position=52)
#     result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
#     # Zero case or inf case  
#     if result_e_final  >= 2047 :
#         return result_s , 2047 , 0
#     elif result_e_final < 0  :
#         return 0 , 0 , 0
#     elif result_e_final == 0 and result_m_final == 0 :
#         return 0 , 0 , 0
#     else :
#         return result_s, result_e_final, result_m_final
    


##########################################################################
#                         Generate  pattern                              #
##########################################################################
def generate_random_sign():
    return random.randint(0, 1)

def generate_random_exp():
    return random.randint(0, 2047)  

def generate_random_mantissa():
    return random.randint(0, (1 << 52) - 1)

def ieee754_double_to_hex(sign, exponent, mantissa):
    bits = (sign << 63) | (exponent << 52) | mantissa
    return f"{bits:016X}"


pattern_num = 500000

with open("a.dat", "w") as fa, open("b.dat", "w") as fb, open("golden.dat", "w") as fg, \
     open("a_float.dat", "w") as fa_fp, open("b_float.dat", "w") as fb_fp, open("golden_float.dat", "w") as fg_fp:

    for i in range(pattern_num):
        a_sign = generate_random_sign()
        b_sign = generate_random_sign()

        a_exp =  generate_random_exp()
        b_exp = generate_random_exp()
        
        a_frac = generate_random_mantissa()
        b_frac = generate_random_mantissa()

            
        a_bits = encode_IEEE754(a_sign , a_exp , a_frac )
        b_bits = encode_IEEE754(b_sign , b_exp , b_frac )
        
        a_val  = bits_to_float(a_bits)
        b_val  = bits_to_float(b_bits)
        
        if(a_exp == 2047) and (a_frac != 0) :
            fa_fp.write(f"NAN\n")
        else :
            fa_fp.write(f"{a_val:.16e}\n")
        
        if(b_exp == 2047) and (b_frac != 0) :
            fb_fp.write(f"NAN\n")
        else :
            fb_fp.write(f"{b_val:.16e}\n") 
            
        sa, ea, ma = extract_components(a_bits)
        sb, eb, mb = extract_components(b_bits)


        result_s , result_e , result_m = fp64_add(ma, mb, ea, eb, sa, sb)
        result_bits = encode_IEEE754 (result_s , result_e , result_m )
        result_val  = bits_to_float(result_bits)
        if(result_e == 2047) and (result_m != 0):
            fg_fp.write(f" NaN \n")
        else :
            fg_fp.write(f"{result_val:.16e}\n")
            
        fa.write(f"{a_bits:016X}\n")
        fb.write(f"{b_bits:016X}\n")
        fg.write(f"{result_bits:016X}\n")



print(f"{pattern_num} of pattern generated !")




