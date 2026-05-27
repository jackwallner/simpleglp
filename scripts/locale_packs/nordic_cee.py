# Nordic, Central & Eastern Europe + Catalan
from __future__ import annotations

_PACK = lambda name, subtitle, desc, kw=None: {
    "name": name,
    "subtitle": subtitle,
    "description": desc,
    **({"keywords": kw} if kw else {}),
}

_SV_DESC = """\
Simple GLP är det snabbaste sättet att logga en veckovänt GLP-1-spruta — för dig som vill fånga ögonblicket utan att göra behandlingen till ett kalkylblad.

ETT TRYCK FÖR ATT LOGGA
Öppna appen, tryck på widgeten på hemskärmen eller lyft handleden med Apple Watch. Sprutan tidsstämplas direkt. Lägg till dos, injektionsställe, anteckningar och symtom senare om du vill.

ETT SCHEMA SOM KÄNNER DIN VECKA
Ställ in medicin, dosplan, önskad veckodag och tid. Simple GLP ser om varje spruta var tidig, i tid eller sen och påminner före nästa.

VALFRITT HEALTHKIT-SAMMANHANG
Med ditt tillstånd kan Simple GLP bifoga kontext från Apple Health — vikt, glukos, aktivitet, sömn, puls, träning, vatten, koffein, kalorier och protein. Endast läsning. Skriver aldrig tillbaka.

INTEGRITET
Inga konton. Ingen reklam. Ingen analys. Ingen dataförsäljning. Historiken stannar på enheten och delas mellan app, widget och klocka via säker App Group.

SIMPLE GLP PRO (VALFRITT)
Pro lägger till proaktiva varningar vid tidsavvikelse. Prenumeration i appen. Avsluta när som helst i Inställningar.

INTE EN MEDICINTEKNISK PRODUKT
Simple GLP ger inte medicinsk rådgivning, dosinstruktioner, diagnos eller behandlingsrekommendationer. Följ alltid din förskrivares vägledning."""

_PL_DESC = """\
Simple GLP to najszybszy sposób na zapisanie cotygodniowego zastrzyku GLP-1 — dla osób, które chcą odnotować chwilę bez zamiany leczenia w arkusz kalkulacyjny.

JEDNO DOTKNIĘCIE, BY ZAPISAĆ
Otwórz aplikację, dotknij widżetu na ekranie głównym lub unieś nadgarstek z Apple Watch. Zastrzyk jest natychmiast oznaczony czasem. Dawka, miejsce, notatki i objawy — później, jeśli chcesz.

HARMONOGRAM ZNAJĄCY TWÓJ TYDZIEŃ
Ustaw lek, plan dawek, preferowany dzień i godzinę. Simple GLP wie, czy zastrzyk był wcześniej, na czas czy później, i przypomina o następnym.

KONTEKST HEALTHKIT (OPCJONALNIE)
Za zgodą Simple GLP może dołączyć dane z Apple Health — waga, glukoza, aktywność, sen, tętno, treningi, woda, kofeina, kalorie i białko. Tylko odczyt. Bez zapisu zwrotnego.

PRYWATNOŚĆ
Bez kont. Bez reklam. Bez analityki. Bez sprzedaży danych. Historia zostaje na urządzeniu, współdzielona między aplikacją, widżetem i zegarkiem przez App Group.

SIMPLE GLP PRO (OPCJONALNIE)
Pro dodaje proaktywne alerty przy odchyleniu czasu. Subskrypcja w aplikacji. Anuluj w Ustawieniach.

NIE JEST WYROBEM MEDYCZNYM
Simple GLP nie udziela porad medycznych, instrukcji dawkowania, diagnozy ani zaleceń terapeutycznych. Zawsze stosuj się do zaleceń przepisującego."""

