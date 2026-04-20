import json
import os
import sys

city_names = {
    "amadiya": "ئامێدى",
    "amedi": "ئامێدى",
    "arbat": "عەربەت",
    "akre": "عەقرە",
    "barznja": "بەرزنجە",
    "barzan": "بەرزنجە",
    "bazian": "بازیان",
    "bazyan": "بازیان",
    "chamchamal": "چەمچەماڵ",
    "chwartha": "چوارتا",
    "chwarta": "چوارتا",
    "darbandikhan": "دەربەندیخان",
    "darbandixan": "دەربەندیخان",
    "duhok": "دهۆک",
    "dokan": "دوکان",
    "dukan": "دوکان",
    "hajiawa": "حاجیاوا",
    "halabja": "هەلەبجە",
    "halabjan": "هەلەبجەى تازە",
    "halabja_taza": "هەلەبجەى تازە",
    "hawler": "هەولێر",
    "kalar": "کەلار",
    "kifri": "کفرى",
    "kfri": "کفرى",
    "kirkuk": "کەرکووک",
    "koya": "کۆیە",
    "mosul": "موسڵ",
    "penjwen": "پێنجوێن",
    "penjuin": "پێنجوێن",
    "piramagroon": "پیرەمەگرون",
    "piramagrun": "پیرەمەگرون",
    "qaderkaram": "قادرکەرەم",
    "qadirkaram": "قادرکەرەم",
    "qaladze": "قەڵادزێ",
    "qaradagh": "قەرەداغ",
    "qaradax": "قەرەداغ",
    "qasre": "قەسرێ",
    "ranya": "ڕانیە",
    "saidsadiq": "سیدصادق",
    "sulaimani": "سلێمانى",
    "slemany": "سلێمانى",
    "soran": "سۆران",
    "takya": "تەکیە",
    "taqtaq": "تەق تەق",
    "tasluja": "تاسڵوجە",
    "duzkhurmatoo": "دوزخورماتو",
    "tuzxurmatu": "دوزخورماتو",
    "xalakan": "خەلەکان",
    "xanaqin": "خانەقین",
    "zakho": "زاخۆ",
    "zaxo": "زاخۆ",
}

def write_compact(f, data):
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

def convert_file(input_path, output_path, city_key):
    with open(input_path, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    months = {}
    seen_dates = set()

    for entry in data:
        if entry.get("Date", "") == "D" or entry.get("ID", "") == "ID":
            continue
        date = entry.get("Date", "")
        if not date or "-" not in date:
            continue
        if date in seen_dates:
            continue
        seen_dates.add(date)

        try:
            month = int(date.split("-")[0])
            day = int(date.split("-")[1])
        except:
            continue

        if month not in months:
            months[month] = []

        months[month].append({
            "day": day,
            "fajr": entry["Fajr"],
            "sunrise": entry["Sunrise"],
            "dhuhr": entry["Dhuhr"],
            "asr": entry["Asr"],
            "maghrib": entry["Maghrib"],
            "isha": entry["Isha"]
        })

    months_list = []
    for month_num in sorted(months.keys()):
        days = sorted(months[month_num], key=lambda x: x["day"])
        months_list.append({"month": month_num, "days": days})

    city_name = city_names.get(city_key, city_key)

    result = {
        "city": city_name,
        "source": "Bang Kurdistan",
        "months": months_list
    }

    write_compact(output_path, result)
    print(f'✅ {city_key} -> {os.path.basename(output_path)}')

def main():
    input_folder = sys.argv[1] if len(sys.argv) > 1 else "."
    output_folder = sys.argv[2] if len(sys.argv) > 2 else "output"

    os.makedirs(output_folder, exist_ok=True)

    converted = 0
    errors = 0
    for filename in sorted(os.listdir(input_folder)):
        if filename.endswith(".json"):
            city_key = filename.replace(".json", "").replace("_prayer_times", "").replace("_2026", "").replace("_2025", "").lower()

            input_path = os.path.join(input_folder, filename)
            output_filename = f"{city_key}_prayer_times.json"
            output_path = os.path.join(output_folder, output_filename)

            try:
                convert_file(input_path, output_path, city_key)
                converted += 1
            except Exception as e:
                print(f'❌ Error in {filename}: {e}')
                errors += 1

    print(f'\n✅ تەواو بوو! {converted} فایل گۆڕدرا، {errors} هەڵە')

if __name__ == "__main__":
    main()
