#!/usr/bin/env python3
"""Apply optimized native keywords/subtitles for all fastlane metadata locales (Simple GLP).

Dedupes keywords against each locale's name + subtitle (Apple indexes all three).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"

# Brand + feature tokens (≤100 chars after dedupe). No repeats of name/subtitle terms.
KEYWORDS: dict[str, str] = {
    "en-US": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose",
    "en-GB": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose",
    "en-AU": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose",
    "en-CA": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose",
    "de-DE": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,erinnerung,spritze,privat,dosis,wöchentlich",
    "fr-FR": "ozempic,wegovy,mounjaro,zepbound,sémaglutide,tirzépatide,peptide,rappel,injection,privé,dose,hebdomadaire",
    "fr-CA": "ozempic,wegovy,mounjaro,zepbound,sémaglutide,tirzépatide,peptide,rappel,injection,privé,dose,hebdomadaire",
    "es-ES": "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,péptido,recordatorio,inyección,privado,dosis,semanal",
    "es-MX": "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,péptido,recordatorio,inyección,privado,dosis,semanal",
    "ca": "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,pèptid,recordatori,injecció,privat,dosi,setmanal",
    "it": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,promemoria,iniezione,privato,dose,settimanale",
    "pt-BR": "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,peptídeo,lembrete,injeção,privado,dose,semanal",
    "pt-PT": "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,peptídeo,lembrete,injeção,privado,dose,semanal",
    "nl-NL": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,herinnering,injectie,privé,dosis,wekelijks",
    "pl": "ozempic,wegovy,mounjaro,zepbound,semaglutyd,tirzepatyd,peptyd,przypomnienie,zastrzyk,prywatny,dawka,tygodniowy",
    "sv": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påminnelse,spruta,privat,dos,veckovis",
    "da": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påmindelse,indsprøjtning,privat,dosis,ugentlig",
    "no": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påminnelse,sprøyte,privat,dose,ukentlig",
    "fi": "ozempic,wegovy,mounjaro,zepbound,semaglutidi,tirzepatidi,peptidi,muistutus,ruiske,yksityinen,annos,vikoittain",
    "cs": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,připomínka,injekce,soukromý,dávka,týdenní",
    "sk": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,pripomienka,injekcia,súkromný,dávka,týždenný",
    "hu": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,emlékeztető,injekció,privát,adag,heti",
    "ro": "ozempic,wegovy,mounjaro,zepbound,semaglutidă,tirzepatidă,peptid,memento,injecție,privat,doză,săptămânal",
    "hr": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,podsjetnik,injekcija,privatno,doza,tjedno",
    "el": "ozempic,wegovy,mounjaro,zepbound,σεμαγλουτίδη,τιρζεπατίδη,πεπτιδ,υπενθύμιση,ένεση,ιδιωτικό,δόση,εβδομαδιαίο",
    "tr": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,hatırlatıcı,enjeksiyon,özel,doz,haftalık",
    "ru": "ozempic,wegovy,mounjaro,zepbound,семаглутид,тирзепатид,пептид,напоминание,инъекция,приват,доза,еженедельно",
    "uk": "ozempic,wegovy,mounjaro,zepbound,семаглутид,тирзепатид,пептид,нагадування,ін'єкція,приват,доза,тижневий",
    "ja": "オゼンピック,ウゴービ,マンジャロ,ゼップバウンド,セマグルチド,チルゼパチド,ペプチド,リマインダー,注射,プライベート,用量,週次",
    "ko": "오젬픽,위고비,마운자로,젭바운드,세마글루타이드,티르제파타이드,펩타이드,알림,주사,프라이빗,용량,주간",
    "zh-Hans": "司美格鲁肽,替尔泊肽,利拉鲁肽,度拉糖肽,奥泽匹克,维戈维,玛仕度肽,泽普肽,肽,提醒,注射,私密,剂量,每周",
    "zh-Hant": "司美格魯肽,替爾泊肽,利拉魯肽,度拉糖肽,奧澤匹克,維戈維,瑪仕度肽,澤普肽,肽,提醒,注射,私密,劑量,每週",
    "ar-SA": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,ببتيد,تذكير,حقن,خاص,جرعة,أسبوعي",
    "he": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,פפטיד,תזכורת,זריקה,פרטי,מינון,שבועי",
    "hi": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,पेप्टाइड,रिमाइंडर,इंजेक्शन,प्राइवेट,खुराक,साप्ताहिक",
    "th": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,เปปไทด์,เตือน,ฉีด,ส่วนตัว,ขนาด,รายสัปดาห์",
    "vi": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,nhắc,tiêm,riêng,liều,hàngtuần",
    "id": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptida,pengingat,suntik,privat,dosis,mingguan",
    "ms": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptida,peringatan,suntikan,peribadi,dos,mingguan",
    "bn-BD": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,পেপটাইড,রিমাইন্ডার,ইনজেকশন,প্রাইভেট,ডোজ,সাপ্তাহিক",
    "gu-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,પેપટાઇડ,રિમાઇન્ડર,ઇન્જેક્શન,ખાનગી,ડોઝ,સાપ્તાહિક",
    "kn-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,ಪೆಪ್ಟೈಡ್,ಜ್ಞಾಪನೆ,ಇಂಜೆಕ್ಷನ್,ಖಾಸಗಿ,ಡೋಸ್,ವಾರಕ್ಕೊಮ್ಮೆ",
    "ml-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,പെപ്റ്റൈഡ്,ഓർമ്മപ്പെടുത്തൽ,ഇഞ്ചക്ഷൻ,സ്വകാര്യ,ഡോസ്,ആഴ്ചതോറും",
    "mr-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,पेप्टाइड,स्मरण,इंजेक्शन,खाजगी,डोस,साप्ताहिक",
    "or-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,ପେପଟାଇଡ୍,ସ୍ମରଣ,ଇଞ୍ଜେକ୍ସନ,ବ୍ୟକ୍ତିଗତ,ଡୋଜ,ସାପ୍ତାହିକ",
    "pa-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,ਪੇਪਟਾਈਡ,ਯਾਦ,ਇੰਜੈਕਸ਼ਨ,ਨਿੱਜੀ,ਖੁਰਾਕ,ਹਫ਼ਤਾਵਾਰ",
    "ta-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,பெப்டைடு,நினைவூட்டல்,ஊசி,தனிப்பட்ட,அளவு,வாராந்திர",
    "te-IN": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,పెప్టైడ్,రిమైండర్,ఇంజెక్షన్,ప్రైవేట్,డోస్,వారంవారం",
    "ur-PK": "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,پیپٹائڈ,یاددہانی,انجکشن,نجی,خوراک,ہفتہوار",
    "sl-SI": "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,opomnik,injekcija,zasebno,odmera,tedensko",
}

SUBTITLES: dict[str, str] = {
    "en-US": "One-Tap Widget · Watch Log",
    "en-GB": "One-Tap Widget · Watch Log",
    "en-AU": "One-Tap Widget · Watch Log",
    "en-CA": "One-Tap Widget · Watch Log",
    "de-DE": "Widget & Watch · Ein-Tap-Log",
    "fr-FR": "Widget & Montre · Log 1 toucher",
    "fr-CA": "Widget & Montre · Log 1 toucher",
    "es-ES": "Widget y Watch · Log un toque",
    "es-MX": "Widget y Watch · Log un toque",
    "ca": "Widget i Watch · Log un toc",
    "it": "Widget e Watch · Log un tocco",
    "pt-BR": "Widget e Watch · Log um toque",
    "pt-PT": "Widget e Watch · Log um toque",
    "nl-NL": "Widget & Watch · Log één tik",
    "pl": "Widget i Watch · Log jednym tap",
    "ja": "ウィジェット・Watchでワンタップログ",
    "ko": "위젯·워치 원탭 주사 기록",
    "zh-Hans": "小组件与手表一键记录",
    "zh-Hant": "小組件與手錶一鍵記錄",
}

NAMES: dict[str, str] = {
    "en-US": "Easy GLP - GLP-1 Shot Tracker",
    "en-GB": "Easy GLP - GLP-1 Shot Tracker",
    "en-AU": "Easy GLP - GLP-1 Shot Tracker",
    "en-CA": "Easy GLP - GLP-1 Shot Tracker",
    "de-DE": "Easy GLP - GLP-1 Spritzen-Log",
    "fr-FR": "Easy GLP - Suivi injection GLP-1",
    "fr-CA": "Easy GLP - Suivi injection GLP-1",
    "es-ES": "Easy GLP - Registro inyección GLP-1",
    "es-MX": "Easy GLP - Registro inyección GLP-1",
    "it": "Easy GLP - Diario iniezioni GLP-1",
    "pt-BR": "Easy GLP - Registro injeção GLP-1",
    "ja": "Easy GLP - GLP-1注射トラッカー",
    "ko": "Easy GLP - GLP-1 주사 트래커",
    "zh-Hans": "Easy GLP - GLP-1注射记录",
    "zh-Hant": "Easy GLP - GLP-1注射記錄",
}


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def dedupe_keywords(name: str, subtitle: str, keywords_csv: str) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    for raw in keywords_csv.replace(" ", "").split(","):
        kw = raw.strip().lower()
        if not kw:
            continue
        if kw in indexed:
            continue
        if any(kw == t or (len(kw) >= 4 and kw in t) or (len(t) >= 4 and t in kw) for t in indexed):
            continue
        kept.append(kw)
    return ",".join(kept)


def trim_keywords(s: str, limit: int = 100) -> str:
    s = s.replace(" ", "")
    if len(s) <= limit:
        return s
    parts = s.split(",")
    while parts and len(",".join(parts)) > limit:
        parts.pop()
    return ",".join(parts)


def trim_subtitle(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def trim_name(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def main() -> None:
    report: dict[str, dict] = {}
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue
        kw_path = loc_dir / "keywords.txt"
        sub_path = loc_dir / "subtitle.txt"
        name_path = loc_dir / "name.txt"
        old_kw = kw_path.read_text(encoding="utf-8").strip() if kw_path.exists() else ""
        old_sub = sub_path.read_text(encoding="utf-8").strip() if sub_path.exists() else ""
        old_name = name_path.read_text(encoding="utf-8").strip() if name_path.exists() else ""
        name = NAMES.get(loc, old_name)
        if loc in NAMES and name_path.exists():
            new_name = trim_name(name)
            name_path.write_text(new_name + "\n", encoding="utf-8")
            name = new_name
        sub_for_dedupe = SUBTITLES.get(loc, old_sub)
        raw_kw = KEYWORDS[loc]
        new_kw = trim_keywords(dedupe_keywords(name, sub_for_dedupe, raw_kw))
        kw_path.write_text(new_kw + "\n", encoding="utf-8")
        new_sub = old_sub
        if loc in SUBTITLES:
            new_sub = trim_subtitle(SUBTITLES[loc])
            sub_path.write_text(new_sub + "\n", encoding="utf-8")
        report[loc] = {
            "name": {"old": old_name, "new": name} if loc in NAMES else {},
            "keywords": {"old": old_kw, "new": new_kw, "len": len(new_kw)},
            "subtitle": {"old": old_sub, "new": new_sub} if loc in SUBTITLES else {},
        }
    out = ROOT / "scripts" / "aso-locale-optimization-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {len(report)} locales → {out}")


if __name__ == "__main__":
    main()
