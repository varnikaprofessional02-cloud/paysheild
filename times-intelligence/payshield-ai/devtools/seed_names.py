"""LOCAL TEST ONLY: give the synthetic employees made-up, Singapore-style names (Chinese, Malay, Indian and expat mix)
instead of "Synthetic E00001". Names are combined from common first and family names; they are not real people."""

from __future__ import annotations

import random

CHINESE = (["Wei Ming", "Hui Ling", "Jia Hui", "Kai Xin", "Jun Jie", "Mei Ling", "Zhi Hao", "Xin Yi", "Wen Jie", "Li Ting",
            "Yong Sheng", "Shu Fen", "Jia Wei", "Pei Shan", "Kok Leong", "Siew Mei", "Boon Keat", "Hui Min", "Chee Keong", "Yu Ting"],
           ["Tan", "Lim", "Lee", "Ng", "Ong", "Wong", "Goh", "Chua", "Chan", "Koh", "Teo", "Ang", "Yeo", "Tay", "Ho", "Low", "Sim", "Chong"])
MALAY_M = (["Muhammad Faizal", "Ahmad Yusof", "Hafiz", "Mohd Irfan", "Iskandar", "Amirul", "Khairul", "Ridwan"],
           ["bin Ismail", "bin Abdullah", "bin Osman", "bin Ahmad", "bin Hassan", "bin Salleh"])
MALAY_F = (["Nurul Huda", "Siti Rahmah", "Nur Aisyah", "Farah Nadia", "Zarina", "Nabilah", "Aishah", "Syafiqah"],
           ["binte Rahman", "binte Hassan", "binte Salleh", "binte Ali", "binte Ismail", "binte Osman"])
INDIAN = (["Karthik", "Priya", "Ravi", "Divya", "Arjun", "Meena", "Suresh", "Lakshmi", "Vikram", "Anitha", "Ganesh", "Kavitha",
           "Rajesh", "Deepa", "Harish", "Shalini"],
          ["Subramaniam", "Menon", "Kumar", "Pillai", "Nair", "Rajan", "Krishnan", "Raman", "Naidu", "Chandran"])
OTHER = (["Daniel", "Sarah", "Marcus", "Grace", "Joshua", "Rachel", "Kevin", "Nicole", "Ryan", "Michelle", "Adrian", "Joanne"],
         ["Fernandez", "D'Souza", "Rodrigues", "Pereira", "Santos", "Reyes", "Smith", "Walker", "Cruz", "Gomez"])
MIX = [CHINESE] * 6 + [MALAY_M, MALAY_F] + [INDIAN] * 2 + [OTHER]  # roughly the Singapore workforce mix


def name_employees(c, company_id: int, seed: int = 21) -> int:
    """Renames every employee of the company (unique names, matching work emails). Returns how many were renamed."""
    rng = random.Random(seed)
    users = c.execute("""SELECT u.id FROM security."user" u JOIN employee.user_company_contract ucc ON ucc.user_id = u.id
                         WHERE ucc.company_id = %s ORDER BY ucc.employee_no""", (company_id,)).fetchall()
    used: set[tuple[str, str]] = set()
    for row in users:
        while True:
            first, last = rng.choice(MIX)
            pair = (rng.choice(first), rng.choice(last))
            if pair not in used:
                used.add(pair)
                break
        local = ".".join(w.lower() for w in (pair[0].split()[0], pair[1].split()[-1])).replace("'", "")
        c.execute('UPDATE security."user" SET first_name = %s, last_name = %s, email = %s WHERE id = %s',
                  (pair[0], pair[1], f"{local}{row['id']}@carltonhotel.example", row["id"]))
    return len(users)
