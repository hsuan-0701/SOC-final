import random


with open("A.dat", "w") as f_a, open("B.dat", "w") as f_b, open("GOLDEN.dat", "w") as f_g:
    for i in range(10000):
        A = random.randint(0, 2722258935367507707706996859454145691647)  # 131-bit A
        B = random.randint(0, 2722258935367507707706996859454145691647)  # 131-bit B
        # A = random.randint(0, 65535)  # 131-bit A
        # B = random.randint(0, 65535)  # 131-bit B
        golden = A + B                # 131-bit 結果

        # 寫入各自檔案（十進位格式）
        f_a.write(f"{A}\n")
        f_b.write(f"{B}\n")
        f_g.write(f"{golden}\n")

print("成功產出 A.dat, B.dat, GOLDEN.dat 各 10000 筆資料")
