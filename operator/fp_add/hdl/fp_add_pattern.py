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
    sign = (bits >> 63) & 1
    exponent = (bits >> 52) & 0x7FF
    mantissa = bits & ((1 << 52) - 1)
    if exponent != 0:
        mantissa |= (1 << 52)  # hidden bit
    return sign, exponent, mantissa

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

#####################################################################
#                     Alignment before add                          #
#####################################################################

def align_exponents(m1, e1, m2, e2):
    if e1 > e2:
        shift = e1 - e2
        m2 = 0 if shift >= 64 else m2 >> shift
        return m1, m2, e1
    else:
        shift = e2 - e1
        m1 = 0 if shift >= 64 else m1 >> shift
        return m1, m2, e2

def round_to_nearest_even(m):
    guard = (m >> 1) & 1
    round_bit = m & 1
    lsb = (m >> 2) & 1
    if guard == 1 and (round_bit == 1 or lsb == 1):
        m += 4
    return m >> 2

def normalize(m, e):
    while m >= (1 << 55):
        m >>= 1
        e += 1
    while m and m < (1 << 53):
        m <<= 1
        e -= 1
    return m, e

def assemble_float(sign, exponent, mantissa):
    if exponent >= 2047:
        exponent = 2047
        mantissa = 0
    elif exponent < 0:
        exponent = 0
        mantissa = 0
    else:
        mantissa &= ~(1 << 52)
    bits = (sign << 63) | (exponent << 52) | mantissa
    return bits_to_float(bits)

def fp64_add(ma, mb, ea, eb, sa, sb):
    ma, mb, e = align_exponents(ma, ea, mb, eb)
    ma <<= 2
    mb <<= 2
    if sa == sb:
        result_m = ma + mb
        result_s = sa
    else:
        if ma >= mb:
            result_m = ma - mb
            result_s = sa
        else:
            result_m = mb - ma
            result_s = sb
    result_m, result_e = normalize(result_m, e)
    result_m = round_to_nearest_even(result_m)
    return assemble_float(result_s, result_e, result_m)

#########################################################################################################
#                               Generate pattern and  write into .txt                                   #
#########################################################################################################

pattern_num = 1000

with open("a.dat", "w") as fa, open("b.dat", "w") as fb, open("golden.dat", "w") as fg, \
     open("a_float.dat", "w") as fa_fp, open("b_float.dat", "w") as fb_fp, open("golden_float.dat", "w") as fg_fp:

    for i in range(pattern_num):
        a_sign = generate_random_sign()
        b_sign = generate_random_sign()

        a_exp =  generate_random_exp()
        b_exp = generate_random_exp()
        
        a_frac = generate_random_mantissa()
        b_frac = generate_random_mantissa()

        a_val = assemble_float(a_sign, a_exp, a_frac)
        b_val = assemble_float(b_sign, b_exp, b_frac)

        a_bits = float_to_bits(a_val)
        b_bits = float_to_bits(b_val)

        sa, ea, ma = extract_components(int(a_bits, 2))
        sb, eb, mb = extract_components(int(b_bits, 2))

        result_val = fp64_add(ma, mb, ea, eb, sa, sb)

        fa.write(f"{int(a_bits, 2):016X}\n")
        fb.write(f"{int(b_bits, 2):016X}\n")
        fg.write(f"{int(float_to_bits(result_val), 2):016X}\n")

        fa_fp.write(f"{a_val:.16e}\n")
        fb_fp.write(f"{b_val:.16e}\n")
        fg_fp.write(f"{result_val:.16e}\n")

print(f"{pattern_num} of pattern generated !")
