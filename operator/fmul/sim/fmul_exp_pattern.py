import random

pattern_num = 50000

#############################################################################################
#                                  EXP CALCULATE                                            #
#############################################################################################
def exp_calculate (ea ,eb):
    if ea == 0 :
        ea_real = ea - 1022
    else :
        ea_real = ea -1023
    
    if eb == 0 :
        eb_real = eb -1022
    else :
        eb_real = eb -1023
    
    e = ea_real + eb_real
    e = e+1023
    # if(ea == 2047 or eb == 2047): e =2047
    # if(C==1):   e=0
    return e

with open("exp_A.dat", "w") as f_a, open("exp_B.dat", "w") as f_b, open("exp_golden.dat", "w") as f_g , open("out_inf.dat","w") as f_c:
    for i in range(pattern_num):
        if i < 1000 :
        # test subnormal case
            A = 0
            B = random.randint(0 , 2047)
        else :    
            A = random.randint(0, 2047)  # 11-bit A
            B = random.randint(0, 2047)  # 11-bit B
        golden = exp_calculate(A,B)   # 11-bit exp 結果
        out_inf = 0
        if A==2047 : out_inf = 1
        if B==2047 : out_inf = 1
        # 寫入各自檔案（十進位格式）
        f_a.write(f"{A}\n")
        f_b.write(f"{B}\n")
        f_c.write(f"{out_inf}\n")
        f_g.write(f"{golden}\n")

print(f"{pattern_num} of fmul_exp pattern generated !")