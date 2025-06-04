import random

# 開啟三個檔案
with open("A.dat", "w") as f_a, open("B.dat", "w") as f_b, open("GOLDEN.dat", "w") as f_g:
    for i in range(5000):
        #A = random.randint(0, 9007199254740991)  # 53-bit A
        #B = random.randint(0, 9007199254740991)  # 53-bit B
        # A = random.randint(0, 65535)  # 16-bit A
        # B = random.randint(0, 65535)  # 16-bit B

        A = random.randint(0, 2047)  # 11-bit A
        B = random.randint(0, 2047)  # 11-bit B
        
        golden = A + B                # 53-bit 結果

        # 寫入各自檔案（十進位格式）
        f_a.write(f"{A}\n")
        f_b.write(f"{B}\n")
        f_g.write(f"{golden}\n")

print("成功產出 A.dat, B.dat, GOLDEN.dat 各 5000 筆資料")