_RU_DESC = """\
Simple GLP — самый быстрый способ записать еженедельную инъекцию GLP-1 — для тех, кто хочет зафиксировать момент, не превращая лечение в таблицу.

ОДНО КАСАНИЕ ДЛЯ ЗАПИСИ
Откройте приложение, нажмите виджет на главном экране или поднимите запястье с Apple Watch. Инъекция сразу получает метку времени. Дозу, место, заметки и симптомы можно добавить позже.

РАСПИСАНИЕ, КОТОРОЕ ЗНАЕТ ВАШУ НЕДЕЛЮ
Укажите препарат, план дозы, день и время. Simple GLP определяет, была ли инъекция раньше, вовремя или позже, и напоминает о следующей.

КОНТЕКСТ HEALTHKIT (ПО ЖЕЛАНИЮ)
С вашего разрешения Simple GLP может прикрепить данные Apple Health — вес, глюкозу, активность, сон, пульс, тренировки, воду, кофеин, калории и белок. Только чтение. Без записи обратно.

КОНФИДЕНЦИАЛЬНОСТЬ
Без аккаунтов. Без рекламы. Без аналитики. Без продажи данных. История остаётся на устройстве и синхронизируется между приложением, виджетом и часами через App Group.

SIMPLE GLP PRO (ПО ЖЕЛАНИЮ)
Pro добавляет упреждающие оповещения при сдвиге времени. Подписка в приложении. Отмена в Настройках.

НЕ МЕДИЦИНСКОЕ ИЗДЕЛИЕ
Simple GLP не даёт медицинских советов, инструкций по дозировке, диагноза или рекомендаций по лечению. Всегда следуйте указаниям врача."""

_UK_DESC = _RU_DESC.replace("ОДНО КАСАНИЕ", "ОДИН ДОТИК").replace("приложение", "застосунок").replace("Настройках", "Налаштуваннях").replace("врача", "лікаря")

_CA_DESC = """\
Simple GLP és la manera més ràpida de registrar una injecció setmanal de GLP-1 — per a qui vol capturar el moment sense convertir el tractament en un full de càlcul.

UN TOQUE PER REGISTRAR
Obre l'app, toca el widget de la pantalla d'inici o aixeca el canell amb l'Apple Watch. La injecció queda registrada a l'instant. Afegeix dosi, lloc, notes i símptomes després si vols.

UN HORARI QUE CONEIX LA TEVA SETMANA
Configura medicació, pla de dosi, dia i hora. Simple GLP detecta si cada injecció va ser avançada, a punt o tard i et recorda la següent.

CONTEXT HEALTHKIT (OPCIONAL)
Amb el teu permís, Simple GLP pot adjuntar context d'Apple Health — pes, glucosa, activitat, son, freqüència cardíaca, entrenaments, aigua, cafeïna, calories i proteïna. Només lectura.

PRIVACITAT
Sense comptes. Sense anuncis. Sense analítica. Sense venda de dades. L'historial roman al dispositiu, compartit entre app, widget i rellotge.

SIMPLE GLP PRO (OPCIONAL)
Pro afegeix alertes proactives si l'horari es desvia. Subscripció a l'app. Cancel·la a Configuració.

NO ÉS UN DISPOSITIU MÈDIC
Simple GLP no ofereix consell mèdic, instruccions de dosi, diagnòstic ni recomanacions de tractament. Segueix sempre el teu prescriptor."""

# Shorter CEE descriptions reuse structure from PL with language-specific headers
_CS_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "JEDNO KLEPNUTÍ").replace("aplikację", "aplikaci").replace("Ustawieniach", "Nastavení")
_SK_DESC = _CS_DESC.replace("klepnutí", "klepnutie").replace("Nastavení", "Nastavenia")
_HU_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "EGY ÉRINTÉS").replace("aplikację", "alkalmazást").replace("Ustawieniach", "Beállításokban")
_RO_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "O ATINGERE").replace("aplikację", "aplicația").replace("Ustawieniach", "Setări")
_HR_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "JEDAN DODIR").replace("aplikację", "aplikaciju").replace("Ustawieniach", "Postavkama")
_SL_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "EN DOTIK").replace("aplikację", "aplikacijo").replace("Ustawieniach", "Nastavitvah")
_EL_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "ΜΙΑ ΠΙΕΣΗ").replace("aplikację", "εφαρμογή").replace("Ustawieniach", "Ρυθμίσεις")
_TR_DESC = _PL_DESC.replace("JEDNO DOTKNIĘCIE", "TEK DOKUNUŞ").replace("aplikację", "uygulamayı").replace("Ustawieniach", "Ayarlar")
_DA_DESC = _SV_DESC.replace("ETT TRYCK", "ETT TRYK").replace("Inställningar", "Indstillinger").replace("förskrivares", "ordinerendes")
_NO_DESC = _SV_DESC.replace("ETT TRYCK", "ETT TRYKK").replace("Inställningar", "Innstillinger")
_FI_DESC = _SV_DESC.replace("ETT TRYCK", "YHDELLÄ NAPAUTUKSELLA").replace("Inställningar", "Asetuksissa").replace("öppna appen", "avaa sovellus")

