import json
import os
import glob

folder = r'E:\prayer_time\my-project\assets\data'

for f in glob.glob(os.path.join(folder, '*.json')):
    try:
        with open(f, 'r', encoding='utf-8-sig') as file:
            data = json.load(file)
    except:
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
            data = json.loads(content)
        except Exception as e:
            print(f'❌ {os.path.basename(f)}: {e}')
            continue

    if 'months' not in data:
        continue

    with open(f, 'w', encoding='utf-8') as file:
        file.write('{\n')
        file.write(f'  "city": "{data["city"]}",\n')
        file.write(f'  "source": "{data["source"]}",\n')
        file.write('  "months": [\n')
        for mi, month in enumerate(data['months']):
            file.write('    {\n')
            file.write(f'      "month": {month["month"]},\n')
            file.write('      "days": [\n')
            for di, day in enumerate(month['days']):
                comma = ',' if di < len(month['days']) - 1 else ''
                line = '        {"day": ' + str(day["day"])
                line += ', "fajr": "' + day["fajr"] + '"'
                line += ', "sunrise": "' + day["sunrise"] + '"'
                line += ', "dhuhr": "' + day["dhuhr"] + '"'
                line += ', "asr": "' + day["asr"] + '"'
                line += ', "maghrib": "' + day["maghrib"] + '"'
                line += ', "isha": "' + day["isha"] + '"}'
                line += comma + '\n'
                file.write(line)
            file.write('      ]\n')
            mcomma = ',' if mi < len(data['months']) - 1 else ''
            file.write(f'    }}{mcomma}\n')
        file.write('  ]\n')
        file.write('}\n')

    print(f'✅ {os.path.basename(f)}')

print('\nتەواو بوو!')
