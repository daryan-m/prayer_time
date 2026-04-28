import json

path = 'assets/quran/quran.json'

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

surahs = data['data']['surahs']
for surah in surahs:
    if surah['number'] == 1:
        for ayah in surah['ayahs']:
            if ayah['numberInSurah'] == 1:
                print(f"پێشتر: {ayah['text'][:80]}")
                # یەکەم وشەی بسملە دەسڕێتەوە
                words = ayah['text'].split(' ')
                # بسملە ٤ وشەیە لە سەرەتا
                ayah['text'] = ' '.join(words[4:]).strip()
                print(f"دواتر: {ayah['text'][:80]}")

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("تەواو ✅")