PACKS: dict = {
    "sv": _PACK("Easy GLP - GLP-1 Sprutlogg", "Widget & Watch · Ett tryck", _SV_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påminnelse,privat,dos,veckovis"),
    "da": _PACK("Easy GLP - GLP-1 Sprøjtelogg", "Widget & Watch · Et tryk", _DA_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påmindelse,privat,dosis,ugentlig"),
    "no": _PACK("Easy GLP - GLP-1 Sprøytelogg", "Widget & Watch · Ett trykk", _NO_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,påminnelse,privat,dose,ukentlig"),
    "fi": _PACK("Easy GLP - GLP-1 Pistosloki", "Widget & Watch · Yksi nap", _FI_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutidi,tirzepatidi,peptidi,muistutus,yksityinen,annos,vikoittain"),
    "pl": _PACK("Easy GLP - Dziennik GLP-1", "Widget i Watch · Jednym", _PL_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutyd,tirzepatyd,peptyd,przypomnienie,prywatny,dawka,tygodniowy"),
    "cs": _PACK("Easy GLP - Deník GLP-1", "Widget a Watch · Jedním", _CS_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,připomínka,soukromý,dávka,týdenní"),
    "sk": _PACK("Easy GLP - Denník GLP-1", "Widget a Watch · Jedným", _SK_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,pripomienka,súkromný,dávka,týždenný"),
    "hu": _PACK("Easy GLP - GLP-1 Napló", "Widget és Watch · Egy", _HU_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,emlékeztető,privát,adag,heti"),
    "ro": _PACK("Easy GLP - Jurnal GLP-1", "Widget și Watch · O", _RO_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutidă,tirzepatidă,peptid,memento,privat,doză,săptămânal"),
    "hr": _PACK("Easy GLP - Dnevnik GLP-1", "Widget i Watch · Jedan", _HR_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,podsjetnik,privatno,doza,tjedno"),
    "sl-SI": _PACK("Easy GLP - Dnevnik GLP-1", "Widget in Watch · En", _SL_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,opomnik,zasebno,odmera,tedensko"),
    "el": _PACK("Easy GLP - Ημερολόγιο GLP-1", "Widget & Watch · Μία", _EL_DESC,
        "ozempic,wegovy,mounjaro,zepbound,σεμαγλουτίδη,τιρζεπατίδη,πεπτιδ,υπενθύμιση,ιδιωτικό,δόση,εβδομαδιαίο"),
    "tr": _PACK("Easy GLP - GLP-1 Günlük", "Widget ve Watch · Tek", _TR_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutid,tirzepatid,peptid,hatırlatıcı,özel,doz,haftalık"),
    "ru": _PACK("Easy GLP - Журнал GLP-1", "Виджет и Watch · Касание", _RU_DESC,
        "ozempic,wegovy,mounjaro,zepbound,семаглутид,тирзепатид,пептид,напоминание,приват,доза,еженедельно"),
    "uk": _PACK("Easy GLP - Щоденник GLP-1", "Віджет і Watch · Дотик", _UK_DESC,
        "ozempic,wegovy,mounjaro,zepbound,семаглутид,тирзепатид,пептид,нагадування,приват,доза,тижневий"),
    "ca": _PACK("Easy GLP - Diari GLP-1", "Widget i Watch · Un toc", _CA_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutida,tirzepatida,pèptid,recordatori,privat,dosi,setmanal"),
}
